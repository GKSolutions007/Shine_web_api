using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace SampWebApi.Controllers
{
    public class MobileDeviceVerifyController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/mobiledeviceverify/verify")]
        public IHttpActionResult GetData(string Mode, string DeviceName, string DeviceID, string UID, string DBName, string Active, string Ident)
        {
            DataTable dt = bl.BL_ExecuteParamSP("uspVerifyMobileDeviceInfo", Mode, DeviceName, DeviceID, UID, DBName, Active, DateTime.Now, Ident);
            string JSONCONV = JsonConvert.SerializeObject(dt);
            return Ok(JSONCONV);
        }
        [HttpGet]
        [Route("api/mobiledevicelogin/loginverify")]
        public IHttpActionResult Getloginverify(string Mode, string TokenValue, string UID, string DivIDent)
        {
            DataTable dt = bl.BL_ExecuteParamSP("uspLoginInfoRecieve", Mode, TokenValue, UID, DivIDent);
            string JSONCONV = JsonConvert.SerializeObject(dt);
            return Ok(JSONCONV);
        }
    }
}
