{{ config(alias='ApplicationFeatures') }}

with source_rows as (
    select * from {{ ref('stg_application') }}
),
normalized as (
    select
        SourceBatchID,
        SourceRowNumber,
        DatasetSplit,
        ApplicationID,
        cast(TargetFlag as bit) as TargetFlag,
        case
            when nullif(ltrim(rtrim(ContractTypeRaw)), '') is null
              or upper(ltrim(rtrim(ContractTypeRaw))) = 'XNA' then 'Unknown'
            when upper(ltrim(rtrim(ContractTypeRaw))) = 'XAP' then 'Not applicable'
            else ltrim(rtrim(ContractTypeRaw))
        end as ContractType,
        case
            when nullif(ltrim(rtrim(GenderCodeRaw)), '') is null
              or upper(ltrim(rtrim(GenderCodeRaw))) = 'XNA' then 'Unknown'
            else ltrim(rtrim(GenderCodeRaw))
        end as GenderCode,
        cast(ChildrenCount as int) as ChildrenCount,
        cast(IncomeAmount as decimal(19, 2)) as IncomeAmount,
        cast(CreditAmount as decimal(19, 2)) as CreditAmount,
        cast(AnnuityAmount as decimal(19, 2)) as AnnuityAmount,
        cast(GoodsPriceAmount as decimal(19, 2)) as GoodsPriceAmount,
        case when DaysBirth < 0 then cast(floor(-DaysBirth / 365.25) as smallint) end as AgeYears,
        case
            when DaysEmployed = 365243 then null
            when DaysEmployed < 0 then cast(-DaysEmployed as int)
        end as EmploymentTenureDays,
        cast(case when DaysEmployed = 365243 then 1 else 0 end as bit) as EmploymentSentinelFlag,
        cast(case when AnnuityAmount is null then 1 else 0 end as bit) as MissingAnnuityFlag,
        cast(case when GoodsPriceAmount is null then 1 else 0 end as bit) as MissingGoodsPriceFlag,
        ExternalScore1,
        ExternalScore2,
        ExternalScore3
    from source_rows
)
select * from normalized

