using DocumentFormat.OpenXml.Office2010.ExcelAc;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.ComponentModel;
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
    public class PurchaseOrderController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/purchaseorder/get")]
        public IHttpActionResult GetData(string Mode, string CodeName, string ID = null)
        {
            DataTable DDT = new DataTable();
            if (Mode == "1"|| Mode == "5")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseOrderData", Mode,3, CodeName);
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
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseOrderData", Mode, 3, CodeName);
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
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseOrderData", Mode,3, CodeName);
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
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseOrderData", Mode, 3, CodeName);
                List<ProductModel> list = new List<ProductModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {

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
                        LocationID = DDT.Rows[i]["LocationID"].ToString(),
                        MOH = DDT.Rows[i]["MOH"].ToString(),
                        MOQ = DDT.Rows[i]["MOQ"].ToString(),
                        Remarks = DDT.Rows[i]["Remarks"].ToString(),
                        Active = DDT.Rows[i]["Active"].ToString(),
                        ABSQty = DDT.Rows[i]["ABSQty"].ToString(),
                        TaxName = DDT.Rows[i]["TaxName"].ToString(),
                        GSTPern = DDT.Rows[i]["GST"].ToString(),
                        IGSTPern = DDT.Rows[i]["IGST"].ToString(),
                        BaseUOMName = DDT.Rows[i]["BaseUOMName"].ToString(),
                        PurchaseUomName = DDT.Rows[i]["PurchaseUOMName"].ToString(),
                    });
                }
                return Ok(list);
            }
            if (Mode == "6" || Mode == "9" || Mode == "13")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseOrderData", Mode, CodeName);
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
            if (Mode == "7" || Mode == "10" || Mode == "14")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseOrderData", Mode, 3, null, CodeName);
                List<PurchaseModel> list = new List<PurchaseModel>();
                if (DDT.Rows.Count > 0)
                {
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        DataTable DDT1 = bl.BL_ExecuteParamSP("uspGetSetPurchaseOrderData", 31, 3, DDT.Rows[i][6].ToString());
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
                        DataTable DDT2 = bl.BL_ExecuteParamSP("uspGetSetPurchaseOrderData", Mode == "7" ? 8 : Mode == "10" ? 11 : 15, 3, null, CodeName);
                        for (int k = 0; k < DDT2.Rows.Count; k++)
                        {
                            listProductGrid.Add(new PurchaseGridData
                            {
                                
                                ProdID = DDT2.Rows[k]["ProdID"].ToString(),
                                UomID = DDT2.Rows[k]["UomID"].ToString(),
                                UomName = DDT2.Rows[k]["UomName"].ToString(),
                                TaxID = DDT2.Rows[k]["TaxID"].ToString(),
                                Code = DDT2.Rows[k]["Code"].ToString(),
                                Name = DDT2.Rows[k]["Name"].ToString(),
                                Qty = DDT2.Rows[k]["Qty"].ToString(),
                                ExclPrice = DDT2.Rows[k]["Excl"].ToString(),
                                InclPrice = DDT2.Rows[k]["Incl"].ToString(),
                                TaxPern = DDT2.Rows[k]["TaxPern"].ToString(),
                                GrossAmt = DDT2.Rows[k]["GrossAmt"].ToString(),
                                TaxAmt = DDT2.Rows[k]["TaxAmt"].ToString(),
                                TaxName = DDT2.Rows[k]["TaxName"].ToString(),
                                NetAmt = DDT2.Rows[k]["NetAmt"].ToString(),
                                UOM = DDT2.Rows[k]["UomCR"].ToString(),

                            });
                        }
                        list.Add(new PurchaseModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            DocID = DDT.Rows[i]["DocID"].ToString(),
                            Date = Convert.ToDateTime(DDT.Rows[i]["Date"].ToString()).ToString("yyyy-MM-dd"),
                            RefNo = DDT.Rows[i]["RefNo"].ToString(),
                            BranchID = DDT.Rows[i]["BranchID"].ToString(),
                            VendorID = DDT.Rows[i]["VendorID"].ToString(),
                            UOMType = DDT.Rows[i]["UOMType"].ToString(),
                            //VendorName = DDT.Rows[i]["Name"].ToString(),
                            GrossAmt = DDT.Rows[i]["GrossAmt"].ToString(),
                            TaxAmt = DDT.Rows[i]["TaxAmt"].ToString(),
                            NetAmt = DDT.Rows[i]["NetAmt"].ToString(),
                            Status = DDT.Rows[i]["Status"].ToString(),
                            TaxTypeID = DDT.Rows[i]["TaxTypeID"].ToString(),
                            RoundOffAmt = DDT.Rows[i]["RoundOffAmt"].ToString(),    
                            UDFId = DDT.Rows[i]["UDFId"].ToString(),                          
                            Remarks = DDT.Rows[i]["Remarks"].ToString(),
                            Narration = DDT.Rows[i]["Narration"].ToString(),
                            lstPartyInfo = listParty,
                            lstProdGrid = listProductGrid,
                        });
                    }
                }
                return Ok(list);
            }
            if (Mode == "12")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseOrderData", Mode, 3, null, CodeName);
                return Ok("0");
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/purchaseorder/productqtybatch")]
        public IHttpActionResult GetFilterData(string ProdID, string BranchID)
        {
            DataTable dtProd = bl.BL_ExecuteParamSP("uspGetProductLastBatches", 2, BranchID, ProdID);
            List<ProdPreviousbatchqty> listProd = new List<ProdPreviousbatchqty>();
            for (int i = 0; i < dtProd.Rows.Count; i++)
            {
                listProd.Add(new ProdPreviousbatchqty
                {
                    TransDate = dtProd.Rows[i]["TransDate"].ToString(),
                    PurchaseQty = dtProd.Rows[i]["PurchaseQty"].ToString(),
                    SaleQty = dtProd.Rows[i]["SaleQty"].ToString(),
                    PurchasePrice = dtProd.Rows[i]["PurchasePrice"].ToString(),
                });
            }
            string srqty = "0",drQty = "0";
            if (dtProd.Rows.Count > 0)
            {
                DataTable dtSR = bl.BL_ExecuteParamSP("uspGetProductLastBatches", 3, BranchID, ProdID,
                    dtProd.Rows[dtProd.Rows.Count - 1]["TDate"].ToString());
                if (dtSR.Rows.Count > 0)
                {
                    srqty = dtSR.Rows[0][0].ToString();
                    drQty = dtSR.Rows[0][1].ToString();
                }
            }
            DataTable dtUOM = bl.BL_ExecuteParamSP("uspGetProductLastBatches", 4, 0, ProdID);
            List<clsPurchaseUOM> ulist = new List<clsPurchaseUOM>();
            for (int j = 0; j < dtUOM.Rows.Count; j++)
            {
                ulist.Add(new clsPurchaseUOM
                {
                    ID = (j + 1).ToString(),
                    Name = dtUOM.Rows[j][0].ToString(),
                    ConvRate = dtUOM.Rows[j][1].ToString()
                });
            }
            DataTable DDT = bl.BL_ExecuteParamSP("uspGetProductLastBatches", 1, BranchID, ProdID);
                
                List<ProductModel> list = new List<ProductModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new ProductModel
                    {
                        ID = DDT.Rows[i]["ProdID"].ToString(),
                        Code = DDT.Rows[i]["Code"].ToString(),
                        Name = DDT.Rows[i]["Name"].ToString(),
                        MOH = DDT.Rows[i]["MOH"].ToString(),
                        MOQ = DDT.Rows[i]["MOQ"].ToString(),
                        PurchasePrice = DDT.Rows[i]["PurchasePrice"].ToString(),
                        ABSQty = DDT.Rows[i]["ABSQty"].ToString(),
                        ABSValue = DDT.Rows[i]["ABSValue"].ToString(),
                        lstProdQtyBatch = listProd,
                        SalesReturnPrice = srqty,
                        DamageReturnPrice = drQty,
                        UOMList = ulist
                    });
                }
                return Ok(list);
            
        }
        [HttpGet]
        [Route("api/purchaseorder/getfilterdata")]
        public IHttpActionResult GetFilterData(string TransID, string FType, string Branch, string Party, string FromDate, string ToDate, string Showall)
        {
            //if (Mode == "6" || Mode == "9")
            {
                string Mode = FType == "1" ? "6" : FType == "2" ? "9" : "13";
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetPurchaseOrderData", Mode, TransID, FType, Branch, Party, FromDate, ToDate, Showall);
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
        [HttpPost]
        [Route("api/purchaseorder/save")]
        public IHttpActionResult Save(PurchaseModel listTrans)
        {
            if (listTrans != null)
            {
                DataTable dtProd = new DataTable();
                if (dtProd.Columns.Count == 0) 
                {
                    dtProd.Columns.Add("ProdId", typeof(int));
                    dtProd.Columns.Add("UomId", typeof(int));
                    dtProd.Columns.Add("Qty", typeof(decimal));
                    dtProd.Columns.Add("PurchasePrice", typeof(decimal));
                    dtProd.Columns.Add("TaxID", typeof(int));
                    dtProd.Columns.Add("TaxPercentage", typeof(decimal));
                    dtProd.Columns.Add("GrossAmt", typeof(decimal)).DefaultValue = 0;
                    dtProd.Columns.Add("TaxAmt", typeof(decimal));
                    dtProd.Columns.Add("NetAmt", typeof(decimal));
                    dtProd.Columns.Add("InventoryId", typeof(int));
                    dtProd.Columns.Add("Serial", typeof(int));
                    dtProd.Columns.Add("UomCR", typeof(decimal));
                }
                DataTable dtProducts = ToDataTable(listTrans.lstProdGrid);
                List<SaveMessage> list = new List<SaveMessage>();
                if (listTrans.TransMode != "4")
                {                    
                    for (int i = 0; i < dtProducts.Rows.Count; i++)
                    {
                        int nProdID = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["ProdID"]));
                        if (nProdID > 0)
                        {
                            DataRow dtRow = dtProd.NewRow();
                            dtRow[0] = nProdID;
                            dtRow[1] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["UomID"]));
                            dtRow[2] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["Qty"]));
                            dtRow[3] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["ExclPrice"]));
                            dtRow[4] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["TaxID"]));
                            dtRow[5] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["TaxPern"]));
                            dtRow[6] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["GrossAmt"]));
                            dtRow[7] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["TaxAmt"]));
                            dtRow[8] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["NetAmt"]));
                            dtRow[9] = bl.BL_dValidation(0);
                            dtRow[10] = (i + 1);
                            dtRow[11] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["UOM"]));
                            dtProd.Rows.Add(dtRow);
                        }
                    }
                    if (listTrans.IsDraft == "0")
                    {
                        bl.bl_Transaction(1);
                        try
                        {
                            DataTable dtResult = bl.bl_ManageTrans("uspManagePurchaseOrder", dtProd, listTrans.TransMode, bl.BL_nValidation(listTrans.ID), bl.BL_nValidation(listTrans.BranchID), bl.BL_nValidation(listTrans.CurrentStatus),
                                listTrans.Date, listTrans.VendorID, listTrans.RefNo, 1, bl.BL_dValidation(listTrans.RoundOffAmt), bl.BL_dValidation(listTrans.GrossAmt), bl.BL_dValidation(listTrans.TaxAmt),
                                bl.BL_dValidation(listTrans.NetAmt), bl.BL_nValidation(listTrans.UDFId), listTrans.Remarks, listTrans.Narration,
                                listTrans.CBy, bl.BL_nValidation(listTrans.DraftID), bl.BL_nValidation(listTrans.UOMType));
                            if (dtResult.Columns.Count > 1)
                            {
                                bl.bl_Transaction(3);
                                string[] strErrorList = dtResult.Rows[0][0].ToString().Split('$');
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
                        catch (Exception ex)
                        {
                            bl.bl_Transaction(3);
                        }
                    }
                    else //  Draft
                    {
                        bl.bl_Transaction(1);
                        DataTable dtResult = bl.bl_ManageTrans("uspManagePurchaseOrderDraft", dtProd, listTrans.TransMode, bl.BL_nValidation(listTrans.ID), bl.BL_nValidation(listTrans.BranchID), bl.BL_nValidation(listTrans.CurrentStatus),
                            listTrans.Date, listTrans.VendorID, listTrans.RefNo, 1, bl.BL_dValidation(listTrans.RoundOffAmt), bl.BL_dValidation(listTrans.GrossAmt), bl.BL_dValidation(listTrans.TaxAmt),
                            bl.BL_dValidation(listTrans.NetAmt), bl.BL_nValidation(listTrans.UDFId), listTrans.Remarks, listTrans.Narration,
                            listTrans.CBy, bl.BL_nValidation(listTrans.DraftID));
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
                    DataTable dtResult = bl.bl_ManageTrans("uspManagePurchaseCancel", 4, listTrans.ID, listTrans.CBy, listTrans.CurrentStatus, listTrans.Remarks, listTrans.Narration);
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
