using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class MasterSyncController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [Route("api/mastersync/synctables")]
        public IHttpActionResult getDiscountschemeinfo()
        {
            try
            {
                DataTable dtTables = bl.BL_ExecuteParamSP("uspgetsetMasterSyncdata", 1);
                return Ok(dtTables);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("MasterSync", "mastersync/synctables", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/mastersync/syncdata")]
        public IHttpActionResult SyncData(List<syncdetails> lstsyncdata)
        {
            string TableName = "";
            try
            {
                var list = new List<object>();
                if (lstsyncdata != null)
                {
                    string DBName = ConfigurationManager.AppSettings["MasterSyncDB"];
                    foreach (syncdetails item in lstsyncdata)
                    {
                        DataTable dtResult = bl.BL_ExecuteParamSP("uspSyncMasterData",
                            DBName, item.TableName,item.SyncTime);
                        if(dtResult.Rows.Count == 0)
                        {
                            //update sync time
                            bl.BL_ExecuteParamSP("uspgetsetMasterSyncdata", 2, item.TableName);
                        }
                        else
                        {
                            list.Add(new
                            {
                                ID = item.ID.ToString(),
                                TableName = item.TableName,
                                LastUpdateTime = DateTime.Now.ToString("dd/MMM/yyyy hh:ss:mm"),
                                MsgID = "1",
                                Message = dtResult.Rows[0][0].ToString(),
                            });
                            return Ok(list);
                        }
                    }
                    list.Add(new SaveMessage()
                    {
                        ID = 0.ToString(),
                        MsgID = "0",
                        Message = "Master Synchronized successfully"
                    });
                    return Ok(list);
                }
                list.Add(new SaveMessage()
                {
                    ID = 0.ToString(),
                    MsgID = "1",
                    Message = "Data not saved. Try again"
                });
                return Ok(list);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("MasterSync", "mastersync/syncdata", ex.Message + "\tTable Name : " + TableName);
            }
            return Ok();
        }
    }

    public class syncdetails
    {
        public int ID { get; set; }
        public string TableName { get; set; }
        public string SyncTime { get; set; }
    }
}
