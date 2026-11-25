using DocumentFormat.OpenXml.Office.CustomUI;
using DocumentFormat.OpenXml.Office2010.Excel;
using DocumentFormat.OpenXml.Spreadsheet;
using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
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
    public class CustomerStockRequestController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        DataTable dtPMDetail = new DataTable(), dtPopUpDetail = new DataTable(), dtProd = new DataTable(), dtGSTInfo = new DataTable();
        [HttpGet]
        [Route("api/customerstockrequest/get")]
        public IHttpActionResult GetData(string Mode, string Date = null, string ShowAll = "0")
        {
            try
            {
                DataSet DDT = Mode == "2"
                    ? bl.BL_ExecuteParamSPDataset("uspGetSaveCustomerStock", Mode, Date, ShowAll)
                    : bl.BL_ExecuteParamSPDataset("uspGetSaveCustomerStock", Mode);
                if (DDT.Tables.Count > 0)
                {
                    return Ok(DDT);
                }
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CustomerStockRequest", "customerstockrequest/get", ex.Message);
            }
            return Ok();
        }

        [HttpPost]
        [Route("api/customerstockrequest/save")]
        public IHttpActionResult SaveData(List<CustomerStockRequestModel> listTrans)
        {
            try
            {
                if (listTrans != null && listTrans.Count > 0)
                {
                    List<SaveMessage> list = new List<SaveMessage>();
                    bl.bl_Transaction(1);
                    foreach (CustomerStockRequestModel item in listTrans)
                    {
                        DataTable dtResult = bl.bl_ManageTrans("uspSaveCustomerStock", bl.BL_nValidation(item.ID), item.Date,
                            bl.BL_nValidation(item.ProdID), bl.BL_nValidation(item.CustID), bl.BL_dValidation(item.Qty),
                            bl.BL_dValidation(item.Price), bl.BL_nValidation(item.UomID), item.MobileNo,
                            bl.BL_nValidation(item.CBy), bl.BL_nValidation(item.Status), item.ExpectedDate);
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
                    }
                    bl.bl_Transaction(2);
                    list.Add(new SaveMessage()
                    {
                        ID = "0",
                        MsgID = "0",
                        Message = "Saved Successfully"
                    });
                    return Ok(list);
                }
                return Ok(0);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CustomerStockRequest", "customerstockrequest/save", ex.Message);
            }
            return Ok("No data found");
        }
    }
}
