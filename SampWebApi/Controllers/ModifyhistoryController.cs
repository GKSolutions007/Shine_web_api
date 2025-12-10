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
using System.Web.Http.Cors;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class ModifyhistoryController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [Route("api/modifyhistory/get")]
        public IHttpActionResult GetData(string Mode, string UserID, string FormID = null, string FromDate = null, string ToDate = null, string HID = null)
        {
            DataTable DDT = new DataTable();
            if (Mode == "1")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetModifyHistoryData", Mode, 0);
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
            if (Mode == "2" || Mode == "3")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetModifyHistoryData", Mode, FormID, UserID, Convert.ToDateTime(FromDate), Convert.ToDateTime(ToDate));
                List<SingleMasterModel> list = new List<SingleMasterModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new SingleMasterModel
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        Name = DDT.Rows[i][1].ToString(),
                    });
                }
                return Ok(list);

            }
            if (Mode == "4")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetModifyHistoryData", Mode, FormID, UserID, Convert.ToDateTime(FromDate), Convert.ToDateTime(ToDate));
                string data = JsonConvert.SerializeObject(DDT, Formatting.Indented);
                //List<SingleMasterModel> list = new List<SingleMasterModel>();
                //for (int i = 0; i < DDT.Rows.Count; i++)
                //{
                //    list.Add(new SingleMasterModel
                //    {
                //        ID = DDT.Rows[i][0].ToString(),
                //        Name = DDT.Rows[i][1].ToString(),
                //         Value = DDT.Rows[i][2].ToString(),
                //    });
                //}
                return Ok(data);
            }
            if (Mode == "5")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetModifyHistoryData", Mode, FormID, UserID, Convert.ToDateTime(FromDate), Convert.ToDateTime(ToDate),HID);
                string data = JsonConvert.SerializeObject(DDT, Formatting.Indented);
                return Ok(data);
            }
            return Ok();
        }
    }
}
