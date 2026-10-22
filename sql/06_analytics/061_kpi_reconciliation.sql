/*
Purpose: Human-readable KPI evidence query after DDS validation.
Run after 060_create_analytics_views.sql and replace @BatchID as required.
*/

DECLARE @BatchID BIGINT = 1;

SELECT N'Executive' AS KPIGroup, *
FROM dds.vw_ExecutiveKPI
WHERE SourceBatchID = @BatchID;

SELECT N'Previous applications' AS KPIGroup, *
FROM dds.vw_PreviousApplicationKPI
WHERE SourceBatchID = @BatchID;

SELECT N'Payment behavior' AS KPIGroup, *
FROM dds.vw_PaymentKPI
WHERE SourceBatchID = @BatchID;

SELECT N'Bureau history' AS KPIGroup, *
FROM dds.vw_BureauKPI
WHERE SourceBatchID = @BatchID;

SELECT
    AgeBand,
    COUNT_BIG(*) AS Applications,
    SUM(CONVERT(BIGINT, DefaultFlag)) AS Defaults,
    CONVERT(DECIMAL(19,6), AVG(CONVERT(DECIMAL(19,6), DefaultFlag))) AS DefaultRate
FROM dds.vw_ApplicationAnalytics
WHERE SourceBatchID = @BatchID
GROUP BY AgeBand
ORDER BY MIN(AgeYears);

SELECT
    AffordabilityBand,
    COUNT_BIG(*) AS Applications,
    SUM(CONVERT(BIGINT, DefaultFlag)) AS Defaults,
    CONVERT(DECIMAL(19,6), AVG(CONVERT(DECIMAL(19,6), DefaultFlag))) AS DefaultRate
FROM dds.vw_ApplicationAnalytics
WHERE SourceBatchID = @BatchID
GROUP BY AffordabilityBand, AffordabilitySortOrder
ORDER BY AffordabilitySortOrder;

SELECT
    ContractType,
    COUNT_BIG(*) AS Applications,
    CONVERT(DECIMAL(19,2), AVG(CreditAmount)) AS AverageCreditAmount,
    CONVERT(DECIMAL(19,6), AVG(CONVERT(DECIMAL(19,6), DefaultFlag))) AS DefaultRate
FROM dds.vw_ApplicationAnalytics
WHERE SourceBatchID = @BatchID
GROUP BY ContractType
ORDER BY Applications DESC;
