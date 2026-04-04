-- запрос нужен для создания параметров выборки месторождения
select Code,DESCRIPTION from demo.lkp_code
where CATEGORY = 'Deposit'