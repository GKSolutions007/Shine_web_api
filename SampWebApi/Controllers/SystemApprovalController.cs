using BuinessLayer;
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
using System.Text.Json;
using System.Web.Http;
using System.Web.Http.Cors;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class SystemApprovalController : ApiController
    {
        clsBusinessLayer objBL = new clsBusinessLayer();

        [HttpGet]
        [Route("api/MobileDeviceApproval/get")]
        public IHttpActionResult LoadMobileDevDetails(int Mode)
        {
            try
            {
                List<SystemApprovalModel> sList = new List<SystemApprovalModel>();
                if (Mode == 1)// Web Approval Load
                {
                    DataTable dtResult = objBL.BL_ExecuteParamSP("uspLoginInfoRecieve", 4);
                    if (dtResult.Rows.Count > 0)
                    {
                        string mobcounts = SampWebApi.BuisnessLayer.clsEncryptDecrypt.Decrypt(dtResult.Rows[0]["MobileDevices"].ToString());
                        for (int i = 0; i < dtResult.Rows.Count; i++)
                        {
                            sList.Add(new SystemApprovalModel
                            {
                                UserName = dtResult.Rows[i][4].ToString(),
                                DeviceName = dtResult.Rows[i][0].ToString(),
                                UserID = dtResult.Rows[i][2].ToString(),
                                DeviceID = dtResult.Rows[i][5].ToString(),
                                Activate = dtResult.Rows[i][3].ToString(),
                                MobileNo = dtResult.Rows[i][6].ToString(),
                                DBName = mobcounts,
                            });
                        }
                    }
                }
                if (Mode == 10)
                {
                    DataTable dtResult = objBL.BL_ExecuteParamSP("uspLoginInfoRecieve", Mode);
                    if (dtResult.Rows.Count > 0)
                    {
                        for (int i = 0; i < dtResult.Rows.Count; i++)
                        {
                            sList.Add(new SystemApprovalModel
                            {
                                UserID = dtResult.Rows[i][0].ToString(),
                                UserName = dtResult.Rows[i][1].ToString(),
                            });
                        }
                    }
                }
                return Ok(sList);
            }
            catch(Exception ex)
            {
                objBL.BL_WriteErrorMsginLog("SystemApproval", "MobileDeviceApproval/get", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/MobileDeviceApproval/save")]
        public IHttpActionResult ActiveDeactiveMobDev(string nMode, string nDeviceID, string nUserID)
        {
            try
            {
                if(nMode == "6")// DeActive Device (nMode != "7" && nMode != "8")
                {                    
                    DataTable dtResult = objBL.BL_ExecuteParamSP("uspLoginInfoRecieve", nMode, null, nUserID, nDeviceID);
                    return Ok(1);
                }
                if (nMode == "5")// Active Device
                {
                    var sList = new List<object>();
                    DataTable dtMobDev = objBL.BL_ExecuteParamSP("uspManageUpdateCompanyDetail", 1);
                    string MobDevCount = dtMobDev.Rows.Count > 0 ? SampWebApi.BuisnessLayer.clsEncryptDecrypt.Decrypt(dtMobDev.Rows[0]["MobileDevices"].ToString()) : "1";
                    DataTable dtResult = objBL.BL_ExecuteParamSP("uspLoginInfoRecieve", nMode, null, nUserID, nDeviceID, MobDevCount);
                    if(dtResult.Rows.Count > 0)
                    {
                        sList.Add(new
                        {
                            MsgID = "1",
                            Message = dtResult.Rows[0][0].ToString(),
                        });                        
                    }
                    else
                    {
                        sList.Add(new
                        {
                            MsgID = "0",
                            Message = "Activated Successfully.!!!",
                        });                        
                    }
                    return Ok(sList);
                }
                if (nMode == "8")
                {
                    

                    DataTable dtResult = objBL.BL_ExecuteParamSP("uspLoginInfoRecieve", nMode, null, nUserID, nDeviceID);
                    return Ok(1);
                }
                return Ok();
            }
            catch(Exception ex)
            {
                objBL.BL_WriteErrorMsginLog("SystemApproval", "MobileDeviceApproval/save", ex.Message);
            }
            return Ok();
        }

        [HttpGet]
        [Route("api/DeviceApproval/get")]
        public IHttpActionResult LoadSystemDetails(int Mode)
        {
            if(Mode == 1)
            {
                DataSet dtResult = objBL.BL_ExecuteParamSPDataset("uspManageDeviceApproval", Mode);
                string DeviceInfo = JsonConvert.SerializeObject(dtResult);
                return Ok(DeviceInfo);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/DeviceApproval/save")]
        public IHttpActionResult ActiveDeactiveDevice(string nMode, string nID)
        {
            try
            {
                DataTable dtResult = objBL.BL_ExecuteParamSP("uspManageDeviceApproval", nMode, nID);
                return Ok(1);
            }
            catch(Exception ex)
            {
                objBL.BL_WriteErrorMsginLog("SystemApproval", "DeviceApproval/save", ex.Message);
            }
            return Ok();
        }
    }
}
