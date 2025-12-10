using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
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
    [EnableCors(origins: "*", headers: "*", methods: "*")]
    public class SystemApprovalController : ApiController
    {
        clsBusinessLayer objBL = new clsBusinessLayer();

        [HttpGet]
        [Route("api/SystemApproval/get")]
        public IHttpActionResult LoadSystemDetails(int Mode)
        {
            List<SystemApprovalModel> sList = new List<SystemApprovalModel>();
            if (Mode == 1)// Web Approval Load
            {
                DataTable dtResult = objBL.BL_ExecuteParamSP("uspLoginInfoRecieve", 4);
                if (dtResult.Rows.Count > 0)
                {
                    for (int i = 0; i < dtResult.Rows.Count; i++)
                    {
                        sList.Add(new SystemApprovalModel
                        {
                            UserName = dtResult.Rows[i][4].ToString(),
                            DeviceName = dtResult.Rows[i][0].ToString(),
                            UserID = dtResult.Rows[i][2].ToString(),
                            DeviceID = dtResult.Rows[i][5].ToString(),
                            Activate = dtResult.Rows[i][3].ToString(),
                            MobileNo = dtResult.Rows[i][6].ToString()
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
        [HttpGet]
        [Route("api/SystemApproval/save")]
        public IHttpActionResult ActiveDeactive(string nMode, string nDeviceID, string nUserID)
        {
            if (nMode != "7" && nMode != "8")
            {
                //string Cons = clsEncryptDecrypt.Decrypt(ConfigurationManager.ConnectionStrings["Connection"].ConnectionString);
                //string Cons = APIGlobalConn.Decrypt(HttpUtility.UrlDecode(WebCon));
                //SqlConnection con = new SqlConnection(Cons);
                //con.Open();
                //SqlCommand cmd = new SqlCommand("uspLoginInfoRecieve", con);
                //cmd.CommandType = CommandType.StoredProcedure;
                //cmd.Parameters.AddWithValue("@Mode", nMode);
                //cmd.Parameters.AddWithValue("@TokenValue", nDBs);
                //cmd.Parameters.AddWithValue("@UserID", nUserID);
                //cmd.Parameters.AddWithValue("@DeviceIdent", nDeviceID);
                //SqlDataAdapter sda = new SqlDataAdapter(cmd);                
                //sda.Fill(dtResult);
                //con.Close();
                DataTable dtResult = objBL.BL_ExecuteParamSP("uspLoginInfoRecieve", nMode, null, nUserID, nDeviceID);
            }
            else if (nMode == "8")
            {
                DataTable dtResult = objBL.BL_ExecuteParamSP("uspLoginInfoRecieve", nMode, null, nUserID, nDeviceID);
            }
            return Ok(1);
        }
    }
}
