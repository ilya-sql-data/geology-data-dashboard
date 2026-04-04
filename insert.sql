/* DEMO SEED (SQL Server)
   Назначение: синтетические данные для запуска отчётного запроса/дашборда
   Схема: demo
   Примечания:
   - sample_id уникален глобально
   - Есть несколько batch_id на одну пробу (для проверки логики "последнего результата")
   - Есть Au/Ag и пару лишних элементов (чтобы было видно фильтрацию) */

SET NOCOUNT ON;

BEGIN TRAN;

-- 1) Справочники (параметры)
INSERT INTO demo.lkp_code(category, code, description, code_group)
VALUES
-- Месторождения/проекты
(N'project', N'PJT1', N'Project Alpha (demo)', NULL),
(N'project', N'PJT2', N'Project Beta (demo)',  NULL),

-- Участки/зоны (привязаны к project_code через code_group)
(N'zone', N'ZN-01', N'Zone 01 (demo)', N'PJT1'),
(N'zone', N'ZN-02', N'Zone 02 (demo)', N'PJT1'),
(N'zone', N'ZN-11', N'Zone 11 (demo)', N'PJT2');

-- 2) Скважины/выработки
INSERT INTO demo.site(project_code, zone_code, hole_id, site_type, completed_at)
VALUES
(N'PJT1', N'ZN-01', N'Hole-A-001', N'DRILL', '2025-01-12'),
(N'PJT1', N'ZN-01', N'Hole-A-002', N'DRILL', '2025-02-03'),
(N'PJT1', N'ZN-02', N'Hole-A-003', N'TRENCH', '2025-02-20'),
(N'PJT1', N'ZN-02', N'Hole-A-004', N'DRILL', '2025-03-05'),
(N'PJT2', N'ZN-11', N'Hole-B-001', N'DRILL', '2025-02-10');

-- 3) Основные пробы (интервальные)
INSERT INTO demo.sample_primary(project_code, hole_id, sample_id, sample_type, parent_sample_id, depth_from, depth_to, mass)
VALUES
-- Hole-A-001
(N'PJT1', N'Hole-A-001', N'SMP-0001', N'smp_A', NULL,  0.00,  1.00, 2.150),
(N'PJT1', N'Hole-A-001', N'SMP-0002', N'smp_A', NULL,  1.00,  2.00, 2.090),
(N'PJT1', N'Hole-A-001', N'SMP-0003', N'smp_A', NULL,  2.00,  3.00, 2.020),

-- Hole-A-002
(N'PJT1', N'Hole-A-002', N'SMP-0101', N'smp_A', NULL, 10.00, 11.00, 1.980),
(N'PJT1', N'Hole-A-002', N'SMP-0102', N'smp_A', NULL, 11.00, 12.00, 2.010),

-- Hole-A-003
(N'PJT1', N'Hole-A-003', N'SMP-0201', N'smp_A', NULL,  0.00,  0.50, 1.200),

-- Hole-A-004
(N'PJT1', N'Hole-A-004', N'SMP-0301', N'smp_A', NULL,  5.00,  6.00, 2.300),

-- Hole-B-001
(N'PJT2', N'Hole-B-001', N'SMP-1001', N'smp_A', NULL, 20.00, 21.00, 2.050);

-- 4) Дубликаты/контрольные пробы (ссылаются на parent_sample_id)
INSERT INTO demo.sample_duplicate(project_code, hole_id, sample_id, sample_type, parent_sample_id)
VALUES
(N'PJT1', N'Hole-A-001', N'DUP-0001', N'dup_A', N'SMP-0002'),
(N'PJT1', N'Hole-A-001', N'DUP-0002', N'dup_B', N'SMP-0002'),
(N'PJT1', N'Hole-A-002', N'DUP-0101', N'dup_A', N'SMP-0101'),
(N'PJT2', N'Hole-B-001', N'DUP-1001', N'dup_C', N'SMP-1001');

-- 5) Стандарты/QAQC
INSERT INTO demo.sample_standard(project_code, hole_id, sample_id, sample_type, standard_id)
VALUES
(N'PJT1', N'Hole-A-001', N'STD-0001', N'st_A', N'STD-REF-01'),
(N'PJT1', N'Hole-A-002', N'STD-0101', N'st_B', N'STD-REF-02'),
(N'PJT2', N'Hole-B-001', N'STD-1001', N'st_A', N'STD-REF-01');

-- 6) Поставки в лабораторию (batch/dispatch)
INSERT INTO demo.lab_dispatch(batch_id, send_date)
VALUES
(N'BATCH-2025-01-001', '2025-01-15'),
(N'BATCH-2025-02-001', '2025-02-05'),
(N'BATCH-2025-02-002', '2025-02-22'),
(N'BATCH-2025-03-001', '2025-03-07');

-- 7) Результаты лаборатории (основной поток)
INSERT INTO demo.lab_result(sample_tag, batch_id, job_no, lab_element, result)
VALUES
-- SMP-0001 (одна поставка)
(N'SMP-0001', N'BATCH-2025-01-001', N'JOB-10001', N'Au', 0.120000),
(N'SMP-0001', N'BATCH-2025-01-001', N'JOB-10001', N'Ag', 1.800000),
(N'SMP-0001', N'BATCH-2025-01-001', N'JOB-10001', N'Cu', 55.000000),

-- SMP-0002
(N'SMP-0002', N'BATCH-2025-01-001', NULL,        N'Au', 0.090000),
(N'SMP-0002', N'BATCH-2025-01-001', NULL,        N'Ag', 1.200000),
(N'SMP-0002', N'BATCH-2025-02-002', N'JOB-10022', N'Au', 0.110000),
(N'SMP-0002', N'BATCH-2025-02-002', N'JOB-10022', N'Ag', 1.350000),

-- SMP-0003
(N'SMP-0003', N'BATCH-2025-02-001', N'JOB-10011', N'Au', 0.060000),
(N'SMP-0003', N'BATCH-2025-02-001', N'JOB-10011', N'Ag', 0.900000),

-- SMP-0101
(N'SMP-0101', N'BATCH-2025-02-001', N'JOB-10101', N'Au', 0.200000),
(N'SMP-0101', N'BATCH-2025-02-001', N'JOB-10101', N'Ag', 2.400000),

-- SMP-0102
(N'SMP-0102', N'BATCH-2025-03-001', N'JOB-10120', N'Au', 0.150000),
(N'SMP-0102', N'BATCH-2025-03-001', N'JOB-10120', N'Ag', 1.950000),

-- SMP-0201
(N'SMP-0201', N'BATCH-2025-02-002', N'JOB-10201', N'Au', 0.030000),
(N'SMP-0201', N'BATCH-2025-02-002', N'JOB-10201', N'Ag', 0.400000),

-- SMP-0301
(N'SMP-0301', N'BATCH-2025-03-001', N'JOB-10301', N'Au', 0.080000),
(N'SMP-0301', N'BATCH-2025-03-001', N'JOB-10301', N'Ag', 1.100000),

-- SMP-1001
(N'SMP-1001', N'BATCH-2025-02-001', N'JOB-11001', N'Au', 0.070000),
(N'SMP-1001', N'BATCH-2025-02-001', N'JOB-11001', N'Ag', 0.850000);

-- 8) Результаты по стандартам/контрольным
INSERT INTO demo.lab_result_standard(sample_tag, batch_id, job_no, lab_element, result)
VALUES
-- Стандарты
(N'STD-0001', N'BATCH-2025-01-001', N'JOB-STD-001', N'Au', 0.100000),
(N'STD-0001', N'BATCH-2025-01-001', N'JOB-STD-001', N'Ag', 1.000000),

(N'STD-0101', N'BATCH-2025-02-002', N'JOB-STD-101', N'Au', 0.100000),
(N'STD-0101', N'BATCH-2025-02-002', N'JOB-STD-101', N'Ag', 1.000000),

(N'STD-1001', N'BATCH-2025-02-001', N'JOB-STD-201', N'Au', 0.100000),
(N'STD-1001', N'BATCH-2025-02-001', N'JOB-STD-201', N'Ag', 1.000000),

-- Дубликаты как "контрольный поток" (по желанию)
(N'DUP-0001', N'BATCH-2025-02-002', N'JOB-DUP-001', N'Au', 0.105000),
(N'DUP-0001', N'BATCH-2025-02-002', N'JOB-DUP-001', N'Ag', 1.300000);

COMMIT;