using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
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
    public class BulkCollectionController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/bulkcollection/filterdata")]
        public IHttpActionResult Getfilterdata(string Mode)
        {
            try
            {
                DataSet DDT = bl.BL_ExecuteParamSPDataset("uspgetsetBulkCollection", Mode);
                return Ok(DDT);               
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("BulkCollection", "Getfilterdata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/bulkcollection/documentdata")]
        public IHttpActionResult documentdata(string Branch,string Beat,string Salesman,string Party,string AsonDate)
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspBulkCollectionData", Branch, Beat, Salesman, Party, AsonDate);
                return Ok(DDT);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("BulkCollection", "documentdata", ex.Message);
            }
            return Ok();
        }
    }
}
