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
        public IHttpActionResult GetData(string Mode)
        {
            try
            {
                DataSet DDT = bl.BL_ExecuteParamSPDataset("uspGetSaveCustomerStock", Mode);
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
    }
}
