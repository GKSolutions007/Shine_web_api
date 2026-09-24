using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web;
using System.Web.Http;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class BarcoderPrintController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/barcodeprint/filterdata")]
        public IHttpActionResult GetFilterData(string Branch, string FromDate, string ToDate, string Showall)
        {
            try
            {

                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetBarcodeprint", 1, Branch, 25, FromDate, ToDate, Showall);
                return Ok(DDT);

            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Inventory", "inventoryadjustment/getfilterdata", ex.Message);
            }
            return Ok();
        }

        [HttpGet]
        [Route("api/barcodeprofiles/remove")]
        public IHttpActionResult removebarcodeprofiles(int ProfileID)
        {
            try
            {
                DataTable dtTrans = bl.BL_ExecuteParamSP("uspGetSetBarcodeProfileConfig", 3, ProfileID);
                return Ok("Profile Deleted Successfully");
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("BarcodeProfileConfig", "barcodeprofiles/remove", ex.Message);
            }
            return Ok();
        }
        [System.Web.Http.HttpPost]
        [System.Web.Http.Route("api/barcode/uploadfile")]
        public IHttpActionResult myuploadsFiles()
        {
            string Msg = "";
            string dt = "";
            List<ImportResults> MTM = new List<ImportResults>();
            try
            {
                var file = HttpContext.Current.Request.Files.Count > 1 ? HttpContext.Current.Request.Files[0] : null;
                //var data = Request.Files[0].InputStream.Read;                                                       
                if (HttpContext.Current.Request.Files.Count > 0)
                {
                    DataTable dtBakPath = bl.BL_ExecuteSqlQuery("select BackupPath from tblCompanyRegistration");
                    string path = AppDomain.CurrentDomain.BaseDirectory;
                    string strFilePath = path + "\\barcodefile\\";
                    string UserID = HttpContext.Current.Request.Files.AllKeys[0].ToString();
                    for (int i = 0; i < HttpContext.Current.Request.Files.Count; i++)
                    {
                        string fileName = HttpContext.Current.Request.Files[i].FileName;
                        string fileContentType = HttpContext.Current.Request.Files[i].ContentType;
                        //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Upload Files\\";
                        if (!Directory.Exists(strFilePath))
                        {
                            Directory.CreateDirectory(strFilePath);
                        }
                        HttpContext.Current.Request.Files[i].SaveAs(strFilePath + fileName);
                    }
                    MTM.Add(new ImportResults()
                    {
                        ID = "0",
                        Msg = "File Uploaded Successfully.",
                    });
                    return Ok(MTM);
                }
            }
            catch (Exception ex)
            {
                MTM.Add(new ImportResults()
                {
                    ID = "2",
                    Msg = ex.Message + " Date : " + dt,
                });
                return Ok(MTM);
            }
            return Ok(Msg);
        }
        [HttpPost]
        [Route("api/barcodeprofiles/saveprofiles")]
        public IHttpActionResult Saveprofiles([FromBody] List<BarcodeProfiles> ProfileDetails)
        {
            try
            {
                List<SaveMessage> savemsg = new List<SaveMessage>();
                if (ProfileDetails == null || ProfileDetails.Count == 0)
                    return BadRequest("No controls received.");
                bl.bl_Transaction(1);
                foreach (BarcodeProfiles profile in ProfileDetails)
                {
                    DataTable dtTrans = bl.bl_ManageTrans("uspGetSetBarcodeProfileConfig", 2, profile.ID, profile.ProfileName,
                        profile.FileName, profile.Width, profile.Height, profile.NoofRows, profile.UID);
                    if (dtTrans.Rows.Count > 0)
                    {
                        bl.bl_Transaction(3);
                        savemsg.Add(new SaveMessage()
                        {
                            ID = 0.ToString(),
                            MsgID = "1",
                            Message = profile.ProfileName + " - " + dtTrans.Rows[0][0].ToString(),
                        });
                        return Ok(savemsg);
                    }
                }
                bl.bl_Transaction(2);
                savemsg.Add(new SaveMessage()
                {
                    MsgID = "0",
                    Message = "Saved Successfully",
                });
                return Ok(savemsg);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("BarcodeProfileConfig", "barcodeprofiles/saveprofiles", ex.Message);
            }
            return Ok();
        }
    }
}
