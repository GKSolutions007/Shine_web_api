using DocumentFormat.OpenXml.Office2016.Drawing.ChartDrawing;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Reflection;
using System.Web.Http;
using System.Web.Http.Cors;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class PurchaseReturnController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        DataTable dtPMDetail = new DataTable(), dtPopUpDetail = new DataTable(), dtProd = new DataTable(), dtGSTInfo = new DataTable();
        [HttpGet]
        [Route("api/purchasereturn/get")]
        public IHttpActionResult GetData(string Mode, string CodeName, string ID = null,string BranchID = "0",
            string Date ="", string PriceID = "1", string DraftID = "0")
        {
            try
            {
                DataTable DDT = new DataTable();
                if (Mode == "1")
                {
                    DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseReturnData", Mode, 0);
                    List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new CustomerVendorModel
                        {
                            FType = DDT.Rows[i][0].ToString(),
                            Form = DDT.Rows[i][1].ToString(),
                            ID = DDT.Rows[i][2].ToString(),
                            Code = DDT.Rows[i][3].ToString(),
                            Name = DDT.Rows[i][4].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "2")
                {
                    DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseReturnData", Mode, BranchID, null, null, null, Convert.ToDateTime(ID));
                    List<ProductModel> list = new List<ProductModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new ProductModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Code = DDT.Rows[i]["Code"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                            EAN = DDT.Rows[i]["EAN"].ToString(),
                            HSNCode = DDT.Rows[i]["HSNCode"].ToString(),
                            PurchasePrice = DDT.Rows[i]["PurchasePrice"].ToString(),
                            ReturnPrice = DDT.Rows[i]["ReturnPrice"].ToString(),
                            ABSQty = DDT.Rows[i]["ABSQty"].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "3")
                {
                    DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseReturnData", Mode, CodeName);
                    List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new CustomerVendorModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Code = DDT.Rows[i]["Code"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                            Billadd1 = DDT.Rows[i]["Billadd1"].ToString(),
                            Billadd2 = DDT.Rows[i]["Billadd2"].ToString(),
                            Billadd3 = DDT.Rows[i]["Billadd3"].ToString(),
                            Shipadd1 = DDT.Rows[i]["Shipadd1"].ToString(),
                            Shipadd2 = DDT.Rows[i]["shipadd2"].ToString(),
                            Shipadd3 = DDT.Rows[i]["Shipadd3"].ToString(),
                            Pincode = DDT.Rows[i]["Pincode"].ToString(),
                            ContactPerson = DDT.Rows[i]["ContactPerson"].ToString(),
                            Ph1 = DDT.Rows[i]["Ph1"].ToString(),
                            Ph2 = DDT.Rows[i]["Ph2"].ToString(),
                            Mob1 = DDT.Rows[i]["Mob1"].ToString(),
                            Mob2 = DDT.Rows[i]["Mob2"].ToString(),
                            Email = DDT.Rows[i]["Email"].ToString(),
                            PANNumber = DDT.Rows[i]["PANNumber"].ToString(),
                            AadharNo = DDT.Rows[i]["AadharNo"].ToString(),
                            DLNo20 = DDT.Rows[i]["DLNo20"].ToString(),
                            DLNo21 = DDT.Rows[i]["DLNo21"].ToString(),
                            FSSAINo = DDT.Rows[i]["FSSAINo"].ToString(),
                            StateID = DDT.Rows[i]["StateID"].ToString(),
                            GSTIN = DDT.Rows[i]["GSTIN"].ToString(),
                            CreditTermID = DDT.Rows[i]["CreditTermID"].ToString(),
                            PaymentModeID = DDT.Rows[i]["PaymentModeID"].ToString(),
                            TaxTypeID = DDT.Rows[i]["TaxTypeID"].ToString(),
                            FAID = DDT.Rows[i]["FAID"].ToString(),
                            WeekCycle = DDT.Rows[i]["WeekCycle"].ToString(),
                            Active = DDT.Rows[i]["Active"].ToString(),
                            Ratings = DDT.Rows[i]["Rating"].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "4")
                {
                    DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseReturnData", Mode, CodeName);
                    List<PRBatch> list = new List<PRBatch>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        DataTable dtUOM = bl.BL_ExecuteParamSP("uspGetSetPurchaseReturnData", 5, "", DDT.Rows[i][0].ToString());
                        List<clsPurchaseUOM> ulist = new List<clsPurchaseUOM>();
                        for (int j = 0; j < dtUOM.Rows.Count; j++)
                        {
                            ulist.Add(new clsPurchaseUOM
                            {
                                ID = dtUOM.Rows[j][0].ToString(),
                                Name = dtUOM.Rows[j][1].ToString(),
                                ConvRate = dtUOM.Rows[j][2].ToString()
                            });
                        }
                        List<PurchaseBatchInfo> ulistBatch = new List<PurchaseBatchInfo>();
                        //string Mode, string CodeName, string ID = null,string BranchID = "0",string Date ="", string PriceID = "1"
                        //DataTable dtBatch = bl.BL_ExecuteParamSP("uspGetSetPurchaseReturnData", 41, DDT.Rows[i][0].ToString(),PriceID,12,
                        //    BranchID,Convert.ToDateTime(Date));
                        DataTable dtBatch = bl.BL_ExecuteParamSP("uspGetPRProductIntoryBatch", DDT.Rows[i][0].ToString(), BranchID, Convert.ToDateTime(Date), PriceID, ID);
                        for (int j = 0; j < dtBatch.Rows.Count; j++)
                        {
                            string PKD = !string.IsNullOrEmpty(dtBatch.Rows[j]["PKDDate"].ToString()) ? Convert.ToDateTime(dtBatch.Rows[j]["PKDDate"].ToString()).ToString("yyyy-MM-dd") : "";//dd/MM/yyyy
                            string Exp = !string.IsNullOrEmpty(dtBatch.Rows[j]["ExpiryDate"].ToString()) ? Convert.ToDateTime(dtBatch.Rows[j]["ExpiryDate"].ToString()).ToString("yyyy-MM-dd") : "";
                            ulistBatch.Add(new PurchaseBatchInfo
                            {
                                InventoryID = dtBatch.Rows[j]["InventoryID"].ToString(),
                                ProdID = dtBatch.Rows[j]["ProdID"].ToString(),
                                BatchNo = dtBatch.Rows[j]["BatchNumber"].ToString(),
                                PKDDate = PKD,//dtBatch.Rows[j]["PKDDate"].ToString(),
                                ExpiryDate = Exp,// dtBatch.Rows[j]["ExpiryDate"].ToString(),
                                ActQty = dtBatch.Rows[j]["ActualQty"].ToString(),
                                ActFreeQty = dtBatch.Rows[j]["ActualFreeQty"].ToString(),
                                ActDmgQty = dtBatch.Rows[j]["ActualDmgQty"].ToString(),
                                MRP = dtBatch.Rows[j]["MRP"].ToString(),
                                PurchasePrice = dtBatch.Rows[j]["PurchasePrice"].ToString(),
                                ReturnPrice = dtBatch.Rows[j]["ReturnPrice"].ToString(),
                                TrackBatch = DDT.Rows[i]["TrackBatch"].ToString(),
                                TrackPKD = DDT.Rows[i]["TrackPDK"].ToString(),
                                Qty = dtBatch.Rows[j]["Qty"].ToString(),
                                FreeQty = dtBatch.Rows[j]["FreeQty"].ToString(),
                                DmgQty = dtBatch.Rows[j]["DmgQty"].ToString(),
                            });
                        }
                        list.Add(new PRBatch
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Code = DDT.Rows[i]["Code"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                            HSNCode = DDT.Rows[i]["HSNCode"].ToString(),
                            ProductDiscPerc = DDT.Rows[i]["ProductDiscPerc"].ToString(),
                            BaseUomID = DDT.Rows[i]["BaseUomID"].ToString(),
                            BaseCR = DDT.Rows[i]["BaseCR"].ToString(),
                            PurchaseUomID = DDT.Rows[i]["PurchaseUomID"].ToString(),
                            PurchaseCR = DDT.Rows[i]["PurchaseCR"].ToString(),
                            PurchaseTaxID = DDT.Rows[i]["PurchaseTaxID"].ToString(),
                            TaxName = DDT.Rows[i]["TaxName"].ToString(),
                            GSTPern = DDT.Rows[i]["GST"].ToString(),
                            TrackBatch = DDT.Rows[i]["TrackBatch"].ToString(),
                            TrackPKD = DDT.Rows[i]["TrackPDK"].ToString(),
                            TransactionPrice = DDT.Rows[i]["PurchaseReturnPrice"].ToString(),
                            UOMList = ulist,
                            PRBatchInfo = ulistBatch,
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "6" || Mode == "10")
                {
                    DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseReturnData", Mode, CodeName);
                    List<PurchaseModel> list = new List<PurchaseModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new PurchaseModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            DocID = DDT.Rows[i]["DocID"].ToString(),
                            Date = DDT.Rows[i]["DocDate"].ToString(),
                            RefNo = DDT.Rows[i]["RefNo"].ToString(),
                            BranchID = DDT.Rows[i]["Branch"].ToString(),
                            VendorID = DDT.Rows[i]["Party"].ToString(),
                            GrossAmt = DDT.Rows[i]["GrossAmt"].ToString(),
                            TaxAmt = DDT.Rows[i]["TaxAmt"].ToString(),
                            NetAmt = DDT.Rows[i]["NetAmt"].ToString(),
                            Status = DDT.Rows[i]["Status"].ToString(),
                        });
                    }
                    return Ok(list);
                }

                if (Mode == "7" || Mode == "11")
                {
                    DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseReturnData", Mode, null, CodeName);
                    List<PurchaseModel> list = new List<PurchaseModel>();
                    if (DDT.Rows.Count > 0)
                    {
                        for (int i = 0; i < DDT.Rows.Count; i++)
                        {
                            DataTable DDT1 = bl.BL_ExecuteParamSP("uspGetSetPurchaseReturnData", 31, DDT.Rows[i][6].ToString());
                            List<CustomerVendorModel> listParty = new List<CustomerVendorModel>();
                            for (int j = 0; j < DDT1.Rows.Count; j++)
                            {
                                listParty.Add(new CustomerVendorModel
                                {
                                    ID = DDT1.Rows[j]["ID"].ToString(),
                                    Code = DDT1.Rows[j]["Code"].ToString(),
                                    Name = DDT1.Rows[j]["Name"].ToString(),
                                    Billadd1 = DDT1.Rows[j]["Billadd1"].ToString(),
                                    Billadd2 = DDT1.Rows[j]["Billadd2"].ToString(),
                                    Billadd3 = DDT1.Rows[j]["Billadd3"].ToString(),
                                    Shipadd1 = DDT1.Rows[j]["Shipadd1"].ToString(),
                                    Shipadd2 = DDT1.Rows[j]["shipadd2"].ToString(),
                                    Shipadd3 = DDT1.Rows[j]["Shipadd3"].ToString(),
                                    Pincode = DDT1.Rows[j]["Pincode"].ToString(),
                                    ContactPerson = DDT1.Rows[j]["ContactPerson"].ToString(),
                                    Ph1 = DDT1.Rows[j]["Ph1"].ToString(),
                                    Ph2 = DDT1.Rows[j]["Ph2"].ToString(),
                                    Mob1 = DDT1.Rows[j]["Mob1"].ToString(),
                                    Mob2 = DDT1.Rows[j]["Mob2"].ToString(),
                                    Email = DDT1.Rows[j]["Email"].ToString(),
                                    PANNumber = DDT1.Rows[j]["PANNumber"].ToString(),
                                    AadharNo = DDT1.Rows[j]["AadharNo"].ToString(),
                                    DLNo20 = DDT1.Rows[j]["DLNo20"].ToString(),
                                    DLNo21 = DDT1.Rows[j]["DLNo21"].ToString(),
                                    FSSAINo = DDT1.Rows[j]["FSSAINo"].ToString(),
                                    StateID = DDT1.Rows[j]["StateID"].ToString(),
                                    GSTIN = DDT1.Rows[j]["GSTIN"].ToString(),
                                    CreditTermID = DDT1.Rows[j]["CreditTermID"].ToString(),
                                    PaymentModeID = DDT1.Rows[j]["PaymentModeID"].ToString(),
                                    TaxTypeID = DDT1.Rows[j]["TaxTypeID"].ToString(),
                                    FAID = DDT1.Rows[j]["FAID"].ToString(),
                                    WeekCycle = DDT1.Rows[j]["WeekCycle"].ToString(),
                                    Active = DDT1.Rows[j]["Active"].ToString(),
                                    Ratings = DDT1.Rows[j]["Rating"].ToString(),
                                });
                            }

                            List<PurchaseGridData> listProductGrid = new List<PurchaseGridData>();
                            DataTable DDT2 = bl.BL_ExecuteParamSP("uspGetSetPurchaseReturnData", Mode == "7" ? 8 : 12, null, CodeName);
                            for (int k = 0; k < DDT2.Rows.Count; k++)
                            {
                                listProductGrid.Add(new PurchaseGridData
                                {
                                    ProdID = DDT2.Rows[k]["ProdID"].ToString(),
                                    UomID = DDT2.Rows[k]["UomID"].ToString(),
                                    ReasonID = DDT2.Rows[k]["ReasonId"].ToString(),
                                    ReasonName = DDT2.Rows[k]["ReasonName"].ToString(),
                                    Code = DDT2.Rows[k]["Code"].ToString(),
                                    Name = DDT2.Rows[k]["Name"].ToString(),
                                    HSNCode = DDT2.Rows[k]["HSNCode"].ToString(),
                                    UOM = DDT2.Rows[k]["UOM"].ToString(),
                                    Qty = DDT2.Rows[k]["Qty"].ToString(),
                                    FreeQty = DDT2.Rows[k]["FreeQty"].ToString(),
                                    DmgQty = DDT2.Rows[k]["DmgQty"].ToString(),
                                    ProdPern = DDT2.Rows[k]["ProdPern"].ToString(),
                                    TradePern = DDT2.Rows[k]["TradePern"].ToString(),
                                    AddnlPern = DDT2.Rows[k]["AddnlPern"].ToString(),
                                    ProdAmt = DDT2.Rows[k]["ProdDiscAmt"].ToString(),
                                    TradeAmt = DDT2.Rows[k]["TradeDiscAmt"].ToString(),
                                    AddnlAmt = DDT2.Rows[k]["AddnlDiscAmt"].ToString(),
                                    TaxPern = DDT2.Rows[k]["TaxPern"].ToString(),
                                    GoodsAmt = DDT2.Rows[k]["GoodsAmt"].ToString(),
                                    GrossAmt = DDT2.Rows[k]["GrossAmt"].ToString(),
                                    TaxAmt = DDT2.Rows[k]["TaxAmt"].ToString(),
                                    TaxName = DDT2.Rows[k]["TaxName"].ToString(),
                                    NetAmt = DDT2.Rows[k]["NetAmt"].ToString(),
                                    TransactionPrice = DDT2.Rows[k]["PurchaseReturnPrice"].ToString(),
                                    DiffAmt = DDT2.Rows[k]["DiffAmt"].ToString(),
                                    MRPonTax = DDT2.Rows[k]["MRPonTaxAmt"].ToString(),
                                    CumMRPonTax = DDT2.Rows[k]["CumMRPonTax"].ToString(),
                                });
                            }
                            List<PurchaseBatchInfo> listBatch = new List<PurchaseBatchInfo>();
                            DataTable DDT3 = bl.BL_ExecuteParamSP("uspGetSetPurchaseReturnData", Mode == "7" ? 9 : 13, null, CodeName);
                            for (int l = 0; l < DDT3.Rows.Count; l++)
                            {
                                listBatch.Add(new PurchaseBatchInfo
                                {
                                    InventoryID = DDT3.Rows[l]["InventoryID"].ToString(),
                                    ProdID = DDT3.Rows[l]["ProdID"].ToString(),
                                    BatchNo = DDT3.Rows[l]["BatchNumber"].ToString(),
                                    PKDDate = !string.IsNullOrEmpty(DDT3.Rows[l]["PKDDate"].ToString()) ? Convert.ToDateTime(DDT3.Rows[l]["PKDDate"].ToString()).ToString("yyyy-MM-dd") : "",
                                    ExpiryDate = !string.IsNullOrEmpty(DDT3.Rows[l]["ExpiryDate"].ToString()) ? Convert.ToDateTime(DDT3.Rows[l]["ExpiryDate"].ToString()).ToString("yyyy-MM-dd") : "",
                                    //DDT3.Rows[l]["ExpiryDate"].ToString(),
                                    ActQty = DDT3.Rows[l]["Qty"].ToString(),
                                    ActFreeQty = DDT3.Rows[l]["FreeQty"].ToString(),
                                    ActDmgQty = DDT3.Rows[l]["DmgQty"].ToString(),
                                    MRP = DDT3.Rows[l]["MRP"].ToString(),
                                    OrgRTNPrice = DDT3.Rows[l]["PurchasePrice"].ToString(),
                                    ReturnPrice = DDT3.Rows[l]["ReturnPrice"].ToString(),
                                    UOMPrice = DDT3.Rows[l]["UOMPrice"].ToString(),
                                    Qty = DDT3.Rows[l]["PRQty"].ToString(),
                                    FreeQty = DDT3.Rows[l]["PRFree"].ToString(),
                                    DmgQty = DDT3.Rows[l]["PRDmg"].ToString(),
                                    TaxName = DDT3.Rows[l]["TaxName"].ToString(),
                                    TaxID = DDT3.Rows[l]["PurchaseTaxID"].ToString(),
                                    TaxPern = DDT3.Rows[l]["GSTPern"].ToString(),
                                    ConversionRate = DDT3.Rows[l]["ConversionRate"].ToString(),
                                });
                            }
                            string asdf = "";
                            list.Add(new PurchaseModel
                            {
                                ID = DDT.Rows[i]["ID"].ToString(),
                                DocID = DDT.Rows[i]["DocID"].ToString(),
                                DocPrefix = DDT.Rows[i]["Prefix"].ToString(),
                                Date = Convert.ToDateTime(DDT.Rows[i]["Date"].ToString()).ToString("yyyy-MM-dd"),
                                RefNo = DDT.Rows[i]["RefNo"].ToString(),
                                BranchID = DDT.Rows[i]["BranchID"].ToString(),
                                VendorID = DDT.Rows[i]["VendorID"].ToString(),

                                //VendorName = DDT.Rows[i]["Name"].ToString(),
                                GrossAmt = DDT.Rows[i]["GrossAmt"].ToString(),
                                TaxAmt = DDT.Rows[i]["TaxAmt"].ToString(),
                                NetAmt = DDT.Rows[i]["NetAmt"].ToString(),
                                Status = DDT.Rows[i]["Status"].ToString(),
                                ProdGroupID = DDT.Rows[i]["ProdGroupID"].ToString(),
                                TaxTypeID = DDT.Rows[i]["TaxTypeID"].ToString(),
                                PriceID = DDT.Rows[i]["PriceType"].ToString(),
                                PaymentModeID = DDT.Rows[i]["PaymentModeID"].ToString(),
                                PaymentTermID = DDT.Rows[i]["PaymentTermID"].ToString(),
                                PaymentDate = DDT.Rows[i]["PaymentDate"].ToString(),
                                VehicleNo = DDT.Rows[i]["VehicleNo"].ToString(),
                                Frieght = DDT.Rows[i]["Frieght"].ToString(),
                                OtherChargePern = DDT.Rows[i]["OtherChrgPern"].ToString(),
                                OtherChargeAmt = DDT.Rows[i]["OtherChargeAmt"].ToString(),
                                ProdDiscPern = DDT.Rows[i]["ProdPern"].ToString(),
                                TradeDiscPern = DDT.Rows[i]["TradePern"].ToString(),
                                AddnlDiscPern = DDT.Rows[i]["AddnlPern"].ToString(),
                                TotalProdDiscAmt = DDT.Rows[i]["TotalProdDiscAmt"].ToString(),
                                TotalTradeDiscAmt = DDT.Rows[i]["TotalTradeDiscAmt"].ToString(),
                                TotalAddnlDiscAmt = DDT.Rows[i]["TotalAddnlDiscAmt"].ToString(),
                                WriteOffAmt = DDT.Rows[i]["WriteOffAmt"].ToString(),
                                RoundOffAmt = DDT.Rows[i]["RoundOffAmt"].ToString(),
                                Balance = DDT.Rows[i]["Balance"].ToString(),
                                PymtID = DDT.Rows[i]["PymtID"].ToString(),
                                OrgId = DDT.Rows[i]["OrgId"].ToString(),
                                UDFId = DDT.Rows[i]["UDFId"].ToString(),
                                UDFDocId = DDT.Rows[i]["UDFDocId"].ToString(),
                                UDFDocPrefix = DDT.Rows[i]["UDFDocPrefix"].ToString(),
                                UDFDocValue = DDT.Rows[i]["UDFDocValue"].ToString(),
                                ReturnType = DDT.Rows[i]["ReturnType"].ToString(),
                                TransactionType = DDT.Rows[i]["TransactionType"].ToString(),

                                TCSTaxPern = DDT.Rows[i]["TCSTaxPern"].ToString(),
                                TCSTaxAmt = DDT.Rows[i]["TCSTaxAmt"].ToString(),
                                TDSAmount = DDT.Rows[i]["TDSAmount"].ToString(),
                                IRN = DDT.Rows[i]["IRN"].ToString(),
                                AckNo = DDT.Rows[i]["AckNo"].ToString(),
                                AckDate = DDT.Rows[i]["AckDate"].ToString(),
                                AckStatus = DDT.Rows[i]["AckStatus"].ToString(),
                                SignedQRCode = DDT.Rows[i]["SignedQRCode"].ToString(),
                                EWBNo = DDT.Rows[i]["EWBNo"].ToString(),
                                Distance = DDT.Rows[i]["Distance"].ToString(),
                                TransMode = DDT.Rows[i]["TransMode"].ToString(),
                                VehicleType = DDT.Rows[i]["VehicleType"].ToString(),
                                TransportID = DDT.Rows[i]["TransportID"].ToString(),
                                TransportName = DDT.Rows[i]["TransportName"].ToString(),
                                Remarks = DDT.Rows[i]["Remarks"].ToString(),
                                Narration = DDT.Rows[i]["Narration"].ToString(),
                                DiffValueGross = DDT.Rows[i]["DiffValueGross"].ToString(),
                                DiffValueNet = DDT.Rows[i]["DiffValueNet"].ToString(),
                                lstPartyInfo = listParty,
                                lstProdGrid = listProductGrid,
                                lstBatchInfo = listBatch
                            });
                        }
                    }
                    return Ok(list);
                }
                if (Mode == "14")
                {
                    DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseReturnData", Mode, CodeName, ID);
                    List<PurchaseDetail> list = new List<PurchaseDetail>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new PurchaseDetail
                        {
                            HID = DDT.Rows[i][0].ToString(),
                            Date = DDT.Rows[i][1].ToString(),
                            MRP = DDT.Rows[i][2].ToString(),
                            UomQty = DDT.Rows[i][3].ToString(),
                            UomID = DDT.Rows[i][4].ToString(),
                            PurchasePrice = DDT.Rows[i][5].ToString(),
                            ProdDiscPern = DDT.Rows[i][6].ToString(),
                            TradeDiscPern = DDT.Rows[i][7].ToString(),
                            AddnlDiscPern = DDT.Rows[i][8].ToString(),
                            SalePrice = DDT.Rows[i][9].ToString(),
                            ECP = DDT.Rows[i][10].ToString(),
                            SPLPrice = DDT.Rows[i][11].ToString(),
                            ReturnPrice = DDT.Rows[i][12].ToString(),
                            BatchNo = DDT.Rows[i][13].ToString(),
                            PKD = DDT.Rows[i][14].ToString(),
                            Expiry = DDT.Rows[i][15].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "15")
                {
                    DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseReturnData", Mode, null, CodeName);
                    return Ok("0");
                }
                if (Mode == "16")
                {
                    string trkPKD = "False", trkBATCH = "False", trkTrkInv = "True";
                    DataTable dtProdinfo = bl.BL_ExecuteSqlQuery("select TrackBatch,TrackPDK,TrackInventory,PurchaseTaxID,MT.GST from tblMasterProduct MP JOIN tblMasterTax MT ON MT.TaxID = MP.PurchaseTaxID WHERE MP.ID = " + CodeName);
                    if (dtProdinfo.Rows.Count > 0)
                    {
                        trkPKD = dtProdinfo.Rows[0]["TrackPDK"].ToString();
                        trkBATCH = dtProdinfo.Rows[0]["TrackBatch"].ToString();
                        trkTrkInv = dtProdinfo.Rows[0]["TrackInventory"].ToString();
                    }
                    List<PurchaseBatchInfo> ulistBatch = new List<PurchaseBatchInfo>();
                    //string Mode, string CodeName, string ID = null,string BranchID = "0",string Date ="", string PriceID = "1"
                    //DataTable dtBatch = bl.BL_ExecuteParamSP("uspGetSetPurchaseReturnData", 41, DDT.Rows[i][0].ToString(),PriceID,12,
                    //    BranchID,Convert.ToDateTime(Date));
                    DataTable dtBatch = bl.BL_ExecuteParamSP("uspGetPRProductIntoryBatch", CodeName, BranchID, Convert.ToDateTime(Date), PriceID, ID, DraftID);
                    for (int j = 0; j < dtBatch.Rows.Count; j++)
                    {
                        string PKD = !string.IsNullOrEmpty(dtBatch.Rows[j]["PKDDate"].ToString()) ? Convert.ToDateTime(dtBatch.Rows[j]["PKDDate"].ToString()).ToString("yyyy-MM-dd") : "";//dd/MM/yyyy
                        string Exp = !string.IsNullOrEmpty(dtBatch.Rows[j]["ExpiryDate"].ToString()) ? Convert.ToDateTime(dtBatch.Rows[j]["ExpiryDate"].ToString()).ToString("yyyy-MM-dd") : "";
                        ulistBatch.Add(new PurchaseBatchInfo
                        {
                            InventoryID = dtBatch.Rows[j]["InventoryID"].ToString(),
                            ProdID = dtBatch.Rows[j]["ProdID"].ToString(),
                            BatchNo = dtBatch.Rows[j]["BatchNumber"].ToString(),
                            PKDDate = PKD,//dtBatch.Rows[j]["PKDDate"].ToString(),
                            ExpiryDate = Exp,// dtBatch.Rows[j]["ExpiryDate"].ToString(),
                            ActQty = dtBatch.Rows[j]["ActualQty"].ToString(),
                            ActFreeQty = dtBatch.Rows[j]["ActualFreeQty"].ToString(),
                            ActDmgQty = dtBatch.Rows[j]["ActualDmgQty"].ToString(),
                            MRP = dtBatch.Rows[j]["MRP"].ToString(),
                            PurchasePrice = dtBatch.Rows[j]["PurchasePrice"].ToString(),
                            ReturnPrice = dtBatch.Rows[j]["ReturnPrice"].ToString(),
                            TrackBatch = trkBATCH,
                            TrackPKD = trkPKD,
                            Qty = dtBatch.Rows[j]["Qty"].ToString(),
                            FreeQty = dtBatch.Rows[j]["FreeQty"].ToString(),
                            DmgQty = dtBatch.Rows[j]["DmgQty"].ToString(),
                            TaxID = dtProdinfo.Rows[0]["PurchaseTaxID"].ToString(),
                            TaxPern = dtProdinfo.Rows[0]["GST"].ToString(),
                        });
                    }
                    return Ok(ulistBatch);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("PurchaseReturn", "purchasereturn/get", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/purchasereturn/variantdata")]
        public IHttpActionResult variantdata(string VariantType, string ID, string PartyID)
        {
            try
            {
                DataSet dtPRData = bl.BL_ExecuteParamSPDataset("uspPurchaseReturnVariantData", VariantType, ID, PartyID);
                DataTable DDT1 = dtPRData.Tables[0];//Vendor Details
                DataTable DDT = dtPRData.Tables[1];//Header Details
                DataTable DDT2 = dtPRData.Tables[2];//Item Details
                DataTable DDT3 = dtPRData.Tables[3];//Batch Details
                DataTable dtReasons = dtPRData.Tables[4];//Reason Data
                //////////////////
                List<PurchaseModel> list = new List<PurchaseModel>();
                if (DDT.Rows.Count > 0)
                {
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        List<CustomerVendorModel> listParty = new List<CustomerVendorModel>();
                        for (int j = 0; j < DDT1.Rows.Count; j++)
                        {
                            listParty.Add(new CustomerVendorModel
                            {
                                ID = DDT1.Rows[j]["ID"].ToString(),
                                Code = DDT1.Rows[j]["Code"].ToString(),
                                Name = DDT1.Rows[j]["Name"].ToString(),
                                Billadd1 = DDT1.Rows[j]["Billadd1"].ToString(),
                                Billadd2 = DDT1.Rows[j]["Billadd2"].ToString(),
                                Billadd3 = DDT1.Rows[j]["Billadd3"].ToString(),
                                Shipadd1 = DDT1.Rows[j]["Shipadd1"].ToString(),
                                Shipadd2 = DDT1.Rows[j]["shipadd2"].ToString(),
                                Shipadd3 = DDT1.Rows[j]["Shipadd3"].ToString(),
                                Pincode = DDT1.Rows[j]["Pincode"].ToString(),
                                ContactPerson = DDT1.Rows[j]["ContactPerson"].ToString(),
                                Ph1 = DDT1.Rows[j]["Ph1"].ToString(),
                                Ph2 = DDT1.Rows[j]["Ph2"].ToString(),
                                Mob1 = DDT1.Rows[j]["Mob1"].ToString(),
                                Mob2 = DDT1.Rows[j]["Mob2"].ToString(),
                                Email = DDT1.Rows[j]["Email"].ToString(),
                                PANNumber = DDT1.Rows[j]["PANNumber"].ToString(),
                                AadharNo = DDT1.Rows[j]["AadharNo"].ToString(),
                                DLNo20 = DDT1.Rows[j]["DLNo20"].ToString(),
                                DLNo21 = DDT1.Rows[j]["DLNo21"].ToString(),
                                FSSAINo = DDT1.Rows[j]["FSSAINo"].ToString(),
                                StateID = DDT1.Rows[j]["StateID"].ToString(),
                                GSTIN = DDT1.Rows[j]["GSTIN"].ToString(),
                                CreditTermID = DDT1.Rows[j]["CreditTermID"].ToString(),
                                PaymentModeID = DDT1.Rows[j]["PaymentModeID"].ToString(),
                                TaxTypeID = DDT1.Rows[j]["TaxTypeID"].ToString(),
                                FAID = DDT1.Rows[j]["FAID"].ToString(),
                                WeekCycle = DDT1.Rows[j]["WeekCycle"].ToString(),
                                Active = DDT1.Rows[j]["Active"].ToString(),
                                Ratings = DDT1.Rows[j]["Rating"].ToString(),
                            });
                        }
                        List<SingleMasterModel> listReasons = new List<SingleMasterModel>();
                        for (int j = 0; j < dtReasons.Rows.Count; j++)
                        {
                            listReasons.Add(new SingleMasterModel
                            {
                                ID = dtReasons.Rows[j][0].ToString(),
                                Name = dtReasons.Rows[j][1].ToString()
                            });
                        }
                        List<PurchaseGridData> listProductGrid = new List<PurchaseGridData>();
                        for (int k = 0; k < DDT2.Rows.Count; k++)
                        {
                            listProductGrid.Add(new PurchaseGridData
                            {
                                ProdID = DDT2.Rows[k]["ProdID"].ToString(),
                                UomID = DDT2.Rows[k]["UomID"].ToString(),
                                ReasonID = DDT2.Rows[k]["ReasonId"].ToString(),
                                ReasonName = DDT2.Rows[k]["ReasonName"].ToString(),
                                Code = DDT2.Rows[k]["Code"].ToString(),
                                Name = DDT2.Rows[k]["Name"].ToString(),
                                HSNCode = DDT2.Rows[k]["HSNCode"].ToString(),
                                UOM = DDT2.Rows[k]["UOM"].ToString(),
                                Qty = DDT2.Rows[k]["Qty"].ToString(),
                                FreeQty = DDT2.Rows[k]["FreeQty"].ToString(),
                                DmgQty = DDT2.Rows[k]["DmgQty"].ToString(),
                                ProdPern = DDT2.Rows[k]["ProdPern"].ToString(),
                                TradePern = DDT2.Rows[k]["TradePern"].ToString(),
                                AddnlPern = DDT2.Rows[k]["AddnlPern"].ToString(),
                                ProdAmt = DDT2.Rows[k]["ProdDiscAmt"].ToString(),
                                TradeAmt = DDT2.Rows[k]["TradeDiscAmt"].ToString(),
                                AddnlAmt = DDT2.Rows[k]["AddnlDiscAmt"].ToString(),
                                TaxPern = DDT2.Rows[k]["TaxPern"].ToString(),
                                GoodsAmt = DDT2.Rows[k]["GoodsAmt"].ToString(),
                                GrossAmt = DDT2.Rows[k]["GrossAmt"].ToString(),
                                TaxAmt = DDT2.Rows[k]["TaxAmt"].ToString(),
                                TaxName = DDT2.Rows[k]["TaxName"].ToString(),
                                NetAmt = DDT2.Rows[k]["NetAmt"].ToString(),
                                TransactionPrice = DDT2.Rows[k]["PurchaseReturnPrice"].ToString(),
                                DiffAmt = DDT2.Rows[k]["DiffAmt"].ToString(),
                                MRPonTax = DDT2.Rows[k]["MRPonTaxAmt"].ToString(),
                                CumMRPonTax = DDT2.Rows[k]["CumMRPonTax"].ToString(),
                                lstReason = listReasons
                            });
                        }
                        List<PurchaseBatchInfo> listBatch = new List<PurchaseBatchInfo>();
                        for (int l = 0; l < DDT3.Rows.Count; l++)
                        {
                            listBatch.Add(new PurchaseBatchInfo
                            {
                                InventoryID = DDT3.Rows[l]["InventoryID"].ToString(),
                                ProdID = DDT3.Rows[l]["ProdID"].ToString(),
                                BatchNo = DDT3.Rows[l]["BatchNumber"].ToString(),
                                PKDDate = !string.IsNullOrEmpty(DDT3.Rows[l]["PKDDate"].ToString()) ? Convert.ToDateTime(DDT3.Rows[l]["PKDDate"].ToString()).ToString("yyyy-MM-dd") : "",
                                ExpiryDate = !string.IsNullOrEmpty(DDT3.Rows[l]["ExpiryDate"].ToString()) ? Convert.ToDateTime(DDT3.Rows[l]["ExpiryDate"].ToString()).ToString("yyyy-MM-dd") : "",
                                //DDT3.Rows[l]["ExpiryDate"].ToString(),
                                ActQty = DDT3.Rows[l]["Qty"].ToString(),
                                ActFreeQty = DDT3.Rows[l]["FreeQty"].ToString(),
                                ActDmgQty = DDT3.Rows[l]["DmgQty"].ToString(),
                                MRP = DDT3.Rows[l]["MRP"].ToString(),
                                OrgRTNPrice = DDT3.Rows[l]["PurchasePrice"].ToString(),
                                ReturnPrice = DDT3.Rows[l]["ReturnPrice"].ToString(),
                                UOMPrice = DDT3.Rows[l]["UOMPrice"].ToString(),
                                Qty = DDT3.Rows[l]["PRQty"].ToString(),
                                FreeQty = DDT3.Rows[l]["PRFree"].ToString(),
                                DmgQty = DDT3.Rows[l]["PRDmg"].ToString(),
                                TaxName = DDT3.Rows[l]["TaxName"].ToString(),
                                TaxID = DDT3.Rows[l]["PurchaseTaxID"].ToString(),
                                TaxPern = DDT3.Rows[l]["GSTPern"].ToString(),
                                ConversionRate = DDT3.Rows[l]["ConversionRate"].ToString(),
                            });
                        }
                        string asdf = "";
                        list.Add(new PurchaseModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            DocID = DDT.Rows[i]["DocID"].ToString(),
                            DocPrefix = DDT.Rows[i]["Prefix"].ToString(),
                            Date = Convert.ToDateTime(DDT.Rows[i]["Date"].ToString()).ToString("yyyy-MM-dd"),
                            RefNo = DDT.Rows[i]["RefNo"].ToString(),
                            BranchID = DDT.Rows[i]["BranchID"].ToString(),
                            VendorID = DDT1.Rows[0]["ID"].ToString(),

                            //VendorName = DDT.Rows[i]["Name"].ToString(),
                            GrossAmt = DDT.Rows[i]["GrossAmt"].ToString(),
                            TaxAmt = DDT.Rows[i]["TaxAmt"].ToString(),
                            NetAmt = DDT.Rows[i]["NetAmt"].ToString(),
                            Status = DDT.Rows[i]["Status"].ToString(),
                            ProdGroupID = DDT.Rows[i]["ProdGroupID"].ToString(),
                            TaxTypeID = DDT.Rows[i]["TaxTypeID"].ToString(),
                            PriceID = DDT.Rows[i]["PriceType"].ToString(),
                            PaymentModeID = DDT.Rows[i]["PaymentModeID"].ToString(),
                            PaymentTermID = DDT.Rows[i]["PaymentTermID"].ToString(),
                            PaymentDate = DDT.Rows[i]["PaymentDate"].ToString(),
                            VehicleNo = DDT.Rows[i]["VehicleNo"].ToString(),
                            Frieght = DDT.Rows[i]["Frieght"].ToString(),
                            OtherChargePern = DDT.Rows[i]["OtherChrgPern"].ToString(),
                            OtherChargeAmt = DDT.Rows[i]["OtherChargeAmt"].ToString(),
                            ProdDiscPern = DDT.Rows[i]["ProdPern"].ToString(),
                            TradeDiscPern = DDT.Rows[i]["TradePern"].ToString(),
                            AddnlDiscPern = DDT.Rows[i]["AddnlPern"].ToString(),
                            TotalProdDiscAmt = DDT.Rows[i]["TotalProdDiscAmt"].ToString(),
                            TotalTradeDiscAmt = DDT.Rows[i]["TotalTradeDiscAmt"].ToString(),
                            TotalAddnlDiscAmt = DDT.Rows[i]["TotalAddnlDiscAmt"].ToString(),
                            WriteOffAmt = DDT.Rows[i]["WriteOffAmt"].ToString(),
                            RoundOffAmt = DDT.Rows[i]["RoundOffAmt"].ToString(),
                            Balance = DDT.Rows[i]["Balance"].ToString(),
                            PymtID = DDT.Rows[i]["PymtID"].ToString(),
                            OrgId = DDT.Rows[i]["OrgId"].ToString(),
                            UDFId = DDT.Rows[i]["UDFId"].ToString(),
                            UDFDocId = DDT.Rows[i]["UDFDocId"].ToString(),
                            UDFDocPrefix = DDT.Rows[i]["UDFDocPrefix"].ToString(),
                            UDFDocValue = DDT.Rows[i]["UDFDocValue"].ToString(),
                            ReturnType = DDT.Rows[i]["ReturnType"].ToString(),
                            TransactionType = DDT.Rows[i]["TransactionType"].ToString(),

                            TCSTaxPern = DDT.Rows[i]["TCSTaxPern"].ToString(),
                            TCSTaxAmt = DDT.Rows[i]["TCSTaxAmt"].ToString(),
                            TDSAmount = DDT.Rows[i]["TDSAmount"].ToString(),
                            IRN = DDT.Rows[i]["IRN"].ToString(),
                            AckNo = DDT.Rows[i]["AckNo"].ToString(),
                            AckDate = DDT.Rows[i]["AckDate"].ToString(),
                            AckStatus = DDT.Rows[i]["AckStatus"].ToString(),
                            SignedQRCode = DDT.Rows[i]["SignedQRCode"].ToString(),
                            EWBNo = DDT.Rows[i]["EWBNo"].ToString(),
                            Distance = DDT.Rows[i]["Distance"].ToString(),
                            TransMode = DDT.Rows[i]["TransMode"].ToString(),
                            VehicleType = DDT.Rows[i]["VehicleType"].ToString(),
                            TransportID = DDT.Rows[i]["TransportID"].ToString(),
                            TransportName = DDT.Rows[i]["TransportName"].ToString(),
                            Remarks = DDT.Rows[i]["Remarks"].ToString(),
                            Narration = DDT.Rows[i]["Narration"].ToString(),
                            DiffValueGross = DDT.Rows[i]["DiffValueGross"].ToString(),
                            DiffValueNet = DDT.Rows[i]["DiffValueNet"].ToString(),
                            lstPartyInfo = listParty,
                            lstProdGrid = listProductGrid,
                            lstBatchInfo = listBatch
                        });
                    }
                }
                return Ok(list);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("PurchaseReturn", "purchasereturn/get", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/purchasereturn/getfilterdata")]
        public IHttpActionResult GetFilterData(string TransID, string FType, string Branch, string Party, string FromDate, string ToDate, string Showall)
        {
            try
            {
                //if (Mode == "6" || Mode == "9")
                {
                    string Mode = FType == "1" ? "6" : "10";
                    DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseReturnData", Mode, FType, Branch, TransID, Party, FromDate, ToDate, Showall);
                    List<PurchaseModel> list = new List<PurchaseModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new PurchaseModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            DocID = DDT.Rows[i]["DocID"].ToString(),
                            Date = DDT.Rows[i]["DocDate"].ToString(),
                            RefNo = DDT.Rows[i]["RefNo"].ToString(),
                            BranchID = DDT.Rows[i]["Branch"].ToString(),
                            VendorID = DDT.Rows[i]["Party"].ToString(),
                            GrossAmt = DDT.Rows[i]["GrossAmt"].ToString(),
                            TaxAmt = DDT.Rows[i]["TaxAmt"].ToString(),
                            NetAmt = DDT.Rows[i]["NetAmt"].ToString(),
                            Status = DDT.Rows[i]["Status"].ToString(),
                            Balance = DDT.Rows[i]["Balance"].ToString(),
                            CBy = DDT.Rows[i]["UserName"].ToString(),
                            CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                            CurrentStatus = DDT.Rows[i]["StatusID"].ToString(),
                            Remarks = DDT.Rows[i]["Remarks"].ToString(),
                            Narration = DDT.Rows[i]["Narration"].ToString()
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("PurchaseReturn", "purchasereturn/getfilterdata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/purchasereturn/manufproducts")]
        public IHttpActionResult GetPRManufProds(string BranchID, string PriceType, string ManufID, string TransDate)
        {
            try
            {
                var ManufProdData = new List<object>();
                DataSet ds = bl.BL_ExecuteParamSPDataset("uspGerPRManufProducts", ManufID, BranchID, PriceType, TransDate);
                DataTable dtProduts = ds.Tables[0];
                DataTable dtBatches = ds.Tables[1];
                if (dtProduts.Rows.Count > 0)
                {
                    List<PurchaseGridData> listProductGrid = new List<PurchaseGridData>();                    
                    for (int k = 0; k < dtProduts.Rows.Count; k++)
                    {
                        listProductGrid.Add(new PurchaseGridData
                        {
                            ProdID = dtProduts.Rows[k]["ProdID"].ToString(),
                            UomID = dtProduts.Rows[k]["UomID"].ToString(),
                            ReasonID = dtProduts.Rows[k]["ReasonId"].ToString(),
                            ReasonName = dtProduts.Rows[k]["ReasonName"].ToString(),
                            Code = dtProduts.Rows[k]["Code"].ToString(),
                            Name = dtProduts.Rows[k]["Name"].ToString(),
                            HSNCode = dtProduts.Rows[k]["HSNCode"].ToString(),
                            UOM = dtProduts.Rows[k]["UOM"].ToString(),
                            Qty = dtProduts.Rows[k]["Qty"].ToString(),
                            FreeQty = dtProduts.Rows[k]["FreeQty"].ToString(),
                            DmgQty = dtProduts.Rows[k]["DmgQty"].ToString(),
                            ProdPern = dtProduts.Rows[k]["ProdPern"].ToString(),
                            TradePern = dtProduts.Rows[k]["TradePern"].ToString(),
                            AddnlPern = dtProduts.Rows[k]["AddnlPern"].ToString(),
                            ProdAmt = dtProduts.Rows[k]["ProdDiscAmt"].ToString(),
                            TradeAmt = dtProduts.Rows[k]["TradeDiscAmt"].ToString(),
                            AddnlAmt = dtProduts.Rows[k]["AddnlDiscAmt"].ToString(),
                            TaxPern = dtProduts.Rows[k]["TaxPern"].ToString(),
                            GoodsAmt = dtProduts.Rows[k]["GoodsAmt"].ToString(),
                            GrossAmt = dtProduts.Rows[k]["GrossAmt"].ToString(),
                            TaxAmt = dtProduts.Rows[k]["TaxAmt"].ToString(),
                            TaxName = dtProduts.Rows[k]["TaxName"].ToString(),
                            NetAmt = dtProduts.Rows[k]["NetAmt"].ToString(),
                            TransactionPrice = dtProduts.Rows[k]["PurchaseReturnPrice"].ToString(),
                            DiffAmt = dtProduts.Rows[k]["DiffAmt"].ToString(),
                            MRPonTax = dtProduts.Rows[k]["MRPonTaxAmt"].ToString(),
                            CumMRPonTax = dtProduts.Rows[k]["CumMRPonTax"].ToString(),
                        });
                    }
                    List<PurchaseBatchInfo> listBatch = new List<PurchaseBatchInfo>();                    
                    for (int l = 0; l < dtBatches.Rows.Count; l++)
                    {
                        listBatch.Add(new PurchaseBatchInfo
                        {
                            InventoryID = dtBatches.Rows[l]["InventoryID"].ToString(),
                            ProdID = dtBatches.Rows[l]["ProdID"].ToString(),
                            BatchNo = dtBatches.Rows[l]["BatchNumber"].ToString(),
                            PKDDate = !string.IsNullOrEmpty(dtBatches.Rows[l]["PKDDate"].ToString()) ? Convert.ToDateTime(dtBatches.Rows[l]["PKDDate"].ToString()).ToString("yyyy-MM-dd") : "",
                            ExpiryDate = !string.IsNullOrEmpty(dtBatches.Rows[l]["ExpiryDate"].ToString()) ? Convert.ToDateTime(dtBatches.Rows[l]["ExpiryDate"].ToString()).ToString("yyyy-MM-dd") : "",
                            //dtBatches.Rows[l]["ExpiryDate"].ToString(),
                            Qty = dtBatches.Rows[l]["Qty"].ToString(),
                            FreeQty = dtBatches.Rows[l]["FreeQty"].ToString(),
                            DmgQty = dtBatches.Rows[l]["DmgQty"].ToString(),
                            MRP = dtBatches.Rows[l]["MRP"].ToString(),
                            OrgRTNPrice = dtBatches.Rows[l]["PurchasePrice"].ToString(),
                            ReturnPrice = dtBatches.Rows[l]["ReturnPrice"].ToString(),
                            ActQty = dtBatches.Rows[l]["PRQty"].ToString(),
                            ActFreeQty = dtBatches.Rows[l]["PRFree"].ToString(),
                            ActDmgQty = dtBatches.Rows[l]["PRDmg"].ToString(),
                            TaxName = dtBatches.Rows[l]["TaxName"].ToString(),
                            TaxID = dtBatches.Rows[l]["PurchaseTaxID"].ToString(),
                            TaxPern = dtBatches.Rows[l]["GSTPern"].ToString(),
                            ConversionRate = dtBatches.Rows[l]["ConversionRate"].ToString(),
                        });
                    }

                    ManufProdData.Add(new
                    {
                        ProductData = listProductGrid,
                        BatchData = listBatch
                    });
                    return Ok(ManufProdData);
                }
                else
                {
                    return Ok(ManufProdData);
                }
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Purchase Return", "GetPRManufProds", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/purchasereturn/pricetypechange")]
        public IHttpActionResult GetPTChangeProds(List<PRPriceTypechange> PRBatch)
        {
            try
            {
                string BranchID = "", PriceType = "", ProdID = "", TransDate = "", PRID = "";
                decimal GoodsAmt = 0;
                var ManufProdData = new List<object>();
                
                DataTable dtBatches = bl.BL_ExecuteParamSP("uspGetPRProductIntoryBatch", BranchID, TransDate, PriceType, PRID);
                if (dtBatches.Rows.Count > 0)
                {                    
                    List<PurchaseBatchInfo> listBatch = new List<PurchaseBatchInfo>();
                    for (int l = 0; l < dtBatches.Rows.Count; l++)
                    {
                        if(l == 0)
                        {

                        }
                        listBatch.Add(new PurchaseBatchInfo
                        {
                            InventoryID = dtBatches.Rows[l]["InventoryID"].ToString(),
                            ProdID = dtBatches.Rows[l]["ProdID"].ToString(),
                            BatchNo = dtBatches.Rows[l]["BatchNumber"].ToString(),
                            PKDDate = !string.IsNullOrEmpty(dtBatches.Rows[l]["PKDDate"].ToString()) ? Convert.ToDateTime(dtBatches.Rows[l]["PKDDate"].ToString()).ToString("yyyy-MM-dd") : "",
                            ExpiryDate = !string.IsNullOrEmpty(dtBatches.Rows[l]["ExpiryDate"].ToString()) ? Convert.ToDateTime(dtBatches.Rows[l]["ExpiryDate"].ToString()).ToString("yyyy-MM-dd") : "",
                            //dtBatches.Rows[l]["ExpiryDate"].ToString(),
                            ActQty = dtBatches.Rows[l]["Qty"].ToString(),
                            ActFreeQty = dtBatches.Rows[l]["FreeQty"].ToString(),
                            ActDmgQty = dtBatches.Rows[l]["DmgQty"].ToString(),
                            MRP = dtBatches.Rows[l]["MRP"].ToString(),
                            OrgRTNPrice = dtBatches.Rows[l]["PurchasePrice"].ToString(),
                            ReturnPrice = dtBatches.Rows[l]["ReturnPrice"].ToString(),
                            Qty = dtBatches.Rows[l]["PRQty"].ToString(),
                            FreeQty = dtBatches.Rows[l]["PRFree"].ToString(),
                            DmgQty = dtBatches.Rows[l]["PRDmg"].ToString(),
                            TaxName = dtBatches.Rows[l]["TaxName"].ToString(),
                            TaxID = dtBatches.Rows[l]["PurchaseTaxID"].ToString(),
                            TaxPern = dtBatches.Rows[l]["GSTPern"].ToString(),
                            ConversionRate = dtBatches.Rows[l]["ConversionRate"].ToString(),
                        });
                    }

                    ManufProdData.Add(new
                    {
                        BatchData = listBatch
                    });
                    return Ok(ManufProdData);
                }
                else
                {
                    return Ok(ManufProdData);
                }
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Purchase Return", "GetPRManufProds", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/purchasereturn/save")]
        public IHttpActionResult Save(PurchaseModel listTrans)
        {
            try
            {
                if (listTrans != null)
                {
                    dtGSTInfo.Columns.Add("TransID", typeof(int));
                    dtGSTInfo.Columns.Add("TransIdentID", typeof(int));
                    dtGSTInfo.Columns.Add("ProdID", typeof(int));
                    dtGSTInfo.Columns.Add("TaxID", typeof(int));
                    dtGSTInfo.Columns.Add("GSTTaxTypeID", typeof(int));
                    dtGSTInfo.Columns.Add("TaxTypeID", typeof(int));
                    dtGSTInfo.Columns.Add("TaxCompID", typeof(int));
                    dtGSTInfo.Columns.Add("TaxCompPern", typeof(decimal));
                    dtGSTInfo.Columns.Add("TaxCompAmount", typeof(decimal));
                    dtGSTInfo.Columns.Add("GrossAmount", typeof(decimal));
                    dtGSTInfo.Columns.Add("TransSerial", typeof(int));
                    dtGSTInfo.Columns.Add("SerialNo", typeof(int));
                    int nBillScopeID = 0; decimal MRPonTaxAMt = 0;
                    DataTable dtBatch = ToDataTable(listTrans.lstBatchInfo);
                    DataTable dtProducts = ToDataTable(listTrans.lstProdInfo);
                    List<SaveMessage> list = new List<SaveMessage>();
                    if (listTrans.TransMode != "4")
                    {
                        if (listTrans.IsDraft == "0")
                        {
                            bl.bl_Transaction(1);
                            try
                            {
                                int nMode = listTrans.TransMode == "2" ? 3 : 6;
                                DataTable dtResult = bl.bl_ManageTrans("uspManagePRHeader", listTrans.TransMode, nMode, listTrans.CBy, bl.BL_nValidation(listTrans.ID), listTrans.Remarks, listTrans.Narration,
                                    bl.BL_nValidation(listTrans.BranchID), listTrans.VendorID, listTrans.Date, bl.BL_dValidation(listTrans.TotalProdDiscAmt), bl.BL_dValidation(listTrans.GrossAmt), bl.BL_dValidation(listTrans.TaxAmt),
                                    bl.BL_dValidation(listTrans.NetAmt), listTrans.RefNo, listTrans.PaymentModeID, listTrans.ProdGroupID,
                                    listTrans.TaxTypeID, listTrans.VehicleNo, bl.BL_dValidation(listTrans.TradeDiscPern), bl.BL_dValidation(listTrans.TotalTradeDiscAmt),
                                    bl.BL_dValidation(listTrans.AddnlDiscPern), bl.BL_dValidation(listTrans.TotalAddnlDiscAmt),
                                    bl.BL_dValidation(listTrans.Frieght), bl.BL_dValidation(listTrans.OtherChargePern), bl.BL_dValidation(listTrans.OtherChargeAmt),
                                    bl.BL_dValidation(listTrans.WriteOffAmt), bl.BL_dValidation(listTrans.RoundOffAmt), listTrans.UDFId, bl.BL_dValidation(listTrans.ReturnType), bl.BL_nValidation(listTrans.CurrentStatus),
                                    null, bl.BL_dValidation(listTrans.TCSTaxPern), bl.BL_dValidation(listTrans.TCSTaxAmt), 1, listTrans.DraftID
                                    , listTrans.PriceID, bl.BL_dValidation(listTrans.DiffValueGross), bl.BL_dValidation(listTrans.DiffValueNet));
                                if (dtResult.Columns.Count == 1)
                                {
                                    int nPRID = bl.BL_nValidation(dtResult.Rows[0][0].ToString());
                                    for (int i = 0; i < dtProducts.Rows.Count; i++)
                                    {
                                        int nProdID = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["ProdID"]));
                                        if (nProdID > 0)
                                        {

                                            DataRow[] dr = dtBatch.Select("ProdID = '" + nProdID + "'", null);
                                            foreach (DataRow iRow in dr)
                                            {
                                                dtGSTInfo.Rows.Clear();
                                                //DataTable getConvFact = bl.BL_ExecuteSqlQuery("select dbo.fnGetConvertionFact(" + bl.BL_nValidation(dgvProd.Rows[DetailCount].Cells[UomGrpID.Name].Value) + "," + bl.BL_nValidation(dgvProd.Rows[DetailCount].Cells[UomID.Name].Value) + ")");
                                                decimal dUomTax = 0;// bl.GetUOMTaxValue(bl.BL_nValidation(iRow["TaxID"]), bl.BL_nValidation(txtTaxType.Tag),
                                                                    //(bl.BL_dValidation(iRow["Qty"]) + bl.BL_dValidation(iRow["DmgQty"])) * (getConvFact.Rows.Count > 0 ? bl.BL_dValidation(getConvFact.Rows[0][0].ToString()) : 0.00M));// bl.BL_dValidation(dgvProd.Rows[DetailCount].Cells[SelectedUomCF.Name].Value));

                                                decimal dQty = (bl.BL_dValidation(iRow["DmgQty"].ToString()) + bl.BL_dValidation(iRow["Qty"].ToString()));
                                                if (dQty > 0)
                                                {
                                                    int TaxID = bl.BL_nValidation(iRow["TaxID"].ToString());
                                                    int TaxTypeID = bl.BL_nValidation(listTrans.TaxTypeID);
                                                    decimal dMRP = bl.BL_dValidation(iRow["MRP"].ToString());
                                                    DataTable dtMTdetail = bl.bl_ManageTrans("uspGetTaxCumulative", TaxID, TaxTypeID, 1);
                                                    decimal dApponMRPCum = dtMTdetail.Select("AppOn = -1").Select(r => Convert.ToDecimal(r["CumulativeTax"])).DefaultIfEmpty(0).Sum();
                                                    if (dApponMRPCum > 0)
                                                    {
                                                        MRPonTaxAMt = bl.ReturnGrossorMRPTaxAmt(0, TaxID, TaxTypeID, 0, dMRP, true) * dQty;
                                                    }
                                                    decimal dGrs = dQty * bl.BL_dValidation(iRow["ReturnPrice"].ToString());
                                                    decimal dTax = dApponMRPCum > 0 ? MRPonTaxAMt : (dGrs * bl.BL_dValidation(iRow["TaxPern"].ToString())) / 100;
                                                    decimal dNet = dGrs + dTax;

                                                    string pkd = !string.IsNullOrEmpty(iRow["PKDDate"].ToString()) ? Convert.ToDateTime(iRow["PKDDate"]).ToString("yyyy-MM-dd") : null;
                                                    string exp = !string.IsNullOrEmpty(iRow["ExpiryDate"].ToString()) ? Convert.ToDateTime(iRow["ExpiryDate"]).ToString("yyyy-MM-dd") : null;
                                                    DataTable dtResultDetail = bl.bl_ManageTrans("uspManagePRDetail", listTrans.Date, nPRID, nProdID, bl.BL_nValidation(dtProducts.Rows[i]["UomID"].ToString()),
                                                        bl.BL_dValidation(iRow["Qty"].ToString()), bl.BL_dValidation(iRow["FreeQty"].ToString()), bl.BL_dValidation(iRow["DmgQty"].ToString()),
                                                        iRow["BatchNo"].ToString(), pkd, exp, bl.BL_dValidation(iRow["OrgRTNPrice"].ToString()),
                                                        bl.BL_dValidation(iRow["MRP"].ToString()), bl.BL_nValidation(iRow["TaxPern"].ToString()), bl.BL_dValidation(iRow["ReturnPrice"].ToString()),
                                                        bl.BL_dValidation(iRow["TaxPern"].ToString()), dGrs, bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["ProdDiscPern"])), dGrs, dTax,
                                                        dNet, bl.BL_nValidation(iRow["TaxID"].ToString()), listTrans.TaxTypeID, bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["ReasonId"])), (i + 1), bl.BL_nValidation(iRow["TaxID"].ToString()), 1, (i + 1),
                                                        bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["TradeDiscPern"])), bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["AddnlDiscPern"])), 1,
                                                        bl.BL_nValidation(listTrans.BranchID), listTrans.PriceID, bl.BL_dValidation(iRow["ConversionRate"].ToString()),
                                                        bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["DiffAmt"])),
                                                        bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["ProdDiscAmt"])),
                                                        bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["TradeDiscAmt"])),
                                                        bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["AddnlDiscAmt"])));
                                                    if (dtResultDetail.Rows.Count > 0)
                                                    {
                                                        string Error = "Qty Mismatched";// dtResultDetail.Rows[0][0].ToString();
                                                        bl.bl_Transaction(3);
                                                        list.Add(new SaveMessage()
                                                        {
                                                            ID = 0.ToString(),
                                                            MsgID = "2",
                                                            Message = Error,
                                                            RowID = nProdID.ToString()
                                                        });
                                                        return Ok(list);
                                                    }

                                                    nBillScopeID = bl.BL_nValidation(dtResult.Rows[0][0]);

                                                    int nTaxID = 0, nTaxTypeID = 0, SRSerial = 1, nTranSerial = 1;
                                                    decimal dQtnGrossAmount = 0.00M, dQtys = 0.00M;
                                                    dtGSTInfo.Rows.Clear();
                                                    //if (bl.BL_dValidation(dtProducts.Rows[nCount]["Qty"]) > 0)
                                                    //{
                                                    //nProdID = bl.BL_nValidation(dtProducts.Rows[nCount]["ProdID"]);

                                                    nTaxID = bl.BL_nValidation(iRow["TaxID"].ToString());
                                                    nTaxTypeID = bl.BL_nValidation(listTrans.TaxTypeID);

                                                    dQtnGrossAmount = dGrs;// bl.BL_dValidation(dtProducts.Rows[nCount]["GrossAmt"]);

                                                    //DataTable dtResultcv = bl.BL_GetColumnValBasedTwoCond("UomGroupMaster",
                                                    //Convert.ToString(dtProducts.Rows[nCount]["UomGrpID"]),
                                                    //Convert.ToString(dtProducts.Rows[nCount]["UomId"]));

                                                    //DataTable getConvFact = bl.BL_ExecuteSqlQuery("select dbo.fnGetConvertionFact(" + bl.BL_nValidation(dtProducts.Rows[nCount]["UomGrpID"]) + "," + bl.BL_nValidation(dtProducts.Rows[nCount]["UomId"]) + ")");

                                                    dQtys = (bl.BL_dValidation(iRow["Qty"].ToString()) + bl.BL_dValidation(iRow["DmgQty"].ToString())) * 1;// bl.BL_dValidation(dtResult.Rows[0][0]);
                                                    decimal newgrossamt = dApponMRPCum == 0 ? dQtnGrossAmount : bl.ReturnGrossorMRPTaxAmt(1, nTaxID, nTaxTypeID, dQtnGrossAmount,
                                           dMRP * dQtys, true);
                                                    DataTable dtTaxCompInfo = bl.bl_ManageTrans("uspGetTaxCompInfo", nTaxID, nTaxTypeID);
                                                    if (dtTaxCompInfo.Rows.Count > 0)
                                                    {
                                                        bool ValidtoCalc = false;

                                                        for (int nTaxComp = 0; nTaxComp < dtTaxCompInfo.Rows.Count; nTaxComp++)
                                                        {
                                                            ValidtoCalc = true;// nTaxTypeID == 2 && bl.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 1 ||
                                                                               //nTaxTypeID == 1 && bl.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 2 ? false : true;
                                                            DataRow drG = dtGSTInfo.NewRow();
                                                            drG["TransID"] = 12;
                                                            drG["TransIdentID"] = nBillScopeID;
                                                            drG["ProdID"] = nProdID;
                                                            drG["TaxID"] = nTaxID;
                                                            drG["GSTTaxTypeID"] = bl.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]);
                                                            drG["TaxTypeID"] = nTaxTypeID;
                                                            drG["TaxCompID"] = bl.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][0]);
                                                            drG["TaxCompPern"] = bl.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2]);
                                                            drG["TaxCompAmount"] = ValidtoCalc ? ((newgrossamt * bl.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2])) / 100) :
                                                                    bl.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2]) * dQtys;//dQtnGrossAmount
                                                            drG["GrossAmount"] = newgrossamt;// dQtnGrossAmount;
                                                                                             //drG["TransSerial"] = nTranSerial;
                                                            drG["TransSerial"] = (i + 1);
                                                            drG["SerialNo"] = SRSerial;
                                                            dtGSTInfo.Rows.Add(drG);
                                                            SRSerial++;
                                                        }
                                                        nTranSerial++;
                                                    }
                                                    //}

                                                    if (dtGSTInfo.Rows.Count > 0)
                                                    {
                                                        bl.bl_ManageTrans("uspSaveTranGSTInfo", dtGSTInfo);
                                                    }
                                                }
                                            }
                                        }
                                    }


                                    list.Add(new SaveMessage()
                                    {
                                        ID = nBillScopeID.ToString(),
                                        MsgID = "0",
                                        Message = "Saved Successfully"
                                    });
                                    bl.bl_Transaction(2);
                                    bl.BL_UpdateclosingDateforPosting(12, nPRID, Convert.ToDateTime(listTrans.Date));
                                    return Ok(list);
                                }
                                else
                                {
                                    bl.bl_Transaction(3);
                                    list.Add(new SaveMessage()
                                    {
                                        ID = 0.ToString(),
                                        MsgID = "1",
                                        Message = dtResult.Rows[0][0].ToString()
                                    });
                                    return Ok(list);
                                }
                            }
                            catch (Exception ex)
                            {
                                bl.bl_Transaction(3);
                                list.Add(new SaveMessage()
                                {
                                    ID = 0.ToString(),
                                    MsgID = "1",
                                    Message = ex.Message
                                });
                                return Ok(list);
                            }
                        }
                        else //  Draft
                        {
                            bl.bl_Transaction(1);
                            DataTable dtResult = bl.bl_ManageTrans("uspManagePRDraftHeader", listTrans.TransMode, 6, listTrans.CBy, bl.BL_nValidation(listTrans.ID),
                                bl.BL_nValidation(listTrans.BranchID), listTrans.VendorID, listTrans.Date, bl.BL_dValidation(listTrans.TotalProdDiscAmt), bl.BL_dValidation(listTrans.GrossAmt), bl.BL_dValidation(listTrans.TaxAmt),
                                bl.BL_dValidation(listTrans.NetAmt), listTrans.RefNo, listTrans.PaymentModeID, listTrans.ProdGroupID,
                                listTrans.TaxTypeID, listTrans.VehicleNo, bl.BL_dValidation(listTrans.TradeDiscPern), bl.BL_dValidation(listTrans.TotalTradeDiscAmt),
                                bl.BL_dValidation(listTrans.AddnlDiscPern), bl.BL_dValidation(listTrans.TotalAddnlDiscAmt),
                                bl.BL_dValidation(listTrans.Frieght), bl.BL_dValidation(listTrans.OtherChargePern), bl.BL_dValidation(listTrans.OtherChargeAmt),
                                bl.BL_dValidation(listTrans.WriteOffAmt), bl.BL_dValidation(listTrans.RoundOffAmt), listTrans.UDFId, 1, bl.BL_nValidation(listTrans.CurrentStatus),
                                null, bl.BL_dValidation(listTrans.TCSTaxPern), bl.BL_dValidation(listTrans.TCSTaxAmt), 1,
                                listTrans.Remarks, listTrans.Narration, listTrans.DraftID, listTrans.PriceID, bl.BL_dValidation(listTrans.DiffValueGross), bl.BL_dValidation(listTrans.DiffValueNet));
                            if (dtResult.Columns.Count == 1)
                            {
                                int nPRID = bl.BL_nValidation(dtResult.Rows[0][0].ToString());
                                for (int i = 0; i < dtProducts.Rows.Count; i++)
                                {
                                    int nProdID = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["ProdID"]));
                                    if (nProdID > 0)
                                    {
                                        DataRow[] dr = dtBatch.Select("ProdID = '" + nProdID + "'", null);
                                        foreach (DataRow iRow in dr)
                                        {
                                            //DataTable getConvFact = bl.BL_ExecuteSqlQuery("select dbo.fnGetConvertionFact(" + bl.BL_nValidation(dgvProd.Rows[DetailCount].Cells[UomGrpID.Name].Value) + "," + bl.BL_nValidation(dgvProd.Rows[DetailCount].Cells[UomID.Name].Value) + ")");
                                            decimal dUomTax = 0;// bl.GetUOMTaxValue(bl.BL_nValidation(iRow["TaxID"]), bl.BL_nValidation(txtTaxType.Tag),
                                                                //(bl.BL_dValidation(iRow["Qty"]) + bl.BL_dValidation(iRow["DmgQty"])) * (getConvFact.Rows.Count > 0 ? bl.BL_dValidation(getConvFact.Rows[0][0].ToString()) : 0.00M));// bl.BL_dValidation(dgvProd.Rows[DetailCount].Cells[SelectedUomCF.Name].Value));

                                            decimal dQty = (bl.BL_dValidation(iRow["DmgQty"].ToString()) + bl.BL_dValidation(iRow["Qty"].ToString()));
                                            if (dQty > 0)
                                            {
                                                int TaxID = bl.BL_nValidation(iRow["TaxID"].ToString());
                                                int TaxTypeID = bl.BL_nValidation(listTrans.TaxTypeID);
                                                decimal dMRP = bl.BL_dValidation(iRow["MRP"].ToString());
                                                DataTable dtMTdetail = bl.bl_ManageTrans("uspGetTaxCumulative", TaxID, TaxTypeID, 1);
                                                decimal dApponMRPCum = dtMTdetail.Select("AppOn = -1")
                                              .Select(r => Convert.ToDecimal(r["CumulativeTax"]))
                                              .DefaultIfEmpty(0)
                                              .Sum();
                                                if (dApponMRPCum > 0)
                                                {
                                                    MRPonTaxAMt = bl.ReturnGrossorMRPTaxAmt(0, TaxID, TaxTypeID, 0, dMRP, true) * dQty;
                                                }
                                                decimal dGrs = dQty * bl.BL_dValidation(iRow["ReturnPrice"].ToString());
                                                decimal dTax = dApponMRPCum > 0 ? MRPonTaxAMt : (dGrs * bl.BL_dValidation(iRow["TaxPern"].ToString())) / 100;
                                                decimal dNet = dGrs + dTax;

                                                string pkd = !string.IsNullOrEmpty(iRow["ExpiryDate"].ToString()) ? iRow["ExpiryDate"].ToString() : null;
                                                string exp = !string.IsNullOrEmpty(iRow["ExpiryDate"].ToString()) ? iRow["ExpiryDate"].ToString() : null;
                                                DataTable dtResultDetail = bl.bl_ManageTrans("uspManagePRDraftDetail", listTrans.Date, nPRID, nProdID, bl.BL_nValidation(dtProducts.Rows[i]["UomID"].ToString()),
                                                    bl.BL_dValidation(iRow["Qty"].ToString()), bl.BL_dValidation(iRow["FreeQty"].ToString()), bl.BL_dValidation(iRow["DmgQty"].ToString()),
                                                    iRow["BatchNo"].ToString(), pkd, exp, bl.BL_dValidation(iRow["OrgRTNPrice"].ToString()),
                                                    bl.BL_dValidation(iRow["MRP"].ToString()), bl.BL_nValidation(iRow["TaxPern"].ToString()), bl.BL_dValidation(iRow["ReturnPrice"].ToString()),
                                                    bl.BL_dValidation(iRow["TaxPern"].ToString()), dGrs, bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["ProdDiscPern"])), dGrs, dTax,
                                                    dNet, bl.BL_nValidation(iRow["TaxID"].ToString()), listTrans.TaxTypeID, 0, (i + 1), bl.BL_nValidation(iRow["TaxID"].ToString()), 1, (i + 1),
                                                    bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["TradeDiscPern"])),
                                                    bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["AddnlDiscPern"])), 1,
                                                    bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["DiffAmt"])), bl.BL_dValidation(iRow["ConversionRate"].ToString()));
                                                if (dtResultDetail.Rows.Count > 0)
                                                {
                                                    bl.bl_Transaction(3);
                                                    list.Add(new SaveMessage()
                                                    {
                                                        ID = 0.ToString(),
                                                        MsgID = "1",
                                                        Message = ""
                                                    });
                                                    return Ok(list);
                                                }
                                            }
                                        }
                                    }
                                }
                                bl.bl_Transaction(2);
                                nBillScopeID = bl.BL_nValidation(dtResult.Rows[0][0]);
                                list.Add(new SaveMessage()
                                {
                                    ID = nBillScopeID.ToString(),
                                    MsgID = "0",
                                    Message = "Saved Successfully"
                                });
                                return Ok(list);
                            }
                            else
                            {
                                bl.bl_Transaction(3);
                                list.Add(new SaveMessage()
                                {
                                    ID = 0.ToString(),
                                    MsgID = "1",
                                    Message = ""//dtResult.Rows[0][0].ToString()
                                });
                                return Ok(list);
                            }
                        }
                    }
                    else// for cancel
                    {
                        bl.bl_Transaction(1);
                        DataTable dtResult = bl.bl_ManageTrans("uspManagePRHeader", 4, 4, listTrans.CBy, listTrans.ID, listTrans.Remarks, listTrans.Narration);
                        if (dtResult.Rows.Count > 0)
                        {
                            bl.bl_Transaction(3);
                            list.Add(new SaveMessage()
                            {
                                ID = 1.ToString(),
                                MsgID = "1",
                                Message = dtResult.Rows[0][0].ToString()
                            });
                            return Ok(list);
                        }
                        else
                        {
                            bl.bl_Transaction(2);
                            bl.BL_UpdateclosingDateforPosting(12, bl.BL_nValidation(listTrans.ID), Convert.ToDateTime(listTrans.Date));
                            list.Add(new SaveMessage()
                            {
                                ID = 0.ToString(),
                                MsgID = "0",
                                Message = "Saved Successfully"
                            });
                            return Ok(list);
                        }
                    }
                    return Ok(0);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("PurchaseReturn", "purchasereturn/save", ex.Message);
            }
            return Ok("No data found");
        }
        public DataTable ToDataTable<T>(List<T> items)
        {
            DataTable dataTable = new DataTable(typeof(T).Name);
            //Get all the properties
            PropertyInfo[] Props = typeof(T).GetProperties(BindingFlags.Public | BindingFlags.Instance);
            foreach (PropertyInfo prop in Props)
            {
                //Setting column names as Property names
                dataTable.Columns.Add(prop.Name);
            }
            foreach (T item in items)
            {
                var values = new object[Props.Length];
                for (int i = 0; i < Props.Length; i++)
                {
                    //inserting property values to datatable rows
                    values[i] = Props[i].GetValue(item, null);
                }
                dataTable.Rows.Add(values);
            }
            //put a breakpoint here and check datatable
            return dataTable;
        }
    }
}
