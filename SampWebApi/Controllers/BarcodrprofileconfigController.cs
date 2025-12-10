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
using System.Web.Http;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class BarcodrprofileconfigController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/barcodeprofiles/initialDatas")]
        public IHttpActionResult GetinitialDatas()
        {
            var InitialData = new List<object>();
            var objProfiles = new List<object>();
            var objprnFiles = new List<object>();
            DataTable dtTrans = bl.BL_ExecuteParamSP("uspGetSetBarcodeProfileConfig", 1);
            if (dtTrans.Rows.Count > 0)
            {
                for (int i = 0; i < dtTrans.Rows.Count; i++)
                {
                    objProfiles.Add(new
                    {
                        ID = dtTrans.Rows[i]["Id"].ToString(),
                        ProfileName = dtTrans.Rows[i]["ProfileName"].ToString(),
                        FileName = dtTrans.Rows[i]["FileName"].ToString(),
                        Width = dtTrans.Rows[i]["Width"].ToString(),    
                        Height = dtTrans.Rows[i]["Height"].ToString(),
                        NoofRows = dtTrans.Rows[i]["NoofRows"].ToString(),
                    });
                }
            }
            int FID = 1;
            string strBarcodePath = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"] + "\\Barcode\\";
            if (Directory.Exists(strBarcodePath))
            {
                string[] prnFiles = Directory.GetFiles(strBarcodePath, "*.prn");
                foreach (string file in prnFiles)
                {
                    FileInfo f = new FileInfo(file);
                    //Console.WriteLine(file);
                    
                    objprnFiles.Add(new
                    {
                        ID = FID++,
                        FileName = f.Name
                    });
                }
            }
            InitialData.Add(new
            {
                BarcodeProfiles = objProfiles,
                FileNames = objprnFiles
            });
            return Ok(InitialData);

            
        }
        [HttpPost]
        [Route("api/barcodeprofiles/saveprofiles")]
        public IHttpActionResult Saveprofiles([FromBody] List<BarcodeProfiles> ProfileDetails)
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
    }
}
