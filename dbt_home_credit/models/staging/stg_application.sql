{{ config(alias='ApplicationCleanInput') }}

select
    BatchID as SourceBatchID,
    SourceRowNumber,
    DatasetSplit,
    SK_ID_CURR as ApplicationID,
    TARGET as TargetFlag,
    NAME_CONTRACT_TYPE as ContractTypeRaw,
    CODE_GENDER as GenderCodeRaw,
    FLAG_OWN_CAR as OwnCarFlagRaw,
    FLAG_OWN_REALTY as OwnRealtyFlagRaw,
    CNT_CHILDREN as ChildrenCount,
    AMT_INCOME_TOTAL as IncomeAmount,
    AMT_CREDIT as CreditAmount,
    AMT_ANNUITY as AnnuityAmount,
    AMT_GOODS_PRICE as GoodsPriceAmount,
    NAME_INCOME_TYPE as IncomeTypeRaw,
    NAME_EDUCATION_TYPE as EducationTypeRaw,
    NAME_FAMILY_STATUS as FamilyStatusRaw,
    NAME_HOUSING_TYPE as HousingTypeRaw,
    DAYS_BIRTH as DaysBirth,
    DAYS_EMPLOYED as DaysEmployed,
    OCCUPATION_TYPE as OccupationTypeRaw,
    ORGANIZATION_TYPE as OrganizationTypeRaw,
    EXT_SOURCE_1 as ExternalScore1,
    EXT_SOURCE_2 as ExternalScore2,
    EXT_SOURCE_3 as ExternalScore3
from {{ source('home_credit_stg', 'application') }}
where BatchID = {{ var('batch_id') }}

