/* DEMO DDL (SQL Server)
   Схема: demo
   Назначение: минимальная модель данных для демонстрации вашего отчёта
   Примечания:
   - Имена нейтральные (demo.*)
   - sample_id считается уникальным глобально
   - Ограничения и индексы подобраны под основной запрос и параметрические выборки */

-- 0) Создаём схему demo (если её нет)
IF SCHEMA_ID(N'demo') IS NULL
    EXEC(N'CREATE SCHEMA demo');
GO

/* 1) Справочник для параметров (месторождения/участки/и т.п.)
   Первичный ключ: (category, code) */
IF OBJECT_ID(N'demo.lkp_code', N'U') IS NOT NULL DROP TABLE demo.lkp_code;
GO

CREATE TABLE demo.lkp_code (
    category     NVARCHAR(64)  NOT NULL,
    code         NVARCHAR(24)  NOT NULL,
    description  NVARCHAR(250) NULL,
    code_group   NVARCHAR(64) NULL,   -- например, project_code для списка участков
    CONSTRAINT PK_lkp_code PRIMARY KEY CLUSTERED (category, code)
);
GO

-- Индекс для быстрых выборок значений параметров
CREATE INDEX IX_lkp_code_category_code_group
ON demo.lkp_code(category)
INCLUDE (code, description, code_group);
GO

-- Скважины / выработки (site)
IF OBJECT_ID(N'demo.site', N'U') IS NOT NULL DROP TABLE demo.site;
GO

CREATE TABLE demo.site (
    project_code  NVARCHAR(16)     NOT NULL,
    zone_code     NVARCHAR(32)     NOT NULL,
    hole_id       NVARCHAR(40)     NOT NULL,
    site_type     NVARCHAR(16)     NULL,
    completed_at  SMALLDATETIME    NULL,
    CONSTRAINT PK_site PRIMARY KEY CLUSTERED (project_code, hole_id)
);
GO

-- Индекс под типичные фильтры отчёта (месторождение/участок/тип/дата)
CREATE INDEX IX_site_filters
ON demo.site(project_code, zone_code, site_type, completed_at)
INCLUDE (hole_id);
GO

/* 3) Основные пробы (primary samples)
   PK по sample_id
   FK: (project_code, hole_id) -> demo.site */
IF OBJECT_ID(N'demo.sample_primary', N'U') IS NOT NULL DROP TABLE demo.sample_primary;
GO

CREATE TABLE demo.sample_primary (
    project_code       NVARCHAR(16)  NOT NULL,
    hole_id            NVARCHAR(40)  NOT NULL,
    sample_primary     NVARCHAR(30)  NOT NULL,
    sample_type        NVARCHAR(50)  NOT NULL,
    parent_sample_primary   NVARCHAR(30)  NULL,
    depth_from         DECIMAL(10,2) NULL,
    depth_to           DECIMAL(10,2) NULL,
    mass               DECIMAL(10,3) NULL,
    CONSTRAINT PK_sample_primary PRIMARY KEY CLUSTERED (sample_id),
    CONSTRAINT FK_sample_primary_site
        FOREIGN KEY (project_code, hole_id) REFERENCES demo.site(project_code, hole_id)
);
GO

-- Индекс для быстрых JOIN по скважине/месторождению при сборке выборки
CREATE INDEX IX_sample_primary_site
ON demo.sample_primary(project_code, hole_id)
INCLUDE (sample_id, sample_type, depth_from, depth_to, mass, parent_sample_id);
GO

/* 4) Контрольные / дубликатные пробы (duplicate/check samples)
   FK: (project_code, hole_id) -> demo.site
   parent_sample_id: ссылка на исходную пробу (логическая связь) */
IF OBJECT_ID(N'demo.sample_duplicate', N'U') IS NOT NULL DROP TABLE demo.sample_duplicate;
GO

CREATE TABLE demo.sample_duplicate (
    project_code       NVARCHAR(16)  NOT NULL,
    hole_id            NVARCHAR(40)  NOT NULL,
    sample_id          NVARCHAR(30)  NOT NULL,
    sample_type        NVARCHAR(50)  NOT NULL,
    parent_sample_id   NVARCHAR(30)  NOT NULL,
    CONSTRAINT PK_sample_duplicate PRIMARY KEY CLUSTERED (sample_id),
    CONSTRAINT FK_sample_duplicate_site
        FOREIGN KEY (project_code, hole_id) REFERENCES demo.site(project_code, hole_id)
);
GO

-- Индекс для выборки дублей по скважине
CREATE INDEX IX_sample_duplicate_site
ON demo.sample_duplicate(project_code, hole_id)
INCLUDE (sample_id, sample_type, parent_sample_id);
GO

-- Индекс для подсчёта/поиска по parent_sample_id (COUNT OVER / фильтрация)
CREATE INDEX IX_sample_duplicate_parent
ON demo.sample_duplicate(parent_sample_id)
INCLUDE (sample_id, project_code, hole_id);
GO

/* 5) Стандарты / QAQC
   sample_id уникален глобально (PK по sample_id).
   FK: (project_code, hole_id) -> demo.site */
IF OBJECT_ID(N'demo.sample_standard', N'U') IS NOT NULL DROP TABLE demo.sample_standard;
GO

CREATE TABLE demo.sample_standard (
    project_code       NVARCHAR(16)  NOT NULL,
    hole_id            NVARCHAR(40)  NOT NULL,
    sample_id          NVARCHAR(30)  NOT NULL,
    sample_type        NVARCHAR(50)  NOT NULL,
    standard_id        NVARCHAR(30)  NOT NULL,
    CONSTRAINT PK_sample_standard PRIMARY KEY CLUSTERED (sample_id),
    CONSTRAINT FK_sample_standard_site
        FOREIGN KEY (project_code, hole_id) REFERENCES demo.site(project_code, hole_id)
);
GO

-- Индекс для быстрых JOIN по скважине и выборки стандартов
CREATE INDEX IX_sample_standard_site
ON demo.sample_standard(project_code, hole_id)
INCLUDE (sample_id, sample_type, standard_id);
GO

/* 6) Поставки/отправки в лабораторию (dispatch/batch metadata)
   batch_id — уникальный идентификатор поставки (PK). */
IF OBJECT_ID(N'demo.lab_dispatch', N'U') IS NOT NULL DROP TABLE demo.lab_dispatch;
GO

CREATE TABLE demo.lab_dispatch (
    batch_id    NVARCHAR(64)  NOT NULL,
    send_date   SMALLDATETIME NULL,
    CONSTRAINT PK_lab_dispatch PRIMARY KEY CLUSTERED (batch_id)
);
GO

/* 7) Результаты лаборатории (основной поток)
   Нужно поддержать:
   - несколько элементов на пробу (Au/Ag/…)
   - несколько поставок на пробу (batch_id)
   Поэтому PK: (sample_tag, batch_id, lab_element)
   FK: sample_tag -> demo.sample_primary(sample_id)
   - batch_id   -> demo.lab_dispatch(batch_id) */
IF OBJECT_ID(N'demo.lab_result', N'U') IS NOT NULL DROP TABLE demo.lab_result;
GO

CREATE TABLE demo.lab_result (
    sample_tag   NVARCHAR(30)  NOT NULL,
    batch_id     NVARCHAR(64)  NOT NULL,
    job_no       NVARCHAR(64)  NULL,
    lab_element  NVARCHAR(16)  NOT NULL,
    result       DECIMAL(18,6) NULL,
    CONSTRAINT PK_lab_result PRIMARY KEY CLUSTERED (sample_tag, batch_id, lab_element),
    CONSTRAINT FK_lab_result_sample
        FOREIGN KEY (sample_tag) REFERENCES demo.sample_primary(sample_id),
    CONSTRAINT FK_lab_result_batch
        FOREIGN KEY (batch_id) REFERENCES demo.lab_dispatch(batch_id)
);
GO

-- Индекс под выборку результата по элементу (Au/Ag) для одной пробы
CREATE INDEX IX_lab_result_sample_element
ON demo.lab_result(sample_tag, lab_element)
INCLUDE (result, batch_id, job_no);
GO

-- Индекс под выбор “последней поставки” по пробе
CREATE INDEX IX_lab_result_sample_batch
ON demo.lab_result(sample_tag, batch_id)
INCLUDE (job_no);
GO

/* 8) Результаты лаборатории по стандартам/контрольным (отдельный поток)
   Структура такая же, как у demo.lab_result.
   В демо оставляем FK на demo.sample_primary(sample_id).
   Если хотите строго: можно поменять FK на demo.sample_standard(sample_id). */
IF OBJECT_ID(N'demo.lab_result_standard', N'U') IS NOT NULL DROP TABLE demo.lab_result_standard;
GO

CREATE TABLE demo.lab_result_standard (
    sample_tag   NVARCHAR(30)  NOT NULL,
    batch_id     NVARCHAR(64)  NOT NULL,
    job_no       NVARCHAR(64)  NULL,
    lab_element  NVARCHAR(16)  NOT NULL,
    result       DECIMAL(18,6) NULL,
    CONSTRAINT PK_lab_result_standard PRIMARY KEY CLUSTERED (sample_tag, batch_id, lab_element),
    CONSTRAINT FK_lab_result_standard_sample
        FOREIGN KEY (sample_tag) REFERENCES demo.sample_primary(sample_id),
    CONSTRAINT FK_lab_result_standard_batch
        FOREIGN KEY (batch_id) REFERENCES demo.lab_dispatch(batch_id)
);
GO

-- Индекс под выборку результата по элементу (Au/Ag) для стандартов
CREATE INDEX IX_lab_result_standard_sample_element
ON demo.lab_result_standard(sample_tag, lab_element)
INCLUDE (result, batch_id, job_no);
GO

-- Индекс под выбор “последней поставки” по стандартам/контрольным
CREATE INDEX IX_lab_result_standard_sample_batch
ON demo.lab_result_standard(sample_tag, batch_id)
INCLUDE (job_no);
GO
