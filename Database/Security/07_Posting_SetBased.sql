/* =====================================================================================
   07_Posting_SetBased.sql  -  P2: set-based stock/collection logic in posting procedures
   -------------------------------------------------------------------------------------
   Run on each Shine database after 01-06 and BEFORE 08 and 09. Safe to re-run.

   Procedures (only the loop parts change; everything else is the existing text):
     Van loading   uspManageVanloadingSlipCancel   stock revert: 1 UPDATE instead of a loop per item
                   uspManageVanloadingSlipReturn   return to stock: set-based fast path
                   uspQtyReduceFromVanloading      FIFO stock allocation: set-based fast path
     Sales cancel  uspManageTranSalesCancel        collection cancel + stock revert: set-based
     Collections   uspCancelCollection             re-open adjusted documents: 1 UPDATE per table
                   uspManageTranSalesColl          credit-note adjustments: INSERT ... SELECT
     Purchase bill uspManageTransPurchaseBill      removed batches on modify: set-based check + reset

   Rules followed:
   - Same results as the loops: same formulas, rounding (the loops' decimal(15,4)/(25,6) variables
     are reproduced with CAST), NULL handling, line order and error messages. Verified on a copy of
     WSHINE_TEST01_APR2026 by running old and new side by side on every existing document and on
     generated edge cases (see the P2 report).
   - Where the old loop's line-by-line order could change the outcome (duplicates, gaps in serial
     numbers, unusual quantities) the procedure still runs the original loop, unchanged.
   - When validation fails, the error message (and returned ids) are the same; the loops had already
     written the lines before the failing one, the new code writes nothing. The API rolls its
     transaction back in both cases (these procedures are only called inside bl_ManageTrans or by
     a procedure that is), so the saved data is the same.
   - Known oddities of the old logic are kept on purpose (changing them changes stock figures and
     needs a business decision), e.g. free-qty van loading adds the still-needed qty to VLSFreeQty
     for every batch used; see the P2 report.

   Each procedure is only replaced when its current text is exactly the version this script was
   written for (SHA-256 check); otherwise it is skipped with a message and nothing changes.
   The old definition is saved in dbo.DbaProcBackup (Script = '07') before the change.
   Rollback of one procedure: take its Definition from dbo.DbaProcBackup, change the leading CREATE
   to ALTER and run it.
   ===================================================================================== */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO
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

/* ===================================================================================== dbo.uspManageVanloadingSlipCancel */
SET NOEXEC OFF;
GO
DECLARE @d nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspManageVanloadingSlipCancel'));
IF @d IS NULL
BEGIN PRINT N'dbo.uspManageVanloadingSlipCancel : not found - skipped'; SET NOEXEC ON; END
ELSE IF @d LIKE N'%/*p2:07%'
BEGIN PRINT N'dbo.uspManageVanloadingSlipCancel : already applied'; SET NOEXEC ON; END
ELSE IF HASHBYTES('SHA2_256', @d) <> 0xA6B25C75148AE789E4BFA28143A268019D50760E06C6741855246767D30EC753
BEGIN PRINT N'dbo.uspManageVanloadingSlipCancel : SKIPPED - this database has a different version of the procedure than the one this script was written for'; SET NOEXEC ON; END
ELSE
BEGIN
    INSERT dbo.DbaProcBackup (ProcName, Script, UsesAnsiNulls, UsesQuotedIdentifier, Definition)
    SELECT N'uspManageVanloadingSlipCancel', '07', uses_ansi_nulls, uses_quoted_identifier, definition FROM sys.sql_modules WHERE object_id = OBJECT_ID(N'dbo.uspManageVanloadingSlipCancel');
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
ALTER proc [dbo].[uspManageVanloadingSlipCancel]    
@VLSID int = 34,@Status int = 1,@UserID int = 2,@Remarks nvarchar(100) = null,@Narration nvarchar(255) = null    
as    
begin try    
DECLARE @CurrentStatus int,@VLSSaleQty decimal(15,4)    
DECLARE @ProdIDs NVARCHAR(MAX) = '0';    
    
select @CurrentStatus = Status from tblVanLoadingSlipHeader WHERE ID = @VLSID    
IF((@Status != @CurrentStatus) or @CurrentStatus in (2,4))    
BEGIN    
RAISERROR('This document status already changed',16,1,0);    
END    
    
SELECT @VLSSaleQty = (ISNULL(SUM(VD.VLSMQty),0) + ISNULL(SUM(VD.VLSRetrunQty),0)) FROM tblVanLoadingSlipHeader VH    
JOIN tblVanLoadingSlipDetail VD ON VD.ID = VH.ID    
WHERE VH.ID = @VLSID    
IF(@VLSSaleQty > 0)    
BEGIN    
set @ProdIDs =(SELECT  STRING_AGG(CAST(VD.ProdID AS VARCHAR(20)), ',') AS ProdIDs FROM tblVanLoadingSlipHeader VH    
JOIN tblVanLoadingSlipDetail VD ON VD.ID = VH.ID    
WHERE VH.ID = @VLSID and ISNULL(VD.VLSMQty,0) > 0)    
RAISERROR('This invoice cannot be cancelled because one or more items in the Loading Slip have already been sold/return.',16,1,@ProdIDs);    
END    
    
/*p2:07 set-based: one UPDATE for all items instead of one per item. Same rules as the old loop:
  qty = UomQty / UomCF rounded to 4 decimals per item, items of the same batch are added up,
  a NULL qty makes the stock NULL (as ActualQty + NULL did), UomCF = 0 still raises divide by zero.*/
UPDATE PI SET ActualQty = PI.ActualQty + V.ActQty, VLSQty = PI.VLSQty - V.ActQty
FROM tblProductInventory PI
JOIN (SELECT VD.ProdID, VD.InventoryID,
             CASE WHEN COUNT(*) = COUNT(CAST(VD.UomQty / VD.UomCF AS decimal(15,4)))
                  THEN SUM(CAST(VD.UomQty / VD.UomCF AS decimal(15,4))) END AS ActQty
      FROM tblVanLoadingSlipHeader VH
      JOIN tblVanLoadingSlipDetail VD ON VD.ID = VH.ID
      WHERE VH.ID = @VLSID
      GROUP BY VD.ProdID, VD.InventoryID) V ON PI.ProdID = V.ProdID AND PI.InventoryId = V.InventoryID    
    
update tblVanLoadingSlipHeader set Status = 4,ClBy = @UserID,ClDate = GETDATE(),Remarks = @Remarks,Narration = @Narration    
WHERE ID = @VLSID    
SELECT @VLSID    
    
end try    
begin catch    
select ERROR_MESSAGE(),ERROR_LINE(),ERROR_PROCEDURE(),@ProdIDs ErrorIds    
end catch

GO
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspManageVanloadingSlipCancel')) LIKE N'%/*p2:07%' PRINT N'dbo.uspManageVanloadingSlipCancel : changed';
GO
SET NOEXEC OFF;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
/* ===================================================================================== dbo.uspManageVanloadingSlipReturn */
SET NOEXEC OFF;
GO
DECLARE @d nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspManageVanloadingSlipReturn'));
IF @d IS NULL
BEGIN PRINT N'dbo.uspManageVanloadingSlipReturn : not found - skipped'; SET NOEXEC ON; END
ELSE IF @d LIKE N'%/*p2:07%'
BEGIN PRINT N'dbo.uspManageVanloadingSlipReturn : already applied'; SET NOEXEC ON; END
ELSE IF HASHBYTES('SHA2_256', @d) <> 0xA111118801753A17ED065F43C9D0B2B949258566ABBF15D769FE09310C9C9E21
BEGIN PRINT N'dbo.uspManageVanloadingSlipReturn : SKIPPED - this database has a different version of the procedure than the one this script was written for'; SET NOEXEC ON; END
ELSE
BEGIN
    INSERT dbo.DbaProcBackup (ProcName, Script, UsesAnsiNulls, UsesQuotedIdentifier, Definition)
    SELECT N'uspManageVanloadingSlipReturn', '07', uses_ansi_nulls, uses_quoted_identifier, definition FROM sys.sql_modules WHERE object_id = OBJECT_ID(N'dbo.uspManageVanloadingSlipReturn');
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
--uspManageVanloadingSlipReturn  
ALTER PROC [dbo].[uspManageVanloadingSlipReturn]  
@BranchID int = 4,@SalesmanID int = 17,@SpotSalePriceMode int = 2 ,@UserID int = 2,  
@tvpVLSItemdetails dbo.tvpVLSItemdetails READONLY  
AS  
BEGIN TRY  
--INSERT INTO @tvpVLSItemdetails([Index],ProdID,AvailableQty,UOMPrice,MRP)  
--VALUES (1,622,5.0000,12.0000,20.0000)--,(2,318,15.0000,49.1600,65.0000);  
-- Verify  
--SELECT * FROM @tvpVLSItemdetails;  
----  
declare @tvpCount INT, @tvpIndex INT,@TempSerial int  
DECLARE @InsertIdent INT SET @InsertIdent=1;  
DECLARE @InvAdjId INT,@InvAdjQty DECIMAL(25, 4),@InvAdjVLSID INT  
SET @tvpCount =(SELECT COUNT(*) FROM @tvpVLSItemdetails)  
SET @tvpIndex =1  
SET @TempSerial=1  
DECLARE @IdentID INT,@ProdID INT,@AvailableQty DECIMAL(15,4),@AdjustQty DECIMAL(15,4),@UOMPrice DECIMAL(15,4),  
@MRP DECIMAL(15,4),@SaleUomCRate DECIMAL(15,4) = 1,@TaxPercentage DECIMAL(15,4),@BaseUomPrice decimal(15,4);  
declare @TaxID smallint,@UOMID smallint  
/*p2:07 set-based fast path. Same result as the loop below: every open loading-slip line of this
  branch/salesman with the product and MRP (and price in mode 1) and a remaining qty gets its whole
  remaining qty returned (VLSRetrunQty) and put back into stock, unless the line's AvailableQty is 0.
  The loop below is still used for inputs where its line-by-line order could matter: [Index] not
  1..N, the same product twice, or two slip lines with the same slip + batch.*/
IF (SELECT COUNT(*) FROM @tvpVLSItemdetails)
     = (SELECT COUNT(DISTINCT [Index]) FROM @tvpVLSItemdetails WHERE [Index] BETWEEN 1 AND (SELECT COUNT(*) FROM @tvpVLSItemdetails))
   AND (SELECT COUNT(*) FROM @tvpVLSItemdetails) = (SELECT COUNT(DISTINCT ProdID) FROM @tvpVLSItemdetails)
   AND NOT EXISTS (SELECT 1
                   FROM (SELECT VD.ID, VD.InventoryID FROM tblVanLoadingSlipHeader VH JOIN tblVanLoadingSlipDetail VD ON VD.ID = VH.ID
                         WHERE VH.Status NOT IN (2,4) AND VH.BranchID = @BranchID AND VH.SalesmanID = @SalesmanID
                         GROUP BY VD.ID, VD.InventoryID HAVING COUNT(*) > 1) dup
                   WHERE EXISTS (SELECT 1 FROM tblVanLoadingSlipDetail V2 JOIN @tvpVLSItemdetails T ON T.ProdID = V2.ProdID
                                 WHERE V2.ID = dup.ID AND (V2.InventoryID = dup.InventoryID OR (V2.InventoryID IS NULL AND dup.InventoryID IS NULL))))
BEGIN
    DECLARE @p2_g TABLE (ID int, InventoryID int, Qty decimal(15,4));
    INSERT @p2_g (ID, InventoryID, Qty)
    SELECT VD.ID, VD.InventoryID, SUM(VD.UomQty - (ISNULL(VD.VLSMQtY,0) + ISNULL(VD.VLSRetrunQty,0)))
    FROM @tvpVLSItemdetails T
    JOIN tblVanLoadingSlipDetail VD ON VD.ProdID = T.ProdID AND VD.MRP = T.MRP
                                    AND (ISNULL(@SpotSalePriceMode,1) = 2 OR VD.UomPrice = T.UOMPrice)
    JOIN tblVanLoadingSlipHeader VH ON VH.ID = VD.ID
    WHERE ISNULL(@SpotSalePriceMode,1) IN (1,2)
      AND VH.Status NOT IN (2,4) AND VH.BranchID = @BranchID AND VH.SalesmanID = @SalesmanID
      AND (VD.UomQty - (ISNULL(VD.VLSMQty,0) + ISNULL(VD.VLSRetrunQty,0))) > 0
      AND (T.AvailableQty IS NULL OR T.AvailableQty <> 0)
    GROUP BY VD.ID, VD.InventoryID, VD.ProdID, VD.UomPrice, VD.MRP;

    UPDATE VD SET VLSRetrunQty = ISNULL(VD.VLSRetrunQty,0) + ISNULL(G.Qty,0), FullyAdjusted = 0
    FROM tblVanLoadingSlipDetail VD JOIN @p2_g G ON VD.InventoryId = G.InventoryID AND VD.ID = G.ID;

    UPDATE PI SET ActualQty = PI.ActualQty + S.Qty, VLSQty = ISNULL(PI.VLSQty,0) - S.Qty
    FROM tblProductInventory PI
    JOIN (SELECT InventoryID, SUM(Qty) AS Qty FROM @p2_g GROUP BY InventoryID) S ON PI.InventoryId = S.InventoryID;
END
ELSE
--Loop through Table Value Parameter(TVP)
WHILE @tvpCount >0
BEGIN
CREATE TABLE #InventoryId (Ident INT IDENTITY ,TempInvId INT,TempInvQty DECIMAL (15,4),TempVLAID int)  
CREATE TABLE #DATA1(ID INT,InventoryID INT,ProdID INT,UomQty DECIMAL (15,4),VLSMQty DECIMAL (15,4),UomPrice DECIMAL (15,4),  
MRP DECIMAL (15,4))  
  
select @ProdID = ProdID,@AvailableQty = AvailableQty,@UOMPrice = UOMPrice,@MRP = MRP from @tvpVLSItemdetails  
where [Index] = @tvpIndex  
  
IF(ISNULL(@SpotSalePriceMode,1) = 1)--VLS PRICE BASE QTY REDUCE(ECP/other price & MRP)  
BEGIN  
INSERT INTO #DATA1  
select VD.ID,VD.InventoryID,VD.ProdID,SUM(VD.UomQty - (ISNULL(VD.VLSMQtY,0) + ISNULL(VD.VLSRetrunQty,0))) UomQty,  
SUM(VD.VLSMQty) VLSMQty,VD.UomPrice,VD.MRP  
from tblVanLoadingSlipHeader VH  
JOIN tblVanLoadingSlipDetail VD ON VD.ID = VH.ID  
WHERE Status NOT IN (2,4) AND VH.BranchID = @BranchID AND VH.SalesmanID = @SalesmanID AND ProdID = @ProdID  
AND UomPrice = @UOMPrice AND VD.MRP = @MRP  
AND (UomQty - (ISNULL(VLSMQty,0) + ISNULL(VD.VLSRetrunQty,0))) > 0  
GROUP BY VD.ID,VD.InventoryID,VD.ProdID,VD.UomPrice,VD.MRP  
ORDER BY VD.ID  
END  
ELSE IF(ISNULL(@SpotSalePriceMode,1) = 2)--INVENTORY PRICE BASE QTY REDUCE(MRP)  
BEGIN  
INSERT INTO #DATA1  
select VD.ID,VD.InventoryID,VD.ProdID,SUM(VD.UomQty - (ISNULL(VD.VLSMQtY,0) + ISNULL(VD.VLSRetrunQty,0))) UomQty,  
SUM(VD.VLSMQty) VLSMQty,VD.UomPrice,VD.MRP  
from tblVanLoadingSlipHeader VH  
JOIN tblVanLoadingSlipDetail VD ON VD.ID = VH.ID  
WHERE Status NOT IN (2,4) AND VH.BranchID = @BranchID AND VH.SalesmanID = @SalesmanID AND ProdID = @ProdID AND VD.MRP = @MRP  
AND (UomQty - (ISNULL(VLSMQty,0) + ISNULL(VD.VLSRetrunQty,0))) > 0  
GROUP BY VD.ID,VD.InventoryID,VD.ProdID,VD.UomPrice,VD.MRP  
ORDER BY VD.ID
END  
SET @AvailableQty = @SaleUomCRate * @AvailableQty  
  
DECLARE @InventoryId INT,@InventoryQty DECIMAL(25, 4),@VLSID INT  
DECLARE cursor_Inventory CURSOR FOR (SELECT InventoryId,UomQty,ID AS Qty FROM #DATA1)  
OPEN cursor_Inventory  
FETCH NEXT FROM cursor_Inventory INTO @InventoryId,@InventoryQty,@VLSID  
WHILE @@FETCH_STATUS =0  
BEGIN  
--Loop Exist Qty Adjusted After  
IF(@AvailableQty =0)  
BEGIN  
BREAK;  
END  
--Qty Type SALE  
  
UPDATE tblVanLoadingSlipDetail SET VLSRetrunQty = ISNULL(VLSRetrunQty,0)+ISNULL(@InventoryQty,0),FullyAdjusted = 0  
WHERE InventoryId = @InventoryId AND ID = @VLSID    
  
  
update tblProductInventory set ActualQty = ActualQty + @InventoryQty,VLSQty = isnull(VLSQty,0) - @InventoryQty  
where InventoryId = @InventoryId  
  
FETCH NEXT FROM cursor_Inventory INTO @InventoryId,@InventoryQty,@VLSID  
END  
CLOSE cursor_Inventory  
DEALLOCATE cursor_Inventory  
  
DROP TABLE #DATA1,#InventoryId  
SET @tvpIndex =@tvpIndex+1  
SET @tvpCount =@tvpCount-1;  
END  
END TRY  
BEGIN CATCH  
SELECT ERROR_MESSAGE() MSG,ERROR_LINE() LINE,ERROR_PROCEDURE() PRO  
END CATCH

GO
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspManageVanloadingSlipReturn')) LIKE N'%/*p2:07%' PRINT N'dbo.uspManageVanloadingSlipReturn : changed';
GO
SET NOEXEC OFF;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
/* ===================================================================================== dbo.uspQtyReduceFromVanloading */
SET NOEXEC OFF;
GO
DECLARE @d nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspQtyReduceFromVanloading'));
IF @d IS NULL
BEGIN PRINT N'dbo.uspQtyReduceFromVanloading : not found - skipped'; SET NOEXEC ON; END
ELSE IF @d LIKE N'%/*p2:07%'
BEGIN PRINT N'dbo.uspQtyReduceFromVanloading : already applied'; SET NOEXEC ON; END
ELSE IF HASHBYTES('SHA2_256', @d) <> 0xF5BF09055D3809CAE37BB1227F32ED6E83489475C92D620ECF3CB244F0AFDD8B
BEGIN PRINT N'dbo.uspQtyReduceFromVanloading : SKIPPED - this database has a different version of the procedure than the one this script was written for'; SET NOEXEC ON; END
ELSE
BEGIN
    INSERT dbo.DbaProcBackup (ProcName, Script, UsesAnsiNulls, UsesQuotedIdentifier, Definition)
    SELECT N'uspQtyReduceFromVanloading', '07', uses_ansi_nulls, uses_quoted_identifier, definition FROM sys.sql_modules WHERE object_id = OBJECT_ID(N'dbo.uspQtyReduceFromVanloading');
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
ALTER PROC [dbo].[uspQtyReduceFromVanloading]    
@Transaction VARCHAR(50),@BranchID INT,@AppPriceId INT,@InvoiceScopeId INT=NULL,@DispathScopeId INT=NULL,@DocDate DATE,    
@tvpTranSaleDetail tvpTranSaleDetail READONLY    
AS    
BEGIN TRY    
DECLARE @ProdId INT,@BaseUomPrice DECIMAL (15,4),@UomId INT,@UomQty DECIMAL (15,4) ,@UomPrice DECIMAL (15,4),@GoodsAmt DECIMAL (15,4),    
@GrossAmt DECIMAL (15,4),    
@TaxId INT , @TaxPercentage DECIMAL (15,4) ,@TaxAmt DECIMAL (15,4),@NetAmt DECIMAL (15,4),@BatchNumber NVARCHAR(255),    
@PkgDate NVARCHAR(25),@ExpiryDate NVARCHAR(25),@InventoryPrice DECIMAL (15,4),@MRP DECIMAL (15,4),@InvQtyType INT ,@TempUomGroupId INT,    
@TempInventoryYesNo INT ,@TempBatchYesNo INT,@TempPKDYesNo INT,@TempSerialYesNo INT,@tvpCount INT, @tvpIndex INT,@ActiveCheck INT,    
@SaleUomCRate DECIMAL (15,4),@Qty DECIMAL (15,4),@SaleQty DECIMAL (15,4),@Index INT,@TrackInventory INT,@TrackBatch INT,@TrackPkd INT,    
@TrackSerial INT ,@UomGroupId INT,@PSerial NVARCHAR(255),@TempSerial INT ,    
@ProdSchemeID INT    
declare @dtluomqty decimal(15,4),@dtluomprice decimal(15,4),@dtlgross decimal(15,4),@dtltax decimal(15,4),@dtlnet decimal(15,4)  
--Detail stored in SalesDetail Table    
SET @tvpCount =(SELECT COUNT(*) FROM @tvpTranSaleDetail)    
SET @tvpIndex =1    
SET @TempSerial=1    
--Invoice Detail Using Table Value Parameter(TVP)    
/*p2:07 set-based FIFO fast path. Same result as the loop below: for each line (Serial order) the
  matching batches are used oldest TransDate first (then lowest InventoryId), stock moves from
  ActualQty/ActualFreeQty to VLSQty/VLSFreeQty with the same formulas, and one slip line is written
  per batch used, with the same amounts, rounding and line order. Errors: the first line (Serial order)
  that fails gives the same message and @ProdId as the loop. Nothing is written in that case (the
  loop wrote the earlier lines first; the API rolls its transaction back in both cases).
  The loop below still handles inputs where its line-by-line order could matter: Serial not 1..N,
  the same product + qty type on two lines, unknown products, a negative UOM factor, PKD/expiry text
  that is not a date, or values too large for the decimal(15,4) variables the loop uses.*/
IF (SELECT COUNT(*) FROM @tvpTranSaleDetail)
     = (SELECT COUNT(DISTINCT Serial) FROM @tvpTranSaleDetail WHERE Serial BETWEEN 1 AND (SELECT COUNT(*) FROM @tvpTranSaleDetail))
   AND NOT EXISTS (SELECT 1 FROM @tvpTranSaleDetail T
                   WHERE ABS(T.BaseUomPrice) >= 100000000000 OR ABS(T.UomQty) >= 100000000000 OR ABS(T.UomPrice) >= 100000000000
                      OR ABS(T.GoodsAmt) >= 100000000000 OR ABS(T.GrossAmt) >= 100000000000 OR ABS(T.TaxPercentage) >= 100000000000
                      OR ABS(T.TaxAmt) >= 100000000000 OR ABS(T.NetAmt) >= 100000000000 OR ABS(T.InventoryPrice) >= 100000000000
                      OR ABS(T.MRP) >= 100000000000 OR ABS(T.UomCR) >= 100000000000)
   AND NOT EXISTS (SELECT 1 FROM @tvpTranSaleDetail T
                   WHERE ISNULL(T.ProdId,0) > 0 AND ISNULL(T.UomQty,0) > 0
                     AND (   (SELECT COUNT(*) FROM tblMasterProduct M WHERE M.ID = T.ProdId) <> 1
                          OR ISNULL(T.UomCR,1) < 0
                          OR T.InvQtyType IS NULL
                          OR EXISTS (SELECT 1 FROM @tvpTranSaleDetail U
                                     WHERE U.Serial <> T.Serial AND U.ProdId = T.ProdId AND ISNULL(U.UomQty,0) > 0
                                       AND (U.InvQtyType = T.InvQtyType OR U.InvQtyType IS NULL))
                          OR EXISTS (SELECT 1 FROM tblMasterProduct M
                                     WHERE M.ID = T.ProdId AND ISNULL(M.TrackInventory,0) = 1 AND ISNULL(M.TrackPDK,0) = 1 AND T.InvQtyType IN (1,2)
                                       AND (TRY_CAST(CAST(T.PkgDate AS nvarchar(25)) AS date) IS NULL
                                            OR TRY_CAST(CAST(T.ExpiryDate AS nvarchar(25)) AS date) IS NULL))))
BEGIN
    DECLARE @p2_err int = 0;
    DECLARE @p2_r TABLE (Serial int PRIMARY KEY, TempSerial int, ProdId int, BaseUomPrice decimal(15,4), UomId int, UomQty decimal(15,4),
        TaxId int, TaxPercentage decimal(15,4), BatchNumber nvarchar(255), PkgDate nvarchar(25), ExpiryDate nvarchar(25),
        InventoryPrice decimal(15,4), MRP decimal(15,4), InvQtyType int, CR decimal(15,4),
        TrackInventory int, TrackBatch int, TrackPkd int, Err int, SaleQty decimal(15,4), PkdKey date, ExpKey date);
    INSERT @p2_r (Serial, TempSerial, ProdId, BaseUomPrice, UomId, UomQty, TaxId, TaxPercentage, BatchNumber, PkgDate, ExpiryDate,
                  InventoryPrice, MRP, InvQtyType, CR, TrackInventory, TrackBatch, TrackPkd, Err)
    SELECT T.Serial, ROW_NUMBER() OVER (ORDER BY T.Serial), T.ProdId, T.BaseUomPrice, T.UomId, T.UomQty, T.TaxId, T.TaxPercentage,
           T.BatchNumber, CAST(T.PkgDate AS nvarchar(25)), CAST(T.ExpiryDate AS nvarchar(25)), T.InventoryPrice, T.MRP, T.InvQtyType,
           ISNULL(T.UomCR,1), M.TrackInventory, M.TrackBatch, M.TrackPDK,
           CASE WHEN ISNULL(M.TrackInventory,0) != ISNULL(T.InventoryYesNo,0) OR ISNULL(M.TrackBatch,0) != ISNULL(T.BatchYesNo,0)
                  OR ISNULL(T.PKDYesNo,0) != ISNULL(M.TrackPDK,0) OR ISNULL(M.TrackSerial,0) != ISNULL(T.SerialYesNo,0) THEN 1
                WHEN ISNULL(CAST(ISNULL(T.UomCR,1) AS decimal(15,4)),0) = 0 THEN 2
                ELSE 0 END
    FROM @tvpTranSaleDetail T JOIN tblMasterProduct M ON M.ID = T.ProdId
    WHERE ISNULL(T.ProdId,0) > 0 AND ISNULL(CAST(T.UomQty AS decimal(15,4)),0) > 0;

    UPDATE @p2_r SET SaleQty = CR * UomQty,
           PkdKey = CASE WHEN ISNULL(TrackPkd,0) = 1 THEN CAST(PkgDate AS date) END,
           ExpKey = CASE WHEN ISNULL(TrackPkd,0) = 1 THEN CAST(ExpiryDate AS date) END
    WHERE Err = 0;

    -- batches each line may use (the loop's #Temp)
    DECLARE @p2_c TABLE (Serial int, InventoryId int, TDate date, Qty decimal(15,4), PRIMARY KEY (Serial, InventoryId));
    INSERT @p2_c (Serial, InventoryId, TDate, Qty)
    SELECT R.Serial, PI.InventoryId, PI.TransDate, CASE R.InvQtyType WHEN 1 THEN PI.ActualQty ELSE PI.ActualFreeQty END
    FROM @p2_r R
    JOIN tblProductInventory PI ON PI.ProdId = R.ProdId AND PI.BranchID = @BranchID AND PI.TransDate <= @DocDate
    WHERE R.Err = 0 AND ISNULL(R.TrackInventory,0) = 1
      AND (   (R.InvQtyType = 1 AND PI.ActualQty > 0 AND PI.MRPONPrice = R.MRP
               AND (CASE WHEN @AppPriceId = 1 THEN PI.PurchasePrice WHEN @AppPriceId = 2 THEN PI.SalesPrice WHEN @AppPriceId = 3 THEN PI.ECP
                         WHEN @AppPriceId = 4 THEN PI.MRP WHEN @AppPriceId = 5 THEN PI.SPLPrice ELSE PI.ReturnPrice END) = R.InventoryPrice)
           OR (R.InvQtyType = 2 AND PI.ActualFreeQty > 0))
      AND (ISNULL(R.TrackBatch,0) = 0 OR PI.BatchNumber = R.BatchNumber)
      AND (ISNULL(R.TrackPkd,0) = 0 OR (PI.PKDDate = R.PkdKey AND PI.ExpiryDate = R.ExpKey));

    UPDATE R SET Err = 3 FROM @p2_r R
    WHERE R.Err = 0 AND ISNULL(R.TrackInventory,0) = 1
      AND R.SaleQty > ISNULL((SELECT SUM(C.Qty) FROM @p2_c C WHERE C.Serial = R.Serial), 0);

    SELECT TOP (1) @ProdId = ProdId, @p2_err = Err FROM @p2_r WHERE Err <> 0 ORDER BY Serial;
    IF @p2_err = 1 RAISERROR('Product classification already changed',16,1);
    IF @p2_err = 2 RAISERROR('Selected UOM changed for that product',16,1);
    IF @p2_err = 3 RAISERROR('Qty Mismatched',16,1);

    -- FIFO: Remaining = qty still needed when this batch is reached, Take = qty taken from it
    DECLARE @p2_a TABLE (Serial int, InventoryId int, TDate date, Qty decimal(15,4), Remaining decimal(38,4), Take decimal(38,4), PRIMARY KEY (Serial, InventoryId));
    WITH x AS (
        SELECT C.Serial, C.InventoryId, C.TDate, C.Qty,
               R.SaleQty - (SUM(C.Qty) OVER (PARTITION BY C.Serial ORDER BY C.TDate, C.InventoryId ROWS UNBOUNDED PRECEDING) - C.Qty) AS Remaining
        FROM @p2_c C JOIN @p2_r R ON R.Serial = C.Serial)
    INSERT @p2_a (Serial, InventoryId, TDate, Qty, Remaining, Take)
    SELECT Serial, InventoryId, TDate, Qty, Remaining, CASE WHEN Remaining > Qty THEN Qty ELSE Remaining END
    FROM x WHERE Remaining > 0;

    UPDATE PI SET ActualQty = CASE WHEN A.Remaining > A.Qty THEN ISNULL(PI.ActualQty,0) - ISNULL(A.Qty,0) ELSE ISNULL(A.Qty,0) - ISNULL(A.Remaining,0) END,
                  VLSQty = ISNULL(PI.VLSQty,0) + ISNULL(A.Take,0), mdate = GETDATE()
    FROM tblProductInventory PI JOIN @p2_a A ON A.InventoryId = PI.InventoryId JOIN @p2_r R ON R.Serial = A.Serial
    WHERE R.InvQtyType = 1;
    -- free qty: VLSFreeQty grows by the qty still needed when the batch is reached (as the loop did)
    UPDATE PI SET ActualFreeQty = CASE WHEN A.Remaining > A.Qty THEN ISNULL(PI.ActualFreeQty,0) - ISNULL(A.Qty,0) ELSE ISNULL(A.Qty,0) - ISNULL(A.Remaining,0) END,
                  VLSFreeQty = ISNULL(PI.VLSFreeQty,0) + ISNULL(A.Remaining,0), mdate = GETDATE()
    FROM tblProductInventory PI JOIN @p2_a A ON A.InventoryId = PI.InventoryId JOIN @p2_r R ON R.Serial = A.Serial
    WHERE R.InvQtyType = 2;

    INSERT INTO dbo.tblVanLoadingSlipDetail(Id,InventoryId,AdjustQty,ProdId,BaseUomPrice,UomId,UomQty,UomPrice,
        UOMCF,MRP,GrossAmt,TaxId,TaxValue,TaxAmt,NetAmt,Serial,QtyType)
    SELECT @InvoiceScopeId, A.InventoryId, A.Take, R.ProdId, R.BaseUomPrice, R.UomId, v1.uq, v1.up,
           R.CR, R.MRP, v2.g, R.TaxId, R.TaxPercentage, v3.t, CAST(v2.g + v3.t AS decimal(15,4)), R.TempSerial, R.InvQtyType
    FROM @p2_a A JOIN @p2_r R ON R.Serial = A.Serial
    CROSS APPLY (SELECT CAST(CAST(A.Take AS decimal(25,9)) / R.CR AS decimal(15,4)) AS uq, CAST(R.BaseUomPrice * R.CR AS decimal(15,4)) AS up) v1
    CROSS APPLY (SELECT CAST(v1.uq * v1.up AS decimal(15,4)) AS g) v2
    CROSS APPLY (SELECT CAST(CAST(dbo.fngetMRPonTaxValue(2, v2.g, R.MRP, R.TaxId, 1) AS decimal(15,4)) * v1.uq AS decimal(15,4)) AS t) v3
    ORDER BY A.Serial, A.TDate, A.InventoryId;
END
ELSE
--Loop through Table Value Parameter(TVP)
WHILE @tvpCount >0
BEGIN
SELECT @ProdId=[ProdId],@BaseUomPrice =[BaseUomPrice] ,@UomId =[UomId] ,@UomQty =[UomQty] ,@UomPrice =[UomPrice] , @GoodsAmt =[GoodsAmt] ,    
@GrossAmt =[GrossAmt] ,@TaxId =[TaxId],    
@TaxPercentage =[TaxPercentage] ,@TaxAmt =[TaxAmt] ,@NetAmt =[NetAmt] ,@BatchNumber=[BatchNumber] ,@PkgDate =[PkgDate] ,    
@ExpiryDate =[ExpiryDate] ,@InventoryPrice =[InventoryPrice],@MRP =[MRP] ,@InvQtyType =[InvQtyType] ,--,@TempUomGroupId =[UomGroupId],    
@TempInventoryYesNo =[InventoryYesNo] ,@TempBatchYesNo=[BatchYesNo] ,@TempPKDYesNo=[PKDYesNo] ,@TempSerialYesNo =[SerialYesNo],    
@SaleUomCRate= isnull(UomCR,1)    
--,@ProdSchemeID = SecondarySchemeID    
FROM @tvpTranSaleDetail WHERE [Serial]=@tvpIndex    
--Verify Empty Row    
IF ISNULL(@ProdId,0)>0 AND ISNULL(@UomQty,0)>0    
BEGIN    
    
--Get Product Classification    
SELECT @TrackInventory= TrackInventory,@TrackBatch =TrackBatch ,@TrackPkd =TrackPDK,@TrackSerial=TrackSerial--,@SaleUomCRate=SalesCR--,@UomGroupId=UomGroupID    
FROM tblMasterProduct WHERE ID =@ProdId    
IF (ISNULL(@TrackInventory,0) != ISNULL(@TempInventoryYesNo,0) OR ISNULL(@TrackBatch,0) != ISNULL(@TempBatchYesNo,0) OR    
ISNULL(@TempPKDYesNo,0) != ISNULL(@TrackPkd,0) OR ISNULL(@TrackSerial,0) != ISNULL(@TempSerialYesNo,0))    
BEGIN    
RAISERROR('Product classification already changed',16,1);    
END    
--Convert Qty as Base UOM    
--SELECT @SaleUomCRate=ISNULL(ConversionRate,0) FROM tblMastUomGroupDetail WHERE UOMGroupID =@UomGroupId AND UOMMastID =@UomId    
IF ISNULL(@SaleUomCRate,0)=0    
BEGIN    
RAISERROR('Selected UOM changed for that product',16,1);    
END    
SET @Qty=@SaleUomCRate*@UomQty    
SET @SaleQty =@SaleUomCRate*@UomQty    
--Inventory Yes Procduct Only    
IF ISNULL(@TrackInventory,0) =1    
BEGIN    
--Inventory Base Uom Price    
--SET @InventoryPrice =(@InventoryPrice /@SaleUomCRate)    
--Check Date Weather NULL OR NOT NULL    
IF(ISNULL(@TrackPkd,0) =1)    
BEGIN    
SET @PkgDate =CONVERT(NVARCHAR,@PkgDate ,103)    
SET @ExpiryDate =CONVERT(NVARCHAR,@ExpiryDate ,103)    
END    
ELSE    
BEGIN    
SET @PkgDate =NULL    
SET @ExpiryDate=NULL    
END    
CREATE TABLE #InventoryId (Ident INT IDENTITY ,TempInvId INT,TempInvQty DECIMAL (15,4))    
    
    
CREATE TABLE #Temp (TDate DATE,TInventoryId INT,TInventoryQty DECIMAL (15,4))    
CREATE TABLE #TempReduceQty (TInventoryId INT,TInventoryQty DECIMAL (15,4))    
/*Sale Qty Only Get From Inventory Table */    
IF(@InvQtyType=1)    
BEGIN    
--Product Classification    
IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)=0 AND ISNULL(@TrackPkd,0)=0    
BEGIN    
INSERT INTO #Temp SELECT TransDate,InventoryId,ActualQty FROM tblProductInventory    
WHERE ProdId =@ProdId and BranchID = @BranchID AND ActualQty>0 AND TransDate<=@DocDate AND MRPONPrice =@MRP    
AND (CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP    
WHEN @AppPriceId =4 THEN MRP WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END)=@InventoryPrice    
ORDER BY TransDate    
END    
ELSE IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)<>0 AND ISNULL(@TrackPkd,0)=0    
BEGIN    
INSERT INTO #Temp SELECT TransDate,InventoryId,ActualQty FROM tblProductInventory    
WHERE ProdId =@ProdId and BranchID = @BranchID AND ActualQty>0 AND TransDate<=@DocDate AND BatchNumber =@BatchNumber AND MRPONPrice =@MRP    
AND (CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP    
WHEN @AppPriceId =4 THEN MRP WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END) =@InventoryPrice    
ORDER BY TransDate    
END    
ELSE IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)<>0 AND ISNULL(@TrackPkd,0)<>0    
BEGIN    
INSERT INTO #Temp SELECT TransDate,InventoryId,ActualQty FROM tblProductInventory    
WHERE ProdId =@ProdId and BranchID = @BranchID AND ActualQty>0 AND TransDate<=@DocDate AND BatchNumber =@BatchNumber AND PkdDate =@PkgDate AND ExpiryDate =@ExpiryDate AND MRPONPrice =@MRP AND    
(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP    
WHEN @AppPriceId =4 THEN MRP WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END) =@InventoryPrice    
ORDER BY TransDate    
END    
ELSE IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)=0 AND ISNULL(@TrackPkd,0)<>0    
BEGIN    
INSERT INTO #Temp SELECT TransDate,InventoryId,ActualQty FROM tblProductInventory    
WHERE ProdId =@ProdId and BranchID = @BranchID AND ActualQty>0 AND TransDate<=@DocDate AND PkdDate =@PkgDate AND ExpiryDate =@ExpiryDate AND MRPONPrice =@MRP AND    
(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP    
WHEN @AppPriceId =4 THEN MRP WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END) =@InventoryPrice    
ORDER BY TransDate    
END    
END    
/*Free Qty Only Get From Invnetory */    
ELSE IF(@InvQtyType=2)    
BEGIN    
--Product Classification    
IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)=0 AND ISNULL(@TrackPkd,0)=0    
BEGIN    
INSERT INTO #Temp SELECT TransDate,InventoryId,ActualFreeQty FROM tblProductInventory    
WHERE ProdId =@ProdId and BranchID = @BranchID AND ActualFreeQty>0 AND TransDate<=@DocDate    
ORDER BY TransDate    
END    
ELSE IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)<>0 AND ISNULL(@TrackPkd,0)=0    
BEGIN    
INSERT INTO #Temp SELECT TransDate,InventoryId,ActualFreeQty FROM tblProductInventory    
WHERE ProdId =@ProdId and BranchID = @BranchID AND ActualFreeQty>0 AND TransDate<=@DocDate AND BatchNumber=@BatchNumber    
ORDER BY TransDate    
END    
ELSE IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)<>0 AND ISNULL(@TrackPkd,0)<>0    
BEGIN    
INSERT INTO #Temp SELECT TransDate,InventoryId,ActualFreeQty FROM tblProductInventory    
WHERE ProdId =@ProdId and BranchID = @BranchID AND ActualFreeQty>0 AND TransDate<=@DocDate AND BatchNumber=@BatchNumber    
AND PkdDate=@PkgDate AND ExpiryDate=@ExpiryDate    
ORDER BY TransDate    
END    
ELSE IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)=0 AND ISNULL(@TrackPkd,0)<>0    
BEGIN    
INSERT INTO #Temp SELECT TransDate,InventoryId,ActualFreeQty FROM tblProductInventory    
WHERE ProdId =@ProdId and BranchID = @BranchID AND ActualFreeQty>0 AND TransDate<=@DocDate AND PkdDate=@PkgDate AND ExpiryDate=@ExpiryDate    
ORDER BY TransDate    
END    
END    
-- Changed by Sriram G (Reduce Qty Order by Trans Date)    
INSERT INTO #TempReduceQty SELECT TInventoryId,SUM(TInventoryQty) FROM #Temp GROUP BY TDate,TInventoryId ORDER BY TDate    
/*Inventory Detail Adjustment in Inventory Table*/    
DECLARE @InventoryId INT,@InventoryQty DECIMAL(25, 9)    
DECLARE cursor_Inventory CURSOR FOR (SELECT TInventoryId,TInventoryQty AS Qty FROM #TempReduceQty)    
OPEN cursor_Inventory    
FETCH NEXT FROM cursor_Inventory INTO @InventoryId,@InventoryQty    
WHILE @@FETCH_STATUS =0    
BEGIN    
--Loop Exist Qty Adjusted After    
IF(@SaleQty =0)    
BEGIN    
BREAK;    
END    
--Qty Type SALE    
IF(@InvQtyType=1)    
BEGIN  IF @SaleQty >@InventoryQty    
BEGIN    
UPDATE tblProductInventory SET ActualQty =ISNULL(ActualQty,0)-ISNULL(@InventoryQty,0),VLSQty = ISNULL(VLSQty,0)+ISNULL(@InventoryQty,0),    
mdate = getdate() WHERE InventoryId =@InventoryId    
SET @SaleQty =@SaleQty -@InventoryQty    
INSERT INTO #InventoryId VALUES (@InventoryId,@InventoryQty)    
END    
ELSE IF @SaleQty <@InventoryQty    
BEGIN    
UPDATE tblProductInventory SET ActualQty =ISNULL(@InventoryQty,0)-ISNULL(@SaleQty,0),VLSQty = ISNULL(VLSQty,0)+ISNULL(@SaleQty,0),    
mdate = getdate() WHERE InventoryId =@InventoryId    
INSERT INTO #InventoryId VALUES (@InventoryId,@SaleQty)    
SET @SaleQty =0    
END    
ELSE IF @SaleQty=@InventoryQty    
BEGIN    
UPDATE tblProductInventory SET ActualQty =ISNULL(@InventoryQty,0)-ISNULL(@SaleQty,0),VLSQty = ISNULL(VLSQty,0)+ISNULL(@SaleQty,0),    
mdate = getdate() WHERE InventoryId =@InventoryId    
INSERT INTO #InventoryId VALUES (@InventoryId,@SaleQty)    
SET @SaleQty =0    
END    
END    
--Qty Type FREE    
ELSE IF(@InvQtyType=2)    
BEGIN    
IF @SaleQty >@InventoryQty    
BEGIN    
UPDATE tblProductInventory SET ActualFreeQty =ISNULL(ActualFreeQty,0)-ISNULL(@InventoryQty,0),VLSFreeQty = ISNULL(VLSFreeQty,0)+ISNULL(@SaleQty,0),    
mdate = getdate() WHERE InventoryId =@InventoryId    
SET @SaleQty =@SaleQty -@InventoryQty    
INSERT INTO #InventoryId VALUES (@InventoryId,@InventoryQty)    
END    
ELSE IF @SaleQty <@InventoryQty    
BEGIN    
UPDATE tblProductInventory SET ActualFreeQty =ISNULL(@InventoryQty,0)-ISNULL(@SaleQty,0),VLSFreeQty = ISNULL(VLSFreeQty,0)+ISNULL(@SaleQty,0),    
mdate = getdate() WHERE InventoryId =@InventoryId    
INSERT INTO #InventoryId VALUES (@InventoryId,@SaleQty)    
SET @SaleQty =0    
END    
ELSE IF @SaleQty=@InventoryQty    
BEGIN    
UPDATE tblProductInventory SET ActualFreeQty =ISNULL(@InventoryQty,0)-ISNULL(@SaleQty,0),VLSFreeQty = ISNULL(VLSFreeQty,0)+ISNULL(@SaleQty,0),    
mdate = getdate() WHERE InventoryId =@InventoryId    
INSERT INTO #InventoryId VALUES (@InventoryId,@SaleQty)    
SET @SaleQty =0    
END    
END    
FETCH NEXT FROM cursor_Inventory INTO @InventoryId,@InventoryQty    
END    
CLOSE cursor_Inventory    
DEALLOCATE cursor_Inventory    
/*Sales Detail Table Store the Detail Based On Serial and Inventory Adjusted Row wies*/    
IF ISNULL(@SaleQty,0) !=0    
BEGIN    
RAISERROR('Qty Mismatched',16,1);    
END    
ELSE    
BEGIN    
DECLARE @InsertCount INT=(SELECT COUNT(*) FROM #InventoryId )    
DECLARE @InsertIdent INT SET @InsertIdent=1;    
DECLARE @InvAdjId INT,@InvAdjQty DECIMAL(25, 9)    
SET @Index=1    
--loop Inentory Adjustment Qty    
  
WHILE @InsertCount>0    
BEGIn    
SET @InvAdjId=(SELECT TempInvId FROM #InventoryId WHERE Ident=@InsertIdent)    
SET @InvAdjQty=(SELECT TempInvQty FROM #InventoryId WHERE Ident=@InsertIdent)    
IF @Index=@Index--1    
BEGIN    
set @dtluomqty = (@InvAdjQty / @SaleUomCRate)  
set @dtluomprice = (@BaseUomPrice * @SaleUomCRate)  
set @dtlgross = (@dtluomqty * @dtluomprice)  
set @dtltax = (select dbo.fngetMRPonTaxValue(2,@dtlgross,@MRP,@TaxId,1))  
SET @dtltax = @dtltax * @dtluomqty
--(@dtlgross * @TaxPercentage) / 100  
set @dtlnet = @dtlgross + @dtltax  
INSERT INTO dbo.tblVanLoadingSlipDetail(Id,InventoryId,AdjustQty,ProdId,BaseUomPrice,UomId,UomQty,UomPrice,    
UOMCF,MRP,GrossAmt,TaxId,TaxValue,TaxAmt,NetAmt,Serial,QtyType)    
VALUES(@InvoiceScopeId,@InvAdjId ,@InvAdjQty,@ProdId ,@BaseUomPrice,@UomId,@dtluomqty,  
@dtluomprice, --@UomQty ,@UomPrice,    
@SaleUomCRate,@MRP,@dtlgross ,@TaxId,@TaxPercentage,@dtltax,@dtlnet,@TempSerial,@InvQtyType)    
    
ENd    
ELSE    
BEGIN    
IF @Transaction ='DIRECT_SALE'    
BEGIN    
--Sales    
INSERT INTO tblVanLoadingSlipDetail(Id,ProdId,InventoryId,AdjustQty,QtyType,Serial,MRP,UOMCF)    
VALUES(@InvoiceScopeId,@ProdId,@InvAdjId,@InvAdjQty,@PSerial,@InvQtyType,@MRP,@SaleUomCRate)    
END    
END    
SET @Index=@Index+1    
--Insert Loop Increment    
SET @InsertIdent=@InsertIdent+1;    
SET @InsertCount=@InsertCount-1;    
END    
--Destroy Table    
DROP TABLE #Temp;    
DROP TABLE #TempReduceQty;    
DROP TABLE #InventoryId;    
END    
END    
SET @TempSerial =@TempSerial+1 ;    
END    
SET @tvpIndex =@tvpIndex+1    
SET @tvpCount =@tvpCount-1;    
END    
END TRY    
BEGIN CATCH    
SELECT ERROR_MESSAGE() ,ERROR_PROCEDURE() ,ERROR_LINE(),@ProdId;    
END CATCH

GO
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspQtyReduceFromVanloading')) LIKE N'%/*p2:07%' PRINT N'dbo.uspQtyReduceFromVanloading : changed';
GO
SET NOEXEC OFF;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
/* ===================================================================================== dbo.uspManageTranSalesCancel */
SET NOEXEC OFF;
GO
DECLARE @d nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspManageTranSalesCancel'));
IF @d IS NULL
BEGIN PRINT N'dbo.uspManageTranSalesCancel : not found - skipped'; SET NOEXEC ON; END
ELSE IF @d LIKE N'%/*p2:07%'
BEGIN PRINT N'dbo.uspManageTranSalesCancel : already applied'; SET NOEXEC ON; END
ELSE IF HASHBYTES('SHA2_256', @d) <> 0x11C4DA234D5CAC46137F8CC06E93E1FCE7E66253DB9C995564040B451FEFC8F1
BEGIN PRINT N'dbo.uspManageTranSalesCancel : SKIPPED - this database has a different version of the procedure than the one this script was written for'; SET NOEXEC ON; END
ELSE
BEGIN
    INSERT dbo.DbaProcBackup (ProcName, Script, UsesAnsiNulls, UsesQuotedIdentifier, Definition)
    SELECT N'uspManageTranSalesCancel', '07', uses_ansi_nulls, uses_quoted_identifier, definition FROM sys.sql_modules WHERE object_id = OBJECT_ID(N'dbo.uspManageTranSalesCancel');
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
-- uspManageTranSalesCancel 3,9469,2,5                  
ALTER PROC [dbo].[uspManageTranSalesCancel]                  
@CurrentStatus SMALLINT,@InvId INT,@UID INT,@Mode SMALLINT,@Remarks NVARCHAR(255) = NULL,@Narration NVARCHAR(MAX) = NULL                   
AS                  
BEGIN TRY                  
DECLARE @Bool VARCHAR(100), @Status INT, @TransType INT,@TempId INT,@TempDocValue INT,@TempSalesDocValue INT,@nStatus INT                  
DECLARE @SalesDate DATE,@SelesOrSRDocPrefix INT,@DispatchId INT,@TempDispatchDocValue INT,@DispatchDate DATE ,@BoolCancel SMALLINT=0                  
DECLARE @nDocPrefix INT,@OldNetAmt decimal(25,4),@CustId int          
                  
--check THIS inv document is used in SR or not                  
IF((SELECT COUNT(*) FROM tblTranSalesHeader WHERE OrgInvID = @InvId) > 0 AND @Mode != 2)                  
BEGIN                  
RAISERROR('21',16,1);                  
END                  
SELECT @nStatus = [Status] From tblTranSalesHeader Where ID = @InvId            
IF((@nStatus != @CurrentStatus) or @nStatus in (2,4))    
BEGIN            
RAISERROR('Document Status already changed',16,1)            
END       
      
if((isnull((SELECT COUNT(*) AS DeliveryCount FROM tblDeliveryOrderHeader DH      
JOIN tblDeliveryOrderDetail DD ON DD.DOID = DH.ID      
WHERE DH.Status IN (1,3,5) AND DD.Status IN (1,5) AND DD.InvIdentID = @InvId      
GROUP BY DD.InvIdentID),0)) > 0)      
BEGIN      
RAISERROR('This document already processed in Delivery',16,1)        
END      
  
if((isnull((SELECT COUNT(*) AS DeliveryCount FROM tblAssignInvoicesHeader DH      
JOIN tblAssignInvoicesDetail DD ON DD.HID = DH.ID      
WHERE DH.Status IN (1,3,5) AND DD.Status IN (1,5) AND DD.InvID = @InvId      
GROUP BY DD.InvID),0)) > 0)      
BEGIN      
RAISERROR('This document already processed in Assigned Invoice',16,1)        
END     
  
SET @Bool=[dbo].[funValidateSalesTran](@CurrentStatus ,@InvId)                  
-- Check and Update Collection Status = 4                  
                  
SELECT @nDocPrefix = DocPrefix,@OldNetAmt = NetAmt,@CustId = CustID FROM tblTranSalesHeader WHERE Id=@InvId                  
IF @Bool = 'TRUE' AND (SELECT DocPrefix FROM tblTranSalesHeader WHERE Id=@InvId)=15                  
BEGIN                  
DECLARE @CollIDs AS TABLE (Serial INT IDENTITY(1,1), TempColID INT)                  
DECLARE @SalesRtnCollID AS TABLE (DocPrefix INT, SRID INT, AdjAmt DECIMAL(25,6))                  
-- Revert Collection Status for Inserting                  
INSERT INTO @CollIDs                  
SELECT ColID FROM tblTranCollectionHeader                  
WHERE ColID IN (SELECT ColID FROM tblTranCollectionDetail WHERE DocID = @InvId) AND Type=1                  
-- Revert Sales Return Status for Inserting                  
INSERT INTO @SalesRtnCollID                  
SELECT DocPrefix,DocID,TotalAmtAdj                  
FROM tblTranCollectionDetail WHERE ColID IN (SELECT TempColID FROM @CollIDs) AND DocPrefix IN (3,6)                  
                  
IF (SELECT PaymentModeId FROM tblTranSalesHeader WHERE Id = @InvId)=8                  
BEGIN                  
IF (SELECT COUNT(*) FROM tblTranCollectionDetail WHERE DocID = @InvId) > 0                  
BEGIN                  
IF (SELECT COUNT(ColID) FROM tblTranCollectionHeader WHERE ColID IN                  
(SELECT ColID FROM tblTranCollectionDetail WHERE DocID = @InvId AND DocPrefix = @nDocPrefix) AND Type=0 AND Status IN (1,5)) > 0                  
BEGIn                  
SET @Bool = '16'                  
END                  
ELSE                  
BEGIN                  
SET @Bool = 'TRUE'                  
END                  
END                  
END                  
                  
IF @Bool = 'TRUE'                  
BEGIN                  
DECLARE @ColSerial INT = 1, @ColCount INT = (SELECT COUNT(TempColID) FROM @CollIDs)                  
/*p2:07 set-based: the collections of this invoice are cancelled with 3 UPDATEs instead of a loop.
  If any of them is not in status 1 the result is '16' as before (the loop had already cancelled the
  ones before it; the API rolls back in both cases). The loop is kept for collections with more than
  one header or payment-mode row, where it stops with "subquery returned more than 1 value".*/
IF NOT EXISTS (SELECT 1 FROM @CollIDs C
               WHERE (SELECT COUNT(*) FROM tblTranCollectionHeader H WHERE H.ColID = C.TempColID) > 1
                  OR (SELECT COUNT(*) FROM tblCollPMDetails P WHERE P.ColID = C.TempColID) > 1)
BEGIN
    IF EXISTS (SELECT 1 FROM @CollIDs C
               WHERE (SELECT Status FROM tblTranCollectionHeader WHERE ColID = C.TempColID) != 1
                  OR (SELECT Status FROM tblCollPMDetails WHERE ColID = C.TempColID) != 1)
        SET @Bool = '16';
    ELSE
    BEGIN
        UPDATE tblTranCollectionHeader SET Status=4,ClBy=@UID,ClDate=GETDATE(),Remarks = @Remarks,Narration = @Narration
        WHERE ColID IN (SELECT TempColID FROM @CollIDs);
        UPDATE tblCollPMDetails SET Status=4 WHERE ColID IN (SELECT TempColID FROM @CollIDs);
        UPDATE tblFAJournal SET Status=4,ClBy=@UID,ClDate=GETDATE(),Remarks = @Remarks,Narration = @Narration
        WHERE TransId IN (SELECT TempColID FROM @CollIDs) AND DocPrefix=19;--COLL
    END
END
ELSE
WHILE @ColCount > 0
BEGIN
DECLARE @CollID INT = (SELECT TempColID FROM @CollIDs WHERE Serial = @ColSerial)                 
DECLARE @PayModeID INT = (SELECT ColMode FROM tblTranCollectionHeader WHERE ColID = @CollID)                  
IF (SELECT Status FROM tblTranCollectionHeader WHERE ColID = @CollID) != 1 OR                  
(SELECT Status FROM tblCollPMDetails WHERE ColID = @CollID) != 1                  
BEGIN                  
SET @Bool = '16'                  
BREAK;                  
END                  
--IF ISNULL(@PayModeID,0)=6 -- DENOMINATION                  
--BEGIN                  
--DECLARE @tempActualCount INT,@SettledCount INT                  
--SELECT @tempActualCount=ISNULL(SUM(DCount),0),@SettledCount=ISNULL(SUM(SettlementCount),0)                  
--FROM tblmastdenominationPMDetails WHERE FormDocPrefix=5 AND TransID=@CollID                  
--IF @tempActualCount=@SettledCount                  
--BEGIN                  
--UPDATE tblmastdenominationPMDetails SET Status=4 WHERE FormDocPrefix=5 AND TransID=@CollID                  
--END                  
--ELSE                  
--BEGIN                  
--RAISERROR('17',16,1)                  
--END                  
--END                  
                  
-- Updating Collection Status = 4                  
UPDATE tblTranCollectionHeader SET Status=4,ClBy=@UID,ClDate=GETDATE(),Remarks = @Remarks,Narration = @Narration WHERE ColID = @CollID                  
UPDATE tblCollPMDetails SET Status=4 WHERE ColID = @CollID                  
UPDATE tblFAJournal SET Status=4,ClBy=@UID,ClDate=GETDATE(),Remarks = @Remarks,Narration = @Narration WHERE TransId=@CollID AND DocPrefix=19--COLL                  
                  
SET @ColSerial = @ColSerial + 1;                  
SET @ColCount = @ColCount - 1;                  
END                  
-- Update Sales Return Status = 6 or 7 and Revert Net Amount                  
UPDATE tblTranSalesHeader SET Balance=NetAmt WHERE Id=@InvId                  
IF (SELECT COUNT(*) FROM @SalesRtnCollID) > 0                  
BEGIN                  
UPDATE tblTranSalesHeader SET Balance=(Balance+SR.AdjAmt),Status=(                  
CASE                
WHEN (SELECT COUNT(DocId) FROM tblTranSalesHeader                  
WHERE DocId IN (SELECT DocId FROM tblTranSalesHeader WHERE Id = SR.SRID)                  
AND (InvDate BETWEEN (SELECT F_SD FROM tblCompanyRegistration) AND (SELECT F_ED FROM tblCompanyRegistration))) = 1                  
THEN (CASE WHEN TransactionType=2 THEN 6 ELSE 7 END)                  
ELSE 3                  
END)                  
FROM @SalesRtnCollID AS SR WHERE Id = SR.SRID AND SR.DocPrefix=6                  
UPDATE tblNoteDetails SET Balance=(Balance+SR.AdjAmt),Status=1                  
FROM @SalesRtnCollID AS SR WHERE ID = SR.SRID AND SR.DocPrefix=3  END                  
END                  
END                  
                  
IF @Bool !='TRUE'                  
BEGIN                  
RAISERROR(@Bool,16,1);                  
END                  
ELSE                  
BEGIN --Revert Qty and Posting                  
SELECT @Status=[Status],@TransType=TransactionType,@TempSalesDocValue=DocValue,@SalesDate=InvDate,@SelesOrSRDocPrefix=DocPrefix                  
FROM tblTranSalesHeader WHERE Id =@InvId                  
END                  
IF @Mode =2 OR @Mode=5                  
BEGIN                  
SET @BoolCancel=1;                  
END                  
ELSE IF @Mode =4 AND ISNULL(@TransType,0)<>5                  
BEGIN                  
SET @BoolCancel=1;                  
END                  
--Direct Sales or Saleable Return or Damage Return                  
IF ISNULL(@BoolCancel,0)=1                  
BEGIN                  
/*p2:07 set-based stock revert for: invoices (prefix 15), and sales returns in status 6 (saleable)
  or 7 (damage) whose lines all have a positive qty (and qty type 1/2 for status 6). Same formulas as
  the cursor; for returns the qty must still be in stock ("Quantity mismatched" otherwise, as before).
  Everything else (status 3 returns, zero/negative/NULL qty, other qty types) still uses the cursor.*/
IF ISNULL(@SelesOrSRDocPrefix,0) = 15
   OR (@Status IN (6,7) AND NOT EXISTS (SELECT 1 FROM tblTranSalesDetail
                                        WHERE InvID=@InvId AND ISNULL(InventoryId,0)>0
                                          AND (ISNULL(AdjustQty,0) <= 0 OR (@Status = 6 AND ISNULL(QtyType,0) NOT IN (1,2)))))
BEGIN
    DECLARE @p2_bad int = 0;
    IF ISNULL(@SelesOrSRDocPrefix,0) = 15
    BEGIN
        IF (@Status = 1 OR @Status = 3 OR @Status = 5)
        BEGIN
            UPDATE PI SET ActualQty = ISNULL(PI.ActualQty,0) + D.Qty, InvoiceQty = ISNULL(PI.InvoiceQty,0) - D.Qty
            FROM tblProductInventory PI
            JOIN (SELECT InventoryId, SUM(ISNULL(CAST(AdjustQty AS DECIMAL(25,6)),0)) AS Qty FROM tblTranSalesDetail
                  WHERE InvID=@InvId AND ISNULL(InventoryId,0)>0 AND QtyType = 1 GROUP BY InventoryId) D ON PI.InventoryId = D.InventoryId;
            UPDATE PI SET ActualFreeQty = ISNULL(PI.ActualFreeQty,0) + D.Qty, InvoiceFreeQty = ISNULL(PI.InvoiceFreeQty,0) - D.Qty
            FROM tblProductInventory PI
            JOIN (SELECT InventoryId, SUM(ISNULL(CAST(AdjustQty AS DECIMAL(25,6)),0)) AS Qty FROM tblTranSalesDetail
                  WHERE InvID=@InvId AND ISNULL(InventoryId,0)>0 AND QtyType = 2 GROUP BY InventoryId) D ON PI.InventoryId = D.InventoryId;
        END
        ELSE IF EXISTS (SELECT 1 FROM tblTranSalesDetail WHERE InvID=@InvId AND ISNULL(InventoryId,0)>0 AND AdjustQty <> 0)
            SET @p2_bad = 1;
    END
    ELSE IF @Status = 6
    BEGIN
        IF EXISTS (SELECT 1
                   FROM (SELECT InventoryId, QtyType, SUM(CAST(AdjustQty AS DECIMAL(25,6))) AS Qty FROM tblTranSalesDetail
                         WHERE InvID=@InvId AND ISNULL(InventoryId,0)>0 GROUP BY InventoryId, QtyType) D
                   LEFT JOIN tblProductInventory PI ON PI.InventoryId = D.InventoryId
                   WHERE D.Qty > ISNULL(CASE D.QtyType WHEN 1 THEN PI.ActualQty ELSE PI.ActualFreeQty END, 0))
            SET @p2_bad = 1;
        ELSE
        BEGIN
            UPDATE PI SET ActualQty = ISNULL(PI.ActualQty,0) - D.Qty, SRQty = ISNULL(PI.SRQty,0) - D.Qty, RecdQty = ISNULL(PI.RecdQty,0) - D.Qty
            FROM tblProductInventory PI
            JOIN (SELECT InventoryId, SUM(CAST(AdjustQty AS DECIMAL(25,6))) AS Qty FROM tblTranSalesDetail
                  WHERE InvID=@InvId AND ISNULL(InventoryId,0)>0 AND QtyType = 1 GROUP BY InventoryId) D ON PI.InventoryId = D.InventoryId;
            UPDATE PI SET ActualFreeQty = ISNULL(PI.ActualFreeQty,0) - D.Qty, SRFreeQty = ISNULL(PI.SRFreeQty,0) - D.Qty, RecdFreeQty = ISNULL(PI.RecdFreeQty,0) - D.Qty
            FROM tblProductInventory PI
            JOIN (SELECT InventoryId, SUM(CAST(AdjustQty AS DECIMAL(25,6))) AS Qty FROM tblTranSalesDetail
                  WHERE InvID=@InvId AND ISNULL(InventoryId,0)>0 AND QtyType = 2 GROUP BY InventoryId) D ON PI.InventoryId = D.InventoryId;
        END
    END
    ELSE -- @Status = 7: damage return, every line comes out of the damaged stock
    BEGIN
        IF EXISTS (SELECT 1
                   FROM (SELECT InventoryId, SUM(CAST(AdjustQty AS DECIMAL(25,6))) AS Qty FROM tblTranSalesDetail
                         WHERE InvID=@InvId AND ISNULL(InventoryId,0)>0 GROUP BY InventoryId) D
                   LEFT JOIN tblProductInventory PI ON PI.InventoryId = D.InventoryId
                   WHERE D.Qty > ISNULL(PI.ActualDmgQty, 0))
            SET @p2_bad = 1;
        ELSE
            UPDATE PI SET ActualDmgQty = ISNULL(PI.ActualDmgQty,0) - D.Qty, SRDmgQty = ISNULL(PI.SRDmgQty,0) - D.Qty, RecdDmgQty = ISNULL(PI.RecdDmgQty,0) - D.Qty
            FROM tblProductInventory PI
            JOIN (SELECT InventoryId, SUM(CAST(AdjustQty AS DECIMAL(25,6))) AS Qty FROM tblTranSalesDetail
                  WHERE InvID=@InvId AND ISNULL(InventoryId,0)>0 GROUP BY InventoryId) D ON PI.InventoryId = D.InventoryId;
    END
    IF @p2_bad = 1 RAISERROR('Quantity mismatched',16,1);
END
ELSE
BEGIN /*p2:07 original cursor, used for the cases above*/
DECLARE CursorCancelSR CURSOR
FOR (SELECT InventoryId ,QtyType ,AdjustQty FROM tblTranSalesDetail WHERE InvID=@InvId AND ISNULL(InventoryId ,0)>0 )                  
DECLARE @CancelQty DECIMAL(25,6),@CancelQtyT INT,@CancelInvId INT                  
OPEN CursorCancelSR                  
FETCH NEXT FROM CursorCancelSR INTO @CancelInvId,@CancelQtyT,@CancelQty                  
WHILE @@FETCH_STATUS =0         
BEGIN /*All Record loop and verify based on Invoice Id*/                  
                  
IF ISNULL(@SelesOrSRDocPrefix,0)=15                  
BEGIN                  
IF(@Status =1 OR @Status =3 OR @Status =5)                  
BEGIN /*Sales Invoice Cancel Update*/                  
IF(@CancelQtyT =1)                  
BEGIN                  
UPDATE tblProductInventory SET ActualQty =ISNULL(ActualQty,0)+ISNULL(@CancelQty,0),InvoiceQty = ISNULL(InvoiceQty,0)-ISNULL(@CancelQty,0) WHERE InventoryId =@CancelInvId                  
END                  
IF(@CancelQtyT =2)                  
BEGIN                  
UPDATE tblProductInventory SET ActualFreeQty =ISNULL(ActualFreeQty,0)+ISNULL(@CancelQty,0),InvoiceFreeQty = ISNULL(InvoiceFreeQty,0)-ISNULL(@CancelQty,0) WHERE InventoryId =@CancelInvId                  
END                  
SET @CancelQty=0                  
END                  
END                  
ELSE                  
BEGIN                  
IF(@Status=6 OR @Status=3)                  
BEGIN /*Sales Return Saleable Cancel*/                  
PRINT CONVERT(NVARCHAR(255),@CancelInvId)                  
IF(@CancelQtyT =1)                  
BEGIN                  
IF(@CancelQty<= ISNULL((SELECT ActualQty FROM tblProductInventory WHERE InventoryId= @CancelInvId),0))                  
BEGIN                  
UPDATE tblProductInventory SET ActualQty=ISNULL(ActualQty,0)-ISNULL(@CancelQty,0),SRQty =ISNULL(SRQty,0) -ISNULL(@CancelQty,0),                  
RecdQty =ISNULL(RecdQty,0) -ISNULL(@CancelQty,0)                  
WHERE InventoryId=@CancelInvId                  
SET @CancelQty=0                  
END                  
END                  
IF(@CancelQtyT =2)                  
BEGIN                  
IF(@CancelQty<= ISNULL((SELECT ActualFreeQty FROM tblProductInventory WHERE InventoryId= @CancelInvId),0))                  
BEGIN UPDATE tblProductInventory SET ActualFreeQty=ISNULL(ActualFreeQty,0)-ISNULL(@CancelQty,0),SRFreeQty =ISNULL(SRFreeQty,0)-ISNULL(@CancelQty,0),                  
RecdFreeQty =ISNULL(RecdFreeQty,0) -ISNULL(@CancelQty,0)                  
WHERE InventoryId=@CancelInvId                  
SET @CancelQty=0                  
END                  
END                  
END                  
IF(@Status =7 OR @Status=3)                  
BEGIN /* Sales Return Damage Cancel */                  
IF(@CancelQty<= ISNULL((SELECT ActualDmgQty FROM tblProductInventory WHERE InventoryId= @CancelInvId),0))                  
BEGIN                  
UPDATE tblProductInventory SET ActualDmgQty=ISNULL(ActualDmgQty,0)-ISNULL(@CancelQty,0),SRDmgQty =ISNULL(SRDmgQty,0)-ISNULL(@CancelQty,0),                  
RecdDmgQty =ISNULL(RecdDmgQty,0) -ISNULL(@CancelQty,0)                  
WHERE InventoryId=@CancelInvId                  
SET @CancelQty=0                  
END                  
END                  
END                  
IF(@CancelQty!=0)                  
BEGIN /* Any one Qty miss matched Revert */                  
CLOSE CursorCancelSR                  
DEALLOCATE CursorCancelSR                  
RAISERROR('Quantity mismatched',16,1);                  
END                  
FETCH NEXT FROM CursorCancelSR INTO @CancelInvId,@CancelQtyT,@CancelQty                  
END                  
CLOSE CursorCancelSR
DEALLOCATE CursorCancelSR
END /*p2:07 end of original cursor*/
END
--Update Mode Wise Modify OR cancel                  
IF(@Mode=2)                  
BEGIN /*Sales Header Table Status Change Modify(3)*/                  
UPDATE tblTranSalesHeader SET [Status]=2,MBy =@UID ,MDate =GETDATE () WHERE Id=@InvId                  
END                  
/*Sales Header Table Status Change Cancel(4)*/                  
IF(@Mode=4 OR @Mode=5)                  
BEGIN                  
                  
IF ISNULL(@Mode,0)=4                  
BEGIN          
--Revert Track Point when Cancel          
declare @nTPMode int = (case when @nDocPrefix = 15 then 2 else 1 end)          
EXEC [uspAddTrackPoint] @OldNetAmt,@nTPMode,@CustId          
UPDATE tblTranSalesHeader SET [Status]=4,ClBy=@UID,ClDate=GETDATE() ,Remarks = @Remarks,Narration = @Narration                 
WHERE Id=@InvId                  
END                  
ELSE                  
BEGIN                  
UPDATE tblTranSalesHeader SET [Status]=2,MBy=@UID,MDate=GETDATE()                 
WHERE Id=@InvId                  
END                  
--cancel denomination                  
DECLARE @Paymode INT                  
SET @Paymode=(SELECT PaymentModeId FROM tblTranSalesHeader WHERE Id=@InvId)                  
--IF @Paymode=8                  
--BEGIN                  
--UPDATE tblmastdenominationPMDetails                  
--SET [Status]=4,Cby =@UID ,Cdate =GETDATE ()                  
--WHERE TransID=@InvId and FormDocPrefix=@SelesOrSRDocPrefix                  
--END                  
END                  
                  
--Invoice or Sales Return Posting Status Change Cancel(4)                  
IF ISNULL(@Mode,0)!=5                  
BEGIN                  
UPDATE tblFAJournal SET [Status]= @Mode,ClBy =@UID ,ClDate=GETDATE(),Remarks = @Remarks,Narration = @Narration                  
WHERE TransId=@InvId AND DocPrefix =@SelesOrSRDocPrefix                  
END                  
ELSE                  
BEGIN                  
UPDATE tblFAJournal SET [Status]=2,MBy =@UID ,MDate =GETDATE()                  
WHERE TransId=@InvId AND DocPrefix =@SelesOrSRDocPrefix                  
END                  
END TRY                  
BEGIN CATCH                  
SELECT ERROR_MESSAGE() ,ERROR_PROCEDURE() ,ERROR_LINE();                  
END CATCH 

GO
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspManageTranSalesCancel')) LIKE N'%/*p2:07%' PRINT N'dbo.uspManageTranSalesCancel : changed';
GO
SET NOEXEC OFF;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
/* ===================================================================================== dbo.uspCancelCollection */
SET NOEXEC OFF;
GO
DECLARE @d nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspCancelCollection'));
IF @d IS NULL
BEGIN PRINT N'dbo.uspCancelCollection : not found - skipped'; SET NOEXEC ON; END
ELSE IF @d LIKE N'%/*p2:07%'
BEGIN PRINT N'dbo.uspCancelCollection : already applied'; SET NOEXEC ON; END
ELSE IF HASHBYTES('SHA2_256', @d) <> 0x2340B0A1B16BC19DE6CF3998D5C6FAAAABC4B2F395A266BBC7ED18F576F89D68
BEGIN PRINT N'dbo.uspCancelCollection : SKIPPED - this database has a different version of the procedure than the one this script was written for'; SET NOEXEC ON; END
ELSE
BEGIN
    INSERT dbo.DbaProcBackup (ProcName, Script, UsesAnsiNulls, UsesQuotedIdentifier, Definition)
    SELECT N'uspCancelCollection', '07', uses_ansi_nulls, uses_quoted_identifier, definition FROM sys.sql_modules WHERE object_id = OBJECT_ID(N'dbo.uspCancelCollection');
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
ALTER PROC [dbo].[uspCancelCollection]          
@TranDocPrefix INT,@CollID INT,@UID INT,@AllowNegativeBal INT = NULL,@nStatus INT =null,@Remark nvarchar(255) = null,@Narration nvarchar(255) = null          
AS          
BEGIN TRANSACTION          
BEGIN TRY          
DECLARE @PartyAcc INT, @ExpanceAcc INT,@AccCount INT,@AccountName NVARCHAR(255),          
@TempPaymentMode INT,@TempRecdAmt DECIMAL (25,6),          
@TempDocStatus INT,@PaymentModeStatus INT,@AccID INT,@ExpanceAccID INT          
-- Checking For Amount MissMatch          
DECLARE @RecdAmt DECIMAL (25,6),@BalanceAmt DECIMAL (25,6)          
DECLARE @AdjustedAmt DECIMAL (25,6),@AdjustmentAmt DECIMAL (25,6),@CollType INT,@DocExtraAdjustedAmt DECIMAL (25,6),@nCurrentStatus INT          
SET @nCurrentStatus = (CASE WHEN @TranDocPrefix IN (19,10) THEN (SELECT top 1 Status FROM tblTranCollectionHeader WHERE ColID = @CollID)          
WHEN @TranDocPrefix IN (18,11) THEN (SELECT top 1 Status FROM tblTranPaymentHeader WHERE PYID = @CollID) END)          
--SELECT * FROM tblMastDocSeries          
--SELECT * FROM tblTranCollectionHeader order by 1 desc          
--SELECT * FROM tblTranPaymentHeader order by 1 desc          
IF(isnull(@nStatus,0) = isnull(@nCurrentStatus,0))          
BEGIn          
IF @TranDocPrefix = 19          
BEGIn          
IF ISNULL((SELECT COUNT(ColID) FROM tblTranCollectionHeader WHERE ColID=@CollID AND Type=1),0)>0          
BEGIN          
RAISERROR('TYPE',16,1);          
END          
END          
CREATE TABLE #Temp(ID int identity ,CollID int,DocPrefix INT,DocValue INT, IdentID int, ColValue DECIMAL (25,6))          
IF @TranDocPrefix=19 OR @TranDocPrefix=10          
BEGIn          
SET @TempDocStatus=(SELECT [Status] FROM tblTranCollectionHeader where ColID = @CollID)          
SELECT @PaymentModeStatus=(SELECT [Status] FROM tblCollPMDetails where ColID = @CollID)          
          
          
SELECT @PartyAcc=AccID,@ExpanceAcc=ExpanceAcc,@TempPaymentMode=ColMode,@TempRecdAmt=ColAmt FROM tblTranCollectionHeader where ColID = @CollID          
          
          
-- Check Cash Acc Balance          
DECLARE @PYModeAmt DECIMAL (25,6),@PYFAType NVARCHAR(10),@CashBankAccID INT,@CurrentDate DATE=(SELECT GETDATE())          
DECLARE @PYOutputValue TABLE (Amt DECIMAL(25,6),FAType NVARCHAR(10)) --18.9          
IF ISNULL(@TempPaymentMode,0)=1          
BEGIn          
SET @CashBankAccID = (SELECT FAID FROM tblFAAccount WHERE AccountName='cash')          
INSERT INTO @PYOutputValue(Amt,FAType) EXEC uspLoadClosingBalance 1,@CashBankAccID,@CurrentDate          
-- Get Value From Result          
SELECT @PYModeAmt=Amt,@PYFAType=FAType FROM @PYOutputValue          
IF @PYFAType='Cr' OR @PYModeAmt<@TempRecdAmt          
BEGIN          
IF ISNULL(@AllowNegativeBal,0)=0          
BEGIN          
RAISERROR('Bal',16,1)          
END          
END          
END          
-- Check Bank Acc Balance          
IF ISNULL(@TempPaymentMode,0)=4          
BEGIN          
SELECT @CashBankAccID=BankAccID FROM tblTranCollectionHeader AS Header          
JOIN tblCollPMDetails AS PM          
ON Header.ColID=PM.ColID          
WHERE Header.ColID=@CollID          
INSERT INTO @PYOutputValue(Amt,FAType) EXEC uspLoadClosingBalance 1,@CashBankAccID,@CurrentDate          
-- Get Value From Result          
SELECT @PYModeAmt=Amt,@PYFAType=FAType FROM @PYOutputValue          
IF @PYFAType='Cr' OR @PYModeAmt<@TempRecdAmt          
BEGIN          
IF ISNULL(@AllowNegativeBal,0)=0          
BEGIN          
RAISERROR('Bal',16,1)          
END          
END          
END          
-- Check Coupon Cancelling          
--IF ISNULL(@TempPaymentMode,0)=6          
--BEGIN          
--DECLARE @tempActualCount INT,@SettledCount INT          
--SELECT @tempActualCount=ISNULL(SUM(DCount),0),@SettledCount=ISNULL(SUM(SettlementCount),0)          
--FROM tblmasterdenominationPMDetails WHERE FormDocPrefix=@TranDocPrefix AND TransID=@CollID          
--IF @tempActualCount=@SettledCount          
--BEGIN          
--UPDATE tblmasterdenominationPMDetails SET Status=4 WHERE FormDocPrefix=@TranDocPrefix AND TransID=@CollID          
--END          
--ELSE          
--BEGIN          
--RAISERROR('SETTLED',16,1)          
--END          
--END          
          
IF @TranDocPrefix=19          
BEGIN          
--SELECT * FROM tblDocumentSeries     
--Collection          
-- Get Recd Amt And Balance Amt          
SELECT @RecdAmt=ISNULL(ColAmt,0),@BalanceAmt=ISNULL(Balance,0) FROM tblTranCollectionHeader WHERE ColID=@CollID          
--SELECT * FROM tblTranCollectionHeader WHERE ColID=2899          
--Get Adjusted Amt          
SELECT @AdjustedAmt=ISNULL(SUM(ColValue),0) FROM tblTranCollectionDetail WHERE ColID=@CollID AND DocPrefix IN(4,6,19,16,10)          
--SELECT ISNULL(SUM(ColValue),0) FROM tblTranCollectionDetail WHERE ColID=2899 AND DocPrefix IN(3,5,6)          
--Get AdjustMent Amt          
SELECT @AdjustmentAmt=ISNULL(SUM(ColValue),0) FROM tblTranCollectionDetail WHERE ColID=@CollID AND DocPrefix IN (15,5,7)          
--SELECT ISNULL(SUM(ColValue),0) FROM tblTranCollectionDetail WHERE ColID=2899 AND DocPrefix IN(2,16,29)          
-- Get Adjusted amt          
SELECT @DocExtraAdjustedAmt=ISNULL(SUM(AdjAmt),0) FROM tblTranCollectionDetail WHERE ColID=@CollID AND DocPrefix IN (15,5,7)          
--GROUP BY AdjAmt HAVING ISNULL(AdjAmt,0)>0          
AND AdjAmt > 0          
--SELECT ISNULL(SUM(AdjAmt),0) FROM tblTranCollectionDetail WHERE ColID=2899 AND DocPrefix IN(2,16,29) AND AdjAmt > 0          
--select * from tblMastDocSeries where DocID in (2,3,5,6,16,29)          
-------------------          
IF ISNULL((@RecdAmt+@AdjustedAmt),0)!=ISNULL((@BalanceAmt+@AdjustmentAmt+ISNULL(@DocExtraAdjustedAmt,0)),0)          
BEGIN          
RAISERROR('PROC',16,1)          
END          
END          
          
IF @TranDocPrefix=10          
BEGIN          
--Other Collection          
-- Get Recd Amt And Balance Amt          
SELECT @RecdAmt=ISNULL(ColAmt,0),@BalanceAmt=ISNULL(Balance,0),@CollType=COLLType FROM tblTranCollectionHeader WHERE ColID=@CollID          
--Get Adjusted Amt          
SELECT @AdjustedAmt=ISNULL(SUM(ColValue),0) FROM tblTranCollectionDetail WHERE ColID=@CollID AND DocPrefix IN(4,19,10,6)          
--Get AdjustMent Amt          
SELECT @AdjustmentAmt=ISNULL(SUM(ColValue),0) FROM tblTranCollectionDetail WHERE ColID=@CollID AND DocPrefix IN(5,18,7,11)          
-- Get Adjusted amt          
SELECT @DocExtraAdjustedAmt=ISNULL(SUM(AdjAmt),0) FROM tblTranCollectionDetail WHERE ColID=@CollID AND DocPrefix IN(8,18,7,11)          
--GROUP BY AdjAmt HAVING          
AND AdjAmt>0          
IF ISNULL(@CollType,0)!=2 AND ISNULL(@CollType,0)!=3          
BEGIN          
IF ISNULL((@RecdAmt+@AdjustedAmt),0)!=ISNULL((@BalanceAmt+@AdjustmentAmt+ISNULL(@DocExtraAdjustedAmt,0)),0)          
BEGIN          
RAISERROR('PROC',16,1)          
END          
END          
END          
IF @TempDocStatus=1 OR @TempDocStatus=3          
BEGIn          
IF ISNULL(@PaymentModeStatus,0)=0 OR @PaymentModeStatus=1 OR @PaymentModeStatus=3          
BEGIN          
UPDATE dbo.tblTranCollectionHeader set [Status] = 4,ClBy=@UID,ClDate=GETDATE(),Remarks = @Remark,Narration = @Narration where ColID = @CollID          
UPDATE dbo.tblCollPMDetails SET [Status]=4 WHERE ColID = @CollID          
INSERT INTO #Temp SELECT ColID,DocPrefix,DocValue ,DocID,TotalAmtAdj from dbo.tblTranCollectionDetail where ColID = @CollID          
END          
ELSE          
BEGIN          
RAISERROR('PAYMENT',16,1)          
END          
ENd          
ELSE          
BEGIN          
RAISERROR('CANCELLED',16,1)          
END          
END          
IF @TranDocPrefix=11 OR @TranDocPrefix=18          
BEGIN          
SET @TempDocStatus=(SELECT [Status] FROM tblTranPaymentHeader where PYID = @CollID)          
SET @PaymentModeStatus=(SELECT [Status] FROM tblPaymentPMDetail where PYID = @CollID)          
SELECT @PartyAcc=AccID,@ExpanceAcc=ExpanseAcc,@TempPaymentMode=PYMode FROM tblTranPaymentHeader where PYID = @CollID          
          
--IF ISNULL(@TempPaymentMode,0)=6          
--BEGIN          
--DECLARE @tempCancelSettled TABLE (D_ID INT,DenoID INT,StlCount INT)          
--INSERT INTO @tempCancelSettled          
--SELECT DID,DenoID,StlCount FROM tblSettlementDetailforCoupon          
--WHERE TrnDocPrefix=@TranDocPrefix AND STMID=@CollID AND Status=1 AND TransType=1          
          
--IF ISNULL((SELECT COUNT(*) FROM @tempCancelSettled),0)>0          
--BEGIN          
--UPDATE tblmastdenominationPMDetails SET SettlementCount = (SettlementCount+Temp.StlCount),Status=1          
--FROM @tempCancelSettled AS Temp          
--WHERE tblmastdenominationPMDetails.DId = Temp.D_ID AND tblmastdenominationPMDetails.DenoID = Temp.DenoID          
--UPDATE tblSettlementDetailforCoupon SET Status=4 WHERE TrnDocPrefix=@TranDocPrefix AND STMID=@CollID AND TransType=1          
--END          
--END          
          
IF @TranDocPrefix=18          
BEGIN          
--SELECT * FROM tblDocumentSeries WHERE TransID IN(5,18,12)      
--Payment          
-- Get Recd Amt And Balance Amt          
SELECT @RecdAmt=ISNULL(PYAmt,0),@BalanceAmt=ISNULL(Balance,0) FROM tblTranPaymentHeader WHERE PYID=@CollID          
--Get Adjusted Amt          
SELECT @AdjustedAmt=ISNULL(SUM(BillPYValue),0) FROM tblTranPaymentDetail WHERE PYID=@CollID AND DocPrefix IN (5,18,11,12)          
--Get AdjustMent Amt          
SELECT @AdjustmentAmt=ISNULL(SUM(BillPYValue),0) FROM tblTranPaymentDetail WHERE PYID=@CollID AND DocPrefix IN (1,4,6)          
-- Get Adjusted amt          
SELECT @DocExtraAdjustedAmt=ISNULL(SUM(AdjAmt),0) FROM tblTranPaymentDetail WHERE PYID=@CollID AND DocPrefix IN (1,4,6)          
--GROUP BY AdjAmt HAVING          
AND AdjAmt>0          
IF ISNULL((@RecdAmt+@AdjustedAmt),0)!=ISNULL((@BalanceAmt+@AdjustmentAmt+ISNULL(@DocExtraAdjustedAmt,0)),0)          
BEGIN          
RAISERROR('PROC',16,1)          
END          
END          
IF @TranDocPrefix=11          
BEGIN          
--Other Payment          
-- Get Recd Amt And Balance Amt          
SELECT @RecdAmt=ISNULL(PYAmt,0),@BalanceAmt=ISNULL(Balance,0),@CollType=PYType FROM tblTranPaymentHeader WHERE PYID=@CollID          
--Get Adjusted Amt          
SELECT @AdjustedAmt=ISNULL(SUM(BillPYValue),0) FROM tblTranPaymentDetail WHERE PYID=@CollID AND DocPrefix IN(5,18,7,11)          
--Get AdjustMent Amt          
SELECT @AdjustmentAmt=ISNULL(SUM(BillPYValue),0) FROM tblTranPaymentDetail WHERE PYID=@CollID AND DocPrefix IN(4,19,10,6)          
-- Get Adjusted amt          
SELECT @DocExtraAdjustedAmt=ISNULL(SUM(AdjAmt),0) FROM tblTranPaymentDetail WHERE PYID=@CollID AND DocPrefix IN(4,19,10,6)          
--GROUP BY AdjAmt HAVING          
AND AdjAmt>0          
IF ISNULL(@CollType,0)!=2 AND ISNULL(@CollType,0)!=3          
BEGIN          
IF ISNULL((@RecdAmt+@AdjustedAmt),0)!=ISNULL((@BalanceAmt+@AdjustmentAmt+ISNULL(@DocExtraAdjustedAmt,0)          
),0)          
BEGIN          
RAISERROR('PROC',16,1)          
END          
END          
END          
          
IF @TempDocStatus=1 OR @TempDocStatus=3          
BEGIN          
IF ISNULL(@PaymentModeStatus,0)=0 OR @PaymentModeStatus=1 OR @PaymentModeStatus=3          
BEGIN          
          
UPDATE dbo.tblTranPaymentHeader set [Status] = 4,ClBy=@UID,ClDate=GETDATE(),Remarks = @Remark,Narration = @Narration where PYID = @CollID          
UPDATE dbo.tblPaymentPMDetail SET [Status]=4 WHERE PYID = @CollID          
DECLARE @PaymentModeID INT=(SELECT PYMode FROM tblTranPaymentHeader where PYID = @CollID )          
IF @PaymentModeID=2          
BEGIN          
-- Cancel Cheque Status          
DECLARE @BankFAAccID INT,@ChequeNo INT,@ChequeRefNoWithChequeNo NVARCHAR(50),@BankAccID INT,@RefNo NVARCHAR(50)          
DECLARE @ChequeBookID INT          
SELECT @BankFAAccID=BankAccID,@ChequeNo=[Cheque/DD Number],@ChequeRefNoWithChequeNo=ChequeRefNoWithChequeNo          
FROM tblPaymentPMDetail WHERE PYID = @CollID          
          
SET @BankAccID=(SELECT ID FROM tblMasterBankAccount WHERE FAID=@BankFAAccID)          
SET @RefNo=(SELECT SUBSTRING(@ChequeRefNoWithChequeNo,0,(SELECT CHARINDEX('-', @ChequeRefNoWithChequeNo))-1))          
SET @ChequeBookID=(SELECT ChequebookId FROM tblMasterChequeBook WHERE BankAccountID=@BankAccID AND ChequeBookreferNo=@RefNo)          
UPDATE tblMasterChequeBookDetail SET [Status]=4 WHERE ChequebookId=@ChequeBookID AND ChequeNo=@ChequeNo          
END          
          
INSERT INTO #Temp SELECT PYID,DocPrefix,DocValue ,DocID,TotalAmtAdj from dbo.tblTranPaymentDetail where PYID = @CollID          
END          
ELSE          
BEGIN          
RAISERROR('PAYMENT',16,1)        END          
END          
ELSE          
BEGIN          
RAISERROR('CANCELLED',16,1)          
END          
--END          
-- ELSE          
-- BEGIN          
--RAISERROR('PAYMENT',16,1)          
-- END          
END          
UPDATE tblFAJournal SET [Status]=4,ClBy=@UID,ClDate=GETDATE(),Remarks = @Remark where TransId = @CollID AND DocPrefix=@TranDocPrefix--,Narration = @Narration          
DECLARE @DetailCount int          
DECLARE @Count int          
SET @DetailCount = (SELECT COUNT(CollID) FROM #Temp)          
SET @Count = 1          
          
/*p2:07 set-based: the documents this collection/payment had adjusted get their balance back and
  their status recalculated with one UPDATE per document table instead of a loop per document.
  Same formulas and status rules as the loop below; the loop is still used if the same document
  appears twice in the adjustment list.*/
IF NOT EXISTS (SELECT 1 FROM (SELECT IdentID, CASE WHEN DocPrefix IN (19,10) THEN 1 WHEN DocPrefix IN (18,11) THEN 2 WHEN DocPrefix IN (15,16) THEN 3
                                                   WHEN DocPrefix IN (1,12) THEN 4 WHEN DocPrefix IN (4,5) THEN 5 WHEN DocPrefix IN (6,7) THEN 6 ELSE 0 END AS Cat
                              FROM #Temp) d
               WHERE d.Cat <> 0 GROUP BY d.IdentID, d.Cat HAVING COUNT(*) > 1)
BEGIN
    UPDATE H SET Balance = H.Balance + T.ColValue,
           [Status] = CASE WHEN (SELECT COUNT(X.DocValue) FROM dbo.tblTranCollectionHeader X WHERE X.DocValue = T.DocValue AND X.DocPrefix = T.DocPrefix
                                 AND (X.ColDate BETWEEN (SELECT F_SD FROM tblCompanyRegistration) AND (SELECT F_ED FROM tblCompanyRegistration))) = 1
                           THEN 1 ELSE 3 END
    FROM dbo.tblTranCollectionHeader H JOIN #Temp T ON H.ColID = T.IdentID
    WHERE T.DocPrefix IN (19,10);

    UPDATE H SET Balance = H.Balance + T.ColValue,
           [Status] = CASE WHEN (SELECT COUNT(X.DocValue) FROM dbo.tblTranPaymentHeader X WHERE X.DocValue = T.DocValue AND X.PYPrefix = T.DocPrefix
                                 AND (X.PYDate BETWEEN (SELECT F_SD FROM tblCompanyRegistration) AND (SELECT F_ED FROM tblCompanyRegistration))) = 1
                           THEN 1 ELSE 3 END
    FROM dbo.tblTranPaymentHeader H JOIN #Temp T ON H.PYID = T.IdentID
    WHERE T.DocPrefix IN (18,11);

    UPDATE H SET Balance = H.Balance + T.ColValue,
           [Status] = CASE WHEN (SELECT COUNT(X.DocValue) FROM dbo.tblTranSalesHeader X WHERE X.DocValue = T.DocValue AND X.DocPrefix = T.DocPrefix
                                 AND (X.InvDate BETWEEN (SELECT F_SD FROM tblCompanyRegistration) AND (SELECT F_ED FROM tblCompanyRegistration))) = 1
                           THEN CASE WHEN T.DocPrefix = 15 THEN 1
                                     WHEN H.TransactionType = 2 THEN 6     -- sales return
                                     WHEN H.TransactionType = 3 THEN 7     -- damage return
                                     ELSE H.[Status] END
                           ELSE 3 END
    FROM dbo.tblTranSalesHeader H JOIN #Temp T ON H.Id = T.IdentID
    WHERE T.DocPrefix IN (15,16);

    UPDATE H SET Balance = H.Balance + T.ColValue,
           [Status] = CASE WHEN (SELECT COUNT(X.DocValue) FROM dbo.tblTransPurchaseHeader X WHERE X.DocValue = T.DocValue AND X.TransID = T.DocPrefix
                                 AND (X.Date BETWEEN (SELECT F_SD FROM tblCompanyRegistration) AND (SELECT F_ED FROM tblCompanyRegistration))) = 1
                           THEN CASE WHEN T.DocPrefix = 1 THEN 1 ELSE 6 END
                           ELSE CASE WHEN T.DocPrefix = 1 THEN 3 ELSE 6 END END
    FROM dbo.tblTransPurchaseHeader H JOIN #Temp T ON H.ID = T.IdentID
    WHERE T.DocPrefix IN (1,12);

    UPDATE H SET Balance = H.Balance + T.ColValue,
           [Status] = CASE WHEN (SELECT COUNT(X.DocValue) FROM dbo.tblNoteDetails X WHERE X.DocValue = T.DocValue AND X.TransID = T.DocPrefix
                                 AND (X.DocDate BETWEEN (SELECT F_SD FROM tblCompanyRegistration) AND (SELECT F_ED FROM tblCompanyRegistration))) = 1
                           THEN 1 ELSE 3 END
    FROM dbo.tblNoteDetails H JOIN #Temp T ON H.ID = T.IdentID
    WHERE T.DocPrefix IN (4,5);

    UPDATE H SET Balance = H.Balance + T.ColValue,
           [Status] = CASE WHEN (SELECT COUNT(X.DocValue) FROM dbo.tblTranPRVoucher X WHERE X.DocValue = T.DocValue AND X.TransID = T.DocPrefix
                                 AND (X.DocDate BETWEEN (SELECT F_SD FROM tblCompanyRegistration) AND (SELECT F_ED FROM tblCompanyRegistration))) = 1
                           THEN 1 ELSE 3 END
    FROM dbo.tblTranPRVoucher H JOIN #Temp T ON H.ID = T.IdentID
    WHERE T.DocPrefix IN (6,7);
END
ELSE
WHILE (@Count <= @DetailCount)
BEGIN
CREATE TABLE #TEMP2 (DocValue INT)          
DECLARE @TempID INT,@TempAmt DECIMAL (25,6),@DocValue INT,@DocPrefix INT ,@DocCount INT          
SET @TempID = (SELECT IdentID FROM #Temp WHERE ID = @Count)          
SET @TempAmt = (SELECT ColValue FROM #Temp WHERE ID = @Count)          
SET @DocValue = (SELECT DocValue FROM #Temp WHERE ID = @Count)          
SET @DocPrefix = (SELECT DocPrefix FROM #Temp WHERE ID = @Count)          
          
IF @DocPrefix=19 OR @DocPrefix=10          
BEGIN          
UPDATE dbo.tblTranCollectionHeader SET Balance = Balance+@TempAmt WHERE ColID = @TempID          
          
INSERT INTO #TEMP2 SELECT DocValue FROM dbo.tblTranCollectionHeader WHERE DocValue = @DocValue AND DocPrefix=@DocPrefix          
AND (ColDate BETWEEN (SELECT F_SD FROM tblCompanyRegistration) AND (SELECT F_ED FROM tblCompanyRegistration))          
SET @DocCount = (SELECT COUNT(DocValue) FROM #TEMP2)          
IF(@DocCount = 1)          
BEGIN          
UPDATE dbo.tblTranCollectionHeader SET [Status] = 1 WHERE ColID = @TempID          
END          
ELSE          
BEGIN          
UPDATE dbo.tblTranCollectionHeader SET [Status] = 3 WHERE ColID = @TempID          
END          
END          
          
IF @DocPrefix=18 OR @DocPrefix=11          
BEGIN          
UPDATE dbo.tblTranPaymentHeader SET Balance = Balance+@TempAmt WHERE PYID = @TempID          
          
INSERT INTO #TEMP2 SELECT DocValue FROM dbo.tblTranPaymentHeader WHERE DocValue = @DocValue AND PYPrefix=@DocPrefix          
AND (PYDate BETWEEN (SELECT F_SD FROM tblCompanyRegistration) AND (SELECT F_ED FROM tblCompanyRegistration))          
SET @DocCount = (SELECT COUNT(DocValue) FROM #TEMP2)          
IF(@DocCount = 1)          
BEGIN          
UPDATE dbo.tblTranPaymentHeader SET [Status] = 1 WHERE PYID = @TempID          
END          
ELSE          
BEGIN          
UPDATE dbo.tblTranPaymentHeader SET [Status] = 3 WHERE PYID = @TempID          
END          
END          
          
IF @DocPrefix=15 OR @DocPrefix=16          
BEGIN          
UPDATE dbo.tblTranSalesHeader SET Balance = Balance+@TempAmt WHERE Id = @TempID          
INSERT INTO #TEMP2 SELECT DocValue FROM dbo.tblTranSalesHeader WHERE DocValue = @DocValue AND DocPrefix=@DocPrefix          
AND (InvDate BETWEEN (SELECT F_SD FROM tblCompanyRegistration) AND (SELECT F_ED FROM tblCompanyRegistration))          
SET @DocCount = (SELECT COUNT(DocValue) FROM #TEMP2)          
IF(@DocCount = 1)          
BEGIN          
IF @DocPrefix=15          
BEGIN          
UPDATE dbo.tblTranSalesHeader SET [Status] = 1 WHERE Id = @TempID          
END          
IF @DocPrefix=16          
BEGIN          
DECLARE @Type INT          
SELECT @Type=TransactionType FROM tblTranSalesHeader WHERE Id=@TempID          
-- Change document to Sales Return If Type=2          
IF @Type=2          
BEGIN          
UPDATE dbo.tblTranSalesHeader SET [Status] = 6 WHERE Id = @TempID          
END          
-- Change document to Damage Return If Type=2          
IF @Type=3          
BEGIN          
UPDATE dbo.tblTranSalesHeader SET [Status] = 7 WHERE Id = @TempID          
END          
END          
END          
ELSE          
BEGIN          
UPDATE dbo.tblTranSalesHeader SET [Status] = 3 WHERE Id = @TempID          
END          
END          
IF @DocPrefix=1 OR @DocPrefix=12          
BEGIN          
UPDATE dbo.tblTransPurchaseHeader SET Balance = Balance+@TempAmt WHERE ID = @TempID          
          
INSERT INTO #TEMP2 SELECT DocValue FROM dbo.tblTransPurchaseHeader WHERE DocValue = @DocValue AND TransID=@DocPrefix          
AND (Date BETWEEN (SELECT F_SD FROM tblCompanyRegistration) AND (SELECT F_ED FROM tblCompanyRegistration))          
SET @DocCount = (SELECT COUNT(DocValue) FROM #TEMP2)          
IF(@DocCount = 1)          
BEGIN          
IF @DocPrefix=1          
BEGIN          
UPDATE dbo.tblTransPurchaseHeader SET [Status] = 1 WHERE ID = @TempID          
END          
IF @DocPrefix=12          
BEGIN          
UPDATE dbo.tblTransPurchaseHeader SET [Status] = 6 WHERE ID = @TempID          
END          
END          
ELSE          
BEGIN          
IF @DocPrefix=1          
BEGIN          
UPDATE dbo.tblTransPurchaseHeader SET [Status] = 3 WHERE ID = @TempID          
END          
IF @DocPrefix=12          
BEGIN          
UPDATE dbo.tblTransPurchaseHeader SET [Status] = 6 WHERE ID = @TempID          
END          
END          
END          
          
IF @DocPrefix=4 OR @DocPrefix=5          
BEGIN          
UPDATE dbo.tblNoteDetails SET Balance = Balance+@TempAmt WHERE ID = @TempID          
          
INSERT INTO #TEMP2   
SELECT DocValue FROM dbo.tblNoteDetails WHERE DocValue = @DocValue AND TransID=@DocPrefix          
AND (DocDate BETWEEN (SELECT F_SD FROM tblCompanyRegistration) AND (SELECT F_ED FROM tblCompanyRegistration))          
SET @DocCount = (SELECT COUNT(DocValue) FROM #TEMP2)    
  
UPDATE dbo.tblNoteDetails SET [Status] = (CASE WHEN (@DocCount = 1) THEN 1 ELSE 3 END) WHERE ID = @TempID          
END          
          
IF @DocPrefix=6 OR @DocPrefix=7          
BEGIN          
UPDATE dbo.tblTranPRVoucher SET Balance = Balance+@TempAmt WHERE ID = @TempID          
          
INSERT INTO #TEMP2 SELECT DocValue FROM dbo.tblTranPRVoucher WHERE DocValue = @DocValue AND TransID=@DocPrefix          
AND (DocDate BETWEEN (SELECT F_SD FROM tblCompanyRegistration) AND (SELECT F_ED FROM tblCompanyRegistration))          
SET @DocCount = (SELECT COUNT(DocValue) FROM #TEMP2)          
UPDATE dbo.tblTranPRVoucher SET [Status] = (CASE WHEN (@DocCount = 1) THEN 1 ELSE 3 END) WHERE ID = @TempID          
END          
          
SET @Count = @Count+1          
DROP TABLE #TEMP2          
END          
DROP TABLE #Temp          
END          
ELSE          
BEGIN          
RAISERROR('This document already processed',16,1);          
END          
COMMIT TRANSACTION          
END TRy          
BEGIN CATCH          
ROLLBACK TRANSACTION          
SELECT ERROR_MESSAGE(),ERROR_LINE(),ERROR_PROCEDURE()          
END CATCH 

GO
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspCancelCollection')) LIKE N'%/*p2:07%' PRINT N'dbo.uspCancelCollection : changed';
GO
SET NOEXEC OFF;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
/* ===================================================================================== dbo.uspManageTranSalesColl */
SET NOEXEC OFF;
GO
DECLARE @d nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspManageTranSalesColl'));
IF @d IS NULL
BEGIN PRINT N'dbo.uspManageTranSalesColl : not found - skipped'; SET NOEXEC ON; END
ELSE IF @d LIKE N'%/*p2:07%'
BEGIN PRINT N'dbo.uspManageTranSalesColl : already applied'; SET NOEXEC ON; END
ELSE IF HASHBYTES('SHA2_256', @d) <> 0x6F2A1645F9249B7D52697126BE8E8F0FC0E1453E329BF0BA5426417E8CF08D29
BEGIN PRINT N'dbo.uspManageTranSalesColl : SKIPPED - this database has a different version of the procedure than the one this script was written for'; SET NOEXEC ON; END
ELSE
BEGIN
    INSERT dbo.DbaProcBackup (ProcName, Script, UsesAnsiNulls, UsesQuotedIdentifier, Definition)
    SELECT N'uspManageTranSalesColl', '07', uses_ansi_nulls, uses_quoted_identifier, definition FROM sys.sql_modules WHERE object_id = OBJECT_ID(N'dbo.uspManageTranSalesColl');
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
ALTER PROC [dbo].[uspManageTranSalesColl]    
@UID INT,@InvId INT,@tvpAdjInvCrNote tvpAdjInvCrNote READONLY,@tvpTranSalesMop tvpTranSalesMop READONLY,    
@BeatID INT=NULL,@SalesManID INT=NULL,@tvpSaveDenomination dbo.tvpSaveDenomination READONLY,@BranchID int
AS    
BEGIN TRY    
SET DATEFORMAT DMY;    
SET NOCOUNT ON;    
--Declaration of variable    
DECLARE @CustId INT,@Accid INT,@PaymentModeId INT,@CrAdjCount INT,@Index INT,@InvDate DATE,@DocRef NVARCHAR(255),@DocId NVARCHAR(255),    
@DocValue INT,@NoteId INT,@CrDocPrefix INT,@CrDocValue INT ,@CrDate NVARCHAR(25),@CrAdjAmt DECIMAL (25,6),@ActiveCheck INT,    
@TotalNetAmt DECIMAL (25,6),@TCrNoteAdjValue DECIMAL (25,6)    
--Get Invoice Details    
SELECT @CustId=CustId,@PaymentModeId=PaymentModeId,@InvDate=InvDate,@DocRef=DocRef,@DocId=DocId,    
@DocValue=DocValue,@TCrNoteAdjValue=CreditNoteAdjAmt,@TotalNetAmt=NetAmt    
FROM tblTranSalesHeader WHERE Id =@InvId    
--Get Customer Account Id    
SELECT @Accid=FAID FROM tblMasterCustomer WHERE ID =@CustId    
SET @CrAdjCount=(SELECT COUNT(*) FROM @tvpAdjInvCrNote)    
DECLARE @Header tvpCollHeader,@Detail tvpCollDetail,@Mop tvpCollMop    
--IF PaymentMode Credit but Adjusted Credit Note or Sales Return    
IF (@PaymentModeId = 7 AND ISNULL(@CrAdjCount,0)>0)    
BEGIN    
--IF Credit Adjust Amt their is Payment Mode store in 9    
IF ISNULL(@CrAdjCount,0)>0    
BEGIN    
SET @PaymentModeId =9    
END    
--Collection Header    
INSERT INTO @Header VALUES(CONVERT(NVARCHAR(50),@InvDate,103),1,@DocRef ,@Accid,0 ,0,@PaymentModeId,1,0,@UID,1,1,null,null)    
--Collection Detail    
INSERT INTO @Detail VALUES(@Accid,15,@DocValue, @InvId,@InvDate,ISNULL(@TotalNetAmt,0),    
ISNULL(@TCrNoteAdjValue,0),0,0,0,0,0,ISNULL(@TCrNoteAdjValue,0),0,1,0)    
--Credit Note Adjustment    
IF ISNULL(@CrAdjCount,0) >0    
BEGIN    
/*p2:07 set-based: the adjusted credit notes are added with two INSERT ... SELECT instead of a cursor
  (same values and conversions: the note date is read as text of up to 25 characters, as before)*/
INSERT INTO @Detail
SELECT @Accid, A.DocPrefix, A.DocValue, A.NoteId, CONVERT(DATE, CAST(A.CrNoteDate AS NVARCHAR(25)), 103), A.Balance, A.Balance, 0,0,0,0,0, A.Balance, 0, 1, 0
FROM @tvpAdjInvCrNote A;
--Credit Note Value Store in Sales Transaction Adjment Table
INSERT INTO tblTransSaleAdjDetail (InvId ,NoteId ,DocPrefix ,DocValue,DocDate,Balance )
SELECT @InvId, A.NoteId, A.DocPrefix, A.DocValue, CAST(A.CrNoteDate AS NVARCHAR(25)), A.Balance
FROM @tvpAdjInvCrNote A;    
END    
END    
--Collection Implicit Posting Sales Transaction Multi payment mode Only    
ELSE IF(@PaymentModeId = 8)    
BEGIN    
DECLARE @PaymentCount INT, @PaymentIndex INT,@InvCurrentAmt DECIMAL (25,6),@AddAdjustmentIndex INT =0 ,@MOPCount INT =0    
SET @PaymentCount=(SELECT COUNT(*) FROM @tvpTranSalesMop)    
SET @MOPCount= @PaymentCount    
SET @PaymentIndex=1    
SELECT @InvCurrentAmt=ISNULL(Balance,0) FROM tblTranSalesHeader WHERE Id =@InvId    
WHILE @PaymentCount >0    
BEGIN    
DECLARE @ReceivedAmt DECIMAL (25,6),@ChqDDNo NVARCHAR(25), @chqDate NVARCHAR(25),@BankAccNo NVARCHAR(255),@BankAccID INT ,    
@IFSCCode NVARCHAR(25),@Bank NVARCHAR(255),@Branch NVARCHAR(255),@PayAt NVARCHAR(255),@Balance DECIMAL (25,6),@VisaPern DECIMAL (25,6), @VisaAmt DECIMAL (25,6)    
--Get Record    
SELECT @PaymentModeId=[PayModeId],@ChqDDNo=[Cheque_OR_DDNumber_OR_NEFTId],@BankAccNo=[BankAccNo],@BankAccID=[BankAccID],@chqDate=[PMDate],    
@PayAt=[PayAt],@IFSCCode=[IfscCode],@Bank=[Bank] ,@Branch=[Branch] ,@ReceivedAmt=[Amt] , @Balance = isnull([Balance],0),@VisaPern = [VisaPern], @VisaAmt =[VisaAmt]    
FROM @tvpTranSalesMop WHERE [SerialNo]=@PaymentIndex    
    
--Transaction Sales payment detail    
INSERT INTO tblTran_Sale_Bill_PaymentDetail(TransId,InvId,[PayModeId],[Cheque_OR_DDNumber_OR_NEFTId],Acc_OR_PaytermId,[PMDate],[PayAt],[IfscCode],[Bank] ,    
[Branch] ,[Amt] ,[SerialNo],RecdAmt,VisaPer,VisaAmt )VALUES(15,@InvId,@PaymentModeId,@ChqDDNo,@BankAccID,@chqDate,@PayAt,@IFSCCode,@Bank,@Branch,@ReceivedAmt ,@PaymentIndex,@Balance,@VisaPern,@VisaAmt)    
--Restrict Credit Mode    
IF ISNULL(@PaymentModeId,0) != 7    
BEGIN    
--Collection Header    
INSERT INTO @Header VALUES(CONVERT(NVARCHAR(50),@InvDate,103),1,@DocRef ,@Accid,@ReceivedAmt ,0,@PaymentModeId,1 ,0,@UID,1,@PaymentIndex,@VisaPern,@VisaAmt)    
--Mop Detail    
INSERT INTO @Mop VALUES(@Accid,@PaymentModeId,@ChqDDNo,CONVERT(NVARCHAR(50),@chqDate,103),@BankAccID,@ChqDDNo ,@ReceivedAmt,@IFSCCode ,@Bank ,    
@Branch ,@PayAt,@BankAccNo,null,0,@PaymentIndex,@Balance)    
IF (ISNULL(@TCrNoteAdjValue,0)>0 AND @AddAdjustmentIndex=0)    
BEGIN    
--Credit Note Adjustment    
IF ISNULL(@CrAdjCount,0) >0    
BEGIN    
/*p2:07 set-based: the adjusted credit notes are added with two INSERT ... SELECT instead of a cursor
  (same values and conversions: the note date is read as text of up to 25 characters, as before)*/
INSERT INTO @Detail
SELECT @Accid, A.DocPrefix, A.DocValue, A.NoteId, CONVERT(DATE, CAST(A.CrNoteDate AS NVARCHAR(25)), 103), A.Balance, A.Balance, 0,0,0,0,0, A.Balance, 0, @PaymentIndex, 0
FROM @tvpAdjInvCrNote A;
--Credit Note Value Store in Sales Transaction Adjment Table
INSERT INTO tblTransSaleAdjDetail (InvId ,NoteId ,DocPrefix ,DocValue,DocDate,Balance )
SELECT @InvId, A.NoteId, A.DocPrefix, A.DocValue, CAST(A.CrNoteDate AS NVARCHAR(25)), A.Balance
FROM @tvpAdjInvCrNote A;    
END    
-- Col Detail    
INSERT INTO @Detail VALUES(@Accid,15,@DocValue, @InvId,@InvDate,@InvCurrentAmt,ISNULL(@ReceivedAmt,0)+ISNULL(@TCrNoteAdjValue,0),0,0,0,0,0,    
ISNULL(@ReceivedAmt,0)+ISNULL(@TCrNoteAdjValue,0),0,@PaymentIndex,0)    
SET @InvCurrentAmt=@InvCurrentAmt-(ISNULL(@ReceivedAmt,0)+ISNULL(@TCrNoteAdjValue,0))    
SET @AddAdjustmentIndex=1;    
END    
ELSE    
BEGIN    
-- Col Detail    
INSERT INTO @Detail VALUES(@Accid,15,@DocValue, @InvId,@InvDate,@InvCurrentAmt,@ReceivedAmt,0,0,0,0,0,@ReceivedAmt,0,@PaymentIndex,0)    
SET @InvCurrentAmt=@InvCurrentAmt-@ReceivedAmt;    
END    
END    
--Only Credit Mode and MOP Detail Count 1 and Adjustment is Adjust    
ELSE IF (@PaymentModeId = 7 AND @MOPCount=1 AND ISNULL(@CrAdjCount,0) >0)    
BEGIN    
--Collection Header    
INSERT INTO @Header VALUES(CONVERT(NVARCHAR(50),@InvDate,103),1,@DocRef ,@Accid,0 ,0,@PaymentModeId,1,0,@UID,1,1,null,null)    
--Collection Detail    
INSERT INTO @Detail VALUES(@Accid,15,@DocValue, @InvId,@InvDate,ISNULL(@TotalNetAmt,0),    
ISNULL(@TCrNoteAdjValue,0),0,0,0,0,0,ISNULL(@TCrNoteAdjValue,0),0,1,0)    
--Adjustment    
IF ISNULL(@CrAdjCount,0) >0    
BEGIN    
/*p2:07 set-based: the adjusted credit notes are added with two INSERT ... SELECT instead of a cursor
  (same values and conversions: the note date is read as text of up to 25 characters, as before)*/
INSERT INTO @Detail
SELECT @Accid, A.DocPrefix, A.DocValue, A.NoteId, CONVERT(DATE, CAST(A.CrNoteDate AS NVARCHAR(25)), 103), A.Balance, A.Balance, 0,0,0,0,0, A.Balance, 0, 1, 0
FROM @tvpAdjInvCrNote A;
--Credit Note Value Store in Sales Transaction Adjment Table
INSERT INTO tblTransSaleAdjDetail (InvId ,NoteId ,DocPrefix ,DocValue,DocDate,Balance )
SELECT @InvId, A.NoteId, A.DocPrefix, A.DocValue, CAST(A.CrNoteDate AS NVARCHAR(25)), A.Balance
FROM @tvpAdjInvCrNote A;    
END    
END    
SET @PaymentCount=@PaymentCount-1;    
SET @PaymentIndex=@PaymentIndex+1;    
END    
END    
    
IF ((SELECT ISNULL(COUNT(*),0) FROM @Header)>0)    
BEGIN    
-- Get UDN for Collection    
DECLARE @UDFCount INT,@UDNSingle INT    
SET @UDFCount = (SELECT COUNT(DISTINCT UDNId) FROM tblMasterUserDefineNoDetail    
WHERE UDNId IN (SELECT UDNId FROM tblMasterUserDefineNoHeader WHERE TransID=19) AND UserId=@UID)    
IF ISNULL(@UDFCount,0)=1    
BEGIN    
SET @UDNSingle = (SELECT DISTINCT UDNId FROM tblMasterUserDefineNoDetail WHERE UDNId IN (SELECT UDNId FROM tblMasterUserDefineNoHeader WHERE TransId=19)AND UserId=@UID )    
END    
    
EXEC uspManageFullColl 19,@UDNSingle,@Header,@Detail,@Mop,1,@BeatID,@SalesManID,NULL,@tvpSaveDenomination ,1,0,1,0,null,null,@BranchID    
END    
    
SET NOCOUNT OFF;    
END TRY    
BEGIN CATCH    
SELECT ERROR_MESSAGE() ,ERROR_PROCEDURE() ,ERROR_LINE();    
END CATCH 

GO
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspManageTranSalesColl')) LIKE N'%/*p2:07%' PRINT N'dbo.uspManageTranSalesColl : changed';
GO
SET NOEXEC OFF;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
/* ===================================================================================== dbo.uspManageTransPurchaseBill */
SET NOEXEC OFF;
GO
DECLARE @d nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspManageTransPurchaseBill'));
IF @d IS NULL
BEGIN PRINT N'dbo.uspManageTransPurchaseBill : not found - skipped'; SET NOEXEC ON; END
ELSE IF @d LIKE N'%/*p2:07%'
BEGIN PRINT N'dbo.uspManageTransPurchaseBill : already applied'; SET NOEXEC ON; END
ELSE IF HASHBYTES('SHA2_256', @d) <> 0xF34DDC3608CC12ED9E117A3DDA513BBE8D598F1F401D7EC2466ED27A02751374
BEGIN PRINT N'dbo.uspManageTransPurchaseBill : SKIPPED - this database has a different version of the procedure than the one this script was written for'; SET NOEXEC ON; END
ELSE
BEGIN
    INSERT dbo.DbaProcBackup (ProcName, Script, UsesAnsiNulls, UsesQuotedIdentifier, Definition)
    SELECT N'uspManageTransPurchaseBill', '07', uses_ansi_nulls, uses_quoted_identifier, definition FROM sys.sql_modules WHERE object_id = OBJECT_ID(N'dbo.uspManageTransPurchaseBill');
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
ALTER PROC [dbo].[uspManageTransPurchaseBill]--2000            
(@Mode INT,@BillId INT = NULL,@BranchID INT = NULL,@nCurrStatus int,@BillDate DATE,@VendorId INT,@TotalGrossAmt DECIMAL (25,6),@TotalTaxAmt DECIMAL (25,6),@TotalNetAmt DECIMAL (25,6),            
@GRNRefNo NVARCHAR(255)=NULL,@PGroupID INT=NULL,@TaxTypeID INT,@PaymentTermId INT=NULL,@paymentDate NVARCHAR(25)=NULL,            
@PaymentModeId INT=NULL ,@vehicleno NVARCHAR(255)=NULL,@Frieght DECIMAL (25,6)= NULL,@OtherCharge DECIMAL(25,6)=NULL,            
@OtherChargeamt DECIMAL (25,6)=NULL,@ProdDisc DECIMAL(25,6)=NULL,@TradeDisc DECIMAL(25,6)=NULL,@AddnlDisc DECIMAL(25,6)=NULL,            
@TotalProdDiscAmt DECIMAL (25,6)= NULL,@TotalTradeDiscAmt DECIMAL (25,6)= NULL,@TotalAddnlDiscAmt DECIMAL (25,6)= NULL,            
@WrightOffAmt DECIMAL (25,6)= NULL,@UID INT,@RoundOffAmt DECIMAL (25,6)= NULL,@tvpTranBillDetail AS [tvpTranBillDetail] READONLY,            
@tvpTranBillMop AS [tvpTranBillMop] READONLY,@UDFId INT =NULL ,@IFBIll SMALLINT=1,@nAllowNegativeBal INT=NULL,@IS_IMPORT INT=NULL,            
@DateBill DATE=NULL,@TCSPern DECIMAL(25,6) = NULL,@TCSAmt DECIMAL(25,6) = NULL,@TDSAmt DECIMAL(25,6) = NULL,@ImportStatus INT = 0,            
@Remarks NVARCHAR(25)=NULL,@Narration NVARCHAR(25)=NULL,@DraftID INT = 0,@tvpSaveDenomination dbo.tvpSaveDenomination READONLY,            
@DiffValueGross DECIMAL(25,4) = 0,@DiffValueNet DECIMAL(25,4) = 0,@UpdateVendor INT = 0,@FilterType INT = 1)            
AS            
BEGIN TRY            
SET DATEFORMAT dmy;            
SET NOCOUNT ON;            
DECLARE @AccId INT,@ScopeID INT            
DECLARE @docvalue INT ,@Status INT,@DocID NVARCHAR(255),@GRNDocID NVARCHAR(255),@UDFDocId NVARCHAR(255),@UDFDocValue INT,@UDFDocPrefix NVARCHAR(255),@CheckUDFId INT            
DECLARE @CheckStatus INT,@DrDetbitNote DECIMAL(25,6),@TempPOID int,@PreviousTranDate DATE,@Balance DECIMAL (25,6) ,@NET DECIMAL (25,6)           
DECLARE @F_SD DATE = (SELECT F_SD FROM tblCompanyRegistration WHERE CompanyId = 1)            
DECLARE @F_ED DATE = (SELECT F_ED FROM tblCompanyRegistration WHERE CompanyId = 1)            
declare @tblDocdetails as table(ID int,DocValue int,Prefix nvarchar(100))            
DECLARE @DocSeriesIdent int,@InvoiceID int      
SELECT @Accid=FAID FROM tblMasterVendor WHERE ID =@VendorId            
IF(@Mode = 1)            
BEGIN            
--SELECT @CheckStatus = [Status] FROM tblTranGRNHeader WHERE GRNID = @GRNID            
--IF(@CheckStatus != @nCurrStatus)            
--BEGIN            
--RAISERROR('PROC',16,1)            
--END            
--USER$ DEFINE NUMBER DOC VALIDATIONS            
insert into @tblDocdetails            
select ID,DocValue,Prefix DocID from tblYearwiseDocumentSeries where (@BillDate between FromDate and ToDate) and BranchID = @BranchID and TransID = 1            
IF((select count(*) from @tblDocdetails) = 0)            
BEGIN            
RAISERROR ('Document ID not found for this Branch/Date/Transaction',16,1)            
END            
IF(ISNULL(@GRNRefNo,'') != '')        
BEGIN        
IF((SELECT COUNT(*) FROM tblTransPurchaseHeader WHERE VendorID = @VendorId AND RefNo = @GRNRefNo) > 0)        
BEGIN        
RAISERROR ('Ref No already exists',16,1)            
END        
END        
SELECT @DocValue = DocValue,@DocId = Prefix + Convert(nvarchar, DocValue),@DocSeriesIdent = ID FROM @tblDocdetails            
            
UPDATE tblYearwiseDocumentSeries SET DocValue = @DocValue + 1 WHERE TransID = 1 and ID = @DocSeriesIdent            
            
IF ISNULL(@BillId,0)>0 -- PO to Bill            
BEGIN            
set @TempPOID = @BillId            
SET @BillId = 0            
END            
          
            
IF(ISNULL(@DraftID,0) > 0 and isnull(@FilterType,0) = 2)            
BEGIN            
exec uspValidateDraftData 1,1,@DraftID,@nCurrStatus             
END            
IF(ISNULL(@TempPOID,0) > 0 and isnull(@FilterType,0) = 3)            
BEGIN            
select @CheckStatus = Status from tblPurchaseorderheader WHERE ID = @TempPOID       
if((@CheckStatus != @nCurrStatus) OR @CheckStatus IN (2,4))
begin            
RAISERROR ('This Document status already changed',16,1)                           
end          
ENd           
IF(ISNULL(@DraftID,0) > 0 and isnull(@FilterType,0) = 4)            
BEGIN            
set @InvoiceID = @DraftID;      
END       
IF ISNULL(@UDFId,0)>0            
BEGIN            
SELECT @UDFDocValue=DocValue,@UDFDocPrefix=DocPrefix,@UDFDocId=DocPrefix+ CONVERT(NVARCHAR, DocValue)            
FROM tblMasterUserDefineNoHeader WHERE UDNId=@UDFId            
IF ISNULL(@IS_IMPORT,0)=0            
BEGIN            
UPDATE tblMasterUserDefineNoHeader SET DocValue=1+ISNULL(DocValue,0) WHERE UDNId=@UDFId            
END            
END           
--Set Status            
SET @Status=1            
SET @BillId=0   
ENd            
ELSE            
BEGIN            
            
--Get Difference Inentory Id From GRN Table            
CREATE TABLE #Temp(InvId INT)            
INSERT INTO #Temp SELECT GRND.InventoryId FROM tblTransPurchaseDetail GRND            
WHERE GRND.InventoryId NOT IN(SELECT InventoryId FROM @tvpTranBillDetail) AND GRND.HID =@BillId            
            
DECLARE @TempQty DECIMAL(25, 9),@TempFreeQty DECIMAL(25, 9),@TempDmgQty DECIMAL(25, 9),@TempInvId INT            
/*p2:07 set-based: batches removed from the bill are checked and reset with one query each instead
  of a cursor. Same rule: every removed batch must be untouched (received = actual for qty, free and
  damaged), otherwise "Qty Miss Matched,Cannot Delete Product/Batch". The cursor is still used if a
  removed batch no longer exists in tblProductInventory.*/
IF NOT EXISTS (SELECT 1 FROM #Temp T WHERE NOT EXISTS (SELECT 1 FROM tblProductInventory PI WHERE PI.InventoryId = T.InvId))
BEGIN
    IF EXISTS (SELECT 1 FROM #Temp T JOIN tblProductInventory PI ON PI.InventoryId = T.InvId
               WHERE NOT (CAST(ISNULL(PI.RecdQty,0)-ISNULL(PI.ActualQty,0) AS DECIMAL(25,9)) = 0
                          AND CAST(ISNULL(PI.RecdFreeQty,0)-ISNULL(PI.ActualFreeQty,0) AS DECIMAL(25,9)) = 0
                          AND CAST(ISNULL(PI.RecdDmgQty,0)-ISNULL(PI.ActualDmgQty,0) AS DECIMAL(25,9)) = 0))
        RAISERROR('Qty Miss Matched,Cannot Delete Product/Batch',16,1);
    UPDATE tblProductInventory SET RecdQty = 0,RecdFreeQty = 0,RecdDmgQty = 0, ActualQty = ISNULL(ActualQty,0)-ISNULL(RecdQty,0) ,
    ActualFreeQty =ISNULL(ActualFreeQty,0)-ISNULL(RecdFreeQty,0),ActualDmgQty = ISNULL(ActualDmgQty,0)-ISNULL(RecdDmgQty,0)
    WHERE InventoryId IN (SELECT InvId FROM #Temp);
END
ELSE
BEGIN /*p2:07 original cursor*/
DECLARE Temp CURSOR FOR(SELECT InvId FROM #Temp)            
OPEN Temp            
FETCH NEXT FROM Temp INTO @TempInvId            
WHILE @@FETCH_STATUS =0            
BEGIN            
--Get Datail Inventory Id if Modify GRN            
SELECT @TempQty= (ISNULL(RecdQty,0)-ISNULL(ActualQty,0)),            
@TempFreeQty= (ISNULL(RecdFreeQty,0)-ISNULL(ActualFreeQty,0)),            
@TempDmgQty= (ISNULL(RecdDmgQty,0)-ISNULL(ActualDmgQty,0))            
FROM tblProductInventory WHERE InventoryId=@TempInvId            
--Any One Qty Miss Matched To Not Allow Modify A Batch            
IF(@TempQty=0 AND @TempFreeQty=0 AND @TempDmgQty=0)            
BEGIN            
UPDATE tblProductInventory SET RecdQty = 0,RecdFreeQty = 0,RecdDmgQty = 0, ActualQty = ISNULL(ActualQty,0)-ISNULL(RecdQty,0) ,            
ActualFreeQty =ISNULL(ActualFreeQty,0)-ISNULL(RecdFreeQty,0),ActualDmgQty = ISNULL(ActualDmgQty,0)-ISNULL(RecdDmgQty,0)            
WHERE InventoryId=@TempInvId            
END            
ELSE            
BEGIN            
RAISERROR('Qty Miss Matched,Cannot Delete Product/Batch',16,1);            
END            
FETCH NEXT FROM Temp INTO @TempInvId
END
END /*p2:07 end of original cursor*/
SELECT @CheckStatus = [Status],@Balance = Balance,@NET = NetAmt FROM tblTransPurchaseHeader WHERE ID = @BillId          
IF((@CheckStatus != @nCurrStatus) OR @CheckStatus IN (2,4))            
BEGIN            
RAISERROR('Document status already changed',16,1)            
END            
IF(@NET != @Balance)          
BEGIN            
RAISERROR('Document partially payment',16,1)            
END              
--select [Status] from tblTranBillHeader where BillID = 2876            
UPDATE tblTransPurchaseHeader SET [Status]=2 ,Mby =@UID ,Mdate =GETDATE () Where ID = @BillId            
UPDATE tblFAJournal SET [Status]=2 ,Mby =@UID ,Mdate =GETDATE () WHERE TransId =@BillId AND DocPrefix =1            
            
            
--exec uspValidateBillModifyORCancel @nCurrStatus,@GRNId,@Mode,            
--Modify Bill Get Doc Value Amended Bill            
SELECT @docvalue=DocValue ,@DocID =DocID,@UDFDocValue=ISNULL(UDFDocValue,0),@CheckUDFId=ISNULL(UDFId,0),@InvoiceID = InvoiceID            
FROM tblTransPurchaseHeader WHERE ID =@BillId            
SET @Status=3            
IF ISNULL(@UDFId,0)>0            
BEGIn            
IF(@UDFId=@CheckUDFId)            
BEGIN            
SELECT @UDFDocId=DocPrefix + CONVERT(NVARCHAR, @UDFDocValue),@UDFDocPrefix=DocPrefix FROM tblMasterUserDefineNoHeader WHERE UDNId=@UDFId            
END            
IF(@UDFId!=@CheckUDFId)            
BEGIN            
SELECT @UDFDocValue=DocValue,@UDFDocPrefix=DocPrefix,@UDFDocId=DocPrefix+ CONVERT(NVARCHAR, DocValue)            
FROM tblMasterUserDefineNoHeader WHERE UDNId=@UDFId            
UPDATE tblMasterUserDefineNoHeader SET DocValue = ISNULL(DocValue,0)+1 WHERE UDNId =@UDFId            
END            
END            
END            
IF(@Mode = 1)-- OR @Mode = 2            
BEGIN            
IF((SELECT COUNT(DocValue) FROM tblTransPurchaseHeader WHERE DocID = @DocID and             
Date BETWEEN @F_SD AND @F_ED and TransID = 1) != 0)-- and Status in (1,3,4,5)            
BEGIN            
RAISERROR('<code><h4>%s</h4></code> &ensp;Document ID already exists',16,1,@DocId)              
END            
ENd            
IF(@Mode = 2)            
BEGIN            
IF((SELECT COUNT(DocValue) FROM tblTransPurchaseHeader WHERE DocID = @DocID and             
Date not BETWEEN @F_SD AND @F_ED and TransID = 1) != 0)-- and Status in (1,3,4,5)            
BEGIN            
RAISERROR('<code><h4>%s</h4></code> &ensp;Document ID already exists',16,1,@DocId)              
END            
ENd            
-----TDSamount value for Balance            
IF(ISNULL(@PaymentTermId,0) > 0)            
BEGIN            
SELECT @paymentDate = DATEADD(DD,Value,@BillDate) FROM tblMasterCreditTerm WHERE ID = @PaymentTermId            
END            
Declare @TDSBalance decimal(25,4)            
IF ISNULL(@Mode,0)=1 OR ISNULL(@Mode,0)=2            
BEGIN            
Set @TDSBalance=(@TotalNetAmt-@TDSAmt)            
END            
SET @TotalNetAmt = (ISNULL(@TotalNetAmt,0) )            
--Insert bill header            
INSERT INTO tblTransPurchaseHeader(Date,DocID,TransID,BranchID,DocValue,VENDorID,[Status],GrossAmt,TaxAmt,NetAmt,RefNo,ProdGroupID,TaxTypeID,PaymentTermID,PaymentDate,            
PaymentModeId, VehicleNo,Frieght,[OtherCharge%],OtherChargeAmt,[ProdDisc%],[TradeDisc%],[AddnlDisc%],TotalProdDiscAmt,TotalTradeDiscAmt,            
TotalAddnlDiscAmt,WriteOffAmt,RoundOffAmt, Balance,OrgId,Cby,Cdate,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue,            
DateBill,TCSTaxPern,TCSTaxAmt,TDSAmount,Remarks,Narration,PriceType,DiffValueGross,DiffValueNet,InvoiceID)            
VALUES(@BillDate, @DocID,1 ,@BranchID,@docvalue,@VendorId,CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END ,            
@TotalGrossAmt,@TotalTaxAmt,@TotalNetAmt,@GRNRefNo,@PGroupID,@TaxTypeID,@PaymentTermId,            
(CASE WHEN ISNULL(@paymentDate,'')='' THEN NULL ELSE @paymentDate END),@PaymentModeId,@vehicleno,@Frieght,@OtherCharge,@OtherChargeamt,@ProdDisc,@TradeDisc,@AddnlDisc,@TotalProdDiscAmt,@TotalTradeDiscAmt,            
@TotalAddnlDiscAmt,@WrightOffAmt,@RoundOffAmt,@TDSBalance,@BillId,@UID,GETDATE (),@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,            
(CASE WHEN ISNULL(@DateBill,'')='' THEN @BillDate ELSE @DateBill END),@TCSPern,@TCSAmt,@TDSAmt,@Remarks,@Narration,1,@DiffValueGross,@DiffValueNet,@InvoiceID)            
--Scope Indentity for Bill Header Table            
            
SET @ScopeID=(SELECT SCOPE_IDENTITY())            
            
IF(@Mode = 1)            
BEGIN            
EXEC uspCreateBackTran 1,@BranchID,@ScopeID,0,1,@DocValue ,@BillDate,NULL,@UID            
END            
IF(@Mode = 2)            
BEGIN            
EXEC uspCreateBackTran @Mode,@BranchID,@ScopeID,@BillId,1,@DocValue ,@BillDate,@PreviousTranDate,@UID            
END            
--Variable declaration for Loop bill detail            
DECLARE @ProdID INT,@UOMID INT,@UomGrpID INT,@BatchNo NVARCHAR(255) = NULL,@PKD NVARCHAR(255) = NULL,@Expiry NVARCHAR(255) = NULL,@UomQty DECIMAL(25, 9) ,@UomFreeQty DECIMAL(25,9),            
@UomDamageQty DECIMAL(25, 9) ,@PurchasePrice DECIMAL (25,6),@SalePrice DECIMAL (25,6),@ECP DECIMAL (25,6),@MRP DECIMAL (25,6),@SPLPrice DECIMAL (25,6),@TaxID INT,@BTaxTypeId INT,            
@TaxPercentage DECIMAL (25,6),@GoodsAmt DECIMAL (25,6),@ProdDiscPercent DECIMAL (25,6) = NULL,@TradeDiscPercent DECIMAL (25,6) = NULL,@AddnlDiscPercent DECIMAL (25,6) = NULL,    
@ProdDiscAmount DECIMAL (25,6) = NULL,@TradeDiscAmount DECIMAL (25,6) = NULL,@AddnlDiscAmount DECIMAL (25,6) = NULL,    
@BGrossAmt DECIMAL (25,6),@BTaxAmt DECIMAL (25,6),@BNetAmt DECIMAL (25,6),@InvId INT,@InclusiveYesNo INT,@IsChrgProd INT = 0     
,@ReturnPrice DECIMAL (25,6),@InvScopeID INT = 0,@HSNCode NVARCHAR(255) = NULL,@ReasonID INT,@LocationID INT,@DiffAmt DECIMAL (25,4) = 0            
--Loop Detail using CURSOR            
DECLARE @PKDDate DATE,@ExpiryDate DATE            
DECLARE @PriceOnUomCF DECIMAL (25,6),@MRPOnUomCF DECIMAL (25,6),@SelectedUomCF DECIMAL (25,6) = 1,            
@Qty DECIMAL(25, 9),@FreeQty DECIMAL(25, 9),@DamageQty DECIMAL(25, 9)            
DECLARE @PUomId INT,@MRPUomId INT,@TrackPKD INT            
DECLARE @InventoryID INT =0            
DECLARE cursor_Temp CURSOR FOR (SELECT [ProdID] ,[UOMID],[UomGrpID],[BatchNo] ,[PKD] ,[Expiry], [Qty] , [FreeQty] , [DamageQty],            
[PurchasePrice],[SalePrice] ,[ECP] ,[MRP] ,[SPLPrice] , [TaxID] ,[TaxTypeId] ,[TaxPercentage] ,[GoodsAmt] ,[ProdDiscPercent],            
[TradeDiscPercent], [AddnlDiscPercent],[GrossAmt] ,[TaxAmt],[NetAmt] ,[InventoryId],InclusiveYesNo,ReturnPrice,UOMCR,HSN,ReasonID,LocationID,DiffAmt,    
ProdDiscAmount ,TradeDiscAmount ,AddnlDiscAmount    
FROM @tvpTranBillDetail)            
OPEN cursor_Temp            
FETCH NEXT FROM cursor_Temp INTO @ProdID , @UOMID ,@UomGrpID ,@BatchNo ,@PKD ,@Expiry ,@UomQty ,            
@UomFreeQty,@UomDamageQty ,@PurchasePrice ,@SalePrice ,@ECP ,@MRP ,@SPLPrice ,@TaxID ,@BTaxTypeId ,@TaxPercentage ,            
@GoodsAmt ,@ProdDiscPercent ,@TradeDiscPercent ,@AddnlDiscPercent ,@BGrossAmt ,@BTaxAmt ,@BNetAmt ,@InvId ,@InclusiveYesNo,            
@ReturnPrice,@SelectedUomCF,@HSNCode,@ReasonID,@LocationID,@DiffAmt,@ProdDiscAmount ,@TradeDiscAmount ,@AddnlDiscAmount            
DECLARE @GTaxAmt DECIMAL (25,6),@InclMRP DECIMAL (25,6)            
--SET @GTaxAmt =( @MRP * @TaxPercentage /100)            
--SET @InclMRP = (@MRP + @GTaxAmt)            
IF(@Status = 1 AND @Mode = 1)  
BEGIN  
SET @InvId = 0  
END  
DECLARE @BillDetailSerial INT = 1            
WHILE @@FETCH_STATUS =0            
BEGIN            
IF(@IFBIll=1)            
BEGIN --Direct Bill Screen            
IF ISDATE(CONVERT(NVARCHAR,@PKD,103))=1            
BEGIN            
SET @PKDDate=@PKD            
END            
ELSE            
BEGIN            
SET @PKDDate=NULL            
END            
IF ISDATE(CONVERT(NVARCHAR,@Expiry,103))=1            
BEGIN            
SET @ExpiryDate=@Expiry            
END            
ELSE            
BEGIN            
SET @ExpiryDate=NULL            
END            
END            
ELSE            
BEGIN --GRN wise Bill Create            
IF @PKD !=NULL OR @PKD !=''            
BEGIN            
SET @PKDDate=@PKD            
END            
ELSE            
BEGIN            
SET @PKDDate=NULL            
END            
IF @Expiry!=NULL OR @Expiry!=''            
BEGIN            
SET @ExpiryDate=@Expiry            
END            
ELSE            
BEGIN            
SET @ExpiryDate=NULL            
END            
END            
--Get Price On,MRP ON from Product Table            
SELECT @PUomId=PurchaseUomID,@PriceOnUomCF=PurchaseCR,@TrackPKD = TrackPDK--,@IsChrgProd = (CASE WHEN TrackInventory = 0 AND ChargesPern > 0 THEN 1 ELSE 0 END)            
FROM tblMasterProduct WHERE ID =@ProdID            
            
SET @Qty=@UomQty *@SelectedUomCF;            
SET @FreeQty=@UomFreeQty *@SelectedUomCF;            
SET @DamageQty=@UomDamageQty *@SelectedUomCF;            
            
-- Uom Convertion            
--SELECT @PriceOnUomCF=ConversionRate FROM tblMastUomGroupDetail WHERE UOMGroupID =@UomGrpID AND UOMMastID =@PUomId            
--SELECT @MRPOnUomCF=ConversionRate FROM tblMastUomGroupDetail WHERE UOMGroupID =@UomGrpID AND UOMMastID =@MRPUomId            
--SELECT @SelectedUomCF=ConversionRate FROM tblMastUomGroupDetail WHERE UOMGroupID =@UomGrpID AND UOMMastID =@UOMID            
--Insert In Purchase Bill Bill Detail Table            
--New Batch Insertion            
IF ISNULL(@InvId,0)=0            
BEGIn            
IF(@IsChrgProd = 0)            
BEGIN            
EXEC uspInsertInventory 'INSERT',1,@BillDate,@DocValue,@ProdId,@UomGrpID,@UOMID,@Qty,@FreeQty,@DamageQty,@Qty,@FreeQty,            
@DamageQty,0,0,0,@Batchno ,@PKDDate,@ExpiryDate,@PurchasePrice,@SalePrice,@ECP,@SPLPrice,@MRP,@ReturnPrice,@TaxId ,@TaxTypeId ,            
@TaxPercentage,0,@InvScopeId OUT,0,@InclusiveYesNo,@UID,@BranchID,@SelectedUomCF            
END            
END            
ELSE            
BEGIN            
DECLARE @CheckBatchVerify INT            
IF(@TrackPKD =1)            
BEGIN            
SET @CheckBatchVerify =(SELECT COUNT(*) FROM tblProductInventory IP            
JOIN @tvpTranBillDetail TVP ON TVP .InventoryId =IP.InventoryId            
WHERE IP.InventoryId =@InvId AND ISNULL(IP.BatchNumber,'')=ISNULL(TVP.BatchNo,'')            
AND IP.PkdDate =CONVERT(DATE,TVP.PKD,103) AND IP.ExpiryDate =CONVERT(DATE,TVP.Expiry,103))            
END            
ELSE            
BEGIN            
SET @CheckBatchVerify =(SELECT COUNT(*) FROM tblProductInventory IP            
JOIN @tvpTranBillDetail TVP ON TVP .InventoryId =IP.InventoryId            
WHERE IP.InventoryId =@InvId AND ISNULL(IP.BatchNumber,'')=ISNULL(TVP.BatchNo,''))            
END            
            
--iyan----            
--If Change Batch Info To Verify Changes Allow or Not            
--IF(ISNULL(@CheckBatchVerify,0)=0)            
--BEGIN            
-- SELECT @TempQty=ISNULL(RecdQty,0)-(ISNULL(ActualQty,0)-ISNULL(SRQty,0)),            
-- @TempFreeQty=ISNULL(RecdFreeQty,0)-(ISNULL(ActualFreeQty,0)-ISNULL(SRFreeQty,0)),            
-- @TempDmgQty=ISNULL(RecdDmgQty,0)-(ISNULL(ActualDmgQty,0)-ISNULL(SRFreeQty,0))            
-- FROM tblProdInventory WHERE InventoryId=@InventoryID            
-- IF(@TempQty !=0 OR @TempFreeQty !=0 OR @TempDmgQty !=0)            
-- BEGIN            
-- RAISERROR('Batch Cannot Change',16,1);            
-- END            
--END            
--Find Required Qty            
DECLARE @RQTY DECIMAL(25, 9),@RFQTY DECIMAL(25, 9),@RDQTY DECIMAL(25, 9),@AQty DECIMAL(25, 9)            
DECLARE @AFQty DECIMAL(25, 9),@ADQty DECIMAL(25, 9),@SRQty DECIMAL(25, 9),@SRFQty DECIMAL(25, 9),@SRDQty DECIMAL(25, 9)            
            
SELECT @RQTY = RecdQty,@RFQTY =RecdFreeQty ,@RDQTY = RecdDmgQty,            
@AQty =ActualQty ,@AFQty =ActualFreeQty ,@ADQty =ActualDmgQty ,            
@SRQty =SRQty,@SRFQty = SRFreeQty ,@SRDQty = SRDmgQty            
FROM dbo.tblProductInventory WHERE InventoryId = @InvId            
            
DECLARE @FinalQty DECIMAL(25, 9),@FinalFreeQty DECIMAL(25, 9),@FinalDmgQty DECIMAL(25, 9)            
            
SET @FinalQty = @RQTY - (@AQty - @SRQty )            
SET @FinalFreeQty = @RFQTY - (@AFQty - @SRFQty)            
SET @FinalDmgQty = @RDQTY - (@ADQty - @SRDQty )            
            
DECLARE @QtyDiff DECIMAL(25, 9)            
DECLARE @EM NVARCHAR(MAX) = 'Qty : '+convert(NVARCHAR(50),isnull(@Qty,0))+' , Final Qty : '+convert(NVARCHAR(50),isnull(@FinalQty,0))            
--Verify Required Qty If Pass to Update the Qty In Inventory Table            
IF(isnull(@Qty,0) >= isnull(@FinalQty,0) AND isnull(@FreeQty,0) >= isnull(@FinalFreeQty,0) AND isnull(@DamageQty,0) >= isnull(@FinalDmgQty,0) )            
BEGIN            
IF(@RQTY < @Qty)            
BEGIN SET @QtyDiff = @Qty - @RQTY            
SET @RQTY = @RQTY + @QtyDiff            
SET @AQty = @AQty + @QtyDiff            
END            
ELSE IF(@Qty < @RQTY )            
BEGIN            
SET @QtyDiff = @RQTY - @Qty            
SET @RQTY = @RQTY - @QtyDiff            
set @AQty = @AQty - @QtyDiff            
END            
IF(@RFQTY < @FreeQty)            
BEGIN            
SET @QtyDiff = @FreeQty - @RFQTY            
SET @RFQTY = @RFQTY + @QtyDiff            
SET @AFQty = @AFQty + @QtyDiff            
END            
ELSE IF(@RFQTY >@FreeQty)            
BEGIN            
SET @QtyDiff = @RFQTY - @FreeQty            
SET @RFQTY = @RFQTY - @QtyDiff            
SET @AFQty = @AFQty - @QtyDiff END            
IF(@RDQTY < @DamageQty)            
BEGIN            
Set @QtyDiff = @DamageQty - @RDQTY            
Set @RDQTY = @RDQTY + @QtyDiff            
set @ADQty = @ADQty + @QtyDiff            
END            
ELSE IF(@RDQTY > @DamageQty )            
BEGIN         
SET @QtyDiff = @RDQTY - @DamageQty            
SET @RDQTY = @RDQTY - @QtyDiff            
set @ADQty = @ADQty - @QtyDiff            
END            
IF(@IsChrgProd = 0)            
BEGIN            
EXEC uspInsertInventory 'UPDATE',1,@BillDate,@DocValue,@ProdId,@UomGrpID,@UOMID,@RQTY,@RFQTY,@RDQTY,@AQty,@AFQty,@ADQty,0,0,0,            
@Batchno ,@PKDDate,@ExpiryDate,@PurchasePrice,@SalePrice,@ECP,@SPLPrice,@MRP,@ReturnPrice,@TaxId ,@TaxTypeId ,@TaxPercentage,            
@InvId,@InvScopeId OUT ,0,@InclusiveYesNo,@UID,@BranchID,@SelectedUomCF            
END            
END            
ELSE            
BEGIN            
declare @MG NVARCHAR(MAX) = 'Qty Miss Matched.%s'            
RAISERROR(@MG,16,1,@EM);            
END            
END            
--SELECT * FROM tblTransPurchaseDetail ORDER BY 1 DESC          
--SELECT * FROM tblproductinventory ORDER BY 1 DESC            
INSERT INTO tblTransPurchaseDetail(HID,InventoryId,ProdID,UOMID,BatchNo,PKD,Expiry,UomQty,UomFreeQty,UomDamageQty,            
UomPurchasePrice, UomSalePrice,UomECP,UomMRP,UomSPLPrice,UomReturnPrice,PurchasePrice,SalePrice,ECP,MRP,SPLPrice,ReturnPrice,            
TaxID,TaxTypeId,[Tax%],GoodsAmt,[ProdDisc%],[TradeDisc%],[AddnlDisc%], GrossAmt,TaxAmt,NetAmt,Serial,UOMCF,ReasonId,LocationID,DiffAmt,            
AdjQty,AdjFreeQty,AdjDmgQty,ProdDiscAmt,TradeDiscAmt,AddnlDiscAmt)            
VALUES            
(@ScopeID,@InvScopeId,@ProdID ,@UOMID,@BatchNo,@PKDDate,@ExpiryDate,@UomQty , @UomFreeQty , @UomDamageQty,            
@PurchasePrice,@SalePrice,@ECP, @MRP,@SPLPrice,@ReturnPrice,ISNULL((@PurchasePrice / @SelectedUomCF ),0),ISNULL((@SalePrice / @SelectedUomCF) ,0),            
ISNULL((@ECP / @SelectedUomCF) ,0),ISNULL(@MRP ,0),ISNULL((@SPLPrice / @SelectedUomCF) ,0),ISNULL(@ReturnPrice,0),            
@TaxID ,@TaxTypeId,@TaxPercentage,@GoodsAmt , @ProdDiscPercent,@TradeDiscPercent,@AddnlDiscPercent,@BGrossAmt,@BTaxAmt,@BNetAmt,            
@BillDetailSerial,@SelectedUomCF,@ReasonID,@LocationID,@DiffAmt,ISNULL((@UomQty * @SelectedUomCF) ,0),ISNULL((@UomFreeQty * @SelectedUomCF) ,0),            
ISNULL((@UomDamageQty * @SelectedUomCF) ,0),@ProdDiscAmount ,@TradeDiscAmount ,@AddnlDiscAmount)            
            
SET @BillDetailSerial = @BillDetailSerial + 1            
--Direct Bill Only Update Inventory and Product Table            
IF(@IFBIll=1)            
BEGIN            
--UPDATE PRICE In Inventory            
DECLARE @MP DECIMAL (25,6)            
--SET @MP =ISNULL(@MRP ,0)            
--IF ISNULL(@InclusiveYesNo,0)=1            
--BEGIN            
SET @MP = (@MRP / ((@TaxPercentage /100 )+ 1))            
--SET @MP = @NPrice            
--END            
IF(@IsChrgProd = 0 AND ISNULL(@ImportStatus,0) = 0)            
BEGIN            
--Product Price Updation            
EXEC uspUpdatePriceInProductMaster @ProdID ,@PurchasePrice,@SalePrice,@ECP,@SPLPrice,@MRP,@ReturnPrice,@SelectedUomCF ,1,@HSNCode,@LocationID--@PriceOnUomCF            
if(@UpdateVendor = 1)            
begin            
update tblmasterproduct set VendorID = @vendorid where id = @ProdID            
end            
END            
END            
FETCH NEXT FROM cursor_Temp INTO @ProdID , @UOMID ,@UomGrpID ,@BatchNo ,@PKD ,@Expiry ,@UomQty ,@UomFreeQty,@UomDamageQty ,            
@PurchasePrice ,@SalePrice ,@ECP ,@MRP ,@SPLPrice ,@TaxID ,@BTaxTypeId ,@TaxPercentage ,@GoodsAmt ,@ProdDiscPercent ,            
@TradeDiscPercent ,@AddnlDiscPercent ,@BGrossAmt ,@BTaxAmt ,@BNetAmt ,@InvId ,@InclusiveYesNo ,@ReturnPrice,@SelectedUomCF,@HSNCode,            
@ReasonID,@LocationID,@DiffAmt,@ProdDiscAmount ,@TradeDiscAmount ,@AddnlDiscAmount            
END            
CLOSE cursor_Temp            
DEALLOCATE cursor_Temp            
BEGIN --Posting Tamil            
DECLARE @JVID INT            
SELECT @JVID=ISNULL(MAX(JVID),0)+1 FROM tblFAJournal            
IF ISNULL(@TotalGrossAmt,0)>0            
BEGIN --Gross Amt Posting            
-- Puchase Account            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate,TransId,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate ,@GRNRefNo ,76,0,(ISNULL(@TotalGrossAmt,0)), 0,'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,            
@UID ,GETDATE (),@ScopeID,@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID) --(ISNULL(@TotalGrossAmt,0)+ISNULL(@WrightOffAmt,0))            
END            
IF ISNULL(@TotalTaxAmt,0)>0            
BEGIN --Tax Amt Posting            
-- VAT Receivable (Input Tax Credit)            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate,TransId,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate ,@GRNRefNo ,113,0,@TotalTaxAmt, 0,'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,@UID ,GETDATE (),@ScopeID,            
@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID)            
END            
IF ISNULL(@TCSAmt,0)>0            
BEGIN --TCS Amt Posting            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate,TransId,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate ,@GRNRefNo ,57,0,@TCSAmt, 0,'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,@UID ,GETDATE (),@ScopeID,            
@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID)            
END            
IF ISNULL(@TDSAmt,0)>0            
BEGIN --TDS Amt Posting            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate,TransId,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate ,@GRNRefNo ,107,@TDSAmt,0, 0,'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,@UID ,GETDATE (),@ScopeID,            
@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID)            
END            
IF ISNULL(@Frieght,0)>0 BEGIN--Fright            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate,TransId ,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate ,@GRNRefNo ,39,0,ISNULL(@Frieght,0),0,'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,            
@UID ,GETDATE (),@ScopeID,@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID)            
END            
IF ISNULL(@OtherChargeAmt,0)>0            
BEGIN--Other Charges            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate,TransId,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue ,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate ,@GRNRefNo ,61,0,ISNULL((@OtherChargeAmt),0),0,'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,            
@UID ,GETDATE (),@ScopeID,@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID)            
END            
IF ISNULL(@OtherChargeAmt,0)<0            
BEGIN            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate,TransId,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue ,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate ,@GRNRefNo ,61,ISNULL(-(@OtherChargeAmt),0),0,0,'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,            
@UID ,GETDATE (),@ScopeID,@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID)            
END            
IF ISNULL(@WrightOffAmt,0)>0 -- Writeoff Amount Gives Positive (+)            
BEGIN            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate,TransId,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue ,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate ,@GRNRefNo ,117,0,ISNULL((@WrightOffAmt),0),0,'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,            
@UID ,GETDATE (),@ScopeID,@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID)            
END            
IF ISNULL(@WrightOffAmt,0)<0 -- Writeoff Amount Gives Negative (-)            
BEGIN            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate,TransId,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue ,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate ,@GRNRefNo ,117,ISNULL(-(@WrightOffAmt),0),0,0,'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,            
@UID ,GETDATE (),@ScopeID,@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID)            
END            
IF ISNULL(@TotalNetAmt,0)>0            
BEGIN --Net Amt Posting            
--Remove Round Of From Net Amount            
DECLARE @RAmt DECIMAL (25,6)            
SET @RAmt=-1*ISNULL(@RoundOffAmt,0)            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate,TransId,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate ,@GRNRefNo ,@Accid,ISNULL(@TotalNetAmt,0)+@RAmt,0, 0,'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,            
@UID ,GETDATE (),@ScopeID,@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID)            
END            
SELECT @JVID=ISNULL(MAX(JVID),0)+1 FROM tblFAJournal       
IF ISNULL(@RoundOffAmt,0)<>0            
BEGIn --Round Off Amt Posting            
IF ISNULL(@RoundOffAmt,0)>0            
BEGIN            
--Round Value Positive(+)            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate,TransId,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue ,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate,@GRNRefNo ,82,0,@RoundOffAmt,0,'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,            
@UID ,GETDATE (),@ScopeID,@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID)            
--Opposite Vendor Account Id            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate,TransId,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue ,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate ,@GRNRefNo ,@Accid,@RoundOffAmt,0,0,'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,            
@UID ,GETDATE (),@ScopeID,@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID)            
END            
IF ISNULL(@RoundOffAmt,0)<0            
BEGIN            
--Opposite Vendor Account Id            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate,TransId,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate ,@GRNRefNo ,@Accid,0,ABS(@RoundOffAmt),0,'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,            
@UID ,GETDATE (),@ScopeID,@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID)            
--Round Value Negative(-)            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate ,TransId,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate ,@GRNRefNo ,82,ABS(@RoundOffAmt),0,0,'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,            
@UID ,GETDATE (),@ScopeID,@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID)            
            
END            
END            
IF(ISNULL(@TotalAddnlDiscAmt,0) +ISNULL(@TotalProdDiscAmt,0) +ISNULL(@TotalTradeDiscAmt,0))>0            
BEGIN            
SELECT @JVID=ISNULL(MAX(JVID),0)+1 FROM tblFAJournal            
--All Discount Sum Of posting            
--Purchase Account            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate,TransId ,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate ,@GRNRefNo ,76,0,(ISNULL(@TotalAddnlDiscAmt,0) +ISNULL(@TotalProdDiscAmt,0) +ISNULL(@TotalTradeDiscAmt,0)),0,            
'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,@UID ,GETDATE (),@ScopeID,@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID)            
--Discout On Purchase            
INSERT INTO tblFAJournal([DocID],[DocPrefix],[DocValue],[DocDate],[DocRef],[AccountID],[Credit],[Debit],[Balance],[Remarks],[Narration],[Status],            
CBy ,CDate ,TransId,UDFId,UDFDocId,UDFDocPrefix,UDFDocValue,JVID,Adjusment,BranchID)            
VALUES (@DocId, 1, @DocValue,@BillDate ,@GRNRefNo ,31,(ISNULL(@TotalAddnlDiscAmt,0) +ISNULL(@TotalProdDiscAmt,0) +ISNULL(@TotalTradeDiscAmt,0)),0, 0,            
'','Purchase Bill',CASE WHEN ISNULL(@ImportStatus,0) = 0 THEN @Status ELSE @ImportStatus END,@UID ,GETDATE (),@ScopeID,@UDFId,@UDFDocId,@UDFDocPrefix,@UDFDocValue,@JVID,0,@BranchID)            
END            
            
END            
IF @PaymentModeId != 7            
BEGIN            
DECLARE @Header tvpCollHeader,@Detail tvpCollDetail,@Mop tvpCollMop,@ReceivedAmt DECIMAL (25,6) ,@BankAccNo NVARCHAR(20),            
@BankAccId INT ,@CDNumber NVARCHAR(255) ,@CDId INT ,@CDDate NVARCHAR(25),@PayAt NVARCHAR(20),@IFSC NVARCHAR(20),@Bank NVARCHAR(255),            
@Branch NVARCHAR(255),@NEFTId NVARCHAR(255),@VMId NVARCHAR(20),@VMTransID NVARCHAR(20),@PaymentCount INT, @PaymentIndex INT,          
@InvCurrentAmt DECIMAL (25,6),@VisaPern DECIMAL (25,6), @VisaAmt DECIMAL (25,6)            
SET @InvCurrentAmt=@TotalNetAmt - ISNULL(@TDSAmt,0);            
--Get Vendor Acc Id            
SELECT @Accid=FAID FROM tblMasterVendor WHERE id =@VendorId            
--Collection            
SET @PaymentCount=(SELECT COUNT(*) FROM @tvpTranBillMop)            
SET @PaymentIndex=1            
WHILE @PaymentCount >0            
BEGIN            
SELECT @PaymentModeId=[PayModeId],@CDId=[ChequeId],@CDNumber=[Cheque_OR_DDNumber_OR_NEFTId],@BankAccNo=[BankAccNo],@BankAccID=[BankAccID],            
@CDDate=[PMDate],@PayAt=[PayAt],@IFSC=[IfscCode],@Bank=[Bank] ,@Branch=[Branch] ,@ReceivedAmt=[Amt],@Balance=[RecdAmt],@VisaPern = [VisaPern], @VisaAmt = [VisaAmt]            
FROM @tvpTranBillMop WHERE [SerialNo]=@PaymentIndex            
--Transaction Bill payment detail            
INSERT INTO tblTran_Sale_Bill_PaymentDetail(TransId,InvId,[PayModeId],[ChequeNo],[Cheque_OR_DDNumber_OR_NEFTId],Acc_OR_PaytermId,[PMDate],[PayAt],[IfscCode],[Bank] ,            
[Branch] ,[Amt] ,[SerialNo],RecdAmt,Visaper,VisaAmt )VALUES(1,@ScopeID,@PaymentModeId,@CDId,@CDNumber,@BankAccID,@CDDate,@PayAt,@IFSC,@Bank,@Branch,@ReceivedAmt ,@PaymentIndex,@Balance,@VisaPern,@VisaAmt)            
            
IF @PaymentModeId !=7            
BEGIN            
--Col Header            
INSERT INTO @Header VALUES(CONVERT(NVARCHAR(50),@BillDate,103),0 ,@GRNRefNo ,@Accid,@ReceivedAmt ,0,@PaymentModeId,1 ,0,@UID,1,@PaymentIndex,@VisaPern,@VisaAmt) --Mop Detail            
IF @PaymentModeId !=3            
BEGIN            
INSERT INTO @Mop VALUES(@Accid,@PaymentModeId,@CDId ,CONVERT(NVARCHAR(50),@CDDate,103),@BankAccId ,@CDNumber,@ReceivedAmt,@IFSC ,@Bank ,@Branch ,@PayAt,@BankAccNo,            
(CASE WHEN @PaymentModeId =3 THEN NULL ELSE @CDNumber END), @CDId,@PaymentIndex,@Balance)            
END            
ELSE            
BEGIN            
INSERT INTO @Mop VALUES(@Accid,@PaymentModeId,@CDNumber ,CONVERT(NVARCHAR(50),@CDDate,103),@BankAccId ,'',@ReceivedAmt,@IFSC ,@Bank ,@Branch ,@PayAt,@BankAccNo,            
(CASE WHEN @PaymentModeId =3 THEN NULL ELSE @CDNumber END), @CDId,@PaymentIndex,@Balance)            
END            
-- Col Detail            
INSERT INTO @Detail VALUES(@Accid,1,@DocValue, @ScopeID,@BillDate,ISNULL(@InvCurrentAmt,0),ISNULL(@ReceivedAmt,0),0,0,0,0,0,ISNULL(@ReceivedAmt,0),1,@PaymentIndex,0)            
--Amount Calculate            
SET @InvCurrentAmt=@InvCurrentAmt-@ReceivedAmt;            
END            
SET @PaymentCount=@PaymentCount-1;            
SET @PaymentIndex=@PaymentIndex+1;            
END            
            
-- Get UDN for Payment            
DECLARE @UDFCount INT,@UDNSingle INT            
SET @UDFCount = (            
SELECT COUNT(DISTINCT UDNId) FROM tblMasterUserDefineNoDetail            
WHERE UDNId IN (SELECT UDNId FROM tblMastERUserDefineNoHeader WHERE TransID=18) AND UserId=@UID            
)            
IF ISNULL(@UDFCount,0)=1            
BEGIN            
SET @UDNSingle = (SELECT DISTINCT UDNId FROM tblMasterUserDefineNoDetail WHERE UDNId IN (SELECT UDNId FROM tblMasterUserDefineNoHeader WHERE TransId=18)AND UserId=@UID )            
END            
            
--Payment Implicit Posting            
EXEC uspManageFullColl 18,@UDNSingle,@Header,@Detail,@Mop,1,0,0,@nAllowNegativeBal,@tvpSaveDenomination,NULL,NULL,NULL,0,@Remarks,@Narration,@BranchID            
            
            
ENd            
            
IF(ISNULL(@DraftID,0) > 0 and isnull(@FilterType,0) = 2)            
BEGIN            
UPDATE tblPurchaseDraftHeader SET Status = 8,MBy = @UID,MDate = GETDATE() WHERE ID = @DraftID            
END            
IF(ISNULL(@TempPOID,0) > 0 and isnull(@FilterType,0) = 3)            
BEGIN            
UPDATE tblPurchaseOrderHeader SET GRNId=@ScopeID,Status=5,Mby=@UID,Mdate=GETDATE() WHERE ID=@TempPOID            
END            
SELECT @ScopeID AS IdentId            
            
END TRY            
BEGIN CATCH            
SELECT ERROR_MESSAGE() ,ERROR_PROCEDURE() ,ERROR_LINE()            
END CATCH

GO
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.uspManageTransPurchaseBill')) LIKE N'%/*p2:07%' PRINT N'dbo.uspManageTransPurchaseBill : changed';
GO
SET NOEXEC OFF;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO