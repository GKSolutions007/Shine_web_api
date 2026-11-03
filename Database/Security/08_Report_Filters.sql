/* =====================================================================================
   08_Report_Filters.sql  -  P2: let the report filters use indexes
   -------------------------------------------------------------------------------------
   Run on each Shine database after 05 (it relies on the clustered keys 05 creates) and after 07.
   Safe to re-run. Index builds lock the table while they run; the tables here are small
   (largest: tblTranSalesHeader, a few thousand rows on WSHINE_VIG001), seconds per index.

   Findings behind this script (Query Store, 30 days, WSHINE_VIG001):
   - The stock movement reports (uspMfrwise.../uspProdwiseDatewiseclosingDetail/Header with
     fnGetMfrStockMovementValues / fnGetProdStockMovementValues) are ~70% of all database time.
     They call the function once per day (or per product) and each call runs 8 queries filtered
     by document DATE + type + status. The date columns had no index, so every call scanned the
     whole sales / purchase / inventory headers.
     -> date indexes below (the filters are already plain  col BETWEEN @From AND @To  / col = @Date).
     Measured on a copy of WSHINE_VIG001 (same results before/after, warm cache):
       manufacturer date-wise detail, 61 days   ~830 ms -> ~470 ms after 05 -> ~220 ms after 08
       product date-wise detail, 61 days        ~740 ms -> ~400 ms after 05 -> ~170 ms after 08
       product date-wise header, 1 mfr, 1 month ~8 s    -> ~5 s    after 05 -> ~3 s    after 08
       (two measurement runs; logical reads 64,000 -> 22,000 -> 16,000 for the first report)
     The rest of their time is the day-by-day loop itself (one function call per day/product);
     a set-based rewrite of these reports is the next step (they differ between databases).
   - Functions around columns in WHERE: the scan of all 483 procedures found very few, and most
     of them are CAST/CONVERT(date, datetimeColumn), which SQL Server can still use an index for.
     The one that blocks an existing index is rewritten in section 2.
   - Date parameters declared as NVARCHAR: none of them is compared to an indexed column as text
     (the parameter is converted, not the column), so they do not stop index use. Changing their
     type would change what the API has to send (dd/MM/yyyy strings today) and is not done here.

   Rollback: DROP INDEX for the IX_p2_ names; for section 2 see dbo.DbaProcBackup (Script = '08').
   ===================================================================================== */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
GO

/* ---------- 1. indexes for the report date filters ---------- */
DECLARE @ix TABLE (tbl sysname, name sysname, keys nvarchar(400), incl nvarchar(400));
INSERT @ix VALUES
 (N'tblTranSalesHeader',     N'IX_p2_tblTranSalesHeader_InvDate',            N'InvDate, DocPrefix',        N'Status, TransactionType'),
 (N'tblTransPurchaseHeader', N'IX_p2_tblTransPurchaseHeader_Date',           N'[Date], TransID',           N'Status'),
 (N'tblInventoryHeader',     N'IX_p2_tblInventoryHeader_InventoryDate',      N'InventoryDate, TransID',    N'Status, ConvertionTypeId'),
 (N'tblClosingStock',        N'IX_p2_tblClosingStock_ClsDate',               N'ClsDate',                   N'ProdId, SaleQty, PurchPrice');
DECLARE @t sysname, @n sysname, @k nvarchar(400), @i nvarchar(400), @sql nvarchar(max), @missing nvarchar(400);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT tbl, name, keys, incl FROM @ix;
OPEN c; FETCH NEXT FROM c INTO @t, @n, @k, @i;
WHILE @@FETCH_STATUS = 0
BEGIN
    -- every column must exist (databases differ a little); skip the index otherwise
    SELECT @missing = STRING_AGG(LTRIM(RTRIM(REPLACE(REPLACE(s.value, N'[', N''), N']', N''))), N', ')
    FROM STRING_SPLIT(@k + N',' + @i, N',') s
    WHERE COL_LENGTH(N'dbo.' + @t, LTRIM(RTRIM(REPLACE(REPLACE(s.value, N'[', N''), N']', N'')))) IS NULL;
    IF OBJECT_ID(N'dbo.' + @t, N'U') IS NULL
        PRINT N'skipped ' + @n + N': table not found';
    ELSE IF @missing IS NOT NULL
        PRINT N'skipped ' + @n + N': column(s) not found: ' + @missing;
    ELSE IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.' + @t) AND name = @n)
        PRINT N'exists  ' + @n;
    -- tblClosingStock: only when no index already starts with ClsDate (some databases cluster on it)
    ELSE IF @t = N'tblClosingStock' AND EXISTS (
            SELECT 1 FROM sys.index_columns ic JOIN sys.columns col ON col.object_id = ic.object_id AND col.column_id = ic.column_id
            WHERE ic.object_id = OBJECT_ID(N'dbo.tblClosingStock') AND ic.key_ordinal = 1 AND col.name = N'ClsDate')
        PRINT N'skipped ' + @n + N': an index on ClsDate already exists';
    ELSE
    BEGIN
        SET @sql = N'CREATE INDEX ' + QUOTENAME(@n) + N' ON dbo.' + QUOTENAME(@t) + N' (' + @k + N') INCLUDE (' + @i + N');';
        EXEC sys.sp_executesql @sql;
        PRINT N'created ' + @n;
    END
    FETCH NEXT FROM c INTO @t, @n, @k, @i;
END
CLOSE c; DEALLOCATE c;
GO

/* ---------- 2. ISNULL(column, 0) = @param in uspGetCustomerWiseSalesFooter ----------
   ISNULL(TSH.BeAtId,0)=@BeatID AND ISNULL(TSH.SalesManId,0)=@SalesManID hides the columns from
   the existing index IX_TranSalesHeaderID (BeatID, SalesManID). Same meaning written so the index
   can be used: a NULL beat/salesman still matches @BeatID/@SalesManID = 0. */
IF OBJECT_ID(N'dbo.DbaProcBackup', N'U') IS NULL
    CREATE TABLE dbo.DbaProcBackup (
        BackupID int IDENTITY(1,1) CONSTRAINT PK_DbaProcBackup PRIMARY KEY,
        ProcName sysname NOT NULL,
        Script varchar(10) NOT NULL,
        SavedAt datetime2(0) NOT NULL CONSTRAINT DF_DbaProcBackup_SavedAt DEFAULT SYSDATETIME(),
        UsesAnsiNulls bit NULL,
        UsesQuotedIdentifier bit NULL,
        Definition nvarchar(max) NOT NULL);
GO
DECLARE @name sysname = N'uspGetCustomerWiseSalesFooter';
DECLARE @old nvarchar(400) = N'ISNULL(TSH.BeAtId,0)=@BeatID AND ISNULL(TSH.SalesManId,0)=@SalesManID';
DECLARE @new nvarchar(400) = N'(TSH.BeAtId = @BeatID OR (TSH.BeAtId IS NULL AND @BeatID = 0)) AND (TSH.SalesManId = @SalesManID OR (TSH.SalesManId IS NULL AND @SalesManID = 0)) /*p2:08*/';
DECLARE @d nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.' + @name)), @an bit, @qi bit, @cnt int, @sql nvarchar(max);
SELECT @an = uses_ansi_nulls, @qi = uses_quoted_identifier FROM sys.sql_modules WHERE object_id = OBJECT_ID(N'dbo.' + @name);
SET @cnt = (LEN(@d) - LEN(REPLACE(@d, @old, N''))) / NULLIF(LEN(@old), 0);
IF @d IS NULL
    PRINT N'skipped ' + @name + N': not found';
ELSE IF @d LIKE N'%/*p2:08*/%'
    PRINT N'exists  ' + @name + N' (already changed)';
ELSE IF ISNULL(@cnt, 0) = 0
    PRINT N'skipped ' + @name + N': text differs from the version this script was written for';
ELSE
BEGIN
    INSERT dbo.DbaProcBackup (ProcName, Script, UsesAnsiNulls, UsesQuotedIdentifier, Definition) VALUES (@name, '08', @an, @qi, @d);
    SET @d = REPLACE(@d, @old, @new);
    SET @d = STUFF(@d, PATINDEX(N'%CREATE%PROC%', @d), 6, N'ALTER');
    SET @sql = N'SET ANSI_NULLS ' + CASE WHEN @an = 1 THEN N'ON' ELSE N'OFF' END + N'; SET QUOTED_IDENTIFIER ' + CASE WHEN @qi = 1 THEN N'ON' ELSE N'OFF' END + N'; EXEC sys.sp_executesql @x;';
    EXEC sys.sp_executesql @sql, N'@x nvarchar(max)', @x = @d;
    PRINT N'changed ' + @name + N' (' + CAST(@cnt AS nvarchar(10)) + N' places)';
END
GO
