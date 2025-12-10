using DocumentFormat.OpenXml.InkML;
using DocumentFormat.OpenXml.Office2010.Excel;
using DocumentFormat.OpenXml.Spreadsheet;
using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Printing;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics.Eventing.Reader;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Configuration;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Reflection;
using System.Web.Http;
using System.Web.Http.Cors;

namespace SampWebApi.Controllers
{
    //[EnableCors(origins: "*", headers: "*", methods: "*")]
    [CookieAuthorize]
    public class InvoiceController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        DataTable dtPMDetail = new DataTable(), dtPopUpDetail = new DataTable(), dtGSTInfo = new DataTable(), dtProd = new DataTable(), dtDocument = new DataTable(), dtSerialInfo = new DataTable(),
            dtMop = new DataTable();
        [HttpGet]
        [Route("api/invoice/get")]
        public IHttpActionResult GetData(string Mode, string CodeName, string ID = null, string BranchID = "0", string Date = "", string PriceID = "2")
        {
            DataTable DDT = new DataTable();
            if (Mode == "1")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", Mode, CodeName);
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
                DDT = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", 111, 0);
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
                DDT = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", 112, CodeName);
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
            if (Mode == "33")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", Mode, CodeName, ID);
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
                DDT = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", Mode, CodeName, PriceID, null, null, Convert.ToDateTime(ID));
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
                        PurchasePrice = DDT.Rows[i]["Price"].ToString(),
                        ABSQty = DDT.Rows[i]["ABSQty"].ToString(),
                        LocationID = DDT.Rows[i]["LocationName"].ToString(),
                    });
                }
                return Ok(list);
            }
            if (Mode == "3")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", Mode, CodeName);
                List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    string strBeatID = "0", strSalesmanID = "0";

                    DataTable dtBSM = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", 32, DDT.Rows[i]["ID"].ToString());
                    if (dtBSM.Rows.Count > 0)
                    {
                        strBeatID = dtBSM.Rows[0]["BeatID"].ToString();
                        strSalesmanID = dtBSM.Rows[0]["SalesmanID"].ToString();
                    }
                    List<clsCustomerRemarks> listRemark = new List<clsCustomerRemarks>();
                    DataTable dtRem = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", 34, DDT.Rows[i]["ID"].ToString());
                    if (dtRem.Rows.Count > 0)
                    {
                        for (int j = 0; j < dtRem.Rows.Count; j++)
                        {
                            listRemark.Add(new clsCustomerRemarks
                            {
                                Remarks = dtRem.Rows[j][1].ToString()
                            });
                        }
                    }
                    string strOSVal = "0", strOSType = "Cr", ACDay = "0";
                    DataTable dtPartyOs = bl.BL_ExecuteParamSP("uspPartyReportData", 2, DDT.Rows[i]["FAID"].ToString(), 1);
                    if(dtPartyOs.Rows.Count > 0)
                    {
                        strOSVal = dtPartyOs.Rows[0]["OSBAL"].ToString();
                        strOSType = dtPartyOs.Rows[0]["CrDr"].ToString();
                        ACDay = dtPartyOs.Rows[0]["ACC"].ToString();
                    }
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
                        PriceTypeID = DDT.Rows[i]["PriceTypeID"].ToString(),
                        FAID = DDT.Rows[i]["FAID"].ToString(),
                        Active = DDT.Rows[i]["Active"].ToString(),
                        Ratings = DDT.Rows[i]["Rating"].ToString(),
                        RatingName = DDT.Rows[i]["RatingName"].ToString(),
                        Distance = DDT.Rows[i]["Distance"].ToString(),
                        CloseBal = strOSVal,
                        OSType = strOSType,
                        ACDate = ACDay,
                        BeatID = strBeatID,
                        SalesmanID = strSalesmanID,
                        lstCustRemark = listRemark
                    });
                }
                return Ok(list);
            }
            if (Mode == "4")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", Mode, CodeName);
                List<InvoiceBatchInfo> list = new List<InvoiceBatchInfo>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    DataTable dtUOM = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", 5, "", DDT.Rows[i][0].ToString());
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
                    List<InvoiceBatchPopup> ulistBatch = new List<InvoiceBatchPopup>();
                    DataTable dtBatch = bl.BL_ExecuteParamSP("uspGetProdInventory", 1, BranchID, PriceID, Convert.ToDateTime(Date), DDT.Rows[i][0].ToString(), 0);
                    for (int j = 0; j < dtBatch.Rows.Count; j++)
                    {
                        ulistBatch.Add(new InvoiceBatchPopup
                        {
                            QtyType = dtBatch.Rows[j]["QtyType"].ToString(),
                            QtyTag = dtBatch.Rows[j]["Tag"].ToString(),
                            ProdID = DDT.Rows[i]["ID"].ToString(),
                            BatchNo = dtBatch.Rows[j]["BatchNumber"].ToString(),
                            PKDDate = dtBatch.Rows[j]["PKDDate"].ToString(),
                            ExpiryDate = dtBatch.Rows[j]["ExpiryDate"].ToString(),
                            ActQty = dtBatch.Rows[j]["Qty"].ToString(),
                            MRP = dtBatch.Rows[j]["MRP"].ToString(),
                            SalesPrice = dtBatch.Rows[j]["Price"].ToString(),
                        });
                    }
                    #region Discount Schemme
                    decimal dConvFact = bl.BL_dValidation(DDT.Rows[i]["SalesCR"].ToString());
                    decimal ApplyPrice = dtBatch.Rows.Count > 0 ? bl.BL_dValidation(dtBatch.Rows[0]["Price"].ToString()) * dConvFact : 0;

                    DataTable dtDiscScheme = bl.BL_ExecuteParamSP("uspGetCustWiseProdDisc", Date, ID, DDT.Rows[i][0].ToString());
                    decimal OrgDiscPern = bl.BL_dValidation(DDT.Rows[i]["ProductDiscPerc"].ToString());
                    decimal OrgTradeDiscPern = 0;
                    decimal OldDiscPern = bl.BL_dValidation(DDT.Rows[i]["ProductDiscPerc"].ToString());
                    decimal DSProdDiscPern = 0, DSProdDiscAmt = 0, DSTradeDiscPern = 0, DSTradeDiscAmt = 0;
                    if (dtDiscScheme.Rows.Count > 0)
                    {
                        DSProdDiscPern = bl.BL_dValidation(dtDiscScheme.Rows[0][2]);
                        DSProdDiscAmt = bl.BL_dValidation(dtDiscScheme.Rows[0][3]) * dConvFact;
                        DSTradeDiscPern = bl.BL_dValidation(dtDiscScheme.Rows[0][4]);
                        DSTradeDiscAmt = bl.BL_dValidation(dtDiscScheme.Rows[0][5]) * dConvFact;
                        int ReplaceExists = bl.BL_nValidation(dtDiscScheme.Rows[0][1]);

                        decimal PDiscAmt = 0, dTradPernfromAmt = 0, dProdPernfromAmt = 0;
                        if (ReplaceExists == 1)//Replay exists
                        {
                            PDiscAmt = (ApplyPrice * DSProdDiscPern) / 100;
                        }
                        else
                        {
                            PDiscAmt = (ApplyPrice * (DSProdDiscPern + OldDiscPern)) / 100;
                        }
                        if (DSTradeDiscAmt > 0)
                        {
                            if (ApplyPrice > 0)
                                dTradPernfromAmt = bl.BL_dValidation((DSTradeDiscAmt / (ApplyPrice - PDiscAmt - DSProdDiscAmt)) * 100);
                            else
                                dTradPernfromAmt = 0;
                        }
                        if (DSProdDiscAmt > 0)
                        {
                            if (ApplyPrice > 0)
                                dProdPernfromAmt = bl.BL_dValidation((DSProdDiscAmt / ApplyPrice) * 100);
                            else
                                dProdPernfromAmt = 0;
                        }
                        if (ReplaceExists == 1)//Replay exists
                        {
                            OrgDiscPern = DSProdDiscPern;
                            OrgTradeDiscPern = DSTradeDiscPern + dTradPernfromAmt;
                        }
                        else
                        {
                            OrgDiscPern = dProdPernfromAmt + DSProdDiscPern + OldDiscPern;
                            OrgTradeDiscPern = DSTradeDiscPern + dTradPernfromAmt;
                        }
                    }
                    #endregion
                    list.Add(new InvoiceBatchInfo
                    {
                        ProdID = DDT.Rows[i]["ID"].ToString(),
                        Code = DDT.Rows[i]["Code"].ToString(),
                        Name = DDT.Rows[i]["Name"].ToString(),
                        HSNCode = DDT.Rows[i]["HSNCode"].ToString(),
                        //ProductDiscPerc = DDT.Rows[i]["ProductDiscPerc"].ToString(),
                        ProductDiscPerc = OrgDiscPern.ToString(),
                        TradeDiscPerc = OrgTradeDiscPern.ToString(),
                        BaseUomID = DDT.Rows[i]["BaseUomID"].ToString(),
                        BaseCR = DDT.Rows[i]["BaseCR"].ToString(),
                        PurchaseUomID = DDT.Rows[i]["PurchaseUomID"].ToString(),
                        PurchaseCR = DDT.Rows[i]["PurchaseCR"].ToString(),
                        SalesUomID = DDT.Rows[i]["SalesUomID"].ToString(),
                        SalesCR = DDT.Rows[i]["SalesCR"].ToString(),
                        SalesTaxID = DDT.Rows[i]["SalesTaxID"].ToString(),
                        PurchasePrice = DDT.Rows[i]["PurchasePrice"].ToString(),
                        SalesPrice = DDT.Rows[i]["SalesPrice"].ToString(),
                        ECP = DDT.Rows[i]["ECP"].ToString(),
                        SPLPrice = DDT.Rows[i]["SPLPrice"].ToString(),
                        MRP = DDT.Rows[i]["MRP"].ToString(),
                        ReturnPrice = DDT.Rows[i]["ReturnPrice"].ToString(),
                        TaxName = DDT.Rows[i]["TaxName"].ToString(),
                        GSTPern = DDT.Rows[i]["GST"].ToString(),
                        IGSTPern = DDT.Rows[i]["IGST"].ToString(),
                        TrackPKD = DDT.Rows[i]["TrackPDK"].ToString(),
                        TrackBatch = DDT.Rows[i]["TrackBatch"].ToString(),
                        TrackInventory = DDT.Rows[i]["TrackInventory"].ToString(),
                        ItemTransactionPrice = DDT.Rows[i]["InvoicePrice"].ToString(),
                        UOMList = ulist,
                        lstInvPopup = ulistBatch
                    });
                }
                return Ok(list);
            }
            if (Mode == "6" || Mode == "10")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", Mode, CodeName);
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

            if (Mode == "7" || Mode == "11" || Mode == "17" || Mode == "21")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", Mode, null, CodeName);
                List<SalesModel> list = new List<SalesModel>();
                if (DDT.Rows.Count > 0)
                {
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        DataTable DDT1 = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", 31, DDT.Rows[i][8].ToString());
                        List<CustomerVendorModel> listParty = new List<CustomerVendorModel>();
                        List<clsCustomerRemarks> listRemark = new List<clsCustomerRemarks>();
                        DataTable dtRem = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", 34, DDT1.Rows[i]["ID"].ToString());
                        if (dtRem.Rows.Count > 0)
                        {
                            for (int j = 0; j < dtRem.Rows.Count; j++)
                            {
                                listRemark.Add(new clsCustomerRemarks
                                {
                                    Remarks = dtRem.Rows[j][1].ToString()
                                });
                            }
                        }
                        string strOSVal = "0", strOSType = "Cr", ACDay = "0";
                        DataTable dtPartyOs = bl.BL_ExecuteParamSP("uspPartyReportData", 2, DDT1.Rows[i]["FAID"].ToString(), 1);
                        if (dtPartyOs.Rows.Count > 0)
                        {
                            strOSVal = dtPartyOs.Rows[0]["OSBAL"].ToString();
                            strOSType = dtPartyOs.Rows[0]["CrDr"].ToString();
                            ACDay = dtPartyOs.Rows[0]["ACC"].ToString();
                        }
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
                                Active = DDT1.Rows[j]["Active"].ToString(),
                                Ratings = DDT1.Rows[j]["Rating"].ToString(),
                                RatingName = DDT1.Rows[i]["RatingName"].ToString(),
                                Distance = DDT.Rows[i]["Distance"].ToString(),
                                CloseBal = strOSVal,
                                OSType = strOSType,
                                ACDate = ACDay,
                                lstCustRemark = listRemark
                            });
                        }

                        List<SalesDetail> listProductGrid = new List<SalesDetail>();
                        int TMode = Mode == "7" ? 8 : Mode == "11" ? 12 : Mode == "17" ? 18 : 22;
                        DataTable DDT2 = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", TMode, null, CodeName);
                        for (int k = 0; k < DDT2.Rows.Count; k++)
                        {
                            DataTable dtUOM = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", 5, "", DDT2.Rows[k]["ProdID"].ToString());
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
                            List<InvoiceBatchPopup> ulistBatch = new List<InvoiceBatchPopup>();
                            DataTable dtBatch = bl.BL_ExecuteParamSP("uspGetProdInventory", 1, DDT.Rows[i]["BranchID"].ToString(), 2,
                                Convert.ToDateTime(DDT.Rows[i]["Date"].ToString()).ToString("yyyy-MM-dd"), DDT2.Rows[k]["ProdID"].ToString(), DDT.Rows[i]["ID"].ToString());
                            for (int j = 0; j < dtBatch.Rows.Count; j++)
                            {
                                ulistBatch.Add(new InvoiceBatchPopup
                                {
                                    QtyType = dtBatch.Rows[j]["QtyType"].ToString(),
                                    QtyTag = dtBatch.Rows[j]["Tag"].ToString(),
                                    ProdID = DDT.Rows[i]["ID"].ToString(),
                                    BatchNo = dtBatch.Rows[j]["BatchNumber"].ToString(),
                                    PKDDate = dtBatch.Rows[j]["PKDDate"].ToString(),
                                    ExpiryDate = dtBatch.Rows[j]["ExpiryDate"].ToString(),
                                    ActQty = dtBatch.Rows[j]["Qty"].ToString(),
                                    MRP = dtBatch.Rows[j]["MRP"].ToString(),
                                    SalesPrice = dtBatch.Rows[j]["Price"].ToString(),
                                });
                            }
                            listProductGrid.Add(new SalesDetail
                            {
                                ProdID = DDT2.Rows[k]["ProdID"].ToString(),
                                UomID = DDT2.Rows[k]["UomID"].ToString(),
                                Code = DDT2.Rows[k]["Code"].ToString(),
                                Name = DDT2.Rows[k]["Name"].ToString(),
                                TaxID = DDT2.Rows[k]["TaxID"].ToString(),
                                UomQty = DDT2.Rows[k]["Qty"].ToString(),
                                MRP = DDT2.Rows[k]["DetailMRP"].ToString(),
                                UomSalePrice = DDT2.Rows[k]["ExclPrice"].ToString(),
                                UomSalePriceIncl = DDT2.Rows[k]["InclPrice"].ToString(),
                                ProdDiscPern = DDT2.Rows[k]["ProdPern"].ToString(),
                                ProdDiscAmt = DDT2.Rows[k]["ProdDiscAmt"].ToString(),
                                TradeDiscPern = DDT2.Rows[k]["TradePern"].ToString(),
                                TradeDiscAmt = DDT2.Rows[k]["TradeDiscAmt"].ToString(),
                                AddnlDiscPern = DDT2.Rows[k]["AddnlPern"].ToString(),
                                AddnlDiscAmt = DDT2.Rows[k]["AddnlDiscAmt"].ToString(),
                                TaxPern = DDT2.Rows[k]["TaxPern"].ToString(),
                                GrossAmt = DDT2.Rows[k]["GrossAmt"].ToString(),
                                TaxAmt = DDT2.Rows[k]["TaxAmt"].ToString(),
                                TaxName = DDT2.Rows[k]["TaxName"].ToString(),
                                NetAmt = DDT2.Rows[k]["NetAmt"].ToString(),
                                GoodsAmt = DDT2.Rows[k]["GoodsAmt"].ToString(),
                                OrgPrice = DDT2.Rows[k]["BaseUomPrice"].ToString(),
                                BatchNo = DDT2.Rows[k]["BatchNo"].ToString(),
                                PKD = !string.IsNullOrEmpty(DDT2.Rows[k]["PKD"].ToString()) ? Convert.ToDateTime(DDT2.Rows[k]["PKD"]).ToString("dd/MM/yyyy") : "",
                                Expiry = !string.IsNullOrEmpty(DDT2.Rows[k]["Expiry"].ToString()) ? Convert.ToDateTime(DDT2.Rows[k]["Expiry"]).ToString("dd/MM/yyyy") : "",
                                InvYN = DDT2.Rows[k]["TrackInventory"].ToString() == "True" ? "1" : "0",
                                BatchYN = DDT2.Rows[k]["TrackBatch"].ToString() == "True" ? "1" : "0",
                                PKDYN = DDT2.Rows[k]["TrackPDK"].ToString() == "True" ? "1" : "0",
                                SerialYN = DDT2.Rows[k]["TrackSerial"].ToString() == "True" ? "1" : "0",
                                DiffAmt = DDT2.Rows[k]["DiffValue"].ToString(),
                                ProductTransPrice = DDT2.Rows[k]["InvoicePrice"].ToString(),
                                QtyType = DDT2.Rows[k]["QtyType"].ToString(),
                                UOMList = ulist,
                                lstInvPopup = ulistBatch
                            });
                        }
                        list.Add(new SalesModel
                        {
                            //Date = Convert.ToDateTime(DDT.Rows[i]["Date"].ToString()).ToString("yyyy-MM-dd"),
                            ID = DDT.Rows[i]["ID"].ToString(),
                            DocDate = Convert.ToDateTime(DDT.Rows[i]["Date"].ToString()).ToString("yyyy-MM-dd"),
                            TransID = DDT.Rows[i]["TransID"].ToString(),
                            BranchID = DDT.Rows[i]["BranchID"].ToString(),
                            DocId = DDT.Rows[i]["DocID"].ToString(),
                            DocValue = DDT.Rows[i]["DocValue"].ToString(),
                            BeatID = DDT.Rows[i]["BeatID"].ToString(),
                            SalesmanID = DDT.Rows[i]["SalesmanID"].ToString(),
                            CustomerID = DDT.Rows[i]["CustomerID"].ToString(),
                            RefNo = DDT.Rows[i]["RefNo"].ToString(),
                            TaxTypeID = DDT.Rows[i]["TaxTypeID"].ToString(),
                            PriceID = DDT.Rows[i]["PriceID"].ToString(),
                            PaymentModeID = DDT.Rows[i]["PaymentModeID"].ToString(),
                            PaymentTermID = DDT.Rows[i]["CreditTermID"].ToString(),
                            FrightAmt = DDT.Rows[i]["FrightAmt"].ToString(),
                            OtherChargePern = DDT.Rows[i]["OtherChrgPern"].ToString(),
                            OtherChargeAmt = DDT.Rows[i]["OtherChargeAmt"].ToString(),
                            TradeDiscPern = DDT.Rows[i]["TradePern"].ToString(),
                            AddnlDiscPern = DDT.Rows[i]["AddnlPern"].ToString(),
                            TotalProdDiscAmt = DDT.Rows[i]["TotalProdDiscAmt"].ToString(),
                            TradeDiscAmt = DDT.Rows[i]["TradeDiscAmt"].ToString(),
                            AddnlDiscAmt = DDT.Rows[i]["AddnlDiscAmt"].ToString(),
                            RoundOffAmt = DDT.Rows[i]["RoundOffAmt"].ToString(),
                            GrossAmt = DDT.Rows[i]["GrossAmt"].ToString(),
                            TaxAmt = DDT.Rows[i]["TaxAmt"].ToString(),
                            NetAmt = DDT.Rows[i]["NetAmt"].ToString(),
                            Status = DDT.Rows[i]["Status"].ToString(),
                            UDFId = DDT.Rows[i]["UDFId"].ToString(),
                            UDFDocId = DDT.Rows[i]["UDFDocId"].ToString(),
                            UDFDocPrefix = DDT.Rows[i]["UDFDocPrefix"].ToString(),
                            UDFDocValue = DDT.Rows[i]["UDFDocValue"].ToString(),
                            Remarks = DDT.Rows[i]["Remarks"].ToString(),
                            Narration = DDT.Rows[i]["Narration"].ToString(),
                            TCSTaxAmt = DDT.Rows[i]["TCSTaxAmt"].ToString(),
                            TDSAmount = DDT.Rows[i]["TDSAmount"].ToString(),
                            WriteOffAmt = DDT.Rows[i]["Writeoff"].ToString(),
                            VehicleNo = DDT.Rows[i]["VehicleNo"].ToString(),
                            Distance = DDT.Rows[i]["Distance"].ToString(),
                            TransportType = DDT.Rows[i]["VehicleType"].ToString(),
                            TransportMode = DDT.Rows[i]["TransMode"].ToString(),
                            TransactionID = DDT.Rows[i]["TransportID"].ToString(),
                            TransactionName = DDT.Rows[i]["TransportName"].ToString(),
                            DiffValueGross = DDT.Rows[i]["DiffValueGross"].ToString(),
                            DiffValueNet = DDT.Rows[i]["DiffValueNet"].ToString(),
                            lstPartyInfo = listParty,
                            lstProdInfo = listProductGrid,
                        });
                    }
                }
                return Ok(list);
            }
            if (Mode == "14")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", Mode, CodeName, ID);
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
                        BatchNo = DDT.Rows[i][9].ToString(),
                        PKD = DDT.Rows[i][10].ToString(),
                        Expiry = DDT.Rows[i][11].ToString(),
                    });
                }
                return Ok(list);
            }
            if (Mode == "15")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", Mode, ID, CodeName);
                return Ok("0");
            }
            if (Mode == "20")
            {
                List<InvoiceBatchPopup> ulistBatch = new List<InvoiceBatchPopup>();
                string PKD = "False", BATCH = "False", TrkInv = "True";
                DataTable dtProdinfo = bl.BL_ExecuteSqlQuery("select TrackBatch,TrackPDK,TrackInventory from tblMasterProduct WHERE ID = " + CodeName);
                if (dtProdinfo.Rows.Count > 0)
                {
                    PKD = dtProdinfo.Rows[0]["TrackPDK"].ToString();
                    BATCH = dtProdinfo.Rows[0]["TrackBatch"].ToString();
                    TrkInv = dtProdinfo.Rows[0]["TrackInventory"].ToString();
                }   
                DataTable dtBatch = bl.BL_ExecuteParamSP("uspGetProdInventory", 1, BranchID, PriceID, Convert.ToDateTime(Date), CodeName, ID);
                if (dtBatch.Rows.Count > 0)
                {
                    for (int j = 0; j < dtBatch.Rows.Count; j++)
                    {
                        ulistBatch.Add(new InvoiceBatchPopup
                        {
                            QtyType = dtBatch.Rows[j]["QtyType"].ToString(),
                            QtyTag = dtBatch.Rows[j]["Tag"].ToString(),
                            ProdID = CodeName,
                            BatchNo = dtBatch.Rows[j]["BatchNumber"].ToString(),
                            PKDDate = dtBatch.Rows[j]["PKDDate"].ToString(),
                            ExpiryDate = dtBatch.Rows[j]["ExpiryDate"].ToString(),
                            ActQty = dtBatch.Rows[j]["Qty"].ToString(),
                            MRP = dtBatch.Rows[j]["MRP"].ToString(),
                            SalesPrice = dtBatch.Rows[j]["Price"].ToString(),
                            TrackBatch = BATCH,
                            TrackPKD = PKD,
                            TrackInventory = TrkInv
                        });
                    }
                }
                return Ok(ulistBatch);
            }
            if (Mode == "23")
            {
                List<InvoiceBatchPopup> ulistBatch = new List<InvoiceBatchPopup>();
                string PKD = "False", BATCH = "False", TrkInv = "True";
                //DataTable dtProdinfo = bl.BL_ExecuteSqlQuery("select TrackBatch,TrackPDK,TrackInventory from tblMasterProduct WHERE ID = " + CodeName);
                DataTable dtProdinfo = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", Mode, CodeName, PriceID);
                if (dtProdinfo.Rows.Count > 0)
                {
                    PKD = dtProdinfo.Rows[0]["TrackPDK"].ToString();
                    BATCH = dtProdinfo.Rows[0]["TrackBatch"].ToString();
                    TrkInv = dtProdinfo.Rows[0]["TrackInventory"].ToString();
                }

                if (TrkInv == "True")
                {
                    DataTable dtBatch = bl.BL_ExecuteParamSP("uspGetProdInventory", 1, BranchID, PriceID, Convert.ToDateTime(Date), CodeName, ID);
                    if (dtBatch.Rows.Count > 0)
                    {
                        //for (int j = 0; j < dtBatch.Rows.Count; j++)
                        {
                            ulistBatch.Add(new InvoiceBatchPopup
                            {
                                QtyType = dtBatch.Rows[0]["QtyType"].ToString(),
                                QtyTag = dtBatch.Rows[0]["Tag"].ToString(),
                                ProdID = CodeName,
                                BatchNo = dtBatch.Rows[0]["BatchNumber"].ToString(),
                                PKDDate = dtBatch.Rows[0]["PKDDate"].ToString(),
                                ExpiryDate = dtBatch.Rows[0]["ExpiryDate"].ToString(),
                                ActQty = dtBatch.Rows[0]["Qty"].ToString(),
                                MRP = dtBatch.Rows[0]["MRP"].ToString(),
                                SalesPrice = dtBatch.Rows[0]["Price"].ToString(),
                                TrackBatch = BATCH,
                                TrackPKD = PKD,
                                TrackInventory = TrkInv
                            });
                        }
                    }
                }
                else
                {
                    ulistBatch.Add(new InvoiceBatchPopup
                    {
                        QtyType = "SALE",
                        QtyTag = "1",
                        ProdID = CodeName,
                        BatchNo = null,
                        PKDDate = null,
                        ExpiryDate = null,
                        ActQty = "0",
                        MRP = dtProdinfo.Rows[0]["MRP"].ToString(),
                        SalesPrice = dtProdinfo.Rows[0]["Price"].ToString(),
                        TrackBatch = BATCH,
                        TrackPKD = PKD,
                        TrackInventory = TrkInv
                    });
                }

                return Ok(ulistBatch);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/invoice/getproductlist")]
        public IHttpActionResult GetgetproductlistData(string TransID, string Branch, string PriceType, string Date)
        {
            DataTable DDT = bl.BL_ExecuteParamSP("uspTransProductAutocomplete", TransID, Branch, PriceType, Convert.ToDateTime(Date));
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
                    PurchasePrice = DDT.Rows[i]["Price"].ToString(),
                    ABSQty = TransID != "17" ? DDT.Rows[i]["ABSQty"].ToString() : DDT.Rows[i]["ABSDmgQty"].ToString(),
                    LocationID = DDT.Rows[i]["LocationName"].ToString(),
                });
            }
            return Ok(list);
        }
        [HttpGet]
        [Route("api/invoice/getfilterdata")]
        public IHttpActionResult GetFilterData(string TransID, string FType, string Branch, string Party, string FromDate, string ToDate, string Showall)
        {
            string Mode = FType == "1" ? "6" : FType == "2" ? "10" : FType == "3" ? "16" : "20";
            DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", Mode, FType, Branch, TransID, Party, FromDate, ToDate, Showall);
            List<PurchaseModel> list = new List<PurchaseModel>();
            //SalesModel
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
                    InfoMessage = DDT.Rows[i]["Info"].ToString(),
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
                               CurrentStatus = users.CurrentStatus,
                               InfoMessage = users.InfoMessage
                           };
            return Ok(data);
        }
        [HttpGet]
        [Route("api/invoice/validatecreditlimit")]
        public IHttpActionResult validatecreditlim(string CustID, string Date, string CreditTermID, string NetAmt, string TransID)
        {

            DataTable DDT = bl.BL_ExecuteParamSP("uspValidateCustomerCreditLimit", 2, CustID, Date, CreditTermID, NetAmt, TransID);
            List<PasswordSettingAppconfig> list = new List<PasswordSettingAppconfig>();
            if (DDT.Columns.Count > 1)
            {
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new PasswordSettingAppconfig
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        Name = DDT.Rows[i][1].ToString(),
                        Value = DDT.Rows[i][2].ToString(),
                    });
                }
            }
            return Ok(list);
        }
        [HttpGet]
        [Route("api/invoice/invoicecollectiondata")]
        public IHttpActionResult invoicecollectiondata(string InvoiceID)
        {

            DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetAssignInvoices", 6, InvoiceID);
            string invjson = JsonConvert.SerializeObject(DDT);
            return Ok(invjson);            
        }
        [HttpPost]
        [Route("api/invoice/verifycreditlimit")]
        public IHttpActionResult checkPASSOWRD(ApplicationConfig lstPWD)
        {
            List<SaveMessage> list = new List<SaveMessage>();
            foreach (PasswordSettingAppconfig item in lstPWD.lstConfigPasswords)
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspManageApplicationConfig", 9, item.ID);                
                if (DDT.Rows.Count > 0)
                {
                    string decryptpwd = clsEncryptDecrypt.Decrypt(DDT.Rows[0][2].ToString());
                    if (item.Passwords != decryptpwd)
                    {
                        list.Add(new SaveMessage
                        {
                            Message = "Invalid Password",
                            MsgID = "1",
                            ID = item.ID
                        });
                    }                    
                }
                else
                {
                    list.Add(new SaveMessage
                    {
                        Message = "Password not found or De-activated",
                        MsgID = "2",
                        ID = item.ID
                    });
                }
            }
            return Ok(list);
        }
            [HttpPost]
        [Route("api/invoice/save")]
        public IHttpActionResult Save(SalesModel listTrans)
        {
            if (listTrans != null)
            {
                if (dtProd.Columns.Count == 0)
                {
                    dtProd.Columns.Add("ProdId", typeof(int));
                    dtProd.Columns.Add("InventoryYesNo", typeof(int));
                    dtProd.Columns.Add("BatchYesNo", typeof(int));
                    dtProd.Columns.Add("PKDYesNo", typeof(int));
                    dtProd.Columns.Add("SerialYesNo", typeof(int));
                    dtProd.Columns.Add("BaseUomPrice", typeof(decimal));
                    dtProd.Columns.Add("UomId", typeof(int));
                    dtProd.Columns.Add("UomQty", typeof(decimal));
                    dtProd.Columns.Add("UomPrice", typeof(decimal));
                    dtProd.Columns.Add("GoodsAmt", typeof(decimal));
                    dtProd.Columns.Add("UserDisc", typeof(decimal));
                    dtProd.Columns.Add("UserDiscAmt", typeof(decimal));
                    dtProd.Columns.Add("ProdDisc", typeof(decimal));
                    dtProd.Columns.Add("ProdDiscAmt", typeof(decimal));
                    dtProd.Columns.Add("TradeDisc", typeof(decimal));
                    dtProd.Columns.Add("TradeDiscPern", typeof(decimal));
                    dtProd.Columns.Add("AddnlDisc", typeof(decimal));
                    dtProd.Columns.Add("AddnlDiscPern", typeof(decimal));
                    dtProd.Columns.Add("GrossAmt", typeof(decimal));
                    dtProd.Columns.Add("TaxId", typeof(int));
                    dtProd.Columns.Add("TaxPercentage", typeof(decimal));
                    dtProd.Columns.Add("TaxAmt", typeof(decimal));
                    dtProd.Columns.Add("NetAmt", typeof(decimal));
                    dtProd.Columns.Add("ReasonId", typeof(int));
                    dtProd.Columns.Add("Serial", typeof(int));
                    dtProd.Columns.Add("BatchNumber", typeof(string));
                    dtProd.Columns.Add("PkgDate", typeof(string));
                    dtProd.Columns.Add("ExpiryDate", typeof(string));
                    dtProd.Columns.Add("InventoryPrice", typeof(decimal));
                    dtProd.Columns.Add("MRP", typeof(decimal));
                    dtProd.Columns.Add("InvQtyType", typeof(int));
                    dtProd.Columns.Add("TempBatchInvId", typeof(int));
                    dtProd.Columns.Add("UomCR", typeof(decimal));
                    dtProd.Columns.Add("DiffAmt", typeof(decimal));
                    
                }
                DataTable dtTempBachInfo = new DataTable();
                DataColumn column = new DataColumn("Serial");
                column.DataType = System.Type.GetType("System.Int32");
                column.AutoIncrement = true;
                column.AutoIncrementSeed = 1;
                column.AutoIncrementStep = 1;
                dtTempBachInfo.Columns.Add(column);
                dtTempBachInfo.Columns.Add("ProdId", typeof(int));
                dtTempBachInfo.Columns.Add("Batch", typeof(string));
                dtTempBachInfo.Columns.Add("PKD", typeof(string));
                dtTempBachInfo.Columns.Add("Expiry", typeof(string));
                dtTempBachInfo.Columns.Add("PPrice", typeof(decimal));
                dtTempBachInfo.Columns.Add("SPrice", typeof(decimal));
                dtTempBachInfo.Columns.Add("ECP", typeof(decimal));
                dtTempBachInfo.Columns.Add("MRP", typeof(decimal));
                dtTempBachInfo.Columns.Add("SPLPrice", typeof(decimal));
                dtTempBachInfo.Columns.Add("ReturnPrice", typeof(decimal));
                dtTempBachInfo.Columns.Add("TaxId", typeof(int));
                dtTempBachInfo.Columns.Add("TaxTypeId", typeof(int));
                dtTempBachInfo.Columns.Add("InclusiveYesNo", typeof(int));
                dtTempBachInfo.Columns.Add("BatchType", typeof(int));
                dtTempBachInfo.Columns.Add("HiddenRowID", typeof(int));
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

                dtDocument.Columns.Add("TransName");
                dtDocument.Columns.Add("Status", typeof(int)).DefaultValue = 0;
                dtDocument.Columns.Add("DocumentId", typeof(int)).DefaultValue = 0;
                //Serial Table
                dtSerialInfo.Columns.Add("Index", typeof(int));
                dtSerialInfo.Columns.Add("ProdId", typeof(int));
                dtSerialInfo.Columns.Add("Serial", typeof(string));
                //paymentmode

                dtMop.Columns.Add("AccId",typeof(int));
                dtMop.Columns.Add("PayModeId", typeof(int));
                dtMop.Columns.Add("Cheque_OR_DDNumber_OR_NEFTId", typeof(string));
                dtMop.Columns.Add("BankAccNo", typeof(string));
                dtMop.Columns.Add("BankAccID", typeof(int));
                dtMop.Columns.Add("PMDate", typeof(string));
                dtMop.Columns.Add("PayAt", typeof(string));
                dtMop.Columns.Add("IfscCode", typeof(string));
                dtMop.Columns.Add("Bank", typeof(string));
                dtMop.Columns.Add("Branch", typeof(string));
                dtMop.Columns.Add("Amt", typeof(decimal));
                dtMop.Columns.Add("SerialNo", typeof(int));
                dtMop.Columns.Add("Balance", typeof(decimal));
                dtMop.Columns.Add("OriginalCollAmt", typeof(decimal));
                dtMop.Columns.Add("VisaPern", typeof(decimal));
                dtMop.Columns.Add("VisaAmt", typeof(decimal));


                DataTable dtBatch = new DataTable();// ToDataTable(listTrans.lstBatchInfo);
                DataTable dtPaymodeDetails = new DataTable();
                DataTable dtProducts = ToDataTable(listTrans.lstProdInfo);
                if (listTrans.lstPaymodeInfo != null)
                    dtPaymodeDetails = ToDataTable(listTrans.lstPaymodeInfo);
                List<SaveMessage> list = new List<SaveMessage>();
                if (listTrans.TransMode != "4")
                {
                    int nSerial = 1;
                    for (int i = 0; i < dtProducts.Rows.Count; i++)
                    {
                        int nProdID = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["ProdID"]));
                        if (nProdID > 0)
                        {
                            //DataTable getConvFact = bl.BL_ExecuteSqlQuery("select dbo.fnGetConvertionFact(" + bl.BL_nValidation(dgvProd.Rows[DetailCount].Cells[UomGrpID.Name].Value) + "," + bl.BL_nValidation(dgvProd.Rows[DetailCount].Cells[UomID.Name].Value) + ")");
                            decimal dUomTax = 0;// bl.GetUOMTaxValue(bl.BL_nValidation(iRow["TaxID"]), bl.BL_nValidation(txtTaxType.Tag),
                                                //(bl.BL_dValidation(iRow["Qty"]) + bl.BL_dValidation(iRow["DmgQty"])) * (getConvFact.Rows.Count > 0 ? bl.BL_dValidation(getConvFact.Rows[0][0].ToString()) : 0.00M));// bl.BL_dValidation(dgvProd.Rows[DetailCount].Cells[SelectedUomCF.Name].Value));
                            DataRow dtRow = dtProd.NewRow();

                            dtRow["ProdId"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["ProdID"]));
                            dtRow["InventoryYesNo"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["InvYN"]));
                            dtRow["BatchYesNo"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["BatchYN"]));
                            dtRow["PKDYesNo"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["PKDYN"]));
                            dtRow["SerialYesNo"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["SerialYN"]));
                            dtRow["BaseUomPrice"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["OrgPrice"]));
                            dtRow["UomId"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["UOMID"]));
                            dtRow["UomQty"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["UomQty"]));
                            dtRow["UomPrice"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["SalePrice"]));
                            dtRow["GoodsAmt"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["GoodsAmt"]));
                            dtRow["UserDisc"] = 0;
                            dtRow["UserDiscAmt"] = 0;
                            dtRow["ProdDisc"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["ProdDiscPern"]));
                            dtRow["ProdDiscAmt"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["ProdDiscAmt"]));
                            dtRow["TradeDisc"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["TradeDiscAmt"]));
                            dtRow["TradeDiscPern"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["TradeDiscPern"]));
                            dtRow["AddnlDisc"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["AddnlDiscAmt"]));
                            dtRow["AddnlDiscPern"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["AddnlDiscPern"]));
                            dtRow["GrossAmt"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["GrossAmt"]));
                            dtRow["TaxId"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["TaxID"])); ;
                            dtRow["TaxPercentage"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["TaxPern"]));
                            dtRow["TaxAmt"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["TaxAmt"]));
                            dtRow["NetAmt"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["NetAmt"]));
                            dtRow["ReasonId"] = 0;
                            dtRow["Serial"] = nSerial;
                            dtRow["BatchNumber"] = Convert.ToString(dtProducts.Rows[i]["BatchNo"]);
                            dtRow["PkgDate"] = Convert.ToString(dtProducts.Rows[i]["PKD"]);
                            dtRow["ExpiryDate"] = Convert.ToString(dtProducts.Rows[i]["Expiry"]);
                            dtRow["InventoryPrice"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["OrgPrice"]));
                            dtRow["MRP"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["MRP"]));
                            dtRow["UomCR"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["ConvFact"]));                            
                            dtRow["InvQtyType"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["QtyType"]));
                            dtRow["TempBatchInvId"] = 0;
                            dtRow["DiffAmt"]= bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["DiffAmt"]));
                            dtProd.Rows.Add(dtRow);
                            nSerial++;
                        }
                    }
                    nSerial = 1;
                    for (int i = 0; i < dtPaymodeDetails.Rows.Count; i++)
                    {                        
                        int nPayMode = bl.BL_nValidation(Convert.ToString(dtPaymodeDetails.Rows[i]["Mode"]));
                        decimal dAmt = bl.BL_dValidation(dtPaymodeDetails.Rows[i]["Amt"].ToString());
                        if (dAmt > 0)
                        {
                            DataRow dtRow = dtMop.NewRow();
                            dtRow["AccId"] = bl.BL_nValidation(dtPaymodeDetails.Rows[i]["AccID"]);
                            dtRow["PayModeId"] = nPayMode;
                            dtRow["Cheque_OR_DDNumber_OR_NEFTId"] = dtPaymodeDetails.Rows[i]["ChequeDDNumber"].ToString();
                            dtRow["BankAccNo"] = dtPaymodeDetails.Rows[i]["BankAccNo"].ToString();
                            dtRow["BankAccID"] = dtPaymodeDetails.Rows[i]["BankAccId"].ToString();
                            dtRow["PMDate"] = !string.IsNullOrEmpty(dtPaymodeDetails.Rows[i]["Date"].ToString()) ?
                                Convert.ToDateTime(dtPaymodeDetails.Rows[i]["Date"].ToString()).ToString("dd/MM/yyyy") : DateTime.Now.ToString("dd/MM/yyyy");
                            dtRow["PayAt"] = null;// nPayMode == 4 ? bl.BL_nValidation(dtPaymodeDetails.Rows[i]["AccID"].ToString()) : 0;
                            dtRow["IfscCode"] = dtPaymodeDetails.Rows[i]["IFSC"].ToString();
                            dtRow["Bank"] = dtPaymodeDetails.Rows[i]["Bank"].ToString();
                            dtRow["Branch"] = dtPaymodeDetails.Rows[i]["Branch"].ToString();
                            dtRow["Amt"] = dAmt;
                            //dtRow["RecdAmt"] = bl.BL_dValidation(dtPaymodeDetails.Rows[i]["RecdAmt"].ToString());
                            dtRow["SerialNo"] = nSerial;
                            dtRow["Balance"] = bl.BL_dValidation(dtPaymodeDetails.Rows[i]["OriginalCollAmt"].ToString());
                            dtRow["OriginalCollAmt"] = bl.BL_dValidation(dtPaymodeDetails.Rows[i]["OriginalCollAmt"].ToString());
                            dtRow["VisaPern"] = dtPaymodeDetails.Rows[i]["VisaPern"].ToString();
                            dtRow["VisaAmt"] = dtPaymodeDetails.Rows[i]["VisaAmt"].ToString();
                            dtMop.Rows.Add(dtRow);
                            nSerial++;
                        }
                    }
                    if (listTrans.IsDraft == "0")
                    {
                        bl.bl_Transaction(1);
                        try
                        {
                            if (listTrans.TransMode == "2")
                            {
                                DataTable dtCheck = bl.bl_ManageTrans("uspManageTranSalesCancel", listTrans.CurrentStatus, listTrans.ID, listTrans.UserID, listTrans.TransMode);
                                if (dtCheck.Columns.Count > 1)
                                {
                                    string ErrorMsg = "";
                                    int nCheck = bl.BL_nValidation(dtCheck.Rows[0][0].ToString());
                                    if (nCheck == 7)
                                    {
                                        ErrorMsg = "This document already processed";
                                    }
                                    if (nCheck == 8)
                                    {
                                        ErrorMsg = "Amount miss matched,So this invoice unable to modify or cancel";
                                    }
                                    if (nCheck == 9)
                                    {
                                        ErrorMsg = "Product already de-active for this document";
                                    }
                                    if (nCheck == 10)
                                    {
                                        ErrorMsg = "Qty Not Exist,so this transaction unable to  cancel";
                                    }
                                    if (nCheck == 16)
                                    {
                                        ErrorMsg = "Collection Status Already Changed";
                                    }
                                    if (nCheck == 17)
                                    {
                                        ErrorMsg = "Coupon Status Already Changed";
                                    }
                                    if (nCheck == 20)
                                    {
                                        ErrorMsg = "Amount Partially collected";
                                    }
                                    if (nCheck == 21)
                                    {
                                        ErrorMsg = "This Document Already Used in Sales Return";
                                    }
                                    bl.bl_Transaction(3);
                                    list.Add(new SaveMessage()
                                    {
                                        ID = 1.ToString(),
                                        MsgID = "1",
                                        Message = ErrorMsg
                                    });
                                    return Ok(list);
                                }
                            }

                            string nMode = listTrans.TransMode == "3" ? "1" : listTrans.TransMode;
                            decimal TotDiscAmt = bl.BL_dValidation(listTrans.TotalProdDiscAmt) + bl.BL_dValidation(listTrans.TradeDiscAmt) + bl.BL_dValidation(listTrans.AddnlDiscAmt);
                            DataTable dtResult = bl.bl_ManageTrans("uspManageSalesHeader", bl.BL_nValidation(listTrans.Status), bl.BL_nValidation(listTrans.UserID),
                                 bl.BL_nValidation(listTrans.TransID), bl.BL_nValidation(listTrans.ID), listTrans.DocDate, listTrans.DocDate, listTrans.BeatID, listTrans.SalesmanID,
                                 listTrans.BranchID, listTrans.CustomerID, bl.BL_nValidation(listTrans.PriceID), bl.BL_nValidation(listTrans.TaxTypeID), bl.BL_nValidation(listTrans.PaymentModeID), bl.BL_nValidation(listTrans.PaymentTermID),
                                 0, listTrans.RefNo, bl.BL_dValidation(listTrans.FrightAmt), bl.BL_dValidation(listTrans.OtherChargePern), bl.BL_dValidation(listTrans.OtherChargeAmt),
                                 bl.BL_dValidation(listTrans.RoundOffAmt), bl.BL_dValidation(listTrans.WriteOffAmt), 0, bl.BL_dValidation(listTrans.TradeDiscPern), bl.BL_dValidation(listTrans.TradeDiscAmt),
                                 bl.BL_dValidation(listTrans.TotalProdDiscAmt), bl.BL_dValidation(listTrans.AddnlDiscPern), bl.BL_dValidation(listTrans.AddnlDiscAmt),
                                 bl.BL_dValidation(listTrans.GrossAmt), bl.BL_dValidation(listTrans.TaxAmt), TotDiscAmt,
                                 bl.BL_dValidation(listTrans.NetAmt), bl.BL_nValidation(listTrans.UDFId), dtDocument, dtProd, dtSerialInfo, 1, bl.BL_nValidation(listTrans.CurrentStatus), null,
                                 0, bl.BL_dValidation(listTrans.TCSTaxAmt), bl.BL_nValidation(listTrans.TDSAmount), 0,
                                 listTrans.Remarks, listTrans.Narration, bl.BL_nValidation(listTrans.DraftID),
                                 bl.BL_nValidation(listTrans.FilterTypeID), listTrans.VehicleNo, listTrans.Distance, listTrans.TransportType,
                                 listTrans.TransportMode, listTrans.TransactionID, listTrans.TransactionName, bl.BL_dValidation(listTrans.DiffValueGross), bl.BL_dValidation(listTrans.DiffValueNet));

                            if (dtResult.Columns.Count > 1)
                            {
                                bl.bl_Transaction(3);
                                string msg = "", RowID = "-1";
                                string[] strErrorList = dtResult.Rows[0][0].ToString().Split('$');
                                if ("DocumentStatus" == strErrorList[0].Trim())
                                {
                                    msg = "Adjusted document status changed";
                                }
                                else if ("DocumentAmount" == strErrorList[0].Trim())
                                {
                                    msg = "Adjusted document amount changed";
                                }
                                else if ("BankAcc" == strErrorList[0].Trim())
                                {
                                    msg = "Account de-active in multipayment mode popup";
                                }
                                else if ("6" == strErrorList[0].Trim())
                                {
                                    msg = "Qty Mismatched";
                                    RowID = dtResult.Columns.Count == 4 ? dtResult.Rows[0][3].ToString() : "0";
                                }
                                else if ("13" == strErrorList[0].Trim())
                                {
                                    msg = "Qty Mismatched";
                                    RowID = dtResult.Rows[0][3].ToString();
                                }
                                else
                                {
                                    msg = dtResult.Rows[0][0].ToString();
                                }
                                list.Add(new SaveMessage()
                                {
                                    ID = 0.ToString(),
                                    MsgID = "1",
                                    Message = msg,
                                    RowID = RowID
                                });
                                return Ok(list);
                            }
                            else
                            {
                                //bl.bl_Transaction(2);
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

                                        //DataTable getConvFact = bl.BL_ExecuteSqlQuery("select dbo.fnGetConvertionFact(" + bl.BL_nValidation(dtProd.Rows[nCount]["UomGrpID"]) + "," + bl.BL_nValidation(dtProd.Rows[nCount]["UomId"]) + ")");

                                        dQtys = (bl.BL_dValidation(dtProd.Rows[nCount]["UomQty"])) * 1;// bl.BL_dValidation(dtResult.Rows[0][0]);

                                        DataTable dtTaxCompInfo = bl.bl_ManageTrans("uspGetTaxCompInfo", nTaxID, nTaxTypeID);
                                        if (dtTaxCompInfo.Rows.Count > 0)
                                        {
                                            bool ValidtoCalc = false;

                                            for (int nTaxComp = 0; nTaxComp < dtTaxCompInfo.Rows.Count; nTaxComp++)
                                            {
                                                ValidtoCalc = true;
                                                    //nTaxTypeID == 1 && bl.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 1 ||
                                                     //       nTaxTypeID == 2 && bl.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 2 ? false : true;
                                                DataRow dr = dtGSTInfo.NewRow();
                                                dr["TransID"] = 15;
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
                                                dr["TransSerial"] = (nCount + 1);
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
                                DataTable dtAdjId = new DataTable();
                                dtAdjId.Columns.Add("NoteId");
                                dtAdjId.Columns.Add("DocPrefix");
                                dtAdjId.Columns.Add("DocValue");
                                dtAdjId.Columns.Add("CrDate");
                                dtAdjId.Columns.Add("Balance", typeof(decimal)).DefaultValue = 0;
                                dtAdjId.Columns.Add("UDN");
                                DataTable dtDenominationPMDetail = new DataTable();
                                dtDenominationPMDetail.Columns.Add("ColDetailDid", typeof(int));
                                dtDenominationPMDetail.Columns.Add("ColDetailDenomination", typeof(int));
                                dtDenominationPMDetail.Columns.Add("ColtotCoupons", typeof(int));
                                dtDenominationPMDetail.Columns.Add("ColDetailCount", typeof(string));
                                dtDenominationPMDetail.Columns.Add("ColDetailAmount", typeof(decimal));
                                if (listTrans.PaymentModeID == "8")
                                {
                                    DataTable dtCheck = bl.bl_ManageTrans("uspManageTranSalesColl",
                                    listTrans.UserID,
                                    nBillScopeID,
                                    dtAdjId,
                                    dtMop,
                                    listTrans.BeatID,
                                    listTrans.SalesmanID,
                                    dtDenominationPMDetail
                                    );
                                    //Error Raised in Collection Level
                                    if (dtCheck.Columns.Count > 1)
                                    {
                                        string msg = "";
                                        int nCheck;
                                        
                                        if (int.TryParse(dtCheck.Rows[0][0].ToString(), out nCheck))
                                        {
                                            if (nCheck == 11)
                                            {
                                                msg = "Credit term de-active in multi payment mode popup";
                                            }
                                        }
                                        else
                                        {
                                            string[] strErrorList = dtCheck.Rows[0][0].ToString().Split('$');
                                            
                                            if ("DocumentStatus" == strErrorList[0].Trim())
                                            {
                                                msg = "Adjusted document status changed";
                                            }
                                            else if ("DocumentAmount" == strErrorList[0].Trim())
                                            {
                                                msg = "Adjusted document amount changed";
                                            }
                                            else if ("BankAcc" == strErrorList[0].Trim())
                                            {
                                                msg = "Account de-active in multipayment mode popup";
                                            }
                                            else
                                            {                                                
                                                msg = dtCheck.Rows[0][0].ToString();
                                                msg = msg + " , " + dtCheck.Rows[0][1].ToString() + " , " + dtCheck.Rows[0][2].ToString();
                                            }
                                        }
                                        bl.bl_Transaction(3);
                                        list.Add(new SaveMessage()
                                        {
                                            ID = 0.ToString(),
                                            MsgID = "1",
                                            Message = "Collection : " + msg
                                        });
                                        return Ok(list);
                                    }
                                }
                                bl.bl_Transaction(2);
                                bl.BL_UpdateclosingDateforPosting(15, nBillScopeID, Convert.ToDateTime(listTrans.DocDate));
                                list.Add(new SaveMessage()
                                {
                                    ID = nBillScopeID.ToString(),
                                    MsgID = "0",
                                    Message = "Saved Successfully"
                                });
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
                        DataTable dtResult = bl.bl_ManageTrans("uspManageSalesDraftHeader", bl.BL_nValidation(listTrans.Status), bl.BL_nValidation(listTrans.UserID),
                                 bl.BL_nValidation(listTrans.TransID), bl.BL_nValidation(listTrans.ID), listTrans.DocDate, listTrans.DocDate, listTrans.BeatID, listTrans.SalesmanID,
                                 listTrans.BranchID, listTrans.CustomerID, bl.BL_nValidation(listTrans.PriceID), bl.BL_nValidation(listTrans.TaxTypeID), bl.BL_nValidation(listTrans.PaymentModeID), bl.BL_nValidation(listTrans.PaymentTermID),
                                 0, listTrans.RefNo, bl.BL_dValidation(listTrans.FrightAmt), bl.BL_dValidation(listTrans.OtherChargePern), bl.BL_dValidation(listTrans.OtherChargeAmt),
                                 bl.BL_dValidation(listTrans.RoundOffAmt), bl.BL_dValidation(listTrans.WriteOffAmt), 0, bl.BL_dValidation(listTrans.TradeDiscPern), bl.BL_dValidation(listTrans.TradeDiscAmt),
                                 bl.BL_dValidation(listTrans.TotalProdDiscAmt), bl.BL_dValidation(listTrans.AddnlDiscPern), bl.BL_dValidation(listTrans.AddnlDiscAmt),
                                 bl.BL_dValidation(listTrans.GrossAmt), bl.BL_dValidation(listTrans.TaxAmt), bl.BL_dValidation(listTrans.TotalDiscAmt),
                                 bl.BL_dValidation(listTrans.NetAmt), bl.BL_nValidation(listTrans.UDFId), dtDocument, dtProd, dtSerialInfo,dtTempBachInfo, 1, bl.BL_nValidation(listTrans.CurrentStatus), null,
                                 0, bl.BL_nValidation(listTrans.TCSTaxAmt), bl.BL_nValidation(listTrans.TDSAmount), 0,
                                 listTrans.Remarks, listTrans.Narration, bl.BL_nValidation(listTrans.DraftID), bl.BL_nValidation(listTrans.FilterTypeID), bl.BL_dValidation(listTrans.DiffValueGross), bl.BL_dValidation(listTrans.DiffValueNet));
                        if (dtResult.Columns.Count > 1)
                        {
                            bl.bl_Transaction(3);
                            list.Add(new SaveMessage()
                            {
                                ID = 0.ToString(),
                                MsgID = "1",
                                Message ="Draft : "+ dtResult.Rows[0][0].ToString()
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
                    DataTable dtResult = bl.bl_ManageTrans("uspManageTranSalesCancel", listTrans.CurrentStatus, listTrans.ID, listTrans.UserID, listTrans.TransMode, listTrans.Remarks, listTrans.Narration);
                    if (dtResult.Columns.Count > 1)
                    {
                        string ErrorMsg = "";
                        int nCheck = bl.BL_nValidation(dtResult.Rows[0][0].ToString());
                        if (nCheck == 7)
                        {
                            ErrorMsg = "This document already processed";
                        }
                        if (nCheck == 8)
                        {
                            ErrorMsg = "Amount miss matched,So this invoice unable to modify or cancel";
                        }
                        if (nCheck == 9)
                        {
                            ErrorMsg = "Product already de-active for this document";
                        }
                        if (nCheck == 10)
                        {
                            ErrorMsg = "Qty Not Exist,so this transaction unable to  cancel";
                        }
                        if (nCheck == 16)
                        {
                            ErrorMsg = "Collection Status Already Changed";
                        }
                        if (nCheck == 17)
                        {
                            ErrorMsg = "Coupon Status Already Changed";
                        }
                        if (nCheck == 20)
                        {
                            ErrorMsg = "Amount Partially collected";
                        }
                        if (nCheck == 21)
                        {
                            ErrorMsg = "This Document Already Used in Sales Return";
                        }
                        bl.bl_Transaction(3);
                        list.Add(new SaveMessage()
                        {
                            ID = 1.ToString(),
                            MsgID = "1",
                            Message ="Cancel : "+ ErrorMsg
                        });
                        return Ok(list);
                    }
                    else
                    {
                        bl.bl_Transaction(2);
                        bl.BL_UpdateclosingDateforPosting(15, bl.BL_nValidation(listTrans.ID), Convert.ToDateTime(listTrans.DocDate));
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
        [HttpGet]
        [Route("api/invoice/PDFGenerate")]
        public IHttpActionResult PDFGenerate(string DocID, string TransID = "", string ConfigID = "", string PrinterID = "", string TransName = "")
        {
            try
            {
                string pdfFilePath = AppDomain.CurrentDomain.BaseDirectory + "PDF\\";// System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"] + "PDF\\";
                string FileLocationwithname = "";

                if (!string.IsNullOrEmpty(pdfFilePath))
                {
                    //DownloadFile df = new DownloadFile();
                    // df.DownloadFiles(@"E:\Print Document\PrintSpool\full.pdf");
                    //GKSDownload gksd = new GKSDownload();

                    //DownloadFiles(@"E:\Print Document\PrintSpool\half.pdf");
                    //tpm.TransName = "Invoice";
                    //ConfigID = "1";
                    DataTable dtTName = bl.BL_ExecuteSqlQuery("select TransName from tblTransName where Id = " + TransID);

                    PrintBase PB = new PrintBase { GKS_BL = bl };
                    //DataTable dt = objBL.BL_ExecuteParamSP("uspgetID", dtTName.Rows[0][0].ToString(), DocID);
                    if (Convert.ToInt32(DocID) > 0)
                    {
                        if (!string.IsNullOrEmpty(ConfigID.ToString()))
                        {
                            FileLocationwithname = PB.SaveAsPDF(Convert.ToInt32(TransID), Convert.ToInt32(DocID), Dns.GetHostName(), "", Convert.ToInt32(ConfigID));
                            //PB.PrintAndPreview(Convert.ToInt32(TransID), Convert.ToInt32(dt.Rows[0][0].ToString()), true, false, false, "");

                        }
                    }
                }
                //Build the File Path.
                //string path = Server.MapPath("~/Files/") + fileName;
                //string path = @"E:\Print Document\PrintSpool\" + fileName;

                //if (!string.IsNullOrEmpty(FileLocationwithname))
                //{
                string pathwithFileName = FileLocationwithname;// @"E:\Print Document\PrintSpool\half.pdf";
                                                               //Read the File data into Byte Array.
                byte[] bytes = System.IO.File.ReadAllBytes(pathwithFileName);
                string exts = Path.GetExtension(pathwithFileName);
                string ctype = GetMimeType(exts);
                string fileName = Path.GetFileName(pathwithFileName);
                //string pth = pathwithFileName.Replace(Filena, "");
                //Send the File to Download.
                //return File(bytes, "application/pdf", fileName);
                //Directory.Delete(pth, true);

                //return File(bytes, ctype, fileName);
                return Ok(fileName);
                //}
                //else
                //{
                //    return File(null,"");
                //}
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("PDFGenerate", "SaveFileinLocation", ex.Message);
            }
            return null;
        }
        public IDictionary<string, string> _mappings = new Dictionary<string, string>(StringComparer.InvariantCultureIgnoreCase);

        public string GetMimeType(string extension)
        {
            if (extension == null)
            {
                throw new ArgumentNullException("extension");
            }

            if (!extension.StartsWith("."))
            {
                extension = "." + extension;
            }
            string mime;

            return _mappings.TryGetValue(extension, out mime) ? mime : "application/octet-stream";
        }
        [System.Web.Http.HttpGet]
        [System.Web.Http.Route("api/invoice/downloadprint")]
        public HttpResponseMessage downloadprintData(string FName)
        {
            DataTable dt = new DataTable();
            string FPath = AppDomain.CurrentDomain.BaseDirectory+ "PDF\\" + FName;            
            string fileName = FName;
            if (!File.Exists(FPath))
                return new HttpResponseMessage(HttpStatusCode.NotFound);

            var result = new HttpResponseMessage(HttpStatusCode.OK);
            var stream = new FileStream(FPath, FileMode.Open, FileAccess.Read);
            result.Content = new StreamContent(stream);
            result.Content.Headers.ContentType = new MediaTypeHeaderValue("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
            result.Content.Headers.ContentDisposition = new ContentDispositionHeaderValue("attachment")
            {
                FileName = fileName
            };
            return result;
        }
    }
}
