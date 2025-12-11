using DocumentFormat.OpenXml.Drawing.Diagrams;
using iTextSharp.awt.geom;
using Org.BouncyCastle.Utilities;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.RegularExpressions;
using System.Web.Http;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class PrintCustomizeController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpPost]
        [Route("api/printcustomize/savecontrols")]
        public IHttpActionResult SavePaperControls([FromBody] List<PrintConfigModel> PrintDetails)
        {
            List<SaveMessage> savemsg = new List<SaveMessage>();
            List<PrintCustomizeModel> controls = new List<PrintCustomizeModel>();
            if (PrintDetails == null || PrintDetails.Count == 0)
                return BadRequest("No controls received.");
            controls = PrintDetails[0].PrintConfigDeatils;
            try
            {
                // Create DataTable
                DataTable tvpPrintConfigDetail = new DataTable();

                // Define columns matching the SQL user-defined table type
                tvpPrintConfigDetail.Columns.Add("PrintID", typeof(int));
                tvpPrintConfigDetail.Columns.Add("ctrlName", typeof(string));
                tvpPrintConfigDetail.Columns.Add("ctrlWidth", typeof(int));
                tvpPrintConfigDetail.Columns.Add("ctrlHeight", typeof(int));
                tvpPrintConfigDetail.Columns.Add("ctrlXposition", typeof(int));
                tvpPrintConfigDetail.Columns.Add("ctrlYposition", typeof(int));
                tvpPrintConfigDetail.Columns.Add("SourceName", typeof(string));
                tvpPrintConfigDetail.Columns.Add("FontName", typeof(string));
                tvpPrintConfigDetail.Columns.Add("FontSize", typeof(int));
                tvpPrintConfigDetail.Columns.Add("FontStyle", typeof(int));
                tvpPrintConfigDetail.Columns.Add("Type", typeof(string));
                tvpPrintConfigDetail.Columns.Add("Footer", typeof(int));
                tvpPrintConfigDetail.Columns.Add("Bold", typeof(int));
                tvpPrintConfigDetail.Columns.Add("Italic", typeof(int));
                tvpPrintConfigDetail.Columns.Add("Underline", typeof(int));
                tvpPrintConfigDetail.Columns.Add("Align", typeof(int));
                tvpPrintConfigDetail.Columns.Add("ImageSource", typeof(byte[])); // [image] maps to byte[]
                tvpPrintConfigDetail.Columns.Add("QRCodeValue", typeof(string));
                tvpPrintConfigDetail.Columns.Add("FontColor", typeof(string));
                tvpPrintConfigDetail.Columns.Add("WrapText", typeof(byte)); // [tinyint] maps to byte
                foreach (var c in controls)
                {
                    try
                    {
                        if(c.ControlType == "H_Line")
                        {

                        }
                        string ContentType = !string.IsNullOrEmpty(c.PlaceType.ToString()) ? c.PlaceType : "Header";
                        string Align = !string.IsNullOrEmpty(c.Alignment) ? c.Alignment : "0";
                        byte[] imageBytes = null;
                        string strQRCodeValue = "";
                        string Fontcolor = "255,0,0,0";
                        if (!string.IsNullOrEmpty(c.Fontcolor))
                        {
                            var match = Regex.Match(c.Fontcolor, @"rgb\((\d+),\s*(\d+),\s*(\d+)\)");
                            if (match.Success)
                            {
                                int r = int.Parse(match.Groups[1].Value);
                                int g = int.Parse(match.Groups[2].Value);
                                int b = int.Parse(match.Groups[3].Value);

                                Color color = Color.FromArgb(255, r, g, b);
                                Fontcolor = $"{color.A},{color.R},{color.G},{color.B}";
                            }
                        }
                        if (c.ControlType == "Image")
                        {
                            string base64Image = c.ImageData; // truncated

                            //Remove the prefix if it exists
                            if (base64Image.StartsWith("data:image"))
                            {
                                base64Image = base64Image.Substring(base64Image.IndexOf(",") + 1);
                            }
                            imageBytes = Convert.FromBase64String(base64Image);
                        }
                        if (c.ControlType == "gksQRCode" || c.ControlType == "gksBarCode")
                        {
                            strQRCodeValue = c.QRText;
                        }
                        DataRow drr = tvpPrintConfigDetail.NewRow();
                        drr["PrintID"] = 0;
                        drr["ctrlName"] = c.ControlType == "V_Line" ? "V_Line" : c.ControlType == "H_Line" ? "H_Line" :
                            c.ControlType == "Image" ? "Image" : c.ControlType == "Box" ? "Box" :
                            c.ControlType == "gksQRCode" || c.ControlType == "gksBarCode" ? c.QRBarcodeID : c.TextValue ?? "";
                        drr["ctrlWidth"] = c.Width;
                        drr["ctrlHeight"] = c.Height;
                        drr["ctrlXposition"] = c.X;
                        drr["ctrlYposition"] = c.Y;
                        string SrcName = c.ControlType == "V_Line" ? "Value" : c.ControlType == "H_Line" ? "Value" : c.ControlType;
                        // c.ControlType == "Image" ? "Image" : c.ControlType == "Value" ? "Value" : c.ControlType == "Box" ? "Box" : "Label";
                        drr["SourceName"] = SrcName;//c.SourceName ?? (object)DBNull.Value;
                        drr["FontName"] = !string.IsNullOrEmpty(c.FontFamily) ? c.FontFamily.Replace('"', ' ').Trim() : "Times New Roman";
                        drr["FontSize"] = !string.IsNullOrEmpty(c.FontSize) ? (object)Math.Round(Convert.ToDecimal(c.FontSize.Replace("px", ""))) : (object)"9";// "9";// c.FontSize ?? (object)DBNull.Value;
                        drr["FontStyle"] = "65";// c.FontStyle ?? (object)DBNull.Value;
                        drr["Type"] = ContentType;// c.Type ?? (object)DBNull.Value;
                        drr["Footer"] = c.IsFooter ?? (object)0;// c.Footer ?? (object)DBNull.Value;
                        drr["Bold"] = c.Bold ?? (object)0;
                        drr["Italic"] = c.Italic ?? (object)0;
                        drr["Underline"] = 0;// c.Underline ?? (object)DBNull.Value;
                        drr["Align"] = Align;// c.Align ?? (object)DBNull.Value;
                        drr["ImageSource"] = imageBytes;// c.ImageSource ?? (object)DBNull.Value;
                        drr["QRCodeValue"] = strQRCodeValue;//c.QRCodeValue ?? (object)DBNull.Value;
                        drr["FontColor"] = Fontcolor;// c.FontColor ?? (object)DBNull.Value;
                        drr["WrapText"] = c.Wraptext ?? (object)0;// c.WrapText ?? (object)DBNull.Value;
                        tvpPrintConfigDetail.Rows.Add(drr);
                    }
                    catch(Exception ex)
                    {
                        bl.BL_WriteErrorMsginLog("Print Customize", "Save", ex.Message);
                        return InternalServerError(ex);
                    }
                }
                decimal papercf = 3.77619M;
                int boxHeight = Convert.ToInt32(bl.BL_dValidation(PrintDetails[0].Height.ToString()) * papercf);
                int boxWidth = Convert.ToInt32(bl.BL_dValidation(PrintDetails[0].Width.ToString()) * papercf);
                bl.bl_Transaction(1);
                DataTable dtResult = bl.bl_ManageTrans("uspSavePrintConfig", PrintDetails[0].SaveType,
                                PrintDetails[0].SaveMode,
                                PrintDetails[0].SaveMode == "2" ? PrintDetails[0].PrintID : "0",
                                PrintDetails[0].ConfigName,
                                PrintDetails[0].TransactionID,
                                boxHeight,
                                boxWidth,                                
                                53,
                                59,
                                PrintDetails[0].PrintMode,
                                PrintDetails[0].DetailItemPerPage,
                                PrintDetails[0].ContinuesPaper,
                                0,
                                PrintDetails[0].FooterOnEP,
                                PrintDetails[0].PaperType,
                                "mm",
                                PrintDetails[0].BodyLineSpace,
                                PrintDetails[0].LineFeed,
                                PrintDetails[0].IncludeCut,
                                0,
                                PrintDetails[0].UserID, tvpPrintConfigDetail);
                if(dtResult.Columns.Count > 1)
                {
                    bl.bl_Transaction(3);
                    savemsg.Add(new SaveMessage()
                    {
                        ID = 0.ToString(),
                        MsgID = "1",
                        Message = dtResult.Rows[0][0].ToString(),
                    });
                }
                else
                {
                    savemsg.Add(new SaveMessage()
                    {
                        ID = dtResult.Rows[0][0].ToString(),
                        MsgID = "0",
                        Message = "Saved Successfully",
                    });
                    bl.bl_Transaction(2);
                }
                

                return Ok(savemsg);
            }
            catch (Exception ex)
            {
                return InternalServerError(ex);
            }
        }
        [HttpGet]
        [Route("api/printcustomize/getcontrols")]
        public IHttpActionResult GetPaperControls(int PrintID)
        {
            List<PrintConfigModel> objlist = new List<PrintConfigModel>();
            List<PrintCustomizeModel> list = new List<PrintCustomizeModel>();
            try
            {
                DataSet dtPrintDetails = bl.BL_ExecuteParamSPDataset("uspGetSetPrintConfig", 1, 0, PrintID);
               
                
                DataTable dtResult = dtPrintDetails.Tables[1];
                for (int i = 0; i < dtResult.Rows.Count; i++)
                {
                    string ControlName = dtResult.Rows[i]["ctrlName"].ToString();
                    string SoruceName = dtResult.Rows[i]["SourceName"].ToString();
                    string AlignID = dtResult.Rows[i]["Align"].ToString();
                    string base64ImageWithPrefix = null;
                    if (ControlName == "Image")
                    {
                        byte[] imageBytes = (byte[])dtResult.Rows[i]["ImageSource"];
                        base64ImageWithPrefix = "data:image/jpeg;base64," + Convert.ToBase64String(imageBytes);
                    }
                    list.Add(new PrintCustomizeModel
                    {
                        PaperID = dtResult.Rows[i]["PrintID"].ToString(),// reader["PaperID"] != DBNull.Value ? Convert.ToInt32(reader["PaperID"]) : (int?)null,
                        ControlType = ControlName == "V_Line" || ControlName == "H_Line" ? ControlName : SoruceName,// reader["ControlType"].ToString(),
                        X = dtResult.Rows[i]["ctrlXposition"].ToString(),// Convert.ToInt32(reader["X"]),
                        Y = dtResult.Rows[i]["ctrlYposition"].ToString(),// Convert.ToInt32(reader["Y"]),
                        Width = dtResult.Rows[i]["ctrlWidth"].ToString(),// Convert.ToInt32(reader["Width"]),
                        Height = dtResult.Rows[i]["ctrlHeight"].ToString(),// Convert.ToInt32(reader["Height"]),
                        Rotation = "0",// reader["Rotation"] != DBNull.Value ? Convert.ToSingle(reader["Rotation"]) : 0,
                        FontFamily = dtResult.Rows[i]["FontName"].ToString(),// reader["FontFamily"]?.ToString(),
                        FontSize = !string.IsNullOrEmpty(dtResult.Rows[i]["FontSize"].ToString()) ? dtResult.Rows[i]["FontSize"].ToString() + "px" : "9px",// reader["FontSize"]?.ToString(),
                        FontWeight = null,// reader["FontWeight"]?.ToString(),
                        FontStyle = null,// reader["FontStyle"]?.ToString(),
                        TextValue = ControlName,// reader["TextValue"]?.ToString(),
                        ImageData = base64ImageWithPrefix,// reader["ImageData"]?.ToString()
                        Alignment = !string.IsNullOrEmpty(AlignID) ? AlignID == "0" ? "left" : AlignID == "1" ? "right" : "denter" : "left",
                        IsFooter = dtResult.Rows[i]["Footer"].ToString(),
                        Bold = dtResult.Rows[i]["Bold"].ToString(),
                        Italic = dtResult.Rows[i]["Italic"].ToString(),
                        Underline = dtResult.Rows[i]["Underline"].ToString(),
                        Fontcolor = dtResult.Rows[i]["FontColor"].ToString(),
                        Wraptext = dtResult.Rows[i]["WrapText"].ToString(),
                        PlaceType = dtResult.Rows[i]["Type"].ToString(),
                        SourceName = dtResult.Rows[i]["SourceName"].ToString(),
                        QRText = dtResult.Rows[i]["QRCodeValue"].ToString(),
                    });
                }
                DataTable dtHeader = dtPrintDetails.Tables[0];
                if (dtHeader.Rows.Count > 0)
                {
                    objlist.Add(new PrintConfigModel()
                    {
                        PrintID = dtHeader.Rows[0]["PrintID"].ToString(),
                        ConfigName = dtHeader.Rows[0]["ConfigName"].ToString(),
                        TransactionID = dtHeader.Rows[0]["TransactionID"].ToString(),
                        BoxW = dtHeader.Rows[0]["BoxW"].ToString(),
                        BoxH = dtHeader.Rows[0]["BoxH"].ToString(),
                        BoxX = dtHeader.Rows[0]["BoxX"].ToString(),
                        BoxY = dtHeader.Rows[0]["BoxY"].ToString(),
                        PrintMode = dtHeader.Rows[0]["PrintMode"].ToString(),
                        DetailItemPerPage = dtHeader.Rows[0]["DetailItemPerPage"].ToString(),
                        ContinuesPaper = dtHeader.Rows[0]["ContinuesPaper"].ToString(),
                        HeaderOnEP = dtHeader.Rows[0]["HeaderOnEP"].ToString(),
                        FooterOnEP = dtHeader.Rows[0]["FooterOnEP"].ToString(),
                        PaperType = dtHeader.Rows[0]["PaperType"].ToString(),
                        PaperSizeType = dtHeader.Rows[0]["PaperSizeType"].ToString(),                        
                        BodyLineSpace = dtHeader.Rows[0]["BodyLineSpace"].ToString(),
                        LineFeed = dtHeader.Rows[0]["LineFeed"].ToString(),
                        IncludeCut = dtHeader.Rows[0]["IncludeCut"].ToString(),
                        WebPrint = dtHeader.Rows[0]["WebPrint"].ToString(),
                        PaperTypeID = dtHeader.Rows[0]["PaperTypeID"].ToString(),
                        Height = dtHeader.Rows[0]["Height"].ToString(),
                        Width = dtHeader.Rows[0]["Width"].ToString(),
                        PrintConfigDeatils = list
                    });
                }
                return Ok(objlist);
            }
            catch (Exception ex)
            {
                return InternalServerError(ex);
            }
        }
        [HttpGet]
        [Route("api/printcustomize/transactioncontrols")]
        public IHttpActionResult GettransactionControls(int TransID)
        {
            var Controls = new List<object>();
            var HeaderControls = new List<object>();
            var BodyControls = new List<object>();
            var FooterControls = new List<object>();
            DataTable dtTrans = bl.BL_ExecuteParamSP("uspGetSetPrintConfig", 2, TransID, 0);
            if (dtTrans.Rows.Count > 0)
            {
                string HeaderProc = dtTrans.Rows[0]["Header"].ToString();
                string BodyProc = dtTrans.Rows[0]["Body"].ToString();
                string FooterProc = dtTrans.Rows[0]["SpecialField"].ToString();
                DataTable dtHeader = bl.BL_ExecuteParamSP(HeaderProc);
                for (int i = 0; i < dtHeader.Columns.Count; i++)
                {
                    HeaderControls.Add(new
                    {
                        ControlName = dtHeader.Columns[i].ColumnName,
                    });
                }
                DataTable dtBody = bl.BL_ExecuteParamSP(BodyProc);
                for (int i = 0; i < dtBody.Columns.Count; i++)
                {
                    BodyControls.Add(new
                    {
                        ControlName = dtBody.Columns[i].ColumnName,
                    });
                }
                DataTable dtFooter = bl.BL_ExecuteParamSP(FooterProc);
                for (int i = 0; i < dtFooter.Columns.Count; i++)
                {
                    FooterControls.Add(new
                    {
                        ControlName = dtFooter.Columns[i].ColumnName,
                    });
                }
                Controls.Add(new
                {
                    Header = HeaderControls,
                    Body = BodyControls,
                    Footer = FooterControls,
                });
                return Ok(Controls);
            }
            return Ok();
        }

        [HttpGet]
        [Route("api/printcustomize/initialDatas")]
        public IHttpActionResult GetinitialDatas()
        {
            var InitialData = new List<object>();
            var objPrintPaper = new List<object>();
            var objTransNames = new List<object>();
            var objConfigNames = new List<object>();
            var objFontNames = new List<object>();
            DataSet dtTrans = bl.BL_ExecuteParamSPDataset("uspGetSetPrintConfig", 3);
            if (dtTrans.Tables.Count > 0)
            {
                DataTable dtPrintPaper = dtTrans.Tables[0];
                DataTable dtTransNames = dtTrans.Tables[1];
                DataTable dtConfigNames = dtTrans.Tables[2];

                for (int i = 0; i < dtPrintPaper.Rows.Count; i++)
                {
                    objPrintPaper.Add(new
                    {
                        ID = dtPrintPaper.Rows[i]["Id"].ToString(),
                        PaperSize = dtPrintPaper.Rows[i]["PaperSize"].ToString(),
                        Width = dtPrintPaper.Rows[i]["Width"].ToString(),
                        Height = dtPrintPaper.Rows[i]["Height"].ToString(),
                    });
                }

                for (int i = 0; i < dtTransNames.Rows.Count; i++)
                {
                    objTransNames.Add(new
                    {
                        ID = dtTransNames.Rows[i]["Id"].ToString(),
                        TransName = dtTransNames.Rows[i]["TransName"].ToString(),
                    });
                }
                for (int i = 0; i < dtConfigNames.Rows.Count; i++)
                {
                    objConfigNames.Add(new
                    {
                        PrintID = dtConfigNames.Rows[i]["PrintID"].ToString(),
                        ConfigName = dtConfigNames.Rows[i]["ConfigName"].ToString(),
                        TransactionID = dtConfigNames.Rows[i]["TransactionID"].ToString(),
                    });
                }

                int FID = 1;
                foreach (FontFamily font in System.Drawing.FontFamily.Families)
                {
                    if (font.IsStyleAvailable(FontStyle.Regular))
                    {
                        objFontNames.Add(new
                        {
                            ID = FID++,
                            FontName = font.Name
                        });
                    }
                }
                InitialData.Add(new
                {
                    PrintPaper = objPrintPaper,
                    TransNames = objTransNames,
                    ConfigNames = objConfigNames,
                    FontNames = objFontNames,
                });
                return Ok(InitialData);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/printcustomize/renameprofile")]
        public IHttpActionResult RenameProfile(string TransID, string ConfigID,string NewProfileName)
        {
            DataTable dtTrans = bl.BL_ExecuteParamSP("uspGetSetPrintConfig", 4, TransID, ConfigID, NewProfileName);
            if(dtTrans.Rows.Count > 0)
            {
                return Ok(dtTrans.Rows[0][0]);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/printcustomize/deleteprofile")]
        public IHttpActionResult DeleteProfile(string ConfigID)
        {
            DataTable dtTrans = bl.BL_ExecuteParamSP("uspGetSetPrintConfig", 5, 0, ConfigID);
            return Ok(dtTrans.Rows[0][0]);
        }
        [HttpGet]
        [Route("api/printcustomize/profilescript")]
        public HttpResponseMessage GetreportscriptData(string ConfigID, string ConfigName)
        {
            string strAppStartPath = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"] + "\\Print_Script_Data\\";
            if (!Directory.Exists(strAppStartPath))
            {
                Directory.CreateDirectory(strAppStartPath);
            }
            string strFileName = ConfigName + "_" + DateTime.Now.ToString("yyyymmddhhmmss") + ".txt";
            using (StreamWriter sw = System.IO.File.CreateText(System.IO.Path.Combine(strAppStartPath, strFileName)))
            {
                DataTable dt = new DataTable();
                dt = bl.BL_ExecuteParamSP("uspGetScriptPrintConfig", ConfigID);
                if (dt.Rows.Count > 0)
                {
                    for (int iRow = 0; iRow < dt.Rows.Count; iRow++)
                    {
                        sw.WriteLine(Convert.ToString(dt.Rows[iRow][0]).Trim());
                    }
                    sw.WriteLine("");
                }
            }
            Type officeType = Type.GetTypeFromProgID("Excel.Application");
            var sDocument = System.IO.Path.Combine(strAppStartPath, strFileName);
            byte[] fileBytes = System.IO.File.ReadAllBytes(sDocument);
            //return File(fileBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
            if (!System.IO.File.Exists(System.IO.Path.Combine(strAppStartPath, strFileName)))
                return new HttpResponseMessage(HttpStatusCode.NotFound);

            var result = new HttpResponseMessage(HttpStatusCode.OK);
            var stream = new FileStream(System.IO.Path.Combine(strAppStartPath, strFileName), FileMode.Open, FileAccess.Read);
            result.Content = new StreamContent(stream);
            result.Content.Headers.ContentType = new MediaTypeHeaderValue("text/plain");
            result.Content.Headers.ContentDisposition = new ContentDispositionHeaderValue("attachment")
            {
                FileName = strFileName
            };
            return result;
        }
    }
}
