-- запрос нужен для создания параметров выборки участка
select 'All' as code ,N'Все участки' as DESCRIPTION 
union 
select code,DESCRIPTION from demo.lkp_code
where CATEGORY = N'zone' and CODE_GROUP = @project_code and DESCRIPTION not like N'%archive%'