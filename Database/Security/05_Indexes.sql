/* =====================================================================================
   05_Indexes.sql  -  P1: clustered indexes for heap tables + indexes for the real workload
   -------------------------------------------------------------------------------------
   Run on each Shine database after 01-04, preferably outside working hours: index creation
   locks each table while it runs (online index builds need Enterprise edition). On the test
   database the whole script takes a few seconds; on large databases plan a maintenance window.
   Safe to re-run: every step checks whether it was already done.

   Evidence used (Query Store + missing-index data of WSHINE_TEST01_APR2026):
   - SELECT * FROM tblRefreshTokens WHERE AuthToken = @Token runs on EVERY authenticated API
     call (99,060 calls, 63.7 s in total). AuthToken is nvarchar(max), which cannot be indexed,
     so every call read the whole table, and the table grows with every login.
     -> persisted SHA-256 hash columns + index, used by uspGetRefreshToken / uspUpdateRefreshToken.
   - uspFAAccOpenCloseBalance sums tblFAJournal by AccountID/Status (34,455 + 9,835 calls);
     missing index AccountID+Status: 1,110 seeks, 93% estimated gain.
   - tblProductInventory by BranchID (+ProdID): stock screens and reports.
   - tblDeviceInfo by DeviceID (75,172 calls, heap).
   - 17 foreign keys had no index on their column; detail tables were heaps.

   1. Every heap gets a clustered index:
      - identity column that is unique and NOT NULL -> PRIMARY KEY CLUSTERED on it
        (UNIQUE CLUSTERED index if the table already has a nonclustered primary key)
      - detail tables -> clustered index on the header column (e.g. HID), NOT unique,
        so the application can insert exactly what it inserts today
      - other tables with an ID column -> non-unique clustered index on ID
      Nothing becomes unique unless it is an identity column that is unique today.
   2. Nonclustered indexes listed in section 2.
   Result sets do not change. Queries without ORDER BY may return rows in a different order
   than before (as they always could); the clustered keys follow insertion order where possible.
   Rollback: DROP INDEX / ALTER TABLE ... DROP CONSTRAINT for the names created here
   (all start with PK_p1_, CX_p1_, UX_p1_ or IX_p1_).
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

/* ---------- 0. session token lookup (biggest single cost) ---------- */
IF COL_LENGTH(N'dbo.tblRefreshTokens', N'AuthTokenHash') IS NULL
    ALTER TABLE dbo.tblRefreshTokens ADD AuthTokenHash AS CAST(HASHBYTES('SHA2_256', AuthToken) AS binary(32)) PERSISTED;
IF COL_LENGTH(N'dbo.tblRefreshTokens', N'TokenHash') IS NULL
    ALTER TABLE dbo.tblRefreshTokens ADD TokenHash AS CAST(HASHBYTES('SHA2_256', Token) AS binary(32)) PERSISTED;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_p1_tblRefreshTokens_AuthTokenHash')
    CREATE INDEX IX_p1_tblRefreshTokens_AuthTokenHash ON dbo.tblRefreshTokens (AuthTokenHash);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_p1_tblRefreshTokens_TokenHash')
    CREATE INDEX IX_p1_tblRefreshTokens_TokenHash ON dbo.tblRefreshTokens (TokenHash);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_p1_tblRefreshTokens_UserId_IsRevoked')
    CREATE INDEX IX_p1_tblRefreshTokens_UserId_IsRevoked ON dbo.tblRefreshTokens (UserId, IsRevoked);
GO
-- Same parameters and result columns as before (the hash columns are not returned).
CREATE OR ALTER PROCEDURE [dbo].[uspGetRefreshToken]
@TokenType int,@Token VARCHAR(MAX)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @h binary(32) = CAST(HASHBYTES('SHA2_256', CAST(@Token AS nvarchar(max))) AS binary(32));
 if(@TokenType = 1)
 begin
 SELECT Id, UserId, Token, ExpiresAt, IsRevoked, CreatedAt, SessionID, AuthToken, AuthTokenExpireAt
 FROM tblRefreshTokens WHERE TokenHash = @h AND Token = @Token
 end
 else
 begin
 SELECT Id, UserId, Token, ExpiresAt, IsRevoked, CreatedAt, SessionID, AuthToken, AuthTokenExpireAt
 FROM tblRefreshTokens WHERE AuthTokenHash = @h AND AuthToken = @Token
 end
END
GO
CREATE OR ALTER PROCEDURE [dbo].[uspUpdateRefreshToken]
@TokenType int,@Token VARCHAR(MAX)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @h binary(32) = CAST(HASHBYTES('SHA2_256', CAST(@Token AS nvarchar(max))) AS binary(32));
 if(@TokenType = 1)
 begin
 UPDATE tblRefreshTokens SET IsRevoked = 0 WHERE TokenHash = @h AND Token = @Token
 end
 else
 begin
 UPDATE tblRefreshTokens SET IsRevoked = 0 WHERE AuthTokenHash = @h AND AuthToken = @Token
 end
END
GO

/* ---------- 1. clustered indexes for heap tables ---------- */
SET NOCOUNT ON;
DECLARE @plan TABLE (tbl sysname PRIMARY KEY, keycols nvarchar(400) NOT NULL, kind varchar(10) NOT NULL, pkcol sysname NULL);
-- detail / mapping tables: clustered on the column they are read by (not unique)
INSERT @plan (tbl, keycols, kind) VALUES
 (N'tblTransPurchaseDetail', N'HID', 'CX'), (N'tblPurchaseOrderDetail', N'HID', 'CX'),
 (N'tblPurchaseDraftDetail', N'HID', 'CX'), (N'tblSalesDraftDetail', N'HID', 'CX'),
 (N'tblQuotationDetail', N'QuationID', 'CX'), (N'tblInventoryDetail', N'InventoryID', 'CX'),
 (N'tblCollPMDetails', N'ColID', 'CX'), (N'tblTransAutomaticIndentDetail', N'HID', 'CX'),
 (N'tblMasterChequeBookDetail', N'ChequeBookID', 'CX'), (N'tblTranOrderCollectionDetail', N'HID', 'CX'),
 (N'tblTranOrderReturnDetail', N'ID', 'CX'), (N'tblTranOrderTakenDetail', N'ID', 'CX'),
 (N'tblBarcodePrintDetail', N'HID', 'CX'), (N'tblMasterDiscountSchemeCustomers', N'ID', 'CX'),
 (N'tblRolePermissions', N'Role, PermissionFormId', 'CX'), (N'tblProductLocationMapping', N'ProductID, BranchID', 'CX'),
 (N'tblBranchMapping', N'RoleID, BranchID', 'CX'), (N'tblMobileDevicePermission', N'UserID, DeviceIdent', 'CX'),
 (N'tblManufacturerMapping', N'UserID, MfrID', 'CX'), (N'tblMasterCustomerRemarks', N'CustomerID', 'CX'),
 (N'tblMasterUserDefineNoDetail', N'UDNID', 'CX'), (N'tblFAType', N'FATypeID', 'CX'), (N'tblAccountType', N'TypeID', 'CX');
-- detail tables with an identity: clustered on the header column + nonclustered primary key on the identity
INSERT @plan (tbl, keycols, kind, pkcol) VALUES
 (N'tblTranCollectionDetail', N'ColID', 'CX+PK', N'ColDetailID'),
 (N'tblTranPaymentDetail', N'PYID', 'CX+PK', N'PYDetailID');
-- every other heap: identity -> primary key; else ID column -> clustered on ID
INSERT @plan (tbl, keycols, kind)
SELECT t.name,
       COALESCE((SELECT c.name FROM sys.columns c WHERE c.object_id = t.object_id AND c.is_identity = 1),
                (SELECT c.name FROM sys.columns c WHERE c.object_id = t.object_id AND c.name = N'ID')),
       CASE WHEN EXISTS (SELECT 1 FROM sys.columns c WHERE c.object_id = t.object_id AND c.is_identity = 1) THEN 'PK' ELSE 'CX' END
FROM sys.tables t
WHERE t.is_ms_shipped = 0
  AND EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = t.object_id AND i.index_id = 0)
  AND NOT EXISTS (SELECT 1 FROM @plan p WHERE p.tbl = t.name)
  AND EXISTS (SELECT 1 FROM sys.columns c WHERE c.object_id = t.object_id AND (c.is_identity = 1 OR c.name = N'ID'));

DECLARE @tbl sysname, @keys nvarchar(400), @kind varchar(10), @pk sysname, @sql nvarchar(max), @ok bit, @missing int, @n int;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT tbl, keycols, kind, pkcol FROM @plan ORDER BY tbl;
OPEN c; FETCH NEXT FROM c INTO @tbl, @keys, @kind, @pk;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF OBJECT_ID(N'dbo.' + QUOTENAME(@tbl), N'U') IS NULL
       OR NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.' + QUOTENAME(@tbl)) AND index_id = 0)
    BEGIN
        FETCH NEXT FROM c INTO @tbl, @keys, @kind, @pk; CONTINUE;   -- not there, or already has a clustered index
    END
    SELECT @missing = COUNT(*) FROM STRING_SPLIT(@keys, N',') s WHERE COL_LENGTH(N'dbo.' + QUOTENAME(@tbl), LTRIM(RTRIM(s.value))) IS NULL;
    IF @missing > 0
    BEGIN
        PRINT N'skipped ' + @tbl + N': column(s) ' + @keys + N' not found';
        FETCH NEXT FROM c INTO @tbl, @keys, @kind, @pk; CONTINUE;
    END
    DECLARE @keyList nvarchar(600) = (SELECT STRING_AGG(QUOTENAME(LTRIM(RTRIM(value))), N', ') FROM STRING_SPLIT(@keys, N','));
    DECLARE @nameKeys nvarchar(200) = REPLACE(REPLACE(@keys, N' ', N''), N',', N'_');

    IF @kind = 'PK'
    BEGIN
        -- only if the identity column really is unique and NOT NULL today
        SET @sql = N'SELECT @ok = CASE WHEN COUNT(*) = COUNT(DISTINCT ' + @keyList + N') AND COUNT(*) = COUNT(' + @keyList + N') THEN 1 ELSE 0 END FROM dbo.' + QUOTENAME(@tbl);
        EXEC sys.sp_executesql @sql, N'@ok bit OUTPUT', @ok = @ok OUTPUT;
        IF @ok = 1 AND COLUMNPROPERTY(OBJECT_ID(N'dbo.' + QUOTENAME(@tbl)), @keys, 'AllowsNull') = 0
        BEGIN
            IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.' + QUOTENAME(@tbl)) AND type = 'PK')
                SET @sql = N'CREATE UNIQUE CLUSTERED INDEX ' + QUOTENAME(N'UX_p1_' + @tbl + N'_' + @nameKeys) + N' ON dbo.' + QUOTENAME(@tbl) + N' (' + @keyList + N');';
            ELSE
                SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@tbl) + N' ADD CONSTRAINT ' + QUOTENAME(N'PK_p1_' + @tbl) + N' PRIMARY KEY CLUSTERED (' + @keyList + N');';
        END
        ELSE
            SET @sql = N'CREATE CLUSTERED INDEX ' + QUOTENAME(N'CX_p1_' + @tbl + N'_' + @nameKeys) + N' ON dbo.' + QUOTENAME(@tbl) + N' (' + @keyList + N');';
    END
    ELSE
        SET @sql = N'CREATE CLUSTERED INDEX ' + QUOTENAME(N'CX_p1_' + @tbl + N'_' + @nameKeys) + N' ON dbo.' + QUOTENAME(@tbl) + N' (' + @keyList + N');';
    EXEC sys.sp_executesql @sql;
    PRINT @sql;

    IF @kind = 'CX+PK' AND COL_LENGTH(N'dbo.' + QUOTENAME(@tbl), @pk) IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.' + QUOTENAME(@tbl)) AND type = 'PK')
    BEGIN
        SET @sql = N'SELECT @ok = CASE WHEN COUNT(*) = COUNT(DISTINCT ' + QUOTENAME(@pk) + N') THEN 1 ELSE 0 END FROM dbo.' + QUOTENAME(@tbl);
        EXEC sys.sp_executesql @sql, N'@ok bit OUTPUT', @ok = @ok OUTPUT;
        IF @ok = 1 AND COLUMNPROPERTY(OBJECT_ID(N'dbo.' + QUOTENAME(@tbl)), @pk, 'AllowsNull') = 0
        BEGIN
            SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@tbl) + N' ADD CONSTRAINT ' + QUOTENAME(N'PK_p1_' + @tbl) + N' PRIMARY KEY NONCLUSTERED (' + QUOTENAME(@pk) + N');';
            EXEC sys.sp_executesql @sql;
            PRINT @sql;
        END
    END
    FETCH NEXT FROM c INTO @tbl, @keys, @kind, @pk;
END
CLOSE c; DEALLOCATE c;

SELECT @n = COUNT(*) FROM sys.tables t WHERE t.is_ms_shipped = 0 AND EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = t.object_id AND i.index_id = 0);
PRINT N'heap tables left: ' + CAST(@n AS nvarchar(10));
GO

/* ---------- 2. nonclustered indexes for the measured workload and unindexed foreign keys ---------- */
SET NOCOUNT ON;
DECLARE @ix TABLE (name sysname PRIMARY KEY, tbl sysname, keycols nvarchar(400), inc nvarchar(800) NULL);
INSERT @ix VALUES
 -- account balance (uspFAAccOpenCloseBalance and ledgers)
 (N'IX_p1_tblFAJournal_AccountID_Status', N'tblFAJournal', N'AccountID, Status', N'DocDate, BranchID, Debit, Credit'),
 (N'IX_p1_tblFAJournal_JVID',             N'tblFAJournal', N'JVID', NULL),
 (N'IX_p1_tblFAJournal_DocPrefix_DocValue', N'tblFAJournal', N'DocPrefix, DocValue, DocDate', N'BranchID'),
 -- stock by branch / product
 (N'IX_p1_tblProductInventory_BranchID_ProdID', N'tblProductInventory', N'BranchID, ProdID', N'TransDate, ActualQty, ActualFreeQty, ActualDmgQty, PurchasePrice, MRP, TaxId'),
 (N'IX_p1_tblProductInventory_ProdID_BranchID', N'tblProductInventory', N'ProdID, BranchID', N'ActualQty, ActualFreeQty, ActualDmgQty'),
 -- device check at login / on every request
 (N'IX_p1_tblDeviceInfo_DeviceID',        N'tblDeviceInfo', N'DeviceID', N'Active, UserID'),
 (N'IX_p1_tblColumnSettings_FormorReport', N'tblColumnSettings', N'FormorReport', N'FormName'),
 -- foreign keys without an index (the detail-table ones are covered by section 1)
 (N'IX_p1_tblTranSalesHeader_CustID',     N'tblTranSalesHeader', N'CustID', NULL),
 (N'IX_p1_tblTranSalesHeader_BranchID',   N'tblTranSalesHeader', N'BranchID', NULL),
 (N'IX_p1_tblTranSalesDetail_ProdID',     N'tblTranSalesDetail', N'ProdID', NULL),
 (N'IX_p1_tblTransPurchaseHeader_VendorID', N'tblTransPurchaseHeader', N'VendorID', NULL),
 (N'IX_p1_tblPurchaseOrderHeader_VendorID', N'tblPurchaseOrderHeader', N'VendorID', NULL),
 (N'IX_p1_tblInventoryHeader_BranchID',   N'tblInventoryHeader', N'BranchID', NULL),
 (N'IX_p1_tblMasterTaxDetail_TaxID',      N'tblMasterTaxDetail', N'TaxID', NULL),
 (N'IX_p1_tblTransPurchaseDetail_ProdID', N'tblTransPurchaseDetail', N'ProdID', NULL),
 -- collections / payments by account
 (N'IX_p1_tblTranCollectionHeader_AccID', N'tblTranCollectionHeader', N'AccID', NULL),
 (N'IX_p1_tblTranPaymentHeader_AccID',    N'tblTranPaymentHeader', N'AccID', NULL),
 -- modify-history screen (WHERE FormID = .. AND ID = ..)
 (N'IX_p1_tblMasterHistory_FormID_ID',    N'tblMasterHistory', N'FormID, ID', NULL),
 (N'IX_p1_tblMasterCustomerVendorHistory_FormID_ID', N'tblMasterCustomerVendorHistory', N'FormID, ID', NULL),
 (N'IX_p1_tblMasterProductHistory_FormID_ID', N'tblMasterProductHistory', N'FormID, ID', NULL);

DECLARE @name sysname, @tbl sysname, @keys nvarchar(400), @inc nvarchar(800), @sql nvarchar(max), @bad int;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT name, tbl, keycols, inc FROM @ix ORDER BY tbl, name;
OPEN c; FETCH NEXT FROM c INTO @name, @tbl, @keys, @inc;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF OBJECT_ID(N'dbo.' + QUOTENAME(@tbl), N'U') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = @name AND object_id = OBJECT_ID(N'dbo.' + QUOTENAME(@tbl)))
    BEGIN
        SELECT @bad = COUNT(*) FROM STRING_SPLIT(@keys + ISNULL(N',' + @inc, N''), N',') s
        WHERE COL_LENGTH(N'dbo.' + QUOTENAME(@tbl), LTRIM(RTRIM(s.value))) IS NULL
           OR COL_LENGTH(N'dbo.' + QUOTENAME(@tbl), LTRIM(RTRIM(s.value))) = -1 AND CHARINDEX(LTRIM(RTRIM(s.value)), @keys) > 0;
        IF @bad > 0
            PRINT N'skipped ' + @name + N': missing or non-indexable column';
        ELSE
        BEGIN
            SET @sql = N'CREATE INDEX ' + QUOTENAME(@name) + N' ON dbo.' + QUOTENAME(@tbl) + N' ('
                     + (SELECT STRING_AGG(QUOTENAME(LTRIM(RTRIM(value))), N', ') FROM STRING_SPLIT(@keys, N',')) + N')'
                     + ISNULL(N' INCLUDE (' + (SELECT STRING_AGG(QUOTENAME(LTRIM(RTRIM(value))), N', ') FROM STRING_SPLIT(@inc, N',')) + N')', N'') + N';';
            EXEC sys.sp_executesql @sql;
            PRINT @sql;
        END
    END
    FETCH NEXT FROM c INTO @name, @tbl, @keys, @inc;
END
CLOSE c; DEALLOCATE c;
GO
