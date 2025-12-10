using DocumentFormat.OpenXml.Spreadsheet;
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
using System.Security.Cryptography;
using System.Web.Http;
using System.Web.Http.Cors;
using System.Xml.Linq;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class PurchaseBillController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        DataTable dtPMDetail = new DataTable(), dtPopUpDetail = new DataTable(), dtProd = new DataTable(), dtGSTInfo = new DataTable();
        [HttpGet]
        [Route("api/purchasebill/get")]
        public IHttpActionResult GetData(string Mode, string CodeName,string ID = null)
        {
            DataTable DDT = new DataTable();
            if (Mode == "1")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseData", Mode, 0);
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
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseData", 111, 0);
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
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseData", Mode, CodeName,null,null,null,Convert.ToDateTime(ID));
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
                        ABSQty = DDT.Rows[i]["ABSQty"].ToString(),
                    });
                }
                return Ok(list);
            }
            if (Mode == "3")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseData", Mode, CodeName);
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
                        shipadd2 = DDT.Rows[i]["shipadd2"].ToString(),
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
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseData", Mode, CodeName);
                List<ProductModel> list = new List<ProductModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    DataTable dtUOM = bl.BL_ExecuteParamSP("uspGetSetPurchaseData", 5, "", DDT.Rows[i][0].ToString());
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
                    string SalePerc = Convert.ToBoolean(DDT.Rows[i]["SaleonMRP"].ToString()) ? Convert.ToString(bl.BL_dValidation(DDT.Rows[i]["SaleonpPern"].ToString()) * -1 ):
                        Convert.ToString(bl.BL_dValidation(DDT.Rows[i]["SaleonpPern"].ToString()));
                    string ECPPerc = Convert.ToBoolean(DDT.Rows[i]["ECPonMRP"].ToString()) ? Convert.ToString(bl.BL_dValidation(DDT.Rows[i]["ECPonpPern"].ToString()) * -1) :
                        Convert.ToString(bl.BL_dValidation(DDT.Rows[i]["ECPonpPern"].ToString()));
                    string SPLPerc = Convert.ToBoolean(DDT.Rows[i]["SPLonMRP"].ToString()) ? Convert.ToString(bl.BL_dValidation(DDT.Rows[i]["SPLonpPern"].ToString()) * -1) :
                        Convert.ToString(bl.BL_dValidation(DDT.Rows[i]["SPLonpPern"].ToString()));
                    list.Add(new ProductModel
                    {
                        ID = DDT.Rows[i]["ID"].ToString(),
                        Code = DDT.Rows[i]["Code"].ToString(),
                        Name = DDT.Rows[i]["Name"].ToString(),
                        EAN = DDT.Rows[i]["EAN"].ToString(),
                        MfrID = DDT.Rows[i]["MfrID"].ToString(),
                        BrandID = DDT.Rows[i]["BrandID"].ToString(),
                        CategoryID = DDT.Rows[i]["CategoryID"].ToString(),
                        HSNCode = DDT.Rows[i]["HSNCode"].ToString(),
                        ProductDiscPerc = DDT.Rows[i]["ProductDiscPerc"].ToString(),
                        BaseUomID = DDT.Rows[i]["BaseUomID"].ToString(),
                        BaseCR = DDT.Rows[i]["BaseCR"].ToString(),
                        PurchaseUomID = DDT.Rows[i]["PurchaseUomID"].ToString(),
                        PurchaseCR = DDT.Rows[i]["PurchaseCR"].ToString(),
                        SalesUomID = DDT.Rows[i]["SalesUomID"].ToString(),
                        SalesCR = DDT.Rows[i]["SalesCR"].ToString(),
                        ReportingUomID = DDT.Rows[i]["ReportingUomID"].ToString(),
                        ReportingCR = DDT.Rows[i]["ReportingCR"].ToString(),
                        ReportingQty = DDT.Rows[i]["ReportingQty"].ToString(),
                        PurchaseTaxID = DDT.Rows[i]["PurchaseTaxID"].ToString(),
                        SalesTaxID = DDT.Rows[i]["SalesTaxID"].ToString(),
                        PurchasePrice = DDT.Rows[i]["PurchasePrice"].ToString(),
                        SalesPrice = DDT.Rows[i]["SalesPrice"].ToString(),
                        ECP = DDT.Rows[i]["ECP"].ToString(),
                        SPLPrice = DDT.Rows[i]["SPLPrice"].ToString(),
                        MRP = DDT.Rows[i]["MRP"].ToString(),
                        ReturnPrice = DDT.Rows[i]["ReturnPrice"].ToString(),
                        TrackInventory = DDT.Rows[i]["TrackInventory"].ToString(),
                        TrackBatch = DDT.Rows[i]["TrackBatch"].ToString(),
                        TrackSerial = DDT.Rows[i]["TrackSerial"].ToString(),
                        TrackPDK = DDT.Rows[i]["TrackPDK"].ToString(),
                        DateFormat = DDT.Rows[i]["DateFormat"].ToString(),
                        BarcodeUomID = DDT.Rows[i]["BarcodeUomID"].ToString(),
                        BarcodePriceID = DDT.Rows[i]["BarcodePriceID"].ToString(),
                        VendorID = DDT.Rows[i]["VendorID"].ToString(),
                        LocationID = !string.IsNullOrEmpty(DDT.Rows[i]["LocationID"].ToString()) ?  DDT.Rows[i]["LocationID"].ToString() : "0",
                        MOH = DDT.Rows[i]["MOH"].ToString(),
                        MOQ = DDT.Rows[i]["MOQ"].ToString(),
                        Remarks = DDT.Rows[i]["Remarks"].ToString(),
                        Active = DDT.Rows[i]["Active"].ToString(),
                        ABSQty = DDT.Rows[i]["ABSQty"].ToString(),
                        TaxName = DDT.Rows[i]["TaxName"].ToString(),
                        GSTPern = DDT.Rows[i]["GST"].ToString(),
                        IGSTPern = DDT.Rows[i]["IGST"].ToString(),
                        PurchaseBillPrice = DDT.Rows[i]["PurchaseBillPrice"].ToString(),
                        UOMList = ulist,
                        SaleonpPern = SalePerc,
                        ECPonpPern = ECPPerc,
                        SPLonpPern = SPLPerc
                    });
                }
                return Ok(list);
            }
            if (Mode == "6" || Mode == "10")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseData", Mode, CodeName);
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

            if (Mode == "7"|| Mode == "11" || Mode == "17")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseData", Mode, null, CodeName);
                List<PurchaseModel> list = new List<PurchaseModel>();
                if (DDT.Rows.Count > 0)
                {
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        DataTable DDT1 = bl.BL_ExecuteParamSP("uspGetSetPurchaseData", 31, DDT.Rows[i][6].ToString());
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
                                shipadd2 = DDT1.Rows[j]["shipadd2"].ToString(),
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
                        int TMode = Mode == "7" ? 8 : Mode == "11" ? 12 : 18;
                        DataTable  DDT2 = bl.BL_ExecuteParamSP("uspGetSetPurchaseData", TMode, null, CodeName);
                        for (int k = 0; k < DDT2.Rows.Count; k++)
                        {
                            listProductGrid.Add(new PurchaseGridData
                            {
                                ProdID = DDT2.Rows[k]["ProdID"].ToString(),
                                UomID = DDT2.Rows[k]["UomID"].ToString(),
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
                                TaxPern = DDT2.Rows[k]["TaxPern"].ToString(),
                                GrossAmt = DDT2.Rows[k]["GrossAmt"].ToString(),
                                TaxAmt = DDT2.Rows[k]["TaxAmt"].ToString(),
                                TaxName = DDT2.Rows[k]["TaxName"].ToString(),
                                NetAmt = DDT2.Rows[k]["NetAmt"].ToString(),
                                GoodsAmt = DDT2.Rows[k]["GoodsAmt"].ToString(),
                                ReasonID = DDT2.Rows[k]["ReasonId"].ToString(),
                                LocationID = DDT2.Rows[k]["LocationID"].ToString(),
                                TransactionPrice = DDT2.Rows[k]["PurchaseBillPrice"].ToString(),
                                DiffAmt = DDT2.Rows[k]["DiffAmt"].ToString(),
                            });
                        }
                        List<PurchaseBatchInfo> listBatch = new List<PurchaseBatchInfo>();
                        TMode = Mode == "7" ? 9 : Mode == "11" ? 13 : 19;
                        DataTable DDT3 = bl.BL_ExecuteParamSP("uspGetSetPurchaseData", TMode, null, CodeName);
                        for (int l = 0; l < DDT3.Rows.Count; l++)
                        {
                            string PKD = !string.IsNullOrEmpty(DDT3.Rows[l]["PKD"].ToString()) ? Convert.ToDateTime(DDT3.Rows[l]["PKD"].ToString()).ToString("yyyy-MM-dd") : null;
                            string Exp = !string.IsNullOrEmpty(DDT3.Rows[l]["Expiry"].ToString()) ? Convert.ToDateTime(DDT3.Rows[l]["Expiry"].ToString()).ToString("yyyy-MM-dd") : null;
                            listBatch.Add(new PurchaseBatchInfo
                            {
                                BillID = DDT3.Rows[l]["HID"].ToString(),
                                InventoryID = DDT3.Rows[l]["InventoryId"].ToString(),
                                DmgQty = DDT3.Rows[l]["UomDamageQty"].ToString(),
                                ECP = DDT3.Rows[l]["UomECP"].ToString(),
                                FreeQty = DDT3.Rows[l]["UomFreeQty"].ToString(),
                                MRP = DDT3.Rows[l]["UomMRP"].ToString(),
                                OrgECP = DDT3.Rows[l]["UomECP"].ToString(),
                                OrgMRP = DDT3.Rows[l]["UomMRP"].ToString(),
                                OrgPPrice = DDT3.Rows[l]["UomPurchasePrice"].ToString(),
                                OrgRTNPrice = DDT3.Rows[l]["UomReturnPrice"].ToString(),
                                OrgSPL = DDT3.Rows[l]["UomSPLPrice"].ToString(),
                                OrgSPrice = DDT3.Rows[l]["UomSalePrice"].ToString(),
                                PKDDate = PKD,// DDT3.Rows[l]["PKD"].ToString(),
                                ExpiryDate = Exp,// DDT3.Rows[l]["Expiry"].ToString(),
                                BatchNo = DDT3.Rows[l]["BatchNo"].ToString(),
                                ProdID = DDT3.Rows[l]["ProdID"].ToString(),
                                PurchasePrice = DDT3.Rows[l]["UomPurchasePrice"].ToString(),
                                Qty = DDT3.Rows[l]["UomQty"].ToString(),
                                ReturnPrice = DDT3.Rows[l]["UomReturnPrice"].ToString(),
                                SPLPrice = DDT3.Rows[l]["UomSPLPrice"].ToString(),
                                SalesPrice = DDT3.Rows[l]["UomSalePrice"].ToString(),
                                TrackBatch = DDT3.Rows[l]["TrackBatch"].ToString(),
                                TrackInventory = DDT3.Rows[l]["TrackInventory"].ToString(),
                                UomID = DDT3.Rows[l]["UomID"].ToString(),
                                TrackPKD = DDT3.Rows[l]["TrackPDK"].ToString(),
                                TaxID = DDT3.Rows[l]["TaxID"].ToString(),
                                TaxTypeID = DDT3.Rows[l]["TaxTypeID"].ToString(),
                                TaxPern = (Mode == "7" || Mode == "17") ? DDT3.Rows[l]["Tax%"].ToString() : DDT3.Rows[l]["TaxPern"].ToString(),
                                UOMName = DDT3.Rows[l]["UOMName"].ToString(),
                                HSN = DDT3.Rows[l]["HSNCode"].ToString(),
                                ConversionRate = DDT3.Rows[l]["UOMCF"].ToString(),
                            });
                        }
                       
                        string asdf = "";
                        list.Add(new PurchaseModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            DocID = DDT.Rows[i]["DocID"].ToString(),
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
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseData", Mode, CodeName, ID);
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
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseData", Mode, null, CodeName);
                return Ok("0");
            }
            if (Mode == "20")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseData", Mode, CodeName,ID);
                List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new CustomerVendorModel
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        Name = DDT.Rows[i][1].ToString(),
                    });
                }
                return Ok(list);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/purchasebill/getfilterdata")]
        public IHttpActionResult GetFilterData(string TransID, string FType, string Branch, string Party, string FromDate, string ToDate, string Showall)
        {
            
                string Mode = FType == "1" ? "6" : FType == "2" ? "10" : "16";
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseData", Mode,  FType, Branch, TransID, Party, FromDate, ToDate, Showall);
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
                    });
                }
            //return Ok(list);

            var data = from users in list
                       select
                           new
                           {
                               ID = users.ID,
                               DocID = users.DocID,
                               Date = users.Date,
                               RefNo = users.RefNo,
                               BranchID = users.BranchID,
                               VendorID = users.VendorID,
                               GrossAmt = users.GrossAmt,
                               TaxAmt = users.TaxAmt,
                               NetAmt = users.NetAmt,
                               Status = users.Status,
                               Balance = users.Balance,
                               CBy = users.CBy,
                               CDate = users.CDate,
                               CurrentStatus = users.CurrentStatus
                           };            
            return Ok(data);  
        }
        [HttpPost]
        [Route("api/purchasebill/save")]
        public IHttpActionResult Save(PurchaseModel listTrans)
        {
            if(listTrans!= null)
            {
                dtPMDetail.Columns.Add("AccID", typeof(int));
                dtPMDetail.Columns.Add("ModeId", typeof(int));
                dtPMDetail.Columns.Add("BankAccNo", typeof(string));
                dtPMDetail.Columns.Add("BankAccId", typeof(int));
                dtPMDetail.Columns.Add("chqDDNoId", typeof(int));
                dtPMDetail.Columns.Add("ChequeDDNo", typeof(string));
                dtPMDetail.Columns.Add("Date", typeof(string));
                dtPMDetail.Columns.Add("PayAt", typeof(string));
                dtPMDetail.Columns.Add("IFSC", typeof(string));
                dtPMDetail.Columns.Add("Bank", typeof(string));
                dtPMDetail.Columns.Add("Branch", typeof(string));
                dtPMDetail.Columns.Add("Amt", typeof(decimal));
                dtPMDetail.Columns.Add("SerialNumber", typeof(int));
                dtPMDetail.Columns.Add("RecdAmt", typeof(decimal));
                dtPMDetail.Columns.Add("OriginalCollAmt", typeof(decimal));
                dtPMDetail.Columns.Add("VisaPern", typeof(decimal));
                dtPMDetail.Columns.Add("VisaAmt", typeof(decimal));

                if (dtPopUpDetail.Columns.Count == 0)
                {
                    dtPopUpDetail.Columns.Add("ProdId", typeof(int));
                    dtPopUpDetail.Columns.Add("BatchNo", typeof(string));
                    dtPopUpDetail.Columns.Add("PKD", typeof(string));
                    dtPopUpDetail.Columns.Add("Expiry", typeof(string));
                    dtPopUpDetail.Columns.Add("Qty", typeof(decimal)).DefaultValue = 0;
                    dtPopUpDetail.Columns.Add("FreeQty", typeof(decimal)).DefaultValue = 0;
                    dtPopUpDetail.Columns.Add("DmgQty", typeof(decimal)).DefaultValue = 0;
                    dtPopUpDetail.Columns.Add("PurchasePrice", typeof(decimal)).DefaultValue = 0;
                    dtPopUpDetail.Columns.Add("SalePrice", typeof(decimal));
                    dtPopUpDetail.Columns.Add("ECP", typeof(decimal));
                    dtPopUpDetail.Columns.Add("MRP", typeof(decimal));
                    dtPopUpDetail.Columns.Add("SPLPrice", typeof(decimal));

                    dtPopUpDetail.Columns.Add("TempPPrice", typeof(decimal)).DefaultValue = 0;
                    dtPopUpDetail.Columns.Add("TempSalesPrice", typeof(decimal)).DefaultValue = 0;
                    dtPopUpDetail.Columns.Add("TempECP", typeof(decimal)).DefaultValue = 0;
                    dtPopUpDetail.Columns.Add("TempMRP", typeof(decimal)).DefaultValue = 0;
                    dtPopUpDetail.Columns.Add("TempSplPrice", typeof(decimal)).DefaultValue = 0;

                    dtPopUpDetail.Columns.Add("TaxName", typeof(string));
                    dtPopUpDetail.Columns.Add("TaxID", typeof(int));
                    dtPopUpDetail.Columns.Add("TaxPercentage", typeof(decimal)).DefaultValue = 0;
                    dtPopUpDetail.Columns.Add("InventoryId", typeof(int));
                    dtPopUpDetail.Columns.Add("GoodsAmt", typeof(decimal), bl.dValidationExp("((Qty+DmgQty)*TempPPrice)"));
                    dtPopUpDetail.Columns.Add("ProdDisc", typeof(decimal)).DefaultValue = 0;
                    dtPopUpDetail.Columns.Add("ProdDiscAmt", typeof(decimal), bl.dValidationExp("((GoodsAmt*ProdDisc)/100)"));
                    dtPopUpDetail.Columns.Add("dtColPDAftrGGrossAmt", typeof(decimal), bl.dValidationExp("(GoodsAmt-ProdDiscAmt)"));
                    dtPopUpDetail.Columns.Add("AddnlDisc", typeof(decimal)).DefaultValue = 0;
                    dtPopUpDetail.Columns.Add("AddnlDiscAmt", typeof(decimal), bl.dValidationExp("((dtColPDAftrGGrossAmt*AddnlDisc)/100)"));
                    dtPopUpDetail.Columns.Add("TradeDisc", typeof(decimal)).DefaultValue = 0;
                    dtPopUpDetail.Columns.Add("TradeDiscAmt", typeof(decimal), bl.dValidationExp("((dtColPDAftrGGrossAmt*TradeDisc)/100)"));
                    dtPopUpDetail.Columns.Add("GrossAmt", typeof(decimal), bl.dValidationExp("(GoodsAmt-(ProdDiscAmt+TradeDiscAmt+AddnlDiscAmt))"));
                    dtPopUpDetail.Columns.Add("TaxAmt", typeof(decimal), bl.dValidationExp("((GrossAmt*TaxPercentage)/100)"));
                    dtPopUpDetail.Columns.Add("NetAmt", typeof(decimal), bl.dValidationExp("(GrossAmt+TaxAmt)"));
                    dtPopUpDetail.Columns.Add("InclusiveYesNo", typeof(int)).DefaultValue = 0;
                }
                
                if (dtProd.Columns.Count == 0)
                {
                    dtProd.Columns.Add("ProdId", typeof(int));
                    dtProd.Columns.Add("UomId", typeof(int));
                    dtProd.Columns.Add("UomGrpID", typeof(int));
                    dtProd.Columns.Add("UOMCR", typeof(decimal));
                    dtProd.Columns.Add("HSN", typeof(string));
                    dtProd.Columns.Add("BatchNo", typeof(string));
                    dtProd.Columns.Add("PKD", typeof(string));
                    dtProd.Columns.Add("Expiry", typeof(string));
                    dtProd.Columns.Add("Qty", typeof(decimal));
                    dtProd.Columns.Add("FreeQty", typeof(decimal));
                    dtProd.Columns.Add("DamageQty", typeof(decimal));
                    dtProd.Columns.Add("PurchasePrice", typeof(decimal));
                    dtProd.Columns.Add("SalePrice", typeof(decimal));
                    dtProd.Columns.Add("ECP", typeof(decimal));
                    dtProd.Columns.Add("MRP", typeof(decimal));
                    dtProd.Columns.Add("SPLPrice", typeof(decimal));
                    dtProd.Columns.Add("ReturnPrice", typeof(decimal));
                    dtProd.Columns.Add("TaxID", typeof(int));
                    dtProd.Columns.Add("TaxTypeId", typeof(int));
                    dtProd.Columns.Add("TaxPercentage", typeof(decimal));
                    dtProd.Columns.Add("GoodsAmt", typeof(decimal));
                    dtProd.Columns.Add("ProdDiscPercent", typeof(decimal));
                    dtProd.Columns.Add("TradeDiscPercent", typeof(decimal));
                    dtProd.Columns.Add("AddnlDiscPercent", typeof(decimal));
                    dtProd.Columns.Add("GrossAmt", typeof(decimal));
                    dtProd.Columns.Add("TaxAmt", typeof(decimal));
                    dtProd.Columns.Add("NetAmt", typeof(decimal));
                    dtProd.Columns.Add("InventoryId", typeof(int));
                    dtProd.Columns.Add("InclusiveYesNo", typeof(int)).DefaultValue = 0;
                    dtProd.Columns.Add("ReasonID", typeof(int)).DefaultValue = 0;
                    dtProd.Columns.Add("LocationID", typeof(int)).DefaultValue = 0;
                    dtProd.Columns.Add("DiffAmt", typeof(int)).DefaultValue = 0;
                }
                DataTable dtDenominationPMDetail = new DataTable();
                dtDenominationPMDetail.Columns.Add("ColDetailDid", typeof(int));
                dtDenominationPMDetail.Columns.Add("ColDetailDenomination", typeof(int));
                dtDenominationPMDetail.Columns.Add("ColtotCoupons", typeof(int));
                dtDenominationPMDetail.Columns.Add("ColDetailCount", typeof(string));
                dtDenominationPMDetail.Columns.Add("ColDetailAmount", typeof(decimal));
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
                DataTable dtPaymodeDetails = new DataTable();
                if (listTrans.lstPaymodeInfo != null)
                    dtPaymodeDetails = ToDataTable(listTrans.lstPaymodeInfo);
                DataTable dtBatch = ToDataTable(listTrans.lstBatchInfo);
                DataTable dtProducts = ToDataTable(listTrans.lstProdInfo);
                List<SaveMessage> list = new List<SaveMessage>();
                if (listTrans.TransMode != "4")
                {
                    for (int i = 0; i < dtProducts.Rows.Count; i++)
                    {
                        int nProdID = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["ProdID"]));
                        if (nProdID > 0)
                        {
                            //// Check Product Active
                            //if (bl.BL_CheckActiveByID("Product", Convert.ToString(dgvProd.Rows[DetailCount].Cells["ProdId"].Value)) == false)
                            //{
                            //    dgvProd.Rows[DetailCount].ErrorText = bl.BL_XMLMessage(128);
                            //    if (bTransIsValid == true)
                            //        obj_mdi.messages(bl.BL_XMLMessage(128), bl.ToolStripErrorMsg);
                            //    bTransIsValid = false;
                            //}

                            DataRow[] dr = dtBatch.Select("ProdID = '" + nProdID + "'", null);

                            foreach (DataRow iRow in dr)
                            {
                                //DataTable getConvFact = bl.BL_ExecuteSqlQuery("select dbo.fnGetConvertionFact(" + bl.BL_nValidation(dgvProd.Rows[DetailCount].Cells[UomGrpID.Name].Value) + "," + bl.BL_nValidation(dgvProd.Rows[DetailCount].Cells[UomID.Name].Value) + ")");
                                decimal dUomTax = 0;// bl.GetUOMTaxValue(bl.BL_nValidation(iRow["TaxID"]), bl.BL_nValidation(txtTaxType.Tag),
                                                    //(bl.BL_dValidation(iRow["Qty"]) + bl.BL_dValidation(iRow["DmgQty"])) * (getConvFact.Rows.Count > 0 ? bl.BL_dValidation(getConvFact.Rows[0][0].ToString()) : 0.00M));// bl.BL_dValidation(dgvProd.Rows[DetailCount].Cells[SelectedUomCF.Name].Value));
                                decimal dGrs = (bl.BL_dValidation(iRow["DmgQty"].ToString()) + bl.BL_dValidation(iRow["Qty"].ToString())) * bl.BL_dValidation(iRow["PurchasePrice"].ToString());
                                //decimal dTax = (dGrs * bl.BL_dValidation(iRow["TaxPern"].ToString())) / 100;
                                
                                decimal PrDisc = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["ProdDiscPern"]));
                                decimal TrDisc = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["TradeDiscPern"])); 
                                decimal AddDisc = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["AddnlDiscPern"]));
                                decimal PrDAmt = (PrDisc * dGrs) / 100;
                                decimal TrDAmt = (TrDisc * (dGrs - PrDAmt)) / 100;
                                decimal AddDAmt = (AddDisc * (dGrs - PrDAmt)) / 100;
                                decimal fgrsamt = dGrs - (PrDAmt + TrDAmt + AddDAmt);
                                decimal dTax = (fgrsamt * bl.BL_dValidation(iRow["TaxPern"].ToString())) / 100;
                                decimal dNet = fgrsamt + dTax;
                                
                                DataRow dtRow = dtProd.NewRow();
                                dtRow["ProdId"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["ProdID"]));
                                dtRow["UomId"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["UomID"]));
                                dtRow["UOMCR"] = bl.BL_dValidation(iRow["ConversionRate"].ToString());
                                dtRow["HSN"] = (Convert.ToString(dtProducts.Rows[i]["HSN"]));
                                string PKD = !string.IsNullOrEmpty(iRow["PKDDate"].ToString()) ? Convert.ToDateTime(iRow["PKDDate"].ToString()).ToString("dd/MM/yyyy") : null;
                                string Exp = !string.IsNullOrEmpty(iRow["ExpiryDate"].ToString()) ? Convert.ToDateTime(iRow["ExpiryDate"].ToString()).ToString("dd/MM/yyyy") : null;
                                dtRow["BatchNo"] = iRow["BatchNo"].ToString();
                                dtRow["PKD"] = PKD;// iRow["PKDDate"].ToString();
                                dtRow["Expiry"] = Exp;// iRow["ExpiryDate"].ToString();
                                dtRow["Qty"] = bl.BL_dValidation(iRow["Qty"].ToString());
                                dtRow["FreeQty"] = bl.BL_dValidation(iRow["FreeQty"].ToString());
                                dtRow["DamageQty"] = bl.BL_dValidation(iRow["DmgQty"].ToString());
                                dtRow["PurchasePrice"] = bl.BL_dValidation(iRow["PurchasePrice"].ToString());
                                dtRow["SalePrice"] = bl.BL_dValidation(iRow["SalesPrice"].ToString());
                                dtRow["ECP"] = bl.BL_dValidation(iRow["ECP"].ToString());
                                dtRow["MRP"] = bl.BL_dValidation(iRow["MRP"].ToString());
                                dtRow["SPLPrice"] = bl.BL_dValidation(iRow["SPLPrice"].ToString());
                                dtRow["ReturnPrice"] = bl.BL_dValidation(iRow["ReturnPrice"].ToString());
                                dtRow["TaxID"] = bl.BL_nValidation(iRow["TaxID"].ToString());
                                dtRow["TaxTypeId"] = bl.BL_nValidation(listTrans.TaxTypeID);
                                dtRow["TaxPercentage"] = bl.BL_dValidation(iRow["TaxPern"].ToString());
                                dtRow["GoodsAmt"] = dGrs;// bl.BL_dValidation(iRow["GoodsAmt"].ToString()); // GoodsAmt
                                dtRow["ProdDiscPercent"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["ProdDiscPern"]));// bl.BL_dValidation(iRow["ProdDisc"]);
                                dtRow["TradeDiscPercent"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["TradeDiscPern"]));//bl.BL_dValidation(iRow["TradeDiscAmt"]); // Trade disc Amt;
                                dtRow["AddnlDiscPercent"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["AddnlDiscPern"]));// bl.BL_dValidation(iRow["AddnlDiscAmt"]); // Addnl Disc Amt
                                dtRow["GrossAmt"] = fgrsamt; // gross
                                dtRow["TaxAmt"] = dTax + bl.BL_dValidation(dUomTax); // tax
                                dtRow["NetAmt"] = dNet + bl.BL_dValidation(dUomTax); // net
                                dtRow["InventoryId"] = bl.BL_dValidation(iRow["InventoryID"].ToString()); ;// bl.BL_nValidation(iRow["InventoryId"].ToString());
                                dtRow["InclusiveYesNo"] = bl.BL_nValidation(iRow["CheckInclusive"].ToString());
                                dtRow["ReasonID"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["ReasonId"]));
                                dtRow["LocationID"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["LocationID"]));
                                dtRow["DiffAmt"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["DiffAmt"]));
                                dtProd.Rows.Add(dtRow);
                            }
                        }
                    }
                    int nSerial = 1;
                    for (int i = 0; i < dtPaymodeDetails.Rows.Count; i++)
                    {
                        int nPayMode = bl.BL_nValidation(Convert.ToString(dtPaymodeDetails.Rows[i]["Mode"]));
                        decimal dAmt = bl.BL_dValidation(dtPaymodeDetails.Rows[i]["Amt"].ToString());
                        if (dAmt > 0)
                        {

                            DataRow dtRow = dtPMDetail.NewRow();
                            dtRow["AccID"] = bl.BL_nValidation(dtPaymodeDetails.Rows[i]["AccID"]);
                            dtRow["ModeId"] = nPayMode;
                            if (nPayMode == 2)
                            {
                                dtRow["chqDDNoId"] = dtPaymodeDetails.Rows[i]["ChequeBookID"].ToString();
                                dtRow["ChequeDDNo"] = dtPaymodeDetails.Rows[i]["ChequeBkRefNo"].ToString();
                            }
                            else
                            {
                                dtRow["ChequeDDNo"] = dtPaymodeDetails.Rows[i]["ChequeDDNumber"].ToString();
                            }
                            dtRow["BankAccNo"] = dtPaymodeDetails.Rows[i]["BankAccNo"].ToString();
                            dtRow["BankAccId"] = dtPaymodeDetails.Rows[i]["BankAccId"].ToString();
                            dtRow["Date"] = !string.IsNullOrEmpty(dtPaymodeDetails.Rows[i]["Date"].ToString()) ?
                                Convert.ToDateTime(dtPaymodeDetails.Rows[i]["Date"].ToString()).ToString("dd/MM/yyyy") : DateTime.Now.ToString("dd/MM/yyyy");
                            dtRow["PayAt"] = null;// nPayMode == 4 ? bl.BL_nValidation(dtPaymodeDetails.Rows[i]["AccID"].ToString()) : 0;
                            dtRow["IFSC"] = dtPaymodeDetails.Rows[i]["IFSC"].ToString();
                            dtRow["Bank"] = dtPaymodeDetails.Rows[i]["Bank"].ToString();
                            dtRow["Branch"] = dtPaymodeDetails.Rows[i]["Branch"].ToString();
                            dtRow["Amt"] = dAmt;
                            //dtRow["RecdAmt"] = bl.BL_dValidation(dtPaymodeDetails.Rows[i]["RecdAmt"].ToString());
                            dtRow["SerialNumber"] = nSerial;
                            dtRow["RecdAmt"] = bl.BL_dValidation(dtPaymodeDetails.Rows[i]["OriginalCollAmt"].ToString());
                            dtRow["OriginalCollAmt"] = bl.BL_dValidation(dtPaymodeDetails.Rows[i]["OriginalCollAmt"].ToString());
                            dtRow["VisaPern"] = dtPaymodeDetails.Rows[i]["VisaPern"].ToString();
                            dtRow["VisaAmt"] = dtPaymodeDetails.Rows[i]["VisaAmt"].ToString();
                            dtPMDetail.Rows.Add(dtRow);
                            nSerial++;
                        }
                    }
                    if (listTrans.IsDraft == "0")
                    {
                        bl.bl_Transaction(1);
                        try
                        {
                            string nMode = listTrans.TransMode == "3" ? "1" : listTrans.TransMode;
                            DataTable dtResult = bl.bl_ManageTrans("uspManageTransPurchaseBill", nMode, bl.BL_nValidation(listTrans.ID), bl.BL_nValidation(listTrans.BranchID), bl.BL_nValidation(listTrans.CurrentStatus),
                                listTrans.Date, listTrans.VendorID, bl.BL_dValidation(listTrans.GrossAmt), bl.BL_dValidation(listTrans.TaxAmt),
                                bl.BL_dValidation(listTrans.NetAmt), listTrans.RefNo, listTrans.ProdGroupID,
                                listTrans.TaxTypeID, listTrans.PaymentTermID, listTrans.PaymentDate, listTrans.PaymentModeID, listTrans.VehicleNo,
                                bl.BL_dValidation(listTrans.Frieght),
                                bl.BL_dValidation(listTrans.OtherChargePern), bl.BL_dValidation(listTrans.OtherChargeAmt), bl.BL_dValidation(listTrans.ProdDiscPern), bl.BL_dValidation(listTrans.TradeDiscPern),
                                bl.BL_dValidation(listTrans.AddnlDiscPern), bl.BL_dValidation(listTrans.TotalProdDiscAmt),
                                bl.BL_dValidation(listTrans.TotalTradeDiscAmt), bl.BL_dValidation(listTrans.TotalAddnlDiscAmt), bl.BL_dValidation(listTrans.WriteOffAmt), listTrans.CBy,
                                bl.BL_dValidation(listTrans.RoundOffAmt), dtProd,
                                dtPMDetail, listTrans.UDFId, 1, 0, 0, null, bl.BL_dValidation(listTrans.TCSTaxPern), bl.BL_dValidation(listTrans.TCSTaxAmt), bl.BL_dValidation(listTrans.TDSAmount), 0,
                                listTrans.Remarks, listTrans.Narration, listTrans.DraftID,dtDenominationPMDetail, bl.BL_dValidation(listTrans.DiffValueGross), bl.BL_dValidation(listTrans.DiffValueNet));
                            if (dtResult.Columns.Count > 1)
                            {
                                bl.bl_Transaction(3);
                                string[] strErrorList = dtResult.Rows[0][0].ToString().Split('$');
                                //if (strErrorList.Length == 1)
                                //{
                                //    if (strErrorList[0].Trim().ToUpper() == "ACC")
                                //    {
                                //        SetErrorAndFocus(txtVendName, 289);
                                //    }
                                //    else if (strErrorList[0].Trim().ToUpper() == "BANKACC")
                                //    {
                                //        SetErrorAndFocus(cmdSave, 289);
                                //    }                        
                                //}
                                list.Add(new SaveMessage()
                                {
                                    ID = 0.ToString(),
                                    MsgID = "1",
                                    Message = dtResult.Rows[0][0].ToString()
                                });
                                return Ok(list);
                            }
                            else
                            {
                                int nBillScopeID = bl.BL_nValidation(dtResult.Rows[0][0]);

                                if (dtProd.Rows.Count > 0)
                                    {
                                        int nProdID = 0, nTaxID = 0, nTaxTypeID = 0, SRSerial = 1, nTranSerial = 1;
                                        decimal dQtnGrossAmount = 0.00M, dQtys = 0.00M;
                                        dtGSTInfo.Rows.Clear();
                                        for (int nCount = 0; nCount < dtProd.Rows.Count; nCount++)
                                        {
                                            //if (bl.BL_dValidation(dtProd.Rows[nCount]["Qty"]) > 0)
                                            //{
                                                nProdID = bl.BL_nValidation(dtProd.Rows[nCount]["ProdId"]);
                                                nTaxID = bl.BL_nValidation(dtProd.Rows[nCount]["TaxID"]);
                                                nTaxTypeID = bl.BL_nValidation(listTrans.TaxTypeID);
                                                dQtnGrossAmount = bl.BL_dValidation(dtProd.Rows[nCount]["GrossAmt"]);

                                        //DataTable dtResultcv = bl.BL_GetColumnValBasedTwoCond("UomGroupMaster",
                                        //Convert.ToString(dtProd.Rows[nCount]["UomGrpID"]),
                                        //Convert.ToString(dtProd.Rows[nCount]["UomId"]));

                                        //DataTable getConvFact = bl.BL_ExecuteSqlQuery("select dbo.fnGetConvertionFact(" + bl.BL_nValidation(dtProd.Rows[nCount]["UomGrpID"]) + "," + bl.BL_nValidation(dtProd.Rows[nCount]["UomId"]) + ")");

                                        dQtys = (bl.BL_dValidation(dtProd.Rows[nCount]["Qty"]) + bl.BL_dValidation(dtProd.Rows[nCount]["DamageQty"])) * 1;// bl.BL_dValidation(dtResult.Rows[0][0]);

                                            DataTable dtTaxCompInfo = bl.bl_ManageTrans("uspGetTaxCompInfo", nTaxID, nTaxTypeID);
                                                if (dtTaxCompInfo.Rows.Count > 0)
                                                {
                                                bool ValidtoCalc = false;

                                                for (int nTaxComp = 0; nTaxComp < dtTaxCompInfo.Rows.Count; nTaxComp++)
                                                    {
                                                    ValidtoCalc = true; //nTaxTypeID == 2 && bl.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 1 ||
                                                                //nTaxTypeID == 1 && bl.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 2 ? false : true;
                                                    DataRow dr = dtGSTInfo.NewRow();
                                                        dr["TransID"] = 1;
                                                        dr["TransIdentID"] = nBillScopeID;
                                                        dr["ProdID"] = nProdID;
                                                        dr["TaxID"] = nTaxID;
                                                        dr["GSTTaxTypeID"] = bl.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]);
                                                        dr["TaxTypeID"] = nTaxTypeID;
                                                        dr["TaxCompID"] = bl.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][0]);
                                                        dr["TaxCompPern"] = bl.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2]);
                                                        dr["TaxCompAmount"] = ValidtoCalc ? ((dQtnGrossAmount * bl.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2])) / 100) :
                                                                bl.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2]) * dQtys;
                                                dr["GrossAmount"] = dQtnGrossAmount;
                                                        //dr["TransSerial"] = nTranSerial;
                                                        dr["TransSerial"] = (nCount+1);
                                                        dr["SerialNo"] = SRSerial;
                                                        dtGSTInfo.Rows.Add(dr);
                                                        SRSerial++;
                                                    }
                                                    nTranSerial++;
                                                }
                                            //}
                                        }
                                        if (dtGSTInfo.Rows.Count > 0)
                                        {
                                            bl.bl_ManageTrans("uspSaveTranGSTInfo", dtGSTInfo);
                                        }
                                    }
                                
                                list.Add(new SaveMessage()
                                {
                                    ID = nBillScopeID.ToString(),
                                    MsgID = "0",
                                    Message = "Saved Successfully"
                                });
                                bl.bl_Transaction(2);
                                bl.BL_UpdateclosingDateforPosting(bl.BL_nValidation(listTrans.TransID), nBillScopeID, Convert.ToDateTime(listTrans.Date));
                                return Ok(list);
                            }
                        }
                        catch
                        {
                            bl.bl_Transaction(3);
                        }
                    }
                    else //  Draft
                    {
                        bl.bl_Transaction(1);
                        DataTable dtResult = bl.bl_ManageTrans("uspManagePurchaseDraft", listTrans.TransMode, bl.BL_nValidation(listTrans.ID), bl.BL_nValidation(listTrans.BranchID), bl.BL_nValidation(listTrans.CurrentStatus),
                            listTrans.Date, listTrans.VendorID, bl.BL_dValidation(listTrans.GrossAmt), bl.BL_dValidation(listTrans.TaxAmt),
                            bl.BL_dValidation(listTrans.NetAmt), listTrans.RefNo, listTrans.ProdGroupID,
                            listTrans.TaxTypeID, listTrans.PaymentTermID, listTrans.PaymentDate, listTrans.PaymentModeID, listTrans.VehicleNo,
                            bl.BL_dValidation(listTrans.Frieght),
                            bl.BL_dValidation(listTrans.OtherChargePern), bl.BL_dValidation(listTrans.OtherChargeAmt), bl.BL_dValidation(listTrans.ProdDiscPern), bl.BL_dValidation(listTrans.TradeDiscPern),
                            bl.BL_dValidation(listTrans.AddnlDiscPern), bl.BL_dValidation(listTrans.TotalProdDiscAmt),
                            bl.BL_dValidation(listTrans.TotalTradeDiscAmt), bl.BL_dValidation(listTrans.TotalAddnlDiscAmt), bl.BL_dValidation(listTrans.WriteOffAmt), listTrans.CBy,
                            bl.BL_dValidation(listTrans.RoundOffAmt), dtProd,
                            dtPMDetail, listTrans.UDFId, 1, 0, 0, null, bl.BL_dValidation(listTrans.TCSTaxPern), bl.BL_dValidation(listTrans.TCSTaxAmt), bl.BL_dValidation(listTrans.TDSAmount), 0,
                            listTrans.Remarks, listTrans.Narration, bl.BL_nValidation(listTrans.DraftID), bl.BL_dValidation(listTrans.DiffValueGross), bl.BL_dValidation(listTrans.DiffValueNet));
                        if (dtResult.Columns.Count > 1)
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
                        else
                        {
                            bl.bl_Transaction(2);
                            int nBillScopeID = bl.BL_nValidation(dtResult.Rows[0][0]);
                            list.Add(new SaveMessage()
                            {
                                ID = nBillScopeID.ToString(),
                                MsgID = "0",
                                Message = "Saved Successfully"
                            });
                            return Ok(list);
                        }
                    }
                }
                else// for cancel
                {
                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspCancelPurchaseBill", 4, listTrans.ID, listTrans.CBy, listTrans.CurrentStatus, listTrans.Remarks, listTrans.Narration);
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
                        bl.BL_UpdateclosingDateforPosting(1, bl.BL_nValidation(listTrans.ID), Convert.ToDateTime(listTrans.Date));
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
