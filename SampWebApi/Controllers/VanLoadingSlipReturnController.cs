using Newtonsoft.Json;
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

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class VanLoadingSlipReturnController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/vlsreturn/initialdata")]
        public IHttpActionResult GetData()
        {
            try
            {
                DataSet DDT = new DataSet();
                DDT = bl.BL_ExecuteParamSPDataset("uspgetReturnVLSData", 1);
                return Ok(DDT);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("VanLoadingSlipReturn", "vlsreturn/initialdata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/vlsreturn/products")]
        public IHttpActionResult GetData(string BranchID, string SalesmanID, string BatchType)
        {
            try
            {
                DataSet DDT = new DataSet();
                DDT = bl.BL_ExecuteParamSPDataset("uspgetReturnVLSData", 2, SalesmanID, BranchID, BatchType);
                return Ok(DDT);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("VanLoadingSlipReturn", "vlsreturn/initialdata", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/vlsreturn/save")]
        public IHttpActionResult Save(ReturnVLS listTrans)
        {
            List<SaveMessage> list = new List<SaveMessage>();
            try
            {
                if (listTrans != null)
                {
                    DataTable dtItemDetails = new DataTable();
                    DataColumn column = new DataColumn("Index");
                    column.DataType = System.Type.GetType("System.Int32");
                    column.AutoIncrement = true;
                    column.AutoIncrementSeed = 1;
                    column.AutoIncrementStep = 1;
                    dtItemDetails.Columns.Add(column);
                    dtItemDetails.Columns.Add("IdentID", typeof(int));
                    dtItemDetails.Columns.Add("ProdID", typeof(int));
                    dtItemDetails.Columns.Add("AvailableQty", typeof(decimal));
                    dtItemDetails.Columns.Add("AdjustQty", typeof(decimal));
                    dtItemDetails.Columns.Add("UOMPrice", typeof(decimal));
                    dtItemDetails.Columns.Add("MRP", typeof(decimal));

                    dtItemDetails.Columns.Add("UOMCR", typeof(decimal));
                    dtItemDetails.Columns.Add("TaxPern", typeof(decimal));
                    dtItemDetails.Columns.Add("TaxID", typeof(decimal));
                    dtItemDetails.Columns.Add("UOMID", typeof(decimal));
                    dtItemDetails.Columns.Add("BaseUOMPrice", typeof(decimal));
                    int nSerial = 1;
                    foreach (ReturnItems item in listTrans.lstProducts)
                    {
                        DataRow dr = dtItemDetails.NewRow();
                        dr["ProdID"] = item.ProdID;
                        dr["AvailableQty"] = item.ReturnQty;
                        dr["UOMPrice"] = item.Price;
                        dr["MRP"] = item.MRP;
                        dtItemDetails.Rows.Add(dr);
                        nSerial++;
                    }

                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspManageVanloadingSlipReturn",
                        bl.BL_nValidation(listTrans.BranchID),
                        bl.BL_nValidation(listTrans.SalesmanID),
                        bl.BL_nValidation(listTrans.VLSPriceMode),
                        listTrans.UserID,
                        dtItemDetails);

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
                        //int nBillScopeID = bl.BL_nValidation(dtResult.Rows[0][0]);
                        bl.bl_Transaction(2);
                        //bl.BL_UpdateclosingDateforPosting(24, nBillScopeID, Convert.ToDateTime(listTrans.DocDate));
                        list.Add(new SaveMessage()
                        {
                            ID = "0",//nBillScopeID.ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                        return Ok(list);
                    }
                }
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("VanLoadingSlipReturn", "vlsreturn/save", ex.Message);
            }
            return Ok();
        }
    }
}
