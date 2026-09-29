using DocumentFormat.OpenXml.Drawing.Spreadsheet;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web;
using System.Web.Http;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class BarcoderPrintController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/barcodeprint/filterdata")]
        public IHttpActionResult GetFilterData(string Branch, string FromDate, string ToDate, string Showall)
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetBarcodeprint", 1, Branch, 25, FromDate, ToDate, Showall);
                return Ok(DDT);

            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("BarcoderPrint", "barcodeprint/filterdata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/barcodeprint/Productdata")]
        public IHttpActionResult GetProductdata(string ProdID,string BranchID,string Date,string QtyBatchOnly)
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetBarcodeprint", 2, ProdID);
                int ProdPriceID = DDT.Rows.Count > 0 ? bl.BL_nValidation(DDT.Rows[0]["BarcodePriceId"]) : 0;
                DataTable DDTbatch = bl.BL_ExecuteParamSP("uspGetSetBarcodeprint", 3, ProdID, BranchID, Date, null,
                    QtyBatchOnly, ProdPriceID);
                DataSet ds = new DataSet();
                ds.Tables.Add(DDT);
                ds.Tables[0].TableName = "ProductData";
                ds.Tables.Add(DDTbatch);
                ds.Tables[1].TableName = "BatchData";
                return Ok(ds);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("BarcoderPrint", "barcodeprint/Productdata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/barcodeprint/bpdocumentdata")]
        public IHttpActionResult getdocumentdata(string ID,string Status)
        {
            try
            {
                DataSet ds = bl.BL_ExecuteParamSPDataset("uspGetSetBarcodeprint", 4, ID);             
                ds.Tables[0].TableName = "HeaderData";
                ds.Tables[1].TableName = "ProductData";
                return Ok(ds);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("BarcoderPrint", "barcodeprint/bpdocumentdata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/barcodeprint/productbatch")]
        public IHttpActionResult Getproductbatch(string BranchID, string PriceID, string Date, string ProductID,string QtyBatchOnly)
        {
            try
            {
                DataTable DDTbatch = bl.BL_ExecuteParamSP("uspGetSetBarcodeprint", 3, ProductID, BranchID, Date, null,
                   QtyBatchOnly, PriceID);
                return Ok(DDTbatch);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("barcodeprint", "barcodeprint/productdetails", ex.Message);
            }
            return Ok();
        }       
        [HttpPost]
        [Route("api/barcodeprint/save")]
        public IHttpActionResult Save(SalesModel listTrans)
        {
            try
            {
                if (listTrans != null)
                {
                    DataTable dtProd = new DataTable();
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
                                dtRow["GoodsAmt"] = 0;
                                dtRow["UserDisc"] = 0;
                                dtRow["UserDiscAmt"] = 0;
                                dtRow["ProdDisc"] = 0;
                                dtRow["ProdDiscAmt"] = 0;
                                dtRow["TradeDisc"] = 0;
                                dtRow["TradeDiscPern"] = 0;
                                dtRow["AddnlDisc"] = 0;
                                dtRow["AddnlDiscPern"] = 0;
                                dtRow["GrossAmt"] =0;
                                dtRow["TaxId"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["TaxID"])); ;
                                dtRow["TaxPercentage"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["TaxPern"]));
                                dtRow["TaxAmt"] = 0;
                                dtRow["NetAmt"] =0;
                                dtRow["ReasonId"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["ReasonId"]));
                                dtRow["Serial"] = nSerial;
                                dtRow["BatchNumber"] = Convert.ToString(dtProducts.Rows[i]["BatchNo"]);
                                dtRow["PkgDate"] = Convert.ToString(dtProducts.Rows[i]["PKD"]);
                                dtRow["ExpiryDate"] = Convert.ToString(dtProducts.Rows[i]["Expiry"]);
                                dtRow["InvoicePrice"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["OrgPrice"]));
                                dtRow["MRP"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["MRP"]));
                                dtRow["UomCR"] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["ConvFact"]));
                                dtRow["InvQtyType"] =0;
                                dtRow["TempBatchInvId"] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["InventoryId"]));
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

                            DataTable dtResult = bl.bl_ManageTrans("uspSaveBarcodePrinting", bl.BL_nValidation(listTrans.TransMode), bl.BL_nValidation(listTrans.TransID),
                                InvoiceIdentID, listTrans.BranchID, listTrans.DocDate,  listTrans.RefNo, listTrans.Remarks, listTrans.Narration,
                                 listTrans.UserID, dtProd);

                            if (dtResult.Columns.Count > 1)
                            {
                                bl.bl_Transaction(3);
                                string RowID = dtResult.Columns.Count == 4 ? dtResult.Rows[0][3].ToString() : "-1";
                                string msg = dtResult.Rows[0][0].ToString();
                                list.Add(new SaveMessage()
                                {
                                    ID = RowID,
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
                                bl.BL_UpdateclosingDateforPosting(25, nBillScopeID, Convert.ToDateTime(listTrans.DocDate));
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
                        bl.bl_Transaction(1);
                        DataTable dtResult = bl.bl_ManageTrans("uspManageVanloadingSlipCancel", listTrans.ID, listTrans.CurrentStatus, listTrans.UserID, listTrans.Remarks, listTrans.Narration);
                        if (dtResult.Columns.Count > 1)
                        {
                            string ErrorMsg = dtResult.Rows[0][0].ToString();
                            string ErrorProdIds = dtResult.Rows[0][3].ToString();
                            bl.bl_Transaction(3);
                            list.Add(new SaveMessage()
                            {
                                ID = ErrorProdIds,
                                MsgID = "1",
                                Message = ErrorMsg
                            });
                            return Ok(list);
                        }
                        else
                        {
                            bl.bl_Transaction(2);
                            bl.BL_UpdateclosingDateforPosting(24, bl.BL_nValidation(listTrans.ID), Convert.ToDateTime(listTrans.DocDate));

                            list.Add(new SaveMessage()
                            {
                                ID = 0.ToString(),
                                MsgID = "0",
                                Message = "Cancelled Successfully"
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
