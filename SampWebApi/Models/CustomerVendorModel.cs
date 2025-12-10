using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SampWebApi.Models
{
    public class CustomerVendorModel
    {
        public string FType { get; set; }
        public string Form { get; set; }
        public string Mode { get; set; }
        public string ID { get; set; }
        public string Code { get; set; }
        public string Name { get; set; }
        public string CustomerType { get; set; }
        public string Ratings { get; set; }
        public string RatingName { get; set; }
        public string CloseBal { get; set; }
        public string OSType { get; set; }
        public string ACDate { get; set; }
        public string Billadd1 { get; set; }
        public string Billadd2 { get; set; }
        public string Billadd3 { get; set; }
        public string Shipadd1 { get; set; }
        public string shipadd2 { get; set; }
        public string Shipadd3 { get; set; }
        public string Pincode { get; set; }
        public string ContactPerson { get; set; }
        public string Ph1 { get; set; }
        public string Ph2 { get; set; }
        public string Mob1 { get; set; }
        public string Mob2 { get; set; }
        public string Email { get; set; }
        public string PANNumber { get; set; }
        public string AadharNo { get; set; }
        public string DLNo20 { get; set; }
        public string DLNo21 { get; set; }
        public string FSSAINo { get; set; }
        public string StateID { get; set; }
        public string IfRegister { get; set; }
        public string GSTIN { get; set; }
        public string CreditTermID { get; set; }
        public string PaymentModeID { get; set; }
        public string TaxTypeID { get; set; }
        public string OSValue { get; set; }
        public string FAID { get; set; }
        public string OverDueValue { get; set; }
        public string OverDueInvCount { get; set; }
        public string CreditLimitValue { get; set; }
        public string CreditLimitCount { get; set; }
        public string CreditlimitOS { get; set; }
        public string PriceTypeID { get; set; }
        public string WeekCycle { get; set; }
        public string OwnerName { get; set; }
        public string DiscountPern { get; set; }
        public string TrackPoint { get; set; }
        public string ClosingTrackPoint { get; set; }
        public string TCSTax { get; set; }
        public string Latitude { get; set; }
        public string Longtitude { get; set; }
        public string Distance { get; set; }
        public string Remark { get; set; }
        public string Active { get; set; }
        public string UserID { get; set; }
        public string BeatID { get; set; }
        public string SalesmanID { get; set; }
        public List<MapBeatSalesman> BSM { get; set; }
        public List<ProductModel> lstProduct { get; set; }
        public string AIopen { get; set; }
        public string POopen { get; set; }
        public List<clsCustomerRemarks> lstCustRemark { set; get; }
        public string UserName { get; set; }
        public string LastActionTime { get; set; }
    }
    public class clsCustomerRemarks
    {
        public string Remarks { get; set; }
    }
    public class MapBeatSalesman
    {
        public string BeatName { get; set; }
        public string SalesmanName { get; set; }
    }
    public class ProductModel
    {
        public string Mode { get; set; }
        public string ID { get; set; }
        public string Code { get; set; }
        public string Name { get; set; }
        public string EAN { get; set; }
        public string BranchID { get; set; }
        public string MfrID { get; set; }
        public string BrandID { get; set; }
        public string CategoryID { get; set; }
        public string HSNCode { get; set; }
        public string ProductDiscPerc { get; set; }
        public string TradeDiscPerc { get; set; }
        public string BaseUomID { get; set; }
        public string BaseCR { get; set; }
        public string BaseUOMName { get; set; }
        public string PurchaseUomID { get; set; }
        public string PurchaseUomName { get; set; }
        public string PurchaseCR { get; set; }
        public string SalesUomID { get; set; }
        public string SalesCR { get; set; }
        public string ReportingUomID { get; set; }
        public string ReportingCR { get; set; }
        public string ReportingQty { get; set; }
        public string PurchaseTaxID { get; set; }
        public string SalesTaxID { get; set; }
        public string PurchasePrice { get; set; }
        public string SalesPrice { get; set; }
        public string ECP { get; set; }
        public string SPLPrice { get; set; }
        public string MRP { get; set; }
        public string ReturnPrice { get; set; }
        public string SaleonMRP { get; set; }
        public string SaleonpPern { get; set; }
        public string ECPonMRP { get; set; }
        public string ECPonpPern { get; set; }
        public string SPLonMRP { get; set; }
        public string SPLonpPern { get; set; }

        public string TrackInventory { get; set; }
        public string TrackBatch { get; set; }
        public string TrackSerial { get; set; }
        public string TrackPDK { get; set; }
        public string DateFormat { get; set; }
        public string BarcodeUomID { get; set; }
        public string BarcodePriceID { get; set; }
        public string BarcodePrint { get; set; }
        public string Weborder { get; set; }
        public string VendorID { get; set; }
        public string Branch { get; set; }
        public string MOH { get; set; }
        public string MOQ { get; set; }
        public string Remarks { get; set; }
        public string ProdLifeTime {  get; set; }
        public string LocationID { get; set; }
        public string Active { get; set; }
        public string CBy { get; set; }
        public string ABSValue { get; set; }
        public string ABSQty { get; set; }
        public string ABSFreeQty { get; set; }
        public string ABSDmgQty { get; set; }
        public string CustStkReq { get; set; }
        public string IndentQty { get; set; }
        public List<clsPurchaseUOM> UOMList { get; set; }
        public string TaxName { get; set; }
        public string GSTPern { get; set; }
        public string IGSTPern { get; set; }
        public string Qty1 { get; set; }
        public string FreeQty1 { get; set; }
        public string DmgQty1 { get; set; }
        public string Qty2 { get; set; }
        public string FreeQty2 { get; set; }
        public string DmgQty2 { get; set; }
        public string BatchNo { get; set; }
        public string PKD { get; set; }
        public string Expiry { get; set; }
        public string ProdInvCount { get; set; }
        public string ProdBatCount { get; set; }
        public string ProdPkdCount { get; set; }
        public List<ProdPricechangedata> lstProdPrice {  get; set; }
        public List<ProdPreviousbatchqty> lstProdQtyBatch { get; set; }        
        public string PurchaseBillPrice { get; set; }
        public string PurchaseReturnPrice { get; set; }
        public string InvoicePrice { get; set; }
        public string SalesReturnPrice { get; set; }
        public string DamageReturnPrice { get; set; }
        public string UserName { get; set; }
        public string LastActionTime { get; set; }
    }
    
    public class clsPurchaseUOM
    {
        public string ID { get; set; }
        public string Name { get; set; }
        public string ConvRate { get; set; }
    }
    public class ProdPricechangedata
    {
        public string InventoryID { get; set; }
        public string TransDate { get; set; }
        public string BatchNo { get; set; }
        public string PKD { get; set; }
        public string Expiry { get; set; }
        public string ActualQty { get; set; }
        public string PurchasePrice { get; set; }
        public string SalePrice { get; set; }
        public string ECP { get; set; }
        public string MRP { get; set; }
        public string MRPExcl { get; set; }
        public string SPLPrice { get; set; }
        public string ReturnPrice { get; set; }
    }
    public class DiscountschemeHeader
    {
        public string Mode { get; set; }
        public string ID { get; set; }
        public string Name { get; set; }
        public string FromDate { get; set; }
        public string ToDate { get; set; }
        public string ReplaceExists { get; set; }
        public string Active { get; set; }
        public string CBy { get; set; }
        public List<DiscountschemeDetail> lstDiscDetail { get; set; }
    }
    public class DiscountschemeDetail
    {
        public string FType { get; set; }
        public string ID { get; set; }
        public string Code { get; set; }
        public string Name { get; set; }
        public string ProdDiscPern { get; set; }
        public string ProdDiscAmt { get; set; }
        public string TradeDiscPern { get; set; }
        public string TradeDiscAmt { get; set; }        
    }
    public class ProdPreviousbatchqty
    {
        public string TransDate { get; set; }
        public string PurchaseQty { get; set; }
        public string SaleQty { get; set; }
        public string SRQty { get; set; }
        public string PurchasePrice { get; set; }
        
    }
    public class PrintProfileConfig
    {
        public string TransID { get; set; }
        public string ConfigID { get; set; }
        public string DefaultConfig { get; set; }
        public string UserID { get; set; }
    }
}