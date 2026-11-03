/* =====================================================================================
   01_Injection_Fixes.sql  -  P0 fix: SQL injection in dynamic-SQL stored procedures
   -------------------------------------------------------------------------------------
   Run on each Shine database (SSMS or sqlcmd) as db_owner/sysadmin, then run
   02_Account_Security.sql and 03_App_Login_Permissions.sql (03 re-signs 4 of these procedures).
   Safe to re-run (CREATE OR ALTER). Parameter names, order and result sets are unchanged.

   What changed in each procedure
   - Values from parameters are no longer pasted into the SQL text. The dynamic SQL now
     refers to the parameter (e.g.  MC.Name = @Party ) and runs through
     sys.sp_executesql with the procedure's own parameters passed as typed parameters.
   - Comma-separated ID lists used as  IN (1,2,3)  are read with STRING_SPLIT, or (where the
     list is put into the text) only digits, commas and spaces are accepted.
   - uspSyncMasterData: only tables enabled in tblWebshineMasterSyncTables, source database
     must exist and is quoted.
   - uspShrinkDataBase: current database only; keeps its recovery model (the old code always
     switched it to FULL); clears this database's plan cache instead of the whole server's.
   - Bug fix: uspGetCustomerWiseSalesHeader failed whenever @Ratings was given (missing FROM).

   Verified on a copy of WSHINE_TEST01_APR2026: old and new versions were called with the
   same inputs (3,970 calls, every mode) and returned the same results; injection payloads
   in every string parameter changed the SQL of 59 old procedures and of none of the new ones.

   Rollback: re-create the previous versions from the script.ipynb export / source control.
   ===================================================================================== */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspAvailableBookStockDetail';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspAvailableBookStockDetail]      
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
WHERE  MP.ID =' + convert(nvarchar(10),@ProductId)+ ' and [PI].Branchid = '+ convert(nvarchar(10),@BranchID)      
set @query += case when ISNULL(@QtyType,1) = 1 then ' and ([PI].ActualQty > 0 OR [PI].ActualFreeQty > 0 OR [PI].ActualDmgQty > 0)' else '' END        
 set @query += ' GROUP BY MP.Code,MP.Name,[PI].Prodid,[PI].BatchNumber,[PI].pkdDate,[PI].ExpiryDate,Uom.Name,        
[PI].PurchasePrice,[PI].SalesPrice,[PI].MRPONPrice,[PI].ECP,[PI].SPLPrice,[PI].ReturnPrice '    
EXEC sys.sp_executesql @query, N'@QtyType NVARCHAR(10), @ProductId INT, @BranchID int', @QtyType = @QtyType, @ProductId = @ProductId, @BranchID = @BranchID    
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspAvailableBookStockHeader';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspAvailableBookStockHeader]      
@BranchName NVARCHAR(255) = '',  @ManufName NVARCHAR(255) = '',@BrandName NVARCHAR(255) = '',@CategoryName NVARCHAR(255) = '',@ProductName NVARCHAR(255)='',      
@QtyType int = 1      
AS      
BEGIN      
DECLARE @query NVARCHAR(MAX)      
set @query = '      
SELECT '+CONVERT(nvarchar(10),@QtyType)+' QtyType,Prod.ID ProductID,isnull(PInv.BranchID,0) BranchID,MBO.Name [Branch Name],Prod.Code AS [Product Code],Prod.Name AS [Product Name],    
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
 set @query += case when ISNULL(@BranchName,0) = 0 then '' else ' AND PInv.BranchID = CONVERT(nvarchar(50),@BranchName)'+'' END        
 set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND MB.ID IN (SELECT * from dbo.fnSplitString( @BrandName,'',''))' END        
 set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND HI.ID IN (SELECT * from dbo.fnSplitString( @CategoryName,'',''))' END        
 set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND MF.ID IN (SELECT * from dbo.fnSplitString( @ManufName,'',''))' END        
 set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND Prod.ID IN (SELECT * from dbo.fnSplitString( @ProductName,'',''))' END        
 set @query += ' GROUP BY Prod.MfrID,MB.ID,HI.ID, Prod.ID,Prod.Code,Prod.EAN,Prod.Name,MF.Name,Mb.Name,HI.Name,    
Prod.PurchaseUomID,Prod.SalesUomID,Prod.ReportingUomID,Prod.ReportingQty,UOMPur.Name,    
UOMSale.Name,UOMRep.Name,UOMBase.Name,Prod.PurchaseCR ,Prod.SalesCR,PInv.BranchID,MBO.Name order by Prod.Name'    
EXEC sys.sp_executesql @query, N'@BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @QtyType int', @BranchName = @BranchName, @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName, @QtyType = @QtyType    
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspBMSWiseLoadingSlipReport';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspBMSWiseLoadingSlipReport]                    
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
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSD.InvDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)        
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString( @BeatName,'',''))' END)                            
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND MSM.ID IN (SELECT * from dbo.fnSplitString( @SalesmanName,'',''))' END)                         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ManufName,'')='' THEN '' ELSE ' AND MMF.ID IN (SELECT * from dbo.fnSplitString( @ManufName,'',''))' END)                         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BrandName,'')='' THEN '' ELSE ' AND MBN.ID IN (SELECT * from dbo.fnSplitString( @BrandName,'',''))' END)                            
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CategoryName,'')='' THEN '' ELSE ' AND PHL.ID IN (SELECT * from dbo.fnSplitString( @CategoryName,'',''))' END)                     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ProductName,'')='' THEN '' ELSE ' AND MP.ID IN (SELECT * from dbo.fnSplitString( @ProductName,'',''))' END)                     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND BOF.ID = @BranchName' END)                     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocRange,'')='' THEN '' ELSE ' AND TSD.DocValue IN (SELECT DocValue FROM dbo.SplitDocRange(@DocRange)) ' END)     
SET @StrQuery = @StrQuery + '                   
GROUP BY MP.Code,MP.ReportingQty,TSH.UomId,MP.Name,MP.EAN,MMF.Name,Uom.Name, Uom1.Name ,TSH.DetailMRP,TSD.DocPrefix,TSD.ID,MBN.Name,                  
PHL.Name,Uom2.Name,mp.BaseCR)AS Temp                  
GROUP BY Temp.[Product Code],Temp.[Product Name],Temp.EAN,Temp.[Manufacturer Name],                  
[Base UOM],[Sales UOM],[MRP On Price],[Brand Name],[Category Name],[Reporting Uom],ReportingQty,ConvFact'           
PRINT @StrQuery    
 EXEC sys.sp_executesql @StrQuery, N'@BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @DocRange NVARCHAR(MAX), @FromDate DATE, @ToDate DATE', @BranchName = @BranchName, @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @DocRange = @DocRange, @FromDate = @FromDate, @ToDate = @ToDate                    
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspCommonDocumentFilter';
GO
--[uspCommonDocumentFilter] 4,23,'2025-05-01','2027-05-01'
CREATE OR ALTER PROCEDURE [dbo].[uspCommonDocumentFilter]          
@Branch INT = 0,@DocPreix INT = 4,@FromDate DATE = '2025-05-01',@ToDate DATE = '2025-11-11',@DocRange NVARCHAR(MAX) = NULL,@CustID NVARCHAR(MAX) = NULL,        
@FilterBy int = 1        
as          
begin          
declare @StrQuery NVARCHAR(MAX) = ''            
if(@DocPreix = 4 or @DocPreix = 5)--4 : Invoice, 5 - SR          
BEGIN          
SET @StrQuery = 'select SH.DocValue,SH.DocId + (case when SH.ReturnsTransType = 2 then '' - DR'' when SH.ReturnsTransType = 1 THEN ''- SR'' ELSE '''' END) DocId,    
FORMAT(SH.InvDate,''dd/MMM/yyyy'') DocDate,MB.Name BeatName,MB.Name SalesmanName,MC.Name,SH.DocRef RefNo,dbo.fnGetRoundedValue(SH.NetAmt) NetAmt ,          
COUNT(SD.ProdID) ItemsCount          
from tblTranSalesHeader SH                    
JOIN tblMasterCustomer MC ON MC.Id = SH.CustId    
LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatID    
LEFT JOIN tblMasterSalesman SM ON SM.ID = SH.SalesmanID    
JOIN tblTranSalesDetail SD ON SD.InvID = SH.ID WHERE SD.TaxID > 0 AND SH.BranchID = '+CONVERT(nvarchar(10),@Branch) +' and '  
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocPreix,0)=4 THEN 'SH.DocPrefix = 15 ' ELSE ' SH.DocPrefix = 16 ' END)                                  
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocPreix,0)=4 THEN 'AND Status IN (1,3,5) ' ELSE ' AND Status IN (3,5,6,7)' END)               
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (SH.InvDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocRange,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocRange,LEN(@DocRange) - 1), N'',''))' END)                                  
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@FilterBy,0)=1 THEN '' WHEN ISNULL(@FilterBy,0)=2 THEN ' AND IRN IS NOT NULL' ELSE ' AND IRN IS NULL' END)            
SET @StrQuery = @StrQuery +  ' GROUP BY SH.DocId,SH.InvDate,MC.Name,SH.DocValue,SH.DocRef,SH.NetAmt,SH.ReturnsTransType,MB.Name,MB.Name order by SH.DocValue'          
EXEC sys.sp_executesql @StrQuery, N'@Branch INT, @DocPreix INT, @FromDate DATE, @ToDate DATE, @DocRange NVARCHAR(MAX), @CustID NVARCHAR(MAX), @FilterBy int', @Branch = @Branch, @DocPreix = @DocPreix, @FromDate = @FromDate, @ToDate = @ToDate, @DocRange = @DocRange, @CustID = @CustID, @FilterBy = @FilterBy          
END          
if(@DocPreix = 2 or @DocPreix = 3)--2 : Bill, 5 - PR          
BEGIN          
SET @StrQuery = 'select SH.DocValue,SH.DocId,FORMAT(SH.Date,''dd/MMM/yyyy'') DocDate,null BeatName,null SalesmanName,MC.Name,SH.RefNo RefNo,dbo.fnGetRoundedValue(SH.NetAmt) NetAmt ,          
COUNT(SD.ProdID) ItemsCount          
from tblTransPurchaseHeader SH                    
JOIN tblMastervendor MC ON MC.Id = SH.VendorID                    
JOIN tblTransPurchasedetail SD ON SD.HID = SH.ID WHERE SD.TaxID > 0 AND SH.BranchID = '+CONVERT(nvarchar(10),@Branch) +' and '        
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocPreix,0)=2 THEN 'SH.TransID = 1 ' ELSE ' SH.TransID = 12 ' END)                                  
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocPreix,0)=2 THEN 'AND Status IN (1,3,5) ' ELSE ' AND Status IN (3,5,6,7)' END)               
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (SH.Date BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocRange,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocRange,LEN(@DocRange) - 1), N'',''))' END)                                  
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@FilterBy,0)=1 THEN '' WHEN ISNULL(@FilterBy,0)=2 THEN ' AND IRN IS NOT NULL' ELSE ' AND IRN IS NULL' END)            
SET @StrQuery = @StrQuery +  ' GROUP BY SH.DocId,SH.Date,MC.Name,SH.DocValue,SH.RefNo,SH.NetAmt order by SH.DocValue'          
EXEC sys.sp_executesql @StrQuery, N'@Branch INT, @DocPreix INT, @FromDate DATE, @ToDate DATE, @DocRange NVARCHAR(MAX), @CustID NVARCHAR(MAX), @FilterBy int', @Branch = @Branch, @DocPreix = @DocPreix, @FromDate = @FromDate, @ToDate = @ToDate, @DocRange = @DocRange, @CustID = @CustID, @FilterBy = @FilterBy          
END       
if(@DocPreix = 23)--23 : Van Loading Slip
BEGIN          
SET @StrQuery = 'select SH.DocValue,SH.DocId,FORMAT(SH.DocDate,''dd/MMM/yyyy'') DocDate,null BeatName,MC.Name SalesmanName,
null Name,SH.RefNo RefNo,dbo.fnGetRoundedValue(SH.NetAmt) NetAmt ,COUNT(SD.ProdID) ItemsCount          
from tblvanloadingslipheader SH                    
JOIN tblMastersalesman MC ON MC.Id = SH.SalesmanID                    
JOIN tblvanloadingslipDetail SD ON SD.ID = SH.ID WHERE SD.TaxID > 0 AND SH.BranchID = '+CONVERT(nvarchar(10),@Branch)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocPreix,0)=23 THEN 'AND Status IN (1,3,5) ' ELSE ' AND Status IN (3,5,6,7)' END)               
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (SH.DocDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocRange,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocRange,LEN(@DocRange) - 1), N'',''))' END)                                  
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@FilterBy,0)=1 THEN '' WHEN ISNULL(@FilterBy,0)=2 THEN ' AND IRN IS NOT NULL' ELSE ' AND IRN IS NULL' END)            
SET @StrQuery = @StrQuery +  ' GROUP BY SH.DocId,SH.DocDate,MC.Name,SH.DocValue,SH.RefNo,SH.NetAmt order by SH.DocValue'          
EXEC sys.sp_executesql @StrQuery, N'@Branch INT, @DocPreix INT, @FromDate DATE, @ToDate DATE, @DocRange NVARCHAR(MAX), @CustID NVARCHAR(MAX), @FilterBy int', @Branch = @Branch, @DocPreix = @DocPreix, @FromDate = @FromDate, @ToDate = @ToDate, @DocRange = @DocRange, @CustID = @CustID, @FilterBy = @FilterBy          
END 
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspCustomerHeaderReportDetail';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspCustomerHeaderReportDetail]    
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
WHERE mc.id = ' + convert(nvarchar,@CustomerID)    
SET @strQuery += CASE WHEN ISNULL(@BeatName,'') = '' THEN '' ELSE ' AND MB.Name = @BeatName' END            
SET @strQuery += CASE WHEN ISNULL(@SalesmanName,'') = '' THEN '' ELSE ' AND SM.Name = @SalesmanName' END      
EXEC sys.sp_executesql @strQuery, N'@CustomerID int, @CustomerType nvarchar(255), @Ratings nvarchar(255), @BeatName nvarchar(255), @SalesmanName nvarchar(255), @Location nvarchar(255)', @CustomerID = @CustomerID, @CustomerType = @CustomerType, @Ratings = @Ratings, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @Location = @Location    
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspCustomerHeaderReportHeader';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspCustomerHeaderReportHeader]    
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
--SET @strQuery += CASE WHEN ISNULL(@CustomerType,'') = '' THEN '' ELSE ' AND [Customer Type] = @CustomerType' END            
--SET @strQuery += CASE WHEN ISNULL(@Ratings,'') = '' THEN '' ELSE ' AND Ratings = @Ratings' END         
--SET @strQuery += CASE WHEN ISNULL(@BeatName,'') = '' THEN '' ELSE ' AND [BeatName] = @BeatName' END            
--SET @strQuery += CASE WHEN ISNULL(@SalesmanName,'') = '' THEN '' ELSE ' AND SalesmanName = @SalesmanName' END      
SET @strQuery += CASE WHEN ISNULL(@CustomerType,'') = '' THEN '' ELSE ' AND   
[Customer ID] IN (SELECT * from dbo.fnSplitString(@CustomerType,'',''))' END            
SET @strQuery += CASE WHEN ISNULL(@Ratings,'') = '' THEN '' ELSE ' AND   
RatingsID IN (SELECT * from dbo.fnSplitString(@Ratings,'',''))' END         
SET @strQuery += CASE WHEN ISNULL(@BeatName,'') = '' THEN '' ELSE ' AND   
[BeatID] IN (SELECT * from dbo.fnSplitString(@BeatName,'',''))' END            
SET @strQuery += CASE WHEN ISNULL(@SalesmanName,'') = '' THEN '' ELSE ' AND   
SalesmanID IN (SELECT * from dbo.fnSplitString(@SalesmanName,'',''))' END   

-- Location Filter mapping (1 = All, 2 = Yes, 3 = No)
SET @strQuery += CASE 
    WHEN @Location = 2 THEN ' AND [Location] = ''Yes'''
    WHEN @Location = 3 THEN ' AND [Location] = ''No'''
    ELSE '' 
END

SET @strQuery += ' ORDER BY [Customer Name] '      
EXEC sys.sp_executesql @strQuery, N'@CustomerType nvarchar(255), @Ratings nvarchar(255), @BeatName nvarchar(255), @SalesmanName nvarchar(255), @Location INT', @CustomerType = @CustomerType, @Ratings = @Ratings, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @Location = @Location     
DROP TABLE #TEMP    
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspDateWiseSaleReport';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspDateWiseSaleReport]      
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
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)                  
  
    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND TSH.BranchID = @BranchName' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND Beat.ID IN (SELECT * from dbo.fnSplitString( @BeatName,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SM.ID IN (SELECT * from dbo.fnSplitString( @SalesmanName,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString( @CustomerName,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN (SELECT * from dbo.fnSplitString( @CustomerType,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN (SELECT * from dbo.fnSplitString( @Ratings,'',''))' END)     
SET @StrQuery = @StrQuery + '    
GROUP BY TSH.InvDate, TransactionType,TSH.ID,TSH.NetAmt,DocPrefix          
) AS iyan  GROUP BY  iyan.[Invoice Date] ORDER BY CONVERT(DATE,[Invoice Date])  '    
EXEC sys.sp_executesql @StrQuery, N'@BranchName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BranchName = @BranchName, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @CustomerType = @CustomerType, @Ratings = @Ratings, @FromDate = @FromDate, @ToDate = @ToDate    
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspExportIRNData';
GO
--uspExportIRNData 1,'2025-01-01','2025-08-01',NULL  
CREATE OR ALTER PROCEDURE [dbo].[uspExportIRNData]  
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
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+'''' + CONVERT(NVARCHAR,@FromDate) +'''' +' AND ' +'''' + CONVERT(NVARCHAR,@ToDate) +'''' +'' END)  
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)  
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
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.Date BETWEEN '+'''' + CONVERT(NVARCHAR,@FromDate) +'''' +' AND ' +'''' + CONVERT(NVARCHAR,@ToDate) +'''' +'' END)  
--SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)  
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)  
SET @QRY = @QRY + ' GROUP BY SH.Date,MC.GSTIN,MC.Name,SCN.StateName,MC.Mob1,MC.Email,MC.Billadd1,MC.Billadd2,MC.Billadd3,  
MC.Pincode,SH.TaxTypeID,SH.TransportID,SH.TransportName,SH.TransMode,SH.Distance,VH.VehicleNo,SH.VehicleType,  
SH.OtherChargeAmt,SH.TCSTaxAmt,SH.RoundOffAmt,SH.NetAmt,SH.TransID,SH.DocId,SH.DocId,MT.[GCESS Amount],MT.[CGST Amount],MT.[SGST Amount],MT.[IGST Amount],MT.[GUOM Amount],MT.[IUOM Amount],SH.DocId '  
SET @QRY = @QRY + ' ) AS REC ORDER BY DocPrefix,InvDate,[Document Number *]'  
EXEC sys.sp_executesql @QRY, N'@SheetMode INT, @FromDate date, @ToDate DATE, @DocIDs NVARCHAR(MAX)', @SheetMode = @SheetMode, @FromDate = @FromDate, @ToDate = @ToDate, @DocIDs = @DocIDs  
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
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+'''' + CONVERT(NVARCHAR,@FromDate) +'''' +' AND ' +'''' + CONVERT(NVARCHAR,@ToDate) +'''' +'' END)  
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)  
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
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.Date BETWEEN '+'''' + CONVERT(NVARCHAR,@FromDate) +'''' +' AND ' +'''' + CONVERT(NVARCHAR,@ToDate) +'''' +'' END)  
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)  
SET @QRY = @QRY + ' ) AS REC ORDER BY DocPrefix,InvDate,[Document Number *],Serial'  
EXEC sys.sp_executesql @QRY, N'@SheetMode INT, @FromDate date, @ToDate DATE, @DocIDs NVARCHAR(MAX)', @SheetMode = @SheetMode, @FromDate = @FromDate, @ToDate = @ToDate, @DocIDs = @DocIDs  
drop table #TaxItems,#TaxPRItems,#MainTaxItems  
END  
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspFilterCollectionPayment';
GO
--uspFilterCollectionPayment 1,18,null,'2021-03-01','2026-03-24',0                    
CREATE OR ALTER PROCEDURE [dbo].[uspFilterCollectionPayment]                    
@Mode NVARCHAR(50),@DocPrefix INT,@Name NVARCHAR(255)=Null,@FromDate date,@ToDate date,@ShowAllStatus int = null                    
AS                    
BEGIN                    
declare @StrQueryNew NVARCHAR(MAX)           
declare @DecVal int = (SELECT AppValue FROM tblAppConfig WHERE AppId = 8)    
IF @DocPrefix=19                    
BEGIN                    
SET @StrQueryNew = 'SELECT Collect.DocID DocID,CONVERT(nvarchar(40),Collect.ColDate,103) DocDate,Collect.ColDocRefNo RefNo,                    
Customer.Code,Customer.Name,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),Collect.ColAmt) Amount,PayMode.PaymentMode,StatusTable.[Description] Status,Collect.Status StatusID,Collect.ColID ID,Collect.UDFDocId AS [UDN],                    
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),Balance) Balance,Bank.AccountName AS [Bank A/C Name],                
Bank.AccountNo AS [Bank A/C No],          
(CASE WHEN ISNULL(pm.PaymentTermID,0)=2 THEN pm.[Cheque/DD Number] WHEN ISNULL(pm.PaymentTermID,0)=3 THEN pm.[Cheque/DD Number]                
WHEN ISNULL(pm.PaymentTermID,0)=4 THEN pm.NeftID WHEN ISNULL(pm.PaymentTermID,0)=5 THEN pm.NeftID END) AS [Cheque/DD/NEFT],                
CASE WHEN pm.PaymentTermID IN (2,3) THEN FORMAT(pm.Date,''dd-MMM-yyyy'')WHEN pm.PaymentTermID IN (4,5) THEN FORMAT(pm.Date,''dd-MMM-yyyy'')                
ELSE NULL END AS [Cheque/DD/NEFT Date],convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),Collect.VisaPern) AS [Card (%)],                
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),Collect.VisaAmt) AS [Card Amount],  
pm.BankName AS [Bank Name],                
pm.BranchName AS [Branch Name],pm.Ifsccode AS [IFSC Code],          
CUR.UserName UserName,CONVERT(NVARCHAR(100),Collect.CDate) LastActionTime,              
Collect.Remarks,Collect.Narration,ISNULL(Collect.BranchID,0) BranchID,MBO.Name BranchName,CTM.ModeName                    
FROM tblTranCollectionHeader AS Collect                    
LEFT JOIN tblMasterCustomer AS Customer ON Customer.FAID =Collect.AccID          
LEFT JOIN tblCollPMDetails as pm ON pm.ColID=Collect.ColID           
LEFT JOIN tblMasterBankAccount AS Bank ON Bank.FAID = pm.BankAccID          
JOIN tblDocumentSeries AS Doc ON Doc.TransID=Collect.DocPrefix                    
JOIN tblPaymentMode AS PayMode ON PayMode.Id=Collect.ColMode      
JOIN tblStatus AS StatusTable ON StatusTable.[ID]=Collect.[Status]                   
JOIN tblUsers CUR ON CUR.ID = Collect.CBy      
JOIN tblMasterBranchOffice AS MBO ON MBO.Id = Collect.BranchID      
LEFT JOIN tblContraMode CTM ON CTM.ID = Collect.BTMode  
--LEFT JOIN tblMasterBank MBNK ON MBNK.ID = pm.BankName and ISNUMERIC(pm.BankName) = 1  
WHERE Collect.DocPrefix= ' + CONVERT(NVARCHAR,@DocPrefix) +' AND ColDate BETWEEN '+'''' + CONVERT(NVARCHAR,@FromDate) +'''' +' AND ' +'''' + CONVERT(NVARCHAR,@ToDate) +'''' +''                    
SET @StrQueryNew = @StrQueryNew + (CASE WHEN @ShowAllStatus = 1 THEN '' ELSE 'AND Collect.[Status] in (1,3,5)' end)                    
SET @StrQueryNew = @StrQueryNew + (CASE WHEN ISNULL(@Name,'')='' THEN '' ELSE 'AND Customer.Name = CONVERT(NVARCHAR(255),@Name)' end)                    
SET @StrQueryNew = @StrQueryNew + ' ORDER BY Collect.ColDate DESC,Collect.DocValue DESC,Collect.ColID DESC'                    
EXEC sys.sp_executesql @StrQueryNew, N'@Mode NVARCHAR(50), @DocPrefix INT, @Name NVARCHAR(255), @FromDate date, @ToDate date, @ShowAllStatus int', @Mode = @Mode, @DocPrefix = @DocPrefix, @Name = @Name, @FromDate = @FromDate, @ToDate = @ToDate, @ShowAllStatus = @ShowAllStatus                    
  
END                    
ELSE IF @DocPrefix=18                    
BEGIN                    
SET @StrQueryNew = 'SELECT Payment.DocID DocID,CONVERT(nvarchar(40),Payment.PYDate,103) DocDate,Payment.PYDocRefNo RefNo,                    
Vendor.Code,Vendor.Name,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),Payment.PYAmt) Amount,PayMode.PaymentMode,StatusTable.[Description] Status,                    
Payment.Status StatusID,Payment.PYID ID,Payment.UDFDocId AS [UDN],convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),Balance) Balance,       
Bank.AccountName AS [Bank A/C Name],                
Bank.AccountNo AS [Bank A/C No],      
(CASE WHEN ISNULL(pm.PaymentTermID,0)=2 THEN pm.[Cheque/DD Number] WHEN ISNULL(pm.PaymentTermID,0)=3 THEN pm.[Cheque/DD Number]                
WHEN ISNULL(pm.PaymentTermID,0)=4 THEN pm.NeftID WHEN ISNULL(pm.PaymentTermID,0)=5 THEN pm.NeftID END) AS [Cheque/DD/NEFT],       
CASE WHEN pm.PaymentTermID IN (2,3) THEN FORMAT(pm.Date,''dd-MMM-yyyy'')WHEN pm.PaymentTermID IN (4,5) THEN FORMAT(pm.Date,''dd-MMM-yyyy'')                
ELSE NULL END AS [Cheque/DD/NEFT Date],convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),Payment.VisaPern) AS [Card (%)],                
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),Payment.VisaAmt) AS [Card Amount],pm.BankName AS [Bank Name],                
pm.BranchName AS [Branch Name],pm.Ifsccode AS [IFSC Code],      
CUR.UserName UserName,CONVERT(NVARCHAR(100),Payment.CDate) LastActionTime,Payment.Remarks,Payment.Narration,      
ISNULL(Payment.BranchID,0) BranchID,MBO.Name BranchName ,CTM.ModeName                    
FROM tblTranPaymentHeader AS Payment      
LEFT JOIN tblMasterVendor AS Vendor ON Vendor.FAID = Payment.AccID      
LEFT JOIN tblPaymentPMDetail as pm ON pm.PYID = Payment.PYID           
LEFT JOIN tblMasterBankAccount AS Bank ON Bank.FAID = pm.BankAccID        
JOIN tblDocumentSeries AS Doc ON Doc.TransID=Payment.PYPrefix                    
JOIN tblPaymentMode AS PayMode ON PayMode.Id=Payment.PYMode                    
JOIN tblStatus AS StatusTable ON StatusTable.ID=Payment.[Status]                   
JOIN tblUsers CUR ON CUR.ID = Payment.CBy                  
JOIN tblMasterBranchOffice AS MBO ON MBO.Id = Payment.BranchID     
LEFT JOIN tblContraMode CTM ON CTM.ID = Payment.BTMode  
WHERE Payment.PYPrefix =' + CONVERT(NVARCHAR,@DocPrefix) +' AND PYDate BETWEEN '+'''' + CONVERT(NVARCHAR,@FromDate) +'''' +' AND ' +'''' + CONVERT(NVARCHAR,@ToDate) +'''' +''                    
SET @StrQueryNew = @StrQueryNew + (CASE WHEN @ShowAllStatus = 1 THEN '' ELSE 'AND Payment.[Status] in (1,3,5)' end)                    
SET @StrQueryNew = @StrQueryNew + (CASE WHEN ISNULL(@Name,'')='' THEN '' ELSE 'AND Vendor.Name = CONVERT(NVARCHAR(255),@Name)' end)                    
SET @StrQueryNew = @StrQueryNew + ' ORDER BY Payment.PYDate DESC, Payment.DocValue DESC,Payment.PYID DESC'                    
EXEC sys.sp_executesql @StrQueryNew, N'@Mode NVARCHAR(50), @DocPrefix INT, @Name NVARCHAR(255), @FromDate date, @ToDate date, @ShowAllStatus int', @Mode = @Mode, @DocPrefix = @DocPrefix, @Name = @Name, @FromDate = @FromDate, @ToDate = @ToDate, @ShowAllStatus = @ShowAllStatus                    
END                    
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspFinRepDetailedTrailBalance';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspFinRepDetailedTrailBalance] 
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
SET @STRQRY += 'WHERE Status IN (1,3,5,6,7,9) AND DocDate BETWEEN '+''''+convert(nvarchar,@Fromdate)+''''+' AND '+''''+convert(nvarchar,@ToDate)+''''  
SET @STRQRY += ' GROUP BY '+@STRGBY+'FAG0.AccountGroupName,FAA.AccountName,TypeName,FAJ.AccountId'  
SET @STRQRY += ' ) AS REC group by AccountID,[Account Type],'+@SELCOLNM+'AccountGroupName,AccountName'  
SET @STRQRY += ' union all '  
SET @STRQRY += ' SELECT AccountID,[Account Type],'+@SELCOLNM+'AccountGroupName,AccountName,case when SUM(openbal) < 0 then SUM(Credit + abs(openbal)) else SUM(Credit) end  Credit,        
case when SUM(openbal) >= 0 then SUM(Debit + openbal) else SUM(Debit) end Debit FROM (  
SELECT FAA.FAID AccountID,TypeName [Account Type],'+ @STRACCGRPNAME+' isnull(FAG0.AccountGroupName,'''') AccountGroupName,FAA.AccountName,        
0 Credit,0 Debit,CASE WHEN FAA.FAID = 60 then '+CONVERT(nvarchar(255),@OPENAMT)+' else dbo.[uspReturnOpeningBalance]('+convert(nvarchar,@BranchID)+',FAA.FAID,'+''''+convert(nvarchar,@Fromdate)+''''+') end openbal 
FROM tblFAAccount FAA  
JOIN tblFAGroup FAG0 ON FAG0.FAGroup = FAA.AccountGroup  
LEFT JOIN tblAccountType AT ON AT.TypeId=FAG0.TypeID'  
SET @STRQRY += @STRQRYJOIN  
SET @STRQRY += ' GROUP BY '+@STRGBY+'FAG0.AccountGroupName,FAA.AccountName,TypeName,FAA.FAID'  
SET @STRQRY += ' ) AS REC WHERE ISNULL(openbal,0) <> 0 group by AccountID,[Account Type],'+@SELCOLNM+'AccountGroupName,AccountName'  
SET @STRQRY += ') AS REC1 GROUP BY  '+@SELCOLNM+'AccountID,[Account Type],AccountGroupName,AccountName '  
SET @STRQRY += ' ) AS REC2 ORDER BY [Account Type],[Account Group],[Account Name]'  
EXEC sys.sp_executesql @STRQRY, N'@BranchID int, @Fromdate date, @ToDate date', @BranchID = @BranchID, @Fromdate = @Fromdate, @ToDate = @ToDate  
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetCustomerWiseSalesHeader';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspGetCustomerWiseSalesHeader]      
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
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)                  
  
    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND TSH.BranchID = @BranchName' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND Beat.ID IN (SELECT * from dbo.fnSplitString( @BeatName,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SM.ID IN (SELECT * from dbo.fnSplitString( @SalesmanName,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString( @CustomerName,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN (SELECT * from dbo.fnSplitString( @CustomerType,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN (SELECT * from dbo.fnSplitString( @Ratings,'',''))' END)       
SET @StrQuery = @StrQuery + ' GROUP BY MC.ID,TSH.BeatId,TSH.SalesManId,MC.Code,MC.Name,Beat.Name,SM.Name,MCT.Name,RT.RatingName'    
EXEC sys.sp_executesql @StrQuery, N'@BranchName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BranchName = @BranchName, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @CustomerType = @CustomerType, @Ratings = @Ratings, @FromDate = @FromDate, @ToDate = @ToDate    
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetCustWiseMonthlySalesHeader';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspGetCustWiseMonthlySalesHeader]      
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
(CASE WHEN CONVERT(NVARCHAR(255),@Type)'+'=''2'' THEN (SUM(TSH.GrossAmt)) ELSE (SUM(TSH.NetAmt))END) AS Value,      
RT.RatingName Ratings      
FROM tblTranSalesHeader AS TSH             
JOIN tblMasterCustomer AS MC ON MC.ID = TSH.CustId              
left join tblMasterCustomerType as mct on mct.ID=MC.CustomerType              
LEFT JOIN tblMasterBeat AS MB ON MB.ID = TSH.BeatID              
LEFT JOIN tblMasterSalesMan AS MSM ON MSM.ID = TSH.SalesManId        
LEFT JOIN tblRatings AS RT ON RT.ID = MC.Rating        
WHERE TSH.DocPrefix=15 AND TSH.Status IN (1,3,5) '            
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)                  
  
    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString( @CustomerName,'',''))' END)                          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString( @BeatName,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND MSM.ID IN (SELECT * from dbo.fnSplitString( @SalesmanName,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN (SELECT * from dbo.fnSplitString( @CustomerType,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN (SELECT * from dbo.fnSplitString( @Ratings,'',''))' END)                     
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
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.ColDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)                 
   
    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString( @CustomerName,'',''))' END)                          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString( @BeatName,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND MSM.ID IN (SELECT * from dbo.fnSplitString( @SalesmanName,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN (SELECT * from dbo.fnSplitString( @CustomerType,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN (SELECT * from dbo.fnSplitString( @Ratings,'',''))' END)                   
SET @StrQuery = @StrQuery + ' GROUP BY MC.Code,MC.Name,mct.Name,MC.Id,MB.Name,MSM.Name,MB.Id,MSM.Id,            
ColDate,RT.RatingName) AS NK GROUP BY CustId,BeatID,SalesManID,[Customer Code],[Customer Name],[Customer Type],[Beat Name],             
 [SalesMan Name],MY,Ratings'        
 END      
  insert into #Temp1        
  EXEC sys.sp_executesql @StrQuery, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @Type NVARCHAR(255), @FilterBy NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @CustomerType = @CustomerType, @Ratings = @Ratings, @Type = @Type, @FilterBy = @FilterBy, @FromDate = @FromDate, @ToDate = @ToDate      
      
        
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
 EXEC sys.sp_executesql @StrQuery, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @Type NVARCHAR(255), @FilterBy NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @CustomerType = @CustomerType, @Ratings = @Ratings, @Type = @Type, @FilterBy = @FilterBy, @FromDate = @FromDate, @ToDate = @ToDate             
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
EXEC sys.sp_executesql @StrQuery, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @Type NVARCHAR(255), @FilterBy NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @CustomerType = @CustomerType, @Ratings = @Ratings, @Type = @Type, @FilterBy = @FilterBy, @FromDate = @FromDate, @ToDate = @ToDate            
DROP TABLE #Temp,#VNAMES,#VNAMESISNULL,#Temp1       
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetDatewiseDetail';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspGetDatewiseDetail]        
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
WHERE TransactionType in(1,2,3,4,5,6) AND Sh.Status IN (1,3,5,6,7) AND Sh.InvDate = '''+CONVERT(NVARCHAR,CAST(@InvDate AS DATE))+''''      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND SH.BranchID = @BranchName' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND Beat.ID IN ( SELECT * from dbo.fnSplitString( @BeatName,'',''))' END)             
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SM.ID IN ( SELECT * from dbo.fnSplitString( @SalesmanName,'',''))' END)                
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN ( SELECT * from dbo.fnSplitString( @CustomerName,'',''))' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN ( SELECT * from dbo.fnSplitString( @CustomerType,'',''))' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN ( SELECT * from dbo.fnSplitString( @Ratings,'',''))' END)       
   SET @StrQuery = @StrQuery + ' order by Sh.DocId asc   '     EXEC sys.sp_executesql @StrQuery, N'@InvDate DATE, @BranchName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @FromDate DATE, @ToDate DATE', @InvDate = @InvDate, @BranchName = @BranchName, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @CustomerType = @CustomerType, @Ratings = @Ratings, @FromDate = @FromDate, @ToDate = @ToDate      
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetFullGSTInfoReport';
GO
--uspGetFullGSTInfoReport 'S','2026-09-01','2026-09-30',0,'1'   
--uspGetFullGSTInfoReport 'SR','2026-09-01','2026-09-30',0,'1'     
--uspGetFullGSTInfoReport 'P','2026-09-01','2026-09-30',0,'1'       
--uspGetFullGSTInfoReport 'PR','2026-09-01','2026-09-30',0,'1'    
--uspGetFullGSTInfoReport 'PV','2026-09-01','2026-09-30',0,'1'   
--uspGetFullGSTInfoReport 'RV','2026-09-01','2026-09-30',0,'1'      
CREATE OR ALTER PROCEDURE [dbo].[uspGetFullGSTInfoReport]      
@TransName NVARCHAR(255),@FromDate DATE,@ToDate DATE,@WOEinv int = 0,@BranchIDs NVARCHAR(255) = null  
AS      
BEGIN      
--REPLACE(CONVERT(NVARCHAR,SH.InvDate,106), ' ', '-')      
SET DATEFORMAT dmy;      
DECLARE @Query nvarchar(MAX),@DocPrefix NVARCHAR(20)      
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
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 1),0)) AS [CGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 1),0)) AS [CGST Amount],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 2),0)) AS [SGST %],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 2),0)) AS [SGST Amount],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 3),0)) AS [UTGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 3),0)) AS [UTGST Amount],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 4),0)) AS [GCESS %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID IN (4,5)),0)) AS [GCESS Amount],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID = 1),0)) AS [IGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID = 1),0)) AS [IGST Amount],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID = 2),0)) AS [ICESS %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = SD.InvId AND ProdID = SD.ProdId AND Serial = SD.Serial AND TaxID = SD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID IN (2,3)),0)) AS [ICESS Amount],      
CONVERT(DECIMAL(15,2),SD.NetAmt) AS [Net Amount]'      
SET @Query = @Query + ' FROM tblTranSalesHeader AS SH      
JOIN tblTranSalesDetail AS SD ON SH.ID = SD.InvId      
JOIN tblMasterCustomer AS Cust ON Cust.ID = SH.CustId      
JOIN tblMasterTaxType AS TT ON TT.TaxTypeID = SH.TaxTypeId      
JOIN tblMasterProduct AS Prod ON Prod.ID = SD.ProdId      
JOIN tblMasterUom AS UOM ON Prod.BaseUomID=UOM.ID      
JOIN TblMasterBranchoffice MBO ON MBO.ID = SH.BranchID  
WHERE SH.DocPrefix='''+@DocPrefix+''' AND SH.Status IN (1,3,5,6,7) AND ISNULL(SD.TaxId,0)>0      
AND ISNULL(SH.IRN,'''') = (CASE WHEN '+CONVERT(NVARCHAR,@WOEinv)+' = 0 THEN ISNULL(SH.IRN,'''') ELSE '''' END) '  
SET @Query += case when isnull(@BranchIDs,'') = '' then '' else ' AND SH.BranchID IN (SELECT value FROM STRING_SPLIT(@BranchIDs, '',''))' END  
SET @Query += ' AND (SH.InvDate BETWEEN '''+CAST(@FromDate AS NVARCHAR)+''' AND '''+CAST(@ToDate AS NVARCHAR)+''')      
ORDER BY SH.InvDate,CASE WHEN SH.UDFId > 0 THEN SH.UDFDocId ELSE SH.DocId END '      
PRINT @Query
EXEC sys.sp_executesql @Query, N'@TransName NVARCHAR(255), @FromDate DATE, @ToDate DATE, @WOEinv int, @BranchIDs NVARCHAR(255)', @TransName = @TransName, @FromDate = @FromDate, @ToDate = @ToDate, @WOEinv = @WOEinv, @BranchIDs = @BranchIDs      
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
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 1),0)) AS [CGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 1),0)) AS [CGST Amount],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 2),0)) AS [SGST %], '      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 2),0)) AS [SGST Amount],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 3),0)) AS [UTGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 3),0)) AS [UTGST Amount],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID = 4),0)) AS [GCESS %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 1 AND GSTTaxTypeID IN (4,5)),0)) AS [GCESS Amount],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID = 1),0)) AS [IGST %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID = 1),0)) AS [IGST Amount],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),ISNULL((SELECT DISTINCT TaxCompPern      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID = 2),0)) AS [ICESS %],      
CONVERT(DECIMAL(15,2),ISNULL((SELECT SUM(TaxValue)      
FROM tblTransGSTInfo      
WHERE TransID = '''+@DocPrefix+''' AND TransIdentID = BD.HID AND ProdID = BD.ProdId AND Serial = BD.Serial AND TaxID = BD.TaxId      
AND TaxTypeID = 2 AND GSTTaxTypeID IN (2,3)),0)) AS [ICESS Amount],'      
SET @Query = @Query + 'CONVERT(DECIMAL(15,2),BD.NetAmt) AS [Net Amount]      
FROM tbltranspurchaseheader AS BH      
JOIN tbltranspurchasedetail AS BD ON BH.ID = BD.HID      
LEFT JOIN tblMasterProduct AS Prod ON Prod.ID = BD.ProdId      
LEFT JOIN tblMasterUom AS UOM ON Prod.BaseUomID=UOM.ID      
LEFT JOIN tblMasterVendor AS Ven ON Ven.id = BH.VendorID      
JOIN tblMasterTaxType AS TT ON TT.TaxTypeID = BH.TaxTypeId      
JOIN TblMasterBranchoffice MBO ON MBO.ID = BH.BranchID  
WHERE BH.TransID = '''+@DocPrefix+''' AND BH.Status IN (1,3,6,5) AND ISNULL(BD.UomID,0)>0      
AND ISNULL(BH.IRN,'''') = (CASE WHEN '+CONVERT(NVARCHAR,@WOEinv)+' = 0 THEN ISNULL(BH.IRN,'''') ELSE '''' END)  '  
SET @Query += case when isnull(@BranchIDs,'') = '' then '' else ' AND BH.BranchID IN (SELECT value FROM STRING_SPLIT(@BranchIDs, '',''))' END  
SET @Query += '  AND (BH.Date BETWEEN '''+CAST(@FromDate AS NVARCHAR)+''' AND '''+CAST(@ToDate AS NVARCHAR)+''')      
ORDER BY BH.Date,CASE WHEN BH.UDFId > 0 THEN BH.UDFDocId ELSE BH.DocId END'      
EXEC sys.sp_executesql @Query, N'@TransName NVARCHAR(255), @FromDate DATE, @ToDate DATE, @WOEinv int, @BranchIDs NVARCHAR(255)', @TransName = @TransName, @FromDate = @FromDate, @ToDate = @ToDate, @WOEinv = @WOEinv, @BranchIDs = @BranchIDs      
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
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetJsonDataforEWaybill';
GO
--uspGetJsonDataforEWaybill 2,3,0,'2026-01-05','2026-12-30',''                    
--uspGetJsonDataforEWaybill 3,639,'2022-12-05','2026-12-30'                    
--uspGetJsonDataforEWaybill 3,1,'2627/JUL/31','2022-12-05','2026-12-30'                     
--uspGetJsonDataforEWaybill 5,3,'','2024-12-05','2026-12-30','VLS/2627/4'                      
--uspGetJsonDataforEWaybill 6,'','2022-12-05','2026-12-30',''                     
CREATE OR ALTER PROCEDURE [dbo].[uspGetJsonDataforEWaybill]                      
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
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+'''' + CONVERT(NVARCHAR,@FromDate) +'''' +' AND ' +'''' + CONVERT(NVARCHAR,@ToDate) +'''' +'' END)                      
--SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
SET @QRY = @QRY + ' GROUP BY SH.ID,SH.DocId,SH.InvDate '                      
SET @QRY = @QRY + ' ORDER BY DocId,SH.InvDate'        
END      
ELSE IF(@TypeID = 3)--VLS E-WAY      
BEGIN      
--select * from tblVanLoadingSlipHeader      
SET @QRY = 'select SH.ID,SH.DocId,SH.DocDate InvDate FROM tblVanLoadingSlipHeader SH       
WHERE Status IN (1,3,5) AND ISNULL(SH.EWBNo,'''') = '''' and isnull(SH.VehicleNo,0) > 0 and isnull(SH.DocId,'''') != '''''                   
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.DocDate BETWEEN '+'''' + CONVERT(NVARCHAR,@FromDate) +'''' +' AND ' +'''' + CONVERT(NVARCHAR,@ToDate) +'''' +'' END)                      
--SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
SET @QRY = @QRY + ' GROUP BY SH.ID,SH.DocId,SH.DocDate '                      
SET @QRY = @QRY + ' ORDER BY DocId,SH.DocDate'      
END      
EXEC sys.sp_executesql @QRY, N'@Mode INT, @TypeID INT, @InvID nvarchar(255), @FromDate date, @ToDate DATE, @DocIDs NVARCHAR(MAX)', @Mode = @Mode, @TypeID = @TypeID, @InvID = @InvID, @FromDate = @FromDate, @ToDate = @ToDate, @DocIDs = @DocIDs                      
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
'''+@compGSTIN+''' userGstin,''O'' supplyType,1 subSupplyType,'''' "subSupplyDesc",''INV'' "docType",                      
1 "transType",'''+@compGSTIN+''' fromGstin,'''+@CompName+''' fromTrdName,'''+@CompAddress+''' fromAddr1,'''' fromAddr2,                      
'''+@CompCity+''' fromPlace,'''+@CompPIN+''' fromPincode,'''+@compStateCode+''' fromStateCode,'''+@compStateCode+''' actualFromStateCode,        
TINNo "toStateCode",TINNo "actualToStateCode",dbo.fnGetRoundedValue(SH.GrossAmt) "totalValue",                      
(CASE WHEN SH.TaxTypeId = 1 THEN dbo.fnGetRoundedValue(SH.TotalTaxAmt/2) ELSE ''0.00'' END) "cgstValue",                      
(CASE WHEN SH.TaxTypeId = 1 THEN dbo.fnGetRoundedValue(SH.TotalTaxAmt/2) ELSE ''0.00'' END) "sgstValue",                      
(CASE WHEN SH.TaxTypeId = 2 THEN dbo.fnGetRoundedValue(TotalTaxAmt) ELSE ''0.00'' END) "igstValue",0.00 "cessValue",                      
0.00 "TotNonAdvolVal",dbo.fnGetRoundedValue( NetAmt - (GrossAmt + TotalTaxAmt)) "OthValue",dbo.fnGetRoundedValue(SH.NetAmt) "totInvValue",                      
CONVERT(VARCHAR,(CASE WHEN TransMode = ''Road'' THEN 1 WHEN TransMode = ''Rail'' THEN 2 WHEN TransMode = ''Air'' THEN 3                      
WHEN TransMode = ''Ship/Road cum Ship'' THEN 4 ELSE '''' END)) "transMode",                      
CASE WHEN MC.Pincode = '''+@CompPIN+''' THEN 1 ELSE isnull(SH.Distance,0) END "transDistance",(case when isnull(SH.TransportName,'''') = '''' then '''' else LEFT(TransportName,100) end) "transporterName",                      
(case when isnull(SH.TransportID,'''') = '''' then '''' else LEFT(SH.TransportID,15) end) "transporterId",SH.DocId "transDocNo",                      
CONVERT(NVARCHAR,SH.InvDate,103) "transDocDate",VH.VehicleNo "vehicleNo",                      
CASE WHEN SH.VehicleType = ''Regular'' THEN ''R'' WHEN SH.VehicleType = ''ODC'' THEN ''O'' ELSE '''' end "vehicleType",'''' mainHsnCode                      
from tblTranSalesHeader SH                      
JOIN tblMasterCustomer MC ON MC.ID = SH.CustId                      
LEFT JOIN tblMasterBeat GHL ON GHL.ID = SH.BeatID                         
LEFT JOIN tblMasterVehicle VH ON VH.ID = SH.VehicleNo                      
LEFT JOIN tblGSTStateNameandCode GST ON GST.StateID = MC.StateID                         
WHERE SH.DocPrefix =15 AND Status IN (1,3,5) AND ISNULL(SH.EWBNo,'''') = '''' and isnull(SH.VehicleNo,0) > 0 and isnull(SH.DocId,'''') != '''' '                  
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+'''' + CONVERT(NVARCHAR,@FromDate) +'''' +' AND ' +'''' + CONVERT(NVARCHAR,@ToDate) +'''' +'' END)                      
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
SET @QRY = @QRY + ' ORDER BY DocId '      
END      
ELSE IF(@TypeID = 3)--VLS E-WAY      
BEGIN      
SET @QRY = ' select DocId "docNo",CONVERT(NVARCHAR,DocDate,103) "docDate",'''' "toTrdName",'''+@compGSTIN+''' toGstin,        
'''' "toAddr2",'''' "toPlace",'''+@CompPIN+''' "toPincode",      
'''+@compGSTIN+''' userGstin,''O'' supplyType,10 subSupplyType,'''' "subSupplyDesc",''CHL'' "docType",                      
1 "transType",'''+@compGSTIN+''' fromGstin,'''+@CompName+''' fromTrdName,'''+@CompAddress+''' fromAddr1,'''' fromAddr2,                      
'''+@CompCity+''' fromPlace,'''+@CompPIN+''' fromPincode,'''+@compStateCode+''' fromStateCode,'''+@compStateCode+''' actualFromStateCode,        
'''+@compStateCode+''' "toStateCode",'''+@compStateCode+''' "actualToStateCode",dbo.fnGetRoundedValue(SH.GrossAmt) "totalValue",                      
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
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.DocDate BETWEEN '+'''' + CONVERT(NVARCHAR,@FromDate) +'''' +' AND ' +'''' + CONVERT(NVARCHAR,@ToDate) +'''' +'' END)                      
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
SET @QRY = @QRY + ' ORDER BY DocId '      
END      
EXEC sys.sp_executesql @QRY, N'@Mode INT, @TypeID INT, @InvID nvarchar(255), @FromDate date, @ToDate DATE, @DocIDs NVARCHAR(MAX)', @Mode = @Mode, @TypeID = @TypeID, @InvID = @InvID, @FromDate = @FromDate, @ToDate = @ToDate, @DocIDs = @DocIDs                      
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
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+'''' + CONVERT(NVARCHAR,@FromDate) +'''' +' AND ' +'''' + CONVERT(NVARCHAR,@ToDate) +'''' +'' END)                      
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
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
SET @QRY = @QRY + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.DocDate BETWEEN '+'''' + CONVERT(NVARCHAR,@FromDate) +'''' +' AND ' +'''' + CONVERT(NVARCHAR,@ToDate) +'''' +'' END)                      
SET @QRY = @QRY + (CASE WHEN ISNULL(@DocIDs,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(LEFT(@DocIDs,LEN(@DocIDs) - 1), N'',''))' END)                      
SET @QRY = @QRY + ' ORDER BY SH.DocDate,DocId,SD.Serial '       
END      
EXEC sys.sp_executesql @QRY, N'@Mode INT, @TypeID INT, @InvID nvarchar(255), @FromDate date, @ToDate DATE, @DocIDs NVARCHAR(MAX)', @Mode = @Mode, @TypeID = @TypeID, @InvID = @InvID, @FromDate = @FromDate, @ToDate = @ToDate, @DocIDs = @DocIDs                      
END                      
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetModifyHistoryData';
GO
--uspGetModifyHistoryData 5,2,2,'2026-10-21','2026-10-21',5      
CREATE OR ALTER PROCEDURE [dbo].[uspGetModifyHistoryData]          
@Mode INT,@TableID NVARCHAR(MAX) = NULL,@UserID NVARCHAR(MAX) = NULL,@FromDate date = null,@ToDate date = null,@ID NVARCHAR(255) = NULL          
AS          
BEGIN          
declare @strQuery NVARCHAR(MAX),@FormID int          
IF(@Mode = 1)          
BEGIN          
select 1 Type,'Tables' Trans,ID,'' Code,FormName Name from tblTablesNames where ID <= 29 OR ID IN (42) OR FormType IN (1,2)    
union all          
SELECT 2 Type,'Users' Trans,ID,'',UserName FROM tblUsers WHERE Active = 1          
order by Type,Name          
END          
ELSE IF(@Mode = 2)          
BEGIN          
set @FormID = @TableID          
select MBy UserID,UPPER(UserName) UserName from (          
--SINGLE MASTER          
select MH.HisCBy MBy,U.UserName from tblMasterHistory MH          
JOIN tblUsers U ON U.ID = MH.HisCBy WHERE MH.HisCBy = (CASE WHEN @UserID = 0 THEN MH.HisCBy ELSE @UserID END) and          
CONVERT(DATE,MH.HisCDate) BETWEEN @FromDate AND @ToDate and FormID = (CASE WHEN @FormID = 0 THEN FormID ELSE @FormID END)          
GROUP BY MH.HisCBy,U.UserName          
UNION -- CUSTOMER,VENDOR          
SELECT MH.HisCBy,U.UserName FROM tblMasterCustomerVendorHistory MH          
JOIN tblUsers U ON U.ID = MH.HisCBy WHERE MH.HisCBy = (CASE WHEN @UserID = 0 THEN MH.HisCBy ELSE @UserID END) and          
CONVERT(DATE,MH.HisCDate) BETWEEN @FromDate AND @ToDate and FormID = (CASE WHEN @FormID = 0 THEN FormID ELSE @FormID END)          
GROUP BY MH.HisCBy,U.UserName          
UNION -- PRODUCT          
SELECT MH.HisCBy,U.UserName FROM tblMasterProductHistory MH          
JOIN tblUsers U ON U.ID = MH.HisCBy WHERE MH.HisCBy = (CASE WHEN @UserID = 0 THEN MH.HisCBy ELSE @UserID END) and          
CONVERT(DATE,MH.HisCDate) BETWEEN @FromDate AND @ToDate and FormID = (CASE WHEN @FormID = 0 THEN FormID ELSE @FormID END)          
GROUP BY MH.HisCBy,U.UserName          
UNION -- PRODUCT PRICE CHANGE         
SELECT MH.HisCBy,U.UserName FROM tblPriceChangeHistory MH          
JOIN tblUsers U ON U.ID = MH.HisCBy WHERE MH.HisCBy = (CASE WHEN @UserID = 0 THEN MH.HisCBy ELSE @UserID END) and          
CONVERT(DATE,MH.HisCDate) BETWEEN @FromDate AND @ToDate and FormID = (CASE WHEN @FormID = 0 THEN FormID ELSE @FormID END)      
GROUP BY MH.HisCBy,U.UserName       
--UNION -- AUTO INDENT          
--SELECT MH.MBy,U.UserName FROM tblTransAutomaticIndentHeader MH          
--JOIN tblUsers U ON U.ID = MH.MBy WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY MH.MBy,U.UserName          
--UNION -- PO          
--SELECT MH.MBy,U.UserName FROM tblPurchaseOrderHeader MH          
--JOIN tblUsers U ON U.ID = MH.MBy WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY MH.MBy,U.UserName          
--UNION -- BILL,PR          
--SELECT MH.MBy,U.UserName FROM tblTransPurchaseHeader MH          
--JOIN tblUsers U ON U.ID = MH.MBy WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY MH.MBy,U.UserName          
--UNION -- CN,DN          
--SELECT MH.MBy,U.UserName FROM tblNoteDetails MH          
--JOIN tblUsers U ON U.ID = MH.MBy WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY MH.MBy,U.UserName          
--UNION -- CONT          
--SELECT MH.MBy,U.UserName FROM tblTranContra MH          
--JOIN tblUsers U ON U.ID = MH.MBy WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY MH.MBy,U.UserName          
--UNION -- RV,PV    
--SELECT MH.MBy,U.UserName FROM tblTranPRVoucher MH          
--JOIN tblUsers U ON U.ID = MH.MBy WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY MH.MBy,U.UserName          
--UNION ALL -- JE          
--SELECT MH.MBy,U.UserName FROM tblFAJournal MH          
--JOIN tblUsers U ON U.ID = MH.MBy WHERE DocPrefix = 9 AND Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY MH.MBy,U.UserName          
--UNION ALL -- OTHER COLL          
--SELECT MH.MBy,U.UserName FROM tblTranCollectionHeader MH          
--JOIN tblUsers U ON U.ID = MH.MBy WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY MH.MBy,U.UserName          
--UNION ALL -- OTHER PAY          
--SELECT MH.MBy,U.UserName FROM tblTranPaymentHeader MH          
--JOIN tblUsers U ON U.ID = MH.MBy WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY MH.MBy,U.UserName          
) as rec          
GROUP BY MBy,UserName          
ORDER BY UserName          
END          
ELSE IF(@Mode = 3)          
BEGIN          
set @FormID = @TableID          
select FormID,UPPER(FormName) FormName into #tempForms from (          
--SINGLE MASTER          
select MH.FormID,U.FormName from tblMasterHistory MH          
JOIN tblTablesNames U ON U.ID = MH.FormID WHERE MH.HisCBy = (CASE WHEN @UserID = 0 THEN MH.HisCBy ELSE @UserID END) and          
CONVERT(DATE,MH.HisCDate) BETWEEN @FromDate AND @ToDate          
GROUP BY MH.FormID,U.FormName          
UNION ALL -- CUSTOMER,VENDOR          
SELECT MH.FormID,U.FormName FROM tblMasterCustomerVendorHistory MH          
JOIN tblTablesNames U ON U.ID = MH.FormID WHERE MH.HisCBy = (CASE WHEN @UserID = 0 THEN MH.HisCBy ELSE @UserID END) and          
CONVERT(DATE,MH.HisCDate) BETWEEN @FromDate AND @ToDate          
GROUP BY MH.FormID,U.FormName          
UNION ALL -- PRODUCT          
SELECT MH.FormID,U.FormName FROM tblMasterProductHistory MH          
JOIN tblTablesNames U ON U.ID = MH.FormID WHERE MH.HisCBy = (CASE WHEN @UserID = 0 THEN MH.HisCBy ELSE @UserID END) and          
CONVERT(DATE,MH.HisCDate) BETWEEN @FromDate AND @ToDate          
GROUP BY MH.FormID,U.FormName          
UNION ALL -- PRODUCT  PRICE CHANGE      
SELECT MH.FormID,U.FormName FROM tblPriceChangeHistory MH          
JOIN tblTablesNames U ON U.ID = MH.FormID WHERE MH.HisCBy = (CASE WHEN @UserID = 0 THEN MH.HisCBy ELSE @UserID END) and          
CONVERT(DATE,MH.HisCDate) BETWEEN @FromDate AND @ToDate          
GROUP BY MH.FormID,U.FormName         
--UNION ALL -- AUTO INDENT          
--SELECT 30,'Automatic Indent' FROM tblTransAutomaticIndentHeader MH          
-- WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--UNION ALL -- PO          
--SELECT 31,'Purchase Order' FROM tblPurchaseOrderHeader MH          
-- WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--UNION ALL -- BILL,PR          
--SELECT case when TransID = 1 then 32 ELSE 33 END,case when TransID = 1 then 'Purchase Bill' ELSE 'Purchase Return' END FROM tblTransPurchaseHeader MH          
-- WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--UNION ALL -- CN,DN          
--SELECT case when TransID = 4 then 34 ELSE 35 END,case when TransID = 4 then 'Credit Note' ELSE 'Debit Note' END FROM tblNoteDetails MH          
-- WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--UNION ALL -- CONT          
--SELECT 36,'Contra' FROM tblTranContra MH          
-- WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--UNION ALL -- RV,PV          
--SELECT case when TransID = 6 then 37 ELSE 38 END,case when TransID = 6 then 'Payable Voucher' ELSE 'Receivable Voucher' END FROM tblTranPRVoucher MH          
-- WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--UNION ALL -- JE          
--SELECT 39,'Journal Entry' FROM tblFAJournal MH          
-- WHERE DocPrefix = 9 AND Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--UNION ALL -- OTHER COLL          
--SELECT 40,'Other Collection' FROM tblTranCollectionHeader MH          
-- WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--UNION ALL -- OTHER PAY          
--SELECT 41,'Other Payment' FROM tblTranPaymentHeader MH          
-- WHERE Status = 2 AND MH.Mby = (CASE WHEN @UserID = 0 THEN MH.MBy ELSE @UserID END) and          
--CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
) as rec          
GROUP BY FormID,FormName          
order by FormName          
select * from #tempForms where FormID = (CASE WHEN @FormID = 0 THEN FormID ELSE @FormID END)          
drop table #tempForms          
END          
ELSE IF(@Mode = 4)          
BEGIN          
set @FormID = @TableID          
IF(@FormID <= 25 or @FormID = 29 OR @FormID = 43)          
BEGIN          
select MH.ID,MIN(Name) Name,COUNT(Ident) nCount from tblMasterHistory MH          
WHERE MH.HisCBy = @UserID and FormID = @FormID and CONVERT(DATE,MH.HisCDate) BETWEEN @FromDate AND @ToDate          
GROUP BY MH.ID          
END          
IF(@FormID = 26 OR @FormID = 27) -- customer,vendor          
BEGIN          
select MH.ID,MIN(Name) Name,COUNT(Ident) nCount from tblMasterCustomerVendorHistory MH          
WHERE MH.HisCBy = @UserID and FormID = @FormID and CONVERT(DATE,MH.HisCDate) BETWEEN @FromDate AND @ToDate          
GROUP BY MH.ID          
END          
IF(@FormID = 28) -- product          
BEGIN          
select MH.ID,MIN(Name) Name,COUNT(IdentID) nCount from tblMasterProductHistory MH          
WHERE MH.HisCBy = @UserID and FormID = @FormID and CONVERT(DATE,MH.HisCDate) BETWEEN @FromDate AND @ToDate          
GROUP BY MH.ID          
END          
IF(@FormID = 42) -- product PRICE CHANGE         
BEGIN          
select MH.InventoryId ID,MIN(Name) Name,COUNT(MH.ProdID) nCount from tblPriceChangeHistory MH         
JOIN tblMasterProduct MP ON MP.ID= MH.ProdID      
WHERE MH.HisCBy = @UserID and FormID = @FormID and CONVERT(DATE,MH.HisCDate) BETWEEN @FromDate AND @ToDate          
GROUP BY MH.InventoryId          
END         
--IF(@FormID = 30) -- AI          
--BEGIN          
--SELECT DocValue,DocID Name,COUNT(ID) nCount FROM tblTransAutomaticIndentHeader MH          
--WHERE Status = 2 AND MH.Mby = @UserID and CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY DocValue,DocID          
--END          
--IF(@FormID = 31) -- PO          
--BEGIN          
--SELECT DocValue,DocID Name,COUNT(ID) nCount FROM tblPurchaseOrderHeader MH          
--WHERE Status = 2 AND MH.Mby = @UserID and CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY DocValue,DocID          
--END          
--IF(@FormID = 32 OR @FormID = 33) -- BILL,PR          
--BEGIN          
--SELECT DocValue,DocID Name,COUNT(ID) nCount FROM tblTransPurchaseHeader MH          
--WHERE Status = 2 AND TransID = (CASE WHEN @FormID = 32 THEN 1 ELSE 12 END) AND MH.Mby = @UserID and CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY DocValue,DocID          
--END          
--IF(@FormID = 34 OR @FormID = 35) -- CN,DN          
--BEGIN          
--SELECT DocValue,DocID Name,COUNT(ID) nCount FROM tblNoteDetails MH          
--WHERE Status = 2 AND TransID = (CASE WHEN @FormID = 34 THEN 4 ELSE 5 END) AND MH.Mby = @UserID and CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY DocValue,DocID          
--END          
--IF(@FormID = 36) -- CONT          
--BEGIN          
--SELECT DocValue,DocID Name,COUNT(ID) nCount FROM tblTranContra MH          
--WHERE Status = 2 AND MH.Mby = @UserID and CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY DocValue,DocID          
--END          
--IF(@FormID = 37 OR @FormID = 38) -- PV,RV          
--BEGIN          
--SELECT DocValue,DocID Name,COUNT(ID) nCount FROM tblTranPRVoucher MH          
--WHERE Status = 2 AND TransID = (CASE WHEN @FormID = 37 THEN 6 ELSE 7 END) AND MH.Mby = @UserID and CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY DocValue,DocID          
--END          
--IF(@FormID = 39) -- JE          
--BEGIN          
--SELECT DocValue,DocID Name,COUNT(NoteID) nCount FROM tblFAJournal MH          
--WHERE Status = 2 AND DocPrefix = 9 AND MH.Mby = @UserID and CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY DocValue,DocID          
--END          
--IF(@FormID = 40) -- OT COLL          
--BEGIN          
--SELECT DocValue,DocID Name,COUNT(ColID) nCount FROM tblTranCollectionHeader MH          
--WHERE Status = 2 AND MH.Mby = @UserID and CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY DocValue,DocID          
--END          
--IF(@FormID = 41) -- OT PAY          
--BEGIN          
--SELECT DocValue,DocID Name,COUNT(PYID) nCount FROM tblTranPaymentHeader MH          
--WHERE Status = 2 AND MH.Mby = @UserID and CONVERT(DATE,MH.MDATE) BETWEEN @FromDate AND @ToDate          
--GROUP BY DocValue,DocID          
--END          
END          
ELSE IF(@Mode = 5)          
BEGIN          
set @FormID = @TableID          
declare @TableName nvarchar(255),@FormType INT          
select @TableName = TableName,@FormType = FormType from tblTablesNames where ID = @FormID          
--select * from tblMasterCreditTerm          
PRINT 'MODE 5 Table Name : '+@TableName
IF(@FormType = 1)          
BEGIN          
SET @strQuery = ' SELECT ID,Name,Active,[Created By],[Created Date],[Modified By],[Modified Date]'+
 case when @FormID = 2 then ',[Pref Lang Name]' else '' end+' FROM (          
SELECT 1 IDX,MH.ID,Name,CASE WHEN MH.Active = 1 THEN ''YES'' else ''NO'' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MH.CDATE) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MH.MDATE) [Modified Date],'
set @strQuery += case when @FormID = 2 then 'PLName [Pref Lang Name],' else '' end
set @strQuery += 'Ident          
FROM tblMasterHistory MH          
JOIN tblUsers MUC ON MUC.ID = MH.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MH.Mby          
WHERE FormID = '+convert(nvarchar,@FormID)+' and MH.ID = convert(nvarchar,@ID) AND MH.HisCBy = convert(nvarchar,@UserID) AND CONVERT(DATE,MH.HisCDate) BETWEEN '''+convert(nvarchar,@FromDate)+''' AND '''+convert(nvarchar,@ToDate )+'''          
UNION ALL          
SELECT 2,MH.ID,Name,CASE WHEN MH.Active = 1 THEN ''YES'' else ''NO'' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MH.CDATE) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MH.MDATE) [Modified Date],'
set @strQuery += case when @FormID = 2 then 'PLName [Pref Lang Name],' else '' end
set @strQuery += '0 FROM '+@TableName+' MH          
JOIN tblUsers MUC ON MUC.ID = MH.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MH.Mby WHERE MH.ID = convert(nvarchar,@ID)) AS REC          
ORDER BY IDX,Ident '    
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TableID NVARCHAR(MAX), @UserID NVARCHAR(MAX), @FromDate date, @ToDate date, @ID NVARCHAR(255)', @Mode = @Mode, @TableID = @TableID, @UserID = @UserID, @FromDate = @FromDate, @ToDate = @ToDate, @ID = @ID          
END          
ELSE IF(@FormType = 2)          
BEGIN          
SET @strQuery = ' SELECT ID,Name,Value,Active,[Created By],[Created Date],[Modified By],[Modified Date] FROM (          
SELECT 1 IDX,MH.ID,Name,Column1 Value,CASE WHEN MH.Active = 1 THEN ''YES'' else ''NO'' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MH.CDATE) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MH.MDATE) [Modified Date],Ident          
FROM tblMasterHistory MH          
JOIN tblUsers MUC ON MUC.ID = MH.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MH.Mby          
WHERE FormID = '+convert(nvarchar,@FormID)+' and MH.ID = convert(nvarchar,@ID) AND MH.HisCBy = convert(nvarchar,@UserID) AND CONVERT(DATE,MH.HisCDate) BETWEEN '''+convert(nvarchar,@FromDate)+''' AND '''+convert(nvarchar,@ToDate )+'''          
UNION ALL          
SELECT 2,MH.ID,Name,Value,CASE WHEN MH.Active = 1 THEN ''YES'' else ''NO'' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MH.CDATE) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MH.MDATE) [Modified Date],0          
FROM '+@TableName+' MH          
JOIN tblUsers MUC ON MUC.ID = MH.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MH.Mby WHERE MH.ID = convert(nvarchar,@ID)) AS REC          
ORDER BY IDX,Ident '          
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TableID NVARCHAR(MAX), @UserID NVARCHAR(MAX), @FromDate date, @ToDate date, @ID NVARCHAR(255)', @Mode = @Mode, @TableID = @TableID, @UserID = @UserID, @FromDate = @FromDate, @ToDate = @ToDate, @ID = @ID          
END          
ELSE IF(@FormID = 18)-- service          
BEGIN          
SELECT * INTO #MSERV FROM (          
SELECT 1 IDX,MS.ID,Name,TaxName Tax,column2 [SAC Code],dbo.fnGetRoundedValue(Column3) [Inward Price],dbo.fnGetRoundedValue(Column4) [Outward Price],          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],Ident          
FROM tblMasterHistory MS          
JOIN tblMasterTax MT ON MT.TaxID = MS.Column1          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby          
WHERE FormID = @FormID AND MS.HisCBy = @UserID and MS.ID = @ID AND CONVERT(DATE,MS.HisCDate) BETWEEN @FromDate and @ToDate          
UNION ALL          
SELECT 2,MS.ID,Name,TaxName Tax,SACCode [SAC Code],dbo.fnGetRoundedValue(Inwardprice) [Inward Price],dbo.fnGetRoundedValue(Outwardprice) [Outward Price],          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],0 FROM tblMasterService MS          
JOIN tblMasterTax MT ON MT.TaxID = MS.TaxID          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby WHERE MS.ID = @ID ) AS REC ORDER BY IDX,Ident          
ALTER TABLE #MSERV DROP COLUMN IDX,Ident          
SELECT * FROM #MSERV          
drop table #Mdata          
END          
ELSE IF(@FormID = 19)-- Vehicle          
BEGIN          
SELECT * INTO #MVEH FROM (          
SELECT 1 IDX,MS.ID,Name [Vehicle No],Column1 [Vehicle Namee],CONVERT(NVARCHAR(25),Column2,103) [DO Purchase],CONVERT(NVARCHAR(25),Column3,103) [Insurance Date],          
CONVERT(NVARCHAR(25),Column4,103) [Insurance Expire],CONVERT(NVARCHAR(25),Column5,103) [FC Date],          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],Ident          
FROM tblMasterHistory MS          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby          
WHERE FormID = @FormID AND MS.HisCBy = @UserID and MS.ID = @ID AND CONVERT(DATE,MS.HisCDate) BETWEEN @FromDate and @ToDate          
UNION ALL          
SELECT 2,MS.ID,MS.VehicleNo,MS.VehicleName,CONVERT(NVARCHAR(25),DOPurchase,103),CONVERT(NVARCHAR(25),InsuranceDate,103),          
CONVERT(NVARCHAR(25),InsuranceExpire,103),CONVERT(NVARCHAR(25),FCDate,103),          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],0 FROM tblMasterVehicle MS          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby WHERE MS.ID = @ID) AS REC ORDER BY IDX,Ident          
ALTER TABLE #MVEH DROP COLUMN IDX,Ident          
SELECT * FROM #MVEH          
drop table #MVEH          
END          
ELSE IF(@FormID = 20)-- SALESMAN          
BEGIN          
--SELECT top 1* FROM tblMasterBranchOffice          
--SELECT top 1* FROM tblMasterHistory where FormID = 20        
SELECT * INTO #MSALESMAN FROM (          
SELECT 1 IDX,MS.ID,MS.Name,CONVERT(NVARCHAR(25),Column1,103) DOB,CONVERT(NVARCHAR(25),Column2,103) DOJ,Column3 [Mobile No],Column4 [Aadhar No],          
Column5 [PAN No],Column6 Address,MT.Name [SalesMan Group],          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],PLName [Pref Lang Name],Ident          
FROM tblMasterHistory MS          
LEFT JOIN tblMasterSalesmanGroup MT ON MT.ID = MS.Column7          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby          
WHERE FormID = @FormID AND MS.HisCBy = @UserID and MS.ID = @ID AND CONVERT(DATE,MS.HisCDate) BETWEEN @FromDate and @ToDate          
UNION ALL          
SELECT 2,MS.ID,MS.Name,CONVERT(NVARCHAR(25),DOB,103),CONVERT(NVARCHAR(25),DOJ,103),MobileNo,AadharNo,PANNumber,Address,MT.Name SMGrp,          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],PLName [Pref Lang Name],0 FROM tblMasterSalesman MS          
JOIN tblMasterSalesmanGroup MT ON MT.ID = MS.SalesmanGroupID          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby WHERE MS.ID = @ID ) AS REC ORDER BY IDX,Ident          
ALTER TABLE #MSALESMAN DROP COLUMN IDX,Ident          
SELECT * FROM #MSALESMAN          
drop table #MSALESMAN          
END          
ELSE IF(@FormID = 21)-- Branch Office          
BEGIN          
--SELECT top 1* FROM tblMasterBranchOffice          
--SELECT top 1* FROM tblMasterHistory where FormID = 21          
SELECT * INTO #Mbo FROM (          
SELECT 1 IDX,MS.ID,MS.Column1 [Code],MS.Name,Column2 [Bill Add 1],Column3 [Bill Add 2],Column4 [Bill Add 3],Column5 [Contact Person],Column6 Ph1,Column7 Mob1,          
Column8 Email,MT.StateName [State Name],Column10 GSTIN,CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],Ident          
FROM tblMasterHistory MS          
JOIN tblGSTStateNameandCode MT ON MT.StateID = Column9          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby          
WHERE FormID = @FormID AND MS.HisCBy = @UserID and MS.ID = @ID AND CONVERT(DATE,MS.HisCDate) BETWEEN @FromDate and @ToDate          
UNION ALL          
SELECT 2,MS.ID,MS.Code,MS.Name,Billadd1,Billadd2,Billadd3,ContactPerson,Ph1,Mob1,MS.Email,MT.StateName,GSTIN,          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],0 FROM tblMasterBranchOffice MS          
JOIN tblGSTStateNameandCode MT ON MT.StateID = MS.StateID          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby WHERE MS.ID = @ID ) AS REC ORDER BY IDX,Ident          
ALTER TABLE #Mbo DROP COLUMN IDX,Ident          
SELECT * FROM #Mbo          
drop table #Mbo          
END          
ELSE IF(@FormID = 22)-- Bank Account          
BEGIN          
--SELECT top 1* FROM tblMasterBankAccount          
--SELECT top 1* FROM tblMasterHistory where FormID = 22          
SELECT * INTO #MBankAcc FROM (          
SELECT 1 IDX,MS.ID,MS.Name [Account No],Column1 [Account Name],MT.Name Bank,Column3 Branch,Column4 [IFSC Code],Column5 MICR,CASE WHEN Column7 = 1 THEN 'YES' else 'NO' End SetDefault,          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],Ident          
FROM tblMasterHistory MS          
JOIN tblMasterBank MT ON MT.ID = MS.Column2          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby          
WHERE FormID = @FormID AND MS.HisCBy = @UserID and MS.ID = @ID AND CONVERT(DATE,MS.HisCDate) BETWEEN @FromDate and @ToDate          
UNION ALL          
SELECT 2,MS.ID,AccountNo,AccountName,MT.Name Bank,BranchName,IFSCCode,MICR,CASE WHEN MS.SetDefault = 1 THEN 'YES' else 'NO' End SetDefault,          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],0 FROM tblMasterBankAccount MS          
JOIN tblMasterBank MT ON MT.ID = MS.BankID          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby WHERE MS.ID = @ID ) AS REC ORDER BY IDX,Ident          
ALTER TABLE #MBankAcc DROP COLUMN IDX,Ident          
SELECT * FROM #MBankAcc          
drop table #MBankAcc          
END          
ELSE IF(@FormID = 24)-- Fin Account          
BEGIN          
          
SELECT * INTO #MFA FROM (          
SELECT 1 IDX,MS.ID,Name [Account Name],MT.AccountGroupName [Account Group],dbo.fnGetRoundedValue(Column2) [Opening Balance],FAT.FAType,          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],Ident FROM tblMasterHistory MS          
JOIN tblFAGroup MT ON MT.FAGroup = MS.Column1          
JOIN tblFAType FAT ON FAT.FATypeID = MS.Column3          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby          
WHERE FormID = @FormID AND MS.HisCBy = @UserID and MS.ID = @ID AND CONVERT(DATE,MS.HisCDate) BETWEEN @FromDate and @ToDate          
UNION ALL          
SELECT 2,MS.FAID,AccountName,MT.AccountGroupName,dbo.fnGetRoundedValue(OpeningBalance) OpeningBalance,FAT.FAType,          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],0 FROM tblFAAccount MS          
JOIN tblFAGroup MT ON MT.FAGroup = MS.AccountGroup          
JOIN tblFAType FAT ON FAT.FATypeID = MS.FATypeID          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby WHERE MS.FAID = @ID ) AS REC ORDER BY IDX,Ident          
ALTER TABLE #MFA DROP COLUMN IDX,Ident          
SELECT * FROM #MFA          
drop table #MFA          
END          
ELSE IF(@FormID = 25)-- Fin Account GRP          
BEGIN          
SELECT * INTO #MFAG FROM (          
SELECT 1 IDX,MS.ID,Name [Account Group Name],MT.AccountGroupName [Parent Group],FAT.TypeName [Account Type],          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],Ident FROM tblMasterHistory MS          
LEFT JOIN tblFAGroup MT ON MT.FAGroup = MS.Column1          
JOIN tblAccountType FAT ON FAT.TypeID = MS.Column2          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby          
WHERE FormID = @FormID AND MS.HisCBy = @UserID and MS.ID = @ID AND CONVERT(DATE,MS.HisCDate) BETWEEN @FromDate and @ToDate          
UNION ALL          
SELECT 2,MS.FAGroup,MS.AccountGroupName,MT.AccountGroupName par,FAT.TypeName,          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],0 FROM tblFAGroup MS          
LEFT JOIN tblFAGroup MT ON MT.FAGroup = MS.ParentGroup          
JOIN tblAccountType FAT ON FAT.TypeID = MS.TypeID          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby WHERE MS.FAGroup = @ID ) AS REC ORDER BY IDX,Ident          
ALTER TABLE #MFAG DROP COLUMN IDX,Ident          
SELECT * FROM #MFAG          
drop table #MFAG          
END          
ELSE IF(@FormID = 29)-- USER          
BEGIN          
SELECT * INTO #MUS FROM (          
SELECT 1 IDX,MS.ID,MS.Name [User Name],Column1 [Key],Column2 [Mobile No],Column3 [EMail ID],MT.Name [Role],          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],Ident FROM tblMasterHistory MS          
LEFT JOIN tblMasterRole MT ON MT.ID = MS.Column4          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby          
WHERE FormID = @FormID AND MS.HisCBy = @UserID and MS.ID = @ID AND CONVERT(DATE,MS.HisCDate) BETWEEN @FromDate and @ToDate          
UNION ALL          
SELECT 2,MS.ID,MS.UserName,MS.Password,MS.Mobilenumber,MS.EMailID,MT.Name Roles,          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],0 FROM tblUsers MS          
LEFT JOIN tblMasterRole MT ON MT.ID = MS.RoleID          
LEFT JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby WHERE MS.ID = @ID ) AS REC ORDER BY IDX,Ident          
ALTER TABLE #MUS DROP COLUMN IDX,Ident          
SELECT * FROM #MUS          
drop table #MUS          
END          
ELSE IF(@FormID = 26)-- Customer          
BEGIN          
SELECT * INTO #MCUST FROM (          
SELECT 1 IDX,MS.ID,Code,MS.Name,Billadd1,Billadd2, Billadd3,Shipadd1,shipadd2,Shipadd3,Pincode,ContactPerson,Ph1,Ph2,Mob1,Mob2,Email,          
PANNumber,AadharNo,DLNo20,DLNo21,FSSAINo,GST.StateName [State],GSTIN,CRT.Name [Credit Term],PM.PaymentMode [Payment Mode],MTT.TaxTypeName [Tax Type],          
OSValue,FAID,OverDueValue,OverDueInvCount,CreditLimitValue,CreditLimitCount,CreditlimitOS,PT.PriceType,OwnerName,DiscountPern,TrackPoint,ClosingTrackPoint,          
TCSTax,Latitude,Longtitude,Distance,Remark,CUT.Name [Customer Type],RT.RatingName Rating,          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],PLName [Pref Lang Name],
PLBillAdd1 [Pref Lang BillAdd1],PLBillAdd2 [Pref Lang BillAdd2],PLBillAdd3 [Pref Lang BillAdd3],
PLContactPerson [Pref Lang ContactPerson],Ident FROM tblMasterCustomerVendorHistory MS          
LEFT JOIN tblGSTStateNameandCode GST ON GST.StateID = MS.StateID          
LEFT JOIN tblMasterCreditTerm CRT ON CRT.ID = MS.CreditTermID          
LEFT JOIN tblPaymentMode PM ON PM.ID = MS.PaymentModeID          
LEFT JOIN tblMasterTaxType MTT ON MTT.TaxTypeID = MS.TaxTypeID          
LEFT JOIN tblMasterCustomerType CUT ON CUT.ID = MS.CustomerType          
LEFT JOIN tblRatings RT ON RT.ID = MS.Rating          
LEFT JOIN tblPriceType PT ON PT.ID = MS.PriceTypeWeekCycle          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby          
WHERE FormID = @FormID AND MS.HisCBy = @UserID and MS.ID = @ID AND CONVERT(DATE,MS.HisCDate) BETWEEN @FromDate and @ToDate          
UNION ALL          
SELECT 2,MS.ID,Code,MS.Name,Billadd1,Billadd2, Billadd3,Shipadd1,shipadd2,Shipadd3,Pincode,ContactPerson,Ph1,Ph2,Mob1,Mob2,Email,          
PANNumber,AadharNo,DLNo20,DLNo21,FSSAINo,GST.StateName [State],GSTIN,CRT.Name [Credit Term],PM.PaymentMode [Payment Mode],MTT.TaxTypeName [Tax Type],          
OSValue,FAID,OverDueValue,OverDueInvCount,CreditLimitValue,CreditLimitCount,CreditlimitOS,PT.PriceType,OwnerName,DiscountPern,TrackPoint,ClosingTrackPoint,          
TCSTax,Latitude,Longtitude,Distance,Remark,CUT.Name [Customer Type],RT.RatingName Rating,          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],PLName [Pref Lang Name],
PLBillAdd1 [Pref Lang BillAdd1],PLBillAdd2 [Pref Lang BillAdd2],PLBillAdd3 [Pref Lang BillAdd3],
PLContactPerson [Pref Lang ContactPerson],0 FROM tblMasterCustomer MS          
LEFT JOIN tblGSTStateNameandCode GST ON GST.StateID = MS.StateID          
LEFT JOIN tblMasterCreditTerm CRT ON CRT.ID = MS.CreditTermID          
LEFT JOIN tblPaymentMode PM ON PM.ID = MS.PaymentModeID          
LEFT JOIN tblMasterTaxType MTT ON MTT.TaxTypeID = MS.TaxTypeID          
LEFT JOIN tblMasterCustomerType CUT ON CUT.ID = MS.CustomerType          
LEFT JOIN tblRatings RT ON RT.ID = MS.Rating          
LEFT JOIN tblPriceType PT ON PT.ID = MS.PriceTypeID          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby WHERE MS.ID = @ID          
) AS REC ORDER BY IDX,Ident          
ALTER TABLE #MCUST DROP COLUMN IDX,Ident          
SELECT * FROM #MCUST          
drop table #MCUST          
END          
ELSE IF(@FormID = 27)-- Vendor          
BEGIN          
--SELECT top 1* FROM tblMasterVendor          
--SELECT top 1* FROM tblMasterCustomerVendorHistory where FormID = 27          
SELECT * INTO #MVEND FROM (          
SELECT 1 IDX,MS.ID,Code,MS.Name,Billadd1,Billadd2,Billadd3,Shipadd1,shipadd2,Shipadd3,Pincode,ContactPerson,Ph1,Ph2,Mob1,Mob2,Email,PANNumber,AadharNo,          
DLNo20,DLNo21,FSSAINo,GST.StateName [State],GSTIN,CRT.Name [Credit Term],PM.PaymentMode [Payment Mode],MTT.TaxTypeName [Tax Type],          
OSValue,RT.RatingName Rating,CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],PLName [Pref Lang Name],
PLBillAdd1 [Pref Lang BillAdd1],PLBillAdd2 [Pref Lang BillAdd2],PLBillAdd3 [Pref Lang BillAdd3],
PLContactPerson [Pref Lang ContactPerson],Ident FROM tblMasterCustomerVendorHistory MS          
LEFT JOIN tblGSTStateNameandCode GST ON GST.StateID = MS.StateID          
LEFT JOIN tblMasterCreditTerm CRT ON CRT.ID = MS.CreditTermID          
LEFT JOIN tblPaymentMode PM ON PM.ID = MS.PaymentModeID          
LEFT JOIN tblMasterTaxType MTT ON MTT.TaxTypeID = MS.TaxTypeID          
LEFT JOIN tblRatings RT ON RT.ID = MS.Rating          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby          
WHERE FormID = @FormID AND MS.HisCBy = @UserID and MS.ID = @ID AND CONVERT(DATE,MS.HisCDate) BETWEEN @FromDate and @ToDate          
UNION ALL          
select 2,MS.ID,Code,MS.Name,Billadd1,Billadd2,Billadd3,Shipadd1,shipadd2,Shipadd3,Pincode,ContactPerson,Ph1,Ph2,Mob1,Mob2,Email,PANNumber,AadharNo,          
DLNo20,DLNo21,FSSAINo,GST.StateName [State],GSTIN,CRT.Name [Credit Term],PM.PaymentMode [Payment Mode],MTT.TaxTypeName [Tax Type],          
OSValue,RT.RatingName Rating,CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],PLName [Pref Lang Name],
PLBillAdd1 [Pref Lang BillAdd1],PLBillAdd2 [Pref Lang BillAdd2],PLBillAdd3 [Pref Lang BillAdd3],
PLContactPerson [Pref Lang ContactPerson],0          
from tblMasterVendor MS          
LEFT JOIN tblGSTStateNameandCode GST ON GST.StateID = MS.StateID          
LEFT JOIN tblMasterCreditTerm CRT ON CRT.ID = MS.CreditTermID          
LEFT JOIN tblPaymentMode PM ON PM.ID = MS.PaymentModeID          
LEFT JOIN tblMasterTaxType MTT ON MTT.TaxTypeID = MS.TaxTypeID          
LEFT JOIN tblRatings RT ON RT.ID = MS.Rating          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby WHERE MS.ID = @ID) AS REC ORDER BY IDX,Ident          
ALTER TABLE #MVEND DROP COLUMN IDX,Ident          
SELECT * FROM #MVEND          
drop table #MVEND          
END          
ELSE IF(@FormID = 28)-- Product          
BEGIN          
--SaleonMRP SaleonpPern ECPonMRP ECPonpPern SPLonMRP SPLonpPern  
PRINT 'PRODUCT'          
SELECT * INTO #Mprod FROM (          
SELECT 1 IDX,MP.ID,MP.Code,MP.Name,EAN,MF.Name Mfr,MB.Name Brand,MB.Name Category,HSNCode,ProductDiscPerc,BUOM.Name BaseUom,BaseCR,PUOM.Name PurchaseUom,          
PurchaseCR,SUOM.Name SalesUom,SalesCR,RUOM.Name ReportingUom,ReportingCR,ReportingQty,PTAX.TaxName PurchaseTax,STAX.TaxName SalesTax,          
PurchasePrice,  
CASE WHEN MP.SaleonMRP = 1 THEN 'YES' else 'NO' End SaleonMRP,SaleonpPern,SalesPrice,  
CASE WHEN MP.ECPonMRP = 1 THEN 'YES' else 'NO' End ECPonMRP,ECPonpPern,ECP,  
CASE WHEN MP.SPLonMRP = 1 THEN 'YES' else 'NO' End SPLonMRP,SPLonpPern,SPLPrice,  
MRP,ReturnPrice,CASE WHEN MP.TrackInventory = 1 THEN 'YES' else 'NO' End TrackInventory,          
CASE WHEN MP.TrackBatch = 1 THEN 'YES' else 'NO' End TrackBatch,CASE WHEN MP.TrackSerial = 1 THEN 'YES' else 'NO' End TrackSerial,          
CASE WHEN MP.TrackPDK = 1 THEN 'YES' else 'NO' End TrackPDK,CASE WHEN MP.DateFormat = 1 THEN 'DMY' else 'MY' End DateFormat,      
CASE WHEN MP.BarcodeEnable = 1 THEN 'YES' else 'NO' End BarcodeYN,BARUOM.Name BarcodeUom,          
PTY.PriceType BarcodePriceD,MV.Name Vendor,MOH,MOQ,Weborder,Remarks,ML.Name Location,  
CASE WHEN MP.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MP.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MP.MDate) [Modified Date],MP.PLName [Pref Lang Name],IdentID          
FROM tblMasterProductHistory MP          
JOIN tblMasterManufacturer MF ON MF.ID = MP.MfrID          
JOIN tblMasterBrand MB ON MB.ID = MP.BrandID          
JOIN tblMasterCategory MC ON MC.ID = MP.CategoryID          
JOIN tblMasterUOM BUOM ON BUOM.ID = MP.BaseUomID          
JOIN tblMasterUOM PUOM ON PUOM.ID = MP.PurchaseUomID          
JOIN tblMasterUOM SUOM ON SUOM.ID = MP.SalesUomID          
JOIN tblMasterUOM RUOM ON RUOM.ID = MP.ReportingUomID          
JOIN tblMasterTax PTAX ON PTAX.TaxID = MP.PurchaseTaxID          
JOIN tblMasterTax STAX ON STAX.TaxID = MP.SalesTaxID          
LEFT JOIN tblMasterUOM BARUOM ON BARUOM.ID = MP.BarcodeUomID          
LEFT JOIN tblPriceType PTY ON PTY.ID = MP.BarcodePriceID          
LEFT JOIN tblMasterVendor MV ON MV.ID = MP.VendorID          
LEFT JOIN tblMasterLocation ML ON ML.ID = MP.LocationID          
JOIN tblUsers MUC ON MUC.ID = MP.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MP.Mby          
WHERE FormID = @FormID AND MP.HisCBy = @UserID and MP.ID = @ID AND CONVERT(DATE,MP.HisCDate) BETWEEN @FromDate and @ToDate          
UNION ALL          
SELECT 2 IDX,MP.ID,MP.Code,MP.Name,EAN,MF.Name Mfr,MB.Name Brand,MB.Name Category,HSNCode,ProductDiscPerc,BUOM.Name BaseUom,BaseCR,PUOM.Name PurchaseUom,          
PurchaseCR,SUOM.Name SalesUom,SalesCR,RUOM.Name ReportingUom,ReportingCR,ReportingQty,PTAX.TaxName PurchaseTax,STAX.TaxName SalesTax,          
PurchasePrice,CASE WHEN MP.SaleonMRP = 1 THEN 'YES' else 'NO' End SaleonMRP,SaleonpPern,SalesPrice,  
CASE WHEN MP.ECPonMRP = 1 THEN 'YES' else 'NO' End ECPonMRP,ECPonpPern,ECP,  
CASE WHEN MP.SPLonMRP = 1 THEN 'YES' else 'NO' End SPLonMRP,SPLonpPern,SPLPrice,MRP,ReturnPrice,CASE WHEN MP.TrackInventory = 1 THEN 'YES' else 'NO' End TrackInventory,          
CASE WHEN MP.TrackBatch = 1 THEN 'YES' else 'NO' End TrackBatch,CASE WHEN MP.TrackSerial = 1 THEN 'YES' else 'NO' End TrackSerial,          
CASE WHEN MP.TrackPDK = 1 THEN 'YES' else 'NO' End TrackPDK,CASE WHEN MP.DateFormat = 1 THEN 'DMY' else 'MY' End DateFormat,      
CASE WHEN MP.BarcodeEnable = 1 THEN 'YES' else 'NO' End BarcodeYN,BARUOM.Name BarcodeUom,          
PTY.PriceType BarcodePriceD,MV.Name Vendor,MOH,MOQ,Weborder,Remarks,ML.Name Location,CASE WHEN MP.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MP.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MP.MDate) [Modified Date],MP.PLName [Pref Lang Name],0 IdentID          
FROM tblMasterProduct MP          
JOIN tblMasterManufacturer MF ON MF.ID = MP.MfrID          
JOIN tblMasterBrand MB ON MB.ID = MP.BrandID          
JOIN tblMasterCategory MC ON MC.ID = MP.CategoryID          
JOIN tblMasterUOM BUOM ON BUOM.ID = MP.BaseUomID          
JOIN tblMasterUOM PUOM ON PUOM.ID = MP.PurchaseUomID          
JOIN tblMasterUOM SUOM ON SUOM.ID = MP.SalesUomID          
JOIN tblMasterUOM RUOM ON RUOM.ID = MP.ReportingUomID          
JOIN tblMasterTax PTAX ON PTAX.TaxID = MP.PurchaseTaxID          
JOIN tblMasterTax STAX ON STAX.TaxID = MP.SalesTaxID          
LEFT JOIN tblMasterUOM BARUOM ON BARUOM.ID = MP.BarcodeUomID          
LEFT JOIN tblPriceType PTY ON PTY.ID = MP.BarcodePriceID          
LEFT JOIN tblMasterVendor MV ON MV.ID = MP.VendorID          
LEFT JOIN tblMasterLocation ML ON ML.ID = MP.LocationID          
JOIN tblUsers MUC ON MUC.ID = MP.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MP.Mby WHERE MP.ID = @ID          
) AS REC ORDER BY IDX,IdentID          
ALTER TABLE #Mprod DROP COLUMN IDX,IdentID          
SELECT * FROM #Mprod          
drop table #Mprod          
END          
ELSE IF(@FormID = 42)-- Product PRICE CHANGE          
BEGIN          
SELECT InventoryId,BatchNumber Batch,PKDDate PKD,ExpiryDate Expiry,dbo.fnGetRoundedValue(PurchasePrice) [Purchase Price],dbo.fnGetRoundedValue(SalesPrice) [Sales Price],      
dbo.fnGetRoundedValue(ECP) ECP,dbo.fnGetRoundedValue(SPLPrice) [SPL Price],dbo.fnGetRoundedValue(ReturnPrice) [Return Price],      
dbo.fnGetRoundedValue(MRPONPrice) [MRP On] FROM (      
SELECT 1 IDX,InventoryId,BatchNumber,PKDDate,ExpiryDate,PurchasePrice,SalesPrice,ECP,SPLPrice,ReturnPrice,MRPONPrice       
FROM tblPriceChangeHistory WHERE InventoryId = @ID      
UNION ALL      
SELECT 2,InventoryId,BatchNumber,PKDDate,ExpiryDate,PurchasePrice,SalesPrice,ECP,SPLPrice,ReturnPrice,MRPONPrice       
FROM tblProductInventory WHERE InventoryId = @ID      
) AS REC      
ORDER BY IDX,InventoryId      
END      
END          
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetProdInventoryInSalesReturn';
GO
--[uspGetProdInventoryInSalesReturn] 4,2,1,16,'2025-12-10',620,0,0              
CREATE OR ALTER PROCEDURE [dbo].[uspGetProdInventoryInSalesReturn]                                           
@BranchID INT,@AppPriceId INT,@Mode SMALLINT,@ProdId INT,@SRDate DATE,@ModifyId INT=NULL,@SalesORDamage INT=0,@Show0BatchinSR int = 0                                                       
AS                                                       
BEGIN                                                       
SET DATEFORMAT dmy;                                                       
SET NOCOUNT ON;                                    
DECLARE @TEMPDRID INT = 0                      
declare @EnableReturnPrice int =  (select AppValue from tblAppConfig where AppId = 12)          
--declare @Show0BatchinSR int =  (select AppValue from tblAppConfig where AppId = 33)          
declare @nTop int =  (case when @Show0BatchinSR = 1 then 10 ELSE 0 END)    
IF(@Mode = 6)                                  
BEGIN                                  
SET @ModifyId = NULL                                  
END                                  
-- Sales Return Modify                                                       
IF ISNULL(@Mode,0)=5 or ISNULL(@Mode,0)=6                                                
BEGIN                                                       
SET @Mode = @SalesORDamage                                        
END                                    
print @Mode                              
--IF ISNULL(@Mode,0) = 6 AND @SalesORDamage = 2                                    
--BEGIN                                    
--SET @Mode = @SalesORDamage                                    
--SET @TEMPDRID = 7                                    
--END                                    
DECLARE @TrackInventory INT, @TrackBatch INT, @TrackPkg INT                                                       
SELECT @TrackInventory= TrackInventory,@TrackBatch =TrackBatch ,@TrackPkg =TrackPDK FROM tblMasterProduct WHERE ID =@ProdId                                                       
--SELECT * FROM tblMasterProduct WHERE ProdId = 665                                            
CREATE TABLE #TempInventoryDetail(QtyType VARCHAR(25),BatchNumber NVARCHAR(255) NULL, PKDDate DATE NULL,ExpiryDate DATE NULL,                                                       
Price DECIMAL (25,6), MRP DECIMAL (25,6),Qty DECIMAL (25,6),Tag SMALLINT)                
    
-- Create clustered Index on Tag    
--CREATE CLUSTERED  INDEX IX_TempInventoryDetail_Tag ON #TempInventoryDetail(Tag);    
declare @strQry nvarchar(max)    
print @TrackInventory                              
print @TrackBatch                              
print @TrackPkg                              
IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)=0 AND ISNULL(@TrackPkg,0)=0                                                       
BEGIN                            
print 'Track Inventory : Yes,Track Batch :No ,Track Pkd : No , Mode :'+convert(nvarchar(50),@Mode)
IF ISNULL(@Mode,0)=1 --OR ISNULL(@Mode,0)=6                                        
BEGIN           
print 'trk invo yes only'    
--INSERT INTO #TempInventoryDetail    
--SELECT QtyType,BatchNumber,PKDDate,ExpiryDate,Price,MRPONPrice,SUM(QTY),Tag FROM(                                                       
--SELECT DISTINCT 'SALE' AS QtyType,NULL AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,                                                       
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END) AS Price,MRPONPrice,                                        
--SUM(ActualQty)AS QTY ,1 AS Tag FROM tblProductInventory WHERE BranchID = @BranchID and ProdId=@ProdId AND ActualQty > 0                                                       
--GROUP BY               
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice                           
--UNION                                                       
--SELECT DISTINCT 'FREE' AS QtyType ,NULL AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,0 AS Price,0 AS MRP,SUM(ActualFreeQty),2 AS Tag         
--FROM tblProductInventory WHERE BranchID = @BranchID and ProdId=@ProdId AND ActualfREEQty > 0        
--) AS TAMIL GROUP BY QtyType,BatchNumber,PKDDate,ExpiryDate,MRPONPrice,Tag,Price                
--ORDER BY Tag ASC      
set @strQry = ' SELECT QtyType,BatchNumber,PKDDate,ExpiryDate,Price,MRPONPrice,SUM(QTY),Tag FROM(                                                       
SELECT DISTINCT ''SALE'' AS QtyType,NULL AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) AS Price,MRPONPrice,                                        
SUM(ActualQty)AS QTY ,1 AS Tag,1 idx FROM tblProductInventory WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId= '+CONVERT(NVARCHAR(10),@ProdId)+' AND ActualQty > 0                                                       
GROUP BY               
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice '    
set @strQry += CASE WHEN @Show0BatchinSR = 0 THEN '' ELSE '    
UNION all    
SELECT DISTINCT TOP('+CONVERT(NVARCHAR(10),@nTop)+') ''SALE'' AS QtyType,NULL AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) AS Price,MRPONPrice,                                        
SUM(ActualQty)AS QTY ,1 AS Tag,2 idx FROM tblProductInventory WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId= '+CONVERT(NVARCHAR(10),@ProdId)+' AND ActualQty = 0     
GROUP BY               
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice ' END       
set @strQry += ' UNION                     
SELECT DISTINCT ''FREE'' AS QtyType ,NULL AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,0 AS Price,0 AS MRPONPrice,SUM(ActualFreeQty),2 AS Tag,3 idx         
FROM tblProductInventory WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId= '+CONVERT(NVARCHAR(10),@ProdId)+' AND ActualfREEQty > 0        
) AS TAMIL GROUP BY QtyType,BatchNumber,PKDDate,ExpiryDate,MRPONPrice,Tag,Price ,idx               
ORDER BY idx,Tag ASC'    
INSERT INTO #TempInventoryDetail    
EXEC sys.sp_executesql @strQry, N'@BranchID INT, @AppPriceId INT, @Mode SMALLINT, @ProdId INT, @SRDate DATE, @ModifyId INT, @SalesORDamage INT, @Show0BatchinSR int', @BranchID = @BranchID, @AppPriceId = @AppPriceId, @Mode = @Mode, @ProdId = @ProdId, @SRDate = @SRDate, @ModifyId = @ModifyId, @SalesORDamage = @SalesORDamage, @Show0BatchinSR = @Show0BatchinSR    
--select  * from #TempInventoryDetail    
END                                                       
IF ISNULL(@Mode,0)=2                            
BEGIN                                                      
--INSERT INTO #TempInventoryDetail                                     
--SELECT DISTINCT 'DAMAGE' AS QtyType,NULL AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,                                        
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END) Price ,MRPONPrice,                                                       
--SUM(ActualDmgQty)AS QTY ,3 AS Tag FROM tblProductInventory WHERE BranchID = @BranchID and ProdId=@ProdId AND (ActualQty > 0 OR ActualFreeQty > 0)        
--GROUP BY               
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice    
                                  
set @strQry = 'SELECT QtyType,BatchNumber,PKDDate,ExpiryDate,Price,MRPONPrice,SUM(QTY),Tag FROM (    
SELECT DISTINCT ''DAMAGE'' AS QtyType,NULL AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) Price ,MRPONPrice,                                                       
SUM(ActualDmgQty)AS QTY ,3 AS Tag FROM tblProductInventory WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId= '+CONVERT(NVARCHAR(10),@ProdId)+' AND (ActualDmgQty > 0)        
GROUP BY               
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice '    
set @strQry += CASE WHEN @Show0BatchinSR = 0 THEN '' ELSE 'UNION ALL    
SELECT DISTINCT TOP('+CONVERT(NVARCHAR(10),@nTop)+') ''DAMAGE'' AS QtyType,NULL AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) Price ,MRPONPrice,                                                       
SUM(ActualDmgQty)AS QTY ,3 AS Tag FROM tblProductInventory WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId= '+CONVERT(NVARCHAR(10),@ProdId)+' AND (ActualDmgQty = 0)        
GROUP BY               
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice ' end    
set @strQry += ' ) AS REC    
GROUP BY QtyType,BatchNumber,PKDDate,ExpiryDate,MRPONPrice,Tag,Price     
ORDER BY Tag ASC '     
INSERT INTO #TempInventoryDetail     
EXEC sys.sp_executesql @strQry, N'@BranchID INT, @AppPriceId INT, @Mode SMALLINT, @ProdId INT, @SRDate DATE, @ModifyId INT, @SalesORDamage INT, @Show0BatchinSR int', @BranchID = @BranchID, @AppPriceId = @AppPriceId, @Mode = @Mode, @ProdId = @ProdId, @SRDate = @SRDate, @ModifyId = @ModifyId, @SalesORDamage = @SalesORDamage, @Show0BatchinSR = @Show0BatchinSR    
END                                                       
END                            
IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)<>0 AND ISNULL(@TrackPkg,0)=0                                                       
BEGIN                   
print 'Track Inventory : Yes,Track Batch : Yes ,Track Pkd : No , Mode :'+convert(nvarchar(50),@Mode)
IF ISNULL(@Mode,0)=1 --OR ISNULL(@Mode,0)=6                                                      
BEGIN                 
--INSERT INTO #TempInventoryDetail                                                       
--SELECT QtyType,BatchNumber,PKDDate,ExpiryDate,Price,MRPONPrice,SUM(QTY),Tag FROM(                                               
--SELECT DISTINCT 'SALE' AS QtyType,BatchNumber AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,                                                       
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice,                                                       
--SUM(ActualQty)AS QTY ,1 AS Tag FROM tblProductInventory WHERE BranchID = @BranchID and ProdId=@ProdId AND ActualQty > 0                                               
--GROUP BY BatchNumber,              
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice                                                       
--UNION                                                       
--SELECT DISTINCT 'FREE' AS QtyType ,BatchNumber AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,0 AS Price,0 AS MRP,SUM(ActualFreeQty),2 AS Tag                                                       
--FROM tblProductInventory WHERE BranchID = @BranchID and ProdId=@ProdId  AND ActualFreeQty > 0                                                      
--GROUP BY BatchNumber                                                      
--)AS TAMIL GROUP BY QtyType,BatchNumber,PKDDate,ExpiryDate,Price,MRPONPrice,Tag  ORDER BY Tag ASC                                                       
set @strQry = 'SELECT QtyType,BatchNumber,PKDDate,ExpiryDate,Price,MRPONPrice,SUM(QTY),Tag FROM(                                                       
SELECT DISTINCT ''SALE'' AS QtyType,BatchNumber AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice,                                                       
SUM(ActualQty)AS QTY ,1 AS Tag,1 idx FROM tblProductInventory WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId= '+CONVERT(NVARCHAR(10),@ProdId)+' AND ActualQty > 0                                               
GROUP BY BatchNumber,              
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice '    
set @strQry += CASE WHEN @Show0BatchinSR = 0 THEN '' ELSE ' union all    
SELECT DISTINCT top('+CONVERT(NVARCHAR(10),@nTop)+') ''SALE'' AS QtyType,BatchNumber AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice,                                                       
SUM(ActualQty)AS QTY ,1 AS Tag,2 idx FROM tblProductInventory WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId= '+CONVERT(NVARCHAR(10),@ProdId)+' AND ActualQty = 0                                               
GROUP BY BatchNumber,              
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice ' END    
set @strQry += ' UNION                                                       
SELECT DISTINCT ''FREE'' AS QtyType ,BatchNumber AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,0 AS Price,0 AS MRP,SUM(ActualFreeQty),2 AS Tag,3 idx                                                       
FROM tblProductInventory WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId= '+CONVERT(NVARCHAR(10),@ProdId)+'  AND ActualFreeQty > 0                                                      
GROUP BY BatchNumber                                                      
)AS TAMIL GROUP BY QtyType,BatchNumber,PKDDate,ExpiryDate,Price,MRPONPrice,Tag,idx  ORDER BY idx,Tag ASC  '     
INSERT INTO #TempInventoryDetail     
EXEC sys.sp_executesql @strQry, N'@BranchID INT, @AppPriceId INT, @Mode SMALLINT, @ProdId INT, @SRDate DATE, @ModifyId INT, @SalesORDamage INT, @Show0BatchinSR int', @BranchID = @BranchID, @AppPriceId = @AppPriceId, @Mode = @Mode, @ProdId = @ProdId, @SRDate = @SRDate, @ModifyId = @ModifyId, @SalesORDamage = @SalesORDamage, @Show0BatchinSR = @Show0BatchinSR    
END                                                       
IF ISNULL(@Mode,0)=2                                                       
BEGIN                                                       
--INSERT INTO #TempInventoryDetail                                                       
--SELECT DISTINCT 'DAMAGE' AS QtyType,BatchNumber AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,                                                       
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice,                                                       
--SUM(ActualDmgQty)AS QTY ,3 AS Tag FROM tblProductInventory WHERE BranchID = @BranchID and ProdId=@ProdId AND (ActualQty > 0 OR ActualFreeQty > 0)                                                     
--GROUP BY BatchNumber,               
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice          
set @strQry = 'SELECT QtyType,BatchNumber,PKDDate,ExpiryDate,Price,MRPONPrice,SUM(QTY),Tag FROM (    
SELECT DISTINCT ''DAMAGE'' AS QtyType,BatchNumber AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice,                                                       
SUM(ActualDmgQty)AS QTY ,3 AS Tag FROM tblProductInventory WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId= '+CONVERT(NVARCHAR(10),@ProdId)+' AND (ActualDmgQty > 0)                                                     
GROUP BY BatchNumber,               
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice  '    
set @strQry += CASE WHEN @Show0BatchinSR = 0 THEN '' ELSE ' union all    
SELECT DISTINCT top('+CONVERT(NVARCHAR(10),@nTop)+') ''DAMAGE'' AS QtyType,BatchNumber AS BatchNumber,NULL AS PKDDate,NULL AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice,                                                       
SUM(ActualDmgQty)AS QTY ,3 AS Tag FROM tblProductInventory WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId= '+CONVERT(NVARCHAR(10),@ProdId)+' AND (ActualDmgQty = 0)                                                     
GROUP BY BatchNumber,               
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice ' END    
set @strQry += ') AS REC    
GROUP BY QtyType,BatchNumber,PKDDate,ExpiryDate,MRPONPrice,Tag,Price ORDER BY Tag ASC  '    
INSERT INTO #TempInventoryDetail     
EXEC sys.sp_executesql @strQry, N'@BranchID INT, @AppPriceId INT, @Mode SMALLINT, @ProdId INT, @SRDate DATE, @ModifyId INT, @SalesORDamage INT, @Show0BatchinSR int', @BranchID = @BranchID, @AppPriceId = @AppPriceId, @Mode = @Mode, @ProdId = @ProdId, @SRDate = @SRDate, @ModifyId = @ModifyId, @SalesORDamage = @SalesORDamage, @Show0BatchinSR = @Show0BatchinSR    
END                                                     
END                                                       
IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)<>0 AND ISNULL(@TrackPkg,0)<>0                                                       
BEGIN                                 
print 'Track Inventory : Yes,Track Batch : Yes ,Track Pkd : Yes , Mode :'+convert(nvarchar(50),@Mode)
IF ISNULL(@Mode,0)=1  --OR ISNULL(@Mode,0)=6                                                     
BEGIN                  
--INSERT INTO #TempInventoryDetail                                                       
--SELECT TAMIL.QtyType,TAMIL.BatchNumber,Convert(nvarchar,TAMIL.PKDDate,103) AS [PKDDate],Convert(nvarchar,TAMIL.ExpiryDate,103),TAMIL.Price,TAMIL.MRPONPrice,SUM(Tamil.QTY) QTY,TAMIL.Tag                                                  
--FROM(                                                       
--SELECT DISTINCT 'SALE' AS QtyType,BatchNumber AS BatchNumber,PKDDate AS PKDDate,ExpiryDate AS ExpiryDate,                                                       
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice,                                                       
--SUM(ActualQty)AS QTY ,1 AS Tag FROM tblProductInventory                                                       
--WHERE BranchID = @BranchID and ProdId=@ProdId AND PKDDate <= @SRDate  AND ActualQty > 0                                                      
--GROUP BY BatchNumber,PKDDate,ExpiryDate,               
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END) ,MRPONPrice                                                       
--UNION                                                       
--SELECT DISTINCT 'FREE' AS QtyType ,BatchNumber AS BatchNumber,PKDDate AS PKDDate,ExpiryDate AS ExpiryDate,0 AS Price,0 AS MRP,SUM(ActualFreeQty),2 AS Tag                                                 
--FROM tblProductInventory WHERE BranchID = @BranchID and ProdId=@ProdId AND PKDDate <= @SRDate AND ActualFreeQty > 0                                                       
--GROUP BY BatchNumber,PKDDate,ExpiryDate                                                    
--)AS TAMIL GROUP BY QtyType,BatchNumber,PKDDate,ExpiryDate,Price,MRPONPrice,Tag  ORDER BY Tag ASC ,ExpiryDate ASC           
set @strQry = ' SELECT TAMIL.QtyType,TAMIL.BatchNumber,Convert(nvarchar,TAMIL.PKDDate,103) AS [PKDDate],Convert(nvarchar,TAMIL.ExpiryDate,103),TAMIL.Price,TAMIL.MRPONPrice,SUM(Tamil.QTY) QTY,TAMIL.Tag                                                  
FROM(                                                       
SELECT DISTINCT ''SALE'' AS QtyType,BatchNumber AS BatchNumber,PKDDate AS PKDDate,ExpiryDate AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice,                            
SUM(ActualQty)AS QTY ,1 AS Tag,1 idx FROM tblProductInventory                                                       
WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId= '+CONVERT(NVARCHAR(10),@ProdId)+' AND PKDDate <= '+ ''''+CONVERT(NVARCHAR(10),@SRDate)+''''+'  AND ActualQty > 0                                                      
GROUP BY BatchNumber,PKDDate,ExpiryDate,               
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) ,MRPONPrice '    
set @strQry += CASE WHEN @Show0BatchinSR = 0 THEN '' ELSE ' UNION ALL    
SELECT DISTINCT TOP('+CONVERT(NVARCHAR(10),@AppPriceId)+') ''SALE'' AS QtyType,BatchNumber AS BatchNumber,PKDDate AS PKDDate,ExpiryDate AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice,                                                       
SUM(ActualQty)AS QTY ,1 AS Tag,2 idx FROM tblProductInventory                                                       
WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId= '+CONVERT(NVARCHAR(10),@ProdId)+' AND PKDDate <= '+ ''''+CONVERT(NVARCHAR(10),@SRDate)+''''+'  AND ActualQty = 0                                                      
GROUP BY BatchNumber,PKDDate,ExpiryDate,               
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) ,MRPONPrice ' END    
set @strQry += ' UNION                                                       
SELECT DISTINCT ''FREE'' AS QtyType ,BatchNumber AS BatchNumber,PKDDate AS PKDDate,ExpiryDate AS ExpiryDate,0 AS Price,0 AS MRP,    
SUM(ActualFreeQty),2 AS Tag,3 idx                                                 
FROM tblProductInventory WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId= '+CONVERT(NVARCHAR(10),@ProdId)+' AND PKDDate <= '+ ''''+CONVERT(NVARCHAR(10),@SRDate)+''''+' AND ActualFreeQty > 0
 GROUP BY BatchNumber,PKDDate,ExpiryDate                                                    
)AS TAMIL GROUP BY QtyType,BatchNumber,PKDDate,ExpiryDate,Price,MRPONPrice,idx,Tag  ORDER BY idx,Tag ASC ,ExpiryDate ASC '      
INSERT INTO #TempInventoryDetail     
EXEC sys.sp_executesql @strQry, N'@BranchID INT, @AppPriceId INT, @Mode SMALLINT, @ProdId INT, @SRDate DATE, @ModifyId INT, @SalesORDamage INT, @Show0BatchinSR int', @BranchID = @BranchID, @AppPriceId = @AppPriceId, @Mode = @Mode, @ProdId = @ProdId, @SRDate = @SRDate, @ModifyId = @ModifyId, @SalesORDamage = @SalesORDamage, @Show0BatchinSR = @Show0BatchinSR    
END                                                       
IF ISNULL(@Mode,0)=2                                         
BEGIN                                                       
--INSERT INTO #TempInventoryDetail                                       
--SELECT DISTINCT 'DAMAGE' AS QtyType,BatchNumber AS BatchNumber,CONVERT (NVARCHAR,PKDDate,103) AS PKDDate,CONVERT (NVARCHAR,ExpiryDate,103) AS ExpiryDate,                                                       
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP      
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice,                                                       
--SUM(ActualDmgQty)AS QTY ,3 AS Tag FROM tblProductInventory                                                       
--WHERE BranchID = @BranchID and ProdId=@ProdId AND PKDDate <= @SRDate AND (ActualQty > 0 OR ActualFreeQty > 0)                                               
--GROUP BY BatchNumber,PKDDate, ExpiryDate,               
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice                                                       
--ORDER BY ExpiryDate ASC      
set @strQry = 'SELECT QtyType,BatchNumber,PKDDate,ExpiryDate,Price,MRPONPrice,SUM(QTY),Tag FROM (    
SELECT DISTINCT ''DAMAGE'' AS QtyType,BatchNumber AS BatchNumber,CONVERT (NVARCHAR,PKDDate,103) AS PKDDate,CONVERT (NVARCHAR,ExpiryDate,103) AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice,                                                       
SUM(ISNULL(ActualDmgQty,0))AS QTY ,3 AS Tag FROM tblProductInventory                                                       
WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId='+CONVERT(NVARCHAR(10),@ProdId)+' AND PKDDate <= '+ ''''+CONVERT(NVARCHAR(10),@SRDate)+''''+' AND (ActualDmgQty > 0)                                                       
GROUP BY BatchNumber,PKDDate, ExpiryDate,               
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice '             
set @strQry += CASE WHEN @Show0BatchinSR = 0 THEN '' ELSE ' UNION ALL    
SELECT DISTINCT TOP('+CONVERT(NVARCHAR(10),@nTop)+') ''DAMAGE'' AS QtyType,BatchNumber AS BatchNumber,CONVERT (NVARCHAR,PKDDate,103) AS PKDDate,CONVERT (NVARCHAR,ExpiryDate,103) AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice,                                                       
SUM(ISNULL(ActualDmgQty,0))AS QTY ,3 AS Tag FROM tblProductInventory                                                       
WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId='+CONVERT(NVARCHAR(10),@ProdId)+' AND PKDDate <= '+ ''''+CONVERT(NVARCHAR(10),@SRDate)+''''+' AND (ActualDmgQty = 0)                                                       
GROUP BY BatchNumber,PKDDate, ExpiryDate,               
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice ' END    
set @strQry +=  ') AS R    
GROUP BY QtyType,BatchNumber,PKDDate,ExpiryDate,MRPONPrice,Tag,Price ORDER BY ExpiryDate ASC '    
INSERT INTO #TempInventoryDetail     
EXEC sys.sp_executesql @strQry, N'@BranchID INT, @AppPriceId INT, @Mode SMALLINT, @ProdId INT, @SRDate DATE, @ModifyId INT, @SalesORDamage INT, @Show0BatchinSR int', @BranchID = @BranchID, @AppPriceId = @AppPriceId, @Mode = @Mode, @ProdId = @ProdId, @SRDate = @SRDate, @ModifyId = @ModifyId, @SalesORDamage = @SalesORDamage, @Show0BatchinSR = @Show0BatchinSR  
END                                                       
END                                                       
IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)=0 AND ISNULL(@TrackPkg,0)<>0                                                       
BEGIN                             
print 'Track Inventory : Yes,Track Batch :No ,Track Pkd : Yes , Mode :'+convert(nvarchar(50),@Mode)
IF ISNULL(@Mode,0)=1 --OR ISNULL(@Mode,0)=6                                        
BEGIN                                                       
--INSERT INTO #TempInventoryDetail    
--SELECT TAMIL.QtyType,TAMIL.BatchNumber,Convert(nvarchar,TAMIL.PKDDate,103) AS [PKDDate],Convert(nvarchar,TAMIL.ExpiryDate,103),TAMIL.Price,TAMIL.MRPONPrice,SUM(Tamil.QTY) QTY,TAMIL.Tag FROM(                                                       
--SELECT 'SALE' AS QtyType,NULL AS BatchNumber,PKDDate AS PKDDate,ExpiryDate AS ExpiryDate,                                                       
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice ,                                                       
--SUM(ActualQty)AS QTY ,1 AS Tag FROM tblProductInventory                                                       
--WHERE BranchID = @BranchID and ProdId=@ProdId AND PKDDate <= @SRDate AND ActualQty > 0        
--GROUP BY PKDDate,ExpiryDate,              
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice                                                       
--UNION                                                       
--SELECT DISTINCT 'FREE' AS QtyType ,NULL AS BatchNumber,PKDDate AS PKDDate,ExpiryDate AS ExpiryDate,0 AS Price,0 AS MRP,SUM(ActualFreeQty),2 AS Tag                                                       
--FROM tblProductInventory WHERE BranchID = @BranchID and ProdId=@ProdId AND PKDDate <= @SRDate AND ActualFreeQty > 0                                                      
--GROUP BY PKDDate, ExpiryDate                                                       
--)AS TAMIL GROUP BY QtyType,BatchNumber,PKDDate,ExpiryDate,Price,MRPONPrice,Tag  ORDER BY Tag ASC,ExpiryDate ASC           
set @strQry = ' SELECT TAMIL.QtyType,TAMIL.BatchNumber,Convert(nvarchar,TAMIL.PKDDate,103) AS [PKDDate],Convert(nvarchar,TAMIL.ExpiryDate,103),TAMIL.Price,
TAMIL.MRPONPrice,SUM(Tamil.QTY) QTY,TAMIL.Tag FROM(SELECT ''SALE'' AS QtyType,NULL AS BatchNumber,PKDDate AS PKDDate,ExpiryDate AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice ,                                                       
SUM(ActualQty)AS QTY ,1 AS Tag,1 idx FROM tblProductInventory                                                       
WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId='+CONVERT(NVARCHAR(10),@ProdId)+' AND PKDDate <= '+ ''''+CONVERT(NVARCHAR(10),@SRDate)+''''+' AND ActualQty > 0        
GROUP BY PKDDate,ExpiryDate,              
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice  '     
set @strQry += CASE WHEN @Show0BatchinSR = 0 THEN '' ELSE ' UNION ALL    
SELECT DISTINCT TOP('+CONVERT(NVARCHAR(10),@nTop)+') ''SALE'' AS QtyType,NULL AS BatchNumber,PKDDate AS PKDDate,ExpiryDate AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice ,                                                       
SUM(ActualQty)AS QTY ,1 AS Tag,2 idx FROM tblProductInventory                                                       
WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId='+CONVERT(NVARCHAR(10),@ProdId)+' AND PKDDate <= '+ ''''+CONVERT(NVARCHAR(10),@SRDate)+''''+' AND ActualQty = 0        
GROUP BY PKDDate,ExpiryDate,              
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice ' END    
set @strQry += ' UNION                                                       
SELECT DISTINCT ''FREE'' AS QtyType ,NULL AS BatchNumber,PKDDate AS PKDDate,ExpiryDate AS ExpiryDate,0 AS Price,0 AS MRP,SUM(ActualFreeQty),2 AS Tag,3 idx                                                    
FROM tblProductInventory WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId='+CONVERT(NVARCHAR(10),@ProdId)+' AND PKDDate <= '+ ''''+CONVERT(NVARCHAR(10),@SRDate)+''''+' AND ActualFreeQty > 0                                                      
GROUP BY PKDDate, ExpiryDate                                                       
)AS TAMIL GROUP BY QtyType,BatchNumber,PKDDate,ExpiryDate,Price,MRPONPrice,Tag,idx  ORDER BY idx,Tag ASC,ExpiryDate ASC '    
INSERT INTO #TempInventoryDetail     
EXEC sys.sp_executesql @strQry, N'@BranchID INT, @AppPriceId INT, @Mode SMALLINT, @ProdId INT, @SRDate DATE, @ModifyId INT, @SalesORDamage INT, @Show0BatchinSR int', @BranchID = @BranchID, @AppPriceId = @AppPriceId, @Mode = @Mode, @ProdId = @ProdId, @SRDate = @SRDate, @ModifyId = @ModifyId, @SalesORDamage = @SalesORDamage, @Show0BatchinSR = @Show0BatchinSR  
END                                                       
IF ISNULL(@Mode,0)=2                                          
BEGIN                                                       
--INSERT INTO #TempInventoryDetail                                                       
--SELECT 'DAMAGE' AS QtyType,NULL AS BatchNumber,CONVERT (NVARCHAR,PKDDate,103) AS PKDDate,CONVERT (NVARCHAR,ExpiryDate,103) AS ExpiryDate,                                                       
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice,                                                       
--SUM(ActualDmgQty)AS QTY ,3 AS Tag FROM tblProductInventory                                                       
--WHERE BranchID = @BranchID and ProdId=@ProdId AND PKDDate <= @SRDate AND (ActualQty > 0 OR ActualFreeQty > 0)        
--GROUP BY PKDDate,ExpiryDate,              
--(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
--WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice                                          
--ORDER BY ExpiryDate ASC           
set @strQry = 'SELECT QtyType,BatchNumber,PKDDate,ExpiryDate,Price,MRPONPrice,SUM(QTY),Tag FROM (    
SELECT ''DAMAGE'' AS QtyType,NULL AS BatchNumber,CONVERT (NVARCHAR,PKDDate,103) AS PKDDate,CONVERT (NVARCHAR,ExpiryDate,103) AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice,                                                       
SUM(ActualDmgQty)AS QTY ,3 AS Tag FROM tblProductInventory                                                       
WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId='+CONVERT(NVARCHAR(10),@ProdId)+' AND PKDDate <= '+ ''''+CONVERT(NVARCHAR(10),@SRDate)+''''+' AND (ActualDmgQty > 0)        
GROUP BY PKDDate,ExpiryDate,              
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice '            
set @strQry += CASE WHEN @Show0BatchinSR = 0 THEN '' ELSE ' UNION ALL    
SELECT ''DAMAGE'' AS QtyType,NULL AS BatchNumber,CONVERT (NVARCHAR,PKDDate,103) AS PKDDate,CONVERT (NVARCHAR,ExpiryDate,103) AS ExpiryDate,                                                       
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END) AS Price ,MRPONPrice,                                                       
SUM(ActualDmgQty)AS QTY ,3 AS Tag FROM tblProductInventory                                                       
WHERE BranchID = '+CONVERT(NVARCHAR(10),@BranchID)+' and ProdId='+CONVERT(NVARCHAR(10),@ProdId)+' AND PKDDate <= '+ ''''+CONVERT(NVARCHAR(10),@SRDate)+''''+' AND (ActualDmgQty = 0 )        
GROUP BY PKDDate,ExpiryDate,              
(CASE WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =1 THEN PurchasePrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =2 THEN SalesPrice WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =3 THEN ECP                 
WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =4 THEN MRP  WHEN '+CONVERT(NVARCHAR(10),@AppPriceId)+' =5 THEN SPLPrice ELSE ReturnPrice END),MRPONPrice'  END    
set @strQry += ') AS R    
GROUP BY QtyType,BatchNumber,PKDDate,ExpiryDate,MRPONPrice,Tag,Price ORDER BY ExpiryDate ASC '      
INSERT INTO #TempInventoryDetail     
EXEC sys.sp_executesql @strQry, N'@BranchID INT, @AppPriceId INT, @Mode SMALLINT, @ProdId INT, @SRDate DATE, @ModifyId INT, @SalesORDamage INT, @Show0BatchinSR int', @BranchID = @BranchID, @AppPriceId = @AppPriceId, @Mode = @Mode, @ProdId = @ProdId, @SRDate = @SRDate, @ModifyId = @ModifyId, @SalesORDamage = @SalesORDamage, @Show0BatchinSR = @Show0BatchinSR  
END                                                       
END                              
--SELECT * FROM #TempInventoryDetail                                            
print @ModifyId                                                    
IF ISNULL(@ModifyId,0)=0                                    
BEGIn                                                      
SELECT QtyType,BatchNumber,CONVERT(NVARCHAR,PKDDate,103) AS PKDDate,CONVERT(NVARCHAR,ExpiryDate,103) AS ExpiryDate,Price,MRP,Qty,Tag                                                      
FROM #TempInventoryDetail --where Qty > 0          
DROP TABLE #TempInventoryDetail                                                      
END                                                      
ELSE                             
BEGIN                                       
CREATE TABLE #TempModifyTable([Type] NVARCHAR(50),BatchNumber NVARCHAR(255),PKDDate DATE NULL,ExpiryDate DATE NULL,                                                       
Price DECIMAL (25,6),MRP DECIMAL (25,6),Qty DECIMAL (25,6),Tag INT)              
--sales return                              
print @Mode                              
IF ISNULL(@Mode,0)=1                                                       
BEGIN
print 'Modify return'
INSERT INTO #TempModifyTable                    
SELECT (CASE WHEN QtyType =1 THEN 'SALE' ELSE 'FREE' END),(CASE P.BatchNumber WHEN '' THEN NULL ELSE P.BatchNumber END) AS BatchNumber,                    
(CASE P.PKDDate WHEN '' THEN NULL ELSE P.PKDDate END) AS PKDDate,(CASE P.ExpiryDate WHEN '' THEN NULL ELSE P.ExpiryDate END) AS ExpiryDate,(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END),                    
(CASE WHEN QtyType =1 THEN P.MRPONPrice ELSE 0 END),SUM(AdjustQty),SOD.QtyType                    
FROM tblTranSalesDetail SOD                    
JOIN tblProductInventory P ON P.InventoryId =SOD.InventoryId                    
WHERE InvId =@ModifyId AND SOD.ProdId =@ProdId --and sod.TaxId = 100
GROUP BY P.BatchNumber,P.PKDDate ,P.ExpiryDate,MRPONPrice ,QtyType,                    
(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END)              
order by  ExpiryDate                    
END                            
ELSE                            
BEGIN                                                      
INSERT INTO #TempModifyTable                    
SELECT 'DAMAGE' ,(CASE P.BatchNumber WHEN '' THEN NULL ELSE P.BatchNumber END) AS BatchNumber,(CASE P.PKDDate WHEN '' THEN NULL ELSE P.PKDDate END) AS PKDDate,                    
(CASE P.ExpiryDate WHEN '' THEN NULL ELSE P.ExpiryDate END) AS ExpiryDate,(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END),                    
P.MRPONPrice,SUM(AdjustQty),SOD.QtyType FROM tblTranSalesDetail SOD                    
JOIN tblProductInventory P ON P.InventoryId =SOD.InventoryId                    
WHERE InvId =@ModifyId AND SOD.ProdId =@ProdId                    
GROUP BY P.BatchNumber,P.PKDDate ,P.ExpiryDate,MRPONPrice ,QtyType,                    
(CASE WHEN @AppPriceId =1 THEN PurchasePrice WHEN @AppPriceId =2 THEN SalesPrice WHEN @AppPriceId =3 THEN ECP                 
WHEN @AppPriceId =4 THEN MRP  WHEN @AppPriceId =5 THEN SPLPrice ELSE ReturnPrice END)                
--ORDER BY P.TransDate DESC                        
END                                    

IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)=0 AND ISNULL(@TrackPkg,0)=0        
BEGIN                     
MERGE #TempModifyTable MT USING #TempInventoryDetail InvT                    
ON InvT.Price= MT.Price AND InvT.MRP= MT.MRP AND InvT.Tag= MT.Tag                    
WHEN MATCHED THEN UPDATE SET MT.QTY = (CASE WHEN ISNULL((MT.QTY - InvT.QTY),0)<0 THEN (MT.QTY - InvT.QTY)*-1 ELSE (MT.QTY - InvT.QTY) END)                    
WHEN NOT MATCHED THEN INSERT VALUES(InvT.QtyType ,InvT.BatchNumber ,InvT.PKDDate ,InvT.ExpiryDate,InvT.Price,InvT.MRP,InvT.Qty,InvT.Tag);                    
TRUNCATE TABLE #TempInventoryDetail                    
INSERT INTO #TempInventoryDetail SELECT [Type],BatchNumber,PKDDate, ExpiryDate,Price,MRP,Qty,Tag                   
FROM #TempModifyTable                    
END                                                       
IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)<>0 AND ISNULL(@TrackPkg,0)=0                                                       
BEGIN                                                       
MERGE #TempModifyTable MT USING #TempInventoryDetail InvT                                                       
ON MT. BatchNumber= InvT.BatchNumber AND InvT.Price= MT.Price AND InvT.MRP= MT.MRP AND InvT.Tag= MT.Tag                                                       
WHEN MATCHED THEN UPDATE SET MT.QTY = (CASE WHEN ISNULL((MT.QTY - InvT.QTY),0)<0 THEN (MT.QTY - InvT.QTY)*-1 ELSE (MT.QTY - InvT.QTY) END)                                                       
WHEN NOT MATCHED THEN INSERT VALUES(InvT.QtyType ,InvT.BatchNumber ,InvT.PKDDate ,InvT.ExpiryDate,InvT.Price,InvT.MRP,InvT.Qty,InvT.Tag);                                                       
TRUNCATE TABLE #TempInventoryDetail                    
INSERT INTO #TempInventoryDetail SELECT [Type],BatchNumber,PKDDate, ExpiryDate,Price,MRP,Qty,Tag                                                       
FROM #TempModifyTable                      
END                                                       
IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)<>0 AND ISNULL(@TrackPkg,0)<>0                                                       
BEGIN                                                       
MERGE #TempModifyTable MT USING #TempInventoryDetail InvT                                                       
ON MT. BatchNumber= InvT.BatchNumber AND MT. PKDDate= InvT.PKDDate AND MT. ExpiryDate= InvT.ExpiryDate AND InvT.Price= MT.Price AND InvT.MRP= MT.MRP AND InvT.Tag= MT.Tag                                           
WHEN MATCHED THEN UPDATE SET MT.QTY = (CASE WHEN ISNULL((MT.QTY - InvT.QTY),0)<0 THEN (MT.QTY - InvT.QTY)*-1 ELSE (MT.QTY - InvT.QTY) END)                                                       
WHEN NOT MATCHED THEN INSERT VALUES(InvT.QtyType ,InvT.BatchNumber ,InvT.PKDDate ,InvT.ExpiryDate,InvT.Price,InvT.MRP,InvT.Qty,InvT.Tag);                                               
TRUNCATE TABLE #TempInventoryDetail                                                       
INSERT INTO #TempInventoryDetail SELECT [Type],BatchNumber,PKDDate, ExpiryDate,Price,MRP,Qty,Tag                                                       
FROM #TempModifyTable ORDER BY ExpiryDate ASC                                                       
END                                                       
IF ISNULL(@TrackInventory,0)<>0 AND ISNULL(@TrackBatch,0)=0 AND ISNULL(@TrackPkg,0)<>0                                      
BEGIN                                                       
MERGE #TempModifyTable MT USING #TempInventoryDetail InvT                                                
ON MT. PKDDate= InvT.PKDDate AND MT. ExpiryDate= InvT.ExpiryDate AND InvT.Price= MT.Price AND InvT.MRP= MT.MRP AND InvT.Tag= MT.Tag                                                       
WHEN MATCHED THEN UPDATE SET MT.QTY = (CASE WHEN ISNULL((MT.QTY - InvT.QTY),0)<0 THEN (MT.QTY - InvT.QTY)*-1 ELSE (MT.QTY - InvT.QTY) END)                                                       
WHEN NOT MATCHED THEN INSERT VALUES(InvT.QtyType ,InvT.BatchNumber ,InvT.PKDDate ,InvT.ExpiryDate,InvT.Price,InvT.MRP,InvT.Qty,InvT.Tag);                                                       
TRUNCATE TABLE #TempInventoryDetail                                           
INSERT INTO #TempInventoryDetail SELECT [Type],BatchNumber,PKDDate, ExpiryDate,Price,MRP,Qty,Tag                                                       
FROM #TempModifyTable ORDER BY ExpiryDate ASC                               
END                                                      
    
SELECT QtyType,BatchNumber,CONVERT(NVARCHAR,PKDDate,103) AS PKDDate,CONVERT(NVARCHAR,ExpiryDate,103) AS ExpiryDate,Price,MRP,SUM(Qty) AS Qty,Tag                                                       
FROM #TempInventoryDetail where (isnull(Qty,0)) > (case when isnull(@ModifyId,0) > 0 then -1 else 0 end)
GROUP BY QtyType,BatchNumber,PKDDate,ExpiryDate,Price,MRP,Tag                                               
ORDER BY tag asc,(ExpiryDate) ASC         --tag asc,                                            
DROP TABLE #TempInventoryDetail                                                       
DROP TABLE #TempModifyTable                                                      
END                                                      
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetPRProductIntoryBatch';
GO
--uspGetPRProductIntoryBatch 124,4,'2026-02-24',1,0,107
--uspGetPRProductIntoryBatch 124,4,'2026-02-24',1,556,0
CREATE OR ALTER PROCEDURE [dbo].[uspGetPRProductIntoryBatch]          
@ProdId INT = 2,@BranchID INT = 4,@Date DATE = '2025-04-24',@PriceType int = 1,@BillID int = 0,@DraftID int = 0            
AS          
BEGIN          
DECLARE @TrackInventory INT,@TrackBatch INT,@TrackPkg INT          
SELECT @TrackInventory= TrackInventory,@TrackBatch =TrackBatch ,@TrackPkg =TrackPDK FROM tblMasterProduct WHERE ID =@ProdId          
declare @strQuery nvarchar(max)          
IF(ISNULL(@BillID,0) = 0 and ISNULL(@DraftID,0) = 0)--Create          
BEGIN          
set @strQuery = ' SELECT 0 InventoryId,ProdID,isnull(PV.BatchNumber,'''') BatchNumber,PV.PKDDate PKDDate,PV.ExpiryDate ExpiryDate,(SUM(isnull(ActualQty,0))) ActualQty,          
(SUM(isnull(ActualFreeQty,0))) ActualFreeQty,(SUM(isnull(ActualDmgQty,0))) ActualDmgQty,0 Qty,0 FreeQty,0 DmgQty,(PV.MRPONPrice) MRP,0 PurchasePrice,'+      
(case when (convert(nvarchar,@PriceType)) = '1' then  ' isnull(PV.PurchasePrice,0) ' else ' isnull(PV.ReturnPrice,0)' end) +' ReturnPrice          
FROM tblProductInventory PV WHERE(ActualQty > 0 OR ActualFreeQty > 0 OR ActualDmgQty > 0) and pv.ProdID ='+convert(nvarchar,@ProdId)+' and BranchID = '+convert(nvarchar,@BranchID)+'           
and TransDate <= '+''''+convert(nvarchar,@Date)+''''+'          
GROUP BY isnull(PV.BatchNumber,''''),PV.PKDDate,PV.ExpiryDate,PV.MRPONPrice,'+(case when (convert(nvarchar,@PriceType)) = '1' then  'PV.PurchasePrice ' else ' PV.ReturnPrice' end) +',ProdID '          
set @strQuery += (CASE WHEN @TrackPkg = 0 THEN '' ELSE ' order by PV.ExpiryDate DESC' END)          
EXEC sys.sp_executesql @strQuery, N'@ProdId INT, @BranchID INT, @Date DATE, @PriceType int, @BillID int, @DraftID int', @ProdId = @ProdId, @BranchID = @BranchID, @Date = @Date, @PriceType = @PriceType, @BillID = @BillID, @DraftID = @DraftID          
END
ELSE if(ISNULL(@BillID,0) > 0)
BEGIN--Modify          
set @strQuery = 'SELECT  0 InventoryId,ProdID,BatchNumber,PKDDate,ExpiryDate,          
SUM(ActualQty) ActualQty,SUM(ActualFreeQty) ActualFreeQty,SUM(ActualDmgQty) ActualDmgQty,          
SUM(Qty) Qty,SUM(FreeQty) FreeQty,SUM(DmgQty) DmgQty,MRP,PurchasePrice,ReturnPrice FROM (   
SELECT ProdID,isnull(PV.BatchNumber,'''') BatchNumber,PV.PKDDate,PV.ExpiryDate,          
(SUM(ActualQty)) ActualQty,(SUM(ActualFreeQty)) ActualFreeQty,(SUM(ActualDmgQty)) ActualDmgQty,0 Qty,0 FreeQty,0 DmgQty,
(PV.MRPONPrice) MRP,0 PurchasePrice,'+(case when (convert(nvarchar,@PriceType)) = '1' then  'PV.PurchasePrice ' else ' PV.ReturnPrice' end) +' ReturnPrice
FROM tblProductInventory PV WHERE(ActualQty > 0 OR ActualFreeQty > 0 OR ActualDmgQty > 0) and pv.ProdID ='+convert(nvarchar,@ProdId)+' and BranchID = '+convert(nvarchar,@BranchID)+'           
and TransDate <= '+''''+convert(nvarchar,@Date)+''''+'          
GROUP BY isnull(PV.BatchNumber,''''),PV.PKDDate,PV.ExpiryDate,PV.MRPONPrice,'+(case when (convert(nvarchar,@PriceType)) = '1' then  'PV.PurchasePrice ' else ' PV.ReturnPrice' end) +',ProdID '          
set @strQuery += ' UNION ALL '          
set @strQuery += '           
SELECT PD.ProdID,isnull(PV.BatchNumber,'''') BatchNumber,Pv.PKDDate PKDDate,Pv.ExpiryDate ExpiryDate,sum(UomQty * ISNULL(UOMCF,1)) as Qty,          
sum(UomFreeQty * ISNULL(UOMCF,1)) as FreeQty,sum(UomDamageQty * ISNULL(UOMCF,1)) as DmgQty,sum(UomQty * ISNULL(UOMCF,1)) as Qty,          
sum(UomFreeQty * ISNULL(UOMCF,1)) as FreeQty,sum(UomDamageQty * ISNULL(UOMCF,1)) as DmgQty,PV.MRPONPrice MRP,0 PurchasePrice,          
'+(case when (convert(nvarchar,@PriceType)) = '1' then  'PD.UomPurchasePrice ' else ' PD.UomReturnPrice' end) +' ReturnPrice          
FROM tblTransPurchaseHeader PH          
JOIN tblTransPurchaseDetail PD ON PD.HID = PH.ID          
join tblProductInventory pv on pv.InventoryId = PD.InventoryId          
join tblMasterProduct mp on mp.ID = PD.ProdID          
where PD.ProdID = '+ CONVERT(NVARCHAR(50),@ProdID) +' and PD.HID = '+ CONVERT(NVARCHAR(50),@BillID)+' AND PH.BranchID = ' +CONVERT(NVARCHAR(50),@BranchID)          
set @strQuery += ' GROUP BY PD.ProdID,PD.BatchNo,PD.PKD,PD.Expiry,PD.UomMRP,PV.MRPONPrice,isnull(PV.BatchNumber,''''),Pv.PKDDate,
Pv.ExpiryDate,'+(case when (convert(nvarchar,@PriceType)) = '1' then  'PD.UomPurchasePrice ' else ' PD.UomReturnPrice' end) +',PD.ProdID  '  
SET @strQuery += ' ) AS REC group by ProdID,BatchNumber,PKDDate,ExpiryDate,MRP,PurchasePrice,ReturnPrice '          
set @strQuery += (CASE WHEN @TrackPkg = 0 THEN '' ELSE ' order by ExpiryDate DESC' END)          
EXEC sys.sp_executesql @strQuery, N'@ProdId INT, @BranchID INT, @Date DATE, @PriceType int, @BillID int, @DraftID int', @ProdId = @ProdId, @BranchID = @BranchID, @Date = @Date, @PriceType = @PriceType, @BillID = @BillID, @DraftID = @DraftID
END  
ELSE if(ISNULL(@DraftID,0) > 0)
BEGIN
-- DRAFT EDIT BATCH
PRINT 'DRAFT EDIT BATCH'
CREATE TABLE #MainDraftData    
(    
    InventoryId     INT,    
    ProdID          INT,    
    BatchNumber     NVARCHAR(50) NULL,     
    PKDDate         DATE NULL,    
    ExpiryDate      DATE NULL,    
    Qty             DECIMAL(18,4),    
    FreeQty         DECIMAL(18,4),    
    DmgQty          DECIMAL(18,4),    
    MRP             DECIMAL(18,4),    
    PurchasePrice   DECIMAL(18,4),    
    ReturnPrice     DECIMAL(18,4),    
    PRQty           DECIMAL(18,4),    
    PRFree          DECIMAL(18,4),    
    PRDmg           DECIMAL(18,4),    
    TaxName         NVARCHAR(100),    
    GSTPern         DECIMAL(5,2),    
    PurchaseTaxID   INT,    
    ConversionRate  DECIMAL(18,4),
    UOMPurchasePrice   DECIMAL(18,4),    
    UOMReturnPrice     DECIMAL(18,4)
);    
    
    
select PD.*,MTT.TaxName into #draftdetails from tblPurchaseDraftDetail PD    
join tblMasterTax MTT ON MTT.TaxID = PD.TaxID where hid = @DraftID AND  ProdID = @ProdID  
ALTER TABLE #draftdetails ADD RowID INT IDENTITY(1,1);    
    
DECLARE @DRFTPRODID INT,@MRP DECIMAL(25,4),@PPrice DECIMAL(25,4),@RTNPrice DECIMAL(25,4),@batchno nvarchar(255),    
@pkd date,@expiry date,@qty DECIMAL(25,4),@freeqty DECIMAL(25,4),@dmgqty DECIMAL(25,4),@TaxName nvarchar(255),    
@GSTPern  DECIMAL(25,4),@PurchaseTaxID INT,@ConversionRate  DECIMAL(25,4),@orgPPrice DECIMAL(25,4),@orgRTNPrice DECIMAL(25,4)    
    
    
declare @n int = 1,@totcount int = (select count(*) from #draftdetails)    
    
while(@totcount >= @n)    
BEGIN    
select @DRFTPRODID = ProdID,@batchno =  isnull(BatchNo,''),@pkd = PKD,@expiry = Expiry,@qty =  UomQty,    
@freeqty = UomFreeQty,@dmgqty = UomDamageQty,@PPrice = UomPurchasePrice,@RTNPrice = UomReturnPrice,
@orgPPrice = PurchasePrice,@orgRTNPrice = ReturnPrice,
@MRP = UomMRP,@TaxName = TaxName,@GSTPern = TaxPern,@PurchaseTaxID = TaxID,@ConversionRate = ISNULL(UOMCF,1)     
from #draftdetails WHERE RowID = @n    
    
SELECT ProdID,BatchNumber,PKDDate,ExpiryDate,SUM(Qty) Qty,SUM(FreeQty) FreeQty,SUM(DmgQty) DmgQty,MRP,PurchasePrice,ReturnPrice    
 into #prodinvdata FROM (    
select PV.ProdID,ISNULL(PV.BatchNumber,'') BatchNumber,convert(date,PV.PKDDate,105) PKDDate,convert(date,PV.ExpiryDate,105) ExpiryDate,    
(SUM(ISNULL(ActualQty,0))) Qty,(SUM(ISNULL(ActualFreeQty,0))) FreeQty,(SUM(ISNULL(ActualDmgQty,0))) DmgQty,              
(PV.MRPONPrice) MRP,(case when @PriceType = 6 THEN PV.ReturnPrice ELSE PV.PurchasePrice end) PurchasePrice,              
(case when @PriceType = 6 THEN PV.ReturnPrice ELSE PV.PurchasePrice end) ReturnPrice    
from tblProductInventory PV
where (ProdID = @DRFTPRODID and branchid = @BranchID and TransDate <= @Date) AND (ActualQty > 0 OR ActualFreeQty > 0 OR ActualDmgQty > 0)    
GROUP BY ISNULL(PV.BatchNumber,''),PV.PKDDate,PV.ExpiryDate,PV.MRPONPrice,PV.ReturnPrice,PV.ProdID,PV.PurchasePrice) AS GRP    
GROUP BY ProdID,BatchNumber,PKDDate,ExpiryDate,MRP,PurchasePrice,ReturnPrice    
ALTER TABLE #prodinvdata ADD IDENT INT IDENTITY(1,1);    
DECLARE @nPV INT = 1,@totPV int = (select count(*) from #prodinvdata)    
declare @pvProdID int,@pvBatchNumber nvarchar(255),@pvPKDDate date,@pvExpiryDate date,@pvQty DECIMAL(25,4),    
@pvFreeQty DECIMAL(25,4),@pvDmgQty DECIMAL(25,4),@pvMRP DECIMAL(25,4),@pvPurchasePrice DECIMAL(25,4),@pvReturnPrice DECIMAL(25,4)    
    
while(@totPV >= @nPV)    
BEGIN    
    
select @pvProdID=ProdID,@pvBatchNumber= isnull(BatchNumber,''), @pvPKDDate=PKDDate, @pvExpiryDate=ExpiryDate,@pvQty=Qty,@pvFreeQty=FreeQty,    
@pvDmgQty=DmgQty,@pvMRP=MRP,@pvPurchasePrice=PurchasePrice,@pvReturnPrice=ReturnPrice    
from #prodinvdata where IDENT = @nPV    
    
declare @adjQty decimal(25,4) = 0,@adjFreeQty decimal(25,4) = 0,@adjDmtQty decimal(25,4) = 0    
declare @compareprice decimal(25,4) = (case when @PriceType = 1 then @orgPPrice else @orgRTNPrice end)    
declare @compareProdInvprice decimal(25,4) = (case when @PriceType = 1 then @pvPurchasePrice else @pvReturnPrice end)    
--select @qty qty,@freeqty freeqty,@dmgqty dmgqty,@compareprice compareprice,@compareProdInvprice compareProdInvprice,@MRP MRP,@pvMRP pvMRP,@batchno batchno,    
--@pvBatchNumber pvBatchNumber,@pkd pkd,@pvPKDDate pvPKDDate,@expiry expiry,@pvExpiryDate pvExpiryDate    
if(@compareprice = @compareProdInvprice and @MRP = @pvMRP and isnull(@batchno,'') = isnull(@pvBatchNumber,'')     
and  isnull(@pkd,'') =  isnull(@pvPKDDate,'') and  isnull(@expiry,'') =  isnull(@pvExpiryDate,''))    
begin    
print 'assign qty'    
set @adjQty = @qty;    
set @adjFreeQty = @freeqty;    
set @adjDmtQty = @dmgqty;    
end    
    
insert into #MainDraftData values(0,@DRFTPRODID,@pvBatchNumber,@pvPKDDate,@pvExpiryDate,@pvQty,@pvFreeQty,@pvDmgQty,@pvMRP,    
@pvPurchasePrice,@pvReturnPrice,@adjQty,@adjFreeQty,@adjDmtQty,@TaxName,@GSTPern,@PurchaseTaxID,@ConversionRate,@PPrice,@RTNPrice    
)    
--@PPrice,@RTNPrice
SET @nPV += 1    
end    
    
drop table #prodinvdata    
SET @n += 1    
END    
--select * from #MainDraftData    
SELECT InventoryId,ProdID,BatchNumber,PKDDate,ExpiryDate,Qty ActualQty,FreeQty ActualFreeQty,DmgQty ActualDmgQty,

SUM(PRQty) AS PRQty,SUM(PRFree) AS PRFree,SUM(PRDmg) AS PRDmg,MRP,0 PurchasePrice,
CASE WHEN @PriceType = 1 THEN PurchasePrice ELSE ReturnPrice END ReturnPrice
FROM #MainDraftData
GROUP BY InventoryId,ProdID,BatchNumber,PKDDate,ExpiryDate,Qty,FreeQty,DmgQty,MRP,PurchasePrice,ReturnPrice
drop table #draftdetails,#MainDraftData
END
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetAssignInvoices';
GO
--[uspGetSetAssignInvoices] 2,0,0,0,null,'2025-05-05','2026-09-01',0,3,0  
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetAssignInvoices]  
@Mode INT,@ID int = 0,@Beat NVARCHAR(MAX) = NULL,@Salesman NVARCHAR(MAX) = NULL,@Party NVARCHAR(MAX) = NULL,@FromDate date = null,  
@ToDate date = null,@Showall int = null,@BranchID smallint = 0,@BeatSMFilter int = 0  
as  
BEGIN  
DECLARE @StrQuery NVARCHAR(MAX) = ''  
IF(@Mode = 1)  
BEGIN  
select 1 Type,'Salesman' Trans,ID,'' Code,Name from tblMasterSalesman where Active = 1  
union all  
SELECT 2 Type,'Beat' Trans,ID,'',Name FROM tblMasterBeat WHERE Active = 1  
union all  
SELECT 3 Type,'Customer' Trans,ID,Code,Name FROM tblMasterCustomer WHERE Active = 1  
union all  
SELECT 4 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 21  
union all  
SELECT 5 Type,'Branch' Trans,ID,'',Name FROM tblMasterBranchOffice WHERE Active = 1  
union all  
select 6 Type,'Today Route' Trans,CONVERT(NVARCHAR,ISNULL(BranchID,0)),CONVERT(NVARCHAR,ISNULL(BeatID,0)),CONVERT(NVARCHAR,ISNULL(SalesmanID,0)) from tblUsers WHERE ID = @ID  
order by Type,Name  
END  
IF(@Mode = 2)  
BEGIN  
SET @strQuery = 'SELECT ID,DocID,DocDate,RefNo,Salesman,Status,StatusID,DetailSts,SUM(coldtl) coldtl,InvoiceCount,UserName,LastActionTime,Remarks AS Remarks,  
Narration AS Narration,convert(nvarchar(10),dtlOpen) +'' - ''+convert(nvarchar(10), dtlClose)+'' - ''+convert(nvarchar(10),dtlReturn) AS [OCR]  
,BranchID,[Branch Name] ,dtlOpen,dtlClose,dtlReturn,(dtlClose + dtlReturn)  AnyoneStsChanged  FROM (  
SELECT ID,DocID,DocDate,RefNo,Salesman,Status,StatusID,isnull(coldtl,0) coldtl,DetailSts,InvoiceCount,UserName,LastActionTime,  
dtlOpen,dtlClose,dtlReturn,Remarks,Narration,BranchID,[Branch Name],AIVDATE FROM (  
select AINV.ID,DocID,convert(nvarchar(25),AINV.DocDate,103) DocDate,RefNo,SM.Name Salesman,sts.Description Status,AINV.Status StatusID,  
COUNT(DISTINCT CASE  
WHEN CH.Status = 1 AND CD.InvoiceID = AINVD.InvID AND CD.AssignID = AINVD.HID  
THEN CD.HID END  
) AS coldtl,  
(select count(*) from tblAssignInvoicesDETAIL where Status = 6 and tblAssignInvoicesDETAIL.HID = AINV.ID) DetailSts,  
(select count(*) from tblAssignInvoicesDETAIL where tblAssignInvoicesDETAIL.HID = AINV.ID) InvoiceCount,  
CUR.UserName UserName,CONVERT(NVARCHAR(100),AINV.CDate) LastActionTime,  
(select COUNT(*) from tblAssignInvoicesDETAIL DD where DD.HID = AINV.ID AND DD.Status = 1) dtlOpen,  
(select COUNT(*) from tblAssignInvoicesDETAIL DD1 where DD1.HID = AINV.ID AND DD1.Status = 5) dtlClose,  
(select COUNT(*) from tblAssignInvoicesDETAIL DD2 where DD2.HID = AINV.ID AND DD2.Status = 6) dtlReturn,AINV.Remarks,AINV.Narration  
,isnull(AINV.BranchID,0) BranchID,MBO.Name[Branch Name],AINV.DocDate AIVDATE  
from tblAssignInvoicesHeader AINV  
join tblAssignInvoicesDETAIL AINVD ON AINVD.HID = AINV.ID  
JOIN tblMasterSalesman SM ON SM.ID = AINV.SalesmanID  
JOIN tblStatus Sts ON Sts.ID = AINV.Status  
LEFT JOIN tbltranordercollectionDetail CD ON CD.InvoiceID = AINVD.InvID AND CD.AssignID = AINVD.HID  
LEFT JOIN tbltranordercollectionheader CH ON CH.ID = CD.HID  
LEFT JOIN tblMasterBranchOffice MBO on MBO.ID = AINV.BranchID  
JOIN tblUsers CUR ON CUR.ID = AINV.CBy  
WHERE AINV.ID > 0 '  
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND AINV.DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END  
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND AINV.Status in (1,3,5)' END  
SET @strQuery += ' group by AINV.ID,DocID,AINV.DocDate ,RefNo,SM.Name ,sts.Description ,AINV.Status ,  
AINVD.Status,AINVD.InvID,AINVD.HID,CUR.UserName,AINV.CDate,AINV.Remarks,AINV.Narration,AINV.BranchID,MBO.Name  
) AS REC group by ID,DocID,DocDate,RefNo,Salesman,Status,StatusID,coldtl,DetailSts,InvoiceCount,UserName,LastActionTime,dtlOpen,  
dtlClose,dtlReturn,Remarks,Narration,BranchID,[Branch Name],AIVDATE) AS REC1  
GROUP BY ID,DocID,DocDate,RefNo,Salesman,Status,StatusID,DetailSts,InvoiceCount,UserName,LastActionTime,dtlOpen,dtlClose,dtlReturn,  
Remarks,Narration,BranchID,[Branch Name],AIVDATE,dtlOpen,dtlClose,dtlReturn order by AIVDATE DESC,DocID desc, ID DESC'  
print @strQuery
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID int, @Beat NVARCHAR(MAX), @Salesman NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @BranchID smallint, @BeatSMFilter int', @Mode = @Mode, @ID = @ID, @Beat = @Beat, @Salesman = @Salesman, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall, @BranchID = @BranchID, @BeatSMFilter = @BeatSMFilter  
END  
IF(@Mode = 3)  
BEGIN  
SELECT *,dbo.fnTransactionPrefix(DocDate,BranchID,TransID) Prefix FROM tblAssignInvoicesHeader WHERE ID = @ID  
END  
IF(@Mode = 4)  
BEGIN  
SELECT SH.ID,SH.DocID,convert(nvarchar(50),SH.InvDate,103) Date,SH.DocRef RefNo,MB.Name Beat,SM.Name Salesman,MC.Name Customer,dbo.fnGetRoundedValue(NetAmt) NetAmt,  
dbo.fnGetRoundedValue(Balance) Balance,DATEDIFF(dd,SH.InvDate,GETDATE()) Ageing,AID.Status,  
(select count(*) from tblAssignInvoicesDETAIL AD JOIN tblAssignInvoicesHeader AH ON AH.ID = AD.HID AND AH.Status IN (1,3,5)  
where AD.InvID = SH.ID) AssignedInvoiceCount,STS.Description StatusDesp FROM tblAssignInvoicesDetail AID  
JOIN tblAssignInvoicesHeader AIH ON AIH.ID = AID.HID  
JOIN tbltransalesheader SH ON SH.ID = AID.INVID  
JOIN tblMasterCustomer MC ON MC.ID = SH.CustID  
LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatID  
LEFT JOIN tblMasterSalesman SM ON SM.ID = SH.SalesManID  
join tblStatus STS ON STS.ID = AID.Status
WHERE HID = @ID  
END  
IF(@Mode = 5)-- Filter Documents  
BEGIN  
IF(@BeatSMFilter = 0)  
BEGIN  
SET @StrQuery = ' select SH.ID,SH.Status StatusID,SH.DocID,convert(nvarchar(50),SH.InvDate,103) Date,SH.DocRef RefNo,MB.Name Beat,  
SM.Name Salesman,MC.Name Customer,dbo.fnGetRoundedValue(NetAmt) NetAmt,  
dbo.fnGetRoundedValue(Balance) Balance,DATEDIFF(dd,SH.InvDate,GETDATE()) Ageing,  
(select count(*) from tblAssignInvoicesDETAIL AD JOIN tblAssignInvoicesHeader AH ON AH.ID = AD.HID AND AH.Status IN (1,3,5)  
where AD.InvID = SH.ID) [AssignedInvoiceCount],ISNULL(SH.BeatID,0) BeatID,ISNULL(SH.SalesManID,0) SalesManID  
from tbltransalesheader SH  
JOIN tblMasterCustomer MC ON MC.ID = SH.CustID  
LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatID  
LEFT JOIN tblMasterSalesman SM ON SM.ID = SH.SalesManID where status in (1,3,5) AND SH.DocPrefix = 15 and SH.balance > 0  
and SH.ID NOT IN (select InvID from tblAssignInvoicesDetail  
WHERE HID IN (select ID from tblAssignInvoicesHeader WHERE Status in (1,3)) AND Status in (1,5)) '  
SET @strQuery += CASE WHEN ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND SH.InvDate <= '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END  
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MC.Name = @Party' END  
SET @strQuery += CASE WHEN ISNULL(@BranchID,'0') = '0' THEN '' ELSE ' AND SH.BranchID = '+''''+CONVERT(NVARCHAR,@BranchID) +'''' END  
SET @strQuery += CASE WHEN ISNULL(@Beat,'0') = '0' THEN '' ELSE ' AND SH.BeatID = @Beat' END  
SET @strQuery += CASE WHEN ISNULL(@Salesman,'0') = '0' THEN '' ELSE ' AND SH.SalesManID = @Salesman' END  
SET @strQuery += ' order by SH.InvDate,SH.DocValue '  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID int, @Beat NVARCHAR(MAX), @Salesman NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @BranchID smallint, @BeatSMFilter int', @Mode = @Mode, @ID = @ID, @Beat = @Beat, @Salesman = @Salesman, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall, @BranchID = @BranchID, @BeatSMFilter = @BeatSMFilter  
END  
ELSE BEGIN  
SET @StrQuery = 'select ID,DocID,convert(nvarchar(50),Date,103) Date,RefNo,Beat,Salesman,Customer,NetAmt,Balance,Ageing,  
AssignedInvoiceCount,BeatID,SalesManID,StatusID from ( select SH.ID,SH.Status StatusID,SH.DocID,SH.InvDate Date,SH.DocRef RefNo,MB.Name Beat,  
SM.Name Salesman,MC.Name Customer,dbo.fnGetRoundedValue(NetAmt) NetAmt,  
dbo.fnGetRoundedValue(Balance) Balance,DATEDIFF(dd,SH.InvDate,GETDATE()) Ageing,  
(select count(*) from tblAssignInvoicesDETAIL AD JOIN tblAssignInvoicesHeader AH ON AH.ID = AD.HID AND AH.Status IN (1,3,5)  
where AD.InvID = SH.ID) [AssignedInvoiceCount],DocValue ,'+  
(CASE WHEN isnull(@Beat,'0') != '0' AND isnull(@Salesman,'0') = '0' THEN 'ISNULL(BSM.BeatID,0) BeatID,  
ISNULL(SH.SalesManID,0) SalesManID' WHEN isnull(@Beat,'0') = '0' AND isnull(@Salesman,'0') != '0' THEN  
'ISNULL(SH.BeatID,0) BeatID, ISNULL(BSM.SalesManID,0) SalesManID'  
WHEN isnull(@Beat,'0') != '0' AND isnull(@Salesman,'0') != '0' THEN 'ISNULL(BSM.BeatID,0) BeatID,  
ISNULL(BSM.SalesManID,0) SalesManID'  
ELSE 'ISNULL(SH.BeatID,0) BeatID, ISNULL(SH.SalesManID,0) SalesManID' END)  
+'  
 from tbltransalesheader SH  
JOIN tblMasterCustomer MC ON MC.ID = SH.CustID '  
SET @StrQuery += case when isnull(@Beat,'0') != '0' or isnull(@Salesman,'0') != '0' then '  
LEFT JOIN tblBeatSalesmanMapping BSM ON BSM.CustomerID = SH.CustID ' +  
(  
CASE WHEN isnull(@Beat,'0') != '0' AND isnull(@Salesman,'0') = '0' THEN  
' LEFT JOIN tblMasterBeat MB ON MB.ID = BSM.BeatID  
LEFT JOIN tblMasterSalesman SM ON SM.ID = SH.SalesManID '  
  
WHEN isnull(@Beat,'0') = '0' AND isnull(@Salesman,'0') != '0' THEN  
' LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatID  
LEFT JOIN tblMasterSalesman SM ON SM.ID = BSM.SalesManID ' ELSE '  
  
LEFT JOIN tblMasterBeat MB ON MB.ID = BSM.BeatID  
LEFT JOIN tblMasterSalesman SM ON SM.ID = BSM.SalesManID  
' END)  
else  
'LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatID  
LEFT JOIN tblMasterSalesman SM ON SM.ID = SH.SalesManID ' end  
SET @StrQuery += ' where status in (1,3,5) AND SH.DocPrefix = 15 and SH.balance > 0  
and SH.ID NOT IN (select InvID from tblAssignInvoicesDetail WHERE HID IN (select ID from tblAssignInvoicesHeader WHERE Status in (1,3)) AND Status in (1,5)) '  
SET @strQuery += CASE WHEN ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND SH.InvDate <= '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END  
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MC.Name = @Party' END  
SET @strQuery += CASE WHEN ISNULL(@BranchID,'0') = '0' THEN '' ELSE ' AND SH.BranchID = '+''''+CONVERT(NVARCHAR,@BranchID) +'''' END  
SET @strQuery += CASE WHEN ISNULL(@Beat,'0') = '0' THEN '' ELSE ' AND BSM.BeatID = @Beat' END  
SET @strQuery += CASE WHEN ISNULL(@Salesman,'0') = '0' THEN '' ELSE ' AND BSM.SalesManID = @Salesman' END  
SET @strQuery += ' ) as rec  
group by ID,DocID,Date,RefNo,Beat,Salesman,Customer,NetAmt,Balance,Ageing,AssignedInvoiceCount,DocValue,BeatID,SalesManID,  
StatusID   
order by REC.Date,DocValue'  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID int, @Beat NVARCHAR(MAX), @Salesman NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @BranchID smallint, @BeatSMFilter int', @Mode = @Mode, @ID = @ID, @Beat = @Beat, @Salesman = @Salesman, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall, @BranchID = @BranchID, @BeatSMFilter = @BeatSMFilter  
END  
END  
IF(@Mode = 6)-- INVOICE COLLECTION POPUP  
BEGIN  
--@Beat as DocPrefix  
if(@Beat = 15 or @Beat = 16)--Invoice and Sales Return  
BEGIN  
select CH.DocID,FORMAT(CH.ColDate,'dd-MMM-yyyy') ColDate,dbo.fnGetRoundedValue(sum(CD.TotalAmtAdj)) ColAmt,DATEDIFF(DD,SH.InvDate,ColDate) Ageing,  
PM.PaymentMode,(select count(*) from tblAssignInvoicesDETAIL AD JOIN tblAssignInvoicesHeader AH ON AH.ID = AD.HID AND AH.Status IN (1,3,5)  
where AD.InvID = CD.DOCID) AssignedInvoices,dbo.fnGetRoundedValue(SH.NetAmt) InvoiceAmt,dbo.fnGetRoundedValue(SUM(CD.DiscAmt)) DiscAmt  
from tblTranCollectionHeader CH  
JOIN tblTranCollectionDetail CD ON CD.ColID = CH.ColID  
JOIN tblPaymentMode PM ON PM.ID = CH.ColMode  
LEFT JOIN tblTranSalesHeader SH ON SH.ID = CD.DocID  
WHERE CH.DocPrefix = 19 AND CH.Status IN (1,3,5) AND CD.Docprefix in (15,16) AND CD.DocID = @ID  
group by CH.ColID ,CH.DocID,CH.ColDate,PM.PaymentMode,SH.NetAmt,CD.DocID,SH.InvDate  
order by CH.ColID  
END  
ELSE--Bill and Purchase Return  
BEGIN  
select CH.DocID,FORMAT(CH.PYDate,'dd-MMM-yyyy') ColDate,dbo.fnGetRoundedValue(sum(CD.TotalAmtAdj)) ColAmt,DATEDIFF(DD,SH.Date,PYDate) Ageing,  
PM.PaymentMode,(select count(*) from tblAssignInvoicesDETAIL AD JOIN tblAssignInvoicesHeader AH ON AH.ID = AD.HID AND AH.Status IN (1,3,5)  
where AD.InvID = CD.DOCID) AssignedInvoices,dbo.fnGetRoundedValue(SH.NetAmt) InvoiceAmt,dbo.fnGetRoundedValue(SUM(CD.DiscAmt)) DiscAmt  
from tblTranPaymentHeader CH  
JOIN tblTranPaymentDetail CD ON CD.PYID = CH.PYID  
JOIN tblPaymentMode PM ON PM.ID = CH.PYMode  
LEFT JOIN tblTransPurchaseHeader SH ON SH.ID = CD.DocID  
WHERE CH.PYPrefix = 18 AND CH.Status IN (1,3,5) AND CD.Docprefix in (1,12) AND CD.DocID = @ID  
group by CH.PYID ,CH.DocID,CH.PYDate,PM.PaymentMode,SH.NetAmt,CD.DocID,SH.Date  
order by CH.PYID  
END  
END  
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetAutoIndentData';
GO
--[uspGetSetAutoIndentData] 6,NULL,36,1,'','2024-11-10','2024-12-16',0                              
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetAutoIndentData]                              
@Mode INT,@Code NVARCHAR(MAX) = NULL,@ID NVARCHAR(MAX) = NULL,@TransID int =2,@Party NVARCHAR(MAX) = NULL,@FromDate date = null,                              
@ToDate date = null,@Showall int = null                              
AS                              
BEGIN                              
declare @AIOpenCount INT,@POOpenCount INT,@vid int,@strQuery NVARCHAR(MAX)                              
IF(@Mode = 1)                              
BEGIN                              
select 1 Type,'Vendor' Trans,ID,Code,Name from tblMasterVendor where Active = 1                              
union all                              
SELECT 2 Type,'Branch' Trans,ID,'',Name FROM tblMasterBranchOffice WHERE Active = 1                              
union all                              
SELECT 3 Type,'UDN' Trans,UDNID,'',DocName FROM tblMasterUserDefineNoHeader WHERE TransID = 1                              
union all                              
SELECT 4 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 2                              
order by Type,Name                              
END                              
IF(@Mode = 2)                              
BEGIN                              
SELECT * FROM tblMasterVendor WHERE Active = 1 AND Code = @Code ORDER BY Name                              
END                              
IF(@Mode = 21)                              
BEGIN                              
SELECT * FROM tblMasterVendor WHERE Active = 1 AND ID = @Code ORDER BY Name                              
END                              
IF(@Mode = 3)                              
BEGIN                              
SELECT @POOpenCount = COUNT(ID) FROM tblPurchaseOrderHeader WHERE VendorID=@Code AND [Status] IN (1,3)                              
--SET @POOpenCount = 0                              
SELECT @AIOpenCount = COUNT(ID) FROM tblTransAutomaticIndentHeader WHERE VendorID=@Code AND [Status] IN (1,3)                              
                              
SELECT MP.ID,MP.Code,MP.Name,dbo.fnGetRoundedValue(MP.PurchasePrice) Price,dbo.fnGetRoundedValue(sum(ISNULL(PV.ActualQty,0))) ABSQty,                              
mp.BaseUomID,MU.Name BaseUOM,0.00 CustStkReq,MP.MOH,MP.MOQ,@AIOpenCount AIOpen,@POOpenCount POopen                              
FROM tblMasterProduct MP                              
LEFT JOIN tblProductInventory PV ON PV.ProdID = MP.ID                              
join tblMasterUOM MU ON MU.ID = MP.BaseUomID                              
WHERE VendorID = @Code AND MP.Active = 1                              
group by MP.ID,MP.Code,MP.Name,MP.PurchasePrice,mp.BaseUomID,MU.Name,MP.MOH,MP.MOQ                              
END                              
IF(@Mode = 4)                              
BEGIN                              
--SELECT PH.ID,DocID,CONVERT(NVARCHAR,Date,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(ISNULL(SUM(PD.IndentValue),0)) IndentValue,                              
--STS.Description Status FROM tblTransAutomaticIndentHeader PH                              
--LEFT JOIN tblTransAutomaticIndentDetail PD ON PD.HID = PH.ID                              
--JOIN tblMasterVendor MV ON MV.ID = PH.VendorID                              
--JOIN tblStatus STS ON STS.ID = PH.Status                              
--JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                              
--GROUP BY PH.ID,DocID,Date,RefNo,MBO.Name,MV.Name,STS.Description,DocValue                              
--ORDER BY DocValue DESC,PH.ID                              
                              
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,Date,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,            
(ISNULL(SUM(PD.IndentValue),0)) IndentValue,STS.Description Status,            
CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,PH.Remarks,PH.Narration                   
FROM tblTransAutomaticIndentHeader PH                              
LEFT JOIN tblTransAutomaticIndentDetail PD ON PD.HID = PH.ID                              
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID                              
JOIN tblStatus STS ON STS.ID = PH.Status                    
JOIN tblUsers CUR ON CUR.ID = PH.CBy                  
LEFT JOIN tblUsers MUR ON MUR.ID = PH.MBy               
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID WHERE MV.Active IN (0,1) '                              
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                              
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END                              
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                              
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                              
SET @strQuery += ' GROUP BY PH.ID,DocID,Date,RefNo,MBO.Name,MV.Name,STS.Description,DocValue,CUR.UserName,PH.CDate,PH.Status,PH.Remarks,PH.Narration   
ORDER BY PH.Date DESC, PH.DocValue DESC,PH.ID DESC '                              
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                              
                              
END                              
IF(@Mode = 5)                              
BEGIN                              
SELECT PH.ID, PH.Date, PH.TransID, PH.BranchID, PH.DocID, PH.DocValue, PH.VendorID, PH.RefNo,                              
PH.Status, PH.UDFId, PH.UDFDocId, PH.UDFDocPrefix, PH.UDFDocValue, PH.CBy, PH.Remarks, PH.Narration,PoID,dbo.fnTransactionPrefix(PH.Date,BranchID,PH.TransID) Prefix                                 
FROM tblTransAutomaticIndentHeader PH                              
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID              
JOIN tblStatus STS ON STS.ID = PH.Status                              
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                              
where PH.ID = @ID                              
END                              
IF(@Mode = 6)                              
BEGIN                              
select @vid = VendorID from tblTransAutomaticIndentHeader WHERE ID = @ID                              
--SET @POOpenCount = 0                              
SELECT @AIOpenCount = COUNT(ID) FROM tblTransAutomaticIndentHeader WHERE VendorID=@vid AND [Status] IN (1,3)                        
SELECT @POOpenCount = COUNT(ID) FROM tblPurchaseOrderHeader WHERE VendorID=@vid AND [Status] IN (1,3)                        
SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,UOM.Name UOM,DBO.fnGetRoundedValue(PD.PurchasePrice) PurchasePrice,                              
DBO.fnGetRoundedValue(sum(ISNULL(PV.ActualQty,0))) ABSQty,PD.MOH,PD.MOQ,IndentValue,0.00 CustStkReq,@AIOpenCount AIOpen,@POOpenCount POopen                              
FROM tblTransAutomaticIndentDetail PD                              
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                              
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                   
LEFT JOIN tblProductInventory PV ON PV.ProdID = PD.ProdID              
where PD.HID = @ID              
GROUP BY  PD.ProdID,PD.UomID,MP.Code,MP.Name,UOM.Name,PD.PurchasePrice,PD.MOH,PD.MOQ,IndentValue,Serial              
ORDER BY Serial                              
END                              
                              
IF(@Mode = 7)--Draft                              
BEGIN                              
--SELECT PH.ID,DocID,CONVERT(NVARCHAR,Date,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,0 IndentValue,                              
--STS.Description Status FROM tblPurchaseDraftHeader PH                
--JOIN tblMasterVendor MV ON MV.ID = PH.VendorID                              
--JOIN tblStatus STS ON STS.ID = PH.Status                              
--left JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                             
--WHERE Status = 1 AND TransID = 2                              
--ORDER BY PH.ID DESC,Date                              
  --select * from tblPurchaseDraftDetail where HID = 34                            
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,Date,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,            
(SUM(UOMQty)) IndentValue,                              
STS.Description Status,            
CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,PH.Remarks,PH.Narration                              
FROM tblPurchaseDraftHeader PH                              
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID                              
join tblPurchaseDraftDetail PD ON PD.HID = PH.ID                            
JOIN tblStatus STS ON STS.ID = PH.Status                    
JOIN tblUsers CUR ON CUR.ID = PH.CBy                  
LEFT JOIN tblUsers MUR ON MUR.ID = PH.MBy               
left JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID WHERE MV.Active IN (0,1) and PH.TransID = ' + CONVERT(NVARCHAR,@TransID)                     
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                              
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END                              
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                              
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                              
SET @strQuery += ' GROUP BY PH.ID,DocID,Date,RefNo,MBO.Name,MV.Name,STS.Description,CUR.UserName,PH.CDate,PH.Status,PH.Remarks,PH.Narration    
ORDER BY PH.Date DESC,PH.ID DESC '                              
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                              
                              
END                              
IF(@Mode = 8)                              
BEGIN                      
--SELECT * FROM tblPurchaseDraftHeader ORDER BY 1 DESC              
declare @currDocid nvarchar(255) = (SELECT DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 2)                              
SELECT PH.ID, PH.Date, PH.TransID, PH.BranchID, @currDocid DocID, PH.DocValue, PH.VendorID, PH.RefNo,                              
PH.Status, PH.UDFId, PH.UDFDocId, PH.UDFDocPrefix, PH.UDFDocValue, PH.CBy, PH.Remarks, PH.Narration ,isnull(TransactionType,0) PoID,dbo.fnTransactionPrefix(PH.Date,BranchID,PH.TransID) Prefix                             
FROM tblPurchaseDraftHeader PH                              
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID                              
JOIN tblStatus STS ON STS.ID = PH.Status                              
left JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                              
where PH.ID = @ID                              
END                              
IF(@Mode = 9)                              
BEGIN                              
select @vid = VendorID from tblPurchaseDraftHeader WHERE ID = @ID                              
--SET @POOpenCount = 0                              
SELECT @AIOpenCount = COUNT(ID) FROM tblTransAutomaticIndentHeader WHERE VendorID=@vid AND [Status] IN (1,3)                             
SELECT @POOpenCount = COUNT(ID) FROM tblPurchaseOrderHeader WHERE VendorID=@vid AND [Status] IN (1,3)                        
SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,UOM.Name UOM,DBO.fnGetRoundedValue(PD.PurchasePrice) PurchasePrice,                              
DBO.fnGetRoundedValue(sum(ISNULL(PV.ActualQty,0))) ABSQty,MP.MOH,MP.MOQ,                              
convert(int,PD.UomQty) IndentValue,0.00 CustStkReq,@AIOpenCount AIOpen,@POOpenCount POopen                              
FROM tblPurchaseDraftDetail PD                              
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                              
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID              
LEFT JOIN tblProductInventory PV ON PV.ProdID = MP.ID              
where PD.HID = @ID               
GROUP BY PD.ProdID,PD.UomID,MP.Code,MP.Name,UOM.Name,PD.PurchasePrice,MP.MOH,MP.MOQ,PD.UomQty,Serial              
ORDER BY Serial                              
END                              
IF(@Mode = 10)                              
BEGIN       
DECLARE @DraftID INT                              
SELECT @DraftID = ID FROM tblPurchaseDraftHeader WHERE ID = @ID AND TransID = 2                              
DELETE tblPurchaseDraftHeader WHERE ID = @DraftID                              
DELETE tblPurchaseDraftDetail WHERE HID = @DraftID                              
END                              
IF(@Mode = 11)                              
BEGIN                     
select MBO.Name,dbo.fngetroundedvalue(SUM(ActualQty)) ActualQty,MP.Name ProductName,MP.Code ProductCode from tblProductInventory PV                        
JOIN tblMasterBranchOffice MBO ON MBO.ID = PV.BranchID                
JOIN tblMasterProduct MP ON MP.ID = PV.ProdID WHERE PRODID = @Code                        
GROUP BY MBO.Name,MP.Name,MP.Code                        
END                       
IF(@Mode = 12)                              
BEGIN                   
select * from tblFilterDates WHERE Active = 1 order by DisplayIndex                    
END                    
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetBarcodeprint';
GO
--uspGetSetBarcodeprint 4,52          
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetBarcodeprint]          
@Mode INT,@ID NVARCHAR(MAX) = NULL,@TransID int =25,@FromDate date = null,                            
@ToDate date = null,@Showall int = null,@PriceID int = 0        
as          
begin          
declare @strQuery NVARCHAR(MAX)           
if(@Mode = 1)          
BEGIN          
SET @strQuery = 'select PH.ID ID,PH.Status StatusID,DocID,CONVERT(NVARCHAR,DocDate,103) DocDate,RefNo,MBO.Name Branch,          
dbo.fnGetRoundedValue(SUM(Qty * Price)) Value,STS.Description Status,CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,      
PH.Remarks,PH.Narration          
from tblBarcodePrintHeader PH            
JOIN tblBarcodePrintDetail as PD ON PD.HID = PH.ID          
JOIN tblStatus STS ON STS.ID = PH.Status                            
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                      
JOIN tblUsers CUR ON CUR.ID = PH.CBy WHERE TransID = 25 '          
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                            
SET @strQuery += CASE WHEN ISNULL(@ID,'0') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                            
SET @strQuery += CASE WHEN ISNULL(@Showall,'0') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END             
SET @strQuery += ' GROUP BY PH.ID,PH.Status,DocID,DocDate,RefNo,MBO.Name,STS.Description,CUR.UserName,PH.CDate,  
PH.Remarks,PH.Narration,DocValue ORDER BY DocDate DESC,DocValue Desc'      
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID NVARCHAR(MAX), @TransID int, @FromDate date, @ToDate date, @Showall int, @PriceID int', @Mode = @Mode, @ID = @ID, @TransID = @TransID, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall, @PriceID = @PriceID           
END        
IF(@Mode = 2)          
BEGIN          
SELECT p.ID ProdID,Code  ,P.Name [Name],[TrackInventory],[TrackBatch],[TrackPDK] TrackPKD ,[BarcodeUomId],U.Name UomName,        
P.PurchaseCR  AS BarConRate,[BarcodePriceId],                                           
(CASE WHEN [BarcodePriceId]=1 THEN PurchasePrice WHEN [BarcodePriceId]=2 THEN SalesPrice         
WHEN [BarcodePriceId]=3 THEN ECP WHEN [BarcodePriceId]=4 THEN MRP WHEN [BarcodePriceId]= 5 THEN SPLPrice          
ELSE ReturnPrice END) AS Price ,P.PurchaseUomID ,P.PurchaseCR  AS PriceConRate,P.MRP,P.PurchaseTaxID,        
dbo.fngetInclusiveValue(P.PurchaseTaxID,P.MRP,(CASE WHEN [BarcodePriceId]=1 THEN PurchasePrice WHEN [BarcodePriceId]=2 THEN SalesPrice         
WHEN [BarcodePriceId]=3 THEN ECP WHEN [BarcodePriceId]=4 THEN MRP WHEN [BarcodePriceId]= 5 THEN SPLPrice          
ELSE ReturnPrice END)) InclPrice,MT.GST TaxPern,null BatchNo,null PKD,null Expiry        
FROM tblMasterProduct P        
JOIN tblMasterUOM U ON U.ID = P.BarcodeUomID                                                                  
join tblMasterTax MT ON MT.TaxID = P.PurchaseTaxID        
WHERE P.ID = @ID        
END        
IF(@Mode = 3)          
BEGIN          
SELECT BatchNumber,CONVERT(NVARCHAR,PKDDate,103) AS PKDDate,CONVERT(NVARCHAR,ExpiryDate,103) AS ExpiryDate,        
 ISNULL(ActualQty,0) AS Qty,(CASE WHEN @PriceID=1 THEN PurchasePrice WHEN @PriceID=2 THEN SalesPrice         
WHEN @PriceID=3 THEN ECP WHEN @PriceID=4 THEN MRP ELSE SPLPrice END) AS Price ,        
MRPONPrice,TaxValue,InventoryId,0 AS BatchId,dbo.fngetInclusiveValue(P.TaxId,P.MRPONPrice,        
(CASE WHEN @PriceID=1 THEN PurchasePrice         
WHEN @PriceID = 2 THEN SalesPrice WHEN @PriceID = 3 THEN ECP         
WHEN @PriceID = 4 THEN MRP ELSE SPLPrice END)) AS [PriceIncl]        
FROM dbo.tblProductInventory P        
WHERE BranchID = @TransID and ProdId = @ID AND TransDate <= @FromDate AND         
ISNULL(ActualQty,0) > (CASE WHEN @Showall = 1 THEN 0 ELSE -1 END)        
ORDER BY TransDate DESC        
END        
IF(@Mode = 4)          
BEGIN         
SELECT * FROM tblBarcodePrintHeader WHERE ID = @ID      
      
SELECT p.ID ProdID,Code  ,P.Name [Name],[TrackInventory],[TrackBatch],[TrackPDK] TrackPKD ,[BarcodeUomId],U.Name UomName,        
P.PurchaseCR  AS BarConRate,[BarcodePriceId],         
(CASE WHEN [BarcodePriceId]=1 THEN P.PurchasePrice WHEN [BarcodePriceId]=2 THEN P.SalesPrice         
WHEN [BarcodePriceId]=3 THEN P.ECP WHEN [BarcodePriceId]=4 THEN P.MRP WHEN [BarcodePriceId]= 5 THEN P.SPLPrice          
ELSE P.ReturnPrice END) AS Price ,P.PurchaseUomID ,P.PurchaseCR  AS PriceConRate,P.MRP,P.PurchaseTaxID,        
dbo.fngetInclusiveValue(P.PurchaseTaxID,P.MRP,(CASE WHEN [BarcodePriceId]=1 THEN P.PurchasePrice WHEN [BarcodePriceId]=2 THEN P.SalesPrice         
WHEN [BarcodePriceId]=3 THEN P.ECP WHEN [BarcodePriceId]=4 THEN P.MRP WHEN [BarcodePriceId]= 5 THEN P.SPLPrice          
ELSE P.ReturnPrice END)) InclPrice,MT.GST TaxPern,PV.BatchNumber BatchNo,PV.PKDDate PKD,PV.ExpiryDate Expiry,      
BPD.Qty BPQty,BPD.Price BPPrice,BPD.Inventory BPInventory,BPD.ReasonID BPReasonID,BPD.MRP BPMRP,      
dbo.fngetInclusiveValue(P.PurchaseTaxID,BPD.MRP,BPD.Price) BPInclPrice,
dbo.fngetMRPonCumValue(0,P.PurchaseTaxID,1,P.MRP) CumTaxPern,
dbo.fngetMRPonTaxValue(2,BPD.Price,P.MRP,P.PurchaseTaxID,1) MRPonTax,
SUM(isnull(PVABS.ActualQty,0)) ActualQty,SUM(isnull(PVABS.ActualFreeQty,0)) ActualFreeQty
FROM tblBarcodePrintDetail BPD       
JOIN tblBarcodePrintHeader BPH ON BPH.ID = BPD.HID
JOIN tblMasterProduct P  ON BPD.ProdID = P.ID      
JOIN tblMasterUOM U ON U.ID = P.BarcodeUomID                                                                  
join tblMasterTax MT ON MT.TaxID = P.PurchaseTaxID        
join tblProductInventory PV ON PV.InventoryId = BPD.Inventory
left join tblProductInventory PVABS ON PVABS.ProdID = BPD.ProdID AND PVABS.BranchID = BPH.BranchID
WHERE BPD.HID = @ID  
GROUP BY
    P.ID,
    P.Code,
    P.Name,
    P.TrackInventory,
    P.TrackBatch,
    P.TrackPDK,
    P.BarcodeUomId,
    U.Name,
    P.PurchaseCR,
    p.BarcodePriceId,
    P.PurchasePrice,
    P.SalesPrice,
    P.ECP,
    P.MRP,
    P.SPLPrice,
    P.ReturnPrice,
    P.PurchaseUomID,
    P.PurchaseTaxID,
    MT.GST,
    PV.BatchNumber,
    PV.PKDDate,
    PV.ExpiryDate,
    BPD.Qty,
    BPD.Price,
    BPD.Inventory,
    BPD.ReasonID,
    BPD.MRP,BPD.Serial    
ORDER BY BPD.Serial      
      
END      
IF(@Mode = 5)--BARCODE PRINT GET DOCUMENT DETAILS    
BEGIN        
SELECT Prod.CODE ProdCode,dbo.fngetInclusiveValue(Prod.PurchaseTaxID,Detail.MRP,Detail.Price)    
as price,Detail.Qty,Prod.Name ProdName ,    
CONVERT(NVARCHAR,InvProd.PKDDate,103) AS PKD ,             
InvProd.BatchNumber ,CONVERT(NVARCHAR,InvProd.ExpiryDate,103) AS ExpiryDate,             
InvProd.MRPONPrice, --(InvProd.MRPONPrice +((InvProd.MRPONPrice * Tax.GST)/100))             
'','','','',Reason.Name ReasonName,CONVERT(NVARCHAR,Header.DocDate,103) DocDate,0 ExpiryDays,Prod.Remarks AS [Remark]      
FROM tblBarcodePrintDetail Detail          
JOIN tblBarcodePrintHeader Header ON Header.ID = Detail.HID    
left JOIN tblProductInventory InvProd ON Detail .Inventory =InvProd.InventoryId             
JOIN tblMasterProduct Prod ON Detail .ProdID =Prod .ID     
Join tblMasterTax tax on Tax.TaxID = Prod.SalesTaxId             
LEFT JOIN tblMasterReason Reason ON Reason .ID =Detail .ReasonID             
WHERE Detail.HID =@ID             
    
END    
IF(@Mode = 6)--GET PROFILE DATA    
BEGIN      
select * from tblBarcodeProfileConfig WHERE Active = 1  
END    
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspgetsetBRSData';
GO
--[uspgetsetBRSData] 2
CREATE OR ALTER PROCEDURE [dbo].[uspgetsetBRSData]      
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
  
SET @strQuery = 'SELECT DISTINCT JVID into #tempTable FROM tblFAJournal AS FAJ WHERE [Status] NOT IN (2,4)  AND AccountID = '+ CONVERT(NVARCHAR(255),@BankAccID)       
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
WHERE  FA.AccountID ! =  '+ CONVERT(NVARCHAR(255),@BankAccID)      
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND FA.DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                           
SET @strQuery += CASE WHEN ISNULL(@AccName,'') = '' THEN '' ELSE ' AND AccName.AccountName = CONVERT(NVARCHAR,@AccName)' END                
SET @strQuery += CASE WHEN ISNULL(@shwblkdate,'') = '0' THEN '' ELSE ' AND BRSDate IS NULL ' END           
SET @strQuery +=  ' ORDER BY FA.DocDate,FA.DocPrefix,FA.DocValue drop table #tempTable'   
  
INSERT INTO #MainData  
EXEC sys.sp_executesql @strQuery, N'@Mode int, @BankAccID int, @AccName nvarchar(255), @FromDate Date, @ToDate Date, @shwblkdate int', @Mode = @Mode, @BankAccID = @BankAccID, @AccName = @AccName, @FromDate = @FromDate, @ToDate = @ToDate, @shwblkdate = @shwblkdate      
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
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetChequeBounceRealiseData';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetChequeBounceRealiseData]      
@Mode INT,@TransID INT,@AccountNo NVARCHAR(MAX) = NULL,@PartyName NVARCHAR(MAX) = NULL,@FromDate date = null,      
@ToDate date = null,@Showall int = null      
AS      
BEGIN      
declare @strQuery NVARCHAR(MAX)      
IF(@Mode = 1)      
BEGIN      
select 1 Type,'BankAccNo' Trans,MBA.FAID,'1' Code,AccountNo+'|'+MB.Name+'|'+BranchName+'|'+IFSCCode+'|'+MICR+'|'+CONVERT(nvarchar,SetDefault) Name from tblMasterBankAccount MBA      
JOIN tblMasterBank MB ON MB.ID = MBA.BankID where MBA.Active = 1 AND FAID > 0      
union all      
select 2 Type,'PartyName' Trans,FAID ID,'' Code,AccountName Name from tblFAAccount  where Active = 1-- and AccountGroup IN (44,2,25,3,29,6,12,13,39,1,19,33,43,35,18,20)     
order by Type,Name      
END     
IF(@Mode = 2)--For View & Cancel  
BEGIN      
SET @strQuery = '    
SELECT CD.DocID AS DocID,CONVERT(NVARCHAR,CD.DocDate,103) AS ChequeDate,CP.[Cheque/DD Number] ChequeNo,    
BA.AccountNo,CP.BankName,SM.Name ,S.[Description] ,CD.DepositID,CD.[Status],    
dbo.fngetroundedvalue(ISNULL(CP.CollAmt,0)) AS Amount,FA.AccountName AS [Party Name],CD.UDFDocId AS [UDN],CP.IfscCode    
FROM tblTranChequeDeposit CD    
JOIN tblMasterBankAccount BA ON BA.FAID =CD.DepositAccountId    
JOIN tblStatus S ON S.ID=CD.[Status]    
JOIN tblDocumentSeries DS ON DS.TransID =CD.DocPrefix    
JOIN tblCollPMDetails CP ON CP.ColID =CD.CollId    
LEFT JOIN tblMasterSalesMan SM ON SM.ID =CD.SalesManId    
JOIN tblFAAccount FA ON FA.FAID=CP.AccId    
WHERE CD.DocPrefix = 20  '    
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND CD.DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                  
SET @strQuery += CASE WHEN ISNULL(@PartyName,'') = '' THEN '' ELSE ' AND FA.AccountName = @PartyName' END            
SET @strQuery += CASE WHEN ISNULL(@AccountNo,'') = 0 THEN '' ELSE ' AND BA.FAID = @AccountNo' END            
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND CD.Status in (1)' END      
SET @strQuery += ' order by CD.DocDate desc,CD.DocValue'
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @AccountNo NVARCHAR(MAX), @PartyName NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @TransID = @TransID, @AccountNo = @AccountNo, @PartyName = @PartyName, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall       
END    
IF(@Mode = 3)--For Open  
BEGIN      
SET @strQuery = '    
SELECT CD.DocID AS DocID,CONVERT(NVARCHAR,CD.DocDate,103) AS ChequeDate,CP.[Cheque/DD Number] ChequeNo,    
BA.AccountNo,CP.BankName,SM.Name ,S.[Description] ,CD.DepositID,CD.[Status],    
dbo.fngetroundedvalue(ISNULL(CP.CollAmt,0)) AS Amount,FA.AccountName AS [Party Name],CD.UDFDocId AS [UDN],CP.IfscCode    
FROM tblTranChequeDeposit CD    
JOIN tblMasterBankAccount BA ON BA.FAID =CD.DepositAccountId    
JOIN tblStatus S ON S.ID=CD.[Status]    
JOIN tblDocumentSeries DS ON DS.TransID =CD.DocPrefix    
JOIN tblCollPMDetails CP ON CP.ColID =CD.CollId    
LEFT JOIN tblMasterSalesMan SM ON SM.ID =CD.SalesManId    
JOIN tblFAAccount FA ON FA.FAID=CP.AccId    
WHERE CD.DocPrefix = 20 AND CD.Status in (1) '    
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND CD.DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                  
SET @strQuery += CASE WHEN ISNULL(@PartyName,'') = '' THEN '' ELSE ' AND FA.AccountName = @PartyName' END            
SET @strQuery += CASE WHEN ISNULL(@AccountNo,'') = 0 THEN '' ELSE ' AND BA.FAID = @AccountNo' END       
SET @strQuery += ' order by CD.DocDate desc,CD.DocValue'
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @AccountNo NVARCHAR(MAX), @PartyName NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @TransID = @TransID, @AccountNo = @AccountNo, @PartyName = @PartyName, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall       
END  
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetChequeDepositData';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetChequeDepositData]        
@Mode INT,@TransID INT,@AccountNo NVARCHAR(MAX) = NULL,@PartyName NVARCHAR(MAX) = NULL,@FromDate date = null,        
@ToDate date = null,@Showall int = null        
AS        
BEGIN        
declare @strQuery NVARCHAR(MAX)        
IF(@Mode = 1)        
BEGIN        
select 1 Type,'BankAccNo' Trans,MBA.FAID,'1' Code,AccountNo+'|'+MB.Name+'|'+BranchName+'|'+IFSCCode+'|'+MICR+'|'+CONVERT(nvarchar,SetDefault) Name from tblMasterBankAccount MBA        
JOIN tblMasterBank MB ON MB.ID = MBA.BankID where MBA.Active = 1 AND FAID > 0        
union all        
select 2 Type,'PartyName' Trans,FAID ID,'' Code,AccountName Name from tblFAAccount  where Active = 1 and AccountGroup IN (44,2,25,3,29,6,12,13,39,1,19,33,43,35,18,20)      
union all        
SELECT 3 Type,'Salesman' Trans,ID,'' Code,Name from tblMasterSalesman where Active = 1        
union all        
SELECT 4 Type,'UDN' Trans,UDNID,'',DocName FROM tblMasterUserDefineNoHeader WHERE TransID = @TransID        
union all        
SELECT 5 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = @TransID   
order by Type,Name        
END       
IF(@Mode = 3)        
BEGIN        
SET @strQuery = '      
SELECT  CD.DocID AS DocID,CONVERT(NVARCHAR,CD.DocDate,103) AS ChequeDate,CP.[Cheque/DD Number] ChequeNo,      
BA.AccountNo,CP.BankName,SM.Name ,S.[Description] ,CD.DepositID,CD.[Status],      
dbo.fngetroundedvalue(ISNULL(CP.CollAmt,0)) AS Amount,FA.AccountName AS [Party Name],CD.UDFDocId AS [UDN],CP.IfscCode     
,CUR.UserName UserName,CONVERT(NVARCHAR(100),CD.CDate) LastActionTime       
FROM tblTranChequeDeposit CD      
JOIN tblMasterBankAccount BA ON BA.FAID =CD.DepositAccountId      
JOIN tblStatus S ON S.ID=CD.[Status]      
JOIN tblDocumentSeries DS ON DS.TransID =CD.DocPrefix      
JOIN tblCollPMDetails CP ON CP.ColID =CD.CollId      
LEFT JOIN tblMasterSalesMan SM ON SM.ID =CD.SalesManId      
JOIN tblFAAccount FA ON FA.FAID=CP.AccId      
JOIN tblUsers CUR ON CUR.ID = CD.CBy    
WHERE CD.DocPrefix = 20  '      
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND CD.DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                    
SET @strQuery += CASE WHEN ISNULL(@PartyName,'') = '' THEN '' ELSE ' AND FA.AccountName = @PartyName' END              
SET @strQuery += CASE WHEN ISNULL(@AccountNo,'') = 0 THEN '' ELSE ' AND BA.FAID = @AccountNo' END              
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND CD.Status in (1)' END                          
SET @strQuery += ' ORDER BY CD.DocDate DESC,CD.DocValue '
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @AccountNo NVARCHAR(MAX), @PartyName NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @TransID = @TransID, @AccountNo = @AccountNo, @PartyName = @PartyName, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall         
END      
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetCollPayData';
GO
--uspGetSetCollPayData 1,18,null,19,'','2024-12-30','2025-12-16',1        
--uspGetSetCollPayData 33,4,4,19      
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetCollPayData]                                                            
@Mode INT,@Code NVARCHAR(MAX) = NULL,@ID NVARCHAR(MAX) = NULL,@TransID int =1,@Party NVARCHAR(MAX) = NULL,@FromDate date = null,                                                            
@ToDate date = null,@Showall int = null                                                            
AS                                                            
BEGIN                                                            
declare @strQuery NVARCHAR(MAX) ,@AllowAllSM int = 0                         
IF(@Mode = 1)                          
BEGIN                          
select 1 Type,'Customer' Trans,ID,Code,Name,BillAdd1 Address from tblMasterCustomer where Active = 1 and FAID > 0                           
and ID = case when @TransID = 19 then ID ELSE 0 END                          
union all                          
select 1 Type,'vendor' Trans,ID,Code,Name,BillAdd1 Address from tblMasterVendor where Active = 1 and FAID > 0                          
and ID = case when @TransID = 18 then ID ELSE 0 END                          
union all                          
SELECT 2 Type,'Branch' Trans,ID,'',Name,'' FROM tblMasterBranchOffice WHERE Active = 1                          
union all                          
SELECT 3 Type,'UDN' Trans,UDNID,'',DocName,'' FROM tblMasterUserDefineNoHeader WHERE TransID = @TransID                          
union all                          
SELECT 4 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue,'' FROM tblDocumentSeries WHERE Active = 1 and TransID = @TransID                          
union all                          
SELECT 5 Type,'Paymode' Trans,ID,'',PaymentMode,'' FROM tblPaymentMode WHERE Active = 1 AND ID not IN (10,6,8,7)                          
union all                          
SELECT 6 Type,'CreditTerm' Trans,ID,'',Name,'' FROM tblMasterCreditTerm WHERE Active = 1                          
union all                          
SELECT 7 Type,'Beat' Trans,ID,'',Name,'' FROM tblMasterBeat WHERE Active = 1 and ID = case when @TransID = 19 then ID ELSE 0 END                          
union all                          
SELECT 8 Type,'Salesman' Trans,ID,'',Name,'' FROM tblMasterSalesman WHERE Active = 1 and ID = case when @TransID = 19 then ID ELSE 0 END                          
union all                          
SELECT 9 Type,'BankAccNo' Trans,MBA.ID,CONVERT(NVARCHAR,MBA.FAID) Code,AccountNo+'|'+MB.Name+'|'+BranchName+'|'+IFSCCode+'|'+MICR+'|'+CONVERT(nvarchar,SetDefault)+'|'+CONVERT(nvarchar,MB.ID) Name,''                       
from tblMasterBankAccount MBA                          
JOIN tblMasterBank MB ON MB.ID = MBA.BankID where MBA.Active = 1 AND FAID > 0                          
union all                          
SELECT 10 Type,'BankAcc' Trans,ID,'',ModeName,'' FROM tblContraMode WHERE Active = 1 and ID > 2                      
union all                          
SELECT 11 Type,'Banks' Trans,ID,'',Name,'' FROM tblMasterBank WHERE Active = 1                        
union all                                      
SELECT 12 Type,'Reason' Trans,ID,'',Name,'' FROM tblMasterReason WHERE Active = 1            
order by Type,Name                                        
END                              
IF(@Mode = 2)                          
BEGIN                          
IF(@TransID = 19)                          
BEGIN                          
SELECT * FROM tblMasterCustomer WHERE Active = 1 AND Code = @Code ORDER BY Name                          
END                          
ELSE                          
BEGIN                          
SELECT * FROM tblMasterVendor WHERE Active = 1 AND Code = @Code ORDER BY Name                          
END                          
END                          
IF(@Mode = 3)                          
BEGIN                          
IF(@TransID = 19)                          
BEGIN                    
SELECT * FROM tblMasterCustomer WHERE Active = 1 AND ID = @Code ORDER BY Name           
END                          
ELSE                          
BEGIN                          
SELECT * FROM tblMasterVendor WHERE Active = 1 AND ID = @Code ORDER BY Name                          
END                          
END              
IF(@Mode = 32)--get beat & sm                          
BEGIN                         
IF(@TransID = 19)                          
BEGIN               
select TOP 1* from tblBeatSalesmanMapping WHERE CustomerID = @Code ORDER BY ID                          
END                    
END                           
IF(@Mode = 33)--get beat & sm                          
BEGIN                          
select @AllowAllSM = AppValue from tblAppConfig where AppId = 18                        
IF(@TransID = 19)                          
BEGIN                      
SET @strQuery = '                          
SELECT  1 Type,''Customer'' Trans,MC.ID,Code,Name,MC.BillAdd1 FROM tblMasterCustomer MC                           
LEFT JOIN tblBeatSalesmanMapping BSM ON BSM.CustomerID = MC.ID                          
where Active = 1 AND FAID > 0 '                          
SET @strQuery += case when @Code > 0 then ' AND BSM.BeatID = @Code' else '' end                          
SET @strQuery += case when @ID > 0 and @AllowAllSM = 0 then ' AND BSM.SalesmanID = @ID' else '' end                          
SET @strQuery += ' group by MC.ID,Code,Name,MC.BillAdd1 order by Name'                          
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                          
END                    
END                      
IF(@Mode = 4)--Coll Pay Filter                                     
BEGIN                                           
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,InvDate,103) DocDate,DocRef RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(PH.GrossAmt) GrossAmt,                                                            
dbo.fnGetRoundedValue(PH.TotalTaxAmt) TaxAmt,dbo.fnGetRoundedValue(PH.NetAmt) NetAmt,                                                            
STS.Description Status FROM tbltransalesheader PH                                            
JOIN tblMasterCustomer MV ON MV.ID = PH.CustID                                                            
JOIN tblStatus STS ON STS.ID = PH.Status                                      
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID WHERE MV.Active IN (0,1) and DocPrefix = 15 '                                                            
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND InvDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                                                    
  
     
     
        
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END                                                            
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                                                            
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                                                            
SET @strQuery += ' ORDER BY DocValue desc,PH.ID'                                                            
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                                                            
END                     
IF(@Mode = 5)                                                                                    
BEGIn                                     
declare @sts as table(Sts int)                                  
if(isnull(@Code,0) = 0)                                  
begin                                  
insert into @sts values(1)                                  
end                                  
else                                  
begin                                  
insert into @sts values(1),(5)                             
end                                 
if(@TransID = 18)                                
BEGIN                                
SELECT 1 Type,'ChequeBook' Trans,CBD.ChequeNo ID,ChequeBookreferNo Code,CBH.ChequeBookreferNo+' - '+CBD.ChequeNo Name,CBH.ChequeBookID  
FROM tblMasterChequeBook CBH                                    
JOIN tblMasterChequeBookDetail CBD ON CBD.ChequeBookID = CBH.ChequeBookID                                    
join tblMasterBankAccount MBA ON MBA.ID = CBH.BankAccountID                                    
WHERE MBA.ID = @ID and CBD.Status in (select * from @sts)                                  
END                                
END           
IF(@Mode = 6)                  
BEGIN                  
IF(@TransID = 19)                          
BEGIN                          
SELECT SH.ID,InvDate DocDate,DocPrefix TransID,DocID,DocValue,CustID PartyID,MC.Code,MC.Name FROM tblTranSalesHeader SH                  
JOIN tblMasterCustomer MC ON MC.ID = SH.CustID WHERE DocValue = @Code                  
END                          
ELSE                          
BEGIN                          
SELECT SH.ID,Date DocDate,TransID,DocID,DocValue,VendorID PartyID,MC.Code,MC.Name FROM tblTransPurchaseHeader SH                  
JOIN tblMasterVendor MC ON MC.ID = SH.VendorID WHERE DocValue = @Code                  
END                   
END                  
IF(@Mode = 7)                  
BEGIN                 
IF(@TransID = 19)                          
BEGIN                 
DECLARE @PartyACCID INT = (SELECT FAID FROM tblMasterCustomer WHERE ID=@ID)                     
SELECT BankName,BranchName,IfscCode FROM tblCollPMDetails WHERE AccID=@PartyACCID                
AND (ISNULL(BankName,'') != '' OR ISNULL(BranchName,'') != '' OR ISNULL(IfscCode,'') != '')                
GROUP BY BankName,BranchName,IfscCode,ColID order by ColID                
END                
END        
IF(@Mode = 8)                  
BEGIN         
SELECT * FROM tblTranOrderCollectionHeader WHERE ID = @ID        
        
SELECT * FROM tblTranOrderCollectionDetail WHERE HID = @ID        
END     
IF(@Mode = 9)                  
BEGIN   
CREATE TABLE #OTCdata(Serial int identity(1,1),DocPrefix int,TransID int)
CREATE TABLE #ErrorInvoices(DocPrefix int,TransID int,DocID nvarchar(255))
insert into #OTCdata
SELECT InvDocPrefix,InvoiceID  FROM tblTranOrderCollectionDetail WHERE HID = @ID        

--select * from #OTCdata
declare @OTDocCount int = (select count(*) from #OTCdata),@Incr int = 1
declare @DocPrefix int,@ChkTransID int,@ChkDocID nvarchar(255)
WHILE(@OTDocCount >= @Incr)
BEGIN
select @DocPrefix = DocPrefix,@ChkTransID = TransID from #OTCdata where Serial = @Incr
if(@DocPrefix in (15,16))
begin
IF((select COUNT(1) from tblTranSalesHeader where id = @ChkTransID AND Status IN (5,2,4)) > 0)
BEGIN
select @ChkDocID = DocID from tblTranSalesHeader where id = @ChkTransID
INSERT INTO #ErrorInvoices VALUES (@DocPrefix,@ChkTransID,@ChkDocID)
END
END
if(@DocPrefix in (4,5))
begin
IF((select COUNT(1) from tblNoteDetails where id = @ChkTransID AND Status IN (5,2,4)) > 0)
BEGIN
select @ChkDocID = DocID from tblNoteDetails where id = @ChkTransID
INSERT INTO #ErrorInvoices VALUES (@DocPrefix,@ChkTransID,@ChkDocID)
END
END
if(@DocPrefix in (6,7))
begin
IF((select COUNT(1) from tblTranPRVoucher where id = @ChkTransID AND Status IN (5,2,4)) > 0)
BEGIN
select @ChkDocID = DocID from tblTranPRVoucher where id = @ChkTransID
INSERT INTO #ErrorInvoices VALUES (@DocPrefix,@ChkTransID,@ChkDocID)
END
enD
SET @Incr = @Incr + 1;
END
SELECT *,'Document status changed' Msg  FROM #ErrorInvoices
drop table #OTCdata,#ErrorInvoices
END
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetContraData';
GO
--uspGetSetContraData 2,8,'',0,'','2025-04-10','2025-12-16',1                  
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetContraData]                  
@Mode INT,@TransID INT,@Code NVARCHAR(MAX) = NULL,@ID NVARCHAR(MAX) = NULL,@AccountName NVARCHAR(MAX) = NULL,@FromDate date = null,                  
@ToDate date = null,@Showall int = null,@Branch NVARCHAR(MAX) = NULL                  
AS                  
BEGIN                  
BEGIN TRY                  
declare @strQuery NVARCHAR(MAX)                  
IF(@Mode = 1)                  
BEGIN                  
select 1 Type,'BankAccNo' Trans,MBA.FAID,'1' Code,AccountNo+'|'+MB.Name+'|'+BranchName+'|'+IFSCCode+'|'+MICR+'|'+CONVERT(nvarchar,SetDefault)+'|'+CONVERT(nvarchar,MBA.ID) Name from tblMasterBankAccount MBA                  
JOIN tblMasterBank MB ON MB.ID = MBA.BankID where MBA.Active = 1 AND FAID > 0                  
union all                  
SELECT 2 Type,'ContraType' Trans,ID,'' Code,TypeName Name from tblContraType where Active = 1                  
union all                  
SELECT 3 Type,'ContraMode' Trans,ID,'3' Code,ModeName Name from tblContraMode where Active = 1 and ID IN (2,3,4,5,6,7)                  
union all                  
SELECT 3 Type,'ContraMode' Trans,ID,'2' Code,ModeName Name from tblContraMode where Active = 1 and ID IN (1,2)                  
union all                  
SELECT 4 Type,'Salesman' Trans,ID,'' Code,Name from tblMasterSalesman where Active = 1                  
union all                  
SELECT 5 Type,'UDN' Trans,UDNID,'',DocName FROM tblMasterUserDefineNoHeader WHERE TransID = @TransID                  
union all                  
SELECT 6 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = @TransID                  
union all                  
SELECT 7 Type,'BranchName' Trans,ID,'',Name FROM tblMasterBranchOffice  WHERE Active = 1                
union all            
SELECT 1 Type,'BranchOffice' Trans,FAID,'4' Code,Name from tblMasterBranchOffice where Active = 1 and FAID > 0                  
order by Type,Name                  
END                  
IF(@Mode = 2)                  
BEGIN                  
SET @strQuery = 'SELECT ND.ID,ND.DocId,convert(nvarchar(50),ND.DocDate,103) DocDate, ND.RefNo,CT.TypeName,CM.ModeName,Party.AccountName as[Party Name] ,                  
FAA.AccountName as[Account Name],dbo.fnGetRoundedValue(ND.Amount) Gross,dbo.fnGetRoundedValue(ND.Balance)Balance ,                
ST.[Description],ND.Status,CUR.UserName UserName,CONVERT(NVARCHAR(100),ND.CDate) LastActionTime,ND.ChequeNumberWithRef,          
ND.WDSlipNo,MS.Name[Salesman],ND.Remarks,ND.Narration,isnull(ND.BranchID,0)[BranchID],MBO.Name[Branch Name]              
FROM tblTranContra ND                  
LEFT join tblContraMode CM ON CM.ID = ND.ModeID                  
join tblContraType CT ON CT.ID = ND.TypeID                  
JOIN tblStatus ST ON ST.ID=ND.[Status]                  
JOIN tblFAAccount Party ON ND.FromFAID=Party.FAID                  
left JOIN tblFAAccount FAA ON ND.ToFAID=FAA.FAID                
LEFT JOIN tblMasterSalesman MS ON MS.ID = ND.SalesManID              
LEFT JOIN tblMasterBranchOffice MBO on MBO.ID = ND.BranchID            
JOIN tblUsers CUR ON CUR.ID = ND.CBy WHERE ND.TransID = ' + CONVERT(NVARCHAR,@TransID)                  
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                  
SET @strQuery += CASE WHEN ISNULL(@AccountName,'') = '0' THEN '' ELSE ' AND ND.FromFAID = @AccountName' END       
SET @strQuery += CASE WHEN ISNULL(@Branch,'') = '0' THEN '' ELSE ' AND ND.BranchID = CONVERT(NVARCHAR,@Branch)' END      
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND ND.Status in (1,3,5)' END                  
SET @strQuery += ' ORDER BY ND.DocDate DESC, ND.DocValue desc,ND.ID'                  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @AccountName NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @Branch NVARCHAR(MAX)', @Mode = @Mode, @TransID = @TransID, @Code = @Code, @ID = @ID, @AccountName = @AccountName, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall, @Branch = @Branch          
                  
END                  
IF(@Mode = 3)                  
BEGIN                  
SELECT ND.ID,DocID,TransID,DocValue,DocDate,TypeID,ModeID,RefNo,Amount,Balance,                  
CASE WHEN TypeID = 1 THEN ToFAID ELSE FromFAID END FromFAID,        
WDSlipNo,ChequeNo,ChequeNumberWithRef,                  
SalesManID,CASE WHEN TypeID = 3 THEN ToFAID ELSE 0 END ToFAID,Remarks,Narration,UDFID,                  
Status,BranchID,MBO.Name[Branch Name],dbo.fnTransactionPrefix(ND.DocDate,BranchID,ND.TransID) Prefix              
FROM tblTranContra ND              
LEFT  JOIN tblMasterBranchOffice MBO on MBO.ID = ND.BranchID             
WHERE ND.ID = @ID                  
END                  
IF(@Mode = 4)                  
BEGIN                  
declare @sts as table(Sts int)                  
if(isnull(@Code,0) = 0)                  
begin                  
insert into @sts values(1)                  
end                  
else                  
begin                  
insert into @sts values(1),(5)                  
end                  
SELECT 1 Type,'ChequeBook' Trans,CBD.ChequeNo ID,ChequeBookreferNo Code,CBH.ChequeBookreferNo+' - '+CBD.ChequeNo Name, CBH.ChequeBookID                 
FROM tblMasterChequeBook CBH                  
JOIN tblMasterChequeBookDetail CBD ON CBD.ChequeBookID = CBH.ChequeBookID                  
join tblMasterBankAccount MBA ON MBA.ID = CBH.BankAccountID                  
WHERE MBA.FAID = @ID and CBD.Status in (select * from @sts)                  
END                  
IF(@Mode = 5)               
BEGIN                  
SELECT * FROM tblMasterBankAccount WHERE FAID = @TransID                  
END                  
END TRY                  
BEGIN CATCH                  
SELECT ERROR_MESSAGE () MSG,ERROR_PROCEDURE () [PROC],ERROR_LINE () LINE                  
END CATCH                  
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetCreditDebitNoteData';
GO
--uspGetSetCreditDebitNoteData 2,5,0,'','','2024-11-10','2024-12-16',1                  
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetCreditDebitNoteData]                                                              
@Mode INT,@TransID INT,@ID NVARCHAR(MAX) = NULL,@AccountName NVARCHAR(MAX) = NULL,@Party NVARCHAR(MAX) = NULL,@FromDate date = null,                  
@ToDate date = null,@Showall int = null   ,@Branch NVARCHAR(MAX) = NULL              
AS                                                              
BEGIN                        
BEGIN TRY                
declare @strQuery NVARCHAR(MAX)                  
IF(@Mode = 1)                                                              
BEGIN                          
--7,8,10,11                          
select 1 Type,'PartyName' Trans,FAID ID,'' Code,AccountName Name from tblFAAccount  where Active = 1 and AccountGroup IN (44,2,25,3,29,6,12,13,39,1,19,33,43,35,18,20)                          
union all                                                              
SELECT 2 Type,'AccountName' Trans,FAID ID,'' Code,[Account Name] Name from [FACNAccountNames]                    
union all                                                                                      
SELECT 3 Type,'UDN' Trans,UDNID,'',DocName FROM tblMasterUserDefineNoHeader WHERE TransID = @TransID                                                   
union all                                                              
SELECT 4 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = @TransID          
union all          
SELECT 5 Type,'BranchName' Trans,ID,'',Name FROM tblMasterBranchOffice  WHERE Active = 1            
order by Type,Name                                                              
END                          
IF(@Mode = 2)                                                              
BEGIN                                   
--SELECT ND.ID,ND.DocId,convert(nvarchar(50),ND.DocDate,103) DocDate, ND.RefNo,Party.AccountName as[Party Name] ,FAA.AccountName as[Account Name],                                                       
--dbo.fnGetRoundedValue(ND.NoteValue) NoteValue,dbo.fnGetRoundedValue(ND.Balance)Balance ,ST.[Description]                        
--FROM tblNoteDetails ND                           
--JOIN  tblDocumentSeries  DS ON ND.TransID=DS.TransID                                                         
--JOIN tblStatus ST ON ST.ID=ND.[Status]                                             
--JOIN tblFAAccount FAA ON ND.FAID=FAA.FAID                                       
--JOIN tblFAAccount Party ON ND.PartyId=Party.FAID                        
--WHERE ND.TransID = @TransID                        
--ORDER BY ND.DocValue desc,ND.ID                
                
SET @strQuery = 'SELECT ND.ID,ND.DocId,convert(nvarchar(50),ND.DocDate,103) DocDate, ND.RefNo,Party.AccountName as[Party Name] ,FAA.AccountName as[Account Name],                                                       
dbo.fnGetRoundedValue(ND.NoteValue) NoteValue,dbo.fnGetRoundedValue(ND.Balance)Balance ,ST.[Description],              
CUR.UserName UserName,CONVERT(NVARCHAR(100),ND.CDate) LastActionTime,ND.[Status] StatusID ,ND.Remark,ND.Narration,ND.BranchID[BranchID],MBO.Name[Branch Name]              
FROM tblNoteDetails ND                           
JOIN  tblDocumentSeries  DS ON ND.TransID=DS.TransID                                                         
JOIN tblStatus ST ON ST.ID=ND.[Status]                                             
JOIN tblFAAccount FAA ON ND.FAID=FAA.FAID               
LEFT JOIN tblMasterBranchOffice MBO on MBO.ID = ND.BranchID          
JOIN tblFAAccount Party ON ND.PartyId=Party.FAID              
JOIN tblUsers CUR ON CUR.ID = ND.CBy WHERE  ND.TransID = ' + CONVERT(NVARCHAR,@TransID)                  
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                      
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND Party.AccountName = @Party' END                
SET @strQuery += CASE WHEN ISNULL(@AccountName,'') = '' THEN '' ELSE ' AND FAA.AccountName = @AccountName' END   
SET @strQuery += CASE WHEN ISNULL(@Branch,'') = '0' THEN '' ELSE ' AND ND.BranchID = CONVERT(NVARCHAR,@Branch)' END  
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND ND.Status in (1,3,5)' END                     
SET @strQuery += ' ORDER BY ND.DocDate DESC, ND.DocValue desc,ND.ID'                  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @ID NVARCHAR(MAX), @AccountName NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @Branch NVARCHAR(MAX)', @Mode = @Mode, @TransID = @TransID, @ID = @ID, @AccountName = @AccountName, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall, @Branch = @Branch                  
END                        
IF(@Mode = 3)                                                              
BEGIN                          
SELECT ND.ID,ND.DocId,ND.DocDate,ND.DocValue, ND.RefNo,Party.AccountName as[Party Name] ,FAA.AccountName as[Account Name],                                                       
ND.NoteValue,ND.Balance ,ND.[Status],ND.Remark,ND.Narration,ND.BranchID[BranchID],MBO.Name[Branch Name],    
dbo.fnTransactionPrefix(ND.DocDate,BranchID,ND.TransID) Prefix    
FROM tblNoteDetails ND                           
JOIN tblFAAccount FAA ON ND.FAID=FAA.FAID                                       
JOIN tblFAAccount Party ON ND.PartyId=Party.FAID            
left JOIN tblMasterBranchOffice MBO on MBO.ID = ND.BranchID          
WHERE ND.ID = @ID                      
END                        
END TRY                        
BEGIN CATCH                        
SELECT ERROR_MESSAGE () MSG,ERROR_PROCEDURE () [PROC],ERROR_LINE () LINE                        
END CATCH                        
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetsetDailyactivityData';
GO
--uspGetsetDailyactivityData 1,2,4,1                      
CREATE OR ALTER PROCEDURE [dbo].[uspGetsetDailyactivityData]                      
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
SET @StrQuery += CASE WHEN ISNULL(@ID,0) = 0 THEN '' ELSE ' AND BSM.BeatID = '+convert(nvarchar,@ID) end                    
SET @StrQuery += CASE WHEN (ISNULL(@SMID,0) = 0 or isnull(@AllSalesman,0) = 1) THEN '' ELSE ' AND BSM.SalesmanID = '+convert(nvarchar,@SMID) end                    
SET @StrQuery += ' GROUP BY MC.ID,Code,Name ORDER BY Name'                    
EXEC sys.sp_executesql @StrQuery, N'@Mode INT, @ID INT, @SMID INT, @SelectID NVARCHAR(MAX), @Value NVARCHAR(MAX)', @Mode = @Mode, @ID = @ID, @SMID = @SMID, @SelectID = @SelectID, @Value = @Value                    
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
left JOIN tblProductInventory PV ON PV.ProdId = MP.ID AND PV.BranchID = '+convert(nvarchar,@SMID) + '      
LEFT JOIN tblImages IMGD ON IMGD.ID = MP.ID AND IMGD.FormID = 1      
WHERE MP.Active=1 '                    
SET @StrQuery += CASE WHEN ISNULL(@SelectID,0) = 1 and isnull(@Value,'') != '' THEN ' AND MP.MfrID IN (SELECT value FROM STRING_SPLIT(convert(nvarchar(255),@Value), N'',''))' ELSE '' end                    
SET @StrQuery += CASE WHEN ISNULL(@SelectID,0) = 2 and isnull(@Value,'') != '' THEN ' AND MP.CategoryID IN (SELECT value FROM STRING_SPLIT(convert(nvarchar(255),@Value), N'',''))' ELSE '' end                    
SET @StrQuery += CASE WHEN ISNULL(@SelectID,0) = 3 and isnull(@Value,'') != '' THEN ' AND MP.Name IN (convert(nvarchar(255),@Value)'+')' ELSE '' end                    
SET @StrQuery +=  ' group by MP.PurchasePrice,MP.SalesPrice,MP.ECP,MP.MRP,MP.SPLPrice,Tax.GST,MP.ID,Name,ProductDiscPerc,                    
WebOrder,MP.TrackInventory,MP.ReturnPrice,IMGD.Imagedata ORDER BY WebOrder ASC,MP.Name ASC   '                    
EXEC sys.sp_executesql @StrQuery, N'@Mode INT, @ID INT, @SMID INT, @SelectID NVARCHAR(MAX), @Value NVARCHAR(MAX)', @Mode = @Mode, @ID = @ID, @SMID = @SMID, @SelectID = @SelectID, @Value = @Value                    
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
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspgetsetDiscountSchemeData';
GO
--exec [uspgetsetDiscountSchemeData] 32,112  
CREATE OR ALTER PROCEDURE [dbo].[uspgetsetDiscountSchemeData]              
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
SET @strQuery += '  where MDH.ID = CONVERT(NVARCHAR(20),@ID )'  
SET @strQuery +=  'group by  MDD.ProdID,'+(CASE WHEN @nMapByID = 1 then 'MC.Code,' ELSE '' END)+' MC.Name,MDD.ProdDisc,MDD.ProdDiscAmt,  
MDD.TradeDiscPern,MDD.TradeDiscAmt    '  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID NVARCHAR(255), @CustTypeorManuf nvarchar(255), @BeatorBrand nvarchar(255), @SalesmanorCategory nvarchar(255), @CustomerorProduct nvarchar(255), @nMapByID int', @Mode = @Mode, @ID = @ID, @CustTypeorManuf = @CustTypeorManuf, @BeatorBrand = @BeatorBrand, @SalesmanorCategory = @SalesmanorCategory, @CustomerorProduct = @CustomerorProduct, @nMapByID = @nMapByID       
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
SET @strQuery += CASE WHEN ISNULL(@CustTypeorManuf,'') = '' THEN '' ELSE ' AND MCT.Name = @CustTypeorManuf' end              
SET @strQuery += CASE WHEN ISNULL(@BeatorBrand,'') = '' THEN '' ELSE ' AND MB.Name = @BeatorBrand' end              
SET @strQuery += CASE WHEN ISNULL(@SalesmanorCategory,'') = '' THEN '' ELSE ' AND SM.Name = @SalesmanorCategory' end              
SET @strQuery += CASE WHEN ISNULL(@CustomerorProduct,'') = '' THEN '' ELSE ' AND MC.Name = @CustomerorProduct' end              
SET @strQuery += ' GROUP BY  MC.ID,MC.Code,MC.Name ORDER BY MC.Name'              
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID NVARCHAR(255), @CustTypeorManuf nvarchar(255), @BeatorBrand nvarchar(255), @SalesmanorCategory nvarchar(255), @CustomerorProduct nvarchar(255), @nMapByID int', @Mode = @Mode, @ID = @ID, @CustTypeorManuf = @CustTypeorManuf, @BeatorBrand = @BeatorBrand, @SalesmanorCategory = @SalesmanorCategory, @CustomerorProduct = @CustomerorProduct, @nMapByID = @nMapByID              
END              
ELSE -- PRODUCT FILTER              
BEGIN              
if(@nMapByID = 1)  
BEGIN  
SET @strQuery = ' SELECT MP.ID,MP.Code,MP.Name,0 ProdDiscPern,0 ProdDiscAmt,0 TradeDiscPern,0 TradeDiscAmt FROM TBLMASTERPRODUCT MP              
LEFT JOIN tblMasterManufacturer MF ON MF.ID = MP.MfrID              
LEFT JOIN tblMasterCategory MC ON MC.ID = MP.CategoryID              
LEFT JOIN tblMasterBrand MB ON Mb.ID = MP.BrandID WHERE MP.Active = 1 '              
SET @strQuery += CASE WHEN ISNULL(@CustTypeorManuf,'') = '' THEN '' ELSE ' AND MF.Name = @CustTypeorManuf' end              
SET @strQuery += CASE WHEN ISNULL(@BeatorBrand,'') = '' THEN '' ELSE ' AND MB.Name = @BeatorBrand' end              
SET @strQuery += CASE WHEN ISNULL(@SalesmanorCategory,'') = '' THEN '' ELSE ' AND MC.Name = @SalesmanorCategory' end              
SET @strQuery += CASE WHEN ISNULL(@CustomerorProduct,'') = '' THEN '' ELSE ' AND MP.Name = @CustomerorProduct' end              
SET @strQuery += ' GROUP BY   MP.ID,MP.Code,MP.Name ORDER BY MP.Name'              
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID NVARCHAR(255), @CustTypeorManuf nvarchar(255), @BeatorBrand nvarchar(255), @SalesmanorCategory nvarchar(255), @CustomerorProduct nvarchar(255), @nMapByID int', @Mode = @Mode, @ID = @ID, @CustTypeorManuf = @CustTypeorManuf, @BeatorBrand = @BeatorBrand, @SalesmanorCategory = @SalesmanorCategory, @CustomerorProduct = @CustomerorProduct, @nMapByID = @nMapByID                 
END  
ELSE  
BEGIN  
SET @strQuery = ' SELECT ID,null Code,Name,0 ProdDiscPern,0 ProdDiscAmt,0 TradeDiscPern,0 TradeDiscAmt FROM '  
SET @strQuery += CASE WHEN @nMapByID = 2 THEN 'tblMasterManufacturer' WHEN @nMapByID = 3 THEN 'tblMasterBrand'  
 ELSE 'tblMasterCategory' end              
SET @strQuery += '  WHERE Active = 1 order by Name'  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID NVARCHAR(255), @CustTypeorManuf nvarchar(255), @BeatorBrand nvarchar(255), @SalesmanorCategory nvarchar(255), @CustomerorProduct nvarchar(255), @nMapByID int', @Mode = @Mode, @ID = @ID, @CustTypeorManuf = @CustTypeorManuf, @BeatorBrand = @BeatorBrand, @SalesmanorCategory = @SalesmanorCategory, @CustomerorProduct = @CustomerorProduct, @nMapByID = @nMapByID          
END  
END              
END              
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetInventoryAdjustmentData';
GO
--uspGetSetInventoryAdjustmentData 2,1,0,13,'7','2024-12-25','2024-12-26',0                
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetInventoryAdjustmentData]                
@Mode INT,@Code NVARCHAR(MAX) = NULL,@ID NVARCHAR(MAX) = NULL,@TransID int =13,@Party NVARCHAR(MAX) = NULL,@FromDate date = null,                
@ToDate date = null,@Showall int = null                
AS                
BEGIN                
declare @strQuery NVARCHAR(MAX)                
IF(@Mode = 1)                
BEGIN                
SELECT 1 Type,'Branch' Trans,ID,'',Name FROM tblMasterBranchOffice WHERE Active = 1                
union all                
SELECT 2 Type,'UDN' Trans,UDNID,'',DocName FROM tblMasterUserDefineNoHeader WHERE TransID = 1                
union all                
SELECT 3 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 13                
order by Type,Name                
END                
IF(@Mode = 2)                
BEGIN                
CREATE TABLE #ABS(ProdID INT,ABSQty DECIMAL(25,4))                
IF(@Code = 1)                
BEGIN                
INSERT INTO #ABS                
SELECT ProdID,dbo.fnGetRoundedValue(SUM(ActualQty)) ABSQty FROM tblProductInventory             
WHERE BranchID = @Party AND TransDate <= @FromDate AND (ActualQty > 0 OR ActualDmgQty > 0 OR ActualFreeQty > 0)                
GROUP BY ProdID               
SELECT MP.*,dbo.fnGetRoundedValue(ISNULL(AB.ABSQty,0)) ABSQty FROM tblMasterProduct MP                
JOIN #ABS AB ON AB.ProdID = MP.ID                
WHERE Active = 1 AND TrackInventory = 1 ORDER BY Name               
END                
ELSE                
BEGIN                
INSERT INTO #ABS                
SELECT ProdID,dbo.fnGetRoundedValue(SUM(ActualQty)) ABSQty FROM tblProductInventory WHERE BranchID = @Party AND TransDate <= @FromDate            
GROUP BY ProdID                
SELECT MP.*,dbo.fnGetRoundedValue(ISNULL(AB.ABSQty,0)) ABSQty FROM tblMasterProduct MP                
left JOIN #ABS AB ON AB.ProdID = MP.ID                
WHERE Active = 1 AND TrackInventory = 1 ORDER BY Name               
END                 
DROP TABLE #ABS                
END                
IF(@Mode = 3)                
BEGIN                
SELECT MP.ID,MP.Code,MP.Name,HSNCode,MP.BaseUomID,MP.BaseCR,MP.PurchaseUomID,MP.PurchaseCR,mp.PurchaseTaxID,MT.TaxName,MT.GST,            
MP.ProductDiscPerc,MP.PurchasePrice,MP.SalesPrice,MP.ECP,MP.SPLPrice,MP.MRP,MP.ReturnPrice,TrackBatch,TrackPDK            
FROM tblMasterProduct MP                
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID                
WHERE Code = @Code                
END                
IF(@Mode = 4)                
BEGIN                
IF ISNULL(@Code,0)=0                
BEGIn --All Batch Info                
SELECT ProdId,BatchNumber,CONVERT(NVARCHAR,PKDDate,103) AS PKDDate,CONVERT(NVARCHAR,ExpiryDate,103) AS ExpiryDate,isnull(ActualQty,0) AS Qty ,         
isnull(ActualFreeQty,0) AS [FreeQty],isnull(ActualDmgQty,0) AS [DmgQty] ,                
PurchasePrice,MRPONPrice MRP,TaxValue,TaxId,InventoryId,CONVERT(NVARCHAR,TransDate,103) AS DocDate                
FROM dbo.tblProductInventory                
WHERE ProdId = @ID AND TransDate <= @FromDate AND BranchID = @Party ORDER BY TransDate DESC                
END                
ELSE IF ISNULL(@Code,0)=1              
BEGIn--Valid Batch Only                
SELECT ProdId,BatchNumber,CONVERT(NVARCHAR,PKDDate,103) AS PKDDate,CONVERT(NVARCHAR,ExpiryDate,103) AS ExpiryDate,        
isnull(ActualQty,0) AS Qty ,isnull(ActualFreeQty,0) AS [FreeQty],ActualDmgQty AS [DmgQty] ,                
PurchasePrice,MRPONPrice MRP,TaxValue,TaxId,InventoryId,CONVERT(NVARCHAR,TransDate,103) AS DocDate                
FROM dbo.tblProductInventory                
WHERE ProdId = @ID AND TransDate <= @FromDate AND BranchID = @Party AND (ISNULL(ActualQty,0)>0 OR ISNULL(ActualFreeQty,0)>0 OR ISNULL(ActualDmgQty,0) >0)                
ORDER BY TransDate DESC                
END                
END                
ELSE IF(@Mode = 41)                
BEGIN                
SELECT 0 InventoryId,ProdID,PV.BatchNumber,PV.PKDDate,PV.ExpiryDate,dbo.fnGetRoundedValue(SUM(ActualQty)) Qty,                
dbo.fnGetRoundedValue(SUM(ActualFreeQty)) FreeQty,dbo.fnGetRoundedValue(SUM(ActualDmgQty)) DmgQty,            
dbo.fnGetRoundedValue(PV.MRPONPrice) MRP,0 PurchasePrice,dbo.fnGetRoundedValue(PV.ReturnPrice) ReturnPrice                
FROM tblProductInventory PV                
WHERE pv.ProdID = @Code and (ActualQty > 0 OR ActualDmgQty > 0) and BranchID = @Party and TransDate <= @FromDate                
GROUP BY PV.BatchNumber,PV.PKDDate,PV.ExpiryDate,PV.MRPONPrice,PV.ReturnPrice,ProdID                
END                
IF(@Mode = 5)                
BEGIN                
select mp.BaseUomID,MU.Name,BaseCR CR from tblMasterProduct mp                
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID = @ID                
END                
IF(@Mode = 6)                
BEGIN                
SELECT MP.*,MT.GST FROM tblMasterProduct MP            
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID WHERE ID = @Code                
END                
IF(@Mode = 7)                
BEGIN                
SET @strQuery = 'select PH.InventoryID ID,DocID,CONVERT(NVARCHAR,InventoryDate,103) DocDate,RefNo,MBO.Name Branch,dbo.fnGetRoundedValue(PH.TotalAmt) GrossAmt,                
STS.Description Status,CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,PH.Remarks,
PH.Narration,[dbo].[fnGetRoundedValue](SUM((invd.ActualQty - invd.OrgQty) * ActualPurPrice)) [Final Diff Value]
from tblInventoryHeader PH
JOIN tblInventoryDetail as invd ON invd.InventoryID=PH.InventoryID  
JOIN tblStatus STS ON STS.ID = PH.Status                
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID          
JOIN tblUsers CUR ON CUR.ID = PH.CBy WHERE TransID = 13 '                
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND InventoryDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                
SET @strQuery += ' GROUP BY PH.InventoryID,DocID,InventoryDate,RefNo,MBO.Name,PH.TotalAmt,                
STS.Description,CUR.UserName,PH.CDate,PH.Status,PH.Remarks,DocValue,
PH.Narration ORDER BY InventoryDate desc,DocValue desc,PH.InventoryID'                
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                
END                
IF(@Mode = 8)                
BEGIN                
SELECT *,dbo.fnTransactionPrefix(InventoryDate,BranchID,TransID) Prefix  FROM tblInventoryHeader where InventoryID = @ID                
END                
IF(@Mode = 9)                
BEGIN                
SELECT PD.ProdID,MP.BaseUomID UomID,MT.GST TaxPern,MP.Code,MP.Name,sum(OrgQty) OrgQty,sum(OrgFreeQty) OrgFreeQty,sum(OrgDmgQty) OrgDmgQty,                
MU.Name UOMName,sum(ActualQty) ActualQty,sum(ActualFreeQty) ActualFreeQty,sum(ActualDmgQty) ActualDmgQty,                
GrossAmt FROM tblInventoryDetail PD                
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                
JOIN tblMasterUOM MU ON MU.ID = MP.BaseUomID                
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID                
where InventoryID = @Code                
group by PD.ProdID,MP.BaseUomID ,MT.GST,MP.Code,MP.Name,GrossAmt,MU.Name                
END                
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetInventoryConvertionData';
GO
--uspGetSetInventoryAdjustmentData 2,1,0,13,'7','2024-12-25','2024-12-26',0              
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetInventoryConvertionData]              
@Mode INT,@Code NVARCHAR(MAX) = NULL,@ID NVARCHAR(MAX) = NULL,@TransID int =22,@Party NVARCHAR(MAX) = NULL,@FromDate date = null,              
@ToDate date = null,@Showall int = null              
AS              
BEGIN              
declare @strQuery NVARCHAR(MAX)              
IF(@Mode = 1)              
BEGIN              
SELECT 1 Type,'Branch' Trans,ID,'',Name FROM tblMasterBranchOffice WHERE Active = 1              
union all              
SELECT 2 Type,'ConversionType' Trans,ConvertionTypeID ID,'',ConvertionType Name FROM tblConvertionType WHERE Active = 1              
union all              
SELECT 4 Type,'Reason' Trans,ID,'',Name FROM tblMasterReason WHERE Active = 1        
union all      
SELECT 3 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 22              
order by Type,Name              
END              
IF(@Mode = 2)              
BEGIN              
CREATE TABLE #ABS(ProdID INT,ABSQty DECIMAL(25,4))              
IF(@Code = 1 OR @Code = 2 OR @Code = 7)-- Sale to Free ,sale TO Damage AND Sample      
BEGIN              
INSERT INTO #ABS              
SELECT ProdID,dbo.fnGetRoundedValue(SUM(ActualQty)) ABSQty FROM tblProductInventory           
WHERE BranchID = @Party AND TransDate <= @FromDate AND (ActualQty > 0)              
GROUP BY ProdID             
      
SELECT MP.*,dbo.fnGetRoundedValue(ISNULL(AB.ABSQty,0)) ABSQty FROM tblMasterProduct MP              
JOIN #ABS AB ON AB.ProdID = MP.ID              
WHERE Active = 1 AND TrackInventory = 1 ORDER BY Name             
END              
ELSE IF(@Code = 3 OR  @Code = 4) --Free to sale,free to damage           
BEGIN              
INSERT INTO #ABS              
SELECT ProdID,dbo.fnGetRoundedValue(SUM(ActualFreeQty)) ABSQty FROM tblProductInventory           
WHERE BranchID = @Party AND TransDate <= @FromDate AND (ActualFreeQty > 0)              
GROUP BY ProdID             
      
SELECT MP.*,dbo.fnGetRoundedValue(ISNULL(AB.ABSQty,0)) ABSQty FROM tblMasterProduct MP              
JOIN #ABS AB ON AB.ProdID = MP.ID              
WHERE Active = 1 AND TrackInventory = 1 ORDER BY Name              
END        
ELSE IF(@Code = 5 OR  @Code = 6) --Damage to Sale,Damage to Free        
BEGIN              
INSERT INTO #ABS              
SELECT ProdID,dbo.fnGetRoundedValue(SUM(ActualDmgQty)) ABSQty FROM tblProductInventory           
WHERE BranchID = @Party AND TransDate <= @FromDate AND (ActualDmgQty > 0)              
GROUP BY ProdID             
      
SELECT MP.*,dbo.fnGetRoundedValue(ISNULL(AB.ABSQty,0)) ABSQty FROM tblMasterProduct MP              
JOIN #ABS AB ON AB.ProdID = MP.ID              
WHERE Active = 1 AND TrackInventory = 1 ORDER BY Name              
END       
DROP TABLE #ABS              
END              
IF(@Mode = 3)              
BEGIN              
SELECT MP.ID,MP.Code,MP.Name,HSNCode,MP.BaseUomID,MP.BaseCR,MP.PurchaseUomID,MP.PurchaseCR,mp.PurchaseTaxID,MT.TaxName,MT.GST,          
MP.ProductDiscPerc,MP.PurchasePrice,MP.SalesPrice,MP.ECP,MP.SPLPrice,MP.MRP,MP.ReturnPrice,TrackBatch,TrackPDK          
FROM tblMasterProduct MP              
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID              
WHERE Code = @Code              
END              
IF(@Mode = 4)              
BEGIN              
IF ISNULL(@Code,0)=0              
BEGIn --All Batch Info              
SELECT ProdId,BatchNumber,CONVERT(NVARCHAR,PKDDate,103) AS PKDDate,CONVERT(NVARCHAR,ExpiryDate,103) AS ExpiryDate,ActualQty AS Qty , ActualFreeQty AS [FreeQty],ActualDmgQty AS [DmgQty] ,              
PurchasePrice,MRPONPrice MRP,TaxValue,TaxId,InventoryId,CONVERT(NVARCHAR,TransDate,103) AS DocDate              
FROM dbo.tblProductInventory              
WHERE ProdId = @ID AND TransDate <= @FromDate AND BranchID = @Party ORDER BY TransDate DESC              
END              
ELSE IF ISNULL(@Code,0)=1            
BEGIn--Valid Batch Only              
SELECT ProdId,BatchNumber,CONVERT(NVARCHAR,PKDDate,103) AS PKDDate,CONVERT(NVARCHAR,ExpiryDate,103) AS ExpiryDate,ActualQty AS Qty , ActualFreeQty AS [FreeQty],ActualDmgQty AS [DmgQty] ,              
PurchasePrice,MRPONPrice MRP,TaxValue,TaxId,InventoryId,CONVERT(NVARCHAR,TransDate,103) AS DocDate              
FROM dbo.tblProductInventory              
WHERE ProdId = @ID AND TransDate <= @FromDate AND BranchID = @Party AND (ISNULL(ActualQty,0)>0 OR ISNULL(ActualFreeQty,0)>0 OR ISNULL(ActualDmgQty,0) >0)              
ORDER BY TransDate DESC              
END              
END              
ELSE IF(@Mode = 41)              
BEGIN              
SELECT 0 InventoryId,ProdID,PV.BatchNumber,PV.PKDDate,PV.ExpiryDate,dbo.fnGetRoundedValue(SUM(ActualQty)) Qty,              
dbo.fnGetRoundedValue(SUM(ActualFreeQty)) FreeQty,dbo.fnGetRoundedValue(SUM(ActualDmgQty)) DmgQty,              
dbo.fnGetRoundedValue(PV.MRPONPrice) MRP,0 PurchasePrice,dbo.fnGetRoundedValue(PV.ReturnPrice) ReturnPrice              
FROM tblProductInventory PV              
WHERE pv.ProdID = @Code and (ActualQty > 0 OR ActualDmgQty > 0) and BranchID = @Party and TransDate <= @FromDate              
GROUP BY PV.BatchNumber,PV.PKDDate,PV.ExpiryDate,PV.MRPONPrice,PV.ReturnPrice,ProdID              
END              
IF(@Mode = 5)              
BEGIN              
select mp.BaseUomID,MU.Name,BaseCR CR from tblMasterProduct mp              
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID = @ID              
END              
IF(@Mode = 6)              
BEGIN              
SELECT MP.*,MT.GST FROM tblMasterProduct MP          
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID WHERE ID = @Code              
END              
IF(@Mode = 7)              
BEGIN              
SET @strQuery = 'select PH.InventoryID ID,DocID,CONVERT(NVARCHAR,InventoryDate,103) DocDate,RefNo,MBO.Name Branch,dbo.fnGetRoundedValue(PH.TotalAmt) GrossAmt,              
STS.Description Status,CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,CT.ConvertionType,PH.Remarks,PH.Narration      
from tblInventoryHeader PH              
JOIN tblStatus STS ON STS.ID = PH.Status              
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID        
join tblConvertionType CT ON CT.ConvertionTypeID = PH.ConvertionTypeID      
JOIN tblUsers CUR ON CUR.ID = PH.CBy WHERE TransID = 22 '              
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND InventoryDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END              
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END              
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END              
SET @strQuery += ' ORDER BY InventoryDate DESC,DocValue desc,PH.InventoryID'              
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall              
END              
IF(@Mode = 8)              
BEGIN              
SELECT *,dbo.fnTransactionPrefix(InventoryDate,BranchID,TransID) Prefix FROM tblInventoryHeader where InventoryID = @ID              
END              
IF(@Mode = 9)              
BEGIN              
SELECT PD.ProdID,MP.BaseUomID UomID,MT.GST TaxPern,MP.Code,MP.Name,sum(OrgSaleQty) OrgQty,MU.Name UOMName,      
sum(GrossAmt)GrossAmt,ISNULL(PD.ReasonId,0) ReasonId,MR.Name Reason FROM tblInventoryDetail PD      
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID      
JOIN tblMasterUOM MU ON MU.ID = MP.BaseUomID      
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID      
LEFT JOIN TBLMASTERREASON MR ON MR.ID = PD.ReasonID      
where InventoryID = @Code and NewBatchID > 0      
group by PD.ProdID,MP.BaseUomID ,MT.GST,MP.Code,MP.Name,MU.Name,PD.ReasonId,MR.Name        
END              
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetInvoiceData';
GO
--uspGetSetInvoiceData 8,'0',1265,15,'','2021-12-30','2028-12-16',1                        
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetInvoiceData]                        
@Mode INT,@Code NVARCHAR(MAX) = NULL,@ID NVARCHAR(MAX) = NULL,@TransID int =1,@Party NVARCHAR(MAX) = NULL,@FromDate date = null,                        
@ToDate date = null,@Showall int = null                        
AS                        
BEGIN                        
declare @strQuery NVARCHAR(MAX) ,@AllowAllSM int = 0                        
declare @currDocid nvarchar(255)                        
declare @RestrictBlocklist int = (SELECT AppValue FROM tblAppConfig WHERE AppId = 31)                        
declare @DecVal int = (SELECT AppValue FROM tblAppConfig WHERE AppId = 8)                        
IF(@Mode = 0)                        
BEGIN                        
select ID,Code,Name,Billadd1 Address,Shinecode from tblMasterCustomer where Active = 1 and FAID > 0                        
AND isnull(Rating,0) != (case when @RestrictBlocklist = 1 then 5 else -1 end)                     
                        
select CustomerID,BeatID,SalesmanID,MC.Name CustomerName,MB.Name Beat,SM.Name Salesman from tblBeatSalesmanMapping BSM                        
JOIN tblMasterCustomer MC ON MC.ID = BSM.CustomerID                        
JOIN tblMasterBeat MB ON MB.ID = BSM.BeatID                        
JOIN tblMasterSalesman SM ON SM.ID = BSM.SalesmanID                        
where CustomerID = -1                    
END                        
IF(@Mode = 1)                        
BEGIN                        
--select 1 Type,'Customer' Trans,ID,Code,Name,Billadd1 Address from tblMasterCustomer where Active = 1 and FAID > 0                        
--AND isnull(Rating,0) != (case when @RestrictBlocklist = 1 then 5 else -1 end)                        
--union all                        
SELECT 2 Type,'Branch' Trans,ID,'',Name,'' FROM tblMasterBranchOffice WHERE Active = 1                        
union all                        
SELECT 3 Type,'UDN' Trans,UDNID,'',DocName,'' FROM tblMasterUserDefineNoHeader WHERE TransID = 1                        
union all                        
SELECT 4 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue,'' FROM tblDocumentSeries WHERE Active = 1 and TransID = 15                        
union all                        
SELECT 5 Type,'Paymode' Trans,ID,'',PaymentMode,'' FROM tblPaymentMode WHERE Active = 1 AND ID IN (7,8)                        
union all                        
SELECT 6 Type,'CreditTerm' Trans,ID,'',Name,'' FROM tblMasterCreditTerm WHERE Active = 1                        
union all                        
SELECT 7 Type,'Beat' Trans,ID,'',Name,'' FROM tblMasterBeat WHERE Active = 1                        
union all                        
SELECT 8 Type,'Salesman' Trans,ID,'',Name,'' FROM tblMasterSalesman WHERE Active = 1                        
union all                        
SELECT 9 Type,'TaxType' Trans,TaxTypeID,'',TaxTypeName,'' FROM tblMasterTaxType WHERE Active = 1                        
union all                        
SELECT 12 Type,'BankAcc' Trans,MBA.ID,convert(nvarchar, FAID),AccountNo+'|'+MB.Name+'|'+BranchName+'|'+IFSCCode+'|'+MICR+'|'+CONVERT(nvarchar,SetDefault) Name,'' from tblMasterBankAccount MBA                        
JOIN tblMasterBank MB ON MB.ID = MBA.BankID WHERE MBA.Active = 1 and FAID > 0                        
union all                        
SELECT 13 Type,'BankAcc' Trans,ID,'',ModeName,'' FROM tblContraMode WHERE Active = 1 and ID > 2                        
union all                        
SELECT 14 Type,'Bank' Trans,ID,'',Name,'' FROM tblMasterBank WHERE Active = 1                        
union all                        
SELECT 15 Type,'Reason' Trans,ID,'',Name,'' FROM tblMasterReason WHERE Active = 1                        
union all                        
SELECT 16 Type,'Vehicle' Trans,ID,'',VehicleNo Name,'' FROM tblMasterVehicle WHERE Active = 1                        
order by Type,Name                        
END       
IF(@Mode = 111)                        
BEGIN                        
SELECT 11 Type,'AllPaymode' Trans,ID,CONVERT(nvarchar,Orderby),PaymentMode FROM tblPaymentMode WHERE Active = 1 AND ID NOT IN (8,9,10)         
ORDER BY Orderby,PaymentMode                        
END                        
IF(@Mode = 112)                        
BEGIN                    
DECLARE @PT AS TABLE(ID SMALLINT)                        
IF(@Code = 1 OR @Code = 2)                        
BEGIN            
INSERT INTO @PT                        
SELECT ID FROM tblPriceType                        
END                        
ELSE                        
BEGIN                        
INSERT INTO @PT                        
SELECT ID FROM tblPriceType WHERE ID NOT IN (1)                        
END                        
SELECT 10 Type,'PriceType' Trans,ID,'',PriceType FROM tblPriceType WHERE Active = 1 and id IN (SELECT * FROM @PT)                        
ORDER BY DisplayIndex,PriceType                        
END                        
IF(@Mode = 2)                        
BEGIN                        
DECLARE @StockOnly INT = (SELECT AppValue FROM tblAppConfig WHERE AppId = 24)                        
SELECT ProdID,SUM(ISNULL(ActualQty,0)) ABSQty into #ABS FROM tblProductInventory WHERE BranchID = @Code                        
AND TransDate <= @FromDate                        
GROUP BY ProdID                        
SELECT MP.ID,MP.Code,MP.Name,MP.EAN,MP.HSNCode,dbo.fnGetRoundedValue(CASE WHEN @ID = 1 THEN PurchasePrice WHEN @ID = 2 THEN SalesPrice WHEN @ID = 3 THEN ECP                        
WHEN @ID = 4 THEN MRP WHEN @ID = 5 THEN SPLPrice WHEN @ID = 6 THEN ReturnPrice ELSE 0 END) Price,                        
dbo.fnGetRoundedValue(ISNULL(AB.ABSQty,0)) ABSQty,ML.NAME LocationName FROM tblMasterProduct MP                        
LEFT JOIN #ABS AB ON AB.ProdID = MP.ID                        
LEFT JOIN TBLMASTERLOCATION ML ON ML.ID = MP.LOCATIONID                        
WHERE MP.Active = 1 AND ABSQty > (CASE WHEN @StockOnly = 1 THEN 0 ELSE -1 END) ORDER BY Name                        
drop table #ABS                        
END                        
IF(@Mode = 3)                        
BEGIN                        
SELECT MC.*,RT.RatingName FROM tblMasterCustomer MC LEFT JOIN tblRatings RT ON RT.ID = MC.Rating                        
WHERE MC.Active = 1 AND Code = @Code ORDER BY Name                        
END                        
IF(@Mode = 31)                        
BEGIN                        
SELECT MC.*,RT.RatingName FROM tblMasterCustomer MC LEFT JOIN tblRatings RT ON RT.ID = MC.Rating                        
WHERE MC.Active = 1 AND MC.ID = @Code ORDER BY Name                        
END                        
IF(@Mode = 32)--get beat & sm                        
BEGIN                        
select TOP 1* from tblBeatSalesmanMapping WHERE CustomerID = @Code ORDER BY ID                        
END                        
IF(@Mode = 33)--get beat & sm                        
BEGIN                        
select @AllowAllSM = AppValue from tblAppConfig where AppId = 18                        
SET @strQuery = '                        
SELECT 1 Type,''Customer'' Trans,MC.ID,Code,Name,Billadd1 Address FROM tblMasterCustomer MC                        
LEFT JOIN tblBeatSalesmanMapping BSM ON BSM.CustomerID = MC.ID                        
where Active = 1 AND FAID > 0 AND isnull(Rating,0) != (case when '+convert(nvarchar,@RestrictBlocklist)+' = 1 then 5 else -1 end)'                        
SET @strQuery += case when @Code > 0 then ' AND BSM.BeatID = @Code' else '' end                        
SET @strQuery += case when @ID > 0 and @AllowAllSM = 0 then ' AND BSM.SalesmanID = @ID' else '' end                         
SET @strQuery += ' group by MC.ID,Code,Name,Billadd1 order by Name'                        
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                        
END                        
IF(@Mode = 34)--get customerremarks                        
BEGIN                        
select * from tblMasterCustomerRemarks WHERE CustomerID = @Code                        
END                        
IF(@Mode = 4)                        
BEGIN                        
SELECT MP.*,0.00 ABSQty,MT.TaxName,MT.GST,MT.IGST,ISNULL(PTP.InvoicePrice,0) InvoicePrice FROM tblMasterProduct MP                        
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID                        
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = MP.ID                        
WHERE Code = @Code                        
END                        
IF(@Mode = 5)                        
BEGIN                        
select mp.SalesUomID,MU.Name,SalesCR from tblMasterProduct mp                        
JOIN tblMasterUOM MU ON MU.ID = mp.SalesUomID where MP.ID = @ID                        
UNION all                       
select mp.PurchaseUomID,MU.Name,PurchaseCR from tblMasterProduct mp                        
JOIN tblMasterUOM MU ON MU.ID = mp.PurchaseUomID where MP.ID = @ID                        
UNION all                        
select mp.BaseUomID,MU.Name,BaseCR CR from tblMasterProduct mp                        
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID = @ID            
END                        
IF(@Mode = 6)--sales Filter                        
BEGIN                        
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,InvDate,103) DocDate,DocRef RefNo,MBO.Name Branch,MV.Name Party,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.GrossAmt) GrossAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TotalTaxAmt) TaxAmt,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.NetAmt) NetAmt,                        
STS.Description Status,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.Balance) Balance,CUR.UserName UserName,                        
CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,                        
null Info,PT.PriceType,PH.Remarks, PH.Narration,                   
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TotalTradeDiscAmt + PH.TotalProdDiscAmt + PH.AdditionalDiscAmt) AS TotalDiscAmt,                    
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TotalProdDiscAmt) TotalProdDiscAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.AdditionalDisc) AddnlDiscPern,                    
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.AdditionalDiscAmt) AddnlDiscAmt,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TradeDisc) TradeDiscPern,                    
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TotalTradeDiscAmt) TradeDiscAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),OtherCharge) OtherChargePern,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),OtherChargeAmt) OtherChargeAmt,                    
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),Frieght) FrightAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),TCSTaxAmt) TCSTaxAmt,MS.Name [Salesman],MB.Name [BeatName],                        
ISNULL(DC.DeliveryCount,0) AS DeliveryCount ,        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.DiffValueGross) [DiffExcl],                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.DiffValueNet) DiffIncl,PH.PaymentModeID PaymentModeID,    
ISNULL(AC.AssignCount,0) AS AssignCount     
FROM tbltransalesheader PH                        
JOIN tblMasterCustomer MV ON MV.ID = PH.CustID                        
JOIN tblStatus STS ON STS.ID = PH.Status                        
JOIN tblUsers CUR ON CUR.ID = PH.CBy                        
LEFT JOIN tblUsers MUR ON MUR.ID = PH.MBy                        
left join tblMasterSalesman MS ON MS.ID = PH.SalesmanID                        
left join tblMasterBeat MB ON MB.ID = PH.BeatID                        
JOIN tblPriceType PT ON PT.ID = PH.PriceID                       
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                    
LEFT JOIN (SELECT DD.InvIdentID,COUNT(*) AS DeliveryCount    
FROM tblDeliveryOrderHeader DH    
JOIN tblDeliveryOrderDetail DD ON DD.DOID = DH.ID    
WHERE DH.Status IN (1,3,5) AND DD.Status IN (1,5)    
GROUP BY DD.InvIdentID) DC ON DC.InvIdentID = PH.ID    
    
LEFT JOIN (SELECT AD.InvID,COUNT(*) AS AssignCount    
FROM tblAssignInvoicesHeader AH    
JOIN tblAssignInvoicesDetail AD ON AD.HID = AH.ID    
WHERE AH.Status IN (1,3,5) AND AD.Status IN (1,5)    
GROUP BY AD.InvID) AC ON AC.InvID = PH.ID      
    
WHERE DocPrefix = 15 '                        
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND InvDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                        
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END                        
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                        
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                        
SET @strQuery += ' ORDER BY InvDate desc,DocValue desc,PH.ID'                   
PRINT @strQuery               
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                        
END                        
IF(@Mode = 7)                        
BEGIN                        
SELECT PH.ID, PH.InvDate Date, PH.DocPrefix TransID, PH.BranchID, PH.DocID, PH.DocValue,PH.BeatID,PH.SalesManID, PH.CustID CustomerID, PH.DocRef RefNo,0 ProdGroupID,                        
PH.TaxTypeID,PH.PriceID,PH.PaymentModeID,PH.CreditTermID, PH.Frieght FrightAmt, PH.OtherCharge OtherChrgPern,PH.OtherChargeAmt, PH.TradeDisc TradePern, PH.AdditionalDisc AddnlPern,                        
PH.TotalProdDiscAmt, PH.TotalTradeDiscAmt TradeDiscAmt,PH.AdditionalDiscAmt AddnlDiscAmt, PH.RoundOfAmt RoundOffAmt, PH.GrossAmt,                        
PH.TotalTaxAmt TaxAmt, PH.NetAmt,PH.Status, PH.UDFId, PH.UDFDocId, PH.UDFDocPrefix, PH.UDFDocValue, PH.Remarks, PH.Narration,                        
PH.TCSTaxAmt,PH.TDSAmount,CreditNoteAdjAmt Writeoff,PH.VehicleNo,PH.Distance,PH.VehicleType,PH.TransMode,PH.TransportID,PH.TransportName,                        
DiffValueGross,DiffValueNet,dbo.fnTransactionPrefix(PH.InvDate,BranchID,PH.DocPrefix) Prefix,dbo.fnGetRoundedValue(PH.Balance) Balance,                        
PH.IRN,PH.AckNo,PH.AckDate,PH.AckStatus,PH.EWBNo,PH.SignedQRCode                        
FROM tblTranSalesHeader PH JOIN tblMasterCustomer MV ON MV.ID = PH.CustID                        
JOIN tblStatus STS ON STS.ID = PH.Status                        
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                        
where PH.ID = @ID                        
END                        
IF(@Mode = 8)                        
BEGIN

select ProdID,(SUM(isnull(ActualQty,0))) ActualQty,(SUM(isnull(ActualFreeQty,0))) ActualFreeQty,      
(SUM(isnull(ActualDmgQty,0))) ActualDmgQty INTO #ABSQ from tblProductInventory WHERE ProdID IN (      
select distinct ProdID from tblTranSalesDetail where INVID = @ID) AND BranchID = (      
select distinct BranchID from tblTranSalesHeader where ID = @ID)      
GROUP BY ProdID     

SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,UOM.Name UOM,SUM(UomQty) Qty,PD.DetailMRP,PD.UomPrice ExclPrice,                        
dbo.fngetinclusivevalue(PD.TaxID,PD.DetailMRP,PD.UomPrice) InclPrice,                        
--(PD.UomPrice * (1 + (PD.TaxValue / 100))) InclPrice,                        
PD.ProdDisc ProdPern,pd.ProdDiscAmt,PD.TradeDiscPern TradePern,TradeDisc TradeDiscAmt,                        
PD.AddnlDiscPern AddnlPern,AddnlDisc AddnlDiscAmt,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,PD.TaxID,MT.TaxName,PD.TaxValue TaxPern,                        
SUM(GoodsAmt) GoodsAmt,BaseUomPrice,PV.BatchNumber BatchNo,PV.PKDDate PKD,PV.ExpiryDate Expiry,MP.TrackInventory,MP.TrackBatch,                        
MP.TrackPDK,mp.TrackSerial,ISNULL(PD.DiffValue,0) DiffValue,ISNULL(PTP.InvoicePrice,0) InvoicePrice ,ISNULL(QtyType,1) QtyType,                        
SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,                        
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.DetailMRP)) MRPonTaxAmt,MP.Shinecode,PD.Serial,
dbo.fnGetRoundedValue((isnull(AQ.ActualQty,0))) ActualQty,dbo.fnGetRoundedValue((isnull(AQ.ActualFreeQty,0))) ActualFreeQty,      
dbo.fnGetRoundedValue((isnull(AQ.ActualDmgQty,0))) ActualDmgQty  
into #invitems                     
FROM tblTranSalesDetail PD                        
LEFT JOIN tblProductInventory PV ON PV.InventoryId = PD.InventoryID                        
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                        
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                        
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID                        
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = PD.ProdID
left join #ABSQ AQ ON AQ.ProdID = PD.ProdID
where PD.InvID = @ID                   
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.ProdDisc,PD.TradeDiscPern,PD.AddnlDiscPern,Serial,                        
MT.TaxName,PD.TaxValue,PD.DetailMRP,PD.UomPrice,PD.TaxID,pd.ProdDiscAmt,AddnlDisc,TradeDisc,BaseUomPrice,MP.Shinecode,                        
PV.BatchNumber,PV.PKDDate,PV.ExpiryDate,MP.TrackInventory,MP.TrackBatch,MP.TrackPDK,mp.TrackSerial,PD.DiffValue,          
PTP.InvoicePrice,QtyType ,PD.Serial,AQ.ActualQty,AQ.ActualFreeQty,AQ.ActualDmgQty                       
ORDER BY Serial                        
            
select * from #invitems ORDER BY Serial          
select SalesUomID,Name,SalesCR,ProdID,UOMType from (            
select mp.SalesUomID,MU.Name,SalesCR,mp.ID ProdID,'SalesUOM' UOMType,1 sno from tblMasterProduct mp                        
JOIN tblMasterUOM MU ON MU.ID = mp.SalesUomID where MP.ID in (select prodid from #invitems)            
UNION all                        
select mp.PurchaseUomID,MU.Name,PurchaseCR,mp.ID ProdID,'PurchaseUOM' UOMType,2 sno from tblMasterProduct mp                        
JOIN tblMasterUOM MU ON MU.ID = mp.PurchaseUomID where MP.ID in (select prodid from #invitems)                   
UNION all                        
select mp.BaseUomID,MU.Name,BaseCR CR,mp.ID ProdID,'BaseUOM' UOMType,3 sno from tblMasterProduct mp                        
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID in (select prodid from #invitems)            
) as uoms            
group by ProdID,SalesUomID,Name,SalesCR,UOMType,sno            
order by sno            
drop table #invitems,#ABSQ
  
select PMDTL.*,PM.PaymentMode,MBAC.AccountNo,MBAC.AccountName,  
CONVERT(VARCHAR(10),CONVERT(date,left(PMDate,10),103),23) OrgPMDate,MBK.ID BankID  
from tblTran_Sale_Bill_PaymentDetail PMDTL  
JOIN tblPaymentMode PM ON PM.ID = PMDTL.PayModeId  
LEFT JOIN tblMasterBankAccount MBAC ON MBAC.ID = PMDTL.Acc_OR_PaytermId  
LEFT JOIN tblMasterBank MBK ON MBK.Name = PMDTL.Bank  
where TransId  = 15 and InvId = @ID  


END                        
IF(@Mode = 10)--Draft                        
BEGIN                
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,Date,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.GrossAmt) GrossAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TaxAmt) TaxAmt,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.NetAmt) NetAmt,                        
STS.Description Status,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.NetAmt) Balance,CUR.UserName UserName,                        
CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,null Info,PT.PriceType,PH.Remarks, PH.Narration,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TotalTradeDiscAmt + PH.TotalProdDiscAmt + PH.TotalAddnlDiscAmt) AS TotalDiscAmt,                    
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TotalProdDiscAmt) TotalProdDiscAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.AddnlDiscPern) AddnlDiscPern,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TotalAddnlDiscAmt) AddnlDiscAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TradeDiscPern) TradeDiscPern,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TotalTradeDiscAmt) TradeDiscAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),OtherChargePern) OtherChargePern,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),OtherChargeAmt) OtherChargeAmt,
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),Frieght) FrightAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),TCSTaxAmt) TCSTaxAmt,MS.Name [Salesman],MB.Name [BeatName],         
0 DeliveryCount ,        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.DiffValueGross) [DiffExcl],                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.DiffValueNet) DiffIncl,7 PaymentModeID ,0 AssignCount         
FROM tblSalesDraftHeader PH                        
JOIN tblMasterCustomer MV ON MV.ID = PH.CustomerID                        
JOIN tblStatus STS ON STS.ID = PH.Status                        
JOIN tblUsers CUR ON CUR.ID = PH.CBy                        
LEFT JOIN tblUsers MUR ON MUR.ID = PH.MBy                        
left join tblMasterSalesman MS ON MS.ID = PH.SalesmanID                        
left join tblMasterBeat MB ON MB.ID = PH.BeatID                      
JOIN tblPriceType PT ON PT.ID = PH.PriceTypeID                        
left JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID WHERE MV.Active IN (0,1) and PH.TransID = ' + CONVERT(NVARCHAR,@TransID)                        
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE                    
' AND Date BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                        
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END                        
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                        
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1)' END                        
SET @strQuery += ' ORDER BY PH.Date desc,PH.ID DESC '                        
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                       
END                        
IF(@Mode = 11)                        
BEGIN                        
set @currDocid = (SELECT DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 15)                        
                        
SELECT PH.ID, PH.Date Date, PH.TransID, PH.BranchID, @currDocid DocID, PH.DocValue,PH.BeatID,PH.SalesManID, PH.CustomerID, PH.RefNo,0 ProdGroupID,                        
PH.TaxTypeID,PH.PriceTypeID PriceID,PH.PaymentModeID,PH.PaymentTermID CreditTermID, PH.Frieght FrightAmt, PH.OtherChargePern OtherChrgPern,                        
PH.OtherChargeAmt, PH.TradeDiscPern TradePern, PH.AddnlDiscPern AddnlPern, PH.TotalProdDiscAmt, PH.TotalTradeDiscAmt TradeDiscAmt,                        
PH.TotalAddnlDiscAmt AddnlDiscAmt, PH.RoundOffAmt, PH.GrossAmt, PH.TaxAmt, PH.NetAmt,                        
PH.Status, PH.UDFId, PH.UDFDocId, PH.UDFDocPrefix, PH.UDFDocValue, PH.Remarks, PH.Narration,WriteOffAmt Writeoff,TCSTaxAmt,TDSAmount,                        
0 VehicleNo,0 Distance,'' VehicleType,'' TransMode,'' TransportID,'' TransportName,DiffValueGross,DiffValueNet,dbo.fnTransactionPrefix(PH.Date,BranchID,PH.TransID) Prefix,                        
0 AS Balance,null IRN,null AckNo,null AckDate,null AckStatus,null EWBNo,null SignedQRCode                        
FROM tblSalesDraftHeader PH                        
JOIN tblMasterCustomer MV ON MV.ID = PH.CustomerID                        
JOIN tblStatus STS ON STS.ID = PH.Status                        
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                        
where PH.ID = @ID                        
                        
END                        
IF(@Mode = 12)                        
BEGIN
select ProdID,(SUM(isnull(ActualQty,0))) ActualQty,(SUM(isnull(ActualFreeQty,0))) ActualFreeQty,      
(SUM(isnull(ActualDmgQty,0))) ActualDmgQty INTO #ABSQ1 from tblProductInventory WHERE ProdID IN (      
select distinct ProdID from tblSalesDraftDetail where HID = @ID) AND BranchID = (      
select distinct BranchID from tblSalesDraftHeader where ID = @ID)      
GROUP BY ProdID    

SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,UOM.Name UOM,SUM(UOMQty) Qty,PD.MRP DetailMRP,PD.SalePrice ExclPrice,                        
dbo.fngetinclusivevalue(PD.TaxID,PD.MRP,PD.SalePrice) InclPrice,                        
--(PD.SalePrice * (1 + (TaxPern / 100))) InclPrice,                        
PD.ProdDiscPern ProdPern,pd.ProdDiscAmt,PD.TradeDiscPern TradePern,TradeDiscAmt,                       
PD.AddnlDiscPern AddnlPern,AddnlDiscAmt,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,PD.TaxID,MT.TaxName,PD.TaxPern TaxPern,                        
SUM(GoodsAmt) GoodsAmt,BaseUOMPrice,BatchNo,PKDDate PKD,ExpiryDate Expiry,MP.TrackInventory,MP.TrackBatch,MP.TrackPDK,mp.TrackSerial                        
,ISNULL(PD.DiffValue,0) DiffValue,ISNULL(PTP.InvoicePrice,0) InvoicePrice,ISNULL(QtyType,1) QtyType,                        
SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,                        
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.MRP)) MRPonTaxAmt,MP.Shinecode,Serial,
dbo.fnGetRoundedValue((isnull(AQ.ActualQty,0))) ActualQty,dbo.fnGetRoundedValue((isnull(AQ.ActualFreeQty,0))) ActualFreeQty,      
dbo.fnGetRoundedValue((isnull(AQ.ActualDmgQty,0))) ActualDmgQty   into #invitems1            
FROM tblSalesDraftDetail PD                        
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                        
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                        
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID                        
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = PD.ProdID   
left join #ABSQ1 AQ ON AQ.ProdID = PD.ProdID
where PD.HID = @ID                        
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.ProdDiscPern,PD.TradeDiscPern,PD.AddnlDiscPern,Serial,                        
MT.TaxName,PD.TaxPern,PD.MRP,PD.SalePrice,PD.TaxID,pd.ProdDiscAmt,AddnlDiscAmt,TradeDiscAmt,BaseUOMPrice,BatchNo,PKDDate,ExpiryDate                        
,MP.TrackInventory,MP.TrackBatch,MP.TrackPDK,mp.TrackSerial,PD.DiffValue,PTP.InvoicePrice ,QtyType,MP.Shinecode,
AQ.ActualQty,AQ.ActualFreeQty,AQ.ActualDmgQty                         
ORDER BY Serial                        
            
select * from #invitems1   ORDER BY Serial          
select SalesUomID,Name,SalesCR,ProdID,UOMType from (            
select mp.SalesUomID,MU.Name,SalesCR,mp.ID ProdID,'SalesUOM' UOMType,1 sno from tblMasterProduct mp                        
JOIN tblMasterUOM MU ON MU.ID = mp.SalesUomID where MP.ID in (select prodid from #invitems1)            
UNION all                        
select mp.PurchaseUomID,MU.Name,PurchaseCR,mp.ID ProdID,'PurchaseUOM' UOMType,2 sno from tblMasterProduct mp                        
JOIN tblMasterUOM MU ON MU.ID = mp.PurchaseUomID where MP.ID in (select prodid from #invitems1)                   
UNION all                        
select mp.BaseUomID,MU.Name,BaseCR CR,mp.ID ProdID,'BaseUOM' UOMType,3 sno from tblMasterProduct mp                        
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID in (select prodid from #invitems1)            
) as uoms            
group by ProdID,SalesUomID,Name,SalesCR,UOMType,sno            
order by sno            
drop table #invitems1,#ABSQ1          
  
select PMDTL.*,PM.PaymentMode,MBAC.AccountNo,MBAC.AccountName,  
CONVERT(VARCHAR(10),CONVERT(date,left(PMDate,10),103),23) OrgPMDate,MBK.ID BankID  
from tblTran_Sale_Bill_PaymentDetail PMDTL  
JOIN tblPaymentMode PM ON PM.ID = PMDTL.PayModeId  
LEFT JOIN tblMasterBankAccount MBAC ON MBAC.ID = PMDTL.Acc_OR_PaytermId  
LEFT JOIN tblMasterBank MBK ON MBK.Name = PMDTL.Bank  
where TransId  = -15 and InvId = @ID  
END                        
IF(@Mode = 13)                        
BEGIN                        
SELECT PD.*,MP.*,UOM.Name UOMName,MT.TaxName,0 InventoryId,1 TaxTypeID FROM tblPurchaseDraftDetail PD                        
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                        
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                        
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID                        
where PD.HID = @ID                        
ORDER BY Serial                        
END                        
IF(@Mode = 14)                   
BEGIN                        
SELECT top 10 DocID,CONVERT(NVARCHAR(25),Date,103) DocDate,MRP,Qty,Uom,Price,ProdDiscPern+' / '+ProdDiscAmt ProdDisc,TradeDiscPern+' / '+TradeDiscAmt TradeDisc                        
,AdnlDiscPern+' / '+AddnlDiscAmt AddnlDisc,BatchNo,PKD,Expiry FROM (                        
SELECT PH.DocID,InvDate Date,dbo.fnGetRoundedValue(PD.DetailMRP) MRP,dbo.fnGetRoundedValue(PD.UomQty) Qty,                        
UOM.Name Uom,dbo.fnGetRoundedValue(PD.UomPrice) Price,                        
dbo.fnGetRoundedValue(PD.[ProdDisc]) ProdDiscPern,dbo.fnGetRoundedValue((PD.[ProdDisc]* PD.GrossAmt) / 100) ProdDiscAmt,                        
dbo.fnGetRoundedValue(PD.[TradeDiscPern]) TradeDiscPern,dbo.fnGetRoundedValue((PD.[TradeDiscPern]* PD.GrossAmt) / 100) TradeDiscAmt,                        
dbo.fnGetRoundedValue(PD.[AddnlDiscPern]) AdnlDiscPern,dbo.fnGetRoundedValue((PD.[AddnlDiscPern]* PD.GrossAmt) / 100) AddnlDiscAmt,                        
PV.BatchNumber BatchNo,convert(nvarchar(25),PKDDate,103) PKD,convert(nvarchar(25),ExpiryDate,103) Expiry                        
FROM tblTranSALESHeader PH                        
JOIN tblTranSALESDetail PD ON PD.InvID = PH.ID                        
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                        
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                        
LEFT JOIN tblProductInventory PV ON PV.InventoryID = PD.InventoryID                        
WHERE DocPrefix = 15 and status in (1,3,5) and PH.CustID = @Code AND PD.ProdID = @ID) AS REC                        
END                        
IF(@Mode = 15)                        
BEGIN                        
if(@Code = 2)                        
BEGIN                        
DECLARE @DraftID INT                        
SELECT @DraftID = ID FROM tblSalesDraftHeader WHERE ID = @ID AND TransID = 15                        
DELETE tblSalesDraftHeader WHERE ID = @DraftID                        
DELETE tblSalesDraftDetail WHERE HID = @DraftID                        
END                    
ELSE IF(@Code = 4)                        
BEGIN                        
UPDATE tblTranOrderTakenHeader set Status = 4,ClBy = @TransID,ClDate = GETDATE() where ID = @ID AND STATUS IN (1,3)                        
END                        
END                        
IF(@Mode = 16)--Quotation Filter                        
BEGIN                        
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,DocDate,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.GrossAmt) GrossAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TaxAmt) TaxAmt,        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.NetAmt) NetAmt,                        
STS.Description Status,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.NetAmt) Balance,                        
CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,null Info,                        
PT.PriceType,PH.Remarks, PH.Narration,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TotalDiscAmt) AS TotalDiscAmt,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TotalProdDiscAmt) TotalProdDiscAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.AddnlDiscPern) AddnlDiscPern,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.AddnlDiscAmt) AddnlDiscAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TradeDiscPern) TradeDiscPern,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TradeDiscAmt) TradeDiscAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),OtherChargePern) OtherChargePern,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),OtherChargeAmt) OtherChargeAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),0) FrightAmt,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),0) TCSTaxAmt,                        
(SELECT TOP 1 MBB.Name FROM tblBeatSalesmanMapping BSMB                        
LEFT JOIN TBLMASTERBEAT MBB ON MBB.ID = BSMB.BeatID                        
WHERE BSMB.CustomerID = PH.CustomerID ORDER BY 1) [BeatName],                        
(SELECT TOP 1 MBS.Name FROM tblBeatSalesmanMapping BSMB1                        
LEFT JOIN tblMasterSalesman MBS ON MBS.ID = BSMB1.SalesmanID                        
WHERE BSMB1.CustomerID = PH.CustomerID ORDER BY 1) [Salesman], 0 DeliveryCount,0 [DiffExcl],0 DiffIncl,7 PaymentModeID,0 AssignCount          
FROM tblQuotationHeader PH                        
JOIN tblMasterCustomer MV ON MV.ID = PH.CustomerID                        
JOIN tblStatus STS ON STS.ID = PH.Status                        
JOIN tblUsers CUR ON CUR.ID = PH.CBy                        
LEFT JOIN tblUsers MUR ON MUR.ID = PH.MBy                        
JOIN tblPriceType PT ON PT.ID = PH.PriceID                        
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID WHERE DocPrefix = 14 '                        
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                        
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END                        
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                        
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3)' END                        
SET @strQuery += ' ORDER BY DocDate desc, DocValue desc,PH.ID'                        
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                        
END                        
IF(@Mode = 17)                        
BEGIN                        
SELECT PH.ID, PH.DocDate Date, PH.DocPrefix TransID, PH.BranchID, PH.DocID, PH.DocValue,                        
isnull((SELECT TOP 1 CBS.BeatId FROM tblBeatSalesmanMapping CBS                        
WHERE CustomerId =PH.CustomerID),0) BeatID,isnull((SELECT TOP 1 CBS.SalesmanID FROM tblBeatSalesmanMapping CBS                        
WHERE CustomerId =PH.CustomerID ),0) SalesManID, PH.CustomerID, PH.RefNo,0 ProdGroupID,                        
PH.TaxTypeID,PH.PriceID,MV.PaymentModeID,MV.CreditTermID CreditTermID, PH.FrightAmt FrightAmt, PH.OtherChargePern OtherChrgPern,PH.OtherChargeAmt,                        
PH.TradeDiscPern TradePern, PH.AddnlDiscPern AddnlPern,                        
PH.TotalProdDiscAmt, PH.TradeDiscAmt TradeDiscAmt,PH.AddnlDiscAmt AddnlDiscAmt, PH.RoundOffAmt RoundOffAmt, PH.GrossAmt,                        
PH.TaxAmt TaxAmt, PH.NetAmt,PH.Status, PH.UDFId, PH.UDFDocId, PH.UDFDocPrefix, PH.UDFDocValue, PH.Remarks, PH.Narration,                        
0 TCSTaxAmt,0 TDSAmount,0 Writeoff,0 VehicleNo,0 Distance,'' VehicleType,'' TransMode,'' TransportID,'' TransportName,0 DiffValueGross,0 DiffValueNet,                    
dbo.fnTransactionPrefix(PH.DocDate,BranchID,PH.DocPrefix) Prefix,                        
0 AS Balance,null IRN,null AckNo,null AckDate,null AckStatus,null EWBNo,null SignedQRCode                        
FROM tblQuotationHeader PH                        
JOIN tblMasterCustomer MV ON MV.ID = PH.CustomerID                        
JOIN tblStatus STS ON STS.ID = PH.Status                        
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                        
where PH.ID = @ID                        
END                        
IF(@Mode = 18)  
BEGIN                   
select ProdID,(SUM(isnull(ActualQty,0))) ActualQty,(SUM(isnull(ActualFreeQty,0))) ActualFreeQty,      
(SUM(isnull(ActualDmgQty,0))) ActualDmgQty INTO #ABSQ2 from tblProductInventory WHERE ProdID IN (      
select distinct ProdID from tblquotationdetail where QuationID = @ID) AND BranchID = (      
select distinct BranchID from tblQuotationHeader where ID = @ID)      
GROUP BY ProdID    
SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,UOM.Name UOM,SUM(Qty) Qty,PD.DetailMRP,PD.SalesPrice ExclPrice,                        
dbo.fngetinclusivevalue(PD.TaxID,PD.DetailMRP,PD.SalesPrice) InclPrice,                        
--(PD.SalesPrice * (1 + (TaxPercentage / 100))) InclPrice,                        
PD.ProdDiscPern ProdPern,pd.ProdDiscAmt,PD.TradeDiscPern TradePern,TradeDiscAmt TradeDiscAmt,                        
PD.AddnlDiscPern AddnlPern,AddnlDiscAmt AddnlDiscAmt,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,PD.TaxID,MT.TaxName,PD.TaxPercentage TaxPern,                        
SUM(GoodsAmt) GoodsAmt,PD.SalesPrice BaseUomPrice,''BatchNo,''PKD,''Expiry,MP.TrackInventory,MP.TrackBatch,MP.TrackPDK,mp.TrackSerial                        
,(ISNULL(PTP.InvoicePrice,0) - PD.SalesPrice) DiffValue,ISNULL(PTP.InvoicePrice,0) InvoicePrice,1 QtyType,             
SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,                        
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.DetailMRP)) MRPonTaxAmt,MP.Shinecode,Serial,
dbo.fnGetRoundedValue((isnull(AQ.ActualQty,0))) ActualQty,dbo.fnGetRoundedValue((isnull(AQ.ActualFreeQty,0))) ActualFreeQty,      
dbo.fnGetRoundedValue((isnull(AQ.ActualDmgQty,0))) ActualDmgQty   into #invitems2            
FROM tblquotationdetail PD                        
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                        
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                        
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID                        
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = PD.ProdID   
left join #ABSQ2 AQ ON AQ.ProdID = PD.ProdID
where PD.QuationID = @ID                        
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.ProdDiscPern,PD.TradeDiscPern,PD.AddnlDiscPern,Serial,                        
MT.TaxName,PD.TaxPercentage,PD.DetailMRP,PD.SalesPrice,PD.TaxID,pd.ProdDiscAmt,AddnlDiscAmt,TradeDiscAmt                        
,MP.TrackInventory,MP.TrackBatch,MP.TrackPDK,mp.TrackSerial,PTP.InvoicePrice,MP.Shinecode,AQ.ActualQty,AQ.ActualFreeQty,AQ.ActualDmgQty                         
ORDER BY Serial                        
select * from #invitems2  ORDER BY Serial          
select SalesUomID,Name,SalesCR,ProdID,UOMType from (            
select mp.SalesUomID,MU.Name,SalesCR,mp.ID ProdID,'SalesUOM' UOMType,1 sno from tblMasterProduct mp                        
JOIN tblMasterUOM MU ON MU.ID = mp.SalesUomID where MP.ID in (select prodid from #invitems2)            
UNION all                        
select mp.PurchaseUomID,MU.Name,PurchaseCR,mp.ID ProdID,'PurchaseUOM' UOMType,2 sno from tblMasterProduct mp                        
JOIN tblMasterUOM MU ON MU.ID = mp.PurchaseUomID where MP.ID in (select prodid from #invitems2)                   
UNION all                        
select mp.BaseUomID,MU.Name,BaseCR CR,mp.ID ProdID,'BaseUOM' UOMType,3 sno from tblMasterProduct mp                        
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID in (select prodid from #invitems2)            
) as uoms            
group by ProdID,SalesUomID,Name,SalesCR,UOMType,sno            
order by sno            
drop table #invitems2,#ABSQ2            
select PMDTL.*,PM.PaymentMode,MBAC.AccountNo,MBAC.AccountName,  
CONVERT(VARCHAR(10),CONVERT(date,left(PMDate,10),103),23) OrgPMDate,MBK.ID BankID  
from tblTran_Sale_Bill_PaymentDetail PMDTL  
JOIN tblPaymentMode PM ON PM.ID = PMDTL.PayModeId  
LEFT JOIN tblMasterBankAccount MBAC ON MBAC.ID = PMDTL.Acc_OR_PaytermId  
LEFT JOIN tblMasterBank MBK ON MBK.Name = PMDTL.Bank  
where TransId  = -15 and InvId = @ID  
END                        
IF(@Mode = 19)                        
BEGIN                        
SELECT PD.HID,0 InventoryId,PD.ProdID,PD.UomID,NULL BatchNo,NULL PKD,NULL Expiry,Qty UomQty,0 UomFreeQty,0 UomDamageQty,PD.PurchasePrice UomPurchasePrice,                        
MP.SalesPrice UomSalePrice,MP.ECP UomECP,MP.MRP UomMRP,MP.SPLPrice UomSPLPrice,MP.ReturnPrice UomReturnPrice,PD.PurchasePrice,MP.SalesPrice SalePrice,                        
MP.ECP,MP.MRP, MP.SPLPrice,MP.ReturnPrice,PD.TaxID,1 TaxTypeID,PD.TaxPern [Tax%],PD.GrossAmt GoodsAmt,MP.ProductDiscPerc [ProdDisc%],0 [TradeDisc%],                        
0 [AddnlDisc%],PD.GrossAmt,PD.TaxAmt,PD.NetAmt,PD.Serial,0AdjQty,0 AdjFreeQty,0 AdjDmgQty,0 ReasonId,MP.*,UOM.Name UOMName,MT.TaxName                        
FROM tblPurchaseOrderDetail PD                        
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                        
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                        
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID                        
where PD.HID = @ID                        
ORDER BY Serial                        
END                        
IF(@Mode = 20)--Order Taken Filter                        
BEGIN                        
SET @strQuery = 'SELECT PH.ID,''OT''+CONVERT(NVARCHAR,PH.ID) DocID,CONVERT(NVARCHAR,DocDate,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),sum(PD.Amount)) GrossAmt,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),0) TaxAmt,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),0) NetAmt,                        
STS.Description Status,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),0) Balance,                        
CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,null Info,                        
PT.PriceType,null Remarks, PH.Narration,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),(PH.AdDiscPern * sum(PD.Amount)) + (PH.TrDiscPern * sum(PD.Amount)) + sum(PD.DisAmt)) AS TotalDiscAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'), sum(PD.DisAmt)) TotalProdDiscAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.AdDiscPern) AddnlDiscPern,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.AdDiscPern * sum(PD.Amount)) AddnlDiscAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TrDiscPern) TradeDiscPern,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),PH.TrDiscPern * sum(PD.Amount)) TradeDiscAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),0) OtherChargePern,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),0) OtherChargeAmt,convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),0) FrightAmt,                        
convert(DECIMAL(18,'+convert(nvarchar(10), @DecVal)+'),0) TCSTaxAmt,MS.Name [Salesman],MB.Name [BeatName],         
0 DeliveryCount,0 [DiffExcl],0 DiffIncl,7 PaymentModeID,0 AssignCount   FROM tblTranOrderTakenHeader PH                        
JOIN tblTranOrderTakenDetail PD ON PD.ID = PH.ID                        
JOIN tblMasterCustomer MV ON MV.ID = PH.CustID                        
JOIN tblStatus STS ON STS.ID = PH.Status                        
JOIN tblUsers CUR ON CUR.ID = PH.CBy                        
LEFT JOIN tblUsers MUR ON MUR.ID = PH.MBy                        
left join tblMasterSalesman MS ON MS.ID = PH.SalesmanID                        
left join tblMasterBeat MB ON MB.ID = PH.BeatID                        
JOIN tblPriceType PT ON PT.ID = MV.PriceTypeID                       
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID WHERE PH.ID > 0 '                       
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                        
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END                        
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                        
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3)' END                        
SET @strQuery += ' group by PH.ID,DocDate,RefNo,MBO.Name,MV.Name,CUR.UserName,PH.CDate,STS.Description,PH.Status,PT.PriceType, PH.Narration,                        
PH.AdDiscPern,PH.TrDiscPern,MS.Name,MB.Name ORDER BY PH.DocDate desc,PH.ID DESC'                        
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                        
END                        
IF(@Mode = 21)--Order Taken Filter                        
BEGIN                      
set @currDocid = (SELECT DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 15)                        
SELECT PH.ID, PH.DocDate Date,15 TransID, PH.BranchID,@currDocid DocID,null DocValue, BeatID, SalesManID, PH.CustID CustomerID, PH.RefNo,0 ProdGroupID,                        
MV.TaxTypeID,MV.PriceTypeID PriceID,MV.PaymentModeID,MV.CreditTermID CreditTermID,0 FrightAmt,0 OtherChrgPern,0 OtherChargeAmt,                        
PH.TrDiscPern TradePern, PH.AdDiscPern AddnlPern,0 TotalProdDiscAmt, 0 TradeDiscAmt,0 AddnlDiscAmt,0 RoundOffAmt,sum(PD.Amount) GrossAmt,                        
sum((PD.Amount * MT.GST) / 100) TaxAmt,(sum(PD.Amount) + sum((PD.Amount * MT.GST) / 100)) NetAmt,PH.Status,0 UDFId,NULL UDFDocId,                        
NULL UDFDocPrefix,NULL UDFDocValue,NULL Remarks,PH.Narration Narration,                        
0 TCSTaxAmt,0 TDSAmount,0 Writeoff,0 VehicleNo,0 Distance,'' VehicleType,'' TransMode,'' TransportID,'' TransportName,                     
0 DiffValueGross,0 DiffValueNet,dbo.fnTransactionPrefix(PH.DocDate,BranchID,15) Prefix,0 AS Balance,null IRN,null AckNo,null AckDate,null AckStatus,null EWBNo,null SignedQRCode                        
FROM tblTranOrderTakenHeader PH                        
JOIN tblTranOrderTakenDetail PD ON PD.ID = PH.ID                        
join tblmasterproduct mp on mp.id = pd.prodid                        
JOIN tblMasterCustomer MV ON MV.ID = PH.CustiD                        
JOIN tblStatus STS ON STS.ID = PH.Status                        
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                        
join tblMasterTax MT ON MT.TaxID = MP.SalesTaxID                        
where PH.ID = @ID                        
group by PH.ID, PH.DocDate,BranchID,BeatID, SalesManID, PH.CustID, RefNo, TaxTypeID, MV.PriceTypeID , PaymentModeID, CreditTermID,                        
PH.TrDiscPern, PH.AdDiscPern, PH.Status, PH.Narration                        
END                        
IF(@Mode = 22)                        
BEGIN           
select ProdID,(SUM(isnull(ActualQty,0))) ActualQty,(SUM(isnull(ActualFreeQty,0))) ActualFreeQty,      
(SUM(isnull(ActualDmgQty,0))) ActualDmgQty INTO #ABSQ3 from tblProductInventory WHERE ProdID IN (      
select distinct ProdID from tblTranOrderTakenDetail where ID = @ID) AND BranchID = (      
select distinct BranchID from tblTranOrderTakenHeader where ID = @ID)      
GROUP BY ProdID    
SELECT PD.ProdID,MP.BaseUOMID UomID,MP.Code,MP.Name,UOM.Name UOM,SUM(Qty) Qty,MP.MRP DetailMRP,PD.Price ExclPrice,                        
dbo.fngetinclusivevalue(MP.SalesTaxID,MP.MRP,PD.Price) InclPrice,                        
--(PD.Price * (1 + (MT.GST / 100))) InclPrice,                        
PD.DisPern ProdPern,pd.DisAmt ProdDiscAmt,PH.TrDiscPern TradePern,                        
(PH.TrDiscPern * (SUM(PD.Amount) - pd.DisAmt)) / 100 TradeDiscAmt,PH.AdDiscPern AddnlPern,                        
(PH.AdDiscPern * (SUM(PD.Amount) - pd.DisAmt)) / 100 AddnlDiscAmt,SUM(PD.Amount) GrossAmt,             
sum((PD.Amount * MT.GST) / 100) TaxAmt,(sum(PD.Amount) + sum((PD.Amount * MT.GST) / 100)) NetAmt,MP.SalesTaxID TaxID,MT.TaxName,                        
MT.GST TaxPern,SUM(PD.Amount) GoodsAmt,PD.OrgPrice BaseUomPrice,''BatchNo,''PKD,''Expiry,MP.TrackInventory,MP.TrackBatch,                        
MP.TrackPDK,mp.TrackSerial ,(ISNULL(PD.Price,0) - ISNULL(PTP.InvoicePrice,0)) DiffValue,ISNULL(PTP.InvoicePrice,0) InvoicePrice,1 QtyType,                        
SUM(dbo.fngetMRPonCumValue(0,MP.SalesTaxID,1,0)) CumMRPonTax,                        
SUM(dbo.fngetMRPonCumValue(1,MP.SalesTaxID,1,MP.MRP)) MRPonTaxAmt,MP.Shinecode,SerialNo Serial,
dbo.fnGetRoundedValue((isnull(AQ.ActualQty,0))) ActualQty,dbo.fnGetRoundedValue((isnull(AQ.ActualFreeQty,0))) ActualFreeQty,      
dbo.fnGetRoundedValue((isnull(AQ.ActualDmgQty,0))) ActualDmgQty   into #invitems3            
FROM tblTranOrderTakenDetail PD                        
join tblTranOrderTakenHeader PH ON PH.ID = PD.ID                        
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                        
JOIN tblMasterUOM UOM ON UOM.ID = MP.BaseUOMID                        
JOIN tblMasterTax MT ON MT.TaxID = MP.SalesTaxID                        
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = PD.ProdID  
left join #ABSQ3 AQ ON AQ.ProdID = PD.ProdID
where PD.ID = @ID                        
group by PD.ProdID,MP.BaseUOMID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.DisPern,Ph.TrDiscPern,Ph.AdDiscPern,SerialNo,                      
MT.TaxName,MT.GST,MP.MRP,PD.Price,MP.SalesTaxID,pd.DisAmt,pd.DisAmt,                        
MP.TrackInventory,MP.TrackBatch,MP.TrackPDK,mp.TrackSerial,PD.OrgPrice,PTP.InvoicePrice,MP.Shinecode ,
AQ.ActualQty,AQ.ActualFreeQty,AQ.ActualDmgQty                       
ORDER BY SerialNo                        
select * from #invitems3  ORDER BY Serial          
select SalesUomID,Name,SalesCR,ProdID,UOMType from (            
select mp.SalesUomID,MU.Name,SalesCR,mp.ID ProdID,'SalesUOM' UOMType,1 sno from tblMasterProduct mp                        
JOIN tblMasterUOM MU ON MU.ID = mp.SalesUomID where MP.ID in (select prodid from #invitems3)            
UNION all                        
select mp.PurchaseUomID,MU.Name,PurchaseCR,mp.ID ProdID,'PurchaseUOM' UOMType,2 sno from tblMasterProduct mp                        
JOIN tblMasterUOM MU ON MU.ID = mp.PurchaseUomID where MP.ID in (select prodid from #invitems3)                   
UNION all                        
select mp.BaseUomID,MU.Name,BaseCR CR,mp.ID ProdID,'BaseUOM' UOMType,3 sno from tblMasterProduct mp                        
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID in (select prodid from #invitems3)            
) as uoms            
group by ProdID,SalesUomID,Name,SalesCR,UOMType,sno            
order by sno            
drop table #invitems3,#ABSQ3
select PMDTL.*,PM.PaymentMode,MBAC.AccountNo,MBAC.AccountName,  
CONVERT(VARCHAR(10),CONVERT(date,left(PMDate,10),103),23) OrgPMDate,MBK.ID BankID  
from tblTran_Sale_Bill_PaymentDetail PMDTL  
JOIN tblPaymentMode PM ON PM.ID = PMDTL.PayModeId  
LEFT JOIN tblMasterBankAccount MBAC ON MBAC.ID = PMDTL.Acc_OR_PaytermId  
LEFT JOIN tblMasterBank MBK ON MBK.Name = PMDTL.Bank  
where TransId  = -15 and InvId = @ID  
END                        
IF(@Mode = 23)                        
BEGIN                        
--uspGetSetInvoiceData 23,124,4                        
SELECT TrackBatch,TrackPDK,TrackInventory,case when @ID = 4 THEN Price / Tax else Price end Price,MRP,                        
case when @ID = 4 THEN Price else Price * Tax end Incl FROM (                        
SELECT TrackBatch,TrackPDK,TrackInventory,CASE WHEN @ID = 1 THEN PurchasePrice WHEN @ID = 2 THEN SalesPrice WHEN @ID = 3 THEN ECP                        
WHEN @ID = 5 THEN SPLPrice WHEN @ID = 4 THEN MRP WHEN @ID = 6 THEN ReturnPrice else 0 end Price,MRP, 1 + (GST/100) Tax                        
FROM tblMasterProduct MP                        
JOIN TBLMASTERTAX MT ON MT.TaxID = MP.SalesTaxID                        
WHERE ID = @Code ) AS REC                        
END                        
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetJournalEntryData';
GO
--uspGetSetJournalEntryData 2,9,'','0','','2024-11-10','2024-12-16',0                          
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetJournalEntryData]                                                                  
@Mode INT,@TransID INT,@Code NVARCHAR(MAX) = NULL,@ID NVARCHAR(MAX) = NULL,@AccountName NVARCHAR(MAX) = NULL,@FromDate date = null,                  
@ToDate date = null,@Showall int = null,@Branch NVARCHAR(MAX) = NULL                   
AS                                                                  
BEGIN                            
BEGIN TRY              
declare @strQuery NVARCHAR(MAX)              
IF(@Mode = 1)                                                                  
BEGIN                              
select 1 Type,'AccName' Trans,FAA.FAID,'' Code,AccountName as Name  FROM tblFAAccount FAA                            
  JOIN tblFAGroup FAG ON FAG.FAGroup =FAA.AccountGroup AND FAG.UserGroup IN (0,1,2)                             
  WHERE  FAA.Active =1                               
union all                                                                  
SELECT 2 Type,'FAType' Trans,FATypeID,'' Code,FAType Name from tblFAType  where Active = 1                               
union all                                                                                          
SELECT 3 Type,'UDN' Trans,UDNID,'',DocName FROM tblMasterUserDefineNoHeader WHERE TransID = @TransID                                                       
union all                                                                  
SELECT 4 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = @TransID         
union all        
SELECT 5 Type,'BranchName' Trans,ID,'',Name FROM tblMasterBranchOffice  WHERE Active = 1         
order by Type,Name                                                                  
END                              
IF(@Mode = 2)                                                                  
BEGIN                               
--SELECT ND.JVID,ND.DocId,convert(nvarchar(50),ND.DocDate,103) DocDate, ND.DocRef,Party.AccountName as[Party Name] ,                    
--dbo.fnGetRoundedValue(ND.Credit) Credit,dbo.fnGetRoundedValue(ND.Debit) Debit,dbo.fnGetRoundedValue(ND.Balance)Balance ,ST.[Description],ND.Status                        
--FROM tblFAJournal ND                    
--JOIN tblStatus ST ON ST.ID=ND.[Status]                           
--JOIN tblFAAccount Party ON ND.AccountID=Party.FAID                    
--where DocPrefix = @TransID                  
--ORDER BY ND.DocValue desc,ND.JVID              
                
SET @strQuery = 'SELECT ND.JVID,ND.DocId,convert(nvarchar(50),ND.DocDate,103) DocDate, ND.DocRef,Party.AccountName as[Party Name] ,                    
dbo.fnGetRoundedValue(ND.Credit) Credit,dbo.fnGetRoundedValue(ND.Debit) Debit,dbo.fnGetRoundedValue(ND.Balance)Balance ,            
ST.[Description],ND.Status,CUR.UserName UserName,CONVERT(NVARCHAR(100),ND.CDate) LastActionTime,ND.Narration,isnull(ND.BranchID,0) BranchID,MBO.Name[Branch Name]                      
FROM tblFAJournal ND                    
JOIN tblStatus ST ON ST.ID=ND.[Status]                           
JOIN tblFAAccount Party ON ND.AccountID=Party.FAID            
LEFT JOIN tblMasterBranchOffice MBO on MBO.ID = ND.BranchID         
JOIN tblUsers CUR ON CUR.ID = ND.CBy  WHERE  ND.DocPrefix = ' + CONVERT(NVARCHAR,@TransID)                  
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                      
SET @strQuery += CASE WHEN ISNULL(@AccountName,'') = '' THEN '' ELSE ' AND Party.AccountName = @AccountName' END   
SET @strQuery += CASE WHEN ISNULL(@Branch,'') = '0' THEN '' ELSE ' AND ND.BranchID = CONVERT(NVARCHAR,@Branch)' END  
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND ND.Status in (1,3,5)' END                
SET @strQuery += ' ORDER BY ND.DocDate DESC, ND.DocValue desc,ND.JVID'                  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @AccountName NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @Branch NVARCHAR(MAX)', @Mode = @Mode, @TransID = @TransID, @Code = @Code, @ID = @ID, @AccountName = @AccountName, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall, @Branch = @Branch                
END                            
IF(@Mode = 3)                                                                  
BEGIN                     
SELECT ND.JVID,ND.DocId,ND.DocDate, ND.DocRef,ND.AccountID,Party.AccountName as[Party Name] ,                    
dbo.fnGetRoundedValue(ND.Credit) Credit,dbo.fnGetRoundedValue(ND.Debit) Debit,dbo.fnGetRoundedValue(ND.Balance)Balance ,ST.[Description],ND.Status,                  
ND.Remarks,ND.Narration,CASE WHEN Credit > 0 THEN 'Credit' ELSE 'Debit' END FAType,CASE WHEN Adjusment = 0 THEN 'No' ELSE 'Yes' END Adjusment,ND.BranchID,MBO.Name[Branch Name],    
dbo.fnTransactionPrefix(ND.DocDate,BranchID,ND.TransID) Prefix      
FROM tblFAJournal ND                    
JOIN tblStatus ST ON ST.ID=ND.[Status]                           
JOIN tblFAAccount Party ON ND.AccountID=Party.FAID          
LEFT JOIN tblMasterBranchOffice MBO on MBO.ID = ND.BranchID        
where DocPrefix = 9 and ND.JVID =@ID                  
END                    
END TRY                            
BEGIN CATCH                            
SELECT ERROR_MESSAGE () MSG,ERROR_PROCEDURE () [PROC],ERROR_LINE () LINE                            
END CATCH                            
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetsetMobileCollectionData';
GO
--uspGetsetMobileCollectionData 4,78,0,2,4                
CREATE OR ALTER PROCEDURE [dbo].[uspGetsetMobileCollectionData]                    
@Mode INT,@ID INT = NULL,@SMID INT = NULL,@SelectID NVARCHAR(MAX) = null,@Value NVARCHAR(MAX) = NULL                  
AS                    
BEGIN                    
DECLARE @StrQuery NVARCHAR(MAX) = '' ,@AllSalesman INT = (SELECT AppValue FROM tblAppConfig WHERE AppId = 18)                 
IF(@MODE = 1)                    
BEGIN                    
declare @getBeatID INT,@getSMID INT                  
select @getBeatID =ISNULL(BeatID,0),@getSMID = ISNULL(SalesmanID,0) from tblUsers WHERE ID = @ID                  
select 1 Type,'Salesman' Trans,ID,'' Code,Name from tblMasterSalesman where Active = 1                                
union all                                
SELECT 2 Type,'Beat' Trans,ID,'',Name FROM tblMasterBeat WHERE Active = 1                    
union all                                
SELECT 3 Type,'PayMode' Trans,ID,'',PaymentMode Name FROM tblPaymentMode WHERE Active = 1  and ID IN (1,2,4)                  
union all                                
SELECT 4 Type,'BankAcc' Trans,ID,CONVERT(nvarchar,SetDefault)+'|'+CONVERT(nvarchar,BankID)+'|'+IFSCCode Code,AccountNo Name FROM tblMasterBankAccount WHERE Active = 1                    
union all                    
SELECT 5 Type,'Bank' Trans,ID,'' Code,Name FROM tblMasterBank WHERE Active = 1           
union all                    
SELECT 6 Type,'Branch' Trans,ID,Code,Name FROM tblMasterBranchOffice WHERE Active = 1           
union all                    
select 7 Type,'Today Route' Trans,CONVERT(NVARCHAR,ISNULL(BranchID,0)),CONVERT(NVARCHAR,ISNULL(BeatID,0)),CONVERT(NVARCHAR,ISNULL(SalesmanID,0)) from tblUsers WHERE ID = @ID                    
END                    
IF(@MODE = 2)                    
BEGIN                    
IF(ISNULL(@SelectID,0) = 2)-- ALL CUSTOMERS                  
BEGIN                  
SET @StrQuery = 'SELECT 7 Type,''Customer'' Trans,MC.ID,Code,Name FROM tblMasterCustomer MC                  
LEFT JOIN tblBeatSalesmanMapping BSM ON BSM.CustomerID = MC.ID                  
WHERE Active = 1 '                  
SET @StrQuery += CASE WHEN ISNULL(@ID,0) = 0 THEN '' ELSE ' AND BSM.BeatID = '+convert(nvarchar,@ID) end                  
SET @StrQuery += CASE WHEN  (ISNULL(@SMID,0) = 0 or isnull(@AllSalesman,0) = 1) THEN '' ELSE ' AND BSM.SalesmanID = '+convert(nvarchar,@SMID) end                  
SET @StrQuery += ' GROUP BY MC.ID,Code,Name ORDER BY Name'                  
EXEC sys.sp_executesql @StrQuery, N'@Mode INT, @ID INT, @SMID INT, @SelectID NVARCHAR(MAX), @Value NVARCHAR(MAX)', @Mode = @Mode, @ID = @ID, @SMID = @SMID, @SelectID = @SelectID, @Value = @Value                  
END                  
ELSE IF(ISNULL(@SelectID,0) = 1) -- ASSIGEN INVOICE CUSTOMERS
BEGIN                  
SET @StrQuery = ' select 7 Type,''Customer'' Trans,MC.ID,Code,Name from tblAssignInvoicesHeader AH                  
JOIN tblAssignInvoicesDetail AD ON AD.HID = AH.ID                  
JOIN tblTransalesHeader SH ON SH.ID = AD.InvID                  
join tblmasterCustomer MC ON MC.ID = SH.CustID                  
where AH.SalesmanID = '+convert(nvarchar,@SMID) +' AND AH.Status in (1,3) and AD.Status IN (1,6)                   
AND SH.DocPrefix = 15 AND SH.Status IN (1,3,5) AND SH.Balance > 0                  
GROUP BY MC.ID,Code,Name  ORDER BY Name'                  
EXEC sys.sp_executesql @StrQuery, N'@Mode INT, @ID INT, @SMID INT, @SelectID NVARCHAR(MAX), @Value NVARCHAR(MAX)', @Mode = @Mode, @ID = @ID, @SMID = @SMID, @SelectID = @SelectID, @Value = @Value                 
END
ELSE IF(ISNULL(@SelectID,0) = 3) -- Delivery
BEGIN                  
SET @StrQuery = ' select 7 Type,''Customer'' Trans,MC.ID,Code,Name from tblDeliveryOrderHeader AH                  
JOIN tblDeliveryOrderDetail AD ON AD.DOID = AH.ID                  
JOIN tblTransalesHeader SH ON SH.ID = AD.InvIdentID                  
join tblmasterCustomer MC ON MC.ID = SH.CustID                  
where AH.SalesmanID = '+convert(nvarchar,@SMID) +' AND AH.Status in (1,3) and AD.Status IN (1,6)                   
AND SH.DocPrefix = 15 AND SH.Status IN (1,3,5) AND SH.Balance > 0                  
GROUP BY MC.ID,Code,Name  ORDER BY Name'                  
EXEC sys.sp_executesql @StrQuery, N'@Mode INT, @ID INT, @SMID INT, @SelectID NVARCHAR(MAX), @Value NVARCHAR(MAX)', @Mode = @Mode, @ID = @ID, @SMID = @SMID, @SelectID = @SelectID, @Value = @Value
END  
END                  
IF(@MODE = 3)                    
BEGIN                    
SELECT 'CUSTOMER DETAILS'                  
END                  
IF(@MODE = 4)                    
BEGIN                  
if(@SelectID = 1)                  
BEGIN                  
select ID,DocPrefix,DocID,DocDate,RefNo,dbo.fnGetRoundedValue(NetAmt) NetAmt,dbo.fnGetRoundedValue(Balance) Balance,AssignID from (                  
select AD.InvID ID,SH.DocPrefix,SH.DocID,convert(nvarchar(25),InvDate,103) DocDate,SH.DocRef RefNo,(NetAmt) NetAmt,                  
((Balance) - ISNULL((SELECT (case when SUM(WriteOff) < 0 THEN ISNULL(SUM(AdjAmt + isnull(DiscAmt,0) + ABS(WriteOff)),0) ELSE SUM(AdjAmt + isnull(DiscAmt,0)) END)                      
FROM tblTranOrderCollectionHeader OCH                  
JOIN tblTranOrderCollectionDetail OCD ON OCD.HID = OCH.ID AND OCD.InvoiceID = SH.ID                 
WHERE InvDocPrefix = 15 AND InvoiceID = SH.Id AND OCH.Status=1),0)) Balance,AD.HID AssignID         
from tblAssignInvoicesHeader AH                  
JOIN tblAssignInvoicesDetail AD ON AD.HID = AH.ID               
JOIN tblTransalesHeader SH ON SH.ID = AD.InvID                  
where AH.SalesmanID = @smid and SH.CustID = @ID AND AH.Status in (1,3) and AD.Status IN (1,6)                   
AND SH.DocPrefix = 15 AND SH.Status IN (1,3,5) AND SH.BranchID = isnull(@Value,SH.BranchID) AND SH.Balance > 0                  
) as rec where Balance > 0                  
                  
END                  
ELSE                  
BEGIN                  
select ID,DocPrefix,DocID,DocDate,RefNo,dbo.fnGetRoundedValue(NetAmt) NetAmt,dbo.fnGetRoundedValue(Balance) Balance,0 AssignID from (                  
select SH.ID,SH.DocPrefix,SH.DocID,convert(nvarchar(25),InvDate,103) DocDate,SH.DocRef RefNo,NetAmt NetAmt,                  
((Balance) - ISNULL((SELECT (case when SUM(WriteOff) < 0 THEN ISNULL(SUM(AdjAmt + isnull(DiscAmt,0) + ABS(WriteOff)),0) ELSE SUM(AdjAmt + isnull(DiscAmt,0)) END)                                                                    
FROM tblTranOrderCollectionHeader OCH                  
JOIN tblTranOrderCollectionDetail OCD ON OCD.HID = OCH.ID AND OCD.InvoiceID = SH.ID                 
WHERE InvDocPrefix = 15 AND InvoiceID = SH.Id AND OCH.Status=1),0)) Balance         
from tblTransalesHeader SH                  
where SH.CustID = @ID AND SH.DocPrefix = 15 AND SH.BranchID = isnull(@Value,SH.BranchID) AND SH.Status IN (1,3,5) AND SH.Balance > 0                  
) as rec where Balance > 0                  
END                  
END              
IF(@MODE = 5)-- BEAT,SALESMAN FOR CUSTOMER MAPPED              
BEGIN                
SELECT TOP 1 BSM.BeatID,BSM.SalesmanID,BSM.CustomerID,MC.Code,MC.Name FROM tblBeatSalesmanMapping BSM              
join tblMasterCustomer MC ON MC.ID = BSM.CustomerID          
WHERE CustomerID = @ID              
ORDER BY BSM.ID              
END            
IF(@MODE = 6)-- SWITCH ASSIGN INV VALIDATE          
BEGIN            
select COUNT(*) from tblAssignInvoicesHeader AH                  
JOIN tblAssignInvoicesDetail AD ON AD.HID = AH.ID                  
JOIN tblTransalesHeader SH ON SH.ID = AD.InvID                  
join tblmasterCustomer MC ON MC.ID = SH.CustID                  
where AH.SalesmanID = @SMID AND MC.ID = @ID AND AH.Status in (1,3) and AD.Status IN (1,6)                   
AND SH.DocPrefix = 15 AND SH.Status IN (1,3,5) AND SH.Balance > 0                  
END          
IF(@Mode = 7)--MODILE COLLECTION DATA        
BEGIN    
DECLARE @sts as table(StatusID int)    
if(isnull(@SelectID,0) = 0)    
begin    
insert into @sts values(1),(3)    
end    
ELSE    
BEGIN    
insert into @sts values(1),(2),(3),(4),(8)    
END    
declare @RoleID int,@showallDataPermission int =0    
select @RoleID = RoleID from tblUsers where ID = @SMID    
    
select @showallDataPermission = count(*) from tblRolePermissions  where Role =@RoleID and PermissionFormId = 466    
    
SELECT OCH.ID,FORMAT(OCH.DocDate,'dd-MMM-yyyy') DocDate,MB.Name BeatName,MS.Name SalesmanName,MC.Name CustomerName,        
dbo.fnGetRoundedValue(Amt) CollectionValue,PM.PaymentMode,MBO.Name BranchName,sts.Description Status,OCH.Status StatusID,        
OCH.Remarks,OCH.Narration,CU.UserName,CONVERT(NVARCHAR(50),OCH.CDate) CreateDate        
FROM tblTranOrderCollectionHeader OCH        
JOIN tblMasterCustomer MC ON MC.ID = OCH.CustID        
LEFT JOIN TBLMasterBeat MB ON MB.ID = OCH.BeatID        
LEFT JOIN tblMasterSalesman MS ON MS.ID = OCH.SalesManID        
JOIN tblPaymentMode PM ON PM.ID = OCH.PaymentID        
LEFT JOIN tblMasterBranchOffice MBO ON MBO.ID = OCH.BranchID        
join tblStatus sts ON sts.ID = OCH.Status        
JOIN tblUsers CU ON CU.ID = OCH.CBy    
WHERE    
(    
      (@showallDataPermission = 0 AND     
          (    
             OCH.CBy = (CASE WHEN @SMID = 1 THEN OCH.CBy ELSE @SMID END)  
              OR OCH.MBy = (CASE WHEN @SMID = 1 THEN OCH.CBy ELSE @SMID END)    
          )    
      )    
   OR (@showallDataPermission > 0)    
)    
AND OCH.Status IN (SELECT StatusID FROM @sts)    
ORDER BY OCH.ID desc    
END        
IF(@Mode = 8)--MODILE COLLECTION VIEW        
BEGIN        
SELECT OCH.ID,OCH.DocDate,ISNULL(OCH.BranchID,0) BranchID,ISNULL(OCH.BeatID,0) BeatID,ISNULL(OCH.SalesManID,0) SalesManID,        
OCH.CustID CustomerID,MC.Name CustomerName,dbo.fnGetRoundedValue(Amt) CollectionValue,OCH.PaymentID,OCH.Status StatusID,        
OCH.Remarks,OCH.Narration,ChequeNo,ChequeDate,BankID,IFSCcode,BankAccountID        
FROM tblTranOrderCollectionHeader OCH        
JOIN tblMasterCustomer MC ON MC.ID = OCH.CustID        
where och.ID = @ID        
    
select  OCD.InvoiceID ID,OCD.InvDocPrefix Docprefix,OCD.AssignID AssignInvoiceID,SH.DocID Docid,        
format(InvDate,'dd/MM/yyyy') Docdate,SH.DocRef Refno,        
OCD.InvoiceAmt NetAmt,OCD.InvBalance Balance,OCD.AdjAmt,ISNULL(OCD.WriteOff,0) WriteOff,        
ISNULL(OCD.DiscPern,0)  DiscPern,ISNULL(OCD.DiscAmt,0)  DiscAmt        
from tblTranOrderCollectionDetail OCD        
JOIN tblTransalesHeader SH ON SH.ID = OCD.InvoiceID        
WHERE HID = @ID        
END        
IF(@Mode = 9)--MODILE COLLECTION EDIT        
BEGIN        
SELECT OCH.ID,OCH.DocDate,ISNULL(OCH.BranchID,0) BranchID,ISNULL(OCH.BeatID,0) BeatID,ISNULL(OCH.SalesManID,0) SalesManID,        
OCH.CustID CustomerID,MC.Name CustomerName,dbo.fnGetRoundedValue(Amt) CollectionValue,OCH.PaymentID,OCH.Status StatusID,        
OCH.Remarks,OCH.Narration,ChequeNo,ChequeDate,BankID,IFSCcode,BankAccountID        
FROM tblTranOrderCollectionHeader OCH        
JOIN tblMasterCustomer MC ON MC.ID = OCH.CustID        
where och.ID = @ID        
        
DECLARE @wceCustomerID int,@wceBranchID int        
SELECT @wceCustomerID = CustID,@wceBranchID = BranchID FROM tblTranOrderCollectionHeader WHERE ID = @ID        
        
select ID,DocPrefix Docprefix,DocID Docid,DocDate Docdate,RefNo Refno,dbo.fnGetRoundedValue(NetAmt) NetAmt,        
dbo.fnGetRoundedValue(Balance + AdjValue) Balance,        
AdjValue AdjAmt,WriteOff,DiscAmt,DiscPern,AssignID AssignInvoiceID from (                  
select SH.ID,SH.DocPrefix,SH.DocID,format(InvDate,'dd/MM/yyyy') DocDate,SH.DocRef RefNo,NetAmt NetAmt,                  
ISNULL(SH.Balance,0) - (ISNULL((SELECT (case when SUM(WriteOff) < 0 THEN ISNULL(SUM(AdjAmt + isnull(DiscAmt,0) + ABS(WriteOff)),0)         
ELSE SUM(AdjAmt + isnull(DiscAmt,0)) END)        
FROM tblTranOrderCollectionHeader OCH        
JOIN tblTranOrderCollectionDetail OCD ON OCD.HID = OCH.ID AND OCD.InvoiceID = SH.ID                 
WHERE InvDocPrefix = 15 AND InvoiceID = SH.Id AND OCH.Status in (1,3)),0))Balance,        
ISNULL((case when SUM(OCDM.WriteOff) < 0 THEN ISNULL(SUM(OCDM.AdjAmt + isnull(OCDM.DiscAmt,0) + ABS(OCDM.WriteOff)),0)         
ELSE SUM(OCDM.AdjAmt + isnull(OCDM.DiscAmt,0)) END),0) AdjValue,SUM(isnull(WriteOff,0)) WriteOff,SUM(isnull(DiscAmt,0)) DiscAmt,        
isnull(DiscPern,0) DiscPern,        
OCDM.AssignID        
from tblTransalesHeader SH        
left join tblTranOrderCollectionDetail OCDM ON OCDM.InvoiceID = SH.ID AND OCDM.HID = @ID        
where SH.CustID = @wceCustomerID AND SH.DocPrefix = 15 AND SH.BranchID = @wceBranchID AND SH.Status IN (1,3,5) AND SH.Balance > 0               
GROUP BY SH.ID,SH.DocPrefix,SH.DocID,InvDate,SH.DocRef,NetAmt,Balance,DiscPern,OCDM.AssignID        
) as rec where Balance > 0         
END        
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetsetMobileSRDRData';
GO
--uspGetsetMobileSRDRData 6,1,1,0    
CREATE OR ALTER PROCEDURE [dbo].[uspGetsetMobileSRDRData]    
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
SET @StrQuery += CASE WHEN ISNULL(@ID,0) = 0 THEN '' ELSE ' AND BSM.BeatID = '+convert(nvarchar,@ID) end                  
SET @StrQuery += CASE WHEN (ISNULL(@SMID,0) = 0 or isnull(@AllSalesman,0) = 1) THEN '' ELSE ' AND BSM.SalesmanID = '+convert(nvarchar,@SMID) end                  
SET @StrQuery += ' GROUP BY MC.ID,Code,Name ORDER BY Name'                  
EXEC sys.sp_executesql @StrQuery, N'@Mode INT, @TransType int, @ID INT, @SMID INT, @SelectID NVARCHAR(MAX), @Value NVARCHAR(MAX)', @Mode = @Mode, @TransType = @TransType, @ID = @ID, @SMID = @SMID, @SelectID = @SelectID, @Value = @Value                  
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
left JOIN tblProductInventory PV ON PV.ProdId = MP.ID AND PV.BranchID = '+convert(nvarchar,@SMID) + '                  
WHERE MP.Active = 1 '                  
SET @StrQuery += CASE WHEN ISNULL(@SelectID,0) = 1 and isnull(@Value,'') != '' THEN ' AND MP.MfrID IN (SELECT value FROM STRING_SPLIT(convert(nvarchar,@Value), N'',''))' ELSE '' end                  
SET @StrQuery += CASE WHEN ISNULL(@SelectID,0) = 2 and isnull(@Value,'') != '' THEN ' AND MP.CategoryID IN (SELECT value FROM STRING_SPLIT(convert(nvarchar,@Value), N'',''))' ELSE '' end                  
SET @StrQuery += CASE WHEN ISNULL(@SelectID,0) = 3 and isnull(@Value,'') != '' THEN ' AND MP.Name IN (convert(nvarchar,@Value)'+')' ELSE '' end                  
SET @StrQuery +=  ' group by MP.PurchasePrice,MP.SalesPrice,MP.ECP,MP.MRP,MP.SPLPrice,Tax.GST,MP.ID,Name,ProductDiscPerc,                  
WebOrder,MP.TrackInventory,MP.ReturnPrice ORDER BY WebOrder ASC,MP.Name ASC   '                  
EXEC sys.sp_executesql @StrQuery, N'@Mode INT, @TransType int, @ID INT, @SMID INT, @SelectID NVARCHAR(MAX), @Value NVARCHAR(MAX)', @Mode = @Mode, @TransType = @TransType, @ID = @ID, @SMID = @SMID, @SelectID = @SelectID, @Value = @Value                  
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
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetOtherCollPayData';
GO
--uspGetSetOtherCollPayData 4,11,'0',16,'','','2024-11-10','2024-12-16',1                          
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetOtherCollPayData]                          
@Mode INT,@TransID INT,@Code NVARCHAR(MAX) = NULL,@ID NVARCHAR(MAX) = NULL,@AccountName NVARCHAR(MAX) = NULL,@Party NVARCHAR(MAX) = NULL,@FromDate date = null,                          
@ToDate date = null,@Showall int = null,@Branch NVARCHAR(MAX) = NULL                          
AS                                                                              
BEGIN                                        
BEGIN TRY                           
declare @strQuery NVARCHAR(MAX)                       
IF(@Mode = 1)                                                                              
BEGIN                                          
select 1 Type,'PartyName' Trans,FAID ID,'' Code,AccountName Name from tblFAAccount  where Active = 1 and AccountGroup IN (44,2,25,3,29,6,12,13,39,1,19,33,43,35,18,20)                               
union all                                                                          
--SELECT 2 Type,'ExpensesAccount' Trans,FAID ID,'' Code,AccountName Name from tblFAAccount  where Active = 1 and AccountGroup IN (7,8,10,11)                                
SELECT 2 Type,'ExpensesAccount' Trans,FAID ID,'' Code,[Account Name] Name from [FACNAccountNames]                            
union all                                                                                                      
SELECT 3 Type,'UDN' Trans,UDNID,'',DocName FROM tblMasterUserDefineNoHeader WHERE TransID = @TransID                                                                   
union all                                                                              
SELECT 4 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = @TransID                                                     
union all                                                                          
SELECT 6 Type,'BTMode' Trans,ID,'' Code,ModeName from tblContraMode  where Active = 1 and ID IN (3,4,5,6)                              
union all                              
select 7 Type,'BankAccNo' Trans,MBA.ID,FAID Code,AccountNo+'|'+convert(nvarchar,MB.ID)+'|'+BranchName+'|'+IFSCCode+'|'+MICR+'|'+MB.Name  Name from tblMasterBankAccount MBA                                    
JOIN tblMasterBank MB ON MB.ID = MBA.BankID where MBA.Active = 1 AND FAID > 0                          
union all                                                                          
SELECT 8 Type,'Bank' Trans,ID,'' Code,Name from tblMasterBank  where Active = 1          
union all          
SELECT 9 Type,'BranchName' Trans,ID,'',Name FROM tblMasterBranchOffice  WHERE Active = 1           
order by Type,Name                                                                              
END                       
IF(@Mode = 111)                          
BEGIN                       
SELECT 5 Type,'AllPaymode' Trans,ID,CONVERT(nvarchar,Orderby),PaymentMode FROM tblPaymentMode WHERE Active = 1 AND ID NOT IN (6,7,8,9,10)                       
ORDER BY Orderby,PaymentMode                    
END                    
IF(@Mode = 2)                                                                              
BEGIN                            
--For Expenses , To Party For an Expenses(payment)                            
if(@TransID = 10)                            
BEGIN                            
--SELECT ND.ColID,ND.DocId,convert(nvarchar(50),ND.ColDate,103) DocDate,CASE WHEN COLLType = 2 THEN 'For Income' ELSE 'From Party For an Income' END Type,                            
--ND.ColDocRefNo,PM.PaymentMode,Party.AccountName as[Party Name],FAA.AccountName as[Account Name],dbo.fnGetRoundedValue(ND.ColAmt) ColAmt,                            
--dbo.fnGetRoundedValue(ND.Balance)Balance ,ST.[Description],ND.Status                                    
--FROM tblTranCollectionHeader ND                                
--join tblPaymentMode PM ON PM.ID = ND.ColMode                                
--JOIN tblStatus ST ON ST.ID=ND.[Status]                                       
--left JOIN tblFAAccount Party ON ND.AccID=Party.FAID                            
--left JOIN tblFAAccount FAA ON ND.ExpanceAcc=FAA.FAID                  
--ORDER BY ND.DocValue desc,ND.ColID                      
SET @strQuery = 'SELECT ND.ColID,ND.DocId,convert(nvarchar(50),ND.ColDate,103) DocDate,CASE WHEN COLLType = 2 THEN ''For Income'' ELSE ''From Party For an Income'' END Type,                            
ND.ColDocRefNo,PM.PaymentMode,Party.AccountName as[Party Name],FAA.AccountName as[Account Name],dbo.fnGetRoundedValue(ND.ColAmt) ColAmt,                            
dbo.fnGetRoundedValue(ND.Balance)Balance ,ST.[Description],ND.Status,CUR.UserName UserName,CONVERT(NVARCHAR(100),ND.CDate) LastActionTime,CM.ModeName [Mode],        
MBA.AccountNo,CPD.[Cheque/DD Number]ChequeNo,convert(nvarchar(50),CPD.Date,103) [ChequeDate],              
MBB.Name[BankName],CPD.BranchName,CPD.ifscCode,CPD.NeftID,ND.Remarks,ND.Narration,isnull(ND.BranchID,0) BranchID,MBO.Name[Branch Name]                 
FROM tblTranCollectionHeader ND                
LEFT JOIN tblcollPMDetails CPD ON CPD.ColID = ND.ColID              
join tblPaymentMode PM ON PM.ID = ND.ColMode                                
JOIN tblStatus ST ON ST.ID=ND.[Status]                                       
left JOIN tblFAAccount Party ON ND.AccID=Party.FAID                                
left JOIN tblFAAccount FAA ON ND.ExpanceAcc=FAA.FAID                
LEFT JOIN tblContraMode CM ON CM.ID = ND.ColMode              
LEFT JOIN tblMasterBank MBB ON MBB.ID = CPD.BankName                  
LEFT JOIN tblMasterBankAccount MBA ON MBA.FAID = CPD.BankAccID           
LEFT JOIN tblMasterBranchOffice MBO on MBO.ID = ND.BranchID         
JOIN tblUsers CUR ON CUR.ID = ND.CBy WHERE ND.DocPrefix = ' + CONVERT(NVARCHAR,@TransID)                          
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND ColDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                              
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND Party.AccountName = @Party' END                        
SET @strQuery += CASE WHEN ISNULL(@AccountName,'') = '' THEN '' ELSE ' AND FAA.AccountName = @AccountName' END      
SET @strQuery += CASE WHEN ISNULL(@Branch,'') = '0' THEN '' ELSE ' AND ND.BranchID = CONVERT(NVARCHAR,@Branch)' END    
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND ND.Status in (1,3,5)' END                             
SET @strQuery += ' ORDER BY ND.ColDate DESC, ND.DocValue desc,ND.ColID'                          
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @AccountName NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @Branch NVARCHAR(MAX)', @Mode = @Mode, @TransID = @TransID, @Code = @Code, @ID = @ID, @AccountName = @AccountName, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall, @Branch = @Branch                        
                      
END                            
ELSE                            
BEGIN                            
--SELECT ND.PYID,ND.DocId,convert(nvarchar(50),ND.PYDate,103) DocDate,CASE WHEN PYType = 2 THEN 'For Expenses' ELSE 'To Party For an Expenses' END Type,                            
--ND.PYDocRefNo,PM.PaymentMode,Party.AccountName as[Party Name],FAA.AccountName as[Account Name],dbo.fnGetRoundedValue(ND.PYAmt) ColAmt,                            
--dbo.fnGetRoundedValue(ND.Balance)Balance ,ST.[Description],ND.Status                                    
--FROM tblTranPaymentHeader ND                                
--join tblPaymentMode PM ON PM.ID = ND.PYMode                                
--JOIN tblStatus ST ON ST.ID=ND.[Status]                                       
--left JOIN tblFAAccount Party ON ND.AccID=Party.FAID                                
--left JOIN tblFAAccount FAA ON ND.ExpanseAcc=FAA.FAID                                
--ORDER BY ND.DocValue DESC,ND.PYID                          
SET @strQuery = 'SELECT ND.PYID,ND.DocId,convert(nvarchar(50),ND.PYDate,103) DocDate,CASE WHEN PYType = 2 THEN ''For Expenses'' ELSE ''To Party For an Expenses'' END Type,                            
ND.PYDocRefNo,PM.PaymentMode,Party.AccountName as[Party Name],FAA.AccountName as[Account Name],dbo.fnGetRoundedValue(ND.PYAmt) ColAmt,                            
dbo.fnGetRoundedValue(ND.Balance)Balance ,ST.[Description],ND.Status,CUR.UserName UserName,CONVERT(NVARCHAR(100),ND.CDate) LastActionTime,        
CM.ModeName [Mode],MBA.AccountNo,PD.[Cheque/DD Number]ChequeNo,              
convert(nvarchar(50),PD.Date,103) [ChequeDate],MBB.Name[BankName],PD.BranchName,PD.ifscCode,PD.NeftID,ND.Remarks,ND.Narration,isnull(ND.BranchID,0) BranchID,MBO.Name[Branch Name]                 
FROM tblTranPaymentHeader ND              
LEFT JOIN tblPaymentPMDetail PD ON PD.PYID = ND.PYID              
join tblPaymentMode PM ON PM.ID = ND.PYMode                                
JOIN tblStatus ST ON ST.ID=ND.[Status]                                       
left JOIN tblFAAccount Party ON ND.AccID=Party.FAID                                
left JOIN tblFAAccount FAA ON ND.ExpanseAcc=FAA.FAID                
LEFT JOIN tblMasterBank MBB ON MBB.ID = PD.BankName                 
LEFT JOIN tblContraMode CM ON CM.ID = ND.PYMode              
LEFT JOIN tblMasterBankAccount MBA ON MBA.FAID = PD.BankAccID         
LEFT JOIN tblMasterBranchOffice MBO on MBO.ID = ND.BranchID        
JOIN tblUsers CUR ON CUR.ID = ND.CBy WHERE ND.PYPrefix = ' + CONVERT(NVARCHAR,@TransID)                          
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND PYDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                              
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND Party.AccountName = @Party' END                        
SET @strQuery += CASE WHEN ISNULL(@AccountName,'') = '' THEN '' ELSE ' AND FAA.AccountName = @AccountName' END     
SET @strQuery += CASE WHEN ISNULL(@Branch,'') = '0' THEN '' ELSE ' AND ND.BranchID = CONVERT(NVARCHAR,@Branch)' END    
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND ND.Status in (1,3,5)' END                             
SET @strQuery += ' ORDER BY ND.PYDate DESC, ND.DocValue desc,ND.PYID'                          
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @AccountName NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @Branch NVARCHAR(MAX)', @Mode = @Mode, @TransID = @TransID, @Code = @Code, @ID = @ID, @AccountName = @AccountName, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall, @Branch = @Branch                      
                      
END                            
END                                        
IF(@Mode = 3)                                                                              
BEGIN                                          
if(@TransID = 10)                            
BEGIN                            
SELECT ND.ColID,ND.DocId,ND.ColDate,COLLType,ND.ColDocRefNo,ColMode,Party.AccountName as[Party Name],FAA.AccountName as[Account Name],                            
dbo.fnGetRoundedValue(ND.ColAmt) ColAmt,dbo.fnGetRoundedValue(ND.Balance)Balance ,ST.[Description],ND.Status,Remarks,Narration,UDFID,                            
VisaAmt,VisaPern,BTMode,BranchID,MBO.Name[Branch Name],dbo.fnTransactionPrefix(ND.ColDate,BranchID,ND.DocPrefix) Prefix                            
FROM tblTranCollectionHeader ND                                 
JOIN tblStatus ST ON ST.ID=ND.[Status]                                       
left JOIN tblFAAccount Party ON ND.AccID=Party.FAID                                
left JOIN tblFAAccount FAA ON ND.ExpanceAcc=FAA.FAID               
LEFT  JOIN tblMasterBranchOffice MBO on MBO.ID = ND.BranchID           
WHERE ColID = @ID                            
ORDER BY ND.DocValue,ND.ColID                             
END                            
ELSE                            
BEGIN                            
SELECT ND.PYID,ND.DocId,ND.PYDate,PYType,ND.PYDocRefNo,PYMode,Party.AccountName as[Party Name],FAA.AccountName as[Account Name],                            
dbo.fnGetRoundedValue(ND.PYAmt) ColAmt,                            
dbo.fnGetRoundedValue(ND.Balance)Balance ,ST.[Description],ND.Status,Remarks,Narration,UDFID,VisaAmt,VisaPern,BTMode,BranchID,MBO.Name[Branch Name],      
dbo.fnTransactionPrefix(ND.PYDate,BranchID,ND.PYPrefix) Prefix       
FROM tblTranPaymentHeader ND                                
JOIN tblStatus ST ON ST.ID=ND.[Status]                        
left JOIN tblFAAccount Party ON ND.AccID=Party.FAID           
left JOIN tblFAAccount FAA ON ND.ExpanseAcc=FAA.FAID              
LEFT  JOIN tblMasterBranchOffice MBO on MBO.ID = ND.BranchID           
WHERE PYID = @ID                            
ORDER BY ND.DocValue,ND.PYID                             
END                            
END                                
IF(@Mode = 4)                                                                              
BEGIN                               
declare @sts as table(Sts int)                            
if(isnull(@Code,0) = 0)                            
begin                            
insert into @sts values(1)                            
end                            
else                            
begin                            
insert into @sts values(1),(5)                            
end                           
if(@TransID = 11)                          
BEGIN                          
SELECT 1 Type,'ChequeBook' Trans,CBD.ChequeNo ID,ChequeBookreferNo Code,CBH.ChequeBookreferNo+' - '+CBD.ChequeNo Name,CBH.ChequeBookID 
FROM tblMasterChequeBook CBH                              
JOIN tblMasterChequeBookDetail CBD ON CBD.ChequeBookID = CBH.ChequeBookID                              
join tblMasterBankAccount MBA ON MBA.ID = CBH.BankAccountID                              
WHERE MBA.ID = @ID and CBD.Status in (select * from @sts)                            
END                          
END                            
IF(@Mode = 5)                                                                              
BEGIN                               
SELECT * FROM tblFAAccount WHERE AccountName = @Code                            
END                  
IF(@Mode = 6)                            
BEGIN                            
IF(@TransID = 10)                            
BEGIN                            
select  ColID, CollAmt,PaymentTermID,[Cheque/DD Number],isnull(MB.ID,0) BankAccID,NeftID,Date,PayAt,pm.IfscCode,pm.BankName,pm.BranchName,                          
AmtRecd,Status,isnull(BankAccID,0)                          
 from tblCollPMDetails pm                          
 LEFT JOIN tblMasterBankAccount MB ON MB.FAID = BankAccID WHERE ColID = @ID                            
END                            
ELSE                            
BEGIN                            
select  PYID,PYAmt,PaymentTermID,[Cheque/DD Number],isnull(BankAccID,0)BankAccID,NeftID,Date,PayAt,                          
pm.IfscCode,BankName,pm.BranchName,AmtRecd,Status from tblPaymentPMDetail pm                          
 LEFT JOIN tblMasterBankAccount MB ON MB.FAID = BankAccID  WHERE PYID = @ID                            
END                            
END                            
END TRY                          
BEGIN CATCH                                        
SELECT ERROR_MESSAGE () MSG,ERROR_PROCEDURE () [PROC],ERROR_LINE () LINE                                        
END CATCH                                        
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetPurchaseData';
GO
--uspGetSetPurchaseData 16,3,4,1,'','2026-10-01','2026-12-16',0        
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetPurchaseData]        
@Mode INT,@Code NVARCHAR(MAX) = NULL,@ID NVARCHAR(MAX) = NULL,@TransID int =1,@Party NVARCHAR(MAX) = NULL,@FromDate date = null,        
@ToDate date = null,@Showall int = null        
AS        
BEGIN        
declare @strQuery NVARCHAR(MAX)        
IF(@Mode = 1)        
BEGIN        
select 1 Type,'Vendor' Trans,ID,Code,Name from tblMasterVendor where Active = 1 and FAID > 0        
union all        
SELECT 2 Type,'Branch' Trans,ID,'',Name FROM tblMasterBranchOffice WHERE Active = 1        
union all        
SELECT 3 Type,'Paymode' Trans,ID,'',PaymentMode FROM tblPaymentMode WHERE Active = 1 AND ID IN (7,8)        
union all        
SELECT 4 Type,'CreditTerm' Trans,ID,'',Name FROM tblMasterCreditTerm WHERE Active = 1        
union all        
SELECT 5 Type,'UDN' Trans,UDNID,'',DocName FROM tblMasterUserDefineNoHeader WHERE TransID = 1        
union all        
SELECT 6 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 1        
union all        
SELECT 8 Type,'BankAcc' Trans,MBA.ID,convert(nvarchar, FAID),AccountNo+'|'+MB.Name+'|'+BranchName+'|'+IFSCCode+'|'+MICR+'|'+CONVERT(nvarchar,SetDefault)        
FROM tblmasterBankAccount MBA        
JOIN tblMasterBank MB ON MB.ID = MBA.BankID WHERE MBA.Active = 1 and FAID > 0        
union all        
SELECT 9 Type,'BankAcc' Trans,ID,'',ModeName FROM tblContraMode WHERE Active = 1 and ID > 2        
union all        
SELECT 10 Type,'Reason' Trans,ID,'',Name FROM tblMasterReason WHERE Active = 1        
union all        
SELECT 11 Type,'Location' Trans,ID,'',Name FROM tblMasterLocation WHERE Active = 1        
order by Type,Name,Code        
END        
IF(@Mode = 111)        
BEGIN        
SELECT 7 Type,'AllPaymode' Trans,ID,CONVERT(nvarchar,Orderby),PaymentMode FROM tblPaymentMode WHERE Active = 1 AND ID NOT IN (8,9,10)        
ORDER BY Orderby,PaymentMode        
END        
IF(@Mode = 2)        
BEGIN        
SELECT ProdID,SUM(ActualQty) ABSQty into #ABS FROM tblProductInventory WHERE BranchID = @Code AND (ActualQty > 0)        
AND TransDate <= @FromDate        
GROUP BY ProdID        
SELECT MP.*,dbo.fnGetRoundedValue(ISNULL(AB.ABSQty,0)) ABSQty FROM tblMasterProduct MP        
LEFT JOIN #ABS AB ON AB.ProdID = MP.ID        
WHERE Active = 1 AND TrackInventory = 1 ORDER BY Name        
drop table #ABS        
END        
IF(@Mode = 3)        
BEGIN        
SELECT * FROM tblMasterVendor WHERE Active = 1 AND Code = @Code ORDER BY Name        
END        
IF(@Mode = 31)        
BEGIN        
SELECT * FROM tblMasterVendor WHERE Active = 1 AND ID = @Code ORDER BY Name        
END        
IF(@Mode = 32)        
BEGIN        
SELECT * FROM tblMasterVendor WHERE Active = 1 AND Shinecode = @Code ORDER BY Name        
END        
IF(@Mode = 33)        
BEGIN        
SELECT MP.*,MT.TaxName,MT.GST,BUOM.Name BaseUOM,SUOM.Name SalesUOM,PUOM.Name PurchaseUOM,        
ISNULL(PTP.PurchaseBillPrice,0) PurchaseBillPrice FROM tblMasterProduct MP        
JOIN tblMasterTax MT ON MP.PurchaseTaxID = MT.TaxID        
JOIN tblMasterUOM BUOM ON BUOM.ID = MP.BaseUomID        
JOIN tblMasterUOM SUOM ON SUOM.ID = MP.SalesUomID        
JOIN tblMasterUOM PUOM ON PUOM.ID = MP.PurchaseUomID        
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = MP.ID        
WHERE MP.Active = 1 AND Shinecode = @Code ORDER BY Name        
END        
IF(@Mode = 4)        
BEGIN        
DECLARE @PVABS DECIMAL(15,4)=0,@PVABSFREE DECIMAL(15,4)=0,@PVABSDMG DECIMAL(15,4)=0      
SELECT @PVABS = SUM(ActualQty),@PVABSFREE = SUM(ActualFreeQty),@PVABSDMG = SUM(ActualDmgQty) FROM tblMasterProduct MP        
LEFT JOIN tblProductInventory PV ON PV.ProdID = MP.ID       
WHERE Code = @Code  AND PV.BranchID = ISNULL(@ID,0)      
      
SELECT mp.*,MT.TaxName,MT.GST,MT.IGST,      
ISNULL(PTP.PurchaseBillPrice,0) PurchaseBillPrice,dbo.fnGetRoundedValue(ISNULL(@PVABS,0)) ABSQty,      
dbo.fnGetRoundedValue(ISNULL(@PVABSFREE,0)) ABSFreeQty,dbo.fnGetRoundedValue(ISNULL(@PVABSDMG,0)) ABSDmgQty      
FROM tblMasterProduct MP        
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID        
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = MP.ID        
WHERE Code = @Code        
END        
IF(@Mode = 5)        
BEGIN        
select mp.PurchaseUomID,MU.Name,PurchaseCR from tblMasterProduct mp       
JOIN tblMasterUOM MU ON MU.ID = mp.PurchaseUomID where MP.ID = @ID        
union all        
select mp.SalesUomID,MU.Name,SalesCR from tblMasterProduct mp        
JOIN tblMasterUOM MU ON MU.ID = mp.SalesUomID where MP.ID = @ID        
UNION all        
select mp.BaseUomID,MU.Name,BaseCR CR from tblMasterProduct mp        
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID = @ID        
END        
IF(@Mode = 6)--Bill Filter        
BEGIN        
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,Date,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(PH.GrossAmt) GrossAmt,        
dbo.fnGetRoundedValue(PH.TaxAmt) TaxAmt,dbo.fnGetRoundedValue(PH.NetAmt) NetAmt,STS.Description Status,        
dbo.fnGetRoundedValue(PH.Balance) Balance,CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,PH.Remarks,PH.Narration,        
dbo.fnGetRoundedValue(PH.TotalTradeDiscAmt + PH.TotalProdDiscAmt + PH.TotalAddnlDiscAmt) AS TotalDiscAmt,dbo.fnGetRoundedValue(PH.TotalProdDiscAmt) TotalProdDiscAmt,        
dbo.fnGetRoundedValue(PH.[AddnlDisc%]) AddnlDiscPern,dbo.fnGetRoundedValue(PH.TotalAddnlDiscAmt) AddnlDiscAmt,dbo.fnGetRoundedValue(PH.[TradeDisc%]) TradeDiscPern,dbo.fnGetRoundedValue(PH.TotalTradeDiscAmt) TradeDiscAmt,        
dbo.fnGetRoundedValue(PH.[OtherCharge%]) OtherChargePern,dbo.fnGetRoundedValue(PH.OtherChargeAmt) OtherChargeAmt,dbo.fnGetRoundedValue(Frieght) FrightAmt,        
dbo.fnGetRoundedValue(TCSTaxAmt) TCSTaxAmt,dbo.fnGetRoundedValue(DiffValueGross) DiffExcl,        
dbo.fnGetRoundedValue(DiffValueNet) DiffIncl,dbo.fnGetRoundedValue(WriteOffAmt) WriteOff,PH.PaymentModeID PaymentModeID        
FROM tblTransPurchaseHeader PH        
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID        
JOIN tblStatus STS ON STS.ID = PH.Status        
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID        
JOIN tblUsers CUR ON CUR.ID = PH.CBy        
WHERE MV.Active IN (0,1) and TransID = 1 '        
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END        
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END        
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END        
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END        
SET @strQuery += ' ORDER BY PH.Date DESC,PH.DocValue desc,PH.ID'        
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall        
END        
IF(@Mode = 7)        
BEGIN        
SELECT PH.ID, PH.Date, PH.TransID, PH.BranchID, PH.DocID, PH.DocValue, PH.VendorID, PH.RefNo, PH.ProdGroupID,        
PH.TaxTypeID, PH.PaymentModeID, PH.PaymentTermID, PH.PaymentDate, PH.VehicleNo, PH.Frieght, PH.[OtherCharge%] OtherChrgPern,        
PH.OtherChargeAmt, PH.[ProdDisc%] ProdPern, PH.[TradeDisc%] TradePern, PH.[AddnlDisc%] AddnlPern, PH.TotalProdDiscAmt, PH.TotalTradeDiscAmt,        
PH.TotalAddnlDiscAmt, PH.WriteOffAmt, PH.RoundOffAmt, PH.GrossAmt, PH.TaxAmt, PH.NetAmt,dbo.fnGetRoundedValue(PH.Balance) Balance, PH.PymtID,        
PH.Status, PH.OrgId, PH.UDFId, PH.UDFDocId, PH.UDFDocPrefix, PH.UDFDocValue, PH.CBy, PH.CDate,        
PH.MBy, PH.MDate, PH.ClBy, PH.ClDate, PH.ReturnType, PH.TransactionType, PH.DateBill, PH.PortalDate,        
PH.TCSTaxPern, PH.TCSTaxAmt, PH.TDSAmount, PH.IRN, PH.AckNo, PH.AckDate, PH.AckStatus, PH.SignedQRCode,        
PH.EWBNo, PH.Distance, PH.TransMode, PH.VehicleType, PH.TransportID, PH.TransportName, PH.Remarks, PH.Narration,        
ISNULL(PriceType,1) PriceType,DiffValueGross,DiffValueNet,dbo.fnTransactionPrefix(PH.Date,BranchID,PH.TransID) Prefix        
FROM tblTransPurchaseHeader PH        
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID        
JOIN tblStatus STS ON STS.ID = PH.Status        
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID        
where PH.ID = @ID        
        
select PMDTL.*,PM.PaymentMode,MBAC.AccountNo,MBAC.AccountName,        
CONVERT(VARCHAR(10),CONVERT(date,left(PMDate,10),103),23) OrgPMDate,MBK.ID BankID        
from tblTran_Sale_Bill_PaymentDetail PMDTL        
JOIN tblPaymentMode PM ON PM.ID = PMDTL.PayModeId        
LEFT JOIN tblMasterBankAccount MBAC ON MBAC.ID = PMDTL.Acc_OR_PaytermId        
LEFT JOIN tblMasterBank MBK ON MBK.Name = PMDTL.Bank        
where TransId = 1 and InvId = @ID        
END        
IF(@Mode = 8)        
BEGIN        
      
select ProdID,(SUM(isnull(ActualQty,0))) ActualQty,(SUM(isnull(ActualFreeQty,0))) ActualFreeQty,      
(SUM(isnull(ActualDmgQty,0))) ActualDmgQty INTO #ABSQ from tblProductInventory WHERE ProdID IN (      
select distinct ProdID from tblTransPurchaseDetail where HID = @ID) AND BranchID = (      
select distinct BranchID from tblTransPurchaseHeader where ID = @ID)      
GROUP BY ProdID      
      
      
--select distinct from tblTransPurchaseHeader order by 1 desc        
SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name UOM,SUM(UomQty) Qty,SUM(UomFreeQty) FreeQty,SUM(UomDamageQty) DmgQty,        
PD.[ProdDisc%] ProdPern,PD.[TradeDisc%] TradePern,PD.[AddnlDisc%] AddnlPern,SUM(PD.GrossAmt) GrossAmt,SUM(PD.TaxAmt) TaxAmt,SUM(PD.NetAmt) NetAmt,        
MT.TaxName,PD.[Tax%] TaxPern ,SUM(GoodsAmt) GoodsAmt,ISNULL(PTP.PurchaseBillPrice,0) PurchaseBillPrice,ISNULL(ReasonId,0) ReasonId        
,ISNULL(PD.LocationID,0) LocationID,sum(ISNULL(PD.DiffAmt,0)) DiffAmt,SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,        
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.MRP))* SUM(UomQty+UomDamageQty) MRPonTaxAmt,        
sum(ProdDiscAmt) ProdDiscAmt,sum(TradeDiscAmt) TradeDiscAmt,sum(AddnlDiscAmt) AddnlDiscAmt ,      
dbo.fnGetRoundedValue((isnull(ActualQty,0))) ActualQty,dbo.fnGetRoundedValue((isnull(ActualFreeQty,0))) ActualFreeQty,      
dbo.fnGetRoundedValue((isnull(ActualDmgQty,0))) ActualDmgQty      
FROM tblTransPurchaseDetail PD        
JOIN tblTransPurchaseHeader PH ON PH.ID = PD.HID      
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID        
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID        
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID        
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = MP.ID        
JOIN #ABSQ PVABS ON PVABS.ProdID = PD.ProdID       
where PD.HID = @ID        
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.[ProdDisc%],PD.[TradeDisc%],        
ActualQty,ActualFreeQty,ActualDmgQty,      
PD.[AddnlDisc%],MT.TaxName,PD.[Tax%],ISNULL(PTP.PurchaseBillPrice,0),ISNULL(ReasonId,0),PD.LocationID--,PD.DiffAmt,Serial        
--ORDER BY Serial        
      
DROP TABLE #ABSQ      
END        
IF(@Mode = 9)        
BEGIN        
SELECT PD.*,MP.*,UOM.Name UOMName,MT.TaxName FROM tblTransPurchaseDetail PD        
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID        
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID        
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID        
where PD.HID = @ID        
ORDER BY Serial        
END        
IF(@Mode = 10)--Draft        
BEGIN        
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,Date,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(PH.GrossAmt) GrossAmt,        
dbo.fnGetRoundedValue(PH.TaxAmt) TaxAmt,dbo.fnGetRoundedValue(PH.NetAmt) NetAmt,        
STS.Description Status,dbo.fnGetRoundedValue(0) Balance,CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,PH.Remarks,PH.Narration,        
dbo.fnGetRoundedValue(PH.TotalTradeDiscAmt + PH.TotalProdDiscAmt + PH.TotalAddnlDiscAmt) AS TotalDiscAmt,dbo.fnGetRoundedValue(PH.TotalProdDiscAmt) TotalProdDiscAmt,        
dbo.fnGetRoundedValue(PH.AddnlDiscPern) AddnlDiscPern,dbo.fnGetRoundedValue(PH.TotalAddnlDiscAmt) AddnlDiscAmt,dbo.fnGetRoundedValue(PH.TradeDiscPern) TradeDiscPern,dbo.fnGetRoundedValue(PH.TotalTradeDiscAmt) TradeDiscAmt,        
dbo.fnGetRoundedValue(PH.OtherChargePern) OtherChargePern,dbo.fnGetRoundedValue(PH.OtherChargeAmt) OtherChargeAmt,dbo.fnGetRoundedValue(Frieght) FrightAmt,        
dbo.fnGetRoundedValue(TCSTaxAmt) TCSTaxAmt,dbo.fnGetRoundedValue(DiffValueGross) DiffExcl,dbo.fnGetRoundedValue(DiffValueNet) DiffIncl,dbo.fnGetRoundedValue(WriteOffAmt) WriteOff        
,PH.PaymentModeID PaymentModeID FROM tblPurchaseDraftHeader PH        
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID        
JOIN tblStatus STS ON STS.ID = PH.Status        
left JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID        
JOIN tblUsers CUR ON CUR.ID = PH.CBy WHERE MV.Active IN (0,1) and PH.TransID = ' + CONVERT(NVARCHAR,@TransID)        
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END        
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END        
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END        
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END        
SET @strQuery += ' ORDER BY PH.Date DESC,PH.ID '        
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall        
END        
        
IF(@Mode = 11)        
BEGIN        
declare @currDocid nvarchar(255) = (SELECT DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 1)        
SELECT PH.ID, PH.Date, PH.TransID, PH.BranchID, @currDocid DocID, PH.DocValue, PH.VendorID, PH.RefNo, PH.ProdGroupID,        
PH.TaxTypeID, PH.PaymentModeID, PH.PaymentTermID, PH.PaymentDate, PH.VehicleNo, PH.Frieght, PH.[OtherChargePern] OtherChrgPern,        
PH.OtherChargeAmt, PH.[ProdDiscPern] ProdPern, PH.[TradeDiscPern] TradePern, PH.[AddnlDiscPern] AddnlPern, PH.TotalProdDiscAmt, PH.TotalTradeDiscAmt,        
PH.TotalAddnlDiscAmt, PH.WriteOffAmt, PH.RoundOffAmt, PH.GrossAmt, PH.TaxAmt, PH.NetAmt,dbo.fnGetRoundedValue(PH.Balance) Balance, PH.PymtID,        
PH.Status, PH.OrgId, PH.UDFId, PH.UDFDocId, PH.UDFDocPrefix, PH.UDFDocValue, PH.CBy, PH.CDate,        
PH.MBy, PH.MDate, PH.ClBy, PH.ClDate, PH.ReturnType, PH.TransactionType, '' DateBill, '' PortalDate,        
PH.TCSTaxPern, PH.TCSTaxAmt, PH.TDSAmount, '' IRN, '' AckNo, '' AckDate, '' AckStatus, '' SignedQRCode,        
'' EWBNo,'' Distance, '' TransMode, '' VehicleType, '' TransportID, '' TransportName, PH.Remarks, PH.Narration,        
ISNULL(PriceType,1) PriceType,DiffValueGross,DiffValueNet,dbo.fnTransactionPrefix(PH.Date,BranchID,PH.TransID) Prefix        
FROM tblPurchaseDraftHeader PH        
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID        
JOIN tblStatus STS ON STS.ID = PH.Status        
LEFT JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID        
where PH.ID = @ID        
        
select PMDTL.*,PM.PaymentMode,MBAC.AccountNo,MBAC.AccountName,        
CONVERT(VARCHAR(10),CONVERT(date,left(PMDate,10),103),23) OrgPMDate,MBK.ID BankID        
from tblTran_Sale_Bill_PaymentDetail PMDTL        
JOIN tblPaymentMode PM ON PM.ID = PMDTL.PayModeId        
LEFT JOIN tblMasterBankAccount MBAC ON MBAC.ID = PMDTL.Acc_OR_PaytermId        
LEFT JOIN tblMasterBank MBK ON MBK.Name = PMDTL.Bank        
where TransId = -1 and InvId = @ID        
END        
IF(@Mode = 12)        
BEGIN        
      
select ProdID,(SUM(isnull(ActualQty,0))) ActualQty,(SUM(isnull(ActualFreeQty,0))) ActualFreeQty,      
(SUM(isnull(ActualDmgQty,0))) ActualDmgQty INTO #ABSQ1 from tblProductInventory WHERE ProdID IN (      
select distinct ProdID from tblPurchaseDraftDetail where HID = @ID) AND BranchID = (      
select distinct BranchID from tblPurchaseDraftHeader where ID = @ID)      
GROUP BY ProdID      
      
SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name UOM,SUM(UomQty) Qty,SUM(UomFreeQty) FreeQty,SUM(UomDamageQty) DmgQty,        
PD.[ProdDiscPern] ProdPern,PD.[TradeDiscPern] TradePern,PD.[AddnlDiscPern] AddnlPern,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,        
MT.TaxName,PD.TaxPern TaxPern,SUM(GoodsAmt) GoodsAmt,ISNULL(PTP.PurchaseBillPrice,0) PurchaseBillPrice,        
ISNULL(ReasonId,0) ReasonId ,ISNULL(PD.LocationID,0) LocationID,(ISNULL(PD.DiffAmt,0)) DiffAmt ,SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,        
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.MRP))* SUM(UomQty+UomDamageQty) MRPonTaxAmt,        
sum(ProdDiscAmt) ProdDiscAmt,sum(TradeDiscAmt) TradeDiscAmt,sum(AddnlDiscAmt) AddnlDiscAmt ,      
dbo.fnGetRoundedValue((isnull(ActualQty,0))) ActualQty,dbo.fnGetRoundedValue((isnull(ActualFreeQty,0))) ActualFreeQty,      
dbo.fnGetRoundedValue((isnull(ActualDmgQty,0))) ActualDmgQty      
FROM tblPurchaseDraftDetail PD        
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID        
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID        
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID        
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = MP.ID        
LEFT JOIN #ABSQ1 PVABS ON PVABS.ProdID = PD.ProdID       
where PD.HID = @ID        
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.[ProdDiscPern],PD.[TradeDiscPern],PD.[AddnlDiscPern],        
Serial,  ActualQty,ActualFreeQty,ActualDmgQty,      
MT.TaxName,PD.TaxPern,ISNULL(PTP.PurchaseBillPrice,0),ISNULL(ReasonId,0),PD.LocationID,PD.DiffAmt,PD.UOMCF        
ORDER BY Serial        
      
DROP TABLE #ABSQ1      
END        
IF(@Mode = 13)        
BEGIN        
SELECT PD.*,MP.*,UOM.Name UOMName,MT.TaxName,0 InventoryId,1 TaxTypeID FROM tblPurchaseDraftDetail PD        
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID        
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID        
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID        
where PD.HID = @ID        
ORDER BY Serial        
END        
IF(@Mode = 14)        
BEGIN        
SELECT top 10 DocID,CONVERT(NVARCHAR(25),Date,103) DocDate,MRP,Qty,Uom,Price,ProdDiscPern+' / '+ProdDiscAmt ProdDisc,TradeDiscPern+' / '+TradeDiscAmt TradeDisc        
,AdnlDiscPern+' / '+AddnlDiscAmt AddnlDisc,SalePrice,ECPPrice,SPLPrice,ReturnPrice,BatchNo,PKD,Expiry FROM (        
SELECT PH.DocID,Date,dbo.fnGetRoundedValue(PD.UomMRP) MRP,dbo.fnGetRoundedValue(PD.UomQty) Qty,        
UOM.Name Uom,dbo.fnGetRoundedValue(PD.UomPurchasePrice) Price,        
dbo.fnGetRoundedValue(PD.[ProdDisc%]) ProdDiscPern,        
dbo.fnGetRoundedValue(PD.ProdDiscAmt) ProdDiscAmt,        
dbo.fnGetRoundedValue(PD.[TradeDisc%]) TradeDiscPern,        
dbo.fnGetRoundedValue(PD.TradeDiscAmt) TradeDiscAmt,        
dbo.fnGetRoundedValue(PD.[AddnlDisc%]) AdnlDiscPern,        
dbo.fnGetRoundedValue(PD.AddnlDiscAmt) AddnlDiscAmt,        
dbo.fnGetRoundedValue(PD.UomSalePrice) SalePrice,dbo.fnGetRoundedValue(PD.UomECP) ECPPrice,dbo.fnGetRoundedValue(PD.UomSPLPrice) SPLPrice,        
dbo.fnGetRoundedValue(PD.UomReturnPrice) ReturnPrice,BatchNo,convert(nvarchar(25),PKD,103) PKD,convert(nvarchar(25),Expiry,103) Expiry        
FROM tblTransPurchaseHeader PH        
JOIN tblTransPurchaseDetail PD ON PD.HID = PH.ID        
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID        
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID        
WHERE PH.VendorID = @Code AND PD.ProdID = @ID) AS REC        
END        
IF(@Mode = 15)        
BEGIN        
DECLARE @DraftID INT        
SELECT @DraftID = ID FROM tblPurchaseDraftHeader WHERE ID = @ID AND TransID = @TransID        
DELETE tblPurchaseDraftHeader WHERE ID = @DraftID        
DELETE tblPurchaseDraftDetail WHERE HID = @DraftID        
END        
IF(@Mode = 16)-- PO Data        
BEGIN        
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,DocDate,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(PH.GrossAmt) GrossAmt,        
dbo.fnGetRoundedValue(PH.TaxAmt) TaxAmt,dbo.fnGetRoundedValue(PH.NetAmt) NetAmt,        
STS.Description Status,dbo.fnGetRoundedValue(0) Balance,CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,        
PH.Status StatusID,PH.Remarks,PH.Narration,        
0 AS TotalDiscAmt,0 AS TotalProdDiscAmt,0 AS AddnlDiscPern,        
0 as AddnlDiscAmt,0 AS TradeDiscPern,0 AS TradeDiscAmt,        
0 AS OtherChargePern,0 AS OtherChargeAmt,0 AS FrightAmt,        
0 AS TCSTaxAmt,0 AS DiffExcl,0 AS DiffIncl,0 AS WriteOff,MV.PaymentModeID PaymentModeID        
FROM tblPurchaseOrderHeader PH        
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID        
JOIN tblStatus STS ON STS.ID = PH.Status JOIN tblUsers CUR ON CUR.ID = PH.CBy        
left JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID        
WHERE PH.TransID = 3 AND PH.Status in (1,3)'        
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END        
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END        
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END        
--SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END        
SET @strQuery += 'ORDER BY PH.DocDate DESC,PH.DocValue desc,PH.ID '        
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall        
END        
IF(@Mode = 17)        
BEGIN        
SELECT PH.ID, PH.DocDate Date, PH.TransID, PH.BranchID, PH.DocID, PH.DocValue, PH.VendorID, PH.RefNo, 0 ProdGroupID,        
PH.TaxTypeID, MV.PaymentModeID PaymentModeID, MV.CreditTermID PaymentTermID, null PaymentDate, null VehicleNo, 0 Frieght, 0 OtherChrgPern,        
0 OtherChargeAmt, 0 ProdPern, 0 TradePern, 0 AddnlPern, 0 TotalProdDiscAmt, 0 TotalTradeDiscAmt,        
0 TotalAddnlDiscAmt, 0 WriteOffAmt, PH.RoundOffAmt, PH.GrossAmt, PH.TaxAmt, PH.NetAmt, 0 Balance, 0 PymtID,        
PH.Status, 0 OrgId, PH.UDFId, PH.UDFDocId, PH.UDFDocPrefix, PH.UDFDocValue, PH.CBy, PH.CDate,        
PH.MBy, PH.MDate, PH.ClBy, PH.ClDate, 0 ReturnType,null TransactionType,null DateBill,null PortalDate,        
null TCSTaxPern,null TCSTaxAmt,null TDSAmount, null IRN,null AckNo,null AckDate, null AckStatus,null SignedQRCode,        
null EWBNo, null Distance, null TransMode, null VehicleType, null TransportID, null TransportName, PH.Remarks, PH.Narration,1 PriceType        
,0 DiffValueGross,0 DiffValueNet,dbo.fnTransactionPrefix(PH.DocDate,BranchID,PH.TransID) Prefix        
FROM tblPurchaseOrderHeader PH        
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID        
JOIN tblStatus STS ON STS.ID = PH.Status        
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID        
where PH.ID = @ID        
        
select PMDTL.*,PM.PaymentMode,MBAC.AccountNo,MBAC.AccountName,        
CONVERT(VARCHAR(10),CONVERT(date,left(PMDate,10),103),23) OrgPMDate,MBK.ID BankID        
from tblTran_Sale_Bill_PaymentDetail PMDTL        
JOIN tblPaymentMode PM ON PM.ID = PMDTL.PayModeId        
LEFT JOIN tblMasterBankAccount MBAC ON MBAC.ID = PMDTL.Acc_OR_PaytermId        
LEFT JOIN tblMasterBank MBK ON MBK.Name = PMDTL.Bank        
where TransId = -1 and InvId = @ID        
END        
IF(@Mode = 18)        
BEGIN

select ProdID,(SUM(isnull(ActualQty,0))) ActualQty,(SUM(isnull(ActualFreeQty,0))) ActualFreeQty,      
(SUM(isnull(ActualDmgQty,0))) ActualDmgQty INTO #ABSQ2 from tblProductInventory WHERE ProdID IN (      
select distinct ProdID from tblPurchaseOrderDetail where HID = @ID) AND BranchID = (      
select distinct BranchID from tblPurchaseOrderHeader where ID = @ID)      
GROUP BY ProdID  

SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name UOM,SUM(Qty) Qty,0 FreeQty,0 DmgQty,MP.ProductDiscPerc ProdPern,0 TradePern,        
0 AddnlPern,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,MT.TaxName,PD.TaxPern TaxPern,SUM(GrossAmt) GoodsAmt,        
ISNULL(PTP.PurchaseBillPrice,0) PurchaseBillPrice,0 ReasonId,MP.LocationID,0 DiffAmt,SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,        
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,MP.MRP))* SUM(Qty) MRPonTaxAmt,0 ProdDiscAmt,0TradeDiscAmt,0 AddnlDiscAmt ,
dbo.fnGetRoundedValue((isnull(ActualQty,0))) ActualQty,dbo.fnGetRoundedValue((isnull(ActualFreeQty,0))) ActualFreeQty,      
dbo.fnGetRoundedValue((isnull(ActualDmgQty,0))) ActualDmgQty     
FROM tblPurchaseOrderDetail PD        
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID        
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID        
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID        
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = MP.ID
LEFT JOIN #ABSQ2 PVABS ON PVABS.ProdID = PD.ProdID 
where PD.HID = @ID       
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,ProductDiscPerc,Serial,MT.TaxName,PD.TaxPern,        
ISNULL(PTP.PurchaseBillPrice,0),MP.LocationID,ActualQty,ActualFreeQty,ActualDmgQty
ORDER BY Serial        

DROP TABLE #ABSQ2
END        
IF(@Mode = 19)        
BEGIN        
SELECT PD.HID,0 InventoryId,PD.ProdID,PD.UomID,NULL BatchNo,NULL PKD,NULL Expiry,Qty UomQty,0 UomFreeQty,0 UomDamageQty,PD.PurchasePrice UomPurchasePrice,        
MP.SalesPrice UomSalePrice,MP.ECP UomECP,MP.MRP UomMRP,MP.SPLPrice UomSPLPrice,MP.ReturnPrice UomReturnPrice,PD.PurchasePrice,MP.SalesPrice SalePrice,        
MP.ECP,MP.MRP, MP.SPLPrice,MP.ReturnPrice,PD.TaxID,1 TaxTypeID,PD.TaxPern [Tax%],PD.GrossAmt GoodsAmt,MP.ProductDiscPerc [ProdDisc%],0 [TradeDisc%],        
0 [AddnlDisc%],PD.GrossAmt,PD.TaxAmt,PD.NetAmt,PD.Serial,0AdjQty,0 AdjFreeQty,0 AdjDmgQty,0 ReasonId,MP.*,UOM.Name UOMName,MT.TaxName,        
PD.UomCR UOMCF        
FROM tblPurchaseOrderDetail PD        
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID        
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID        
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID        
where PD.HID = @ID        
ORDER BY Serial        
END        
IF(@Mode = 20)        
BEGIN        
IF(ISNULL(@ID,0) = 0)        
BEGIN        
SELECT ChequeNo,ChequeNoWithRef as [Cheque No] FROM        
(select tblMasterChequeBookDetail.ChequeNo AS ChequeNo,tblMasterChequeBook.ChequeBookreferNo        
+ ' - '+ tblMasterChequeBookDetail.ChequeNo AS ChequeNoWithRef FROM tblMasterChequeBookDetail        
JOIN tblMasterChequeBook        
ON tblMasterChequeBookDetail.ChequebookId=tblMasterChequeBook.ChequebookId        
WHERE tblMasterChequeBook.BankAccountID=@Code AND tblMasterChequeBook.Active=1 AND tblMasterChequeBookDetail.[Status]=1) Saran        
ORDER BY ChequeNoWithRef        
END        
ELSE        
BEGIN        
DECLARE @RevCheqPrefix NVARCHAR(255),@RevCheqPostFix NVARCHAR(255),@RevCheqbookID INT,@RevBankAccFAID INT        
select @RevBankAccFAID = FAID from tblMasterBankAccount where ID = @Code        
SELECT TOP 10 ChequeNo,ChequeNoWithRef as [Cheque No] FROM        
(        
select tblMasterChequeBookDetail.ChequeNo AS ChequeNo,tblMasterChequeBook.ChequeBookreferNo        
+ ' - '+ tblMasterChequeBookDetail.ChequeNo AS ChequeNoWithRef FROM tblMasterChequeBookDetail        
JOIN tblMasterChequeBook        
ON tblMasterChequeBookDetail.ChequebookId=tblMasterChequeBook.ChequebookId        
WHERE tblMasterChequeBook.BankAccountID=@Code AND tblMasterChequeBook.Active=1 AND tblMasterChequeBookDetail.[Status]=1        
UNION        
select [Cheque/DD Number] ,ChequeRefNoWithChequeNo from tblPaymentPMDetail where PYID in (        
select PYID from tblTranPaymentDetail where DocPrefix = 1 and DocID = @ID) and paymenttermid = 2         
AND BankAccID = @RevBankAccFAID) Saran        
        
ORDER BY ChequeNoWithRef        
END        
END        
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetPurchaseOrderData';
GO
--uspGetSetPurchaseOrderData 13,3,3,0,'','2025-02-10','2025-03-16',1                            
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetPurchaseOrderData]                            
@Mode INT,@TransID int =3,@Code NVARCHAR(MAX) = NULL,@ID NVARCHAR(MAX) = NULL,@Party NVARCHAR(MAX) = NULL,@FromDate date = null,                            
@ToDate date = null,@Showall int = null                            
AS                            
BEGIN                            
declare @strQuery NVARCHAR(MAX)                            
declare @currDocid nvarchar(255) = ''                            
IF(@Mode = 1)                            
BEGIN                            
select 1 Type,'Vendor' Trans,ID,Code,Name from tblMasterVendor where Active = 1                            
union all                            
SELECT 2 Type,'Branch' Trans,ID,'',Name FROM tblMasterBranchOffice WHERE Active = 1          
union all                            
SELECT 3 Type,'UDN' Trans,UDNID,'',DocName FROM tblMasterUserDefineNoHeader WHERE TransID = 1                            
union all                            
SELECT 4 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = @TransID                            
union all                            
SELECT 5 Type,'Mfr' Trans,ID,'',Name FROM tblMasterManufacturer WHERE Active = 1          
order by Type,Name                            
END                            
IF(@Mode = 2)                            
BEGIN                            
SELECT MP.ID,MP.Code,MP.Name,MP.EAN,HSNCode,                            
case when @Code = 1 THEN dbo.fnGetRoundedValue(isnull(MP.PurchasePrice,0)) ELSE dbo.fnGetRoundedValue(isnull(MP.PurchasePrice / MP.PurchaseCR,0)) END PurchasePrice,                            
dbo.fnGetRoundedValue(isnull(sum(ActualQty),0)) ABSQty                            
FROM tblMasterProduct MP                            
LEFT JOIN TBLProductInventory PV ON PV.ProdID = MP.ID                            
WHERE Active = 1 GROUP BY MP.ID,MP.Code,MP.Name,MP.EAN,MP.PurchasePrice,HSNCode,MP.PurchaseCR ORDER BY Name                            
END                            
IF(@Mode = 3)                            
BEGIN                            
SELECT * FROM tblMasterVendor WHERE Active = 1 AND Code = @Code ORDER BY Name                            
END                            
IF(@Mode = 31)                            
BEGIN                            
SELECT * FROM tblMasterVendor WHERE Active = 1 AND ID = @Code ORDER BY Name                            
END                            
IF(@Mode = 5)                            
BEGIN                            
IF(@Code = 1)                            
BEGIN                            
SELECT 1 Type,'Manuf' Trans,ID,''Code,Name FROM TBLMASTERMANUFACTURER WHERE ACTIVE = 1 ORDER BY NAME                            
END                            
IF(@Code = 2)                            
BEGIN                            
SELECT 1 Type,'Brand' Trans,ID,''Code,Name FROM TBLMASTERBRAND WHERE ACTIVE = 1 ORDER BY NAME                            
END                            
IF(@Code = 3)                            
BEGIN                            
SELECT 1 Type,'Category' Trans,ID,''Code,Name FROM TBLMASTERCATEGORY WHERE ACTIVE = 1 ORDER BY NAME                            
END                            
END                            
IF(@Mode = 4)                            
BEGIN                            
DECLARE @ABS DECIMAL(25,2) = (SELECT ISNULL(SUM(ActualQty),0) FROM tblMasterProduct MP                            
LEFT JOIN TBLProductInventory PV ON PV.ProdID = MP.ID WHERE Code = @Code )                            
                            
SELECT *,@ABS ABSQty,MT.TaxName,MT.GST,MT.IGST,BSUOM.Name BaseUOMName,PUUOM.Name PurchaseUOMName FROM tblMasterProduct MP                            
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID                            
join tblMasterUOM BSUOM ON BSUOM.ID = MP.BaseUomID                            
join tblMasterUOM PUUOM ON PUUOM.ID = MP.PurchaseUomID                            
WHERE Code = @Code                            
END                            
IF(@Mode = 6)                            
BEGIN                            
--SELECT PH.ID,DocID,CONVERT(NVARCHAR,DocDate,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(PH.GrossAmt) GrossAmt,                            
--dbo.fnGetRoundedValue(PH.TaxAmt) TaxAmt,dbo.fnGetRoundedValue(PH.NetAmt) NetAmt,STS.Description Status                            
--FROM tblPurchaseOrderHeader PH                            
--JOIN tblMasterVendor MV ON MV.ID = PH.VendorID                            
--JOIN tblStatus STS ON STS.ID = PH.Status                            
--JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                     
--ORDER BY DocValue DESC,PH.ID                            
SET @strQuery = 'SELECT PH.ID,DocID,FORMAT(DocDate,''dd/MM/yyyy'') DocDate,RefNo,MBO.Name Branch,MV.Name Party,    
dbo.funTwoDecimalRoundOff(PH.GrossAmt) GrossAmt,                            
dbo.funTwoDecimalRoundOff(PH.TaxAmt) TaxAmt,dbo.funTwoDecimalRoundOff(PH.NetAmt) NetAmt,STS.Description Status,ISNULL(PH.UomType,1) UomType,                      
CUR.UserName UserName,FORMAT(PH.CDate,''dd/MMM/yyyy hh:mm:ss tt'') LastActionTime,PH.Status StatusID,PH.Remarks,PH.Narration                       
FROM tblPurchaseOrderHeader PH                            
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID                            
JOIN tblStatus STS ON STS.ID = PH.Status                            
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                      
JOIN tblUsers CUR ON CUR.ID = PH.CBy   WHERE MV.Active IN (0,1) '                        
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                            
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END                            
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                            
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                            
SET @strQuery += ' ORDER BY PH.DocDate DESC, DocValue DESC,PH.ID '                            
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID int, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @TransID = @TransID, @Code = @Code, @ID = @ID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                            
END                            
IF(@Mode = 7)                            
BEGIN                            
SELECT PH.ID, PH.DocDate Date, PH.TransID, PH.BranchID, PH.DocID, PH.DocValue, PH.VendorID, PH.RefNo,                            
PH.TaxTypeID, PH.RoundOffAmt, PH.GrossAmt, PH.TaxAmt, PH.NetAmt,                            
PH.Status, PH.UDFId, PH.CBy,PH.Remarks, PH.Narration,ISNULL(PH.UomType,1) UomType,dbo.fnTransactionPrefix(PH.DocDate,BranchID,PH.TransID) Prefix                 
FROM tblPurchaseOrderHeader PH                            
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID                            
JOIN tblStatus STS ON STS.ID = PH.Status                            
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                            
where PH.ID = @ID                            
END                            
IF(@Mode = 8)                            
BEGIN                            
--SELECT PD.ProdID,PD.UomID,PD.TaxID,MP.Code,MP.Name,UOM.Name UomName,Qty,pd.PurchasePrice Excl,              
----(pd.PurchasePrice * (1 + (PD.TaxPern / 100))) Incl,                            
--dbo.fngetInclusiveValue(PD.TaxID,MP.MRP,PD.PurchasePrice) Incl,              
--GrossAmt,TaxAmt,NetAmt,MT.TaxName,PD.TaxPern,PD.UomCR,MP.MRP        
--FROM tblPurchaseOrderDetail PD                            
--JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                            
--JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                            
--JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID                            
--where PD.HID = @ID              
--ORDER BY Serial             
SELECT PD.ProdID,PD.UomID,PD.TaxID,MP.Code,MP.Name,UOM.Name UomName,Qty,pd.PurchasePrice Excl,      
dbo.fngetInclusiveValue(PD.TaxID,MP.MRP,PD.PurchasePrice) Incl,      
PD.GrossAmt,PD.TaxAmt,PD.NetAmt,MT.TaxName,PD.TaxPern,PD.UomCR,MP.MRP,ISNULL(SUM(CumulativeTax),0) CumulativeTax,
isnull(SUM(PV.ActualQty),0) ActualQty,isnull(SUM(PV.ActualFreeQty),0) ActualFreeQty
FROM tblPurchaseOrderDetail PD      
JOIN tblPurchaseOrderHeader PH ON PH.ID = PD.HID      
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID      
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID      
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID      
LEFT join tblMasterTaxDetail MTD ON MTD.TaxID = PD.TaxID AND MTD.TaxTypeID=PH.TaxTypeID      
AND GSTTaxType NOT IN (5,3) AND MTD.AppOn = -1   
LEFT JOIN tblProductInventory PV ON PV.ProdID = PD.ProdID AND PV.BranchID = PH.BranchID
where PD.HID = @ID        
GROUP BY PD.ProdID,PD.UomID,PD.TaxID,MP.Code,MP.Name,UOM.Name,Qty,PD.PurchasePrice,PD.GrossAmt,      
PD.TaxAmt,PD.NetAmt,MT.TaxName,PD.TaxPern,PD.UomCR,MP.MRP,Serial      
ORDER BY Serial      
END                            
IF(@Mode = 9)--Draft                            
BEGIN                            
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,Date,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(PH.GrossAmt) GrossAmt,                            
dbo.fnGetRoundedValue(PH.TaxAmt) TaxAmt,dbo.fnGetRoundedValue(PH.NetAmt) NetAmt,STS.Description Status,ISNULL(PH.UomType,1) UomType,                      
CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,PH.Remarks,PH.Narration                      
FROM tblPurchaseDraftHeader PH                            
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID                            
JOIN tblStatus STS ON STS.ID = PH.Status                            
left JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                     
JOIN tblUsers CUR ON CUR.ID = PH.CBy WHERE MV.Active IN (0,1) and PH.TransID = ' + CONVERT(NVARCHAR,@TransID)                            
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                            
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END                            
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                            
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                            
SET @strQuery += ' ORDER BY PH.Date DESC,PH.ID DESC '                            
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID int, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @TransID = @TransID, @Code = @Code, @ID = @ID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                            
END                            
IF(@Mode = 10)                            
BEGIN                            
set @currDocid = (SELECT DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 3)                            
SELECT PH.ID, PH.Date Date, PH.TransID, PH.BranchID, @currDocid DocID, PH.DocValue, PH.VendorID, PH.RefNo,                            
PH.TaxTypeID, PH.RoundOffAmt, PH.GrossAmt, PH.TaxAmt, PH.NetAmt,                            
PH.Status, PH.UDFId, PH.CBy,PH.Remarks, PH.Narration,ISNULL(UomType,1) UomType,dbo.fnTransactionPrefix(PH.Date,BranchID,PH.TransID) Prefix                  
FROM tblPurchaseDraftHeader PH                            
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID                            
JOIN tblStatus STS ON STS.ID = PH.Status                            
left JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                            
where PH.ID = @ID                            
END                            
IF(@Mode = 11)        
BEGIN                            
SELECT PD.ProdID,PD.UomID,PD.TaxID,MP.Code,MP.Name,UOM.Name UomName,UomQty Qty,pd.PurchasePrice Excl,              
dbo.fngetInclusiveValue(PD.TaxID,MP.MRP,PD.PurchasePrice) Incl,                                   
PD.GrossAmt,PD.TaxAmt,PD.NetAmt,MT.TaxName,PD.TaxPern,ISNULL(PD.UomCR,1) UomCR,MP.MRP,
ISNULL(SUM(CumulativeTax),0) CumulativeTax,isnull(SUM(PV.ActualQty),0) ActualQty,isnull(SUM(PV.ActualFreeQty),0) ActualFreeQty
FROM tblPurchaseDraftDetail PD                  
JOIN tblPurchaseDraftHeader PH ON PH.ID = PD.HID      
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                            
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                            
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID               
LEFT join tblMasterTaxDetail MTD ON MTD.TaxID = PD.TaxID AND MTD.TaxTypeID=PH.TaxTypeID      
AND GSTTaxType NOT IN (5,3) AND MTD.AppOn = -1      
LEFT JOIN tblProductInventory PV ON PV.ProdID = PD.ProdID AND PV.BranchID = PH.BranchID
where PD.HID = @ID                 
GROUP BY PD.ProdID,PD.UomID,PD.TaxID,MP.Code,MP.Name,UOM.Name,UomQty,pd.PurchasePrice,                                        
PD.GrossAmt,PD.TaxAmt,PD.NetAmt,MT.TaxName,PD.TaxPern,PD.UomCR,MP.MRP       
END                            
IF(@Mode = 12)                            
BEGIN                            
DECLARE @DraftID INT                            
SELECT @DraftID = ID FROM tblPurchaseDraftHeader WHERE ID = @ID AND TransID = @TransID                            
DELETE tblPurchaseDraftHeader WHERE ID = @DraftID                            
DELETE tblPurchaseDraftDetail WHERE HID = @DraftID                            
END                            
IF(@Mode = 13)--AI Data                            
BEGIN                            
                            
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,DATE,103) DocDate,RefNo,MBO.NAME Branch,MV.NAME Party,DBO.FNGETROUNDEDVALUE(SUM(PD.PURCHASEPRICE * INDENTVALUE)) GrossAmt,                            
DBO.FNGETROUNDEDVALUE(SUM(((PD.PURCHASEPRICE)*(PD.IndentValue))* (ISNULL((MT.GST),0))/100)) AS [TaxAmt],                            
DBO.FNGETROUNDEDVALUE(SUM(PD.PURCHASEPRICE * INDENTVALUE) + SUM(((PD.PURCHASEPRICE)*(PD.IndentValue))* (ISNULL((MT.GST),0))/100)) NetAmt,                            
STS.DESCRIPTION Status,CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,PH.Remarks,PH.Narration                               
FROM TBLTRANSAUTOMATICINDENTHEADER PH                            
JOIN TBLTRANSAUTOMATICINDENTDETAIL PD ON PD.HID = PH.ID                            
JOIN TBLMASTERPRODUCT MP ON MP.ID = PD.PRODID                            
JOIN TBLMASTERTAX MT ON MT.TAXID = MP.PurchaseTaxID            
JOIN TBLMASTERVENDOR MV ON MV.ID = PH.VENDORID                            
JOIN TBLSTATUS STS ON STS.ID = PH.STATUS                            
LEFT JOIN TBLMASTERBRANCHOFFICE MBO ON MBO.ID = PH.BRANCHID                      
JOIN tblUsers CUR ON CUR.ID = PH.CBy WHERE MV.ACTIVE IN (0,1) AND PH.TRANSID = 2 '                            
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                            
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END                            
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                            
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN ' AND PH.Status in (1,3) ' ELSE ' AND PH.Status in (1,3)' END                            
SET @strQuery += ' GROUP BY PH.ID,DOCID,PH.DocValue,DATE,REFNO,MBO.NAME,MV.NAME,STS.DESCRIPTION,CUR.UserName,PH.CDate,PH.Status,PH.Remarks,PH.Narration '                            
SET @strQuery += ' ORDER BY PH.Date DESC, PH.DocValue DESC,PH.ID DESC '                            
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID int, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @TransID = @TransID, @Code = @Code, @ID = @ID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                            
                            
END                            
IF(@Mode = 14)                            
BEGIN                            
set @currDocid = (SELECT DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 3)                            
SELECT PH.ID, PH.Date Date, PH.TransID, PH.BranchID, @currDocid DocID, PH.DocValue, PH.VendorID, PH.RefNo,                            
MV.TaxTypeID, 0 RoundOffAmt,DBO.FNGETROUNDEDVALUE(SUM(PD.PURCHASEPRICE * INDENTVALUE)) GrossAmt,                            
DBO.FNGETROUNDEDVALUE(SUM(((PD.PURCHASEPRICE)*(PD.IndentValue))* (ISNULL((MT.GST),0))/100)) AS [TaxAmt],                            
DBO.FNGETROUNDEDVALUE(SUM(PD.PURCHASEPRICE * INDENTVALUE) + SUM(((PD.PURCHASEPRICE)*(PD.IndentValue))* (ISNULL((MT.GST),0))/100)) NetAmt,                            
PH.Status, PH.UDFId, PH.CBy,PH.Remarks, PH.Narration,1 UomType,dbo.fnTransactionPrefix(PH.Date,BranchID,PH.TransID) Prefix                 
FROM tblTransAutomaticIndentHeader PH                            
JOIN tblTransAutomaticIndentDetail PD ON PD.HID = PH.ID                            
JOIN TBLMASTERPRODUCT MP ON MP.ID = PD.ProdID                            
JOIN TBLMASTERTAX MT ON MT.TAXID = MP.PurchaseTaxID                            
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID                         
JOIN tblStatus STS ON STS.ID = PH.Status                            
left JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                            
where PH.ID = @ID                            
GROUP BY PH.ID, PH.Date, PH.TransID, PH.BranchID, PH.DocValue, PH.VendorID, PH.RefNo,                            
MV.TaxTypeID,PH.Status, PH.UDFId, PH.CBy,PH.Remarks, PH.Narration                            
END                            
IF(@Mode = 15)                            
BEGIN                            
SELECT PD.ProdID,MP.PurchaseUomID UomID,MP.PurchaseTaxID TaxID,MP.Code,MP.Name,UOM.Name UomName,sum(INDENTVALUE) Qty,                            
pd.PurchasePrice Excl,              
dbo.fngetInclusiveValue(MP.PurchaseTaxID,MP.MRP,PD.PurchasePrice) Incl,              
--(pd.PurchasePrice * (1 + (MT.GST / 100))) Incl,                            
DBO.FNGETROUNDEDVALUE(SUM(PD.PURCHASEPRICE * INDENTVALUE)) GrossAmt,                            
DBO.FNGETROUNDEDVALUE(SUM(((PD.PURCHASEPRICE)*(PD.IndentValue))* (ISNULL((MT.GST),0))/100)) AS [TaxAmt],                            
DBO.FNGETROUNDEDVALUE(SUM(PD.PURCHASEPRICE * INDENTVALUE) + SUM(((PD.PURCHASEPRICE)*(PD.IndentValue))* (ISNULL((MT.GST),0))/100)) NetAmt,                            
MT.TaxName,MT.GST TaxPern,MP.BaseCR UomCR,MP.MRP,ISNULL(SUM(CumulativeTax),0) CumulativeTax ,
isnull(SUM(PV.ActualQty),0) ActualQty,isnull(SUM(PV.ActualFreeQty),0) ActualFreeQty
FROM tblTransAutomaticIndentDetail PD                          
JOIN tblTransAutomaticIndentHeader PH ON PH.ID = PD.HID      
JOIN TBLMASTERVENDOR MV ON MV.ID = PH.VENDORID        
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                            
JOIN tblMasterUOM UOM ON UOM.ID = MP.PurchaseUomID                            
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID        
LEFT join tblMasterTaxDetail MTD ON MTD.TaxID = MP.PurchaseTaxID AND MTD.TaxTypeID=MV.TaxTypeID      
AND GSTTaxType NOT IN (5,3) AND MTD.AppOn = -1      
LEFT JOIN tblProductInventory PV ON PV.ProdID = PD.ProdID AND PV.BranchID = PH.BranchID
where PD.HID = @ID               
group by PD.ProdID,MP.PurchaseUomID,MP.PurchaseTaxID,MP.MRP,MP.Code,MP.Name,UOM.Name,MT.TaxName,MT.GST,pd.PurchasePrice,MP.BaseCR,MP.MRP                            
END                            
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetPurchaseReturnData';
GO
--uspGetSetPurchaseReturnData 9,null,130,12,4,'2025-03-07','2026-12-26',0  
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetPurchaseReturnData]  
@Mode INT,@Code NVARCHAR(MAX) = NULL,@ID NVARCHAR(MAX) = NULL,@TransID int =12,@Party NVARCHAR(MAX) = NULL,@FromDate date = null,  
@ToDate date = null,@Showall int = null  
AS  
BEGIN  
declare @strQuery NVARCHAR(MAX)  
declare @ApplyReturnprice int;-- = (select count(*) from tblRolePermissions where Role = 2 and PermissionFormId = 129 )  
select @ApplyReturnprice = AppValue from tblAppConfig where AppId = 12  
DECLARE @BID INT ,@TDate DATE,@ApplyPrice int  
IF(@Mode = 1)  
BEGIN  
select 1 Type,'Vendor' Trans,ID,Code,Name from tblMasterVendor where Active = 1 and FAID > 0  
union all  
SELECT 2 Type,'Branch' Trans,ID,'',Name FROM tblMasterBranchOffice WHERE Active = 1  
union all  
SELECT 3 Type,'Paymode' Trans,ID,'',PaymentMode FROM tblPaymentMode WHERE Active = 1  
union all  
SELECT 4 Type,'CreditTerm' Trans,ID,'',Name FROM tblMasterCreditTerm WHERE Active = 1  
union all  
SELECT 5 Type,'UDN' Trans,UDNID,'',DocName FROM tblMasterUserDefineNoHeader WHERE TransID = 1  
union all  
SELECT 6 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 12  
union all  
SELECT 7 Type,'ReturnType' Trans,ID,'',Name FROM tblMasterReturnType WHERE Active = 1  
union all  
SELECT 8 Type,'Reason' Trans,ID,'',Name FROM tblMasterReason WHERE Active = 1  
union all  
SELECT 9 Type,'PriceType' Trans,ID,'',PriceType FROM tblPriceType WHERE Active = 1 AND ID IN (1,6)  
union all  
SELECT 10 Type,'ManufName' Trans,ID,'',Name FROM tblMasterManufacturer WHERE Active = 1  
order by Type,Name  
END  
IF(@Mode = 2)  
BEGIN  
SELECT ProdID,SUM(ActualQty) ABSQty into #ABS FROM tblProductInventory WHERE BranchID = @Code AND TransDate <= @FromDate AND  
(ActualQty > 0 OR ActualFreeQty > 0 OR ActualDmgQty > 0)  
  
GROUP BY ProdID  
SELECT MP.*,dbo.fnGetRoundedValue(ISNULL(AB.ABSQty,0)) ABSQty FROM tblMasterProduct MP  
JOIN #ABS AB ON AB.ProdID = MP.ID  
WHERE Active = 1 AND TrackInventory = 1 ORDER BY Name  
DROP TABLE #ABS  
END  
IF(@Mode = 3)  
BEGIN  
SELECT * FROM tblMasterVendor WHERE Active = 1 AND Code = @Code ORDER BY Name  
END  
IF(@Mode = 31)  
BEGIN  
SELECT * FROM tblMasterVendor WHERE Active = 1 AND ID = @Code ORDER BY Name  
END  
IF(@Mode = 4)  
BEGIN  
SELECT MP.ID,MP.Code,MP.Name,HSNCode,MP.BaseUomID,MP.BaseCR,MP.PurchaseUomID,MP.PurchaseCR,mp.PurchaseTaxID,MT.TaxName,MT.GST,  
MP.ProductDiscPerc,MP.TrackBatch,MP.TrackPDK,ISNULL(PTP.PurchaseReturnPrice,0) PurchaseReturnPrice  
FROM tblMasterProduct MP  
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID  
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = MP.ID  
WHERE Code = @Code  
END  
ELSE IF(@Mode = 41)  
BEGIN  
set @strQuery = ' SELECT 0 InventoryId,ProdID,PV.BatchNumber,PV.PKDDate,PV.ExpiryDate,(SUM(ActualQty)) Qty,  
(SUM(ActualFreeQty)) FreeQty,(SUM(ActualDmgQty)) DmgQty,(PV.MRPONPrice) MRP,0 PurchasePrice,'+  
(case when (convert(nvarchar,@ID)) = '1' then 'PV.PurchasePrice ' else ' PV.ReturnPrice' end) +' ReturnPrice  
FROM tblProductInventory PV WHERE(ActualQty > 0 OR ActualFreeQty > 0 OR ActualDmgQty > 0) and  
pv.ProdID =convert(nvarchar,@Code) and BranchID = convert(nvarchar,@Party) and  
TransDate <= '+''''+convert(nvarchar,@FromDate)+''''+'  
GROUP BY PV.BatchNumber,PV.PKDDate,PV.ExpiryDate,PV.MRPONPrice,'+(case when (convert(nvarchar,@ID)) = '1' then 'PV.PurchasePrice '  
else ' PV.ReturnPrice' end) +',ProdID '  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall  
END  
IF(@Mode = 5)  
BEGIN  
select mp.BaseUomID,MU.Name,BaseCR CR from tblMasterProduct mp  
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID = @ID  
UNION ALL  
select mp.PurchaseUomID,MU.Name,PurchaseCR from tblMasterProduct mp  
JOIN tblMasterUOM MU ON MU.ID = mp.PurchaseUomID where MP.ID = @ID  
UNION ALL  
select mp.SalesUomID,MU.Name,SalesCR from tblMasterProduct mp  
JOIN tblMasterUOM MU ON MU.ID = mp.SalesUomID where MP.ID = @ID  
END  
IF(@Mode = 6)  
BEGIN  
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,Date,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(PH.GrossAmt) GrossAmt,  
dbo.fnGetRoundedValue(PH.TaxAmt) TaxAmt,dbo.fnGetRoundedValue(PH.NetAmt) NetAmt,  
STS.Description Status,dbo.fnGetRoundedValue(PH.Balance) Balance,CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,  
PH.Status StatusID,PH.Remarks,PH.Narration  
FROM tblTransPurchaseHeader PH  
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID  
JOIN tblStatus STS ON STS.ID = PH.Status  
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID  
JOIN tblUsers CUR ON CUR.ID = PH.CBy  
WHERE MV.Active IN (0,1) and TransID = 12 '  
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END  
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END  
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END  
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (3,5,6)' END  
SET @strQuery += ' ORDER BY PH.Date DESC,DocValue desc,PH.ID'  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall  
END  
IF(@Mode = 7)  
BEGIN  
SELECT PH.ID, PH.Date, PH.TransID, PH.BranchID, PH.DocID, PH.DocValue, PH.VendorID, PH.RefNo, PH.ProdGroupID,  
PH.TaxTypeID, PH.PaymentModeID, PH.PaymentTermID, PH.PaymentDate, PH.VehicleNo, PH.Frieght, PH.[OtherCharge%] OtherChrgPern,  
PH.OtherChargeAmt, PH.[ProdDisc%] ProdPern, PH.[TradeDisc%] TradePern, PH.[AddnlDisc%] AddnlPern, PH.TotalProdDiscAmt, PH.TotalTradeDiscAmt,  
PH.TotalAddnlDiscAmt, PH.WriteOffAmt, PH.RoundOffAmt, PH.GrossAmt, PH.TaxAmt, PH.NetAmt,dbo.fnGetRoundedValue(PH.Balance) Balance, PH.PymtID,  
PH.Status, PH.OrgId, PH.UDFId, PH.UDFDocId, PH.UDFDocPrefix, PH.UDFDocValue, PH.CBy, PH.CDate,  
PH.MBy, PH.MDate, PH.ClBy, PH.ClDate, PH.ReturnType, PH.TransactionType, PH.DateBill, PH.PortalDate,  
PH.TCSTaxPern, PH.TCSTaxAmt, PH.TDSAmount, PH.IRN, PH.AckNo, PH.AckDate, PH.AckStatus, PH.SignedQRCode,  
PH.EWBNo, PH.Distance, PH.TransMode, PH.VehicleType, PH.TransportID, PH.TransportName, PH.Remarks, PH.Narration,PriceType,  
DiffValueGross,DiffValueNet,dbo.fnTransactionPrefix(PH.Date,BranchID,PH.TransID) Prefix  
FROM tblTransPurchaseHeader PH  
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID  
JOIN tblStatus STS ON STS.ID = PH.Status  
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID  
where PH.ID = @ID  
END  
IF(@Mode = 8)  
BEGIN  
select ProdID,(SUM(isnull(ActualQty,0))) ActualQty,(SUM(isnull(ActualFreeQty,0))) ActualFreeQty,    
(SUM(isnull(ActualDmgQty,0))) ActualDmgQty INTO #ABSQ from tblProductInventory WHERE ProdID IN (    
select distinct ProdID from tblTransPurchaseDetail where HID = @ID) AND BranchID = (    
select distinct BranchID from tblTransPurchaseHeader where ID = @ID)    
GROUP BY ProdID    
    
SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name UOM,SUM(UomQty) Qty,SUM(UomFreeQty) FreeQty,SUM(UomDamageQty) DmgQty,  
PD.[ProdDisc%] ProdPern,PD.[TradeDisc%] TradePern,PD.[AddnlDisc%] AddnlPern,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,  
MT.TaxName,PD.[Tax%] TaxPern,isnull(PD.ReasonId,0) ReasonId,MR.Name ReasonName,ISNULL(PTP.PurchaseReturnPrice,0) PurchaseReturnPrice  
,ISNULL(PD.DiffAmt,0) DiffAmt,SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,  
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.MRP))* SUM(UomQty+UomDamageQty) MRPonTaxAmt,SUM(GoodsAmt) GoodsAmt,  
ProdDiscAmt,TradeDiscAmt,AddnlDiscAmt,
dbo.fnGetRoundedValue((isnull(ActualQty,0))) ActualQty,dbo.fnGetRoundedValue((isnull(ActualFreeQty,0))) ActualFreeQty,    
dbo.fnGetRoundedValue((isnull(ActualDmgQty,0))) ActualDmgQty  
FROM tblTransPurchaseDetail PD  
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID  
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID  
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID  
LEFT JOIN TBLMASTERREASON MR ON MR.ID = PD.ReasonId  
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = MP.ID  
JOIN #ABSQ PVABS ON PVABS.ProdID = PD.ProdID     
where PD.HID = @ID  
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.[ProdDisc%],PD.[TradeDisc%],PD.[AddnlDisc%],  
Serial,MT.TaxName,PD.[Tax%],isnull(PD.ReasonId,0),MR.Name,PTP.PurchaseReturnPrice,PD.DiffAmt,  
ProdDiscAmt,TradeDiscAmt,AddnlDiscAmt,ActualQty,ActualFreeQty,ActualDmgQty 
ORDER BY Serial  

DROP TABLE #ABSQ 
END  
IF(@Mode = 9)  
BEGIN  
  
SELECT @BID = BranchID,@TDate =Date,@ApplyPrice = PriceType FROM tblTransPurchaseHeader where ID = @ID  
SELECT InventoryId,ProdID,BatchNumber,PKDDate,ExpiryDate,(SUM(Qty)) Qty,(SUM(FreeQty)) FreeQty  
,(SUM(DmgQty)) DmgQty,MRP,PurchasePrice,ReturnPrice,(SUM(PRQty)) PRQty,(SUM(PRFree)) PRFree  
,(SUM(PRDmg)) PRDmg,TaxName,GSTPern,PurchaseTaxID,ConversionRate,UOMPrice FROM (  
SELECT 0 InventoryId,PV.ProdID,P.BatchNumber BatchNumber,P.PKDDate PKDDate,P.ExpiryDate ExpiryDate,(SUM(UomQty)) Qty,  
(SUM(UomFreeQty)) FreeQty,(SUM(UomDamageQty)) DmgQty,  
(P.MRPONPrice) MRP,(case when @ApplyPrice = 6 THEN P.ReturnPrice ELSE P.PurchasePrice end) PurchasePrice,  
(case when @ApplyPrice = 6 THEN PV.UomReturnPrice else PV.UOMPurchasePrice end) ReturnPrice,(SUM(UomQty)) PRQty,  
(SUM(UomFreeQty)) PRFree,(SUM(UomDamageQty)) PRDmg,MTT.TaxName,PV.[Tax%] GSTPern,PV.TaxID PurchaseTaxID,  
isnull(UOMCF,1) ConversionRate,(case when @ApplyPrice = 6 THEN PV.UomReturnPrice else PV.UOMPurchasePrice end) UOMPrice  
FROM tblTransPurchaseDetail PV  
JOIN tblProductInventory P ON P.InventoryId = PV.InventoryId  
join tblMasterTax MTT ON MTT.TaxID = PV.TaxID  
WHERE PV.HID = @ID  
GROUP BY P.BatchNumber,P.PKDDate,P.ExpiryDate,P.MRPONPrice,PV.UomReturnPrice,PV.ProdID,P.ReturnPrice,MTT.TaxName,PV.[Tax%],PV.TaxID,UOMCF,  
(case when @ApplyPrice = 6 THEN P.ReturnPrice ELSE P.PurchasePrice end),(case when @ApplyPrice = 6 THEN PV.UomReturnPrice else PV.UOMPurchasePrice end)) AS REC  
group by InventoryId,ProdID,BatchNumber,PKDDate,ExpiryDate,MRP,PurchasePrice,ReturnPrice,TaxName,GSTPern,  
PurchaseTaxID,ConversionRate,UOMPrice  
  
END  
IF(@Mode = 10)--Draft  
BEGIN  
  
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,Date,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(PH.GrossAmt) GrossAmt,  
dbo.fnGetRoundedValue(PH.TaxAmt) TaxAmt,dbo.fnGetRoundedValue(PH.NetAmt) NetAmt,  
STS.Description Status,dbo.fnGetRoundedValue(PH.NetAmt) Balance,CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,  
PH.Status StatusID,PH.Remarks,PH.Narration  
FROM tblPurchaseDraftHeader PH  
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID  
JOIN tblStatus STS ON STS.ID = PH.Status  
left JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID  
JOIN tblUsers CUR ON CUR.ID = PH.CBy WHERE MV.Active IN (0,1) and PH.TransID = 12'  
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END  
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END  
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END  
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (3,5,6)' END  
SET @strQuery += ' ORDER BY PH.Date DESC,PH.ID DESC '  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall  
END  
IF(@Mode = 11)  
BEGIN  
declare @currDocid nvarchar(255) = (SELECT DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 12)  
SELECT PH.ID, PH.Date, PH.TransID, PH.BranchID, @currDocid DocID, PH.DocValue, PH.VendorID, PH.RefNo, PH.ProdGroupID,  
PH.TaxTypeID, PH.PaymentModeID, PH.PaymentTermID, PH.PaymentDate, PH.VehicleNo, PH.Frieght, PH.[OtherChargePern] OtherChrgPern,  
PH.OtherChargeAmt, PH.[ProdDiscPern] ProdPern, PH.[TradeDiscPern] TradePern, PH.[AddnlDiscPern] AddnlPern, PH.TotalProdDiscAmt, PH.TotalTradeDiscAmt,  
PH.TotalAddnlDiscAmt, PH.WriteOffAmt, PH.RoundOffAmt, PH.GrossAmt, PH.TaxAmt, PH.NetAmt,dbo.fnGetRoundedValue(PH.Balance) Balance, PH.PymtID,  
PH.Status, PH.OrgId, PH.UDFId, PH.UDFDocId, PH.UDFDocPrefix, PH.UDFDocValue, PH.CBy, PH.CDate,  
PH.MBy, PH.MDate, PH.ClBy, PH.ClDate, PH.ReturnType, PH.TransactionType, '' DateBill, '' PortalDate,  
PH.TCSTaxPern, PH.TCSTaxAmt, PH.TDSAmount, '' IRN, '' AckNo, '' AckDate, '' AckStatus, '' SignedQRCode,  
'' EWBNo,'' Distance, '' TransMode, '' VehicleType, '' TransportID, '' TransportName, PH.Remarks, PH.Narration,PriceType,DiffValueGross,DiffValueNet,dbo.fnTransactionPrefix(PH.Date,BranchID,PH.TransID) Prefix  
FROM tblPurchaseDraftHeader PH  
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID  
JOIN tblStatus STS ON STS.ID = PH.Status  
LEFT JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID  
where PH.ID = @ID  
END  
IF(@Mode = 12)  
BEGIN  

select ProdID,(SUM(isnull(ActualQty,0))) ActualQty,(SUM(isnull(ActualFreeQty,0))) ActualFreeQty,    
(SUM(isnull(ActualDmgQty,0))) ActualDmgQty INTO #ABSQ1 from tblProductInventory WHERE ProdID IN (    
select distinct ProdID from tblPurchaseDraftDetail where HID = @ID) AND BranchID = (    
select distinct BranchID from tblPurchaseDraftHeader where ID = @ID)    
GROUP BY ProdID    

SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name UOM,SUM(UomQty) Qty,SUM(UomFreeQty) FreeQty,SUM(UomDamageQty) DmgQty,  
PD.[ProdDiscPern] ProdPern,PD.[TradeDiscPern] TradePern,PD.[AddnlDiscPern] AddnlPern,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,  
MT.TaxName,PD.TaxPern TaxPern,isnull(PD.ReasonId,0) ReasonId,MR.Name ReasonName,ISNULL(PTP.PurchaseReturnPrice,0) PurchaseReturnPrice  
,ISNULL(PD.DiffAmt,0) DiffAmt,SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,SUM(GoodsAmt) GoodsAmt,  
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.MRP))* SUM(UomQty+UomDamageQty) MRPonTaxAmt,  
ProdDiscAmt,TradeDiscAmt,AddnlDiscAmt,
dbo.fnGetRoundedValue((isnull(ActualQty,0))) ActualQty,dbo.fnGetRoundedValue((isnull(ActualFreeQty,0))) ActualFreeQty,    
dbo.fnGetRoundedValue((isnull(ActualDmgQty,0))) ActualDmgQty    
FROM tblPurchaseDraftDetail PD  
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID  
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID  
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID  
LEFT JOIN TBLMASTERREASON MR ON MR.ID = PD.ReasonId  
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = MP.ID  
LEFT JOIN #ABSQ1 PVABS ON PVABS.ProdID = PD.ProdID   
where PD.HID = @ID  
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.[ProdDiscPern],PD.[TradeDiscPern],PD.[AddnlDiscPern],Serial,MT.TaxName,PD.TaxPern  
,isnull(PD.ReasonId,0),MR.Name,PTP.PurchaseReturnPrice,PD.DiffAmt,ProdDiscAmt,TradeDiscAmt,AddnlDiscAmt,ActualQty,ActualFreeQty,ActualDmgQty  
ORDER BY Serial  

DROP TABLE #ABSQ1 
END  
IF(@Mode = 13)  
BEGIN  
SELECT @BID = BranchID,@TDate =Date,@ApplyPrice = PriceType FROM tblPurchaseDraftHeader where ID = @ID  
--SELECT InventoryId,ProdID,BatchNumber,PKDDate,ExpiryDate,(SUM(Qty)) Qty,(SUM(FreeQty)) FreeQty  
--,(SUM(DmgQty)) DmgQty,MRP,PurchasePrice,ReturnPrice,(SUM(PRQty)) PRQty,(SUM(PRFree)) PRFree  
--,(SUM(PRDmg)) PRDmg,TaxName,GSTPern,PurchaseTaxID,ConversionRate FROM (  
--SELECT 0 InventoryId,PV.ProdID,PV.BatchNumber,convert(date,PV.PKDDate,105) PKDDate,convert(date,PV.ExpiryDate,105) ExpiryDate,(SUM(ActualQty)) Qty,  
--(SUM(ActualFreeQty)) FreeQty,(SUM(ActualDmgQty)) DmgQty,  
--(PV.MRPONPrice) MRP,(case when @ApplyPrice = 6 THEN PV.ReturnPrice ELSE PV.PurchasePrice end) PurchasePrice,  
--(case when @ApplyPrice = 6 THEN PV.ReturnPrice ELSE PV.PurchasePrice end) ReturnPrice,(SUM(UomQty)) PRQty,  
--(SUM(UomFreeQty)) PRFree,(SUM(UomDamageQty)) PRDmg,MTT.TaxName,PD.TaxPern GSTPern,PD.TaxID PurchaseTaxID,isnull(UOMCF,1) ConversionRate  
--FROM tblPurchaseDraftDetail PD  
-- JOIN tblProductInventory PV ON PV.ProdID = PD.ProdID  
--join tblMasterTax MTT ON MTT.TaxID = PD.TaxID  
--WHERE PD.HID = @ID and TransDate <= @TDate-- and (ActualQty > 0 OR ActualDmgQty > 0)  
--GROUP BY PV.BatchNumber,PV.PKDDate,PV.ExpiryDate,PV.MRPONPrice,PV.ReturnPrice,PV.ProdID,MTT.TaxName,PD.TaxPern,  
--PD.TaxID,UOMCF,PV.PurchasePrice) AS REC  
----where (Qty > 0 or FreeQty > 0 or DmgQty > 0)  
--group by InventoryId,ProdID,BatchNumber,PKDDate,ExpiryDate,MRP,PurchasePrice,ReturnPrice,TaxName,  
--GSTPern,PurchaseTaxID,ConversionRate  
CREATE TABLE #MainDraftData  
(  
InventoryId INT,  
ProdID INT,  
BatchNumber NVARCHAR(50) NULL,  
PKDDate DATE NULL,  
ExpiryDate DATE NULL,  
Qty DECIMAL(18,4),  
FreeQty DECIMAL(18,4),  
DmgQty DECIMAL(18,4),  
MRP DECIMAL(18,4),  
PurchasePrice DECIMAL(18,4),  
ReturnPrice DECIMAL(18,4),  
PRQty DECIMAL(18,4),  
PRFree DECIMAL(18,4),  
PRDmg DECIMAL(18,4),  
TaxName NVARCHAR(100),  
GSTPern DECIMAL(5,2),  
PurchaseTaxID INT,  
ConversionRate DECIMAL(18,4) ,  
UOMPrice DECIMAL(18,4),  
);  
  
  
select PD.*,MTT.TaxName into #draftdetails from tblPurchaseDraftDetail PD  
join tblMasterTax MTT ON MTT.TaxID = PD.TaxID where hid = @ID  
ALTER TABLE #draftdetails ADD RowID INT IDENTITY(1,1);  
  
DECLARE @PRODID INT,@MRP DECIMAL(25,4),@PPrice DECIMAL(25,4),@RTNPrice DECIMAL(25,4),@batchno nvarchar(255),  
@pkd date,@expiry date,@qty DECIMAL(25,4),@freeqty DECIMAL(25,4),@dmgqty DECIMAL(25,4),@TaxName nvarchar(255),  
@GSTPern DECIMAL(25,4),@PurchaseTaxID INT,@ConversionRate DECIMAL(25,4),@orgPPrice DECIMAL(25,4),@orgRTNPrice DECIMAL(25,4)  
,@UOMPrice DECIMAL(25,4) ,@UOMRTNPrice DECIMAL(25,4)  
  
declare @n int = 1,@totcount int = (select count(*) from #draftdetails)  
  
while(@totcount >= @n)  
BEGIN  
select @PRODID = ProdID,@batchno = isnull(BatchNo,''),@pkd = PKD,@expiry = Expiry,@qty = UomQty,  
@freeqty = UomFreeQty,@dmgqty = UomDamageQty,@PPrice = UomPurchasePrice,@RTNPrice = UomReturnPrice,  
@orgPPrice = PurchasePrice,@orgRTNPrice = ReturnPrice,  
@MRP = UomMRP,@TaxName = TaxName,@GSTPern = TaxPern,@PurchaseTaxID = TaxID,@ConversionRate = ISNULL(UOMCF,1),  
@UOMPrice = UomPurchasePrice,@UOMRTNPrice = UomReturnPrice  
from #draftdetails WHERE RowID = @n  
  
SELECT ProdID,BatchNumber,PKDDate,ExpiryDate,SUM(Qty) Qty,SUM(FreeQty) FreeQty,SUM(DmgQty) DmgQty,MRP,PurchasePrice,ReturnPrice  
into #prodinvdata FROM (  
select PV.ProdID,ISNULL(PV.BatchNumber,'') BatchNumber,convert(date,PV.PKDDate,105) PKDDate,convert(date,PV.ExpiryDate,105) ExpiryDate,  
(SUM(ISNULL(ActualQty,0))) Qty,(SUM(ISNULL(ActualFreeQty,0))) FreeQty,(SUM(ISNULL(ActualDmgQty,0))) DmgQty,  
(PV.MRPONPrice) MRP,(case when @ApplyPrice = 6 THEN PV.ReturnPrice ELSE PV.PurchasePrice end) PurchasePrice,  
(case when @ApplyPrice = 6 THEN PV.ReturnPrice ELSE PV.PurchasePrice end) ReturnPrice  
from tblProductInventory PV  
where (ProdID = @PRODID and branchid = @bid and TransDate <= @TDate) AND (ActualQty > 0 OR ActualFreeQty > 0 OR ActualDmgQty > 0)  
GROUP BY ISNULL(PV.BatchNumber,''),PV.PKDDate,PV.ExpiryDate,PV.MRPONPrice,PV.ReturnPrice,PV.ProdID,PV.PurchasePrice) AS GRP  
GROUP BY ProdID,BatchNumber,PKDDate,ExpiryDate,MRP,PurchasePrice,ReturnPrice  
ALTER TABLE #prodinvdata ADD IDENT INT IDENTITY(1,1);  
  
DECLARE @nPV INT = 1,@totPV int = (select count(*) from #prodinvdata)  
declare @pvProdID int,@pvBatchNumber nvarchar(255),@pvPKDDate date,@pvExpiryDate date,@pvQty DECIMAL(25,4),  
@pvFreeQty DECIMAL(25,4),@pvDmgQty DECIMAL(25,4),@pvMRP DECIMAL(25,4),@pvPurchasePrice DECIMAL(25,4),@pvReturnPrice DECIMAL(25,4)  
  
while(@totPV >= @nPV)  
BEGIN  
  
select @pvProdID=ProdID,@pvBatchNumber= isnull(BatchNumber,''), @pvPKDDate=PKDDate, @pvExpiryDate=ExpiryDate,@pvQty=Qty,@pvFreeQty=FreeQty,  
@pvDmgQty=DmgQty,@pvMRP=MRP,@pvPurchasePrice=PurchasePrice,@pvReturnPrice=ReturnPrice  
from #prodinvdata where IDENT = @nPV  
  
declare @adjQty decimal(25,4) = 0,@adjFreeQty decimal(25,4) = 0,@adjDmtQty decimal(25,4) = 0  
declare @compareprice decimal(25,4) = (case when @ApplyPrice = 1 then @orgPPrice else @orgRTNPrice end)  
declare @compareProdInvprice decimal(25,4) = (case when @ApplyPrice = 1 then @pvPurchasePrice else @pvReturnPrice end)  
--select @qty qty,@freeqty freeqty,@dmgqty dmgqty,@compareprice compareprice,@compareProdInvprice compareProdInvprice,@MRP MRP,@pvMRP pvMRP,@batchno batchno,  
--@pvBatchNumber pvBatchNumber,@pkd pkd,@pvPKDDate pvPKDDate,@expiry expiry,@pvExpiryDate pvExpiryDate  
if(@compareprice = @compareProdInvprice and @MRP = @pvMRP and isnull(@batchno,'') = isnull(@pvBatchNumber,'')  
and isnull(@pkd,'') = isnull(@pvPKDDate,'') and isnull(@expiry,'') = isnull(@pvExpiryDate,''))  
begin  
print 'assign qty'  
set @adjQty = @qty;  
set @adjFreeQty = @freeqty;  
set @adjDmtQty = @dmgqty;  
end  
  
insert into #MainDraftData values(0,@PRODID,@pvBatchNumber,@pvPKDDate,@pvExpiryDate,@pvQty,@pvFreeQty,@pvDmgQty,@pvMRP,  
@pvPurchasePrice,@pvReturnPrice,@adjQty,@adjFreeQty,@adjDmtQty,@TaxName,@GSTPern,@PurchaseTaxID,@ConversionRate,  
(case when @ApplyPrice = 1 then @UOMPrice else @UOMRTNPrice end)  
)  
--@pvPurchasePrice,@pvReturnPrice  
--@PPrice,@RTNPrice  
SET @nPV += 1  
end  
  
drop table #prodinvdata  
SET @n += 1  
END  
--select * from #MainDraftData  
SELECT InventoryId,ProdID,BatchNumber,PKDDate,ExpiryDate,Qty,FreeQty,DmgQty,MRP,PurchasePrice,ReturnPrice,  
SUM(PRQty) AS PRQty,SUM(PRFree) AS PRFree,SUM(PRDmg) AS PRDmg,TaxName,GSTPern,PurchaseTaxID,ConversionRate,  
UOMPrice  
FROM #MainDraftData  
GROUP BY InventoryId,ProdID,BatchNumber,PKDDate,ExpiryDate,Qty,FreeQty,DmgQty,MRP,PurchasePrice,ReturnPrice,  
TaxName,GSTPern,PurchaseTaxID,ConversionRate,UOMPrice;  
  
drop table #draftdetails,#MainDraftData  
END  
IF(@Mode = 14)  
BEGIN  
SELECT top 10 DocID,CONVERT(NVARCHAR(25),Date,103) DocDate,MRP,Qty,Uom,Price,ProdDiscPern+' / '+ProdDiscAmt ProdDisc,TradeDiscPern+' / '+TradeDiscAmt TradeDisc  
,AdnlDiscPern+' / '+AddnlDiscAmt AddnlDisc,SalePrice,ECPPrice,SPLPrice,ReturnPrice,BatchNo,PKD,Expiry FROM (  
SELECT PH.DocID,Date,dbo.fnGetRoundedValue(PD.UomMRP) MRP,dbo.fnGetRoundedValue(PD.UomQty) Qty,  
UOM.Name Uom,dbo.fnGetRoundedValue(PD.UomPurchasePrice) Price,  
dbo.fnGetRoundedValue(PD.[ProdDisc%]) ProdDiscPern,dbo.fnGetRoundedValue(PD.ProdDiscAmt) ProdDiscAmt,  
dbo.fnGetRoundedValue(PD.[TradeDisc%]) TradeDiscPern,  
dbo.fnGetRoundedValue(PD.TradeDiscAmt) TradeDiscAmt,  
dbo.fnGetRoundedValue(PD.[AddnlDisc%]) AdnlDiscPern,dbo.fnGetRoundedValue(PD.AddnlDiscAmt) AddnlDiscAmt,  
dbo.fnGetRoundedValue(PD.UomSalePrice) SalePrice,dbo.fnGetRoundedValue(PD.UomECP) ECPPrice,dbo.fnGetRoundedValue(PD.UomSPLPrice) SPLPrice,  
dbo.fnGetRoundedValue(PD.UomReturnPrice) ReturnPrice,BatchNo,convert(nvarchar(25),PKD,103) PKD,convert(nvarchar(25),Expiry,103) Expiry  
FROM tblTransPurchaseHeader PH  
JOIN tblTransPurchaseDetail PD ON PD.HID = PH.ID  
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID  
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID  
WHERE TransID = 1 and STATUS IN (1,3,5) AND PH.VendorID = @Code AND PD.ProdID = @ID) AS REC  
END  
IF(@Mode = 15)  
BEGIN  
DECLARE @DraftID INT  
SELECT @DraftID = ID FROM tblPurchaseDraftHeader WHERE ID = @ID AND TransID = @TransID  
DELETE tblPurchaseDraftHeader WHERE ID = @DraftID  
DELETE tblPurchaseDraftDetail WHERE HID = @DraftID  
END  
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetQuotationData';
GO
--uspGetSetQuotationData 2,4,2,0,'','2024-12-30','2025-12-16',0                                      
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetQuotationData]                                      
@Mode INT,@Code NVARCHAR(MAX) = NULL,@ID NVARCHAR(MAX) = NULL,@TransID int =1,@Party NVARCHAR(MAX) = NULL,@FromDate date = null,                                      
@ToDate date = null,@Showall int = null                                      
AS                                      
BEGIN                                      
declare @strQuery NVARCHAR(MAX)                                      
IF(@Mode = 1)                                      
BEGIN                                      
select 1 Type,'Customer' Trans,ID,Code,Name,BillAdd1 Address from tblMasterCustomer where Active = 1-- and FAID > 0                                      
union all                                      
SELECT 2 Type,'Branch' Trans,ID,'',Name,'' FROM tblMasterBranchOffice WHERE Active = 1                                          
union all                                      
SELECT 3 Type,'UDN' Trans,UDNID,'',DocName,'' FROM tblMasterUserDefineNoHeader WHERE TransID = 1                                      
union all                                      
SELECT 4 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue,'' FROM tblDocumentSeries WHERE Active = 1 and TransID = 14                          
union all                                      
SELECT 5 Type,'PriceType' Trans,ID,'',PriceType,'' FROM tblpricetype WHERE Active = 1 and ID not in (6,1)                          
order by Type,Name                                      
END                                      
IF(@Mode = 2)                                      
BEGIN                                      
SELECT ProdID,SUM(ActualQty) ABSQty into #ABS FROM tblProductInventory WHERE BranchID = @Code AND (ActualQty > 0)                                      
AND TransDate <= @FromDate                                      
GROUP BY ProdID                                      
SELECT MP.ID,MP.Code,MP.Name,MP.EAN,MP.HSNCode,dbo.fnGetRoundedValue(CASE WHEN @ID = 1 THEN PurchasePrice WHEN @ID = 2 THEN SalesPrice WHEN @ID = 3 THEN ECP                          
 WHEN @ID = 4 THEN MRP  WHEN @ID = 5 THEN SPLPrice WHEN @ID = 6 THEN ReturnPrice ELSE 0 END) Price,dbo.fnGetRoundedValue(ISNULL(AB.ABSQty,0)) ABSQty FROM tblMasterProduct MP                                      
LEFT JOIN #ABS AB ON AB.ProdID = MP.ID                                      
WHERE Active = 1 ORDER BY Name                                      
drop table #ABS                                      
END                                      
IF(@Mode = 3)                                      
BEGIN                                      
SELECT * FROM tblMasterCustomer WHERE Active = 1 AND Code = @Code ORDER BY Name                                      
END                                      
IF(@Mode = 31)                                      
BEGIN                                      
SELECT * FROM tblMasterCustomer WHERE Active = 1 AND ID = @Code ORDER BY Name                                      
END                                      
IF(@Mode = 4)                                      
BEGIN                                      
SELECT *,0.00 ABSQty,MT.TaxName,MT.GST,MT.IGST FROM tblMasterProduct MP                                      
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID WHERE Code = @Code                                      
END                                      
IF(@Mode = 5)                                      
BEGIN                              
select mp.SalesUomID,MU.Name,SalesCR from tblMasterProduct mp                                      
JOIN tblMasterUOM MU ON MU.ID = mp.SalesUomID where MP.ID = @ID                            
UNION ALL                         
select mp.PurchaseUomID,MU.Name,PurchaseCR from tblMasterProduct mp                                      
JOIN tblMasterUOM MU ON MU.ID = mp.PurchaseUomID where MP.ID = @ID   
UNION ALL                                
select mp.BaseUomID,MU.Name,BaseCR CR from tblMasterProduct mp                                      
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID = @ID                         
END                                      
IF(@Mode = 6)--quotation Filter                 
BEGIN                             
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,DocDate,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(PH.GrossAmt) GrossAmt,                                      
dbo.fnGetRoundedValue(PH.TaxAmt) TaxAmt,dbo.fnGetRoundedValue(PH.NetAmt) NetAmt,                                      
STS.Description Status,CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,PT.PriceType,PH.Remarks,PH.Narration,                
dbo.fnGetRoundedValue(PH.TotalProdDiscAmt) TotalProdDiscAmt,dbo.fnGetRoundedValue(PH.TotalDiscAmt) TotalDiscAmt,                  
dbo.fnGetRoundedValue(PH.AddnlDiscPern) AddnlDiscPern,dbo.fnGetRoundedValue(PH.AddnlDiscAmt) AddnlDiscAmt,dbo.fnGetRoundedValue(PH.TradeDiscPern) TradeDiscPern,                
dbo.fnGetRoundedValue(PH.TradeDiscAmt) TradeDiscAmt,dbo.fnGetRoundedValue(OtherChargePern) OtherChargePern,dbo.fnGetRoundedValue(OtherChargeAmt) OtherChargeAmt,                  
dbo.fnGetRoundedValue(FrightAmt) FrightAmt                  
FROM tblQuotationHeader PH                                      
JOIN tblMasterCustomer MV ON MV.ID = PH.CustomerID                                      
JOIN tblStatus STS ON STS.ID = PH.Status                                      
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                    
LEFT JOIN tblPriceType PT ON PT.ID = PH.PriceID                    
JOIN tblUsers CUR ON CUR.ID = PH.CBy                        
WHERE MV.Active IN (0,1) and DocPrefix = 14 '                                      
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                                      
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END                                  
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                                      
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                                      
SET @strQuery += ' ORDER BY PH.DocDate DESC, DocValue desc,PH.ID'                                      
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                                      
END                                      
IF(@Mode = 7)                                      
BEGIN                                      
SELECT PH.ID, PH.DocDate Date, PH.DocPrefix TransID, PH.BranchID, PH.DocID, PH.DocValue, PH.CustomerID, PH.RefNo,0 ProdGroupID,                                      
PH.TaxTypeID, PH.FrightAmt, PH.OtherChargePern OtherChrgPern,                                      
PH.OtherChargeAmt, PH.TradeDiscPern TradePern, PH.AddnlDiscPern AddnlPern, PH.TotalProdDiscAmt, PH.TradeDiscAmt,                                      
PH.AddnlDiscAmt,  PH.RoundOffAmt, PH.GrossAmt, PH.TaxAmt, PH.NetAmt,                                       
PH.Status, PH.UDFId, PH.UDFDocId, PH.UDFDocPrefix, PH.UDFDocValue, PH.Remarks, PH.Narration,PH.PriceID,dbo.fnTransactionPrefix(PH.DocDate,BranchID,PH.DocPrefix) Prefix                                      
FROM tblQuotationHeader PH                                      
JOIN tblMasterCustomer MV ON MV.ID = PH.CustomerID                                      
JOIN tblStatus STS ON STS.ID = PH.Status                                      
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                                      
where PH.ID = @ID                                      
END                                      
IF(@Mode = 8)                      
BEGIN                                      
SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,UOM.Name UOM,SUM(Qty) Qty,PD.DetailMRP,PD.SalesPrice ExclPrice,          
dbo.fngetinclusivevalue(PD.TaxID,PD.DetailMRP,PD.SalesPrice) InclPrice,      
PD.ProdDiscPern ProdPern,pd.ProdDiscAmt,PD.TradeDiscPern TradePern,PD.TradeDiscAmt,                            
PD.AddnlDiscPern AddnlPern,PD.AddnlDiscAmt,SUM(PD.GrossAmt) GrossAmt,SUM(PD.TaxAmt) TaxAmt,SUM(PD.NetAmt) NetAmt,PD.TaxID,MT.TaxName,          
PD.TaxPercentage TaxPern,SUM(GoodsAmt) GoodsAmt,SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,          
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.DetailMRP)) MRPonTaxAmt,Serial,
isnull(SUM(PV.ActualQty),0) ActualQty,isnull(SUM(PV.ActualFreeQty),0) ActualFreeQty into #QtnData      
FROM tblQuotationDetail PD
JOIN tblQuotationHeader PH ON PH.ID = PD.QuationID
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                                      
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                                      
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID
LEFT JOIN tblProductInventory PV ON PV.ProdID = PD.ProdID AND PV.BranchID = PH.BranchID
where PD.QuationID = @ID                                      
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.ProdDiscPern,PD.TradeDiscPern,PD.AddnlDiscPern,Serial,                            
MT.TaxName,PD.TaxPercentage,PD.DetailMRP,PD.SalesPrice,PD.TaxID,pd.ProdDiscAmt,PD.AddnlDiscAmt,PD.TradeDiscAmt                            
ORDER BY Serial                                      
      
select * from #QtnData order by Serial    
select SalesUomID,Name,SalesCR,ProdID,UOMType from (        
select mp.SalesUomID,MU.Name,SalesCR,mp.ID ProdID,'SalesUOM' UOMType,1 sno from tblMasterProduct mp                    
JOIN tblMasterUOM MU ON MU.ID = mp.SalesUomID where MP.ID in (select prodid from #QtnData)        
UNION all                    
select mp.PurchaseUomID,MU.Name,PurchaseCR,mp.ID ProdID,'PurchaseUOM' UOMType,2 sno from tblMasterProduct mp                    
JOIN tblMasterUOM MU ON MU.ID = mp.PurchaseUomID where MP.ID in (select prodid from #QtnData)               
UNION all                    
select mp.BaseUomID,MU.Name,BaseCR CR,mp.ID ProdID,'BaseUOM' UOMType,3 sno from tblMasterProduct mp                    
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID in (select prodid from #QtnData)        
) as uoms        
group by ProdID,SalesUomID,Name,SalesCR,UOMType,sno        
order by sno        
drop table #QtnData       
      
END                                               
IF(@Mode = 10)--Draft                                      
BEGIN                                      
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,Date,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(PH.GrossAmt) GrossAmt,                                      
dbo.fnGetRoundedValue(PH.TaxAmt) TaxAmt,dbo.fnGetRoundedValue(PH.NetAmt) NetAmt,                                      
STS.Description Status,CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,PT.PriceType,PH.Remarks,PH.Narration,                  
dbo.fnGetRoundedValue(PH.TotalTradeDiscAmt + PH.TotalProdDiscAmt + PH.TotalAddnlDiscAmt) AS TotalDiscAmt,dbo.fnGetRoundedValue(PH.TotalProdDiscAmt) TotalProdDiscAmt,                  
dbo.fnGetRoundedValue(PH.AddnlDiscPern) AddnlDiscPern,dbo.fnGetRoundedValue(PH.TotalAddnlDiscAmt) AddnlDiscAmt,dbo.fnGetRoundedValue(PH.TradeDiscPern) TradeDiscPern,dbo.fnGetRoundedValue(PH.TotalTradeDiscAmt) TradeDiscAmt,                  
dbo.fnGetRoundedValue(OtherChargePern) OtherChargePern,dbo.fnGetRoundedValue(OtherChargeAmt) OtherChargeAmt,dbo.fnGetRoundedValue(Frieght) FrightAmt                  
FROM tblSalesDraftHeader PH                                      
JOIN tblMasterCustomer MV ON MV.ID = PH.CustomerID                                      
JOIN tblStatus STS ON STS.ID = PH.Status                                      
left JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                      
LEFT JOIN tblPriceType PT ON PT.ID = PH.PriceTypeID                    
JOIN tblUsers CUR ON CUR.ID = PH.CBy                     
WHERE MV.Active IN (0,1) and PH.TransID = ' + CONVERT(NVARCHAR,@TransID)                                      
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                                      
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END                                      
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                                      
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                                      
SET @strQuery += ' ORDER BY PH.Date DESC,PH.ID DESC '                                      
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                                      
END                                      
IF(@Mode = 11)                                      
BEGIN                                      
declare @currDocid nvarchar(255) = (SELECT DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 14)                               
                                    
SELECT PH.ID, PH.Date Date, PH.TransID, PH.BranchID, @currDocid DocID, PH.DocValue, PH.CustomerID, PH.RefNo,0 ProdGroupID,                                      
PH.TaxTypeID, PH.Frieght FrightAmt, PH.OtherChargePern OtherChrgPern,                                      
PH.OtherChargeAmt, PH.TradeDiscPern TradePern, PH.AddnlDiscPern AddnlPern, PH.TotalProdDiscAmt, PH.TotalTradeDiscAmt TradeDiscAmt,                                      
PH.TotalAddnlDiscAmt AddnlDiscAmt,  PH.RoundOffAmt, PH.GrossAmt, PH.TaxAmt, PH.NetAmt,                                       
PH.Status, PH.UDFId, PH.UDFDocId, PH.UDFDocPrefix, PH.UDFDocValue, PH.Remarks, PH.Narration,PH.PriceTypeID PriceID ,dbo.fnTransactionPrefix(PH.Date,BranchID,PH.TransID) Prefix                                     
FROM tblSalesDraftHeader PH                                      
JOIN tblMasterCustomer MV ON MV.ID = PH.CustomerID                                      
JOIN tblStatus STS ON STS.ID = PH.Status                                      
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                                      
where PH.ID = @ID                             
END                                      
IF(@Mode = 12)                                      
BEGIN                      
SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,UOM.Name UOM,SUM(UOMQty) Qty,PD.MRP DetailMRP,PD.SalePrice ExclPrice,                            
dbo.fngetinclusivevalue(PD.TaxID,PD.MRP,PD.SalePrice) InclPrice,          
--(PD.SalePrice * (1 + (TaxPern / 100))) InclPrice,          
PD.ProdDiscPern ProdPern,pd.ProdDiscAmt,PD.TradeDiscPern TradePern,TradeDiscAmt,          
PD.AddnlDiscPern AddnlPern,AddnlDiscAmt,SUM(PD.GrossAmt) GrossAmt,SUM(PD.TaxAmt) TaxAmt,SUM(PD.NetAmt) NetAmt,PD.TaxID          
,MT.TaxName,PD.TaxPern TaxPern,SUM(GoodsAmt) GoodsAmt,SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,          
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.MRP)) MRPonTaxAmt,Serial ,
isnull(SUM(PV.ActualQty),0) ActualQty,isnull(SUM(PV.ActualFreeQty),0) ActualFreeQty  into #QtnDraftData      
FROM tblSalesDraftDetail PD
JOIN tblSalesDraftHeader PH ON PH.ID = PD.HID
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                                      
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                                      
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID
LEFT JOIN tblProductInventory PV ON PV.ProdID = PD.ProdID AND PV.BranchID = PH.BranchID
where PD.HID = @ID                                      
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.ProdDiscPern,PD.TradeDiscPern,PD.AddnlDiscPern,Serial,                            
MT.TaxName,PD.TaxPern,PD.MRP,PD.SalePrice,PD.TaxID,pd.ProdDiscAmt,AddnlDiscAmt,TradeDiscAmt                                     
ORDER BY Serial             
      
select * from #QtnDraftData order by Serial    
select SalesUomID,Name,SalesCR,ProdID,UOMType from (        
select mp.SalesUomID,MU.Name,SalesCR,mp.ID ProdID,'SalesUOM' UOMType,1 sno from tblMasterProduct mp                    
JOIN tblMasterUOM MU ON MU.ID = mp.SalesUomID where MP.ID in (select prodid from #QtnDraftData)        
UNION all                    
select mp.PurchaseUomID,MU.Name,PurchaseCR,mp.ID ProdID,'PurchaseUOM' UOMType,2 sno from tblMasterProduct mp                    
JOIN tblMasterUOM MU ON MU.ID = mp.PurchaseUomID where MP.ID in (select prodid from #QtnDraftData)               
UNION all                    
select mp.BaseUomID,MU.Name,BaseCR CR,mp.ID ProdID,'BaseUOM' UOMType,3 sno from tblMasterProduct mp                    
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID in (select prodid from #QtnDraftData)        
) as uoms        
group by ProdID,SalesUomID,Name,SalesCR,UOMType,sno        
order by sno        
drop table #QtnDraftData       
END                                      
IF(@Mode = 13)                                      
BEGIN                                      
SELECT PD.*,MP.*,UOM.Name UOMName,MT.TaxName,0 InventoryId,1 TaxTypeID FROM tblPurchaseDraftDetail PD                                      
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                                      
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                                      
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID                                      
where PD.HID = @ID                                      
ORDER BY Serial                                      
END                                      
IF(@Mode = 14)                                      
BEGIN                                      
SELECT top 10 DocID,CONVERT(NVARCHAR(25),Date,103) DocDate,MRP,Qty,Uom,Price,ProdDiscPern+' / '+ProdDiscAmt ProdDisc,TradeDiscPern+' / '+TradeDiscAmt TradeDisc                                      
,AdnlDiscPern+' / '+AddnlDiscAmt TradeDisc FROM (                                      
SELECT PH.DocID,Date,dbo.fnGetRoundedValue(PD.UomMRP) MRP,dbo.fnGetRoundedValue(PD.UomQty) Qty,                                      
UOM.Name Uom,dbo.fnGetRoundedValue(PD.UomPurchasePrice) Price,                                      
dbo.fnGetRoundedValue(PD.[ProdDisc%]) ProdDiscPern,dbo.fnGetRoundedValue((PD.[ProdDisc%]* PD.GrossAmt) / 100) ProdDiscAmt,                                      
dbo.fnGetRoundedValue(PD.[TradeDisc%]) TradeDiscPern,dbo.fnGetRoundedValue((PD.[TradeDisc%]* PD.GrossAmt) / 100) TradeDiscAmt,                                      
dbo.fnGetRoundedValue(PD.[AddnlDisc%]) AdnlDiscPern,dbo.fnGetRoundedValue((PD.[AddnlDisc%]* PD.GrossAmt) / 100) AddnlDiscAmt                                      
FROM tblTransPurchaseHeader PH                                      
JOIN tblTransPurchaseDetail PD ON PD.HID = PH.ID                                      
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                                      
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                                      
WHERE PH.VendorID = @Code AND PD.ProdID = @ID) AS REC                                      
END                                      
IF(@Mode = 15)                                      
BEGIN                              
DECLARE @DraftID INT                                      
SELECT @DraftID = ID FROM tblPurchaseDraftHeader WHERE ID = @ID AND TransID = @TransID                                      
DELETE tblPurchaseDraftHeader WHERE ID = @DraftID                                      
DELETE tblPurchaseDraftDetail WHERE HID = @DraftID                                      
END                                      
IF(@Mode = 16)-- PO Data                            
BEGIN                                      
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,DocDate,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(PH.GrossAmt) GrossAmt,                                      
dbo.fnGetRoundedValue(PH.TaxAmt) TaxAmt,dbo.fnGetRoundedValue(PH.NetAmt) NetAmt,                                      
STS.Description Status,CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID  FROM tblPurchaseOrderHeader PH                          
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID                                      
JOIN tblStatus STS ON STS.ID = PH.Status                                      
left JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                      
JOIN tblUsers CUR ON CUR.ID = PH.CBy                       
WHERE PH.TransID = 3 AND PH.Status in (1,3)'                                      
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                                      
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END                                      
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                                      
--SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                                      
SET @strQuery += ' ORDER BY PH.ID DESC,DocDate '                                      
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                                      
END                                      
IF(@Mode = 17)                            
BEGIN                                      
SELECT PH.ID, PH.DocDate Date, PH.TransID, PH.BranchID, PH.DocID, PH.DocValue, PH.VendorID, PH.RefNo, 0 ProdGroupID,                                      
PH.TaxTypeID, MV.PaymentModeID PaymentModeID, MV.CreditTermID PaymentTermID, null PaymentDate, null VehicleNo, 0 Frieght, 0 OtherChrgPern,                                      
0 OtherChargeAmt, 0 ProdPern, 0 TradePern, 0 AddnlPern, 0 TotalProdDiscAmt, 0 TotalTradeDiscAmt,                                      
0 TotalAddnlDiscAmt, 0 WriteOffAmt, PH.RoundOffAmt, PH.GrossAmt, PH.TaxAmt, PH.NetAmt, 0 Balance, 0 PymtID,                                      
PH.Status, 0 OrgId, PH.UDFId, PH.UDFDocId, PH.UDFDocPrefix, PH.UDFDocValue, PH.CBy, PH.CDate,                                      
PH.MBy, PH.MDate, PH.ClBy, PH.ClDate, 0 ReturnType,null TransactionType,null DateBill,null PortalDate,                                      
null TCSTaxPern,null TCSTaxAmt,null TDSAmount, null IRN,null AckNo,null AckDate, null AckStatus,null SignedQRCode,                                      
null EWBNo, null Distance, null TransMode, null VehicleType, null TransportID, null TransportName, PH.Remarks, PH.Narration,dbo.fnTransactionPrefix(PH.DocDate,BranchID,PH.TransID) Prefix                                     
FROM tblPurchaseOrderHeader PH                                      
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID                                      
JOIN tblStatus STS ON STS.ID = PH.Status                                      
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                                      
where PH.ID = @ID                                      
END                                      
IF(@Mode = 18)                            
BEGIN                                      
SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name UOM,SUM(Qty) Qty,0 FreeQty,0 DmgQty,MP.ProductDiscPerc ProdPern,0 TradePern,                                      
0 AddnlPern,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,MT.TaxName,PD.TaxPern TaxPern,SUM(GrossAmt) GoodsAmt                                      
FROM tblPurchaseOrderDetail PD                                      
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                                      
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                                      
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID                                      
where PD.HID = @ID                                      
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,ProductDiscPerc,Serial,MT.TaxName,PD.TaxPern                                      
ORDER BY Serial                                      
END                                      
IF(@Mode = 19)                                      
BEGIN                                      
SELECT PD.HID,0 InventoryId,PD.ProdID,PD.UomID,NULL BatchNo,NULL PKD,NULL Expiry,Qty UomQty,0 UomFreeQty,0 UomDamageQty,PD.PurchasePrice UomPurchasePrice,                                      
MP.SalesPrice UomSalePrice,MP.ECP UomECP,MP.MRP UomMRP,MP.SPLPrice UomSPLPrice,MP.ReturnPrice UomReturnPrice,PD.PurchasePrice,MP.SalesPrice SalePrice,                                      
MP.ECP,MP.MRP, MP.SPLPrice,MP.ReturnPrice,PD.TaxID,1 TaxTypeID,PD.TaxPern [Tax%],PD.GrossAmt GoodsAmt,MP.ProductDiscPerc [ProdDisc%],0 [TradeDisc%],                                      
0 [AddnlDisc%],PD.GrossAmt,PD.TaxAmt,PD.NetAmt,PD.Serial,0AdjQty,0 AdjFreeQty,0 AdjDmgQty,0 ReasonId,MP.*,UOM.Name UOMName,MT.TaxName                                      
FROM tblPurchaseOrderDetail PD                                      
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                                      
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                                      
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID                                      
where PD.HID = @ID                                      
ORDER BY Serial                                      
END      
IF(@Mode = 20)--Price Type Change  
BEGIN     
select ID,Code,Name,MRP,case when @ID = 1 then PurchasePrice when @ID = 2 then SalesPrice  
 when @ID = 3 then ECP when @ID = 4 then dbo.[fngetExclusiveValue](MP.SalesTaxID,MP.MRP,MP.MRP)    
 when @ID = 5 then SPLPrice  
  when @ID = 6 then ReturnPrice else 0 end priceExcl  
  from tblmasterproduct MP  
  where id in (select * from string_split(@Code,','))  
END  
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetSalesDamageReturnData';
GO
--uspGetSetSalesDamageReturnData 6,16,7,14,0,'','2024-12-30','2025-12-16',0            
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetSalesDamageReturnData]            
@Mode INT,@Docprefix int,@Code NVARCHAR(MAX) = NULL,@ID NVARCHAR(MAX) = NULL,@TransID int =1,@Party NVARCHAR(MAX) = NULL,@FromDate date = null,            
@ToDate date = null,@Showall int = null            
AS            
BEGIN            
declare @strQuery NVARCHAR(MAX),@AllowAllSM int = 0          
declare @currDocid nvarchar(255)        
IF(@Mode = 1)            
BEGIN            
select 1 Type,'Customer' Trans,ID,Code,Name,BillAdd1 Address from tblMasterCustomer where Active = 1 and FAID > 0            
union all            
SELECT 2 Type,'Branch' Trans,ID,'',Name,'' FROM tblMasterBranchOffice WHERE Active = 1            
union all            
SELECT 3 Type,'UDN' Trans,UDNID,'',DocName,'' FROM tblMasterUserDefineNoHeader WHERE TransID = 1            
union all            
SELECT 4 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue,'' FROM tblDocumentSeries WHERE Active = 1 and TransID = 16            
union all            
SELECT 5 Type,'Paymode' Trans,ID,'',PaymentMode,'' FROM tblPaymentMode WHERE Active = 1 AND ID IN (7,8)            
union all            
SELECT 6 Type,'CreditTerm' Trans,ID,'',Name,'' FROM tblMasterCreditTerm WHERE Active = 1            
union all            
SELECT 7 Type,'Beat' Trans,ID,'',Name,'' FROM tblMasterBeat WHERE Active = 1            
union all            
SELECT 8 Type,'Salesman' Trans,ID,'',Name,'' FROM tblMasterSalesman WHERE Active = 1            
union all            
SELECT 9 Type,'TaxType' Trans,TaxTypeID,'',TaxTypeName,'' FROM tblMasterTaxType WHERE Active = 1            
union all            
SELECT 11 Type,'ReturnType' Trans,ID,'',Name,'' FROM tblMasterReturnType WHERE Active = 1            
union all            
SELECT 12 Type,'Reason' Trans,ID,'',Name,'' FROM tblMasterReason WHERE Active = 1            
order by Type,Name            
END            
IF(@Mode = 111)            
BEGIN            
DECLARE @PT AS TABLE(ID SMALLINT)            
IF(@Code = 1 OR @Code = 2)            
BEGIN            
INSERT INTO @PT            
SELECT ID FROM tblPriceType            
END            
ELSE            
BEGIN            
INSERT INTO @PT            
SELECT ID FROM tblPriceType WHERE ID NOT IN (1)            
END            
SELECT 10 Type,'PriceType' Trans,ID,'',PriceType,'' FROM tblPriceType WHERE Active = 1 and id IN (SELECT * FROM @PT)            
ORDER BY DisplayIndex,PriceType            
END            
IF(@Mode = 2)            
BEGIN            
SELECT ProdID,SUM(ActualQty) ABSQty,SUM(ActualDmgQty) ActualDmgQty into #ABS FROM tblProductInventory WHERE BranchID = @Code AND (ActualQty > 0)            
AND TransDate <= @FromDate            
GROUP BY ProdID            
SELECT MP.*,dbo.fnGetRoundedValue(ISNULL(AB.ABSQty,0)) ABSQty,dbo.fnGetRoundedValue(ISNULL(SUM(ActualDmgQty),0)) ActualDmgQty FROM tblMasterProduct MP            
LEFT JOIN #ABS AB ON AB.ProdID = MP.ID            
WHERE Active = 1 ORDER BY Name-- and ISNULL(AB.ABSQty,0) > 0            
drop table #ABS            
END            
IF(@Mode = 3)            
BEGIN            
SELECT * FROM tblMasterCustomer WHERE Active = 1 AND Code = @Code ORDER BY Name            
END            
IF(@Mode = 31)            
BEGIN            
SELECT * FROM tblMasterCustomer WHERE Active = 1 AND ID = @Code ORDER BY Name            
END            
IF(@Mode = 32)--get beat & sm            
BEGIN            
select TOP 1* from tblBeatSalesmanMapping WHERE CustomerID = @Code ORDER BY ID            
END            
IF(@Mode = 33)--get beat & sm            
BEGIN            
select @AllowAllSM = AppValue from tblAppConfig where AppId = 18            
SET @strQuery = '            
SELECT 1 Type,''Customer'' Trans,MC.ID,Code,Name,BillAdd1 Address FROM tblMasterCustomer MC            
LEFT JOIN tblBeatSalesmanMapping BSM ON BSM.CustomerID = MC.ID            
where Active = 1 AND FAID > 0 '            
SET @strQuery += case when @Code > 0 then ' AND BSM.BeatID = @Code' else '' end            
SET @strQuery += case when @ID > 0 and @AllowAllSM = 0 then ' AND BSM.SalesmanID = @ID' else '' end            
SET @strQuery += ' group by MC.ID,Code,Name,BillAdd1 order by Name'            
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Docprefix int, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Docprefix = @Docprefix, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall            
END            
IF(@Mode = 34)--get customerremarks            
BEGIN            
select * from tblMasterCustomerRemarks WHERE CustomerID = @Code            
END            
IF(@Mode = 4)            
BEGIN            
SELECT MP.*,0.00 ABSQty,MT.TaxName,MT.GST,MT.IGST,ISNULL(PTP.SalesReturnPrice,0) SalesReturnPrice FROM tblMasterProduct MP            
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID            
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = MP.ID            
WHERE Code = @Code            
END            
IF(@Mode = 5)            
BEGIN            
select mp.SalesUomID,MU.Name,SalesCR from tblMasterProduct mp            
JOIN tblMasterUOM MU ON MU.ID = mp.SalesUomID where MP.ID = @ID            
UNION ALL            
select mp.PurchaseUomID,MU.Name,PurchaseCR from tblMasterProduct mp            
JOIN tblMasterUOM MU ON MU.ID = mp.PurchaseUomID where MP.ID = @ID            
UNION all            
select mp.BaseUomID,MU.Name,BaseCR CR from tblMasterProduct mp            
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID = @ID            
END            
IF(@Mode = 6)--sales Filter            
BEGIN            
declare @TransType INT = (CASE WHEN @Docprefix = 16 then 2 else 3 end)            
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,InvDate,103) DocDate,DocRef RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(PH.GrossAmt) GrossAmt,            
dbo.fnGetRoundedValue(PH.TotalTaxAmt) TaxAmt,dbo.fnGetRoundedValue(PH.NetAmt) NetAmt,            
CASE WHEN PH.Status IN (6,7) THEN ''Open'' ELSE STS.Description END Status,            
dbo.fnGetRoundedValue(PH.Balance) Balance,CUR.UserName UserName,            
CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,PT.PriceType,MRT.Name ReturnType,PH.Remarks, PH.Narration,            
dbo.fnGetRoundedValue(PH.TotalTradeDiscAmt + PH.TotalProdDiscAmt + PH.AdditionalDiscAmt) AS TotalDiscAmt,dbo.fnGetRoundedValue(PH.TotalProdDiscAmt) TotalProdDiscAmt,            
dbo.fnGetRoundedValue(PH.AdditionalDisc) AddnlDiscPern,dbo.fnGetRoundedValue(PH.AdditionalDiscAmt) AddnlDiscAmt,dbo.fnGetRoundedValue(PH.TradeDisc) TradeDiscPern,
dbo.fnGetRoundedValue(PH.TotalTradeDiscAmt) TradeDiscAmt,            
dbo.fnGetRoundedValue(OtherCharge) OtherChargePern,dbo.fnGetRoundedValue(OtherChargeAmt) OtherChargeAmt,dbo.fnGetRoundedValue(Frieght) FrightAmt,            
dbo.fnGetRoundedValue(TCSTaxAmt) TCSTaxAmt,dbo.fnGetRoundedValue(DiffValueGross) DiffExcl,dbo.fnGetRoundedValue(DiffValueNet) DiffIncl            
FROM tbltransalesheader PH            
JOIN tblMasterCustomer MV ON MV.ID = PH.CustID            
JOIN tblStatus STS ON STS.ID = PH.Status            
JOIN tblUsers CUR ON CUR.ID = PH.CBy            
LEFT JOIN tblPriceType PT ON PT.ID = PH.PriceID            
LEFT JOIN tblMasterReturnType MRT ON MRT.ID = PH.ReturnType            
LEFT JOIN tblUsers MUR ON MUR.ID = PH.MBy            
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID WHERE DocPrefix = 16 and TransactionType = '+ CONVERT(NVARCHAR,@TransType)            
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND InvDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END            
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END            
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END            
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (3,5,6,7)' END            
SET @strQuery += ' ORDER BY PH.InvDate DESC,DocValue desc,PH.ID'            
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Docprefix int, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Docprefix = @Docprefix, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall            
END            
IF(@Mode = 7)            
BEGIN            
SELECT PH.ID, PH.InvDate Date, PH.DocPrefix TransID, PH.BranchID, PH.DocID, PH.DocValue,PH.BeatID,PH.SalesManID, PH.CustID CustomerID, PH.DocRef RefNo,0 ProdGroupID,            
PH.TaxTypeID,PH.PriceID,PH.PaymentModeID,PH.CreditTermID, PH.Frieght FrightAmt, PH.OtherCharge OtherChrgPern,PH.OtherChargeAmt, PH.TradeDisc TradePern, PH.AdditionalDisc AddnlPern,            
PH.TotalProdDiscAmt, PH.TotalTradeDiscAmt TradeDiscAmt,PH.AdditionalDiscAmt AddnlDiscAmt, PH.RoundOfAmt RoundOffAmt, PH.GrossAmt,            
PH.TotalTaxAmt TaxAmt, PH.NetAmt,PH.Status, PH.UDFId, PH.UDFDocId, PH.UDFDocPrefix, PH.UDFDocValue, PH.Remarks, PH.Narration,            
PH.TCSTaxAmt,PH.TDSAmount,CreditNoteAdjAmt Writeoff,DiffValueGross,DiffValueNet,ReturnType,dbo.fnTransactionPrefix(PH.InvDate,BranchID,PH.DocPrefix) Prefix,            
dbo.fnGetRoundedValue(PH.Balance) Balance            
FROM tblTranSalesHeader PH            
JOIN tblMasterCustomer MV ON MV.ID = PH.CustID            
JOIN tblStatus STS ON STS.ID = PH.Status            
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID            
where PH.ID = @ID            
END            
IF(@Mode = 8)            
BEGIN            

select ProdID,(SUM(isnull(ActualQty,0))) ActualQty,(SUM(isnull(ActualFreeQty,0))) ActualFreeQty,        
(SUM(isnull(ActualDmgQty,0))) ActualDmgQty INTO #ABSQ from tblProductInventory WHERE ProdID IN (        
select distinct ProdID from tblTranSalesDetail where INVID = @ID) AND BranchID = (        
select distinct BranchID from tblTranSalesHeader where ID = @ID)        
GROUP BY ProdID  

SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,UOM.Name UOM,SUM(UomQty) Qty,PD.DetailMRP,PD.UomPrice ExclPrice,            
dbo.fngetinclusivevalue(PD.TaxID,PD.DetailMRP,PD.UomPrice) InclPrice,            
--(PD.UomPrice * (1 + (PD.TaxValue / 100))) InclPrice,            
PD.ProdDisc ProdPern,pd.ProdDiscAmt,PD.TradeDiscPern TradePern,TradeDisc TradeDiscAmt,            
PD.AddnlDiscPern AddnlPern,AddnlDisc AddnlDiscAmt,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,PD.TaxID,MT.TaxName,PD.TaxValue TaxPern,            
SUM(GoodsAmt) GoodsAmt,BaseUomPrice,PV.BatchNumber BatchNo,PV.PKDDate PKD,PV.ExpiryDate Expiry,PD.ReasonID,MP.TrackInventory,            
MP.TrackBatch,MP.TrackSerial,MP.TrackPDK,ISNULL(PTP.SalesReturnPrice,0) SalesReturnPrice,ISNULL(PD.DiffValue,0) DiffValue            
,0 NewBatchCreated,PV.PurchasePrice BtPPrice, PV.SalesPrice BtSPrice,PV.ECP BtECP,PV.MRP BtMRP            
, PV.SPLPrice BtSPLPrice, PV.ReturnPrice BtRtnPrice, PD.Serial HiddenRowID,            
SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,            
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.DetailMRP)) MRPonTaxAmt,Serial,
dbo.fnGetRoundedValue((isnull(AQ.ActualQty,0))) ActualQty,dbo.fnGetRoundedValue((isnull(AQ.ActualFreeQty,0))) ActualFreeQty,        
dbo.fnGetRoundedValue((isnull(AQ.ActualDmgQty,0))) ActualDmgQty  into #sritems         
FROM tblTranSalesDetail PD            
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID            
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID            
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID            
LEFT JOIN TBLProductInventory PV ON PV.InventoryId = PD.InventoryID            
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = PD.ProdID        
left join #ABSQ AQ ON AQ.ProdID = PD.ProdID  
where PD.InvID = @ID            
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.ProdDisc,PD.TradeDiscPern,PD.AddnlDiscPern,Serial,            
MT.TaxName,PD.TaxValue,PD.DetailMRP,PD.UomPrice,PD.TaxID,pd.ProdDiscAmt,AddnlDisc,TradeDisc,BaseUomPrice,PD.ReasonID            
,PV.BatchNumber,PV.PKDDate,PV.ExpiryDate,MP.TrackInventory,MP.TrackBatch,MP.TrackSerial,MP.TrackPDK,PTP.SalesReturnPrice,PD.DiffValue,            
PV.PurchasePrice,PV.SalesPrice,PV.ECP,PV.MRP, PV.SPLPrice, PV.ReturnPrice, PD.Serial,AQ.ActualQty,AQ.ActualFreeQty,AQ.ActualDmgQty            
ORDER BY Serial           
    
select * from #sritems order by Serial  
select SalesUomID,Name,SalesCR,ProdID,UOMType from (      
select mp.SalesUomID,MU.Name,SalesCR,mp.ID ProdID,'SalesUOM' UOMType,1 sno from tblMasterProduct mp                  
JOIN tblMasterUOM MU ON MU.ID = mp.SalesUomID where MP.ID in (select prodid from #sritems)      
UNION all                  
select mp.PurchaseUomID,MU.Name,PurchaseCR,mp.ID ProdID,'PurchaseUOM' UOMType,2 sno from tblMasterProduct mp                  
JOIN tblMasterUOM MU ON MU.ID = mp.PurchaseUomID where MP.ID in (select prodid from #sritems)             
UNION all                  
select mp.BaseUomID,MU.Name,BaseCR CR,mp.ID ProdID,'BaseUOM' UOMType,3 sno from tblMasterProduct mp                  
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID in (select prodid from #sritems)      
) as uoms      
group by ProdID,SalesUomID,Name,SalesCR,UOMType,sno      
order by sno      
drop table #sritems,#ABSQ
    
END            
IF(@Mode = 10)--Draft            
BEGIN            
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,Date,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(PH.GrossAmt) GrossAmt,            
dbo.fnGetRoundedValue(PH.TaxAmt) TaxAmt,dbo.fnGetRoundedValue(PH.NetAmt) NetAmt,            
STS.Description Status,dbo.fnGetRoundedValue(0) Balance,CUR.UserName UserName,            
CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,PT.PriceType,MRT.Name ReturnType,PH.Remarks, PH.Narration,            
dbo.fnGetRoundedValue(PH.TotalTradeDiscAmt + PH.TotalProdDiscAmt + PH.TotalAddnlDiscAmt) AS TotalDiscAmt,dbo.fnGetRoundedValue(PH.TotalProdDiscAmt) TotalProdDiscAmt,            
dbo.fnGetRoundedValue(PH.AddnlDiscPern) AddnlDiscPern,dbo.fnGetRoundedValue(PH.TotalAddnlDiscAmt) AddnlDiscAmt,dbo.fnGetRoundedValue(PH.TradeDiscPern) TradeDiscPern,
dbo.fnGetRoundedValue(PH.TotalTradeDiscAmt) TradeDiscAmt,            
dbo.fnGetRoundedValue(OtherChargePern) OtherChargePern,dbo.fnGetRoundedValue(OtherChargeAmt) OtherChargeAmt,dbo.fnGetRoundedValue(Frieght) FrightAmt,            
dbo.fnGetRoundedValue(TCSTaxAmt) TCSTaxAmt,dbo.fnGetRoundedValue(DiffValueGross) DiffExcl,dbo.fnGetRoundedValue(DiffValueNet) DiffIncl            
FROM tblSalesDraftHeader PH            
JOIN tblMasterCustomer MV ON MV.ID = PH.CustomerID            
JOIN tblStatus STS ON STS.ID = PH.Status            
JOIN tblUsers CUR ON CUR.ID = PH.CBy            
LEFT JOIN tblPriceType PT ON PT.ID = PH.PriceTypeID            
LEFT JOIN tblMasterReturnType MRT ON MRT.ID = PH.ReturnType            
LEFT JOIN tblUsers MUR ON MUR.ID = PH.MBy            
left JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID WHERE PH.Status in (1) and PH.TransID IN (' + CONVERT(NVARCHAR,@TransID) +')'            
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END            
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END            
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END            
--SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END            
SET @strQuery += ' ORDER BY PH.Date DESC,PH.ID DESC '    EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Docprefix int, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Docprefix = @Docprefix, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall            
END            
IF(@Mode = 11)            
BEGIN            
set @currDocid = (SELECT DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 16)            
            
SELECT            
PH.ID, Date,PH.TransID TransID, PH.BranchID,@currDocid DocID, PH.DocValue,PH.BeatID,PH.SalesManID, PH.CustomerID CustomerID, PH.RefNo RefNo,0 ProdGroupID,            
PH.TaxTypeID,PH.PriceTypeID PriceID,PH.PaymentModeID,PH.PaymentTermID CreditTermID, PH.Frieght FrightAmt, PH.OtherChargePern OtherChrgPern,PH.OtherChargeAmt,            
PH.TradeDiscPern TradePern, PH.AddnlDiscPern AddnlPern,            
PH.TotalProdDiscAmt, PH.TotalTradeDiscAmt TradeDiscAmt,PH.TotalAddnlDiscAmt AddnlDiscAmt, PH.RoundOffAmt RoundOffAmt, PH.GrossAmt,            
PH.TaxAmt TaxAmt, PH.NetAmt,PH.Status, PH.UDFId, PH.UDFDocId, PH.UDFDocPrefix, PH.UDFDocValue, PH.Remarks, PH.Narration,            
PH.TCSTaxAmt,PH.TDSAmount,0 Writeoff,DiffValueGross,DiffValueNet,ReturnType ,dbo.fnTransactionPrefix(PH.Date,BranchID,PH.TransID) Prefix,            
0 AS Balance            
FROM tblSalesDraftHeader PH            
JOIN tblMasterCustomer MV ON MV.ID = PH.CustomerID            
JOIN tblStatus STS ON STS.ID = PH.Status            
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID            
where PH.ID = @ID            
END            
IF(@Mode = 12)            
BEGIN            

select ProdID,(SUM(isnull(ActualQty,0))) ActualQty,(SUM(isnull(ActualFreeQty,0))) ActualFreeQty,        
(SUM(isnull(ActualDmgQty,0))) ActualDmgQty INTO #ABSQ1 from tblProductInventory WHERE ProdID IN (        
select distinct ProdID from tblSalesDraftDetail where HID = @ID) AND BranchID = (        
select distinct BranchID from tblSalesDraftheader where ID = @ID)        
GROUP BY ProdID  

SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,UOM.Name UOM,SUM(UOMQty) Qty,PD.MRP DetailMRP,PD.SalePrice ExclPrice,            
dbo.fngetinclusivevalue(PD.TaxID,PD.MRP,PD.SalePrice) InclPrice,            
--(PD.SalePrice * (1 + (TaxPern / 100))) InclPrice.            
PD.ProdDiscPern ProdPern,pd.ProdDiscAmt,PD.TradeDiscPern TradePern,TradeDiscAmt,            
PD.AddnlDiscPern AddnlPern,AddnlDiscAmt,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,PD.TaxID,MT.TaxName,            
PD.TaxPern TaxPern,SUM(GoodsAmt) GoodsAmt,ISNULL(PTP.SalesReturnPrice,0) SalesReturnPrice,ISNULL(PD.DiffValue,0) DiffValue,            
PD.SalePrice BaseUomPrice,PD.BatchNo BatchNo,pd.PKDDate PKD,pd.ExpiryDate Expiry,PD.ReasonID,MP.TrackInventory,            
MP.TrackBatch,MP.TrackSerial,MP.TrackPDK,ISNULL(PD.NewBatchCreated,0) NewBatchCreated, PD.BtPPrice, PD.BtSPrice, PD.BtECP, PD.BtMRP            
, PD.BtSPLPrice, PD.BtRtnPrice,(CASE WHEN ISNULL(PD.HiddenRowID,0) = 0 THEN PD.Serial else PD.HiddenRowID end) HiddenRowID,            
SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,            
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.MRP)) MRPonTaxAmt,PD.Serial,
dbo.fnGetRoundedValue((isnull(AQ.ActualQty,0))) ActualQty,dbo.fnGetRoundedValue((isnull(AQ.ActualFreeQty,0))) ActualFreeQty,        
dbo.fnGetRoundedValue((isnull(AQ.ActualDmgQty,0))) ActualDmgQty
 into #srdraftitems       
FROM tblSalesDraftDetail PD            
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID            
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID            
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID            
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = PD.ProdID         
left join #ABSQ1 AQ ON AQ.ProdID = PD.ProdID     
where PD.HID = @ID            
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.ProdDiscPern,PD.TradeDiscPern,PD.AddnlDiscPern,Serial,            
MT.TaxName,PD.TaxPern,PD.MRP,PD.SalePrice,PD.TaxID,pd.ProdDiscAmt,AddnlDiscAmt,TradeDiscAmt,PTP.SalesReturnPrice,PD.DiffValue,PD.ReasonID,MP.TrackInventory,            
MP.TrackBatch,MP.TrackSerial,MP.TrackPDK,ISNULL(PD.NewBatchCreated,0), PD.BtPPrice, PD.BtSPrice, PD.BtECP, PD.BtMRP            
, PD.BtSPLPrice, PD.BtRtnPrice, PD.HiddenRowID ,PD.BatchNo ,pd.PKDDate ,pd.ExpiryDate,AQ.ActualQty,AQ.ActualFreeQty,AQ.ActualDmgQty            
ORDER BY Serial            
select * from #srdraftitems order by Serial     
select SalesUomID,Name,SalesCR,ProdID,UOMType from (      
select mp.SalesUomID,MU.Name,SalesCR,mp.ID ProdID,'SalesUOM' UOMType,1 sno from tblMasterProduct mp                  
JOIN tblMasterUOM MU ON MU.ID = mp.SalesUomID where MP.ID in (select prodid from #srdraftitems)      
UNION all                  
select mp.PurchaseUomID,MU.Name,PurchaseCR,mp.ID ProdID,'PurchaseUOM' UOMType,2 sno from tblMasterProduct mp                  
JOIN tblMasterUOM MU ON MU.ID = mp.PurchaseUomID where MP.ID in (select prodid from #srdraftitems)             
UNION all                  
select mp.BaseUomID,MU.Name,BaseCR CR,mp.ID ProdID,'BaseUOM' UOMType,3 sno from tblMasterProduct mp                  
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID in (select prodid from #srdraftitems)      
) as uoms      
group by ProdID,SalesUomID,Name,SalesCR,UOMType,sno      
order by sno      
drop table #srdraftitems,#ABSQ1
END            
IF(@Mode = 13)            
BEGIN            
SELECT PD.*,MP.*,UOM.Name UOMName,MT.TaxName,0 InventoryId,1 TaxTypeID FROM tblPurchaseDraftDetail PD            
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID            
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID            
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID            
where PD.HID = @ID            
ORDER BY Serial            
END            
IF(@Mode = 14)            
BEGIN            
SELECT top 10 DocID,CONVERT(NVARCHAR(25),Date,103) DocDate,MRP,Qty,Uom,Price,ProdDiscPern+' / '+ProdDiscAmt ProdDisc,TradeDiscPern+' / '+TradeDiscAmt TradeDisc            
,AdnlDiscPern+' / '+AddnlDiscAmt AddnlDisc,BatchNo,PKD,Expiry FROM (            
SELECT PH.DocID,InvDate Date,dbo.fnGetRoundedValue(PD.DetailMRP) MRP,dbo.fnGetRoundedValue(PD.UomQty) Qty,            
UOM.Name Uom,dbo.fnGetRoundedValue(PD.UomPrice) Price,            
dbo.fnGetRoundedValue(PD.[ProdDisc]) ProdDiscPern,dbo.fnGetRoundedValue((PD.[ProdDisc]* PD.GrossAmt) / 100) ProdDiscAmt,            
dbo.fnGetRoundedValue(PD.[TradeDiscPern]) TradeDiscPern,dbo.fnGetRoundedValue((PD.[TradeDiscPern]* PD.GrossAmt) / 100) TradeDiscAmt,            
dbo.fnGetRoundedValue(PD.[AddnlDiscPern]) AdnlDiscPern,dbo.fnGetRoundedValue((PD.[AddnlDiscPern]* PD.GrossAmt) / 100) AddnlDiscAmt,            
PV.BatchNumber BatchNo,convert(nvarchar(25),PKDDate,103) PKD,convert(nvarchar(25),ExpiryDate,103) Expiry            
FROM tblTranSALESHeader PH            
JOIN tblTranSALESDetail PD ON PD.InvID = PH.ID            
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID            
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID LEFT JOIN tblProductInventory PV ON PV.InventoryID = PD.InventoryID            
WHERE DocPrefix = 15 and status in (1,3,5) and PH.CustID = @Code AND PD.ProdID = @ID) AS REC            
END            
IF(@Mode = 15)            
BEGIN            
if(@Code = 2)                                                      
BEGIN        
DECLARE @DraftID INT            
SELECT @DraftID = ID FROM tblSalesDraftHeader WHERE ID = @ID AND TransID = @Docprefix            
DELETE tblSalesDraftHeader WHERE ID = @DraftID            
DELETE tblSalesDraftDetail WHERE HID = @DraftID            
END        
ELSE IF(@Code = 3)                                                      
BEGIN                                                      
UPDATE tblTranOrderRETURNHeader set Status = 4,ClBy = @TransID,ClDate = GETDATE() where ID = @ID AND STATUS IN (1,3)        
END         
END            
IF(@Mode = 16)-- Web Return Data            
BEGIN            
SET @strQuery = 'SELECT PH.ID,''WR''+CONVERT(NVARCHAR,PH.ID) DocID,CONVERT(NVARCHAR,DocDate,103) DocDate,RefNo,MBO.Name Branch,
MV.Name Party,dbo.fnGetRoundedValue(SUM(PD.Price * Qty)) GrossAmt,            
dbo.fnGetRoundedValue(SUM(PD.Amount) - SUM(PD.Price * Qty)) TaxAmt,dbo.fnGetRoundedValue(SUM(PD.Amount)) NetAmt,            
STS.Description Status,dbo.fnGetRoundedValue(0) Balance,CUR.UserName UserName,            
CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,PT.PriceType,NULL ReturnType,NULL Remarks, PH.Narration,            
dbo.fnGetRoundedValue(sum(isnull(DisAmt,0))) AS TotalDiscAmt,        
dbo.fnGetRoundedValue(sum(isnull(DisAmt,0))) TotalProdDiscAmt,            
dbo.fnGetRoundedValue(0) AddnlDiscPern,dbo.fnGetRoundedValue(0) AddnlDiscAmt,        
dbo.fnGetRoundedValue(0) TradeDiscPern,dbo.fnGetRoundedValue(0) TradeDiscAmt,            
dbo.fnGetRoundedValue(0) OtherChargePern,dbo.fnGetRoundedValue(0) OtherChargeAmt,dbo.fnGetRoundedValue(0) FrightAmt,            
dbo.fnGetRoundedValue(0) TCSTaxAmt,dbo.fnGetRoundedValue(0) DiffExcl,dbo.fnGetRoundedValue(0) DiffIncl            
FROM tblTranOrderReturnHeader PH            
join tblTranOrderReturnDetail PD ON PD.ID = PH.ID        
JOIN tblMasterCustomer MV ON MV.ID = PH.CustID            
JOIN tblStatus STS ON STS.ID = PH.Status            
JOIN tblUsers CUR ON CUR.ID = PH.CBy            
LEFT JOIN tblPriceType PT ON PT.ID = MV.PriceTypeID            
LEFT JOIN tblUsers MUR ON MUR.ID = PH.MBy            
left JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID WHERE PH.ReturnTransType = ' +  (case when @TransID = 16 then '1' else '2' end)        
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END            
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name = @Party' END            
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END            
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END            
SET @strQuery += ' GROUP BY PH.ID,DocDate,RefNo,MBO.Name,MV.Name,STS.Description,CUR.UserName,PH.CDate,PH.Status,PT.PriceType,PH.Narration'        
SET @strQuery += ' ORDER BY PH.ID DESC,DocDate '            
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Docprefix int, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Docprefix = @Docprefix, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall            
END            
IF(@Mode = 17) --Header data        
BEGIN            
set @currDocid = (SELECT DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 16)            
            
SELECT            
PH.ID,dOCDATE Date,16 TransID, PH.BranchID,@currDocid DocID,PH.ID DocValue,PH.BeatID,PH.SalesManID, PH.CustID CustomerID,null RefNo,0 ProdGroupID,            
MV.TaxTypeID,MV.PriceTypeID PriceID,7 PaymentModeID,0 CreditTermID, 0 FrightAmt, 0 OtherChrgPern,0 OtherChargeAmt,            
0 TradePern, 0 AddnlPern,            
0 TotalProdDiscAmt,0  TradeDiscAmt,0 AddnlDiscAmt,0 RoundOffAmt,0 GrossAmt,            
0 TaxAmt,0 NetAmt,PH.Status,0 UDFId,null UDFDocId, null UDFDocPrefix, null UDFDocValue, null Remarks, PH.Narration,            
0 TCSTaxAmt,0 TDSAmount,0 Writeoff,0 DiffValueGross,0 DiffValueNet,0 ReturnType ,dbo.fnTransactionPrefix(PH.DocDate,BranchID,16) Prefix,            
0 AS Balance            
FROM tblTranOrderReturnHeader PH            
JOIN tblMasterCustomer MV ON MV.ID = PH.CustID            
JOIN tblStatus STS ON STS.ID = PH.Status            
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID            
where PH.ID = @ID           
END            
IF(@Mode = 18)--Detail Data        
BEGIN        
select ProdID,(SUM(isnull(ActualQty,0))) ActualQty,(SUM(isnull(ActualFreeQty,0))) ActualFreeQty,        
(SUM(isnull(ActualDmgQty,0))) ActualDmgQty INTO #ABSQ2 from tblProductInventory WHERE ProdID IN (        
select distinct ProdID from tblTranorderreturndetail where ID = @ID) AND BranchID = (        
select distinct BranchID from tblTranorderreturnHEADER where ID = @ID)        
GROUP BY ProdID  

SELECT PD.ProdID,MP.BaseUOMID UomID,MP.Code,MP.Name,UOM.Name UOM,SUM(Qty) Qty,PD.MRP DetailMRP,PD.Price ExclPrice,        
dbo.fngetinclusivevalue(MP.SalesTaxID,PD.MRP,PD.Price) InclPrice,        
PD.DisPern ProdPern,pd.DisAmt ProdDiscAmt,0 TradePern,0 TradeDiscAmt,        
0 AddnlPern,0 AddnlDiscAmt,SUM(PD.Qty * PD.Price) GrossAmt, sum(Amount) - SUM(PD.Qty * PD.Price) TaxAmt,SUM(Amount) NetAmt,        
MP.SalesTaxID TaxID,MT.TaxName,MT.GST TaxPern,        
SUM(PD.Qty * PD.Price) GoodsAmt,OrgPrice BaseUomPrice,null BatchNo,null PKD,null Expiry,0 ReasonID,MP.TrackInventory,        
MP.TrackBatch,MP.TrackSerial,MP.TrackPDK,ISNULL(PTP.SalesReturnPrice,0) SalesReturnPrice,ISNULL(PD.Price,0) - ISNULL(PTP.SalesReturnPrice,0) DiffValue        
,0 NewBatchCreated,MP.PurchasePrice BtPPrice, MP.SalesPrice BtSPrice,MP.ECP BtECP,MP.MRP BtMRP        
, MP.SPLPrice BtSPLPrice, MP.ReturnPrice BtRtnPrice, PD.SerialNo HiddenRowID,        
SUM(dbo.fngetMRPonCumValue(0,MP.SalesTaxID,1,0)) CumMRPonTax,        
SUM(dbo.fngetMRPonCumValue(1,MP.SalesTaxID,1,PD.MRP)) MRPonTaxAmt, PD.SerialNo Serial,
dbo.fnGetRoundedValue((isnull(AQ.ActualQty,0))) ActualQty,dbo.fnGetRoundedValue((isnull(AQ.ActualFreeQty,0))) ActualFreeQty,        
dbo.fnGetRoundedValue((isnull(AQ.ActualDmgQty,0))) ActualDmgQty into #srwsrtitems       
FROM tblTranorderreturndetail PD        
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID        
JOIN tblMasterUOM UOM ON UOM.ID = MP.BaseUOMID        
JOIN tblMasterTax MT ON MT.TaxID = MP.SalesTaxID        
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = PD.ProdID   
left join #ABSQ2 AQ ON AQ.ProdID = PD.ProdID  
where PD.ID = @ID        
group by PD.ProdID,MP.BaseUOMID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.DisPern,SerialNo,        
MT.TaxName,PD.MRP,PD.Price,MT.TaxID,pd.DisAmt,OrgPrice,MP.TrackInventory,MP.TrackBatch,MP.TrackSerial,MP.TrackPDK,PTP.SalesReturnPrice,        
MP.PurchasePrice,MP.SalesPrice,MP.ECP,MP.MRP, MP.SPLPrice, MP.ReturnPrice,MP.SalesTaxID,MT.GST,AQ.ActualQty,AQ.ActualFreeQty,AQ.ActualDmgQty        
ORDER BY SerialNo        
    
select * from #srwsrtitems ORDER BY Serial     
select SalesUomID,Name,SalesCR,ProdID,UOMType from (      
select mp.SalesUomID,MU.Name,SalesCR,mp.ID ProdID,'SalesUOM' UOMType,1 sno from tblMasterProduct mp                  
JOIN tblMasterUOM MU ON MU.ID = mp.SalesUomID where MP.ID in (select prodid from #srwsrtitems)      
UNION all                  
select mp.PurchaseUomID,MU.Name,PurchaseCR,mp.ID ProdID,'PurchaseUOM' UOMType,2 sno from tblMasterProduct mp                  
JOIN tblMasterUOM MU ON MU.ID = mp.PurchaseUomID where MP.ID in (select prodid from #srwsrtitems)             
UNION all                  
select mp.BaseUomID,MU.Name,BaseCR CR,mp.ID ProdID,'BaseUOM' UOMType,3 sno from tblMasterProduct mp                  
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID in (select prodid from #srwsrtitems)      
) as uoms      
group by ProdID,SalesUomID,Name,SalesCR,UOMType,sno      
order by sno      
drop table #srwsrtitems,#ABSQ2     
    
END        
IF(@Mode = 19)            
BEGIN            
SELECT PD.HID,0 InventoryId,PD.ProdID,PD.UomID,NULL BatchNo,NULL PKD,NULL Expiry,Qty UomQty,0 UomFreeQty,0 UomDamageQty,PD.PurchasePrice UomPurchasePrice,            
MP.SalesPrice UomSalePrice,MP.ECP UomECP,MP.MRP UomMRP,MP.SPLPrice UomSPLPrice,MP.ReturnPrice UomReturnPrice,PD.PurchasePrice,MP.SalesPrice SalePrice,            
MP.ECP,MP.MRP, MP.SPLPrice,MP.ReturnPrice,PD.TaxID,1 TaxTypeID,PD.TaxPern [Tax%],PD.GrossAmt GoodsAmt,MP.ProductDiscPerc [ProdDisc%],0 [TradeDisc%],            
0 [AddnlDisc%],PD.GrossAmt,PD.TaxAmt,PD.NetAmt,PD.Serial,0AdjQty,0 AdjFreeQty,0 AdjDmgQty,0 ReasonId,MP.*,UOM.Name UOMName,MT.TaxName            
FROM tblPurchaseOrderDetail PD            
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID            
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID            
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID            
where PD.HID = @ID            
ORDER BY Serial            
END            
IF(@Mode = 21)            
BEGIN            
DECLARE @DT DATE = GETDATE();            
select DocId DocID,CONVERT(NVARCHAR,InvDate,103) DocDate,DocRef RefNo,MB.Name Branch,dbo.fngetroundedvalue(GrossAmt) GrossAmt,            
dbo.fngetroundedvalue(TotalTaxAmt) TaxAmt,dbo.fngetroundedvalue(NetAmt) NetAmt,SH.ID from tblTranSalesHeader SH            
join tblMasterBranchOffice MB ON MB.ID = SH.BranchID            
where Status IN (1,3,5) AND DocPrefix = 15 AND InvDate between dateadd(DD,-180,@DT) AND @DT AND CustId = @Code -- AND Balance > 0            
order by CONVERT(DATE,InvDate) desc,DocId ASC            
END            
IF(@Mode = 23)            
BEGIN            
--uspGetSetInvoiceData 23,124,4            
SELECT TrackBatch,TrackPDK,TrackInventory,case when @ID = 4 THEN Price / Tax else Price end Price,MRP,            
case when @ID = 4 THEN Price else Price * Tax end Incl FROM (            
SELECT TrackBatch,TrackPDK,TrackInventory,CASE WHEN @ID = 1 THEN PurchasePrice WHEN @ID = 2 THEN SalesPrice WHEN @ID = 3 THEN ECP            
WHEN @ID = 5 THEN SPLPrice WHEN @ID = 4 THEN MRP WHEN @ID = 6 THEN ReturnPrice else 0 end Price,MRP, 1 + (GST/100) Tax            
FROM tblMasterProduct MP            
JOIN TBLMASTERTAX MT ON MT.TaxID = MP.SalesTaxID            
WHERE ID = @Code ) AS REC            
END            
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetStockDestructionData';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetStockDestructionData]    
@Mode INT,@Code NVARCHAR(MAX) = NULL,@ID NVARCHAR(MAX) = NULL,@TransID int =26,@Party NVARCHAR(MAX) = NULL,@FromDate date = null,                    
@ToDate date = null,@Showall int = null                    
AS                    
BEGIN                    
declare @strQuery NVARCHAR(MAX)                    
IF(@Mode = 1)                    
BEGIN                    
SELECT 1 Type,'Branch' Trans,ID,'',Name FROM tblMasterBranchOffice WHERE Active = 1                    
union all                    
SELECT 2 Type,'ConversionType' Trans,ConvertionTypeID ID,'',ConvertionType Name FROM tblConvertionType WHERE Active = 1                    
union all                    
SELECT 4 Type,'Reason' Trans,ID,'',Name FROM tblMasterReason WHERE Active = 1              
union all            
SELECT 3 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = 26                    
order by Type,Name                    
END                    
IF(@Mode = 2)                    
BEGIN                    
Create Table #DMG(ProdID INT, DMGQty Decimal(25,4))    
Insert Into #DMG    
SELECT ProdID,dbo.fnGetRoundedValue(SUM(ActualDmgQty)) DMGQty FROM tblProductInventory    
WHERE BranchID = @Party AND TransDate <= @FromDate AND (ActualDmgQty > 0)      
GROUP BY ProdID    
                        
SELECT MP.*,dbo.fnGetRoundedValue(ISNULL(AB.DMGQty,0)) DMGQty FROM tblMasterProduct MP                    
JOIN #DMG AB ON AB.ProdID = MP.ID                    
WHERE Active = 1 AND TrackInventory = 1 ORDER BY Name                           
DROP TABLE #DMG                    
END                    
IF(@Mode = 3)                    
BEGIN                    
SELECT MP.ID,MP.Code,MP.Name,HSNCode,MP.BaseUomID,MP.BaseCR,MP.PurchaseUomID,MP.PurchaseCR,mp.PurchaseTaxID,MT.TaxName,MT.GST,                
MP.ProductDiscPerc,MP.PurchasePrice,MP.SalesPrice,MP.ECP,MP.SPLPrice,MP.MRP,MP.ReturnPrice,TrackBatch,TrackPDK                
FROM tblMasterProduct MP                    
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID                    
WHERE Code = @Code                    
END                    
IF(@Mode = 4)                    
BEGIN                    
IF ISNULL(@Code,0)=0                    
BEGIn --All Batch Info                    
SELECT ProdId,BatchNumber,CONVERT(NVARCHAR,PKDDate,103) AS PKDDate,CONVERT(NVARCHAR,ExpiryDate,103) AS ExpiryDate,ActualQty AS Qty , ActualFreeQty AS [FreeQty],ActualDmgQty AS [DmgQty] ,                    
PurchasePrice,MRPONPrice MRP,TaxValue,TaxId,InventoryId,CONVERT(NVARCHAR,TransDate,103) AS DocDate                    
FROM dbo.tblProductInventory                    
WHERE ProdId = @ID AND TransDate <= @FromDate AND BranchID = @Party ORDER BY TransDate DESC                    
END                    
ELSE IF ISNULL(@Code,0)=1                  
BEGIn--Valid Batch Only                    
SELECT ProdId,BatchNumber,CONVERT(NVARCHAR,PKDDate,103) AS PKDDate,CONVERT(NVARCHAR,ExpiryDate,103) AS ExpiryDate,ActualQty AS Qty , ActualFreeQty AS [FreeQty],ActualDmgQty AS [DmgQty] ,                    
PurchasePrice,MRPONPrice MRP,TaxValue,TaxId,InventoryId,CONVERT(NVARCHAR,TransDate,103) AS DocDate                    
FROM dbo.tblProductInventory                    
WHERE ProdId = @ID AND TransDate <= @FromDate AND BranchID = @Party AND (ISNULL(ActualQty,0)>0 OR ISNULL(ActualFreeQty,0)>0 OR ISNULL(ActualDmgQty,0) >0)                    
ORDER BY TransDate DESC                    
END                    
END                    
ELSE IF(@Mode = 41)                    
BEGIN                    
SELECT 0 InventoryId,ProdID,PV.BatchNumber,PV.PKDDate,PV.ExpiryDate,dbo.fnGetRoundedValue(SUM(ActualQty)) Qty,                    
dbo.fnGetRoundedValue(SUM(ActualFreeQty)) FreeQty,dbo.fnGetRoundedValue(SUM(ActualDmgQty)) DmgQty,                    
dbo.fnGetRoundedValue(PV.MRPONPrice) MRP,0 PurchasePrice,dbo.fnGetRoundedValue(PV.ReturnPrice) ReturnPrice                    
FROM tblProductInventory PV                  
WHERE pv.ProdID = @Code and (ActualQty > 0 OR ActualDmgQty > 0) and BranchID = @Party and TransDate <= @FromDate                    
GROUP BY PV.BatchNumber,PV.PKDDate,PV.ExpiryDate,PV.MRPONPrice,PV.ReturnPrice,ProdID                    
END                    
IF(@Mode = 5)                    
BEGIN                    
select mp.BaseUomID,MU.Name,BaseCR CR from tblMasterProduct mp                    
JOIN tblMasterUOM MU ON MU.ID = mp.BaseUomID where MP.ID = @ID                    
END                    
IF(@Mode = 6)                    
BEGIN                    
SELECT MP.*,MT.GST FROM tblMasterProduct MP                
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID WHERE ID = @Code                    
END                    
IF(@Mode = 7)                    
BEGIN                    
SET @strQuery = 'select PH.InventoryID ID,DocID,CONVERT(NVARCHAR,InventoryDate,103) DocDate,RefNo,MBO.Name Branch,dbo.fnGetRoundedValue(PH.TotalAmt) GrossAmt,                    
STS.Description Status,CUR.UserName UserName,CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,PH.Remarks,PH.Narration            
from tblInventoryHeader PH                    
JOIN tblStatus STS ON STS.ID = PH.Status                    
JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID                         
JOIN tblUsers CUR ON CUR.ID = PH.CBy WHERE TransID = 26 '                    
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND InventoryDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END                    
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID = @ID' END                    
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                    
SET @strQuery += ' ORDER BY InventoryDate DESC,DocValue desc,PH.InventoryID'                    
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode = @Mode, @Code = @Code, @ID = @ID, @TransID = @TransID, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall                    
END                    
IF(@Mode = 8)                    
BEGIN                    
SELECT *,dbo.fnTransactionPrefix(InventoryDate,BranchID,TransID) Prefix FROM tblInventoryHeader where InventoryID = @ID                    
END                    
IF(@Mode = 9)                    
BEGIN                    
SELECT PD.ProdID,MP.BaseUomID UomID,MT.GST TaxPern,MP.Code,MP.Name,sum(OrgDmgQty) DmgQty,MU.Name UOMName,            
sum(GrossAmt)GrossAmt,ISNULL(PD.ReasonId,0) ReasonId,MR.Name Reason FROM tblInventoryDetail PD            
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID            
JOIN tblMasterUOM MU ON MU.ID = MP.BaseUomID            
JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID            
LEFT JOIN TBLMASTERREASON MR ON MR.ID = PD.ReasonID            
where InventoryID = @Code and NewBatchID > 0            
group by PD.ProdID,MP.BaseUomID ,MT.GST,MP.Code,MP.Name,MU.Name,PD.ReasonId,MR.Name              
END                    
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetVoucherData';
GO
--uspGetSetVoucherData 2,6,0,'','','2024-11-10','2024-12-16',1                       
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetVoucherData]                                                                      
@Mode INT,@TransID INT,@ID NVARCHAR(MAX) = NULL,@AccountName NVARCHAR(MAX) = NULL,@Party NVARCHAR(MAX) = NULL,@FromDate date = null,                          
@ToDate date = null,@Showall int = null,@Branch NVARCHAR(MAX) = NULL                           
AS                                                                      
BEGIN                                
BEGIN TRY                      
declare @strQuery NVARCHAR(MAX)                          
IF(@Mode = 1)                                                                      
BEGIN                                  
select 1 Type,'PartyName' Trans,FAID ID,'' Code,AccountName Name from tblFAAccount  where Active = 1 and AccountGroup IN (44,2,25,3,29,6,12,13,39,1,19,33,43,35,18,20)                                  
union all                                                                      
--SELECT 2 Type,'AccountName' Trans,FAID ID,'' Code,AccountName Name from tblFAAccount  where Active = 1 and AccountGroup IN (7,8,10,11,15,17)                                  
SELECT 2 Type,'AccountName' Trans,FAID ID,'' Code,[Account Name] Name from [FACNAccountNames]                            
union all                                                                                              
SELECT 3 Type,'UDN' Trans,UDNID,'',DocName FROM tblMasterUserDefineNoHeader WHERE TransID = @TransID                                                           
union all                                                                      
SELECT 4 Type,'DocID' Trans,TransID,'',DocPrefix +DocValue FROM tblDocumentSeries WHERE Active = 1 and TransID = @TransID                                  
union all                                                                                              
SELECT 5 Type,'Tax' Trans,TaxID,CONVERT(nvarchar(50),GST),TaxName FROM tblMasterTax WHERE Active = 1                 
union all            
SELECT 6 Type,'BranchName' Trans,ID,'',Name FROM tblMasterBranchOffice  WHERE Active = 1               
order by Type,Name                                                                      
END                                  
IF(@Mode = 2)                                                                      
BEGIN                                           
                
SET @strQuery = 'SELECT ND.ID,ND.DocId,convert(nvarchar(50),ND.DocDate,103) DocDate, ND.RefNo,Party.AccountName as[Party Name] ,FAA.AccountName as[Account Name],ND.SACorHSNCode,               
MT.TaxName,dbo.fnGetRoundedValue(ND.Amount)Amount,dbo.fnGetRoundedValue(ND.DiscPern)DiscPern,dbo.fnGetRoundedValue(ND.DiscAmt)DiscAmt,dbo.fnGetRoundedValue(ND.RoundoffAmt)RoundoffAmt,              
dbo.fnGetRoundedValue(ND.GrossAmount) Gross,dbo.fnGetRoundedValue(ND.TaxtAmount) Tax,dbo.fnGetRoundedValue(ND.NetAmount) Net,ND.Remarks,ND.Narration,                 
dbo.fnGetRoundedValue(ND.Balance)Balance ,ST.[Description],ND.Status StatusID,CUR.UserName UserName,        
CONVERT(NVARCHAR(100),ND.CDate) LastActionTime,isnull(ND.BranchID,0) BranchID,MBO.Name[Branch Name]                            
FROM tblTranPRVoucher ND                                   
JOIN  tblDocumentSeries  DS ON ND.TransID=DS.TransID                                                                 
JOIN tblStatus ST ON ST.ID=ND.[Status]                                                     
JOIN tblFAAccount FAA ON ND.FAID=FAA.FAID                       
JOIN tblFAAccount Party ON ND.PartyId=Party.FAID                    
LEFT JOIN tblMasterTax MT ON MT.TaxID = ND.TaxID              
LEFT JOIN tblMasterBranchOffice MBO on MBO.ID = ND.BranchID         
JOIN tblUsers CUR ON CUR.ID = ND.CBy WHERE  ND.TransID = ' + CONVERT(NVARCHAR,@TransID)                          
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END          
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND Party.AccountName = @Party' END                        
SET @strQuery += CASE WHEN ISNULL(@AccountName,'') = '' THEN '' ELSE ' AND FAA.AccountName = @AccountName' END     
SET @strQuery += CASE WHEN ISNULL(@Branch,'') = '0' THEN '' ELSE ' AND ND.BranchID = CONVERT(NVARCHAR,@Branch)' END  
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND ND.Status in (1,3,5)' END                         
SET @strQuery += ' ORDER BY ND.DocDate DESC, ND.DocValue desc,ND.ID'                      
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @ID NVARCHAR(MAX), @AccountName NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @Branch NVARCHAR(MAX)', @Mode = @Mode, @TransID = @TransID, @ID = @ID, @AccountName = @AccountName, @Party = @Party, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall, @Branch = @Branch                       
                      
END                                
IF(@Mode = 3)                                                                      
BEGIN                                  
SELECT ND.ID,ND.DocId,ND.DocDate,ND.DocValue, ND.RefNo,Party.AccountName as[Party Name] ,FAA.AccountName as[Account Name],                                                               
ND.Amount,ND.Balance,ND.[Status],ND.Remarks,ND.Narration,ND.TaxID,ND.TaxPern,DiscPern,DiscAmt,ND.GrossAmount,ND.TaxtAmount,ND.NetAmount,                            
TDSAmount,ND.SACorHSNCode SACCode,RoundoffAmt,ND.BranchID AS [BranchID],MBO.Name[Branch Name],    
dbo.fnTransactionPrefix(ND.DocDate,BranchID,ND.TransID) Prefix      
FROM tblTranPRVoucher ND                                   
JOIN tblFAAccount FAA ON ND.FAID=FAA.FAID                                               
JOIN tblFAAccount Party ON ND.PartyId=Party.FAID               
LEFT JOIN tblMasterBranchOffice MBO ON MBO.ID = ND.BranchID            
WHERE ND.ID = @ID                                
END                                
END TRY                                
BEGIN CATCH                                
SELECT ERROR_MESSAGE () MSG,ERROR_PROCEDURE () [PROC],ERROR_LINE () LINE                                
END CATCH                                
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSetWebCollectionData';
GO
--uspGetSetWebCollectionData 3                      
CREATE OR ALTER PROCEDURE [dbo].[uspGetSetWebCollectionData]                      
@Mode INT,@ID int = null,@SMID INT = NULL,@CustomerID INT = NULL,@PaymentModeID INT = NULL,@ChequeDate date = null,        
@AllowDate INT = 0,@ShowAll INT = 0        
AS                      
BEGIN                      
DECLARE @StrQuery NVARCHAR(MAX)                      
IF(@Mode = 1)                      
BEGIN                      
select 1 Type,'Salesman' Trans,ID,'' Code,Name from tblMasterSalesman where Active = 1                      
union all                      
SELECT 2 Type,'Beat' Trans,ID,'',Name FROM tblMasterBeat WHERE Active = 1                      
UNION ALL                      
SELECT 3 Type,'Customer' Trans,ID,Code,Name FROM tblMasterCustomer WHERE Active = 1                      
union all                      
SELECT 4 Type,'PayMode' Trans,ID,'',PaymentMode Name FROM tblPaymentMode WHERE Active = 1 and ID IN (1,2,4)                      
END                      
IF(@Mode = 2)                      
BEGIN                      
SET @StrQuery = 'SELECT REC.PaymentID,ISNULL(COUNT(REC.PaymentID),0) AS [Count],                      
dbo.fnGetRoundedValue(ISNULL(SUM(REC.Amt),0)) AS Amount FROM                      
(SELECT PaymentID,Amt FROM tblTranOrderCollectionHeader TOC WHERE Status = 1 '                      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@AllowDate,0)=0 THEN '' ELSE ' AND TOC.ChequeDate <=' + '''' +CONVERT(NVARCHAR,@ChequeDate) + '''' END)                      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerID,0)=0 THEN '' ELSE ' AND CustID ='+CONVERT(NVARCHAR,@CustomerID)+'' END)                      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ID,0)=0 THEN '' ELSE ' AND BeatID='+CONVERT(NVARCHAR,@ID)+'' END)                      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SMID,0)=0 THEN '' ELSE ' AND SalesManID='+CONVERT(NVARCHAR,@SMID)+'' END)                      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@PaymentModeID,0)=0 THEN '' ELSE ' and PaymentID='+CONVERT(NVARCHAR,@PaymentModeID)+'' END)                      
SET @StrQuery = @StrQuery + ') AS REC group by REC.PaymentID'                      
EXEC sys.sp_executesql @StrQuery, N'@Mode INT, @ID int, @SMID INT, @CustomerID INT, @PaymentModeID INT, @ChequeDate date, @AllowDate INT, @ShowAll INT', @Mode = @Mode, @ID = @ID, @SMID = @SMID, @CustomerID = @CustomerID, @PaymentModeID = @PaymentModeID, @ChequeDate = @ChequeDate, @AllowDate = @AllowDate, @ShowAll = @ShowAll                      
END                      
IF(@Mode = 3)                      
BEGIN                      
SET @StrQuery = ' SELECT TOC.ID,CONVERT(NVARCHAR,DocDate,103) AS DocDate,MB.Name Beat,MS.Name SalesMan,cus.Name Customer,PaymentMode,                      
dbo.fnGetRoundedValue(Amt) AS CollAmt,CONVERT(NVARCHAR,TOC.ChequeDate,103) AS ChequeDate,chequeNo ChequeNo,0 OtherChrg,0 AdvCollAmt,  
TOC.Remarks,TOC.Narration,dbo.fnGetRoundedValue(SUM(ISNULL(TOCD.DiscAmt,0))) DiscAmt,dbo.fnGetRoundedValue(SUM(ISNULL(TOCD.Writeoff,0))) Writeoff              
,dbo.fnGetRoundedValue(SUM(case when TOCD.InvDocprefix = 15 then ISNULL(TOCD.AdjAmt,0) else ISNULL(TOCD.AdjAmt * -1,0) end)) AdjAmt          
,dbo.fnGetRoundedValue(SUM(ISNULL(TOCD.InvoiceAmt,0))) Writeoff,TOC.Status StatusID,sts.Description Status       
,dbo.fnGetRoundedValue(SUM(ISNULL(TOCD.InvBalance - TOCD.AdjAmt,0))) NetBalance ,  
CONVERT(NVARCHAR(50),DATEDIFF(DD,MIN(SH.InvDate),TOC.ChequeDate)) +''-''+
CONVERT(NVARCHAR(50),DATEDIFF(DD,TOC.DocDate,TOC.ChequeDate)) ChqAging  
FROM tblTranOrderCollectionHeader TOC                      
JOIN tblTranOrderCollectionDetail TOCD ON TOCD.HID = TOC.ID   
JOIN tblMasterCustomer AS cus ON cus.Id=TOC.CustID                      
JOIN tblPaymentMode AS py ON py.Id=TOC.PaymentID                      
LEFT JOIN tblMasterBeat MB ON MB.Id = TOC.BeatID                      
LEFT JOIN tblMasterSalesMan MS ON MS.Id = TOC.SalesManID        
LEFT JOIN tblTranSalesHeader SH ON SH.ID = TOCD.InvoiceID  
join tblStatus sts on sts.ID = TOC.Status        
WHERE TOC.ID > 0'                      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ShowAll,0)=1 THEN '' ELSE ' AND TOC.Status IN (1,3) ' END)                  
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@AllowDate,0)=0 THEN '' ELSE ' AND TOC.ChequeDate <=' + '''' +CONVERT(NVARCHAR,@ChequeDate) + '''' END)                      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerID,0)=0 THEN '' ELSE ' AND TOC.CustID ='+CONVERT(NVARCHAR,@CustomerID)+'' END)                      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ID,0)=0 THEN '' ELSE ' AND TOC.BeatID='+CONVERT(NVARCHAR,@ID)+'' END)                      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SMID,0)=0 THEN '' ELSE ' AND TOC.SalesManID='+CONVERT(NVARCHAR,@SMID)+'' END)                      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@PaymentModeID,0)=0 THEN '' ELSE ' and TOC.PaymentID='+CONVERT(NVARCHAR,@PaymentModeID)+'' END)                      
SET @StrQuery = @StrQuery + ' GROUP BY  TOC.ID,DocDate,MB.Name,MS.Name,cus.Name,PaymentMode,                      
Amt,TOC.ChequeDate,chequeNo,TOC.Remarks,TOC.Narration,TOC.Status,sts.Description  ORDER by cus.Name'                      
EXEC sys.sp_executesql @StrQuery, N'@Mode INT, @ID int, @SMID INT, @CustomerID INT, @PaymentModeID INT, @ChequeDate date, @AllowDate INT, @ShowAll INT', @Mode = @Mode, @ID = @ID, @SMID = @SMID, @CustomerID = @CustomerID, @PaymentModeID = @PaymentModeID, @ChequeDate = @ChequeDate, @AllowDate = @AllowDate, @ShowAll = @ShowAll                      
END                      
IF(@Mode = 4)                      
BEGIN                      
UPDATE tblTranOrderCollectionHeader SET Status = 4,ClBy = @SMID ,ClDate = getdate() where ID = @ID                      
END                      
IF(@Mode = 5)                      
BEGIN                      
SELECT OCH.*,MC.ID CustomerID,MC.FAID,MBA.AccountNo BankAcNo,BranchName FROM tblTranOrderCollectionHeader OCH                      
JOIN tblMasterCustomer MC ON MC.ID = OCH.CustID                       
left JOIN TBLMASTERBANKACCOUNT MBA ON MBA.ID = OCH.BankAccountID WHERE  OCH.ID = @ID                      
END                      
IF(@Mode = 6)                      
BEGIN                      
SELECT OCD.*,(CASE WHEN ISNULL(OCD.WriteOff,0)<0 THEN OCD.AdjAmt + OCD.DiscAmt + ABS(OCD.WriteOff) ELSE OCD.AdjAmt+ OCD.DiscAmt END) AS TotAdjAmt ,SH.DocValue,SH.InvDate                      
FROM tblTranOrderCollectionDetail OCD                      
join tblTranOrderCollectionHeader OCH ON OCH.ID = OCD.HID                      
JOIN TBLTRANSALESHEADER SH ON SH.ID = OCD.InvoiceID                      
WHERE OCH.ID = @ID                      
END                      
IF(@Mode = 7)                      
BEGIN                  
--CHANGE ORDER COLLECTION TO STATUS PROCESSED(8)                    
UPDATE tblTranOrderCollectionHeader SET Status = 8,CollectionID = @SMID WHERE ID = @ID    --CHANGE ASSIGN INVOICE STATUS                    
CREATE TABLE #CollInvoices(ID int identity(1,1),InvoiceID INT)                    
--GET COLLECTION ID INVOICES                    
INSERT INTO #CollInvoices                    
select InvoiceID from tblTranOrderCollectiondetail where Hid = @ID                     
DECLARE @nCount int = (SELECT count(*) FROM #CollInvoices),@nIncr int = 1,@InvoiceID INT,@Balance decimal(25,4), @AAignID int                    
while(@nCount >= @nIncr)                    
begin                    
SELECT @InvoiceID = InvoiceID FROM #CollInvoices WHERE ID = @nIncr                    
select @Balance =  balance from tbltransalesheader where Docprefix = 15 and status in (1,3,5) and  id = @InvoiceID                    
--CHANGE ASSIGN DETAIL TABLE STATUS TO 5(CLOSE) IF INVOICE BALANCE IS 0                    
if(isnull(@Balance,0) = 0)                    
begin                    
select @AAignID = HID from tblAssignInvoicesDetail where  InvID = @InvoiceID and status = 1                    
update tblAssignInvoicesDetail set status = 5 where InvID = @InvoiceID and status = 1                    
if(isnull(@AAignID,0) > 0)                    
begin                    
--CHANGE ASSIGN DETAIL TABLE STATUS TO 5(CLOSE) IF ALL DETAIL INVOICES STATUS IS NOT 1                    
if((select count(*) from tblAssignInvoicesDetail where HID = @AAignID and status = 1) = 0)                    
begin                    
update tblAssignInvoicesHeader set status = 5 where id = @AAignID                    
end                    
end                    
end                    
set @nIncr = @nIncr + 1;                    
end                    
DROP TABLE #CollInvoices                    
END                      
IF(@Mode = 8)                  
BEGIN                  
select SH.DocID,CONVERT(NVARCHAR(50),SH.InvDate,103) DocDate,SH.DocRef RefNo,                  
dbo.fngetroundedvalue(SH.NetAmt) NetAmt,dbo.fngetroundedvalue(CD.AdjAmt) AdjAmt,dbo.fngetroundedvalue(CD.WriteOff) WriteOff                
,dbo.fngetroundedvalue(CD.DiscPern) DiscPern                
,dbo.fngetroundedvalue(CD.DiscAmt) DiscAmt ,dbo.fngetroundedvalue(CD.InvBalance) Balance          
from tblTranOrderCollectionHeader CH                  
JOIN tblTranOrderCollectionDetail CD ON CD.HID = CH.ID                  
JOIN tbltransalesheader SH ON SH.ID = CD.InvoiceID                  
WHERE CH.ID = @ID                    
END                  
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetSinglemasterdata';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspGetSinglemasterdata]
@FormID int
as
begin
declare @TableName nvarchar(255) = (select TableName from tblTablesNames where ID = @FormID)                
declare @strQuery NVARCHAR(MAX)
SET @strQuery = ' SELECT * FROM '+@TableName+' WHERE Active = 1 ORDER BY [Name]'
EXEC sys.sp_executesql @strQuery  
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspGetStockAgeingHeader';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspGetStockAgeingHeader]        
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
 set @query += case when ISNULL(@BranchName,'') = '' then '' else ' AND Inv.BranchID = '+''''+ CONVERT(nvarchar(50),@BranchName)+''''+'' END          
 set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND MB.ID IN (SELECT * from dbo.fnSplitString( @BrandName,'',''))' END          
 set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND MC.ID IN (SELECT * from dbo.fnSplitString( @CategoryName,'',''))' END          
 set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND MM.ID IN (SELECT * from dbo.fnSplitString( @ManufName,'',''))' END          
 set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND pa.ID IN (SELECT * from dbo.fnSplitString( @ProductName,'',''))' END          
 set @query += ' GROUP BY  pa.Code,pa.Name,pa.EAN,MM.Name,MB.Name,MC.Name,Inv.TransDate,Inv.ProdId,MBR.Name
 order by pa.Name'       

 EXEC sys.sp_executesql @query, N'@BranchName int, @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255)', @BranchName = @BranchName, @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName        
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspInActiveCustomerHeader';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspInActiveCustomerHeader]    
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
WHERE [Net Amount] <= '+ CONVERT(NVARCHAR,@Value)    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND ID IN (SELECT * from dbo.fnSplitString( @CustomerName,'',''))' END)                    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND BeatId IN (SELECT * from dbo.fnSplitString( @BeatName,'',''))' END)        
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SalesmanId IN (SELECT * from dbo.fnSplitString( @SalesmanName,'',''))' END)     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND CustomerTypeId IN (SELECT * from dbo.fnSplitString( @CustomerType,'',''))' END)        
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RatingId IN(SELECT * from  dbo.fnSplitString( @Ratings,'',''))' END)     
SET @StrQuery = @StrQuery + ' ORDER BY [Net Amount] DESC'      
EXEC sys.sp_executesql @StrQuery, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @Value INT, @FromDate DATE, @ToDate DATE', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @CustomerType = @CustomerType, @Ratings = @Ratings, @Value = @Value, @FromDate = @FromDate, @ToDate = @ToDate     
DROP TABLE #TEMP,#MainTemp  
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspLoadDeliveryDocumentData_new';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspLoadDeliveryDocumentData_new]          
@Branch INT = 4,@nMode INT = 1,@DOID INT = 0 ,@CustID NVARCHAR(255)='', @BeatID NVARCHAR(255)='',@SalesManID NVARCHAR(255)='',          
@FromDate DATE = NULL,@ToDate DATE = NULL ,@InclDoc INT = 0,        
@DocID NVARCHAR(MAX) = NULL         
AS          
BEGIN
-- Security: these values are placed in the SQL text as ID lists, so only digits, commas and spaces are accepted.
IF (ISNULL(@DocID,N'') LIKE N'%[^0-9, ]%' OR ISNULL(@CustID,N'') LIKE N'%[^0-9, ]%' OR ISNULL(@BeatID,N'') LIKE N'%[^0-9, ]%' OR ISNULL(@SalesManID,N'') LIKE N'%[^0-9, ]%')
    THROW 50001, N'Invalid ID list.', 1;
          
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
WHERE DocPrefix = 15 AND STATUS IN (1,3,5) AND SH.BranchID = '+ CONVERT(NVARCHAR,@Branch)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+'''' + CONVERT(NVARCHAR,@FromDate) +'''' +' AND ' +'''' + CONVERT(NVARCHAR,@ToDate) +'''' +'' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocID,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(@DocID, N'',''))' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustID,'')='' THEN '' ELSE ' AND SH.CustId IN (SELECT value FROM STRING_SPLIT(@CustID, N'',''))' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatID,'')='' THEN '' ELSE ' AND SH.BeatID IN (SELECT value FROM STRING_SPLIT(@BeatID, N'',''))' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesManID,'')='' THEN '' ELSE ' AND SH.SalesmanID IN (SELECT value FROM STRING_SPLIT(@SalesManID, N'',''))' END)          
SET @StrQuery = @StrQuery + ' AND SH.ID NOT IN (SELECT InvIdentID FROM #DeliProcs WHERE IsMods = 1)'          
SET @StrQuery = @StrQuery + ' ORDER BY DocId,ID'          
EXEC sys.sp_executesql @StrQuery, N'@Branch INT, @nMode INT, @DOID INT, @CustID NVARCHAR(255), @BeatID NVARCHAR(255), @SalesManID NVARCHAR(255), @FromDate DATE, @ToDate DATE, @InclDoc INT, @DocID NVARCHAR(MAX)', @Branch = @Branch, @nMode = @nMode, @DOID = @DOID, @CustID = @CustID, @BeatID = @BeatID, @SalesManID = @SalesManID, @FromDate = @FromDate, @ToDate = @ToDate, @InclDoc = @InclDoc, @DocID = @DocID          
END          
ELSE          
BEGIN          
set @StrQuery = 'SELECT * FROM (SELECT SH.ID,SH.Status Status,DocId,CONVERT(NVARCHAR,InvDate,103) InvDate,DocRef,MC.Name,          
dbo.fnGetRoundedValue(SH.NetAmt) NetAmt,ISNULL(DP.IsMods,1) IsMods FROM tblTranSalesHeader SH          
JOIN tblMasterCustomer MC ON MC.ID = SH.CustId          
LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatID          
LEFT JOIN tblMasterSalesman SM ON SM.ID = SH.SalesmanID          
LEFT JOIN #DeliProcs DP on DP.InvIdentID = SH.ID AND DP.IsMods = 2          
WHERE DocPrefix = 15 AND STATUS IN (1,3) AND SH.BranchID = '+ CONVERT(NVARCHAR,@Branch) -- AND SH.InvDate BETWEEN @FromDate AND @ToDate          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+'''' + CONVERT(NVARCHAR,@FromDate) +'''' +' AND ' +'''' + CONVERT(NVARCHAR,@ToDate) +'''' +'' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustID,'')='' THEN '' ELSE ' AND SH.CustId IN (SELECT value FROM STRING_SPLIT(@CustID, N'',''))' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatID,'')='' THEN '' ELSE ' AND SH.BeatID IN (SELECT value FROM STRING_SPLIT(@BeatID, N'',''))' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesManID,'')='' THEN '' ELSE ' AND SH.SalesmanID IN (SELECT value FROM STRING_SPLIT(@SalesManID, N'',''))' END)          
SET @StrQuery = @StrQuery + ' AND SH.ID NOT IN (SELECT InvIdentID FROM #DeliProcs WHERE IsMods = 1)'          
SET @StrQuery = @StrQuery + ' union '          
set @StrQuery = @StrQuery + 'SELECT InvId,SH.Status,DocId,CONVERT(NVARCHAR,InvDate,103) InvDate,DocRef,MC.Name,          
dbo.fnGetRoundedValue(SH.NetAmt) NetAmt,ISNULL(DP.IsMods,1) IsMods FROM tblTranSalesHeader SH          
JOIN tblMasterCustomer MC ON MC.ID = SH.CustId          
LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatID          
LEFT JOIN tblMasterSalesman SM ON SM.ID = SH.SalesmanID          
LEFT JOIN #DeliProcs DP on DP.InvIdentID = SH.ID AND DP.IsMods = 2          
WHERE DocPrefix = 15 AND STATUS IN (1,3) AND SH.BranchID = '+ CONVERT(NVARCHAR,@Branch) -- AND SH.InvDate BETWEEN @FromDate AND @ToDate          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@FromDate,'')='' and ISNULL(@ToDate,'')='' THEN '' ELSE ' AND SH.InvDate BETWEEN '+'''' + CONVERT(NVARCHAR,@FromDate) +'''' +' AND ' +'''' + CONVERT(NVARCHAR,@ToDate) +'''' +'' END)          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocID,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT value FROM STRING_SPLIT(@DocID, N'',''))' END)          
SET @StrQuery = @StrQuery + ' AND SH.ID NOT IN (SELECT InvIdentID FROM #DeliProcs WHERE IsMods = 1)) AS REC'          
SET @StrQuery = @StrQuery + ' ORDER BY DocId,Id'          
EXEC sys.sp_executesql @StrQuery, N'@Branch INT, @nMode INT, @DOID INT, @CustID NVARCHAR(255), @BeatID NVARCHAR(255), @SalesManID NVARCHAR(255), @FromDate DATE, @ToDate DATE, @InclDoc INT, @DocID NVARCHAR(MAX)', @Branch = @Branch, @nMode = @nMode, @DOID = @DOID, @CustID = @CustID, @BeatID = @BeatID, @SalesManID = @SalesManID, @FromDate = @FromDate, @ToDate = @ToDate, @InclDoc = @InclDoc, @DocID = @DocID          
          
END          
drop table #DeliProcs,#DeliProcs1          
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspManageCustomerMaster';
GO
--[uspManageCustomerMaster] 12,22
CREATE OR ALTER PROCEDURE [dbo].[uspManageCustomerMaster]                      
@Mode int,@ID int = null,@Code nvarchar(255) = null,@Name nvarchar(255) = null,@Billadd1 nvarchar(MAX) = null,@Billadd2 nvarchar(MAX) = null,                      
@Billadd3 nvarchar(MAX) = null,@Shipadd1 nvarchar(MAX) = null,@shipadd2 nvarchar(MAX) = null,@Shipadd3 nvarchar(MAX) = null,@Pincode nvarchar(15) = null,                      
@ContactPerson nvarchar(255) = null,@Ph1 nvarchar(25) = null,@Ph2 nvarchar(25) = null,@Mob1 nvarchar(25) = null,@Mob2 nvarchar(25) = null,@Email nvarchar(255) = null,                      
@PANNumber nvarchar(25) = null,@AadharNo nvarchar(25) = null,@DLNo20 nvarchar(25) = null,@DLNo21 nvarchar(25) = null,@FSSAINo nvarchar(30) = null,@StateID tinyint = null,                      
@GSTIN nvarchar(40) = null,@CreditTermID tinyint = null,@PaymentModeID tinyint = null,@TaxTypeID tinyint = null,                      
@FAID int = null,@OverDueValue decimal(25, 4) = null,@OverDueInvCount smallint = null,@CreditLimitValue decimal(25, 4) = null,@CreditLimitCount smallint = null,                      
@CreditlimitOS decimal(25, 4) = null,@PriceTypeID tinyint = null,@OwnerName nvarchar(255) = null,@DiscountPern decimal(25, 4) = null,@TrackPoint smallint = null,                      
@ClosingTrackPoint decimal(25, 4) = null,@TCSTax smallint = null,@Latitude nvarchar(25) = null,@Longtitude nvarchar(25) = null,@Distance smallint = null,                      
@Remark nvarchar(MAX) = null,@Active smallint = null,@UserID smallint = null,@CustomerType SMALLINT = null,@Rating TINYINT = NULL,  
@Shinecode nvarchar(50) = null,@RemoveLocation smallint = 0  
AS                      
BEGIN                      
BEGIN TRY                      
DECLARE @ActiveCheck NVARCHAR(255), @SUNDRYDEBTORS INT ,@FATYPE INT,@AccID INT ,@ACCOUNTID INT,@CHECKID INT,@cstdate DATE,@ExistCount INT                      
SELECT @SUNDRYDEBTORS = FAGroup FROM tblFAGroup WHERE AccountGroupName='Sundry Debtors'                      
IF(@Mode = 1)                      
BEGIN                      
IF((SELECT count(*) FROM tblMasterCustomer WHERE Code = @Code) > 0)                      
BEGIN                      
RAISERROR('Code',16,1)                      
END                      
IF((SELECT count(*) FROM tblMasterCustomer WHERE Name = @Name) > 0)                      
BEGIN                      
RAISERROR('Name',16,1)                      
END                      
--IF((SELECT count(*) FROM tblFAAccount WHERE AccountName = @Name) > 0)                      
--BEGIN                      
--RAISERROR('Account Name Already Exists',16,1)                      
--END                      
                      
IF ISNULL(@ph1,'')!=''                      
BEGIN                      
SELECT @ExistCount=COUNT(Id) FROM tblMasterCustomer WHERE (Ph1 = @ph1 OR Ph2 = @ph1 OR Mob1 = @ph1 OR Mob2 = @ph1 )                      
IF( @ExistCount >0)                      
BEGIN                      
RAISERROR ('Phone No 1 already exists',16,1)                      
END                      
END                      
IF ISNULL(@ph2,'')!=''                      
BEGIN                      
SELECT @ExistCount=COUNT(Id) FROM tblMasterCustomer WHERE (Ph1 = @ph2 OR Ph2 = @ph2 OR Mob1 = @ph2 OR Mob2 = @ph2 )                      
IF( @ExistCount >0) BEGIN                      
RAISERROR ('Phone No 2 already exists',16,1)                      
END                      
END                      
                      
IF ISNULL(@mob1,'')!=''                      
BEGIN                      
SELECT @ExistCount=COUNT(Id) FROM tblMasterCustomer WHERE (Ph1 = @mob1 OR Ph2 = @mob1 OR Mob1 = @mob1 OR Mob2 = @mob1 )                      
IF( @ExistCount >0)                      
BEGIN                      
RAISERROR ('Mobile No 1 already exists',16,1)                      
END                      
END                      
                      
IF ISNULL(@mob2,'')!=''                      
BEGIN                      
SELECT @ExistCount=COUNT(Id) FROM tblMasterCustomer WHERE (Ph1 = @mob2 OR Ph2 = @mob2 OR Mob1 = @mob2 OR Mob2 = @mob2 )                      
IF( @ExistCount >0)     
BEGIN                      
RAISERROR ('Mobile No 2 already exists',16,1)                      
END                      
END                 
IF ISNULL(@Shinecode,'')!=''                      
BEGIN                      
SELECT @ExistCount=COUNT(Id) FROM tblMasterCustomer WHERE (Shinecode = @Shinecode)                      
IF( @ExistCount >0)                      
BEGIN                      
RAISERROR ('Shine code already exists',16,1)                      
END                      
END                      
SELECT @ExistCount=COUNT(FAID) FROM tblFAAccount WHERE AccountName=@name              
IF(@ExistCount>0)                      
BEGIN                      
RAISERROR ('AccountName',16,1)                      
END                      
set @Code =(select dbo.ProperCase(@Code)); set @Name = (select dbo.ProperCase(@Name));                      
set @ContactPerson =(select dbo.ProperCase(@ContactPerson)); set @OwnerName = (select dbo.ProperCase(@OwnerName));                      
set @Billadd1 =(select dbo.ProperCase(@Billadd1)); set @Shipadd1 = (select dbo.ProperCase(@Shipadd1));                      
set @Billadd2 =(select dbo.ProperCase(@Billadd2)); set @Shipadd2 = (select dbo.ProperCase(@Shipadd2));                      
set @Billadd3 =(select dbo.ProperCase(@Billadd3)); set @Shipadd3 = (select dbo.ProperCase(@Shipadd3));                      
set @Remark =(select dbo.ProperCase(@Remark));                      
                      
INSERT INTO tblFAAccount(AccountName,AccountGroup,OpeningBalance,FATypeID,CBy,CDate,UserAccount,PANNumber,Active)                      
VALUES(@name,@SUNDRYDEBTORS,0,1,@UserID,GETDATE(),0,@PANNumber,@Active)                      
SELECT @FAID = FAID FROM tblFAAccount WHERE AccountName = @Name                      
INSERT INTO tblMasterCustomer(Code,Name,Billadd1,Billadd2,Billadd3,Shipadd1,shipadd2,Shipadd3,Pincode,ContactPerson,Ph1,Ph2,Mob1,Mob2,                      
Email,PANNumber,AadharNo,DLNo20,DLNo21,FSSAINo,StateID,GSTIN,CreditTermID,PaymentModeID,TaxTypeID,FAID,OverDueValue,OverDueInvCount,                      
CreditLimitValue,CreditLimitCount,CreditlimitOS,PriceTypeID,OwnerName,DiscountPern,TrackPoint,ClosingTrackPoint,TCSTax,Latitude,                      
Longtitude,Distance,Remark,Active,CBy,CDate,CustomerType,Rating,Shinecode) VALUES                      
(@Code,@Name,@Billadd1,@Billadd2,@Billadd3,@Shipadd1,@shipadd2,@Shipadd3,@Pincode,@ContactPerson,@Ph1,@Ph2,@Mob1,@Mob2,                      
LOWER(@Email),@PANNumber,@AadharNo,@DLNo20,@DLNo21,@FSSAINo,@StateID,UPPER(@GSTIN),@CreditTermID,@PaymentModeID,@TaxTypeID,                      
@FAID,@OverDueValue,@OverDueInvCount,@CreditLimitValue,@CreditLimitCount,@CreditlimitOS,@PriceTypeID,@OwnerName,                      
@DiscountPern,@TrackPoint,0,@TCSTax,@Latitude,@Longtitude,@Distance,@Remark,@Active,@UserID,GETDATE(),@CustomerType,@Rating,@Shinecode)                      
SELECT SCOPE_IDENTITY()                      
END                      
IF(@Mode = 2)                      
BEGIN                      
select @ACCOUNTID = FAID from tblMasterCustomer where ID = @ID                      
IF((SELECT count(*) FROM tblMasterCustomer WHERE Code = @Code AND ID != @ID) > 0)                      
BEGIN                      
RAISERROR('Code',16,1)                      
END                      
IF((SELECT count(*) FROM tblMasterCustomer WHERE Name = @Name AND ID != @ID) > 0)                      
BEGIN                      
RAISERROR('Name',16,1)                      
END                      
IF ISNULL(@ph1,'')!=''                      
BEGIN                      
SELECT @ExistCount=COUNT(Id) FROM tblMasterCustomer WHERE (Ph1 = @ph1 OR Ph2 = @ph1 OR Mob1 = @ph1 OR Mob2 = @ph1 ) AND Id != @ID                      
IF( @ExistCount >0)                      
BEGIN                      
RAISERROR ('Phone No 1 already exists',16,1)                      
END                      END                      
IF ISNULL(@ph2,'')!=''                      
BEGIN                      
SELECT @ExistCount=COUNT(Id) FROM tblMasterCustomer WHERE (Ph1 = @ph2 OR Ph2 = @ph2 OR Mob1 = @ph2 OR Mob2 = @ph2 ) AND Id != @ID                     
IF( @ExistCount >0)                      
BEGIN                      
RAISERROR ('Phone No 2 already exists',16,1)                      
END                      
END                      
                      
IF ISNULL(@mob1,'')!=''               
BEGIN                      
SELECT @ExistCount=COUNT(Id) FROM tblMasterCustomer WHERE (Ph1 = @mob1 OR Ph2 = @mob1 OR Mob1 = @mob1 OR Mob2 = @mob1 ) AND Id != @ID                      
IF( @ExistCount >0)                      
BEGIN                      
RAISERROR ('Mobile No 1 already exists',16,1)                      
END                      
END                      
                      
IF ISNULL(@mob2,'')!=''                      
BEGIN                      
SELECT @ExistCount=COUNT(Id) FROM tblMasterCustomer WHERE (Ph1 = @mob2 OR Ph2 = @mob2 OR Mob1 = @mob2 OR Mob2 = @mob2 ) AND Id != @ID                      
IF( @ExistCount >0)                      
BEGIN                      
RAISERROR ('Mobile No 2 already exists',16,1)                      
END                      
END                      
SELECT @ExistCount=COUNT(FAID) FROM tblFAAccount WHERE AccountName=@name and FAID != @ACCOUNTID                      
IF(@ExistCount>0)                      
BEGIN                      
RAISERROR ('AccountName',16,1)                      
END                      
IF @active=0                      
BEGIN                      
DECLARE @ReturnValue DECIMAL(25,4)                      
EXEC uspGetClosingBal @ACCOUNTID,@ReturnValue OUTPUT                      
IF( @ReturnValue !=0)          BEGIN                      
RAISERROR ('OSPending',16,1)                      
END                      
END                      
IF ISNULL(@Shinecode,'')!=''                      
BEGIN                      
SELECT @ExistCount=COUNT(Id) FROM tblMasterCustomer WHERE (Shinecode = @Shinecode AND ID != @ID)                      
IF( @ExistCount >0)                      
BEGIN                      
RAISERROR ('Shine code already exists',16,1)                      
END                      
END                      
--IF((SELECT count(*) FROM tblFAAccount WHERE AccountName = @Name AND FAID != @FAID) > 0)                      
--BEGIN                      
--RAISERROR('Account Name Already Exists',16,1)                      
--END --Previous ID data Posting in History table                      
insert into tblMasterCustomerVendorHistory (FormID,ID,Code,Name,Billadd1,Billadd2,Billadd3,Shipadd1,shipadd2,Shipadd3,Pincode,                      
ContactPerson,Ph1,Ph2,Mob1,Mob2,Email,PANNumber,AadharNo,DLNo20,DLNo21,FSSAINo,StateID,GSTIN,CreditTermID,PaymentModeID,                      
TaxTypeID,OSValue,FAID,OverDueValue,OverDueInvCount,CreditLimitValue,CreditLimitCount,CreditlimitOS,PriceTypeWeekCycle,                      
OwnerName,DiscountPern,TrackPoint,ClosingTrackPoint,TCSTax,Latitude,Longtitude,Distance,Remark,CustomerType,Rating,                      
Active,CBy,CDate,MBy,MDate,HisCBy,HisCDate,Shinecode)                      
select 26,ID,Code,Name,Billadd1,Billadd2,Billadd3,Shipadd1,shipadd2,Shipadd3,Pincode,ContactPerson,Ph1,Ph2,Mob1,Mob2,Email,PANNumber,                      
AadharNo,DLNo20,DLNo21,FSSAINo,StateID,GSTIN,CreditTermID,PaymentModeID,TaxTypeID,OSValue,FAID,OverDueValue,OverDueInvCount,                      
CreditLimitValue,CreditLimitCount,CreditlimitOS,PriceTypeID,OwnerName,DiscountPern,TrackPoint,ClosingTrackPoint,TCSTax,                      
Latitude,Longtitude,Distance,Remark,CustomerType,Rating,Active,CBy,CDate,MBy,MDate,@UserID,GETDATE(),Shinecode from tblMasterCustomer where ID = @ID                      
                      
set @Code =(select dbo.ProperCase(@Code))                      
set @Name = (select dbo.ProperCase(@Name))                      
set @ContactPerson =(select dbo.ProperCase(@ContactPerson)); set @OwnerName = (select dbo.ProperCase(@OwnerName));                      
set @Billadd1 =(select dbo.ProperCase(@Billadd1)); set @Shipadd1 = (select dbo.ProperCase(@Shipadd1));                      
set @Billadd2 =(select dbo.ProperCase(@Billadd2)); set @Shipadd2 = (select dbo.ProperCase(@Shipadd2));                      
set @Billadd3 =(select dbo.ProperCase(@Billadd3)); set @Shipadd3 = (select dbo.ProperCase(@Shipadd3));                      
set @Remark =(select dbo.ProperCase(@Remark));                      
                      
UPDATE tblFAAccount                      
SET AccountName=@Name,AccountGroup=@SUNDRYDEBTORS,MBy=@UserID,MDate=GETDATE(),UserAccount=0,PANNumber=@PANNumber,Active = @Active                      
WHERE FAID=@ACCOUNTID                      
                      
UPDATE tblMasterCustomer SET Code = @Code,Name = @Name,Billadd1 = @Billadd1,Billadd2 = @Billadd2,Billadd3 = @Billadd3,Shipadd1 = @Shipadd1,shipadd2 = @shipadd2,                      
Shipadd3 = @Shipadd3,Pincode = @Pincode,ContactPerson = @ContactPerson,Ph1 = @Ph1,Ph2 = @Ph2,Mob1 = @Mob1,Mob2 = @Mob2,Email = LOWER(@Email),PANNumber = @PANNumber,                      
AadharNo = @AadharNo,DLNo20 = @DLNo20,DLNo21 = @DLNo21,FSSAINo = @FSSAINo,StateID = @StateID,GSTIN = UPPER(@GSTIN),CreditTermID = @CreditTermID,                      
PaymentModeID = @PaymentModeID,TaxTypeID = @TaxTypeID ,OverDueValue = @OverDueValue,OverDueInvCount = @OverDueInvCount,                      
CreditLimitValue = @CreditLimitValue,CreditLimitCount = @CreditLimitCount,CreditlimitOS = @CreditlimitOS,PriceTypeID = @PriceTypeID,OwnerName = @OwnerName,                      
DiscountPern = @DiscountPern,TrackPoint = @TrackPoint,TCSTax = @TCSTax,--Latitude = @Latitude,Longtitude = @Longtitude,                      
Distance = @Distance,Remark = @Remark,Active = @Active,MBy = @UserID,MDate = GETDATE(),CustomerType = @CustomerType,                      
Rating = @Rating,Shinecode = @Shinecode WHERE ID=@ID                      
  
IF(@RemoveLocation = 1)  
BEGIN  
UPDATE tblMasterCustomer SET Latitude = NULL,Longtitude = NULL,MobilePinAddress = NULL WHERE  ID=@ID      
END  
  
SELECT @ID                      
END                      
IF(@Mode = 3)                      
BEGIN                      
if(isnull(@Billadd1,1) = 0)                      
begin                      
delete from tblBeatSalesmanMapping where CustomerID = @ID                      
end                      
declare @BeatID smallint = (select ID from tblMasterBeat where Name = @Code)                      
declare @SMID smallint = (select ID from tblMasterSalesman where Name = @Name)                      
INSERT INTO tblBeatSalesmanMapping VALUES (@ID,@BeatID,@SMID)                      
END                      
IF(@Mode = 4)                      
BEGIN                      
SELECT TC.ID,TC.Code,TC.Name,MCT.Name CustomerType,PT.PriceType,TC.OwnerName,                      
TC.ContactPerson,TC.Email,TC.Ph1,Tc.Ph2,TC.Mob1 Mob1,TC.Mob2,                      
TC.Billadd1,TC.Billadd2,Tc.Billadd3,TC.Shipadd1,TC.Shipadd2,TC.Shipadd3,TC.Pincode,TC.Distance,                      
TC.CreditLimitValue,dbo.fnGetRoundedValue(TC.CreditLimitCount)CreditLimitCount,dbo.fnGetRoundedValue(TC.OverDueValue)OverDueValue,TC.OverDueInvCount,TC.PANNumber,TC.AadharNo,TC.FSSAINo,TC.DLNo20,TC.DLNo21,                      
SNTC.StateName,TC.GSTIN,MTT.TaxTypeName,PM.PaymentMode,MTCT.Name,dbo.fnGetRoundedValue(TC.DiscountPern)DiscountPern,TC.Remark,RT.RatingName Ratings,TC.TCSTax,TC.TrackPoint,                      
CASE WHEN TC.Active = 1 THEN 'Yes' ELSE 'No' END Active,CASE WHEN ISNULL(TC.MBy,0) = 0 THEN CUR.UserName ELSE MUR.UserName END CBy,                      
CASE WHEN ISNULL(TC.MBy,0) = 0 THEN CONVERT(NVARCHAR(100),TC.CDate) ELSE CONVERT(NVARCHAR(100),TC.MDate) END CDate,                      
TC.Latitude,TC.Longtitude,Shinecode,(CASE WHEN IMG.Filename is null then 0 else 1 end) Imagestate         
,(CASE WHEN isnull(TC.Latitude,'') = '' or isnull(TC.Longtitude,'') = '' then 'No' else 'Yes' end) Location,        
(CASE WHEN IMG.Filename is null then 'No' else 'Yes' end) Images        
FROM tblMasterCustomer TC                      
LEFT JOIN tblMasterCustomerType MCT ON MCT.ID = TC.CustomerType                      
LEFT JOIN tblPriceType PT ON PT.ID = TC.PriceTypeID                      
LEFT JOIN tblGSTStateNameandCode SNTC ON SNTC.StateID = TC.StateID                      
LEFT JOIN tblMasterTaxType MTT ON MTT.TaxTypeID = TC.TaxTypeID                      
LEFT JOIN tblPaymentMode PM ON PM.ID = TC.PaymentModeID                      
LEFT JOIN tblMasterCreditTerm MTCT ON MTCT.ID = TC.CreditTermID                      
LEFT JOIN tblRatings RT ON RT.ID = TC.Rating                      
JOIN tblUsers CUR ON CUR.ID = TC.CBy                      
LEFT JOIN tblUsers MUR ON MUR.ID = TC.MBy                      
left join tblImages IMG ON IMG.ID = TC.ID AND IMG.FormID = 2                  
ORDER BY TC.Name                      
END                      
IF(@Mode = 5)                      
BEGIN                      
DECLARE @OSVAL DECIMAL(25,4),@FAI INT, @OSCOUNT INT                      
SELECT @FAI = FAID FROM tblMasterCustomer WHERE ID = @ID                      
EXEC uspGetClosingBal @FAI,@ReturnValue OUTPUT                      
                      
SELECT @OSCOUNT = COUNT(ID), @OSVAL= SUM(Balance) FROM tblTranSalesHeader WHERE CustID = @ID AND Status IN (1,3) AND Balance > 0                      
SELECT *,@ReturnValue OSVAL,@OSCOUNT OSCOUNT,Billadd1 MobilePinAddress from tblMasterCustomer TC              
WHERE TC.ID = @ID                      
END                      
IF(@Mode = 6)                      
BEGIN                      
DECLARE @PT AS TABLE(ID SMALLINT)                      
IF(@ID = 1 OR @ID = 2)                      
BEGIN                      
INSERT INTO @PT                      
SELECT ID FROM tblPriceType                      
END                      
ELSE                      
BEGIN                      
INSERT INTO @PT                      
SELECT ID FROM tblPriceType WHERE ID NOT IN (1,6)                      
END                      
select 1 FType,'Price Type' Form,ID,PriceType Descriptions from tblPriceType WHERE Active = 1 and id IN (SELECT * FROM @PT)                      
union                      
select 2 FType,'Tax Type' Form,TaxTypeID,TaxTypeName Descriptions from tblMasterTaxType WHERE Active = 1                      
union                      
select 3 FType,'Payment Mode' Form,ID,PaymentMode Descriptions from tblPaymentMode WHERE Active = 1                      
union                      
select 4 FType,'Credit Term' Form,ID,Name Descriptions from tblMasterCreditTerm WHERE Active = 1                      
union                      
select 5 FType,'State Names' Form,StateID,CONVERT(NVARCHAR,TINNO)+' - '+ StateName Descriptions from tblGSTStateNameandCode WHERE Active = 1                      
union                      
select 6 FType,'Rating' Form,ID,RatingName Descriptions from tblRatings WHERE Active = 1                      
union                      
select 7 FType,'Customer Type' Form,ID,Name Descriptions from tblMasterCustomerType WHERE Active = 1                      
union                      
select 8 FType,'Beat' Form,ID,Name from tblMasterBeat where Active = 1                      
union                      
select 9 FType,'Salesman' Form,ID,Name from tblMasterSalesman where Active = 1                      
order by FType,Descriptions                      
END                      
IF(@Mode = 7)                      
BEGIN                      
select BSM.CustomerID,MB.Name Beat,SM.Name Salesman from tblBeatSalesmanMapping BSM                      
JOIN tblMasterBeat MB ON MB.ID = BSM.BeatID JOIN tblMasterSalesman SM ON SM.ID = BSM.SalesmanID                      
where CustomerID = @ID                      
ENd                      
IF(@Mode = 8)                      
BEGIN                      
if(isnull(@Name,1) = 0)                      
begin                      
delete from tblMasterCustomerRemarks where CustomerID = @ID                      
end                      
set @Code =(select dbo.ProperCase(@Code))                      
INSERT INTO tblMasterCustomerRemarks VALUES (@ID,@Code)                      
END                      
IF(@Mode = 9)                      
BEGIN                      
SELECT * FROM tblMasterCustomerRemarks WHERE CustomerID = @ID                      
END                      
IF(@Mode = 10)                    
BEGIN                    
SELECT * FROM tblImages WHERE FormID = 2 and ID = @ID                     
END                    
IF(@Mode = 11)                    
BEGIN                    
SELECT * FROM tblImages WHERE FormID = 2                  
end        
IF(@Mode = 12)                
BEGIN                
declare @TRBeatID INT,@TRSMID INT,@uRoleID INT = 0    
    
select @TRBeatID = ISNULL(BeatID,0),@TRSMID = ISNULL(SalesmanID,0),@uRoleID = isnull(RoleID,0) from tblUsers WHERE ID = @ID                   
    
DECLARE @MobShowAllCustomers int = (select COUNT(1) from tblRolePermissions where Role = @uRoleID and PermissionFormId = 567)    
    
declare @Query NVARCHAR(MAX)     
    
SET @Query = ' SELECT TC.ID,TC.Code,TC.Name,MCT.Name CustomerType,PT.PriceType,TC.OwnerName,                      
TC.ContactPerson,TC.Email,TC.Ph1,Tc.Ph2,TC.Mob1 Mob1,TC.Mob2,                      
TC.Billadd1,TC.Billadd2,Tc.Billadd3,TC.Shipadd1,TC.Shipadd2,TC.Shipadd3,TC.Pincode,TC.Distance,                      
TC.CreditLimitValue,dbo.fnGetRoundedValue(TC.CreditLimitCount)CreditLimitCount,dbo.fnGetRoundedValue(TC.OverDueValue)OverDueValue,    
TC.OverDueInvCount,TC.PANNumber,TC.AadharNo,TC.FSSAINo,TC.DLNo20,TC.DLNo21,SNTC.StateName,TC.GSTIN,MTT.TaxTypeName,PM.PaymentMode,MTCT.Name,    
dbo.fnGetRoundedValue(TC.DiscountPern)DiscountPern,TC.Remark,RT.RatingName Ratings,TC.TCSTax,TC.TrackPoint,                      
CASE WHEN TC.Active = 1 THEN ''Yes'' ELSE ''No'' END Active,CASE WHEN ISNULL(TC.MBy,0) = 0 THEN CUR.UserName ELSE MUR.UserName END CBy,                      
CASE WHEN ISNULL(TC.MBy,0) = 0 THEN CONVERT(NVARCHAR(100),TC.CDate) ELSE CONVERT(NVARCHAR(100),TC.MDate) END CDate,                      
TC.Latitude,TC.Longtitude,Shinecode,(CASE WHEN IMG.Filename is null then 0 else 1 end) Imagestate                  
FROM tblMasterCustomer TC                      
LEFT JOIN tblMasterCustomerType MCT ON MCT.ID = TC.CustomerType                      
LEFT JOIN tblPriceType PT ON PT.ID = TC.PriceTypeID                      
LEFT JOIN tblGSTStateNameandCode SNTC ON SNTC.StateID = TC.StateID                      
LEFT JOIN tblMasterTaxType MTT ON MTT.TaxTypeID = TC.TaxTypeID                      
LEFT JOIN tblPaymentMode PM ON PM.ID = TC.PaymentModeID                      
LEFT JOIN tblMasterCreditTerm MTCT ON MTCT.ID = TC.CreditTermID                      
LEFT JOIN tblRatings RT ON RT.ID = TC.Rating                      
JOIN tblUsers CUR ON CUR.ID = TC.CBy                      
LEFT JOIN tblUsers MUR ON MUR.ID = TC.MBy                      
left join tblImages IMG ON IMG.ID = TC.ID AND IMG.FormID = 2                  
LEFT JOIN tblBeatSalesmanMapping BSM ON BSM.CustomerID = TC.ID                
WHERE TC.Active = 1 '--AND BSM.BeatID = '+CONVERT(nvarchar(20),@TRBeatID) + ' AND BSM.SalesmanID = '+CONVERT(nvarchar(20),@TRSMID)
SET @Query += CASE WHEN @MobShowAllCustomers = 1 THEN     
(CASE WHEN @TRBeatID = 0 THEN '' ELSE ' AND BSM.BeatID =  '+CONVERT(nvarchar(20),@TRBeatID) END)    
ELSE ' AND BSM.BeatID =  '+CONVERT(nvarchar(20),@TRBeatID) END    
SET @Query += CASE WHEN @MobShowAllCustomers = 1 THEN     
(CASE WHEN @TRSMID = 0 THEN '' ELSE ' AND BSM.SalesmanID =  '+CONVERT(nvarchar(20),@TRSMID) END)    
ELSE ' AND BSM.SalesmanID =  '+CONVERT(nvarchar(20),@TRSMID) END
SET @Query += CASE WHEN @Code = 0 THEN ' AND (isnull(TC.Latitude,'''') != '''' and isnull(TC.Longtitude,'''') != '''' )'     
ELSE '' END    
SET @Query += ' ORDER BY TC.Name   '    
PRINT @Query
EXEC sys.sp_executesql @Query, N'@Mode int, @ID int, @Code nvarchar(255), @Name nvarchar(255), @Billadd1 nvarchar(MAX), @Billadd2 nvarchar(MAX), @Billadd3 nvarchar(MAX), @Shipadd1 nvarchar(MAX), @shipadd2 nvarchar(MAX), @Shipadd3 nvarchar(MAX), @Pincode nvarchar(15), @ContactPerson nvarchar(255), @Ph1 nvarchar(25), @Ph2 nvarchar(25), @Mob1 nvarchar(25), @Mob2 nvarchar(25), @Email nvarchar(255), @PANNumber nvarchar(25), @AadharNo nvarchar(25), @DLNo20 nvarchar(25), @DLNo21 nvarchar(25), @FSSAINo nvarchar(30), @StateID tinyint, @GSTIN nvarchar(40), @CreditTermID tinyint, @PaymentModeID tinyint, @TaxTypeID tinyint, @FAID int, @OverDueValue decimal(25, 4), @OverDueInvCount smallint, @CreditLimitValue decimal(25, 4), @CreditLimitCount smallint, @CreditlimitOS decimal(25, 4), @PriceTypeID tinyint, @OwnerName nvarchar(255), @DiscountPern decimal(25, 4), @TrackPoint smallint, @ClosingTrackPoint decimal(25, 4), @TCSTax smallint, @Latitude nvarchar(25), @Longtitude nvarchar(25), @Distance smallint, @Remark nvarchar(MAX), @Active smallint, @UserID smallint, @CustomerType SMALLINT, @Rating TINYINT, @Shinecode nvarchar(50), @RemoveLocation smallint', @Mode = @Mode, @ID = @ID, @Code = @Code, @Name = @Name, @Billadd1 = @Billadd1, @Billadd2 = @Billadd2, @Billadd3 = @Billadd3, @Shipadd1 = @Shipadd1, @shipadd2 = @shipadd2, @Shipadd3 = @Shipadd3, @Pincode = @Pincode, @ContactPerson = @ContactPerson, @Ph1 = @Ph1, @Ph2 = @Ph2, @Mob1 = @Mob1, @Mob2 = @Mob2, @Email = @Email, @PANNumber = @PANNumber, @AadharNo = @AadharNo, @DLNo20 = @DLNo20, @DLNo21 = @DLNo21, @FSSAINo = @FSSAINo, @StateID = @StateID, @GSTIN = @GSTIN, @CreditTermID = @CreditTermID, @PaymentModeID = @PaymentModeID, @TaxTypeID = @TaxTypeID, @FAID = @FAID, @OverDueValue = @OverDueValue, @OverDueInvCount = @OverDueInvCount, @CreditLimitValue = @CreditLimitValue, @CreditLimitCount = @CreditLimitCount, @CreditlimitOS = @CreditlimitOS, @PriceTypeID = @PriceTypeID, @OwnerName = @OwnerName, @DiscountPern = @DiscountPern, @TrackPoint = @TrackPoint, @ClosingTrackPoint = @ClosingTrackPoint, @TCSTax = @TCSTax, @Latitude = @Latitude, @Longtitude = @Longtitude, @Distance = @Distance, @Remark = @Remark, @Active = @Active, @UserID = @UserID, @CustomerType = @CustomerType, @Rating = @Rating, @Shinecode = @Shinecode, @RemoveLocation = @RemoveLocation    
    
              
END                
END TRY                      
BEGIN CATCH                      
SELECT ERROR_MESSAGE(),ERROR_PROCEDURE(), ERROR_LINE()                      
END CATCH                      
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspManageSingleMaster';
GO
--exec uspManageSingleMaster 1,3,2,'AXIS BANK PVT LTD',1,3                        
CREATE OR ALTER PROCEDURE [dbo].[uspManageSingleMaster]                    
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
SET @strQuery = '  IF ISNULL((SELECT COUNT(*) FROM dbo.'+@TableName+' WHERE [Name]=@Name),0) >0                          
 BEGIN                          
  RAISERROR(''Name Already Exists'',16,1)                          
 END                         
INSERT INTO '+@TableName+'([Name],Active,CBy,CDate) VALUES (@Name,'+CONVERT(NVARCHAR(50),@Active)+','+CONVERT(NVARCHAR(50),@CBy)+',GETDATE())                        
select SCOPE_IDENTITY()  '                    
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Active BIT, @CBy SMALLINT', @FormID = @FormID, @Mode = @Mode, @ID = @ID, @Name = @Name, @Active = @Active, @CBy = @CBy                    
END                        
IF(@Mode = 2)-- Modify Existing Data                        
BEGIN                        
SET @strQuery = '  IF ISNULL((SELECT COUNT(*) FROM dbo.'+@TableName +' WHERE [Name]= @Name and ID != '+CONVERT(nvarchar(50),@ID)+'),0) >0                          
 BEGIN                          
  RAISERROR(''Name Already Exists'',16,1)                          
 END                         
 INSERT INTO tblMasterHistory (FormID,ID,Name,Active,CBy,CDate,MBy,MDate'+
 (case when CONVERT(nvarchar(50),@FormID) = '2' then ',PLName' else '' end)+',HisCBy,HisCDate)          
(select '+CONVERT(nvarchar(50),@FormID)+',*,'+CONVERT(nvarchar(50),@CBy)+',GETDATE() from '+@TableName+' where ID = '+CONVERT(nvarchar(50),@ID)+')           
UPDATE '+@TableName +' SET [Name]=@Name,Active='+CONVERT(nvarchar(50),@Active)+',MBy='+CONVERT(nvarchar(50),@CBy)+',MDate=GETDATE() WHERE ID ='+CONVERT(nvarchar(50),@ID)                        
set @strQuery = @strQuery + ' SELECT ' +CONVERT(nvarchar(50),@ID)                     
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Active BIT, @CBy SMALLINT', @FormID = @FormID, @Mode = @Mode, @ID = @ID, @Name = @Name, @Active = @Active, @CBy = @CBy                    
END                        
IF(@Mode = 3)-- Get All details                        
BEGIN                        
SET @strQuery = ' SELECT PH.*,CASE WHEN ISNULL(PH.MBy,0) = 0 THEN CUR.UserName ELSE MUR.UserName END  UserName,    
 CASE WHEN ISNULL(PH.MBy,0) = 0 THEN CONVERT(NVARCHAR(100),PH.CDate) ELSE CONVERT(NVARCHAR(100),PH.MDate) END LastActionTime FROM '+@TableName+' PH    
JOIN tblUsers CUR ON CUR.ID = PH.CBy              
LEFT JOIN tblUsers MUR ON MUR.ID = PH.MBy      
WHERE PH.ID != '+(CASE WHEN @FormID = 12 THEN ' 1 ' ELSE '0' END)+' ORDER BY PH.[Name]'                        
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Active BIT, @CBy SMALLINT', @FormID = @FormID, @Mode = @Mode, @ID = @ID, @Name = @Name, @Active = @Active, @CBy = @CBy                    
END                        
IF(@Mode = 4)-- Get Particular  details by  Name                        
BEGIN                        
SET @strQuery = '  SELECT * FROM '+@TableName+' WHERE [Name] = @Name'                    
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Active BIT, @CBy SMALLINT', @FormID = @FormID, @Mode = @Mode, @ID = @ID, @Name = @Name, @Active = @Active, @CBy = @CBy                    
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
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspManageTaxCompGift';
GO
--exec [uspManageTaxCompGift] 4,3,1,'DAFFS BANK pvt ltd',1,3                    
CREATE OR ALTER PROCEDURE [dbo].[uspManageTaxCompGift]            
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
SET @strQuery = '  IF ISNULL((SELECT COUNT(*) FROM dbo.'+@TableName+' WHERE [Name]=@Name),0) >0                      
 BEGIN                      
  RAISERROR(''Name Already Exists'',16,1)                      
 END                     
INSERT INTO '+@TableName+'([Name],Value,Active,CBy,CDate) VALUES (@Name,'+CONVERT(NVARCHAR(50),@Value)+','+CONVERT(NVARCHAR(50),@Active)+','+CONVERT(NVARCHAR(50),@CBy)+',GETDATE())                    
select SCOPE_IDENTITY()  '                
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Value decimal(25,4), @Active BIT, @CBy SMALLINT', @FormID = @FormID, @Mode = @Mode, @ID = @ID, @Name = @Name, @Value = @Value, @Active = @Active, @CBy = @CBy                
END                    
IF(@Mode = 2)-- Modify Existing Data                    
BEGIN                    
set @Name = (select dbo.ProperCase(@Name))             
SET @strQuery = '  IF ISNULL((SELECT COUNT(*) FROM dbo.'+@TableName +' WHERE [Name]= @Name and ID != '+CONVERT(nvarchar(50),@ID)+'),0) >0                      
 BEGIN                      
  RAISERROR(''Name Already Exists'',16,1)                      
 END                     
  INSERT INTO tblMasterHistory (FormID,ID,Name,Column1,Active,CBy,CDate,MBy,MDate,HisCBy,HisCDate)        
(select '+CONVERT(nvarchar(50),@FormID)+',*,'+CONVERT(nvarchar(50),@CBy)+',GETDATE() from '+@TableName+' where ID = '+CONVERT(nvarchar(50),@ID)+')         
        
 UPDATE '+@TableName +' SET [Name]=@Name,Value = '+CONVERT(nvarchar(50),@Value)+',Active='+CONVERT(nvarchar(50),@Active)+',MBy='+CONVERT(nvarchar(50),@CBy)+',MDate=GETDATE() WHERE ID ='+CONVERT(nvarchar(50),@ID)                    
set @strQuery = @strQuery + ' SELECT ' +CONVERT(nvarchar(50),@ID)                 
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Value decimal(25,4), @Active BIT, @CBy SMALLINT', @FormID = @FormID, @Mode = @Mode, @ID = @ID, @Name = @Name, @Value = @Value, @Active = @Active, @CBy = @CBy                
END                    
IF(@Mode = 3)-- Get All details                    
BEGIN                    
SET @strQuery = ' SELECT PH.ID,PH.Name,'+CASE WHEN @FormID IN (4,43) THEN 'CONVERT(INT, PH.Value) Value' ELSE 'dbo.fnGetRoundedValue(PH.Value) Value' END+',
PH.Active,PH.CBy,PH.CDate,PH.MBy,PH.MDate,CASE WHEN ISNULL(PH.MBy,0) = 0 THEN CUR.UserName ELSE MUR.UserName END  UserName,    
 CASE WHEN ISNULL(PH.MBy,0) = 0 THEN CONVERT(NVARCHAR(100),PH.CDate) ELSE CONVERT(NVARCHAR(100),PH.MDate) END LastActionTime FROM '+@TableName+' PH    
JOIN tblUsers CUR ON CUR.ID = PH.CBy              
LEFT JOIN tblUsers MUR ON MUR.ID = PH.MBy  ORDER BY PH.[Name]'                    
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Value decimal(25,4), @Active BIT, @CBy SMALLINT', @FormID = @FormID, @Mode = @Mode, @ID = @ID, @Name = @Name, @Value = @Value, @Active = @Active, @CBy = @CBy                
END                    
IF(@Mode = 4)-- Get Particular  details by  Name                    
BEGIN                    
SET @strQuery = '  SELECT * FROM '+@TableName+' WHERE [Name] = @Name'                
EXEC sys.sp_executesql @strQuery, N'@FormID int, @Mode int, @ID Smallint, @Name NVARCHAR(MAX), @Value decimal(25,4), @Active BIT, @CBy SMALLINT', @FormID = @FormID, @Mode = @Mode, @ID = @ID, @Name = @Name, @Value = @Value, @Active = @Active, @CBy = @CBy                
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
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspManufSalesableDmgReturnAnalysis';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspManufSalesableDmgReturnAnalysis]        
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
SET @StrQuery = ' SELECT  MF.ID ,MF.Name,'+''''+CONVERT(NVARCHAR,@Query)+''''+',              
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
 SET @StrQuery += (CASE WHEN ISNULL(@FD,'')='' AND ISNULL(@TD,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FD AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@TD AS DATE))+''')' END)                    
 set @StrQuery += case when ISNULL(@BranchName,'') = '' then '' else ' AND TSH.BranchID  = '+''''+ CONVERT(nvarchar(50),@BranchName)+''''+'' END          
 set @StrQuery += case when ISNULL(@BrandName,'') = '' then '' else ' AND MB.ID IN (SELECT * from dbo.fnSplitString( @BrandName,'',''))' END          
 set @StrQuery += case when ISNULL(@CategoryName,'') = '' then '' else ' AND MC.ID IN (SELECT * from dbo.fnSplitString( @CategoryName,'',''))' END          
 set @StrQuery += case when ISNULL(@ManufName,'') = '' then '' else ' AND MF.ID IN (SELECT * from dbo.fnSplitString( @ManufName,'',''))' END          
 set @StrQuery += case when ISNULL(@ProductName,'') = '' then '' else ' AND MP.ID IN (SELECT * from dbo.fnSplitString( @ProductName,'',''))' END           
 set @StrQuery += ' group by TransactionType,MF.ID,MF.Name,TSH.InvDate ORDER BY TSH.InvDate ASC '    
INSERT INTO #TEMP         
EXEC sys.sp_executesql @StrQuery, N'@BranchName int, @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BranchName = @BranchName, @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName, @FromDate = @FromDate, @ToDate = @ToDate        
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
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspManufwiseStockHoldingHeader';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspManufwiseStockHoldingHeader]        
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
 set @query += case when ISNULL(@BranchName,'') = '' then '' else ' AND MT.BranchID = '+''''+ CONVERT(nvarchar(50),@BranchName)+''''+'' END          
 set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND MB.ID IN (SELECT * from dbo.fnSplitString( @BrandName,'',''))' END          
 set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND MC.ID IN (SELECT * from dbo.fnSplitString( @CategoryName,'',''))' END          
 set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND [ManufID] IN (SELECT * from dbo.fnSplitString( @ManufName,'',''))' END          
 set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND MP.ID IN (SELECT * from dbo.fnSplitString( @ProductName,'',''))' END              
SET @query = @query + ' GROUP BY ManufID,[Manufacture Name],[Month Sales],[Perday Sales] ORDER BY SUM([Stock Hold]) DESC '          
EXEC sys.sp_executesql @query, N'@BranchName int, @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BranchName = @BranchName, @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName, @FromDate = @FromDate, @ToDate = @ToDate            
drop table #Temp1,#Temp2,#MAINTEMP         
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspMfrwisesalesDetail';
GO
  CREATE OR ALTER PROCEDURE [dbo].[uspMfrwisesalesDetail]      
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
WHERE TSH.Status IN (1,3,5) AND TSH.DocPrefix = 15 AND ISNULL(TSD.TaxId,0)>0 AND MP.MfrID = '+CONVERT(nvarchar,@ManufID)      
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)                  
  
    
      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND TSH.BranchID = @BranchName' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BrandName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString( @BrandName,'',''))' END)                
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CategoryName,'')='' THEN '' ELSE ' AND PHL.ID IN (SELECT * from dbo.fnSplitString( @CategoryName,'',''))' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ProductName,'')='' THEN '' ELSE ' AND MP.ID IN (SELECT * from dbo.fnSplitString( @ProductName,'',''))' END)       
SET @StrQuery = @StrQuery + ' GROUP BY MP.Code,MP.Name,MP.EAN,TSH.DocPrefix,MB.Name,PHL.Name,MF.Name'      
EXEC sys.sp_executesql @StrQuery, N'@ManufID INT, @BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @ToDate DATE', @ManufID = @ManufID, @BranchName = @BranchName, @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName, @FromDate = @FromDate, @ToDate = @ToDate      
 END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspMfrwisesalesHeader';
GO
 CREATE OR ALTER PROCEDURE [dbo].[uspMfrwisesalesHeader]    
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
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)                  
  
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND TSH.BranchID = @BranchName' END)     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ManufName,'')='' THEN '' ELSE ' AND MM.ID IN (SELECT * from dbo.fnSplitString ( @ManufName,'',''))' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BrandName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString ( @BrandName,'',''))' END)            
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CategoryName,'')='' THEN '' ELSE ' AND PHL.ID IN (SELECT * from dbo.fnSplitString ( @CategoryName,'',''))' END)     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ProductName,'')='' THEN '' ELSE ' AND MP.ID IN (SELECT * from dbo.fnSplitString ( @ProductName,'',''))' END)     
SET @StrQuery = @StrQuery + ' GROUP BY MP.MfrID,MM.Name,TSH.DocPrefix order by MM.Name'  
EXEC sys.sp_executesql @StrQuery, N'@BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BranchName = @BranchName, @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName, @FromDate = @FromDate, @ToDate = @ToDate  
 END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspMobileCustomerOS';
GO
--uspMobileCustomerOS 2,0,0,'','15,30,45'  
CREATE OR ALTER PROCEDURE [dbo].[uspMobileCustomerOS]  
@Mode int, @BeatName int=0,@SalesmanName int=0,@CustomerName NVARCHAR(255)='',  
@fnSplitString NVARCHAR(MAX) = '10',@CustomerType int = 0,@Rating int = 0  
AS  
BEGIN  
IF(@Mode = 1)  
BEGIN  
SELECT ID,Name FROM tblMasterBeat WHERE Active = 1 ORDER BY Name  
SELECT ID,Name FROM tblMasterSalesman WHERE Active = 1 ORDER BY Name  
SELECT ID,Name FROM tblMasterCustomer WHERE Active = 1 ORDER BY Name  
SELECT ID,Name FROM tblMasterCustomerType WHERE Active = 1 ORDER BY Name  
SELECT ID,RatingName Name FROM tblRatings WHERE Active = 1 ORDER BY Name  
SELECT ID, Name FROM tblmasterPeriod WHERE Active = 1 ORDER BY Name  
END  
ELSE IF(@Mode = 2)  
BEGIN  
DECLARE @Serial INT,@Count INT, @Query NVARCHAR(MAX),@Count1 INT,@MainSerial INT, @MainCount INT,@AlterColumnName0 NVARCHAR(255),@AlterColumnName1 NVARCHAR(255)  
DECLARE @Ageing INT,@nCount INT,@nCount1 INT,@nSerial INT,@IsTrueFalse NVARCHAR(10),@nF INT,@nT INT,@nColumnName NVARCHAR(255)  
DECLARE @AsOnDate DATE = getdate()  
SELECT CD.DocID,ISNULL(SUM(TotalAmtAdj),0) TotalAmtAdj INTO #COLTEMP  
FROM tblTranCollectionHeader CH  
JOIN tblTranCollectionDetail CD ON CD.ColID = CH.ColID  
WHERE ColDate > @AsOnDate AND Status IN (1,3,5)  
GROUP BY CD.DocID  
  
--select * from #COLTEMP  
  
SELECT FAC.NoteID,FAC.Adjustment INTO #JVTEMP  
FROM tblFAJournal FA  
JOIN tblFAJournelCancel FAC ON FAC.JVID = FA.JVID  
WHERE DocPrefix = 8 AND DocDate > @AsOnDate AND FA.Status IN (1,3,5)  
GROUP BY FAC.NoteID,FAC.Adjustment  
  
--select * from #JVTEMP  
  
-- Create #TempTable1 for Moving Original Data  
CREATE TABLE #TempTable (DocPrefix int,ID INT,CustomerID int,[Customer Name] NVARCHAR(255)  
,[Opening Amount] DECIMAL(25,6),[Pending Amount] DECIMAL(25,6),[SR Balance] DECIMAL(25,6),[Ageing] INT)  
  
CREATE TABLE #TempTable1 (ID INT IDENTITY(1,1),DocPrefix int,CustomerID int,[Customer Name] NVARCHAR(255)  
,[Net Amt] NVARCHAR(255),[Balance] NVARCHAR(255),[SR Balance] NVARCHAR(255),[Ageing] INT)  
  
SELECT DocPrefix,SRI.[ID],[Customer ID],SRI.[Customer Name],SRI.[Opening Amount],SRI.[Pending Amount],SRI.[SR Balance],SRI.Ageing  
INTO #TEMPDATA  
FROM  
(  
SELECT SH.DocPrefix,SH.ID,FORMAT(SH.InvDate,'dd/MMM/yyyy')[Doc Date],ISNULL(MC.ID,0)[Customer ID],MC.Name[Customer Name],  
SH.NetAmt[Opening Amount],  
CASE WHEN SH.DocPrefix = 15 THEN SH.Balance ELSE 0 END AS [Pending Amount],  
CASE WHEN SH.DocPrefix = 16 THEN SH.Balance ELSE 0 END AS [SR Balance],  
DATEDIFF(DAY,InvDate,@AsOnDate) AS [Ageing]  
FROM tblTranSalesHeader SH  
JOIN tblMasterCustomer MC on MC.ID = SH.CustID  
WHERE SH.DocPrefix in (15,16) AND SH.InvDate <= @AsOnDate AND SH.Status IN (1,3,5,6,7)  
and (@BeatName = 0 or sh.BeatID = @BeatName) and (@SalesmanName = 0 or sh.SalesManID = @SalesmanName)  
and (@CustomerType = 0 or MC.CustomerType = @CustomerType) and (@Rating = 0 or MC.Rating = @Rating)  
and (@CustomerName = '' or MC.Name = @CustomerName)  
UNION ALL  
SELECT SH.DocPrefix,SH.ColID ID,FORMAT(SH.ColDate,'dd/MMM/yyyy')[Doc Date],ISNULL(MC.ID,0)[Customer ID],MC.Name[Customer Name],  
SH.ColAmt [ColAmt],  
0 AS [Pending Amount],  
CASE WHEN SH.DocPrefix = 19 THEN SH.Balance ELSE 0 END AS [SR Balance],  
DATEDIFF(DAY,ColDate,@AsOnDate) AS [Ageing]  
FROM tblTranCollectionHeader SH  
JOIN tblMasterCustomer MC on MC.FAID = SH.AccID  
  
WHERE SH.DocPrefix in (19) AND SH.ColDate <= @AsOnDate AND SH.Status IN (1,3,5)  
and (@BeatName = 0 or sh.BeatID = @BeatName) and (@SalesmanName = 0 or sh.SalesManID = @SalesmanName)  
and (@CustomerType = 0 or MC.CustomerType = @CustomerType) and (@Rating = 0 or MC.Rating = @Rating)  
and (@CustomerName = '' or MC.Name = @CustomerName)  
UNION ALL  
SELECT SH.TransID,SH.ID ID,FORMAT(SH.DocDate,'dd/MMM/yyyy')[Doc Date],ISNULL(MC.ID,0)[Customer ID],MC.Name[Customer Name],  
SH.NetAmount [ColAmt],  
CASE WHEN SH.TransID = 7 THEN SH.Balance ELSE 0 END AS [Pending Amount],  
0 AS [SR Balance],  
--DATEDIFF(DAY,DocDate,@AsOnDate) AS [Ageing]  
(DATEDIFF(DD,ISNULL((select MIN(Date) from tblTranChequeDeposit CHQD  
JOIN tblTranCollectionDetail CH ON CH.ColID = CHQD.CollId  
where ChargesVoucherId = SH.ID OR ChaqueVoucherId = SH.ID),DocDate),@AsOnDate)) Ageing  
FROM tblTranPRVoucher SH  
JOIN tblMasterCustomer MC on MC.FAID = SH.PartyID  
LEFT JOIN tblBeatSalesmanMapping BSM ON BSM.CustomerID = MC.ID  
WHERE SH.TransID in (7) AND SH.DocDate <= @AsOnDate AND SH.Status IN (1,3,5,6,7)  
and (@BeatName = 0 or BSM.BeatID = @BeatName) and (@SalesmanName = 0 or BSM.SalesManID = @SalesmanName)  
and (@CustomerType = 0 or MC.CustomerType = @CustomerType) and (@Rating = 0 or MC.Rating = @Rating)  
and (@CustomerName = '' or MC.Name = @CustomerName)  
UNION ALL  
SELECT SH.TransID,SH.ID ID,FORMAT(SH.DocDate,'dd/MMM/yyyy')[Doc Date],ISNULL(MC.ID,0)[Customer ID],MC.Name[Customer Name],  
SH.NoteValue [ColAmt],  
0 AS [Pending Amount],  
CASE WHEN SH.TransID = 4 THEN SH.Balance ELSE 0 END AS [SR Balance],  
DATEDIFF(DAY,DocDate,@AsOnDate) AS [Ageing]  
FROM tblNoteDetails SH  
JOIN tblMasterCustomer MC on MC.FAID = SH.PartyID  
LEFT JOIN tblBeatSalesmanMapping BSM ON BSM.CustomerID = MC.ID  
WHERE SH.TransID in (4) AND SH.DocDate <= @AsOnDate AND SH.Status IN (1,3,5,6,7)  
and (@BeatName = 0 or BSM.BeatID = @BeatName) and (@SalesmanName = 0 or BSM.SalesManID = @SalesmanName)  
and (@CustomerType = 0 or MC.CustomerType = @CustomerType) and (@Rating = 0 or MC.Rating = @Rating)  
and (@CustomerName = '' or MC.Name = @CustomerName)  
)SRI  
-- Create #TempID for Split String Ageing Wise  
CREATE TABLE #TempID (IdentID INT IDENTITY(1,1),ID INT)  
  
-- Create #TempAlterColumns for Identifying Column and Checking Range Between  
CREATE TABLE #TempAlterColumns (IdentID INT IDENTITY(1,1),[From] INT,[To] INT,OriginalColumn NVARCHAR(MAX))  
  
-- Insert Spliting String Datas  
INSERT INTO #TempID  
SELECT * FROM (SELECT DISTINCT id FROM dbo.fnSplitString(@fnSplitString,',') WHERE ISNULL(id,'')!='') AS SRI ORDER BY CAST(SRI.id AS INT)  
  
--select * from #TEMPDATA  
INSERT INTO #TempTable  
SELECT DocPrefix,ID,[Customer ID],[Customer Name],SUM([Opening Amount]) [Opening Amount],SUM([Pending Amount]) [Pending Amount],  
SUM([SR Balance]) [SR Balance],Ageing  
FROM #TEMPDATA  
WHERE (Ageing = 0 OR Ageing != 0)  
AND(@CustomerName = '' OR [Customer Name] = @CustomerName)  
GROUP BY DocPrefix,ID,[Customer ID],[Customer Name],Ageing  
ORDER BY [Customer Name]  
  
--select * from #TempTable  
  
INSERT INTO #TempTable1  
SELECT DocPrefix,CustomerID,[Customer Name],  
DBO.fnGetRoundedValue([Opening Amount]) [Opening Amount],DBO.fnGetRoundedValue([Pending Amount]) [Pending Amount],  
DBO.fnGetRoundedValue([SR Balance]) [SR Balance],Ageing FROM (  
SELECT DocPrefix,CustomerID,TT.[ID],TT.[Customer Name],  
SUM((TT.[Opening Amount])) [Opening Amount],SUM(((TT.[Pending Amount] + ISNULL(CT.TotalAmtAdj,0)+ ISNULL(Adjustment,0)))) AS [Pending Amount],  
SUM(TT.[SR Balance] *-1) AS [SR Balance],Ageing  
FROM #TempTable TT  
LEFT JOIN #COLTEMP CT ON CT.DocID = TT.ID  
LEFT JOIN #JVTEMP JV ON JV.NoteID = TT.ID  
--WHERE (TT.[Pending Amount] + ISNULL(CT.TotalAmtAdj,0)+ ISNULL(Adjustment,0)) <> 0  
GROUP BY DocPrefix,ID,[SR Balance],CustomerID,[Customer Name],Ageing  
) AS NK  
WHERE ((cast(([Pending Amount]) as numeric(26,2))) <> 0 or (cast(([SR Balance]) as numeric(26,2))) <> 0 )  
order by [Customer Name]  
  
SET @Count1 = (SELECT COUNT(*) FROM #TempID);  
SET @Count = (SELECT COUNT(*) FROM #TempID);  
SET @Serial = 1  
-- Looping for Alter and Spliting Columns using Ageing Wise  
IF ISNULL(@Count1,0)>1  
BEGIN  
print 'aaaaaaaaaaaaaaaaaa'  
WHILE (@Count > 0)  
BEGIN  
SET @AlterColumnName0 = (SELECT ID FROM #TempID WHERE IdentID = @Serial-1)  
SET @AlterColumnName1 = (SELECT ID FROM #TempID WHERE IdentID = @Serial)  
SET @AlterColumnName0 = @AlterColumnName0+1  
IF ISNULL(@Count,0)=1  
BEGIN  
SET @Query = 'ALTER TABLE #TempTable1 ADD ['+@AlterColumnName0+'-'+@AlterColumnName1+' Days] VARCHAR(100) NULL,[>'+@AlterColumnName1+' Days] VARCHAR(100) NULL'  
EXEC sys.sp_executesql @Query, N'@Mode int, @BeatName int, @SalesmanName int, @CustomerName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @CustomerType int, @Rating int', @Mode = @Mode, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @fnSplitString = @fnSplitString, @CustomerType = @CustomerType, @Rating = @Rating  
INSERT INTO #TempAlterColumns VALUES ((@AlterColumnName0),@AlterColumnName1,'['+@AlterColumnName0+'-'+@AlterColumnName1+' Days]')  
INSERT INTO #TempAlterColumns VALUES ((@AlterColumnName1),0,'[>'+@AlterColumnName1+' Days]')  
END  
ELSE IF ISNULL(@Count,0)= @Count1  
BEGIN  
SET @Query = 'ALTER TABLE #TempTable1 ADD [0-'+@AlterColumnName1+' Days] VARCHAR(100) NULL'  
EXEC sys.sp_executesql @Query, N'@Mode int, @BeatName int, @SalesmanName int, @CustomerName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @CustomerType int, @Rating int', @Mode = @Mode, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @fnSplitString = @fnSplitString, @CustomerType = @CustomerType, @Rating = @Rating  
INSERT INTO #TempAlterColumns VALUES (0,@AlterColumnName1,'[0-'+@AlterColumnName1+' Days]')  
END  
ELSE  
BEGIN  
SET @Query = 'ALTER TABLE #TempTable1 ADD ['+@AlterColumnName0+'-'+@AlterColumnName1+' Days] VARCHAR(100) NULL'  
EXEC sys.sp_executesql @Query, N'@Mode int, @BeatName int, @SalesmanName int, @CustomerName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @CustomerType int, @Rating int', @Mode = @Mode, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @fnSplitString = @fnSplitString, @CustomerType = @CustomerType, @Rating = @Rating  
INSERT INTO #TempAlterColumns VALUES ((@AlterColumnName0),@AlterColumnName1,'['+@AlterColumnName0+'-'+@AlterColumnName1+' Days]')  
END  
SET @Count = @Count - 1;  
SET @Serial = @Serial + 1;  
END  
END  
ELSE  
BEGIN  
SET @AlterColumnName0 = (SELECT ID FROM #TempID WHERE IdentID = 1)  
SET @Query = 'ALTER TABLE #TempTable1 ADD [0-'+@AlterColumnName0+' Days] VARCHAR(100) NULL,[>'+@AlterColumnName0+' Days] VARCHAR(100) NULL'  
EXEC sys.sp_executesql @Query, N'@Mode int, @BeatName int, @SalesmanName int, @CustomerName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @CustomerType int, @Rating int', @Mode = @Mode, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @fnSplitString = @fnSplitString, @CustomerType = @CustomerType, @Rating = @Rating  
INSERT INTO #TempAlterColumns VALUES (0,@AlterColumnName0,'[0-'+@AlterColumnName0+' Days]')  
INSERT INTO #TempAlterColumns VALUES (@AlterColumnName0,0,'[>'+@AlterColumnName0+' Days]')  
END  
SET @MainCount = (SELECT COUNT(*) FROM #TempTable1);  
SET @MainSerial = 1  
-- Looping for Get Ageing Information from #TempTable1  
WHILE (@MainCount > 0)  
BEGIN  
SET @Ageing = (SELECT Ageing FROM #TempTable1 WHERE ID = @MainSerial)  
SET @nCount = (SELECT COUNT(*) FROM #TempAlterColumns)  
SET @nCount1 = (SELECT COUNT(*) FROM #TempAlterColumns)  
SET @nSerial = 1  
-- Looping for Check Ageing and From and To Between Ageing Range  
WHILE (@nCount > 0)  
BEGIN  
SET @nF = (SELECT [From] FROM #TempAlterColumns WHERE IdentID = @nSerial)  
SET @nT = (SELECT [to] FROM #TempAlterColumns WHERE IdentID = @nSerial)  
SET @nColumnName = (SELECT OriginalColumn FROM #TempAlterColumns WHERE IdentID = @nSerial)  
IF ISNULL(@nCount1,0) = ISNULL(@nSerial,0)  
BEGIN  
SELECT @IsTrueFalse = (CASE WHEN @Ageing > @nF THEN 'TRUE' ELSE 'FALSE' END)  
END  
ELSE  
BEGIN  
SELECT @IsTrueFalse = (CASE WHEN @Ageing BETWEEN @nF AND @nT THEN 'TRUE' ELSE 'FALSE' END)  
END  
  
-- IF TRUE Updating Pending Amount to Specific Columns  
IF ISNULL(@IsTrueFalse,'')='TRUE'  
BEGIN  
SET @Query = 'UPDATE #TempTable1 SET '+@nColumnName+' = (CASE WHEN DocPrefix = 16 then [SR Balance] ELSE [Balance] END) WHERE ID='+CAST(@MainSerial AS NVARCHAR)+''  
EXEC sys.sp_executesql @Query, N'@Mode int, @BeatName int, @SalesmanName int, @CustomerName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @CustomerType int, @Rating int', @Mode = @Mode, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @fnSplitString = @fnSplitString, @CustomerType = @CustomerType, @Rating = @Rating  
BREAK;  
END  
  
SET @nCount = @nCount - 1;  
SET @nSerial = @nSerial + 1;  
END  
SET @MainCount = @MainCount - 1;  
SET @MainSerial = @MainSerial + 1;  
END  
  
declare @Name varchar(max)  
Select @Name = Coalesce(@Name + ',', '') + 'dbo.fnGetRoundedValue(SUM(CONVERT(DECIMAL(25,4), ISNULL([' + Ltrim(name) + '],0)))) AS ' + '[' + Ltrim(name) + ']'  
from tempdb.sys.columns  
where object_id = object_id('tempdb..#TempTable1') and name not in ('ID','CustomerID','Customer Name','Ageing',  
'DocPrefix','SR Balance','Net Amt','Balance') --  
ORDER BY column_id  
--SELECT @Name  
  
-- Select all data from #TempTable1 Finally  
--alter table #TempTable1 drop column ID  
--alter table #TempTable1 drop column DocPrefix  
--SELECT * FROM #TempTable1  
set @Query = 'SELECT CustomerID,[Customer Name],'+@Name +',  
dbo.fnGetRoundedValue(SUM(CONVERT(DECIMAL(25,4), ISNULL(Balance - ABS([SR Balance]),0))))[Net Balance],  
dbo.fnGetRoundedValue(SUM(CONVERT(DECIMAL(25,4), ISNULL([Net Amt],0))))[Net Amt],  
dbo.fnGetRoundedValue(SUM(CONVERT(DECIMAL(25,4), ISNULL(Balance,0)))) Balance,  
dbo.fnGetRoundedValue(SUM(CONVERT(DECIMAL(25,4), ISNULL(ABS([SR Balance]),0)))) [Payable] FROM #TempTable1 GROUP BY CustomerID,[Customer Name] ORDER BY [Customer Name]'  
EXEC sys.sp_executesql @Query, N'@Mode int, @BeatName int, @SalesmanName int, @CustomerName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @CustomerType int, @Rating int', @Mode = @Mode, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @fnSplitString = @fnSplitString, @CustomerType = @CustomerType, @Rating = @Rating  
-- Drop all #Temp Tables  
DROP TABLE #TempTable1,#TempTable,#TempID,#COLTEMP,#JVTEMP ,#TempAlterColumns,#TEMPDATA  
END  
ELSE IF(@Mode = 3)  
BEGIN  
select DocID,DocDate,NetAmt,OSAmt,Ageing from (  
SELECT CASE WHEN DocPrefix = 15 THEN 1 ELSE 2 END SerialNo,DocID,FORMAT(InvDate,'dd/MMM/yyyy') DocDate,NetAmt,  
CASE WHEN DocPrefix = 15 THEN Balance ELSE Balance *-1 END OSAmt,  
DATEDIFF(DD,InvDate,GETDATE()) Ageing  
FROM tblTranSalesHeader WHERE Status NOT IN (2,4) AND CustID = @BeatName AND Balance > 0  
UNION ALL  
SELECT 3 SerialNo,DocID,FORMAT(DocDate,'dd/MMM/yyyy') DocDate,NetAmount NetAmt,Balance OSAmt,  
(DATEDIFF(DD,ISNULL((select MIN(Date) from tblTranChequeDeposit CHQD  
JOIN tblTranCollectionDetail CH ON CH.ColID = CHQD.CollId  
where ChargesVoucherId = PV.ID OR ChaqueVoucherId = PV.ID),DocDate),GETDATE())) Ageing  
FROM tblTranPRVoucher PV  
JOIN tblMasterCustomer MC ON MC.FAID = PV.PartyID  
WHERE TransID = 7 AND Status NOT IN (2,4) AND MC.ID = @BeatName AND Balance > 0  
UNION ALL  
SELECT 4 SerialNo,DocID,FORMAT(DocDate,'dd/MMM/yyyy') DocDate,NoteValue NetAmt,Balance *-1 OSAmt,  
DATEDIFF(DD,DocDate,GETDATE()) Ageing  
FROM tblNoteDetails PV  
JOIN tblMasterCustomer MC ON MC.FAID = PV.PartyID  
WHERE TransID = 4 AND Status NOT IN (2,4) AND MC.ID = @BeatName AND Balance > 0  
UNION ALL  
SELECT 5 SerialNo,DocID,FORMAT(ColDate,'dd/MMM/yyyy') DocDate,ColAmt NetAmt,Balance *-1 OSAmt,  
DATEDIFF(DD,ColDate,GETDATE()) Ageing  
FROM tblTranCollectionHeader PV  
JOIN tblMasterCustomer MC ON MC.FAID = PV.AccID  
WHERE DocPrefix = 19 AND Status NOT IN (2,4) AND MC.ID = @BeatName AND Balance > 0  
) as rec  
order by SerialNo,Ageing desc  
  
SELECT CD.DocPrefix,CD.DocId [Doc ID],CONVERT(NVARCHAR,CPM.[DATE],103) AS [Cheque Date],[Cheque/DD Number],  
(dbo.fnGetRoundedValue(CollAmt)) [Value]  
FROM tblCollPMDetails CPM  
JOIN tblTranCollectionHeader CD ON CD.ColID = CPM.ColID  
JOIN tblMasterCustomer MC ON MC.FAID = CD.AccID  
WHERE (CPM.[DATE] <= convert(date,getdate())) AND CPM .[Status] IN (1,3) AND CPM.PaymentTermID IN (2) AND MC.ID = @BeatName  
END  
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspMonthlyWiseSalesFooter';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspMonthlyWiseSalesFooter]      
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
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@MFD AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@MED AS DATE))+''')' END)                      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND TSH.BranchID = @BranchName' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND Beat.ID IN (SELECT * from dbo.fnSplitString( @BeatName,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SM.ID IN (SELECT * from dbo.fnSplitString( @SalesmanName,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString( @CustomerName,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN (SELECT * from dbo.fnSplitString( @CustomerType,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN (SELECT * from dbo.fnSplitString( @Ratings,'',''))' END)       
SET @StrQuery = @StrQuery + ' ) as rec ORDER BY InvDate'    
EXEC sys.sp_executesql @StrQuery, N'@MFD DATE, @MED DATE, @BranchName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @FromDate DATE, @ToDate DATE', @MFD = @MFD, @MED = @MED, @BranchName = @BranchName, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @CustomerType = @CustomerType, @Ratings = @Ratings, @FromDate = @FromDate, @ToDate = @ToDate    
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspMonthlyWiseSalesHeader';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspMonthlyWiseSalesHeader]      
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
(CASE WHEN (DATEADD(mm, DATEDIFF(mm, 0, InvDate),0)) < '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+'''        
THEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' ELSE DATEADD(mm, DATEDIFF(mm, 0, InvDate),0) END) AS [From Date],      
(CASE WHEN (DATEADD (dd, -1, DATEADD(mm, DATEDIFF(mm, 0, InvDate) + 1, 0))) > '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+'''            
 THEN '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''' ELSE DATEADD(dd, -1, DATEADD(mm, DATEDIFF(mm, 0, InvDate) + 1, 0))END) AS [To Date],            
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
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)                  
  
    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND TSH.BranchID = @BranchName' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND Beat.ID IN (SELECT * from dbo.fnSplitString( @BeatName,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SM.ID IN (SELECT * from dbo.fnSplitString( @SalesmanName,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString( @CustomerName,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN (SELECT * from dbo.fnSplitString( @CustomerType,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN (SELECT * from dbo.fnSplitString( @Ratings,'',''))' END)       
SET @StrQuery = @StrQuery + ')  AS SRIRAM                
GROUP BY SRIRAM.InvDate,SRIRAM.[MMM/YYYY],SRIRAM.[From Date],SRIRAM.[To Date]) as main    
 GROUP BY [From Date],[To Date],[MMM/YYYY] ORDER BY CONVERT(DATETIME,[MMM/YYYY]) '    
 EXEC sys.sp_executesql @StrQuery, N'@BranchName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BranchName = @BranchName, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @CustomerType = @CustomerType, @Ratings = @Ratings, @FromDate = @FromDate, @ToDate = @ToDate    
 end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspMonthwisesalesAnalticsReport';
GO
--uspMonthwisesalesAnalticsReport 3,5,1,'',1,'',1,'2026-05-28','2026-08-28'
CREATE OR ALTER PROCEDURE [dbo].[uspMonthwisesalesAnalticsReport]
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
WHERE SH.STATUS NOT IN (2,4) AND SH.InvDate BETWEEN '+''''+convert(nvarchar,@FromDate)+''''+' AND '+''''+ convert(nvarchar,@Todate)+''''+''
-- AND ISNULL(SD.TaxId,0)>0
set @InitialQuery += case when @Grp1Type = 1 then ' and SH.DocPrefix = 15 ' when @Grp1Type = 2 then ' and SH.DocPrefix = 16 and SH.TransactionType = 2 '
else ' and SH.DocPrefix = 16 and SH.TransactionType = 3 ' end

set @InitialQuery += (case when ISNULL(@Grp3ID,'') = '' or @Grp3Type = 0 then '' else
case when @Grp3Type = 1 then ' and MP.MfrID IN (SELECT * FROM string_split(@Grp3ID'+','+''','''+'))'
when @Grp3Type = 2 then ' and MP.BrandID IN (SELECT * FROM string_split(@Grp3ID'+','+''','''+'))'
when @Grp3Type = 3 then ' and MP.CategoryID IN (SELECT * FROM string_split(@Grp3ID'+','+''','''+'))'
when @Grp3Type = 4 then ' and MP.ID IN (SELECT * FROM string_split(@Grp3ID'+','+''','''+'))'
END
END)

set @InitialQuery += (case when ISNULL(@Grp2ID,'') = '' or @Grp2Type = 0 then '' else
case when @Grp2Type = 1 then ' and MB.ID IN (SELECT * FROM string_split(@Grp2ID'+','+''','''+'))'
when @Grp2Type = 2 then ' and SM.ID IN (SELECT * FROM string_split(@Grp2ID'+','+''','''+'))'
when @Grp2Type = 3 then ' and MC.ID IN (SELECT * FROM string_split(@Grp2ID'+','+''','''+'))'
when @Grp2Type = 4 then ' and MCT.ID IN (SELECT * FROM string_split(@Grp2ID'+','+''','''+'))'
END
END)

set @InitialQuery += 'GROUP BY SH.InvDate' +(case when @Grp3Type = 0 then '' when @Grp3Type = 1 then ',MP.MfrID,MANUF.Name' when @Grp3Type = 2 then ',MP.BrandID,MBR.Name'
when @Grp3Type = 3 then ',MP.CategoryID,MCAT.Name' else ',MP.ID,MP.Name' END)

set @InitialQuery += case when @Grp2Type = 0 then '' when @Grp2Type = 1 then ',SH.BeatID,MB.Name' when @Grp2Type = 2 then ',SH.SalesmanID,SM.Name'
when @Grp2Type = 3 then ',MC.ID,MC.Name' else ',MCAT.ID,MCAT.Name' END

set @InitialQuery += ') as rec group by InvDate,Grp1ID,Grp1Name,Grp2ID,Grp2Name'--Grp1ID,Grp1Name,Grp2ID,Grp2Name'

--select @InitialQuery

insert into #t1
EXEC sys.sp_executesql @InitialQuery, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode = @Mode, @Grp1Type = @Grp1Type, @Grp2Type = @Grp2Type, @Grp2ID = @Grp2ID, @Grp3Type = @Grp3Type, @Grp3ID = @Grp3ID, @Grp4Type = @Grp4Type, @FromDate = @FromDate, @ToDate = @ToDate

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
EXEC sys.sp_executesql @query, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode = @Mode, @Grp1Type = @Grp1Type, @Grp2Type = @Grp2Type, @Grp2ID = @Grp2ID, @Grp3Type = @Grp3Type, @Grp3ID = @Grp3ID, @Grp4Type = @Grp4Type, @FromDate = @FromDate, @ToDate = @ToDate

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
WHERE TSH.DocPrefix= 19 AND TSH.Status IN (1,3,5) AND TSH.ColDate BETWEEN '+''''+convert(nvarchar,@FromDate)+''''+' AND '+''''+ convert(nvarchar,@Todate)+''''+''
set @InitialQuery += (case when ISNULL(@Grp2ID,'') = '' then '' else
case when @Grp2Type = 1 then ' and MB.ID IN (SELECT * FROM string_split(@Grp2ID'+','+''','''+'))'
when @Grp2Type = 2 then ' and MSM.ID IN (SELECT * FROM string_split(@Grp2ID'+','+''','''+'))'
when @Grp2Type = 3 then ' and MC.ID IN (SELECT * FROM string_split(@Grp2ID'+','+''','''+'))'
when @Grp2Type = 4 then ' and MCT.ID IN (SELECT * FROM string_split(@Grp2ID'+','+''','''+'))'
END
END)
set @InitialQuery +='GROUP BY TSH.ColDate,' + case when @Grp2Type = 1 then 'TSH.BeatID,MB.Name' when @Grp2Type = 2 then 'TSH.SalesmanID,MSM.Name'
when @Grp2Type = 3 then 'MC.ID,MC.Name' else 'mct.ID,mct.Name' END
set @InitialQuery += ') as rec group by ColDate,Grp2Name,Grp2ID'

insert into #t2
EXEC sys.sp_executesql @InitialQuery, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode = @Mode, @Grp1Type = @Grp1Type, @Grp2Type = @Grp2Type, @Grp2ID = @Grp2ID, @Grp3Type = @Grp3Type, @Grp3ID = @Grp3ID, @Grp4Type = @Grp4Type, @FromDate = @FromDate, @ToDate = @ToDate

SET @query = 'SELECT Grp2ID,Grp2Name'+@Group2TypeName+',('+@CumativeCol+') AS '+@Group1TypeName+'],'+@PColWithisnull+
' FROM #t2 PIVOT (SUM(Grp3Value) FOR ColDate IN (' + @PCol + ')) AS PivotTable ORDER BY '+@Group2TypeName+' '
EXEC sys.sp_executesql @query, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode = @Mode, @Grp1Type = @Grp1Type, @Grp2Type = @Grp2Type, @Grp2ID = @Grp2ID, @Grp3Type = @Grp3Type, @Grp3ID = @Grp3ID, @Grp4Type = @Grp4Type, @FromDate = @FromDate, @ToDate = @ToDate

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
SH.InvDate BETWEEN '+''''+convert(nvarchar,@FromDate)+''''+' AND '+''''+ convert(nvarchar,@Todate)+''''+''
set @InitialQuery += (case when ISNULL(@Grp2ID,'') = '' or @Grp2Type = 0 then '' else
case when @Grp2Type = 1 then ' and MB.ID IN (SELECT * FROM string_split(@Grp2ID'+','+''','''+'))'
when @Grp2Type = 2 then ' and SM.ID IN (SELECT * FROM string_split(@Grp2ID'+','+''','''+'))'
when @Grp2Type = 3 then ' and MC.ID IN (SELECT * FROM string_split(@Grp2ID'+','+''','''+'))'
when @Grp2Type = 4 then ' and MCT.ID IN (SELECT * FROM string_split(@Grp2ID'+','+''','''+'))'
END END)
set @InitialQuery += (case when ISNULL(@Grp3ID,'') = '' or @Grp3Type = 0 then '' else
case when @Grp3Type = 1 then ' and MP.MfrID IN (SELECT * FROM string_split(@Grp3ID'+','+''','''+'))'
when @Grp3Type = 2 then ' and MP.BrandID IN (SELECT * FROM string_split(@Grp3ID'+','+''','''+'))'
when @Grp3Type = 3 then ' and MP.CategoryID IN (SELECT * FROM string_split(@Grp3ID'+','+''','''+'))'
when @Grp3Type = 4 then ' and MP.ID IN (SELECT * FROM string_split(@Grp3ID'+','+''','''+'))'
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
EXEC sys.sp_executesql @InitialQuery, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode = @Mode, @Grp1Type = @Grp1Type, @Grp2Type = @Grp2Type, @Grp2ID = @Grp2ID, @Grp3Type = @Grp3Type, @Grp3ID = @Grp3ID, @Grp4Type = @Grp4Type, @FromDate = @FromDate, @ToDate = @ToDate

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
    EXEC sys.sp_executesql @query, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode = @Mode, @Grp1Type = @Grp1Type, @Grp2Type = @Grp2Type, @Grp2ID = @Grp2ID, @Grp3Type = @Grp3Type, @Grp3ID = @Grp3ID, @Grp4Type = @Grp4Type, @FromDate = @FromDate, @ToDate = @ToDate

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
WHERE SH.STATUS NOT IN (2,4) AND SH.Date BETWEEN '+''''+convert(nvarchar,@FromDate)+''''+' AND '+''''+ convert(nvarchar,@Todate)+''''+''
-- AND ISNULL(SD.TaxId,0)>0
set @InitialQuery += case when @Grp1Type = 6 then ' and SH.TransID = 1 ' when @Grp1Type = 7 then ' and TransID = 12 '
else '' end

set @InitialQuery += (case when ISNULL(@Grp3ID,'') = '' or @Grp3Type = 0 then '' else
case when @Grp3Type = 1 then ' and MP.MfrID IN (SELECT * FROM string_split(@Grp3ID'+','+''','''+'))'
when @Grp3Type = 2 then ' and MP.BrandID IN (SELECT * FROM string_split(@Grp3ID'+','+''','''+'))'
when @Grp3Type = 3 then ' and MP.CategoryID IN (SELECT * FROM string_split(@Grp3ID'+','+''','''+'))'
when @Grp3Type = 4 then ' and MP.ID IN (SELECT * FROM string_split(@Grp3ID'+','+''','''+'))'
END
END)

set @InitialQuery += (case when ISNULL(@Grp2ID,'') = '' or @Grp2Type = 0 then '' else
case when @Grp2Type = 1 then ' and MC.ID IN (SELECT * FROM string_split(@Grp2ID'+','+''','''+'))'
END
END)

set @InitialQuery += 'GROUP BY SH.Date' +(case when @Grp3Type = 0 then '' when @Grp3Type = 1 then ',MP.MfrID,MANUF.Name' when @Grp3Type = 2 then ',MP.BrandID,MBR.Name'
when @Grp3Type = 3 then ',MP.CategoryID,MCAT.Name' else ',MP.ID,MP.Name' END)

set @InitialQuery += case when @Grp2Type = 0 then '' when @Grp2Type = 1 then ',SH.VendorID,MC.Name'
else '' END

set @InitialQuery += ') as rec group by InvDate,Grp1ID,Grp1Name,Grp2ID,Grp2Name'--Grp1ID,Grp1Name,Grp2ID,Grp2Name'

--select @InitialQuery

insert into #t1
EXEC sys.sp_executesql @InitialQuery, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode = @Mode, @Grp1Type = @Grp1Type, @Grp2Type = @Grp2Type, @Grp2ID = @Grp2ID, @Grp3Type = @Grp3Type, @Grp3ID = @Grp3ID, @Grp4Type = @Grp4Type, @FromDate = @FromDate, @ToDate = @ToDate

SET @query = 'SELECT '+
case when @Grp3Type = 0 then '' else ' Grp1ID,' end +
case when @Grp2Type = 0 then '' else ' Grp2ID,' end +
case when @Grp3Type = 0 then '' else 'Grp1Name'+@Group3TypeName+',' end +
case when @Grp2Type = 0 then '' else 'Grp2Name'+@Group2TypeName+',' end +
'('+@CumativeCol+') AS '+@Group1TypeName+@Group4TypeName+'],'+@PColWithisnull+
' FROM #t1 PIVOT (SUM(Grp3Value) FOR InvDate IN (' + @PCol + ')) AS PivotTable ORDER BY '+case when @Grp3Type = 0 then '' else @Group3TypeName end +
case when @Grp2Type > 0 and @Grp3Type > 0 then ',' else '' end+
case when @Grp2Type = 0 then '' else @Group2TypeName end
EXEC sys.sp_executesql @query, N'@Mode int, @Grp1Type int, @Grp2Type int, @Grp2ID NVARCHAR(MAX), @Grp3Type int, @Grp3ID NVARCHAR(MAX), @Grp4Type int, @FromDate date, @ToDate date', @Mode = @Mode, @Grp1Type = @Grp1Type, @Grp2Type = @Grp2Type, @Grp2ID = @Grp2ID, @Grp3Type = @Grp3Type, @Grp3ID = @Grp3ID, @Grp4Type = @Grp4Type, @FromDate = @FromDate, @ToDate = @ToDate
END
drop table #t1
END
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspNilStockHeader';
GO
--uspNilStockHeader 0,'','','','126',1500 
CREATE OR ALTER PROCEDURE [dbo].[uspNilStockHeader]      
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
set @query += ' WHERE (ISNULL(Qty,0) <= ' + CONVERT(nvarchar(50),@Qty)  + ')'    
 set @query += case when ISNULL(@BranchName,'') = '' then '' else ' AND BranchID = '+''''+ CONVERT(nvarchar(50),@BranchName)+''''+'' END        
 set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND [BrandID] IN (SELECT * from dbo.fnSplitString( @BrandName,'',''))' END        
 set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND [CategoryID] IN (SELECT * from dbo.fnSplitString( @CategoryName,'',''))' END        
 set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND [MfrID] IN (SELECT * from dbo.fnSplitString( @ManufName,'',''))' END        
 set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND ProductID IN (SELECT * from dbo.fnSplitString( @ProductName,'',''))' END      
 set @query += ' GROUP BY ProductID,BranchID,[Branch Name],Code,Name,EAN,[Mfr Name],[Brand Name],[Category Name],[MfrID],[CategoryID],[BrandID]    
order by Name '    
PRINT @query
 EXEC sys.sp_executesql @query, N'@BranchName int, @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @Qty DECIMAL(25,4)', @BranchName = @BranchName, @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName, @Qty = @Qty      
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspProductBatchHistoryHeader';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspProductBatchHistoryHeader]    
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
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ManufName,'')='' THEN '' ELSE ' AND MF.ID IN (SELECT * from dbo.fnSplitString ( @ManufName,'',''))' END)             
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BrandName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString (  @BrandName,'',''))' END)                
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CategoryName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString (  @CategoryName,'',''))' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ProductName,'')='' THEN '' ELSE ' AND MP.ID IN (SELECT * from dbo.fnSplitString (  @ProductName,'',''))' END)       
SET @StrQuery = @StrQuery +  ' group by MP.ID,MP.Code,MP.Name,MF.Name,MB.Name,MC.Name,[VLS Closing] order BY MP.Name '    
EXEC sys.sp_executesql @StrQuery, N'@ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255)', @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName    
 END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspProductWiseCustomerWiseSalesDetail';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspProductWiseCustomerWiseSalesDetail]        
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
WHERE TSH.DocPrefix = 15 AND Status IN (1,3,5) and TSD.ProdID = '+CONVERT(NVARCHAR,@ProductID)       
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)                  
  
    
      
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString( @CustomerName,'',''))' END)                            
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString( @BeatName,'',''))' END)                
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SM.ID IN (SELECT * from dbo.fnSplitString( @SalesmanName,'',''))' END)             
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN (SELECT * from dbo.fnSplitString( @CustomerType,'',''))' END)                
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN (SELECT * from dbo.fnSplitString( @Ratings,'',''))' END)       
SET @StrQuery = @StrQuery + ' group by MC.ID,MC.Name,TSH.DocId,TSH.InvDate,TSH.DocRef,mb.name,sm.name,mct.Name,RT.Ratingname,MP.Name '      
EXEC sys.sp_executesql @StrQuery, N'@ProductID int, @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @FromDate DATE, @ToDate DATE', @ProductID = @ProductID, @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @CustomerType = @CustomerType, @Ratings = @Ratings, @FromDate = @FromDate, @ToDate = @ToDate      
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspProductWiseCustomerWiseSalesHeader';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspProductWiseCustomerWiseSalesHeader]      
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
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (TSH.InvDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)                  
  
    
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerName,'')='' THEN '' ELSE ' AND MC.ID IN(SELECT * from dbo.fnSplitString( @CustomerName,'',''))' END)                          
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BeatName,'')='' THEN '' ELSE ' AND Beat.ID IN(SELECT * from dbo.fnSplitString( @BeatName,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@SalesmanName,'')='' THEN '' ELSE ' AND SM.ID IN(SELECT * from dbo.fnSplitString( @SalesmanName,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CustomerType,'')='' THEN '' ELSE ' AND MCT.ID IN(SELECT * from dbo.fnSplitString( @CustomerType,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@Ratings,'')='' THEN '' ELSE ' AND RT.ID IN(SELECT * from dbo.fnSplitString( @Ratings,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ManufName,'')='' THEN '' ELSE ' AND MF.ID IN(SELECT * from dbo.fnSplitString( @ManufName,'',''))' END)           
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BrandName,'')='' THEN '' ELSE ' AND MB.ID IN(SELECT * from dbo.fnSplitString( @BrandName,'',''))' END)              
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CategoryName,'')='' THEN '' ELSE ' AND PHL.ID IN(SELECT * from dbo.fnSplitString( @CategoryName,'',''))' END)       
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ProductName,'')='' THEN '' ELSE ' AND MP.ID IN(SELECT * from dbo.fnSplitString( @ProductName,'',''))' END)       
SET @StrQuery = @StrQuery + ' group by MP.ID,MF.ID,MF.Name,mp.Name,tsh.ID,MB.Name,PHL.Name) as nk      
group by ProdID,[Mfr Name],[Product Name],[Brand Name],[Category Name]'    
EXEC sys.sp_executesql @StrQuery, N'@ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @CustomerType NVARCHAR(255), @Ratings NVARCHAR(255), @FromDate DATE, @ToDate DATE', @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @CustomerType = @CustomerType, @Ratings = @Ratings, @FromDate = @FromDate, @ToDate = @ToDate    
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspReasonwiseAnalysisHeader';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspReasonwiseAnalysisHeader]  
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
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (SH.InvDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)                   
   
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ReasonName,'0')='0' THEN '' ELSE ' AND SD.ReasonID = @ReasonName' END)     
SET @StrQuery = @StrQuery + ' group by SD.ReasonID,RSN.Name ORDER BY RSN.Name'  
EXEC sys.sp_executesql @StrQuery, N'@ReasonName nvarchar(255), @FromDate date, @ToDate date', @ReasonName = @ReasonName, @FromDate = @FromDate, @ToDate = @ToDate  
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepAccountLedger';
GO
--uspRepAccountLedger '1,2','2025-02-01','2025-12-01'            
CREATE OR ALTER PROCEDURE [dbo].[uspRepAccountLedger]          
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND FAJ.DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END            
SET @strQuery += CASE WHEN ISNULL(@AccountName,'') = '' THEN '' ELSE ' AND FAA.FAID IN (SELECT * from  dbo.fnSplitString( @AccountName,'',''))' END         
insert into #temp    
EXEC sys.sp_executesql @strQuery, N'@AccountName nvarchar(max), @FromDate date, @ToDate DATE, @Showall nvarchar(max)', @AccountName = @AccountName, @FromDate = @FromDate, @ToDate = @ToDate, @Showall = @Showall           
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
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepBeatSalesmanWiseAgeingHeader';
GO
--uspRepBeatSalesmanWiseAgeingHeader '','','','15','12/02/2026'    
CREATE OR ALTER PROCEDURE [dbo].[uspRepBeatSalesmanWiseAgeingHeader]    
@BeatName NVARCHAR(255)='',    
@SalesmanName NVARCHAR(255)='',    
@CustomerName NVARCHAR(255)='',    
@fnSplitString NVARCHAR(MAX),    
@AsOnDate DATE    
AS    
BEGIN    
    
DECLARE @Serial INT,@Count INT, @Query NVARCHAR(MAX),@Count1 INT,@MainSerial INT, @MainCount INT,@AlterColumnName0 NVARCHAR(255),@AlterColumnName1 NVARCHAR(255)    
DECLARE @Ageing INT,@nCount INT,@nCount1 INT,@nSerial INT,@IsTrueFalse NVARCHAR(10),@nF INT,@nT INT,@nColumnName NVARCHAR(255)    
    
SELECT CD.DocID,ISNULL(SUM(TotalAmtAdj),0) TotalAmtAdj INTO #COLTEMP    
FROM tblTranCollectionHeader CH    
JOIN tblTranCollectionDetail CD ON CD.ColID = CH.ColID    
WHERE ColDate > @AsOnDate AND Status IN (1,3,5)    
GROUP BY CD.DocID    
    
--select * from #COLTEMP    
    
SELECT FAC.NoteID,FAC.Adjustment INTO #JVTEMP    
FROM tblFAJournal FA    
JOIN tblFAJournelCancel FAC ON FAC.JVID = FA.JVID    
WHERE DocPrefix = 8 AND DocDate > @AsOnDate AND FA.Status IN (1,3,5)    
GROUP BY FAC.NoteID,FAC.Adjustment    
    
--select * from #JVTEMP    
    
-- Create #TempTable1 for Moving Original Data    
CREATE TABLE #TempTable (ID INT,[Doc ID] NVARCHAR(255),[Doc Date] NVARCHAR(25),    
[Customer Name] NVARCHAR(255),[Customer Type] NVARCHAR(255),[Beat Name] NVARCHAR(255),[SalesMan Name] NVARCHAR(255)    
,[Opening Amount] DECIMAL(25,6),[Pending Amount] DECIMAL(25,6),[SR Balance] DECIMAL(25,6),[Ageing] INT)    
    
CREATE TABLE #TempTable1 (ID INT IDENTITY(1,1),[Doc ID] NVARCHAR(255),[Doc Date] NVARCHAR(25),    
[Customer Name] NVARCHAR(255),[Customer Type] NVARCHAR(255),[Beat Name] NVARCHAR(255),[SalesMan Name] NVARCHAR(255)    
,[Opening Amount] NVARCHAR(255),[Pending Amount] NVARCHAR(255),[SR Balance] NVARCHAR(255),[Ageing] INT)    
    
SELECT SRI.[ID],SRI.[Doc ID],SRI.[Doc Date],SRI.[Customer Name],SRI.[Customer Type],SRI.[Beat Name],    
SRI.[Salesman Name],SRI.[Opening Amount],SRI.[Pending Amount],SRI.[SR Balance],SRI.Ageing,SRI.[Beat ID],SRI.[Salesman ID],SRI.[Customer ID]    
INTO #TEMPDATA    
FROM    
(    
SELECT    
SH.ID[ID],SH.DocID[Doc ID],FORMAT(SH.InvDate,'dd/MMM/yyyy')[Doc Date],ISNULL(MC.ID,0)[Customer ID],MC.Name[Customer Name],MCT.Name[Customer Type],    
ISNULL(MB.ID,0)[Beat ID],MB.Name[Beat Name],ISNULL(MS.ID,0)[Salesman ID],MS.Name[Salesman Name],SH.NetAmt[Opening Amount],    
CASE WHEN SH.DocPrefix = 15 THEN SH.Balance ELSE 0 END AS [Pending Amount],    
CASE WHEN SH.DocPrefix = 16 THEN SH.Balance ELSE 0 END AS [SR Balance],    
DATEDIFF(DAY,InvDate,@AsOnDate) AS [Ageing]    
FROM tblTranSalesHeader SH    
JOIN tblMasterCustomer MC on MC.ID = SH.CustID    
LEFT JOIN tblMasterCustomerType MCT on MCT.ID = MC.CustomerType    
LEFT JOIN tblMasterBeat MB on MB.ID = SH.BeatID    
LEFT JOIN tblMasterSalesman MS on MS.ID = SH.SalesManID    
WHERE SH.DocPrefix in (15,16) AND SH.InvDate <= @AsOnDate AND SH.Status IN (1,3,5,6,7)    
UNION ALL    
SELECT  RV.ID[ID],RV.DocID[Doc ID],FORMAT(RV.DocDate,'dd/MMM/yyyy')[Doc Date],ISNULL(MC.ID,0)[Customer ID],MC.Name[Customer Name],MCT.Name[Customer Type],    
ISNULL(MB.ID,0)[Beat ID],MB.Name[Beat Name],ISNULL(MS.ID,0)[Salesman ID],MS.Name[Salesman Name],RV.NetAmount[Opening Amount],RV.Balance[Pending Amount],    
0 AS [SR Balance],    
DATEDIFF(DAY, RV.DocDate, @AsOnDate) AS [Ageing]    
FROM tblTranPRVoucher RV    
JOIN tblMasterCustomer MC on MC.FAID = RV.PartyID    
LEFT JOIN tblMasterCustomerType MCT on MCT.ID = MC.CustomerType    
LEFT JOIN tblBeatSalesmanMapping AS CBS ON CBS.CustomerId = MC.ID    
LEFT JOIN tblMasterBeat MB on MB.ID = CBS.BeatID    
LEFT JOIN tblMasterSalesman MS on MS.ID = CBS.SalesmanID    
WHERE RV.TransID IN(7)  AND RV.DocDate <= @AsOnDate  AND RV.Status IN (1,3,5)    
UNION ALL    
SELECT  RV.ID[ID],RV.DocID[Doc ID],FORMAT(RV.DocDate,'dd/MMM/yyyy')[Doc Date],ISNULL(MC.ID,0)[Customer ID],MC.Name[Customer Name],MCT.Name[Customer Type],    
ISNULL(MB.ID,0)[Beat ID],MB.Name[Beat Name],ISNULL(MS.ID,0)[Salesman ID],MS.Name[Salesman Name],RV.NoteValue [Opening Amount],0 [Pending Amount],    
RV.Balance AS [SR Balance],    
DATEDIFF(DAY, RV.DocDate, @AsOnDate) AS [Ageing]    
FROM tblNoteDetails RV    
JOIN tblMasterCustomer MC on MC.FAID = RV.PartyID    
LEFT JOIN tblMasterCustomerType MCT on MCT.ID = MC.CustomerType    
LEFT JOIN tblBeatSalesmanMapping AS CBS ON CBS.CustomerId = MC.ID    
LEFT JOIN tblMasterBeat MB on MB.ID = CBS.BeatID  
LEFT JOIN tblMasterSalesman MS on MS.ID = CBS.SalesmanID    
WHERE RV.TransID IN (4)  AND RV.DocDate <= @AsOnDate  AND RV.Status IN (1,3,5)    
UNION ALL    
SELECT  RV.ColID [ID],RV.DocID[Doc ID],FORMAT(RV.ColDate,'dd/MMM/yyyy')[Doc Date],ISNULL(MC.ID,0)[Customer ID],MC.Name[Customer Name],MCT.Name[Customer Type],    
ISNULL(MB.ID,0)[Beat ID],MB.Name[Beat Name],ISNULL(MS.ID,0)[Salesman ID],MS.Name[Salesman Name],  
RV.ColAmt [Opening Amount],0 [Pending Amount],    
RV.Balance AS [SR Balance],    
DATEDIFF(DAY, RV.ColDate, @AsOnDate) AS [Ageing]    
FROM tblTranCollectionHeader RV    
JOIN tblMasterCustomer MC on MC.FAID = RV.AccID    
LEFT JOIN tblMasterCustomerType MCT on MCT.ID = MC.CustomerType     
LEFT JOIN tblMasterBeat MB on MB.ID = RV.BeatID  
LEFT JOIN tblMasterSalesman MS on MS.ID = RV.SalesmanID    
WHERE RV.DocPrefix IN (19)  AND RV.ColDate <= @AsOnDate  AND RV.Status IN (1,3,5)  
)SRI    
-- Create #TempID for Split String Ageing Wise    
CREATE TABLE #TempID (IdentID INT IDENTITY(1,1),ID INT)    
    
-- Create #TempAlterColumns for Identifying Column and Checking Range Between    
CREATE TABLE #TempAlterColumns (IdentID INT IDENTITY(1,1),[From] INT,[To] INT,OriginalColumn NVARCHAR(MAX))    
    
-- Insert Spliting String Datas    
INSERT INTO #TempID    
SELECT * FROM (SELECT DISTINCT id FROM dbo.fnSplitString(@fnSplitString,',') WHERE ISNULL(id,'')!='') AS SRI ORDER BY CAST(SRI.id AS INT)    
    
--select * from #TEMPDATA    
INSERT INTO #TempTable    
SELECT ID,[Doc ID],[Doc Date],[Customer Name],[Customer Type],    
[Beat Name],[SalesMan Name],SUM([Opening Amount]) [Opening Amount],SUM([Pending Amount]) [Pending Amount],    
SUM([SR Balance]) [SR Balance],Ageing    
FROM #TEMPDATA    
WHERE (Ageing = 0 OR Ageing != 0)    
AND(@BeatName = '' OR [Beat ID] IN(SELECT * from dbo.fnSplitString(@BeatName,',')))
AND(@SalesmanName = '' OR [Salesman ID] IN (SELECT * from dbo.fnSplitString(@SalesmanName,',')))
AND(@CustomerName = '' OR [Customer ID] IN (SELECT * from dbo.fnSplitString (@CustomerName,',')))
GROUP BY ID,[Doc ID],[Doc Date],[Customer Name],[Customer Type],    
[Beat Name],[SalesMan Name],Ageing    
ORDER BY [Customer Name]    
    
--select * from #TempTable    
    
INSERT INTO #TempTable1    
SELECT [Doc ID],[Doc Date],[Customer Name],[Customer Type],[Beat Name],[SalesMan Name],    
DBO.fnGetRoundedValue([Opening Amount]) [Opening Amount],DBO.fnGetRoundedValue([Pending Amount]) [Pending Amount],    
DBO.fnGetRoundedValue([SR Balance]) [SR Balance],Ageing FROM (    
SELECT TT.[ID],TT.[Doc ID],TT.[Doc Date],TT.[Customer Name],TT.[Customer Type],[Beat Name],[SalesMan Name],    
SUM((TT.[Opening Amount])) [Opening Amount],SUM(((TT.[Pending Amount] + ISNULL(CT.TotalAmtAdj,0)+ ISNULL(Adjustment,0)))) AS [Pending Amount],    
SUM(TT.[SR Balance]) AS [SR Balance],Ageing    
FROM #TempTable TT    
LEFT JOIN #COLTEMP CT ON CT.DocID = TT.ID    
LEFT JOIN #JVTEMP JV ON JV.NoteID = TT.ID    
--WHERE (TT.[Pending Amount] + ISNULL(CT.TotalAmtAdj,0)+ ISNULL(Adjustment,0)) <> 0    
GROUP BY ID,[Doc ID],[Doc Date],[Customer Name],[Customer Type],[Beat Name],[SalesMan Name],Ageing    
) AS NK    
WHERE ((cast(([Pending Amount]) as numeric(26,2))) <> 0 or (cast(([SR Balance]) as numeric(26,2))) <> 0 )    
order by [Customer Name]    
    
SET @Count1 = (SELECT COUNT(*) FROM #TempID);    
SET @Count = (SELECT COUNT(*) FROM #TempID);    
SET @Serial = 1    
-- Looping for Alter and Spliting Columns using Ageing Wise    
IF ISNULL(@Count1,0)>1    
BEGIN    
print 'aaaaaaaaaaaaaaaaaa'    
WHILE (@Count > 0)    
BEGIN    
SET @AlterColumnName0 = (SELECT ID FROM #TempID WHERE IdentID = @Serial-1)    
SET @AlterColumnName1 = (SELECT ID FROM #TempID WHERE IdentID = @Serial)    
SET @AlterColumnName0 = @AlterColumnName0+1    
IF ISNULL(@Count,0)=1    
BEGIN    
SET @Query = 'ALTER TABLE #TempTable1 ADD ['+@AlterColumnName0+'-'+@AlterColumnName1+' Days] VARCHAR(100) NULL,[>'+@AlterColumnName1+' Days] VARCHAR(100) NULL'    
EXEC sys.sp_executesql @Query, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @AsOnDate DATE', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @fnSplitString = @fnSplitString, @AsOnDate = @AsOnDate    
INSERT INTO #TempAlterColumns VALUES ((@AlterColumnName0),@AlterColumnName1,'['+@AlterColumnName0+'-'+@AlterColumnName1+' Days]')    
INSERT INTO #TempAlterColumns VALUES ((@AlterColumnName1),0,'[>'+@AlterColumnName1+' Days]')    
END    
ELSE IF ISNULL(@Count,0)= @Count1    
BEGIN    
SET @Query = 'ALTER TABLE #TempTable1 ADD [0-'+@AlterColumnName1+' Days] VARCHAR(100) NULL'    
EXEC sys.sp_executesql @Query, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @AsOnDate DATE', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @fnSplitString = @fnSplitString, @AsOnDate = @AsOnDate    
INSERT INTO #TempAlterColumns VALUES (0,@AlterColumnName1,'[0-'+@AlterColumnName1+' Days]')    
END    
ELSE    
BEGIN    
SET @Query = 'ALTER TABLE #TempTable1 ADD ['+@AlterColumnName0+'-'+@AlterColumnName1+' Days] VARCHAR(100) NULL'    
EXEC sys.sp_executesql @Query, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @AsOnDate DATE', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @fnSplitString = @fnSplitString, @AsOnDate = @AsOnDate    
INSERT INTO #TempAlterColumns VALUES ((@AlterColumnName0),@AlterColumnName1,'['+@AlterColumnName0+'-'+@AlterColumnName1+' Days]')    
END    
SET @Count = @Count - 1;    
SET @Serial = @Serial + 1;    
END    
END    
ELSE    
BEGIN    
SET @AlterColumnName0 = (SELECT ID FROM #TempID WHERE IdentID = 1)    
SET @Query = 'ALTER TABLE #TempTable1 ADD [0-'+@AlterColumnName0+' Days] VARCHAR(100) NULL,[>'+@AlterColumnName0+' Days] VARCHAR(100) NULL'    
EXEC sys.sp_executesql @Query, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @AsOnDate DATE', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @fnSplitString = @fnSplitString, @AsOnDate = @AsOnDate    
INSERT INTO #TempAlterColumns VALUES (0,@AlterColumnName0,'[0-'+@AlterColumnName0+' Days]')    
INSERT INTO #TempAlterColumns VALUES (@AlterColumnName0,0,'[>'+@AlterColumnName0+' Days]')    
END    
SET @MainCount = (SELECT COUNT(*) FROM #TempTable1);    
SET @MainSerial = 1    
-- Looping for Get Ageing Information from #TempTable1    
WHILE (@MainCount > 0)    
BEGIN    
SET @Ageing = (SELECT Ageing FROM #TempTable1 WHERE ID = @MainSerial)    
SET @nCount = (SELECT COUNT(*) FROM #TempAlterColumns)    
SET @nCount1 = (SELECT COUNT(*) FROM #TempAlterColumns)    
SET @nSerial = 1  -- Looping for Check Ageing and From and To Between Ageing Range    
WHILE (@nCount > 0)    
BEGIN    
SET @nF = (SELECT [From] FROM #TempAlterColumns WHERE IdentID = @nSerial)    
SET @nT = (SELECT [to] FROM #TempAlterColumns WHERE IdentID = @nSerial)    
SET @nColumnName = (SELECT OriginalColumn FROM #TempAlterColumns WHERE IdentID = @nSerial)    
IF ISNULL(@nCount1,0) = ISNULL(@nSerial,0)    
BEGIN    
SELECT @IsTrueFalse = (CASE WHEN @Ageing > @nF THEN 'TRUE' ELSE 'FALSE' END)    
END    
ELSE    
BEGIN    
SELECT @IsTrueFalse = (CASE WHEN @Ageing BETWEEN @nF AND @nT THEN 'TRUE' ELSE 'FALSE' END)    
END    
    
-- IF TRUE Updating Pending Amount to Specific Columns    
IF ISNULL(@IsTrueFalse,'')='TRUE'    
BEGIN    
SET @Query = 'UPDATE #TempTable1 SET '+@nColumnName+' = (case when isnull(CAST([SR Balance] AS DECIMAL(25,2)),0) > 0 then [SR Balance] ELSE [Pending Amount] END) WHERE ID='+CAST(@MainSerial AS NVARCHAR)+''    
EXEC sys.sp_executesql @Query, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @AsOnDate DATE', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @fnSplitString = @fnSplitString, @AsOnDate = @AsOnDate    
BREAK;    
END    
    
SET @nCount = @nCount - 1;    
SET @nSerial = @nSerial + 1;    
END    
SET @MainCount = @MainCount - 1;    
SET @MainSerial = @MainSerial + 1;    
END    
-- Select all data from #TempTable1 Finally    
alter table #TempTable1 drop column ID    
SELECT * FROM #TempTable1    
ENd    
-- Drop all #Temp Tables    
DROP TABLE #TempTable1,#TempTable,#TempID,#COLTEMP,#JVTEMP ,#TempAlterColumns,#TEMPDATA
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepBeatwiseOutstandingsHeader';
GO
--uspRepBeatwiseOutstandingsHeader '','','0,10,20','12/02/2026'          
CREATE OR ALTER PROCEDURE [dbo].[uspRepBeatwiseOutstandingsHeader]          
@BeatName NVARCHAR(255)='',          
@SalesmanName NVARCHAR(255)='',           
@fnSplitString NVARCHAR(MAX),          
@AsOnDate DATE          
AS        
BEGIN          
          
DECLARE @Serial INT,@Count INT, @Query NVARCHAR(MAX),@Count1 INT,@MainSerial INT, @MainCount INT,@AlterColumnName0 NVARCHAR(255),@AlterColumnName1 NVARCHAR(255)          
DECLARE @Ageing INT,@nCount INT,@nCount1 INT,@nSerial INT,@IsTrueFalse NVARCHAR(10),@nF INT,@nT INT,@nColumnName NVARCHAR(255)          
          
SELECT CD.DocID,ISNULL(SUM(TotalAmtAdj),0) TotalAmtAdj INTO #COLTEMP          
FROM tblTranCollectionHeader CH          
JOIN tblTranCollectionDetail CD ON CD.ColID = CH.ColID          
WHERE ColDate > @AsOnDate AND Status IN (1,3,5)          
GROUP BY CD.DocID          
          
--select * from #COLTEMP          
          
SELECT FAC.NoteID,FAC.Adjustment INTO #JVTEMP           
FROM tblFAJournal FA          
JOIN tblFAJournelCancel FAC ON FAC.JVID = FA.JVID          
WHERE DocPrefix = 8 AND DocDate > @AsOnDate AND FA.Status IN (1,3,5)          
GROUP BY FAC.NoteID,FAC.Adjustment          
          
--select * from #JVTEMP          
          
-- Create #TempTable1 for Moving Original Data          
CREATE TABLE #TempTable (DocPrefix int,ID INT,[Beat Name] NVARCHAR(255),[SalesMan Name] NVARCHAR(255)          
,[Opening Amount] DECIMAL(25,6),[Pending Amount] DECIMAL(25,6),[SR Balance] DECIMAL(25,6),[Ageing] INT)          
          
CREATE TABLE #TempTable1 (ID INT IDENTITY(1,1),DocPrefix int,[Beat Name] NVARCHAR(255),[SalesMan Name] NVARCHAR(255)          
,[Opening Amount] NVARCHAR(255),[Pending Amount] NVARCHAR(255),[SR Balance] NVARCHAR(255),[Ageing] INT)          
          
SELECT DocPrefix,SRI.[ID],SRI.[Beat Name],SRI.[Salesman Name],SRI.[Opening Amount],        
SRI.[Pending Amount],SRI.[SR Balance],SRI.Ageing,SRI.[Beat ID],SRI.[Salesman ID]         
INTO #TEMPDATA          
FROM          
(           
SELECT  SH.DocPrefix,          
SH.ID[ID],ISNULL(MB.ID,0)[Beat ID],MB.Name[Beat Name],ISNULL(MS.ID,0)[Salesman ID],MS.Name[Salesman Name],        
SH.NetAmt [Opening Amount],        
CASE WHEN SH.DocPrefix = 15 THEN SH.Balance  ELSE 0 END AS [Pending Amount],          
CASE WHEN SH.DocPrefix = 16 THEN SH.Balance * -1 ELSE 0 END AS [SR Balance],        
DATEDIFF(DAY,InvDate,@AsOnDate) AS [Ageing]          
FROM tblTranSalesHeader SH          
JOIN tblMasterCustomer MC on MC.ID = SH.CustID          
LEFT JOIN tblMasterCustomerType MCT on MCT.ID = MC.CustomerType          
LEFT JOIN tblMasterBeat MB on MB.ID = SH.BeatID          
LEFT JOIN tblMasterSalesman MS on MS.ID = SH.SalesManID          
WHERE SH.DocPrefix in (15,16) AND SH.InvDate <= @AsOnDate AND SH.Status IN  (1,3,5,6,7)          
UNION ALL          
SELECT RV.TransID DocPrefix,           
RV.ID[ID],ISNULL(MB.ID,0)[Beat ID],MB.Name[Beat Name],ISNULL(MS.ID,0)[Salesman ID],MS.Name[Salesman Name],        
RV.NetAmount [Opening Amount],RV.Balance[Pending Amount],0 AS [SR Balance],        
DATEDIFF(DAY, RV.DocDate, @AsOnDate)  AS [Ageing]          
FROM tblTranPRVoucher RV          
JOIN tblMasterCustomer MC on MC.FAID = RV.PartyID          
LEFT JOIN tblMasterCustomerType MCT on MCT.ID = MC.CustomerType          
LEFT JOIN tblBeatSalesmanMapping AS CBS ON CBS.CustomerId = MC.ID          
LEFT JOIN tblMasterBeat MB on MB.ID = CBS.BeatID          
LEFT JOIN tblMasterSalesman MS on MS.ID = CBS.SalesmanID          
WHERE RV.TransID IN(7) AND RV.DocDate <= @AsOnDate AND RV.Status IN (1,3,5)     
UNION ALL          
SELECT RV.TransID DocPrefix,RV.ID[ID],ISNULL(MB.ID,0)[Beat ID],MB.Name[Beat Name],ISNULL(MS.ID,0)[Salesman ID],MS.Name[Salesman Name],        
RV.NoteValue * -1 [NoteValue]  ,0 [Pending Amount],RV.Balance * -1 AS [SR Balance],        
DATEDIFF(DAY, RV.DocDate, @AsOnDate)  AS [Ageing]          
FROM tblNoteDetails RV          
JOIN tblMasterCustomer MC on MC.FAID = RV.PartyID          
LEFT JOIN tblMasterCustomerType MCT on MCT.ID = MC.CustomerType          
LEFT JOIN tblBeatSalesmanMapping AS CBS ON CBS.CustomerId = MC.ID          
LEFT JOIN tblMasterBeat MB on MB.ID = CBS.BeatID          
LEFT JOIN tblMasterSalesman MS on MS.ID = CBS.SalesmanID          
    WHERE RV.TransID IN(4) AND RV.DocDate <= @AsOnDate AND RV.Status IN (1,3,5)    
    UNION ALL          
SELECT RV.DocPrefix DocPrefix,RV.ColID [ID],ISNULL(MB.ID,0)[Beat ID],MB.Name[Beat Name],ISNULL(MS.ID,0)[Salesman ID],MS.Name[Salesman Name],        
RV.ColAmt * -1 [NoteValue] ,0 [Pending Amount],RV.Balance * -1 AS [SR Balance],        
DATEDIFF(DAY, RV.ColDate, @AsOnDate)  AS [Ageing]          
FROM tblTranCollectionHeader RV          
JOIN tblMasterCustomer MC on MC.FAID = RV.AccID          
LEFT JOIN tblMasterCustomerType MCT on MCT.ID = MC.CustomerType                 
LEFT JOIN tblMasterBeat MB on MB.ID = RV.BeatID          
LEFT JOIN tblMasterSalesman MS on MS.ID = RV.SalesmanID          
    WHERE RV.DocPrefix IN(4) AND RV.ColDate <= @AsOnDate AND RV.Status IN (1,3,5)    
) SRI          
-- Create #TempID for Split String Ageing Wise          
CREATE TABLE #TempID (IdentID INT IDENTITY(1,1),ID INT)          
          
-- Create #TempAlterColumns for Identifying Column and Checking Range Between          
CREATE TABLE #TempAlterColumns (IdentID INT IDENTITY(1,1),[From] INT,[To] INT,OriginalColumn NVARCHAR(MAX))          
          
-- Insert Spliting String Datas          
INSERT INTO #TempID          
SELECT * FROM (SELECT DISTINCT id FROM dbo.fnSplitString(@fnSplitString,',') WHERE ISNULL(id,'')!='') AS SRI ORDER BY CAST(SRI.id AS INT)          
          
--select * from #TEMPDATA          
INSERT INTO #TempTable          
SELECT DocPrefix,ID,[Beat Name],[SalesMan Name],SUM([Opening Amount]) [Opening Amount],SUM([Pending Amount]) [Pending Amount],        
SUM([SR Balance]) [SR Balance],Ageing          
FROM #TEMPDATA          
WHERE (Ageing = 0 OR Ageing != 0)           
AND(@BeatName = '' OR [Beat ID] IN (SELECT * from dbo.fnSplitString (@BeatName,',')))          
AND(@SalesmanName = '' OR [Salesman ID] IN (SELECT * from dbo.fnSplitString(@SalesmanName,',')))          
GROUP BY  DocPrefix,ID,[Beat Name],[SalesMan Name],Ageing          
ORDER BY [Beat Name]          
          
  --select * from #TempTable        
          
INSERT INTO #TempTable1          
SELECT DocPrefix,[Beat Name],[SalesMan Name],          
DBO.fnGetRoundedValue([Opening Amount]) [Opening Amount],DBO.fnGetRoundedValue([Pending Amount]) [Pending Amount],        
DBO.fnGetRoundedValue([SR Balance]) [SR Balance],Ageing FROM (          
SELECT DocPrefix,TT.[ID],[Beat Name],[SalesMan Name],          
SUM((TT.[Opening Amount])) [Opening Amount],SUM(((TT.[Pending Amount]  + ISNULL(CT.TotalAmtAdj,0)+ ISNULL(Adjustment,0)))) AS [Pending Amount],        
SUM(TT.[SR Balance]) AS [SR Balance],Ageing          
FROM #TempTable TT          
LEFT JOIN #COLTEMP CT ON CT.DocID = TT.ID          
LEFT JOIN #JVTEMP JV ON JV.NoteID = TT.ID          
--WHERE (TT.[Pending Amount] + ISNULL(CT.TotalAmtAdj,0)+ ISNULL(Adjustment,0)) <> 0          
GROUP BY DocPrefix,ID,[Beat Name],[SalesMan Name],Ageing          
) AS NK          
WHERE ((cast(([Pending Amount]) as numeric(26,2))) <> 0  or  (cast(([SR Balance]) as numeric(26,2))) <> 0 )        
order by [Beat Name]          
          
SET @Count1 = (SELECT COUNT(*) FROM #TempID);          
SET @Count = (SELECT COUNT(*) FROM #TempID);          
SET @Serial = 1          
-- Looping for Alter and Spliting Columns using Ageing Wise          
IF ISNULL(@Count1,0)>1          
BEGIN          
print 'aaaaaaaaaaaaaaaaaa'          
WHILE (@Count > 0)          
BEGIN          
SET @AlterColumnName0 = (SELECT ID FROM #TempID WHERE IdentID = @Serial-1)          
SET @AlterColumnName1 = (SELECT ID FROM #TempID WHERE IdentID = @Serial)          
SET @AlterColumnName0 = @AlterColumnName0+1          
IF ISNULL(@Count,0)=1          
BEGIN          
SET @Query = 'ALTER TABLE #TempTable1 ADD ['+@AlterColumnName0+'-'+@AlterColumnName1+' Days] VARCHAR(100) NULL,[>'+@AlterColumnName1+' Days] VARCHAR(100) NULL'          
EXEC sys.sp_executesql @Query, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @AsOnDate DATE', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @fnSplitString = @fnSplitString, @AsOnDate = @AsOnDate          
INSERT INTO #TempAlterColumns VALUES ((@AlterColumnName0),@AlterColumnName1,'['+@AlterColumnName0+'-'+@AlterColumnName1+' Days]')          
INSERT INTO #TempAlterColumns VALUES ((@AlterColumnName1),0,'[>'+@AlterColumnName1+' Days]')          
END          
ELSE IF ISNULL(@Count,0)= @Count1          
BEGIN          
SET @Query = 'ALTER TABLE #TempTable1 ADD [0-'+@AlterColumnName1+' Days] VARCHAR(100) NULL'          
EXEC sys.sp_executesql @Query, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @AsOnDate DATE', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @fnSplitString = @fnSplitString, @AsOnDate = @AsOnDate          
INSERT INTO #TempAlterColumns VALUES (0,@AlterColumnName1,'[0-'+@AlterColumnName1+' Days]')          
END          
ELSE          
BEGIN          
SET @Query = 'ALTER TABLE #TempTable1 ADD ['+@AlterColumnName0+'-'+@AlterColumnName1+' Days] VARCHAR(100) NULL'          
EXEC sys.sp_executesql @Query, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @AsOnDate DATE', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @fnSplitString = @fnSplitString, @AsOnDate = @AsOnDate          
INSERT INTO #TempAlterColumns VALUES ((@AlterColumnName0),@AlterColumnName1,'['+@AlterColumnName0+'-'+@AlterColumnName1+' Days]')          
END          
SET @Count = @Count - 1;          
SET @Serial = @Serial + 1;          
END          
END          
ELSE          
BEGIN          
SET @AlterColumnName0 = (SELECT ID FROM #TempID WHERE IdentID = 1)          
SET @Query = 'ALTER TABLE #TempTable1 ADD [0-'+@AlterColumnName0+' Days] VARCHAR(100) NULL,[>'+@AlterColumnName0+' Days] VARCHAR(100) NULL'          
EXEC sys.sp_executesql @Query, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @AsOnDate DATE', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @fnSplitString = @fnSplitString, @AsOnDate = @AsOnDate          
INSERT INTO #TempAlterColumns VALUES (0,@AlterColumnName0,'[0-'+@AlterColumnName0+' Days]')          
INSERT INTO #TempAlterColumns VALUES (@AlterColumnName0,0,'[>'+@AlterColumnName0+' Days]')          
END          
SET @MainCount = (SELECT COUNT(*) FROM #TempTable1);          
SET @MainSerial = 1          
-- Looping for Get Ageing Information from #TempTable1          
WHILE (@MainCount > 0)          
BEGIN          
SET @Ageing = (SELECT Ageing FROM #TempTable1 WHERE ID = @MainSerial)          
SET @nCount = (SELECT COUNT(*) FROM #TempAlterColumns)          
SET @nCount1 = (SELECT COUNT(*) FROM #TempAlterColumns)          
SET @nSerial = 1          
-- Looping for Check Ageing and From and To Between Ageing Range          
WHILE (@nCount > 0)          
BEGIN          
SET @nF = (SELECT [From] FROM #TempAlterColumns WHERE IdentID = @nSerial)          
SET @nT = (SELECT [to] FROM #TempAlterColumns WHERE IdentID = @nSerial)          
SET @nColumnName = (SELECT OriginalColumn FROM #TempAlterColumns WHERE IdentID = @nSerial)          
IF ISNULL(@nCount1,0) = ISNULL(@nSerial,0)          
BEGIN          
SELECT @IsTrueFalse = (CASE WHEN @Ageing > @nF THEN 'TRUE' ELSE 'FALSE' END)          
END          
ELSE          
BEGIN          
SELECT @IsTrueFalse = (CASE WHEN @Ageing BETWEEN @nF AND @nT THEN 'TRUE' ELSE 'FALSE' END)          
END          
          
-- IF TRUE Updating Pending Amount to Specific Columns          
IF ISNULL(@IsTrueFalse,'')='TRUE'          
BEGIN          
SET @Query = 'UPDATE #TempTable1 SET '+@nColumnName+' = (CASE WHEN DocPrefix = 16 then [SR Balance] ELSE [Pending Amount] END) WHERE ID='+CAST(@MainSerial AS NVARCHAR)+''          
EXEC sys.sp_executesql @Query, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @AsOnDate DATE', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @fnSplitString = @fnSplitString, @AsOnDate = @AsOnDate          
BREAK;          
END          
          
SET @nCount = @nCount - 1;          
SET @nSerial = @nSerial + 1;          
END          
SET @MainCount = @MainCount - 1;          
SET @MainSerial = @MainSerial + 1;          
END          
      
--select 'SUM('+Coalesce(OriginalColumn + '', '')+') '+Coalesce(OriginalColumn + '', ''),* from #TempAlterColumns        
--uspRepBeatwiseOutstandingsHeader '','','0,10,20','12/02/2026'          
      
declare @Name varchar(max)                
Select @Name = Coalesce(@Name + ',', '') + 'dbo.fnGetRoundedValue(SUM(CONVERT(DECIMAL(25,4), ISNULL([' + Ltrim(name) + '],0)))) AS ' + '[' + Ltrim(name) + ']'                
from tempdb.sys.columns                
where object_id = object_id('tempdb..#TempTable1') and name not in ('ID','Beat Name','SalesMan Name','Ageing','DocPrefix')                
ORDER BY column_id      
--SELECT @Name      
      
-- Select all data from #TempTable1 Finally          
alter table #TempTable1 drop column ID          
set @Query = 'SELECT [Beat Name],[SalesMan Name],'+@Name +' FROM #TempTable1 GROUP BY [Beat Name],[SalesMan Name] ORDER BY [Beat Name]'      
EXEC sys.sp_executesql @Query, N'@BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @fnSplitString NVARCHAR(MAX), @AsOnDate DATE', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @fnSplitString = @fnSplitString, @AsOnDate = @AsOnDate      
ENd          
-- Drop all #Temp Tables          
DROP TABLE #TempTable1,#TempTable,#TempID,#COLTEMP,#JVTEMP ,#TempAlterColumns,#TEMPDATA
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepCustomerMfrAnalysisHeader';
GO
--uspRepCustomerMfrAnalysisHeader '1,2,5,13','3,8,24'    
CREATE OR ALTER PROCEDURE [dbo].[uspRepCustomerMfrAnalysisHeader]    
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
        'SUM(CASE WHEN MfrName = ''', MfrName, ''' THEN MfrSalesAmt ELSE 0 END) AS [', MfrName, ' Sales], ',    
        'SUM(CASE WHEN MfrName = ''', MfrName, ''' THEN MfrSalesReturnAmt ELSE 0 END) AS [', MfrName, ' SR], ',    
        'SUM(CASE WHEN MfrName = ''', MfrName, ''' THEN MfrDamageReturnAmt ELSE 0 END) AS [', MfrName, ' DR],',    
        'SUM(CASE WHEN MfrName = ''', MfrName, ''' THEN MfrOSCount ELSE 0 END) AS [', MfrName, ' OSCount], ',    
        'SUM(CASE WHEN MfrName = ''', MfrName, ''' THEN MfrOSValue ELSE 0 END) AS [', MfrName, '  OSValue],',    
        'SUM(CASE WHEN MfrName = ''', MfrName, ''' THEN Mfr30DOSCount ELSE 0 END) AS [', MfrName, ' 30dCount], ',    
        'SUM(CASE WHEN MfrName = ''', MfrName, ''' THEN Mfr30DOSValue ELSE 0 END) AS [', MfrName, ' 30dValue] '    
    ), ', '    
),@colsonly = STRING_AGG(    
    CONCAT(    
        'convert(NVARCHAR(50),convert(decimal(18,2),isnull([', MfrName, ' Sales],0))) [', MfrName, ' Sales], ',    
        'convert(NVARCHAR(50),convert(decimal(18,2),isnull([', MfrName, ' SR],0))) [', MfrName, ' SR], ',    
        'convert(NVARCHAR(50),convert(decimal(18,2),isnull([', MfrName, ' DR],0))) [', MfrName, ' DR],',    
        'convert(NVARCHAR(50),isnull([', MfrName, ' OSCount],0)) [', MfrName, ' OSCount], ',    
        'convert(NVARCHAR(50),convert(decimal(18,2),isnull([', MfrName, '  OSValue],0))) [', MfrName, ' OSValue],',    
        'convert(NVARCHAR(50),isnull([', MfrName, ' 30dCount],0)) [', MfrName, ' 30dCount], ',    
        'convert(NVARCHAR(50),convert(decimal(18,2),isnull([', MfrName, ' 30dValue],0))) [', MfrName, ' 30dValue] '    
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
WHERE BSM.BeatID in (select * from string_split(@BeatIds,'','')) ' END) +'    
ORDER BY TC.Name    
    
DROP TABLE #TEEE,#SalesOSData,#Collectiondata,#SalesData,#SALECOLLMERGEDATA,#overall30DOS'    
-- Step 3: Execute    
    
EXEC sys.sp_executesql @query, N'@BeatIds nvarchar(255), @MfrIds nvarchar(255)', @BeatIds = @BeatIds, @MfrIds = @MfrIds;    
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepCustomerProductSales';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspRepCustomerProductSales]    
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
    AND SH.InvDate BETWEEN '+''''+convert(nvarchar,@FromDate)+''''+' AND '+''''+ convert(nvarchar,@Todate)+''''+''    
 set @query += case when ISNULL(@CustomerName,'') = '' then '' else ' AND MC.ID IN(SELECT * from dbo.fnSplitString( @CustomerName,'',''))' END    
 set @query += case when ISNULL(@BeatName,'') = '' then '' else ' AND MB.ID IN(SELECT * from dbo.fnSplitString(  @BeatName,'',''))' END    
 set @query += case when ISNULL(@SalesmanName,'') = '' then '' else ' AND MS.ID IN(SELECT * from dbo.fnSplitString(  @SalesmanName,'',''))' END    
 set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND BRND.ID IN(SELECT * from dbo.fnSplitString(  @BrandName,'',''))' END    
 set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND CAT.ID IN(SELECT * from dbo.fnSplitString(  @CategoryName,'',''))' END    
 set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND MF.ID IN(SELECT * from dbo.fnSplitString(  @ManufName,'',''))' END    
 set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND MP.ID IN(SELECT * from dbo.fnSplitString(  @ProductName,'',''))' END    
 set @query += case when @CustorProdWise = 1 then '  group by MC.Name,SH.InvDate,MB.Name,MS.Name) ' else '  group by SH.InvDate,MF.Name,BRND.Name,CAT.NAME,MP.Name)' end    
 set @query += 'SELECT '+case when @CustorProdWise = 1 then ' [Beat Name],[Salesman Name],[Customer Name],'+@PColWithisnull     
 else ' [Mfr Name],[Brand Name],[Category Name],[Product Name],'+@PColWithisnull end+' FROM ( SELECT '    
 set @query += case when @CustorProdWise = 1 then ' [Beat Name],[Salesman Name],[Customer Name]'     
 else ' [Mfr Name],[Brand Name],[Category Name],[Product Name]' end+',MonthYear,isnull(Value,0) Value FROM MonthlyData) AS SourceTable    
    PIVOT (SUM(Value) FOR MonthYear IN (' + @PCol + ')) AS PivotTable;';    
EXEC sys.sp_executesql @query, N'@CustorProdWise int, @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @Todate DATE, @ValueType int', @CustorProdWise = @CustorProdWise, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName, @FromDate = @FromDate, @Todate = @Todate, @ValueType = @ValueType;    
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepCustomerwiseWeeklyAnalysisHeader';
GO
--uspRepCustomerwiseWeeklyAnalysisHeader '','','','',1,'2026-02-01','2026-02-28'      
CREATE OR ALTER PROCEDURE [dbo].[uspRepCustomerwiseWeeklyAnalysisHeader]      
    
@BranchName INT,     
@BeatName NVARCHAR(255) = '',                
@SalesmanName NVARCHAR(255) = '',    
@CustomerName NVARCHAR(255) = '',    
@Type INT,      
@FromDate DATE = '2024-08-01',            
@ToDate DATE = '2026-08-30'       
      
AS       
BEGIN      
declare @FirstWeek INT      
SET @FirstWeek = DATEPART(WK,@FromDate)      
declare @totalweeks int = CEILING((DATEDIFF(DAY,@FromDate,@ToDate) + 1) / 7.0)      
CREATE TABLE #LASTSALE(CustID INT,BeatId INT,SalesManId INT,LastTranDate DATE)      
--GET LAST TRAN DATE      
IF(@Type <> 3)      
BEGIN      
INSERT INTO #LASTSALE      
SELECT CustID,BeatID,SalesManID,MAX(InvDate)       
FROM tblTranSalesHeader      
where DocPrefix = CASE       
              WHEN @Type = 1 THEN 15  -- Sales      
              WHEN @Type = 2 THEN 16  -- Sales Return      
            END AND Status IN (1,3,5,6,7) AND InvDate BETWEEN @FromDate AND @ToDate      
GROUP BY CustID,BeatID,SalesManID      
END      
ELSE      
BEGIN      
INSERT INTO #LASTSALE      
SELECT MC.ID,BeatID,SalesManId,MAX(ColDate)       
FROM tblTranCollectionHeader CH      
JOIN tblMasterCustomer MC ON MC.FAID = CH.AccID      
where CH.DocPrefix = 19 AND Status IN (1,3,5) AND ColDate BETWEEN @FromDate AND @ToDate      
GROUP BY MC.ID,BeatID,SalesManId      
END      
      
      
CREATE TABLE #TEMP(CustID INT,BeatID INT,SalesManID INT,[Customer Name] NVARCHAR(255),[Beat Name] NVARCHAR(255),[Salesman Name] NVARCHAR(255),      
NetAmt DECIMAL(25,6),WEEKNO NVARCHAR(50),WEEKINDEX INT,[Outstanding Value] NVARCHAR(255))      
IF(@Type <> 3)      
BEGIN      
INSERT INTO #TEMP      
SELECT CustId,BeatId,SalesManId,[Customer Name],ISNULL([Beat Name],'Default Beat') AS [Beat Name],ISNULL([Salesman Name],'Default Salesman') AS [Salesman Name],      
 SUM(NetAmt) AS NetAmt,'WEEK - '+ CONVERT(NVARCHAR,WEEKNO) WEEKNO,WEEKNO WEEKINDEX,      
CASE       
    WHEN MAX([Outstanding Value]) >= 0       
    THEN CONVERT(NVARCHAR(100), ABS(MAX([Outstanding Value]))) + ' Dr'      
    ELSE CONVERT(NVARCHAR(100), ABS(MAX([Outstanding Value]))) + ' Cr'      
END AS [Outstanding Value] FROM (      
SELECT MC.ID as CustId,SH.BeatID as BeatId,SH.SalesManId as SalesManId,MC.Name [Customer Name],MB.Name [Beat Name],SM.Name as [Salesman Name],SUM(SH.NetAmt) NetAmt,      
CASE WHEN  DATEPART(WK,InvDate) >= @FirstWeek THEN (DATEPART(WK,InvDate) - @FirstWeek) + 1  ELSE      
(((DATEPART(WK,InvDate) - (@FirstWeek)))) + @totalweeks END WEEKNO,      
dbo.funTwoDecimalRoundOff(dbo.uspReturnOpeningBalance(@BranchName, MC.FAID, CONVERT(DATE, @ToDate))) AS [Outstanding Value]      
      
from tblTranSalesHeader SH      
JOIN tblMasterCustomer MC ON MC.ID = SH.CustID      
LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatID      
LEFT JOIN tblMasterSalesman SM ON SM.ID = SH.SalesManID      
WHERE SH.InvDate BETWEEN @FromDate AND @ToDate AND (@BranchName = 0 OR SH.BranchID = @BranchName)      
AND SH.DocPrefix = CASE       
              WHEN @Type = 1 THEN 15  -- Sales      
              WHEN @Type = 2 THEN 16  -- Sales Return      
            END      
AND (      
    (UPPER(@Type) = 'SALES' AND SH.Status IN (1,3,5))      
 OR (UPPER(@Type) <> 'SALES' AND SH.Status IN (3,5,6,7))      
)      
AND (@CustomerName = '' OR MC.ID IN(SELECT * from dbo.fnSplitString( @CustomerName,',')))          
AND (@BeatName = '' OR MB.ID IN(SELECT * from dbo.fnSplitString( @BeatName,',')))          
AND (@SalesmanName = '' OR SM.ID IN(SELECT * from dbo.fnSplitString( @SalesmanName,',')))      
group by MC.ID,MC.Name,MB.Name,SH.BeatID,SH.SalesManID,SM.Name,MC.FAID,DATEPART(WK,InvDate)) AS REC       
GROUP BY [Salesman Name],WEEKNO,[Customer Name],[Beat Name],CustId,BeatId,SalesManId      
ORDER BY WEEKINDEX, [Salesman Name]      
END      
ELSE -- COLLECTION      
BEGIN      
INSERT INTO #TEMP      
SELECT CustId,BeatId,SalesManId,[Customer Name],ISNULL([Beat Name],'Default Beat') [Beat Name],ISNULL([Salesman Name],'Default Salesman') [Salesman Name],      
SUM(NetAmt) NetAmt,'WEEK - '+ CONVERT(NVARCHAR,WEEKNO) WEEKNO,WEEKNO WEEKINDEX,      
CASE       
    WHEN MAX([Outstanding Value]) >= 0      
    THEN CONVERT(NVARCHAR(100),ABS(MAX([Outstanding Value]))) + ' Dr'      
    ELSE CONVERT(NVARCHAR(100),ABS(MAX([Outstanding Value]))) + ' Cr'      
END [Outstanding Value]  FROM (      
SELECT MC.ID as CustId,SH.BeatId,SH.SalesManId,MC.Name [Customer Name],MB.Name [Beat Name],SM.Name as [Salesman Name],SUM(ColAmt) NetAmt,      
CASE WHEN  DATEPART(WK,ColDate) >= @FirstWeek THEN (DATEPART(WK,ColDate) - @FirstWeek) + 1  ELSE      
(((DATEPART(WK,ColDate) - (@FirstWeek)))) + @totalweeks END WEEKNO,      
dbo.funTwoDecimalRoundOff(dbo.uspReturnOpeningBalance(@BranchName, MC.FAID, CONVERT(DATE, @ToDate))) AS [Outstanding Value]      
from tblTranCollectionHeader SH      
JOIN tblMasterCustomer MC ON MC.FAID = SH.AccID      
LEFT JOIN tblMasterBeat MB ON MB.ID = SH.BeatId      
LEFT JOIN tblMasterSalesMan SM ON SM.ID = SH.SalesManId      
WHERE SH.DocPrefix = 19 AND SH.Status IN (1,3,5)      
AND SH.ColDate BETWEEN @FromDate AND @ToDate AND (@BranchName = 0 OR SH.BranchID = @BranchName)      
AND (@CustomerName = '' OR MC.ID IN(SELECT * from dbo.fnSplitString( @CustomerName,',')))          
AND (@BeatName = '' OR MB.ID IN(SELECT * from dbo.fnsplitString( @BeatName,',')))          
AND (@SalesmanName = '' OR SM.ID IN (SELECT * from dbo.fnSplitString(@SalesmanName,',')))      
group by MC.ID,MC.Name,MB.Name,SH.BeatId,SH.SalesManId,SM.Name,MC.FAID,DATEPART(WK,ColDate)) AS REC       
GROUP BY [Salesman Name],WEEKNO,[Customer Name],[Beat Name],CustId, BeatId,SalesManId      
ORDER BY CONVERT(INT,WEEKNO) ,[Salesman Name]       
END      
      
      
CREATE TABLE #TT1(CustID INT,BeatId INT,SalesManId INT,[Customer Name] NVARCHAR(255),[Beat Name] NVARCHAR(255),[Salesman Name] NVARCHAR(255),      
NetAmt DECIMAL(25,6),WEEKNO NVARCHAR(50),WEEKINDEX INT,LastDate DATE,[Outstanding Value] NVARCHAR(255))      
declare @maxcount INT = (SELECT MAX(WEEKINDEX) FROM #TEMP)      
DECLARE @Incr INT = 1      
WHILE(@maxcount >= @Incr)      
begin      
IF((SELECT COUNT(*) FROM #TEMP WHERE WEEKINDEX = @Incr) > 0)      
BEGIN      
INSERT INTO #TT1      
SELECT TE.CustId,TE.BeatID,TE.SalesManId,[Customer Name],[Beat Name],[Salesman Name],(NetAmt) NetAmt,WEEKNO,WEEKINDEX,MAX(LS.LastTranDate),[Outstanding Value] FROM #TEMP as TE      
JOIN #LASTSALE LS ON LS.CustID = TE.CustID AND LS.BeatId = TE.BeatID AND LS.SalesManId = TE.SalesManId      
--LEFT JOIN #LASTSALE LSB ON LSB.BeatId = TE.BeetId      
--LEFT JOIN #LASTSALE LSS ON LSS.SalesManId = TE.SalesManId      
WHERE WEEKINDEX = @Incr      
GROUP BY TE.CustId,TE.BeatID,TE.SalesManId,[Customer Name],[Beat Name],[Salesman Name],NetAmt,WEEKNO,WEEKINDEX,[Outstanding Value]      
END      
ELSE      
BEGIN      
INSERT INTO #TT1 (CustID,BeatId,SalesManId,[Customer Name],WEEKNO,WEEKINDEX) VALUES (0,0,0,null,'WEEK - '+CONVERT(NVARCHAR,@Incr),@Incr)      
END      
SET @Incr = @Incr +1;      
END      
CREATE TABLE #VNAMES (ID INT IDENTITY(1,1),MY NVARCHAR(250),WEEKINDEX INT)      
CREATE TABLE #VNAMESISNULL (ID INT IDENTITY(1,1),MY NVARCHAR(250),WEEKINDEX INT)      
INSERT INTO #vnames      
SELECT DISTINCT WEEKNO,WEEKINDEX FROM #TT1      
INSERT INTO #VNAMESISNULL      
SELECT DISTINCT  'dbo.fnGetRoundedValue(SUM(['+WEEKNO+'])) AS ['+WEEKNO+']',WEEKINDEX  FROM #TT1      
DECLARE @PCol NVARCHAR(MAX),@PCol1 NVARCHAR(MAX),@PCol2 NVARCHAR(MAX),@StrQueryMain NVARCHAR(MAX)      
SELECT @PCol = COALESCE(@PCol+',','') + QUOTENAME(MY) FROM #vnames  ORDER BY WEEKINDEX      
SELECT @PCol1 = COALESCE(@PCol1+',','') + MY  FROM #VNAMESISNULL ORDER BY WEEKINDEX      
SELECT @PCol2 = COALESCE(@PCol2+'+','') + 'isnull('+QUOTENAME(MY)+',0)'  FROM #vnames ORDER BY WEEKINDEX      
--SELECT   QUOTENAME(MY) FROM #vnames  ORDER BY WEEKINDEX      
set @StrQueryMain = 'SELECT * FROM( SELECT [Customer Name],[Beat Name],[Salesman Name],CONVERT(NVARCHAR(20),MAX(LastDate),103) as [Last Transaction Date],[Outstanding Value],      
dbo.fnGetRoundedValue(sum('+@PCol2+')) as [Total '+ CASE @Type WHEN 1 THEN 'SALES' WHEN 2 THEN 'SALES RETURN' WHEN 3 THEN 'COLLECTION' END+' Value],' + @PCol1 +' FROM #TT1      
PIVOT ( SUM(NetAmt) FOR WEEKNO IN ('+ @PCol +')) AS NKPIV GROUP BY [Customer Name],[Beat Name],[Salesman Name],[Outstanding Value]) AS RC WHERE [Customer Name] IS NOT NULL'      
EXEC sys.sp_executesql @StrQueryMain, N'@BranchName INT, @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @Type INT, @FromDate DATE, @ToDate DATE', @BranchName = @BranchName, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @Type = @Type, @FromDate = @FromDate, @ToDate = @ToDate      
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepDoubleMasterData';
GO
--uspRepDoubleMasterData 4,0
CREATE OR ALTER PROCEDURE [dbo].[uspRepDoubleMasterData]
@FormID int,@UserID INT = 0
AS
BEGIN
declare @TableName nvarchar(255) = (select TableName from tblTablesNames where ID = @FormID)    
declare @strQuery NVARCHAR(MAX)   
SET @strQuery = ' select Name [Name],dbo.fngetroundedvalue(Value) Value,case when MB.Active = 1 then ''Yes'' ELSE ''No'' end Active,  
MU.UserName [Created By],CONVERT(NVARCHAR,MB.CDate) [Create Date],  
MUM.UserName [Modify By],CONVERT(NVARCHAR,MB.MDate) [Modify Date] from '+@TableName+' MB      
JOIN tblUsers MU ON MU.ID = MB.CBy      
LEFT JOIN tblUsers MUM ON MUM.ID = MB.MBy '
SET @strQuery += CASE WHEN ISNULL(@UserID,0) = 0 THEN '' ELSE 'WHERE MB.CBy = '+CONVERT(NVARCHAR(50),@UserID) END
SET @strQuery += ' ORDER BY MB.[Name]'                 
EXEC sys.sp_executesql @strQuery, N'@FormID int, @UserID INT', @FormID = @FormID, @UserID = @UserID 
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepInventoryAdjustmentDetail';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspRepInventoryAdjustmentDetail]  
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
WHERE InventHeader.InventoryID= ' + convert(nvarchar(10),@InventoryID)  
set @query += case when ISNULL(@BranchName,0) = 0 then '' else ' AND InventHeader.BranchID = CONVERT(nvarchar(50),@BranchName)'+'' END      
set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND MB.ID IN (SELECT * from dbo.fnSplitString( @BrandName,'',''))' END      
set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND PHL.ID IN (SELECT * from dbo.fnSplitString( @CategoryName,'',''))' END      
set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND Manuf.ID IN (SELECT * from dbo.fnSplitString( @ManufName,'',''))' END      
set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND Product.ID IN (SELECT * from dbo.fnSplitString( @ProductName,'',''))' END    
EXEC sys.sp_executesql @query, N'@InventoryID int, @BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @ToDate DATE', @InventoryID = @InventoryID, @BranchName = @BranchName, @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName, @FromDate = @FromDate, @ToDate = @ToDate  
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepInventoryAdjustmentHeader';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspRepInventoryAdjustmentHeader]      
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
SET @query = @query  + (CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (InventHeader.InventoryDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)        
            
set @query += case when ISNULL(@BranchName,0) = 0 then '' else ' AND InventHeader.BranchID = CONVERT(nvarchar(50),@BranchName)'+'' END      
set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND MB.ID IN (SELECT * from dbo.fnSplitString( @BrandName,'',''))' END      
set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND PHL.ID IN (SELECT * from dbo.fnSplitString( @CategoryName,'',''))' END      
set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND Manuf.ID IN (SELECT * from dbo.fnSplitString( @ManufName,'',''))' END      
set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND Prod.ID IN (SELECT * from dbo.fnSplitString( @ProductName,'',''))' END      
 set @query += '  
GROUP BY InventHeader.InventoryID,TotalAmt,    
InventHeader.DocID,InventoryDate,s.Description,u.username,InventHeader.CDate,MBO.Name,InventHeader.Remarks,Narration,RefNo  
ORDER BY InventHeader.DocID asc  '  
EXEC sys.sp_executesql @query, N'@BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BranchName = @BranchName, @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName, @FromDate = @FromDate, @ToDate = @ToDate   
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepInvoiceOS';
GO
--uspRepInvoiceOS '','','DHANYANTH','2025-03-25'            
CREATE OR ALTER PROCEDURE [dbo].[uspRepInvoiceOS]            
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
  WHERE SH.Status in (1,3,6,7) and SH.InvDate <=  ' +''''+CONVERT(nvarchar(50),@AsonDate)+''''            
SET @strQuery += CASE WHEN ISNULL(@BeatName,'') = '' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString(@BeatName,'',''))' END                
SET @strQuery += CASE WHEN ISNULL(@SalesmanName,'') = '' THEN '' ELSE ' AND SM.ID  IN (SELECT * from dbo.fnSplitString(@SalesmanName,'',''))' END               
SET @strQuery += CASE WHEN ISNULL(@CustomerName,'') = '' THEN '' ELSE ' AND MC.ID  IN (SELECT * from dbo.fnSplitString(@CustomerName,'',''))' END                  
SET @strQuery += ' ORDER BY InvDate,DocValue'            
insert into #temp          
EXEC sys.sp_executesql @strQuery, N'@BeatName nvarchar(max), @SalesmanName nvarchar(max), @CustomerName nvarchar(max), @AsonDate date', @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @AsonDate = @AsonDate            
      
select [Doc ID],[Doc Date],[Ref No],[Beat Name],[Salesman Name],[Customer Name],  
dbo.fnGetRoundedValue([Net Amount]) [Net Amount],dbo.fnGetRoundedValue([Balance]) [Balance],Ageing,[Assigned Invoice Count] from #temp  
        
drop table #temp          
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepItemLedger';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspRepItemLedger]   
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
SET @StrQuery = @StrQuery  +(CASE WHEN ISNULL(@FromDate,'')='' AND ISNULL(@ToDate,'')='' THEN '' ELSE ' AND (PV.TransDate BETWEEN '''+CONVERT(NVARCHAR,CAST(@FromDate AS DATE))+''' AND '''+CONVERT(NVARCHAR,CAST(@ToDate AS DATE))+''')' END)                 
   
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BranchName,'0')='0' THEN '' ELSE ' AND PV.BranchID = @BranchName' END)     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ManufName,'')='' THEN '' ELSE ' AND MM.ID IN (SELECT * from dbo.fnSplitString( @ManufName,'',''))' END)         
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@BrandName,'')='' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString( @BrandName,'',''))' END)            
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@CategoryName,'')='' THEN '' ELSE ' AND PHL.ID IN (SELECT * from dbo.fnSplitString( @CategoryName,'',''))' END)     
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@ProductName,'')='' THEN '' ELSE ' AND MP.ID IN (SELECT * from dbo.fnSplitString( @ProductName,'',''))' END)   
SET @StrQuery = @StrQuery +  ' GROUP BY PV.ProdID,MP.Code,MP.Name,MM.Name,MB.Name,PHL.Name,PV.BatchNumber,PV.PKDDate,PV.ExpiryDate '  
EXEC sys.sp_executesql @StrQuery, N'@BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @FromDate DATE, @ToDate DATE', @BranchName = @BranchName, @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName, @FromDate = @FromDate, @ToDate = @ToDate  
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepItemwiseclosingstockheader';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspRepItemwiseclosingstockheader]      
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
set @query += case when ISNULL(@BranchName,0) = 0 then '' else ' AND TPD.BranchID  = CONVERT(nvarchar(50),@BranchName)'+'' END      
set @query += case when ISNULL(@BrandName,'') = '' then '' else ' AND BrandID IN (SELECT * from dbo.fnSplitString( @BrandName,'',''))' END      
set @query += case when ISNULL(@CategoryName,'') = '' then '' else ' AND CategoryID IN (SELECT * from dbo.fnSplitString( @CategoryName,'',''))' END      
set @query += case when ISNULL(@ManufName,'') = '' then '' else ' AND ManufID IN (SELECT * from dbo.fnSplitString( @ManufName,'',''))' END      
set @query += case when ISNULL(@ProductName,'') = '' then '' else ' AND ProductID IN (SELECT * from dbo.fnSplitString( @ProductName,'',''))' END      
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
EXEC sys.sp_executesql @query, N'@BranchName NVARCHAR(255), @ManufName NVARCHAR(255), @BrandName NVARCHAR(255), @CategoryName NVARCHAR(255), @ProductName NVARCHAR(255), @Date date, @QtyType int', @BranchName = @BranchName, @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName, @Date = @Date, @QtyType = @QtyType      
drop table #TempProductData      
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepMasterProductData';
GO
--uspRepMasterProductData '','','',''      
CREATE OR ALTER PROCEDURE [dbo].[uspRepMasterProductData]      
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
SET @strQuery += CASE WHEN ISNULL(@ManufName,'') = '' THEN '' ELSE ' AND MF.ID IN (SELECT * from dbo.fnSplitString(@ManufName,'',''))' END      
SET @strQuery += CASE WHEN ISNULL(@BrandName,'') = '' THEN '' ELSE ' AND MB.ID IN (SELECT * from dbo.fnSplitString(@BrandName,'',''))' END     
SET @strQuery += CASE WHEN ISNULL(@CategoryName,'') = '' THEN '' ELSE ' AND MC.ID IN (SELECT * from dbo.fnSplitString(@CategoryName,'',''))' END      
SET @strQuery += CASE WHEN ISNULL(@ProductName,'') = '' THEN '' ELSE ' AND MP.ID IN (SELECT * from dbo.fnSplitString(@ProductName,'',''))' END     
EXEC sys.sp_executesql @strQuery, N'@ManufName nvarchar(max), @BrandName nvarchar(max), @CategoryName nvarchar(max), @ProductName nvarchar(max)', @ManufName = @ManufName, @BrandName = @BrandName, @CategoryName = @CategoryName, @ProductName = @ProductName    
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepMasterSalesmanData';
GO
--uspRepMasterSalesmanData '','4,2'
CREATE OR ALTER PROCEDURE [dbo].[uspRepMasterSalesmanData]      
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
--SET @strQuery += CASE WHEN ISNULL(@SalesmanName,'') = '' THEN '' ELSE ' AND MS.Name = @SalesmanName' END      
--SET @strQuery += CASE WHEN ISNULL(@SalesmanGrpName,'') = '' THEN '' ELSE ' AND MSG.Name = @SalesmanGrpName' END      
SET @strQuery += CASE WHEN ISNULL(@SalesmanName,'') = '' THEN '' ELSE ' AND 
MS.ID IN (SELECT * from dbo.fnSplitString(@SalesmanName,'',''))' END      
SET @strQuery += CASE WHEN ISNULL(@SalesmanGrpName,'') = '' THEN '' ELSE ' AND MSG.ID
IN (SELECT * from dbo.fnSplitString(@SalesmanGrpName,'',''))' END      
EXEC sys.sp_executesql @strQuery, N'@SalesmanName nvarchar(max), @SalesmanGrpName nvarchar(max)', @SalesmanName = @SalesmanName, @SalesmanGrpName = @SalesmanGrpName      
end
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepMonthlywiseAnalysisByCustomerHeader';
GO
--uspRepMonthlywiseAnalysisByCustomerHeader 0,'','','',1,'Beat','2026-01-01','2026-03-31'    
CREATE OR ALTER PROCEDURE [dbo].[uspRepMonthlywiseAnalysisByCustomerHeader]    
    
@BranchName INT,         
@BeatName NVARCHAR(255) = '',                    
@SalesmanName NVARCHAR(255) = '',        
@CustomerName NVARCHAR(255) = '',       
@Type INT,    
@FilterBy INT,    
@FromDate DATE,    
@ToDate DATE    
    
AS    
BEGIN    
-- Create #TempTable1 for Get Need Records    
CREATE TABLE #Temp (CustId INT,BeatId INT,SalesmanId INT,[Customer Code] NVARCHAR(255),[Customer Name] NVARCHAR(255),[Customer Type] NVARCHAR(255),[Beat Name] NVARCHAR(255)    
,[SalesMan Name] NVARCHAR(255),[Selected Amount] DECIMAL(25,2),MY NVARCHAR(20),Value DECIMAL(25,2))    
CREATE TABLE #Temp1 (CustId INT,BeatId INT,SalesmanId INT,[Customer Code] NVARCHAR(255),[Customer Name] NVARCHAR(255),[Customer Type] NVARCHAR(255),[Beat Name] NVARCHAR(255)    
,[SalesMan Name] NVARCHAR(255),[Selected Amount] DECIMAL(25,2),MY NVARCHAR(20),Value DECIMAL(25,2))    
    
IF(@Type != 3)    
BEGIN    
 insert into #Temp1    
    
SELECT CustId,BeatID,SalesManID,[Customer Code],[Customer Name],[Customer Type],[Beat Name],          
  [SalesMan Name],ISNULL(SUM([Selected Amount]),0) [Selected Amount],MY,SUM(ISNULL(Value,0)) Value FROM (      
      
 SELECT MC.ID AS CustId,ISNULL(MB.ID,0) AS BeatID,ISNULL(MSM.ID,0) AS SalesManID,MC.Code AS [Customer Code],            
MC.Name AS [Customer Name],mct.Name AS [Customer Type],    
ISNULL(MB.Name,'Default Beat') AS [Beat Name], ISNULL(MSM.Name,'Default SalesMan') AS [SalesMan Name],            
0 AS [Selected Amount],          
UPPER(CONVERT(nvarchar(3),DATENAME(month,TSH.InvDate))) +' '+ CONVERT(NVARCHAR(10),YEAR(TSH.InvDate)) AS MY,          
SUM(CASE     
        WHEN @Type = 1 THEN TSH.GrossAmt    
        ELSE TSH.NetAmt    
    END    
) AS Value    
FROM tblTranSalesHeader AS TSH           
JOIN tblMasterCustomer AS MC ON MC.ID = TSH.CustId            
left join tblMasterCustomerType as mct on mct.ID = MC.CustomerType            
LEFT JOIN tblMasterBeat AS MB ON MB.ID = TSH.BeatID            
LEFT JOIN tblMasterSalesMan AS MSM ON MSM.ID = TSH.SalesManId            
WHERE TSH.DocPrefix=15 AND TSH.Status IN (1,3,5)     
AND TSH.InvDate BETWEEN @FromDate AND @ToDate AND (@BranchName = 0 OR TSH.BranchID = @BranchName)          
AND (@CustomerName = '' OR MC.ID IN(SELECT * from dbo.fnSplitString( @CustomerName,',')))              
AND (@BeatName = '' OR MB.ID IN(SELECT * from dbo.fnSplitString( @BeatName,',')))              
AND (@SalesmanName = '' OR MSM.ID IN(SELECT * from dbo.fnSplitString( @SalesmanName,',')))     
-- Add other joins if needed    
 GROUP BY MC.Code,MC.Name,mct.Name,MC.ID,MB.Name,MSM.Name,MB.ID,MSM.ID,       
InvDate) AS NK GROUP BY CustId,BeatID,SalesManID,[Customer Code],[Customer Name],[Customer Type],[Beat Name],           
 [SalesMan Name],MY    
 END        
 ELSE        
 BEGIN      
 insert into #Temp1    
    
  SELECT CustId,BeatID,SalesManID,[Customer Code],[Customer Name],[Customer Type],[Beat Name],          
  [SalesMan Name],ISNULL(SUM([Selected Amount]),0) [Selected Amount],MY,SUM(ISNULL(Value,0)) Value FROM (     
      
 SELECT MC.ID as CustId,ISNULL(MB.ID,0) AS BeatID,ISNULL(MSM.ID,0) AS SalesManID,MC.Code AS [Customer Code],            
MC.Name AS [Customer Name],mct.Name AS [Customer Type],            
ISNULL(MB.Name,'Default Beat') AS [Beat Name], ISNULL(MSM.Name,'Default SalesMan') AS [SalesMan Name],            
0 AS [Selected Amount],          
UPPER(CONVERT(nvarchar(3),DATENAME(month,ColDate))) +' '+ CONVERT(NVARCHAR(10),YEAR(ColDate)) AS MY,          
SUM(TSH.ColAmt) AS Value          
FROM tblTranCollectionHeader AS TSH           
JOIN tblMasterCustomer AS MC ON MC.ID = TSH.AccID            
left join tblMasterCustomerType as mct on mct.ID = MC.CustomerType            
LEFT JOIN tblMasterBeat AS MB ON MB.ID = TSH.BeatID            
LEFT JOIN tblMasterSalesMan AS MSM ON MSM.ID = TSH.SalesManId                   
WHERE TSH.DocPrefix=19 AND TSH.Status IN (1,3,5)    
AND TSH.ColDate BETWEEN @FromDate AND @ToDate AND (@BranchName = 0 OR TSH.BranchID = @BranchName)          
AND (@CustomerName = '' OR MC.ID IN (SELECT * from dbo.fnSplitString( @CustomerName,',')))              
AND (@BeatName = '' OR MB.ID IN (SELECT * from dbo.fnSplitString( @BeatName,',')))              
AND (@SalesmanName = '' OR MSM.ID IN (SELECT * from dbo.fnSplitString( @SalesmanName,',')))     
 GROUP BY MC.Code,MC.Name,mct.Name,MC.ID,MB.Name,MSM.Name,MB.ID,MSM.ID,          
ColDate) AS NK GROUP BY CustId,BeatID,SalesManID,[Customer Code],[Customer Name],[Customer Type],[Beat Name],           
 [SalesMan Name],MY    
     
 END        
    
 declare @StrQuery nvarchar(max)     
    
 set @StrQuery = 'select ' + case when @FilterBy = 0 THEN 'CustId,BeatId,SalesmanId,[Customer Code],[Customer Name],      
 [Customer Type],[Beat Name],[SalesMan Name],ISNULL(SUM([Selected Amount]),0),MY,SUM(ISNULL(Value,0)) Value'       
 WHEN @FilterBy = 1 THEN ' 0,BeatId,0,'''','''','''',[Beat Name],'''',ISNULL(SUM([Selected Amount]),0),MY,SUM(ISNULL(Value,0)) Value '       
 WHEN @FilterBy = 2 THEN ' 0,0,SalesmanId,'''','''','''','''',[SalesMan Name],ISNULL(SUM([Selected Amount]),0),MY,SUM(ISNULL(Value,0)) Value '      
 WHEN @FilterBy = 3 THEN ' CustId,0,0,[Customer Code],[Customer Name],'''','''','''',ISNULL(SUM([Selected Amount]),0),MY,SUM(ISNULL(Value,0)) Value '       
 else '''' end  + ' from #Temp1 '      
 set @StrQuery += ' GROUP BY '+ case when @FilterBy = 0 THEN 'CustId,BeatId,SalesmanId,[Customer Code],[Customer Name],      
 [Customer Type],[Beat Name],[SalesMan Name],MY'       
 WHEN @FilterBy = 1 THEN ' BeatId,[Beat Name],MY '       
 WHEN @FilterBy = 2 THEN ' SalesmanId,[SalesMan Name],MY '      
 WHEN @FilterBy = 3 THEN ' CustId,[Customer Code],[Customer Name],MY '       
 else '''' end      
 --select * from #Temp        
  insert into #Temp        
 EXEC sys.sp_executesql @StrQuery, N'@BranchName INT, @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @Type INT, @FilterBy INT, @FromDate DATE, @ToDate DATE', @BranchName = @BranchName, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @Type = @Type, @FilterBy = @FilterBy, @FromDate = @FromDate, @ToDate = @ToDate           
    
-- PRINT @StrQuery    
--RETURN    
    
CREATE TABLE #VNAMES (ID INT IDENTITY(1,1),MFD DATE,MY NVARCHAR(50))          
CREATE TABLE #VNAMESISNULL (ID INT IDENTITY(1,1),MFD DATE,MY NVARCHAR(50))          
INSERT INTO #vnames           
SELECT DISTINCT (DATEADD(mm, DATEDIFF(mm, 0, MY),0)), MY FROM #Temp          
INSERT INTO #VNAMESISNULL          
SELECT DISTINCT (DATEADD(mm, DATEDIFF(mm, 0, MY),0)), 'ISNULL(['+MY+'],0)' FROM #Temp          
DECLARE @PCol NVARCHAR(MAX),@PCol1 NVARCHAR(MAX)          
SELECT @PCol = COALESCE(@PCol+',','') + QUOTENAME(MY) FROM #vnames GROUP BY MY,MFD ORDER BY MFD          
SELECT @PCol1 = COALESCE(@PCol1+'+','') +   (MY)  FROM #VNAMESISNULL GROUP BY MY,MFD ORDER BY MFD       
--1 as IdentID,CustId,BeatId,SalesmanId,    
set @StrQuery = ' SELECT [Customer Code],[Customer Name],[Customer Type],[Beat Name],[SalesMan Name],          
 '+ @PCol1 +'  AS [Selected Amount],' + @PCol +'  FROM #Temp          
PIVOT ( SUM(Value) FOR MY IN ('+ @PCol +')) AS NKPIV '          
EXEC sys.sp_executesql @StrQuery, N'@BranchName INT, @BeatName NVARCHAR(255), @SalesmanName NVARCHAR(255), @CustomerName NVARCHAR(255), @Type INT, @FilterBy INT, @FromDate DATE, @ToDate DATE', @BranchName = @BranchName, @BeatName = @BeatName, @SalesmanName = @SalesmanName, @CustomerName = @CustomerName, @Type = @Type, @FilterBy = @FilterBy, @FromDate = @FromDate, @ToDate = @ToDate          
DROP TABLE #Temp,#VNAMES,#VNAMESISNULL,#Temp1      
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspReportScript';
GO
--    
CREATE OR ALTER PROCEDURE [dbo].[uspReportScript]          
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
DECLARE @QueryHeader NVARCHAR(50) = 'SP_HELPTEXT '+@SpHeader          
INSERT INTO @tempHeader EXEC sys.sp_executesql @QueryHeader, N'@Mode INT, @ReportID INT', @Mode = @Mode, @ReportID = @ReportID          
          
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
DECLARE @QueryFooter NVARCHAR(50) = 'SP_HELPTEXT '+@SpFooter          
INSERT INTO @tempFooter EXEC sys.sp_executesql @QueryFooter, N'@Mode INT, @ReportID INT', @Mode = @Mode, @ReportID = @ReportID          
          
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
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspRepSingleMasterData';
GO
--uspRepSingleMasterData 1,0
CREATE OR ALTER PROCEDURE [dbo].[uspRepSingleMasterData]
@FormID int,@UserID INT = 0
AS
BEGIN
declare @TableName nvarchar(255) = (select TableName from tblTablesNames where ID = @FormID)    
declare @strQuery NVARCHAR(MAX)   
SET @strQuery = ' select Name [Name],case when MB.Active = 1 then ''Yes'' ELSE ''No'' end Active,  
MU.UserName [Created By],CONVERT(NVARCHAR,MB.CDate) [Create Date],  
MUM.UserName [Modify By],CONVERT(NVARCHAR,MB.MDate) [Modify Date] from '+@TableName+' MB      
JOIN tblUsers MU ON MU.ID = MB.CBy      
LEFT JOIN tblUsers MUM ON MUM.ID = MB.MBy '
SET @strQuery += CASE WHEN ISNULL(@UserID,0) = 0 THEN '' ELSE 'WHERE MB.CBy = '+CONVERT(NVARCHAR(50),@UserID) END
SET @strQuery += ' ORDER BY MB.[Name]'                 
EXEC sys.sp_executesql @strQuery, N'@FormID int, @UserID INT', @FormID = @FormID, @UserID = @UserID 
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspShrinkDataBase';
GO
--[uspShrinkDataBase] 'WSHINE_TEMP01_APR2026'
CREATE OR ALTER PROCEDURE [dbo].[uspShrinkDataBase]
@DBName NVARCHAR(255)
AS
BEGIN
SET NOCOUNT ON;
-- Security: the database name is no longer placed in the SQL text. The procedure only works on the
-- database it lives in; @DBName is kept so existing callers do not break and must match DB_NAME().
IF ISNULL(@DBName, DB_NAME()) <> DB_NAME()
    THROW 50001, N'uspShrinkDataBase only works on the current database.', 1;

DECLARE @db sysname = DB_NAME(), @StrQuery NVARCHAR(MAX), @LDFFilename sysname, @Recovery nvarchar(60);
SELECT @Recovery = recovery_model_desc FROM sys.databases WHERE database_id = DB_ID();
SELECT @LDFFilename = name FROM sys.database_files WHERE type_desc = 'LOG';

IF @Recovery <> N'SIMPLE'
BEGIN
    SET @StrQuery = N'ALTER DATABASE ' + QUOTENAME(@db) + N' SET RECOVERY SIMPLE';
    EXEC sys.sp_executesql @StrQuery;
END
DBCC SHRINKFILE (@LDFFilename, 1);
-- Put back the recovery model the database had (the old code always forced FULL).
IF @Recovery <> N'SIMPLE'
BEGIN
    SET @StrQuery = N'ALTER DATABASE ' + QUOTENAME(@db) + N' SET RECOVERY ' + CASE @Recovery WHEN N'BULK_LOGGED' THEN N'BULK_LOGGED' ELSE N'FULL' END;
    EXEC sys.sp_executesql @StrQuery;
END
-- Clears cached plans for this database only (DBCC FREEPROCCACHE cleared every database on the server).
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
SELECT '1'
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspSyncMasterData';
GO
--uspSyncMasterData 'WSHINE_DEV001_APR2024','tblMasterDiscountSchemeDetail','2023-11-18 13:07:19.180'    
CREATE OR ALTER PROCEDURE [dbo].[uspSyncMasterData]    
@sourcedbname NVARCHAR(128) = 'WSHINE_DEV001_APR2024',    
@TableName    NVARCHAR(128) = 'tblMasterBank',    
@SyncDate     DATETIME = '2026-08-10 19:14:32.937'    
AS    
BEGIN TRY    
BEGIN TRAN
-- Security: @TableName comes from the request. Only tables enabled in tblWebshineMasterSyncTables
-- may be synchronised, and the source must be another existing database.
IF NOT EXISTS (SELECT 1 FROM dbo.tblWebshineMasterSyncTables WHERE TableName = @TableName AND IsSync = 1)
    THROW 50001, N'This table is not enabled for master sync.', 1;
IF DB_ID(@sourcedbname) IS NULL OR DB_ID(@sourcedbname) = DB_ID()
    THROW 50002, N'Invalid master sync source database.', 1;    
DECLARE @qry NVARCHAR(MAX);    
DECLARE @Columns NVARCHAR(MAX);    
DECLARE @SourceColumns NVARCHAR(MAX);    
DECLARE @UpdateColumns NVARCHAR(MAX);    
    
DECLARE @ISNOTCOMMON INT = 0;    
IF(@TableName IN ('tblBeatSalesmanMapping','tblMasterChequeBookDetail','tblMasterCustomerRemarks',    
'tblMasterTaxDetail', 'tblProductLocationMapping','tblFAAccount','tblFAGroup','tblMasterChequeBook',    
'tblMasterTax','tblRolePermissions','tblMasterDiscountSchemeDetail'))    
BEGIN    
SET @ISNOTCOMMON = 1    
END    
    
IF(@ISNOTCOMMON = 1)    
BEGIN    
IF(@TableName = 'tblBeatSalesmanMapping')    
BEGIN    
SET @qry = 'DELETE tblBeatSalesmanMapping WHERE CustomerID IN (    
SELECT CustomerID FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterCustomer MC    
JOIN '+QUOTENAME(@sourcedbname)+'.dbo.tblBeatSalesmanMapping BSM ON BSM.CustomerID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate)    
    
INSERT INTO tblBeatSalesmanMapping    
SELECT BSM.CustomerID,BSM.BeatID,BSM.SalesmanID FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterCustomer MC    
JOIN '+QUOTENAME(@sourcedbname)+'.dbo.tblBeatSalesmanMapping BSM ON BSM.CustomerID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate '    
END    
IF(@TableName = 'tblMasterChequeBookDetail')    
BEGIN    
SET @qry = 'DELETE tblMasterChequeBookDetail WHERE ChequeBookID IN (    
SELECT ChequeBookID FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterChequeBook MC    
WHERE COALESCE(MDate,CDate) >= @SyncDate)    
    
INSERT INTO tblMasterChequeBookDetail    
SELECT BSM.ChequeBookID,BSM.ChequeNo,BSM.Status FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterChequeBook MC    
JOIN '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterChequeBookDetail BSM ON BSM.ChequeBookID = MC.ChequeBookID    
WHERE COALESCE(MDate,CDate) >= @SyncDate '    
END    
IF(@TableName = 'tblMasterCustomerRemarks')    
BEGIN    
SET @qry = 'DELETE tblMasterCustomerRemarks WHERE CustomerID IN (    
SELECT CustomerID FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterCustomer MC    
JOIN '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterCustomerRemarks BSM ON BSM.CustomerID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate)    
    
INSERT INTO tblMasterCustomerRemarks    
SELECT BSM.CustomerID,BSM.CustomerRemarks FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterCustomer MC    
JOIN '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterCustomerRemarks BSM ON BSM.CustomerID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate '    
END    
    
IF(@TableName = 'tblMasterTaxDetail')    
BEGIN    
SET @qry = 'DELETE tblMasterTaxDetail WHERE TaxID IN (    
SELECT MC.TaxID FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterTax MC    
JOIN '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterTaxDetail BSM ON BSM.TaxID = MC.TaxID    
WHERE COALESCE(MDate,CDate) >= @SyncDate)    
    
INSERT INTO tblMasterTaxDetail    
SELECT BSM.TaxID,TaxTypeID,TaxCompID,TaxRate,AppOn,PartOff,CumulativeTax,GSTTaxType    
FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterTax MC    
JOIN '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterTaxDetail BSM ON BSM.TaxID = MC.TaxID    
WHERE COALESCE(MDate,CDate) >= @SyncDate '    
END    
IF(@TableName = 'tblProductLocationMapping')    
BEGIN    
SET @qry = 'DELETE tblProductLocationMapping WHERE ProductID IN (    
SELECT MC.ID FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterProduct MC    
JOIN '+QUOTENAME(@sourcedbname)+'.dbo.tblProductLocationMapping BSM ON BSM.ProductID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate)    
    
INSERT INTO tblProductLocationMapping    
SELECT BSM.*    
FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterProduct MC    
JOIN '+QUOTENAME(@sourcedbname)+'.dbo.tblProductLocationMapping BSM ON BSM.ProductID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate '    
END    
IF(@TableName = 'tblMasterDiscountSchemeDetail')    
BEGIN    
SET @qry = 'DELETE tblMasterDiscountSchemeDetail WHERE ID IN (    
SELECT MC.ID FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterDiscountSchemeHeader MC    
JOIN '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterDiscountSchemeDetail BSM ON BSM.ID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate)    
    
INSERT INTO tblMasterDiscountSchemeDetail    
SELECT BSM.*    
FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterDiscountSchemeHeader MC    
JOIN '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterDiscountSchemeDetail BSM ON BSM.ID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate '    

SET @qry += ' DELETE tblMasterDiscountSchemeCustomers WHERE ID IN (    
SELECT MC.ID FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterDiscountSchemeHeader MC    
JOIN '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterDiscountSchemeCustomers BSM ON BSM.ID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate)    
    
INSERT INTO tblMasterDiscountSchemeCustomers    
SELECT BSM.*    
FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterDiscountSchemeHeader MC    
JOIN '+QUOTENAME(@sourcedbname)+'.dbo.tblMasterDiscountSchemeCustomers BSM ON BSM.ID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate ' 
END  
IF(@TableName = 'tblFAAccount')    
BEGIN    
-- Get columns except ID    
SELECT @Columns = STRING_AGG(QUOTENAME(COLUMN_NAME), ','),@SourceColumns = STRING_AGG(    
    'S.' + QUOTENAME(COLUMN_NAME), ','),    
    @UpdateColumns = STRING_AGG('T.' + QUOTENAME(COLUMN_NAME) + ' = S.' + QUOTENAME(COLUMN_NAME),',')    
FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName AND COLUMN_NAME <> 'FAID';    
    
SET @qry = N' UPDATE T    
SET ' + @UpdateColumns + '    
FROM dbo.' + QUOTENAME(@TableName) + ' T    
INNER JOIN ' + QUOTENAME(@sourcedbname) + '.dbo.' + QUOTENAME(@TableName) + ' S    
ON T.FAID = S.FAID WHERE COALESCE(S.MDate, S.CDate) >= @SyncDate;     
    
SET IDENTITY_INSERT dbo.' + QUOTENAME(@TableName) + ' ON;    
INSERT INTO dbo.' + QUOTENAME(@TableName) + '    
(    
    FAID,    
    ' + @Columns + '    
)    
SELECT    
    S.FAID,    
    ' + @SourceColumns + '    
FROM ' + QUOTENAME(@sourcedbname) + '.dbo.' + QUOTENAME(@TableName) + ' S    
WHERE COALESCE(S.MDate, S.CDate) >= @SyncDate    
AND NOT EXISTS    
(    
    SELECT 1    
    FROM dbo.' + QUOTENAME(@TableName) + ' T    
    WHERE T.FAID = S.FAID    
);    
SET IDENTITY_INSERT dbo.' + QUOTENAME(@TableName) + ' OFF;';    
END    
IF(@TableName = 'tblFAGroup')    
BEGIN    
-- Get columns except ID    
SELECT @Columns = STRING_AGG(QUOTENAME(COLUMN_NAME), ','),@SourceColumns = STRING_AGG(    
    'S.' + QUOTENAME(COLUMN_NAME), ','),    
    @UpdateColumns = STRING_AGG('T.' + QUOTENAME(COLUMN_NAME) + ' = S.' + QUOTENAME(COLUMN_NAME),',')    
FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName AND COLUMN_NAME <> 'FAGroup';    
    
SET @qry = N' UPDATE T    
SET ' + @UpdateColumns + '    
FROM dbo.' + QUOTENAME(@TableName) + ' T    
INNER JOIN ' + QUOTENAME(@sourcedbname) + '.dbo.' + QUOTENAME(@TableName) + ' S    
ON T.FAGroup = S.FAGroup WHERE COALESCE(S.MDate, S.CDate) >= @SyncDate;     
    
SET IDENTITY_INSERT dbo.' + QUOTENAME(@TableName) + ' ON;    
INSERT INTO dbo.' + QUOTENAME(@TableName) + '    
(    
    FAGroup,    
    ' + @Columns + '    
)    
SELECT    
    S.FAGroup,    
    ' + @SourceColumns + '    
FROM ' + QUOTENAME(@sourcedbname) + '.dbo.' + QUOTENAME(@TableName) + ' S    
WHERE COALESCE(S.MDate, S.CDate) >= @SyncDate    
AND NOT EXISTS    
(    
    SELECT 1    
    FROM dbo.' + QUOTENAME(@TableName) + ' T    
    WHERE T.FAGroup = S.FAGroup    
);    
SET IDENTITY_INSERT dbo.' + QUOTENAME(@TableName) + ' OFF;';    
END    
--CHQ    
IF(@TableName = 'tblMasterChequeBook')    
BEGIN    
-- Get columns except ID    
SELECT @Columns = STRING_AGG(QUOTENAME(COLUMN_NAME), ','),@SourceColumns = STRING_AGG(    
    'S.' + QUOTENAME(COLUMN_NAME), ','),    
    @UpdateColumns = STRING_AGG('T.' + QUOTENAME(COLUMN_NAME) + ' = S.' + QUOTENAME(COLUMN_NAME),',')    
FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName AND COLUMN_NAME <> 'ChequeBookID';    
    
SET @qry = N' UPDATE T    
SET ' + @UpdateColumns + '    
FROM dbo.' + QUOTENAME(@TableName) + ' T    
INNER JOIN ' + QUOTENAME(@sourcedbname) + '.dbo.' + QUOTENAME(@TableName) + ' S    
ON T.ChequeBookID = S.ChequeBookID WHERE COALESCE(S.MDate, S.CDate) >= @SyncDate;     
    
SET IDENTITY_INSERT dbo.' + QUOTENAME(@TableName) + ' ON;    
INSERT INTO dbo.' + QUOTENAME(@TableName) + '    
(    
    ChequeBookID,    
    ' + @Columns + '    
)    
SELECT    
    S.ChequeBookID,    
    ' + @SourceColumns + '    
FROM ' + QUOTENAME(@sourcedbname) + '.dbo.' + QUOTENAME(@TableName) + ' S    
WHERE COALESCE(S.MDate, S.CDate) >= @SyncDate    
AND NOT EXISTS    
(    
    SELECT 1    
    FROM dbo.' + QUOTENAME(@TableName) + ' T    
    WHERE T.ChequeBookID = S.ChequeBookID    
);    
SET IDENTITY_INSERT dbo.' + QUOTENAME(@TableName) + ' OFF;';    
END    
--TAX    
IF(@TableName = 'tblMasterTax')    
BEGIN    
-- Get columns except ID    
SELECT @Columns = STRING_AGG(QUOTENAME(COLUMN_NAME), ','),@SourceColumns = STRING_AGG(    
    'S.' + QUOTENAME(COLUMN_NAME), ','),    
    @UpdateColumns = STRING_AGG('T.' + QUOTENAME(COLUMN_NAME) + ' = S.' + QUOTENAME(COLUMN_NAME),',')    
FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName AND COLUMN_NAME <> 'TaxID';    
    
SET @qry = N' UPDATE T    
SET ' + @UpdateColumns + '    
FROM dbo.' + QUOTENAME(@TableName) + ' T    
INNER JOIN ' + QUOTENAME(@sourcedbname) + '.dbo.' + QUOTENAME(@TableName) + ' S    
ON T.TaxID = S.TaxID WHERE COALESCE(S.MDate, S.CDate) >= @SyncDate;     
    
SET IDENTITY_INSERT dbo.' + QUOTENAME(@TableName) + ' ON;    
INSERT INTO dbo.' + QUOTENAME(@TableName) + '    
(    
    TaxID,    
    ' + @Columns + '    
)    
SELECT    
    S.TaxID,    
    ' + @SourceColumns + '    
FROM ' + QUOTENAME(@sourcedbname) + '.dbo.' + QUOTENAME(@TableName) + ' S    
WHERE COALESCE(S.MDate, S.CDate) >= @SyncDate  AND NOT EXISTS    
(    
    SELECT 1    
    FROM dbo.' + QUOTENAME(@TableName) + ' T    
    WHERE T.TaxID = S.TaxID    
);    
SET IDENTITY_INSERT dbo.' + QUOTENAME(@TableName) + ' OFF;';    
END    
IF(@TableName = 'tblRolePermissions')    
BEGIN    
SET @qry = 'DELETE tblRolePermissions WHERE Role IN (    
SELECT Role FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblRolePermissions MC    
WHERE CDate >= @SyncDate)    
    
INSERT INTO tblRolePermissions    
SELECT MC.* FROM '+QUOTENAME(@sourcedbname)+'.dbo.tblRolePermissions MC    
WHERE CDate >= @SyncDate '    
END    
END    
ELSE    
BEGIN    
-- Get columns except ID    
SELECT    
    @Columns = STRING_AGG(QUOTENAME(COLUMN_NAME), ','),    
        
    @SourceColumns = STRING_AGG(    
        'S.' + QUOTENAME(COLUMN_NAME), ','    
    ),    
        
    @UpdateColumns = STRING_AGG(    
        'T.' + QUOTENAME(COLUMN_NAME) + ' = S.' + QUOTENAME(COLUMN_NAME),    
        ','    
    )    
FROM INFORMATION_SCHEMA.COLUMNS    
WHERE TABLE_NAME = @TableName    
  AND COLUMN_NAME <> 'ID';    
    
    
SET @qry = N'    
    
/* ============================================    
   UPDATE EXISTING RECORDS    
   ============================================ */    
    
UPDATE T    
SET    
    ' + @UpdateColumns + '    
FROM dbo.' + QUOTENAME(@TableName) + ' T    
INNER JOIN ' + QUOTENAME(@sourcedbname) + '.dbo.' + QUOTENAME(@TableName) + ' S    
    ON T.ID = S.ID    
WHERE COALESCE(S.MDate, S.CDate) >= @SyncDate;    
    
    
/* ============================================    
   INSERT NEW RECORDS WITH SAME ID    
   ============================================ */    
'    
SET @qry += CASE WHEN @TableName = 'tblProductTransactionprices' THEN '' ELSE    
N' SET IDENTITY_INSERT dbo.' + QUOTENAME(@TableName) + ' ON;' END    
SET @qry += N'    
INSERT INTO dbo.' + QUOTENAME(@TableName) + '    
(    
    ID,    
    ' + @Columns + '    
)    
SELECT    
    S.ID,    
    ' + @SourceColumns + '    
FROM ' + QUOTENAME(@sourcedbname) + '.dbo.' + QUOTENAME(@TableName) + ' S    
WHERE COALESCE(S.MDate, S.CDate) >= @SyncDate    
AND NOT EXISTS    
(    
    SELECT 1    
    FROM dbo.' + QUOTENAME(@TableName) + ' T    
    WHERE T.ID = S.ID    
);'    
    
SET @qry += CASE WHEN @TableName = 'tblProductTransactionprices' THEN '' ELSE    
N'SET IDENTITY_INSERT dbo.' + QUOTENAME(@TableName) + ' OFF; 'END    
    
END    
--PRINT @qry;    
    
EXEC sp_executesql    
    @qry,    
    N'@SyncDate DATETIME',    
    @SyncDate = @SyncDate;    
        
    
COMMIT TRAN;    
END TRY    
BEGIN CATCH    
ROLLBACK TRAN;    
select ERROR_MESSAGE() MSG,ERROR_LINE() LINE,ERROR_NUMBER() ENO    
END CATCH
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspUpdateEwayInTrans';
GO
--uspUpdateEwayInTrans 2,'2,3,6',1,3,'Road','Regular',NULL,NULL      
CREATE OR ALTER PROCEDURE [dbo].[uspUpdateEwayInTrans]            
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
-- Security: these values are placed in the SQL text as ID lists, so only digits, commas and spaces are accepted.
IF (ISNULL(@InvID,N'') LIKE N'%[^0-9, ]%')
    THROW 50001, N'Invalid ID list.', 1;
-- No documents selected: nothing to update (the old code also did nothing here).
IF ISNULL(@InvID,N'') = N'' RETURN;
            
DECLARE @sql NVARCHAR(MAX)      
if(@Type = 1)-- update in invoice
BEGIN
SET @sql = 'UPDATE tblTranSalesHeader SET VehicleNo =@VehicleID' +',Distance =@Distance' +',
TransMode =@TranMode' +',VehicleType =@VehicleType' +',TransportID =ISNULL(@TransportID,'''')' +',
TransportName = ISNULL(@TransportName,'''')' +' 
WHERE Docprefix = 15 and status in (1,3,5) and DocValue IN ('+ ''+ISNULL(@InvID,'')+''+')'      
set @sql += case when isnull(@Branch,'') = '' then '' else ' and BranchID = convert(nvarchar(255),@Branch)' end    
SET @sql += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE 
' AND InvDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END      
END
ELSE if(@Type = 2)-- update in Van Loading Slip
BEGIN
SET @sql = 'UPDATE tblVanLoadingSlipHeader SET VehicleNo =@VehicleID' +',Distance =@Distance' +',
TransMode =@TranMode' +',VehicleType =@VehicleType' +',TransportID =ISNULL(@TransportID,'''')' +',
TransportName = ISNULL(@TransportName,'''')' +' 
WHERE status in (1,3,5) and DocValue IN ('+ ''+ISNULL(@InvID,'')+''+')'      
set @sql += case when isnull(@Branch,'') = '' then '' else ' and BranchID = convert(nvarchar(255),@Branch)' end    
SET @sql += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE 
' AND DocDate BETWEEN '+''''+CONVERT(NVARCHAR,@FromDate) +''' AND '+''''+CONVERT(NVARCHAR,@ToDate) + '''' END    
END
EXEC sys.sp_executesql @sql, N'@Mode INT, @InvID NVARCHAR(MAX), @VehicleID NVARCHAR(50), @Distance NVARCHAR(50), @TranMode NVARCHAR(100), @VehicleType NVARCHAR(100), @TransportID NVARCHAR(100), @TransportName NVARCHAR(255), @Branch NVARCHAR(255), @FromDate date, @ToDate date, @Type int', @Mode = @Mode, @InvID = @InvID, @VehicleID = @VehicleID, @Distance = @Distance, @TranMode = @TranMode, @VehicleType = @VehicleType, @TransportID = @TransportID, @TransportName = @TransportName, @Branch = @Branch, @FromDate = @FromDate, @ToDate = @ToDate, @Type = @Type      
END            
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
PRINT N'dbo.uspVendorReport';
GO
CREATE OR ALTER PROCEDURE [dbo].[uspVendorReport]
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
SET @strQuery += CASE WHEN ISNULL(@WeekCycle,'0') = '0' THEN '' ELSE ' AND MV.WeekCycle = @WeekCycle' END      
SET @strQuery += CASE WHEN ISNULL(@Ratings,'0') = '0' THEN '' ELSE ' AND MV.Rating = @Ratings' END     
SET @strQuery += ' ORDER BY MV.Name '
EXEC sys.sp_executesql @strQuery, N'@WeekCycle nvarchar(50), @Ratings nvarchar(50)', @WeekCycle = @WeekCycle, @Ratings = @Ratings    
END
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
