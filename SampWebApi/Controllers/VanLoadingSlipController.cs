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
    public class VanLoadingSlipController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/vanloadslip/getdata")]
        public IHttpActionResult InitialData()
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetVanLoadSlipData", 1);
                return Ok(DDT);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("DailyActivity", "vanloadslip/getdata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/vanloadslip/filterdata")]
        public IHttpActionResult GetFilterData(string Branch, string Salesman, string FromDate, string ToDate, string Showall)
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetVanLoadSlipData", 2, Branch, Salesman, FromDate, ToDate, Showall);
                return Ok(DDT);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("VanLoadingSlip", "vanloadslip/filterdata", ex.Message);
            }
            return Ok();
        }
    }
}
