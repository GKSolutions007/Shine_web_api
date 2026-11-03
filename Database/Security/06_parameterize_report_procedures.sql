/* =====================================================================================
   06  Parameterise dynamic SQL in the report procedures (SQL-injection fix, point 10)
   Generated from the schema export of WSHINE_TEST01_APR2026 (script.ipynb, 29-10-2026).
   Run in SSMS against the target database after 01. Each procedure is its own batch.
   Rollback: 06_rollback_report_procedures.sql restores the exported definitions.

   What changed in each procedure:
     - EXEC(@sql) became EXEC sys.sp_executesql @sql, N'<procedure parameters>', <values>.
     - Filter values that were spliced in as text ('''+@X+''', CONVERT(NVARCHAR,@X)) are now
       referenced as @X inside the dynamic SQL, so a quote in a value can no longer change the query.
     - Comma lists that were spliced into IN (...) now go through dbo.fnSplitString(@X, N',').
     - Table / database names are quoted with QUOTENAME (and resolved with OBJECT_ID / DB_ID first).
     - Result columns, filters and sort order are unchanged.

   Procedures (51): uspAvailableBookStockDetail, uspAvailableBookStockHeader, uspBMSWiseLoadingSlipReport, uspCustomerHeaderReportDetail, uspCustomerHeaderReportHeader, uspDateWiseSaleReport, uspExportIRNData, uspFinRepDetailedTrailBalance, uspGetCustomerWiseSalesHeader, uspGetCustWiseMonthlySalesHeader, uspGetDatewiseDetail, uspGetFullGSTInfoReport, uspGetJsonDataforEWaybill, uspgetsetBRSData, uspGetsetDailyactivityData, uspgetsetDiscountSchemeData, uspGetsetMobileSRDRData, uspGetSinglemasterdata, uspGetStockAgeingHeader, uspInActiveCustomerHeader, uspLoadDeliveryDocumentData_new, uspManageSingleMaster, uspManageTaxCompGift, uspManufSalesableDmgReturnAnalysis, uspManufwiseStockHoldingHeader, uspMfrwisesalesDetail, uspMfrwisesalesHeader, uspMonthlyWiseSalesFooter, uspMonthlyWiseSalesHeader, uspMonthwisesalesAnalticsReport, uspNilStockHeader, uspProductBatchHistoryHeader, uspProductWiseCustomerWiseSalesDetail, uspProductWiseCustomerWiseSalesHeader, uspReasonwiseAnalysisHeader, uspRepAccountLedger, uspRepCustomerMfrAnalysisHeader, uspRepCustomerProductSales, uspRepDoubleMasterData, uspRepInventoryAdjustmentDetail, uspRepInventoryAdjustmentHeader, uspRepInvoiceOS, uspRepItemLedger, uspRepItemwiseclosingstockheader, uspRepMasterProductData, uspRepMasterSalesmanData, uspReportScript, uspRepSingleMasterData, uspShrinkDataBase, uspUpdateEwayInTrans, uspVendorReport

   Reviewed and deliberately left unchanged (only typed INT/DATE values or internal values reach the dynamic SQL,
   so they are not injectable; they sit on transaction screens where a rewrite would need a full retest):
     uspGetProdInventoryInSalesReturn, uspGetPRProductIntoryBatch, uspGetsetMobileCollectionData,
     uspGetSetWebCollectionData, uspManageCustomerMaster, uspKillTran, uspMobileCustomerOS,
     uspRepBeatSalesmanWiseAgeingHeader, uspRepBeatwiseOutstandingsHeader (ageing buckets are cast to INT first),
     uspRepCustomerwiseWeeklyAnalysisHeader, uspRepMonthlywiseAnalysisByCustomerHeader (no parameter is concatenated).   ===================================================================================== */
SET NOCOUNT ON;
GO/****** uspAvailableBookStockDetail ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspAvailableBookStockDetail]      
@QtyType NVARCHAR(10) = '2' ,@ProductId INT = 2,@BranchID int = 4    
as    
begin    
DECLARE @query NVARCHAR(MAX)      
set @query = '      
SELECT MP.Code [Product Code],MP.Name [Product Name],[PI].BatchNumber AS [Batch Number],CONVERT(NVARCHAR,[PI].pkdDate,103)AS [PKD Date],CONVERT(NVARCHAR,[PI].ExpiryDate,103)        
AS [Expiry Date],Uom.Name AS [Base UOM],dbo.fngetroundedvalue(isnull((SUM([PI].ActualQty + [PI].ActualFreeQty + [PI].ActualDmgQty)),0)) As [Total Qty],        
dbo.fngetroundedvalue(isnull((SUM([PI].ActualQty)),0)) AS [Saleable Qty],        
dbo.fngetroundedvalue(isnull((SUM([PI].ActualFreeQty)),0)) AS [Free Qty],        
dbo.fngetroundedvalue(isnull((SUM([PI].ActualDmgQty)),0) )AS[Damage Qty],        
dbo.fngetroundedvalue(isnull(([PI].PurchasePrice),0)) AS[Purchase Price],        
dbo.fngetroundedvalue(isnull(([PI].SalesPrice),0)) AS [Sales Price],        
dbo.fngetroundedvalue(isnull(([PI].ECP),0)) AS [ECP],        
dbo.fngetroundedvalue(isnull(([PI].SPLPrice),0)) AS [SPL Price],        
dbo.fngetroundedvalue(isnull(([PI].MRPONPrice),0)) AS [MRP] ,  dbo.fngetroundedvalue(isnull(([PI].ReturnPrice),0)) AS [Return Price] ,       
dbo.fngetroundedvalue(isnull((SUM([PI].ActualQty)* ([PI].PurchasePrice)),0)) AS [Stock Value],  
dbo.fngetroundedvalue(isnull((SUM([PI].ActualDmgQty)* ([PI].PurchasePrice)),0)) AS [Damage Stock Value]     
FROM tblProductInventory AS [PI]        
LEFT JOIN tblMasterProduct AS MP ON MP.ID = [PI].Prodid        
LEFT JOIN tblMasterUom AS Uom ON Uom.ID  = MP.BaseUomID       
WHERE  MP.ID = @ProductId  and [PI].Branchid =  @BranchID '      
set @query += case when ISNULL(@QtyType,1) = 1 then ' and ([PI].ActualQty > 0 OR [PI].ActualFreeQty > 0 OR [PI].ActualDmgQty > 0)' else '' END        
 set @query += ' GROUP BY MP.Code,MP.Name,[PI].Prodid,[PI].BatchNumber,[PI].pkdDate,[PI].ExpiryDate,Uom.Name,        
[PI].PurchasePrice,[PI].SalesPrice,[PI].MRPONPrice,[PI].ECP,[PI].SPLPrice,[PI].ReturnPrice '    
EXEC sys.sp_executesql @query, N'@QtyType NVARCHAR(10), @ProductId INT, @BranchID int', @QtyType, @ProductId, @BranchID    
end  
GO

/****** uspAvailableBookStockHeader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspAvailableBookStockHeader]      
@BranchName NVARCHAR(255) = '',  @ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',@ProductName NVARCHAR(255)='',      
@QtyType int = 1      
AS      
BEGIN      
DECLARE @query NVARCHAR(MAX)      
set @query = '      
SELECT  @QtyType  QtyType,Prod.ID ProductID,isnull(PInv.BranchID,0) BranchID,MBO.Name [Branch Name],Prod.Code AS [Product Code],Prod.Name AS [Product Name],    
Prod.EAN,MF.Name as[Manufacture Name],MB.Name as [Brand Name],HI.Name as[Category Name],UOMBase.Name as [Base UOM],    
dbo.fngetroundedvalue(SUM(PInv.ActualQty)) AS [Saleable Qty],dbo.fngetroundedvalue(SUM(PInv.ActualFreeQty)) AS [Free Qty],    
dbo.fngetroundedvalue(SUM(PInv.ActualDmgQty)) AS [Damage Qty],dbo.fngetroundedvalue(SUM(PInv.ActualQty) / Prod.PurchaseCR) AS [Purchase UOM Qty],    
UOMPur.Name AS [Purchase UOM],dbo.fngetroundedvalue(SUM(PInv.ActualQty) / Prod.SalesCR) AS [Sales UOM Qty],    
UOMSale.Name AS [Sales UOM],    
dbo.fngetroundedvalue((SUM(PInv.ActualQty) / (CASE WHEN ISNULL(Prod.ReportingQty,0)=0 THEN 1 ELSE (Prod.ReportingQty) END))) AS [Reporting UOM Qty],    
UOMRep.Name AS [Reporting UOM],dbo.fngetroundedvalue(SUM((PInv.ActualQty) * (PInv.PurchasePrice))) AS [Actual Stock Value],    
dbo.fngetroundedvalue(SUM((PInv.ActualDmgQty) * (PInv.PurchasePrice))) AS [Damage Stock Value]    
FROM tblProductInventory AS PInv    
JOIN tblMasterProduct AS Prod ON Prod.ID =PInv.ProdId    
JOIN TBLMASTERBRANCHOFFICE MBO ON MBO.ID = PInv.BranchID     
JOIN tblMasterUOM AS UOMPur ON UOMPur.ID = Prod.PurchaseUomID    
JOIN tblMasterUOM AS UOMSale ON UOMSale.ID = Prod.SalesUomID    
JOIN tblMasterUOM AS UOMRep ON UOMRep.ID = Prod.ReportingUomID    
JOIN tblMasterUOM AS UOMBase ON UOMBase.ID = Prod.BaseUomID    
JOIN tblMasterManufacturer MF ON MF.ID =Prod.MfrID    
JOIN tblMasterCategory as HI ON HI.ID =Prod.CategoryID    
JOIN tblMasterBrand as MB on MB.ID = Prod.BrandID WHERE Prod.ID > 0'    
 set @query += case when ISNULL(@QtyType,1) = 1 then ' and (PInv.ActualQty > 0 OR PInv.ActualFreeQty > 0 OR PInv.ActualDmgQty > 0)' else '' END        
 set @query += case when ISNULL(@BranchName,0) = 0 then '' else ' AND PInv.BranchID = '+' @BranchName '+'' END        
 set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND MB.ID IN (SELECT * from dbo.fnSplitString( '+' @BrandName ,'',''))' END        
 set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND HI.ID IN (SELECT * from dbo.fnSplitString( '+' @CategoryName ,'',''))' END        
 set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND MF.ID IN (SELECT * from dbo.fnSplitString( '+' @ManufName ,'',''))' END        
 set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND Prod.ID IN (SELECT * from dbo.fnSplitString( '+' @ProductName ,'',''))' END        
 set @query += ' GROUP BY Prod.MfrID,MB.ID,HI.ID, Prod.ID,Prod.Code,Prod.EAN,Prod.Name,MF.Name,Mb.Name,HI.Name,    
Prod.PurchaseUomID,Prod.SalesUomID,Prod.ReportingUomID,Prod.ReportingQty,UOMPur.Name,    
UOMSale.Name,UOMRep.Name,UOMBase.Name,Prod.PurchaseCR ,Prod.SalesCR,PInv.BranchID,MBO.Name order by Prod.Name'    
EXEC sys.sp_executesql @query, N'@BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @QtyType int', @BranchName, @ManufName, @BrandName, @CategoryName, @ProductName, @QtyType    
END
GO

/****** uspBMSWiseLoadingSlipReport ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspBMSWiseLoadingSlipReport]                    
@BranchName NVARCHAR(255) = '0',@ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',@ProductName NVARCHAR(255) = '',@BeatName NVARCHAR(255) = '',                  
@SalesmanName NVARCHAR(255) = '',@DocRange NVARCHAR(MAX) = '', @FromDate DATE = '2024-08-01',@ToDate DATE = '2026-08-30'                  
AS                  
BEGIN                  
CREATE TABLE #TempProducts (                
    [Product Code]       VARCHAR(50),                
    [Product Name]       VARCHAR(255),                
    EAN               VARCHAR(50),                
    [Mfr Name]           VARCHAR(255),                
    [Brand Name]         VARCHAR(255),                
    [Category Name]      VARCHAR(255),                
    [Base UOM Qty]        DECIMAL(18, 2),                
    [Base UOM]           VARCHAR(50),                
    [Sales UOM Qty]       DECIMAL(18, 2),                
    [Sales UOM]          VARCHAR(50),                
    [Reporting UOM 1 Qty]  DECIMAL(18, 2),                
    [Reporting UOM 1]     VARCHAR(50),                
    [Reporting UOM 2 Qty]  DECIMAL(18, 2),                
    [Reporting UOM 2]     VARCHAR(50),                
    [MRP On Price]       DECIMAL(18, 2),                
    [Value]             DECIMAL(18, 2)                
);                
                
declare @StrQuery nvarchar(max) = ''                    
set @StrQuery = '                  
SELECT  Temp.[Product Code],Temp.[Product Name],Temp.EAN,Temp.[Manufacturer Name] [Mfr Name],                  
[Brand Name],[Category Name],dbo.fnGetRoundedValue(SUM(Temp.[Base UOM Qty]))AS [Base UOM Qty],                  
[Base UOM],dbo.fnGetRoundedValue(SUM(Temp.[Sales UOM Qty]))AS [Sales UOM Qty],[Sales UOM],                  
dbo.fnGetRoundedValue(Left(SUM([Reporting UOM Qty]), CharIndex(''.'',SUM([Reporting UOM Qty]))-1))AS [Reporting UOM 1 Qty],[Reporting Uom] [Reporting UOM 1],                  
dbo.fnGetRoundedValue((((RIGHT(SUM([Reporting UOM Qty]), len(SUM([Reporting UOM Qty])) - CharIndex(''.'',SUM([Reporting UOM Qty]))+1))*ReportingQty)/ConvFact)) AS [Reporting UOM 2 Qty],                  
[Base UOM] [Reporting UOM 2],dbo.fnGetRoundedValue(ISNULL(Temp.[MRP On Price],0)) AS [MRP On Price],dbo.fnGetRoundedValue(SUM(Temp.Value)) AS [Value] FROM (                  
SELECT MP.Code AS [Product Code],MP.Name AS [Product Name],MP.EAN,                  
MMF.Name AS [Manufacturer Name],MBN.Name [Brand Name],PHL.Name [Category Name],                  
(CASE WHEN TSD.DocPrefix = 15 THEN SUM(TSH.UomQty * isnull(mp.BaseCR,1))                  
ELSE SUM(TSH.UomQty * isnull(mp.BaseCR,1) * -1) END) AS [Base UOM Qty],                  
sum(TSH.NetAmt) AS [Value],Uom.Name AS [Base UOM],Uom1.Name AS [Sales UOM],                  
(CASE WHEN TSD.DocPrefix = 15 THEN SUM((TSH.UomQty * isnull(mp.BaseCR,1)) /                  
isnull(MP.SalesCR,0))                  
ELSE SUM((TSH.UomQty * isnull(mp.BaseCR,1))                  
/ isnull(MP.SalesCR,0)) * -1 END) AS [Sales UOM Qty],                  
UOM2.Name AS [Reporting Uom],                  
CASE WHEN TSD.DocPrefix = 15 THEN (SUM((TSH.UomQty * isnull(mp.BaseCR,1)) / nullif(MP.ReportingQty,0)))                  
ELSE (SUM((TSH.UomQty * isnull(mp.BaseCR,1)) / nullif(MP.ReportingQty,0))) * -1 end as [Reporting UOM Qty],                  
TSH.DetailMRP AS [MRP On Price],MP.ReportingQty,isnull(mp.BaseCR,1) ConvFact                  
FROM tblTranSalesHeader AS TSD                  
JOIN tblTranSalesDetail AS TSH ON TSH.InvId = TSD.ID                  
JOIN tblMasterProduct AS MP ON MP.ID = TSH.ProdId                  
JOIN tblMasterManufacturer AS MMF ON MMF.ID = MP.MfrID                  
JOIN tblMasterBrand MBN ON MBN.ID = MP.BrandID                  
JOIN tblMasterCategory PHL ON PHL.ID = MP.CategoryID                  
JOIN tblMasterBranchOffice BOF ON BOF.ID = TSD.BranchID                  
LEFT JOIN tblProductInventory AS PInv ON PInv.InventoryId = TSH.InventoryId                  
LEFT JOIN tblMasterBeat AS MB ON MB.ID = TSD.BeatID                  
LEFT JOIN tblMasterSalesMan AS MSM ON MSM.ID = TSD.SalesManId                  
LEFT JOIN tblMasterUom AS Uom ON Uom.ID = MP.BaseUomID                  
LEFT JOIN tblMasterUom AS Uom1 ON Uom1.ID = MP.SalesUomID                  
left JOIN tblMasterUom AS [UOM2] ON UOM2.ID = mp.ReportingUomID                  
WHERE TSD.Status IN (1,3,5) AND DocPrefix=15 AND TSH.TaxID > 0 '                  
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSD.InvDate BETWEEN  @FromDate  AND  @ToDate )' END)        
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString(  @BeatName ,'',''))' END)                            
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND MSM.ID IN (SELECT * from dbo.fnSplitString(  @SalesmanName ,'',''))' END)                         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ManufName,'')='' THEN '' ELSE ' AND MMF.ID IN (SELECT * from dbo.fnSplitString(  @ManufName ,'',''))' END)                         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BrandName,'')='' THEN '' ELSE ' AND MBN.ID IN (SELECT * from dbo.fnSplitString(  @BrandName ,'',''))' END)                            
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CategoryName,'')='' THEN '' ELSE ' AND PHL.ID IN (SELECT * from dbo.fnSplitString(  @CategoryName ,'',''))' END)                     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ProductName,'')='' THEN '' ELSE ' AND MP.ID IN (SELECT * from dbo.fnSplitString(  @ProductName ,'',''))' END)                     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND BOF.ID =  @BranchName ' END)                     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocRange,'')='' THEN '' ELSE ' AND TSD.DocValue IN (SELECT DocValue FROM dbo.SplitDocRange( @DocRange )) ' END)     
SET @StrQuery = @StrQuery + '                   
GROUP BY MP.Code,MP.ReportingQty,TSH.UomId,MP.Name,MP.EAN,MMF.Name,Uom.Name, Uom1.Name ,TSH.DetailMRP,TSD.DocPrefix,TSD.ID,MBN.Name,                  
PHL.Name,Uom2.Name,mp.BaseCR)AS Temp                  
GROUP BY Temp.[Product Code],Temp.[Product Name],Temp.EAN,Temp.[Manufacturer Name],                  
[Base UOM],[Sales UOM],[MRP On Price],[Brand Name],[Category Name],[Reporting Uom],ReportingQty,ConvFact'           
PRINT @StrQuery    
 EXEC sys.sp_executesql @StrQuery, N'@BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @DocRange NVARCHAR(MAX), @FromDate DATE, @ToDate DATE', @BranchName, @ManufName, @BrandName, @CategoryName, @ProductName, @BeatName, @SalesmanName, @DocRange, @FromDate, @ToDate                    
END
GO

/****** uspCustomerHeaderReportDetail ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspCustomerHeaderReportDetail]    
@CustomerID int =356, @CustomerType nvarchar(255) = '',@Ratings  nvarchar(255) = '',@BeatName  nvarchar(255) = '',
@SalesmanName  nvarchar(255) = '',@Location nvarchar(255) = ''
as    
begin    
DECLARE @strQuery NVARCHAR(MAX) = ''       
set @strQuery = '    
select MC.Code [Customer Code],MC.Name [Customer Name],MB.Name [Beat Name],SM.Name [Salesman Name] from tblmastercustomer MC    
LEFT join tblBeatSalesmanMapping BSM ON BSM.CustomerID = MC.ID    
LEFT JOIN tblMasterBeat MB ON MB.ID = BSM.BeatID    
LEFT JOIN tblMasterSalesman SM ON SM.ID = BSM.SalesmanID    
WHERE mc.id =  @CustomerID '    
SET @strQuery += CASE WHEN ISNULL(@BeatName,'') = '' THEN '' ELSE ' AND MB.Name = '+' @BeatName ' END            
SET @strQuery += CASE WHEN ISNULL(@SalesmanName,'') = '' THEN '' ELSE ' AND SM.Name = '+' @SalesmanName ' END      
EXEC sys.sp_executesql @strQuery, N'@CustomerID int, @CustomerType nvarchar(255), @Ratings nvarchar(255), @BeatName nvarchar(255), @SalesmanName nvarchar(255), @Location nvarchar(255)', @CustomerID, @CustomerType, @Ratings, @BeatName, @SalesmanName, @Location    
end 
GO

/****** uspCustomerHeaderReportHeader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspCustomerHeaderReportHeader]    
 @CustomerType nvarchar(255) = '',@Ratings  nvarchar(255) = '',@BeatName  nvarchar(255) = '',@SalesmanName  nvarchar(255) = '',
 @Location INT = 1
 as    
 begin    
DECLARE @strQuery NVARCHAR(MAX) = ''       
 select MC.ID,MC.Code [Customer Code],MC.Name [Customer Name],MCT.Name [Customer Type],MCT.ID [Customer ID] ,MC.Billadd1   AS [Bill Add 1],MC.Billadd2   AS [Bill Add 2],    
MC.Billadd3   AS [Bill Add 3],MC.Shipadd1   AS [Ship Add 1],MC.Shipadd2   AS [Ship Add 2],MC.Shipadd3   AS [Ship Add 3],    
    MC.Pincode,    
    MC.ContactPerson AS [Contact Person],    
    MC.Ph1        AS [Phone  1],    
    MC.Ph2        AS [Phone 2],    
    MC.Mob1       AS [Mobile 1],    
    MC.Mob2       AS [Mobile 2],    
    MC.Email,    
    MC.PANNumber  AS [PAN No],    
    MC.AadharNo   AS [Aadhar No],    
    MC.DLNo20     AS [DL No 20],    
    MC.DLNo21     AS [DL No 21],    
    MC.FSSAINo    AS [FSSAI No],    
    GST.StateName [State Name],    
    MC.GSTIN,    
    PM.PaymentMode [Payment Mode],      
    CT.Name [Credit Term],      
    PT.PriceType       AS [Price Type],    
    MTT.TaxTypeName [Tax Type],      
    MC.OverDueInvCount   AS [OverDue Inv Count],    
    dbo.fngetroundedvalue(MC.CreditLimitValue)  AS [Credit Limit Value],    
    MC.CreditLimitCount  AS [Credit Limit Count],    
    dbo.fngetroundedvalue(MC.CreditlimitOS)     AS [Credit Limit OS],        
    MC.OwnerName         AS [Owner Name],    
    dbo.fngetroundedvalue(MC.DiscountPern)      AS [Discount %],    
    case when MC.TrackPoint = 1 then 'Yes' ELSE 'No' end AS [Track Point],    
    dbo.fngetroundedvalue(MC.ClosingTrackPoint) AS [Closing Track Point],    
    case when MC.TCSTax = 1 then 'Yes' ELSE 'No' end AS [TCS Tax],    
    MC.Distance,    
    MC.Remark,    
    RT.RatingName Ratings,  
    RT.ID RatingsID,  
     CASE WHEN (MC.Latitude IS NOT NULL AND MC.Latitude != '') AND (MC.Longtitude IS NOT NULL AND MC.Longtitude != '') THEN 'Yes' ELSE 'No' END AS Location,
 CASE WHEN IMG.Filename IS NOT NULL THEN 'Yes' ELSE 'No' END AS Images,
    case when MC.Active = 1 then 'Yes' ELSE 'No' end Active,        
 MU.UserName [Created By],CONVERT(NVARCHAR,MC.CDate) [Create Date],        
 MUM.UserName [Modify By],CONVERT(NVARCHAR,MC.MDate) [Modify Date],MB.Name BeatName,MB.ID [BeatID],SM.Name SalesmanName,SM.ID [SalesmanID] ,MC.FAID
    INTO #TEMP
    from tblmastercustomer MC    
LEFT JOIN tblGSTStateNameandCode GST ON GST.StateID = MC.StateID      
left join tblMasterCustomertype MCT ON MCT.ID = MC.Customertype    
LEFT JOIN tblMasterCreditTerm CT ON CT.ID = MC.CreditTermID      
LEFT JOIN tblPaymentMode PM ON PM.ID = MC.PaymentModeID      
JOIN tblMasterTaxType MTT ON MTT.TaxTypeID = MC.TaxTypeID      
join tblPriceType PT ON PT.ID = MC.PriceTypeID    
LEFT JOIN tblRatings RT ON RT.ID = MC.Rating      
JOIN tblUsers MU ON MU.ID = MC.CBy              
LEFT JOIN tblUsers MUM ON MUM.ID = MC.MBy     
LEFT join tblBeatSalesmanMapping BSM ON BSM.CustomerID = MC.ID    
LEFT JOIN tblMasterBeat MB ON MB.ID = BSM.BeatID    
LEFT JOIN tblMasterSalesman SM ON SM.ID = BSM.SalesmanID
left join tblImages IMG ON IMG.ID = MC.ID AND IMG.FormID = 2
    
SET @strQuery = 'SELECT DISTINCT [ID],    
[Customer Code],    
[Customer Name],    
[Customer Type],    
[Bill Add 1],    
[Bill Add 2],    
[Bill Add 3],    
[Ship Add 1],    
[Ship Add 2],    
[Ship Add 3],    
[Pincode],    
[Contact Person],    
[Phone  1],    
[Phone 2],    
[Mobile 1],    
[Mobile 2],    
[Email],    
[PAN No],    
[Aadhar No],    
[DL No 20],    
[DL No 21],    
[FSSAI No],    
[State Name],    
[GSTIN],    
[Payment Mode],    
[Credit Term],    
[Price Type],    
[Tax Type],    
[OverDue Inv Count],    
[Credit Limit Value],    
[Credit Limit Count],    
[Credit Limit OS],    
[Owner Name],    
[Discount %],    
[Track Point],    
[Closing Track Point],    
[TCS Tax],    
[Distance],    
[Remark],    
[Ratings],    
[dbo].[fnGetRoundedValue]((dbo.fnGetClosingBal(FAID))) [OutStanding Value],
[Location],
[Images],
[Active],    
[Created By],    
[Create Date],    
[Modify By],    
[Modify Date] FROM #TEMP WHERE ID > 0 '    
--SET @strQuery += CASE WHEN ISNULL(@CustomerType,'') = '' THEN '' ELSE ' AND [Customer Type] = '+' @CustomerType ' END            
--SET @strQuery += CASE WHEN ISNULL(@Ratings,'') = '' THEN '' ELSE ' AND Ratings = '+' @Ratings ' END         
--SET @strQuery += CASE WHEN ISNULL(@BeatName,'') = '' THEN '' ELSE ' AND [BeatName] = '+' @BeatName ' END            
--SET @strQuery += CASE WHEN ISNULL(@SalesmanName,'') = '' THEN '' ELSE ' AND SalesmanName = '+' @SalesmanName ' END      
SET @strQuery += CASE WHEN ISNULL(@CustomerType,'') = '' THEN '' ELSE ' AND   
[Customer ID] IN (SELECT * from dbo.fnSplitString('+' @CustomerType ,'',''))' END            
SET @strQuery += CASE WHEN ISNULL(@Ratings,'') = '' THEN '' ELSE ' AND   
RatingsID IN (SELECT * from dbo.fnSplitString('+' @Ratings ,'',''))' END         
SET @strQuery += CASE WHEN ISNULL(@BeatName,'') = '' THEN '' ELSE ' AND   
[BeatID] IN (SELECT * from dbo.fnSplitString('+' @BeatName ,'',''))' END            
SET @strQuery += CASE WHEN ISNULL(@SalesmanName,'') = '' THEN '' ELSE ' AND   
SalesmanID IN (SELECT * from dbo.fnSplitString('+' @SalesmanName ,'',''))' END   

-- Location Filter mapping (1 = All, 2 = Yes, 3 = No)
SET @strQuery += CASE 
    WHEN @Location = 2 THEN ' AND [Location] = ''Yes'''
    WHEN @Location = 3 THEN ' AND [Location] = ''No'''
    ELSE '' 
END

SET @strQuery += ' ORDER BY [Customer Name] '      
EXEC sys.sp_executesql @strQuery, N'@CustomerType nvarchar(255), @Ratings nvarchar(255), @BeatName nvarchar(255), @SalesmanName nvarchar(255), @Location INT', @CustomerType, @Ratings, @BeatName, @SalesmanName, @Location     
DROP TABLE #TEMP    
end
GO

/****** uspDateWiseSaleReport ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspDateWiseSaleReport]      
@BranchName NVARCHAR(255) = '0',@BeatName NVARCHAR(255) = '',@SalesmanName NVARCHAR(255) = '',@CustomerName NVARCHAR(255) = '',@CustomerType NVARCHAR(255) = '',    
@Ratings NVARCHAR(255) = '',@FromDate DATE = '2025-04-01',@ToDate DATE = '2025-08-30'          
AS    
BEGIN    
SET DATEFORMAT dmy;        
declare @StrQuery nvarchar(max) = ''      
 set @StrQuery = '     
SELECT [Invoice Date] Date,                
FORMAT([Invoice Date],''dd-MMM-yyyy'') AS [Invoice Date],                
dbo.fnGetRoundedValue(SUM(iyan.[Total Sales])) AS [Total Sales Amount],                
dbo.fnGetRoundedValue(SUM(iyan.[Salable Return])) AS [Total Saleable Return],                
dbo.fnGetRoundedValue(SUM(iyan.[Damage Return])) AS [Total Damage Return],                
dbo.fnGetRoundedValue((SUM(iyan.[Total Sales]))-(SUM(iyan.[Salable Return]) + SUM(iyan.[Damage Return]))) AS [Net Effect Value],                
dbo.fnGetRoundedValue(sum(iyan.[Total Product Disc Amt])) AS  [Total Product Disc Amt],                
dbo.fnGetRoundedValue(sum(iyan.[Total Trade Disc Amt])) AS [Total Trade Disc Amt],                
dbo.fnGetRoundedValue(sum(iyan.[Additional Disc Amt])) AS [Additional Disc Amt]    
FROM (                
SELECT TSH.ID,TSH.InvDate AS [Invoice Date],                
CASE WHEN TransactionType IN (1,4,5,6) THEN (ISNULL(TSH.NetAmt,0)) ELSE ISNULL(0.00,0) END AS [Total Sales] ,                
CASE WHEN TransactionType=2 THEN (ISNULL(TSH.NetAmt,0)) ELSE ISNULL(0.00,0) END AS [Salable Return],                
CASE WHEN TransactionType=3 THEN (ISNULL(TSH.NetAmt,0)) ELSE ISNULL(0.00,0) END AS [Damage Return],                
(CASE WHEN DocPrefix=15 THEN SUM(ISNULL(TSH.TotalProdDiscAmt,0)) ELSE -1 * SUM(ISNULL(TSH.TotalProdDiscAmt,0)) END )as [Total Product Disc Amt],                
(CASE WHEN DocPrefix=15 THEN SUM(ISNULL(TSH.TotalTradeDiscAmt,0)) ELSE -1 * SUM(ISNULL(TSH.TotalTradeDiscAmt,0)) END) as [Total Trade Disc Amt],                
(CASE WHEN DocPrefix=15 THEN SUM(ISNULL(TSH.AdditionalDiscAmt,0)) ELSE -1* SUM(ISNULL(TSH.AdditionalDiscAmt,0)) END) as [Additional Disc Amt]    
FROM [tblTranSalesHeader] AS TSH          
JOIN tblMasterCustomer MC ON MC.ID= TSH.CustID    
LEFT JOIN tblMasterBeat AS Beat ON Beat.ID = TSH.BeatID          
LEFT JOIN tblMasterSalesMan AS SM ON SM.ID = TSH.SalesManId          
LEFT JOIN tblMasterCustomerType AS MCT ON MCT.ID = MC.CustomerType     
LEFT JOIN tblRatings AS RT ON RT.ID = MC.Rating    
WHERE TransactionType IN(1,2,3,4,5,6) AND TSH.Status IN (1,3,5,6,7) '    
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN  @FromDate  AND  @ToDate )' END)                  
  
    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND TSH.BranchID =  @BranchName ' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND Beat.ID IN (SELECT * from dbo.fnSplitString(  @BeatName ,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SM.ID IN (SELECT * from dbo.fnSplitString(  @SalesmanName ,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString(  @CustomerName ,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN (SELECT * from dbo.fnSplitString(  @CustomerType ,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN (SELECT * from dbo.fnSplitString(  @Ratings ,'',''))' END)     
SET @StrQuery = @StrQuery + '    
GROUP BY TSH.InvDate, TransactionType,TSH.ID,TSH.NetAmt,DocPrefix          
) AS iyan  GROUP BY  iyan.[Invoice Date] ORDER BY CONVERT(DATE,[Invoice Date])  '    
EXEC sys.sp_executesql @StrQuery, N'@BranchName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BranchName, @BeatName, @SalesmanName, @CustomerName, @CustomerType, @Ratings, @FromDate, @ToDate    
END
GO

/****** uspExportIRNData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--uspExportIRNData 1,'2025-01-01','2025-08-01',NULL  
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspExportIRNData]  
@SheetMode INT,@FromDate date = '2025-01-01',@ToDate DATE= '2025-08-01',@DocIDs NVARCHAR(MAX)=NULL  
AS  
BEGIN  
DECLARE @QRY NVARCHAR(MAX)  
IF(@SheetMode = 1)  
BEGIN  
--declare @FromDate DATE = '2023-05-12',@ToDate DATE = '2023-05-13'  
SELECT TransID,TransIdentID,(SUM(RAM.[CGST %])) AS [CGST %],SUM((RAM.[CGST Amount])) AS [CGST Amount],  
(SUM(RAM.[SGST %])) AS [SGST %],(SUM(RAM.[SGST Amount])) AS [SGST Amount],(SUM(RAM.[UTGST %])) AS [UTGST %],  
SUM((RAM.[UTGST Amount])) AS [UTGST Amount],(SUM(RAM.[GCESS %])) AS [GCESS %],SUM((RAM.[GCESS Amount])) AS [GCESS Amount],  
(SUM(RAM.[IGST %])) AS [IGST %],SUM((RAM.[IGST Amount])) AS [IGST Amount],(SUM(RAM.[ICESS %])) AS [ICESS %],  
SUM((RAM.[ICESS Amount])) AS [ICESS Amount],SUM([GUOM %]) [GUOM %],SUM([IUOM %]) [IUOM %],  
SUM(RAM.[GUOM Amount]) [GUOM Amount],SUM(RAM.[IUOM Amount]) [IUOM Amount],  
SUM([GCESS Amount] + [ICESS Amount] + [GUOM Amount] + [IUOM Amount]) [Cumulative CESS Amount] INTO #TaxHeaer  
FROM  
(  
SELECT SRI.TransID,SRI.TransIdentID,  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[CGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 1 AND GSTTaxType = 1),0)) AS [CGST %],  
(ISNULL(SRI.[CGST Amount],0)) AS [CGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[SGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 1 AND GSTTaxType = 2),0)) AS [SGST %],  
(ISNULL(SRI.[SGST Amount],0)) AS [SGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[UTGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 1 AND GSTTaxType = 3),0)) AS [UTGST %],  
(ISNULL(SRI.[UTGST Amount],0)) AS [UTGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[GCESS Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 1 AND GSTTaxType = 4),0)) AS [GCESS %],  
(ISNULL(SRI.[GCESS Amount],0)) AS [GCESS Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[GUOM Amount],0)=0 THEN 0 ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 1 AND GSTTaxType = 5),0)) AS [GUOM %],  
(ISNULL(SRI.[GUOM Amount],0)) AS [GUOM Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[IGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 2 AND GSTTaxType = 1),0)) AS [IGST %],  
(ISNULL(SRI.[IGST Amount],0)) AS [IGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[ICESS Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 2 AND GSTTaxType = 2),0)) AS [ICESS %],  
(ISNULL(SRI.[ICESS Amount],0)) AS [ICESS Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[IUOM Amount],0)=0 THEN 0 ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 2 AND GSTTaxType = 3),0)) AS [IUOM %],  
(ISNULL(SRI.[IUOM Amount],0)) AS [IUOM Amount]  
FROM  
(  
SELECT * FROM  
(  
SELECT Temp.TransID,Temp.TransIdentID,Temp.TaxTypeID,Temp.TaxID,Temp.[GST Comp],  
Temp.TaxName AS TaxName,  
SUM(Temp.TaxValue) AS [TaxValue]  
FROM  
(  
SELECT GSTInfo.TransID,GSTInfo.TransIdentID,MT.TaxID,GSTInfo.TaxTypeID,MT.TaxName,GSTInfo.TaxCompPern,GSTInfo.TaxValue,  
CASE  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=1 AND GSTInfo.TaxTypeID = 1 THEN 'CGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=2 AND GSTInfo.TaxTypeID = 1 THEN 'SGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=3 AND GSTInfo.TaxTypeID = 1 THEN 'UTGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=4 AND GSTInfo.TaxTypeID = 1 THEN 'GCESS Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=5 AND GSTInfo.TaxTypeID = 1 THEN 'GUOM Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=1 AND GSTInfo.TaxTypeID = 2 THEN 'IGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=2 AND GSTInfo.TaxTypeID = 2 THEN 'ICESS Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=3 AND GSTInfo.TaxTypeID = 2 THEN 'IUOM Amount'  
END AS [GST Comp]  
FROM tblTransGSTInfo AS GSTInfo  
JOIN tblTranSalesHeader SH ON SH.ID = GSTInfo.TransIdentID AND SH.DocPrefix = GSTInfo.TransID  
JOIN tblMasterTax AS MT ON MT.TaxID = GSTInfo.TaxID  
WHERE (TransID=15 or TransID=16) AND Status IN (1,3,5,6,7) AND InvDate BETWEEN @FromDate AND @ToDate  
) Temp  
GROUP BY Temp.[GST Comp],Temp.TaxCompPern,Temp.TaxName,Temp.TaxID,Temp.TaxTypeID ,Temp.TransID,Temp.TransIdentID  
) src  
PIVOT  
(  
SUM([TaxValue])  
FOR [GST Comp] in ([CGST %],[CGST Amount],[SGST %],[SGST Amount],[UTGST %],[UTGST Amount],[GCESS %],[GCESS Amount],[IGST %],[IGST Amount],[ICESS %],[ICESS Amount],[GUOM Amount],[IUOM Amount])  
) piv  
) AS SRI  
) AS RAM  
GROUP BY TransID,TransIdentID  
--SELECT * FROM #Tax  
-- PR  
SELECT TransID,TransIdentID,(SUM(RAM.[CGST %])) AS [CGST %],SUM((RAM.[CGST Amount])) AS [CGST Amount],  
(SUM(RAM.[SGST %])) AS [SGST %],(SUM(RAM.[SGST Amount])) AS [SGST Amount],(SUM(RAM.[UTGST %])) AS [UTGST %],  
SUM((RAM.[UTGST Amount])) AS [UTGST Amount],(SUM(RAM.[GCESS %])) AS [GCESS %],SUM((RAM.[GCESS Amount])) AS [GCESS Amount],  
(SUM(RAM.[IGST %])) AS [IGST %],SUM((RAM.[IGST Amount])) AS [IGST Amount],(SUM(RAM.[ICESS %])) AS [ICESS %],  
SUM((RAM.[ICESS Amount])) AS [ICESS Amount],SUM([GUOM %]) [GUOM %],SUM([IUOM %]) [IUOM %],  
SUM(RAM.[GUOM Amount]) [GUOM Amount],SUM(RAM.[IUOM Amount]) [IUOM Amount],  
SUM([GCESS Amount] + [ICESS Amount] + [GUOM Amount] + [IUOM Amount]) [Cumulative CESS Amount] INTO #TaxPRHeaer  
FROM  
(  
SELECT SRI.TransID,SRI.TransIdentID,  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[CGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 1 AND GSTTaxType = 1),0)) AS [CGST %],  
(ISNULL(SRI.[CGST Amount],0)) AS [CGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[SGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 1 AND GSTTaxType = 2),0)) AS [SGST %],  
(ISNULL(SRI.[SGST Amount],0)) AS [SGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[UTGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 1 AND GSTTaxType = 3),0)) AS [UTGST %],  
(ISNULL(SRI.[UTGST Amount],0)) AS [UTGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[GCESS Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 1 AND GSTTaxType = 4),0)) AS [GCESS %],  
(ISNULL(SRI.[GCESS Amount],0)) AS [GCESS Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[GUOM Amount],0)=0 THEN 0 ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 1 AND GSTTaxType = 5),0)) AS [GUOM %],  
(ISNULL(SRI.[GUOM Amount],0)) AS [GUOM Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[IGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 2 AND GSTTaxType = 1),0)) AS [IGST %],  
(ISNULL(SRI.[IGST Amount],0)) AS [IGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[ICESS Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 2 AND GSTTaxType = 2),0)) AS [ICESS %],  
(ISNULL(SRI.[ICESS Amount],0)) AS [ICESS Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[IUOM Amount],0)=0 THEN 0 ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 2 AND GSTTaxType = 3),0)) AS [IUOM %],  
(ISNULL(SRI.[IUOM Amount],0)) AS [IUOM Amount]  
FROM  
(  
SELECT * FROM  
(  
SELECT Temp.TransID,Temp.TransIdentID,Temp.TaxTypeID,Temp.TaxID,Temp.[GST Comp],  
Temp.TaxName AS TaxName,  
SUM(Temp.TaxValue) AS [TaxValue]  
FROM  
(  
SELECT GSTInfo.TransID,GSTInfo.TransIdentID,MT.TaxID,GSTInfo.TaxTypeID,MT.TaxName,GSTInfo.TaxCompPern,GSTInfo.TaxValue,  
CASE  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=1 AND GSTInfo.TaxTypeID = 1 THEN 'CGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=2 AND GSTInfo.TaxTypeID = 1 THEN 'SGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=3 AND GSTInfo.TaxTypeID = 1 THEN 'UTGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=4 AND GSTInfo.TaxTypeID = 1 THEN 'GCESS Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=5 AND GSTInfo.TaxTypeID = 1 THEN 'GUOM Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=1 AND GSTInfo.TaxTypeID = 2 THEN 'IGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=2 AND GSTInfo.TaxTypeID = 2 THEN 'ICESS Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=3 AND GSTInfo.TaxTypeID = 2 THEN 'IUOM Amount'  
END AS [GST Comp]  
FROM tblTransGSTInfo AS GSTInfo  
JOIN tblTransPurchaseHeader SH ON SH.ID = GSTInfo.TransIdentID AND SH.TransID = GSTInfo.TransID  
JOIN tblMasterTax AS MT ON MT.TaxID = GSTInfo.TaxID  
WHERE (SH.TransID=1) AND Status IN (1,3,5,6,7) AND Date BETWEEN @FromDate AND @ToDate  
) Temp  
GROUP BY Temp.[GST Comp],Temp.TaxCompPern,Temp.TaxName,Temp.TaxID,Temp.TaxTypeID ,Temp.TransID,Temp.TransIdentID  
) src  
PIVOT  
(  
SUM([TaxValue])  
FOR [GST Comp] in ([CGST %],[CGST Amount],[SGST %],[SGST Amount],[UTGST %],[UTGST Amount],[GCESS %],[GCESS Amount],[IGST %],[IGST Amount],[ICESS %],[ICESS Amount],[GUOM Amount],[IUOM Amount])  
) piv  
) AS SRI  
) AS RAM  
GROUP BY TransID,TransIdentID  
SELECT * INTO #MainTaxHeaer FROM (  
SELECT * FROM #TaxHeaer  
UNION ALL  
SELECT * FROM #TaxPRHeaer) AS REC  
--select * from #MainTax  
  
SET @QRY = 'SELECT [Supply Type Code *],[Reverse Charge],[e-Comm GSTIN],[Igst On Intra],[Document Type *],[Document Number *],[Document Date (DD/MM/YYYY) *],  
[Buyer GSTIN *],[Buyer Legal Name *],[Buyer Trade Name ],[Buyer POS *],[Buyer Addr1 *],[Buyer Addr2],[Buyer Location *],  
[Buyer Pin Code],[Buyer State *],[Buyer Phone Number],[Buyer Email Id],[Dispatch Name ],[Dispatch Addr1 ],[Dispatch Addr2],  
[Dispatch Location ],[Dispatch Pin Code ],[Dispatch State ],[Shipping GSTIN ],[Shipping Legal Name ],[Shipping Trade Name ],  
[Shipping Addr1 ],[Shipping Addr2],[Shipping Location ],[Shipping Pin Code ],[Shipping State ],[Total Taxable value *],  
[Sgst Amt],[Cgst Amt],[Igst Amt],[Cess Amt],[State Cess Amt],[Discount],[Other charges],[Round off],[Total Invoice value *],  
[Shipping Bill No],[Shipping Bill Dt],[Port],[Refund claim],[Foreign Currency ],[Country Code ],[Export Duty Amount],  
[Trans ID],[Trans Name],[Trans Mode ],[Distance ],[Trans Doc No.] [Trans Doc No],[Trans Doc Date],[Vehicle No.] [Vehicle No],[Vehicle Type],[Error List] FROM ('  
SET @QRY += 'SELECT SH.DocPrefix,SH.InvDate,''B2B'' [Supply Type Code *],'''' [Reverse Charge],'''' [e-Comm GSTIN],'''' [Igst On Intra],  
CASE WHEN SH.DocPrefix = 15 THEN ''Tax Invoice'' ELSE ''Credit Note'' END [Document Type *],SH.DocId [Document Number *],  
CONVERT(NVARCHAR,SH.InvDate,103) [Document Date (DD/MM/YYYY) *],UPPER(MC.GSTIN) [Buyer GSTIN *],MC.Name [Buyer Legal Name *],MC.Name [Buyer Trade Name ],  
SCN.StateName [Buyer POS *],CONVERT(NVARCHAR(100),MC.Billadd1) [Buyer Addr1 *],CONVERT(NVARCHAR(100),MC.Billadd2 + '' ''+MC.Billadd3) [Buyer Addr2],  
CASE WHEN LEN(GHL.Name) >= 3 THEN GHL.Name ELSE ltrim(isnull(GHL.Name,'''') +'' ''+SCN.StateName) END [Buyer Location *],MC.Pincode [Buyer Pin Code],  
SCN.StateName [Buyer State *],MC.Mob1 [Buyer Phone Number],MC.Email [Buyer Email Id],'''' [Dispatch Name ],'''' [Dispatch Addr1 ],'''' [Dispatch Addr2],'''' [Dispatch Location ],'''' [Dispatch Pin Code ],  
'''' [Dispatch State ],'''' [Shipping GSTIN ],'''' [Shipping Legal Name ],'''' [Shipping Trade Name ],'''' [Shipping Addr1 ],'''' [Shipping Addr2],  
'''' [Shipping Location ],'''' [Shipping Pin Code ],'''' [Shipping State ],dbo.funTwoDecimalRoundOff(sum(SD.GrossAmt)) [Total Taxable value *],  
dbo.funTwoDecimalRoundOff(MT.[SGST Amount]) [Sgst Amt],dbo.funTwoDecimalRoundOff(MT.[CGST Amount]) [Cgst Amt],  
dbo.funTwoDecimalRoundOff(MT.[IGST Amount]) [Igst Amt],  
dbo.funTwoDecimalRoundOff(MT.[GCESS Amount] + MT.[GUOM Amount] + MT.[IUOM Amount]) [Cess Amt],'''' [State Cess Amt],  
(case when SH.OtherChargeAmt < 0 then dbo.funTwoDecimalRoundOff(ABS(SH.OtherChargeAmt)) else 0 end) [Discount],  
(case when SH.OtherChargeAmt >= 0 then dbo.funTwoDecimalRoundOff(SH.OtherChargeAmt + SH.TCSTaxAmt) else  
dbo.funTwoDecimalRoundOff(SH.TCSTaxAmt) end) [Other charges],  
dbo.funTwoDecimalRoundOff(dbo.fnGetRoundOffandRoundedNetAmount((dbo.funTwoDecimalRoundOff(sum(SD.GrossAmt)) +  
dbo.funTwoDecimalRoundOff(MT.[SGST Amount]) +  
dbo.funTwoDecimalRoundOff(MT.[CGST Amount]) +  
dbo.funTwoDecimalRoundOff(MT.[IGST Amount]) + dbo.funTwoDecimalRoundOff(MT.[GCESS Amount])),1)) [Round off],  
dbo.funTwoDecimalRoundOff(dbo.fnGetRoundOffandRoundedNetAmount((dbo.funTwoDecimalRoundOff(sum(SD.GrossAmt)) +  
dbo.funTwoDecimalRoundOff(MT.[SGST Amount]) +  
dbo.funTwoDecimalRoundOff(MT.[CGST Amount]) +  
dbo.funTwoDecimalRoundOff(MT.[IGST Amount]) + dbo.funTwoDecimalRoundOff(MT.[GCESS Amount])),0)+  
ISNULL(SH.OtherChargeAmt,0) + ISNULL(SH.TCSTaxAmt,0) + ISNULL(MT.[GUOM Amount],0) + ISNULL(MT.[IUOM Amount],0)) [Total Invoice value *],  
'''' [Shipping Bill No],'''' [Shipping Bill Dt],'''' [Port],'''' [Refund claim],'''' [Foreign Currency ],'''' [Country Code ],'''' [Export Duty Amount],  
SH.TransportID [Trans ID],SH.TransportName [Trans Name],
(case when ISNULL(SH.VehicleNo,0) = 0 THEN '''' ELSE SH.TransMode END) [Trans Mode ],
ISNULL(SH.Distance,'''') [Distance ],  
(CASE WHEN ISNULL(SH.Distance,'''') != '''' THEN SH.DocID ELSE '''' END) [Trans Doc No.],  
(CASE WHEN ISNULL(SH.Distance,'''') != '''' THEN CONVERT(NVARCHAR,SH.InvDate,103) ELSE '''' END) [Trans Doc Date],  
VH.VehicleNo [Vehicle No.],
(case when ISNULL(SH.VehicleNo,0) = 0 THEN '''' ELSE SH.VehicleType END) [Vehicle Type],'''' [Error List]  
FROM tblTranSalesHeader SH  
JOIN tblTranSalesDetail SD ON SD.InvID = SH.Id  
JOIN tblMasterCustomer MC ON MC.ID = SH.CustId  
join #MainTaxHeaer MT ON MT.TransIdentID = SH.Id AND MT.TransID = SH.DocPrefix  
JOIN tblMasterProduct MP ON MP.ID = SD.ProdId  
JOIN tblMasterUom MU ON MU.ID = SD.UomId  
LEFT JOIN tblGSTStateNameandCode SCN ON SCN.StateID = MC.StateID  
LEFT JOIN tblMasterBeat GHL ON GHL.ID = SH.BeatID  
left join tblMasterVehicle VH ON VH.ID = SH.VehicleNo  
WHERE ISNULL(SH.IRN,'''') = '''' AND DocPrefix IN (15,16) AND Status IN (1,3,5,6,7) AND SD.TaxId > 0 AND MC.StateID > 0 and ISNULL(MC.GSTIN,'''') != '''' and isnull(SH.DocId,'''') != '''''  
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+' @FromDate ' +' AND ' +' @ToDate ' +'' END)  
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue in (SELECT id FROM dbo.fnSplitString(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)  
SET @QRY = @QRY + ' GROUP BY SH.InvDate,MC.GSTIN,MC.Name,MC.Name,SCN.StateName,MC.Mob1,MC.Email,  
MC.Billadd1,MC.Billadd2,MC.Billadd3,GHL.Name,MC.Pincode,SH.TaxTypeID,SH.TransportID,SH.TransportName,SH.TransMode,SH.Distance,VH.VehicleNo,SH.VehicleType,  
SH.OtherChargeAmt,SH.TCSTaxAmt,SH.RoundOfAmt,SH.NetAmt,SH.DocPrefix,SH.DocId,MT.[GCESS Amount],MT.[CGST Amount],
MT.[SGST Amount],MT.[IGST Amount],MT.[GUOM Amount],MT.[IUOM Amount],SH.DocId,SH.VehicleNo '  
SET @QRY = @QRY + ' UNION ALL '  
SET @QRY = @QRY + 'SELECT SH.TransID DocPrefix,SH.Date,''B2B'' [Supply Type Code *],'''' [Reverse Charge],'''' [e-Comm GSTIN],'''' [Igst On Intra],  
''Debit Note'' [Document Type *], '  
SET @QRY += 'SH.DocId [Document Number *], CONVERT(NVARCHAR,SH.Date,103) [Document Date (DD/MM/YYYY) *],UPPER(MC.GSTIN) [Buyer GSTIN *],MC.Name [Buyer Legal Name *],  
MC.Name [Buyer Trade Name ],SCN.StateName [Buyer POS *],CONVERT(NVARCHAR(100),MC.Billadd1) [Buyer Addr1 *],  
CONVERT(NVARCHAR(100),MC.Billadd2 + '' ''+MC.Billadd3) [Buyer Addr2],  
SCN.StateName [Buyer Location *],  
MC.Pincode [Buyer Pin Code],SCN.StateName [Buyer State *],MC.Mob1 [Buyer Phone Number],MC.Email [Buyer Email Id],  
'''' [Dispatch Name ],'''' [Dispatch Addr1 ],'''' [Dispatch Addr2],'''' [Dispatch Location ],'''' [Dispatch Pin Code ],  
'''' [Dispatch State ],'''' [Shipping GSTIN ],'''' [Shipping Legal Name ],'''' [Shipping Trade Name ],'''' [Shipping Addr1 ],  
'''' [Shipping Addr2],'''' [Shipping Location ],'''' [Shipping Pin Code ],'''' [Shipping State ],  
dbo.funTwoDecimalRoundOff(sum(SD.GrossAmt)) [Total Taxable value *],  
dbo.funTwoDecimalRoundOff(MT.[SGST Amount]) [Sgst Amt],  
dbo.funTwoDecimalRoundOff(MT.[CGST Amount]) [Cgst Amt],  
dbo.funTwoDecimalRoundOff(MT.[IGST Amount]) [Igst Amt],  
dbo.funTwoDecimalRoundOff(MT.[GCESS Amount] + MT.[GUOM Amount] + MT.[IUOM Amount]) [Cess Amt],  
'''' [State Cess Amt],  
(case when SH.OtherChargeAmt < 0 then dbo.funTwoDecimalRoundOff(ABS(SH.OtherChargeAmt)) else 0 end) [Discount],  
(case when SH.OtherChargeAmt >= 0 then dbo.funTwoDecimalRoundOff(SH.OtherChargeAmt + SH.TCSTaxAmt) else  
dbo.funTwoDecimalRoundOff(SH.TCSTaxAmt) end) [Other charges],  
dbo.funTwoDecimalRoundOff(dbo.fnGetRoundOffandRoundedNetAmount((dbo.funTwoDecimalRoundOff(sum(SD.GrossAmt)) +  
dbo.funTwoDecimalRoundOff(MT.[SGST Amount]) +  
dbo.funTwoDecimalRoundOff(MT.[CGST Amount]) +  
dbo.funTwoDecimalRoundOff(MT.[IGST Amount]) + dbo.funTwoDecimalRoundOff(MT.[GCESS Amount])),1)) [Round off],  
dbo.funTwoDecimalRoundOff(dbo.fnGetRoundOffandRoundedNetAmount((dbo.funTwoDecimalRoundOff(sum(SD.GrossAmt)) +  
dbo.funTwoDecimalRoundOff(MT.[SGST Amount]) +  
dbo.funTwoDecimalRoundOff(MT.[CGST Amount]) +  
dbo.funTwoDecimalRoundOff(MT.[IGST Amount]) + dbo.funTwoDecimalRoundOff(MT.[GCESS Amount])),0)+  
ISNULL(SH.OtherChargeAmt,0) + ISNULL(SH.TCSTaxAmt,0) + ISNULL(MT.[GUOM Amount],0) + ISNULL(MT.[IUOM Amount],0))[Total Invoice value *],  
'''' [Shipping Bill No],'''' [Shipping Bill Dt],'''' [Port],'''' [Refund claim],'''' [Foreign Currency ],'''' [Country Code ],  
'''' [Export Duty Amount],SH.TransportID [Trans ID],SH.TransportName [Trans Name],SH.TransMode [Trans Mode ],  
ISNULL(SH.Distance,'''') [Distance ],(CASE WHEN ISNULL(SH.Distance,'''') != '''' THEN SH.DocID ELSE '''' END) [Trans Doc No.],  
(CASE WHEN ISNULL(SH.Distance,'''') != '''' THEN CONVERT(NVARCHAR,SH.Date,103) ELSE '''' END) [Trans Doc Date],  
VH.VehicleNo [Vehicle No.],SH.VehicleType [Vehicle Type],'''' [Error List]  
FROM tblTransPurchaseHeader SH  
JOIN tblTransPurchaseDetail SD ON SD.HID = SH.ID  
JOIN tblMasterVendor MC ON MC.id = SH.VendorID  
join #MainTaxHeaer MT ON MT.TransIdentID = SH.ID AND MT.TransID = SH.TransID  
JOIN tblMasterProduct MP ON MP.ID = SD.ProdId  
JOIN tblMasterUom MU ON MU.ID = SD.UomId  
LEFT JOIN tblGSTStateNameandCode SCN ON SCN.StateID = MC.StateID  
left join tblMasterVehicle VH ON VH.ID = SH.VehicleNo  
WHERE ISNULL(SH.IRN,'''') = '''' AND SH.TransID IN (12) AND Status IN (3,5,6,7) AND SD.TaxId > 0 AND MC.StateID > 0  
and ISNULL(MC.GSTIN,'''') != '''' and isnull(SH.DocId,'''') != '''' and isnull(SH.DocId,'''') != '''' '  
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.Date BETWEEN '+' @FromDate ' +' AND ' +' @ToDate ' +'' END)  
--SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue in (SELECT id FROM dbo.fnSplitString(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)  
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue in (SELECT id FROM dbo.fnSplitString(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)  
SET @QRY = @QRY + ' GROUP BY SH.Date,MC.GSTIN,MC.Name,SCN.StateName,MC.Mob1,MC.Email,MC.Billadd1,MC.Billadd2,MC.Billadd3,  
MC.Pincode,SH.TaxTypeID,SH.TransportID,SH.TransportName,SH.TransMode,SH.Distance,VH.VehicleNo,SH.VehicleType,  
SH.OtherChargeAmt,SH.TCSTaxAmt,SH.RoundOffAmt,SH.NetAmt,SH.TransID,SH.DocId,SH.DocId,MT.[GCESS Amount],MT.[CGST Amount],MT.[SGST Amount],MT.[IGST Amount],MT.[GUOM Amount],MT.[IUOM Amount],SH.DocId '  
SET @QRY = @QRY + ' ) AS REC ORDER BY DocPrefix,InvDate,[Document Number *]'  
EXEC sys.sp_executesql @QRY, N'@SheetMode INT, @FromDate date, @ToDate DATE, @DocIDs NVARCHAR(MAX)', @SheetMode, @FromDate, @ToDate, @DocIDs  
DROP TABLE #TaxHeaer,#TaxPRHeaer,#MainTaxHeaer  
END  
ELSE  
BEGIN  
SELECT GSTSerial,ProdID,TransID,TransIdentID,(SUM(RAM.[CGST %])) AS [CGST %],SUM((RAM.[CGST Amount])) AS [CGST Amount],  
(SUM(RAM.[SGST %])) AS [SGST %],(SUM(RAM.[SGST Amount])) AS [SGST Amount],(SUM(RAM.[UTGST %])) AS [UTGST %],  
SUM((RAM.[UTGST Amount])) AS [UTGST Amount],(SUM(RAM.[GCESS %])) AS [GCESS %],SUM((RAM.[GCESS Amount])) AS [GCESS Amount],  
(SUM(RAM.[IGST %])) AS [IGST %],SUM((RAM.[IGST Amount])) AS [IGST Amount],(SUM(RAM.[ICESS %])) AS [ICESS %],  
SUM((RAM.[ICESS Amount])) AS [ICESS Amount],SUM([GUOM %]) [GUOM %],SUM([IUOM %]) [IUOM %],  
SUM(RAM.[GUOM Amount]) [GUOM Amount],SUM(RAM.[IUOM Amount]) [IUOM Amount],  
SUM([GCESS Amount] + [ICESS Amount] + [GUOM Amount] + [IUOM Amount]) [Cumulative CESS Amount] INTO #TaxItems  
FROM  
(  
SELECT GSTSerial,ProdID,SRI.TransID,SRI.TransIdentID,  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[CGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 3 AND GSTTaxType = 1),0)) AS [CGST %],  
(ISNULL(SRI.[CGST Amount],0)) AS [CGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[SGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 3 AND GSTTaxType = 2),0)) AS [SGST %],  
(ISNULL(SRI.[SGST Amount],0)) AS [SGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[UTGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 3 AND GSTTaxType = 3),0)) AS [UTGST %],  
(ISNULL(SRI.[UTGST Amount],0)) AS [UTGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[GCESS Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 3 AND GSTTaxType = 4),0)) AS [GCESS %],  
(ISNULL(SRI.[GCESS Amount],0)) AS [GCESS Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[GUOM Amount],0)=0 THEN 0 ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 3 AND GSTTaxType = 5),0)) AS [GUOM %],  
(ISNULL(SRI.[GUOM Amount],0)) AS [GUOM Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[IGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 5 AND GSTTaxType = 1),0)) AS [IGST %],  
(ISNULL(SRI.[IGST Amount],0)) AS [IGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[ICESS Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 5 AND GSTTaxType = 2),0)) AS [ICESS %],  
(ISNULL(SRI.[ICESS Amount],0)) AS [ICESS Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[IUOM Amount],0)=0 THEN 0 ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 5 AND GSTTaxType = 3),0)) AS [IUOM %],  
(ISNULL(SRI.[IUOM Amount],0)) AS [IUOM Amount]  
FROM  
(  
SELECT * FROM  
(  
SELECT GSTSerial,ProdID,Temp.TransID,Temp.TransIdentID,Temp.TaxTypeID,Temp.TaxID,Temp.[GST Comp],  
Temp.TaxName AS TaxName,  
SUM(Temp.TaxValue) AS [TaxValue]  
FROM  
(  
SELECT Serial GSTSerial,ProdID,GSTInfo.TransID,GSTInfo.TransIdentID,MT.TaxID,GSTInfo.TaxTypeID,MT.TaxName,GSTInfo.TaxCompPern,GSTInfo.TaxValue,  
CASE  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=1 AND GSTInfo.TaxTypeID = 1 THEN 'CGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=2 AND GSTInfo.TaxTypeID = 1 THEN 'SGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=3 AND GSTInfo.TaxTypeID = 1 THEN 'UTGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=4 AND GSTInfo.TaxTypeID = 1 THEN 'GCESS Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=5 AND GSTInfo.TaxTypeID = 1 THEN 'GUOM Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=1 AND GSTInfo.TaxTypeID = 2 THEN 'IGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=2 AND GSTInfo.TaxTypeID = 2 THEN 'ICESS Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=3 AND GSTInfo.TaxTypeID = 2 THEN 'IUOM Amount'  
END AS [GST Comp]  
FROM tblTransGSTInfo AS GSTInfo  
JOIN tblTranSalesHeader SH ON SH.ID = GSTInfo.TransIdentID AND SH.DocPrefix = GSTInfo.TransID  
JOIN tblMasterTax AS MT ON MT.TaxID = GSTInfo.TaxID  
WHERE (TransID=15 or TransID=16) AND Status IN (1,3,5,6,7) AND InvDate BETWEEN @FromDate AND @ToDate  
) Temp  
GROUP BY GSTSerial,ProdID,Temp.[GST Comp],Temp.TaxCompPern,Temp.TaxName,Temp.TaxID,Temp.TaxTypeID ,Temp.TransID,Temp.TransIdentID  
) src  
PIVOT  
(  
SUM([TaxValue])  
FOR [GST Comp] in ([CGST %],[CGST Amount],[SGST %],[SGST Amount],[UTGST %],[UTGST Amount],[GCESS %],[GCESS Amount],[IGST %],[IGST Amount],[ICESS %],[ICESS Amount],[GUOM Amount],[IUOM Amount])  
) piv  
) AS SRI  
) AS RAM  
GROUP BY GSTSerial,ProdID,TransID,TransIdentID  
--SELECT * FROM #Tax  
-- PR  
SELECT GSTSerial,ProdID,TransID,TransIdentID,(SUM(RAM.[CGST %])) AS [CGST %],SUM((RAM.[CGST Amount])) AS [CGST Amount],  
(SUM(RAM.[SGST %])) AS [SGST %],(SUM(RAM.[SGST Amount])) AS [SGST Amount],(SUM(RAM.[UTGST %])) AS [UTGST %],  
SUM((RAM.[UTGST Amount])) AS [UTGST Amount],(SUM(RAM.[GCESS %])) AS [GCESS %],SUM((RAM.[GCESS Amount])) AS [GCESS Amount],  
(SUM(RAM.[IGST %])) AS [IGST %],SUM((RAM.[IGST Amount])) AS [IGST Amount],(SUM(RAM.[ICESS %])) AS [ICESS %],  
SUM((RAM.[ICESS Amount])) AS [ICESS Amount],SUM([GUOM %]) [GUOM %],SUM([IUOM %]) [IUOM %],  
SUM(RAM.[GUOM Amount]) [GUOM Amount],SUM(RAM.[IUOM Amount]) [IUOM Amount],  
SUM([GCESS Amount] + [ICESS Amount] + [GUOM Amount] + [IUOM Amount]) [Cumulative CESS Amount] INTO #TaxPRItems  
FROM  
(  
SELECT GSTSerial,ProdID,SRI.TransID,SRI.TransIdentID,  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[CGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 3 AND GSTTaxType = 1),0)) AS [CGST %],  
(ISNULL(SRI.[CGST Amount],0)) AS [CGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[SGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 3 AND GSTTaxType = 2),0)) AS [SGST %],  
(ISNULL(SRI.[SGST Amount],0)) AS [SGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[UTGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 3 AND GSTTaxType = 3),0)) AS [UTGST %],  
(ISNULL(SRI.[UTGST Amount],0)) AS [UTGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[GCESS Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 3 AND GSTTaxType = 4),0)) AS [GCESS %],  
(ISNULL(SRI.[GCESS Amount],0)) AS [GCESS Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[GUOM Amount],0)=0 THEN 0 ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 3 AND GSTTaxType = 5),0)) AS [GUOM %],  
(ISNULL(SRI.[GUOM Amount],0)) AS [GUOM Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[IGST Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 5 AND GSTTaxType = 1),0)) AS [IGST %],  
(ISNULL(SRI.[IGST Amount],0)) AS [IGST Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[ICESS Amount],0)=0 THEN SUM(CumulativeTax) ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 5 AND GSTTaxType = 2),0)) AS [ICESS %],  
(ISNULL(SRI.[ICESS Amount],0)) AS [ICESS Amount],  
(ISNULL((SELECT (CASE WHEN ISNULL(SRI.[IUOM Amount],0)=0 THEN 0 ELSE SUM(CumulativeTax) END) FROM tblMasterTaxDetail WHERE TaxID = SRI.TaxID AND TaxTypeID = 5 AND GSTTaxType = 3),0)) AS [IUOM %],  
(ISNULL(SRI.[IUOM Amount],0)) AS [IUOM Amount]  
FROM  
(  
SELECT * FROM  
(  
SELECT GSTSerial,ProdID,Temp.TransID,Temp.TransIdentID,Temp.TaxTypeID,Temp.TaxID,Temp.[GST Comp],  
Temp.TaxName AS TaxName,  
SUM(Temp.TaxValue) AS [TaxValue]  
FROM  
(  
SELECT Serial GSTSerial,ProdID,GSTInfo.TransID,GSTInfo.TransIdentID,MT.TaxID,GSTInfo.TaxTypeID,MT.TaxName,GSTInfo.TaxCompPern,GSTInfo.TaxValue,  
CASE  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=1 AND GSTInfo.TaxTypeID = 1 THEN 'CGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=2 AND GSTInfo.TaxTypeID = 1 THEN 'SGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=3 AND GSTInfo.TaxTypeID = 1 THEN 'UTGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=4 AND GSTInfo.TaxTypeID = 1 THEN 'GCESS Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=5 AND GSTInfo.TaxTypeID = 1 THEN 'GUOM Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=1 AND GSTInfo.TaxTypeID = 2 THEN 'IGST Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=2 AND GSTInfo.TaxTypeID = 2 THEN 'ICESS Amount'  
WHEN ISNULL(GSTInfo.GSTTaxTypeID,0)=3 AND GSTInfo.TaxTypeID = 2 THEN 'IUOM Amount'  
END AS [GST Comp]  
FROM tblTransGSTInfo AS GSTInfo  
JOIN tblTransPurchaseHeader SH ON SH.ID = GSTInfo.TransIdentID AND SH.TransID = GSTInfo.TransID  
JOIN tblMasterTax AS MT ON MT.TaxID = GSTInfo.TaxID  
WHERE (SH.TransID=12) AND Status IN (3,5,6,7) AND SH.Date BETWEEN @FromDate AND @ToDate  
) Temp  
GROUP BY GSTSerial,ProdID,Temp.[GST Comp],Temp.TaxCompPern,Temp.TaxName,Temp.TaxID,Temp.TaxTypeID ,Temp.TransID,Temp.TransIdentID  
) src  
PIVOT  
(  
SUM([TaxValue])  
FOR [GST Comp] in ([CGST %],[CGST Amount],[SGST %],[SGST Amount],[UTGST %],[UTGST Amount],[GCESS %],[GCESS Amount],[IGST %],[IGST Amount],[ICESS %],[ICESS Amount],[GUOM Amount],[IUOM Amount])  
) piv  
) AS SRI  
) AS RAM  
GROUP BY GSTSerial,ProdID,TransID,TransIdentID  
SELECT * INTO #MainTaxItems FROM (  
SELECT * FROM #TaxItems  
UNION ALL  
SELECT * FROM #TaxPRItems) AS REC  
--select * from #MainTaxItems  
--uspExportIRNData 2,'2023-05-12','2023-12-30','',0,0  
SET @QRY = 'SELECT [Document Type *],[Document Number *],[Document Date (DD/MM/YYYY) *],[Sl.No. *] [Sl No *],[Product Description],[Is_Service *],  
[HSN code *],[Bar code ],[Quantity *],[Free Quantity],[Unit *],[Unit Price *],[Gross Amount *],[Discount],[Pre Tax Value],  
[Taxable value *],[GST Rate (%) *],[Sgst Amt(Rs)],[Cgst Amt (Rs)],[Igst Amt (Rs)],[Cess Rate (%)],[Cess Amt Adval (Rs)],  
[Cess Non Adval Amt (Rs)],[State Cess Rate (%)],[State Cess Adval Amt (Rs)],[State Cess Non-Adval Amt (Rs)],  
[Other Charges ],[Item Total *],[Batch Name],[Batch Expiry Dt],[Warranty Dt]  
FROM ( '  
SET @QRY += 'SELECT SH.InvDate,SH.DocPrefix,SD.Serial,CASE WHEN SH.DocPrefix = 15 THEN ''Tax Invoice'' ELSE ''Credit Note'' END [Document Type *],SH.DocId [Document Number *],'  
SET @QRY += 'CONVERT(NVARCHAR,SH.InvDate,103) [Document Date (DD/MM/YYYY) *],SD.Serial [Sl.No. *],MP.Name [Product Description],  
''NO'' [Is_Service *],MP.HSNCode [HSN code *],'''' [Bar code ],  
CASE WHEN SD.QtyType != 2 THEN dbo.funTwoDecimalRoundOff(SD.UomQty) ELSE 0.00 END [Quantity *],CASE WHEN SD.QtyType = 2 THEN dbo.funTwoDecimalRoundOff(SD.UomQty) ELSE 0.00 END [Free Quantity],  
CASE WHEN MU.Name = ''TIN'' THEN ''NOS'' WHEN MU.Name = ''KG'' THEN ''KGS'' ELSE MU.Name END [Unit *],  
dbo.funTwoDecimalRoundOff(SD.UomPrice) [Unit Price *],dbo.funTwoDecimalRoundOff(SD.GoodsAmt) [Gross Amount *],  
dbo.funTwoDecimalRoundOff(((SD.ProdDisc * SD.GoodsAmt) / 100) + SD.TradeDisc + ((0 * SD.GoodsAmt) / 100) + SD.AddnlDisc) [Discount],'''' [Pre Tax Value],  
dbo.funTwoDecimalRoundOff(SD.GrossAmt) [Taxable value *],  
(CASE WHEN SH.TaxTypeId = 1 THEN dbo.funTwoDecimalRoundOff([CGST %] + [SGST %]) ELSE dbo.funTwoDecimalRoundOff([IGST %]) END) [GST Rate (%) *],  
(dbo.funTwoDecimalRoundOff([SGST Amount])) [Sgst Amt(Rs)],  
(dbo.funTwoDecimalRoundOff([CGST Amount])) [Cgst Amt (Rs)],  
(dbo.funTwoDecimalRoundOff([IGST Amount])) [Igst Amt (Rs)],  
(CASE WHEN SH.TaxTypeId = 1 THEN (dbo.funTwoDecimalRoundOff([GCESS %])) ELSE dbo.funTwoDecimalRoundOff([ICESS %]) END) [Cess Rate (%)],  
(CASE WHEN SH.TaxTypeId = 1 THEN (dbo.funTwoDecimalRoundOff([GCESS Amount])) ELSE dbo.funTwoDecimalRoundOff([ICESS Amount]) END) [Cess Amt Adval (Rs)],  
dbo.funTwoDecimalRoundOff([GUOM Amount] + [IUOM Amount]) [Cess Non Adval Amt (Rs)], '''' [State Cess Rate (%)],'''' [State Cess Adval Amt (Rs)],'''' [State Cess Non-Adval Amt (Rs)],'''' [Other Charges ],  
(dbo.funTwoDecimalRoundOff(SD.GrossAmt) + (dbo.funTwoDecimalRoundOff([SGST Amount])) +  
(dbo.funTwoDecimalRoundOff([CGST Amount])) +  
(dbo.funTwoDecimalRoundOff([IGST Amount])) + (dbo.funTwoDecimalRoundOff([GCESS Amount]))  
+ (dbo.funTwoDecimalRoundOff([GUOM Amount]))+ (dbo.funTwoDecimalRoundOff([IUOM Amount]))) [Item Total *],  
'''' [Batch Name],'''' [Batch Expiry Dt],'''' [Warranty Dt]  
FROM tblTranSalesHeader SH  
JOIN tblTranSalesDetail SD ON SD.InvId = SH.Id  
JOIN tblMasterCustomer MC ON MC.Id = SH.CustId  
JOIN tblMasterProduct MP ON MP.ID = SD.ProdId  
join #MainTaxItems MT ON MT.TransIdentID = SH.Id AND MT.TransID = SH.DocPrefix AND MT.ProdID = SD.ProdID AND MT.GSTSerial = SD.Serial  
JOIN tblMasterUom MU ON MU.ID = SD.UomId  
LEFT JOIN tblGSTStateNameandCode SCN ON SCN.StateID = MC.StateID  
WHERE ISNULL(SH.IRN,'''') = '''' AND DocPrefix IN (15,16) AND  
Status IN (1,3,5,6,7) AND SD.TaxId > 0 AND MC.StateID > 0 and ISNULL(MC.GSTIN,'''') != '''' and isnull(SH.DocId,'''') != '''''  
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+' @FromDate ' +' AND ' +' @ToDate ' +'' END)  
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue in (SELECT id FROM dbo.fnSplitString(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)  
SET @QRY = @QRY + ' UNION ALL '  
SET @QRY = @QRY + ' SELECT SH.Date,SH.TransID DocPrefix,SD.Serial,''Debit Note'' [Document Type *],SH.DocId [Document Number *],'  
SET @QRY += ' CONVERT(NVARCHAR,SH.Date,103) [Document Date (DD/MM/YYYY) *],SD.Serial [Sl.No. *],MP.Name [Product Description],  
''NO'' [Is_Service *],MP.HSNCode [HSN code *],'''' [Bar code ],  
dbo.funTwoDecimalRoundOff(SD.UomQty) [Quantity *],dbo.funTwoDecimalRoundOff(SD.UomFreeQty) [Free Quantity],  
CASE WHEN MU.Name = ''TIN'' THEN ''NOS'' WHEN MU.Name = ''KG'' THEN ''KGS'' ELSE MU.Name END [Unit *],  
dbo.funTwoDecimalRoundOff(SD.UomPurchasePrice) [Unit Price *],dbo.funTwoDecimalRoundOff(SD.GoodsAmt) [Gross Amount *],  
dbo.funTwoDecimalRoundOff(((SD.[ProdDisc%] * SD.GoodsAmt) / 100) +  
(((SD.GoodsAmt - ((SD.[ProdDisc%] * SD.GoodsAmt) / 100)) * SD.[TradeDisc%]) / 100) +  
(((SD.GoodsAmt - ((SD.[ProdDisc%] * SD.GoodsAmt) / 100)) * SD.[AddnlDisc%]) / 100)) [Discount],'''' [Pre Tax Value],  
dbo.funTwoDecimalRoundOff(SD.GrossAmt) [Taxable value *],  
(CASE WHEN SH.TaxTypeId = 1 THEN dbo.funTwoDecimalRoundOff([CGST %] + [SGST %]) ELSE dbo.funTwoDecimalRoundOff([IGST %]) END) [GST Rate (%) *],  
(dbo.funTwoDecimalRoundOff([SGST Amount])) [Sgst Amt(Rs)],  
(dbo.funTwoDecimalRoundOff([CGST Amount])) [Cgst Amt (Rs)],  
(dbo.funTwoDecimalRoundOff([IGST Amount])) [Igst Amt (Rs)],  
(CASE WHEN SH.TaxTypeId = 1 THEN (dbo.funTwoDecimalRoundOff([GCESS %])) ELSE dbo.funTwoDecimalRoundOff([ICESS %]) END) [Cess Rate (%)],  
(CASE WHEN SH.TaxTypeId = 1 THEN (dbo.funTwoDecimalRoundOff([GCESS Amount]+ [GUOM Amount])) ELSE dbo.funTwoDecimalRoundOff([ICESS Amount]+ [GUOM Amount]) END) [Cess Amt Adval (Rs)],  
dbo.funTwoDecimalRoundOff([GUOM Amount] + [IUOM Amount]) [Cess Non Adval Amt (Rs)],'''' [State Cess Rate (%)],'''' [State Cess Adval Amt (Rs)],  
'''' [State Cess Non-Adval Amt (Rs)],'''' [Other Charges ],  
(dbo.funTwoDecimalRoundOff(SD.GrossAmt) + (dbo.funTwoDecimalRoundOff([SGST Amount])) +  
(dbo.funTwoDecimalRoundOff([CGST Amount])) +  
(dbo.funTwoDecimalRoundOff([IGST Amount])) + (dbo.funTwoDecimalRoundOff([GCESS Amount]))  
+ (dbo.funTwoDecimalRoundOff([GUOM Amount]))+ (dbo.funTwoDecimalRoundOff([IUOM Amount]))) [Item Total *],  
'''' [Batch Name],'''' [Batch Expiry Dt],'''' [Warranty Dt]  
FROM tblTransPurchaseHeader SH  
JOIN tblTransPurchaseDetail SD ON SD.HID= SH.ID  
JOIN tblMasterVendor MC ON MC.id = SH.VendorID  
JOIN tblMasterProduct MP ON MP.ID = SD.ProdId  
join #MainTaxItems MT ON MT.TransIdentID = SH.ID AND MT.TransID = SH.TransID AND MT.ProdID = SD.HID AND MT.GSTSerial = SD.Serial  
JOIN tblMasterUom MU ON MU.ID = SD.UomId  
LEFT JOIN tblGSTStateNameandCode SCN ON SCN.StateID = MC.StateID  
WHERE ISNULL(SH.IRN,'''') = '''' AND SH.TransID IN (12) AND Status IN (3,5,6,7) AND SD.TaxId > 0 AND MC.StateID > 0 and isnull(SH.DocId,'''') != '''' '  
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.Date BETWEEN '+' @FromDate ' +' AND ' +' @ToDate ' +'' END)  
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue in (SELECT id FROM dbo.fnSplitString(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)  
SET @QRY = @QRY + ' ) AS REC ORDER BY DocPrefix,InvDate,[Document Number *],Serial'  
EXEC sys.sp_executesql @QRY, N'@SheetMode INT, @FromDate date, @ToDate DATE, @DocIDs NVARCHAR(MAX)', @SheetMode, @FromDate, @ToDate, @DocIDs  
drop table #TaxItems,#TaxPRItems,#MainTaxItems  
END  
END
GO

/****** uspFinRepDetailedTrailBalance ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspFinRepDetailedTrailBalance] 
@BranchID int = 4,@Fromdate date = '2025-09-01',@ToDate date = '2026-11-30'
as
BEGIN
DECLARE @STRQRY NVARCHAR(MAX),@STRQRYJOIN NVARCHAR(MAX) = '',@STRACCGRPNAME NVARCHAR(MAX)= '',@STRGBY NVARCHAR(MAX)= '',  
@SELCOLNM NVARCHAR(MAX) = '',@TBLID INT = 0,@SelID INT ,@GETCOLNM NVARCHAR(255) = '',@CombainCol NVARCHAR(MAX) = '',  
@OPENAMT DECIMAL(25,6)  
SELECT @OPENAMT = [dbo].[fnGetRoundedValue](SUM(ISNULL(SaleStockValue + DmgStockValue,0)))      
FROM tblClosingStock WHERE ClsDate= DATEADD(DAY, -1, @Fromdate)        
declare @MaxLevel INT =(select MAX(LevelID) from tblFAGroup)  
SET @SelID = @MaxLevel  
WHILE(@MaxLevel >= 1)  
BEGIN  
SET @GETCOLNM = 'FAGPAR'+CONVERT(NVARCHAR,@SelID)   
SET @CombainCol +=  @GETCOLNM + '+ (CASE WHEN ISNULL('+@GETCOLNM+','''') = '''' THEN '''' ELSE ''->'' END) +'  
SET @SELCOLNM += @GETCOLNM +','  
SET @STRGBY += ' FAG'+CONVERT(NVARCHAR,@SelID)+'.AccountGroupName,'  
SET @STRACCGRPNAME += ' ISNULL(FAG'+CONVERT(NVARCHAR,@SelID)+'.AccountGroupName,'''') AS FAGPAR'+CONVERT(NVARCHAR,@SelID) +','  
SET @STRQRYJOIN += ' left JOIN tblFAGroup FAG'+CONVERT(NVARCHAR,@TBLID+1)+' ON FAG'+CONVERT(NVARCHAR,@TBLID+1)+'.FAGroup = FAG'+CONVERT(NVARCHAR,@TBLID)+'.ParentGroup  '  
SET @MaxLevel = @MaxLevel - 1;  
SET @TBLID = @TBLID + 1;  
SET @SelID = @SelID - 1;  
END  
  
SET @STRQRY = 'SELECT * FROM (SELECT AccountID,[Account Type],'+@CombainCol+'AccountGroupName [Account Group],AccountName [Account Name],  
dbo.fnGetRoundedValue(case when SUM(Debit - Credit) >= 0 THEN  SUM(Debit - Credit) ELSE 0 END) Debit,        
dbo.fnGetRoundedValue(case when SUM(Debit - Credit) < 0 THEN  SUM(Credit - Debit) ELSE 0 END) Credit FROM('  
SET @STRQRY += 'SELECT AccountID,[Account Type],'+@SELCOLNM+'AccountGroupName,AccountName,case when SUM(openbal) < 0 then SUM(Credit + abs(openbal)) else SUM(Credit) end  Credit,        
case when SUM(openbal) >= 0 then SUM(Debit + openbal) else SUM(Debit) end Debit FROM (SELECT FAJ.AccountId AccountID,TypeName [Account Type],'+ @STRACCGRPNAME+' isnull(FAG0.AccountGroupName,'''') AccountGroupName,FAA.AccountName,        
SUM(Credit) Credit,SUM(Debit) Debit,0 openbal FROM tblFAJournal FAJ        
JOIN tblFAAccount FAA ON FAA.FAID = FAJ.AccountID        
JOIN tblFAGroup FAG0 ON FAG0.FAGroup = FAA.AccountGroup  
LEFT JOIN tblAccountType AT ON AT.TypeId=FAG0.TypeID'  
SET @STRQRY += @STRQRYJOIN  
SET @STRQRY += 'WHERE Status IN (1,3,5,6,7,9) AND DocDate BETWEEN '+' @Fromdate '+' AND '+' @ToDate '  
SET @STRQRY += ' GROUP BY '+@STRGBY+'FAG0.AccountGroupName,FAA.AccountName,TypeName,FAJ.AccountId'  
SET @STRQRY += ' ) AS REC group by AccountID,[Account Type],'+@SELCOLNM+'AccountGroupName,AccountName'  
SET @STRQRY += ' union all '  
SET @STRQRY += ' SELECT AccountID,[Account Type],'+@SELCOLNM+'AccountGroupName,AccountName,case when SUM(openbal) < 0 then SUM(Credit + abs(openbal)) else SUM(Credit) end  Credit,        
case when SUM(openbal) >= 0 then SUM(Debit + openbal) else SUM(Debit) end Debit FROM (  
SELECT FAA.FAID AccountID,TypeName [Account Type],'+ @STRACCGRPNAME+' isnull(FAG0.AccountGroupName,'''') AccountGroupName,FAA.AccountName,        
0 Credit,0 Debit,CASE WHEN FAA.FAID = 60 then '+CONVERT(nvarchar(255),@OPENAMT)+' else dbo.[uspReturnOpeningBalance]( @BranchID ,FAA.FAID,'+' @Fromdate '+') end openbal 
FROM tblFAAccount FAA  
JOIN tblFAGroup FAG0 ON FAG0.FAGroup = FAA.AccountGroup  
LEFT JOIN tblAccountType AT ON AT.TypeId=FAG0.TypeID'  
SET @STRQRY += @STRQRYJOIN  
SET @STRQRY += ' GROUP BY '+@STRGBY+'FAG0.AccountGroupName,FAA.AccountName,TypeName,FAA.FAID'  
SET @STRQRY += ' ) AS REC WHERE ISNULL(openbal,0) <> 0 group by AccountID,[Account Type],'+@SELCOLNM+'AccountGroupName,AccountName'  
SET @STRQRY += ') AS REC1 GROUP BY  '+@SELCOLNM+'AccountID,[Account Type],AccountGroupName,AccountName '  
SET @STRQRY += ' ) AS REC2 ORDER BY [Account Type],[Account Group],[Account Name]'  
EXEC sys.sp_executesql @STRQRY, N'@BranchID int, @Fromdate date, @ToDate date', @BranchID, @Fromdate, @ToDate  
END
GO

/****** uspGetCustomerWiseSalesHeader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetCustomerWiseSalesHeader]      
@BranchName NVARCHAR(255) = '0',@BeatName NVARCHAR(255) = '',@SalesmanName NVARCHAR(255) = '',@CustomerName NVARCHAR(255) = '',@CustomerType NVARCHAR(255) = '',    
@Ratings NVARCHAR(255) = '',@FromDate DATE = '2025-08-01',@ToDate DATE = '2025-08-30'       
AS    
BEGIN    
declare @StrQuery nvarchar(max) = ''      
 set @StrQuery = ' SELECT MC.ID CustomerID,ISNULL(TSH.BeatId,0) AS [BeatID],ISNULL(TSH.SalesManId,0) AS SalesManID,    
MC.Code AS [Customer Code],MC.Name AS [Customer Name],Beat.Name AS [Beat Name],SM.Name AS [SalesMan Name],      
MCT.Name AS [Customer Type],RT.RatingName [Ratings],COUNT(TSH.ID) AS [Inv Count],                
dbo.fnGetRoundedValue(SUM(TSH.NetAmt)) AS [Net Amount],dbo.fnGetRoundedValue(SUM(TSH.Balance)) AS [Balance Amount]                
FROM tblTranSalesHeader AS TSH                
JOIN tblMasterCustomer AS MC ON MC.ID = TSH.CustId                
LEFT JOIN tblMasterBeat AS Beat ON Beat.ID = TSH.BeatID          
LEFT JOIN tblMasterSalesMan AS SM ON SM.ID = TSH.SalesManId          
LEFT JOIN tblMasterCustomerType AS MCT ON MCT.ID = MC.CustomerType     
LEFT JOIN tblRatings AS RT ON RT.ID = MC.Rating    
WHERE TSH.[Status] IN (1,3,5) AND TSH.DocPrefix = 15 '    
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN  @FromDate  AND  @ToDate )' END)                  
  
    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND TSH.BranchID =  @BranchName ' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND Beat.ID IN (SELECT * from dbo.fnSplitString(  @BeatName ,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SM.ID IN (SELECT * from dbo.fnSplitString(  @SalesmanName ,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString(  @CustomerName ,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN (SELECT * from dbo.fnSplitString(  @CustomerType ,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN (SELECT * from dbo.fnSplitString(  @Ratings ,'',''))' END)       
SET @StrQuery = @StrQuery + ' GROUP BY MC.ID,TSH.BeatId,TSH.SalesManId,MC.Code,MC.Name,Beat.Name,SM.Name,MCT.Name,RT.RatingName'    
EXEC sys.sp_executesql @StrQuery, N'@BranchName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BranchName, @BeatName, @SalesmanName, @CustomerName, @CustomerType, @Ratings, @FromDate, @ToDate    
END
GO

/****** uspGetCustWiseMonthlySalesHeader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetCustWiseMonthlySalesHeader]      
@BeatName NVARCHAR(255) = '',@SalesmanName NVARCHAR(255) = '',@CustomerName NVARCHAR(255) = '',@CustomerType NVARCHAR(255) = '',@Ratings NVARCHAR(255)='',      
@Type NVARCHAR(255) = '1',    @FilterBy NVARCHAR(255) = '0',@FromDate DATE = '2025-07-01',@ToDate DATE = '2025-08-30'       
AS      
BEGIN      
declare @StrQuery nvarchar(max) = ''      
-- Create #TempTable1 for Get Need Records                                        
  CREATE TABLE #Temp (CustId INT,BeatId INT,SalesmanId INT,[Customer Code] NVARCHAR(255),[Customer Name] NVARCHAR(255),[Customer Type] NVARCHAR(255),[Ratings] NVARCHAR(255), [Beat Name] NVARCHAR(255)            
  ,[SalesMan Name] NVARCHAR(255),[Selected Amount] DECIMAL(25,2),MY NVARCHAR(20),Value DECIMAL(25,2))        
  CREATE TABLE #Temp1 (CustId INT,BeatId INT,SalesmanId INT,[Customer Code] NVARCHAR(255),[Customer Name] NVARCHAR(255),[Customer Type] NVARCHAR(255),[Ratings] NVARCHAR(255),[Beat Name] NVARCHAR(255)            
  ,[SalesMan Name] NVARCHAR(255),[Selected Amount] DECIMAL(25,2),MY NVARCHAR(20),Value DECIMAL(25,2))        
 Declare @exc Table(id int identity(1,1),DocID NVARCHAR(255),Name NVARCHAR(255),nIndex INT)         
  IF(@Type != '3')          
    BEGIN        
set @StrQuery = ' SELECT CustId,BeatID,SalesManID,[Customer Code],[Customer Name],[Customer Type],Ratings,[Beat Name],            
  [SalesMan Name],ISNULL(SUM([Selected Amount]),0) [Selected Amount],MY,SUM(ISNULL(Value,0)) Value FROM (            
 SELECT MC.ID CustId,ISNULL(MB.ID,0) AS BeatID,ISNULL(MSM.ID,0) AS SalesManID,MC.Code AS [Customer Code],              
MC.Name AS [Customer Name],mct.Name AS [Customer Type],              
ISNULL(MB.Name,''Default Beat'') AS [Beat Name], ISNULL(MSM.Name,''Default SalesMan'') AS [SalesMan Name],              
0 AS [Selected Amount],            
UPPER(CONVERT(nvarchar(3),DATENAME(month,InvDate))) +'' ''+ CONVERT(NVARCHAR(10),YEAR(InvDate)) AS MY,            
(CASE WHEN '+ ' @Type '+'=''2'' THEN (SUM(TSH.GrossAmt)) ELSE (SUM(TSH.NetAmt))END) AS Value,      
RT.RatingName Ratings      
FROM tblTranSalesHeader AS TSH             
JOIN tblMasterCustomer AS MC ON MC.ID = TSH.CustId              
left join tblMasterCustomerType as mct on mct.ID=MC.CustomerType              
LEFT JOIN tblMasterBeat AS MB ON MB.ID = TSH.BeatID              
LEFT JOIN tblMasterSalesMan AS MSM ON MSM.ID = TSH.SalesManId        
LEFT JOIN tblRatings AS RT ON RT.ID = MC.Rating        
WHERE TSH.DocPrefix=15 AND TSH.Status IN (1,3,5) '            
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN  @FromDate  AND  @ToDate )' END)                  
  
    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString(  @CustomerName ,'',''))' END)                          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString(  @BeatName ,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND MSM.ID IN (SELECT * from dbo.fnSplitString(  @SalesmanName ,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN (SELECT * from dbo.fnSplitString(  @CustomerType ,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN (SELECT * from dbo.fnSplitString(  @Ratings ,'',''))' END)                     
SET @StrQuery = @StrQuery + ' GROUP BY MC.Code,MC.Name,mct.Name,MC.ID,MB.Name,MSM.Name,MB.ID,MSM.ID,            
InvDate,RT.RatingName) AS NK GROUP BY CustId,BeatID,SalesManID,[Customer Code],[Customer Name],[Customer Type],[Beat Name],             
 [SalesMan Name],MY,Ratings'         
 END      
 ELSE      
 BEGIN      
 set @StrQuery = ' SELECT CustId,BeatID,SalesManID,[Customer Code],[Customer Name],[Customer Type],Ratings,[Beat Name],            
  [SalesMan Name],ISNULL(SUM([Selected Amount]),0) [Selected Amount],MY,SUM(ISNULL(Value,0)) Value FROM (            
 SELECT MC.Id CustId,ISNULL(MB.Id,0) AS BeatID,ISNULL(MSM.Id,0) AS SalesManID,MC.Code AS [Customer Code],              
MC.Name AS [Customer Name],mct.Name AS [Customer Type],              
ISNULL(MB.Name,''Default Beat'') AS [Beat Name], ISNULL(MSM.Name,''Default SalesMan'') AS [SalesMan Name],              
0 AS [Selected Amount],            
UPPER(CONVERT(nvarchar(3),DATENAME(month,ColDate))) +'' ''+ CONVERT(NVARCHAR(10),YEAR(ColDate)) AS MY,            
SUM(TSH.ColAmt) AS Value,RT.RatingName Ratings            
FROM tblTranCollectionHeader AS TSH             
JOIN tblMasterCustomer AS MC ON MC.FAID = TSH.AccID              
left join tblMasterCustomerType as mct on mct.ID=MC.CustomerType              
LEFT JOIN tblMasterBeat AS MB ON MB.ID = TSH.BeatID              
LEFT JOIN tblMasterSalesMan AS MSM ON MSM.ID = TSH.SalesManId        
LEFT JOIN tblRatings AS RT ON RT.ID = MC.Rating             
WHERE TSH.DocPrefix= 19 AND TSH.Status IN (1,3,5)  '            
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.ColDate BETWEEN  @FromDate  AND  @ToDate )' END)                 
   
    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString(  @CustomerName ,'',''))' END)                          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString(  @BeatName ,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND MSM.ID IN (SELECT * from dbo.fnSplitString(  @SalesmanName ,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN (SELECT * from dbo.fnSplitString(  @CustomerType ,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN (SELECT * from dbo.fnSplitString(  @Ratings ,'',''))' END)                   
SET @StrQuery = @StrQuery + ' GROUP BY MC.Code,MC.Name,mct.Name,MC.Id,MB.Name,MSM.Name,MB.Id,MSM.Id,            
ColDate,RT.RatingName) AS NK GROUP BY CustId,BeatID,SalesManID,[Customer Code],[Customer Name],[Customer Type],[Beat Name],             
 [SalesMan Name],MY,Ratings'        
 END      
  insert into #Temp1        
  EXEC sys.sp_executesql @StrQuery, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @Type NVARCHAR(255), @FilterBy NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BeatName, @SalesmanName, @CustomerName, @CustomerType, @Ratings, @Type, @FilterBy, @FromDate, @ToDate      
      
        
 set @StrQuery = 'select ' + case when @FilterBy = '1' or  @FilterBy = '0' THEN 'CustId,BeatId,SalesmanId,[Customer Code],[Customer Name],        
 [Customer Type],Ratings,[Beat Name],[SalesMan Name],ISNULL(SUM([Selected Amount]),0),MY,SUM(ISNULL(Value,0)) Value'         
 WHEN @FilterBy = '2' THEN ' 0,BeatId,0,'''','''','''','''',[Beat Name],'''',ISNULL(SUM([Selected Amount]),0),MY,SUM(ISNULL(Value,0)) Value '         
 WHEN @FilterBy = '3' THEN ' 0,0,SalesmanId,'''','''','''','''','''',[SalesMan Name],ISNULL(SUM([Selected Amount]),0),MY,SUM(ISNULL(Value,0)) Value '        
 WHEN @FilterBy = '4' THEN ' CustId,0,0,[Customer Code],[Customer Name],[Customer Type],Ratings,'''','''',ISNULL(SUM([Selected Amount]),0),MY,SUM(ISNULL(Value,0)) Value '         
 else '''' end  + ' from #Temp1 '        
 set @StrQuery += ' GROUP BY '+ case when @FilterBy = '1' or  @FilterBy = '0' THEN 'CustId,BeatId,SalesmanId,[Customer Code],[Customer Name],        
 [Customer Type],Ratings,[Beat Name],[SalesMan Name],MY'         
 WHEN @FilterBy = '2' THEN ' BeatId,[Beat Name],MY '         
 WHEN @FilterBy = '3' THEN ' SalesmanId,[SalesMan Name],MY '        
 WHEN @FilterBy = '4' THEN ' CustId,[Customer Code],[Customer Name],MY,Ratings,[Customer Type] '         
 else '''' end        
 --select * from #Temp          
  insert into #Temp          
 EXEC sys.sp_executesql @StrQuery, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @Type NVARCHAR(255), @FilterBy NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BeatName, @SalesmanName, @CustomerName, @CustomerType, @Ratings, @Type, @FilterBy, @FromDate, @ToDate             
CREATE TABLE #VNAMES (ID INT IDENTITY(1,1),MFD DATE,MY NVARCHAR(50))            
CREATE TABLE #VNAMESISNULL (ID INT IDENTITY(1,1),MFD DATE,MY NVARCHAR(50))            
INSERT INTO #vnames             
SELECT DISTINCT (DATEADD(mm, DATEDIFF(mm, 0, MY),0)), MY FROM #Temp            
INSERT INTO #VNAMESISNULL            
SELECT DISTINCT (DATEADD(mm, DATEDIFF(mm, 0, MY),0)), 'ISNULL(['+MY+'],0)' FROM #Temp            
DECLARE @PCol NVARCHAR(MAX),@PCol1 NVARCHAR(MAX)            
SELECT @PCol = COALESCE(@PCol+',','') + QUOTENAME(MY) FROM #vnames GROUP BY MY,MFD ORDER BY MFD            
SELECT @PCol1 = COALESCE(@PCol1+'+','') +   (MY)  FROM #VNAMESISNULL GROUP BY MY,MFD ORDER BY MFD            
set @StrQuery = ' SELECT [Customer Code],[Customer Name],[Customer Type],Ratings,[Beat Name],[SalesMan Name],            
 '+ @PCol1 +'  AS [Selected Amount],' + @PCol +'  FROM #Temp            
PIVOT ( SUM(Value) FOR MY IN ('+ @PCol +')) AS NKPIV '            
EXEC sys.sp_executesql @StrQuery, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @Type NVARCHAR(255), @FilterBy NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BeatName, @SalesmanName, @CustomerName, @CustomerType, @Ratings, @Type, @FilterBy, @FromDate, @ToDate            
DROP TABLE #Temp,#VNAMES,#VNAMESISNULL,#Temp1       
END
GO

/****** uspGetDatewiseDetail ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetDatewiseDetail]        
@InvDate DATE = '2025-08-20',@BranchName NVARCHAR(255) = '4',@BeatName NVARCHAR(255) = '',@SalesmanName NVARCHAR(255) = '',@CustomerName NVARCHAR(255) = '',      
@CustomerType NVARCHAR(255) = '',      
@Ratings NVARCHAR(255) = '',@FromDate DATE = '2025-04-01',@ToDate DATE = '2025-08-30'        
as      
begin      
declare @StrQuery nvarchar(max) = ''        
 set @StrQuery = '       
SELECT CASE WHEN TransactionType IN (1,4,5,6) THEN ''Sales'' WHEN TransactionType=2 THEN ''Sales Return''              
WHEN TransactionType=3 THEN ''Damage Return''  END as [Type],format(Sh.InvDate,''dd-MMM-yyyy'')AS [Invoice Date],              
Sh.DocId AS [Doc ID],CONVERT(NVARCHAR,Sh.InvDate,103) AS [Doc Date],DocRef AS [Ref No],MBO.Name [Branch Name],Beat.Name AS [Beat Name],SM.Name AS [Salesman Name],              
MC.Name as [Customer Name],MCT.Name [Customer Type],RT.RatingName [Ratings],                     
case when DocPrefix=15 then dbo.fnGetRoundedValue(TotalProdDiscAmt) else  dbo.fnGetRoundedValue(-1 * TotalProdDiscAmt)END  AS [Total Product Disc Amt],             
case when DocPrefix=15 then dbo.fnGetRoundedValue(TotalTradeDiscAmt) ELSE dbo.fnGetRoundedValue(-1 * TotalTradeDiscAmt) END AS [Total Trade Disc Amt],             
case when DocPrefix=15 then dbo.fnGetRoundedValue(AdditionalDiscAmt) ELSE dbo.fnGetRoundedValue(-1 * AdditionalDiscAmt)END AS [Total Additional Disc amount],                   
case when DocPrefix=15 then dbo.fnGetRoundedValue(TotalDiscountAmt) ELSE dbo.fnGetRoundedValue(-1 * TotalDiscountAmt)END AS [Total Discount Amt],             
CASE WHEN TransactionType IN (1,4,5,6) THEN  [dbo].[fnGetRoundedValue](ISNULL((Sh.GrossAmt),0))              
WHEN TransactionType=2 THEN [dbo].[fnGetRoundedValue](ISNULL((Sh.GrossAmt),0)*-1)              
WHEN TransactionType=3 THEN [dbo].[fnGetRoundedValue](ISNULL((Sh.GrossAmt),0)*-1)              
END AS [Gross Amount],CASE WHEN TransactionType IN (1,4,5,6) THEN  [dbo].[fnGetRoundedValue](ISNULL((Sh.TotalTaxAmt),0))              
WHEN TransactionType=2 THEN [dbo].[fnGetRoundedValue](ISNULL((Sh.TotalTaxAmt),0)*-1)              
WHEN TransactionType=3 THEN [dbo].[fnGetRoundedValue](ISNULL((Sh.TotalTaxAmt),0)*-1)              
END AS [Tax Amount],dbo.fnGetRoundedValue(Frieght) as [Frieght],        
dbo.fnGetRoundedValue(OtherChargeAmt) as [Other Charge Amount],        
dbo.fnGetRoundedValue(RoundOfAmt) as [Round Of Amount],        
CASE WHEN TransactionType IN (1,4,5,6) THEN  [dbo].[fnGetRoundedValue](ISNULL((Sh.NetAmt),0))              
WHEN TransactionType=2 THEN [dbo].[fnGetRoundedValue](ISNULL((Sh.NetAmt),0)*-1)              
WHEN TransactionType=3 THEN [dbo].[fnGetRoundedValue](ISNULL((Sh.NetAmt),0)*-1)              
END AS [Net Amount]              
FROM tblTranSalesHeader SH              
JOIN tblMasterCustomer MC ON MC.ID= SH.CustID      
LEFT JOIN tblMasterBeat AS Beat ON Beat.ID = SH.BeatID            
LEFT JOIN tblMasterSalesMan AS SM ON SM.ID = SH.SalesManId            
LEFT JOIN tblMasterCustomerType AS MCT ON MCT.ID = MC.CustomerType       
LEFT JOIN tblRatings AS RT ON RT.ID = MC.Rating       
JOIN tblMasterBranchOffice AS MBO ON MBO.ID = SH.BranchID      
WHERE TransactionType in(1,2,3,4,5,6) AND Sh.Status IN (1,3,5,6,7) AND Sh.InvDate =  @InvDate '      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND SH.BranchID =  @BranchName ' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND Beat.ID IN ( SELECT * from dbo.fnSplitString(  @BeatName ,'',''))' END)             
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SM.ID IN ( SELECT * from dbo.fnSplitString(  @SalesmanName ,'',''))' END)                
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN ( SELECT * from dbo.fnSplitString(  @CustomerName ,'',''))' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN ( SELECT * from dbo.fnSplitString(  @CustomerType ,'',''))' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN ( SELECT * from dbo.fnSplitString(  @Ratings ,'',''))' END)       
   SET @StrQuery = @StrQuery + ' order by Sh.DocId asc   '     EXEC sys.sp_executesql @StrQuery, N'@InvDate DATE, @BranchName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @FromDate DATE, @ToDate DATE', @InvDate, @BranchName, @BeatName, @SalesmanName, @CustomerName, @CustomerType, @Ratings, @FromDate, @ToDate      
end
GO

/****** uspGetFullGSTInfoReport ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--uspGetFullGSTInfoReport 'S','2026-09-01','2026-09-30',0,'1'   
--uspGetFullGSTInfoReport 'SR','2026-09-01','2026-09-30',0,'1'     
--uspGetFullGSTInfoReport 'P','2026-09-01','2026-09-30',0,'1'       
--uspGetFullGSTInfoReport 'PR','2026-09-01','2026-09-30',0,'1'    
--uspGetFullGSTInfoReport 'PV','2026-09-01','2026-09-30',0,'1'   
--uspGetFullGSTInfoReport 'RV','2026-09-01','2026-09-30',0,'1'      
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetFullGSTInfoReport]      
@TransName NVARCHAR(255),@FromDate DATE,@ToDate DATE,@WOEinv int = 0,@BranchIDs NVARCHAR(255) = null  
AS      
BEGIN      
--REPLACE(CONVERT(NVARCHAR,SH.InvDate,106), ' ', '-')      
SET DATEFORMAT dmy;      
DECLARE @Query NVARCHAR(MAX),@DocPrefix NVARCHAR(20)      
IF ISNULL(@TransName,'')='S' OR ISNULL(@TransName,'')='SR'      
BEGIN      
SET @DocPrefix = (CASE WHEN @TransName='S' THEN 15 ELSE 16 END)      
SET @Query = 'SELECT SH.DocId AS [Inv ID],REPLACE(CONVERT(NVARCHAR,SH.InvDate,106), '' '', ''-'') AS [Inv Date],    
MBO.Name AS [Branch Name],SH.DocRef AS [Doc Ref],      
Cust.Name AS [Party Name],TT.TaxTypeName AS [Tax Type],Cust.GSTIN AS [GSTIN],Prod.Code AS [Product Code],Prod.Name AS [Product Name],      
Prod.EAN,Prod.HSNCode AS [HSN Code],UOM.Name AS [Base UOM],      
CONVERT(DECIMAL(15,2),SD.UomQty) AS [Base UOM Qty],      
CONVERT(DECIMAL(15,2),SD.GrossAmt) AS [Gross Amount],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 1),0)) AS [CGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 1),0)) AS [CGST Amount],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 2),0)) AS [SGST %],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 2),0)) AS [SGST Amount],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 3),0)) AS [UTGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 3),0)) AS [UTGST Amount],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 4),0)) AS [GCESS %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID IN (4,5)),0)) AS [GCESS Amount],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID = 1),0)) AS [IGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID = 1),0)) AS [IGST Amount],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID = 2),0)) AS [ICESS %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID IN (2,3)),0)) AS [ICESS Amount],      
CONVERT(DECIMAL(15,2),SD.NetAmt) AS [Net Amount]'      
SET @Query = @Query + ' FROM tblTranSalesHeader AS SH      
JOIN tblTranSalesDetail AS SD ON SH.ID = SD.InvId      
JOIN tblMasterCustomer AS Cust ON Cust.ID = SH.CustId      
JOIN tblMasterTaxType AS TT ON TT.TaxTypeID = SH.TaxTypeId      
JOIN tblMasterProduct AS Prod ON Prod.ID = SD.ProdId      
JOIN tblMasterUom AS UOM ON Prod.BaseUomID=UOM.ID      
JOIN TblMasterBranchoffice MBO ON MBO.ID = SH.BranchID  
WHERE SH.DocPrefix= @DocPrefix  AND SH.Status IN (1,3,5,6,7) AND ISNULL(SD.TaxId,0)>0      
AND ISNULL(SH.IRN,'''') = (CASE WHEN  @WOEinv  = 0 THEN ISNULL(SH.IRN,'''') ELSE '''' END) '  
SET @Query += case when isnull(@BranchIDs,'') = '' then '' else ' AND SH.BranchID IN (SELECT value FROM STRING_SPLIT( @BranchIDs , '',''))' END  
SET @Query += ' AND (SH.InvDate BETWEEN  @FromDate  AND  @ToDate )      
ORDER BY SH.InvDate,CASE WHEN SH.UDFId > 0 THEN SH.UDFDocId ELSE SH.DocId END '      
PRINT @Query
EXEC sys.sp_executesql @Query, N'@TransName NVARCHAR(255), @FromDate DATE, @ToDate DATE, @WOEinv int, @BranchIDs NVARCHAR(255), @DocPrefix NVARCHAR(20)', @TransName, @FromDate, @ToDate, @WOEinv, @BranchIDs, @DocPrefix      
END    
ELSE IF ISNULL(@TransName,'')='P' OR ISNULL(@TransName,'')='PR'      
BEGIN      
SET @DocPrefix = (CASE WHEN @TransName='P' THEN 1 ELSE 12 END)      
    
SET @Query = 'SELECT BH.DocId AS [Inv ID],REPLACE(CONVERT(NVARCHAR,BH.Date,106), '' '', ''-'') AS [Inv Date],  
MBO.Name AS [Branch Name],BH.RefNo AS [Doc Ref],      
Ven.name AS [Party Name],TT.TaxTypeName AS [Tax Type],Ven.GSTIN AS [GSTIN],Prod.Code AS [Product Code],Prod.Name AS [Product Name],Prod.EAN     
,Prod.HSNCode AS [HSN Code],UOM.Name AS [Base UOM],CONVERT(DECIMAL(15,2),BD.UomQty) AS [Base UOM Qty],      
CONVERT(DECIMAL(15,2),BD.GrossAmt) AS [Gross Amount],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 1),0)) AS [CGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 1),0)) AS [CGST Amount],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 2),0)) AS [SGST %], '      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 2),0)) AS [SGST Amount],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 3),0)) AS [UTGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 3),0)) AS [UTGST Amount],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 4),0)) AS [GCESS %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID IN (4,5)),0)) AS [GCESS Amount],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID = 1),0)) AS [IGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID = 1),0)) AS [IGST Amount],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID = 2),0)) AS [ICESS %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID =  @DocPrefix  AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID IN (2,3)),0)) AS [ICESS Amount],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),BD.NetAmt) AS [Net Amount]      
FROM tbltranspurchaseheader AS BH      
JOIN tbltranspurchasedetail AS BD ON BH.ID = BD.HID      
LEFT JOIN tblMasterProduct AS Prod ON Prod.ID = BD.ProdId      
LEFT JOIN tblMasterUom AS UOM ON Prod.BaseUomID=UOM.ID      
LEFT JOIN tblMasterVendor AS Ven ON Ven.id = BH.VendorID      
JOIN tblMasterTaxType AS TT ON TT.TaxTypeID = BH.TaxTypeId      
JOIN TblMasterBranchoffice MBO ON MBO.ID = BH.BranchID  
WHERE BH.TransID =  @DocPrefix  AND BH.Status IN (1,3,6,5) AND ISNULL(BD.UomID,0)>0      
AND ISNULL(BH.IRN,'''') = (CASE WHEN  @WOEinv  = 0 THEN ISNULL(BH.IRN,'''') ELSE '''' END)  '  
SET @Query += case when isnull(@BranchIDs,'') = '' then '' else ' AND BH.BranchID IN (SELECT value FROM STRING_SPLIT( @BranchIDs , '',''))' END  
SET @Query += '  AND (BH.Date BETWEEN  @FromDate  AND  @ToDate )      
ORDER BY BH.Date,CASE WHEN BH.UDFId > 0 THEN BH.UDFDocId ELSE BH.DocId END'      
EXEC sys.sp_executesql @Query, N'@TransName NVARCHAR(255), @FromDate DATE, @ToDate DATE, @WOEinv int, @BranchIDs NVARCHAR(255), @DocPrefix NVARCHAR(20)', @TransName, @FromDate, @ToDate, @WOEinv, @BranchIDs, @DocPrefix      
END      
ELSE IF ISNULL(@TransName,'')='RV' OR ISNULL(@TransName,'')='PV'     
BEGIN      
SET @DocPrefix = CASE WHEN ISNULL(@TransName,'')='PV' THEN 6 ELSE 7 END      
SELECT BH.DocId AS [Doc ID],REPLACE(CONVERT(NVARCHAR,BH.DocDate,106), ' ', '-') AS [Doc Date],  
MBO.Name AS [Branch Name],RefNo AS [Doc Ref],      
Prod.AccountName AS [Party Name],'GST' AS [Tax Type],'' AS [GSTIN],      
Prod1.AccountName AS [Account Name],BH.SACorHSNCode AS [HSN Code],      
CONVERT(DECIMAL(15,2),BH.Amount) AS [Goods Amount],CONVERT(DECIMAL(15,2),BH.DiscPern) AS [Discount %],      
CONVERT(DECIMAL(15,2),BH.DiscAmt) AS [Discount Amount],CONVERT(DECIMAL(15,2),BH.TDSAmount) AS [TDS Amount],      
CONVERT(NVARCHAR,BH.TDSDate,103) AS [TDS Date],      
CONVERT(DECIMAL(15,2),BH.GrossAmount) AS [Gross Amount],      
--tblTranPRVoucher order by 1 desc      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = @DocPrefix AND TransIdentID = BH.ID AND TaxID = BH.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 1),0)) AS [CGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = @DocPrefix AND TransIdentID = BH.ID AND TaxID = BH.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 1),0)) AS [CGST Amount],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = @DocPrefix AND TransIdentID = BH.ID AND TaxID = BH.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 2),0)) AS [SGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = @DocPrefix AND TransIdentID = BH.ID AND TaxID = BH.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 2),0)) AS [SGST Amount],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = @DocPrefix AND TransIdentID = BH.ID AND TaxID = BH.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 3),0)) AS [UTGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = @DocPrefix AND TransIdentID = BH.ID AND TaxID = BH.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 3),0)) AS [UTGST Amount],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = @DocPrefix AND TransIdentID = BH.ID AND TaxID = BH.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 4),0)) AS [GCESS %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = @DocPrefix AND TransIdentID = BH.ID AND TaxID = BH.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID IN (4,5)),0)) AS [GCESS Amount],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = @DocPrefix AND TransIdentID = BH.ID AND TaxID = BH.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID = 1),0)) AS [IGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = @DocPrefix AND TransIdentID = BH.ID AND TaxID = BH.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID = 1),0)) AS [IGST Amount],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = @DocPrefix AND TransIdentID = BH.ID AND TaxID = BH.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID = 2),0)) AS [ICESS %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = @DocPrefix AND TransIdentID = BH.ID AND TaxID = BH.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID IN (2,3)),0)) AS [ICESS Amount],      
CONVERT(DECIMAL(15,2),BH.NetAmount) AS [Net Amount]      
FROM tblTranPRVoucher AS BH      
LEFT JOIN tblFAAccount AS Prod ON Prod.FAID = BH.PartyID      
left JOIN tblFAAccount AS Prod1 ON Prod1.FAID = BH.FAID      
JOIN TblMasterBranchoffice MBO ON MBO.ID = BH.BranchID  
WHERE BH.TransID = @DocPrefix AND BH.Status IN (1,3,5)      
AND (BH.DocDate BETWEEN @FromDate AND @ToDate)      
AND (isnull(@BranchIDs,'') = '' OR BH.BranchID in (SELECT value FROM STRING_SPLIT(@BranchIDs, ',')))  
ORDER BY BH.DocDate,CASE WHEN BH.UDFId > 0 THEN BH.UDFDocId ELSE BH.DocId END      
END      
END    
GO

/****** uspGetJsonDataforEWaybill ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--uspGetJsonDataforEWaybill 2,3,0,'2026-01-05','2026-12-30',''                    
--uspGetJsonDataforEWaybill 3,639,'2022-12-05','2026-12-30'                    
--uspGetJsonDataforEWaybill 3,1,'2627/JUL/31','2022-12-05','2026-12-30'                     
--uspGetJsonDataforEWaybill 5,3,'','2024-12-05','2026-12-30','VLS/2627/4'                      
--uspGetJsonDataforEWaybill 6,'','2022-12-05','2026-12-30',''                     
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetJsonDataforEWaybill]                      
@Mode INT,@TypeID INT,@InvID nvarchar(255) =null,@FromDate date = NULL,@ToDate DATE = NULL,@DocIDs NVARCHAR(MAX)=NULL                      
as                      
begin                      
DECLARE @QRY NVARCHAR(MAX) = ''                      
DECLARE @CompName NVARCHAR(255),@CompAddress NVARCHAR(255),@CompCity NVARCHAR(255),                      
@CompPIN NVARCHAR(255),@compState NVARCHAR(255),@compStateCode NVARCHAR(255),@compGSTIN NVARCHAR(255),@MainHSN nvarchar(50)                      
SELECT @CompName = CompanyName,@CompAddress = Address,@CompCity = City,@CompPIN = Pincode,@compState = State,                      
@compStateCode = LEFT(GSTIN,2),@compGSTIN = GSTIN FROM tblCompanyRegistration                     
DECLARE @DetailGross decimal(25,2)        
if(@Mode = 1)                      
BEGIN                      
SELECT 'version' strver,'1.0.0621' ver                      
END                      
IF(@Mode = 2)                      
BEGIN                      
IF(@TypeID = 1)--INVOICE E-WAY      
BEGIN      
SET @QRY = 'select SH.ID,SH.DocId,SH.InvDate FROM tblTranSalesHeader SH                      
JOIN tblTranSalesDetail SD ON SD.InvId = SH.ID                      
JOIN tblMasterCustomer MC ON MC.ID = SH.CustId                      
WHERE SH.DocPrefix = 15 AND Status IN (1,3,5) AND ISNULL(SH.EWBNo,'''') = '''' and isnull(SH.VehicleNo,0) > 0 and isnull(SH.DocId,'''') != '''''                   
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+' @FromDate ' +' AND ' +' @ToDate ' +'' END)                      
--SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue in (SELECT id FROM dbo.fnSplitString(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue in (SELECT id FROM dbo.fnSplitString(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
SET @QRY = @QRY + ' GROUP BY SH.ID,SH.DocId,SH.InvDate '                      
SET @QRY = @QRY + ' ORDER BY DocId,SH.InvDate'        
END      
ELSE IF(@TypeID = 3)--VLS E-WAY      
BEGIN      
--select * from tblVanLoadingSlipHeader      
SET @QRY = 'select SH.ID,SH.DocId,SH.DocDate InvDate FROM tblVanLoadingSlipHeader SH       
WHERE Status IN (1,3,5) AND ISNULL(SH.EWBNo,'''') = '''' and isnull(SH.VehicleNo,0) > 0 and isnull(SH.DocId,'''') != '''''                   
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.DocDate BETWEEN '+' @FromDate ' +' AND ' +' @ToDate ' +'' END)                      
--SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue in (SELECT id FROM dbo.fnSplitString(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue in (SELECT id FROM dbo.fnSplitString(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
SET @QRY = @QRY + ' GROUP BY SH.ID,SH.DocId,SH.DocDate '                      
SET @QRY = @QRY + ' ORDER BY DocId,SH.DocDate'      
END      
EXEC sys.sp_executesql @QRY, N'@Mode INT, @TypeID INT, @InvID nvarchar(255), @FromDate date, @ToDate DATE, @DocIDs NVARCHAR(MAX), @CompName NVARCHAR(255), @CompAddress NVARCHAR(255), @CompCity NVARCHAR(255), @CompPIN NVARCHAR(255), @compStateCode NVARCHAR(255), @compGSTIN NVARCHAR(255)', @Mode, @TypeID, @InvID, @FromDate, @ToDate, @DocIDs, @CompName, @CompAddress, @CompCity, @CompPIN, @compStateCode, @compGSTIN                      
END                      
ELSE IF(@Mode = 3)                      
BEGIN                      
IF(@TypeID = 1)--INVOICE E-WAY      
BEGIN      
SELECT @MainHSN = HSNCode FROM (                      
select TOP 1 MP.HSNCode from tblTranSalesDetail SD                      
JOIN tblTranSalesHeader SH ON SH.ID = SD.InvID                  
JOIN tblMasterProduct MP ON MP.ID = SD.ProdId         
WHERE SH.DocPrefix = 15 AND Status IN (1,3,5) AND ISNULL(SH.EWBNo,'') = '' and isnull(SH.VehicleNo,0) > 0 AND SD.TaxId > 0 AND SH.DocID = @InvID                   
ORDER BY SD.NetAmt ASC) AS NK                      
       
set @DetailGross = (                    
select  SUM(ROUND(SD.GrossAmt,2)) from tblTranSalesDetail SD              
JOIN tblTranSalesHeader SH ON SH.ID = SD.InvID              
WHERE SH.DocID = @InvID AND Status IN (1,3,5))                
              
select @compGSTIN userGstin,'O' supplyType,1 subSupplyType,'' "subSupplyDesc",'INV' "docType",DocId "docNo",                      
CONVERT(NVARCHAR,InvDate,103) "docDate",1 "transType",@compGSTIN fromGstin,@CompName fromTrdName,@CompAddress fromAddr1,'' fromAddr2,                      
@CompCity fromPlace,@CompPIN fromPincode,@compStateCode fromStateCode,@compStateCode actualFromStateCode,                      
CASE WHEN ISNULL(MC.GSTIN,'') != '' THEN MC.GSTIN ELSE 'URP' END toGstin,MC.Name "toTrdName",MC.Billadd1 "toAddr1",                      
MC.Billadd2 +' ' + MC.Billadd3 "toAddr2",CASE WHEN SH.BeatID = 0 THEN 'CHENNAI' ELSE GHL.Name END "toPlace",MC.Pincode "toPincode",                      
GST.TINNo "toStateCode",GST.TINNo "actualToStateCode",@DetailGross "totalValue",--dbo.fnGetRoundedValue(ROUND(SH.GrossAmt,2)) "totalValue",                      
(CASE WHEN SH.TaxTypeId = 1 THEN dbo.fnGetRoundedValue(SH.TotalTaxAmt/2) ELSE '0.00' END) "cgstValue",                      
(CASE WHEN SH.TaxTypeId = 1 THEN dbo.fnGetRoundedValue(SH.TotalTaxAmt/2) ELSE '0.00' END) "sgstValue",                      
(CASE WHEN SH.TaxTypeId = 2 THEN dbo.fnGetRoundedValue(TotalTaxAmt) ELSE '0.00' END) "igstValue",0.00 "cessValue",                      
0.00 "TotNonAdvolVal",dbo.fnGetRoundedValue(ROUND(SH.NetAmt,2) - (@DetailGross + ROUND(SH.TotalTaxAmt,2))) "OthValue",              
dbo.fnGetRoundedValue(SH.NetAmt) "totInvValue",                      
(CASE WHEN TransMode = 'Road' THEN 1 WHEN TransMode = 'Rail' THEN 2                      
WHEN TransMode = 'Air' THEN 3 WHEN TransMode = 'Ship/Road cum Ship' THEN 4 ELSE '' END) "transMode",                      
CASE WHEN MC.Pincode = @CompPIN THEN 1 ELSE isnull(SH.Distance,0) END "transDistance",(case when isnull(SH.TransportName,'') = '' then '' else LEFT(TransportName,100) end) "transporterName",                      
(case when isnull(SH.TransportID,'') = '' then '' else LEFT(SH.TransportID,15) end) "transporterId",SH.DocId "transDocNo",                      
CONVERT(NVARCHAR,SH.InvDate,103) "transDocDate",VH.VehicleNo "vehicleNo",                      
CASE WHEN SH.VehicleType = 'Regular' THEN 'R' WHEN SH.VehicleType = 'ODC' THEN 'O' ELSE '' end "vehicleType",@MainHSN mainHsnCode                      
from tblTranSalesHeader SH                      
JOIN tblMasterCustomer MC ON MC.ID = SH.CustId                      
LEFT JOIN tblMasterBeat GHL ON GHL.ID = SH.BeatID                      
LEFT JOIN tblMasterVehicle VH ON VH.ID = SH.VehicleNo                      
LEFT JOIN tblGSTStateNameandCode GST ON GST.StateID = MC.StateID                      
WHERE SH.DocPrefix =15 AND Status IN (1,3,5) AND ISNULL(SH.EWBNo,'') = '' and isnull(SH.VehicleNo,0) > 0 AND SH.DocID = @InvID                      
END      
ELSE IF(@TypeID = 3)--VLS E-WAY      
BEGIN      
SELECT @MainHSN = HSNCode FROM (                      
select TOP 1 MP.HSNCode from tblVanLoadingSlipDetail SD                      
JOIN tblVanLoadingSlipHeader SH ON SH.ID = SD.ID                  
JOIN tblMasterProduct MP ON MP.ID = SD.ProdId                      
WHERE Status IN (1,3,5) AND ISNULL(SH.EWBNo,'') = '' and isnull(SH.VehicleNo,0) > 0 AND SD.TaxId > 0 AND SH.DocID = @InvID                   
ORDER BY SD.NetAmt ASC) AS NK                      
          
set @DetailGross = (                    
select  SUM(ROUND(SD.GrossAmt,2)) from tblVanLoadingSlipDetail SD              
JOIN tblVanLoadingSlipHeader SH ON SH.ID = SD.ID              
WHERE SH.DocID = @InvID AND Status IN (1,3,5))   
              
select @compGSTIN userGstin,'O' supplyType,10 subSupplyType,'' "subSupplyDesc",'CHL' "docType",DocId "docNo",                      
CONVERT(NVARCHAR,DocDate,103) "docDate",1 "transType",@compGSTIN fromGstin,@CompName fromTrdName,@CompAddress fromAddr1,'' fromAddr2,      
@CompCity fromPlace,@CompPIN fromPincode,@compStateCode fromStateCode,@compStateCode actualFromStateCode,      
@compGSTIN toGstin,'' "toTrdName",'' "toAddr1",      
'' "toAddr2",'' "toPlace",@CompPIN "toPincode",--MC.Pincode      
@compStateCode "toStateCode",@compStateCode "actualToStateCode",@DetailGross "totalValue",--dbo.fnGetRoundedValue(ROUND(SH.GrossAmt,2)) "totalValue",      
dbo.fnGetRoundedValue(SH.TaxAmt/2)"cgstValue",dbo.fnGetRoundedValue(SH.TaxAmt/2) "sgstValue",      
'0.00' "igstValue",0.00 "cessValue",0.00 "TotNonAdvolVal",      
dbo.fnGetRoundedValue(ROUND(SH.NetAmt,2) - (@DetailGross + ROUND(SH.TaxAmt,2))) "OthValue",              
dbo.fnGetRoundedValue(SH.NetAmt) "totInvValue",                      
(CASE WHEN VehicleType = 'Road' THEN 1 WHEN VehicleType = 'Rail' THEN 2                      
WHEN VehicleType = 'Air' THEN 3 WHEN VehicleType = 'Ship/Road cum Ship' THEN 4 ELSE '' END) "transMode",                      
1 "transDistance",(case when isnull(SH.TransportName,'') = '' then '' else LEFT(TransportName,100) end) "transporterName",                      
(case when isnull(SH.TransportID,'') = '' then '' else LEFT(SH.TransportID,15) end) "transporterId",SH.DocId "transDocNo",                      
CONVERT(NVARCHAR,SH.DocDate,103) "transDocDate",VH.VehicleNo "vehicleNo",                      
CASE WHEN SH.TransMode = 'Regular' THEN 'R' WHEN SH.TransMode = 'ODC' THEN 'O' ELSE '' end "vehicleType",@MainHSN mainHsnCode                      
from tblVanLoadingSlipHeader SH                                    
LEFT JOIN tblMasterVehicle VH ON VH.ID = SH.VehicleNo      
WHERE Status IN (1,3,5) AND ISNULL(SH.EWBNo,'') = '' and isnull(SH.VehicleNo,0) > 0 AND SH.DocID = @InvID       
END      
END                      
ELSE IF(@Mode = 4)                      
BEGIN                      
IF(@TypeID = 1)--INVOICE E-WAY      
BEGIN      
SELECT SD.Serial "itemNo",MP.Name "productName",'' "productDesc",MP.HSNCode "hsnCode",dbo.fnGetRoundedValue(SD.UomQty) "quantity",                      
UOM.Name "qtyUnit",dbo.fnGetRoundedValue(SD.GrossAmt) "taxableAmount",dbo.fnGetRoundedValue(SD.TaxValue/2) "sgstRate",                
dbo.fnGetRoundedValue(SD.TaxValue/2) "cgstRate",0 "igstRate",0 "cessRate",                      
0 "cessNonAdvol" from tblTranSalesHeader SH                      
JOIN tblTranSalesDetail SD ON SD.InvId = SH.ID                      
JOIN tblMasterProduct MP ON MP.ID = SD.ProdId                      
JOIN tblMasterUom UOM ON UOM.ID = SD.UomId                      
WHERE SH.DocPrefix = 15 AND Status IN (1,3,5) AND ISNULL(SH.EWBNo,'') = '' and isnull(SH.VehicleNo,0) > 0 AND SD.TaxId > 0 AND SH.DocID = @InvID                      
ORDER BY SD.Serial            
END      
ELSE IF(@TypeID = 3)--VLS E-WAY      
BEGIN      
SELECT SD.Serial "itemNo",MP.Name "productName",'' "productDesc",MP.HSNCode "hsnCode",dbo.fnGetRoundedValue(SD.UomQty) "quantity",                      
UOM.Name "qtyUnit",dbo.fnGetRoundedValue(SD.GrossAmt) "taxableAmount",dbo.fnGetRoundedValue(SD.TaxValue/2) "sgstRate",                
dbo.fnGetRoundedValue(SD.TaxValue/2) "cgstRate",0 "igstRate",0 "cessRate",                      
0 "cessNonAdvol" from tblVanLoadingSlipHeader SH                      
JOIN tblVanLoadingSlipDetail SD ON SD.ID = SH.ID                      
JOIN tblMasterProduct MP ON MP.ID = SD.ProdId                      
JOIN tblMasterUom UOM ON UOM.ID = SD.UomId                      
WHERE Status IN (1,3,5) AND ISNULL(SH.EWBNo,'') = '' and isnull(SH.VehicleNo,0) > 0 AND SD.TaxId > 0 AND SH.DocID = @InvID                      
ORDER BY SD.Serial       
END      
END                      
else if(@Mode = 5)                      
BEGIN                
IF(@TypeID = 1)--INVOICE E-WAY      
BEGIN      SET @QRY = ' select DocId "docNo",CONVERT(NVARCHAR,InvDate,103) "docDate",MC.Name "toTrdName",CASE WHEN ISNULL(MC.GSTIN,'''') != '''' THEN MC.GSTIN ELSE ''URP'' END toGstin,        
MC.Billadd1 "toAddr1",MC.Billadd2 +'' '' + MC.Billadd3 "toAddr2",CASE WHEN SH.BeatID = 0 THEN ''CHENNAI'' ELSE GHL.Name END "toPlace",MC.Pincode "toPincode",        
@compGSTIN userGstin,''O'' supplyType,1 subSupplyType,'''' "subSupplyDesc",''INV'' "docType",                      
1 "transType",@compGSTIN fromGstin,@CompName fromTrdName,@CompAddress fromAddr1,'''' fromAddr2,                      
@CompCity fromPlace,@CompPIN fromPincode,@compStateCode fromStateCode,@compStateCode actualFromStateCode,        
TINNo "toStateCode",TINNo "actualToStateCode",dbo.fnGetRoundedValue(SH.GrossAmt) "totalValue",                      
(CASE WHEN SH.TaxTypeId = 1 THEN dbo.fnGetRoundedValue(SH.TotalTaxAmt/2) ELSE ''0.00'' END) "cgstValue",                      
(CASE WHEN SH.TaxTypeId = 1 THEN dbo.fnGetRoundedValue(SH.TotalTaxAmt/2) ELSE ''0.00'' END) "sgstValue",                      
(CASE WHEN SH.TaxTypeId = 2 THEN dbo.fnGetRoundedValue(TotalTaxAmt) ELSE ''0.00'' END) "igstValue",0.00 "cessValue",                      
0.00 "TotNonAdvolVal",dbo.fnGetRoundedValue( NetAmt - (GrossAmt + TotalTaxAmt)) "OthValue",dbo.fnGetRoundedValue(SH.NetAmt) "totInvValue",                      
CONVERT(VARCHAR,(CASE WHEN TransMode = ''Road'' THEN 1 WHEN TransMode = ''Rail'' THEN 2 WHEN TransMode = ''Air'' THEN 3                      
WHEN TransMode = ''Ship/Road cum Ship'' THEN 4 ELSE '''' END)) "transMode",                      
CASE WHEN MC.Pincode = @CompPIN THEN 1 ELSE isnull(SH.Distance,0) END "transDistance",(case when isnull(SH.TransportName,'''') = '''' then '''' else LEFT(TransportName,100) end) "transporterName",                      
(case when isnull(SH.TransportID,'''') = '''' then '''' else LEFT(SH.TransportID,15) end) "transporterId",SH.DocId "transDocNo",                      
CONVERT(NVARCHAR,SH.InvDate,103) "transDocDate",VH.VehicleNo "vehicleNo",                      
CASE WHEN SH.VehicleType = ''Regular'' THEN ''R'' WHEN SH.VehicleType = ''ODC'' THEN ''O'' ELSE '''' end "vehicleType",'''' mainHsnCode                      
from tblTranSalesHeader SH                      
JOIN tblMasterCustomer MC ON MC.ID = SH.CustId                      
LEFT JOIN tblMasterBeat GHL ON GHL.ID = SH.BeatID                         
LEFT JOIN tblMasterVehicle VH ON VH.ID = SH.VehicleNo                      
LEFT JOIN tblGSTStateNameandCode GST ON GST.StateID = MC.StateID                         
WHERE SH.DocPrefix =15 AND Status IN (1,3,5) AND ISNULL(SH.EWBNo,'''') = '''' and isnull(SH.VehicleNo,0) > 0 and isnull(SH.DocId,'''') != '''' '                  
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+' @FromDate ' +' AND ' +' @ToDate ' +'' END)                      
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue in (SELECT id FROM dbo.fnSplitString(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
SET @QRY = @QRY + ' ORDER BY DocId '      
END      
ELSE IF(@TypeID = 3)--VLS E-WAY      
BEGIN      
SET @QRY = ' select DocId "docNo",CONVERT(NVARCHAR,DocDate,103) "docDate",'''' "toTrdName",@compGSTIN toGstin,        
'''' "toAddr2",'''' "toPlace",@CompPIN "toPincode",      
@compGSTIN userGstin,''O'' supplyType,10 subSupplyType,'''' "subSupplyDesc",''CHL'' "docType",                      
1 "transType",@compGSTIN fromGstin,@CompName fromTrdName,@CompAddress fromAddr1,'''' fromAddr2,                      
@CompCity fromPlace,@CompPIN fromPincode,@compStateCode fromStateCode,@compStateCode actualFromStateCode,        
@compStateCode "toStateCode",@compStateCode "actualToStateCode",dbo.fnGetRoundedValue(SH.GrossAmt) "totalValue",                      
dbo.fnGetRoundedValue(SH.TaxAmt/2) "cgstValue",dbo.fnGetRoundedValue(SH.TaxAmt/2) "sgstValue",      
''0.00'' "igstValue",0.00 "cessValue",0.00 "TotNonAdvolVal",      
dbo.fnGetRoundedValue( NetAmt - (GrossAmt + TaxAmt)) "OthValue",dbo.fnGetRoundedValue(SH.NetAmt) "totInvValue",                      
CONVERT(VARCHAR,(CASE WHEN VehicleType = ''Road'' THEN 1 WHEN VehicleType = ''Rail'' THEN 2 WHEN VehicleType = ''Air'' THEN 3                      
WHEN VehicleType = ''Ship/Road cum Ship'' THEN 4 ELSE '''' END)) "transMode",                      
1 "transDistance",(case when isnull(SH.TransportName,'''') = '''' then '''' else LEFT(TransportName,100) end) "transporterName",                      
(case when isnull(SH.TransportID,'''') = '''' then '''' else LEFT(SH.TransportID,15) end) "transporterId",SH.DocId "transDocNo",                      
CONVERT(NVARCHAR,SH.DocDate,103) "transDocDate",VH.VehicleNo "vehicleNo",                      
CASE WHEN SH.TransMode = ''Regular'' THEN ''R'' WHEN SH.TransMode = ''ODC'' THEN ''O'' ELSE '''' end "vehicleType",'''' mainHsnCode                      
from tblVanLoadingSlipHeader SH                      
LEFT JOIN tblMasterVehicle VH ON VH.ID = SH.VehicleNo      
WHERE Status IN (1,3,5) AND ISNULL(SH.EWBNo,'''') = '''' and isnull(SH.VehicleNo,0) > 0 and isnull(SH.DocId,'''') != '''' '                  
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.DocDate BETWEEN '+' @FromDate ' +' AND ' +' @ToDate ' +'' END)                      
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue in (SELECT id FROM dbo.fnSplitString(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
SET @QRY = @QRY + ' ORDER BY DocId '      
END      
EXEC sys.sp_executesql @QRY, N'@Mode INT, @TypeID INT, @InvID nvarchar(255), @FromDate date, @ToDate DATE, @DocIDs NVARCHAR(MAX), @CompName NVARCHAR(255), @CompAddress NVARCHAR(255), @CompCity NVARCHAR(255), @CompPIN NVARCHAR(255), @compStateCode NVARCHAR(255), @compGSTIN NVARCHAR(255)', @Mode, @TypeID, @InvID, @FromDate, @ToDate, @DocIDs, @CompName, @CompAddress, @CompCity, @CompPIN, @compStateCode, @compGSTIN                      
END                      
else if(@Mode = 6)                      
BEGIN               
IF(@TypeID = 1)--INVOICE E-WAY      
BEGIN      
SET @QRY = ' SELECT DocId "docNo",SD.Serial "itemNo",MP.Name "productName",'''' "productDesc",MP.HSNCode "hsnCode",dbo.fnGetRoundedValue(SD.UomQty) "quantity",                      
UOM.Name "qtyUnit",dbo.fnGetRoundedValue(SD.GrossAmt) "taxableAmount",dbo.fnGetRoundedValue(SD.TaxAmt / 2) "sgstRate",dbo.fnGetRoundedValue(SD.TaxAmt / 2) "cgstRate",0 "igstRate",0 "cessRate",                      
0 "cessNonAdvol" from tblTranSalesHeader SH                      
JOIN tblTranSalesDetail SD ON SD.InvId = SH.ID                      
JOIN tblMasterCustomer MC ON MC.ID = SH.CustId                      
JOIN tblMasterProduct MP ON MP.ID = SD.ProdId                      
JOIN tblMasterUom UOM ON UOM.ID = SD.UomId                      
WHERE SH.DocPrefix =15 AND Status IN (1,3,5) AND ISNULL(SH.EWBNo,'''') = '''' AND SD.TaxId > 0  and isnull(SH.VehicleNo,0) > 0  and isnull(SH.DocId,'''') != '''''--AND ISNULL(MC.GSTIN,'''') != ''''                       
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+' @FromDate ' +' AND ' +' @ToDate ' +'' END)                      
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue in (SELECT id FROM dbo.fnSplitString(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
SET @QRY = @QRY + ' ORDER BY SH.InvDate,DocId,SD.Serial '                      
END      
ELSE IF(@TypeID = 3)--VLS E-WAY      
BEGIN      
SET @QRY = ' SELECT DocId "docNo",SD.Serial "itemNo",MP.Name "productName",'''' "productDesc",MP.HSNCode "hsnCode",dbo.fnGetRoundedValue(SD.UomQty) "quantity",                      
UOM.Name "qtyUnit",dbo.fnGetRoundedValue(SD.GrossAmt) "taxableAmount",dbo.fnGetRoundedValue(SD.TaxAmt / 2) "sgstRate",dbo.fnGetRoundedValue(SD.TaxAmt / 2) "cgstRate",0 "igstRate",0 "cessRate",                      
0 "cessNonAdvol" from tblVanLoadingSlipHeader SH                      
JOIN tblVanLoadingSlipDetail SD ON SD.ID = SH.ID       
JOIN tblMasterProduct MP ON MP.ID = SD.ProdId                      
JOIN tblMasterUom UOM ON UOM.ID = SD.UomId                      
WHERE Status IN (1,3,5) AND ISNULL(SH.EWBNo,'''') = '''' AND SD.TaxId > 0  and isnull(SH.VehicleNo,0) > 0  and isnull(SH.DocId,'''') != '''''--AND ISNULL(MC.GSTIN,'''') != ''''                       
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.DocDate BETWEEN '+' @FromDate ' +' AND ' +' @ToDate ' +'' END)                      
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue in (SELECT id FROM dbo.fnSplitString(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
SET @QRY = @QRY + ' ORDER BY SH.DocDate,DocId,SD.Serial '       
END      
EXEC sys.sp_executesql @QRY, N'@Mode INT, @TypeID INT, @InvID nvarchar(255), @FromDate date, @ToDate DATE, @DocIDs NVARCHAR(MAX), @CompName NVARCHAR(255), @CompAddress NVARCHAR(255), @CompCity NVARCHAR(255), @CompPIN NVARCHAR(255), @compStateCode NVARCHAR(255), @compGSTIN NVARCHAR(255)', @Mode, @TypeID, @InvID, @FromDate, @ToDate, @DocIDs, @CompName, @CompAddress, @CompCity, @CompPIN, @compStateCode, @compGSTIN                      
END                      
END 
GO

/****** uspgetsetBRSData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--[uspgetsetBRSData] 2
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspgetsetBRSData]      
@Mode int,@BankAccID int = 153,@AccName nvarchar(255) = '',@FromDate Date ='2024-03-15',@ToDate Date='2025-04-01',@shwblkdate int =0      
as      
begin      
declare @strQuery NVARCHAR(MAX)      
if(@Mode = 1)      
begin      
SELECT 1 Type,'BankAccNo' Trans,MBA.ID,'1' Code,AccountNo+'|'+MB.Name+'|'+BranchName+'|'+IFSCCode+'|'+MICR+'|'+CONVERT(nvarchar,SetDefault)+'|'+CONVERT(nvarchar,MB.ID) Name             
from tblMasterBankAccount MBA                
JOIN tblMasterBank MB ON MB.ID = MBA.BankID where MBA.Active = 1 AND FAID > 0         
union all          
select 2 Type,'PartyName' Trans,FAID ID,'' Code,AccountName Name from tblFAAccount  where Active = 1       
--and AccountGroup IN (44,2,25,3,29,6,12,13,39,1,19,33,43,35,18,20)        
end      
if(@Mode = 2)      
begin      
create table #open(Balance decimal(25,2),CrDr nvarchar(10))  
create table #close(Balance decimal(25,2),CrDr nvarchar(10))  
insert into #open  
exec [uspLoadClosingBalance] 2,@BankAccID,@FromDate  
insert into #close  
exec [uspLoadClosingBalance] 1,@BankAccID,@ToDate  
--select * from #open  
create table #MainData(Date date,TransName NVARCHAR(255),DocID NVARCHAR(255),DocDate NVARCHAR(255),DocRef NVARCHAR(255),AccountName NVARCHAR(255),  
Debit DECIMAL(25,2),Credit DECIMAL(25,2),Remarks NVARCHAR(255), Narration NVARCHAR(255),Description NVARCHAR(255),  
AccountID INT, DocValue INT, BRSDate DATE,ChequeInfo NVARCHAR(255),JVID INT, ChequeNo NVARCHAR(255),  
)  
  
SET @strQuery = 'SELECT DISTINCT JVID into #tempTable FROM tblFAJournal AS FAJ WHERE [Status] NOT IN (2,4)  AND AccountID =  @BankAccID '       
SET @strQuery += '      
SELECT FA.DocDate Date,DOC.TransName AS [TransName],Doc.DocPrefix+ CONVERT(NVARCHAR(255),FA.DocValue) AS [DocID],                                      
Convert(VARCHAR(10),FA.DocDate,103) AS [DocDate],DocRef AS [DocRef],AccName.AccountName AS [AccountName],                                      
Credit AS [Debit],Debit AS [Credit],Remarks,Narration,DocStatus.[Description],                                    
FA.AccountID,FA.DocValue,FA.BRSDate as [BRSDate],FA.ChequeInfo,JvidTable.JVID,null ChequeNo                        
FROM tblFAJournal AS FA                                      
JOIN #tempTable AS JvidTable ON FA.JVID=JvidTable.JVID                             
JOIN tblFAAccount AS AccName ON FA.AccountID=AccName.FAID                             
JOIN tblDocumentseries AS DOC ON FA.DocPrefix=DOC.TransID                                      
JOIN tblStatus AS DocStatus  ON FA.[Status]=DocStatus.ID       
WHERE  FA.AccountID ! =   @BankAccID '      
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND FA.DocDate BETWEEN '+' @FromDate  AND '+' @ToDate ' END                           
SET @strQuery += CASE WHEN ISNULL(@AccName,'') = '' THEN '' ELSE ' AND AccName.AccountName = '+' @AccName ' END                
SET @strQuery += CASE WHEN ISNULL(@shwblkdate,'') = '0' THEN '' ELSE ' AND BRSDate IS NULL ' END           
SET @strQuery +=  ' ORDER BY FA.DocDate,FA.DocPrefix,FA.DocValue drop table #tempTable'   
  
INSERT INTO #MainData  
EXEC sys.sp_executesql @strQuery, N'@Mode int, @BankAccID int, @AccName nvarchar(255), @FromDate Date, @ToDate Date, @shwblkdate int', @Mode, @BankAccID, @AccName, @FromDate, @ToDate, @shwblkdate      
select NULL Date,'Opening Balance' TransName,'' DocID,'' DocDate,'' DocRef,'' AccountName,dbo.fnGetRoundedValue(case when CrDr = 'Dr' then Balance else 0 end) Debit,  
dbo.fnGetRoundedValue(case when CrDr = 'Cr' then Balance else 0 end) Credit,'' Remarks,'' Narration,'' Description, '' AccountID,  
'' DocValue,null BRSDate,'' ChequeInfo,'' JVID,'' ChequeNo from #open  
UNION ALL  
SELECT Date,TransName,DocID,DocDate,DocRef,AccountName,dbo.fnGetRoundedValue(Debit) Debit,dbo.fnGetRoundedValue(Credit) Credit,Remarks,Narration,Description,AccountID,DocValue,BRSDate,ChequeInfo,JVID,ChequeNo  
 FROM #MainData  
UNION ALL  
SELECT NULL Date,'Total' TransName,'' DocID,'' DocDate,'' DocRef,'' AccountName,  
dbo.fnGetRoundedValue(isnull(SUM(Debit),0)) Debit,dbo.fnGetRoundedValue(isnull(SUM(Credit),0)) Credit,'' Remarks,'' Narration,'' Description, '' AccountID,  
'' DocValue,null BRSDate,'' ChequeInfo,'' JVID,'' ChequeNo  
 FROM #MainData  
 union all  
 select NULL Date,'Closing Balance' TransName,'' DocID,'' DocDate,'' DocRef,'' AccountName,  
dbo.fnGetRoundedValue(case when CrDr = 'Dr' then Balance else 0 end) Debit,dbo.fnGetRoundedValue(case when CrDr = 'Cr' then Balance else 0 end) Credit,'' Remarks,'' Narration,'' Description, '' AccountID,  
'' DocValue,null BRSDate,'' ChequeInfo,'' JVID,'' ChequeNo from #close  
drop table #open,#MainData,#close  
end      
end  
GO

/****** uspGetsetDailyactivityData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--uspGetsetDailyactivityData 1,2,4,1                      
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetsetDailyactivityData]                      
@Mode INT,@ID INT = NULL,@SMID INT = NULL,@SelectID NVARCHAR(MAX) = null,@Value NVARCHAR(MAX) = NULL                    
AS                      
BEGIN                      
DECLARE @StrQuery NVARCHAR(MAX) = '',@AllSalesman INT = (SELECT AppValue FROM tblAppConfig WHERE AppId = 18)            
IF(@MODE = 1)                      
BEGIN  
  
create table #tempinit(Type tinyint,Trans nvarchar(50),ID int,Code nvarchar(100),Name nvarchar(255))  
if(@ID = 1)  
begin  
insert into #tempinit  
SELECT 3 Type,'Manuf' Trans,ID,'',Name FROM tblMasterManufacturer MF where MF.Active = 1  
end  
else  
begin  
insert into #tempinit  
SELECT 3 Type,'Manuf' Trans,ID,'',Name FROM tblMasterManufacturer MF  
JOIN tblManufacturerMapping MFM ON MFM.MfrID = MF.ID  
WHERE (MF.Active = 1 AND MFM.UserID = @ID AND MFM.Active = 1)  
end  
declare @getBeatID INT,@getSMID INT                    
select @getBeatID =ISNULL(BeatID,0),@getSMID = ISNULL(SalesmanID,0) from tblUsers WHERE ID = @ID                    
select 1 Type,'Salesman' Trans,ID,'' Code,Name from tblMasterSalesman where Active = 1                                  
union all                                  
SELECT 2 Type,'Beat' Trans,ID,'',Name FROM tblMasterBeat WHERE Active = 1                      
union all                                  
select * from #tempinit  
union all                                  
SELECT 4 Type,'Category' Trans,ID,'' Code,Name FROM tblMasterCategory WHERE Active = 1                      
union all                      
SELECT 5 Type,'Product' Trans,ID,Code,Name FROM tblMasterProduct WHERE Active = 1                      
union all                      
SELECT 6 Type,'Branch' Trans,ID,Code,Name FROM tblMasterBranchOffice WHERE Active = 1                      
union all                      
select 7 Type,'Today Route' Trans,CONVERT(NVARCHAR,ISNULL(BranchID,0)),CONVERT(NVARCHAR,ISNULL(BeatID,0)),CONVERT(NVARCHAR,ISNULL(SalesmanID,0)) from tblUsers WHERE ID = @ID                      
drop table #tempinit  
END                      
IF(@MODE = 2)                      
BEGIN                      
SET @StrQuery = 'SELECT 8 Type,''Customer'' Trans,MC.ID,Code,Name FROM tblMasterCustomer MC                    
LEFT JOIN tblBeatSalesmanMapping BSM ON BSM.CustomerID = MC.ID                    
WHERE Active = 1 '                    
SET @StrQuery += CASE WHEN ISNULL(@ID,0) = 0 THEN '' ELSE ' AND BSM.BeatID =  @ID ' end                    
SET @StrQuery += CASE WHEN (ISNULL(@SMID,0) = 0 or isnull(@AllSalesman,0) = 1) THEN '' ELSE ' AND BSM.SalesmanID =  @SMID ' end                    
SET @StrQuery += ' GROUP BY MC.ID,Code,Name ORDER BY Name'                    
EXEC sys.sp_executesql @StrQuery, N'@Mode INT, @ID INT, @SMID INT, @SelectID NVARCHAR(MAX), @Value NVARCHAR(MAX)', @Mode, @ID, @SMID, @SelectID, @Value                    
END                    
IF(@MODE = 3)                      
BEGIN                      
SELECT 'CUSTOMER DETAILS'                    
END                    
IF(@MODE = 4)                      
BEGIN                     
DECLARE @tempAppID INT                    
SELECT @tempAppID = PriceTypeID FROM tblMasterCustomer WHERE ID = @ID                    
IF(ISNULL(@tempAppID,0) = 0)                    
BEGIN                    
SET @tempAppID = 2;                    
END                    
set @StrQuery = 'SELECT MP.ID,Name,                    
(CASE WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=1 THEN ''PP:'' + CAST(CAST(((MP.PurchasePrice * ISNULL(Tax.GST,0))/100) + MP.PurchasePrice AS DECIMAL(25,2)) AS NVARCHAR) + ''''                    
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=2 THEN ''SP:'' + CAST(CAST(((MP.SalesPrice * ISNULL(Tax.GST,0))/100) + MP.SalesPrice AS DECIMAL(25,2)) AS NVARCHAR) + ''''                    
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=3 THEN ''ECP:'' + CAST(CAST(((MP.ECP * ISNULL(Tax.GST,0))/100) + MP.ECP AS DECIMAL(25,2)) AS NVARCHAR) + ''''                    
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=4 THEN ''MRP:'' + CAST(CAST(MP.MRP AS DECIMAL(25,2)) AS NVARCHAR) + ''''                    
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=5 THEN ''SPL:'' + CAST(CAST(((MP.SPLPrice * ISNULL(Tax.GST,0))/100) + MP.SPLPrice AS DECIMAL(25,2)) AS NVARCHAR) + ''''                    
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=6 THEN ''RTN:'' + CAST(CAST(((MP.ReturnPrice * ISNULL(Tax.GST,0))/100) + MP.ReturnPrice AS DECIMAL(25,2)) AS NVARCHAR) + ''''                    
END) + '', MRP:'' + CAST(CAST(MP.MRP AS DECIMAL(25,2)) AS NVARCHAR) + ''''+                    
(CASE WHEN MP.TrackInventory = 0 THEN '''' ELSE '', ABS:'' + CAST(CAST(SUM(ISNULL(PV.ActualQty,0)) AS DECIMAL(25,2)) AS NVARCHAR) END)                    
AS PriceInfo,                    
 CAST((CASE WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=1 THEN CAST(((CAST(MP.PurchasePrice AS DECIMAL(25,4)) * ISNULL(Tax.GST,0))/100) + MP.PurchasePrice AS NVARCHAR)                 
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=2 THEN CAST(((CAST(MP.SalesPrice AS DECIMAL(25,4)) * ISNULL(Tax.GST,0))/100) + MP.SalesPrice AS NVARCHAR)                    
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=3 THEN CAST(((CAST(MP.ECP AS DECIMAL(25,4)) * ISNULL(Tax.GST,0))/100) + MP.ECP AS NVARCHAR)                    
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=4 THEN CAST(CAST(MP.MRP AS DECIMAL(25,4)) AS NVARCHAR)                    
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=5 THEN CAST(((CAST(MP.SPLPrice AS DECIMAL(25,4)) * ISNULL(Tax.GST,0))/100) + MP.SPLPrice AS NVARCHAR)                    
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=6 THEN CAST(((CAST(MP.ReturnPrice AS DECIMAL(25,4)) * ISNULL(Tax.GST,0))/100) + MP.ReturnPrice AS NVARCHAR)                    
END)AS DECIMAL(25,4)) AS Price,                    
CAST(CAST(ProductDiscPerc AS DECIMAL(25,4)) AS NVARCHAR) AS ProductDisc,                    
CAST(CAST(MP.MRP AS DECIMAL(25,4)) AS NVARCHAR) AS MRP,IMGD.Imagedata      
FROM tblMasterProduct MP                    
JOIN tblMasterTax AS Tax ON Tax.TaxID = SalesTaxId                    
left JOIN tblProductInventory PV ON PV.ProdId = MP.ID AND PV.BranchID =  @SMID       
LEFT JOIN tblImages IMGD ON IMGD.ID = MP.ID AND IMGD.FormID = 1      
WHERE MP.Active=1 '                    
SET @StrQuery += CASE WHEN ISNULL(@SelectID,0) = 1 and isnull(@Value,'') != '' THEN ' AND MP.MfrID IN (SELECT id FROM dbo.fnSplitString(@Value, N'',''))' ELSE '' end                    
SET @StrQuery += CASE WHEN ISNULL(@SelectID,0) = 2 and isnull(@Value,'') != '' THEN ' AND MP.CategoryID IN (SELECT id FROM dbo.fnSplitString(@Value, N'',''))' ELSE '' end                    
SET @StrQuery += CASE WHEN ISNULL(@SelectID,0) = 3 and isnull(@Value,'') != '' THEN ' AND MP.Name IN ('+' @Value '+')' ELSE '' end                    
SET @StrQuery +=  ' group by MP.PurchasePrice,MP.SalesPrice,MP.ECP,MP.MRP,MP.SPLPrice,Tax.GST,MP.ID,Name,ProductDiscPerc,                    
WebOrder,MP.TrackInventory,MP.ReturnPrice,IMGD.Imagedata ORDER BY WebOrder ASC,MP.Name ASC   '                    
EXEC sys.sp_executesql @StrQuery, N'@Mode INT, @ID INT, @SMID INT, @SelectID NVARCHAR(MAX), @Value NVARCHAR(MAX)', @Mode, @ID, @SMID, @SelectID, @Value                    
END                   
IF(@MODE = 5)-- BEAT,SALESMAN FOR CUSTOMER MAPPED                
BEGIN                  
SELECT TOP 1 BSM.BeatID,BSM.SalesmanID,BSM.CustomerID,MC.Code,MC.Name FROM tblBeatSalesmanMapping BSM                
join tblMasterCustomer MC ON MC.ID = BSM.CustomerID            
WHERE CustomerID = @ID                
ORDER BY BSM.ID                
END                
IF(@MODE = 6)-- MOB OT LIST          
BEGIN          
DECLARE @sts as table(StatusID int)            
if(isnull(@SMID,0) = 0)            
begin            
insert into @sts values(1),(3)            
end            
ELSE            
BEGIN            
insert into @sts values(1),(2),(3),(4),(8)            
END            
declare @RoleID int,@showallDataPermission int =0            
select @RoleID = RoleID from tblUsers where ID = @ID            
            
select @showallDataPermission = count(*) from tblRolePermissions  where Role =@RoleID and PermissionFormId = 466            
            
SELECT OCH.ID,FORMAT(OCH.DocDate,'dd-MMM-yyyy') DocDate,MB.Name BeatName,MS.Name SalesmanName,MC.Name CustomerName,                
dbo.fnGetRoundedValue(SUM(OCD.Amount)) Value,count(*) ItemsCount,MBO.Name BranchName,sts.Description Status,OCH.Status StatusID,                
OCH.Narration,CU.UserName,CONVERT(NVARCHAR(50),OCH.CDate) CreateDate,          
case when ActivityID = 1 then 'Order Taken' when ActivityID = 2  then 'Feedback' else 'No Order' end Activity,          
FeedBack          
FROM tblTranOrderTakenHeader OCH                
LEFT join tblTranOrderTakenDetail OCD ON OCD.ID = OCH.ID          
JOIN tblMasterCustomer MC ON MC.ID = OCH.CustID                
LEFT JOIN TBLMasterBeat MB ON MB.ID = OCH.BeatID        
LEFT JOIN tblMasterSalesman MS ON MS.ID = OCH.SalesManID                      
LEFT JOIN tblMasterBranchOffice MBO ON MBO.ID = OCH.BranchID                
join tblStatus sts ON sts.ID = OCH.Status                
JOIN tblUsers CU ON CU.ID = OCH.CBy            
WHERE((@showallDataPermission = 0 AND (OCH.CBy = @ID OR OCH.MBy = @ID)) OR (@showallDataPermission > 0))            
AND OCH.Status IN (SELECT StatusID FROM @sts)            
GROUP BY OCH.ID,OCH.DocDate,MB.Name,MS.Name,MC.Name,MBO.Name,sts.Description,OCH.Status,OCH.Narration,CU.UserName,OCH.CDate,          
ActivityID,FeedBack          
ORDER BY OCH.ID desc            
END          
IF(@Mode = 7 OR @Mode = 8)        
BEGIN        
DECLARE @CustPriceID int,@BranchID int        
select @BranchID = BranchID,@CustPriceID = MC.PriceTypeID from tblTranOrderTakenHeader OTH        
JOIN tblMasterCustomer MC ON MC.ID = OTH.CustID where OTH.ID = @ID        
        
SELECT OCH.ID,FORMAT(OCH.DocDate,'dd-MMM-yyyy') DocDate,OCH.BeatID,OCH.SalesManID,OCH.CustID CustomerID,        
MC.Name CustomerName,                
dbo.fnGetRoundedValue(SUM(OCD.Amount)) Value,count(*) ItemsCount,OCH.BranchID BranchID,sts.Description Status,OCH.Status StatusID,                
OCH.Narration,CU.UserName,CONVERT(NVARCHAR(50),OCH.CDate) CreateDate,          
ActivityID,FeedBack,isnull(TrDiscPern,0) TrDiscPern,isnull(AdDiscPern,0) AdDiscPern        
FROM tblTranOrderTakenHeader OCH                
LEFT join tblTranOrderTakenDetail OCD ON OCD.ID = OCH.ID          
JOIN tblMasterCustomer MC ON MC.ID = OCH.CustID        
join tblStatus sts ON sts.ID = OCH.Status                
JOIN tblUsers CU ON CU.ID = OCH.CBy           
WHERE OCH.ID = @ID        
GROUP BY OCH.ID,OCH.DocDate,OCH.BeatID,OCH.SalesManID,MC.Name,OCH.CustID,sts.Description,OCH.Status,OCH.Narration,CU.UserName,OCH.CDate,          
ActivityID,FeedBack,OCH.BranchID,TrDiscPern,AdDiscPern          
        
SELECT         
    MP.ID,        
    MP.Name,        
    (        
        CASE         
            WHEN @CustPriceID = 1 THEN 'PP:'  + CAST(CAST(((MP.PurchasePrice * ISNULL(Tax.GST,0))/100) + MP.PurchasePrice AS DECIMAL(25,2)) AS NVARCHAR)        
            WHEN @CustPriceID = 2 THEN 'SP:'  + CAST(CAST(((MP.SalesPrice   * ISNULL(Tax.GST,0))/100) + MP.SalesPrice   AS DECIMAL(25,2)) AS NVARCHAR)        
            WHEN @CustPriceID = 3 THEN 'ECP:' + CAST(CAST(((MP.ECP         * ISNULL(Tax.GST,0))/100) + MP.ECP         AS DECIMAL(25,2)) AS NVARCHAR)        
            WHEN @CustPriceID = 4 THEN 'MRP:' + CAST(CAST(MP.MRP AS DECIMAL(25,2)) AS NVARCHAR)        
            WHEN @CustPriceID = 5 THEN 'SPL:' + CAST(CAST(((MP.SPLPrice    * ISNULL(Tax.GST,0))/100) + MP.SPLPrice    AS DECIMAL(25,2)) AS NVARCHAR)        
            WHEN @CustPriceID = 6 THEN 'RTN:' + CAST(CAST(((MP.ReturnPrice * ISNULL(Tax.GST,0))/100) + MP.ReturnPrice AS DECIMAL(25,2)) AS NVARCHAR)        
        END        
        + ', MRP:' + CAST(CAST(MP.MRP AS DECIMAL(25,2)) AS NVARCHAR)        
        +        
        CASE         
            WHEN MP.TrackInventory = 0 THEN ''        
            ELSE ', ABS:' + CAST(CAST(SUM(ISNULL(PV.ActualQty,0)) AS DECIMAL(25,2)) AS NVARCHAR)        
        END        
    ) AS PriceDesc,        
    CAST(        
        CASE         
            WHEN @CustPriceID = 1 THEN ((MP.PurchasePrice * ISNULL(Tax.GST,0))/100) + MP.PurchasePrice        
           WHEN @CustPriceID = 2 THEN ((MP.SalesPrice   * ISNULL(Tax.GST,0))/100) + MP.SalesPrice        
            WHEN @CustPriceID = 3 THEN ((MP.ECP         * ISNULL(Tax.GST,0))/100) + MP.ECP        
            WHEN @CustPriceID = 4 THEN MP.MRP        
            WHEN @CustPriceID = 5 THEN ((MP.SPLPrice    * ISNULL(Tax.GST,0))/100) + MP.SPLPrice        
            WHEN @CustPriceID = 6 THEN ((MP.ReturnPrice * ISNULL(Tax.GST,0))/100) + MP.ReturnPrice        
        END         
    AS DECIMAL(25,4)) AS Price,        
    CAST(CAST(MP.ProductDiscPerc AS DECIMAL(25,4)) AS NVARCHAR) AS ProductDisc,        
    CAST(CAST(MP.MRP AS DECIMAL(25,4)) AS NVARCHAR) AS MRP,        
    Qty,DisPern Discount,DisAmt,Price ,OrgPrice Rate,IMGD.Imagedata         
FROM tblTranOrderTakenDetail OTD        
JOIN tblMasterProduct MP ON MP.ID = OTD.ProdID        
JOIN tblMasterTax Tax ON Tax.TaxID = MP.SalesTaxId        
LEFT JOIN tblProductInventory PV ON PV.ProdId = MP.ID AND PV.BranchID = @BranchID        
LEFT JOIN tblImages IMGD ON IMGD.ID = MP.ID AND IMGD.FormID = 1    
WHERE OTD.ID = @ID        
GROUP BY         
    MP.PurchasePrice,        
    MP.SalesPrice,        
    MP.ECP,        
    MP.MRP,        
  MP.SPLPrice,        
    Tax.GST,        
    MP.ID,        
    MP.Name,        
    MP.ProductDiscPerc,        
    MP.WebOrder,        
    MP.TrackInventory,        
    MP.ReturnPrice, Qty,DisPern,DisAmt,Price,OrgPrice,OTD.SerialNo,IMGD.Imagedata         
ORDER BY         
    OTD.SerialNo ASC,        
    MP.Name ASC;        
END        
END 
GO

/****** uspgetsetDiscountSchemeData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec [uspgetsetDiscountSchemeData] 32,112  
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspgetsetDiscountSchemeData]              
@Mode INT,@ID NVARCHAR(255) = NULL, @CustTypeorManuf nvarchar(255)='',@BeatorBrand nvarchar(255)='',@SalesmanorCategory nvarchar(255)='',              
@CustomerorProduct nvarchar(255)='' ,@nMapByID int = 1  
as              
BEGIN              
DECLARE @strQuery NVARCHAR(MAX)              
IF(@Mode = 1)              
BEGIN              
select 1 FType,'Manuf' Form,ID,Name from tblMasterManufacturer WHERE Active = 1                          
union                          
select 2 FType,'Brand' Form,ID,Name Descriptions from tblMasterBrand WHERE Active = 1                          
union                        
select 3 FType,'Category' Form,ID,Name Descriptions from tblMasterCategory WHERE Active = 1               
union                        
select 4 FType,'Product' Form,ID,Name Descriptions from tblMasterproduct WHERE Active = 1               
union              
select 5 FType,'CustomerType' Form,ID,Name Descriptions from tblMasterCustomerType WHERE Active = 1                              
union                              
select 6 FType,'Beat' Form,ID,Name from tblMasterBeat where Active = 1                              
union                              
select 7 FType,'Salesman' Form,ID,Name from tblMasterSalesman where Active = 1               
union                              
select 8 FType,'Customer' Form,ID,Name from tblMasterCustomer where Active = 1               
order by FType,Name                
END              
IF(@Mode = 2)              
BEGIN              
SELECT DH.ID,Name,(CASE WHEN isnull(IsReplace,0) = 1 THEN 'YES' ELSE 'NO' END) IsReplace,CONVERT(NVARCHAR(50),FromDate,106) FromDate,            
CONVERT(NVARCHAR(50),ToDate,106) ToDate,(CASE WHEN isnull(DH.Active,0) = 1 THEN 'YES' ELSE 'NO' END) Active,COUNT(distinct DSC.CustomerID) CustomerCount        
,COUNT(distinct ProdID) ProductCount ,CASE WHEN ISNULL(DH.MBy,0) = 0 THEN CUR.UserName ELSE MUR.UserName END  UserName,    
 CASE WHEN ISNULL(DH.MBy,0) = 0 THEN CONVERT(NVARCHAR(100),DH.CDate) ELSE CONVERT(NVARCHAR(100),DH.MDate) END LastActionTime       
FROM tblMasterDiscountSchemeHeader DH        
JOIN tblMasterDiscountSchemeDetail DD ON DD.ID = DH.ID        
JOIN tblMasterDiscountSchemeCustomers DSC ON DSC.ID = DH.ID
JOIN tblUsers CUR ON CUR.ID = DH.CBy              
LEFT JOIN tblUsers MUR ON MUR.ID = DH.MBy     
GROUP BY DH.ID,Name,IsReplace,FromDate,ToDate,DH.Active,DH.MBy  ,DH.CDate  ,DH.MDate ,CUR.UserName,MUR.UserName    
ORDER BY Name            
END              
IF(@Mode = 3)          
BEGIN          
select * from  tblMasterDiscountSchemeHeader where ID = @ID            
END          
IF(@Mode = 31)--customer by schemeid          
BEGIN          
select MDD.CustomerID CustID,MC.Code,MC.Name from tblMasterDiscountSchemeHeader MDH          
--JOIN tblMasterDiscountSchemeDetail MDD ON MDD.ID = MDH.ID          
JOIN tblMasterDiscountSchemeCustomers MDD ON MDD.ID = MDH.ID          
JOIN tblMasterCustomer MC ON MC.ID = MDD.CustomerID  
where MDH.ID = @ID          
group by  MDD.CustomerID,MC.Code,MC.Name          
END          
IF(@Mode = 32)--PRODUCT by schemeid          
BEGIN          
SET @nMapByID = (select ApplyIn from  tblMasterDiscountSchemeHeader where ID = @ID )  
print 'get item details'  
SET @strQuery = ' select MDD.ProdID,'+(CASE WHEN @nMapByID = 1 then 'MC.Code' ELSE '''''' END)+' Code,MC.Name,MDD.ProdDisc ProdDiscPern,MDD.ProdDiscAmt,MDD.TradeDiscPern,MDD.TradeDiscAmt  
from tblMasterDiscountSchemeHeader MDH          
JOIN tblMasterDiscountSchemeDetail MDD ON MDD.ID = MDH.ID '  
SET @strQuery += (CASE WHEN @nMapByID = 1 then ' JOIN tblMasterProduct MC ON MC.ID = MDD.ProdID  '   
 WHEN @nMapByID = 2 then ' JOIN tblMasterManufacturer MC ON MC.ID = MDD.ProdID  '   
 WHEN @nMapByID = 3 then ' JOIN tblMasterBrand MC ON MC.ID = MDD.ProdID  '   
 ELSE ' JOIN tblMasterCategory MC ON MC.ID = MDD.ProdID  ' END )  
SET @strQuery += '  where MDH.ID = @ID '  
SET @strQuery +=  'group by  MDD.ProdID,'+(CASE WHEN @nMapByID = 1 then 'MC.Code,' ELSE '' END)+' MC.Name,MDD.ProdDisc,MDD.ProdDiscAmt,  
MDD.TradeDiscPern,MDD.TradeDiscAmt    '  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID NVARCHAR(255), @CustTypeorManuf nvarchar(255), @BeatorBrand nvarchar(255), @SalesmanorCategory nvarchar(255), @CustomerorProduct nvarchar(255), @nMapByID int', @Mode, @ID, @CustTypeorManuf, @BeatorBrand, @SalesmanorCategory, @CustomerorProduct, @nMapByID       
END          
IF(@Mode = 4)              
BEGIN              
IF(ISNULL(@ID,1) = 1)--CUSTOMER FILTER              
BEGIN              
SET @strQuery = ' SELECT MC.ID,MC.Code,MC.Name FROM tblMasterCustomer MC              
LEFT JOIN tblMasterCustomerType MCT ON MCT.ID = MC.CustomerType              
LEFT JOIN tblBeatSalesmanMapping BSM ON BSM.CustomerID=MC.ID              
LEFT JOIN tblMasterBeat MB ON MB.ID = BSM.BeatID              
LEFT JOIN tblMasterSalesman SM ON SM.ID = BSM.SalesmanID WHERE MC.Active = 1 '              
SET @strQuery += CASE WHEN ISNULL(@CustTypeorManuf,'') = '' THEN '' ELSE ' AND MCT.Name = '+' @CustTypeorManuf ' end              
SET @strQuery += CASE WHEN ISNULL(@BeatorBrand,'') = '' THEN '' ELSE ' AND MB.Name = '+' @BeatorBrand ' end              
SET @strQuery += CASE WHEN ISNULL(@SalesmanorCategory,'') = '' THEN '' ELSE ' AND SM.Name = '+' @SalesmanorCategory ' end              
SET @strQuery += CASE WHEN ISNULL(@CustomerorProduct,'') = '' THEN '' ELSE ' AND MC.Name = '+' @CustomerorProduct ' end              
SET @strQuery += ' GROUP BY  MC.ID,MC.Code,MC.Name ORDER BY MC.Name'              
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID NVARCHAR(255), @CustTypeorManuf nvarchar(255), @BeatorBrand nvarchar(255), @SalesmanorCategory nvarchar(255), @CustomerorProduct nvarchar(255), @nMapByID int', @Mode, @ID, @CustTypeorManuf, @BeatorBrand, @SalesmanorCategory, @CustomerorProduct, @nMapByID              
END              
ELSE -- PRODUCT FILTER              
BEGIN              
if(@nMapByID = 1)  
BEGIN  
SET @strQuery = ' SELECT MP.ID,MP.Code,MP.Name,0 ProdDiscPern,0 ProdDiscAmt,0 TradeDiscPern,0 TradeDiscAmt FROM TBLMASTERPRODUCT MP              
LEFT JOIN tblMasterManufacturer MF ON MF.ID = MP.MfrID              
LEFT JOIN tblMasterCategory MC ON MC.ID = MP.CategoryID              
LEFT JOIN tblMasterBrand MB ON Mb.ID = MP.BrandID WHERE MP.Active = 1 '              
SET @strQuery += CASE WHEN ISNULL(@CustTypeorManuf,'') = '' THEN '' ELSE ' AND MF.Name = '+' @CustTypeorManuf ' end              
SET @strQuery += CASE WHEN ISNULL(@BeatorBrand,'') = '' THEN '' ELSE ' AND MB.Name = '+' @BeatorBrand ' end              
SET @strQuery += CASE WHEN ISNULL(@SalesmanorCategory,'') = '' THEN '' ELSE ' AND MC.Name = '+' @SalesmanorCategory ' end              
SET @strQuery += CASE WHEN ISNULL(@CustomerorProduct,'') = '' THEN '' ELSE ' AND MP.Name = '+' @CustomerorProduct ' end              
SET @strQuery += ' GROUP BY   MP.ID,MP.Code,MP.Name ORDER BY MP.Name'              
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID NVARCHAR(255), @CustTypeorManuf nvarchar(255), @BeatorBrand nvarchar(255), @SalesmanorCategory nvarchar(255), @CustomerorProduct nvarchar(255), @nMapByID int', @Mode, @ID, @CustTypeorManuf, @BeatorBrand, @SalesmanorCategory, @CustomerorProduct, @nMapByID                 
END  
ELSE  
BEGIN  
SET @strQuery = ' SELECT ID,null Code,Name,0 ProdDiscPern,0 ProdDiscAmt,0 TradeDiscPern,0 TradeDiscAmt FROM '  
SET @strQuery += CASE WHEN @nMapByID = 2 THEN 'tblMasterManufacturer' WHEN @nMapByID = 3 THEN 'tblMasterBrand'  
 ELSE 'tblMasterCategory' end              
SET @strQuery += '  WHERE Active = 1 order by Name'  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID NVARCHAR(255), @CustTypeorManuf nvarchar(255), @BeatorBrand nvarchar(255), @SalesmanorCategory nvarchar(255), @CustomerorProduct nvarchar(255), @nMapByID int', @Mode, @ID, @CustTypeorManuf, @BeatorBrand, @SalesmanorCategory, @CustomerorProduct, @nMapByID          
END  
END              
END              
END 
GO

/****** uspGetsetMobileSRDRData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--uspGetsetMobileSRDRData 6,1,1,0    
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetsetMobileSRDRData]    
@Mode INT,@TransType int = 0,@ID INT = 2,@SMID INT = NULL,@SelectID NVARCHAR(MAX) = null,@Value NVARCHAR(MAX) = NULL    
as    
begin    
DECLARE @StrQuery NVARCHAR(MAX) = '',@AllSalesman INT = (SELECT AppValue FROM tblAppConfig WHERE AppId = 18)          
    
IF(@MODE = 1)    
BEGIN    
select 1 Type,'Salesman' Trans,ID,'' Code,Name from tblMasterSalesman where Active = 1 order by Name    
    
SELECT 2 Type,'Beat' Trans,ID,'',Name FROM tblMasterBeat WHERE Active = 1 order by Name    
    
SELECT 3 Type,'Manuf' Trans,ID value,'',Name label FROM tblMasterManufacturer WHERE Active = 1 order by Name    
    
SELECT 4 Type,'Category' Trans,ID value,'' Code,Name label FROM tblMasterCategory WHERE Active = 1 order by Name    
    
SELECT 5 Type,'Product' Trans,ID value,Code,Name label FROM tblMasterProduct WHERE Active = 1 order by Name    
    
SELECT 6 Type,'Branch' Trans,ID,Code,Name FROM tblMasterBranchOffice WHERE Active = 1 order by Name    
    
select 7 Type,'Today Route' Trans,CONVERT(NVARCHAR,ISNULL(BranchID,0)) BranchID,CONVERT(NVARCHAR,ISNULL(BeatID,0)) BeatID,    
CONVERT(NVARCHAR,ISNULL(SalesmanID,0)) SalesmanID    
from tblUsers WHERE ID = @ID    
end    
IF(@MODE = 2)                    
BEGIN                    
SET @StrQuery = 'SELECT MC.ID value,Code,Name label FROM tblMasterCustomer MC                  
LEFT JOIN tblBeatSalesmanMapping BSM ON BSM.CustomerID = MC.ID                  
WHERE Active = 1 '                  
SET @StrQuery += CASE WHEN ISNULL(@ID,0) = 0 THEN '' ELSE ' AND BSM.BeatID =  @ID ' end                  
SET @StrQuery += CASE WHEN (ISNULL(@SMID,0) = 0 or isnull(@AllSalesman,0) = 1) THEN '' ELSE ' AND BSM.SalesmanID =  @SMID ' end                  
SET @StrQuery += ' GROUP BY MC.ID,Code,Name ORDER BY Name'                  
EXEC sys.sp_executesql @StrQuery, N'@Mode INT, @TransType int, @ID INT, @SMID INT, @SelectID NVARCHAR(MAX), @Value NVARCHAR(MAX)', @Mode, @TransType, @ID, @SMID, @SelectID, @Value                  
END      
IF(@MODE = 3)    
BEGIN                   
DECLARE @tempAppID INT                  
SELECT @tempAppID = PriceTypeID FROM tblMasterCustomer WHERE ID = @ID                  
IF(ISNULL(@tempAppID,0) = 0)                  
BEGIN                  
SET @tempAppID = 2;                  
END                  
set @StrQuery = 'SELECT MP.ID,Name,                  
(CASE WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=1 THEN ''PP:'' + CAST(CAST(((MP.PurchasePrice * ISNULL(Tax.GST,0))/100) + MP.PurchasePrice AS DECIMAL(25,2)) AS NVARCHAR) + ''''                  
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=2 THEN ''SP:'' + CAST(CAST(((MP.SalesPrice * ISNULL(Tax.GST,0))/100) + MP.SalesPrice AS DECIMAL(25,2)) AS NVARCHAR) + ''''                  
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=3 THEN ''ECP:'' + CAST(CAST(((MP.ECP * ISNULL(Tax.GST,0))/100) + MP.ECP AS DECIMAL(25,2)) AS NVARCHAR) + ''''                  
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=4 THEN ''MRP:'' + CAST(CAST(MP.MRP AS DECIMAL(25,2)) AS NVARCHAR) + ''''                  
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=5 THEN ''SPL:'' + CAST(CAST(((MP.SPLPrice * ISNULL(Tax.GST,0))/100) + MP.SPLPrice AS DECIMAL(25,2)) AS NVARCHAR) + ''''                  
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=6 THEN ''RTN:'' + CAST(CAST(((MP.ReturnPrice * ISNULL(Tax.GST,0))/100) + MP.ReturnPrice AS DECIMAL(25,2)) AS NVARCHAR) + ''''                  
END) + '', MRP:'' + CAST(CAST(MP.MRP AS DECIMAL(25,2)) AS NVARCHAR) + ''''+                  
(CASE WHEN MP.TrackInventory = 0 THEN '''' ELSE '', ABS:'' + CAST(CAST(SUM(ISNULL('+(case when @TransType = 2 then 'PV.ActualDmgQty' else 'PV.ActualQty' end)+',0)) AS DECIMAL(25,2)) AS NVARCHAR) END)                  
AS PriceInfo,                  
 CAST((CASE WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=1 THEN CAST(((CAST(MP.PurchasePrice AS DECIMAL(25,4)) * ISNULL(Tax.GST,0))/100) + MP.PurchasePrice AS NVARCHAR)               
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=2 THEN CAST(((CAST(MP.SalesPrice AS DECIMAL(25,4)) * ISNULL(Tax.GST,0))/100) + MP.SalesPrice AS NVARCHAR)                  
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=3 THEN CAST(((CAST(MP.ECP AS DECIMAL(25,4)) * ISNULL(Tax.GST,0))/100) + MP.ECP AS NVARCHAR)        
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=4 THEN CAST(CAST(MP.MRP AS DECIMAL(25,4)) AS NVARCHAR)                  
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=5 THEN CAST(((CAST(MP.SPLPrice AS DECIMAL(25,4)) * ISNULL(Tax.GST,0))/100) + MP.SPLPrice AS NVARCHAR)                  
WHEN ' + CAST(@tempAppID AS NVARCHAR)+'=6 THEN CAST(((CAST(MP.ReturnPrice AS DECIMAL(25,4)) * ISNULL(Tax.GST,0))/100) + MP.ReturnPrice AS NVARCHAR)                  
END)AS DECIMAL(25,4)) AS Price,                  
CAST(CAST(ProductDiscPerc AS DECIMAL(25,4)) AS NVARCHAR) AS ProductDisc,                  
CAST(CAST(MP.MRP AS DECIMAL(25,4)) AS NVARCHAR) AS MRP                  
FROM tblMasterProduct MP                  
JOIN tblMasterTax AS Tax ON Tax.TaxID = SalesTaxId                  
left JOIN tblProductInventory PV ON PV.ProdId = MP.ID AND PV.BranchID =  @SMID                   
WHERE MP.Active = 1 '                  
SET @StrQuery += CASE WHEN ISNULL(@SelectID,0) = 1 and isnull(@Value,'') != '' THEN ' AND MP.MfrID IN (SELECT id FROM dbo.fnSplitString(@Value, N'',''))' ELSE '' end                  
SET @StrQuery += CASE WHEN ISNULL(@SelectID,0) = 2 and isnull(@Value,'') != '' THEN ' AND MP.CategoryID IN (SELECT id FROM dbo.fnSplitString(@Value, N'',''))' ELSE '' end                  
SET @StrQuery += CASE WHEN ISNULL(@SelectID,0) = 3 and isnull(@Value,'') != '' THEN ' AND MP.Name IN ('+' @Value '+')' ELSE '' end                  
SET @StrQuery +=  ' group by MP.PurchasePrice,MP.SalesPrice,MP.ECP,MP.MRP,MP.SPLPrice,Tax.GST,MP.ID,Name,ProductDiscPerc,                  
WebOrder,MP.TrackInventory,MP.ReturnPrice ORDER BY WebOrder ASC,MP.Name ASC   '                  
EXEC sys.sp_executesql @StrQuery, N'@Mode INT, @TransType int, @ID INT, @SMID INT, @SelectID NVARCHAR(MAX), @Value NVARCHAR(MAX)', @Mode, @TransType, @ID, @SMID, @SelectID, @Value                  
END    
IF(@Mode = 4)  
BEGIN  
SELECT TOP 1 BSM.BeatID,BSM.SalesmanID,BSM.CustomerID,MC.Code,MC.Name FROM tblBeatSalesmanMapping BSM            
join tblMasterCustomer MC ON MC.ID = BSM.CustomerID        
WHERE CustomerID = @ID            
ORDER BY BSM.ID    
  
SELECT * FROM tblMasterCustomer WHERE ID = @ID     
  
END  
IF(@MODE = 5)-- MOB OT LIST        
BEGIN        
DECLARE @sts as table(StatusID int)          
if(isnull(@SMID,0) = 0)          
begin          
insert into @sts values(1),(3)          
end          
ELSE          
BEGIN          
insert into @sts values(1),(2),(3),(4),(8)          
END          
declare @RoleID int,@showallDataPermission int =0          
select @RoleID = RoleID from tblUsers where ID = @ID          
          
select @showallDataPermission = count(*) from tblRolePermissions  where Role =@RoleID and PermissionFormId = 466          
          
SELECT OCH.ID,FORMAT(OCH.DocDate,'dd-MMM-yyyy') DocDate,MB.Name BeatName,MS.Name SalesmanName,MC.Name CustomerName,              
dbo.fnGetRoundedValue(SUM(OCD.Amount)) Value,count(*) ItemsCount,MBO.Name BranchName,sts.Description Status,OCH.Status StatusID,              
OCH.Narration,CU.UserName,CONVERT(NVARCHAR(50),OCH.CDate) CreateDate    
     
FROM tblTranOrderReturnHeader OCH              
LEFT join tblTranOrderReturnDetail OCD ON OCD.ID = OCH.ID        
JOIN tblMasterCustomer MC ON MC.ID = OCH.CustID              
LEFT JOIN TBLMasterBeat MB ON MB.ID = OCH.BeatID      
LEFT JOIN tblMasterSalesman MS ON MS.ID = OCH.SalesManID                    
LEFT JOIN tblMasterBranchOffice MBO ON MBO.ID = OCH.BranchID              
join tblStatus sts ON sts.ID = OCH.Status              
JOIN tblUsers CU ON CU.ID = OCH.CBy          
WHERE ReturnTransType = @TransType and ((@showallDataPermission = 0 AND (OCH.CBy = @ID OR OCH.MBy = @ID)) OR (@showallDataPermission > 0))          
AND OCH.Status IN (SELECT StatusID FROM @sts)          
GROUP BY OCH.ID,OCH.DocDate,MB.Name,MS.Name,MC.Name,MBO.Name,sts.Description,OCH.Status,OCH.Narration,CU.UserName,OCH.CDate       
ORDER BY OCH.ID desc          
END        
IF(@Mode = 6)-- sr data  
BEGIN    
DECLARE @CustPriceID int,@BranchID int    
select @BranchID = BranchID,@CustPriceID = MC.PriceTypeID from tblTranOrderReturnHeader OTH    
JOIN tblMasterCustomer MC ON MC.ID = OTH.CustID where OTH.ID = @ID    
    
SELECT OCH.ID,FORMAT(OCH.DocDate,'dd-MMM-yyyy') DocDate,OCH.BeatID,OCH.SalesManID,OCH.CustID CustomerID,    
MC.Name CustomerName,            
dbo.fnGetRoundedValue(SUM(OCD.Amount)) Value,count(*) ItemsCount,OCH.BranchID BranchID,sts.Description Status,OCH.Status StatusID,            
OCH.Narration,CU.UserName,CONVERT(NVARCHAR(50),OCH.CDate) CreateDate,      
isnull(TrDiscPern,0) TrDiscPern,isnull(AdDiscPern,0) AdDiscPern    
FROM tblTranOrderReturnHeader OCH            
LEFT join tblTranOrderReturnDetail OCD ON OCD.ID = OCH.ID      
JOIN tblMasterCustomer MC ON MC.ID = OCH.CustID    
join tblStatus sts ON sts.ID = OCH.Status            
JOIN tblUsers CU ON CU.ID = OCH.CBy       
WHERE OCH.ID = @ID    
GROUP BY OCH.ID,OCH.DocDate,OCH.BeatID,OCH.SalesManID,MC.Name,OCH.CustID,sts.Description,OCH.Status,OCH.Narration,CU.UserName,OCH.CDate,      
OCH.BranchID,TrDiscPern,AdDiscPern      
    
SELECT     
    MP.ID,    
    MP.Name,    
    (    
        CASE     
            WHEN @CustPriceID = 1 THEN 'PP:'  + CAST(CAST(((MP.PurchasePrice * ISNULL(Tax.GST,0))/100) + MP.PurchasePrice AS DECIMAL(25,2)) AS NVARCHAR)    
            WHEN @CustPriceID = 2 THEN 'SP:'  + CAST(CAST(((MP.SalesPrice   * ISNULL(Tax.GST,0))/100) + MP.SalesPrice   AS DECIMAL(25,2)) AS NVARCHAR)    
            WHEN @CustPriceID = 3 THEN 'ECP:' + CAST(CAST(((MP.ECP         * ISNULL(Tax.GST,0))/100) + MP.ECP         AS DECIMAL(25,2)) AS NVARCHAR)    
            WHEN @CustPriceID = 4 THEN 'MRP:' + CAST(CAST(MP.MRP AS DECIMAL(25,2)) AS NVARCHAR)    
            WHEN @CustPriceID = 5 THEN 'SPL:' + CAST(CAST(((MP.SPLPrice    * ISNULL(Tax.GST,0))/100) + MP.SPLPrice    AS DECIMAL(25,2)) AS NVARCHAR)    
            WHEN @CustPriceID = 6 THEN 'RTN:' + CAST(CAST(((MP.ReturnPrice * ISNULL(Tax.GST,0))/100) + MP.ReturnPrice AS DECIMAL(25,2)) AS NVARCHAR)    
        END    
        + ', MRP:' + CAST(CAST(MP.MRP AS DECIMAL(25,2)) AS NVARCHAR)    
        +    
        CASE     
            WHEN MP.TrackInventory = 0 THEN ''    
            ELSE ', ABS:' + CAST(CAST(SUM(ISNULL(PV.ActualQty,0)) AS DECIMAL(25,2)) AS NVARCHAR)    
        END    
    ) AS PriceDesc,    
    CAST(    
        CASE     
            WHEN @CustPriceID = 1 THEN ((MP.PurchasePrice * ISNULL(Tax.GST,0))/100) + MP.PurchasePrice    
            WHEN @CustPriceID = 2 THEN ((MP.SalesPrice   * ISNULL(Tax.GST,0))/100) + MP.SalesPrice    
            WHEN @CustPriceID = 3 THEN ((MP.ECP         * ISNULL(Tax.GST,0))/100) + MP.ECP    
            WHEN @CustPriceID = 4 THEN MP.MRP    
            WHEN @CustPriceID = 5 THEN ((MP.SPLPrice    * ISNULL(Tax.GST,0))/100) + MP.SPLPrice    
            WHEN @CustPriceID = 6 THEN ((MP.ReturnPrice * ISNULL(Tax.GST,0))/100) + MP.ReturnPrice    
        END     
    AS DECIMAL(25,4)) AS Price,    
    CAST(CAST(MP.ProductDiscPerc AS DECIMAL(25,4)) AS NVARCHAR) AS ProductDisc,    
    CAST(CAST(OTD.MRP AS DECIMAL(25,4)) AS NVARCHAR) AS MRP,    
    Qty,DisPern Discount,DisAmt,Price ,OrgPrice Rate    
FROM tblTranOrderReturnDetail OTD    
JOIN tblMasterProduct MP ON MP.ID = OTD.ProdID    
JOIN tblMasterTax Tax ON Tax.TaxID = MP.SalesTaxId    
LEFT JOIN tblProductInventory PV ON PV.ProdId = MP.ID AND PV.BranchID = @BranchID    
WHERE OTD.ID = @ID    
GROUP BY     
    MP.PurchasePrice,    
    MP.SalesPrice,    
    MP.ECP,    
    MP.MRP,
    OTD.MRP,    
    MP.SPLPrice,    
    Tax.GST,    
    MP.ID,    
    MP.Name,    
    MP.ProductDiscPerc,    
    MP.WebOrder,    
    MP.TrackInventory,    
    MP.ReturnPrice, Qty,DisPern,DisAmt,Price,OrgPrice,OTD.SerialNo    
ORDER BY     
    OTD.SerialNo ASC,    
    MP.Name ASC;    
END    
end
GO

/****** uspGetSinglemasterdata ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSinglemasterdata]
@FormID int
as
begin
declare @TableName nvarchar(255) = (select TableName from tblTablesNames where ID = @FormID)                
declare @SafeTable NVARCHAR(600) = CASE WHEN OBJECT_ID(@TableName, 'U') IS NOT NULL THEN QUOTENAME(OBJECT_SCHEMA_NAME(OBJECT_ID(@TableName, 'U'))) + '.' + QUOTENAME(OBJECT_NAME(OBJECT_ID(@TableName, 'U'))) END
IF @SafeTable IS NULL AND @TableName IS NOT NULL BEGIN RAISERROR('Master table for this form was not found.', 16, 1); RETURN; END
declare @strQuery NVARCHAR(MAX)
SET @strQuery = ' SELECT * FROM '+@SafeTable+' WHERE Active = 1 ORDER BY [Name]'
EXEC sys.sp_executesql @strQuery, N'@FormID int', @FormID  
end
GO

/****** uspGetStockAgeingHeader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetStockAgeingHeader]        
@BranchName int = 0,@ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',@ProductName NVARCHAR(255)=''        
as        
begin        
DECLARE @query NVARCHAR(MAX)        
set @query = '        
SELECT Inv.ProdId ProductID,MBR.Name [Branch Name],pa.Code as [Product Code],pa.Name as [Product Name],pa.EAN as EAN,MM.Name as [Mfr Name],              
MB.Name as [Brand Name],MC.Name as [Category Name],FORMAT(Inv.TransDate,''dd-MMM-yyyy'')AS [Transaction Date],              
DATEDIFF(day,Inv.TransDate,GETDATE())AS [Stock Ageing],              
[dbo].fnGetRoundedvalue(SUM(Inv.ActualQty) + 
SUM(isnull(VLD.UomQty,0)- isnull(VLD.VLSMQty,0) + isnull(VLD.VLSRetrunQty,0))) AS [Actual Qty],
[dbo].fnGetRoundedvalue((SUM(Inv.Purchaseprice * (Inv.ActualQty))) + 
(sum(Inv.ActualQty) * SUM(isnull(VLD.UomQty,0)- isnull(VLD.VLSMQty,0) + isnull(VLD.VLSRetrunQty,0))))AS [Stock Value]
FROM tblProductInventory Inv              
LEFT JOIN tblMasterProduct pa ON pa.ID = Inv.ProdId              
LEFT JOIN tblMasterBranchOffice MBR ON MBR.ID = Inv.BranchID          
JOIN tblMasterManufacturer MM on MM.ID=pa.MfrID              
join tblMasterBrand MB on MB.ID=pa.BrandID              
JOIN TBLMASTERCATEGORY AS MC ON MC.ID = pa.CategoryID      
LEFT JOIN tblVanLoadingSlipDetail VLD ON VLD.InventoryID = Inv.InventoryId  
WHERE Inv.ActualQty > 0 '        
 set @query += case when ISNULL(@BranchName,'') = '' then '' else ' AND Inv.BranchID = '+' @BranchName '+'' END          
 set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND MB.ID IN (SELECT * from dbo.fnSplitString( '+' @BrandName ,'',''))' END          
 set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND MC.ID IN (SELECT * from dbo.fnSplitString( '+' @CategoryName ,'',''))' END          
 set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND MM.ID IN (SELECT * from dbo.fnSplitString( '+' @ManufName ,'',''))' END          
 set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND pa.ID IN (SELECT * from dbo.fnSplitString( '+' @ProductName ,'',''))' END          
 set @query += ' GROUP BY  pa.Code,pa.Name,pa.EAN,MM.Name,MB.Name,MC.Name,Inv.TransDate,Inv.ProdId,MBR.Name
 order by pa.Name'       

 EXEC sys.sp_executesql @query, N'@BranchName int, @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255)', @BranchName, @ManufName, @BrandName, @CategoryName, @ProductName        
end 
GO

/****** uspInActiveCustomerHeader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspInActiveCustomerHeader]    
@BeatName NVARCHAR(255) = '',@SalesmanName NVARCHAR(255) = '',@CustomerName NVARCHAR(255) = '',@CustomerType NVARCHAR(255) = '',@Ratings NVARCHAR(255)='',  
@Value INT = 2140,@FromDate DATE = '2025-08-01',@ToDate DATE = '2025-08-30'  
as    
begin      
declare @StrQuery NVARCHAR(MAX)     
select distinct nk.ID,isnull(nk.BeatId,0) as BeatId,isnull(nk.SalesmanId,0) as SalesmanId, 
cust.CustomerType as CustomerTypeId, cust.Rating as RatingId,
cust.Code as [Customer Code],cust.Name as [Customer Name],(b.Name) as [Beat Name],(s.Name) as [SalesMan Name],CT.NAME [Customer Type],RT.RatingName [Rating],       
cust.Ph1 as [Phone Number],cust.Mob1 as [Mobile Number],CUST.FAID AS AccountID,        
Net as [Net Amount],        
lsttrndate as [Last Trans Date] INTO #TEMP        
from            
(            
select  cust.ID,cbs.BeatId,cbs.SalesmanId,NULL  AS [Net],null as [lsttrndate]        
from tblMasterCustomer as cust            
left join tblBeatSalesmanMapping as cbs on cbs.CustomerId = cust.ID            
UNION ALL            
select tsh.CustId as custId,BeatID as BeatId,SalesManId as SalesmanId,isnull(sum(NetAmt),0) AS [Net],MAX(InvDate) as [lsttrndate]        
from tblTranSalesHeader TSH        
RIGHT JOIN tblMasterCustomer MC ON TSH.CustId = MC.ID         
where Status in (1,3,5) and DocPrefix=15 AND InvDate BETWEEN @FromDate AND @ToDate        
group by  TSH.CustId,BeatID,SalesManId            
) as nk            
left join tblMasterCustomer as cust on cust.ID = nk.ID            
left join tblMasterBeat as b on b.ID = nk.BeatId            
left join tblMasterSalesMan as s on s.ID = nk.SalesmanId     
left join tblMasterCustomerType CT ON CT.ID = cust.CustomerType  
left join tblRatings RT ON RT.ID = cust.Rating  
order by cust.Name         
select ID,BeatId,SalesmanId,CustomerTypeId, RatingId,[Customer Code],[Customer Name],[Beat Name],[SalesMan Name],[Customer Type],[Rating],[Phone Number],        
[Mobile Number],AccountID,ISNULL(sum([Net Amount]),0) as [Net Amount],FORMAT(MAX([Last Trans Date]),'dd-MMM-yyyy') as [Last Trans Date]        
 INTO #MainTemp from #TEMP        
group by ID,BeatId,SalesmanId,CustomerTypeId, RatingId,[Customer Code],[Customer Name],[Beat Name],[SalesMan Name],[Phone Number],        
[Mobile Number],AccountID,[Customer Type],[Rating]         
set @StrQuery = 'SELECT [Customer Code] ,[Customer Name] ,[Beat Name] ,          
[SalesMan Name] ,[Customer Type],[Rating],[Phone Number] AS [Primary Phone No],[Mobile Number] AS [Primary Mob No] ,          
dbo.fnGetRoundedValue([Net Amount]) as [Doc Value],dbo.fnGetRoundedValue(DBO.fnGetClosingBal(AccountID)) as [Closing Balance],          
[Last Trans Date] FROM #MainTemp   
WHERE [Net Amount] <=  @Value '    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND ID IN (SELECT * from dbo.fnSplitString(  @CustomerName ,'',''))' END)                    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND BeatId IN (SELECT * from dbo.fnSplitString(  @BeatName ,'',''))' END)        
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SalesmanId IN (SELECT * from dbo.fnSplitString(  @SalesmanName ,'',''))' END)     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND CustomerTypeId IN (SELECT * from dbo.fnSplitString(  @CustomerType ,'',''))' END)        
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RatingId IN(SELECT * from  dbo.fnSplitString(  @Ratings ,'',''))' END)     
SET @StrQuery = @StrQuery + ' ORDER BY [Net Amount] DESC'      
EXEC sys.sp_executesql @StrQuery, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @Value INT, @FromDate DATE, @ToDate DATE', @BeatName, @SalesmanName, @CustomerName, @CustomerType, @Ratings, @Value, @FromDate, @ToDate     
DROP TABLE #TEMP,#MainTemp  
end
GO

/****** uspLoadDeliveryDocumentData_new ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspLoadDeliveryDocumentData_new]          
@Branch INT = 4,@nMode INT = 1,@DOID INT = 0 ,@CustID NVARCHAR(255)='', @BeatID NVARCHAR(255)='',@SalesManID NVARCHAR(255)='',          
@FromDate DATE = NULL,@ToDate DATE = NULL ,@InclDoc INT = 0,        
@DocID NVARCHAR(MAX) = NULL         
AS          
BEGIN          
CREATE table #DeliProcs1(InvIdentID INT,IsMods INT)          
CREATE table #DeliProcs(InvIdentID INT,IsMods INT)          
INSERT INTO #DeliProcs1          
select DD.InvIdentID,1 from tblDeliveryOrderHeader DH          
JOIN tblDeliveryOrderDetail DD ON DD.DOID = DH.ID          
JOIN tblTranSalesHeader DSH ON DSH.ID = DD.InvIdentID          
WHERE DD.Status in (1,5) AND DH.Status IN (1,3,5) group by DD.InvIdentID          
IF(@nMode = 4)          
BEGIN          
INSERT INTO #DeliProcs1          
SELECT InvIdentID,2 FROM tblDeliveryOrderDetail WHERE DOID = @DOID          
GROUP BY InvIdentID          
END          
INSERT INTO #DeliProcs          
SELECT InvIdentID,MAX(IsMods) FROM #DeliProcs1 GROUP BY InvIdentID          
DECLARE @StrQuery NVARCHAR(MAX)          
IF(ISNULL(@InclDoc,0) = 0)          
BEGIN          
set @StrQuery = 'SELECT SH.ID,SH.Status Status,DocId,CONVERT(NVARCHAR,InvDate,103) InvDate,DocRef,MC.Name,          
MB.Name BeatName,MB.Name SalesmanName,          
dbo.fnGetRoundedValue(SH.NetAmt) NetAmt,ISNULL(DP.IsMods,1) IsMods          
FROM tblTranSalesHeader SH          
JOIN tblMasterCustomer MC ON MC.Id = SH.CustId          
LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatID          
LEFT JOIN tblMasterSalesman SM ON SM.ID = SH.SalesmanID          
LEFT JOIN #DeliProcs DP on DP.InvIdentID = SH.ID AND DP.IsMods = 2          
WHERE DocPrefix = 15 AND STATUS IN (1,3,5) AND SH.BranchID =  @Branch '          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+' @FromDate ' +' AND ' +' @ToDate ' +'' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocID,'')='' THEN '' ELSE ' AND SH.DocValue in (SELECT id FROM dbo.fnSplitString(@DocID, N'',''))' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustID,'')='' THEN '' ELSE ' AND SH.CustId in (SELECT id FROM dbo.fnSplitString(@CustID, N'',''))' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatID,'')='' THEN '' ELSE ' AND SH.BeatID in (SELECT id FROM dbo.fnSplitString(@BeatID, N'',''))' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesManID,'')='' THEN '' ELSE ' AND SH.SalesmanID in (SELECT id FROM dbo.fnSplitString(@SalesManID, N'',''))' END)          
SET @StrQuery = @StrQuery + ' AND SH.ID NOT IN (SELECT InvIdentID FROM #DeliProcs WHERE IsMods = 1)'          
SET @StrQuery = @StrQuery + ' ORDER BY DocId,ID'          
EXEC sys.sp_executesql @StrQuery, N'@Branch INT, @nMode INT, @DOID INT, @CustID NVARCHAR(255), @BeatID NVARCHAR(255), @SalesManID NVARCHAR(255), @FromDate DATE, @ToDate DATE, @InclDoc INT, @DocID NVARCHAR(MAX)', @Branch, @nMode, @DOID, @CustID, @BeatID, @SalesManID, @FromDate, @ToDate, @InclDoc, @DocID          
END          
ELSE          
BEGIN          
set @StrQuery = 'SELECT * FROM (SELECT SH.ID,SH.Status Status,DocId,CONVERT(NVARCHAR,InvDate,103) InvDate,DocRef,MC.Name,          
dbo.fnGetRoundedValue(SH.NetAmt) NetAmt,ISNULL(DP.IsMods,1) IsMods FROM tblTranSalesHeader SH          
JOIN tblMasterCustomer MC ON MC.ID = SH.CustId          
LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatID          
LEFT JOIN tblMasterSalesman SM ON SM.ID = SH.SalesmanID          
LEFT JOIN #DeliProcs DP on DP.InvIdentID = SH.ID AND DP.IsMods = 2          
WHERE DocPrefix = 15 AND STATUS IN (1,3) AND SH.BranchID =  @Branch ' -- AND SH.InvDate BETWEEN @FromDate AND @ToDate          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+' @FromDate ' +' AND ' +' @ToDate ' +'' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustID,'')='' THEN '' ELSE ' AND SH.CustId in (SELECT id FROM dbo.fnSplitString(@CustID, N'',''))' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatID,'')='' THEN '' ELSE ' AND SH.BeatID in (SELECT id FROM dbo.fnSplitString(@BeatID, N'',''))' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesManID,'')='' THEN '' ELSE ' AND SH.SalesmanID in (SELECT id FROM dbo.fnSplitString(@SalesManID, N'',''))' END)          
SET @StrQuery = @StrQuery + ' AND SH.ID NOT IN (SELECT InvIdentID FROM #DeliProcs WHERE IsMods = 1)'          
SET @StrQuery = @StrQuery + ' union '          
set @StrQuery = @StrQuery + 'SELECT InvId,SH.Status,DocId,CONVERT(NVARCHAR,InvDate,103) InvDate,DocRef,MC.Name,          
dbo.fnGetRoundedValue(SH.NetAmt) NetAmt,ISNULL(DP.IsMods,1) IsMods FROM tblTranSalesHeader SH          
JOIN tblMasterCustomer MC ON MC.ID = SH.CustId          
LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatID          
LEFT JOIN tblMasterSalesman SM ON SM.ID = SH.SalesmanID          
LEFT JOIN #DeliProcs DP on DP.InvIdentID = SH.ID AND DP.IsMods = 2          
WHERE DocPrefix = 15 AND STATUS IN (1,3) AND SH.BranchID =  @Branch ' -- AND SH.InvDate BETWEEN @FromDate AND @ToDate          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+' @FromDate ' +' AND ' +' @ToDate ' +'' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocID,'')='' THEN '' ELSE ' AND SH.DocValue in (SELECT id FROM dbo.fnSplitString(@DocID, N'',''))' END)          
SET @StrQuery = @StrQuery + ' AND SH.ID NOT IN (SELECT InvIdentID FROM #DeliProcs WHERE IsMods = 1)) AS REC'          
SET @StrQuery = @StrQuery + ' ORDER BY DocId,Id'          
EXEC sys.sp_executesql @StrQuery, N'@Branch INT, @nMode INT, @DOID INT, @CustID NVARCHAR(255), @BeatID NVARCHAR(255), @SalesManID NVARCHAR(255), @FromDate DATE, @ToDate DATE, @InclDoc INT, @DocID NVARCHAR(MAX)', @Branch, @nMode, @DOID, @CustID, @BeatID, @SalesManID, @FromDate, @ToDate, @InclDoc, @DocID          
          
END          
drop table #DeliProcs,#DeliProcs1          
END
GO

/****** uspManageSingleMaster ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec uspManageSingleMaster 1,3,2,'AXIS BANK PVT LTD',1,3                        
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspManageSingleMaster]                    
@FormID int,@Mode int,@ID Smallint = NULL,@Name NVARCHAR(MAX) = NULL,@Active BIT = NULL,@CBy SMALLINT = NULL                        
AS                        
BEGIN                        
BEGIN TRY                        
          
set @Name = (select dbo.ProperCase(@Name))                 
declare @TableName nvarchar(255) = (select TableName from tblTablesNames where ID = @FormID)                    
declare @strQuery NVARCHAR(MAX)                    
if EXISTS (select * from sys.tables where name = ''+@TableName+'')                    
BEGIN                    
IF(@Mode = 1)-- CREATE/ADD NEW Data                        
BEGIN                        
SET @strQuery = '  IF ISNULL((SELECT COUNT(*) FROM dbo.'+QUOTENAME(@TableName)+' WHERE [Name]= @Name ),0) >0                          
 BEGIN                          
  RAISERROR(''Name Already Exists'',16,1)                          
 END                         
INSERT INTO dbo.'+QUOTENAME(@TableName)+'([Name],Active,CBy,CDate) VALUES ( @Name , @Active , @CBy ,GETDATE())                        
select SCOPE_IDENTITY()  '                    
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Active BIT, @CBy SMALLINT', @FormID, @Mode, @ID, @Name, @Active, @CBy                    
END                        
IF(@Mode = 2)-- Modify Existing Data                        
BEGIN                        
SET @strQuery = '  IF ISNULL((SELECT COUNT(*) FROM dbo.'+QUOTENAME(@TableName)+' WHERE [Name]=  @Name  and ID !=  @ID ),0) >0                          
 BEGIN                          
  RAISERROR(''Name Already Exists'',16,1)                          
 END                         
 INSERT INTO tblMasterHistory (FormID,ID,Name,Active,CBy,CDate,MBy,MDate'+
 (case when CONVERT(nvarchar(50),@FormID) = '2' then ',PLName' else '' end)+',HisCBy,HisCDate)          
(select  @FormID ,*, @CBy ,GETDATE() from dbo.'+QUOTENAME(@TableName)+' where ID =  @ID )           
UPDATE dbo.'+QUOTENAME(@TableName)+' SET [Name]= @Name ,Active= @Active ,MBy= @CBy ,MDate=GETDATE() WHERE ID = @ID '                        
set @strQuery = @strQuery + ' SELECT  @ID '                     
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Active BIT, @CBy SMALLINT', @FormID, @Mode, @ID, @Name, @Active, @CBy                    
END                        
IF(@Mode = 3)-- Get All details                        
BEGIN                        
SET @strQuery = ' SELECT PH.*,CASE WHEN ISNULL(PH.MBy,0) = 0 THEN CUR.UserName ELSE MUR.UserName END  UserName,    
 CASE WHEN ISNULL(PH.MBy,0) = 0 THEN CONVERT(NVARCHAR(100),PH.CDate) ELSE CONVERT(NVARCHAR(100),PH.MDate) END LastActionTime FROM dbo.'+QUOTENAME(@TableName)+' PH    
JOIN tblUsers CUR ON CUR.ID = PH.CBy              
LEFT JOIN tblUsers MUR ON MUR.ID = PH.MBy      
WHERE PH.ID != '+(CASE WHEN @FormID = 12 THEN ' 1 ' ELSE '0' END)+' ORDER BY PH.[Name]'                        
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Active BIT, @CBy SMALLINT', @FormID, @Mode, @ID, @Name, @Active, @CBy                    
END                        
IF(@Mode = 4)-- Get Particular  details by  Name                        
BEGIN                        
SET @strQuery = '  SELECT * FROM dbo.'+QUOTENAME(@TableName)+' WHERE [Name] =  @Name '                    
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Active BIT, @CBy SMALLINT', @FormID, @Mode, @ID, @Name, @Active, @CBy                    
END                    
END                    
ELSE                    
BEGIN                    
DECLARE @ERR NVARCHAR(255) = 'Table ( '+@TableName+') Not Found'                    
RAISERROR(@ERR,16,1)                    
END                    
END TRY                        
BEGIN CATCH                        
SELECT ERROR_MESSAGE() MSG,ERROR_LINE() LINE,ERROR_PROCEDURE() [PROC]                        
END CATCH                        
END 
GO

/****** uspManageTaxCompGift ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec [uspManageTaxCompGift] 4,3,1,'DAFFS BANK pvt ltd',1,3                    
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspManageTaxCompGift]            
@FormID int,@Mode int,@ID Smallint = NULL,@Name NVARCHAR(MAX) = NULL,@Value decimal(25,4) = NULL,@Active BIT = NULL,@CBy SMALLINT = NULL                    
AS                    
BEGIN                    
BEGIN TRY                    
declare @CaseID int = (select AppValue from tblAppConfig where AppID = 1)              
            
declare @TableName nvarchar(255) = (select TableName from tblTablesNames where ID = @FormID)                
declare @strQuery NVARCHAR(MAX)                
if EXISTS (select * from sys.tables where name = ''+@TableName+'')                
BEGIN                
IF(@Mode = 1)-- CREATE/ADD NEW Data                    
BEGIN                    
set @Name = (select dbo.ProperCase(@Name))             
SET @strQuery = '  IF ISNULL((SELECT COUNT(*) FROM dbo.'+QUOTENAME(@TableName)+' WHERE [Name]= @Name ),0) >0                      
 BEGIN                      
  RAISERROR(''Name Already Exists'',16,1)                      
 END                     
INSERT INTO dbo.'+QUOTENAME(@TableName)+'([Name],Value,Active,CBy,CDate) VALUES ( @Name , @Value , @Active , @CBy ,GETDATE())                    
select SCOPE_IDENTITY()  '                
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Value decimal(25,4), @Active BIT, @CBy SMALLINT', @FormID, @Mode, @ID, @Name, @Value, @Active, @CBy                
END                    
IF(@Mode = 2)-- Modify Existing Data                    
BEGIN                    
set @Name = (select dbo.ProperCase(@Name))             
SET @strQuery = '  IF ISNULL((SELECT COUNT(*) FROM dbo.'+QUOTENAME(@TableName)+' WHERE [Name]=  @Name  and ID !=  @ID ),0) >0                      
 BEGIN                      
  RAISERROR(''Name Already Exists'',16,1)                      
 END                     
  INSERT INTO tblMasterHistory (FormID,ID,Name,Column1,Active,CBy,CDate,MBy,MDate,HisCBy,HisCDate)        
(select  @FormID ,*, @CBy ,GETDATE() from dbo.'+QUOTENAME(@TableName)+' where ID =  @ID )         
        
 UPDATE dbo.'+QUOTENAME(@TableName)+' SET [Name]= @Name ,Value =  @Value ,Active= @Active ,MBy= @CBy ,MDate=GETDATE() WHERE ID = @ID '                    
set @strQuery = @strQuery + ' SELECT  @ID '                 
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Value decimal(25,4), @Active BIT, @CBy SMALLINT', @FormID, @Mode, @ID, @Name, @Value, @Active, @CBy                
END                    
IF(@Mode = 3)-- Get All details                    
BEGIN                    
SET @strQuery = ' SELECT PH.ID,PH.Name,'+CASE WHEN @FormID IN (4,43) THEN 'CONVERT(INT, PH.Value) Value' ELSE 'dbo.fnGetRoundedValue(PH.Value) Value' END+',
PH.Active,PH.CBy,PH.CDate,PH.MBy,PH.MDate,CASE WHEN ISNULL(PH.MBy,0) = 0 THEN CUR.UserName ELSE MUR.UserName END  UserName,    
 CASE WHEN ISNULL(PH.MBy,0) = 0 THEN CONVERT(NVARCHAR(100),PH.CDate) ELSE CONVERT(NVARCHAR(100),PH.MDate) END LastActionTime FROM dbo.'+QUOTENAME(@TableName)+' PH    
JOIN tblUsers CUR ON CUR.ID = PH.CBy              
LEFT JOIN tblUsers MUR ON MUR.ID = PH.MBy  ORDER BY PH.[Name]'                    
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Value decimal(25,4), @Active BIT, @CBy SMALLINT', @FormID, @Mode, @ID, @Name, @Value, @Active, @CBy                
END                    
IF(@Mode = 4)-- Get Particular  details by  Name                    
BEGIN                    
SET @strQuery = '  SELECT * FROM dbo.'+QUOTENAME(@TableName)+' WHERE [Name] =  @Name '                
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Value decimal(25,4), @Active BIT, @CBy SMALLINT', @FormID, @Mode, @ID, @Name, @Value, @Active, @CBy                
END                
END                
ELSE                
BEGIN                
DECLARE @ERR NVARCHAR(255) = 'Table ( '+@TableName+') Not Found'                
RAISERROR(@ERR,16,1)                
END                
END TRY                    
BEGIN CATCH                    
SELECT ERROR_MESSAGE() MSG,ERROR_LINE() LINE,ERROR_PROCEDURE() [PROC]                    
END CATCH                    
END 
GO

/****** uspManufSalesableDmgReturnAnalysis ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspManufSalesableDmgReturnAnalysis]        
@BranchName int = 0,@ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',@ProductName NVARCHAR(255)='',       
@FromDate DATE = '2025-05-01',@ToDate DATE = '2025-08-30'      
as      
begin      
SET DATEFORMAT dmy;    
DECLARE @DiffMonthCount INT,@TempFromDate NVARCHAR(50),@DateSerial INT,@FD DATE,@TD DATE,                
@Query NVARCHAR(MAX) ,@SR DEcimal(25,6),@DR DEcimal(25,6),@GSR  DECIMAL(25,6),@GDR DECIMAL(25,6),@StrQuery NVARCHAR(max) = ''        
  
SET @DiffMonthCount = (SELECT DATEDIFF(MONTH,@FromDate,@ToDate)+1)                
SET @DateSerial = 0                  
CREATE TABLE #TEMP (MFID INT,MFNAME NVARCHAR(255),[MONTH] NVARCHAR(255),InvSale  DECIMAL(25,6),                
GInvSale  DECIMAL(25,6),SR DECIMAL(25,6),GSR DECIMAL(25,6),DR DECIMAL(25,6),GDR DECIMAL(25,6),TRANTYPE INT)      
WHILE @DiffMonthCount > 0                                                              
BEGIN                 
SET @FD = (CASE WHEN (DATEADD(mm, DATEDIFF(mm, 0, DATEADD(MONTH,@DateSerial,@FromDate)),0)) < @FromDate THEN @FromDate ELSE (DATEADD(mm, DATEDIFF(mm, 0, DATEADD(MONTH,@DateSerial,@FromDate)),0)) END)                
SET @TD = (CASE WHEN  DATEADD(dd, -1, DATEADD(mm, DATEDIFF(mm, 0, DATEADD(MONTH,@DateSerial,@FromDate)) + 1, 0)) > @ToDate THEN @ToDate ELSE  DATEADD(dd, -1, DATEADD(mm, DATEDIFF(mm, 0, DATEADD(MONTH,@DateSerial,@FromDate)) + 1, 0)) END)                  
  
    
      
SET @Query = (CONVERT(NVARCHAR(3), UPPER(DATENAME(MONTH,DATEADD(MONTH,@DateSerial,@FromDate)))) +' '+ CAST(DATEPART(YYYY,DATEADD(MONTH,@DateSerial,@FromDate)) AS VARCHAR))                
  print @Query+ ' , From : '+convert(nvarchar(50),@FD)+ ' , To : '+convert(nvarchar(50),@TD)  
SET @StrQuery = ' SELECT  MF.ID ,MF.Name, @Query ,              
(case when TransactionType in (1,4,5,6) then ISNULL(sum(TSD.NetAmt),0)   END) AS InvSale,(case when TransactionType in (1,4,5,6) then ISNULL(sum(TSD.GrossAmt),0)  end) AS GInvSale,                
(case when TransactionType = 2 then ISNULL(sum(TSD.NetAmt),0)   END) AS SR,(case when TransactionType = 2 then ISNULL(sum(TSD.GrossAmt),0)  end) AS GSR,                
(case when TransactionType = 3 then ISNULL(sum(TSD.NetAmt),0)  end) as DR,(case when TransactionType = 3 then ISNULL(sum(TSD.GrossAmt),0) end) AS GDR,TransactionType                
 FROM tblTranSalesDetail TSD                
 JOIN tblTranSalesHeader AS TSH ON TSH.ID=TSD.InvId                
 JOIN tblMasterProduct AS MP ON MP.ID = TSD.ProdId                
 JOIN tblMasterManufacturer AS MF ON MF.ID  =MP.MfrID       
 left join tblMasterBrand MB ON  MB.ID = MP.BrandID      
left join tblMasterCategory MC ON  MC.ID = MP.CategoryID      
left join tblMasterBranchOffice MBO ON  MBO.ID = TSH.BranchID      
WHERE  Status IN (1,3,6,5,7) '    
 SET @StrQuery += (CASE WHEN ISNULL(@FD,'')='' AND ISNULL(@TD,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN  @FD  AND  @TD )' END)                    
 set @StrQuery += case when ISNULL(@BranchName,'') = '' then '' else ' AND TSH.BranchID  = '+' @BranchName '+'' END          
 set @StrQuery += case when ISNULL(@BrandName,'') = '' then '' else ' AND MB.ID IN (SELECT * from dbo.fnSplitString( '+' @BrandName ,'',''))' END          
 set @StrQuery += case when ISNULL(@CategoryName,'') = '' then '' else ' AND MC.ID IN (SELECT * from dbo.fnSplitString( '+' @CategoryName ,'',''))' END          
 set @StrQuery += case when ISNULL(@ManufName,'') = '' then '' else ' AND MF.ID IN (SELECT * from dbo.fnSplitString( '+' @ManufName ,'',''))' END          
 set @StrQuery += case when ISNULL(@ProductName,'') = '' then '' else ' AND MP.ID IN (SELECT * from dbo.fnSplitString( '+' @ProductName ,'',''))' END           
 set @StrQuery += ' group by TransactionType,MF.ID,MF.Name,TSH.InvDate ORDER BY TSH.InvDate ASC '    
INSERT INTO #TEMP         
EXEC sys.sp_executesql @StrQuery, N'@BranchName int, @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @ToDate DATE, @FD DATE, @TD DATE, @Query NVARCHAR(MAX)', @BranchName, @ManufName, @BrandName, @CategoryName, @ProductName, @FromDate, @ToDate, @FD, @TD, @Query        
SET @DateSerial = @DateSerial + 1                                                              
SET @DiffMonthCount = @DiffMonthCount - 1                 
END          
SELECT                
MFID ManufID,MFNAME as [Mfr Name],[MONTH] AS [MM/YYYY], dbo.fnGetRoundedValue(ISNULL(SUM(GInvSale),0)) AS [Gross Sales Value],                
dbo.fnGetRoundedValue(ISNULL(SUM(InvSale),0)) AS [Net Sales Value],dbo.fnGetRoundedValue(ISNULL(SUM(GSR),0)) AS [Gross SR Value],                
dbo.fnGetRoundedValue(ISNULL(SUM(SR),0)) AS [Net SR Value],dbo.fnGetRoundedValue(ISNULL(SUM(GDR),0)) AS [Gross DR Value],                
dbo.fnGetRoundedValue(ISNULL(SUM(DR),0)) AS [Net DR Value] FROM #TEMP                
GROUP BY MFNAME,[MONTH],MFID         
ORDER BY CONVERT(date,CONVERT(nvarchar,DATEADD(month, DATEDIFF(month, 0, [MONTH]), 0),103)) ASC,MFNAME ASC          
DROP TABLE #TEMP    
END
GO

/****** uspManufwiseStockHoldingHeader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspManufwiseStockHoldingHeader]        
@BranchName int = 0,@ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',@ProductName NVARCHAR(255)='',       
@FromDate DATE = '2025-07-01',@ToDate DATE = '2025-08-30'      
as      
begin      
SET DATEFORMAT dmy;          
select BranchID,NK.ManufID AS [ManufID],BrandID,CategoryID,ProdID,NK.[Manufacture Name],NK.[Stock In hand] into #Temp1 from (                  
SELECT PIN.BranchID,MF.ID as [ManufID],MP.BrandID,MP.CategoryID,MP.ID ProdID ,MF.Name AS [Manufacture Name],                  
(sum(PIN.ActualQty * PIN.PurchasePrice)) AS  [Stock In hand]                  
FROM tblProductInventory AS PIN                  
LEFT JOIN tblMasterProduct as MP on MP.ID = PIN.ProdId                  
JOIN tblMasterManufacturer as MF on MF.ID = MP.MfrID      
GROUP BY MF.ID,MF.Name,BrandID,CategoryID,MP.ID,PIN.BranchID) AS NK                  
--Temp Table 2                  
SELECT BranchID,JNK.ManufacturerId,JNK.[Month Sales],JNK.[Perday sales] into #Temp2   FROM(                  
SELECT  PIN.BranchID,MF.ID ManufacturerId,                  
(SUM((TSD.UomQty * isnull(MP.BaseCR,0))  * PIN.PurchasePrice)) AS [Month Sales],                  
(SUM((TSD.UomQty * isnull(MP.BaseCR,0)  * PIN.PurchasePrice) /(DATEDIFF(DAY,@FromDate,@ToDate) + 1))) AS [Perday sales]                  
FROM tblProductInventory AS PIN                  
LEFT JOIN tblTranSalesDetail as TSD on TSD.InventoryId = PIN.InventoryId                  
LEFT JOIN tblTranSalesHeader AS TSH ON TSH.ID = TSD.InvId                  
JOIN tblMasterProduct as MP on MP.ID = PIN.ProdId                  
JOIN tblMasterManufacturer as MF on MF.ID = MP.MfrID                  
WHERE TSH.InvDate BETWEEN @FromDate AND @ToDate AND Status IN (1,3,5) and TSH.DocPrefix = 15                  
GROUP BY MF.ID,PIN.BranchID)as JNK                  
--SELECT VALUES                  
SELECT TMP5.BranchID,TMP5.ManufID AS [ManufID],BrandID,CategoryID,ProdID,[Manufacture Name] AS [Manufacture Name],                  
ISNULL(sum([Month Sales]),0) as [Month Sales],ISNULL(sum([Perday sales]),0) as [Perday Sales],                  
ISNULL(sum([Stock In hand]),0) as [Stock In Hand],ISNULL(sum([Stock In hand] / NULLIF([Perday sales],0)),0) as [Stock Hold]               
INTO #MAINTEMP from #Temp1 as TMP5            
LEFT join #Temp2 as Temp6 on Temp6.ManufacturerId=TMP5.ManufID                  
GROUP BY TMP5.ManufID,TMP5.[Manufacture Name],BrandID,CategoryID,ProdID,TMP5.BranchID        
DECLARE @query NVARCHAR(MAX) = ''      
set @query = '      
SELECT ManufID,[Manufacture Name] [Mfr Name],dbo.fnGetRoundedValue(([Month Sales])) [Month Sales],dbo.fnGetRoundedValue(([Perday Sales])) [Perday Sales],              
dbo.fnGetRoundedValue(SUM([Stock In Hand])) [Stock In Hand],dbo.fnGetRoundedValue(SUM([Stock Hold])) [Stock Hold]               
FROM #MAINTEMP MT      
left join tblMasterProduct MP ON MP.ID = MT.ProdID      
left join tblMasterBrand MB ON  MB.ID = MT.BrandID      
left join tblMasterCategory MC ON  MC.ID = MT.CategoryID      
left join tblMasterBranchOffice MBO ON  MBO.ID = MT.BranchID      
WHERE (MANUFID != 0 OR MANUFID = 0) '      
 set @query += case when ISNULL(@BranchName,'') = '' then '' else ' AND MT.BranchID = '+' @BranchName '+'' END          
 set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND MB.ID IN (SELECT * from dbo.fnSplitString( '+' @BrandName ,'',''))' END          
 set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND MC.ID IN (SELECT * from dbo.fnSplitString( '+' @CategoryName ,'',''))' END          
 set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND [ManufID] IN (SELECT * from dbo.fnSplitString( '+' @ManufName ,'',''))' END          
 set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND MP.ID IN (SELECT * from dbo.fnSplitString( '+' @ProductName ,'',''))' END              
SET @query = @query + ' GROUP BY ManufID,[Manufacture Name],[Month Sales],[Perday Sales] ORDER BY SUM([Stock Hold]) DESC '          
EXEC sys.sp_executesql @query, N'@BranchName int, @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BranchName, @ManufName, @BrandName, @CategoryName, @ProductName, @FromDate, @ToDate            
drop table #Temp1,#Temp2,#MAINTEMP         
end
GO

/****** uspMfrwisesalesDetail ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
  -- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspMfrwisesalesDetail]      
@ManufID INT = 8,@BranchName NVARCHAR(255) = '0',@ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',@ProductName NVARCHAR(255) = '',      
@FromDate DATE = '2025-08-01',@ToDate DATE = '2025-08-30'        
AS      
BEGIN      
declare @StrQuery nvarchar(max) = ''        
 set @StrQuery = ' SELECT MP.Code AS [Product Code],MP.Name AS [Product Name],MP.EAN,MF.Name [Mfr Name],          
MB.Name [Brand Name],PHL.Name [Category Name],        
(CASE WHEN TSH.DocPrefix = 15 THEN dbo.fnGetRoundedValue(SUM(TSD.AdjustQty))end) AS [Base Qty],          
dbo.fnGetRoundedValue(SUM(TSD.GrossAmt)) AS [Gross Amount],          
dbo.fnGetRoundedValue(SUM(TSD.NetAmt)) AS [Net Amount]          
FROM tblMasterManufacturer MM          
JOIN tblmasterProduct MP ON MP.MfrID=MM.ID          
JOIN tblMasterBrand MB ON MB.ID = MP.BrandID        
JOIN tblMasterManufacturer MF ON MF.ID = MP.MfrID      
JOIN tblMasterCategory PHL ON PHL.ID = MP.CategoryID        
JOIN tblTranSalesDetail TSD ON TSD.ProdId=MP.ID          
JOIN tblTranSalesHeader TSH ON TSH.ID=TSD.InvId          
WHERE TSH.Status IN (1,3,5) AND TSH.DocPrefix = 15 AND ISNULL(TSD.TaxId,0)>0 AND MP.MfrID =  @ManufID '      
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN  @FromDate  AND  @ToDate )' END)                  
  
    
      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND TSH.BranchID =  @BranchName ' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BrandName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString(  @BrandName ,'',''))' END)                
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CategoryName,'')='' THEN '' ELSE ' AND PHL.ID IN (SELECT * from dbo.fnSplitString(  @CategoryName ,'',''))' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ProductName,'')='' THEN '' ELSE ' AND MP.ID IN (SELECT * from dbo.fnSplitString(  @ProductName ,'',''))' END)       
SET @StrQuery = @StrQuery + ' GROUP BY MP.Code,MP.Name,MP.EAN,TSH.DocPrefix,MB.Name,PHL.Name,MF.Name'      
EXEC sys.sp_executesql @StrQuery, N'@ManufID INT, @BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @ToDate DATE', @ManufID, @BranchName, @ManufName, @BrandName, @CategoryName, @ProductName, @FromDate, @ToDate      
 END
GO

/****** uspMfrwisesalesHeader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 -- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspMfrwisesalesHeader]    
@BranchName NVARCHAR(255) = '0',@ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',@ProductName NVARCHAR(255) = '',  
@FromDate DATE = '2025-08-01',@ToDate DATE = '2025-08-30'     
AS  
BEGIN  
declare @StrQuery nvarchar(max) = ''    
 set @StrQuery = ' SELECT MP.MfrID, MM.Name AS [Mfr Name],          
(CASE WHEN TSH.DocPrefix = 15 THEN dbo.fnGetRoundedValue(SUM(TSD.UomQty * MP.BaseCR))end) AS [Base Qty],             
dbo.fnGetRoundedValue(sum(TSD.GrossAmt)) AS [Gross Amount],dbo.fnGetRoundedValue(sum(TSD.NetAmt)) AS [Net Amount]          
FROM tblTranSalesDetail TSD          
JOIN tblTranSalesHeader TSH ON TSH.ID=TSD.InvId          
JOIN tblmasterProduct MP ON MP.ID = TSD.ProdId          
JOIN tblMasterManufacturer MM ON MM.ID=MP.MfrID      
JOIN tblMasterBrand MB ON MB.ID = MP.BrandID    
JOIN tblMasterCategory PHL ON PHL.ID = MP.CategoryID    
WHERE TSH.Status IN (1,3,5) AND  TSH.DocPrefix = 15 AND ISNULL(TSD.TaxId,0)>0'  
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN  @FromDate  AND  @ToDate )' END)                  
  
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND TSH.BranchID =  @BranchName ' END)     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ManufName,'')='' THEN '' ELSE ' AND MM.ID IN (SELECT * from dbo.fnSplitString (  @ManufName ,'',''))' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BrandName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString (  @BrandName ,'',''))' END)            
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CategoryName,'')='' THEN '' ELSE ' AND PHL.ID IN (SELECT * from dbo.fnSplitString (  @CategoryName ,'',''))' END)     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ProductName,'')='' THEN '' ELSE ' AND MP.ID IN (SELECT * from dbo.fnSplitString (  @ProductName ,'',''))' END)     
SET @StrQuery = @StrQuery + ' GROUP BY MP.MfrID,MM.Name,TSH.DocPrefix order by MM.Name'  
EXEC sys.sp_executesql @StrQuery, N'@BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BranchName, @ManufName, @BrandName, @CategoryName, @ProductName, @FromDate, @ToDate  
 END
GO

/****** uspMonthlyWiseSalesFooter ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspMonthlyWiseSalesFooter]      
@MFD DATE = '2025-08-01',@MED DATE = '2025-08-30',@BranchName NVARCHAR(255) = '0',@BeatName NVARCHAR(255) = '',@SalesmanName NVARCHAR(255) = '',@CustomerName NVARCHAR(255) = '',@CustomerType NVARCHAR(255) = '',    
@Ratings NVARCHAR(255) = '',@FromDate DATE = '2025-04-01',@ToDate DATE = '2025-08-30'       
AS    
BEGIN    
declare @StrQuery nvarchar(max) = ''      
 set @StrQuery = '     
SELECT [MMM/YYYY] ,[Trans Name],[Doc ID],format(InvDate,''dd-MMM-yyyy'') [Doc Date],[Reference Number] [Ref No],[Customer Name],[Customer Type],Ratings,    
[Beat Name],[Salesman Name],[Gross Amount],[Tax Amount],Charges,[Net Amount] FROM (    
SELECT CONVERT(NVARCHAR(3), UPPER(DATENAME(MONTH,TSH.InvDate))) +'' ''+ CAST(DATEPART(YYYY,TSH.InvDate) AS VARCHAR) AS [MMM/YYYY],    
CASE WHEN  TransactionType in(1,4,5,6) then ''Invoice''  WHEN  TransactionType=2 then ''Sales Return''  WHEN  TransactionType=3 then ''Damage Return''  END AS [Trans Name],    
TSH.DocId AS [Doc ID],TSH.InvDate,TSH.UDFDocId AS [UDN],TSH.DocRef AS [Reference Number],      
MC.Name AS [Customer Name],ISNULL(Beat.Name,'''') AS [Beat Name],ISNULL(SM.Name,'''') AS [Salesman Name],      
dbo.fnGetRoundedValue(CASE WHEN DocPrefix=15 then (TSH.GrossAmt) ELSE (TSH.GrossAmt)*-1  END ) AS [Gross Amount],      
dbo.fnGetRoundedValue(CASE WHEN DocPrefix=15 then (TSH.TotalTaxAmt) ELSE (TSH.TotalTaxAmt*-1)  END ) AS [Tax Amount],      
dbo.fnGetRoundedValue(ISNULL(TSH.Frieght,0) + ISNULL(TSH.OtherChargeAmt,0)) AS [Charges],      
dbo.fnGetRoundedValue(CASE WHEN DocPrefix=15 then (TSH.NetAmt) ELSE (TSH.NetAmt)*-1  END ) AS [Net Amount],MCT.Name [Customer Type],RT.RatingName Ratings    
FROM tblTranSalesHeader AS TSH      
LEFT JOIN tblMasterCustomer AS MC ON MC.ID = TSH.CustId      
LEFT JOIN tblMasterBeat AS Beat ON Beat.ID = TSH.BeatID          
LEFT JOIN tblMasterSalesMan AS SM ON SM.ID = TSH.SalesManId          
LEFT JOIN tblMasterCustomerType AS MCT ON MCT.ID = MC.CustomerType     
LEFT JOIN tblRatings AS RT ON RT.ID = MC.Rating      
WHERE TSH.Status IN (1,3,5,6,7) '    
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN  @MFD  AND  @MED )' END)                      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND TSH.BranchID =  @BranchName ' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND Beat.ID IN (SELECT * from dbo.fnSplitString(  @BeatName ,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SM.ID IN (SELECT * from dbo.fnSplitString(  @SalesmanName ,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString(  @CustomerName ,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN (SELECT * from dbo.fnSplitString(  @CustomerType ,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN (SELECT * from dbo.fnSplitString(  @Ratings ,'',''))' END)       
SET @StrQuery = @StrQuery + ' ) as rec ORDER BY InvDate'    
EXEC sys.sp_executesql @StrQuery, N'@MFD DATE, @MED DATE, @BranchName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @FromDate DATE, @ToDate DATE', @MFD, @MED, @BranchName, @BeatName, @SalesmanName, @CustomerName, @CustomerType, @Ratings, @FromDate, @ToDate    
end 
GO

/****** uspMonthlyWiseSalesHeader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspMonthlyWiseSalesHeader]      
@BranchName NVARCHAR(255) = '0',@BeatName NVARCHAR(255) = '',@SalesmanName NVARCHAR(255) = '',@CustomerName NVARCHAR(255) = '',@CustomerType NVARCHAR(255) = '',    
@Ratings NVARCHAR(255) = '',@FromDate DATE = '2025-04-01',@ToDate DATE = '2025-08-30'       
AS    
BEGIN    
declare @StrQuery nvarchar(max) = ''      
 set @StrQuery = '     
SELECT [From Date],[To Date],[MMM/YYYY],dbo.fnGetRoundedValue(SUM([Sales Value]))  AS [Sales Value],      
dbo.fnGetRoundedValue(SUM([SR Saleable Value])) AS [SR Saleable Value],      
dbo.fnGetRoundedValue(SUM([SR Damage Value])) AS [SR Damage Value] FROM (    
SELECT InvDate,CONVERT(date,SRIRAM.[From Date]) AS [From Date],                
CONVERT(DATE,SRIRAM.[To Date]) AS [To Date],      
SRIRAM.[MMM/YYYY],                
SUM(isnull(SRIRAM.[Net Amount],0)) AS [Sales Value] ,            
SUM(isnull(SRIRAM.[SR Saleable Value],0)) AS [SR Saleable Value] ,            
SUM(isnull(SRIRAM.[SR Damage Value],0)) AS [SR Damage Value] --INTO #TEMP            
FROM             
(             
SELECT InvDate,      
(CASE WHEN (DATEADD(mm, DATEDIFF(mm, 0, InvDate),0)) <  @FromDate         
THEN  @FromDate  ELSE DATEADD(mm, DATEDIFF(mm, 0, InvDate),0) END) AS [From Date],      
(CASE WHEN (DATEADD (dd, -1, DATEADD(mm, DATEDIFF(mm, 0, InvDate) + 1, 0))) >  @ToDate             
 THEN  @ToDate  ELSE DATEADD(dd, -1, DATEADD(mm, DATEDIFF(mm, 0, InvDate) + 1, 0))END) AS [To Date],            
CONVERT(NVARCHAR(3), UPPER(DATENAME(MONTH,InvDate))) +'' ''+ CAST(DATEPART(YYYY,InvDate) AS VARCHAR) AS [MMM/YYYY],             
 (CASE WHEN DocPrefix=15 then isnull(NetAmt,0)END ) AS [Net Amount],               
CASE WHEN DocPrefix=16 AND TransactionType=2  then  (isnull(NetAmt,0))*-1 END AS [SR Saleable Value],            
CASE WHEN DocPrefix=16 AND TransactionType=3  then  (isnull(NetAmt,0))*-1 END AS [SR Damage Value]            
FROM tblTranSalesHeader TSH    
JOIN tblMasterCustomer MC ON MC.ID= TSH.CustID    
LEFT JOIN tblMasterBeat AS Beat ON Beat.ID = TSH.BeatID          
LEFT JOIN tblMasterSalesMan AS SM ON SM.ID = TSH.SalesManId          
LEFT JOIN tblMasterCustomerType AS MCT ON MCT.ID = MC.CustomerType     
LEFT JOIN tblRatings AS RT ON RT.ID = MC.Rating    
WHERE Status in(1,3,5,6,7) '    
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN  @FromDate  AND  @ToDate )' END)                  
  
    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND TSH.BranchID =  @BranchName ' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND Beat.ID IN (SELECT * from dbo.fnSplitString(  @BeatName ,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SM.ID IN (SELECT * from dbo.fnSplitString(  @SalesmanName ,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString(  @CustomerName ,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN (SELECT * from dbo.fnSplitString(  @CustomerType ,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN (SELECT * from dbo.fnSplitString(  @Ratings ,'',''))' END)       
SET @StrQuery = @StrQuery + ')  AS SRIRAM                
GROUP BY SRIRAM.InvDate,SRIRAM.[MMM/YYYY],SRIRAM.[From Date],SRIRAM.[To Date]) as main    
 GROUP BY [From Date],[To Date],[MMM/YYYY] ORDER BY CONVERT(DATETIME,[MMM/YYYY]) '    
 EXEC sys.sp_executesql @StrQuery, N'@BranchName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BranchName, @BeatName, @SalesmanName, @CustomerName, @CustomerType, @Ratings, @FromDate, @ToDate    
 end
GO

/****** uspMonthwisesalesAnalticsReport ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--uspMonthwisesalesAnalticsReport 3,5,1,'',1,'',1,'2026-05-28','2026-08-28'
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspMonthwisesalesAnalticsReport]
@Mode int = 1,@Grp1Type int = 1,@Grp2Type int = 3,@Grp2ID NVARCHAR(MAX) = '', @Grp3Type int = 1,@Grp3ID NVARCHAR(MAX) = '',
@Grp4Type int = 1,@FromDate date = '2026-01-01',@ToDate date = '2026-05-30'
as
begin
if(@Mode = 1)-- FOR PARTY FILTER
BEGIN
IF(@Grp1Type = 1 and @Grp2Type not in (6,7))--Beat
BEGIN
SELECT ID value,Name label FROM tblMasterBeat ORDER BY Name
END
IF(@Grp1Type = 2 and @Grp2Type not in (6,7))--Salesman
BEGIN
SELECT ID value,Name label FROM tblMasterSalesman ORDER BY Name
END
IF(@Grp1Type = 3 and @Grp2Type not in (6,7))--Customer
BEGIN
SELECT ID value,Name label FROM tblMasterCustomer ORDER BY Name
END
IF(@Grp1Type = 4 and @Grp2Type not in (6,7))--CustomerType
BEGIN
SELECT ID value,Name label FROM tblMasterCustomerType ORDER BY Name
END
IF(@Grp1Type = 1 and @Grp2Type in (6,7))--Beat
BEGIN
SELECT ID value,Name label FROM tblMasterVendor ORDER BY Name
END
END
ELSE if(@Mode = 2)-- FOR Product FILTER
BEGIN
IF(@Grp1Type = 1)--manuf
BEGIN
SELECT ID value,Name label FROM tblMasterManufacturer ORDER BY Name
END
IF(@Grp1Type = 2)--brand
BEGIN
SELECT ID value,Name label FROM tblMasterBrand ORDER BY Name
END
IF(@Grp1Type = 3)--Category
BEGIN
SELECT ID value,Name label FROM tblMasterCategory ORDER BY Name
END
IF(@Grp1Type = 4)--product
BEGIN
SELECT ID value,Name label FROM tblMasterProduct ORDER BY Name
END
END
ELSE if(@Mode = 3)--Main Data
BEGIN

declare @Group1TypeName nvarchar(100) = (case when @Grp1Type = 1 then '[Sales Value' when @Grp1Type = 2 then '[SR Value' when
@Grp1Type = 3 then '[DR Value' when @Grp1Type = 4 then '[Collection' when @Grp1Type = 5 then '[Outstandings'
when @Grp1Type = 6 then '[Purchase Value' when @Grp1Type = 7 then '[PR Value' else 'A' end)
declare @Group2TypeName nvarchar(100) = case when @Grp1Type in (1,2,3,4,5) then
(case when @Grp2Type = 1 then '[Beat Name]' when @Grp2Type = 2 then '[Salesman Name]' when
@Grp2Type = 3 then '[Customer Name]' else '[Customer Type]' end) else
(case when @Grp2Type = 1 then '[Vendor Name]' else '' end) end

declare @Group3TypeName nvarchar(100) = (case when @Grp3Type = 1 then '[Manuf Name]' when @Grp3Type = 2 then '[Brand Name]' when
@Grp3Type = 3 then '[Category Name]' else '[Product Name]' end)
declare @Group4TypeName nvarchar(100) = (case when @Grp4Type = 1 then '(Qty)' when @Grp4Type = 2 then '(Gross)' when
@Grp4Type = 3 then '(Net)' else '' end)

DECLARE @query NVARCHAR(MAX),@InitialQuery NVARCHAR(MAX), @PCol NVARCHAR(MAX),@PColWithisnull nvarchar(max),@CumativeCol nvarchar(max);

;WITH ALLMonthsCTE AS (
SELECT DATEFROMPARTS(YEAR(@FromDate), MONTH(@FromDate), 1) AS MonthStart
UNION ALL
SELECT DATEADD(MONTH, 1, MonthStart)
FROM ALLMonthsCTE
WHERE DATEADD(MONTH, 1, MonthStart) <= DATEFROMPARTS(YEAR(@Todate), MONTH(@Todate), 1)
)
SELECT @PCol = MonthList FROM (SELECT STRING_AGG(FORMAT(MonthStart, '[MMM yyyy]'), ', ') WITHIN GROUP (ORDER BY MonthStart) AS MonthList FROM ALLMonthsCTE) AS RR

;WITH ALLMonthsCTE AS (
SELECT DATEFROMPARTS(YEAR(@FromDate), MONTH(@FromDate), 1) AS MonthStart
UNION ALL
SELECT DATEADD(MONTH, 1, MonthStart)
FROM ALLMonthsCTE
WHERE DATEADD(MONTH, 1, MonthStart) <= DATEFROMPARTS(YEAR(@Todate), MONTH(@Todate), 1)
)
SELECT @PColWithisnull = MonthList FROM (SELECT STRING_AGG('(ISNULL([' + FORMAT(MonthStart, 'MMM yyyy')+ '],0)) AS [' + FORMAT(MonthStart, 'MMM yyyy')+ ']', ', ')

WITHIN GROUP (ORDER BY MonthStart) AS MonthList FROM ALLMonthsCTE) AS RR
;WITH ALLMonthsCTE AS (
SELECT DATEFROMPARTS(YEAR(@FromDate), MONTH(@FromDate), 1) AS MonthStart
UNION ALL
SELECT DATEADD(MONTH, 1, MonthStart)
FROM ALLMonthsCTE
WHERE DATEADD(MONTH, 1, MonthStart) <= DATEFROMPARTS(YEAR(@Todate), MONTH(@Todate), 1)
)
SELECT @CumativeCol = MonthList FROM (SELECT STRING_AGG('ISNULL('+FORMAT(MonthStart, '[MMM yyyy]')+',0)', '+ ') WITHIN GROUP (ORDER BY MonthStart) AS MonthList FROM ALLMonthsCTE) AS RR
create table #t1(InvDate nvarchar(50),Grp1ID int,Grp1Name nvarchar(255),Grp2ID int,Grp2Name nvarchar(255),Grp3Value decimal(25,4))
IF(@Grp1Type IN (1,2,3))--SALES,SR,DR
BEGIN
set @InitialQuery = '
SELECT InvDate,Grp1ID,Grp1Name,Grp2ID,Grp2Name,SUM(Grp3Value) Grp3Value FROM (
select UPPER(FORMAT(SH.InvDate,''MMM yyyy'')) InvDate'
set @InitialQuery += case when @Grp3Type = 0 then ',0 Grp1ID,null Grp1Name' when @Grp3Type = 1 then ',MP.MfrID Grp1ID,MANUF.Name Grp1Name' when @Grp3Type = 2 then ',MP.BrandID Grp1ID,MBR.Name Grp1Name'
when @Grp3Type = 3 then ',MP.CategoryID Grp1ID,MCAT.Name Grp1Name' else ',MP.ID Grp1ID,MP.Name Grp1Name' END

set @InitialQuery += case when @Grp2Type = 0 then ',0 Grp2ID,null Grp2Name' when @Grp2Type = 1 then ',ISNULL(SH.BeatID,0) Grp2ID,MB.Name Grp2Name' when @Grp2Type = 2 then ',ISNULL(SH.SalesmanID,0) Grp2ID,SM.Name Grp2Name'
when @Grp2Type = 3 then ',MC.ID Grp2ID,MC.Name Grp2Name' else ',ISNULL(MCAT.ID,0) Grp2ID,MCAT.Name Grp2Name' END

set @InitialQuery += case when @Grp4Type = 1 then ',SUM(SD.UOMQty) Grp3Value ' when @Grp4Type = 2 then ',SUM(SD.GrossAmt) Grp3Value ' else
',SUM(SD.NetAmt) Grp3Value' end
-- AND SH.DocPrefix = 15
set @InitialQuery += ' from tblTranSalesHeader SH
JOIN tblTranSalesDetail SD ON SD.InvID = SH.ID
JOIN tblMasterCustomer MC ON MC.ID = SH.CustID
LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatID
LEFT JOIN tblMasterSalesman SM ON SM.ID = SH.SalesManID
LEFT JOIN tblMasterCustomerType MCT ON MCT.ID = MC.CustomerType
JOIN tblMasterProduct MP ON MP.ID = SD.ProdID
JOIN tblMasterManufacturer MANUF ON MANUF.ID = MP.MfrID
JOIN tblMasterBrand MBR ON MBR.ID = MP.BrandID
JOIN tblMasterCategory MCAT ON MCAT.ID = MP.CategoryID
WHERE SH.STATUS NOT IN (2,4) AND SH.InvDate BETWEEN '+' @FromDate '+' AND '+' @ToDate '+''
-- AND ISNULL(SD.TaxId,0)>0
set @InitialQuery += case when @Grp1Type = 1 then ' and SH.DocPrefix = 15 ' when @Grp1Type = 2 then ' and SH.DocPrefix = 16 and SH.TransactionType = 2 '
else ' and SH.DocPrefix = 16 and SH.TransactionType = 3 ' end

set @InitialQuery += (case when ISNULL(@Grp3ID,'') = '' or @Grp3Type = 0 then '' else
case when @Grp3Type = 1 then ' and MP.MfrID IN (SELECT * FROM string_split('+' @Grp3ID '+','+''','''+'))'
when @Grp3Type = 2 then ' and MP.BrandID IN (SELECT * FROM string_split('+' @Grp3ID '+','+''','''+'))'
when @Grp3Type = 3 then ' and MP.CategoryID IN (SELECT * FROM string_split('+' @Grp3ID '+','+''','''+'))'
when @Grp3Type = 4 then ' and MP.ID IN (SELECT * FROM string_split('+' @Grp3ID '+','+''','''+'))'
END
END)

set @InitialQuery += (case when ISNULL(@Grp2ID,'') = '' or @Grp2Type = 0 then '' else
case when @Grp2Type = 1 then ' and MB.ID IN (SELECT * FROM string_split('+' @Grp2ID '+','+''','''+'))'
when @Grp2Type = 2 then ' and SM.ID IN (SELECT * FROM string_split('+' @Grp2ID '+','+''','''+'))'
when @Grp2Type = 3 then ' and MC.ID IN (SELECT * FROM string_split('+' @Grp2ID '+','+''','''+'))'
when @Grp2Type = 4 then ' and MCT.ID IN (SELECT * FROM string_split('+' @Grp2ID '+','+''','''+'))'
END
END)

set @InitialQuery += 'GROUP BY SH.InvDate' +(case when @Grp3Type = 0 then '' when @Grp3Type = 1 then ',MP.MfrID,MANUF.Name' when @Grp3Type = 2 then ',MP.BrandID,MBR.Name'
when @Grp3Type = 3 then ',MP.CategoryID,MCAT.Name' else ',MP.ID,MP.Name' END)

set @InitialQuery += case when @Grp2Type = 0 then '' when @Grp2Type = 1 then ',SH.BeatID,MB.Name' when @Grp2Type = 2 then ',SH.SalesmanID,SM.Name'
when @Grp2Type = 3 then ',MC.ID,MC.Name' else ',MCAT.ID,MCAT.Name' END

set @InitialQuery += ') as rec group by InvDate,Grp1ID,Grp1Name,Grp2ID,Grp2Name'--Grp1ID,Grp1Name,Grp2ID,Grp2Name'

--select @InitialQuery

insert into #t1
EXEC sys.sp_executesql @InitialQuery, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode, @Grp1Type, @Grp2Type, @Grp2ID, @Grp3Type, @Grp3ID, @Grp4Type, @FromDate, @ToDate

SET @query = 'SELECT '+
case when @Grp3Type = 0 then '' else ' Grp1ID,' end +
case when @Grp2Type = 0 then '' else ' Grp2ID,' end +
case when @Grp3Type = 0 then '' else 'Grp1Name'+@Group3TypeName+',' end +
case when @Grp2Type = 0 then '' else 'Grp2Name'+@Group2TypeName+',' end +
'('+@CumativeCol+') AS '+@Group1TypeName+@Group4TypeName+'],'+@PColWithisnull+
' FROM #t1 PIVOT (SUM(Grp3Value) FOR InvDate IN (' + @PCol + ')) AS PivotTable 
ORDER BY '+case when @Grp3Type = 0 then '' else @Group3TypeName end +
case when @Grp2Type > 0 and @Grp3Type > 0 then ',' else '' end+
case when @Grp2Type = 0 then '' else @Group2TypeName end
EXEC sys.sp_executesql @query, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode, @Grp1Type, @Grp2Type, @Grp2ID, @Grp3Type, @Grp3ID, @Grp4Type, @FromDate, @ToDate

END
ELSE IF(@Grp1Type = 4) -- COLLECTION
BEGIN
create table #t2(ColDate nvarchar(50),Grp2ID int,Grp2Name nvarchar(255),Grp3Value decimal(25,4))
set @InitialQuery = 'SELECT ColDate,Grp2ID,Grp2Name,SUM(Grp3Value) Grp3Value FROM ( SELECT UPPER(FORMAT(TSH.ColDate,''MMM yyyy'')) ColDate,'
set @InitialQuery += case when @Grp2Type = 1 then 'ISNULL(TSH.BeatID,0) Grp2ID,MB.Name Grp2Name,' when @Grp2Type = 2 then 'ISNULL(TSH.SalesmanID,0) Grp2ID,MSM.Name Grp2Name,'
when @Grp2Type = 3 then 'MC.ID Grp2ID,MC.Name Grp2Name,' else 'ISNULL(mct.ID,0) Grp2ID,mct.Name Grp2Name,' END
set @InitialQuery +='SUM(TSH.ColAmt) AS Grp3Value
FROM tblTranCollectionHeader AS TSH
JOIN tblMasterCustomer AS MC ON MC.FAID = TSH.AccID
left join tblMasterCustomerType as mct on mct.ID=MC.CustomerType
LEFT JOIN tblMasterBeat AS MB ON MB.ID = TSH.BeatID
LEFT JOIN tblMasterSalesMan AS MSM ON MSM.ID = TSH.SalesManId
WHERE TSH.DocPrefix= 19 AND TSH.Status IN (1,3,5) AND TSH.ColDate BETWEEN '+' @FromDate '+' AND '+' @ToDate '+''
set @InitialQuery += (case when ISNULL(@Grp2ID,'') = '' then '' else
case when @Grp2Type = 1 then ' and MB.ID IN (SELECT * FROM string_split('+' @Grp2ID '+','+''','''+'))'
when @Grp2Type = 2 then ' and MSM.ID IN (SELECT * FROM string_split('+' @Grp2ID '+','+''','''+'))'
when @Grp2Type = 3 then ' and MC.ID IN (SELECT * FROM string_split('+' @Grp2ID '+','+''','''+'))'
when @Grp2Type = 4 then ' and MCT.ID IN (SELECT * FROM string_split('+' @Grp2ID '+','+''','''+'))'
END
END)
set @InitialQuery +='GROUP BY TSH.ColDate,' + case when @Grp2Type = 1 then 'TSH.BeatID,MB.Name' when @Grp2Type = 2 then 'TSH.SalesmanID,MSM.Name'
when @Grp2Type = 3 then 'MC.ID,MC.Name' else 'mct.ID,mct.Name' END
set @InitialQuery += ') as rec group by ColDate,Grp2Name,Grp2ID'

insert into #t2
EXEC sys.sp_executesql @InitialQuery, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode, @Grp1Type, @Grp2Type, @Grp2ID, @Grp3Type, @Grp3ID, @Grp4Type, @FromDate, @ToDate

SET @query = 'SELECT Grp2ID,Grp2Name'+@Group2TypeName+',('+@CumativeCol+') AS '+@Group1TypeName+'],'+@PColWithisnull+
' FROM #t2 PIVOT (SUM(Grp3Value) FOR ColDate IN (' + @PCol + ')) AS PivotTable ORDER BY '+@Group2TypeName+' '
EXEC sys.sp_executesql @query, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode, @Grp1Type, @Grp2Type, @Grp2ID, @Grp3Type, @Grp3ID, @Grp4Type, @FromDate, @ToDate

DROP TABLE #t2

END
ELSE IF(@Grp1Type = 5) -- Outstandings
BEGIN
;WITH ALLMonthsCTE AS (
SELECT DATEFROMPARTS(YEAR(@FromDate), MONTH(@FromDate), 1) AS MonthStart
UNION ALL
SELECT DATEADD(MONTH, 1, MonthStart)
FROM ALLMonthsCTE
WHERE DATEADD(MONTH, 1, MonthStart) <= DATEFROMPARTS(YEAR(@Todate), MONTH(@Todate), 1)
)
SELECT @PCol = MonthList FROM (SELECT STRING_AGG(FORMAT(MonthStart, '[MMM yyyy]'), ', ') WITHIN GROUP (ORDER BY MonthStart) AS MonthList FROM ALLMonthsCTE) AS RR

;WITH ALLMonthsCTE AS (
SELECT DATEFROMPARTS(YEAR(@FromDate), MONTH(@FromDate), 1) AS MonthStart
UNION ALL
SELECT DATEADD(MONTH, 1, MonthStart)
FROM ALLMonthsCTE
WHERE DATEADD(MONTH, 1, MonthStart) <= DATEFROMPARTS(YEAR(@Todate), MONTH(@Todate), 1)
)
SELECT @PColWithisnull = MonthList FROM (SELECT STRING_AGG('SUM((ISNULL([' + FORMAT(MonthStart, 'MMM yyyy')+ '],0))) AS [' + FORMAT(MonthStart, 'MMM yyyy')+ ']', ', ')

WITHIN GROUP (ORDER BY MonthStart) AS MonthList FROM ALLMonthsCTE) AS RR
;WITH ALLMonthsCTE AS (
SELECT DATEFROMPARTS(YEAR(@FromDate), MONTH(@FromDate), 1) AS MonthStart
UNION ALL
SELECT DATEADD(MONTH, 1, MonthStart)
FROM ALLMonthsCTE
WHERE DATEADD(MONTH, 1, MonthStart) <= DATEFROMPARTS(YEAR(@Todate), MONTH(@Todate), 1)
)
SELECT @CumativeCol = MonthList FROM (SELECT STRING_AGG('sum(ISNULL('+FORMAT(MonthStart, '[MMM yyyy]')+',0))', '+ ') WITHIN GROUP (ORDER BY MonthStart) AS MonthList FROM ALLMonthsCTE) AS RR


create table #t3(InvDate nvarchar(50),Grp1ID int,Grp1Name nvarchar(255),Grp2ID int,Grp2Name nvarchar(255),Grp3Value decimal(25,4),NetAmt decimal(25,4))

set @InitialQuery = ' SELECT InvDate,Grp1ID,Grp1Name,Grp2ID,Grp2Name,SUM(Grp3Value) Grp3Value,SUM(NetAmt) NetAmt FROM (
select UPPER(FORMAT(SH.InvDate,''MMM yyyy'')) InvDate,round((SUM(SD.NetAmt) / NULLIF(SH.NetAmt,0)) * SH.Balance,0) Grp3Value,
round(SUM(SD.NetAmt),0) NetAmt'
set @InitialQuery += case when @Grp3Type = 0 then ',0 Grp1ID,null Grp1Name' when @Grp3Type = 1 then ',MP.MfrID Grp1ID,MANUF.Name Grp1Name' when @Grp3Type = 2 then ',MP.BrandID Grp1ID,MBR.Name Grp1Name'
when @Grp3Type = 3 then ',MP.CategoryID Grp1ID,MCAT.Name Grp1Name' else ',MP.ID Grp1ID,MP.Name Grp1Name' END
set @InitialQuery += case when @Grp2Type = 0 then ',0 Grp2ID,null Grp2Name' when @Grp2Type = 1 then ',ISNULL(SH.BeatID,0) Grp2ID,MB.Name Grp2Name' when @Grp2Type = 2 then ',ISNULL(SH.SalesmanID,0) Grp2ID,SM.Name Grp2Name'
when @Grp2Type = 3 then ',MC.ID Grp2ID,MC.Name Grp2Name' else ',ISNULL(MCT.ID,0) Grp2ID,MCT.Name Grp2Name' END
set @InitialQuery += ' from tblTranSalesHeader SH
JOIN tblTranSalesDetail SD ON SD.InvID = SH.ID
JOIN tblMasterCustomer MC ON MC.ID = SH.CustID
LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatID
LEFT JOIN tblMasterSalesman SM ON SM.ID = SH.SalesManID
LEFT JOIN tblMasterCustomerType MCT ON MCT.ID = MC.CustomerType

JOIN tblMasterProduct MP ON MP.ID = SD.ProdID
JOIN tblMasterManufacturer MANUF ON MANUF.ID = MP.MfrID
JOIN tblMasterBrand MBR ON MBR.ID = MP.BrandID
JOIN tblMasterCategory MCAT ON MCAT.ID = MP.CategoryID
WHERE SH.STATUS NOT IN (2,4) and SH.DocPrefix = 15 AND  SH.Balance > 0 AND SD.TaxID > 0 AND 
SH.InvDate BETWEEN '+' @FromDate '+' AND '+' @ToDate '+''
set @InitialQuery += (case when ISNULL(@Grp2ID,'') = '' or @Grp2Type = 0 then '' else
case when @Grp2Type = 1 then ' and MB.ID IN (SELECT * FROM string_split('+' @Grp2ID '+','+''','''+'))'
when @Grp2Type = 2 then ' and SM.ID IN (SELECT * FROM string_split('+' @Grp2ID '+','+''','''+'))'
when @Grp2Type = 3 then ' and MC.ID IN (SELECT * FROM string_split('+' @Grp2ID '+','+''','''+'))'
when @Grp2Type = 4 then ' and MCT.ID IN (SELECT * FROM string_split('+' @Grp2ID '+','+''','''+'))'
END END)
set @InitialQuery += (case when ISNULL(@Grp3ID,'') = '' or @Grp3Type = 0 then '' else
case when @Grp3Type = 1 then ' and MP.MfrID IN (SELECT * FROM string_split('+' @Grp3ID '+','+''','''+'))'
when @Grp3Type = 2 then ' and MP.BrandID IN (SELECT * FROM string_split('+' @Grp3ID '+','+''','''+'))'
when @Grp3Type = 3 then ' and MP.CategoryID IN (SELECT * FROM string_split('+' @Grp3ID '+','+''','''+'))'
when @Grp3Type = 4 then ' and MP.ID IN (SELECT * FROM string_split('+' @Grp3ID '+','+''','''+'))'
END
END)
set @InitialQuery += 'GROUP BY SH.InvDate' + case when @Grp2Type = 0 then ''
when @Grp2Type = 1 then ',SH.BeatID,MB.Name,SH.Balance,SH.NetAmt'
when @Grp2Type = 2 then ',SH.SalesmanID,SM.Name,SH.Balance,SH.NetAmt'
when @Grp2Type = 3 then ',MC.ID,MC.Name,SH.Balance,SH.NetAmt' else ',MCT.ID,MCT.Name,SH.Balance,SH.NetAmt' END

set @InitialQuery +=  (case when @Grp3Type = 0 then '' 
when @Grp3Type = 1 then ',MP.MfrID,MANUF.Name,SH.Balance,SH.NetAmt' 
when @Grp3Type = 2 then ',MP.BrandID,MBR.Name,SH.Balance,SH.NetAmt'
when @Grp3Type = 3 then ',MP.CategoryID,MCAT.Name,SH.Balance,SH.NetAmt' 
else ',MP.ID,MP.Name,SH.Balance,SH.NetAmt' END)

set @InitialQuery += ') as rec group by InvDate,Grp1ID,Grp1Name,Grp2ID,Grp2Name'

insert into #t3
EXEC sys.sp_executesql @InitialQuery, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode, @Grp1Type, @Grp2Type, @Grp2ID, @Grp3Type, @Grp3ID, @Grp4Type, @FromDate, @ToDate

    SET @query = 'SELECT '+
case when @Grp3Type = 0 then '' else ' Grp1ID,' end +
case when @Grp2Type = 0 then '' else ' Grp2ID,' end +
case when @Grp3Type = 0 then '' else 'Grp1Name'+@Group3TypeName+',' end +
case when @Grp2Type = 0 then '' else 'Grp2Name'+@Group2TypeName+',' end +'SUM(NetAmt) [Invoice Value],('+@CumativeCol+') AS '+@Group1TypeName+'],'+@PColWithisnull+
    ' FROM #t3 PIVOT (SUM(Grp3Value) FOR InvDate IN (' + @PCol + ')) AS PivotTable '
    SET @query += (CASE WHEN @Grp2Type = 0 AND @Grp3Type = 0 THEN ''
    WHEN @Grp2Type = 0 AND @Grp3Type != 0 THEN 'GROUP BY Grp1ID,Grp1Name'
    WHEN @Grp2Type != 0 AND @Grp3Type = 0 THEN 'GROUP BY Grp2ID,Grp2Name'
    WHEN @Grp2Type != 0 AND @Grp3Type != 0 THEN 'GROUP BY Grp1ID,Grp1Name,Grp2ID,Grp2Name'
    ELSE '' END)+'    
    HAVING ('+@CumativeCol+') > 0
    ORDER BY '+case when @Grp3Type = 0 then '' else @Group3TypeName end +
case when @Grp2Type > 0 and @Grp3Type > 0 then ',' else '' end+
case when @Grp2Type = 0 then '' else @Group2TypeName end
    EXEC sys.sp_executesql @query, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode, @Grp1Type, @Grp2Type, @Grp2ID, @Grp3Type, @Grp3ID, @Grp4Type, @FromDate, @ToDate

drop table #t3
END
ELSE IF(@Grp1Type in (6,7)) -- Purchase,PR
BEGIN

set @InitialQuery = '
SELECT InvDate,Grp1ID,Grp1Name,Grp2ID,Grp2Name,SUM(Grp3Value) Grp3Value FROM (
select UPPER(FORMAT(SH.Date,''MMM yyyy'')) InvDate'
set @InitialQuery += case when @Grp3Type = 0 then ',0 Grp1ID,null Grp1Name' when @Grp3Type = 1 then ',MP.MfrID Grp1ID,MANUF.Name Grp1Name' when @Grp3Type = 2 then ',MP.BrandID Grp1ID,MBR.Name Grp1Name'
when @Grp3Type = 3 then ',MP.CategoryID Grp1ID,MCAT.Name Grp1Name' else ',MP.ID Grp1ID,MP.Name Grp1Name' END

set @InitialQuery += case when @Grp2Type = 0 then ',0 Grp2ID,null Grp2Name' when @Grp2Type = 1 then ',ISNULL(SH.VendorID,0) Grp2ID,MC.Name Grp2Name'
else '' END

set @InitialQuery += case when @Grp4Type = 1 then ',SUM(SD.UOMQty) Grp3Value ' when @Grp4Type = 2 then ',SUM(SD.GrossAmt) Grp3Value ' else
',SUM(SD.NetAmt) Grp3Value' end
-- AND SH.DocPrefix = 15
set @InitialQuery += ' from tblTransPurchaseHeader SH
JOIN tblTransPurchaseDetail SD ON SD.HID = SH.ID
JOIN tblMasterVendor MC ON MC.ID = SH.VendorID
JOIN tblMasterProduct MP ON MP.ID = SD.ProdID
JOIN tblMasterManufacturer MANUF ON MANUF.ID = MP.MfrID
JOIN tblMasterBrand MBR ON MBR.ID = MP.BrandID
JOIN tblMasterCategory MCAT ON MCAT.ID = MP.CategoryID
WHERE SH.STATUS NOT IN (2,4) AND SH.Date BETWEEN '+' @FromDate '+' AND '+' @ToDate '+''
-- AND ISNULL(SD.TaxId,0)>0
set @InitialQuery += case when @Grp1Type = 6 then ' and SH.TransID = 1 ' when @Grp1Type = 7 then ' and TransID = 12 '
else '' end

set @InitialQuery += (case when ISNULL(@Grp3ID,'') = '' or @Grp3Type = 0 then '' else
case when @Grp3Type = 1 then ' and MP.MfrID IN (SELECT * FROM string_split('+' @Grp3ID '+','+''','''+'))'
when @Grp3Type = 2 then ' and MP.BrandID IN (SELECT * FROM string_split('+' @Grp3ID '+','+''','''+'))'
when @Grp3Type = 3 then ' and MP.CategoryID IN (SELECT * FROM string_split('+' @Grp3ID '+','+''','''+'))'
when @Grp3Type = 4 then ' and MP.ID IN (SELECT * FROM string_split('+' @Grp3ID '+','+''','''+'))'
END
END)

set @InitialQuery += (case when ISNULL(@Grp2ID,'') = '' or @Grp2Type = 0 then '' else
case when @Grp2Type = 1 then ' and MC.ID IN (SELECT * FROM string_split('+' @Grp2ID '+','+''','''+'))'
END
END)

set @InitialQuery += 'GROUP BY SH.Date' +(case when @Grp3Type = 0 then '' when @Grp3Type = 1 then ',MP.MfrID,MANUF.Name' when @Grp3Type = 2 then ',MP.BrandID,MBR.Name'
when @Grp3Type = 3 then ',MP.CategoryID,MCAT.Name' else ',MP.ID,MP.Name' END)

set @InitialQuery += case when @Grp2Type = 0 then '' when @Grp2Type = 1 then ',SH.VendorID,MC.Name'
else '' END

set @InitialQuery += ') as rec group by InvDate,Grp1ID,Grp1Name,Grp2ID,Grp2Name'--Grp1ID,Grp1Name,Grp2ID,Grp2Name'

--select @InitialQuery

insert into #t1
EXEC sys.sp_executesql @InitialQuery, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode, @Grp1Type, @Grp2Type, @Grp2ID, @Grp3Type, @Grp3ID, @Grp4Type, @FromDate, @ToDate

SET @query = 'SELECT '+
case when @Grp3Type = 0 then '' else ' Grp1ID,' end +
case when @Grp2Type = 0 then '' else ' Grp2ID,' end +
case when @Grp3Type = 0 then '' else 'Grp1Name'+@Group3TypeName+',' end +
case when @Grp2Type = 0 then '' else 'Grp2Name'+@Group2TypeName+',' end +
'('+@CumativeCol+') AS '+@Group1TypeName+@Group4TypeName+'],'+@PColWithisnull+
' FROM #t1 PIVOT (SUM(Grp3Value) FOR InvDate IN (' + @PCol + ')) AS PivotTable ORDER BY '+case when @Grp3Type = 0 then '' else @Group3TypeName end +
case when @Grp2Type > 0 and @Grp3Type > 0 then ',' else '' end+
case when @Grp2Type = 0 then '' else @Group2TypeName end
EXEC sys.sp_executesql @query, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode, @Grp1Type, @Grp2Type, @Grp2ID, @Grp3Type, @Grp3ID, @Grp4Type, @FromDate, @ToDate
END
drop table #t1
END
END
GO

/****** uspNilStockHeader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--uspNilStockHeader 0,'','','','126',1500 
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspNilStockHeader]      
@BranchName int = 0,@ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',@ProductName NVARCHAR(255)='',        
@Qty DECIMAL(25,4) = 0      
as      
begin      
DECLARE @query NVARCHAR(MAX)      
set @query = '      
SELECT ProductID,BranchID,[Branch Name],Code,Name,EAN,[MfrID],[Mfr Name],[BrandID],[Brand Name],[CategoryID],[Category Name],      
dbo.fngetroundedvalue(isnull(SUM(Qty),0)) Qty,dbo.fngetroundedvalue(isnull(SUM([Free Qty]),0)) [Free Qty],    
dbo.fngetroundedvalue(isnull(SUM([Dmg Qty]),0)) [Dmg Qty],      
format(MAX([Last Sale Date]),''dd-MMM-yyyy'') [Last Sale Date]  FROM (    
SELECT PIN.ProdId ProductID,PIN.BranchID,MBR.Name [Branch Name],mp.Code,mp.Name,mp.EAN,MF.ID[MfrID],MF.Name [Mfr Name],MB.ID[BrandID],MB.Name [Brand Name],MC.ID[CategoryID],MC.Name [Category Name],      
(isnull(SUM(ActualQty),0)) + isnull(SUM(isnull(VLD.UomQty,0)- isnull(VLD.VLSMQty,0) + isnull(VLD.VLSRetrunQty,0)),0) Qty,
(isnull(SUM(ActualFreeQty),0)) [Free Qty],    
(isnull(SUM(ActualDmgQty),0)) [Dmg Qty],      
(SELECT (MAX(SH.InvDate)) FROM TBLTRANSALESDETAIL SD
LEFT JOIN TBLTRANSALESHEADER SH ON SH.ID = SD.InvID AND STATUS IN (1,3,5)
AND DocPrefix = 15 WHERE SD.PRODID = PIN.PRODID ) [Last Sale Date]      
FROM tblProductInventory PIN      
JOIN tblMasterProduct MP ON MP.ID = PIN.ProdId      
JOIN tblMasterBranchOffice MBR ON MBR.ID = PIN.BranchID      
JOIN TBLMASTERMANUFACTURER AS MF ON MF.ID = MP.MfrID      
JOIN tblMasterBrand AS MB ON MB.ID = MP.BrandID      
JOIN TBLMASTERCATEGORY AS MC ON MC.ID = MP.CategoryID    
LEFT JOIN tblVanLoadingSlipDetail VLD ON VLD.InventoryID = PIN.InventoryId  
GROUP BY PIN.ProdId,mp.Code,mp.Name,mp.EAN,MF.Name,MB.Name,MC.Name,MBR.Name,PIN.BranchID,MF.ID,MC.ID,MB.ID ) AS REC '    
set @query += ' WHERE (ISNULL(Qty,0) <=  @Qty )'    
 set @query += case when ISNULL(@BranchName,'') = '' then '' else ' AND BranchID = '+' @BranchName '+'' END        
 set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND [BrandID] IN (SELECT * from dbo.fnSplitString( '+' @BrandName ,'',''))' END        
 set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND [CategoryID] IN (SELECT * from dbo.fnSplitString( '+' @CategoryName ,'',''))' END        
 set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND [MfrID] IN (SELECT * from dbo.fnSplitString( '+' @ManufName ,'',''))' END        
 set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND ProductID IN (SELECT * from dbo.fnSplitString( '+' @ProductName ,'',''))' END      
 set @query += ' GROUP BY ProductID,BranchID,[Branch Name],Code,Name,EAN,[Mfr Name],[Brand Name],[Category Name],[MfrID],[CategoryID],[BrandID]    
order by Name '    
PRINT @query
 EXEC sys.sp_executesql @query, N'@BranchName int, @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @Qty DECIMAL(25,4)', @BranchName, @ManufName, @BrandName, @CategoryName, @ProductName, @Qty      
end
GO

/****** uspProductBatchHistoryHeader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspProductBatchHistoryHeader]    
 @ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',@ProductName NVARCHAR(255) = ''    
 AS    
 BEGIN    
declare @StrQuery nvarchar(max) = ''        
 set @StrQuery = '     
select MP.ID ProductID,MP.Code,MP.Name,MF.Name [Mfr Name],MB.Name Brand,MC.Name Category,    
dbo.fngetroundedvalue(sum(ISNULL(PV.ActualQty,0))) [Actual Qty],
dbo.fngetroundedvalue((ISNULL([VLS Closing],0))) [VLS Closing],
dbo.fngetroundedvalue(sum(ISNULL(PV.ActualFreeQty,0))) [Actual Free Qty],    
dbo.fngetroundedvalue(sum(ISNULL(PV.ActualDmgQty,0))) [Actual Dmg Qty] from tblMasterProduct MP    
LEFT join tblProductInventory PV ON PV.ProdID = MP.ID    
JOIN tblMasterManufacturer MF ON MF.ID = MP.MfrID    
JOIN tblMasterBrand MB ON MB.ID = MP.BrandID    
JOIN tblMasterCategory MC ON MC.ID = MP.CategoryID
LEFT JOIN vVLSQty ViewVLS ON ViewVLS.ProductID = MP.ID
WHERE MP.ACTIVE IN (0,1) '    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ManufName,'')='' THEN '' ELSE ' AND MF.ID IN (SELECT * from dbo.fnSplitString (  @ManufName ,'',''))' END)             
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BrandName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString (   @BrandName ,'',''))' END)                
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CategoryName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString (   @CategoryName ,'',''))' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ProductName,'')='' THEN '' ELSE ' AND MP.ID IN (SELECT * from dbo.fnSplitString (   @ProductName ,'',''))' END)       
SET @StrQuery = @StrQuery +  ' group by MP.ID,MP.Code,MP.Name,MF.Name,MB.Name,MC.Name,[VLS Closing] order BY MP.Name '    
EXEC sys.sp_executesql @StrQuery, N'@ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255)', @ManufName, @BrandName, @CategoryName, @ProductName    
 END
GO

/****** uspProductWiseCustomerWiseSalesDetail ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspProductWiseCustomerWiseSalesDetail]        
@ProductID int = 123,@ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',@ProductName NVARCHAR(255) = '',@BeatName NVARCHAR(255) = '',      
@SalesmanName NVARCHAR(255) = '',@CustomerName NVARCHAR(255) = '',@CustomerType NVARCHAR(255) = '',@Ratings NVARCHAR(255)='', @FromDate DATE = '2025-07-01',      
@ToDate DATE = '2025-08-30'         
AS        
BEGIN        
declare @StrQuery nvarchar(max) = ''        
set @StrQuery = ' SELECT MP.Name [Product Name],(tsh.DocId) [Doc ID],            
FORMAT(TSH.InvDate,''dd-MMM-yyyy'') as [Doc Date],TSH.DocRef as [Ref No],mb.name [Beat Name],sm.name [Salesman Name],MC.Name as [Customer Name],mct.Name [Customer Type]      
,RT.Ratingname Ratings,         
dbo.fnGetRoundedValue(sum(TSD.UomQty * MP.BaseCR)) as [Qty],dbo.fnGetRoundedValue(sum(TSD.NetAmt)) as [Net Amount]             
FROM tblTranSalesHeader TSH             
JOIN tblTranSalesDetail TSD ON TSD.InvId = TSH.ID            
LEFT JOIN tblMasterCustomer MC ON MC.ID = TSH.CustId            
LEFT JOIN tblMasterProduct MP ON MP.ID = TSD.ProdId            
LEFT JOIN tblMasterManufacturer MF ON MF.ID = MP.MfrID            
LEFT JOIN tblMasterBeat MB ON MB.ID = TSH.BeatID        
LEFT JOIN tblMasterSalesman SM ON SM.ID = TSH.SalesmanID        
left join tblMasterCustomerType as mct on mct.ID=MC.CustomerType       
LEFT JOIN tblRatings AS RT ON RT.ID = MC.Rating       
WHERE TSH.DocPrefix = 15 AND Status IN (1,3,5) and TSD.ProdID =  @ProductID '       
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN  @FromDate  AND  @ToDate )' END)                  
  
    
      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString(  @CustomerName ,'',''))' END)                            
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString(  @BeatName ,'',''))' END)                
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SM.ID IN (SELECT * from dbo.fnSplitString(  @SalesmanName ,'',''))' END)             
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN (SELECT * from dbo.fnSplitString(  @CustomerType ,'',''))' END)                
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN (SELECT * from dbo.fnSplitString(  @Ratings ,'',''))' END)       
SET @StrQuery = @StrQuery + ' group by MC.ID,MC.Name,TSH.DocId,TSH.InvDate,TSH.DocRef,mb.name,sm.name,mct.Name,RT.Ratingname,MP.Name '      
EXEC sys.sp_executesql @StrQuery, N'@ProductID int, @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @FromDate DATE, @ToDate DATE', @ProductID, @ManufName, @BrandName, @CategoryName, @ProductName, @BeatName, @SalesmanName, @CustomerName, @CustomerType, @Ratings, @FromDate, @ToDate      
end
GO

/****** uspProductWiseCustomerWiseSalesHeader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspProductWiseCustomerWiseSalesHeader]      
@ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',@ProductName NVARCHAR(255) = '',@BeatName NVARCHAR(255) = '',    
@SalesmanName NVARCHAR(255) = '',@CustomerName NVARCHAR(255) = '',@CustomerType NVARCHAR(255) = '',@Ratings NVARCHAR(255)='', @FromDate DATE = '2025-07-01',    
@ToDate DATE = '2025-08-30'       
AS    
BEGIN    
declare @StrQuery nvarchar(max) = ''      
set @StrQuery = 'select ProdID ProductID,[Mfr Name],[Brand Name],[Category Name],[Product Name]      
,COUNT([Inv Count]) as [Inv Count],dbo.fnGetRoundedValue(SUM([Total Qty])) AS [Total Qty],dbo.fnGetRoundedValue(SUM([Net Amt])) [Net Amount] from (      
SELECT MP.ID AS ProdID,MF.Name as  [Mfr Name] ,      
MB.Name [Brand Name],PHL.Name [Category Name],mp.Name as [Product Name],(tsh.ID) [Inv Count],      
SUM(TSD.UomQty * MP.BaseCR) as [Total Qty],sum(TSD.NetAmt) as [Net Amt]      
FROM tblTranSalesHeader TSH      
JOIN tblTranSalesDetail TSD ON TSD.InvId = TSH.ID      
JOIN tblMasterCustomer MC ON MC.ID = TSH.CustId      
JOIN tblMasterProduct MP ON MP.ID = TSD.ProdId      
JOIN tblMasterManufacturer MF ON MF.ID = MP.MfrID      
JOIN tblMasterBrand MB ON MB.ID = MP.BrandID      
JOIN tblMasterCategory PHL ON PHL.ID = MP.CategoryID      
left join tblMasterCustomerType as mct on mct.ID=MC.CustomerType     
LEFT JOIN tblRatings AS RT ON RT.ID = MC.Rating     
LEFT JOIN TBLMASTERBEAT Beat ON Beat.ID = TSH.BeatID    
LEFT JOIN tblMasterSalesman SM ON SM.ID = TSH.SalesManID    
WHERE TSH.DocPrefix = 15 AND Status IN (1,3,5) '    
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN  @FromDate  AND  @ToDate )' END)                  
  
    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN(SELECT * from dbo.fnSplitString(  @CustomerName ,'',''))' END)                          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND Beat.ID IN(SELECT * from dbo.fnSplitString(  @BeatName ,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SM.ID IN(SELECT * from dbo.fnSplitString(  @SalesmanName ,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN(SELECT * from dbo.fnSplitString(  @CustomerType ,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN(SELECT * from dbo.fnSplitString(  @Ratings ,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ManufName,'')='' THEN '' ELSE ' AND MF.ID IN(SELECT * from dbo.fnSplitString(  @ManufName ,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BrandName,'')='' THEN '' ELSE ' AND MB.ID IN(SELECT * from dbo.fnSplitString(  @BrandName ,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CategoryName,'')='' THEN '' ELSE ' AND PHL.ID IN(SELECT * from dbo.fnSplitString(  @CategoryName ,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ProductName,'')='' THEN '' ELSE ' AND MP.ID IN(SELECT * from dbo.fnSplitString(  @ProductName ,'',''))' END)       
SET @StrQuery = @StrQuery + ' group by MP.ID,MF.ID,MF.Name,mp.Name,tsh.ID,MB.Name,PHL.Name) as nk      
group by ProdID,[Mfr Name],[Product Name],[Brand Name],[Category Name]'    
EXEC sys.sp_executesql @StrQuery, N'@ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @FromDate DATE, @ToDate DATE', @ManufName, @BrandName, @CategoryName, @ProductName, @BeatName, @SalesmanName, @CustomerName, @CustomerType, @Ratings, @FromDate, @ToDate    
END
GO

/****** uspReasonwiseAnalysisHeader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspReasonwiseAnalysisHeader]  
@ReasonName nvarchar(255) = '0',@FromDate date ='2025-08-01',@ToDate date = '2025-12-30'  
as  
begin  
SET DATEFORMAT dmy;        
declare @StrQuery nvarchar(max) = ''      
 set @StrQuery = '   
select SD.ReasonID,RSN.Name,dbo.fnGetRoundedValue(sum(isnull(SD.DiffValue,0))) [Excl Diff Amt],  
dbo.fnGetRoundedValue(sum(isnull(SD.DiffValue,0) + ((isnull(SD.DiffValue,0) * TaxValue) / 100))) [Incl Diff Amt] from tblTranSalesHeader SH  
JOIN tblTranSalesDetail SD ON SD.InvID = SH.ID  
left JOIN tblMasterReason RSN ON RSN.ID = SD.ReasonID  
WHERE DocPrefix = 15 AND Status IN (1,3,5) '  
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (SH.InvDate BETWEEN  @FromDate  AND  @ToDate )' END)                   
   
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ReasonName,'0')='0' THEN '' ELSE ' AND SD.ReasonID =  @ReasonName ' END)     
SET @StrQuery = @StrQuery + ' group by SD.ReasonID,RSN.Name ORDER BY RSN.Name'  
EXEC sys.sp_executesql @StrQuery, N'@ReasonName nvarchar(255), @FromDate date, @ToDate date', @ReasonName, @FromDate, @ToDate  
end  
GO

/****** uspRepAccountLedger ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--uspRepAccountLedger '1,2','2025-02-01','2025-12-01'            
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspRepAccountLedger]          
@AccountName nvarchar(max) = null ,@FromDate date = null,@ToDate DATE = NULL,@Showall nvarchar(max) = null      
as              
begin              
DECLARE @strQuery NVARCHAR(MAX) = ''           
CREATE TABLE #temp([Transaction] nvarchar(255),[Doc ID] nvarchar(255),[Date] nvarchar(255),[Account Name] nvarchar(255),    
[Credit] decimal(25,2),[Debit] decimal(25,2),[Remarks] nvarchar(255),[Narration] nvarchar(255),[Status] nvarchar(255))    
SET @strQuery = '  select DS.TransName [Transaction],DocID [Doc ID],CONVERT(nvarchar,FAJ.DocDate,103) Date,FAA.AccountName [Account Name],    
dbo.fnGetRoundedValue(Credit) Credit,dbo.fnGetRoundedValue(Debit) Debit,Remarks,Narration,STS.Description Status from tblFAJournal FAJ          
JOIN tblFAAccount FAA ON FAA.FAID = FAJ.AccountID          
  JOIN tblDocumentSeries DS ON DS.TransID = FAJ.DocPrefix          
  JOIN tblStatus STS ON STS.ID = FAJ.Status          
 WHERE FAA.Active IN (0,1)  '            
 SET @strQuery += CASE WHEN ISNULL(@Showall,'') = 'true' THEN '' ELSE ' and FAJ.Status NOT IN (2,4) ' END       
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND FAJ.DocDate BETWEEN '+' @FromDate  AND '+' @ToDate ' END            
SET @strQuery += CASE WHEN ISNULL(@AccountName,'') = '' THEN '' ELSE ' AND FAA.FAID IN (SELECT * from  dbo.fnSplitString( '+' @AccountName ,'',''))' END         
insert into #temp    
EXEC sys.sp_executesql @strQuery, N'@AccountName nvarchar(max), @FromDate date, @ToDate DATE, @Showall nvarchar(max)', @AccountName, @FromDate, @ToDate, @Showall           
if((select count(*) from #temp) > 0)    
BEGIN    
SELECT * INTO  #DATA FROM(  
select [Transaction],[Doc ID],[Date],[Account Name],[Credit],[Debit],[Remarks],[Narration],[Status] from #temp    
union    
select 'Total' [Transaction],''[Doc ID],'' [Date],''[Account Name],dbo.fnGetRoundedValue(sum([Credit])) [Credit],    
dbo.fnGetRoundedValue(sum([Debit])) [Debit],'' [Remarks],'' [Narration],'' [Status] from #temp  ) AS REC  
SELECT * FROM #DATA  
DROP TABLE #DATA  
END    
drop table #temp    
end       
GO

/****** uspRepCustomerMfrAnalysisHeader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--uspRepCustomerMfrAnalysisHeader '1,2,5,13','3,8,24'    
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspRepCustomerMfrAnalysisHeader]    
@BeatIds nvarchar(255) = '',@MfrIds nvarchar(255) = ''    
as    
begin    
-- ============================================================    
-- MERGED REPORT: Overall Mfr Sales/Returns/OS + 30-Days OS Data    
-- Joined on CustID + MfrName    
-- ============================================================    
DECLARE @cols NVARCHAR(MAX) = '';    
DECLARE @colsonly NVARCHAR(MAX) = '';    
DECLARE @query NVARCHAR(MAX) = '';    
--select *,trim(left(Name,5)) from tblMasterManufacturer    
-- Step 1: Build the dynamic column list based on distinct MfrNames    
SELECT @cols = STRING_AGG(    
    CONCAT(    
        'SUM(CASE WHEN MfrName = ''', REPLACE(MfrName, '''', ''''''), ''' THEN MfrSalesAmt ELSE 0 END) AS [', REPLACE(MfrName, ']', ']]'), ' Sales], ',    
        'SUM(CASE WHEN MfrName = ''', REPLACE(MfrName, '''', ''''''), ''' THEN MfrSalesReturnAmt ELSE 0 END) AS [', REPLACE(MfrName, ']', ']]'), ' SR], ',    
        'SUM(CASE WHEN MfrName = ''', REPLACE(MfrName, '''', ''''''), ''' THEN MfrDamageReturnAmt ELSE 0 END) AS [', REPLACE(MfrName, ']', ']]'), ' DR],',    
        'SUM(CASE WHEN MfrName = ''', REPLACE(MfrName, '''', ''''''), ''' THEN MfrOSCount ELSE 0 END) AS [', REPLACE(MfrName, ']', ']]'), ' OSCount], ',    
        'SUM(CASE WHEN MfrName = ''', REPLACE(MfrName, '''', ''''''), ''' THEN MfrOSValue ELSE 0 END) AS [', REPLACE(MfrName, ']', ']]'), '  OSValue],',    
        'SUM(CASE WHEN MfrName = ''', REPLACE(MfrName, '''', ''''''), ''' THEN Mfr30DOSCount ELSE 0 END) AS [', REPLACE(MfrName, ']', ']]'), ' 30dCount], ',    
        'SUM(CASE WHEN MfrName = ''', REPLACE(MfrName, '''', ''''''), ''' THEN Mfr30DOSValue ELSE 0 END) AS [', REPLACE(MfrName, ']', ']]'), ' 30dValue] '    
    ), ', '    
),@colsonly = STRING_AGG(    
    CONCAT(    
        'convert(NVARCHAR(50),convert(decimal(18,2),isnull([', REPLACE(MfrName, ']', ']]'), ' Sales],0))) [', REPLACE(MfrName, ']', ']]'), ' Sales], ',    
        'convert(NVARCHAR(50),convert(decimal(18,2),isnull([', REPLACE(MfrName, ']', ']]'), ' SR],0))) [', REPLACE(MfrName, ']', ']]'), ' SR], ',    
        'convert(NVARCHAR(50),convert(decimal(18,2),isnull([', REPLACE(MfrName, ']', ']]'), ' DR],0))) [', REPLACE(MfrName, ']', ']]'), ' DR],',    
        'convert(NVARCHAR(50),isnull([', REPLACE(MfrName, ']', ']]'), ' OSCount],0)) [', REPLACE(MfrName, ']', ']]'), ' OSCount], ',    
        'convert(NVARCHAR(50),convert(decimal(18,2),isnull([', REPLACE(MfrName, ']', ']]'), '  OSValue],0))) [', REPLACE(MfrName, ']', ']]'), ' OSValue],',    
        'convert(NVARCHAR(50),isnull([', REPLACE(MfrName, ']', ']]'), ' 30dCount],0)) [', REPLACE(MfrName, ']', ']]'), ' 30dCount], ',    
        'convert(NVARCHAR(50),convert(decimal(18,2),isnull([', REPLACE(MfrName, ']', ']]'), ' 30dValue],0))) [', REPLACE(MfrName, ']', ']]'), ' 30dValue] '    
    ), ', '    
)    
FROM (SELECT DISTINCT trim(left(MF.Name,5)) AS MfrName FROM tblMasterManufacturer MF     
where @MfrIds = '' OR MF.ID IN (SELECT * FROM string_split(@MfrIds,',')) ) AS DistinctMfr;    
SET @query = '    
WITH Overall AS (    
    SELECT    
        CustID,    
        CustomerName,    
        MfrName,    
        SUM(MfrSalesAmt)        AS MfrSalesAmt,    
        SUM(MfrSalesReturnAmt)  AS MfrSalesReturnAmt,    
        SUM(MfrDamageReturnAmt) AS MfrDamageReturnAmt,    
        (CASE WHEN SUM(MfrOSValue) > 0 THEN COUNT(MfrOSCount) ELSE 0 END) AS MfrOSCount,   
        SUM(MfrOSValue)         AS MfrOSValue    
    FROM (    
        SELECT  DISTINCT SH.ID AS MfrOSCount,   
            SH.CustID,    
            MC.Name AS CustomerName,    
            TRIM(LEFT(MF.Name, 5)) AS MfrName,    
            CASE WHEN DocPrefix = 15 THEN SUM(SD.NetAmt) ELSE 0 END AS MfrSalesAmt,    
            CASE WHEN DocPrefix = 16 AND TransactionType = 2 THEN SUM(SD.NetAmt) ELSE 0 END AS MfrSalesReturnAmt,    
            CASE WHEN DocPrefix = 16 AND TransactionType = 3 THEN SUM(SD.NetAmt) ELSE 0 END AS MfrDamageReturnAmt,                
            (SUM(SD.NetAmt) / NULLIF(SH.NetAmt, 0)) * SH.Balance AS MfrOSValue    
        FROM TBLTRANSALESHEADER SH    
        JOIN tblTranSalesDetail   SD ON SD.InvID = SH.ID    
        JOIN tblMasterProduct     MP ON MP.ID = SD.ProdID    
        JOIN tblMasterManufacturer MF ON MF.ID = MP.MfrID    
        JOIN tblMasterCustomer    MC ON MC.ID = SH.CustID    
        WHERE Status NOT IN (2, 4)  AND SH.Balance > 0
          AND SD.TaxID > 0    
        GROUP BY SH.CustID, MC.Name, MF.Name, DocPrefix, TransactionType,    
                 SH.Balance, SH.NetAmt, SH.InvDate  ,SH.ID  
    ) AS OverallRaw    
    GROUP BY CustID, CustomerName, MfrName
),    
    
Days30 AS (    
    SELECT    
        CustID,    
        MfrName,    
        CustomerName,    
        (CASE WHEN SUM(Mfr30DOSValue) > 0 THEN COUNT(Mfr30DOSCount) ELSE 0 END) AS Mfr30DOSCount,   
        SUM(Mfr30DOSValue) AS Mfr30DOSValue    
    FROM (    
        SELECT  DISTINCT SH.ID AS Mfr30DOSCount,    
            SH.CustID AS CustID,    
            MC.Name AS CustomerName,    
            MP.MfrID,    
            TRIM(LEFT(MF.Name, 5)) AS MfrName,                
            (SUM(SD.NetAmt) / NULLIF(SH.NetAmt, 0)) * SH.Balance AS Mfr30DOSValue    
        FROM tblTranSalesHeader SH    
        JOIN tblTranSalesDetail   SD ON SD.InvID = SH.ID    
        JOIN tblMasterProduct     MP ON MP.ID = SD.ProdID    
        JOIN tblMasterManufacturer MF ON MF.ID = MP.MfrID    
        JOIN tblMasterCustomer    MC ON MC.ID = SH.CustID    
        WHERE DocPrefix = 15    
          AND Status NOT IN (2, 4)    
          AND Balance > 0    
          AND SD.TaxID > 0    
          AND SH.InvDate <= DATEADD(DD, -30, GETDATE())    
        GROUP BY SH.CustID, MP.MfrID, MF.Name, SH.NetAmt, SH.Balance, MC.Name  ,SH.ID  
    ) AS Rec    
    GROUP BY CustID, MfrName, CustomerName    
)    
    
SELECT    
    O.CustID,    
    O.CustomerName,    
    O.MfrName,    
    O.MfrSalesAmt,    
    O.MfrSalesReturnAmt,    
    O.MfrDamageReturnAmt,    
    O.MfrOSCount,    
    O.MfrOSValue,    
    ISNULL(D.Mfr30DOSCount, 0) AS Mfr30DOSCount,    
    ISNULL(D.Mfr30DOSValue, 0) AS Mfr30DOSValue INTO #TEEE    
FROM Overall O    
LEFT JOIN Days30 D    
    ON D.CustID = O.CustID    
   AND D.MfrName = O.MfrName    
ORDER BY O.CustID, O.MfrName    
;WITH BaseData AS (    
SELECT * FROM #TEEE    
),    
Aggregated AS (    
    SELECT CustID, CustomerName, MfrName,    
           SUM(MfrSalesAmt) MfrSalesAmt,    
           SUM(MfrSalesReturnAmt) MfrSalesReturnAmt,    
           SUM(MfrDamageReturnAmt) MfrDamageReturnAmt,    
           SUM(MfrOSCount) MfrOSCount,    
           SUM(MfrOSValue) MfrOSValue ,    
           SUM(Mfr30DOSCount) Mfr30DOSCount,    
           SUM(Mfr30DOSValue) Mfr30DOSValue    
    FROM BaseData    
    GROUP BY CustID, CustomerName, MfrName    
)    
SELECT     
    CustID,    
    CustomerName,' + @cols + ' INTO #SalesOSData    
FROM Aggregated AG    
GROUP BY CustID, CustomerName    
ORDER BY CustomerName    
    
    
SELECT SH.CustID CustomerID,FORMAT(MAX(InvDate),''dd/MM/yyyy'') LastSalesDate,SUM(NETAMT) TotalSales,(SUM(NETAMT) / NULLIF(COUNT(SH.ID), 0)) AvgSales,    
MAX(NETAMT) MaxInvValue,SUM(SH.Balance) TotalOS INTO #SalesData FROM TBLTRANSALESHEADER SH    
JOIN tblMasterCustomer TC ON TC.ID = SH.CustID    
WHERE SH.DocPrefix = 15 AND Status NOT IN (2,4)    
GROUP BY SH.CustID    
  
SELECT CustomerID,COUNT(ID) OS30Count,SUM(OS30D) OS30D into #overall30DOS FROM (  
SELECT DISTINCT SH.ID,SH.CustID CustomerID,  ((SUM(SD.NetAmt) / SH.NetAmt) *  SH.Balance) OS30D  
FROM tblTranSalesHeader SH    
JOIN tblTranSalesDetail SD ON SD.InvID = SH.ID  
JOIN tblMasterCustomer TC ON TC.ID = SH.CustID    
WHERE SH.DocPrefix = 15 AND Status NOT IN (2,4) AND Balance > 0   
AND SH.InvDate <= DATEADD(DD,-30,GETDATE())  
GROUP BY SH.CustID  ,SH.NetAmt, SH.Balance ,SH.ID) AS RECOS30D  
group by CustomerID  
  
SELECT TC.ID CustomerID,CASE WHEN CH.ColMode = 1 THEN SUM(ColAmt) ELSE 0 END Cash,    
CASE WHEN CH.ColMode = 2 THEN SUM(ColAmt) ELSE 0 END Cheque,    
CASE WHEN CH.ColMode = 4 and CH.BTMode IN (3,4) THEN SUM(ColAmt) ELSE 0 END RTGSNEFT,    
CASE WHEN CH.ColMode = 4 and CH.BTMode IN (5) THEN SUM(ColAmt) ELSE 0 END IMPS,    
CASE WHEN CH.ColMode = 4 and CH.BTMode IN (6) THEN SUM(ColAmt) ELSE 0 END UPI  INTO #CollectionData    
FROM tblTranCollectionHeader CH    
JOIN tblMasterCustomer TC ON TC.FAID = CH.AccID    
WHERE CH.DocPrefix = 19 AND Status NOT IN (2,4)    
GROUP BY TC.ID,CH.ColMode,CH.BTMode    
    
SELECT TC.ID CustomerID,LastSalesDate,    
convert(NVARCHAR(50),convert(decimal(18,2),isnull(TotalSales,0))) TotalSales,    
convert(NVARCHAR(50),convert(decimal(18,2),isnull(TotalOS,0))) TotalOS,    
convert(NVARCHAR(50),convert(decimal(18,2),isnull(AvgSales,0))) AvgSales,    
convert(NVARCHAR(50),convert(decimal(18,2),isnull(MaxInvValue,0))) MaxInvValue,    
convert(NVARCHAR(50),isnull(OS30Count,0)) OS30Count,    
convert(NVARCHAR(50),convert(decimal(18,2),isnull(OS30D,0))) OS30DValue,    
convert(NVARCHAR(50),convert(decimal(18,2),isnull(SUM(Cash),0))) Cash,    
convert(NVARCHAR(50),convert(decimal(18,2),isnull(SUM(Cheque),0))) Cheque,    
convert(NVARCHAR(50),convert(decimal(18,2),isnull(SUM(RTGSNEFT),0))) RTGSNEFT,    
convert(NVARCHAR(50),convert(decimal(18,2),isnull(SUM(IMPS),0))) IMPS,    
convert(NVARCHAR(50),convert(decimal(18,2),isnull(SUM(UPI),0))) UPI INTO #SALECOLLMERGEDATA FROM tblMasterCustomer TC     
LEFT JOIN #Collectiondata CD ON CD.CustomerID = TC.ID    
LEFT JOIN #SalesData SALE ON SALE.CustomerID = TC.ID    
LEFT JOIN #overall30DOS OS30d ON OS30d.CustomerID = TC.ID    
GROUP BY TC.ID,TotalSales,TotalOS,AvgSales,MaxInvValue,LastSalesDate ,OS30Count, OS30D  
    
SELECT     
   TC.ID,TC.Code,TC.Name,TC.GSTIN,TC.Mob1,TC.Mob2,CASE WHEN TC.Active = 1 THEN ''Active'' ELSE ''Inactive'' END Active,    
TC.Pincode,PT.PriceType,MCT.Name CustomerType,RT.RatingName Ratings,    
convert(NVARCHAR(50),convert(decimal(18,2),isnull(TC.CreditLimitValue,0))) CreditLimitValue,    
convert(NVARCHAR(50),isnull(TC.CreditLimitCount,0)) CreditLimitCount,    
convert(NVARCHAR(50),convert(decimal(18,2),isnull((TC.OverDueValue),0))) OverDueValue,    
convert(NVARCHAR(50),isnull(TC.OverDueInvCount,0)) OverDueInvCount,    
PM.PaymentMode,MTCT.Name CreditTerm,LastSalesDate,    
TotalSales,TotalOS,AvgSales,MaxInvValue,OS30Count,OS30DValue,Cash,Cheque,RTGSNEFT,IMPS,UPI,    
'+@colsonly+'    
FROM tblMasterCustomer TC     
LEFT JOIN #SalesOSData AG on TC.ID = AG.CustID    
LEFT JOIN #SALECOLLMERGEDATA SALECD ON SALECD.CustomerID = TC.ID    
LEFT JOIN tblPriceType PT ON PT.ID = TC.PriceTypeID    
LEFT JOIN tblPaymentMode PM ON PM.ID = TC.PaymentModeID              
LEFT JOIN tblMasterCreditTerm MTCT ON MTCT.ID = TC.CreditTermID              
LEFT JOIN tblRatings RT ON RT.ID = TC.Rating     
LEFT JOIN tblMasterCustomerType MCT ON MCT.ID = TC.CustomerType '+    
(CASE WHEN ISNULL(@BeatIds,'') = '' THEN '' ELSE 'JOIN tblBeatSalesmanMapping BSM ON BSM.CustomerID = TC.ID     
WHERE BSM.BeatID in (select * from string_split( @BeatIds ,'','')) ' END) +'    
ORDER BY TC.Name    
    
DROP TABLE #TEEE,#SalesOSData,#Collectiondata,#SalesData,#SALECOLLMERGEDATA,#overall30DOS'    
-- Step 3: Execute    
    
EXEC sys.sp_executesql @query, N'@BeatIds nvarchar(255), @MfrIds nvarchar(255)', @BeatIds, @MfrIds;    
end  
GO

/****** uspRepCustomerProductSales ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspRepCustomerProductSales]    
@CustorProdWise int = 2,@BeatName NVARCHAR(255) = '',@SalesmanName NVARCHAR(255) = '',@CustomerName NVARCHAR(255) = '',    
@ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',@ProductName NVARCHAR(255)='',    
@FromDate DATE = '2025-01-01', @Todate DATE = '2025-05-31',@ValueType int = 1    
AS    
BEGIN    
DECLARE @query NVARCHAR(MAX), @PCol NVARCHAR(MAX),@PColWithisnull nvarchar(max);    
declare @RoundOff int    
SELECT @RoundOff=AppValue FROM tblAppConfig WHERE AppId=8;    
WITH ALLMonthsCTE AS (    
    SELECT DATEFROMPARTS(YEAR(@FromDate), MONTH(@FromDate), 1) AS MonthStart    
    UNION ALL    
    SELECT DATEADD(MONTH, 1, MonthStart)    
    FROM ALLMonthsCTE    
    WHERE DATEADD(MONTH, 1, MonthStart) <= DATEFROMPARTS(YEAR(@Todate), MONTH(@Todate), 1)    
)    
    
SELECT @PCol = MonthList FROM (SELECT STRING_AGG(FORMAT(MonthStart, '[MMM yyyy]'), ', ') WITHIN GROUP (ORDER BY MonthStart) AS MonthList FROM ALLMonthsCTE) AS RR    
;WITH ALLMonthsCTE AS (    
    SELECT DATEFROMPARTS(YEAR(@FromDate), MONTH(@FromDate), 1) AS MonthStart    
    UNION ALL    
    SELECT DATEADD(MONTH, 1, MonthStart)    
    FROM ALLMonthsCTE    
    WHERE DATEADD(MONTH, 1, MonthStart) <= DATEFROMPARTS(YEAR(@Todate), MONTH(@Todate), 1)    
)    
SELECT @PColWithisnull = MonthList FROM (SELECT STRING_AGG('dbo.fnGetRoundedValue(ISNULL([' + FORMAT(MonthStart, 'MMM yyyy')+ '],0)) AS [' + FORMAT(MonthStart, 'MMM yyyy')+ ']', ', ')     
WITHIN GROUP (ORDER BY MonthStart) AS MonthList FROM ALLMonthsCTE) AS RR    
    
print @PCol    
print @PColWithisnull     
SET @query = ' WITH MonthlyData AS (SELECT '    
set @query += case when @CustorProdWise = 1 then 'MB.Name [Beat Name],MS.Name [Salesman Name],MC.Name AS [Customer Name]'    
else 'MF.Name [Mfr Name],BRND.Name [Brand Name],CAT.NAME [Category Name],MP.Name AS [Product Name]' end    
set @query += ',FORMAT(SH.InvDate, ''MMM yyyy'') AS MonthYear,    
    '+ case when @ValueType =2 then 'isnull(sum(SD.GrossAmt),0) ' when @ValueType = 1  then ' isnull(sum(SD.NetAmt),0)' else ' isnull(sum(SD.UOMQty),0)' end +' Value    
    FROM tblTranSalesHeader SH    
    JOIN tblTranSalesDetail SD ON SD.InvID = SH.ID    
    JOIN tblMasterCustomer MC ON MC.ID = SH.CustID    
 JOIN tblMasterProduct MP ON MP.ID = SD.ProdID    
 JOIN tblMasterManufacturer MF ON MF.ID = MP.MfrID    
 JOIN tblMasterBrand BRND ON BRND.ID = MP.BrandID    
 JOIN tblMasterCategory CAT ON CAT.ID = MP.CategoryID    
 LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatID    
 LEFT JOIN tblMasterSalesman MS ON MS.ID = SH.SalesManID    
    WHERE SH.Status IN (1,3,5) AND SH.DocPrefix = 15     
    AND SH.InvDate BETWEEN '+' @FromDate '+' AND '+' @Todate '+''    
 set @query += case when ISNULL(@CustomerName,'') = '' then '' else ' AND MC.ID IN(SELECT * from dbo.fnSplitString( '+' @CustomerName ,'',''))' END    
 set @query += case when ISNULL(@BeatName,'') = '' then '' else ' AND MB.ID IN(SELECT * from dbo.fnSplitString(  '+' @BeatName ,'',''))' END    
 set @query += case when ISNULL(@SalesmanName,'') = '' then '' else ' AND MS.ID IN(SELECT * from dbo.fnSplitString(  '+' @SalesmanName ,'',''))' END    
 set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND BRND.ID IN(SELECT * from dbo.fnSplitString(  '+' @BrandName ,'',''))' END    
 set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND CAT.ID IN(SELECT * from dbo.fnSplitString(  '+' @CategoryName ,'',''))' END    
 set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND MF.ID IN(SELECT * from dbo.fnSplitString(  '+' @ManufName ,'',''))' END    
 set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND MP.ID IN(SELECT * from dbo.fnSplitString(  '+' @ProductName ,'',''))' END    
 set @query += case when @CustorProdWise = 1 then '  group by MC.Name,SH.InvDate,MB.Name,MS.Name) ' else '  group by SH.InvDate,MF.Name,BRND.Name,CAT.NAME,MP.Name)' end    
 set @query += 'SELECT '+case when @CustorProdWise = 1 then ' [Beat Name],[Salesman Name],[Customer Name],'+@PColWithisnull     
 else ' [Mfr Name],[Brand Name],[Category Name],[Product Name],'+@PColWithisnull end+' FROM ( SELECT '    
 set @query += case when @CustorProdWise = 1 then ' [Beat Name],[Salesman Name],[Customer Name]'     
 else ' [Mfr Name],[Brand Name],[Category Name],[Product Name]' end+',MonthYear,isnull(Value,0) Value FROM MonthlyData) AS SourceTable    
    PIVOT (SUM(Value) FOR MonthYear IN (' + @PCol + ')) AS PivotTable;';    
EXEC sys.sp_executesql @query, N'@CustorProdWise int, @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @Todate DATE, @ValueType int', @CustorProdWise, @BeatName, @SalesmanName, @CustomerName, @ManufName, @BrandName, @CategoryName, @ProductName, @FromDate, @Todate, @ValueType;    
END 
GO

/****** uspRepDoubleMasterData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--uspRepDoubleMasterData 4,0
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspRepDoubleMasterData]
@FormID int,@UserID INT = 0
AS
BEGIN
declare @TableName nvarchar(255) = (select TableName from tblTablesNames where ID = @FormID)    
declare @SafeTable NVARCHAR(600) = CASE WHEN OBJECT_ID(@TableName, 'U') IS NOT NULL THEN QUOTENAME(OBJECT_SCHEMA_NAME(OBJECT_ID(@TableName, 'U'))) + '.' + QUOTENAME(OBJECT_NAME(OBJECT_ID(@TableName, 'U'))) END
IF @SafeTable IS NULL AND @TableName IS NOT NULL BEGIN RAISERROR('Master table for this form was not found.', 16, 1); RETURN; END
declare @strQuery NVARCHAR(MAX)   
SET @strQuery = ' select Name [Name],dbo.fngetroundedvalue(Value) Value,case when MB.Active = 1 then ''Yes'' ELSE ''No'' end Active,  
MU.UserName [Created By],CONVERT(NVARCHAR,MB.CDate) [Create Date],  
MUM.UserName [Modify By],CONVERT(NVARCHAR,MB.MDate) [Modify Date] from '+@SafeTable+' MB      
JOIN tblUsers MU ON MU.ID = MB.CBy      
LEFT JOIN tblUsers MUM ON MUM.ID = MB.MBy '
SET @strQuery += CASE WHEN ISNULL(@UserID,0) = 0 THEN '' ELSE 'WHERE MB.CBy =  @UserID ' END
SET @strQuery += ' ORDER BY MB.[Name]'                 
EXEC sys.sp_executesql @strQuery, N'@FormID int, @UserID INT', @FormID, @UserID 
END
GO

/****** uspRepInventoryAdjustmentDetail ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspRepInventoryAdjustmentDetail]  
 @InventoryID int = 67,@BranchName NVARCHAR(255) = '',  @ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',      
@ProductName NVARCHAR(255)='', @FromDate DATE = '2025-09-01', @ToDate DATE = '2025-12-31'  
as  
begin  
DECLARE @query NVARCHAR(MAX)      
set @query = '   
SELECT InventHeader.DocID AS [Doc ID],    
format(InventoryDate,''dd/MMM/yyyy'') AS [Doc Date],product.Code AS [Product Code] ,product.Name AS [Product Name],  
Manuf.Name AS [Mfr Name],MB.Name AS [Brand Name],PHL.Name AS [Category Name],    
[dbo].[fnGetRoundedValue](OrgPurPrice) AS [Original Purchase Price],    
[dbo].[fnGetRoundedValue](OrgQty) AS [Original Purchase Qty] ,[dbo].[fnGetRoundedValue](OrgFreeQty) as [Original Free Qty],    
[dbo].[fnGetRoundedValue](OrgDmgQty) as [Original Damage Qty],    
[dbo].[fnGetRoundedValue](ActualPurPrice)as [Actual Purchase Price],    
[dbo].[fnGetRoundedValue](InvDetail.ActualQty)AS[Actual Qty],    
[dbo].[fnGetRoundedValue](InvDetail.ActualFreeQty)AS[Actual Free Qty]    
,[dbo].[fnGetRoundedValue](InvDetail.ActualDmgQty)AS [Actual Damage Qty],    
[dbo].[fnGetRoundedValue](InvDetail.ActualQty - InvDetail.OrgQty)AS[Actual Qty Difference],    
[dbo].[fnGetRoundedValue](InvDetail.ActualFreeQty - InvDetail.OrgFreeQty)AS[Actual Free Qty Difference],    
[dbo].[fnGetRoundedValue](InvDetail.ActualDmgQty - InvDetail.OrgDmgQty)AS[Actual Damage Qty Difference],    
[dbo].[fnGetRoundedValue]((ActualPurPrice - OrgPurPrice) * ActualQty) as [Actual Price Difference],    
[dbo].[fnGetRoundedValue]((ActualPurPrice - OrgPurPrice) * ActualDmgQty) as [Actual Damage Price Difference],    
[dbo].[fnGetRoundedValue]((InvDetail.ActualQty - InvDetail.OrgQty) * ActualPurPrice) [Final Diff Value],    
[dbo].[fnGetRoundedValue]((InvDetail.ActualDmgQty - InvDetail.OrgDmgQty) * ActualPurPrice) [Final Diff Damage Value],    
[dbo].[fnGetRoundedValue](GrossAmt) AS [Gross Amount] ,rea.Name AS [Reason]    
FROM tblInventoryDetail AS InvDetail  
join tblInventoryHeader as InventHeader on InventHeader.InventoryID = InvDetail.InventoryID  
JOIN tblMasterProduct AS Product  ON InvDetail.ProdID=Product.ID    
JOIN tblMasterBrand MB ON MB.ID = Product.BrandID      
JOIN tblMasterCategory PHL ON PHL.ID = Product.CategoryID          
JOIN tblMasterManufacturer AS Manuf ON Manuf.ID = Product.MfrID   
LEFT JOIN tblMasterReason as rea ON rea.ID=InvDetail.ReasonId    
WHERE InventHeader.InventoryID=  @InventoryID '  
set @query += case when ISNULL(@BranchName,0) = 0 then '' else ' AND InventHeader.BranchID = '+' @BranchName '+'' END      
set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND MB.ID IN (SELECT * from dbo.fnSplitString( '+' @BrandName ,'',''))' END      
set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND PHL.ID IN (SELECT * from dbo.fnSplitString( '+' @CategoryName ,'',''))' END      
set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND Manuf.ID IN (SELECT * from dbo.fnSplitString( '+' @ManufName ,'',''))' END      
set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND Product.ID IN (SELECT * from dbo.fnSplitString( '+' @ProductName ,'',''))' END    
EXEC sys.sp_executesql @query, N'@InventoryID int, @BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @ToDate DATE', @InventoryID, @BranchName, @ManufName, @BrandName, @CategoryName, @ProductName, @FromDate, @ToDate  
end
GO

/****** uspRepInventoryAdjustmentHeader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspRepInventoryAdjustmentHeader]      
@BranchName NVARCHAR(255) = '',  @ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',      
@ProductName NVARCHAR(255)='', @FromDate DATE = '2025-09-01', @ToDate DATE = '2025-12-31'  
as  
begin  
DECLARE @query NVARCHAR(MAX)      
set @query = 'SELECT InventHeader.InventoryID,InventHeader.DocID AS [Doc ID],    
format(InventoryDate,''dd/MMM/yyyy'') AS [Doc Date],MBO.Name [Branch Name],RefNo [Ref No],  
[dbo].[fnGetRoundedValue](SUM(invd.ActualQty - invd.OrgQty)) AS[Actual Qty Difference],    
[dbo].[fnGetRoundedValue](SUM(invd.ActualFreeQty - invd.OrgFreeQty)) AS[Actual Free Qty Difference],    
[dbo].[fnGetRoundedValue](SUM(invd.ActualDmgQty - invd.OrgDmgQty))AS[Actual Damage Qty Difference],    
[dbo].[fnGetRoundedValue](SUM((ActualPurPrice - OrgPurPrice) * ActualQty)) as [Actual Price Difference],    
[dbo].[fnGetRoundedValue](SUM((ActualPurPrice - OrgPurPrice) * ActualDmgQty)) as [Actual Damage Price Difference],    
[dbo].[fnGetRoundedValue](SUM((invd.ActualQty - invd.OrgQty) * ActualPurPrice)) [Final Diff Value],    
[dbo].[fnGetRoundedValue](SUM((invd.ActualDmgQty - invd.OrgDmgQty) * ActualPurPrice)) [Final Diff Damage Value],    
[dbo].[fnGetRoundedValue]((TotalAmt)) AS [Total Amount],s.Description Status,  
u.username as [User Name],convert(nvarchar,InventHeader.CDate) [Create Date],InventHeader.Remarks,Narration    
FROM tblInventoryHeader AS InventHeader   
JOIN tblInventoryDetail as invd ON invd.InventoryID=InventHeader.InventoryID    
JOIN tblMasterBranchOffice MBO ON MBO.ID = InventHeader.BranchID  
JOIN tblUsers as u ON u.ID = InventHeader.CBy    
LEFT JOIN tblUsers as us ON us.ID = InventHeader.MBy    
LEFT JOIN tblStatus as s ON s.ID = InventHeader.Status    
JOIN tblMasterProduct AS Prod ON Prod.ID = invd.ProdId      
JOIN tblMasterBrand MB ON MB.ID = Prod.BrandID      
JOIN tblMasterCategory PHL ON PHL.ID = Prod.CategoryID          
JOIN tblMasterManufacturer AS Manuf ON Manuf.ID = Prod.MfrID   
WHERE InventHeader.TransID = 13 '  
SET @query = @query  + (CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (InventHeader.InventoryDate BETWEEN  @FromDate  AND  @ToDate )' END)        
            
set @query += case when ISNULL(@BranchName,0) = 0 then '' else ' AND InventHeader.BranchID = '+' @BranchName '+'' END      
set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND MB.ID IN (SELECT * from dbo.fnSplitString( '+' @BrandName ,'',''))' END      
set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND PHL.ID IN (SELECT * from dbo.fnSplitString( '+' @CategoryName ,'',''))' END      
set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND Manuf.ID IN (SELECT * from dbo.fnSplitString( '+' @ManufName ,'',''))' END      
set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND Prod.ID IN (SELECT * from dbo.fnSplitString( '+' @ProductName ,'',''))' END      
 set @query += '  
GROUP BY InventHeader.InventoryID,TotalAmt,    
InventHeader.DocID,InventoryDate,s.Description,u.username,InventHeader.CDate,MBO.Name,InventHeader.Remarks,Narration,RefNo  
ORDER BY InventHeader.DocID asc  '  
EXEC sys.sp_executesql @query, N'@BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BranchName, @ManufName, @BrandName, @CategoryName, @ProductName, @FromDate, @ToDate   
end
GO

/****** uspRepInvoiceOS ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--uspRepInvoiceOS '','','DHANYANTH','2025-03-25'            
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspRepInvoiceOS]            
@BeatName nvarchar(max) = null,@SalesmanName nvarchar(max) = null,@CustomerName nvarchar(max) = null,@AsonDate date = null              
as                  
BEGIN                  
DECLARE @strQuery NVARCHAR(MAX) = ''            
create table #temp([Doc ID] nvarchar(255),[Doc Date] nvarchar(255),[Ref No] nvarchar(255),[Beat Name] nvarchar(255),          
[Salesman Name] nvarchar(255),[Customer Name] nvarchar(255),[Net Amount] decimal(25,2),[Balance] decimal(25,2),Ageing int,[Assigned Invoice Count] int)          
SET @strQuery = 'SELECT DocID [Doc ID],CONVERT(nvarchar(50),InvDate,103) [Doc Date],DocRef [Ref No],MB.Name [Beat Name],SM.Name [Salesman Name],            
MC.Name [Customer Name],case when DocPrefix = 15 THEN dbo.fnGetRoundedValue(SH.NetAmt) ELSE dbo.fnGetRoundedValue(SH.NetAmt * -1) END [Net Amount],            
case when DocPrefix = 15 THEN dbo.fnGetRoundedValue(SH.Balance) ELSE dbo.fnGetRoundedValue(SH.Balance * -1) END [Balance],        
DATEDIFF(DD,InvDate,GETDATE()) Ageing,        
(select count(*) from tblAssignInvoicesDETAIL AD JOIN tblAssignInvoicesHeader AH ON AH.ID = AD.HID AND AH.Status IN (1,3,5)         
where AD.InvID = SH.ID) [Assigned Invoice Count]        
FROM tblTranSalesHeader SH            
JOIN tblMasterCustomer MC ON MC.ID = SH.CustID            
LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatID            
LEFT JOIN tblMasterSalesman SM ON SM.ID = SH.SalesManID            
  WHERE SH.Status in (1,3,6,7) and SH.InvDate <=  ' +' @AsonDate '            
SET @strQuery += CASE WHEN ISNULL(@BeatName,'') = '' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString('+' @BeatName ,'',''))' END                
SET @strQuery += CASE WHEN ISNULL(@SalesmanName,'') = '' THEN '' ELSE ' AND SM.ID  IN (SELECT * from dbo.fnSplitString('+' @SalesmanName ,'',''))' END               
SET @strQuery += CASE WHEN ISNULL(@CustomerName,'') = '' THEN '' ELSE ' AND MC.ID  IN (SELECT * from dbo.fnSplitString('+' @CustomerName ,'',''))' END                  
SET @strQuery += ' ORDER BY InvDate,DocValue'            
insert into #temp          
EXEC sys.sp_executesql @strQuery, N'@BeatName nvarchar(max), @SalesmanName nvarchar(max), @CustomerName nvarchar(max), @AsonDate date', @BeatName, @SalesmanName, @CustomerName, @AsonDate            
      
select [Doc ID],[Doc Date],[Ref No],[Beat Name],[Salesman Name],[Customer Name],  
dbo.fnGetRoundedValue([Net Amount]) [Net Amount],dbo.fnGetRoundedValue([Balance]) [Balance],Ageing,[Assigned Invoice Count] from #temp  
        
drop table #temp          
END 
GO

/****** uspRepItemLedger ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspRepItemLedger]   
@BranchName NVARCHAR(255) = '0',@ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',@ProductName NVARCHAR(255) = '',  
@FromDate DATE = '2025-08-01',@ToDate DATE = '2025-08-30'     
as  
begin  
declare @StrQuery nvarchar(max) = ''    
 set @StrQuery = '   
select PV.ProdID,MP.Code,MP.Name,MM.Name [Mfr Name],MB.Name [Brand Name],PHL.Name [Category Name], dbo.fnGetRoundedValue(ISNULL(SUM(RecdQty), 0)) AS [Recd Qty],  
       dbo.fnGetRoundedValue(ISNULL(SUM(RecdFreeQty), 0)) AS [Recd Free Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(RecdDmgQty), 0)) AS [Recd Dmg Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(PRQty), 0)) AS [PR Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(PRFreeQty), 0)) AS [PR Free Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(PRDmgQty), 0)) AS [PR Dmg Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(SRQty), 0)) AS [SR Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(SRFreeQty), 0)) AS [SR Free Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(SRDmgQty), 0)) AS [SR Dmg Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(InvoiceQty), 0)) AS [Invoice Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(InvoiceFreeQty), 0)) AS [Invoice Free Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(InvoiceDmgQty), 0)) AS [Invoice Dmg Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(InvenoryAdjQty), 0)) AS [Inventory Adj Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(InvenoryAdjFreeQty), 0)) AS [Inventory Adj Free Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(InvenoryAdjDmgQty), 0)) AS [Inventory Adj Dmg Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(InvenoryConvQty), 0) * -1) AS [Inventory Conv Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(InvenoryConvFreeQty), 0) * -1) AS [Inventory Conv Free Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(InvenoryConvDmgQty), 0) * -1) AS [Inventory Conv Dmg Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(ActualQty), 0)) AS [Actual Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(ActualFreeQty), 0)) AS [Actual Free Qty],  
        dbo.fnGetRoundedValue(ISNULL(SUM(ActualDmgQty), 0)) AS [Actual Dmg Qty],  
    PV.BatchNumber [Batch No],FORMAT(PV.PKDDate,''dd-MMM-yyyy'') [PKD Date],FORMAT(PV.ExpiryDate,''dd-MMM-yyyy'') [Expiry Date]  
 from tblproductinventory PV  
right JOIN tblMasterProduct MP ON MP.ID = PV.ProdID  
JOIN tblMasterManufacturer MM ON MM.ID=MP.MfrID      
JOIN tblMasterBrand MB ON MB.ID = MP.BrandID    
JOIN tblMasterCategory PHL ON PHL.ID = MP.CategoryID where MP.ID > 0 '  
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (PV.TransDate BETWEEN  @FromDate  AND  @ToDate )' END)                 
   
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND PV.BranchID =  @BranchName ' END)     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ManufName,'')='' THEN '' ELSE ' AND MM.ID IN (SELECT * from dbo.fnSplitString(  @ManufName ,'',''))' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BrandName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString(  @BrandName ,'',''))' END)            
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CategoryName,'')='' THEN '' ELSE ' AND PHL.ID IN (SELECT * from dbo.fnSplitString(  @CategoryName ,'',''))' END)     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ProductName,'')='' THEN '' ELSE ' AND MP.ID IN (SELECT * from dbo.fnSplitString(  @ProductName ,'',''))' END)   
SET @StrQuery = @StrQuery +  ' GROUP BY PV.ProdID,MP.Code,MP.Name,MM.Name,MB.Name,PHL.Name,PV.BatchNumber,PV.PKDDate,PV.ExpiryDate '  
EXEC sys.sp_executesql @StrQuery, N'@BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BranchName, @ManufName, @BrandName, @CategoryName, @ProductName, @FromDate, @ToDate  
end
GO

/****** uspRepItemwiseclosingstockheader ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspRepItemwiseclosingstockheader]      
@BranchName NVARCHAR(255) = '',  @ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',      
@ProductName NVARCHAR(255)='',@Date date = '2026-09-05',@QtyType int = 1      
as      
begin      
CREATE TABLE #TempProductData      
(      
ProductID              INT,      
BranchID               INT,  
BrandID       INT,  
CategoryID             INT,  
ManufID                INT,  
[Date]                 DATE,      
[Product Code]         NVARCHAR(100),      
[Product Name]         NVARCHAR(200),      
[Branch Name]          NVARCHAR(200),      
[Mfr Name]             NVARCHAR(200),      
[Brand Name]           NVARCHAR(200),      
[Category Name]        NVARCHAR(200),      
[Sales Qty]            DECIMAL(25,4),      
[Sales Gross Amount]   DECIMAL(25,4),      
[Sales Net Amount]     DECIMAL(25,4),      
[Free Qty]             DECIMAL(25,4),      
[Damage Qty]           DECIMAL(25,4),      
[Damage Gross Amount]  DECIMAL(25,4),      
[Damage Net Amount]    DECIMAL(25,4)      
);      
IF @Date=CAST(GETDATE() AS DATE)      
BEGIN      
insert into #TempProductData      
select * from (      
SELECT Prod.ID ProductID,PInv.BranchID BranchID,Prod.BrandID, Prod.CategoryID, Manuf.ID AS ManufID,@Date AS [Date],Prod.Code [Product Code],Prod.Name [Product Name], MBO.Name [Branch Name],      
Manuf.Name[Mfr Name],MB.Name [Brand Name],PHL.Name [Category Name],      

(SUM(PInv.ActualQty)) + SUM(isnull(VLD.UomQty,0)- isnull(VLD.VLSMQty,0) + isnull(VLD.VLSRetrunQty,0)) AS [Sales Qty],     
(SUM(PInv.PurchasePrice* PInv.ActualQty)) +
SUM(((isnull(VLD.UomQty,0)*PInv.PurchasePrice))- (isnull(VLD.VLSMQty,0)*PInv.PurchasePrice) + (isnull(VLD.VLSRetrunQty,0)*PInv.PurchasePrice))
AS [Sales Gross Amount],           
dbo.fngetInclusiveValue(PInv.TaxId,SUM(PInv.MRPONPrice* 
(isnull(VLD.UomQty,0)- isnull(VLD.VLSMQty,0) + isnull(VLD.VLSRetrunQty,0)) + PInv.ActualQty),
SUM(PInv.PurchasePrice* ((isnull(VLD.UomQty,0)- isnull(VLD.VLSMQty,0) + isnull(VLD.VLSRetrunQty,0)) + PInv.ActualQty))) AS [Sales Net Amount],
(SUM(PInv.ActualFreeQty)) AS [Free Qty],      
(SUM(PInv.ActualDmgQty)) AS [Damage Qty],      
(SUM(PInv.PurchasePrice* PInv.ActualDmgQty)) AS [Damage Gross Amount],      
dbo.fngetInclusiveValue(PInv.TaxId,SUM(PInv.MRPONPrice* PInv.ActualDmgQty),SUM(PInv.PurchasePrice* PInv.ActualDmgQty)) AS [Damage Net Amount]
FROM tblProductInventory AS PInv      
LEFT JOIN tblMasterBranchOffice MBO ON MBO.ID = PInv.BranchID      
LEFT JOIN tblMasterProduct AS Prod ON Prod.ID = PInv.ProdId      
JOIN tblMasterBrand MB ON MB.ID = Prod.BrandID      
JOIN tblMasterCategory PHL ON PHL.ID = Prod.CategoryID      
JOIN tblMasterTax AS Tax ON Tax.TaxID = Prod.SalesTaxId      
JOIN tblMasterManufacturer AS Manuf ON Manuf.ID = Prod.MfrID      
LEFT JOIN tblVanLoadingSlipDetail VLD ON VLD.InventoryID = PInv.InventoryId  
--WHERE Manuf.ManufacturerId IN (SELECT ID FROM @tvpAutoListDetails WHERE nIndex=0)      
WHERE PInv.TransDate<=@Date      
GROUP BY Prod.ID,Prod.Code,Prod.Name, MBO.Name,Manuf.Name,MB.Name,PHL.Name,PInv.BranchID,Prod.BrandID, Prod.CategoryID, Manuf.ID,PInv.TaxId) as nk      
END      
ELSE      
BEGIN      
insert into #TempProductData      
SELECT  Prod.ID ProductID,CS.BranchID BranchID,Prod.BrandID, Prod.CategoryID, Manuf.ID AS ManufID,@Date AS [Date],Prod.Code [Product Code],Prod.Name [Product Name], MBO.Name [Branch Name],      
Manuf.Name[Mfr Name],MB.Name [Brand Name],PHL.Name [Category Name],      
(SUM(CS.SaleQty)) AS [Sales Qty],      
(SUM(CS.SaleStockValue)) AS [Sales Gross Amount],      
(SUM(CS.SaleStockValue + (CS.SaleStockValue * Tax.GST)/100)) AS [Sales Net Amount] ,      
(SUM(CS.FreeQty)) AS [Free Qty],      
(SUM(CS.DmgQty)) AS [Damage Qty],      
(SUM(CS.DmgStockValue)) AS [Damage Gross Amount],      
(SUM(CS.DmgStockValue + (CS.DmgStockValue * Tax.GST)/100))  AS [Damage Net Amount]      
FROM tblClosingStock AS CS      
LEFT JOIN tblMasterBranchOffice MBO ON MBO.ID = CS.BranchID      
LEFT JOIN tblMasterProduct AS Prod ON Prod.ID = CS.ProdId      
JOIN tblMasterBrand MB ON MB.ID = Prod.BrandID      
JOIN tblMasterCategory PHL ON PHL.ID = Prod.CategoryID      
JOIN tblMasterTax AS Tax ON Tax.TaxID = Prod.SalesTaxId      
JOIN tblMasterManufacturer AS Manuf ON Manuf.ID = Prod.MfrID      
--WHERE Manuf.ManufacturerId IN (SELECT ID FROM @tvpAutoListDetails WHERE nIndex=0)      
WHERE CS.ClsDate=@Date      
GROUP BY Prod.ID,Prod.Code,Prod.Name, MBO.Name,Manuf.Name,MB.Name,PHL.Name,CS.BranchID,Prod.BrandID, Prod.CategoryID, Manuf.ID     
END      
DECLARE @query NVARCHAR(MAX)      
set @query = ' select ProductID,      
BranchID,      
[Date],      
[Product Code],      
[Product Name],      
[Branch Name],      
[Mfr Name],      
[Brand Name],      
[Category Name],      
dbo.fnGetRoundedValue(SUM([Sales Qty]))             AS [Sales Qty],      
dbo.fnGetRoundedValue(SUM([Sales Gross Amount]))    AS [Sales Gross Amount],      
dbo.fnGetRoundedValue(SUM([Sales Net Amount]))      AS [Sales Net Amount],      
dbo.fnGetRoundedValue(SUM([Free Qty]))              AS [Free Qty],      
dbo.fnGetRoundedValue(SUM([Damage Qty]))            AS [Damage Qty],      
dbo.fnGetRoundedValue(SUM([Damage Gross Amount]))   AS [Damage Gross Amount],      
dbo.fnGetRoundedValue(SUM([Damage Net Amount]))     AS [Damage Net Amount]  FROM #TempProductData TPD WHERE ProductID > 0'      
set @query += case when ISNULL(@QtyType,1) = 1 then ' and ([Sales Qty] > 0 OR [Free Qty] > 0 OR [Damage Qty] > 0)' else '' END      
set @query += case when ISNULL(@BranchName,0) = 0 then '' else ' AND TPD.BranchID  = '+' @BranchName '+'' END      
set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND BrandID IN (SELECT * from dbo.fnSplitString( '+' @BrandName ,'',''))' END      
set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND CategoryID IN (SELECT * from dbo.fnSplitString( '+' @CategoryName ,'',''))' END      
set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND ManufID IN (SELECT * from dbo.fnSplitString( '+' @ManufName ,'',''))' END      
set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND ProductID IN (SELECT * from dbo.fnSplitString( '+' @ProductName ,'',''))' END      
set @query += ' GROUP BY      
ProductID,      
BranchID,      
[Date],      
[Product Code],      
[Product Name],      
[Branch Name],      
[Mfr Name],      
[Brand Name],      
[Category Name];'      
EXEC sys.sp_executesql @query, N'@BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @Date date, @QtyType int', @BranchName, @ManufName, @BrandName, @CategoryName, @ProductName, @Date, @QtyType      
drop table #TempProductData      
end 
GO

/****** uspRepMasterProductData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--uspRepMasterProductData '','','',''      
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspRepMasterProductData]      
@ManufName nvarchar(max) = null,@BrandName nvarchar(max) = null,@CategoryName nvarchar(max) = null,@ProductName nvarchar(max) = null    
as        
begin        
    
DECLARE @strQuery NVARCHAR(MAX) = ''      
SET @strQuery = ' SELECT MP.Code,MP.Name,MP.EAN,MF.Name [Mfr Name],MB.Name [Brand Name],MC.Name [Category Name],MUB.Name [Base UOM],MUP.Name [Purcase UOM],MUS.Name [Sales UOM],    
MT.TaxName Tax,PurchasePrice,SalesPrice,ECP,SPLPrice,MRP,ReturnPrice,case when MP.TrackInventory = 1 then ''Yes'' ELSE ''No'' END [Track Inventory],    
case when MP.TrackBatch = 1 then ''Yes'' ELSE ''No'' END [Track Batch],case when MP.TrackSerial = 1 then ''Yes'' ELSE ''No'' END [Track Serial],    
case when MP.TrackPDK = 1 then ''Yes'' ELSE ''No'' END [Track PDK],case when MP.DateFormat = 1 then ''DMY'' ELSE ''MY'' END [Date Format],MOH,MOQ    
,MV.Name [Vendor Name],case when MP.Active = 1 then ''Yes'' ELSE ''No'' end Active,  
MU.UserName [Created By],CONVERT(NVARCHAR,MP.CDate) [Create Date],  
MUM.UserName [Modify By],CONVERT(NVARCHAR,MB.MDate) [Modify Date]  
from tblMasterProduct MP          
JOIN tblMasterManufacturer MF ON MF.ID = MP.MfrID          
JOIN tblMasterBrand MB ON MB.ID = MP.BrandID          
JOIN tblMasterCategory MC ON MC.ID = MP.CategoryID          
join tblMasterTax MT ON MT.TaxID = MP.SalesTaxID    
join tblMasterUOM MUB ON MUB.ID = MP.BaseUomID    
join tblMasterUOM MUP ON MUP.ID = MP.PurchaseUomID    
join tblMasterUOM MUS ON MUS.ID = MP.PurchaseUomID    
JOIN tblUsers MU ON MU.ID = MP.CBy        
LEFT JOIN tblUsers MUM ON MUM.ID = MP.MBy    
left JOIN tblMasterVendor MV ON MV.ID = MP.VendorID  WHERE MP.Active IN (0,1) '    
SET @strQuery += CASE WHEN ISNULL(@ManufName,'') = '' THEN '' ELSE ' AND MF.ID IN (SELECT * from dbo.fnSplitString('+' @ManufName ,'',''))' END      
SET @strQuery += CASE WHEN ISNULL(@BrandName,'') = '' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString('+' @BrandName ,'',''))' END     
SET @strQuery += CASE WHEN ISNULL(@CategoryName,'') = '' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString('+' @CategoryName ,'',''))' END      
SET @strQuery += CASE WHEN ISNULL(@ProductName,'') = '' THEN '' ELSE ' AND MP.ID IN (SELECT * from dbo.fnSplitString('+' @ProductName ,'',''))' END     
EXEC sys.sp_executesql @strQuery, N'@ManufName nvarchar(max), @BrandName nvarchar(max), @CategoryName nvarchar(max), @ProductName nvarchar(max)', @ManufName, @BrandName, @CategoryName, @ProductName    
end     
GO

/****** uspRepMasterSalesmanData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--uspRepMasterSalesmanData '','4,2'
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspRepMasterSalesmanData]      
@SalesmanName nvarchar(max) = null,@SalesmanGrpName nvarchar(max) = null  
as        
begin        
DECLARE @strQuery NVARCHAR(MAX) = ''      
SET @strQuery = ' select MS.Name [Salesman Name],MSG.Name [Salesman Group],CONVERT(nvarchar,DOJ,103) DOJ,    
MS.MobileNo,case when MS.Active = 1 then ''Yes'' ELSE ''No'' end Active,MU.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Create Date],    
MUM.UserName [Modify By],CONVERT(NVARCHAR,MS.MDate) [Modify Date]    
from tblMasterSalesman MS      
LEFT JOIN tblMasterSalesmanGroup MSG ON MSG.ID = MS.SalesmanGroupID      
JOIN tblUsers MU ON MU.ID = MS.CBy        
LEFT JOIN tblUsers MUM ON MUM.ID = MS.MBy WHERE MS.Active IN (0,1) '      
--SET @strQuery += CASE WHEN ISNULL(@SalesmanName,'') = '' THEN '' ELSE ' AND MS.Name = '+' @SalesmanName ' END      
--SET @strQuery += CASE WHEN ISNULL(@SalesmanGrpName,'') = '' THEN '' ELSE ' AND MSG.Name = '+' @SalesmanGrpName ' END      
SET @strQuery += CASE WHEN ISNULL(@SalesmanName,'') = '' THEN '' ELSE ' AND 
MS.ID IN (SELECT * from dbo.fnSplitString('+' @SalesmanName ,'',''))' END      
SET @strQuery += CASE WHEN ISNULL(@SalesmanGrpName,'') = '' THEN '' ELSE ' AND MSG.ID
IN (SELECT * from dbo.fnSplitString('+' @SalesmanGrpName ,'',''))' END      
EXEC sys.sp_executesql @strQuery, N'@SalesmanName nvarchar(max), @SalesmanGrpName nvarchar(max)', @SalesmanName, @SalesmanGrpName      
end      
GO

/****** uspReportScript ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--    
-- Security fix: sp_helptext is called directly with the procedure name instead of through EXEC() of a concatenated string.
ALTER PROCEDURE [dbo].[uspReportScript]          
@Mode INT = 1,@ReportID INT = 16          
AS          
BEGIN          
DECLARE @MenuId int          
Set @MenuId = (Select MenuID from tblReportViewer where ReportId = @ReportID)          
          
IF ISNULL(@Mode,0)=1 -- Menu permission           
BEGIN          
IF ISNULL((SELECT COUNT(*) FROM tblReportViewer WHERE ReportId = @ReportID),0) > 0          
BEGIN          
Select 'IF (SELECT COUNT(*) FROM tblMenus WHERE MenuId = '+Convert(nvarchar,@MenuId)+') = 0'          
UNION all          
Select 'BEGIN'          
UNION ALL          
SELECT          
'INSERT INTO [dbo].[tblMenus]          
([MenuId],[MenuName],[MenuParentId],[MenuChildLevel],[MenuTree],[LocationName],          
[Permission],[Active],[DisplayIndex],[IsMenu],[FormID],[IsReport],          
[EncMenuID],[EncMenuName],[EncFormID],[IsMobileApp],Favourite,IsFincancialReport)          
VALUES (' +          
'''' + CONVERT(NVARCHAR(MAX),MenuId) + ''',' +          
'''' + ISNULL(CONVERT(NVARCHAR(MAX),MenuName),'') + ''',' +          
'''' + ISNULL(CONVERT(NVARCHAR(MAX),MenuParentId),'') + ''',' +          
'''' + ISNULL(CONVERT(NVARCHAR(MAX),MenuChildLevel),'') + ''',' +          
'''' + ISNULL(CONVERT(NVARCHAR(MAX),MenuTree),'') + ''',' +          
'''' + ISNULL(CONVERT(NVARCHAR(MAX),LocationName),'') + ''',' +          
'''' + ISNULL(CONVERT(NVARCHAR(MAX),Permission),'') + ''',' +          
'''' + ISNULL(CONVERT(NVARCHAR(MAX),Active),'') + ''',' +          
'''' + ISNULL(CONVERT(NVARCHAR(MAX),DisplayIndex),'') + ''',' +          
'''' + ISNULL(CONVERT(NVARCHAR(MAX),IsMenu),'') + ''',' +          
'''' + ISNULL(CONVERT(NVARCHAR(MAX),FormID),'') + ''',' +          
'''' + ISNULL(CONVERT(NVARCHAR(MAX),IsReport),'') + ''',' +          
'''' + ISNULL(CONVERT(NVARCHAR(MAX),EncMenuID),'') + ''',' +          
'''' + ISNULL(CONVERT(NVARCHAR(MAX),EncMenuName),'') + ''',' +          
'''' + ISNULL(CONVERT(NVARCHAR(MAX),EncFormID),'') + ''',' +          
'''' + ISNULL(CONVERT(NVARCHAR(MAX),IsMobileApp),'') + ''',0,0)'          
FROM tblMenus          
WHERE MenuId IN (SELECT MenuID FROM tblReportViewer WHERE ReportId=@ReportID)          
UNION ALL          
Select 'END'          
          
END          
END          
else IF ISNULL(@Mode,0)=2 -- report permission          
BEGIN          
IF ISNULL((SELECT COUNT(*) FROM tblReportViewer WHERE ReportId = @ReportID),0) > 0          
BEGIN          
SELECT 'DELETE tblReportViewer WHERE ReportId = '+CONVERT(NVARCHAR,@ReportID)+''          
UNION ALL          
SELECT           
    'INSERT INTO [dbo].[tblReportViewer]          
    ([ReportID],[ReportName],[ParentID],[Active],[MenuID],          
     [ProcedureName],[DetailProcedureName],[Frames],[SendFiltersDetail],[IsDynamicReport])           
    VALUES (' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),ReportID),'') + ''',' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),ReportName),'') + ''',' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),ParentID),'') + ''',' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),Active),'') + ''',' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),MenuID),'') + ''',' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),ProcedureName),'') + ''',' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),DetailProcedureName),'') + ''',' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),Frames),'') + ''',' +          
 '''' + ISNULL(CONVERT(NVARCHAR(MAX),SendFiltersDetail),'') + ''',' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),IsDynamicReport),'') + ''')'          
FROM tblReportViewer          
WHERE ReportID = @ReportID          
END          
END          
ELSE IF ISNULL(@Mode,0)=3 -- report columns          
BEGIN          
IF ISNULL((SELECT COUNT(*) FROM tblColumnSettings WHERE FormorReport = 1 and FormID = @ReportID),0) > 0          
BEGIN          
SELECT 'DELETE tblColumnSettings WHERE  FormorReport = 1 and FormID = '+CONVERT(NVARCHAR,@ReportID)+''          
UNION ALL          
  
  
SELECT           
'INSERT INTO [dbo].[tblColumnSettings]      (FormID,FormName,FormorReport,TableID,ColumnID,ColumnName,DisplayColumnName,Width,Visible,Alignment,DisplayIndex,      
IsHiddenColumn,Total,TotalYN,EnableSum,EnableAvg,ClickPopup,EnableColumnMenu,ShowinColumnOption,OriginalColumnName,      
PrintYN,PrintColumnName,PrintWidth,EnableCount,EnableUnique,ColumnType,Permission)      
VALUES (' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),FormID),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),FormName),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),FormorReport),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),TableID),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),ColumnID),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),ColumnName),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),DisplayColumnName),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),Width),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),Visible),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),Alignment),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),DisplayIndex),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),IsHiddenColumn),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),Total),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),TotalYN),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),EnableSum),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),EnableAvg),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),ClickPopup),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),EnableColumnMenu),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),ShowinColumnOption),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),OriginalColumnName),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),PrintYN),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),PrintColumnName),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),PrintWidth),'') + ''',' +     
'''' + ISNULL(CONVERT(NVARCHAR(MAX),EnableCount),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),EnableUnique),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),ColumnType),'') + ''',' +      
'''' + ISNULL(CONVERT(NVARCHAR(MAX),Permission),'') + ''')'      
FROM tblColumnSettings          
WHERE FormorReport = 1 and FormID = @ReportID;      
END          
END          
ELSE IF ISNULL(@Mode,0)=4 -- report parameters          
BEGIN          
SELECT 'DELETE tblParameterInfo WHERE ReportId = '+CONVERT(NVARCHAR,@ReportID)+''          
UNION ALL           
SELECT ' SET IDENTITY_INSERT [dbo].[tblParameterInfo] ON  '          
UNION ALL          
SELECT           
    '          
 INSERT INTO [dbo].[tblParameterInfo]          
    ([ParameterID],[ReportID],[ParameterName],[ParameterType],[IsMandatory],[ParamOrder],[AutolistName])           
    VALUES (' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),ParameterID),'') + ''',' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),ReportID),'') + ''',' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),ParameterName),'') + ''',' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),ParameterType),'') + ''',' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),IsMandatory),'') + ''',' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),ParamOrder),'') + ''',' +          
    '''' + ISNULL(CONVERT(NVARCHAR(MAX),AutolistName),'') + ''')          
 '          
FROM tblParameterInfo          
WHERE ReportID = @ReportID          
UNION ALL          
SELECT ' SET IDENTITY_INSERT [dbo].[tblParameterInfo] OFF  '          
END          
ELSE IF ISNULL(@Mode,0)=5 -- Header Procedure script          
BEGIN          
DECLARE @tempHeader TABLE (H_Data NVARCHAR(MAX))          
DECLARE @SpHeader NVARCHAR(255) = (SELECT ProcedureName FROM tblReportViewer WHERE ReportId=@ReportID)          
-- (was: EXEC of 'SP_HELPTEXT '+@SpHeader in an NVARCHAR(50) buffer)          
INSERT INTO @tempHeader EXEC sys.sp_helptext @SpHeader          
          
SELECT 'IF EXISTS (SELECT * FROM sys.objects WHERE type=''P'' AND name='''+@SpHeader+''')'          
UNION ALL          
SELECT 'BEGIN'          
UNION ALL      
SELECT 'DROP PROC '+@SpHeader+''          
UNION ALL          
SELECT 'END'          
UNION ALL          
SELECT 'GO'          
UNION ALL          
SELECT H_Data FROM @tempHeader          
UNION ALL          
SELECT 'GO'          
END          
ELSE IF ISNULL(@Mode,0)=6 -- Detail Procedure script          
BEGIN          
DECLARE @tempFooter TABLE (F_Data NVARCHAR(MAX))          
DECLARE @SpFooter NVARCHAR(255) = (SELECT DetailProcedureName FROM tblReportViewer WHERE ReportId=@ReportID)          
IF ISNULL(@SpFooter,'')!=''          
BEGIN          
-- (was: EXEC of 'SP_HELPTEXT '+@SpFooter in an NVARCHAR(50) buffer)          
INSERT INTO @tempFooter EXEC sys.sp_helptext @SpFooter          
          
SELECT 'IF EXISTS (SELECT * FROM sys.objects WHERE type=''P'' AND name='''+@SpFooter+''')'          
UNION ALL          
SELECT 'BEGIN'          
UNION ALL          
SELECT 'DROP PROC '+@SpFooter+''          
UNION ALL          
SELECT 'END'          
UNION ALL          
SELECT 'GO'          
UNION ALL          
SELECT F_Data FROM @tempFooter          
END          
ELSE          
BEGIN          
SELECT F_Data FROM @tempFooter          
END          
END          
END 
GO

/****** uspRepSingleMasterData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--uspRepSingleMasterData 1,0
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspRepSingleMasterData]
@FormID int,@UserID INT = 0
AS
BEGIN
declare @TableName nvarchar(255) = (select TableName from tblTablesNames where ID = @FormID)    
declare @SafeTable NVARCHAR(600) = CASE WHEN OBJECT_ID(@TableName, 'U') IS NOT NULL THEN QUOTENAME(OBJECT_SCHEMA_NAME(OBJECT_ID(@TableName, 'U'))) + '.' + QUOTENAME(OBJECT_NAME(OBJECT_ID(@TableName, 'U'))) END
IF @SafeTable IS NULL AND @TableName IS NOT NULL BEGIN RAISERROR('Master table for this form was not found.', 16, 1); RETURN; END
declare @strQuery NVARCHAR(MAX)   
SET @strQuery = ' select Name [Name],case when MB.Active = 1 then ''Yes'' ELSE ''No'' end Active,  
MU.UserName [Created By],CONVERT(NVARCHAR,MB.CDate) [Create Date],  
MUM.UserName [Modify By],CONVERT(NVARCHAR,MB.MDate) [Modify Date] from '+@SafeTable+' MB      
JOIN tblUsers MU ON MU.ID = MB.CBy      
LEFT JOIN tblUsers MUM ON MUM.ID = MB.MBy '
SET @strQuery += CASE WHEN ISNULL(@UserID,0) = 0 THEN '' ELSE 'WHERE MB.CBy =  @UserID ' END
SET @strQuery += ' ORDER BY MB.[Name]'                 
EXEC sys.sp_executesql @strQuery, N'@FormID int, @UserID INT', @FormID, @UserID 
END
GO

/****** uspShrinkDataBase ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--[uspShrinkDataBase] 'WSHINE_TEMP01_APR2026'
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspShrinkDataBase]      
@DBName NVARCHAR(255)      
AS      
BEGIN      

DECLARE @StrQuery NVARCHAR(MAX),@LDFFilename nvarchar(255)
IF DB_ID(@DBName) IS NULL BEGIN RAISERROR('Database %s not found.', 16, 1, @DBName); RETURN; END

SELECT  @LDFFilename =  name FROM sys.database_files WHERE type_desc = 'LOG';

SET @StrQuery = 'ALTER DATABASE '+QUOTENAME(@DBName)+' SET RECOVERY SIMPLE'      
EXEC sys.sp_executesql @StrQuery, N'@DBName NVARCHAR(255)', @DBName      
DBCC SHRINKFILE (@LDFFilename, 1)      
SET @StrQuery = 'ALTER DATABASE '+QUOTENAME(@DBName)+' SET RECOVERY FULL'      
EXEC sys.sp_executesql @StrQuery, N'@DBName NVARCHAR(255)', @DBName      
DBCC FREESESSIONCACHE      
DBCC FREEPROCCACHE      
SELECT '1'    
END
GO

/****** uspUpdateEwayInTrans ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--uspUpdateEwayInTrans 2,'2,3,6',1,3,'Road','Regular',NULL,NULL      
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspUpdateEwayInTrans]            
@Mode INT,@InvID NVARCHAR(MAX),@VehicleID NVARCHAR(50) = 0,@Distance NVARCHAR(50) = NULL,@TranMode NVARCHAR(100) = NULL,            
@VehicleType NVARCHAR(100) = NULL,@TransportID NVARCHAR(100) = NULL,@TransportName NVARCHAR(255) = NULL,@Branch NVARCHAR(255) = NULL,  
@FromDate date = NULL,@ToDate date = NULL,@Type int = 1  
AS            
BEGIN            
IF(@Mode = 1)            
BEGIN            
SELECT sh.VehicleNo ID,VH.VehicleNo,Distance,TransMode,VehicleType,TransportID,TransportName FROM tblTranSalesHeader SH            
JOIN tblMasterVehicle VH ON VH.ID = SH.VehicleNo            
WHERE SH.DocValue = @InvID and BranchID = case when isnull(@Branch,'') = '' then BranchID else @Branch end    
END            
ELSE IF(@Mode = 2)            
BEGIN            
DECLARE @sql NVARCHAR(MAX)      
if(@Type = 1)-- update in invoice
BEGIN
SET @sql = 'UPDATE tblTranSalesHeader SET VehicleNo ='+ ' @VehicleID ' +',Distance ='+ ' @Distance ' +',
TransMode ='+ ' @TranMode ' +',VehicleType ='+ ' @VehicleType ' +',TransportID = ISNULL(@TransportID,'''') ,
TransportName =  ISNULL(@TransportName,'''')  
WHERE Docprefix = 15 and status in (1,3,5) and DocValue IN (SELECT id FROM dbo.fnSplitString(@InvID, N'',''))'      
set @sql += case when isnull(@Branch,'') = '' then '' else ' and BranchID = @Branch ' end    
SET @sql += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE 
' AND InvDate BETWEEN '+' @FromDate  AND '+' @ToDate ' END      
END
ELSE if(@Type = 2)-- update in Van Loading Slip
BEGIN
SET @sql = 'UPDATE tblVanLoadingSlipHeader SET VehicleNo ='+ ' @VehicleID ' +',Distance ='+ ' @Distance ' +',
TransMode ='+ ' @TranMode ' +',VehicleType ='+ ' @VehicleType ' +',TransportID = ISNULL(@TransportID,'''') ,
TransportName =  ISNULL(@TransportName,'''')  
WHERE status in (1,3,5) and DocValue IN (SELECT id FROM dbo.fnSplitString(@InvID, N'',''))'      
set @sql += case when isnull(@Branch,'') = '' then '' else ' and BranchID = @Branch ' end    
SET @sql += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE 
' AND DocDate BETWEEN '+' @FromDate  AND '+' @ToDate ' END    
END
EXEC sys.sp_executesql @sql, N'@Mode INT, @InvID NVARCHAR(MAX), @VehicleID NVARCHAR(50), @Distance NVARCHAR(50), @TranMode NVARCHAR(100), @VehicleType NVARCHAR(100), @TransportID NVARCHAR(100), @TransportName NVARCHAR(255), @Branch NVARCHAR(255), @FromDate date, @ToDate date, @Type int', @Mode, @InvID, @VehicleID, @Distance, @TranMode, @VehicleType, @TransportID, @TransportName, @Branch, @FromDate, @ToDate, @Type      
END            
END 
GO

/****** uspVendorReport ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: report filter values are passed to sp_executesql as typed parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspVendorReport]
 @WeekCycle nvarchar(50) = '0',@Ratings nvarchar(50) = '0'
AS
BEGIN
DECLARE @strQuery NVARCHAR(MAX) = ''  
SET @strQuery = '
select 
    MV.Code [Vendor Code],
    MV.Name [Vendor Name],
    MV.Billadd1 [Bill Add 1],
    MV.Billadd2 [Bill Add 2],
    MV.Billadd3 [Bill Add 3],
    MV.Shipadd1 [Ship Add 1],
    MV.Shipadd2 [Ship Add 2],
    MV.Shipadd3 [Ship Add 3],
    MV.Pincode,
    MV.ContactPerson [Contact Person],
    MV.Ph1 [Phone No 1],
    MV.Ph2 [Phone No 2],
    MV.Mob1 [Mob No 1],
    MV.Mob2 [Mob No 2],
    MV.Email [Email ID],
    MV.PANNumber [PAN No],
    MV.AadharNo [Aadhar No],
    MV.DLNo20 [DL No 20],
    MV.DLNo21 [DL No 22],
    MV.FSSAINo,
    GST.StateName [State Name],
    MV.GSTIN,    
    PM.PaymentMode [Payment Mode],
    CT.Name [Credit Term],
    MTT.TaxTypeName [Tax Type],
    WK.WeekDays [Week Cycle],
    RT.RatingnAME Ratings,
    [dbo].[fnGetRoundedValue]((dbo.fnGetClosingBal(MV.FAID))) AS [OutStanding Value],
    case when MV.Active = 1 then ''Yes'' ELSE ''No'' end Active,  
	MU.UserName [Created By],CONVERT(NVARCHAR,MV.CDate) [Create Date],  
	MUM.UserName [Modify By],CONVERT(NVARCHAR,MV.MDate) [Modify Date]
     from tblMasterVendor MV
LEFT JOIN tblGSTStateNameandCode GST ON GST.StateID = MV.StateID
LEFT JOIN tblMasterCreditTerm CT ON CT.ID = MV.CreditTermID
LEFT JOIN tblPaymentMode PM ON PM.ID = MV.PaymentModeID
JOIN tblMasterTaxType MTT ON MTT.TaxTypeID = MV.TaxTypeID
LEFT JOIN tblRatings RT ON RT.ID = MV.Rating
LEFT JOIN tblWeekCycle WK ON WK.ID = MV.WeekCycle
JOIN tblUsers MU ON MU.ID = MV.CBy        
LEFT JOIN tblUsers MUM ON MUM.ID = MV.MBy WHERE MV.ID > 0 '
SET @strQuery += CASE WHEN ISNULL(@WeekCycle,'0') = '0' THEN '' ELSE ' AND MV.WeekCycle = '+' @WeekCycle ' END      
SET @strQuery += CASE WHEN ISNULL(@Ratings,'0') = '0' THEN '' ELSE ' AND MV.Rating = '+' @Ratings ' END     
SET @strQuery += ' ORDER BY MV.Name '
EXEC sys.sp_executesql @strQuery, N'@WeekCycle nvarchar(50), @Ratings nvarchar(50)', @WeekCycle, @Ratings    
END
GO

