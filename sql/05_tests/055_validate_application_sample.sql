/*
Purpose: Validate the bounded 5,000 TRAIN + 5,000 TEST application demo load.
Usage: Set @BatchID to the SSIS sample batch before execution.
This script is sample-only and must not be used to validate the full load.
*/

SET NOCOUNT ON;
GO
DECLARE @BatchID BIGINT = NULL; -- REQUIRED: replace NULL with the SSIS sample BatchID.

IF @BatchID IS NULL
    THROW 51550, 'Set @BatchID to the SSIS application sample batch before running this script.', 1;

IF NOT EXISTS (SELECT 1 FROM ctl.ETLBatch WHERE BatchID = @BatchID)
    THROW 51551, 'The selected BatchID does not exist.', 1;

DECLARE @Results TABLE
(
    TestCode VARCHAR(80) NOT NULL,
    ExpectedValue BIGINT NOT NULL,
    ActualValue BIGINT NOT NULL
);

INSERT @Results (TestCode, ExpectedValue, ActualValue)
SELECT 'SAMPLE_TOTAL_ROWS', 10000, COUNT_BIG(*)
FROM stg.Application
WHERE BatchID = @BatchID
UNION ALL
SELECT 'SAMPLE_TRAIN_ROWS', 5000, COUNT_BIG(*)
FROM stg.Application
WHERE BatchID = @BatchID AND DatasetSplit = 'TRAIN'
UNION ALL
SELECT 'SAMPLE_TEST_ROWS', 5000, COUNT_BIG(*)
FROM stg.Application
WHERE BatchID = @BatchID AND DatasetSplit = 'TEST'
UNION ALL
SELECT 'SAMPLE_TRAIN_DEFAULTS', 386, COUNT_BIG(*)
FROM stg.Application
WHERE BatchID = @BatchID AND DatasetSplit = 'TRAIN' AND TARGET = 1
UNION ALL
SELECT 'SAMPLE_NULL_KEYS', 0, COUNT_BIG(*)
FROM stg.Application
WHERE BatchID = @BatchID AND SK_ID_CURR IS NULL
UNION ALL
SELECT 'SAMPLE_INVALID_TARGET_SCOPE', 0, COUNT_BIG(*)
FROM stg.Application
WHERE BatchID = @BatchID
  AND ((DatasetSplit = 'TRAIN' AND (TARGET IS NULL OR TARGET NOT IN (0, 1)))
       OR (DatasetSplit = 'TEST' AND TARGET IS NOT NULL))
UNION ALL
SELECT 'SAMPLE_DUPLICATE_KEYS', 0, COALESCE(SUM(DuplicateRows), 0)
FROM
(
    SELECT COUNT_BIG(*) - 1 AS DuplicateRows
    FROM stg.Application
    WHERE BatchID = @BatchID
    GROUP BY SK_ID_CURR
    HAVING COUNT_BIG(*) > 1
) AS duplicates;

SELECT
    TestCode,
    ExpectedValue,
    ActualValue,
    CASE WHEN ExpectedValue = ActualValue THEN 'PASS' ELSE 'FAIL' END AS TestStatus
FROM @Results
ORDER BY TestCode;

IF EXISTS (SELECT 1 FROM @Results WHERE ExpectedValue <> ActualValue)
    THROW 51552, 'Application sample validation failed. Review the result grid.', 1;
GO
