using SampWebApi.Models;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Data;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.Processing;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using System.Web.Http.Cors;
using SampWebApi.BuisnessLayer;
using System.Configuration;
using SampWebApi.Utility;
using System.Web;
using Newtonsoft.Json;
using System.Security.Cryptography;
using System.IO;
using DocumentFormat.OpenXml.Spreadsheet;
using Users = SampWebApi.Models.Users;
using DocumentFormat.OpenXml.InkML;
using DocumentFormat.OpenXml.Office2010.Excel;

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
            try
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
                        string imgdata = null;
                        if (!string.IsNullOrEmpty(DDT.Rows[i]["ImgData"].ToString()))
                        {
                            byte[] photoBytes = (byte[])DDT.Rows[i]["ImgData"];
                            imgdata = Convert.ToBase64String(photoBytes);
                        }
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
                            UserImageData = imgdata
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
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Login", "signup/get", ex.Message);
            }
            return Ok();
        }

        [HttpPost]
        [Route("api/signup/save")]
        public IHttpActionResult Savesignup(Users lstMaster)
        {
            try
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
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Login", "signup/save", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/signup/updateuser")]
        public IHttpActionResult Saveupdateuser()
        {
            try
            {
                var httpRequest = HttpContext.Current.Request;

                // Get normal form values
                string FormID = httpRequest.Form["FormID"];
                string nMode = httpRequest.Form["Mode"];
                string ID = httpRequest.Form["ID"];
                string Name = httpRequest.Form["UserName"];
                string MobileNo = httpRequest.Form["Mobilenumber"];
                string Email = httpRequest.Form["EMailID"];
                string UserID = httpRequest.Form["UserID"];
                byte[] photoBytes = null;

                bool removePhoto = !string.IsNullOrEmpty(httpRequest.Form["RemovePhoto"]);

                if (!removePhoto && httpRequest.Files.Count > 0)
                {
                    var file = httpRequest.Files["UserPhoto"]; // must match frontend key

                    if (file != null && file.ContentLength > 0)
                    {
                        using (var image = SixLabors.ImageSharp.Image.Load(file.InputStream))
                        {
                            // OPTIONAL: Resize if too large
                            image.Mutate(x =>
                            {
                                x.Resize(new ResizeOptions
                                {
                                    Mode = ResizeMode.Max,
                                    Size = new Size(800, 800)
                                });

                                // Flatten transparency over white background
                                x.BackgroundColor(SixLabors.ImageSharp.Color.White);
                            });

                            using (var ms = new MemoryStream())
                            {
                                var encoder = new JpegEncoder
                                {
                                    Quality = 75 // 0-100 (lower = more compression)
                                };

                                image.Save(ms, encoder);
                                photoBytes = ms.ToArray();
                            }
                        }
                    }
                }
                // ✅ Save into SQL Server
                using (SqlConnection con = new SqlConnection(connectionString))
                {
                    string query;

                    if (removePhoto)
                    {
                        // Explicitly clear the photo field
                        query = @"UPDATE tblUsers 
                  SET UserName=@Name,
                      Mobilenumber=@MobileNo,
                      EMailID=@Email,
                      ImgData=NULL
                  WHERE ID = @ID";
                    }
                    else if (photoBytes != null)
                    {
                        query = @"UPDATE tblUsers 
              SET UserName=@Name,
                  Mobilenumber=@MobileNo,
                  EMailID=@Email,
                  ImgData=@UserPhoto
              WHERE ID = @ID";
                    }
                    else
                    {
                        query = @"UPDATE tblUsers 
              SET UserName=@Name,
                  Mobilenumber=@MobileNo,
                  EMailID=@Email
              WHERE ID = @ID";
                    }

                    using (SqlCommand cmd = new SqlCommand(query, con))
                    {
                        cmd.Parameters.AddWithValue("@ID", ID);
                        cmd.Parameters.AddWithValue("@Name", Name);
                        cmd.Parameters.AddWithValue("@MobileNo", MobileNo);
                        cmd.Parameters.AddWithValue("@Email", Email);

                        // ✅ Save Photo (varbinary)
                        if (photoBytes != null)
                        {
                            cmd.Parameters.Add("@UserPhoto", SqlDbType.VarBinary).Value = photoBytes;
                        }

                        con.Open();
                        cmd.ExecuteNonQuery();
                        con.Close();
                    }
                }
                List<SaveMessage> list = new List<SaveMessage>();
                list.Add(new SaveMessage()
                {
                    ID = ID,
                    MsgID = "0",
                    Message = "Saved Successfully",
                });
                return Ok(list);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Login", "signup/updateuser", ex.Message);
            }
            return Ok();

        }
            [HttpGet]
        [Route("api/login/get")]
        public IHttpActionResult GetloginData(string UserName, string Password, string DeviceID, 
                string Latitude, string Longitude, string Pincode)
        {
            try
            {
                if (!string.IsNullOrEmpty(UserName) && !string.IsNullOrEmpty(Password))
                {
                    DataTable DDT = bl.BL_ExecuteParamSP("uspManageUsers", 6, 0, UserName, clsEncryptDecrypt.Encrypt(Password));
                    List<Users> list = new List<Users>();
                    if (DDT.Rows.Count > 0)
                    {
                        DataTable dtDevData = bl.BL_ExecuteParamSP("uspValidateDevice", 1, DeviceID, DDT.Rows[0]["ID"].ToString());
                        if (dtDevData.Rows.Count > 0 || DDT.Rows[0]["ID"].ToString() == "1")//Device already exists
                        {
                            string IsDevActive = "0";
                            if (DDT.Rows[0]["ID"].ToString() == "1")
                            {
                                IsDevActive = "1";
                            }
                            else
                            {
                                IsDevActive = dtDevData.Rows[0]["Active"].ToString();
                            }
                            if (IsDevActive == "1")
                            {
                                DateTime dtExpiryDate = Convert.ToDateTime(clsEncryptDecrypt.Decrypt(DDT.Rows[0]["ExpiryDate"].ToString()));
                                if (dtExpiryDate >= DateTime.Today)
                                {


                                    DateTime dtClssTKDate = Convert.ToDateTime(DDT.Rows[0]["UpdateClsDate"].ToString());
                                    if (dtClssTKDate.Date != DateTime.Today)
                                    {
                                        bl.bl_Transaction(1);
                                        bl.bl_ManageTrans("uspUpdateClsStockRepost", 2);
                                        bl.bl_Transaction(2);
                                    }
                                    DataTable dtAppconfig = bl.BL_ExecuteParamSP("uspManageApplicationConfig", 1);
                                    int ThemeID = bl.BL_nValidation(dtAppconfig.Rows[0]["ThemeID"].ToString());
                                    DataTable DTTHEME = bl.BL_ExecuteParamSP("uspManageColorSettings", 1, ThemeID);
                                    string ThemeJson = JsonConvert.SerializeObject(DTTHEME);
                                    DataTable DDTFilterData = bl.BL_ExecuteParamSP("uspGetFilterDates");
                                    string FilterData = JsonConvert.SerializeObject(DDTFilterData);
                                    DataTable dtPermission = bl.BL_ExecuteParamSP("uspMenuPermission", 2, DDT.Rows[0]["RoleID"].ToString(), DDT.Rows[0]["ID"].ToString());
                                    dtPermission.TableName = "UserMenus";
                                    string MenusData = JsonConvert.SerializeObject(dtPermission);

                                    list.Add(new Users
                                    {
                                        Mode = "1",
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
                                        ThemeData = ThemeJson,
                                        FilterDatelist = FilterData,
                                        Menuslist = MenusData,
                                        ResponseMessage = "Login Successful"
                                    });
                                    var authToken = TokenHelper.GenerateToken(DDT.Rows[0]["ID"].ToString());
                                    var refreshToken = TokenHelper.GenerateRefreshToken(DDT.Rows[0]["ID"].ToString(), authToken);

                                }
                                else
                                {
                                    list.Add(new Users
                                    {
                                        Mode = "4",
                                        ResponseMessage = "License Expired. Contact Admin"
                                    });
                                }
                            }
                            else
                            {
                                DataTable dtCompData = bl.BL_ExecuteParamSP("uspValidateDevice", 4);
                                string ToEmail = dtCompData.Rows[0]["Email"].ToString();
                                string CompName = dtCompData.Rows[0]["CompanyName"].ToString();
                                string CompCode = dtCompData.Rows[0]["CompanyCode"].ToString();
                                string CCMail = dtCompData.Rows[0]["CCEmail"].ToString();
                                string LoginUserName = DDT.Rows[0]["UserName"].ToString();
                                Random random = new Random();
                                int OTP = random.Next(100000, 999999);
                                #region Body Mail Content
                                string locationHtml = (!string.IsNullOrWhiteSpace(Latitude) &&
        !string.IsNullOrWhiteSpace(Longitude))
        ? $@"<a href=""https://www.google.com/maps?q={Latitude},{Longitude}"" target=""_blank"">
                        Open Location </a>"
        : "Location Not Found";

                                //                        string MailBody = $@"
                                //Dear <b>{LoginUserName}</b>,<br/><br/>

                                //Your device verification OTP is <label style='color:#0070C0;margin:0;font-size:16px'>{OTP}</label><br/>

                                //<b>Company Code:</b> {CompCode}<br/> <b>Company Name:</b> {CompName}<br/> <b>User Name:</b> {LoginUserName}<br/> <b>Location:</b> {locationHtml}<br/><br/>

                                //Please do not share this OTP with anyone.<br/><br/>

                                //Regards,<br/> <b>{CompName}</b>
                                //";
                                string MailBody = $@"

<html>
<body style='margin:0;padding:0;background-color:#f4f6f9;font-family:Segoe UI,Arial,sans-serif;'>

<div style='max-width:600px;margin:10px auto;background:#ffffff;
            border-radius:10px;overflow:hidden;
            box-shadow:0 2px 10px rgba(0,0,0,0.08);'>

    <div style='background:#0d6efd;padding:10px;text-align:center;color:#ffffff;'>
        <h2 style='margin:0;'>Device Verification</h2>
    </div>

    <div style='padding:15px;'>

        <p style='font-size:15px;color:#333;margin-top:0;'>
            Dear <b>{LoginUserName}</b>,
        </p>

        <p style='font-size:14px;color:#555;line-height:1.6;'>
            A device verification request has been initiated for your account.
            Please use the OTP below to complete the verification process.
        </p>

        <div style='background:#f8f9fa;
                    border:2px dashed #0d6efd;
                    border-radius:8px;
                    text-align:center;
                    padding:20px;
                    margin:15px 0;'>

            <div style='font-size:12px;color:#6c757d;letter-spacing:1px;'>
                ONE-TIME PASSWORD (OTP)
            </div>

            <div style='font-size:32px;
                        font-weight:700;
                        color:#0d6efd;
                        letter-spacing:5px;
                        margin-top:10px;'>
                {OTP}
            </div>
        </div>

        <table style='width:100%;border-collapse:collapse;font-size:14px;'>
            <tr>
                <td style='padding:8px 0;color:#666;width:35%;'><b>Company Code</b></td>
                <td style='padding:8px 0;color:#333;'>{CompCode}</td>
            </tr>
            <tr>
                <td style='padding:8px 0;color:#666;'><b>Company Name</b></td>
                <td style='padding:8px 0;color:#333;'>{CompName}</td>
            </tr>
            <tr>
                <td style='padding:8px 0;color:#666;'><b>User Name</b></td>
                <td style='padding:8px 0;color:#333;'>{LoginUserName}</td>
            </tr>
            <tr>
                <td style='padding:8px 0;color:#666;'><b>Location</b></td>
                <td style='padding:8px 0;color:#333;'>{locationHtml}</td>
            </tr>
        </table>

        <div style='margin-top:10px;
                    padding:12px;
                    background:#fff3cd;
                    border-left:4px solid #ffc107;
                    color:#856404;
                    font-size:13px;'>
            Please do not share this OTP with anyone. If you did not request this verification,
            contact your system administrator immediately.
        </div>

        <p style='margin-top:15px;color:#555;font-size:14px;'>
            Regards,<br/>
            <b>{CompName}</b>
        </p>

    </div>

    <div style='background:#f8f9fa;
                padding:15px;
                text-align:center;
                font-size:12px;
                color:#888;'>
        This is an automated email. Please do not reply.
    </div>

</div>
</body>
</html>";
                                #endregion
                                bool Issend = bl.SendEmail("Device Verification OTP", MailBody,
                                    //"Dear " + CompName + ", OTP for Device Verification <b>" + OTP.ToString() + "</b>", 
                                    ToEmail, CCMail);
                                if (Issend)
                                {
                                    int OTPID = 0;
                                    DataTable dtOTP = bl.BL_ExecuteParamSP("uspManageOTP", 1, 0, "DeviceVerify", OTP, DDT.Rows[0]["ID"].ToString());
                                    if (dtOTP.Rows.Count > 0)
                                    {
                                        OTPID = Convert.ToInt32(dtOTP.Rows[0][0].ToString());
                                    }
                                    list.Add(new Users
                                    {
                                        Mode = "2",
                                        ID = OTPID.ToString(),// DDT.Rows[0]["ID"].ToString(),
                                        UserID = DDT.Rows[0]["ID"].ToString(),
                                        EMailID = ToEmail,
                                        ResponseMessage = "OTP Send to this Email ID (" + ToEmail + ")"
                                    });
                                }
                                else
                                {
                                    list.Add(new Users
                                    {
                                        Mode = "3",
                                        ResponseMessage = "OTP E-Mail is not sending. Please check E-mail ID and try again"
                                    });
                                }
                            }
                        }
                        else//New Device
                        {
                            DataTable dtNewDevData = bl.BL_ExecuteParamSP("uspValidateDevice", 2, DeviceID, DDT.Rows[0]["ID"].ToString(),
                                "Browser", Latitude, Longitude, Pincode);
                            DataTable dtCompData = bl.BL_ExecuteParamSP("uspValidateDevice", 4);
                            string ToEmail = dtCompData.Rows[0]["Email"].ToString();
                            string CompName = dtCompData.Rows[0]["CompanyName"].ToString();
                            string CompCode = dtCompData.Rows[0]["CompanyCode"].ToString();
                            string CCMail = dtCompData.Rows[0]["CCEmail"].ToString();
                            string LoginUserName = DDT.Rows[0]["UserName"].ToString();
                            Random random = new Random();
                            int OTP = random.Next(100000, 999999);
                            #region Body Mail Content
                            string locationHtml = (!string.IsNullOrWhiteSpace(Latitude) &&
    !string.IsNullOrWhiteSpace(Longitude))
    ? $@"<a href=""https://www.google.com/maps?q={Latitude},{Longitude}"" target=""_blank"">
                        Open Location </a>"
    : "Location Not Found";

                            //                        string MailBody = $@"
                            //Dear <b>{LoginUserName}</b>,<br/><br/>

                            //Your device verification OTP is <label style='color:#0070C0;margin:0;font-size:16px'>{OTP}</label><br/>

                            //<b>Company Code:</b> {CompCode}<br/> <b>Company Name:</b> {CompName}<br/> <b>User Name:</b> {LoginUserName}<br/> <b>Location:</b> {locationHtml}<br/><br/>

                            //Please do not share this OTP with anyone.<br/><br/>

                            //Regards,<br/> <b>{CompName}</b>
                            //";
                            string MailBody = $@"

<html>
<body style='margin:0;padding:0;background-color:#f4f6f9;font-family:Segoe UI,Arial,sans-serif;'>

<div style='max-width:600px;margin:10px auto;background:#ffffff;
            border-radius:10px;overflow:hidden;
            box-shadow:0 2px 10px rgba(0,0,0,0.08);'>

    <div style='background:#0d6efd;padding:10px;text-align:center;color:#ffffff;'>
        <h2 style='margin:0;'>Device Verification</h2>
    </div>

    <div style='padding:15px;'>

        <p style='font-size:15px;color:#333;margin-top:0;'>
            Dear <b>{LoginUserName}</b>,
        </p>

        <p style='font-size:14px;color:#555;line-height:1.6;'>
            A device verification request has been initiated for your account.
            Please use the OTP below to complete the verification process.
        </p>

        <div style='background:#f8f9fa;
                    border:2px dashed #0d6efd;
                    border-radius:8px;
                    text-align:center;
                    padding:20px;
                    margin:15px 0;'>

            <div style='font-size:12px;color:#6c757d;letter-spacing:1px;'>
                ONE-TIME PASSWORD (OTP)
            </div>

            <div style='font-size:32px;
                        font-weight:700;
                        color:#0d6efd;
                        letter-spacing:5px;
                        margin-top:10px;'>
                {OTP}
            </div>
        </div>

        <table style='width:100%;border-collapse:collapse;font-size:14px;'>
            <tr>
                <td style='padding:8px 0;color:#666;width:35%;'><b>Company Code</b></td>
                <td style='padding:8px 0;color:#333;'>{CompCode}</td>
            </tr>
            <tr>
                <td style='padding:8px 0;color:#666;'><b>Company Name</b></td>
                <td style='padding:8px 0;color:#333;'>{CompName}</td>
            </tr>
            <tr>
                <td style='padding:8px 0;color:#666;'><b>User Name</b></td>
                <td style='padding:8px 0;color:#333;'>{LoginUserName}</td>
            </tr>
            <tr>
                <td style='padding:8px 0;color:#666;'><b>Location</b></td>
                <td style='padding:8px 0;color:#333;'>{locationHtml}</td>
            </tr>
        </table>

        <div style='margin-top:10px;
                    padding:12px;
                    background:#fff3cd;
                    border-left:4px solid #ffc107;
                    color:#856404;
                    font-size:13px;'>
            Please do not share this OTP with anyone. If you did not request this verification,
            contact your system administrator immediately.
        </div>

        <p style='margin-top:15px;color:#555;font-size:14px;'>
            Regards,<br/>
            <b>{CompName}</b>
        </p>

    </div>

    <div style='background:#f8f9fa;
                padding:15px;
                text-align:center;
                font-size:12px;
                color:#888;'>
        This is an automated email. Please do not reply.
    </div>

</div>
</body>
</html>";
                            #endregion
                            bool Issend = bl.SendEmail("Device Verification OTP", MailBody,
                                //"Dear " + CompName + ", OTP for Device Verification <b>" + OTP.ToString() + "</b>", 
                                ToEmail, CCMail);
                            if (Issend)
                            {
                                int OTPID = 0;
                                DataTable dtOTP = bl.BL_ExecuteParamSP("uspManageOTP", 1, 0, "DeviceVerify", OTP, DDT.Rows[0]["ID"].ToString());
                                if (dtOTP.Rows.Count > 0)
                                {
                                    OTPID = Convert.ToInt32(dtOTP.Rows[0][0].ToString());
                                }
                                list.Add(new Users
                                {
                                    Mode = "2",
                                    ID = OTPID.ToString(),// DDT.Rows[0]["ID"].ToString(),
                                    UserID = DDT.Rows[0]["ID"].ToString(),
                                    EMailID = ToEmail,
                                    ResponseMessage = "OTP Send to this Email ID (" + ToEmail + ")"
                                });
                            }
                            else
                            {
                                list.Add(new Users
                                {
                                    Mode = "3",
                                    ResponseMessage = "OTP E-Mail is not sending. Please check E-mail ID and try again"
                                });
                            }

                        }
                        return Ok(list);
                    }
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Login", "login/get", ex.Message);
            }
            return Ok();
        }

        [HttpGet]
        [Route("api/login/otpverify")]
        public IHttpActionResult loginotpverify(string OTPID, string UserID, string DeviceID, string OTP,
            string Latitude, string Longitude, string Pincode)
        {
            try
            {
                var list = new List<object>();
                DataTable dtOTP = bl.BL_ExecuteParamSP("uspManageOTP", 2, OTPID, null, OTP);
                if (dtOTP.Rows.Count > 0)
                {
                    DataTable dtNewDevData = bl.BL_ExecuteParamSP("uspValidateDevice", 3, DeviceID, UserID,
                                "Browser", Latitude, Longitude, Pincode);
                    //Token assign
                    var authToken = TokenHelper.GenerateToken(UserID);
                    var tkn = HttpContext.Current.Request.Cookies["ASP.NET_SessionId"];
                    var refreshToken = TokenHelper.GenerateRefreshToken(UserID, authToken);
                    DataTable dtAppconfig = bl.BL_ExecuteParamSP("uspManageApplicationConfig", 1);
                    int ThemeID = bl.BL_nValidation(dtAppconfig.Rows[0]["ThemeID"].ToString());
                    DataTable DTTHEME = bl.BL_ExecuteParamSP("uspManageColorSettings", 1, ThemeID);
                    string ThemeJson = JsonConvert.SerializeObject(DTTHEME);
                    DataTable DDTFilterData = bl.BL_ExecuteParamSP("uspGetFilterDates");
                    string FilterData = JsonConvert.SerializeObject(DDTFilterData);
                    DataTable dtRes = bl.BL_ExecuteParamSP("uspManageUsers", 4, UserID);                    
                    string RID = dtRes.Rows[0]["RoleID"].ToString();
                    DataTable dtPermission = bl.BL_ExecuteParamSP("uspMenuPermission", 2, RID, UserID);
                    dtPermission.TableName = "UserMenus";
                    string MenusData = JsonConvert.SerializeObject(dtPermission);
                    list.Add(new
                    {
                        MsgID = "0",
                        ID = UserID.ToString(),
                        Message = "OTP Verified Successfully",
                        ThemeData = ThemeJson,
                        Menuslist = MenusData,
                        FilterDatelist = FilterData,
                    });
                }
                else
                {
                    list.Add(new
                    {
                        MsgID = "1",
                        Message = "Invalid OTP"
                    });
                }
                return Ok(list);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Login", "login/otpverify", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/forgotpassword/validate")]
        public IHttpActionResult GetFGuserData(string UserName, string Email)
        {
            try
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
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Login", "forgotpassword/validate", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/forgotpassword/setpassword")]
        public IHttpActionResult GetFGsetpwd(string UserName, string Email, string Password)
        {
            try
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
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Login", "forgotpassword/setpassword", ex.Message);
            }
            return Ok();
        }

        [HttpGet]
        [Route("api/todayroute/getpost")]
        public IHttpActionResult GetSettodayroute(string Mode, string UserID, string BeatID = "0",string SalesmanID = "0", string BranchID = "0")
        {
            try
            {
                if (Mode == "1")
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
                else if (Mode == "2")
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
                else if (Mode == "3")
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
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Login", "todayroute/getpost", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/companyregistration")]
        public IHttpActionResult companyregistrationData()
        {
            try
            {
                DataTable dt = bl.BL_ExecuteSqlQuery("select * from tblCompanyRegistration");
                string dtjson = JsonConvert.SerializeObject(dt);
                return Ok(dtjson);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Login", "companyregistration", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/activateaccount")]
        public IHttpActionResult AccountActivation(string UID)
        {
            try
            {
                DataTable dtRes = bl.BL_ExecuteParamSP("uspManageUsers", 5, UID);
                string dtjson = JsonConvert.SerializeObject(dtRes);
                return Ok(dtjson);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Login", "activateaccount", ex.Message);
            }
            return Ok();
        }
        //[CookieAuthorize]
        [HttpGet]
        [Route("api/validatepermissions")]
        public IHttpActionResult validatepermissionsData(string UID)
        {
            try
            {
                DataSet ds = new DataSet();
                DataTable dt = bl.BL_ExecuteSqlQuery("select * from tblCompanyRegistration");
                dt.TableName = "CompanyReg";
                ds.Tables.Add(dt);
                DataTable dtAppconfig = bl.BL_ExecuteParamSP("uspManageApplicationConfig", 1);
                dtAppconfig.TableName = "AppConfig";
                ds.Tables.Add(dtAppconfig);
                int ThemeID = bl.BL_nValidation(dtAppconfig.Rows[0]["ThemeID"].ToString());

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

                DataTable dtFinReportParent = bl.BL_ExecuteParamSP("uspFinancialReportPermission", 1, RID);
                dtFinReportParent.TableName = "ParentFinRepMenu";
                ds.Tables.Add(dtFinReportParent);
                DataTable dtFinReportPermission = bl.BL_ExecuteParamSP("uspFinancialReportPermission", 2, RID, UID);
                dtFinReportPermission.TableName = "UserFinRepMenus";
                ds.Tables.Add(dtFinReportPermission);
                DataTable DDT = bl.BL_ExecuteParamSP("uspManageColorSettings", 1, ThemeID);
                dtFinReportPermission.TableName = "ThemeData";
                ds.Tables.Add(DDT);
                string dtjson = JsonConvert.SerializeObject(ds);
                return Ok(dtjson);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Login", "validatepermissions", ex.Message);
            }
            return Ok();
        }
    }
}
