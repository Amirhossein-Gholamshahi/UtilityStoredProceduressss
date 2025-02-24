

CREATE OR ALTER PROCEDURE [dbo].[GenerateInsertScript] @FullTableName VARCHAR(max)
AS
DECLARE @query AS VARCHAR(max);
DECLARE @SchemaName VARCHAR(50) = PARSENAME(@FullTableName, 2) 
DECLARE @TableName VARCHAR(50) = PARSENAME(@FullTableName, 1)
CREATE TABLE ##Queries (
    Script NVARCHAR(MAX)
);
SET NOCOUNT ON
DECLARE @TableDataQuery VARCHAR(MAX) = 'SELECT ROW_NUMBER() OVER (ORDER BY ';
DECLARE @InsertQuery AS NVARCHAR(MAX) = 'INSERT INTO [' + @SchemaName + '].['+ @TableName + '](';
SET @query = 'SELECT ORDINAL_POSITION
	,COLUMN_NAME
	,IS_NULLABLE
	,DATA_TYPE
	INTO ##TableInfo
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = '
SET @query += '''' + @TableName + ''''
SET @query += ' AND TABLE_SCHEMA = '
SET @query += '''' + @SchemaName + ''''
EXEC (@query)
DECLARE @i int = 1
WHILE @i <= (SELECT COUNT(*) FROM ##TableInfo)
BEGIN
	IF @i = (SELECT COUNT(*) FROM ##TableInfo)
		BEGIN
			SET @InsertQuery += (SELECT '[' + COLUMN_NAME + ']' FROM ##TableInfo WHERE ORDINAL_POSITION = @i) + ')';
		END
	ELSE
		BEGIN
			SET @InsertQuery += (SELECT '[' + COLUMN_NAME + ']' FROM ##TableInfo WHERE ORDINAL_POSITION = @i) + ',';
		END
	SET @i = @i + 1
END
SET @TableDataQuery += (SELECT COLUMN_NAME FROM ##TableInfo WHERE ORDINAL_POSITION = 1)
SET @TableDataQuery += ') AS j,* INTO ##TableData FROM ' + @FullTableName;
EXEC (@TableDataQuery);
SET @InsertQuery += ' VALUES ('
DECLARE @j int = 1;
WHILE @j <= (SELECT COUNT(*) FROM ##TableData)
BEGIN
	DECLARE @k int = 1;
	DECLARE @InsertQueryCopy AS NVARCHAR(MAX) = @InsertQuery;
	WHILE @k <= (SELECT COUNT(*) FROM ##TableInfo)
		BEGIN
			DECLARE @ValueOut AS NVARCHAR(MAX);
			DECLARE @FormattedValue NVARCHAR(MAX)
			DECLARE @DataType AS VARCHAR(MAX) = (SELECT DATA_TYPE FROM ##TableInfo WHERE ORDINAL_POSITION = @k);
			DECLARE @ValueQuery AS NVARCHAR(MAX) = 'SET @ValueOut = (SELECT CAST(' + (SELECT COLUMN_NAME FROM ##TableInfo WHERE ORDINAL_POSITION = @k) + ' AS NVARCHAR) FROM ##TableData WHERE j = ' + CAST(@j AS VARCHAR) + ')';
			EXEC SP_EXECUTESQL @ValueQuery, N'@ValueOut NVARCHAR(MAX) OUTPUT', @ValueOut OUTPUT 
			
			IF @DataType IN ('int', 'bigint', 'smallint', 'tinyint', 'decimal', 'numeric', 'float', 'real', 'money', 'smallmoney')
				BEGIN
					SET @FormattedValue = @ValueOut;
				END
			
			ELSE IF @DataType LIKE 'varchar%' OR @DataType LIKE 'char%'
				BEGIN
					SET @FormattedValue = '''' + @ValueOut + ''''
				END
			
			ELSE IF @DataType LIKE 'nvarchar%' OR @DataType LIKE 'nchar%'
				BEGIN
					SET @FormattedValue = 'N' + '''' + @ValueOut + ''''
				END
			
			ELSE
				BEGIN
					SET @FormattedValue = '''' + @ValueOut + ''''
				END
			IF @FormattedValue is NULL
				BEGIN
					SET @FormattedValue = 'NULL'
				END
			IF @k = (SELECT COUNT(*) FROM ##TableInfo)
				BEGIN
					SET @InsertQueryCopy += @FormattedValue + ')';
				END
			ELSE
				BEGIN
					SET @InsertQueryCopy += @FormattedValue + ',';
				END 
			SET @k = @k + 1
		END
	INSERT INTO ##Queries (Script) VALUES (@InsertQueryCopy)
	SET @j = @j + 1
END

DROP TABLE ##TableInfo
DROP TABLE ##TableData

DECLARE @AllRowsScript AS NVARCHAR(MAX) = '
SET NOCOUNT ON
SET IDENTITY_INSERT '+'[' + @SchemaName + '].['+ @TableName + '] ON '

DECLARE @O AS INT = 1;

SELECT Script, ROW_NUMBER() OVER (ORDER BY SCRIPT) as i INTO ##TMPQueris FROM ##Queries 
WHILE @O <= (SELECT COUNT(*) FROM ##Queries)
	BEGIN
		SET @AllRowsScript += (SELECT Script FROM ##TMPQueris WHERE i = @O)
		SET @O += 1
	END

SET @AllRowsScript += '
 SET IDENTITY_INSERT '+'[' + @SchemaName + '].['+ @TableName + '] OFF
SET NOCOUNT OFF'

SELECT @AllRowsScript RESULT
DROP TABLE ##Queries
DROP TABLE ##TMPQueris
SET NOCOUNT OFF



