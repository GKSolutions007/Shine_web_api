using SampWebApi.Models;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Data;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using System.Web.Http.Cors;
using SampWebApi.BuisnessLayer;
using System.Configuration;
using SampWebApi.Utility;
using System.Web;
using static System.Windows.Forms.VisualStyles.VisualStyleElement.StartPanel;
using DocumentFormat.OpenXml.Office2010.ExcelAc;
using Newtonsoft.Json;
using DocumentFormat.OpenXml.Office2010.Excel;
using System.Security.Cryptography;

namespace SampWebApi.Controllers
{
    public class LoginController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        string connectionString = clsEncryptDecrypt.Decrypt(ConfigurationManager.ConnectionStrings["Connections"].ConnectionString);
        [CookieAuthorize]
        [HttpGet]
        [Route("api/signup/get")]
        public IHttpActionResult GetsignupData(string Mode, string Name)
        {
            if (Mode == "3" || Mode == "4")
            {
                SqlConnection sqlConnection = new SqlConnection(connectionString);
                sqlConnection.Open();
                SqlCommand sqlCommand = new SqlCommand("uspManageUsers", sqlConnection);
                sqlCommand.CommandType = CommandType.StoredProcedure;
                sqlCommand.Parameters.AddWithValue("@Mode", Mode);
                sqlCommand.Parameters.AddWithValue("@ID", Name);
                sqlCommand.Parameters.AddWithValue("@UserName", "");
                DataTable DDT = new DataTable();
                SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                SDA.Fill(DDT);
                sqlConnection.Close();
                List<Users> list = new List<Users>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new Users
                    {
                        ID = DDT.Rows[i]["ID"].ToString(),
                        UserName = DDT.Rows[i]["UserName"].ToString(),
                        Active = DDT.Rows[i]["Active"].ToString(),
                        Password = clsEncryptDecrypt.Decrypt(DDT.Rows[i]["Password"].ToString()),
                        Mobilenumber = DDT.Rows[i]["Mobilenumber"].ToString(),
                        EMailID = DDT.Rows[i]["EMailID"].ToString(),
                        RoleID = DDT.Rows[i]["RoleID"].ToString(),
                        RoleName = DDT.Rows[i]["RoleName"].ToString(),
                        PwdResetCount = DDT.Rows[i]["PwdResetCount"].ToString(),
                        PwdResetTime = DDT.Rows[i]["PwdResetTime"].ToString(),
                        LPin = DDT.Rows[i]["LPin"].ToString(),
                        UserID = DDT.Rows[i]["CBy"].ToString(),
                        CBy = DDT.Rows[i]["AUserName"].ToString(),
                        CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                    });
                }
                return Ok(list);
            }
            else if (Mode == "7")
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspManageUsers", Mode, Name);
                List<Salesman> list = new List<Salesman>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new Salesman
                    {
                        ID = DDT.Rows[i]["ID"].ToString(),
                        Name = DDT.Rows[i]["Name"].ToString(),
                    });
                }
                return Ok(list);
            }
            return Ok();
        }

        [HttpPost]
        [Route("api/signup/save")]
        public IHttpActionResult Savesignup(Users lstMaster)
        {
            if (lstMaster != null)
            {
                //DataTable dt = bl.BL_ExecuteParamSP("uspManageUsers")
                SqlConnection sqlConnection = new SqlConnection(connectionString);
                sqlConnection.Open();
                SqlCommand sqlCommand = new SqlCommand("uspManageUsers", sqlConnection);
                sqlCommand.CommandType = CommandType.StoredProcedure;
                sqlCommand.Parameters.AddWithValue("@Mode", lstMaster.Mode);
                sqlCommand.Parameters.AddWithValue("@ID", lstMaster.ID);
                sqlCommand.Parameters.AddWithValue("@UserName", lstMaster.UserName);
                sqlCommand.Parameters.AddWithValue("@Password", clsEncryptDecrypt.Encrypt(lstMaster.Password));
                sqlCommand.Parameters.AddWithValue("@Mobilenumber", lstMaster.Mobilenumber);
                sqlCommand.Parameters.AddWithValue("@EMailID", lstMaster.EMailID);
                sqlCommand.Parameters.AddWithValue("@RoleID", lstMaster.RoleID);
                sqlCommand.Parameters.AddWithValue("@PwdResetCount", lstMaster.PwdResetCount);
                sqlCommand.Parameters.AddWithValue("@PwdResetTime", lstMaster.PwdResetTime);
                sqlCommand.Parameters.AddWithValue("@LPin", lstMaster.LPin);
                sqlCommand.Parameters.AddWithValue("@Active", lstMaster.Active);
                sqlCommand.Parameters.AddWithValue("@UserID", lstMaster.UserID);
                DataTable DDT = new DataTable();
                SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                SDA.Fill(DDT);
                sqlConnection.Close();
                List<SaveMessage> list = new List<SaveMessage>();
                if (DDT.Columns.Count == 1)
                {
                    //Success message
                    list.Add(new SaveMessage()
                    {
                        ID = DDT.Rows[0][0].ToString(),
                        MsgID = "0",
                        Message = "Saved Successfully"
                    });
                }
                else
                {
                    //Error message
                    list.Add(new SaveMessage()
                    {
                        ID = "0",
                        MsgID = "1",
                        Message = DDT.Rows[0][0].ToString(),
                    });
                }
                return Ok(list);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/login/get")]
        public IHttpActionResult GetloginData(string UserName, string Password)
        {
            if (!string.IsNullOrEmpty(UserName) && !string.IsNullOrEmpty(Password))
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspManageUsers", 6, 0, UserName, clsEncryptDecrypt.Encrypt(Password));
                List<Users> list = new List<Users>();
                if (DDT.Rows.Count > 0)
                {

                    DateTime dtClssTKDate = Convert.ToDateTime(DDT.Rows[0]["UpdateClsDate"].ToString());
                    if (dtClssTKDate.Date != DateTime.Today)
                    {
                        bl.bl_Transaction(1);
                        bl.bl_ManageTrans("uspUpdateClsStockRepost", 2);
                        bl.bl_Transaction(2);
                    }
                    list.Add(new Users
                    {
                        ID = DDT.Rows[0]["ID"].ToString(),
                        UserName = DDT.Rows[0]["UserName"].ToString(),
                        Active = DDT.Rows[0]["Active"].ToString(),
                        //Password = DDT.Rows[0]["Password"].ToString(),
                        Mobilenumber = DDT.Rows[0]["Mobilenumber"].ToString(),
                        EMailID = DDT.Rows[0]["EMailID"].ToString(),
                        RoleID = DDT.Rows[0]["RoleID"].ToString(),
                        PwdResetCount = DDT.Rows[0]["PwdResetCount"].ToString(),
                        PwdResetTime = DDT.Rows[0]["PwdResetTime"].ToString(),
                        LPin = DDT.Rows[0]["LPin"].ToString(),
                        UserID = DDT.Rows[0]["CBy"].ToString(),
                    });
                    //HttpContext.Current.Session["LoginUserID"] = DDT.Rows[0]["ID"].ToString();
                    //HttpContext.Current.Session.Add("LoginUserID", DDT.Rows[0]["ID"].ToString());// = DDT.Rows[0]["ID"].ToString();
                    //DataTable dtParent = bl.BL_ExecuteParamSP("uspMenuPermission", 1, null);
                    //DataTable dtPermission = bl.BL_ExecuteParamSP("uspMenuPermission", 2, DDT.Rows[0]["RoleID"].ToString(), DDT.Rows[0]["ID"].ToString());//Convert.ToInt32(Session["LoginUserID"])
                    //HttpContext.Current.Session["dtParent"] = dtParent;
                    //HttpContext.Current.Session["dtPermission"] = dtPermission;
                    //Session["dtParent"] = dtParent;
                    //Session["dtPermission"] = dtPermission;
                    var authToken = TokenHelper.GenerateToken(DDT.Rows[0]["ID"].ToString());
                    var refreshToken = TokenHelper.GenerateRefreshToken(DDT.Rows[0]["ID"].ToString());
                    return Ok(list);
                }
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/forgotpassword/validate")]
        public IHttpActionResult GetFGuserData(string UserName, string Email)
        {

            DataTable DDT = bl.BL_ExecuteParamSP("uspManageUsers", 8, 0, UserName, Email);
            List<Users> list = new List<Users>();
            if (DDT.Rows.Count > 0)
            {
                Random random = new Random();
                int OTP = random.Next(100000, 999999);
                bool Issend = bl.SendEmail("Shine Forgot Password OTP", "Hii user, OTP for forgot password is <b>" + OTP.ToString() + "</b>", Email);
                if (Issend)
                {
                    list.Add(new Users
                    {
                        LPin = OTP.ToString(),
                    });
                }
            }
            return Ok(list);
        }
        [HttpGet]
        [Route("api/forgotpassword/setpassword")]
        public IHttpActionResult GetFGsetpwd(string UserName, string Email, string Password)
        {

            DataTable DDT = bl.BL_ExecuteParamSP("uspManageUsers", 9, 0, UserName, clsEncryptDecrypt.Encrypt(Password),
                null, Email);
            List<SaveMessage> list = new List<SaveMessage>();
            //if (DDT.Rows.Count > 0)
            {
                list.Add(new SaveMessage
                {
                    MsgID = "0",
                    Message = "Password chaged successfully"
                });
            }
            return Ok(list);
        }

        [HttpGet]
        [Route("api/todayroute/getpost")]
        public IHttpActionResult GetSettodayroute(string Mode, string UserID, string BeatID = "0",string SalesmanID = "0", string BranchID = "0")
        {
            if(Mode == "1")
            {
                List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                DataTable DDT = bl.BL_ExecuteParamSP("uspManageTodayRoute", Mode);
                if (DDT.Rows.Count > 0)
                {                   
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new CustomerVendorModel
                        {
                            FType = DDT.Rows[i][0].ToString(),
                            Form = DDT.Rows[i][1].ToString(),
                            ID = DDT.Rows[i][2].ToString(),
                            Name = DDT.Rows[i][3].ToString(),
                        });
                    }                   
                }
                return Ok(list);
            }
            else if(Mode == "2")
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspManageTodayRoute", Mode, UserID);
                List<Users> list = new List<Users>();
                if (DDT.Rows.Count > 0)
                {
                    list.Add(new Users
                    {
                        BeatID = DDT.Rows[0][0].ToString(),
                        SalesmanID = DDT.Rows[0][1].ToString(),
                        BranchID = DDT.Rows[0][2].ToString(),
                    });
                }
                return Ok(list);
            }
            else if(Mode == "3")
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspManageTodayRoute", Mode, UserID, BeatID, SalesmanID, BranchID);
                List<SaveMessage> list = new List<SaveMessage>();
                //if (DDT.Rows.Count > 0)
                {
                    list.Add(new SaveMessage
                    {
                        MsgID = "0",
                        Message = "Saved successfully"
                    });
                }
                return Ok(list);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/companyregistration")]
        public IHttpActionResult companyregistrationData()
        {            
            DataTable dt = bl.BL_ExecuteSqlQuery("select * from tblCompanyRegistration");           
            string dtjson = JsonConvert.SerializeObject(dt);
            return Ok(dtjson);
        }
        [HttpGet]
        [Route("api/activateaccount")]
        public IHttpActionResult AccountActivation(string UID)
        {
            DataTable dtRes = bl.BL_ExecuteParamSP("uspManageUsers", 5, UID);
            return Ok();
        }
        [HttpGet]
        [Route("api/validatepermissions")]
        public IHttpActionResult validatepermissionsData(string UID)
        {
            DataSet ds = new DataSet();
            DataTable dt = bl.BL_ExecuteSqlQuery("select * from tblCompanyRegistration");
            dt.TableName = "CompanyReg";
            ds.Tables.Add(dt);
            DataTable dtAppconfig = bl.BL_ExecuteParamSP("uspManageApplicationConfig", 1);
            dtAppconfig.TableName = "AppConfig";
            ds.Tables.Add(dtAppconfig);
            DataTable dtRes = bl.BL_ExecuteParamSP("uspManageUsers", 4, UID);
            dtRes.TableName = "UserData";
            ds.Tables.Add(dtRes);
            string RID = dtRes.Rows[0]["RoleID"].ToString();
            DataTable dtParent = bl.BL_ExecuteParamSP("uspMenuPermission", 1, null);
            dtParent.TableName = "ParentMenu";
            ds.Tables.Add(dtParent);
            DataTable dtPermission = bl.BL_ExecuteParamSP("uspMenuPermission", 2, RID, UID);
            dtPermission.TableName = "UserMenus";
            ds.Tables.Add(dtPermission);
            DataTable dtReportParent = bl.BL_ExecuteParamSP("uspReportPermission", 1, RID);
            dtReportParent.TableName = "ParentRepMenu";
            ds.Tables.Add(dtReportParent);
            DataTable dtReportPermission = bl.BL_ExecuteParamSP("uspReportPermission", 2, RID, UID);
            dtReportPermission.TableName = "UserRepMenus";
            ds.Tables.Add(dtReportPermission);
            string dtjson = JsonConvert.SerializeObject(ds);
            return Ok(dtjson);
        }
    }
}
