using Microsoft.Ajax.Utilities;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;

namespace SampWebApi.Models
{
    public class SingleMasterModel
    {
        public string ID { get; set; }
        public string Name { get; set; }
        public string Active { get; set; }
        public string UserID { get; set; }
        public string Mode { get; set; }
        public string FormID { get; set; }
        public string Value { get; set; }
        public string CBy { get; set; }
        public string CDate { get; set; }
        public List<clsMenuorder> lstMenus { get; set; }
        public List<clsDocSeries> lstDocSeries { get; set; }
    }
    public class clsMenuorder
    {
        public string MenuID { get; set; }
        public string Order { get; set; }
    }
    public class clsDocSeries
    {
        public string ID { get; set; }
        public string TransName { get; set; }
        public string Prefix { get; set; }
        public string DocValue { get; set; }
    }
    public class SaveMessage
    {
        public string ID { get; set; }
        public string MsgID { get; set; }
        public string Message { get; set; }
        public string RowID { get; set; }
        public string FilePath { get; set; }
        public string FileName { get; set; }
    }
    public class BankAccount
    {
        public string Mode { get; set; }
        public string ID { get; set; }
        public string AccountNo { get; set; }
        public string AccountName { get; set; }
        public string BankID { get; set; }
        public string BranchName { get; set; }
        public string BankName { get; set; }
        public string IFSCCode { get; set; }
        public string MICR { get; set; }
        public string Active { get; set; }
        public string SetDefault { get; set; }
        public string UserID { get; set; }
        public string CBy { get; set; }
        public string CDate { get; set; }
    }
    public class FinancialAccount
    {
        public string Mode { get; set; }
        public string ID { get; set; }
        public string AccountName { get; set; }
        public string FaGroup { get; set; }
        public string OpenBalance { get; set; }
        public string PAN { get; set; }
        public string SACCode { get; set; }
        public string FAType { get; set; }
        public string UserAccount { get; set; }        
        public string Active { get; set; }
        public string UserID { get; set; }
        public string CloseBal { get; set; }
        public string CrDr { get; set; }
        public string UserName { get; set; }
        public string LastActionTime { get; set; }
        public string CBy { get; set; }
        public string CDate { get; set; }

    }
    public class FinancialAccountGroup
    {
        public string Mode { get; set; }
        public string ID { get; set; }
        public string FAGrpName { get; set; }
        public string TypeID { get; set; }
        public string TypeName { get; set; }
        public string ParentGrp { get; set; }
        public string LevelID { get; set; }
        public string UserAccount { get; set; }
        public string Active { get; set; }
        public string UserID { get; set; }
        public string UserName { get; set; }
        public string LastActionTime { get; set; }
        public string CBy { get; set; }
        public string CDate { get; set; }


    }
    public class Salesman
    {
        public string Mode { get; set; }
        public string ID { get; set; }
        public string Name { get; set; }
        public string DOB { get; set; }
        public string DOJ { get; set; }
        public string MobileNo { get; set; }
        public string AadharNo { get; set; }
        public string PANNumber { get; set; }
        public string Address { get; set; }
        public string SalesmanGroupID { get; set; }
        public string SalesmanGroupName { get; set; }
        public string Active { get; set; }
        public string UserID { get; set; }
        public string CBy { get; set; }
        public string CDate { get; set; }
    }
    public class BranchOffice
    {
        public string Mode { get; set; }
        public string ID { get; set; }
        public string Code { get; set; }
        public string Name { get; set; }
        public string Billadd1 { get; set; }
        public string Billadd2 { get; set; }
        public string Billadd3 { get; set; }
        public string ContactPerson { get; set; }
        public string Ph1 { get; set; }
        public string Mob1 { get; set; }
        public string Email { get; set; }
        public string StateID { get; set; }
        public string IfRegister { get; set; }
        public string GSTIN { get; set; }
        public string Active { get; set; }
        public string UserID { get; set; }
        public string CBy { get; set; }
        public string CDate { get; set; }
    }
    public class Vehicle
    {
        public string Mode { get; set; }
        public string ID { get; set; }
        public string VehicleNo { get; set; }
        public string VehicleName { get; set; }
        public string DOPurchase { get; set; }
        public string InsuranceDate { get; set; }
        public string InsuranceExpire { get; set; }
        public string FCDate { get; set; }
        public string Active { get; set; }
        public string UserID { get; set; }
        public string CBy { get; set; }
        public string CDate { get; set; }
    }
    public class Service
    {
        public string Mode { get; set; }
        public string ID { get; set; }
        public string Name { get; set; }
        public string TaxID { get; set; }
        public string TaxName { get; set; }
        public string SACCode { get; set; }
        public string Inwardprice { get; set; }
        public string Outwardprice { get; set; }
        public string Active { get; set; }
        public string UserID { get; set; }
        public string CBy { get; set; }
        public string CDate { get; set; }
    }
    public class Users
    {
        public string Mode { get; set; }
        public string ID { get; set; }
        public string UserName { get; set; }
        public string Password { get; set; }
        public string Mobilenumber { get; set; }
        public string EMailID { get; set; }
        public string RoleID { get; set; }
        public string RoleName { get; set; }
        public string PwdResetCount { get; set; }
        public string PwdResetTime { get; set; }
        public string LPin { get; set; }
        public string Active { get; set; }
        public string UserID { get; set; }
        public string BeatID { get; set; }
        public string SalesmanID { get; set; }
        public string BranchID { get; set; }
        public string CBy { get; set; }
        public string CDate { get; set; }
    }
    public class Chequebook
    {
        public string Mode { get; set; }
        public string ID { get; set; }
        public string Refno { get; set; }
        public string BankAccID { get; set; }
        public string BankAccName { get; set; }
        public string StartingNo { get; set; }
        public string NoofLeaves { get; set; }
        public string Active { get; set; }
        public string UserID { get; set; }
        public string CBy { get; set; }
        public string CDate { get; set; }
        public List<ChequebookDetil> CBDetails { get; set; }
    }
    public class ChequebookDetil
    {
        public string ID { get; set; }
        public string ChequeNo { get; set; }
        public string Status { get; set; }
    }
    public class ColorSettings
    {
        public string ThemeID { get; set; }
        public string UID { get; set; }
        
        public string MenuHeader { get; set; }
        public string AddButton { get; set; }
        public string DraftButton { get; set; }
        public string SaveButton { get; set; }
        public string ClearButton { get; set; }
        public string CloseButton { get; set; }
        public string PDFButton { get; set; }
        public string PreviewButton { get; set; }
        public string PopupHeader { get; set; }
        public string PopupFooter { get; set; }
        public string ConfirmPopupYes { get; set; }
        public string ConfirmPopupNo { get; set; }
        public string SubMenuColor { get; set; }
        public string MenuColor { get; set; }
        public string CompanyNameColor { get; set; }
        public string GridHeaderBackGround { get; set; }
        public string GridHeaderTextColor { get; set; }
        public string PopupHeaderText { get; set; }

        public string AutocompleteBG { get; set; }
        public string AutocompleteLine1 { get; set; }
        public string AutocompleteLine2 { get; set; }

    }
    public class ApplicationConfig
    {
        public string Mode { get; set; }
        public string CaseType { get; set; }
        public string Confirmpopup { get; set; }
        public string ClearConfirmpopup { get; set; }
        public string CloseConfirmpopup { get; set; }
        public string Roundoff { get; set; }
        public string RoundoffValue { get; set; }
        public string SMTPHost { get; set; }
        public string EMail { get; set; }
        public string Password { get; set; }
        public string UserID { get; set; }
        public string BackupPath { get; set; }
        
        public string DecimalValues { get; set; }
        public string Showallstatus { get; set; }
        public string DefaultBranch { get; set; }
        public string EnableReturnPrice { get; set; }
        public string VisaPern { get; set; }
        public string DefaultCustID { get; set; }
        public string UPIID { get; set; }
        public string UPIName { get; set; }
        public string WriteoffAmt { get; set; }
        public string AllSalesmanInvoice { get; set; }
        public string AllowPrint {  get; set; }
        public string ApplySchemeinQuotation { get; set; }
        public string SelectinvoiceinSR { get; set; }
        public string InvoiceStockOnlyProduct { get; set; }
        public string FilterDate { get; set; }        
        public string PurchaseOneView { get; set; }
        public string SalesOneView { get; set; }       
        public string ItemsperPage { get; set; }
        public string Invoiceallowduplicateitem { get; set; }
        public string CommonAgeingCreditDays { get; set; }
        public string RestrictBlocklistinInvoice { get; set; }
        public string RetainDate {  get; set; }
        public string BeatMandatoryinCustomer { get; set; }
        public List<PaymodeAppconfig> lstPaymode { get; set; }
        public List<PasswordSettingAppconfig> lstConfigPasswords { get; set; }
        
    }
    public class PaymodeAppconfig
    {
        public string TypeID { get; set; }
        public string ID { get; set; }
        public string Name { get; set; }
        public string Active { get; set; }
        public string Order { get; set; }
        public string Code { get; set; }
    }
    public class PasswordSettingAppconfig
    {
        public string ID { get; set; }
        public string Name { get; set; }
        public string Value { get; set; }
        public string Active { get; set; }
        public string Passwords { get; set; }
    }
    public class ReportParameters
    {
        public string ParameterID { get; set; }
        public string ReportID { get; set; }
        public string ParameterName { get; set; }
        public string ParameterType { get; set; }
        public string IsMandatory { get; set; }
        public string ParamOrder { get; set; }
        public string AutolistName { get; set; }
        public string ProcedureName { get; set; }
        public string SendFiltersDetail { get; set; }

        public List<ReportFilters> lstvFilters { get; set; }
    }
    public class ReportFilters
    {
        public string Param1 { get; set; }
        public string Param2 { get; set; }
        public string Param4 { get; set; }
        public string Param3 { get; set; }
        public string Param5 { get; set; }
    }
    public class CompanyDeatils{
        public string CompanyId { get; set; }
        public string CompanyCode { get; set; }
        public string CompanyName { get; set; }
        public string StateID { get; set; }
        public string Address { get; set; }
        public string Country { get; set; }
        public string State { get; set; }
        public string City { get; set; }
        public string Pincode { get; set; }
        public string Contact_Person { get; set; }
        public string MobileNo { get; set; }
        public string PhoneNo { get; set; }
        public string Website { get; set; }
        public string Email { get; set; }
        public string FSSAI { get; set; }
        public string AadharNo { get; set; }
        public string PANNo { get; set; }
        public string GSTIN { get; set; }
        public string Dl_20 { get; set; }
        public string Dl_21 { get; set; }
        
        public List<PaymodeAppconfig> lstState { get; set; }
    }
    public class DiscountScheme
    {
        public string ID { get; set; }
        public string Name { get; set; }
        public string Active { get; set; }
        public string UserID { get; set; }
        public string Mode { get; set; }
        public string FormID { get; set; }
        public string ReplaceExists { get; set; }
        public string FromDate { get; set; }
        public string ToDate { get; set; }
        public string lstCustomers { get; set; }
        public string lstProducts { get; set; }
        public string CustomerCount { get; set; }
        public string ProductCount { get; set; }
        public string CBy { get; set; }
        public string CDate { get; set; }
        public List<DiscountSchemeCustomer> lstSchemeCustomer { get; set; }
        public List<DiscountSchemeProduct> lstSchemeProduct { get; set; }
    }
    public class DiscountSchemeCustomer
    {
        public string SchemeID { get; set; }
        public string CustomerID { get; set; }
        public string Code { get; set; }    
        public string Name { get; set; }
    }
    public class DiscountSchemeProduct
    {
        public string SchemeID { get; set; }
        public string ProductID { get; set; }
        public string Code { get; set; }
        public string Name { get; set; }
        public string ProdDiscPern { get; set; }
        public string ProdDiscAmt { get; set; }
        public string TradeDiscPern { get; set; }
        public string TradeDiscAmt { get; set; }
    }
    public class ImportResults
    {
        public string ID { get; set; }
        public string Total { get; set; }
        public string Saved { get; set; }
        public string UnSaved { get; set; }
        public string Msg { get; set; }
        public string FileName { get; set; }
        public string FilePath { get; set; }
    }
    public class SystemApprovalModel
    {
        public string UserName { get; set; }
        public string MobileNo { get; set; }
        public string DeviceName { get; set; }
        public string Activate { get; set; }
        public string UserID { get; set; }
        public string DeviceID { get; set; }
        public string DeActivate { get; set; }
        public string DBName { get; set; }
    }
    public class OneViewData
    {
        public string ID { get; set; }
        public string Code { get; set; }
        public string Name { get; set; }
        public string Address { get; set; }
        public string MobNo { get; set; }
        public string PhNo { get; set; }
        public string EMail { get; set; }
        public string GSTIN { get; set; }
        public string PANNO { get; set; }
        public string RatingID { get; set; }
        public string RatingName { get; set; }
        public string LastTransDate { get; set; }

        public string YearlySale { get; set; }
        public string YearlyReturn { get; set; }
        public string MonthlySale { get; set; }
        public string MonthlyReturn { get; set; }
        public string OutstandingDetails { get; set; }
        public string TopProductsDetails { get; set; }
        public string ChequeDetails { get; set; }
        public string LedgetDetails { get; set; }
        public string PartyDetails { get; set; }
        public string TransDetails { get; set; }
        public string MonthlySalesDetails { get; set; }
    }
    public class ReportModel
    {
        public string ReportID { get; set; }
        public string TableID { get; set; }
        public string ColumnID { get; set; }
        public string ColumnName { get; set; }
        public string DisplayColumnName { get; set; }
        public string Width { get; set; }
        public string Visible { get; set; }
        public string Alignment { get; set; }
        public string DisplayIndex { get; set; }
        public string IsHiddenColumn { get; set; }
        public string Total { get; set; }
        public string TotalYN { get; set; }
    }
    public class ReportColumnDataModel
    {
        public string field { get; set; }
        public bool visible { get; set; }
        public string width { get; set; }
        public string textAlign { get; set; }
        public bool showInColumnChooser { get; set; }
        public string headerText { get; set; }
        public string Total { get; set; }
        public string TotalYN { get; set; }
    }
    public class MapRoleModel
    {
        public MapRoleModel()
        {
            children = new List<MapRoleModel>();
        }
        public int UserID { get; set; }
        public IEnumerable<SelectListItem> UserName { get; set; }
        public string id { get; set; }
        public string text { get; set; }
        public clsState state { get; set; }
        public List<MapRoleModel> children { get; set; }
    }
    public class clsState
    {
        public bool selected { get; set; }

        public clsState()
        {
            selected = false;
        }
    }

    public class checkedIDs
    {
        public int IDs { get; set; }
    }
    public class SaveMapRoleRequest
    {
        public List<checkedIDs> checked_ids { get; set; }
        public string RoleName { get; set; }
        public string UID { get; set; }
    }
    public class CommonDocsFilter
    {
        public string TransID { get; set; }
        public string FromDate { get; set; }
        public string ToDate { get; set; }
        public string DocRange { get; set; }
        public string Party { get; set; }
        public string FilterType { get; set; }

    }
}