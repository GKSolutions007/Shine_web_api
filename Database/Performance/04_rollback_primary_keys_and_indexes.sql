/* =====================================================================================
   04  ROLLBACK - drops only the primary keys and indexes created by
       04_primary_keys_and_indexes.sql (matched by name). Tables go back to heaps.
       Run in a quiet period: dropping a clustered index rebuilds the table.
   ===================================================================================== */
SET NOCOUNT ON;
GO

DECLARE @items TABLE (Seq int IDENTITY(1,1), TableName sysname, ObjectName sysname, IsPK bit);
-- Non-clustered first, then PKs / clustered indexes.
INSERT @items (TableName, ObjectName, IsPK) VALUES
 (N'tblTransPurchaseHeader', N'IX_tblTransPurchaseHeader_TransID_Date', 0),
 (N'tblTransPurchaseHeader', N'IX_tblTransPurchaseHeader_VendorID', 0),
 (N'tblTransPurchaseDetail', N'IX_tblTransPurchaseDetail_ProdID', 0),
 (N'tblTransPurchaseDetail', N'IX_tblTransPurchaseDetail_InventoryId', 0),
 (N'tblPurchaseOrderHeader', N'IX_tblPurchaseOrderHeader_TransID_DocDate', 0),
 (N'tblTranCollectionHeader', N'IX_tblTranCollectionHeader_DocPrefix_ColDate', 0),
 (N'tblTranCollectionHeader', N'IX_tblTranCollectionHeader_AccID', 0),
 (N'tblTranCollectionDetail', N'IX_tblTranCollectionDetail_DocPrefix_DocValue', 0),
 (N'tblTranPaymentHeader', N'IX_tblTranPaymentHeader_PYPrefix_PYDate', 0),
 (N'tblTranPaymentHeader', N'IX_tblTranPaymentHeader_AccID', 0),
 (N'tblTranPaymentDetail', N'IX_tblTranPaymentDetail_DocPrefix_DocValue', 0),
 (N'tblProductInventory', N'IX_tblProductInventory_ProdID_BranchID', 0),
 (N'tblProductInventory', N'IX_tblProductInventory_TransID_DocValue', 0),
 (N'tblInventoryHeader', N'IX_tblInventoryHeader_TransID_InventoryDate', 0),
 (N'tblFAJournal', N'IX_tblFAJournal_AccountID_DocDate', 0),
 (N'tblFAJournal', N'IX_tblFAJournal_DocPrefix_DocValue', 0),
 (N'tblFAJournal', N'IX_tblFAJournal_JVID', 0),
 (N'tblNoteDetails', N'IX_tblNoteDetails_TransID_DocDate', 0),
 (N'tblTranPRVoucher', N'IX_tblTranPRVoucher_TransID_DocDate', 0),
 (N'tblFAAccount', N'IX_tblFAAccount_AccountGroup', 0),
 (N'tblQuotationHeader', N'IX_tblQuotationHeader_DocDate', 0),
 (N'tblMasterCustomer', N'IX_tblMasterCustomer_FAID', 0),
 (N'tblMasterCustomer', N'IX_tblMasterCustomer_Name', 0),
 (N'tblMasterVendor', N'IX_tblMasterVendor_FAID', 0),
 (N'tblMasterVendor', N'IX_tblMasterVendor_Name', 0),
 (N'tblMasterProduct', N'IX_tblMasterProduct_MfrID', 0),
 (N'tblMasterSalesman', N'IX_tblMasterSalesman_FAID', 0),
 (N'tblBeatSalesmanMapping', N'IX_tblBeatSalesmanMapping_CustomerID', 0),
 (N'tblBeatSalesmanMapping', N'IX_tblBeatSalesmanMapping_BeatID_SalesmanID', 0),
 (N'tblMasterTaxDetail', N'IX_tblMasterTaxDetail_TaxID_TaxTypeID', 0),
 (N'tblMasterBankAccount', N'IX_tblMasterBankAccount_FAID', 0),
 -- non-clustered PKs on detail tables
 (N'tblTranCollectionDetail', N'PK_tblTranCollectionDetail', 1),
 (N'tblTranPaymentDetail', N'PK_tblTranPaymentDetail', 1),
 -- clustered indexes on detail tables
 (N'tblTransPurchaseDetail', N'CX_tblTransPurchaseDetail_HID', 0),
 (N'tblPurchaseOrderDetail', N'CX_tblPurchaseOrderDetail_HID', 0),
 (N'tblPurchaseDraftDetail', N'CX_tblPurchaseDraftDetail_HID', 0),
 (N'tblTranCollectionDetail', N'CX_tblTranCollectionDetail_ColID', 0),
 (N'tblCollPMDetails', N'CX_tblCollPMDetails_ColID', 0),
 (N'tblTranPaymentDetail', N'CX_tblTranPaymentDetail_PYID', 0),
 (N'tblInventoryDetail', N'CX_tblInventoryDetail_InventoryID', 0),
 (N'tblQuotationDetail', N'CX_tblQuotationDetail_QuationID', 0),
 (N'tblYearwiseDocumentSeries', N'CX_tblYearwiseDocumentSeries_TransID_BranchID_FromDate', 0),
 -- primary keys
 (N'tblTransPurchaseHeader', N'PK_tblTransPurchaseHeader', 1),
 (N'tblPurchaseOrderHeader', N'PK_tblPurchaseOrderHeader', 1),
 (N'tblPurchaseDraftHeader', N'PK_tblPurchaseDraftHeader', 1),
 (N'tblTranCollectionHeader', N'PK_tblTranCollectionHeader', 1),
 (N'tblTranPaymentHeader', N'PK_tblTranPaymentHeader', 1),
 (N'tblProductInventory', N'PK_tblProductInventory', 1),
 (N'tblInventoryHeader', N'PK_tblInventoryHeader', 1),
 (N'tblFAJournal', N'PK_tblFAJournal', 1),
 (N'tblNoteDetails', N'PK_tblNoteDetails', 1),
 (N'tblTranPRVoucher', N'PK_tblTranPRVoucher', 1),
 (N'tblFAAccount', N'PK_tblFAAccount', 1),
 (N'tblQuotationHeader', N'PK_tblQuotationHeader', 1),
 (N'tblMasterCustomer', N'PK_tblMasterCustomer', 1),
 (N'tblMasterVendor', N'PK_tblMasterVendor', 1),
 (N'tblMasterProduct', N'PK_tblMasterProduct', 1),
 (N'tblMasterSalesman', N'PK_tblMasterSalesman', 1),
 (N'tblMasterBeat', N'PK_tblMasterBeat', 1),
 (N'tblBeatSalesmanMapping', N'PK_tblBeatSalesmanMapping', 1),
 (N'tblMasterBranchOffice', N'PK_tblMasterBranchOffice', 1),
 (N'tblMasterUOM', N'PK_tblMasterUOM', 1),
 (N'tblMasterTax', N'PK_tblMasterTax', 1),
 (N'tblMasterTaxDetail', N'PK_tblMasterTaxDetail', 1),
 (N'tblMasterBankAccount', N'PK_tblMasterBankAccount', 1),
 (N'tblMasterUserDefineNoHeader', N'PK_tblMasterUserDefineNoHeader', 1),
 (N'tblUsers', N'PK_tblUsers', 1);

DECLARE @i int = 1, @n int = (SELECT COUNT(*) FROM @items), @t sysname, @o sysname, @pk bit, @sql nvarchar(max);
WHILE @i <= @n
BEGIN
    SELECT @t = TableName, @o = ObjectName, @pk = IsPK FROM @items WHERE Seq = @i;
    IF @pk = 1 AND EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = @o AND parent_object_id = OBJECT_ID(N'dbo.' + QUOTENAME(@t)))
        SET @sql = N'ALTER TABLE dbo.' + QUOTENAME(@t) + N' DROP CONSTRAINT ' + QUOTENAME(@o) + N';';
    ELSE IF @pk = 0 AND EXISTS (SELECT 1 FROM sys.indexes WHERE name = @o AND object_id = OBJECT_ID(N'dbo.' + QUOTENAME(@t)))
        SET @sql = N'DROP INDEX ' + QUOTENAME(@o) + N' ON dbo.' + QUOTENAME(@t) + N';';
    ELSE
        SET @sql = NULL;
    IF @sql IS NOT NULL
    BEGIN
        EXEC sys.sp_executesql @sql;
        PRINT N'Dropped ' + @o;
    END
    SET @i += 1;
END
GO
