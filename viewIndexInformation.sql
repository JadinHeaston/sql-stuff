DECLARE @DatabaseName NVARCHAR(MAX) = '';
SELECT i.[name],
    s.[index_type_desc],
    o.[name],
    s.[avg_fragmentation_in_percent],
    o.[type_desc],
    (CAST(s.page_count as float) * CAST(8 as float)) / CAST(1000 as float) as index_size_mb,
    CASE
        WHEN s.[avg_fragmentation_in_percent] > 10
        AND s.[avg_fragmentation_in_percent] < 30 THEN 'REORGANIZE'
        WHEN s.[avg_fragmentation_in_percent] > 30 THEN 'REBUILD'
        ELSE NULL
    END as remediation
FROM sys.[dm_db_index_physical_stats] (DB_ID(@DatabaseName), NULL, NULL, NULL, NULL) AS s
    INNER JOIN sys.[indexes] AS i ON s.[object_id] = i.[object_id]
    AND s.[index_id] = i.[index_id]
    INNER JOIN sys.[objects] AS o ON i.[object_id] = o.[object_id]
WHERE (
        i.[Name] like '%IX%'
        OR i.[Name] like '%PK%'
    )
ORDER BY [avg_fragmentation_in_percent] Desc;