using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SampWebApi.Models
{
    public class PurchaseModel
    {
        public string ID { get; set; }
        public string Mode { get; set; }
        public string Date { get; set; }
        public string TransID { get; set; }
        public string EncDocPrefix { get; set; }
        public string TransMode { get; set; }
        public string TransName { get; set; }
        public string IsDraft { get; set; }
        public string DraftID { get; set; }
        public string BranchID { get; set; }
        public string DocID { get; set; }
        public string DocValue { get; set; }
        public string VendorID { get; set; }
        public string VendorName { get; set; }
        public string RefNo { get; set; }
        public string ProdGroupID { get; set; }
        public string TaxTypeID { get; set; }
        public string PaymentModeID { get; set; }
        public string PaymentTermID { get; set; }
        public string PriceID { get; set; }
        public string PaymentDate { get; set; }
        public string VehicleNo { get; set; }
        public string Frieght { get; set; }
        public string OtherChargePern { get; set; }
        public string OtherChargeAmt { get; set; }
        public string ProdDiscPern { get; set; }
        public string TradeDiscPern { get; set; }
        public string AddnlDiscPern { get; set; }
        public string TotalProdDiscAmt { get; set; }
        public string TotalTradeDiscAmt { get; set; }
        public string TotalAddnlDiscAmt { get; set; }
        public string WriteOffAmt { get; set; }
        public string RoundOffAmt { get; set; }
        public string GrossAmt { get; set; }
        public string TaxAmt { get; set; }
        public string NetAmt { get; set; }
        public string Balance { get; set; }
        public string PymtID { get; set; }
        public string Status { get; set; }
        public string CurrentStatus { get; set; }
        public string InfoMessage { get; set; }
        public string OrgId { get; set; }
        public string UDFId { get; set; }
        public string UDFDocId { get; set; }
        public string UDFDocPrefix { get; set; }
        public string UDFDocValue { get; set; }
        public string CBy { get; set; }
        public string CDate { get; set; }
        public string MBy { get; set; }
        public string MDate { get; set; }
        public string ClBy { get; set; }
        public string ClDate { get; set; }
        public string ReturnType { get; set; }
        public string UOMType { get; set; }
        public string TransactionType { get; set; }
        public string DateBill { get; set; }
        public string PortalDate { get; set; }
        public string TCSTaxPern { get; set; }
        public string TCSTaxAmt { get; set; }
        public string TDSAmount { get; set; }
        public string IRN { get; set; }
        public string AckNo { get; set; }
        public string AckDate { get; set; }
        public string AckStatus { get; set; }
        public string SignedQRCode { get; set; }
        public string EWBNo { get; set; }
        public string Distance { get; set; }
        public string VehicleType { get; set; }
        public string TransportID { get; set; }
        public string TransportName { get; set; }
        public string Remarks { get; set; }
        public string Narration { get; set; }
        public string ConvertionType { get; set; }
        public string DiffValueGross { get; set; }
        public string DiffValueNet { get; set; }
        public List<PurchaseBatchInfo> lstBatchInfo { get; set; }
        public List<PurchaseDetail> lstProdInfo { get; set; }
        public List<CustomerVendorModel> lstPartyInfo { get; set; }
        public List<PurchaseGridData> lstProdGrid { get; set; }
        public List<ProductModel> lstProduct { get; set; }
        public List<PaymentmodeInfo> lstPaymodeInfo { get; set; }
    }
    public class PurchaseDetail
    {
        public string HID { get; set; }
        public string Date { get; set; }
        public string InventoryId { get; set; }
        public string ProdID { get; set; }
        public string UomID { get; set; }
        public string HSN { get; set; }
        public string BatchNo { get; set; }
        public string PKD { get; set; }
        public string Expiry { get; set; }
        public string UomQty { get; set; }
        public string UomFreeQty { get; set; }
        public string UomDamageQty { get; set; }
        public string UomPurchasePrice { get; set; }
        public string UomSalePrice { get; set; }
        public string UomECP { get; set; }
        public string UomMRP { get; set; }
        public string UomSPLPrice { get; set; }
        public string UomReturnPrice { get; set; }
        public string PurchasePrice { get; set; }
        public string SalePrice { get; set; }
        public string ECP { get; set; }
        public string MRP { get; set; }
        public string SPLPrice { get; set; }
        public string ReturnPrice { get; set; }
        public string TaxID { get; set; }
        public string TaxTypeID { get; set; }
        public string TaxPern { get; set; }
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
        public string LocationID { get; set; }
        public string DiffAmt { get; set; }

    }
    public class PurchaseBatchInfo
    {
        public string BillID { get; set; }
        public string DocDate { get; set; }
        
        public string InventoryID { get; set; }
        public string DmgQty { get; set; }
        public string ECP { get; set; }
        public string FreeQty { get; set; }
        public string MRP { get; set; }
        public string OrgECP { get; set; }
        public string OrgMRP { get; set; }
        public string OrgPPrice { get; set; }
        public string OrgRTNPrice { get; set; }
        public string OrgSPL { get; set; }
        public string OrgSPrice { get; set; }
        public string PKDDate { get; set; }
        public string ExpiryDate { get; set; }
        public string BatchNo { get; set; }
        public string ProdID { get; set; }
        public string PurchasePrice { get; set; }
        public string Qty { get; set; }
        public string ReturnPrice { get; set; }
        public string SPLPrice { get; set; }
        public string SalesPrice { get; set; }
        public string TrackBatch { get; set; }
        public string TrackInventory { get; set; }
        public string UomID { get; set; }
        public string TrackPKD { get; set; }
        public string TaxID { get; set; }
        public string TaxTypeID { get; set; }
        public string TaxPern { get; set; }
        
        public string TaxName { get; set; }
        public string CheckInclusive { get; set; }
        public string ActQty { get; set; }
        public string ActFreeQty { get; set; }
        public string ActDmgQty { get; set; }
        public string Code { get; set; }
        public string Name { get; set; }
        public string UOMName { get; set; }
        public string HSN { get; set; }
        public string ConversionRate { get; set; }
        public string QtyType { get; set; }
        public string ReasonID { get; set; }
        public string Reason { get; set; }
    }
    public class PurchaseGridData
    {
        public string ProdID { get; set; }
        public string UomID { get; set; }
        public string UomName { get; set; }
        public string ReasonID { get; set; }
        public string LocationID { get; set; }
        public string ReasonName { get; set; }
        public string Code { get; set; }
        public string Name { get; set; }
        public string HSNCode { get; set; }
        public string UOM { get; set; }
        public string Qty { get; set; }
        public string ExclPrice { get; set; }
        public string InclPrice { get; set; }
        public string FreeQty { get; set; }
        public string DmgQty { get; set; }
        public string ProdPern { get; set; }
        public string TradePern { get; set; }
        public string AddnlPern { get; set; }
        public string TaxPern { get; set; }
        public string TaxID { get; set; }
        public string ProdAmt { get; set; }
        public string TradeAmt { get; set; }
        public string AddnlAmt { get; set; }
        public string GrossAmt { get; set; }
        public string GoodsAmt { get; set; }
        public string TaxAmt { get; set; }
        public string TaxName { get; set; }
        public string NetAmt { get; set; }
        public string TransactionPrice { get; set; }
        public string DiffAmt { get; set; }
    }
    public class PRBatch
    {
        public string ID { get; set; }
        public string Code { get; set; }
        public string Name { get; set; }
        public string HSNCode { get; set; }
        public string ProductDiscPerc { get; set; }
        public string BaseUomID { get; set; }
        public string BaseCR { get; set; }
        public string PurchaseUomID { get; set; }
        public string PurchaseCR { get; set; }
        public string PurchaseTaxID { get; set; }
        public string PurchasePrice { get; set; }
        public string SalesPrice { get; set; }
        public string ECP { get; set; }
        public string SPLPrice { get; set; }
        public string MRP { get; set; }
        public string ReturnPrice { get; set; }
        public string TaxName { get; set; }
        public string GSTPern { get; set; }
        public string Qty1 { get; set; }
        public string FreeQty1 { get; set; }
        public string DmgQty1 { get; set; }
        public string BatchNo { get; set; }
        public string PKD { get; set; }
        public string Expiry { get; set; }
        public string TrackBatch { get; set; }
        public string TrackPKD { get; set; }
        public string TransactionPrice { get; set; }
        public List<clsPurchaseUOM> UOMList { get; set; }
        public List<PurchaseBatchInfo> PRBatchInfo { get; set; }

    }
}