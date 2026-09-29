using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Linq.Expressions;
using System.Net;
using System.Net.Http;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Web.Http;
using System.Web.Http.Cors;

namespace SampWebApi.Controllers
{
    public class ColumnConfigController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/columnconfig/get")]
        public IHttpActionResult GetData(int Mode, int? FormOrReport = null, int? FormID = null, int? TableID = null)
        {
            try
            {
                DataTable dt = bl.BL_ExecuteParamSP("uspGetColumnConfiguration",
                                    Mode,
                                    (object)FormOrReport ?? DBNull.Value,
                                    (object)FormID ?? DBNull.Value,
                                    (object)TableID ?? DBNull.Value);

                return Ok(JsonConvert.SerializeObject(dt));
            }
            catch (Exception ex)
            {
                return InternalServerError(ex);
            }
        }
    }
}
