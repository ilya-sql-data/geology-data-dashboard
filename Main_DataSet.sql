-- temporary tables for report performance
IF OBJECT_ID('tempdb..#Sites') IS NOT NULL DROP TABLE #Sites;
IF OBJECT_ID('tempdb..#SampleCnt') IS NOT NULL DROP TABLE #SampleCnt;
IF OBJECT_ID('tempdb..#SampleKeys') IS NOT NULL DROP TABLE #SampleKeys;
IF OBJECT_ID('tempdb..#LabSrc') IS NOT NULL DROP TABLE #LabSrc;

-- filtered sites
SELECT
    project_code,
    zone_code,
    hole_id,
    site_type,
    completed_at
INTO #Sites
FROM demo.site
WHERE project_code = @project_code
  AND hole_id NOT LIKE '%test%'
  AND site_type = @site_type
  AND (@zone_code = N'All' OR zone_code = @zone_code)
  AND (
        @Year = 0
        OR (
            completed_at >= DATEFROMPARTS(@Year, 1, 1)
            AND completed_at < DATEADD(YEAR, 1, DATEFROMPARTS(@Year, 1, 1))
        )
      )
  AND (
        @month IS NULL
        OR DATEPART(MONTH, completed_at) IN (
            SELECT TRY_CAST(LTRIM(RTRIM([value])) AS int)
            FROM STRING_SPLIT(@month, ',')
        )
      )
  AND (
        @SiteID IS NULL
        OR @SiteID = ''
        OR hole_id IN (
            SELECT LTRIM(RTRIM([value]))
            FROM STRING_SPLIT(@SiteID, ',')
        )
      );

CREATE INDEX IX_Sites_project_code_hole_id ON #Sites(project_code, hole_id);

-- samples + duplicates + standards
SELECT
    x.project_code,
    x.hole_id,
    x.sample_primary,
    x.sample_type,
    x.parent_sample_primary,
    x.depth_from,
    x.depth_to,
    x.mass,
    x.src,
    CASE
        WHEN x.parent_sample_primary IS NULL OR x.parent_sample_primary = N'' THEN NULL
        ELSE COUNT(*) OVER (PARTITION BY x.parent_sample_primary)
    END AS parent_cnt
INTO #SampleCnt
FROM (
    SELECT
        sam.project_code,
        sam.hole_id,
        sam.sample_primary,
        sam.sample_type,
        CAST(NULL AS NVARCHAR(32)) AS parent_sample_primary,
        sam.depth_from,
        sam.depth_to,
        sam.mass,
        N'SAMPLE' AS src
    FROM demo.sample_primary sam
    JOIN #Sites s
      ON s.project_code = sam.project_code
     AND s.hole_id = sam.hole_id

    UNION ALL

    SELECT
        sc.project_code,
        sc.hole_id,
        sc.sample_primary,
        sc.sample_type,
        sc.parent_sample_primary,
        CAST(NULL AS DECIMAL(10,2)) AS depth_from,
        CAST(NULL AS DECIMAL(10,2)) AS depth_to,
        CAST(NULL AS DECIMAL(10,3)) AS mass,
        N'CHECK' AS src
    FROM demo.sample_duplicate sc
    JOIN #Sites s
      ON s.project_code = sc.project_code
     AND s.hole_id = sc.hole_id

    UNION ALL

    SELECT
        sq.project_code,
        sq.hole_id,
        sq.sample_primary,
        sq.sample_type,
        sq.standard_id AS parent_sample_primary,
        CAST(NULL AS DECIMAL(10,2)) AS depth_from,
        CAST(NULL AS DECIMAL(10,2)) AS depth_to,
        CAST(NULL AS DECIMAL(10,3)) AS mass,
        N'QAQC' AS src
    FROM demo.sample_standard sq
    JOIN #Sites s
      ON s.project_code = sq.project_code
     AND s.hole_id = sq.hole_id
) x;

CREATE INDEX IX_SampleCnt_hole_id_sample_primary ON #SampleCnt(hole_id, sample_primary);
CREATE INDEX IX_SampleCnt_sample_primary ON #SampleCnt(sample_primary);

SELECT DISTINCT
    sample_primary
INTO #SampleKeys
FROM #SampleCnt
WHERE sample_primary IS NOT NULL;

CREATE UNIQUE CLUSTERED INDEX IX_SampleKeys ON #SampleKeys(sample_primary);

-- lab results
SELECT
    st.sample_primary,
    st.batch_id,
    st.job_no,
    st.lab_element,
    st.result
INTO #LabSrc
FROM demo.lab_result st
JOIN #SampleKeys k
  ON k.sample_primary = st.sample_primary

UNION ALL

SELECT
    ss.sample_primary,
    ss.batch_id,
    ss.job_no,
    ss.lab_element,
    ss.result
FROM demo.lab_result_standard ss
JOIN #SampleKeys k
  ON k.sample_primary = ss.sample_primary;

CREATE CLUSTERED INDEX IX_LabSrc_sample_primary ON #LabSrc(sample_primary);
CREATE INDEX IX_LabSrc_sample_primary_element ON #LabSrc(sample_primary, lab_element) INCLUDE (result);
CREATE INDEX IX_LabSrc_sample_primary_batch ON #LabSrc(sample_primary, batch_id) INCLUDE (job_no);

;WITH ResultPivot AS (
    SELECT
        ls.sample_primary,
        ROUND(MIN(CASE WHEN ls.lab_element = N'Au' THEN ls.result END), 2) AS Au,
        ROUND(MIN(CASE WHEN ls.lab_element = N'Ag' THEN ls.result END), 2) AS Ag
    FROM #LabSrc ls
    GROUP BY ls.sample_primary
),
LastJob AS (
    SELECT
        x.sample_primary,
        x.batch_id,
        x.send_date,
        x.job_no
    FROM (
        SELECT
            ls.sample_primary,
            ls.batch_id,
            ls.job_no,
            des.send_date,
            ROW_NUMBER() OVER (
                PARTITION BY ls.sample_primary
                ORDER BY
                    CASE WHEN ls.job_no IS NULL THEN 1 ELSE 0 END,
                    des.send_date DESC,
                    ls.batch_id DESC
            ) AS rn
        FROM #LabSrc ls
        LEFT JOIN demo.lab_dispatch des
          ON des.batch_id = ls.batch_id
    ) x
    WHERE x.rn = 1
)
SELECT
    lj.batch_id,
    TRY_CONVERT(NVARCHAR(10), lj.send_date, 104) AS [date],
    lj.job_no,
    s.hole_id,
    smp.sample_primary,
    smp.depth_from,
    smp.depth_to,
    smp.depth_to - smp.depth_from AS [length],
    CASE
        WHEN smp.sample_type = N'smp_A' THEN N'Primary sample'
        WHEN smp.sample_type = N'dup_A' THEN N'duplicate_1'
        WHEN smp.sample_type = N'dup_B' THEN N'duplicate_2'
        WHEN smp.sample_type = N'dup_C' THEN N'duplicate_3'
        WHEN smp.sample_type = N'st_A' THEN N'standard_1'
        WHEN smp.sample_type = N'st_B' THEN N'Blank'
        WHEN smp.sample_type = N'st_C' THEN N'standard_2'
        WHEN smp.sample_type = N'grr_A' THEN N'grr_sample'
        WHEN smp.sample_type = N'grr_B' THEN N'grr_sample_2'
        WHEN smp.sample_type = N'grr_C' THEN N'grr_sample_3'
        WHEN smp.sample_type = N'?' THEN N'no_sample'
        ELSE N'other'
    END AS sample_type,
    CASE
        WHEN smp.parent_sample_primary = N'EMPTY' THEN N'empty_sample'
        WHEN smp.parent_sample_primary = N'BLANK_EMPTY' THEN N'Blank'
        ELSE smp.parent_sample_primary
    END AS parent_sample_primary,
    rp.Au,
    rp.Ag,
    smp.mass,
    s.site_type,
    TRY_CONVERT(NVARCHAR(10), s.completed_at, 104) AS completed_at,
    smp.parent_cnt
FROM #Sites s
LEFT JOIN #SampleCnt smp
       ON s.project_code = smp.project_code
      AND s.hole_id = smp.hole_id
LEFT JOIN ResultPivot rp
       ON rp.sample_primary = smp.sample_primary
LEFT JOIN LastJob lj
       ON lj.sample_primary = smp.sample_primary
LEFT JOIN demo.lkp_code a
       ON a.code = s.zone_code
      AND a.category = N'zone'
ORDER BY
    s.hole_id,
    smp.sample_primary,
    smp.depth_from;