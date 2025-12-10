using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SampWebApi.Models
{
    public class SalesModel
    {
        public string ID { get; set; }
        public string Mode { get; set; }
        public string TransID { get; set; }
        public string TransMode { get; set; }
        public string TransName { get; set; }
        public string IsDraft { get; set; }
        public string DraftID { get; set; }
        public string DocDate { get; set; }
        public string DocId { get; set; }
        public string DocPrefix { get; set; }
        public string DocValue { get; set; }
        public string BranchID { get; set; }
        public string CustomerID { get; set; }
        public string BeatID { get; set; }
        public string ReturnType { get; set; }
        public string SalesmanID { get; set; }
        public string RefNo { get; set; }
        public string PaymentModeID { get; set; }
        public string PaymentTermID { get; set; }
        public string PriceID { get; set; }
        public string TaxTypeID { get; set; }
        public string TradeDiscPern { get; set; }
        public string TradeDiscAmt { get; set; }
        public string AddnlDiscPern { get; set; }
        public string AddnlDiscAmt { get; set; }
        public string OtherChargePern { get; set; }
        public string OtherChargeAmt { get; set; }
        public string FrightAmt { get; set; }
        public string TCSTaxAmt { get; set; }
        public string TDSAmount { get; set; }
        public string WriteOffAmt { get; set; }        
        public string TotalProdDiscAmt { get; set; }
        public string TotalDiscAmt { get; set; }
        public string GrossAmt { get; set; }
        public string TaxAmt { get; set; }
        public string NetAmt { get; set; }
        public string RoundOffAmt { get; set; }
        public string Status { get; set; }
        public string UDFId { get; set; }
        public string UDFDocId { get; set; }
        public string UDFDocPrefix { get; set; }
        public string UDFDocValue { get; set; }
        public string UserID { get; set; }
        public string Remarks { get; set; }
        public string Narration { get; set; }
        public string CurrentStatus { get; set; }
        public string AdjustInvoiceID { get; set; }
        public string FilterTypeID { get; set; }

        public string VehicleNo { get; set; }
        public string Distance { get; set; }
        public string TransportType { get; set; }
        public string TransportMode { get; set; }
        public string TransactionID { get; set; }
        public string TransactionName { get; set; }
        public string DiffValueGross { get; set; }
        public string DiffValueNet { get; set; }
        public List<CustomerVendorModel> lstPartyInfo { get; set; }
        public List<SalesDetail> lstProdInfo { get; set; }
        public List<PaymentmodeInfo> lstPaymodeInfo { get; set; }
        public List<SRTempBatch> lstTempBatch { get; set; }
    }
    public class SRTempBatch
    {
        public string ProdId { get; set; }
        public string Batch { get; set; }
        public string PKD { get; set; }
        public string Expiry { get; set; }
        public string PPrice { get; set; }
        public string SPrice { get; set; }
        public string ECP { get; set; }
        public string MRP { get; set; }
        public string SPLPrice { get; set; }
        public string Return { get; set; }
        public string TaxId { get; set; }
        public string TaxTypeId { get; set; }
        public string InclusiveYesNo { get; set; }
        public string BatchType { get; set; }
        public string HiddenRowIndex { get; set; }

    }
    public class SalesDetail
    {
        public string HID { get; set; }
        public string Date { get; set; }
        public string InventoryId { get; set; }
        public string ProdID { get; set; }
        public string Code { get; set; }
        public string Name { get; set; }
        public string UomID { get; set; }
        public string OrgUomID { get; set; }
        public string ConvFact { get; set; }
        public string HSN { get; set; }
        public string BatchNo { get; set; }
        public string PKD { get; set; }
        public string Expiry { get; set; }
        public string UomQty { get; set; }
        public string UomSalePrice { get; set; }
        public string UomSalePriceIncl { get; set; }
        public string UomMRP { get; set; }
        public string OrgPrice { get; set; }
        public string SalePrice { get; set; }       
        public string MRP { get; set; }       
        public string TaxID { get; set; }
        public string TaxTypeID { get; set; }
        public string TaxPern { get; set; }
        public string TaxName { get; set; }
        public string GoodsAmt { get; set; }
        public string ProdDiscPern { get; set; }
        public string TradeDiscPern { get; set; }
        public string AddnlDiscPern { get; set; }
        public string ProdDiscAmt { get; set; }
        public string TradeDiscAmt { get; set; }
        public string AddnlDiscAmt { get; set; }
        public string GrossAmt { get; set; }
        public string TaxAmt { get; set; }
        public string NetAmt { get; set; }
        public string Serial { get; set; }
        public string AdjQty { get; set; }
        public string AdjFreeQty { get; set; }
        public string AdjDmgQty { get; set; }
        public string ReasonId { get; set; }
        public string InvYN { get; set; }
        public string PKDYN { get; set; }
        public string BatchYN { get; set; }
        public string SerialYN { get; set; }
        public string QtyType { get; set; }
        public string ProductSchemeID { get; set; }
        public string ProductTransPrice { get; set; }
        public string DiffAmt { get; set; }
        public string HiddenRowID { get; set; }
        public string NewBatchCreated { get; set; }
        public List<clsPurchaseUOM> UOMList { get; set; }
        public List<InvoiceBatchPopup> lstInvPopup { get; set; }
        public List<SingleMasterModel> lstReason { get; set; }
        public List<SRTempBatch> lstTempBatch { get; set; }
    }
    public class InvoiceBatchPopup
    {
        public string InvID { get; set; }
        public string DocDate { get; set; }
        public string InventoryID { get; set; }
        public string QtyType { get; set; }
        public string QtyTag { get; set; }
        public string Qty { get; set; }       
        public string MRP { get; set; }      
        public string PKDDate { get; set; }
        public string ExpiryDate { get; set; }
        public string BatchNo { get; set; }
        public string ProdID { get; set; }       
        public string SalesPrice { get; set; }       
        public string TrackPKD { get; set; }       
        public string CheckInclusive { get; set; }
        public string ActQty { get; set; }
        public string TrackBatch { get; set; }
        public string TrackInventory { get; set; }
    }

    public class InvoiceBatchInfo
    {
        public string InvID { get; set; }
        public string DocDate { get; set; }
        public string InventoryID { get; set; }
        public string QtyType { get; set; }
        public string QtyTag { get; set; }
        public string Qty { get; set; }
        public string MRP { get; set; }
        public string PKDDate { get; set; }
        public string ExpiryDate { get; set; }
        public string BatchNo { get; set; }
        public string ProdID { get; set; }
        public string HSNCode { get; set; }
        public string ProductDiscPerc { get; set; }
        public string TradeDiscPerc { get; set; }
        
        public string SalesPrice { get; set; }
        public string TrackBatch { get; set; }
        public string TrackInventory { get; set; }
        public string UOMID { get; set; }
        public string TrackPKD { get; set; }
        public string TaxID { get; set; }
        public string TaxTypeID { get; set; }
        public string TaxPern { get; set; }
        public string TaxName { get; set; }
        public string CheckInclusive { get; set; }
        public string ActQty { get; set; }
        public string Code { get; set; }
        public string Name { get; set; }
        public string UOM { get; set; }
        public string BaseUomID { get; set; }
        public string BaseCR { get; set; }
        public string PurchaseUomID { get; set; }
        public string PurchaseCR { get; set; }
        public string SalesUomID { get; set; }
        public string SalesCR { get; set; }
        public string SalesTaxID { get; set; }
        public string PurchasePrice { get; set; }
        public string ECP { get; set; }
        public string SPLPrice { get; set; }
        public string ReturnPrice { get; set; }
        public string GSTPern { get; set; }
        public string IGSTPern { get; set; }
        public string ItemTransactionPrice { get; set; }
        public List<clsPurchaseUOM> UOMList { get; set; }
        public List<InvoiceBatchPopup> lstInvPopup { get; set; }
        public List<SingleMasterModel> lstReason { get; set; }
    }
    public class PaymentmodeInfo
    {
        public string AccID { get; set; }
        public string Mode { get; set; }
        public string ChequeDDNumber { get; set; }
        public string Date { get; set; }
        public string BankAccId { get; set; }
        public string Neft { get; set; }
        public string Amt { get; set; }
        public string IFSC { get; set; }
        public string Bank { get; set; }
        public string Branch { get; set; }
        public string PayAt { get; set; }
        public string BankAccNo { get; set; }
        public string ChequeBkRefNo { get; set; }
        public string ChequeBookID { get; set; }
        public string SerialNo { get; set; }
        public string RecdAmt { get; set; }
        public string VisaPern { get; set; }
        public string VisaAmt { get; set; }
        public string OriginalCollAmt { get; set; }
    }
    public class AssignInvoiceHeader
    {
        public string ID { get; set; }
        public string Mode { get; set; }
        public string Date { get; set; }
        public string DocID { get; set; }
        public string TransID { get; set; }
        public string TransMode { get; set; }
        public string TransName { get; set; }
        public string SalesmanID { get; set; }
        public string RefNo { get; set; }
        public string Status { get; set; }
        public string DetailStatusCount { get; set; }
        public string CollInvCount { get; set; }
        public string CurrentStatus { get; set; }
        public string TotalInvCount { get; set; }
        public string CBy { get; set; }
        public string CDate { get; set; }
        public string StatusID { get; set; }
        public string UDFId { get; set; }
        public string lstJsonAssignDetails { get; set; }
        public List<AssignInvoiceDetails> lstAssignDetails { get; set; }
    }
    public class AssignInvoiceDetails
    {
        public string ID { get; set; }
        public string DocDate { get; set; }
        public string DocId { get; set; }
        public string Customer { get; set; }
        public string Beat { get; set; }
        public string Salesman { get; set; }
        public string RefNo { get; set; }
        public string NetAmt { get; set; }
        public string Balance { get; set; }
        public string Ageing { get; set; }
        public string AssignedInvoiceCount { get; set; }
        public string Status { get; set; }
    }
    public class DailyActivity
    {
        public string BeatID { get; set; }
        public string BeatName { get; set; }
        public string SalesManID { get; set; }
        public string SalesManName { get; set; }
        public string CustomerID { get; set; }
        public string CustomerName { get; set; }
        public string BranchID { get; set; }
        public decimal AddnlDisc { get; set; }
        public decimal TrdDisc { get; set; }
        public string FeedBack { get; set; }
        public string ActivityID { get; set; }
        public List<DailyActivityDetails> lstProdDetails { get; set; }
        public int Allsalesman { get; set; }        
        public string ot_OSValue { get; set; }       
        public string Mode { get; set; }
        public string UserID { get; set; }
        public string CusLatitude { get; set; }
        public string CusLongtitude { get; set; }
        public string Pincode { get; set; }
        public string HasPincode { get; set; }
        public string BillAdd { get; set; }
        public string ShipAdd { get; set; }
        public string ContPerson { get; set; }
        public string MobileNo { get; set; }
        public string GSTIN { get; set; }
        public string ot_CustLocLink { get; set; }
        public string ot_MobnoLink { get; set; }
        public string ot_Remark { get; set; }
        public string TransType { get; set; }
        public string TransID { get; set; }
        public string LocGiven { get; set; }
        public string LastOTDate { get; set; }
        public bool EnableProdDiscAmt { get; set; }
        public string TranStartTime { get; set; }
    }
    public class DailyActivityDetails
    {
        public string Name { get; set; }
        public string ID { get; set; }
        public string Discount { get; set; }
        public string Qty { get; set; }
        public string Rate { get; set; }
        public string MRP { get; set; }
        public string AppPrice { get; set; }
        public string PriceDesc { get; set; }
        public string _DiscAmt { get; set; }
    }
    public class CollectionModel
    {
        public string ID { get; set; }
        public string Date { get; set; }
        public string RefNo { get; set; }
        public string BeatID { get; set; }
        public string BeatName { get; set; }
        public string SalesManID { get; set; }
        public string SalesManName { get; set; }
        public string CustomerID { get; set; }
        public string CustomerName { get; set; }
        public string collectedamt { get; set; }
        public string PaymentmodeID { get; set; }
        public string Paymentmode { get; set; }
        public string Status { get; set; }
        public string Chequedate { get; set; }
        public string Chequeno { get; set; }
        public List<adjDocs> lstadjdocs { get; set; }
        public string AdvAmt { get; set; }
        public string Bankname { get; set; }
        public string BankID { get; set; }
        public string ifsc { get; set; }
        public string BankACno { get; set; }
        public string BankACID { get; set; }
        public int ot_Allsalesman { get; set; }        
        public string UserID { get; set; }        
        public string CusLatitude { get; set; }
        public string CusLongtitude { get; set; }
        public string OSAmt { get; set; }
        public string CashValue { get; set; }
        public string ChequeValue { get; set; }
        public string BankTransferValue { get; set; }
        public string Jsonlstadjdocs { get; set; }
    }
    public class adjDocs
    {
        public string ID { get; set; }
        public string Docprefix { get; set; }
        public string TransName { get; set; }
        public string Docdate { get; set; }
        public string Docid { get; set; }
        public string UDN { get; set; }
        public string Refno { get; set; }
        public string Balance { get; set; }
        public string NetAmt { get; set; }
        public string Amtadj { get; set; }
        public string Ohtercharges { get; set; }
        public string totAdvAmount { get; set; }
        public string clsBalance { get; set; }
        public string AssignInvoiceID { get; set; }
    }
    public class SRExistsbatchget
    {
        public int AppPriceId { get; set; }
        public int BranchId { get; set; }
        public int ProdId { get; set; }

        public string BatchNumber { get; set; }
        public string PkdDate { get; set; }
        public string ExpiryDate { get; set; } 

        public string Price { get; set; } 
        public string MRP { get; set; }
    }

}