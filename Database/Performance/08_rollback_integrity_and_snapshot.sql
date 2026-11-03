/* =====================================================================================
   08 ROLLBACK  Undoes 08_integrity_and_snapshot.sql
     1. READ_COMMITTED_SNAPSHOT OFF (if it is on; needs exclusive access, WITH ROLLBACK IMMEDIATE)
     2. Drops the foreign keys 08 creates (by their FK_<table>_<column> names)
     3. Drops the indexes 08 creates, then widens the narrowed columns back to NVARCHAR(MAX)
        (only columns that still have the exact length 08 gave them; collation/NULL kept)
     4. Drops the primary keys 08 creates (PK_<table>), unless another foreign key still uses them
   Run this before 07_rollback.
   ===================================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF OBJECT_ID('tempdb..#Log08R') IS NOT NULL DROP TABLE #Log08R;
CREATE TABLE #Log08R (Seq int IDENTITY(1,1), ObjectName sysname, Result nvarchar(1000));
GO

/* 1. READ_COMMITTED_SNAPSHOT */
IF (SELECT is_read_committed_snapshot_on FROM sys.databases WHERE database_id = DB_ID()) = 1
BEGIN
    BEGIN TRY
        EXEC sys.sp_executesql N'ALTER DATABASE CURRENT SET READ_COMMITTED_SNAPSHOT OFF WITH ROLLBACK IMMEDIATE;';
        INSERT #Log08R VALUES (DB_NAME(), N'READ_COMMITTED_SNAPSHOT set OFF');
    END TRY
    BEGIN CATCH
        INSERT #Log08R VALUES (DB_NAME(), N'FAILED to set READ_COMMITTED_SNAPSHOT OFF: ' + ERROR_MESSAGE());
    END CATCH
END
ELSE INSERT #Log08R VALUES (DB_NAME(), N'READ_COMMITTED_SNAPSHOT already OFF');
GO

/* 2. foreign keys */
DECLARE @fk TABLE (Seq int IDENTITY(1,1), TableName sysname, ColumnName sysname);
INSERT @fk (TableName, ColumnName) VALUES
 (N'tblTranSalesDetail', N'InvId'), (N'tblTransPurchaseDetail', N'HID'), (N'tblPurchaseOrderDetail', N'HID'),
 (N'tblPurchaseDraftDetail', N'HID'), (N'tblTranCollectionDetail', N'ColID'), (N'tblCollPMDetails', N'ColID'),
 (N'tblTranPaymentDetail', N'PYID'), (N'tblPaymentPMDetail', N'PYID'), (N'tblInventoryDetail', N'InventoryID'),
 (N'tblQuotationDetail', N'QuationID'), (N'tblVanLoadingSlipDetail', N'ID'), (N'tblDeliveryOrderDetail', N'DOID'),
 (N'tblAssignInvoicesDetail', N'HID'),
 (N'tblTranSalesHeader', N'CustId'), (N'tblTranSalesHeader', N'BranchID'), (N'tblTranSalesDetail', N'ProdId'),
 (N'tblTransPurchaseHeader', N'VendorID'), (N'tblPurchaseOrderHeader', N'VendorID'), (N'tblProductInventory', N'ProdID'),
 (N'tblFAJournal', N'AccountID'), (N'tblMasterTaxDetail', N'TaxID'), (N'tblInventoryHeader', N'BranchID'),
 (N'tblTranSalesHeader', N'BeatID'), (N'tblTranSalesHeader', N'SalesManId'), (N'tblTransPurchaseHeader', N'BranchID'),
 (N'tblTransPurchaseDetail', N'ProdID'), (N'tblProductInventory', N'BranchID'), (N'tblTranCollectionHeader', N'BranchID'),
 (N'tblTranPaymentHeader', N'BranchID'), (N'tblMasterProduct', N'MfrID'), (N'tblMasterProduct', N'BrandID'),
 (N'tblMasterProduct', N'CategoryID'), (N'tblBeatSalesmanMapping', N'CustomerID'), (N'tblBeatSalesmanMapping', N'BeatID'),
 (N'tblBeatSalesmanMapping', N'SalesmanID'), (N'tblMasterCustomer', N'FAID'), (N'tblMasterVendor', N'FAID'),
 (N'tblUsers', N'RoleID'), (N'tblRolePermissions', N'Role');
DECLARE @i int = 1, @n int = (SELECT COUNT(*) FROM @fk), @t sysname, @c sysname, @name sysname, @sql nvarchar(max);
WHILE @i <= @n
BEGIN
    SELECT @t = TableName, @c = ColumnName FROM @fk WHERE Seq = @i;
    SET @name = N'FK_' + @t + N'_' + @c;
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = @name AND parent_object_id = OBJECT_ID(N'dbo.' + QUOTENAME(@t)))
    BEGIN
        SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@t) + N' DROP CONSTRAINT ' + QUOTENAME(@name) + N';';
        BEGIN TRY EXEC sys.sp_executesql @sql; INSERT #Log08R VALUES (@name, N'dropped'); END TRY
        BEGIN CATCH INSERT #Log08R VALUES (@name, N'FAILED: ' + ERROR_MESSAGE()); END CATCH
    END
    SET @i += 1;
END
GO

/* 3. indexes, then column types */
DECLARE @ix TABLE (Seq int IDENTITY(1,1), TableName sysname, IndexName sysname);
INSERT @ix (TableName, IndexName) VALUES
 (N'tblUsers', N'IX_tblUsers_UserName'), (N'tblMasterProduct', N'IX_tblMasterProduct_Code'), (N'tblMasterProduct', N'IX_tblMasterProduct_Name'),
 (N'tblDeliveryOrderDetail', N'CX_tblDeliveryOrderDetail_DOID'), (N'tblAssignInvoicesDetail', N'CX_tblAssignInvoicesDetail_HID'),
 (N'tblPaymentPMDetail', N'CX_tblPaymentPMDetail_PYID'), (N'tblVanLoadingSlipDetail', N'IX_tblVanLoadingSlipDetail_ID');
DECLARE @i int = 1, @n int = (SELECT COUNT(*) FROM @ix), @t sysname, @x sysname, @sql nvarchar(max);
WHILE @i <= @n
BEGIN
    SELECT @t = TableName, @x = IndexName FROM @ix WHERE Seq = @i;
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.' + QUOTENAME(@t)) AND name = @x)
    BEGIN
        SET @sql = N'DROP INDEX ' + QUOTENAME(@x) + N' ON dbo.' + QUOTENAME(@t) + N';';
        BEGIN TRY EXEC sys.sp_executesql @sql; INSERT #Log08R VALUES (@t + N'.' + @x, N'dropped'); END TRY
        BEGIN CATCH INSERT #Log08R VALUES (@t + N'.' + @x, N'FAILED: ' + ERROR_MESSAGE()); END CATCH
    END
    SET @i += 1;
END

DECLARE @col TABLE (Seq int IDENTITY(1,1), TableName sysname, ColumnName sysname, Len int);
INSERT @col (TableName, ColumnName, Len) VALUES
 (N'tblUsers', N'UserName', 256), (N'tblUsers', N'EMailID', 320), (N'tblMasterProduct', N'Code', 200), (N'tblMasterProduct', N'Name', 500),
 (N'tblMasterBrand', N'Name', 255), (N'tblMasterCategory', N'Name', 255), (N'tblMasterManufacturer', N'Name', 255),
 (N'tblMasterBeat', N'Name', 255), (N'tblMasterUOM', N'Name', 255), (N'tblMasterRole', N'Name', 255), (N'tblMasterReason', N'Name', 255),
 (N'tblMasterLocation', N'Name', 255), (N'tblMasterBank', N'Name', 255), (N'tblMasterBankAccount', N'AccountNo', 100),
 (N'tblFAAccount', N'AccountName', 500);
DECLARE @len int, @nullable bit, @collation sysname, @stats nvarchar(max), @obj int, @cid int;
SET @i = 1; SET @n = (SELECT COUNT(*) FROM @col);
WHILE @i <= @n
BEGIN
    SELECT @t = TableName, @x = ColumnName, @len = Len FROM @col WHERE Seq = @i;
    SET @obj = OBJECT_ID(N'dbo.' + QUOTENAME(@t)); SET @cid = NULL;
    SELECT @cid = c.column_id, @nullable = c.is_nullable, @collation = c.collation_name
    FROM sys.columns c JOIN sys.types ty ON ty.user_type_id = c.user_type_id
    WHERE c.object_id = @obj AND c.name = @x AND ty.name = N'nvarchar' AND c.max_length = @len * 2;
    IF @cid IS NOT NULL
    BEGIN
        SET @stats = NULL;
        SELECT @stats = STRING_AGG(CONVERT(nvarchar(max), N'DROP STATISTICS dbo.' + QUOTENAME(@t) + N'.' + QUOTENAME(s.name) + N';'), N' ')
        FROM sys.stats s JOIN sys.stats_columns sc ON sc.object_id = s.object_id AND sc.stats_id = s.stats_id
        WHERE s.object_id = @obj AND sc.column_id = @cid AND s.auto_created = 1;
        SET @sql = ISNULL(@stats, N'') + N' ALTER TABLE dbo.' + QUOTENAME(@t) + N' ALTER COLUMN ' + QUOTENAME(@x) + N' NVARCHAR(MAX)' +
                   ISNULL(N' COLLATE ' + @collation, N'') + CASE WHEN @nullable = 1 THEN N' NULL' ELSE N' NOT NULL' END + N';';
        BEGIN TRY EXEC sys.sp_executesql @sql; INSERT #Log08R VALUES (@t + N'.' + @x, N'back to NVARCHAR(MAX)'); END TRY
        BEGIN CATCH INSERT #Log08R VALUES (@t + N'.' + @x, N'FAILED: ' + ERROR_MESSAGE()); END CATCH
    END
    SET @i += 1;
END
GO

/* 4. primary keys added by 08 */
DECLARE @pk TABLE (Seq int IDENTITY(1,1), TableName sysname);
INSERT @pk (TableName) VALUES (N'tblVanLoadingSlipHeader'), (N'tblDeliveryOrderHeader'), (N'tblAssignInvoicesHeader'),
 (N'tblMasterManufacturer'), (N'tblMasterBrand'), (N'tblMasterCategory'), (N'tblMasterRole');
DECLARE @i int = 1, @n int = (SELECT COUNT(*) FROM @pk), @t sysname, @name sysname, @sql nvarchar(max);
WHILE @i <= @n
BEGIN
    SELECT @t = TableName FROM @pk WHERE Seq = @i;
    SET @name = N'PK_' + @t;
    IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = @name AND type = 'PK' AND parent_object_id = OBJECT_ID(N'dbo.' + QUOTENAME(@t)))
    BEGIN
        IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE referenced_object_id = OBJECT_ID(N'dbo.' + QUOTENAME(@t)))
            INSERT #Log08R VALUES (@name, N'KEPT: a foreign key still references ' + @t);
        ELSE
        BEGIN
            SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@t) + N' DROP CONSTRAINT ' + QUOTENAME(@name) + N';';
            BEGIN TRY EXEC sys.sp_executesql @sql; INSERT #Log08R VALUES (@name, N'dropped'); END TRY
            BEGIN CATCH INSERT #Log08R VALUES (@name, N'FAILED: ' + ERROR_MESSAGE()); END CATCH
        END
    END
    SET @i += 1;
END
GO

SELECT ObjectName, Result FROM #Log08R ORDER BY Seq;
GO
