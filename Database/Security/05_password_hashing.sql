/* =====================================================================================
   05  Password hashing - database side (point 9)

   WHAT THIS DOES
     - uspGetUserCredential   (new)  returns the stored password value for an active user name,
                                      so the API can verify the password in C# (PBKDF2).
     - uspSetUserPasswordHash (new)  replaces a user's stored value with a new hash, only if it
                                      still equals the value that was just verified.
     - uspManageUsers         mode 2 (edit user): an empty/NULL @Password keeps the current
                                      password (the edit form can no longer show it), and the
                                      history copy no longer stores the password.
     - uspGetModifyHistoryData       user history shows ******** instead of the stored password.
     Nothing else changes. Login (mode 6), create (mode 1) and reset (mode 9) are unchanged in
     SQL: the API now passes a hash instead of ciphertext.

   ORDER
     Run this BEFORE deploying the new API/UI build. It is compatible with the current build
     (the current API always sends a non-empty password and does not call the new procedures).

   AFTER DEPLOYING THE NEW BUILD
     Each user's password is converted to a hash the next time they log in. Check progress with
     the query at the end; force a reset for anyone still on the old format after a few weeks.

   UNDO: 05_rollback_password_hashing.sql (see the warning in that file).
   ===================================================================================== */
SET NOCOUNT ON;
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspGetUserCredential]
    @UserName nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    -- Same match as uspManageUsers mode 6 (Active = 1 AND UserName = @UserName).
    SELECT ID, Password FROM dbo.tblUsers WHERE Active = 1 AND UserName = @UserName;
END
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[uspSetUserPasswordHash]
    @ID smallint, @OldPassword nvarchar(max), @NewPassword nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    -- Only replaces the value that was just verified (no lost update if it changed meanwhile).
    UPDATE dbo.tblUsers SET Password = @NewPassword
    WHERE ID = @ID AND Password = @OldPassword AND @NewPassword LIKE N'PBKDF2$%';
    SELECT @@ROWCOUNT AS Updated;
END
GO
/****** uspManageUsers ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[uspManageUsers]      
@Mode INT,@ID smallint = null,@UserName nvarchar(MAX) = null,@Password nvarchar(MAX) = null,@Mobilenumber nvarchar(MAX) = null,@EMailID nvarchar(MAX) = null,      
@RoleID smallint = null,@PwdResetCount tinyint = null,@PwdResetTime datetime = null,@LPin int = null,@Active bit = null,@UserID smallint = null      
as      
begin      
BEGIN TRY      
IF(@Mode = 1)      
BEGIN      
IF((SELECT count(*) FROM tblUsers WHERE UserName = @UserName) > 0)      
BEGIN      
RAISERROR('User Name already exists',16,1)      
END      
IF((SELECT count(*) FROM tblUsers WHERE Mobilenumber = @Mobilenumber and isnull(Mobilenumber,'') != '') > 0)      
BEGIN      
RAISERROR('Mobile No already exists',16,1)      
END      
IF((SELECT count(*) FROM tblUsers WHERE EMailID = @EMailID and isnull(EMailID,'') != '') > 0)      
BEGIN      
RAISERROR('EMail ID already exists',16,1)      
END      
SET @UserName = (select dbo.ProperCase(@UserName))      
insert into tblUsers(UserName,Password,Mobilenumber,EMailID,RoleID,Active,CBy,CDate)      
Values (@UserName,@Password,@Mobilenumber,lower(@EMailID),ISNULL(@RoleID,0),@Active,@UserID, GETDATE())      
SELECT SCOPE_IDENTITY()      
END      
IF(@Mode = 2)      
BEGIN      
IF((SELECT count(*) FROM tblUsers WHERE UserName = @UserName and ID != @ID) > 0)      
BEGIN      
RAISERROR('User Name already exists',16,1)      
END      
IF((SELECT count(*) FROM tblUsers WHERE Mobilenumber = @Mobilenumber and ID != @ID and isnull(@Mobilenumber,'') != '') > 0)      
BEGIN      
RAISERROR('Mobile No already exists',16,1)      
END      
IF((SELECT count(*) FROM tblUsers WHERE EMailID = @EMailID and ID != @ID and isnull(EMailID,'') != '') > 0)      
BEGIN      
RAISERROR('EMail ID already exists',16,1)      
END      
INSERT INTO tblMasterHistory (FormID,ID,Name,Column1,Column2,Column3,Column4,Column5,Column6,Column7,Active,CBy,CDate,MBy,MDate,HisCBy,HisCDate)      
(select 29,ID, UserName, NULL, Mobilenumber, EMailID, RoleID, PwdResetCount, PwdResetTime, LPin, Active, CBy, CDate, MBy, MDate,      
@UserID, GETDATE() from tblUsers where ID = @ID)      
SET @UserName = (select dbo.ProperCase(@UserName))      
UPDATE tblUsers SET UserName = @UserName,Password = COALESCE(NULLIF(@Password, N''), Password), Mobilenumber = @Mobilenumber,EMailID = lower(@EMailID),      
Active = @Active,MBy = @UserID ,MDate = GETDATE(), RoleID = (CASE WHEN @UserID = @ID THEN RoleID ELSE @RoleID END) WHERE ID = @ID      
  
UPDATE tblMobileLogin SET SessionStatus = 0 WHERE UserID = @ID      
SELECT @ID      
END      
IF(@Mode = 3)      
BEGIN      
SELECT UR.ID,UR.UserName,UR.Password,UR.Mobilenumber,UR.EMailID,UR.RoleID,MR.Name RoleName,UR.PwdResetCount,UR.PwdResetTime,UR.LPin,      
UR.CBy,UR.Active,CASE WHEN ISNULL(UR.MBy,0) = 0 THEN CUR.UserName ELSE MUR.UserName END AUserName,      
CASE WHEN ISNULL(UR.MBy,0) = 0 THEN CONVERT(NVARCHAR(100),UR.CDate) ELSE CONVERT(NVARCHAR(100),UR.MDate) END LastActionTime,      
UR.ImgData      
from tblUsers UR      
LEFT JOIN tblMasterRole MR ON MR.ID = UR.RoleID      
LEFT JOIN tblUsers CUR ON CUR.ID = UR.CBy      
LEFT JOIN tblUsers MUR ON MUR.ID = UR.MBy      
where UR.ID > 1 order by UR.UserName      
END      
IF(@Mode = 4)      
BEGIN      
SELECT UR.ID,UR.UserName,UR.Password,UR.Mobilenumber,UR.EMailID,UR.RoleID,MR.Name RoleName,UR.PwdResetCount,UR.PwdResetTime,      
UR.LPin,UR.CBy,UR.Active,CASE WHEN ISNULL(UR.MBy,0) = 0 THEN CUR.UserName ELSE MUR.UserName END AUserName,      
CASE WHEN ISNULL(UR.MBy,0) = 0 THEN CONVERT(NVARCHAR(100),UR.CDate) ELSE CONVERT(NVARCHAR(100),UR.MDate) END LastActionTime,      
UR.ImgData      
from tblUsers UR      
LEFT JOIN tblMasterRole MR ON MR.ID = UR.RoleID      
left JOIN tblUsers CUR ON CUR.ID = UR.CBy      
LEFT JOIN tblUsers MUR ON MUR.ID = UR.MBy      
where UR.ID = @ID --and UR.ID > 1      
END      
IF(@Mode = 5)      
BEGIN      
update tblUsers set Active = 1 where ID = @ID    
select UserName from tblUsers where ID = @ID    
END      
IF(@Mode = 6)      
BEGIN      
SELECT *,(select UpdateClsDate from tblCompanyRegistration where CompanyId = 1) UpdateClsDate,      
(select ExpiryDate from tblCompanyRegistration where CompanyId = 1) ExpiryDate ,
(select WebDevices from tblCompanyRegistration where CompanyId = 1) WebDevices 
from tblUsers where Active = 1 and UserName = @UserName and Password = @Password      
--update tblUsers set pwdresettime = GETDATE() where UserName = @UserName and Password = @Password      
END      
IF(@Mode = 7)      
BEGIn      
if(isnull(@ID,0) = 1)      
begin      
SELECT * from tblMasterRole order by Name      
end      
else if(isnull(@ID,0) >= 2)      
begin      
SELECT * from tblMasterRole WHERE ID > 2 order by Name      
end      
END      
IF(@Mode = 8)      
BEGIN      
SELECT * from tblUsers where UserName = @UserName and EMailID = @Password      
END      
IF(@Mode = 9)      
BEGIN      
update tblUsers set Password = @Password where UserName = @UserName and EMailID = @EMailID      
END      
END TRY      
BEGIN CATCH      
SELECT ERROR_MESSAGE() MSG,ERROR_LINE() LINE,ERROR_PROCEDURE() [PROC]      
END CATCH      
END
GO

/****** uspGetModifyHistoryData ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[uspGetModifyHistoryData]          
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
WHERE FormID = '+convert(nvarchar,@FormID)+' and MH.ID = '+convert(nvarchar,@ID)+' AND MH.HisCBy = '+convert(nvarchar,@UserID)+          
' AND CONVERT(DATE,MH.HisCDate) BETWEEN '''+convert(nvarchar,@FromDate)+''' AND '''+convert(nvarchar,@ToDate )+'''          
UNION ALL          
SELECT 2,MH.ID,Name,CASE WHEN MH.Active = 1 THEN ''YES'' else ''NO'' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MH.CDATE) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MH.MDATE) [Modified Date],'
set @strQuery += case when @FormID = 2 then 'PLName [Pref Lang Name],' else '' end
set @strQuery += '0 FROM '+@TableName+' MH          
JOIN tblUsers MUC ON MUC.ID = MH.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MH.Mby WHERE MH.ID = '+convert(nvarchar,@ID)+') AS REC          
ORDER BY IDX,Ident '    
exec(@strQuery)          
END          
ELSE IF(@FormType = 2)          
BEGIN          
SET @strQuery = ' SELECT ID,Name,Value,Active,[Created By],[Created Date],[Modified By],[Modified Date] FROM (          
SELECT 1 IDX,MH.ID,Name,Column1 Value,CASE WHEN MH.Active = 1 THEN ''YES'' else ''NO'' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MH.CDATE) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MH.MDATE) [Modified Date],Ident          
FROM tblMasterHistory MH          
JOIN tblUsers MUC ON MUC.ID = MH.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MH.Mby          
WHERE FormID = '+convert(nvarchar,@FormID)+' and MH.ID = '+convert(nvarchar,@ID)+' AND MH.HisCBy = '+convert(nvarchar,@UserID)+          
' AND CONVERT(DATE,MH.HisCDate) BETWEEN '''+convert(nvarchar,@FromDate)+''' AND '''+convert(nvarchar,@ToDate )+'''          
UNION ALL          
SELECT 2,MH.ID,Name,Value,CASE WHEN MH.Active = 1 THEN ''YES'' else ''NO'' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MH.CDATE) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MH.MDATE) [Modified Date],0          
FROM '+@TableName+' MH          
JOIN tblUsers MUC ON MUC.ID = MH.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MH.Mby WHERE MH.ID = '+convert(nvarchar,@ID)+') AS REC          
ORDER BY IDX,Ident '          
exec(@strQuery)          
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
SELECT 1 IDX,MS.ID,MS.Name [User Name],N'********' [Key],Column2 [Mobile No],Column3 [EMail ID],MT.Name [Role],          
CASE WHEN MS.Active = 1 THEN 'YES' else 'NO' End Active,MUC.UserName [Created By],CONVERT(NVARCHAR,MS.CDate) [Created Date],          
MUM.UserName [Modified By],CONVERT(NVARCHAR,MS.MDate) [Modified Date],Ident FROM tblMasterHistory MS          
LEFT JOIN tblMasterRole MT ON MT.ID = MS.Column4          
JOIN tblUsers MUC ON MUC.ID = MS.Cby          
LEFT JOIN tblUsers MUM ON MUM.ID = MS.Mby          
WHERE FormID = @FormID AND MS.HisCBy = @UserID and MS.ID = @ID AND CONVERT(DATE,MS.HisCDate) BETWEEN @FromDate and @ToDate          
UNION ALL          
SELECT 2,MS.ID,MS.UserName,N'********',MS.Mobilenumber,MS.EMailID,MT.Name Roles,          
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

/* Progress: users still on the old (reversible) format. */
SELECT COUNT(*) AS legacy_password_users FROM dbo.tblUsers WHERE Password IS NOT NULL AND Password NOT LIKE N'PBKDF2$%';
GO

/* OPTIONAL clean-up (irreversible): older history rows hold copies of users' old encrypted
   passwords (tblMasterHistory.Column1 for FormID 29). They are not needed by the app and can be
   decrypted with the key in source. Uncomment to remove them.
-- UPDATE dbo.tblMasterHistory SET Column1 = NULL WHERE FormID = 29 AND Column1 IS NOT NULL;
*/