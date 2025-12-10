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
using System.Web.Http;
using System.Web.Http.Cors;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class QuotationController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        DataTable dtPMDetail = new DataTable(), dtPopUpDetail = new DataTable(), dtProd = new DataTable(), dtGSTInfo = new DataTable();
        [HttpGet]
        [Route("api/quotation/get")]
        public IHttpActionResult GetData(string Mode, string CodeName, string ID = null, string PriceID = "2",string Date = null)
        {
            DataTable DDT = new DataTable();
            if (Mode == "1")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetQuotationData", Mode, 0);
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
                DDT = bl.BL_ExecuteParamSP("uspGetSetQuotationData", Mode, CodeName, PriceID, null, null, Convert.ToDateTime(Date));
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
                    });
                }
                return Ok(list);
            }
            if (Mode == "3")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetQuotationData", Mode, CodeName);
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
                        PriceTypeID = DDT.Rows[i]["PriceTypeID"].ToString(),
                        TaxTypeID = DDT.Rows[i]["TaxTypeID"].ToString(),
                        FAID = DDT.Rows[i]["FAID"].ToString(),
                        Active = DDT.Rows[i]["Active"].ToString(),
                        Ratings = DDT.Rows[i]["Rating"].ToString(),
                    });
                }
                return Ok(list);
            }
            if (Mode == "4")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetQuotationData", Mode, CodeName);
                List<ProductModel> list = new List<ProductModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    DataTable dtUOM = bl.BL_ExecuteParamSP("uspGetSetQuotationData", 5, "", DDT.Rows[i][0].ToString());
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
                    decimal dConvFact = bl.BL_dValidation(DDT.Rows[i]["SalesCR"].ToString());
                    decimal ApplyPrice = bl.BL_dValidation(PriceID == "1" ? DDT.Rows[i]["PurchasePrice"].ToString() : PriceID == "2" ? DDT.Rows[i]["SalesPrice"].ToString()
                        : PriceID == "3" ? DDT.Rows[i]["ECP"].ToString() : PriceID == "4" ? DDT.Rows[i]["MRP"].ToString()
                        : PriceID == "5" ? DDT.Rows[i]["SPLPrice"].ToString() : PriceID == "6" ? DDT.Rows[i]["ReturnPrice"].ToString() : "0") *dConvFact;
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
                        DSTradeDiscAmt = bl.BL_dValidation(dtDiscScheme.Rows[0][5])* dConvFact;
                        int ReplaceExists = bl.BL_nValidation(dtDiscScheme.Rows[0][1]);
                        if (bl.BL_dValidation(dtDiscScheme.Rows[0][0]) == 1)//apply scheme in qtn
                        {
                            decimal PDiscAmt = 0,dTradPernfromAmt = 0, dProdPernfromAmt = 0;
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
                                dTradPernfromAmt = bl.BL_dValidation((DSTradeDiscAmt / (ApplyPrice - PDiscAmt - DSProdDiscAmt)) * 100);
                            }
                            if (DSProdDiscAmt > 0)
                            {
                                dProdPernfromAmt = bl.BL_dValidation((DSProdDiscAmt / ApplyPrice) * 100);
                            }
                            if (ReplaceExists == 1)//Replay exists
                            {
                                OrgDiscPern = DSProdDiscPern;
                                OrgTradeDiscPern = DSTradeDiscPern + dTradPernfromAmt;
                            }
                            else
                            {
                                OrgDiscPern = dProdPernfromAmt+DSProdDiscPern + OldDiscPern;
                                OrgTradeDiscPern = DSTradeDiscPern + dTradPernfromAmt;
                            }
                        }
                    }
                    
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
                        ProductDiscPerc = OrgDiscPern.ToString(),
                        TradeDiscPerc = OrgTradeDiscPern.ToString(),
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
                        LocationID = DDT.Rows[i]["LocationID"].ToString(),
                        MOH = DDT.Rows[i]["MOH"].ToString(),
                        MOQ = DDT.Rows[i]["MOQ"].ToString(),
                        Remarks = DDT.Rows[i]["Remarks"].ToString(),
                        Active = DDT.Rows[i]["Active"].ToString(),
                        ABSQty = DDT.Rows[i]["ABSQty"].ToString(),
                        TaxName = DDT.Rows[i]["TaxName"].ToString(),
                        GSTPern = DDT.Rows[i]["GST"].ToString(),
                        IGSTPern = DDT.Rows[i]["IGST"].ToString(),
                        UOMList = ulist
                    });
                }
                return Ok(list);
            }
            if (Mode == "6" || Mode == "10")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetQuotationData", Mode, CodeName);
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

            if (Mode == "7" || Mode == "11" || Mode == "17")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetQuotationData", Mode, null, CodeName);
                List<SalesModel> list = new List<SalesModel>();
                if (DDT.Rows.Count > 0)
                {
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        DataTable DDT1 = bl.BL_ExecuteParamSP("uspGetSetQuotationData", 31, DDT.Rows[i][6].ToString());
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
                                Active = DDT1.Rows[j]["Active"].ToString(),
                                Ratings = DDT1.Rows[j]["Rating"].ToString(),
                            });
                        }

                        List<SalesDetail> listProductGrid = new List<SalesDetail>();
                        int TMode = Mode == "7" ? 8 : Mode == "11" ? 12 : 18;
                        DataTable DDT2 = bl.BL_ExecuteParamSP("uspGetSetQuotationData", TMode, null, CodeName);
                        for (int k = 0; k < DDT2.Rows.Count; k++)
                        {
                            DataTable dtUOM = bl.BL_ExecuteParamSP("uspGetSetQuotationData", 5, "", DDT2.Rows[k]["ProdID"].ToString());
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
                                UOMList= ulist
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
                            CustomerID = DDT.Rows[i]["CustomerID"].ToString(),
                            RefNo = DDT.Rows[i]["RefNo"].ToString(),
                            TaxTypeID = DDT.Rows[i]["TaxTypeID"].ToString(),
                            PriceID = DDT.Rows[i]["PriceID"].ToString(),
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
                            lstPartyInfo = listParty,
                            lstProdInfo = listProductGrid,
                        });
                    }
                }
                return Ok(list);
            }
            if (Mode == "14")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetQuotationData", Mode, CodeName, ID);
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
                    });
                }
                return Ok(list);
            }
            if (Mode == "15")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetQuotationData", Mode, null, CodeName);
                return Ok("0");
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/quotation/getfilterdata")]
        public IHttpActionResult GetFilterData(string TransID, string FType, string Branch, string Party, string FromDate, string ToDate, string Showall)
        {
            //if (Mode == "6" || Mode == "9")
            {
                string Mode = FType == "1" ? "6" : FType == "2" ? "10" : "16";
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetQuotationData", Mode, FType, Branch, TransID, Party, FromDate, ToDate, Showall);
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
                        CBy = DDT.Rows[i]["UserName"].ToString(),
                        CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                        CurrentStatus = DDT.Rows[i]["StatusID"].ToString(),
                    });
                }
                return Ok(list);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/quotation/getvariantdata")]
        public IHttpActionResult GetVariantQTNData(string VariantType, string DocID)
        {
            DataTable DDT = bl.BL_ExecuteParamSP("uspGetTransVariantQuotationdata", VariantType, 1, DocID);
            List<SalesModel> list = new List<SalesModel>();
            if (DDT.Rows.Count > 0)
            {
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    DataTable DDT1 = bl.BL_ExecuteParamSP("uspGetSetQuotationData", 31, DDT.Rows[i][6].ToString());
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
                            Active = DDT1.Rows[j]["Active"].ToString(),
                            Ratings = DDT1.Rows[j]["Rating"].ToString(),
                        });
                    }

                    List<SalesDetail> listProductGrid = new List<SalesDetail>();
                    DataTable DDT2 = bl.BL_ExecuteParamSP("uspGetTransVariantQuotationdata", VariantType, 2, DocID);
                    for (int k = 0; k < DDT2.Rows.Count; k++)
                    {
                        DataTable dtUOM = bl.BL_ExecuteParamSP("uspGetSetQuotationData", 5, "", DDT2.Rows[k]["ProdID"].ToString());
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
                            UOMList = ulist
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
                        CustomerID = DDT.Rows[i]["CustomerID"].ToString(),
                        RefNo = DDT.Rows[i]["RefNo"].ToString(),
                        TaxTypeID = DDT.Rows[i]["TaxTypeID"].ToString(),
                        PriceID = DDT.Rows[i]["PriceID"].ToString(),
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
                        lstPartyInfo = listParty,
                        lstProdInfo = listProductGrid,
                    });
                }
            }
            return Ok(list);
            return Ok();
        }
            [HttpPost]
        [Route("api/quotation/save")]
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
                    dtProd.Columns.Add("SecondarySchemeID", typeof(int));
                }
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
                DataTable dtBatch = new DataTable();// ToDataTable(listTrans.lstBatchInfo);
                DataTable dtProducts = ToDataTable(listTrans.lstProdInfo);
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
                            dtRow["InventoryYesNo"] = 0;
                            dtRow["BatchYesNo"] = 0;
                            dtRow["PKDYesNo"] = 0;
                            dtRow["SerialYesNo"] = 0;
                            dtRow["BaseUomPrice"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["SalePrice"]));
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
                            dtRow["BatchNumber"] = null;
                            dtRow["PkgDate"] = null;
                            dtRow["ExpiryDate"] = null;
                            dtRow["InventoryPrice"] = 0;
                            dtRow["MRP"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["MRP"]));
                            dtRow["UomCR"] = 0;
                            dtRow["InvQtyType"] = 1;
                            dtRow["TempBatchInvId"] = 0;
                            dtRow["SecondarySchemeID"] = 0;
                            dtProd.Rows.Add(dtRow);
                            nSerial++;
                        }
                    }
                    if (listTrans.IsDraft == "0")
                    {
                        bl.bl_Transaction(1);
                        try
                        {//
                            string nMode = listTrans.TransMode == "3" ? "1" : listTrans.TransMode;
                            DataTable dtResult = bl.bl_ManageTrans("uspManageQuatation",dtProd, nMode, bl.BL_nValidation(listTrans.ID),
                                    listTrans.DocDate, bl.BL_nValidation(listTrans.TransID), listTrans.BranchID, listTrans.CustomerID, listTrans.RefNo,
                                    bl.BL_nValidation(listTrans.PriceID), bl.BL_nValidation(listTrans.TaxTypeID), bl.BL_dValidation(listTrans.TradeDiscPern), bl.BL_dValidation(listTrans.TradeDiscAmt),
                                    bl.BL_dValidation(listTrans.AddnlDiscPern), bl.BL_dValidation(listTrans.AddnlDiscAmt), bl.BL_dValidation(listTrans.OtherChargePern),
                                    bl.BL_dValidation(listTrans.OtherChargeAmt), bl.BL_dValidation(listTrans.FrightAmt), bl.BL_dValidation(listTrans.TotalProdDiscAmt),
                                    bl.BL_dValidation(listTrans.TotalDiscAmt), bl.BL_dValidation(listTrans.GrossAmt), bl.BL_dValidation(listTrans.TaxAmt),
                                    bl.BL_dValidation(listTrans.NetAmt), bl.BL_dValidation(listTrans.RoundOffAmt), bl.BL_nValidation(listTrans.Status),
                                    bl.BL_nValidation(listTrans.UDFId), bl.BL_nValidation(listTrans.UserID), listTrans.Remarks, listTrans.Narration, bl.BL_nValidation(listTrans.DraftID), 
                                    bl.BL_nValidation(listTrans.CurrentStatus));
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
                                                dr["TransID"] = 14;
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
                                bl.bl_Transaction(2);
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
                        DataTable dtResult = bl.bl_ManageTrans("uspManageQuatationDraft", dtProd, bl.BL_nValidation(listTrans.ID),
                                   listTrans.DocDate, bl.BL_nValidation(listTrans.TransID), listTrans.BranchID, listTrans.CustomerID, listTrans.RefNo,
                                   bl.BL_nValidation(listTrans.PriceID), bl.BL_nValidation(listTrans.TaxTypeID), bl.BL_dValidation(listTrans.TradeDiscPern), bl.BL_dValidation(listTrans.TradeDiscAmt),
                                   bl.BL_dValidation(listTrans.AddnlDiscPern), bl.BL_dValidation(listTrans.AddnlDiscAmt), bl.BL_dValidation(listTrans.OtherChargePern),
                                   bl.BL_dValidation(listTrans.OtherChargeAmt), bl.BL_dValidation(listTrans.FrightAmt), bl.BL_dValidation(listTrans.TotalProdDiscAmt),
                                   bl.BL_dValidation(listTrans.TotalDiscAmt), bl.BL_dValidation(listTrans.GrossAmt), bl.BL_dValidation(listTrans.TaxAmt),
                                   bl.BL_dValidation(listTrans.NetAmt), bl.BL_dValidation(listTrans.RoundOffAmt), bl.BL_nValidation(listTrans.Status),
                                   bl.BL_nValidation(listTrans.UDFId), bl.BL_nValidation(listTrans.UserID), listTrans.Remarks, listTrans.Narration, bl.BL_nValidation(listTrans.DraftID),
                                   bl.BL_nValidation(listTrans.CurrentStatus));
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
                    DataTable dtResult = bl.bl_ManageTrans("uspCancelQuatation",listTrans.ID, listTrans.UserID, listTrans.CurrentStatus, listTrans.Remarks, listTrans.Narration);
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
