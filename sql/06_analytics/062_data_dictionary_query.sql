/*
Purpose: Export a technical data dictionary from the deployed SQL Server schema.
Copy the result grid to the report appendix or CSV.
*/

SELECT
    s.name AS SchemaName,
    t.name AS TableName,
    c.column_id AS ColumnOrder,
    c.name AS ColumnName,
    ty.name AS DataType,
    CASE
        WHEN ty.name IN ('nvarchar', 'nchar') AND c.max_length > 0 THEN c.max_length / 2
        ELSE c.max_length
    END AS MaxLength,
    c.precision AS NumericPrecision,
    c.scale AS NumericScale,
    c.is_nullable AS IsNullable,
    c.is_identity AS IsIdentity,
    CONVERT(BIT, CASE WHEN pk.column_id IS NULL THEN 0 ELSE 1 END) AS IsPrimaryKey,
    fk.ReferencedObject,
    fk.ReferencedColumn
FROM sys.schemas AS s
JOIN sys.tables AS t ON t.schema_id = s.schema_id
JOIN sys.columns AS c ON c.object_id = t.object_id
JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
LEFT JOIN
(
    SELECT ic.object_id, ic.column_id
    FROM sys.indexes AS i
    JOIN sys.index_columns AS ic
      ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    WHERE i.is_primary_key = 1
) AS pk ON pk.object_id = c.object_id AND pk.column_id = c.column_id
OUTER APPLY
(
    SELECT TOP (1)
        QUOTENAME(rs.name) + N'.' + QUOTENAME(rt.name) AS ReferencedObject,
        rc.name AS ReferencedColumn
    FROM sys.foreign_key_columns AS fkc
    JOIN sys.tables AS rt ON rt.object_id = fkc.referenced_object_id
    JOIN sys.schemas AS rs ON rs.schema_id = rt.schema_id
    JOIN sys.columns AS rc
      ON rc.object_id = fkc.referenced_object_id
     AND rc.column_id = fkc.referenced_column_id
    WHERE fkc.parent_object_id = c.object_id
      AND fkc.parent_column_id = c.column_id
) AS fk
WHERE s.name IN ('ctl', 'stg', 'nds', 'dds')
ORDER BY
    CASE s.name WHEN 'ctl' THEN 1 WHEN 'stg' THEN 2 WHEN 'nds' THEN 3 WHEN 'dds' THEN 4 ELSE 5 END,
    t.name,
    c.column_id;
