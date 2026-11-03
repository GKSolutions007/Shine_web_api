/* =====================================================================================
   01  Parameterise dynamic SQL in the list-filter procedures (SQL-injection fix)
   Generated from the schema export of WSHINE_TEST01_APR2026 (script.ipynb, 29-10-2026).
   Run in SSMS against the target database. Each procedure is its own batch.
   ===================================================================================== */
SET NOCOUNT ON;
GO
/****** uspFilterCollectionPayment ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspFilterCollectionPayment]                    
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
WHERE Collect.DocPrefix=  @DocPrefix AND ColDate BETWEEN @FromDate AND @ToDate'                    
SET @StrQueryNew = @StrQueryNew + (CASE WHEN @ShowAllStatus = 1 THEN '' ELSE 'AND Collect.[Status] in (1,3,5)' end)                    
SET @StrQueryNew = @StrQueryNew + (CASE WHEN ISNULL(@Name,'')='' THEN '' ELSE 'AND Customer.Name =  @Name' end)                    
SET @StrQueryNew = @StrQueryNew + ' ORDER BY Collect.ColDate DESC,Collect.DocValue DESC,Collect.ColID DESC'                    
EXEC sys.sp_executesql @StrQueryNew, N'@Mode NVARCHAR(50), @DocPrefix INT, @Name NVARCHAR(255), @FromDate date, @ToDate date, @ShowAllStatus int', @Mode, @DocPrefix, @Name, @FromDate, @ToDate, @ShowAllStatus                    
  
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
WHERE Payment.PYPrefix = @DocPrefix AND PYDate BETWEEN @FromDate AND @ToDate'                    
SET @StrQueryNew = @StrQueryNew + (CASE WHEN @ShowAllStatus = 1 THEN '' ELSE 'AND Payment.[Status] in (1,3,5)' end)                    
SET @StrQueryNew = @StrQueryNew + (CASE WHEN ISNULL(@Name,'')='' THEN '' ELSE 'AND Vendor.Name =  @Name' end)                    
SET @StrQueryNew = @StrQueryNew + ' ORDER BY Payment.PYDate DESC, Payment.DocValue DESC,Payment.PYID DESC'                    
EXEC sys.sp_executesql @StrQueryNew, N'@Mode NVARCHAR(50), @DocPrefix INT, @Name NVARCHAR(255), @FromDate date, @ToDate date, @ShowAllStatus int', @Mode, @DocPrefix, @Name, @FromDate, @ToDate, @ShowAllStatus                    
END                    
END 
GO

/****** uspGetSetPurchaseOrderData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetPurchaseOrderData]                            
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN  @FromDate AND @ToDate' END                            
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END                            
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                            
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                            
SET @strQuery += ' ORDER BY PH.DocDate DESC, DocValue DESC,PH.ID '                            
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID int, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @TransID, @Code, @ID, @Party, @FromDate, @ToDate, @Showall                            
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN  @FromDate AND @ToDate' END                            
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END                            
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                            
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                            
SET @strQuery += ' ORDER BY PH.Date DESC,PH.ID DESC '                            
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID int, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @TransID, @Code, @ID, @Party, @FromDate, @ToDate, @Showall                            
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN  @FromDate AND @ToDate' END                            
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END                            
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                            
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN ' AND PH.Status in (1,3) ' ELSE ' AND PH.Status in (1,3)' END                            
SET @strQuery += ' GROUP BY PH.ID,DOCID,PH.DocValue,DATE,REFNO,MBO.NAME,MV.NAME,STS.DESCRIPTION,CUR.UserName,PH.CDate,PH.Status,PH.Remarks,PH.Narration '                            
SET @strQuery += ' ORDER BY PH.Date DESC, PH.DocValue DESC,PH.ID DESC '                            
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID int, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @TransID, @Code, @ID, @Party, @FromDate, @ToDate, @Showall                            
                            
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

/****** uspGetSetPurchaseData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetPurchaseData]    
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN  @FromDate AND @ToDate' END    
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END    
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END    
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END    
SET @strQuery += ' ORDER BY PH.Date DESC,PH.DocValue desc,PH.ID'    
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall    
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN  @FromDate AND @ToDate' END    
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END    
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END    
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END    
SET @strQuery += ' ORDER BY PH.Date DESC,PH.ID '    
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall    
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
0 AS TCSTaxAmt,0 AS DiffExcl,0 AS DiffIncl,0 AS WriteOff,PH.PaymentModeID PaymentModeID    
FROM tblPurchaseOrderHeader PH    
JOIN tblMasterVendor MV ON MV.ID = PH.VendorID    
JOIN tblStatus STS ON STS.ID = PH.Status JOIN tblUsers CUR ON CUR.ID = PH.CBy    
left JOIN tblMasterBranchOffice MBO ON MBO.ID = PH.BranchID    
WHERE PH.TransID = 3 AND PH.Status in (1,3)'    
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN  @FromDate AND @ToDate' END    
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END    
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END    
--SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END    
SET @strQuery += 'ORDER BY PH.DocDate DESC,PH.DocValue desc,PH.ID '    
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall    
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
SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name UOM,SUM(Qty) Qty,0 FreeQty,0 DmgQty,MP.ProductDiscPerc ProdPern,0 TradePern,    
0 AddnlPern,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,MT.TaxName,PD.TaxPern TaxPern,SUM(GrossAmt) GoodsAmt,    
ISNULL(PTP.PurchaseBillPrice,0) PurchaseBillPrice,0 ReasonId,MP.LocationID,0 DiffAmt,SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,    
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,MP.MRP))* SUM(Qty) MRPonTaxAmt,0 ProdDiscAmt,0TradeDiscAmt,0 AddnlDiscAmt    
FROM tblPurchaseOrderDetail PD    
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID    
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID    
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID    
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = MP.ID    
where PD.HID = @ID    
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,ProductDiscPerc,Serial,MT.TaxName,PD.TaxPern,    
ISNULL(PTP.PurchaseBillPrice,0),MP.LocationID    
ORDER BY Serial    
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

/****** uspGetSetPurchaseReturnData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetPurchaseReturnData]
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
pv.ProdID = @Code  and BranchID =  @Party  and
TransDate <=  @FromDate 
GROUP BY PV.BatchNumber,PV.PKDDate,PV.ExpiryDate,PV.MRPONPrice,'+(case when (convert(nvarchar,@ID)) = '1' then 'PV.PurchasePrice '
else ' PV.ReturnPrice' end) +',ProdID '
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN  @FromDate AND @ToDate' END
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (3,5,6)' END
SET @strQuery += ' ORDER BY PH.Date DESC,DocValue desc,PH.ID'
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall
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
SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name UOM,SUM(UomQty) Qty,SUM(UomFreeQty) FreeQty,SUM(UomDamageQty) DmgQty,
PD.[ProdDisc%] ProdPern,PD.[TradeDisc%] TradePern,PD.[AddnlDisc%] AddnlPern,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,
MT.TaxName,PD.[Tax%] TaxPern,isnull(PD.ReasonId,0) ReasonId,MR.Name ReasonName,ISNULL(PTP.PurchaseReturnPrice,0) PurchaseReturnPrice
,ISNULL(PD.DiffAmt,0) DiffAmt,SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.MRP))* SUM(UomQty+UomDamageQty) MRPonTaxAmt,SUM(GoodsAmt) GoodsAmt,
ProdDiscAmt,TradeDiscAmt,AddnlDiscAmt
FROM tblTransPurchaseDetail PD
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID
LEFT JOIN TBLMASTERREASON MR ON MR.ID = PD.ReasonId
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = MP.ID
where PD.HID = @ID
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.[ProdDisc%],PD.[TradeDisc%],PD.[AddnlDisc%],
Serial,MT.TaxName,PD.[Tax%],isnull(PD.ReasonId,0),MR.Name,PTP.PurchaseReturnPrice,PD.DiffAmt,
ProdDiscAmt,TradeDiscAmt,AddnlDiscAmt
ORDER BY Serial
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN  @FromDate AND @ToDate' END
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (3,5,6)' END
SET @strQuery += ' ORDER BY PH.Date DESC,PH.ID DESC '
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall
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
SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name UOM,SUM(UomQty) Qty,SUM(UomFreeQty) FreeQty,SUM(UomDamageQty) DmgQty,
PD.[ProdDiscPern] ProdPern,PD.[TradeDiscPern] TradePern,PD.[AddnlDiscPern] AddnlPern,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,
MT.TaxName,PD.TaxPern TaxPern,isnull(PD.ReasonId,0) ReasonId,MR.Name ReasonName,ISNULL(PTP.PurchaseReturnPrice,0) PurchaseReturnPrice
,ISNULL(PD.DiffAmt,0) DiffAmt,SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,SUM(GoodsAmt) GoodsAmt,
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.MRP))* SUM(UomQty+UomDamageQty) MRPonTaxAmt,
ProdDiscAmt,TradeDiscAmt,AddnlDiscAmt
FROM tblPurchaseDraftDetail PD
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID
LEFT JOIN TBLMASTERREASON MR ON MR.ID = PD.ReasonId
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = MP.ID
where PD.HID = @ID
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.[ProdDiscPern],PD.[TradeDiscPern],PD.[AddnlDiscPern],Serial,MT.TaxName,PD.TaxPern
,isnull(PD.ReasonId,0),MR.Name,PTP.PurchaseReturnPrice,PD.DiffAmt,ProdDiscAmt,TradeDiscAmt,AddnlDiscAmt
ORDER BY Serial
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

/****** uspGetSetQuotationData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetQuotationData]                                      
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN  @FromDate AND @ToDate' END                                      
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END                                  
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                                      
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                                      
SET @strQuery += ' ORDER BY PH.DocDate DESC, DocValue desc,PH.ID'                                      
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall                                      
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN  @FromDate AND @ToDate' END                                      
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END                                      
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                                      
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                                      
SET @strQuery += ' ORDER BY PH.Date DESC,PH.ID DESC '                                      
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall                                      
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN  @FromDate AND @ToDate' END                                      
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END                                      
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                                      
--SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                                      
SET @strQuery += ' ORDER BY PH.ID DESC,DocDate '                                      
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall                                      
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

/****** uspGetSetSalesDamageReturnData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetSalesDamageReturnData]          
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
SET @strQuery += case when @Code > 0 then ' AND BSM.BeatID =  @Code' else '' end          
SET @strQuery += case when @ID > 0 and @AllowAllSM = 0 then ' AND BSM.SalesmanID =  @ID' else '' end          
SET @strQuery += ' group by MC.ID,Code,Name,BillAdd1 order by Name'          
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Docprefix int, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Docprefix, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall          
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
dbo.fnGetRoundedValue(PH.AdditionalDisc) AddnlDiscPern,dbo.fnGetRoundedValue(PH.AdditionalDiscAmt) AddnlDiscAmt,dbo.fnGetRoundedValue(PH.TradeDisc) TradeDiscPern,dbo.fnGetRoundedValue(PH.TotalTradeDiscAmt) TradeDiscAmt,          
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND InvDate BETWEEN  @FromDate AND @ToDate' END          
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END          
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END          
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (3,5,6,7)' END          
SET @strQuery += ' ORDER BY PH.InvDate DESC,DocValue desc,PH.ID'          
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Docprefix int, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Docprefix, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall          
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
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.DetailMRP)) MRPonTaxAmt,Serial into #sritems       
FROM tblTranSalesDetail PD          
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID          
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID          
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID          
LEFT JOIN TBLProductInventory PV ON PV.InventoryId = PD.InventoryID          
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = PD.ProdID          
where PD.InvID = @ID          
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.ProdDisc,PD.TradeDiscPern,PD.AddnlDiscPern,Serial,          
MT.TaxName,PD.TaxValue,PD.DetailMRP,PD.UomPrice,PD.TaxID,pd.ProdDiscAmt,AddnlDisc,TradeDisc,BaseUomPrice,PD.ReasonID          
,PV.BatchNumber,PV.PKDDate,PV.ExpiryDate,MP.TrackInventory,MP.TrackBatch,MP.TrackSerial,MP.TrackPDK,PTP.SalesReturnPrice,PD.DiffValue,          
PV.PurchasePrice,PV.SalesPrice,PV.ECP,PV.MRP, PV.SPLPrice, PV.ReturnPrice, PD.Serial          
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
drop table #sritems   
  
END          
IF(@Mode = 10)--Draft          
BEGIN          
SET @strQuery = 'SELECT PH.ID,DocID,CONVERT(NVARCHAR,Date,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(PH.GrossAmt) GrossAmt,          
dbo.fnGetRoundedValue(PH.TaxAmt) TaxAmt,dbo.fnGetRoundedValue(PH.NetAmt) NetAmt,          
STS.Description Status,dbo.fnGetRoundedValue(0) Balance,CUR.UserName UserName,          
CONVERT(NVARCHAR(100),PH.CDate) LastActionTime,PH.Status StatusID,PT.PriceType,MRT.Name ReturnType,PH.Remarks, PH.Narration,          
dbo.fnGetRoundedValue(PH.TotalTradeDiscAmt + PH.TotalProdDiscAmt + PH.TotalAddnlDiscAmt) AS TotalDiscAmt,dbo.fnGetRoundedValue(PH.TotalProdDiscAmt) TotalProdDiscAmt,          
dbo.fnGetRoundedValue(PH.AddnlDiscPern) AddnlDiscPern,dbo.fnGetRoundedValue(PH.TotalAddnlDiscAmt) AddnlDiscAmt,dbo.fnGetRoundedValue(PH.TradeDiscPern) TradeDiscPern,dbo.fnGetRoundedValue(PH.TotalTradeDiscAmt) TradeDiscAmt,          
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN  @FromDate AND @ToDate' END          
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END          
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END          
--SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END          
SET @strQuery += ' ORDER BY PH.Date DESC,PH.ID DESC '    EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Docprefix int, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Docprefix, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall          
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
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.MRP)) MRPonTaxAmt,PD.Serial into #srdraftitems     
FROM tblSalesDraftDetail PD          
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID          
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID          
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID          
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = PD.ProdID          
where PD.HID = @ID          
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.ProdDiscPern,PD.TradeDiscPern,PD.AddnlDiscPern,Serial,          
MT.TaxName,PD.TaxPern,PD.MRP,PD.SalePrice,PD.TaxID,pd.ProdDiscAmt,AddnlDiscAmt,TradeDiscAmt,PTP.SalesReturnPrice,PD.DiffValue,PD.ReasonID,MP.TrackInventory,          
MP.TrackBatch,MP.TrackSerial,MP.TrackPDK,ISNULL(PD.NewBatchCreated,0), PD.BtPPrice, PD.BtSPrice, PD.BtECP, PD.BtMRP          
, PD.BtSPLPrice, PD.BtRtnPrice, PD.HiddenRowID ,PD.BatchNo ,pd.PKDDate ,pd.ExpiryDate          
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
drop table #srdraftitems   
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
SET @strQuery = 'SELECT PH.ID,''WR''+CONVERT(NVARCHAR,PH.ID) DocID,CONVERT(NVARCHAR,DocDate,103) DocDate,RefNo,MBO.Name Branch,MV.Name Party,dbo.fnGetRoundedValue(SUM(PD.Price * Qty)) GrossAmt,          
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN  @FromDate AND @ToDate' END          
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END          
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END          
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END          
SET @strQuery += ' GROUP BY PH.ID,DocDate,RefNo,MBO.Name,MV.Name,STS.Description,CUR.UserName,PH.CDate,PH.Status,PT.PriceType,PH.Narration'      
SET @strQuery += ' ORDER BY PH.ID DESC,DocDate '          
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Docprefix int, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Docprefix, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall          
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
SUM(dbo.fngetMRPonCumValue(1,MP.SalesTaxID,1,PD.MRP)) MRPonTaxAmt, PD.SerialNo Serial into #srwsrtitems     
FROM tblTranorderreturndetail PD      
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID      
JOIN tblMasterUOM UOM ON UOM.ID = MP.BaseUOMID      
JOIN tblMasterTax MT ON MT.TaxID = MP.SalesTaxID      
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = PD.ProdID      
where PD.ID = @ID      
group by PD.ProdID,MP.BaseUOMID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.DisPern,SerialNo,      
MT.TaxName,PD.MRP,PD.Price,MT.TaxID,pd.DisAmt,OrgPrice,MP.TrackInventory,MP.TrackBatch,MP.TrackSerial,MP.TrackPDK,PTP.SalesReturnPrice,      
MP.PurchasePrice,MP.SalesPrice,MP.ECP,MP.MRP, MP.SPLPrice, MP.ReturnPrice,MP.SalesTaxID,MT.GST      
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
drop table #srwsrtitems   
  
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

/****** uspGetSetAutoIndentData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetAutoIndentData]                              
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN  @FromDate AND @ToDate' END                              
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END                              
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                              
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                              
SET @strQuery += ' GROUP BY PH.ID,DocID,Date,RefNo,MBO.Name,MV.Name,STS.Description,DocValue,CUR.UserName,PH.CDate,PH.Status,PH.Remarks,PH.Narration   
ORDER BY PH.Date DESC, PH.DocValue DESC,PH.ID DESC '                              
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall                              
                              
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND Date BETWEEN  @FromDate AND @ToDate' END                              
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END                              
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                              
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                              
SET @strQuery += ' GROUP BY PH.ID,DocID,Date,RefNo,MBO.Name,MV.Name,STS.Description,CUR.UserName,PH.CDate,PH.Status,PH.Remarks,PH.Narration    
ORDER BY PH.Date DESC,PH.ID DESC '                              
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall                              
                              
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

/****** uspGetSetInvoiceData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetInvoiceData]                      
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
SET @strQuery += case when @Code > 0 then ' AND BSM.BeatID =  @Code' else '' end                      
SET @strQuery += case when @ID > 0 and @AllowAllSM = 0 then ' AND BSM.SalesmanID =  @ID' else '' end                       
SET @strQuery += ' group by MC.ID,Code,Name,Billadd1 order by Name'                      
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall                      
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND InvDate BETWEEN  @FromDate AND @ToDate' END                      
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END                      
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                      
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                      
SET @strQuery += ' ORDER BY InvDate desc,DocValue desc,PH.ID'                 
PRINT @strQuery             
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall                      
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
SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,UOM.Name UOM,SUM(UomQty) Qty,PD.DetailMRP,PD.UomPrice ExclPrice,                      
dbo.fngetinclusivevalue(PD.TaxID,PD.DetailMRP,PD.UomPrice) InclPrice,                      
--(PD.UomPrice * (1 + (PD.TaxValue / 100))) InclPrice,                      
PD.ProdDisc ProdPern,pd.ProdDiscAmt,PD.TradeDiscPern TradePern,TradeDisc TradeDiscAmt,                      
PD.AddnlDiscPern AddnlPern,AddnlDisc AddnlDiscAmt,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,PD.TaxID,MT.TaxName,PD.TaxValue TaxPern,                      
SUM(GoodsAmt) GoodsAmt,BaseUomPrice,PV.BatchNumber BatchNo,PV.PKDDate PKD,PV.ExpiryDate Expiry,MP.TrackInventory,MP.TrackBatch,                      
MP.TrackPDK,mp.TrackSerial,ISNULL(PD.DiffValue,0) DiffValue,ISNULL(PTP.InvoicePrice,0) InvoicePrice ,ISNULL(QtyType,1) QtyType,                      
SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,                      
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.DetailMRP)) MRPonTaxAmt,MP.Shinecode,PD.Serial into #invitems                   
FROM tblTranSalesDetail PD                      
LEFT JOIN tblProductInventory PV ON PV.InventoryId = PD.InventoryID                      
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                      
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                      
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID                      
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = PD.ProdID                      
where PD.InvID = @ID                 
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.ProdDisc,PD.TradeDiscPern,PD.AddnlDiscPern,Serial,                      
MT.TaxName,PD.TaxValue,PD.DetailMRP,PD.UomPrice,PD.TaxID,pd.ProdDiscAmt,AddnlDisc,TradeDisc,BaseUomPrice,MP.Shinecode,                      
PV.BatchNumber,PV.PKDDate,PV.ExpiryDate,MP.TrackInventory,MP.TrackBatch,MP.TrackPDK,mp.TrackSerial,PD.DiffValue,        
PTP.InvoicePrice,QtyType ,PD.Serial                     
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
drop table #invitems

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
' AND Date BETWEEN  @FromDate AND @ToDate' END                      
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END                      
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                      
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1)' END                      
SET @strQuery += ' ORDER BY PH.Date desc,PH.ID DESC '                      
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall                     
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
SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,UOM.Name UOM,SUM(UOMQty) Qty,PD.MRP DetailMRP,PD.SalePrice ExclPrice,                      
dbo.fngetinclusivevalue(PD.TaxID,PD.MRP,PD.SalePrice) InclPrice,                      
--(PD.SalePrice * (1 + (TaxPern / 100))) InclPrice,                      
PD.ProdDiscPern ProdPern,pd.ProdDiscAmt,PD.TradeDiscPern TradePern,TradeDiscAmt,                      
PD.AddnlDiscPern AddnlPern,AddnlDiscAmt,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,PD.TaxID,MT.TaxName,PD.TaxPern TaxPern,                      
SUM(GoodsAmt) GoodsAmt,BaseUOMPrice,BatchNo,PKDDate PKD,ExpiryDate Expiry,MP.TrackInventory,MP.TrackBatch,MP.TrackPDK,mp.TrackSerial                      
,ISNULL(PD.DiffValue,0) DiffValue,ISNULL(PTP.InvoicePrice,0) InvoicePrice,ISNULL(QtyType,1) QtyType,                      
SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,                      
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.MRP)) MRPonTaxAmt,MP.Shinecode,Serial into #invitems1          
FROM tblSalesDraftDetail PD                      
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                      
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                      
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID                      
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = PD.ProdID                      
where PD.HID = @ID                      
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.ProdDiscPern,PD.TradeDiscPern,PD.AddnlDiscPern,Serial,                      
MT.TaxName,PD.TaxPern,PD.MRP,PD.SalePrice,PD.TaxID,pd.ProdDiscAmt,AddnlDiscAmt,TradeDiscAmt,BaseUOMPrice,BatchNo,PKDDate,ExpiryDate                      
,MP.TrackInventory,MP.TrackBatch,MP.TrackPDK,mp.TrackSerial,PD.DiffValue,PTP.InvoicePrice ,QtyType,MP.Shinecode                      
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
drop table #invitems1        

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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN  @FromDate AND @ToDate' END                      
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END                      
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                      
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3)' END                      
SET @strQuery += ' ORDER BY DocDate desc, DocValue desc,PH.ID'                      
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall                      
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
IF(@Mode = 18)    BEGIN                      
SELECT PD.ProdID,PD.UomID,MP.Code,MP.Name,UOM.Name UOM,SUM(Qty) Qty,PD.DetailMRP,PD.SalesPrice ExclPrice,                      
dbo.fngetinclusivevalue(PD.TaxID,PD.DetailMRP,PD.SalesPrice) InclPrice,                      
--(PD.SalesPrice * (1 + (TaxPercentage / 100))) InclPrice,                      
PD.ProdDiscPern ProdPern,pd.ProdDiscAmt,PD.TradeDiscPern TradePern,TradeDiscAmt TradeDiscAmt,                      
PD.AddnlDiscPern AddnlPern,AddnlDiscAmt AddnlDiscAmt,SUM(GrossAmt) GrossAmt,SUM(TaxAmt) TaxAmt,SUM(NetAmt) NetAmt,PD.TaxID,MT.TaxName,PD.TaxPercentage TaxPern,                      
SUM(GoodsAmt) GoodsAmt,PD.SalesPrice BaseUomPrice,''BatchNo,''PKD,''Expiry,MP.TrackInventory,MP.TrackBatch,MP.TrackPDK,mp.TrackSerial                      
,(ISNULL(PTP.InvoicePrice,0) - PD.SalesPrice) DiffValue,ISNULL(PTP.InvoicePrice,0) InvoicePrice,1 QtyType,                      
SUM(dbo.fngetMRPonCumValue(0,PD.TaxID,1,0)) CumMRPonTax,                      
SUM(dbo.fngetMRPonCumValue(1,PD.TaxID,1,PD.DetailMRP)) MRPonTaxAmt,MP.Shinecode,Serial into #invitems2          
FROM tblquotationdetail PD                      
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                      
JOIN tblMasterUOM UOM ON UOM.ID = PD.UomID                      
JOIN tblMasterTax MT ON MT.TaxID = PD.TaxID                      
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = PD.ProdID                      
where PD.QuationID = @ID                      
group by PD.ProdID,PD.UomID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.ProdDiscPern,PD.TradeDiscPern,PD.AddnlDiscPern,Serial,                      
MT.TaxName,PD.TaxPercentage,PD.DetailMRP,PD.SalesPrice,PD.TaxID,pd.ProdDiscAmt,AddnlDiscAmt,TradeDiscAmt                      
,MP.TrackInventory,MP.TrackBatch,MP.TrackPDK,mp.TrackSerial,PTP.InvoicePrice,MP.Shinecode                      
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
drop table #invitems2          
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN  @FromDate AND @ToDate' END                      
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END                      
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                      
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3)' END                      
SET @strQuery += ' group by PH.ID,DocDate,RefNo,MBO.Name,MV.Name,CUR.UserName,PH.CDate,STS.Description,PH.Status,PT.PriceType, PH.Narration,                      
PH.AdDiscPern,PH.TrDiscPern,MS.Name,MB.Name ORDER BY PH.DocDate desc,PH.ID DESC'                      
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall                      
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
SUM(dbo.fngetMRPonCumValue(1,MP.SalesTaxID,1,MP.MRP)) MRPonTaxAmt,MP.Shinecode,SerialNo Serial into #invitems3          
FROM tblTranOrderTakenDetail PD                      
join tblTranOrderTakenHeader PH ON PH.ID = PD.ID                      
JOIN tblMasterProduct MP ON MP.ID = PD.ProdID                      
JOIN tblMasterUOM UOM ON UOM.ID = MP.BaseUOMID                      
JOIN tblMasterTax MT ON MT.TaxID = MP.SalesTaxID                      
LEFT JOIN tblProductTransactionprices PTP ON PTP.ID = PD.ProdID                      
where PD.ID = @ID                      
group by PD.ProdID,MP.BaseUOMID,MP.Code,MP.Name,MP.HSNCode,UOM.Name,PD.DisPern,Ph.TrDiscPern,Ph.AdDiscPern,SerialNo,                    
MT.TaxName,MT.GST,MP.MRP,PD.Price,MP.SalesTaxID,pd.DisAmt,pd.DisAmt,                      
MP.TrackInventory,MP.TrackBatch,MP.TrackPDK,mp.TrackSerial,PD.OrgPrice,PTP.InvoicePrice,MP.Shinecode                      
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
drop table #invitems3          
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

/****** uspGetSetCollPayData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetCollPayData]                                                            
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
SET @strQuery += case when @Code > 0 then ' AND BSM.BeatID =  @Code' else '' end                          
SET @strQuery += case when @ID > 0 and @AllowAllSM = 0 then ' AND BSM.SalesmanID =  @ID' else '' end                          
SET @strQuery += ' group by MC.ID,Code,Name,MC.BillAdd1 order by Name'                          
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall                          
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND InvDate BETWEEN  @FromDate AND @ToDate' END                                                    
  
     
     
        
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MV.Name =  @Party' END                                                            
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                                                            
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                                                            
SET @strQuery += ' ORDER BY DocValue desc,PH.ID'                                                            
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall                                                            
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

/****** uspGetSetCreditDebitNoteData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetCreditDebitNoteData]                                                              
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN  @FromDate AND @ToDate' END                      
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND Party.AccountName =  @Party' END                
SET @strQuery += CASE WHEN ISNULL(@AccountName,'') = '' THEN '' ELSE ' AND FAA.AccountName =  @AccountName' END   
SET @strQuery += CASE WHEN ISNULL(@Branch,'') = '0' THEN '' ELSE ' AND ND.BranchID =  @Branch' END  
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND ND.Status in (1,3,5)' END                     
SET @strQuery += ' ORDER BY ND.DocDate DESC, ND.DocValue desc,ND.ID'                  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @ID NVARCHAR(MAX), @AccountName NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @Branch NVARCHAR(MAX)', @Mode, @TransID, @ID, @AccountName, @Party, @FromDate, @ToDate, @Showall, @Branch                  
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

/****** uspGetSetVoucherData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetVoucherData]                                                                      
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN  @FromDate AND @ToDate' END          
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND Party.AccountName =  @Party' END                        
SET @strQuery += CASE WHEN ISNULL(@AccountName,'') = '' THEN '' ELSE ' AND FAA.AccountName =  @AccountName' END     
SET @strQuery += CASE WHEN ISNULL(@Branch,'') = '0' THEN '' ELSE ' AND ND.BranchID =  @Branch' END  
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND ND.Status in (1,3,5)' END                         
SET @strQuery += ' ORDER BY ND.DocDate DESC, ND.DocValue desc,ND.ID'                      
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @ID NVARCHAR(MAX), @AccountName NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @Branch NVARCHAR(MAX)', @Mode, @TransID, @ID, @AccountName, @Party, @FromDate, @ToDate, @Showall, @Branch                       
                      
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

/****** uspGetSetOtherCollPayData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetOtherCollPayData]                          
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND ColDate BETWEEN  @FromDate AND @ToDate' END                              
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND Party.AccountName =  @Party' END                        
SET @strQuery += CASE WHEN ISNULL(@AccountName,'') = '' THEN '' ELSE ' AND FAA.AccountName =  @AccountName' END      
SET @strQuery += CASE WHEN ISNULL(@Branch,'') = '0' THEN '' ELSE ' AND ND.BranchID =  @Branch' END    
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND ND.Status in (1,3,5)' END                             
SET @strQuery += ' ORDER BY ND.ColDate DESC, ND.DocValue desc,ND.ColID'                          
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @AccountName NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @Branch NVARCHAR(MAX)', @Mode, @TransID, @Code, @ID, @AccountName, @Party, @FromDate, @ToDate, @Showall, @Branch                        
                      
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND PYDate BETWEEN  @FromDate AND @ToDate' END                              
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND Party.AccountName =  @Party' END                        
SET @strQuery += CASE WHEN ISNULL(@AccountName,'') = '' THEN '' ELSE ' AND FAA.AccountName =  @AccountName' END     
SET @strQuery += CASE WHEN ISNULL(@Branch,'') = '0' THEN '' ELSE ' AND ND.BranchID =  @Branch' END    
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND ND.Status in (1,3,5)' END                             
SET @strQuery += ' ORDER BY ND.PYDate DESC, ND.DocValue desc,ND.PYID'                          
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @AccountName NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @Branch NVARCHAR(MAX)', @Mode, @TransID, @Code, @ID, @AccountName, @Party, @FromDate, @ToDate, @Showall, @Branch                      
                      
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

/****** uspGetSetContraData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetContraData]                  
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN  @FromDate AND @ToDate' END                  
SET @strQuery += CASE WHEN ISNULL(@AccountName,'') = '0' THEN '' ELSE ' AND ND.FromFAID =  @AccountName' END       
SET @strQuery += CASE WHEN ISNULL(@Branch,'') = '0' THEN '' ELSE ' AND ND.BranchID =  @Branch' END      
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND ND.Status in (1,3,5)' END                  
SET @strQuery += ' ORDER BY ND.DocDate DESC, ND.DocValue desc,ND.ID'                  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @AccountName NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @Branch NVARCHAR(MAX)', @Mode, @TransID, @Code, @ID, @AccountName, @FromDate, @ToDate, @Showall, @Branch          
                  
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

/****** uspGetSetJournalEntryData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetJournalEntryData]                                                                  
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN  @FromDate AND @ToDate' END                      
SET @strQuery += CASE WHEN ISNULL(@AccountName,'') = '' THEN '' ELSE ' AND Party.AccountName =  @AccountName' END   
SET @strQuery += CASE WHEN ISNULL(@Branch,'') = '0' THEN '' ELSE ' AND ND.BranchID =  @Branch' END  
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND ND.Status in (1,3,5)' END                
SET @strQuery += ' ORDER BY ND.DocDate DESC, ND.DocValue desc,ND.JVID'                  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @AccountName NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @Branch NVARCHAR(MAX)', @Mode, @TransID, @Code, @ID, @AccountName, @FromDate, @ToDate, @Showall, @Branch                
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

/****** uspGetSetChequeDepositData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetChequeDepositData]        
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND CD.DocDate BETWEEN  @FromDate AND @ToDate' END                    
SET @strQuery += CASE WHEN ISNULL(@PartyName,'') = '' THEN '' ELSE ' AND FA.AccountName =  @PartyName' END              
SET @strQuery += CASE WHEN ISNULL(@AccountNo,'') = 0 THEN '' ELSE ' AND BA.FAID =  @AccountNo' END              
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND CD.Status in (1)' END                          
SET @strQuery += ' ORDER BY CD.DocDate DESC,CD.DocValue '
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @AccountNo NVARCHAR(MAX), @PartyName NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @TransID, @AccountNo, @PartyName, @FromDate, @ToDate, @Showall         
END      
END 
GO

/****** uspGetSetChequeBounceRealiseData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetChequeBounceRealiseData]      
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND CD.DocDate BETWEEN  @FromDate AND @ToDate' END                  
SET @strQuery += CASE WHEN ISNULL(@PartyName,'') = '' THEN '' ELSE ' AND FA.AccountName =  @PartyName' END            
SET @strQuery += CASE WHEN ISNULL(@AccountNo,'') = 0 THEN '' ELSE ' AND BA.FAID =  @AccountNo' END            
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND CD.Status in (1)' END      
SET @strQuery += ' order by CD.DocDate desc,CD.DocValue'
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @AccountNo NVARCHAR(MAX), @PartyName NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @TransID, @AccountNo, @PartyName, @FromDate, @ToDate, @Showall       
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND CD.DocDate BETWEEN  @FromDate AND @ToDate' END                  
SET @strQuery += CASE WHEN ISNULL(@PartyName,'') = '' THEN '' ELSE ' AND FA.AccountName =  @PartyName' END            
SET @strQuery += CASE WHEN ISNULL(@AccountNo,'') = 0 THEN '' ELSE ' AND BA.FAID =  @AccountNo' END       
SET @strQuery += ' order by CD.DocDate desc,CD.DocValue'
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @TransID INT, @AccountNo NVARCHAR(MAX), @PartyName NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @TransID, @AccountNo, @PartyName, @FromDate, @ToDate, @Showall       
END  
END    
GO

/****** uspGetSetInventoryAdjustmentData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetInventoryAdjustmentData]                
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND InventoryDate BETWEEN  @FromDate AND @ToDate' END                
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                
SET @strQuery += ' GROUP BY PH.InventoryID,DocID,InventoryDate,RefNo,MBO.Name,PH.TotalAmt,                
STS.Description,CUR.UserName,PH.CDate,PH.Status,PH.Remarks,DocValue,
PH.Narration ORDER BY InventoryDate desc,DocValue desc,PH.InventoryID'                
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall                
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

/****** uspGetSetInventoryConvertionData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetInventoryConvertionData]              
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND InventoryDate BETWEEN  @FromDate AND @ToDate' END              
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END              
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END              
SET @strQuery += ' ORDER BY InventoryDate DESC,DocValue desc,PH.InventoryID'              
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall              
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

/****** uspGetSetStockDestructionData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetStockDestructionData]    
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND InventoryDate BETWEEN  @FromDate AND @ToDate' END                    
SET @strQuery += CASE WHEN ISNULL(@ID,'') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                    
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END                    
SET @strQuery += ' ORDER BY InventoryDate DESC,DocValue desc,PH.InventoryID'                    
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @Code NVARCHAR(MAX), @ID NVARCHAR(MAX), @TransID int, @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int', @Mode, @Code, @ID, @TransID, @Party, @FromDate, @ToDate, @Showall                    
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

/****** uspGetSetBarcodeprint ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetBarcodeprint]          
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND DocDate BETWEEN  @FromDate AND @ToDate' END                            
SET @strQuery += CASE WHEN ISNULL(@ID,'0') = '0' THEN '' ELSE ' AND PH.BranchID =  @ID' END                            
SET @strQuery += CASE WHEN ISNULL(@Showall,'0') = '1' THEN '' ELSE ' AND PH.Status in (1,3,5)' END             
SET @strQuery += ' GROUP BY PH.ID,PH.Status,DocID,DocDate,RefNo,MBO.Name,STS.Description,CUR.UserName,PH.CDate,  
PH.Remarks,PH.Narration,DocValue ORDER BY DocDate DESC,DocValue Desc'      
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID NVARCHAR(MAX), @TransID int, @FromDate date, @ToDate date, @Showall int, @PriceID int', @Mode, @ID, @TransID, @FromDate, @ToDate, @Showall, @PriceID           
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

/****** uspGetSetAssignInvoices ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspGetSetAssignInvoices]  
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
SET @strQuery += CASE WHEN ISNULL(@FromDate,'') = '' OR ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND AINV.DocDate BETWEEN  @FromDate AND @ToDate' END  
SET @strQuery += CASE WHEN ISNULL(@Showall,'') = '1' THEN '' ELSE ' AND AINV.Status in (1,3,5)' END  
SET @strQuery += ' group by AINV.ID,DocID,AINV.DocDate ,RefNo,SM.Name ,sts.Description ,AINV.Status ,  
AINVD.Status,AINVD.InvID,AINVD.HID,CUR.UserName,AINV.CDate,AINV.Remarks,AINV.Narration,AINV.BranchID,MBO.Name  
) AS REC group by ID,DocID,DocDate,RefNo,Salesman,Status,StatusID,coldtl,DetailSts,InvoiceCount,UserName,LastActionTime,dtlOpen,  
dtlClose,dtlReturn,Remarks,Narration,BranchID,[Branch Name],AIVDATE) AS REC1  
GROUP BY ID,DocID,DocDate,RefNo,Salesman,Status,StatusID,DetailSts,InvoiceCount,UserName,LastActionTime,dtlOpen,dtlClose,dtlReturn,  
Remarks,Narration,BranchID,[Branch Name],AIVDATE,dtlOpen,dtlClose,dtlReturn order by AIVDATE DESC,DocID desc, ID DESC'  
print @strQuery
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID int, @Beat NVARCHAR(MAX), @Salesman NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @BranchID smallint, @BeatSMFilter int', @Mode, @ID, @Beat, @Salesman, @Party, @FromDate, @ToDate, @Showall, @BranchID, @BeatSMFilter  
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
SET @strQuery += CASE WHEN ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND SH.InvDate <=  @ToDate' END  
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MC.Name =  @Party' END  
SET @strQuery += CASE WHEN ISNULL(@BranchID,'0') = '0' THEN '' ELSE ' AND SH.BranchID =  @BranchID' END  
SET @strQuery += CASE WHEN ISNULL(@Beat,'0') = '0' THEN '' ELSE ' AND SH.BeatID =  @Beat' END  
SET @strQuery += CASE WHEN ISNULL(@Salesman,'0') = '0' THEN '' ELSE ' AND SH.SalesManID =  @Salesman' END  
SET @strQuery += ' order by SH.InvDate,SH.DocValue '  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID int, @Beat NVARCHAR(MAX), @Salesman NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @BranchID smallint, @BeatSMFilter int', @Mode, @ID, @Beat, @Salesman, @Party, @FromDate, @ToDate, @Showall, @BranchID, @BeatSMFilter  
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
SET @strQuery += CASE WHEN ISNULL(@ToDate,'') = '' THEN '' ELSE ' AND SH.InvDate <=  @ToDate' END  
SET @strQuery += CASE WHEN ISNULL(@Party,'') = '' THEN '' ELSE ' AND MC.Name =  @Party' END  
SET @strQuery += CASE WHEN ISNULL(@BranchID,'0') = '0' THEN '' ELSE ' AND SH.BranchID =  @BranchID' END  
SET @strQuery += CASE WHEN ISNULL(@Beat,'0') = '0' THEN '' ELSE ' AND BSM.BeatID =  @Beat' END  
SET @strQuery += CASE WHEN ISNULL(@Salesman,'0') = '0' THEN '' ELSE ' AND BSM.SalesManID =  @Salesman' END  
SET @strQuery += ' ) as rec  
group by ID,DocID,Date,RefNo,Beat,Salesman,Customer,NetAmt,Balance,Ageing,AssignedInvoiceCount,DocValue,BeatID,SalesManID,  
StatusID   
order by REC.Date,DocValue'  
EXEC sys.sp_executesql @strQuery, N'@Mode INT, @ID int, @Beat NVARCHAR(MAX), @Salesman NVARCHAR(MAX), @Party NVARCHAR(MAX), @FromDate date, @ToDate date, @Showall int, @BranchID smallint, @BeatSMFilter int', @Mode, @ID, @Beat, @Salesman, @Party, @FromDate, @ToDate, @Showall, @BranchID, @BeatSMFilter  
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

/****** uspCommonDocumentFilter ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: list-filter values are passed to sp_executesql as parameters instead of being concatenated into the SQL text.
ALTER PROCEDURE [dbo].[uspCommonDocumentFilter]          
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
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocRange,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT TRY_CAST(value AS int) FROM STRING_SPLIT(@DocRange, '','') WHERE LTRIM(RTRIM(value)) <> '''')' END)                                  
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@FilterBy,0)=1 THEN '' WHEN ISNULL(@FilterBy,0)=2 THEN ' AND IRN IS NOT NULL' ELSE ' AND IRN IS NULL' END)            
SET @StrQuery = @StrQuery +  ' GROUP BY SH.DocId,SH.InvDate,MC.Name,SH.DocValue,SH.DocRef,SH.NetAmt,SH.ReturnsTransType,MB.Name,MB.Name order by SH.DocValue'          
EXEC sys.sp_executesql @StrQuery, N'@Branch INT, @DocPreix INT, @FromDate DATE, @ToDate DATE, @DocRange NVARCHAR(MAX), @CustID NVARCHAR(MAX), @FilterBy int', @Branch, @DocPreix, @FromDate, @ToDate, @DocRange, @CustID, @FilterBy          
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
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocRange,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT TRY_CAST(value AS int) FROM STRING_SPLIT(@DocRange, '','') WHERE LTRIM(RTRIM(value)) <> '''')' END)                                  
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@FilterBy,0)=1 THEN '' WHEN ISNULL(@FilterBy,0)=2 THEN ' AND IRN IS NOT NULL' ELSE ' AND IRN IS NULL' END)            
SET @StrQuery = @StrQuery +  ' GROUP BY SH.DocId,SH.Date,MC.Name,SH.DocValue,SH.RefNo,SH.NetAmt order by SH.DocValue'          
EXEC sys.sp_executesql @StrQuery, N'@Branch INT, @DocPreix INT, @FromDate DATE, @ToDate DATE, @DocRange NVARCHAR(MAX), @CustID NVARCHAR(MAX), @FilterBy int', @Branch, @DocPreix, @FromDate, @ToDate, @DocRange, @CustID, @FilterBy          
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
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@DocRange,'')='' THEN '' ELSE ' AND SH.DocValue IN (SELECT TRY_CAST(value AS int) FROM STRING_SPLIT(@DocRange, '','') WHERE LTRIM(RTRIM(value)) <> '''')' END)                                  
SET @StrQuery = @StrQuery + (CASE WHEN ISNULL(@FilterBy,0)=1 THEN '' WHEN ISNULL(@FilterBy,0)=2 THEN ' AND IRN IS NOT NULL' ELSE ' AND IRN IS NULL' END)            
SET @StrQuery = @StrQuery +  ' GROUP BY SH.DocId,SH.DocDate,MC.Name,SH.DocValue,SH.RefNo,SH.NetAmt order by SH.DocValue'          
EXEC sys.sp_executesql @StrQuery, N'@Branch INT, @DocPreix INT, @FromDate DATE, @ToDate DATE, @DocRange NVARCHAR(MAX), @CustID NVARCHAR(MAX), @FilterBy int', @Branch, @DocPreix, @FromDate, @ToDate, @DocRange, @CustID, @FilterBy          
END 
END 
GO

/****** uspSyncMasterData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Security fix: @TableName must be enabled in tblWebshineMasterSyncTables.
ALTER PROCEDURE [dbo].[uspSyncMasterData]    
@sourcedbname NVARCHAR(128) = 'WSHINE_DEV001_APR2024',    
@TableName    NVARCHAR(128) = 'tblMasterBank',    
@SyncDate     DATETIME = '2026-08-10 19:14:32.937'    
AS
-- Security: only tables enabled for master sync may be synced; @TableName comes from the client.
IF NOT EXISTS (SELECT 1 FROM dbo.tblWebshineMasterSyncTables WHERE TableName = @TableName AND IsSync = 1)
BEGIN
    SELECT N'Table ' + ISNULL(@TableName, N'') + N' is not enabled for master sync.' MSG, 0 LINE, 50001 ENO;
    RETURN;
END    
BEGIN TRY    
BEGIN TRAN    
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
SELECT CustomerID FROM '+@sourcedbname+'.dbo.tblMasterCustomer MC    
JOIN '+@sourcedbname+'.dbo.tblBeatSalesmanMapping BSM ON BSM.CustomerID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate)    
    
INSERT INTO tblBeatSalesmanMapping    
SELECT BSM.CustomerID,BSM.BeatID,BSM.SalesmanID FROM '+@sourcedbname+'.dbo.tblMasterCustomer MC    
JOIN '+@sourcedbname+'.dbo.tblBeatSalesmanMapping BSM ON BSM.CustomerID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate '    
END    
IF(@TableName = 'tblMasterChequeBookDetail')    
BEGIN    
SET @qry = 'DELETE tblMasterChequeBookDetail WHERE ChequeBookID IN (    
SELECT ChequeBookID FROM '+@sourcedbname+'.dbo.tblMasterChequeBook MC    
WHERE COALESCE(MDate,CDate) >= @SyncDate)    
    
INSERT INTO tblMasterChequeBookDetail    
SELECT BSM.ChequeBookID,BSM.ChequeNo,BSM.Status FROM '+@sourcedbname+'.dbo.tblMasterChequeBook MC    
JOIN '+@sourcedbname+'.dbo.tblMasterChequeBookDetail BSM ON BSM.ChequeBookID = MC.ChequeBookID    
WHERE COALESCE(MDate,CDate) >= @SyncDate '    
END    
IF(@TableName = 'tblMasterCustomerRemarks')    
BEGIN    
SET @qry = 'DELETE tblMasterCustomerRemarks WHERE CustomerID IN (    
SELECT CustomerID FROM '+@sourcedbname+'.dbo.tblMasterCustomer MC    
JOIN '+@sourcedbname+'.dbo.tblMasterCustomerRemarks BSM ON BSM.CustomerID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate)    
    
INSERT INTO tblMasterCustomerRemarks    
SELECT BSM.CustomerID,BSM.CustomerRemarks FROM '+@sourcedbname+'.dbo.tblMasterCustomer MC    
JOIN '+@sourcedbname+'.dbo.tblMasterCustomerRemarks BSM ON BSM.CustomerID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate '    
END    
    
IF(@TableName = 'tblMasterTaxDetail')    
BEGIN    
SET @qry = 'DELETE tblMasterTaxDetail WHERE TaxID IN (    
SELECT MC.TaxID FROM '+@sourcedbname+'.dbo.tblMasterTax MC    
JOIN '+@sourcedbname+'.dbo.tblMasterTaxDetail BSM ON BSM.TaxID = MC.TaxID    
WHERE COALESCE(MDate,CDate) >= @SyncDate)    
    
INSERT INTO tblMasterTaxDetail    
SELECT BSM.TaxID,TaxTypeID,TaxCompID,TaxRate,AppOn,PartOff,CumulativeTax,GSTTaxType    
FROM '+@sourcedbname+'.dbo.tblMasterTax MC    
JOIN '+@sourcedbname+'.dbo.tblMasterTaxDetail BSM ON BSM.TaxID = MC.TaxID    
WHERE COALESCE(MDate,CDate) >= @SyncDate '    
END    
IF(@TableName = 'tblProductLocationMapping')    
BEGIN    
SET @qry = 'DELETE tblProductLocationMapping WHERE ProductID IN (    
SELECT MC.ID FROM '+@sourcedbname+'.dbo.tblMasterProduct MC    
JOIN '+@sourcedbname+'.dbo.tblProductLocationMapping BSM ON BSM.ProductID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate)    
    
INSERT INTO tblProductLocationMapping    
SELECT BSM.*    
FROM '+@sourcedbname+'.dbo.tblMasterProduct MC    
JOIN '+@sourcedbname+'.dbo.tblProductLocationMapping BSM ON BSM.ProductID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate '    
END    
IF(@TableName = 'tblMasterDiscountSchemeDetail')    
BEGIN    
SET @qry = 'DELETE tblMasterDiscountSchemeDetail WHERE ID IN (    
SELECT MC.ID FROM '+@sourcedbname+'.dbo.tblMasterDiscountSchemeHeader MC    
JOIN '+@sourcedbname+'.dbo.tblMasterDiscountSchemeDetail BSM ON BSM.ID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate)    
    
INSERT INTO tblMasterDiscountSchemeDetail    
SELECT BSM.*    
FROM '+@sourcedbname+'.dbo.tblMasterDiscountSchemeHeader MC    
JOIN '+@sourcedbname+'.dbo.tblMasterDiscountSchemeDetail BSM ON BSM.ID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate '    

SET @qry += ' DELETE tblMasterDiscountSchemeCustomers WHERE ID IN (    
SELECT MC.ID FROM '+@sourcedbname+'.dbo.tblMasterDiscountSchemeHeader MC    
JOIN '+@sourcedbname+'.dbo.tblMasterDiscountSchemeCustomers BSM ON BSM.ID = MC.ID    
WHERE COALESCE(MDate,CDate) >= @SyncDate)    
    
INSERT INTO tblMasterDiscountSchemeCustomers    
SELECT BSM.*    
FROM '+@sourcedbname+'.dbo.tblMasterDiscountSchemeHeader MC    
JOIN '+@sourcedbname+'.dbo.tblMasterDiscountSchemeCustomers BSM ON BSM.ID = MC.ID    
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
SELECT Role FROM '+@sourcedbname+'.dbo.tblRolePermissions MC    
WHERE CDate >= @SyncDate)    
    
INSERT INTO tblRolePermissions    
SELECT MC.* FROM '+@sourcedbname+'.dbo.tblRolePermissions MC    
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

