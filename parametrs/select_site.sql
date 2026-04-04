-- запрос нужен для создания параметров выборки скважин
select distinct hole_id
from  demo.site 
where project_code =@project_code
	and (@zone_code = N'All' or zone_code = @zone_code)
	and site_type = @site_type
	and (@Year = 0 or (completed_at >= datefromparts(nullif(@Year,0), 1,1))
		and completed_at < dateadd(year,1, datefromparts(nullif(@Year,0), 1,1)))
AND DATEPART(month, completed_at) in (@month)
order by hole_id