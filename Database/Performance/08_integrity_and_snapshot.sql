/* =====================================================================================
   08  Foreign keys, column types and READ_COMMITTED_SNAPSHOT (point 12)
   Run AFTER 04 (primary keys) and 07 (procedure locking hints), in a quiet window.
   Take a full backup first. Test database first, then production.

   WHAT IT DOES
     1. Primary keys on the parent tables 04 did not cover (van loading slip, delivery order,
        assign invoices, manufacturer, brand, category, role) and indexes on their detail keys.
     2. Foreign keys, created WITH CHECK, only where every existing row already points to a real
        parent. Anything with orphan rows is SKIPPED and the query to find those rows is listed.
          - Header -> detail links (sales, purchase, PO, draft, collection, payment, inventory,
            quotation, van loading, delivery, assign invoices).
          - Required master links (NOT NULL columns): customer, branch, product, vendor, account, tax.
          - Draft lines use ON DELETE CASCADE: the draft screens delete the header before its lines.
          - Optional links (beat, salesman, brand, role, ...) are REPORTED only. The API sends 0 for
            "none" in those columns (BL_nValidation), so a foreign key would reject those saves.
            Set @IncludeOptional = 1 in section 2 only after those columns use NULL instead of 0.
     3. NVARCHAR(MAX) -> sized NVARCHAR on short lookup columns (user name, product code/name,
        master names), so they can be indexed (the login lookup searches tblUsers.UserName).
        A column is changed only if every current value fits; collation and NULL-ability are kept.
        Then indexes on tblUsers(UserName) and tblMasterProduct(Code), (Name).
        Other type issues (dates stored as text, ID columns typed differently across tables) are
        listed by the report at the end; they need app changes, so nothing is altered for them.
     4. READ_COMMITTED_SNAPSHOT: OFF unless you set @EnableRCSI = 1 in section 4. It refuses to
        switch on unless 07 is in place (07 makes every save keep today's locking reads and fixes
        the document-number race). Switching needs exclusive access: other sessions' open
        transactions are rolled back (WITH ROLLBACK IMMEDIATE). Watch tempdb (version store).

   SAFETY: every step checks first, logs to #Log08 and runs in its own TRY/CATCH. Re-runnable.
   UNDO:   08_rollback_integrity_and_snapshot.sql
   ===================================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('tempdb..#Log08') IS NOT NULL DROP TABLE #Log08;
CREATE TABLE #Log08 (Seq int IDENTITY(1,1), Step nvarchar(20), ObjectName sysname, Result nvarchar(1000));
GO

/* ---- helper: PRIMARY KEY on one column (same rules as 04) --------------------------------- */
IF OBJECT_ID('tempdb..#EnsurePrimaryKey08') IS NOT NULL DROP PROCEDURE #EnsurePrimaryKey08;
GO
CREATE PROCEDURE #EnsurePrimaryKey08
    @Table sysname, @Column sysname
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @obj int = OBJECT_ID(N'dbo.' + QUOTENAME(@Table), N'U');
    DECLARE @name sysname = N'PK_' + @Table, @sql nvarchar(max), @bad bigint, @online nvarchar(3), @clustered bit = 1;
    IF @obj IS NULL
    BEGIN INSERT #Log08 VALUES (N'1 PK', @Table, N'SKIPPED: table not found'); RETURN; END
    IF COL_LENGTH(N'dbo.' + QUOTENAME(@Table), @Column) IS NULL
    BEGIN INSERT #Log08 VALUES (N'1 PK', @Table, N'SKIPPED: column ' + @Column + N' not found'); RETURN; END
    IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE parent_object_id = @obj AND type = 'PK')
    BEGIN INSERT #Log08 VALUES (N'1 PK', @Table, N'SKIPPED: table already has a primary key'); RETURN; END
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = @obj AND type = 1) SET @clustered = 0;

    SET @sql = N'SELECT @bad = (SELECT COUNT(*) FROM (SELECT ' + QUOTENAME(@Column) + N' FROM dbo.' + QUOTENAME(@Table) +
               N' GROUP BY ' + QUOTENAME(@Column) + N' HAVING COUNT(*) > 1) d) + (SELECT COUNT(*) FROM dbo.' + QUOTENAME(@Table) +
               N' WHERE ' + QUOTENAME(@Column) + N' IS NULL);';
    EXEC sys.sp_executesql @sql, N'@bad bigint OUTPUT', @bad = @bad OUTPUT;
    IF @bad > 0
    BEGIN
        INSERT #Log08 VALUES (N'1 PK', @Table, N'SKIPPED: duplicates/NULLs in ' + @Column + N'. Find them: SELECT ' + @Column +
               N', COUNT(*) FROM dbo.' + @Table + N' GROUP BY ' + @Column + N' HAVING COUNT(*) > 1');
        RETURN;
    END
    SET @online = CASE WHEN CAST(SERVERPROPERTY('EngineEdition') AS int) IN (3, 5, 8) THEN N'ON' ELSE N'OFF' END;
    SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@Table) + N' ADD CONSTRAINT ' + QUOTENAME(@name) + N' PRIMARY KEY ' +
               CASE WHEN @clustered = 1 THEN N'CLUSTERED' ELSE N'NONCLUSTERED' END +
               N' (' + QUOTENAME(@Column) + N') WITH (ONLINE = ' + @online + N', SORT_IN_TEMPDB = ON);';
    BEGIN TRY
        EXEC sys.sp_executesql @sql;
        INSERT #Log08 VALUES (N'1 PK', @Table, N'CREATED: PRIMARY KEY ' + CASE WHEN @clustered = 1 THEN N'CLUSTERED' ELSE N'NONCLUSTERED' END + N' (' + @Column + N')');
    END TRY
    BEGIN CATCH
        INSERT #Log08 VALUES (N'1 PK', @Table, N'FAILED: ' + ERROR_MESSAGE());
    END CATCH
END
GO

/* ---- helper: single-column index ----------------------------------------------------------- */
IF OBJECT_ID('tempdb..#EnsureIndex08') IS NOT NULL DROP PROCEDURE #EnsureIndex08;
GO
CREATE PROCEDURE #EnsureIndex08
    @Table sysname, @Name sysname, @Column sysname, @Clustered bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @obj int = OBJECT_ID(N'dbo.' + QUOTENAME(@Table), N'U'), @col int, @sql nvarchar(max), @online nvarchar(3);
    IF @obj IS NULL
    BEGIN INSERT #Log08 VALUES (N'index', @Table, N'SKIPPED: table not found'); RETURN; END
    SELECT @col = column_id FROM sys.columns WHERE object_id = @obj AND name = @Column;
    IF @col IS NULL
    BEGIN INSERT #Log08 VALUES (N'index', @Table, N'SKIPPED: column ' + @Column + N' not found'); RETURN; END
    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = @obj AND column_id = @col AND max_length = -1)
    BEGIN INSERT #Log08 VALUES (N'index', @Table, @Name + N' SKIPPED: ' + @Column + N' is still a MAX column'); RETURN; END
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = @obj AND name = @Name)
    BEGIN INSERT #Log08 VALUES (N'index', @Table, @Name + N' SKIPPED: already exists'); RETURN; END
    IF EXISTS (SELECT 1 FROM sys.index_columns ic WHERE ic.object_id = @obj AND ic.key_ordinal = 1 AND ic.column_id = @col)
    BEGIN INSERT #Log08 VALUES (N'index', @Table, @Name + N' SKIPPED: an index already leads with ' + @Column); RETURN; END
    IF @Clustered = 1 AND EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = @obj AND type = 1) SET @Clustered = 0;
    SET @online = CASE WHEN CAST(SERVERPROPERTY('EngineEdition') AS int) IN (3, 5, 8) THEN N'ON' ELSE N'OFF' END;
    SET @sql = N'CREATE ' + CASE WHEN @Clustered = 1 THEN N'CLUSTERED' ELSE N'NONCLUSTERED' END + N' INDEX ' + QUOTENAME(@Name) +
               N' ON dbo.' + QUOTENAME(@Table) + N' (' + QUOTENAME(@Column) + N') WITH (ONLINE = ' + @online + N', SORT_IN_TEMPDB = ON);';
    BEGIN TRY
        EXEC sys.sp_executesql @sql;
        INSERT #Log08 VALUES (N'index', @Table, @Name + N' CREATED (' + @Column + N')');
    END TRY
    BEGIN CATCH
        INSERT #Log08 VALUES (N'index', @Table, @Name + N' FAILED: ' + ERROR_MESSAGE());
    END CATCH
END
GO

/* ---- helper: foreign key, created only when the data already satisfies it ------------------- */
IF OBJECT_ID('tempdb..#EnsureForeignKey08') IS NOT NULL DROP PROCEDURE #EnsureForeignKey08;
GO
CREATE PROCEDURE #EnsureForeignKey08
    @Child sysname, @ChildCol sysname, @Parent sysname, @ParentCol sysname,
    @OnDelete nvarchar(20) = N'NO ACTION', @ReportOnly bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step nvarchar(20) = CASE WHEN @ReportOnly = 1 THEN N'2 FK optional' ELSE N'2 FK' END;
    DECLARE @label sysname = @Child + N'.' + @ChildCol;
    DECLARE @name sysname = N'FK_' + @Child + N'_' + @ChildCol;
    DECLARE @c int = OBJECT_ID(N'dbo.' + QUOTENAME(@Child), N'U'), @p int = OBJECT_ID(N'dbo.' + QUOTENAME(@Parent), N'U');
    DECLARE @cc int, @pc int, @sql nvarchar(max), @orphans bigint, @zeros bigint;

    IF @OnDelete NOT IN (N'NO ACTION', N'CASCADE')
    BEGIN INSERT #Log08 VALUES (@step, @label, N'SKIPPED: unsupported ON DELETE option'); RETURN; END
    IF @c IS NULL OR @p IS NULL
    BEGIN INSERT #Log08 VALUES (@step, @label, N'SKIPPED: table ' + CASE WHEN @c IS NULL THEN @Child ELSE @Parent END + N' not found'); RETURN; END
    SELECT @cc = column_id FROM sys.columns WHERE object_id = @c AND name = @ChildCol;
    SELECT @pc = column_id FROM sys.columns WHERE object_id = @p AND name = @ParentCol;
    IF @cc IS NULL OR @pc IS NULL
    BEGIN INSERT #Log08 VALUES (@step, @label, N'SKIPPED: column not found'); RETURN; END
    IF EXISTS (SELECT 1 FROM sys.foreign_key_columns WHERE parent_object_id = @c AND parent_column_id = @cc AND referenced_object_id = @p)
    BEGIN INSERT #Log08 VALUES (@step, @label, N'SKIPPED: a foreign key to ' + @Parent + N' already exists'); RETURN; END
    IF NOT EXISTS (SELECT 1 FROM sys.columns a JOIN sys.columns b ON b.object_id = @p AND b.column_id = @pc
                   WHERE a.object_id = @c AND a.column_id = @cc AND a.user_type_id = b.user_type_id
                     AND a.max_length = b.max_length AND a.precision = b.precision AND a.scale = b.scale)
    BEGIN INSERT #Log08 VALUES (@step, @label, N'SKIPPED: column type differs from ' + @Parent + N'.' + @ParentCol); RETURN; END
    IF NOT EXISTS (SELECT 1 FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
                   WHERE i.object_id = @p AND (i.is_primary_key = 1 OR i.is_unique = 1) AND i.has_filter = 0
                     AND ic.key_ordinal = 1 AND ic.column_id = @pc
                     AND (SELECT COUNT(*) FROM sys.index_columns x WHERE x.object_id = i.object_id AND x.index_id = i.index_id AND x.key_ordinal > 0) = 1)
    BEGIN INSERT #Log08 VALUES (@step, @label, N'SKIPPED: ' + @Parent + N'.' + @ParentCol + N' has no primary key / unique index (see 04 and section 1)'); RETURN; END

    SET @sql = N'SELECT @orphans = COUNT_BIG(*), @zeros = ISNULL(SUM(CASE WHEN c.' + QUOTENAME(@ChildCol) + N' = 0 THEN 1 ELSE 0 END), 0)
                 FROM dbo.' + QUOTENAME(@Child) + N' AS c
                 WHERE c.' + QUOTENAME(@ChildCol) + N' IS NOT NULL
                   AND NOT EXISTS (SELECT 1 FROM dbo.' + QUOTENAME(@Parent) + N' AS p WHERE p.' + QUOTENAME(@ParentCol) + N' = c.' + QUOTENAME(@ChildCol) + N');';
    EXEC sys.sp_executesql @sql, N'@orphans bigint OUTPUT, @zeros bigint OUTPUT', @orphans = @orphans OUTPUT, @zeros = @zeros OUTPUT;
    IF @orphans > 0
    BEGIN
        INSERT #Log08 VALUES (@step, @label, N'SKIPPED: ' + CONVERT(nvarchar(20), @orphans) + N' rows point to a missing ' + @Parent +
               CASE WHEN @zeros > 0 THEN N' (' + CONVERT(nvarchar(20), @zeros) + N' of them are 0 = "none")' ELSE N'' END +
               N'. Find them: SELECT c.* FROM dbo.' + @Child + N' c WHERE c.' + @ChildCol + N' IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.' +
               @Parent + N' p WHERE p.' + @ParentCol + N' = c.' + @ChildCol + N')');
        RETURN;
    END
    IF @ReportOnly = 1
    BEGIN INSERT #Log08 VALUES (@step, @label, N'REPORT: data is clean today; not created (optional link, see header)'); RETURN; END
    IF EXISTS (SELECT 1 FROM sys.objects WHERE name = @name)
    BEGIN INSERT #Log08 VALUES (@step, @label, N'SKIPPED: an object named ' + @name + N' already exists'); RETURN; END

    SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@Child) + N' WITH CHECK ADD CONSTRAINT ' + QUOTENAME(@name) +
               N' FOREIGN KEY (' + QUOTENAME(@ChildCol) + N') REFERENCES dbo.' + QUOTENAME(@Parent) + N' (' + QUOTENAME(@ParentCol) + N')' +
               N' ON DELETE ' + @OnDelete + N';';
    BEGIN TRY
        EXEC sys.sp_executesql @sql;
        INSERT #Log08 VALUES (@step, @label, N'CREATED: ' + @name + N' -> ' + @Parent + N'.' + @ParentCol +
               CASE WHEN @OnDelete = N'CASCADE' THEN N' (ON DELETE CASCADE)' ELSE N'' END);
    END TRY
    BEGIN CATCH
        INSERT #Log08 VALUES (@step, @label, N'FAILED: ' + ERROR_MESSAGE());
    END CATCH
END
GO

/* ---- helper: NVARCHAR(MAX) -> NVARCHAR(n) when every value fits ------------------------------ */
IF OBJECT_ID('tempdb..#NarrowMaxColumn08') IS NOT NULL DROP PROCEDURE #NarrowMaxColumn08;
GO
CREATE PROCEDURE #NarrowMaxColumn08
    @Table sysname, @Column sysname, @Length int
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @obj int = OBJECT_ID(N'dbo.' + QUOTENAME(@Table), N'U'), @col int, @nullable bit, @collation sysname,
            @type sysname, @maxlen int, @sql nvarchar(max), @longest bigint, @stats nvarchar(max);
    DECLARE @label sysname = @Table + N'.' + @Column;
    IF @obj IS NULL
    BEGIN INSERT #Log08 VALUES (N'3 type', @label, N'SKIPPED: table not found'); RETURN; END
    SELECT @col = c.column_id, @nullable = c.is_nullable, @collation = c.collation_name, @type = t.name, @maxlen = c.max_length
    FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
    WHERE c.object_id = @obj AND c.name = @Column;
    IF @col IS NULL
    BEGIN INSERT #Log08 VALUES (N'3 type', @label, N'SKIPPED: column not found'); RETURN; END
    IF @type <> N'nvarchar' OR @maxlen <> -1
    BEGIN INSERT #Log08 VALUES (N'3 type', @label, N'SKIPPED: not NVARCHAR(MAX) (already ' + @type + CASE WHEN @maxlen = -1 THEN N'(max)' ELSE N'(' + CONVERT(nvarchar(10), @maxlen / 2) + N')' END + N')'); RETURN; END
    IF EXISTS (SELECT 1 FROM sys.index_columns WHERE object_id = @obj AND column_id = @col)
       OR EXISTS (SELECT 1 FROM sys.default_constraints WHERE parent_object_id = @obj AND parent_column_id = @col)
       OR EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = @obj AND (parent_column_id = @col OR definition LIKE N'%' + @Column + N'%'))
       OR EXISTS (SELECT 1 FROM sys.computed_columns WHERE object_id = @obj AND definition LIKE N'%' + @Column + N'%')
       OR EXISTS (SELECT 1 FROM sys.stats s JOIN sys.stats_columns sc ON sc.object_id = s.object_id AND sc.stats_id = s.stats_id
                  WHERE s.object_id = @obj AND sc.column_id = @col AND s.auto_created = 0 AND s.user_created = 1)
       OR EXISTS (SELECT 1 FROM sys.sql_expression_dependencies WHERE referenced_id = @obj AND referenced_minor_id = @col AND is_schema_bound_reference = 1)
    BEGIN INSERT #Log08 VALUES (N'3 type', @label, N'SKIPPED: an index, constraint, statistics or schema-bound object uses this column'); RETURN; END

    SET @sql = N'SELECT @longest = ISNULL(MAX(DATALENGTH(' + QUOTENAME(@Column) + N')) / 2, 0) FROM dbo.' + QUOTENAME(@Table) + N';';
    EXEC sys.sp_executesql @sql, N'@longest bigint OUTPUT', @longest = @longest OUTPUT;
    IF @longest > @Length
    BEGIN INSERT #Log08 VALUES (N'3 type', @label, N'SKIPPED: longest value is ' + CONVERT(nvarchar(20), @longest) + N' characters (limit ' + CONVERT(nvarchar(10), @Length) + N')'); RETURN; END

    -- auto-created statistics on the column would block ALTER COLUMN; SQL Server re-creates them
    SELECT @stats = STRING_AGG(CONVERT(nvarchar(max), N'DROP STATISTICS dbo.' + QUOTENAME(@Table) + N'.' + QUOTENAME(s.name) + N';'), N' ')
    FROM sys.stats s JOIN sys.stats_columns sc ON sc.object_id = s.object_id AND sc.stats_id = s.stats_id
    WHERE s.object_id = @obj AND sc.column_id = @col AND s.auto_created = 1;

    SET @sql = ISNULL(@stats, N'') + N' ALTER TABLE dbo.' + QUOTENAME(@Table) + N' ALTER COLUMN ' + QUOTENAME(@Column) +
               N' NVARCHAR(' + CONVERT(nvarchar(10), @Length) + N')' + ISNULL(N' COLLATE ' + @collation, N'') +
               CASE WHEN @nullable = 1 THEN N' NULL' ELSE N' NOT NULL' END + N';';
    BEGIN TRY
        EXEC sys.sp_executesql @sql;
        INSERT #Log08 VALUES (N'3 type', @label, N'CHANGED: NVARCHAR(MAX) -> NVARCHAR(' + CONVERT(nvarchar(10), @Length) + N'), longest value ' + CONVERT(nvarchar(20), @longest));
    END TRY
    BEGIN CATCH
        INSERT #Log08 VALUES (N'3 type', @label, N'FAILED: ' + ERROR_MESSAGE());
    END CATCH
END
GO

/* =====================================================================================
   1. Primary keys on the remaining parent tables, and indexes on their detail keys
   ===================================================================================== */
EXEC #EnsurePrimaryKey08 N'tblVanLoadingSlipHeader', N'ID';
EXEC #EnsurePrimaryKey08 N'tblDeliveryOrderHeader',  N'ID';
EXEC #EnsurePrimaryKey08 N'tblAssignInvoicesHeader', N'ID';
EXEC #EnsurePrimaryKey08 N'tblMasterManufacturer',   N'ID';
EXEC #EnsurePrimaryKey08 N'tblMasterBrand',          N'ID';
EXEC #EnsurePrimaryKey08 N'tblMasterCategory',       N'ID';
EXEC #EnsurePrimaryKey08 N'tblMasterRole',           N'ID';
EXEC #EnsureIndex08 N'tblDeliveryOrderDetail',  N'CX_tblDeliveryOrderDetail_DOID',  N'DOID', 1;
EXEC #EnsureIndex08 N'tblAssignInvoicesDetail', N'CX_tblAssignInvoicesDetail_HID',  N'HID',  1;
EXEC #EnsureIndex08 N'tblPaymentPMDetail',      N'CX_tblPaymentPMDetail_PYID',      N'PYID', 1;
EXEC #EnsureIndex08 N'tblVanLoadingSlipDetail', N'IX_tblVanLoadingSlipDetail_ID',   N'ID';
GO

/* =====================================================================================
   2. Foreign keys
   ===================================================================================== */
-- header -> detail
EXEC #EnsureForeignKey08 N'tblTranSalesDetail',      N'InvId',       N'tblTranSalesHeader',      N'ID';
EXEC #EnsureForeignKey08 N'tblTransPurchaseDetail',  N'HID',         N'tblTransPurchaseHeader',  N'ID';
EXEC #EnsureForeignKey08 N'tblPurchaseOrderDetail',  N'HID',         N'tblPurchaseOrderHeader',  N'ID';
EXEC #EnsureForeignKey08 N'tblPurchaseDraftDetail',  N'HID',         N'tblPurchaseDraftHeader',  N'ID', N'CASCADE';
EXEC #EnsureForeignKey08 N'tblTranCollectionDetail', N'ColID',       N'tblTranCollectionHeader', N'ColID';
EXEC #EnsureForeignKey08 N'tblCollPMDetails',        N'ColID',       N'tblTranCollectionHeader', N'ColID';
EXEC #EnsureForeignKey08 N'tblTranPaymentDetail',    N'PYID',        N'tblTranPaymentHeader',    N'PYID';
EXEC #EnsureForeignKey08 N'tblPaymentPMDetail',      N'PYID',        N'tblTranPaymentHeader',    N'PYID';
EXEC #EnsureForeignKey08 N'tblInventoryDetail',      N'InventoryID', N'tblInventoryHeader',      N'InventoryID';
EXEC #EnsureForeignKey08 N'tblQuotationDetail',      N'QuationID',   N'tblQuotationHeader',      N'ID';
EXEC #EnsureForeignKey08 N'tblVanLoadingSlipDetail', N'ID',          N'tblVanLoadingSlipHeader', N'ID';
EXEC #EnsureForeignKey08 N'tblDeliveryOrderDetail',  N'DOID',        N'tblDeliveryOrderHeader',  N'ID';
EXEC #EnsureForeignKey08 N'tblAssignInvoicesDetail', N'HID',         N'tblAssignInvoicesHeader', N'ID';
-- required master links (NOT NULL columns)
EXEC #EnsureForeignKey08 N'tblTranSalesHeader',      N'CustId',      N'tblMasterCustomer',       N'ID';
EXEC #EnsureForeignKey08 N'tblTranSalesHeader',      N'BranchID',    N'tblMasterBranchOffice',   N'ID';
EXEC #EnsureForeignKey08 N'tblTranSalesDetail',      N'ProdId',      N'tblMasterProduct',        N'ID';
EXEC #EnsureForeignKey08 N'tblTransPurchaseHeader',  N'VendorID',    N'tblMasterVendor',         N'ID';
EXEC #EnsureForeignKey08 N'tblPurchaseOrderHeader',  N'VendorID',    N'tblMasterVendor',         N'ID';
EXEC #EnsureForeignKey08 N'tblProductInventory',     N'ProdID',      N'tblMasterProduct',        N'ID';
EXEC #EnsureForeignKey08 N'tblFAJournal',            N'AccountID',   N'tblFAAccount',            N'FAID';
EXEC #EnsureForeignKey08 N'tblMasterTaxDetail',      N'TaxID',       N'tblMasterTax',            N'TaxID';
EXEC #EnsureForeignKey08 N'tblInventoryHeader',      N'BranchID',    N'tblMasterBranchOffice',   N'ID';
GO
-- optional links: reported only (the API stores 0 for "none" in these). Set to 1 once they use NULL.
DECLARE @IncludeOptional bit = 0;
DECLARE @opt TABLE (Seq int IDENTITY(1,1), Child sysname, ChildCol sysname, Parent sysname, ParentCol sysname);
INSERT @opt (Child, ChildCol, Parent, ParentCol) VALUES
 (N'tblTranSalesHeader',      N'BeatID',      N'tblMasterBeat',         N'ID'),
 (N'tblTranSalesHeader',      N'SalesManId',  N'tblMasterSalesman',     N'ID'),
 (N'tblTransPurchaseHeader',  N'BranchID',    N'tblMasterBranchOffice', N'ID'),
 (N'tblTransPurchaseDetail',  N'ProdID',      N'tblMasterProduct',      N'ID'),
 (N'tblProductInventory',     N'BranchID',    N'tblMasterBranchOffice', N'ID'),
 (N'tblTranCollectionHeader', N'BranchID',    N'tblMasterBranchOffice', N'ID'),
 (N'tblTranPaymentHeader',    N'BranchID',    N'tblMasterBranchOffice', N'ID'),
 (N'tblMasterProduct',        N'MfrID',       N'tblMasterManufacturer', N'ID'),
 (N'tblMasterProduct',        N'BrandID',     N'tblMasterBrand',        N'ID'),
 (N'tblMasterProduct',        N'CategoryID',  N'tblMasterCategory',     N'ID'),
 (N'tblBeatSalesmanMapping',  N'CustomerID',  N'tblMasterCustomer',     N'ID'),
 (N'tblBeatSalesmanMapping',  N'BeatID',      N'tblMasterBeat',         N'ID'),
 (N'tblBeatSalesmanMapping',  N'SalesmanID',  N'tblMasterSalesman',     N'ID'),
 (N'tblMasterCustomer',       N'FAID',        N'tblFAAccount',          N'FAID'),
 (N'tblMasterVendor',         N'FAID',        N'tblFAAccount',          N'FAID'),
 (N'tblUsers',                N'RoleID',      N'tblMasterRole',         N'ID'),
 (N'tblRolePermissions',      N'Role',        N'tblMasterRole',         N'ID');
DECLARE @i int = 1, @n int = (SELECT COUNT(*) FROM @opt), @ch sysname, @cc sysname, @pa sysname, @pc sysname, @ro bit = CASE WHEN @IncludeOptional = 1 THEN 0 ELSE 1 END;
WHILE @i <= @n
BEGIN
    SELECT @ch = Child, @cc = ChildCol, @pa = Parent, @pc = ParentCol FROM @opt WHERE Seq = @i;
    EXEC #EnsureForeignKey08 @ch, @cc, @pa, @pc, N'NO ACTION', @ro;
    SET @i += 1;
END
GO

/* =====================================================================================
   3. Column types: sized NVARCHAR for short lookup columns, then the indexes they allow
   ===================================================================================== */
EXEC #NarrowMaxColumn08 N'tblUsers',              N'UserName',    256;
EXEC #NarrowMaxColumn08 N'tblUsers',              N'EMailID',     320;
EXEC #NarrowMaxColumn08 N'tblMasterProduct',      N'Code',        200;
EXEC #NarrowMaxColumn08 N'tblMasterProduct',      N'Name',        500;
EXEC #NarrowMaxColumn08 N'tblMasterBrand',        N'Name',        255;
EXEC #NarrowMaxColumn08 N'tblMasterCategory',     N'Name',        255;
EXEC #NarrowMaxColumn08 N'tblMasterManufacturer', N'Name',        255;
EXEC #NarrowMaxColumn08 N'tblMasterBeat',         N'Name',        255;
EXEC #NarrowMaxColumn08 N'tblMasterUOM',          N'Name',        255;
EXEC #NarrowMaxColumn08 N'tblMasterRole',         N'Name',        255;
EXEC #NarrowMaxColumn08 N'tblMasterReason',       N'Name',        255;
EXEC #NarrowMaxColumn08 N'tblMasterLocation',     N'Name',        255;
EXEC #NarrowMaxColumn08 N'tblMasterBank',         N'Name',        255;
EXEC #NarrowMaxColumn08 N'tblMasterBankAccount',  N'AccountNo',   100;
EXEC #NarrowMaxColumn08 N'tblFAAccount',          N'AccountName', 500;
EXEC #EnsureIndex08 N'tblUsers',         N'IX_tblUsers_UserName',    N'UserName';
EXEC #EnsureIndex08 N'tblMasterProduct', N'IX_tblMasterProduct_Code', N'Code';
EXEC #EnsureIndex08 N'tblMasterProduct', N'IX_tblMasterProduct_Name', N'Name';
GO

/* =====================================================================================
   4. READ_COMMITTED_SNAPSHOT (off unless @EnableRCSI = 1)
   ===================================================================================== */
DECLARE @EnableRCSI bit = 0;
DECLARE @hinted int = (SELECT COUNT(*) FROM sys.sql_modules m JOIN sys.procedures p ON p.object_id = m.object_id
                       WHERE m.definition LIKE N'%READCOMMITTEDLOCK%');
DECLARE @seriesLocked bit = CASE WHEN OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspManageSalesHeader')) LIKE N'%tblYearwiseDocumentSeries WITH (UPDLOCK)%' THEN 1 ELSE 0 END;
DECLARE @isOn bit = (SELECT is_read_committed_snapshot_on FROM sys.databases WHERE database_id = DB_ID());
IF @isOn = 1
    INSERT #Log08 VALUES (N'4 RCSI', DB_NAME(), N'ALREADY: READ_COMMITTED_SNAPSHOT is ON');
ELSE IF @EnableRCSI = 0
    INSERT #Log08 VALUES (N'4 RCSI', DB_NAME(), N'NOT CHANGED: @EnableRCSI = 0. Readiness: ' + CONVERT(nvarchar(10), @hinted) +
           N' procedures carry READCOMMITTEDLOCK (07 adds it to about 117), document-number lock ' +
           CASE WHEN @seriesLocked = 1 THEN N'in place' ELSE N'MISSING' END + N'.');
ELSE IF @hinted < 100 OR @seriesLocked = 0
    INSERT #Log08 VALUES (N'4 RCSI', DB_NAME(), N'REFUSED: run 07 first (found ' + CONVERT(nvarchar(10), @hinted) +
           N' hinted procedures, document-number lock ' + CASE WHEN @seriesLocked = 1 THEN N'in place' ELSE N'missing' END + N')');
ELSE
BEGIN
    BEGIN TRY
        EXEC sys.sp_executesql N'ALTER DATABASE CURRENT SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;';
        INSERT #Log08 VALUES (N'4 RCSI', DB_NAME(), N'CHANGED: READ_COMMITTED_SNAPSHOT is ON');
    END TRY
    BEGIN CATCH
        INSERT #Log08 VALUES (N'4 RCSI', DB_NAME(), N'FAILED: ' + ERROR_MESSAGE());
    END CATCH
END
GO

/* =====================================================================================
   Results
   ===================================================================================== */
SELECT Step, ObjectName, Result FROM #Log08 ORDER BY Seq;

-- Remaining type issues, for the app team (nothing is changed for these):
-- (a) ID columns with the same name but different types across tables (joins on them convert)
SELECT ColumnName = x.name, Types = STRING_AGG(CONVERT(nvarchar(max), t.name + N' x' + CONVERT(nvarchar(10), x.cnt)), N', ')
FROM (SELECT c.name, c.user_type_id, cnt = COUNT(*) FROM sys.columns c JOIN sys.tables tb ON tb.object_id = c.object_id
      WHERE c.name IN (N'ID', N'BranchID', N'DocPrefix', N'DocValue', N'TransID', N'TaxID', N'Status', N'CBy', N'MBy')
      GROUP BY c.name, c.user_type_id) AS x
JOIN sys.types t ON t.user_type_id = x.user_type_id
GROUP BY x.name
HAVING COUNT(*) > 1;
-- (b) dates stored as text
SELECT TableName = OBJECT_NAME(c.object_id), ColumnName = c.name, DataType = t.name + N'(' + CASE WHEN c.max_length = -1 THEN N'max' ELSE CONVERT(nvarchar(10), c.max_length / 2) END + N')'
FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id JOIN sys.tables tb ON tb.object_id = c.object_id
WHERE t.name IN (N'nvarchar', N'varchar', N'nchar', N'char') AND (c.name LIKE N'%Date' OR c.name LIKE N'Date%' OR c.name LIKE N'%Dt')
ORDER BY 1, 2;
GO
