/* =====================================================================================
   11_Hygiene_Report.sql  -  P3: worklist for SELECT *, UNION and NVARCHAR(MAX) (read-only)
   -------------------------------------------------------------------------------------
   Nothing is changed. Run it on a database (ideally a copy of production, the data checks read
   every (MAX) column once) and use the three lists as a worklist: fix an item when you are in
   that procedure / table for another reason, test it, and ship it with that change.

   How to fix each kind, safely:
   1. SELECT *  ->  explicit column list.
      Keep the SAME columns in the SAME order as SELECT * returns today (the API often reads
      results by position, e.g. Rows[0][3]). Script the column list from sys.columns / sys.dm_exec_
      describe_first_result_set and paste it. Harmless and left alone: EXISTS (SELECT * ...),
      SELECT * FROM STRING_SPLIT(...) / dbo.fnSplitString(...).
   2. UNION  ->  UNION ALL  only where both parts can never return the same row (different
      document types, different literal "Type" columns, ...). UNION removes duplicates with a sort;
      if a report relies on that, keep UNION.
   3. NVARCHAR(MAX)  ->  a sized type. A (MAX) column cannot be an index key, is read from
      separate pages when long, and gives the optimizer a 4,000-byte guess per value (memory grants).
      The list shows the longest value stored today and a suggested size (at least twice that,
      rounded up to 100 / 255 / 500 / 1000 / 2000 / 4000). For text users type (remarks, narration,
      addresses) use the length the screen allows, not today's data. Before changing a column also check the screen / API that writes it allows no
      more than the new size, the TVP types and procedure parameters that feed it, and that the
      ALTER runs in a maintenance window (it rewrites the table). Columns that really hold large
      text or files (images, JSON, tokens, HTML) are marked "keep MAX".
   Already done in P1/P2 where procedures were rewritten (token, OTP, mobile login procedures).
   ===================================================================================== */
SET NOCOUNT ON;
DECLARE @ScanData bit = 1;   -- 0 = skip reading the data of (MAX) columns (faster, no lengths)

/* ---------- 1 + 2. procedures / functions / views ---------- */
IF OBJECT_ID(N'tempdb..#m') IS NOT NULL DROP TABLE #m;
SELECT o.object_id, SCHEMA_NAME(o.schema_id) + N'.' + o.name AS module_name, o.type_desc,
       -- upper case, comments kept, whitespace collapsed to single spaces
       UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(m.definition, NCHAR(9), N' '), NCHAR(13), N' '), NCHAR(10), N' '),
             N' ', N' ' + NCHAR(7)), NCHAR(7) + N' ', N''), NCHAR(7), N'')) AS d
INTO #m
FROM sys.sql_modules m JOIN sys.objects o ON o.object_id = m.object_id
WHERE o.is_ms_shipped = 0 AND m.definition IS NOT NULL;

-- occurrences of a text in d (no regex in T-SQL: LEN arithmetic)
SELECT module_name, type_desc,
       n.select_star - n.harmless AS select_star_to_review,
       n.select_star_into AS of_which_into_temp_table,
       n.harmless AS harmless_exists_or_split,
       n.unions - n.union_all AS union_without_all,
       n.union_all
FROM #m
CROSS APPLY (SELECT
    (LEN(d) - LEN(REPLACE(d, N'SELECT *', N''))) / 8
      + (LEN(d) - LEN(REPLACE(d, N'SELECT DISTINCT *', N''))) / 17 AS select_star,
    (LEN(d) - LEN(REPLACE(d, N'SELECT * INTO', N''))) / 13 AS select_star_into,
    (LEN(d) - LEN(REPLACE(d, N'EXISTS (SELECT *', N''))) / 16 + (LEN(d) - LEN(REPLACE(d, N'EXISTS(SELECT *', N''))) / 15
      + (LEN(d) - LEN(REPLACE(d, N'SELECT * FROM STRING_SPLIT', N''))) / 26
      + (LEN(d) - LEN(REPLACE(d, N'SELECT * FROM DBO.FNSPLITSTRING', N''))) / 31
      + (LEN(d) - LEN(REPLACE(d, N'SELECT * FROM FNSPLITSTRING', N''))) / 27
      + (LEN(d) - LEN(REPLACE(d, N'SELECT * FROM [DBO].[FNSPLITSTRING]', N''))) / 35 AS harmless,
    (LEN(d) - LEN(REPLACE(d, N' UNION ', N''))) / 7 AS unions,
    (LEN(d) - LEN(REPLACE(d, N' UNION ALL ', N''))) / 11 AS union_all) n
WHERE n.select_star - n.harmless > 0 OR n.unions - n.union_all > 0
ORDER BY select_star_to_review DESC, union_without_all DESC, module_name;

SELECT COUNT(*) AS modules, SUM(CASE WHEN n.s > 0 THEN 1 ELSE 0 END) AS with_select_star_to_review, SUM(n.s) AS select_star_to_review,
       SUM(CASE WHEN n.u > 0 THEN 1 ELSE 0 END) AS with_union_without_all, SUM(n.u) AS union_without_all
FROM #m
CROSS APPLY (SELECT
    (LEN(d) - LEN(REPLACE(d, N'SELECT *', N''))) / 8
      - (LEN(d) - LEN(REPLACE(d, N'EXISTS (SELECT *', N''))) / 16 - (LEN(d) - LEN(REPLACE(d, N'EXISTS(SELECT *', N''))) / 15
      - (LEN(d) - LEN(REPLACE(d, N'SELECT * FROM STRING_SPLIT', N''))) / 26
      - (LEN(d) - LEN(REPLACE(d, N'SELECT * FROM DBO.FNSPLITSTRING', N''))) / 31
      - (LEN(d) - LEN(REPLACE(d, N'SELECT * FROM FNSPLITSTRING', N''))) / 27
      - (LEN(d) - LEN(REPLACE(d, N'SELECT * FROM [DBO].[FNSPLITSTRING]', N''))) / 35 AS s,
    (LEN(d) - LEN(REPLACE(d, N' UNION ', N''))) / 7 - (LEN(d) - LEN(REPLACE(d, N' UNION ALL ', N''))) / 11 AS u) n;

/* ---------- 3. (MAX) columns ---------- */
IF OBJECT_ID(N'tempdb..#c') IS NOT NULL DROP TABLE #c;
CREATE TABLE #c (table_name sysname, column_name sysname, type_name sysname, is_nullable bit, rows_ bigint,
                 max_chars bigint NULL, avg_chars decimal(18,1) NULL, has_dependents bit, note nvarchar(200) NULL);
INSERT #c (table_name, column_name, type_name, is_nullable, rows_, has_dependents)
SELECT SCHEMA_NAME(t.schema_id) + N'.' + t.name, c.name, TYPE_NAME(c.user_type_id), c.is_nullable,
       (SELECT SUM(p.rows) FROM sys.partitions p WHERE p.object_id = t.object_id AND p.index_id IN (0, 1)),
       CASE WHEN EXISTS (SELECT 1 FROM sys.computed_columns cc WHERE cc.object_id = t.object_id
                         AND CHARINDEX(QUOTENAME(c.name), cc.definition) > 0)
              OR EXISTS (SELECT 1 FROM sys.index_columns ic WHERE ic.object_id = t.object_id AND ic.column_id = c.column_id)
              OR EXISTS (SELECT 1 FROM sys.sql_expression_dependencies d JOIN sys.objects v ON v.object_id = d.referencing_id AND v.type = 'V'
                         WHERE d.referenced_id = t.object_id)
            THEN 1 ELSE 0 END
FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id
WHERE t.is_ms_shipped = 0 AND c.max_length = -1 AND TYPE_NAME(c.user_type_id) IN (N'nvarchar', N'varchar', N'varbinary');

IF @ScanData = 1
BEGIN
    DECLARE @t sysname, @col sysname, @sql nvarchar(max), @mx bigint, @av decimal(18,1);
    DECLARE cc CURSOR LOCAL FAST_FORWARD FOR SELECT table_name, column_name FROM #c;
    OPEN cc; FETCH NEXT FROM cc INTO @t, @col;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @sql = N'SELECT @mx = MAX(LEN(' + QUOTENAME(@col) + N')), @av = AVG(CAST(LEN(' + QUOTENAME(@col) + N') AS decimal(18,1))) FROM '
                 + QUOTENAME(PARSENAME(@t, 2)) + N'.' + QUOTENAME(PARSENAME(@t, 1)) + N' WITH (NOLOCK);';   -- estimate only: NOLOCK avoids blocking the app
        BEGIN TRY
            EXEC sys.sp_executesql @sql, N'@mx bigint OUTPUT, @av decimal(18,1) OUTPUT', @mx = @mx OUTPUT, @av = @av OUTPUT;
            UPDATE #c SET max_chars = @mx, avg_chars = @av WHERE table_name = @t AND column_name = @col;
        END TRY
        BEGIN CATCH
            UPDATE #c SET note = LEFT(ERROR_MESSAGE(), 200) WHERE table_name = @t AND column_name = @col;
        END CATCH
        FETCH NEXT FROM cc INTO @t, @col;
    END
    CLOSE cc; DEALLOCATE cc;
END

SELECT table_name, column_name, type_name + N'(max)' AS current_type, rows_, max_chars, avg_chars,
       CASE WHEN type_name = N'varbinary'
              OR column_name LIKE N'%Img%' OR column_name LIKE N'%Image%' OR column_name LIKE N'%Photo%' OR column_name LIKE N'%Json%'
              OR column_name LIKE N'%Token%' OR column_name LIKE N'%Html%' OR column_name LIKE N'%Base64%' OR column_name LIKE N'%Signature%'
              OR column_name LIKE N'%Definition%' OR column_name LIKE N'%Xml%' OR column_name LIKE N'%Query%'
              OR max_chars > 2000
            THEN N'keep MAX'
            WHEN max_chars IS NULL AND @ScanData = 1 THEN N'empty column: decide from the screen that fills it'
            WHEN max_chars IS NULL THEN N'(not scanned)'
            ELSE type_name + N'(' + CAST((SELECT MIN(v) FROM (VALUES (100), (255), (500), (1000), (2000), (4000)) s(v) WHERE v >= max_chars * 2) AS nvarchar(10)) + N')'
       END AS suggestion,
       CASE WHEN has_dependents = 1 THEN N'index / computed column / view uses it: change those first' ELSE N'' END AS dependents,
       note
FROM #c
ORDER BY CASE WHEN max_chars IS NULL THEN 1 ELSE 0 END, rows_ DESC, table_name, column_name;
GO
