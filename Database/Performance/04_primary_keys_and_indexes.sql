/* =====================================================================================
   04  Primary keys and core indexes (point 7)

   WHY
     118 of 150 tables are heaps (no clustered index, no primary key). Purchase, collection,
     payment, inventory, journal, note and master tables have no index at all, so every list
     filter, ledger, stock lookup and join scans the whole table. Only the sales tables are
     indexed today.

   WHAT THIS DOES (per table)
     Header / master tables : clustered PRIMARY KEY on the IDENTITY column.
     Detail tables          : clustered index on the parent key (HID, ColID, PYID, ...) so a
                              document's lines are stored together, plus a non-clustered PK on
                              the detail IDENTITY column where one exists.
     Lookup paths           : non-clustered indexes for the filters/joins the procedures use
                              (date range per document type, party/account, product+branch).

   SAFETY
     - Every step checks first and is skipped (with a message) if the table/column is missing,
       the index/PK already exists, the table already has a clustered index, or the key column
       has DUPLICATE or NULL values. Nothing is dropped. Re-runnable.
     - Uses ONLINE = ON on editions that support it (Enterprise/Developer/Azure). On Standard /
       Express each build locks its table while it runs: run in a quiet period.
     - Take a full backup first. Run on the test database, then production.
     - Results are listed at the end. Any "SKIPPED: duplicates" line needs a data clean-up
       before that table can get its key (query to find them is printed with the message).

   UNDO: 04_rollback_primary_keys_and_indexes.sql
   ===================================================================================== */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('tempdb..#IndexLog') IS NOT NULL DROP TABLE #IndexLog;
CREATE TABLE #IndexLog (Seq int IDENTITY(1,1), TableName sysname, ObjectName sysname, Result nvarchar(400));
GO

/* ---- helper: clustered/non-clustered PRIMARY KEY on one column ---------------------------- */
IF OBJECT_ID('tempdb..#EnsurePrimaryKey') IS NOT NULL DROP PROCEDURE #EnsurePrimaryKey;
GO
CREATE PROCEDURE #EnsurePrimaryKey
    @Table sysname, @Column sysname, @Clustered bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @obj int = OBJECT_ID(N'dbo.' + QUOTENAME(@Table), N'U');
    DECLARE @name sysname = N'PK_' + @Table;
    DECLARE @sql nvarchar(max), @bad bigint, @online nvarchar(20);

    IF @obj IS NULL
    BEGIN INSERT #IndexLog VALUES (@Table, @name, N'SKIPPED: table not found'); RETURN; END
    IF COL_LENGTH(N'dbo.' + QUOTENAME(@Table), @Column) IS NULL
    BEGIN INSERT #IndexLog VALUES (@Table, @name, N'SKIPPED: column ' + @Column + N' not found'); RETURN; END
    IF EXISTS (SELECT 1 FROM sys.key_constraints WHERE parent_object_id = @obj AND type = 'PK')
    BEGIN INSERT #IndexLog VALUES (@Table, @name, N'SKIPPED: table already has a primary key'); RETURN; END
    IF @Clustered = 1 AND EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = @obj AND type = 1)
        SET @Clustered = 0;   -- keep the existing clustered index; add the PK as non-clustered

    -- duplicates or NULLs would make ADD PRIMARY KEY fail: check first
    SET @sql = N'SELECT @bad = (SELECT COUNT(*) FROM (SELECT ' + QUOTENAME(@Column) + N' FROM dbo.' + QUOTENAME(@Table) +
               N' GROUP BY ' + QUOTENAME(@Column) + N' HAVING COUNT(*) > 1) d) + (SELECT COUNT(*) FROM dbo.' + QUOTENAME(@Table) +
               N' WHERE ' + QUOTENAME(@Column) + N' IS NULL);';
    EXEC sys.sp_executesql @sql, N'@bad bigint OUTPUT', @bad = @bad OUTPUT;
    IF @bad > 0
    BEGIN
        INSERT #IndexLog VALUES (@Table, @name, N'SKIPPED: duplicates/NULLs in ' + @Column + N'. Find them: SELECT ' + @Column +
               N', COUNT(*) FROM dbo.' + @Table + N' GROUP BY ' + @Column + N' HAVING COUNT(*) > 1');
        RETURN;
    END

    SET @online = CASE WHEN CAST(SERVERPROPERTY('EngineEdition') AS int) IN (3, 5, 8) THEN N'ON' ELSE N'OFF' END;
    SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@Table) + N' ADD CONSTRAINT ' + QUOTENAME(@name) + N' PRIMARY KEY ' +
               CASE WHEN @Clustered = 1 THEN N'CLUSTERED' ELSE N'NONCLUSTERED' END +
               N' (' + QUOTENAME(@Column) + N') WITH (ONLINE = ' + @online + N', SORT_IN_TEMPDB = ON);';
    BEGIN TRY
        EXEC sys.sp_executesql @sql;
        INSERT #IndexLog VALUES (@Table, @name, N'CREATED: PRIMARY KEY ' + CASE WHEN @Clustered = 1 THEN N'CLUSTERED' ELSE N'NONCLUSTERED' END + N' (' + @Column + N')');
    END TRY
    BEGIN CATCH
        INSERT #IndexLog VALUES (@Table, @name, N'FAILED: ' + ERROR_MESSAGE());
    END CATCH
END
GO

/* ---- helper: clustered or non-clustered index ---------------------------------------------- */
IF OBJECT_ID('tempdb..#EnsureIndex') IS NOT NULL DROP PROCEDURE #EnsureIndex;
GO
CREATE PROCEDURE #EnsureIndex
    @Table sysname, @Name sysname, @Keys nvarchar(400), @Include nvarchar(800) = NULL, @Clustered bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @obj int = OBJECT_ID(N'dbo.' + QUOTENAME(@Table), N'U');
    DECLARE @sql nvarchar(max), @keyList nvarchar(max), @incList nvarchar(max), @missing nvarchar(400), @online nvarchar(20);

    IF @obj IS NULL
    BEGIN INSERT #IndexLog VALUES (@Table, @Name, N'SKIPPED: table not found'); RETURN; END
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = @obj AND name = @Name)
    BEGIN INSERT #IndexLog VALUES (@Table, @Name, N'SKIPPED: already exists'); RETURN; END
    IF @Clustered = 1 AND EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = @obj AND type = 1)
    BEGIN INSERT #IndexLog VALUES (@Table, @Name, N'SKIPPED: table already has a clustered index'); RETURN; END

    -- every key/include column must exist (column lists come from this script, not from users)
    SELECT @missing = STRING_AGG(LTRIM(RTRIM(s.value)), N', ')
    FROM STRING_SPLIT(@Keys + ISNULL(N',' + @Include, N''), N',') s
    WHERE LTRIM(RTRIM(s.value)) <> N'' AND COL_LENGTH(N'dbo.' + QUOTENAME(@Table), LTRIM(RTRIM(s.value))) IS NULL;
    IF @missing IS NOT NULL
    BEGIN INSERT #IndexLog VALUES (@Table, @Name, N'SKIPPED: column(s) not found: ' + @missing); RETURN; END

    SELECT @keyList = STRING_AGG(QUOTENAME(LTRIM(RTRIM(s.value))), N', ') WITHIN GROUP (ORDER BY s.ordinal)
    FROM STRING_SPLIT(@Keys, N',', 1) s;

    -- skip if another index already has exactly the same key columns in the same order
    IF EXISTS (
        SELECT 1 FROM sys.indexes i
        WHERE i.object_id = @obj AND i.type IN (1, 2)
          AND (SELECT STRING_AGG(QUOTENAME(c.name), N', ') WITHIN GROUP (ORDER BY ic.key_ordinal)
               FROM sys.index_columns ic JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
               WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.key_ordinal > 0) = @keyList)
    BEGIN INSERT #IndexLog VALUES (@Table, @Name, N'SKIPPED: an index with the same keys exists'); RETURN; END

    IF @Include IS NOT NULL AND @Clustered = 0
        SELECT @incList = STRING_AGG(QUOTENAME(LTRIM(RTRIM(s.value))), N', ')
        FROM STRING_SPLIT(@Include, N',') s WHERE LTRIM(RTRIM(s.value)) <> N'';

    SET @online = CASE WHEN CAST(SERVERPROPERTY('EngineEdition') AS int) IN (3, 5, 8) THEN N'ON' ELSE N'OFF' END;
    SET @sql = N'CREATE ' + CASE WHEN @Clustered = 1 THEN N'CLUSTERED' ELSE N'NONCLUSTERED' END + N' INDEX ' + QUOTENAME(@Name) +
               N' ON dbo.' + QUOTENAME(@Table) + N' (' + @keyList + N')' +
               ISNULL(N' INCLUDE (' + @incList + N')', N'') +
               N' WITH (ONLINE = ' + @online + N', SORT_IN_TEMPDB = ON);';
    BEGIN TRY
        EXEC sys.sp_executesql @sql;
        INSERT #IndexLog VALUES (@Table, @Name, N'CREATED: ' + CASE WHEN @Clustered = 1 THEN N'CLUSTERED' ELSE N'NONCLUSTERED' END + N' (' + @Keys + N')');
    END TRY
    BEGIN CATCH
        INSERT #IndexLog VALUES (@Table, @Name, N'FAILED: ' + ERROR_MESSAGE());
    END CATCH
END
GO

/* =====================================================================================
   PURCHASE
   ===================================================================================== */
EXEC #EnsurePrimaryKey N'tblTransPurchaseHeader', N'ID';
EXEC #EnsureIndex N'tblTransPurchaseHeader', N'IX_tblTransPurchaseHeader_TransID_Date', N'TransID,Date', N'BranchID,VendorID,Status,DocValue';
EXEC #EnsureIndex N'tblTransPurchaseHeader', N'IX_tblTransPurchaseHeader_VendorID', N'VendorID', N'Status,Balance';
EXEC #EnsureIndex N'tblTransPurchaseDetail', N'CX_tblTransPurchaseDetail_HID', N'HID', NULL, 1;
EXEC #EnsureIndex N'tblTransPurchaseDetail', N'IX_tblTransPurchaseDetail_ProdID', N'ProdID';
EXEC #EnsureIndex N'tblTransPurchaseDetail', N'IX_tblTransPurchaseDetail_InventoryId', N'InventoryId';

EXEC #EnsurePrimaryKey N'tblPurchaseOrderHeader', N'ID';
EXEC #EnsureIndex N'tblPurchaseOrderHeader', N'IX_tblPurchaseOrderHeader_TransID_DocDate', N'TransID,DocDate', N'BranchID,VendorID,Status';
EXEC #EnsureIndex N'tblPurchaseOrderDetail', N'CX_tblPurchaseOrderDetail_HID', N'HID', NULL, 1;

EXEC #EnsurePrimaryKey N'tblPurchaseDraftHeader', N'ID';
EXEC #EnsureIndex N'tblPurchaseDraftDetail', N'CX_tblPurchaseDraftDetail_HID', N'HID', NULL, 1;
GO

/* =====================================================================================
   COLLECTION / PAYMENT
   ===================================================================================== */
EXEC #EnsurePrimaryKey N'tblTranCollectionHeader', N'ColID';
EXEC #EnsureIndex N'tblTranCollectionHeader', N'IX_tblTranCollectionHeader_DocPrefix_ColDate', N'DocPrefix,ColDate', N'Status,BranchID,AccID,ColAmt';
EXEC #EnsureIndex N'tblTranCollectionHeader', N'IX_tblTranCollectionHeader_AccID', N'AccID', N'Status,Balance';
EXEC #EnsureIndex N'tblTranCollectionDetail', N'CX_tblTranCollectionDetail_ColID', N'ColID', NULL, 1;
EXEC #EnsurePrimaryKey N'tblTranCollectionDetail', N'ColDetailID', 0;
EXEC #EnsureIndex N'tblTranCollectionDetail', N'IX_tblTranCollectionDetail_DocPrefix_DocValue', N'DocPrefix,DocValue';
EXEC #EnsureIndex N'tblCollPMDetails', N'CX_tblCollPMDetails_ColID', N'ColID', NULL, 1;

EXEC #EnsurePrimaryKey N'tblTranPaymentHeader', N'PYID';
EXEC #EnsureIndex N'tblTranPaymentHeader', N'IX_tblTranPaymentHeader_PYPrefix_PYDate', N'PYPrefix,PYDate', N'Status,BranchID,AccID,PYAmt';
EXEC #EnsureIndex N'tblTranPaymentHeader', N'IX_tblTranPaymentHeader_AccID', N'AccID', N'Status,Balance';
EXEC #EnsureIndex N'tblTranPaymentDetail', N'CX_tblTranPaymentDetail_PYID', N'PYID', NULL, 1;
EXEC #EnsurePrimaryKey N'tblTranPaymentDetail', N'PYDetailID', 0;
EXEC #EnsureIndex N'tblTranPaymentDetail', N'IX_tblTranPaymentDetail_DocPrefix_DocValue', N'DocPrefix,DocValue';
GO

/* =====================================================================================
   INVENTORY
   ===================================================================================== */
EXEC #EnsurePrimaryKey N'tblProductInventory', N'InventoryId';
EXEC #EnsureIndex N'tblProductInventory', N'IX_tblProductInventory_ProdID_BranchID', N'ProdID,BranchID',
     N'BatchNumber,PKDDate,ExpiryDate,MRPONPrice,ActualQty,ActualFreeQty,ActualDmgQty,TransDate';
EXEC #EnsureIndex N'tblProductInventory', N'IX_tblProductInventory_TransID_DocValue', N'TransID,DocValue';

EXEC #EnsurePrimaryKey N'tblInventoryHeader', N'InventoryID';
EXEC #EnsureIndex N'tblInventoryHeader', N'IX_tblInventoryHeader_TransID_InventoryDate', N'TransID,InventoryDate', N'BranchID,Status';
EXEC #EnsureIndex N'tblInventoryDetail', N'CX_tblInventoryDetail_InventoryID', N'InventoryID', NULL, 1;
GO

/* =====================================================================================
   ACCOUNTS (journal, notes, vouchers)
   ===================================================================================== */
EXEC #EnsurePrimaryKey N'tblFAJournal', N'NoteID';
EXEC #EnsureIndex N'tblFAJournal', N'IX_tblFAJournal_AccountID_DocDate', N'AccountID,DocDate', N'Debit,Credit,Status,BranchID';
EXEC #EnsureIndex N'tblFAJournal', N'IX_tblFAJournal_DocPrefix_DocValue', N'DocPrefix,DocValue', N'AccountID,Status';
EXEC #EnsureIndex N'tblFAJournal', N'IX_tblFAJournal_JVID', N'JVID';

EXEC #EnsurePrimaryKey N'tblNoteDetails', N'ID';
EXEC #EnsureIndex N'tblNoteDetails', N'IX_tblNoteDetails_TransID_DocDate', N'TransID,DocDate', N'PartyID,FAID,Status';

EXEC #EnsurePrimaryKey N'tblTranPRVoucher', N'ID';
EXEC #EnsureIndex N'tblTranPRVoucher', N'IX_tblTranPRVoucher_TransID_DocDate', N'TransID,DocDate', N'PartyID,FAID';

EXEC #EnsurePrimaryKey N'tblFAAccount', N'FAID';
EXEC #EnsureIndex N'tblFAAccount', N'IX_tblFAAccount_AccountGroup', N'AccountGroup';
GO

/* =====================================================================================
   QUOTATION
   ===================================================================================== */
EXEC #EnsurePrimaryKey N'tblQuotationHeader', N'ID';
EXEC #EnsureIndex N'tblQuotationHeader', N'IX_tblQuotationHeader_DocDate', N'DocDate', N'BranchID,CustomerID,Status';
EXEC #EnsureIndex N'tblQuotationDetail', N'CX_tblQuotationDetail_QuationID', N'QuationID', NULL, 1;
GO

/* =====================================================================================
   MASTERS AND USERS
   ===================================================================================== */
EXEC #EnsurePrimaryKey N'tblMasterCustomer', N'ID';
EXEC #EnsureIndex N'tblMasterCustomer', N'IX_tblMasterCustomer_FAID', N'FAID';
EXEC #EnsureIndex N'tblMasterCustomer', N'IX_tblMasterCustomer_Name', N'Name';

EXEC #EnsurePrimaryKey N'tblMasterVendor', N'ID';
EXEC #EnsureIndex N'tblMasterVendor', N'IX_tblMasterVendor_FAID', N'FAID';
EXEC #EnsureIndex N'tblMasterVendor', N'IX_tblMasterVendor_Name', N'Name';

EXEC #EnsurePrimaryKey N'tblMasterProduct', N'ID';
EXEC #EnsureIndex N'tblMasterProduct', N'IX_tblMasterProduct_MfrID', N'MfrID', N'BrandID,CategoryID,Active';

EXEC #EnsurePrimaryKey N'tblMasterSalesman', N'ID';
EXEC #EnsureIndex N'tblMasterSalesman', N'IX_tblMasterSalesman_FAID', N'FAID';
EXEC #EnsurePrimaryKey N'tblMasterBeat', N'ID';
EXEC #EnsurePrimaryKey N'tblBeatSalesmanMapping', N'ID';
EXEC #EnsureIndex N'tblBeatSalesmanMapping', N'IX_tblBeatSalesmanMapping_CustomerID', N'CustomerID', N'BeatID,SalesmanID';
EXEC #EnsureIndex N'tblBeatSalesmanMapping', N'IX_tblBeatSalesmanMapping_BeatID_SalesmanID', N'BeatID,SalesmanID', N'CustomerID';

EXEC #EnsurePrimaryKey N'tblMasterBranchOffice', N'ID';
EXEC #EnsurePrimaryKey N'tblMasterUOM', N'ID';
EXEC #EnsurePrimaryKey N'tblMasterTax', N'TaxID';
EXEC #EnsurePrimaryKey N'tblMasterTaxDetail', N'TaxDetialID';
EXEC #EnsureIndex N'tblMasterTaxDetail', N'IX_tblMasterTaxDetail_TaxID_TaxTypeID', N'TaxID,TaxTypeID', N'TaxCompID,TaxRate,GSTTaxType';
EXEC #EnsurePrimaryKey N'tblMasterBankAccount', N'ID';
EXEC #EnsureIndex N'tblMasterBankAccount', N'IX_tblMasterBankAccount_FAID', N'FAID';
EXEC #EnsurePrimaryKey N'tblMasterUserDefineNoHeader', N'UDNID';
EXEC #EnsureIndex N'tblYearwiseDocumentSeries', N'CX_tblYearwiseDocumentSeries_TransID_BranchID_FromDate', N'TransID,BranchID,FromDate', NULL, 1;

EXEC #EnsurePrimaryKey N'tblUsers', N'ID';
GO

/* =====================================================================================
   RESULT
   ===================================================================================== */
SELECT TableName, ObjectName, Result FROM #IndexLog ORDER BY Seq;

-- Remaining heaps after this script (largest first), for the next round:
SELECT t.name AS heap_table, SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.indexes i ON i.object_id = t.object_id AND i.type = 0
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id = 0
GROUP BY t.name
ORDER BY row_count DESC;

DROP PROCEDURE #EnsureIndex;
DROP PROCEDURE #EnsurePrimaryKey;
DROP TABLE #IndexLog;
GO
