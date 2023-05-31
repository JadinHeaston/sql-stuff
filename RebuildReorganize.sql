DECLARE @DatabaseName NVARCHAR(MAX) = '';
DECLARE @IndexName NVARCHAR(MAX);
DECLARE @TableName NVARCHAR(MAX);
DECLARE @CurrentIndexName NVARCHAR(MAX);
DECLARE @CurrentTableName NVARCHAR(MAX);
DECLARE @CurrentRemediation NVARCHAR(MAX);
DECLARE @CmdRemediate NVARCHAR(MAX);
DECLARE @CmdReorganize NVARCHAR(MAX) = 'REORGANIZE';
DECLARE @CmdRebuild NVARCHAR(MAX) = 'REBUILD PARTITION = ALL WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)';
/*
 Displaying index statistics.
 */
DECLARE @tempIndexTable TABLE (
        RowID int not null primary key identity(1, 1),
        IndexName NVARCHAR(MAX),
        IndexType NVARCHAR(MAX),
        TableName NVARCHAR(MAX),
        AvgFragmentationInPercent FLOAT,
        ObjectTypeDescription NVARCHAR(MAX),
        remediation NVARCHAR(MAX)
    );
INSERT INTO @tempIndexTable (
        IndexName,
        IndexType,
        TableName,
        AvgFragmentationInPercent,
        ObjectTypeDescription,
        remediation
    ) (
        SELECT i.[name],
            s.[index_type_desc],
            o.[name],
            s.[avg_fragmentation_in_percent],
            o.[type_desc],
            CASE
                WHEN s.[avg_fragmentation_in_percent] > 10
                AND s.[avg_fragmentation_in_percent] < 30 THEN 'REORGANIZE'
                WHEN s.[avg_fragmentation_in_percent] > 30 THEN 'REBUILD'
            END as remediation
        FROM sys.dm_db_index_physical_stats (DB_ID(@DatabaseName), NULL, NULL, NULL, NULL) AS s
            INNER JOIN sys.indexes AS i ON s.object_id = i.object_id
            AND s.index_id = i.index_id
            INNER JOIN sys.objects AS o ON i.object_id = o.object_id
        WHERE (
                s.avg_fragmentation_in_percent > 10
                and (
                    i.[Name] like '%IX%'
                    OR i.[Name] like '%PK%'
                )
            )
    );
PRINT 'Initial Indexes: ';
SELECT *
FROM @tempIndexTable
ORDER BY AvgFragmentationInPercent Desc;
/*
 Performing remediation. Uncomment the RETURN; to run this portion.
 */
RETURN;
DECLARE @totalCount INTEGER;
SELECT @totalCount = count(1)
FROM @tempIndexTable;
DECLARE @counter INTEGER = 1;
WHILE(@counter <= @totalCount) BEGIN
SET @CurrentIndexName = (
        SELECT top 1 IndexName
        FROM @tempIndexTable
        WHERE RowID = @counter
    );
SET @CurrentTableName = (
        SELECT top 1 TableName
        FROM @tempIndexTable
        WHERE RowID = @counter
    );
SET @CurrentRemediation = (
        SELECT top 1 remediation
        FROM @tempIndexTable
        WHERE RowID = @counter
    );
BEGIN TRY PRINT 'Remediation (' + @CurrentRemediation + ') starting [' + @CurrentIndexName + '] ON [dbo].[' + @CurrentTableName + '] at ' + convert(varchar, getdate(), 121);
IF @CurrentRemediation = 'REORGANIZE'
SET @CmdRemediate = 'ALTER INDEX [' + @CurrentIndexName + '] ON [dbo].[' + @CurrentTableName + '] ' + @CmdReorganize;
IF @CurrentRemediation = 'REBUILD'
SET @CmdRemediate = 'ALTER INDEX [' + @CurrentIndexName + '] ON [dbo].[' + @CurrentTableName + '] ' + @CmdRebuild;
EXEC (@CmdRemediate);
PRINT 'Remediation (' + @CurrentRemediation + ') executed [' + @CurrentIndexName + '] ON [dbo].[' + @CurrentTableName + '] at ' + convert(varchar, getdate(), 121);
END TRY BEGIN CATCH;
PRINT 'Failed to remediate (' + @CurrentRemediation + ') [' + @CurrentIndexName + '] ON [dbo].[' + @CurrentTableName + ']';
PRINT ERROR_MESSAGE();
END CATCH;
SET @counter = @counter + 1;
END;
/*
 Displaying updated index statistics.
 */
DELETE FROM @tempIndexTable
INSERT INTO @tempIndexTable (
        IndexName,
        IndexType,
        TableName,
        AvgFragmentationInPercent,
        ObjectTypeDescription,
        remediation
    ) (
        SELECT i.[name],
            s.[index_type_desc],
            o.[name],
            s.[avg_fragmentation_in_percent],
            o.[type_desc],
            CASE
                WHEN s.[avg_fragmentation_in_percent] > 10
                AND s.[avg_fragmentation_in_percent] < 30 THEN 'REORGANIZE'
                WHEN s.[avg_fragmentation_in_percent] > 30 THEN 'REBUILD'
            END as remediation
        FROM sys.dm_db_index_physical_stats (DB_ID(@DatabaseName), NULL, NULL, NULL, NULL) AS s
            INNER JOIN sys.indexes AS i ON s.object_id = i.object_id
            AND s.index_id = i.index_id
            INNER JOIN sys.objects AS o ON i.object_id = o.object_id
        WHERE (
                s.avg_fragmentation_in_percent > 10
                and (
                    i.[Name] like '%IX%'
                    OR i.[Name] like '%PK%'
                )
            )
    );
SELECT *
FROM @tempIndexTable
ORDER BY AvgFragmentationInPercent Desc;