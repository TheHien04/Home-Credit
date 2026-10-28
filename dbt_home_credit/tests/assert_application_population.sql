select 1 as invalid_population
where (
    select count_big(*)
    from {{ ref('fct_loan_application') }}
) <> 307511
or (
    select count_big(*)
    from {{ ref('fct_loan_application') }}
    where DefaultFlag = 1
) <> 24825

