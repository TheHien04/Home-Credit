{{ config(alias='FactLoanApplicationMVP') }}

select
    ApplicationID,
    SourceBatchID,
    cast(TargetFlag as bit) as DefaultFlag,
    ContractType,
    GenderCode,
    AgeYears,
    case
        when AgeYears < 25 then 'Under 25'
        when AgeYears < 35 then '25-34'
        when AgeYears < 45 then '35-44'
        when AgeYears < 55 then '45-54'
        when AgeYears < 65 then '55-64'
        else '65+'
    end as AgeBand,
    IncomeAmount,
    case
        when IncomeAmount < 100000 then 'Under 100k'
        when IncomeAmount < 150000 then '100k-149k'
        when IncomeAmount < 250000 then '150k-249k'
        else '250k+'
    end as IncomeBand,
    CreditAmount,
    AnnuityAmount,
    GoodsPriceAmount,
    case when IncomeAmount > 0 then cast(AnnuityAmount / IncomeAmount as decimal(18, 10)) end as AnnuityToIncomeRatio,
    EmploymentSentinelFlag,
    MissingAnnuityFlag,
    MissingGoodsPriceFlag
from {{ ref('int_application_features') }}
where DatasetSplit = 'TRAIN'

