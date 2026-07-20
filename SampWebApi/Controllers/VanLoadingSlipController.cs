using DocumentFormat.OpenXml.Office2010.Excel;
using Org.BouncyCastle.Utilities;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using static System.Windows.Forms.VisualStyles.VisualStyleElement.TreeView;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class VanLoadingSlipController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/vanloadslip/getdata")]
        public IHttpActionResult InitialData()
        {
            try
            {
                DataSet DDT = bl.BL_ExecuteParamSPDataset("uspGetSetVanLoadSlipData", 1);
                return Ok(DDT);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("VanLoadingSlip", "vanloadslip/getdata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/vanloadslip/filterdata")]
        public IHttpActionResult GetFilterData(string Branch, string Salesman, string FromDate, string ToDate, string Showall)
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetVanLoadSlipData", 2, Branch, bl.BL_nValidation(Salesman), FromDate, ToDate, Showall);
                return Ok(DDT);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("VanLoadingSlip", "vanloadslip/filterdata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/vanloadslip/vlsdocumentdata")]
        public IHttpActionResult VLSDocumentData(string ID,string Status)
        {
            try
            {
                DataSet DDT = bl.BL_ExecuteParamSPDataset("uspGetSetVanLoadSlipData", 3, ID);
                return Ok(DDT);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("VanLoadingSlip", "vanloadslip/vlsdocumentdata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/vanloadslip/productdetails")]
        public IHttpActionResult Getproductdetails(string BranchID, string PriceID, string Date, string Product)
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetInvoiceData", 4, Product);
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
                    list.Add(new InvoiceBatchInfo
                    {
                        ProdID = DDT.Rows[i]["ID"].ToString(),
                        Code = DDT.Rows[i]["Code"].ToString(),
                        Name = DDT.Rows[i]["Name"].ToString(),
                        HSNCode = DDT.Rows[i]["HSNCode"].ToString(),
                        Shinecode = DDT.Rows[i]["Shinecode"].ToString(),
                        ProductDiscPerc = DDT.Rows[i]["ProductDiscPerc"].ToString(),                        
                        TradeDiscPerc = "0",
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
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("VanLoadingSlip", "vanloadslip/productdetails", ex.Message);
            }
            return Ok();
        }

        [HttpGet]
        [Route("api/vanloadslip/productbatch")]
        public IHttpActionResult Getproductbatch(string BranchID, string PriceID, string Date, string Product)
        {
            try
            {
                List<InvoiceBatchPopup> ulistBatch = new List<InvoiceBatchPopup>();
                string PKD = "False", BATCH = "False", TrkInv = "True";
                DataTable dtProdinfo = bl.BL_ExecuteSqlQuery("select TrackBatch,TrackPDK,TrackInventory from tblMasterProduct WHERE ID = " + Product);
                if (dtProdinfo.Rows.Count > 0)
                {
                    PKD = dtProdinfo.Rows[0]["TrackPDK"].ToString();
                    BATCH = dtProdinfo.Rows[0]["TrackBatch"].ToString();
                    TrkInv = dtProdinfo.Rows[0]["TrackInventory"].ToString();
                }
                DataTable dtBatch = bl.BL_ExecuteParamSP("uspGetProdInventory", 1, BranchID, PriceID, Convert.ToDateTime(Date), Product, 0);
                if (dtBatch.Rows.Count > 0)
                {
                    for (int j = 0; j < dtBatch.Rows.Count; j++)
                    {
                        ulistBatch.Add(new InvoiceBatchPopup
                        {
                            QtyType = dtBatch.Rows[j]["QtyType"].ToString(),
                            QtyTag = dtBatch.Rows[j]["Tag"].ToString(),
                            ProdID = Product,
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
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("VanLoadingSlip", "vanloadslip/productdetails", ex.Message);
            }
            return Ok();
        }
        DataTable dtProd = new DataTable();
        [HttpPost]
        [Route("api/vanloadslip/save")]
        public IHttpActionResult Save(SalesModel listTrans)
        {
            try
            {
                if (listTrans != null)
                {
                    if (dtProd.Columns.Count == 0)
                    {
                        dtProd.Columns.Add("ProdId", typeof(int));
                        dtProd.Columns.Add("InvoiceYesNo", typeof(int));
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
                        dtProd.Columns.Add("InvoicePrice", typeof(decimal));
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
                    


                    DataTable dtBatch = new DataTable();// ToDataTable(listTrans.lstBatchInfo);
                    DataTable dtPaymodeDetails = new DataTable();
                    DataTable dtProducts = bl.ConvertListToDataTable(listTrans.lstProdInfo);
                    
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
                                dtRow["InvoiceYesNo"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["InvYN"]));
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
                                dtRow["ProdDisc"] = 0;
                                dtRow["ProdDiscAmt"] = 0;
                                dtRow["TradeDisc"] = 0;
                                dtRow["TradeDiscPern"] = 0;
                                dtRow["AddnlDisc"] = 0;
                                dtRow["AddnlDiscPern"] = 0;
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
                                dtRow["InvoicePrice"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["OrgPrice"]));
                                dtRow["MRP"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["MRP"]));
                                dtRow["UomCR"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["ConvFact"]));
                                dtRow["InvQtyType"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["QtyType"]));
                                dtRow["TempBatchInvId"] = 0;
                                dtRow["DiffAmt"] = 0;
                                dtProd.Rows.Add(dtRow);
                                nSerial++;
                            }
                        }
                        nSerial = 1;
                        int InvoiceIdentID = bl.BL_nValidation(listTrans.ID);
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
                                    else
                                    {
                                        ErrorMsg = dtCheck.Rows[0][0].ToString();
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

                            DataTable dtResult = bl.bl_ManageTrans("uspManageVanloadingSlip", bl.BL_nValidation(listTrans.TransMode), bl.BL_nValidation(listTrans.TransID),
                                InvoiceIdentID, listTrans.DocDate, listTrans.BranchID, listTrans.SalesmanID, listTrans.RefNo, listTrans.PriceID,
                                 bl.BL_dValidation(listTrans.GrossAmt), bl.BL_dValidation(listTrans.TaxAmt), bl.BL_dValidation(listTrans.RoundOffAmt),
                                 bl.BL_dValidation(listTrans.NetAmt), bl.BL_nValidation(listTrans.CurrentStatus), listTrans.Remarks, listTrans.Narration,
                                 listTrans.UserID, dtProd, listTrans.VehicleNo, listTrans.Distance, listTrans.TransportType,
                                     listTrans.TransportMode, listTrans.TransactionID, listTrans.TransactionName);

                            if (dtResult.Columns.Count > 1)
                            {
                                bl.bl_Transaction(3);
                                string RowID = "-1";
                                string msg = dtResult.Rows[0][0].ToString();
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
                                bl.bl_Transaction(2);
                                bl.BL_UpdateclosingDateforPosting(24, nBillScopeID, Convert.ToDateTime(listTrans.DocDate));
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
                    else// for cancel
                    {
                        string Shinecode = bl.BL_ShineCode(1, bl.BL_nValidation(listTrans.CustomerID));
                        if (!string.IsNullOrEmpty(Shinecode))
                        {
                            bl.bl_Transaction_SC(1);
                            DataTable dtSCcheck = bl.bl_ManageTrans_SC("uspgetMasterdata", 2, 15, listTrans.ID, Shinecode);
                            if (dtSCcheck.Rows.Count == 0)
                            {
                                bl.bl_Transaction_SC(2);
                            }
                            else
                            {
                                bl.bl_Transaction_SC(3);
                                list.Add(new SaveMessage()
                                {
                                    ID = 1.ToString(),
                                    MsgID = "1",
                                    Message = "Invoice transfer document status changed(Status :&ensp; <h4><code>" + dtSCcheck.Rows[0][0] + "</code></h4>)"
                                });
                                return Ok(list);
                            }
                        }
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
                            if (nCheck == 1)
                            {
                                ErrorMsg = "Document Status Already Changed";
                            }
                            else
                            {
                                ErrorMsg = dtResult.Rows[0][0].ToString();
                            }
                            bl.bl_Transaction(3);
                            list.Add(new SaveMessage()
                            {
                                ID = 1.ToString(),
                                MsgID = "1",
                                Message = "Cancel : " + ErrorMsg
                            });
                            return Ok(list);
                        }
                        else
                        {
                            bl.bl_Transaction(2);
                            bl.BL_UpdateclosingDateforPosting(15, bl.BL_nValidation(listTrans.ID), Convert.ToDateTime(listTrans.DocDate));
                            //change to cancel status
                            if (!string.IsNullOrEmpty(Shinecode))
                            {
                                bl.bl_Transaction_SC(1);
                                DataTable dtSCcheck = bl.bl_ManageTrans_SC("uspgetMasterdata", 3, 15, listTrans.ID, Shinecode);
                                bl.bl_Transaction_SC(2);
                            }
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
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Invoice", "invoice/save", ex.Message);
            }
            return Ok("No data found");
        }
    }
}
