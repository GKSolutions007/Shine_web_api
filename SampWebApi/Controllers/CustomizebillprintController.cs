using ClosedXML.Excel;
using DocumentFormat.OpenXml.Office2016.Drawing.ChartDrawing;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Spreadsheet;
using iTextSharp.text;
using iTextSharp.text.pdf;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.AccessControl;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Http;
using System.Windows.Forms;
using System.Xml.Linq;
using static System.Windows.Forms.VisualStyles.VisualStyleElement.TreeView;
using Rectangle = iTextSharp.text.Rectangle;

namespace SampWebApi.Controllers
{
    public class CustomizebillprintController : ApiController
    {
        clsBusinessLayer objBL = new clsBusinessLayer();
        public string strSheetName { get; set; }
        public string strExtension = ".xlsx";
        public string strFileName = "";
        public string strFilePath
        {
            get; set;
        }
        public DataTable dtData { get; set; }
        public DataTable dtHeaderData { get; set; }
        public DataTable dtItemsData { get; set; }
        [System.Web.Http.HttpPost]
        [System.Web.Http.Route("api/uploadcustomizebillfile")]
        public IHttpActionResult TransactionFiledata()
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
                    string UserID = HttpContext.Current.Request.Files.AllKeys[0].ToString();
                    string fileName = HttpContext.Current.Request.Files[1].FileName;
                    string fileContentType = HttpContext.Current.Request.Files[1].ContentType;
                    //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Upload Files\\";
                    string FPt = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"];
                    strFilePath = FPt + "Upload Files\\";
                    strFileName = "Upload_" + fileName;
                    if (!Directory.Exists(strFilePath))
                    {
                        Directory.CreateDirectory(strFilePath);
                    }
                    HttpContext.Current.Request.Files[1].SaveAs(strFilePath + strFileName);
                    bool blHeaderResult = true, blItemsResult = true;
                    List<string> lstHeader = null;
                    List<string> lstItems = null;

                    #region Header Validation
                    bool HeaderErrorColAlreadyExists = false;
                    lstHeader = CustomBillPrintHeaderTemp();
                    TransactionColumnValidation(lstHeader, "Header", ref blHeaderResult);
                    if (!blHeaderResult)
                    {
                        lstHeader = CustomBillPrintHeaderTempwWithError();                        
                        TransactionColumnValidation(lstHeader, "Header", ref blHeaderResult);
                        HeaderErrorColAlreadyExists = true;
                    }
                    #endregion
                    #region Items Validation
                    bool ItemsErrorColAlreadyExists = false;
                    lstItems = CustomBillPrintItemsTemp();
                    TransactionColumnValidation(lstItems, "Items", ref blItemsResult);
                    if (!blItemsResult)
                    {
                        lstItems = CustomBillPrintItemsTempWithError();
                        TransactionColumnValidation(lstItems, "Items", ref blItemsResult);
                        ItemsErrorColAlreadyExists = true;
                    }
                    #endregion
                    if (blHeaderResult && blItemsResult)
                    {
                        DataTable dtHeaderCorrectValues = new DataTable();
                        DataTable dtHeaderWrongValues = new DataTable();
                        foreach (string str in lstHeader)
                        {
                            dtHeaderCorrectValues.Columns.Add(str);
                            dtHeaderWrongValues.Columns.Add(str);
                        }
                        
                        if (!HeaderErrorColAlreadyExists)
                        {
                            dtHeaderCorrectValues.Columns.Add("Error");
                            dtHeaderWrongValues.Columns.Add("Error");
                        }
                        DataTable dtItemsCorrectValues = new DataTable();
                        DataTable dtItemsWrongValues = new DataTable();
                        foreach (string str in lstItems)
                        {
                            dtItemsCorrectValues.Columns.Add(str);
                            dtItemsWrongValues.Columns.Add(str);
                        }
                        
                        if (!ItemsErrorColAlreadyExists)
                        {
                            dtItemsCorrectValues.Columns.Add("Error");
                            dtItemsWrongValues.Columns.Add("Error");
                        }
                        if (dtHeaderData.Rows.Count > 0 && dtItemsData.Rows.Count > 0)
                        {
                            int nIndex = 1;
                            bool NoErrorsinHeader = true, NoErrorsinItems = true;
                            foreach (DataRow item in dtHeaderData.Rows)
                            {
                                DataTable dtValidate = dtHeaderData.Clone();
                                dtValidate.TableName = "Validation";
                                dtValidate.Rows.Add(item.ItemArray);
                                string RowError = HeaderValiation(dtValidate);
                                if (string.IsNullOrEmpty(RowError))
                                {
                                    DataRow drW = dtHeaderWrongValues.NewRow();
                                    drW["Company Name"] = item.ItemArray[0];
                                    drW["Billing Address 1"] = item.ItemArray[1];
                                    drW["Billing Address 2"] = item.ItemArray[2];
                                    drW["Billing Address 3"] = item.ItemArray[3];
                                    drW["Mobile No"] = item.ItemArray[4];
                                    drW["GSTIN"] = item.ItemArray[5];
                                    drW["Doc ID"] = item.ItemArray[6];
                                    drW["Date"] = item.ItemArray[7];
                                    drW["Party Name"] = item.ItemArray[8];
                                    drW["Party Billing Address 1"] = item.ItemArray[9];
                                    drW["Party Billing Address 2"] = item.ItemArray[10];
                                    drW["Party Billing Address 3"] = item.ItemArray[11];
                                    drW["Party GSTIN"] = item.ItemArray[12];
                                    drW["Error"] = RowError;
                                    dtHeaderWrongValues.Rows.Add(drW);

                                    DataRow drC = dtHeaderCorrectValues.NewRow();
                                    drC["Company Name"] = item.ItemArray[0];
                                    drC["Billing Address 1"] = item.ItemArray[1];
                                    drC["Billing Address 2"] = item.ItemArray[2];
                                    drC["Billing Address 3"] = item.ItemArray[3];
                                    drC["Mobile No"] = item.ItemArray[4];
                                    drC["GSTIN"] = item.ItemArray[5];
                                    drC["Doc ID"] = item.ItemArray[6];
                                    drC["Date"] = item.ItemArray[7];
                                    drC["Party Name"] = item.ItemArray[8];
                                    drC["Party Billing Address 1"] = item.ItemArray[9];
                                    drC["Party Billing Address 2"] = item.ItemArray[10];
                                    drC["Party Billing Address 3"] = item.ItemArray[11];
                                    drC["Party GSTIN"] = item.ItemArray[12];
                                    drC["Error"] = RowError;
                                    dtHeaderCorrectValues.Rows.Add(drC);
                                }
                                else
                                {
                                    NoErrorsinHeader = false;
                                    DataRow drW = dtHeaderWrongValues.NewRow();
                                    drW["Company Name"] = item.ItemArray[0];
                                    drW["Billing Address 1"] = item.ItemArray[1];
                                    drW["Billing Address 2"] = item.ItemArray[2];
                                    drW["Billing Address 3"] = item.ItemArray[3];
                                    drW["Mobile No"] = item.ItemArray[4];
                                    drW["GSTIN"] = item.ItemArray[5];
                                    drW["Doc ID"] = item.ItemArray[6];
                                    drW["Date"] = item.ItemArray[7];
                                    drW["Party Name"] = item.ItemArray[8];
                                    drW["Party Billing Address 1"] = item.ItemArray[9];
                                    drW["Party Billing Address 2"] = item.ItemArray[10];
                                    drW["Party Billing Address 3"] = item.ItemArray[11];
                                    drW["Party GSTIN"] = item.ItemArray[12];
                                    drW["Error"] = RowError;
                                    dtHeaderWrongValues.Rows.Add(drW);
                                }
                            }
                            foreach (DataRow item in dtItemsData.Rows)
                            {
                                DataTable dtValidate = dtItemsData.Clone();
                                dtValidate.TableName = "Validation";
                                dtValidate.Rows.Add(item.ItemArray);
                                string RowError = ItemsValiation(dtValidate);
                                if (string.IsNullOrEmpty(RowError))
                                {
                                    DataRow drW = dtItemsWrongValues.NewRow();
                                    drW["Doc ID"] = item.ItemArray[0];
                                    drW["Product Name"] = item.ItemArray[1];
                                    drW["HSN"] = item.ItemArray[2];
                                    drW["MRP"] = !string.IsNullOrEmpty(item.ItemArray[3].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[3]), 2).ToString("F2"))  : "0.00";
                                    drW["Price"] = !string.IsNullOrEmpty(item.ItemArray[4].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[4]), 2).ToString("F2")) : "0.00"; //item.ItemArray[4];
                                    drW["Qty"] = !string.IsNullOrEmpty(item.ItemArray[5].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[5]), 2).ToString("F2")) : "0.00"; //item.ItemArray[5];
                                    drW["Discount Amount"] = !string.IsNullOrEmpty(item.ItemArray[6].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[6]), 2).ToString("F2")) : "0.00"; //item.ItemArray[6];
                                    drW["Tax Name"] = item.ItemArray[7];
                                    drW["Tax Amount"] = !string.IsNullOrEmpty(item.ItemArray[8].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[8]), 2).ToString("F2")) : "0.00"; //item.ItemArray[8];                                    
                                    drW["Net Amount"] = !string.IsNullOrEmpty(item.ItemArray[9].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[9]), 2).ToString("F2")) : "0.00";  //item.ItemArray[9];
                                    drW["Error"] = RowError;
                                    dtItemsWrongValues.Rows.Add(drW);

                                    DataRow drC = dtItemsCorrectValues.NewRow();
                                    drC["Doc ID"] = item.ItemArray[0];
                                    drC["Product Name"] = item.ItemArray[1];
                                    drC["HSN"] = item.ItemArray[2];
                                    drC["MRP"] = !string.IsNullOrEmpty(item.ItemArray[3].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[3]), 2).ToString("F2")) : "0.00";
                                    drC["Price"] = !string.IsNullOrEmpty(item.ItemArray[4].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[4]), 2).ToString("F2")) : "0.00"; //item.ItemArray[4];
                                    drC["Qty"] = !string.IsNullOrEmpty(item.ItemArray[5].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[5]), 2).ToString("F2")) : "0.00"; //item.ItemArray[5];
                                    drC["Discount Amount"] = !string.IsNullOrEmpty(item.ItemArray[6].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[6]), 2).ToString("F2")) : "0.00"; //item.ItemArray[6];
                                    drC["Tax Name"] = item.ItemArray[7];
                                    drC["Tax Amount"] = !string.IsNullOrEmpty(item.ItemArray[8].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[8]), 2).ToString("F2")) : "0.00"; //item.ItemArray[8];                                    
                                    drC["Net Amount"] = !string.IsNullOrEmpty(item.ItemArray[9].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[9]), 2).ToString("F2")) : "0.00";  //item.ItemArray[9];
                                    drC["Error"] = RowError;
                                    dtItemsCorrectValues.Rows.Add(drC);
                                }
                                else
                                {
                                    NoErrorsinItems = false;
                                    DataRow drW = dtItemsWrongValues.NewRow();
                                    drW["Doc ID"] = item.ItemArray[0];
                                    drW["Product Name"] = item.ItemArray[1];
                                    drW["HSN"] = item.ItemArray[2];
                                    drW["MRP"] = !string.IsNullOrEmpty(item.ItemArray[3].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[3]), 2).ToString("F2")) : "0.00";
                                    drW["Price"] = !string.IsNullOrEmpty(item.ItemArray[4].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[4]), 2).ToString("F2")) : "0.00"; //item.ItemArray[4];
                                    drW["Qty"] = !string.IsNullOrEmpty(item.ItemArray[5].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[5]), 2).ToString("F2")) : "0.00"; //item.ItemArray[5];
                                    drW["Discount Amount"] = !string.IsNullOrEmpty(item.ItemArray[6].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[6]), 2).ToString("F2")) : "0.00"; //item.ItemArray[6];
                                    drW["Tax Name"] = item.ItemArray[7];
                                    drW["Tax Amount"] = !string.IsNullOrEmpty(item.ItemArray[8].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[8]), 2).ToString("F2")) : "0.00"; //item.ItemArray[8];                                    
                                    drW["Net Amount"] = !string.IsNullOrEmpty(item.ItemArray[9].ToString()) ? Convert.ToString(Math.Round(Convert.ToDouble(item.ItemArray[9]), 2).ToString("F2")) : "0.00";  //item.ItemArray[9];
                                    drW["Error"] = RowError;
                                    dtItemsWrongValues.Rows.Add(drW);
                                }
                            }
                            if (NoErrorsinHeader && NoErrorsinItems)
                            {
                                dtHeaderCorrectValues.Columns.Remove("Error");
                                dtItemsCorrectValues.Columns.Remove("Error");
                                dtHeaderData = dtHeaderCorrectValues;
                                dtItemsData = dtItemsWrongValues;
                                strFilePath = FPt + "Upload Files\\TempGroupPDF\\";
                                for (int i = 0; i < dtHeaderData.Rows.Count; i++)
                                {
                                    string DocID = dtHeaderData.Rows[i]["Doc ID"].ToString();

                                    DataRow[] DRRHeaders = dtHeaderData.Select("[Doc ID] = '" + DocID + "'");
                                    DataRow[] DRRItems = dtItemsData.Select("[Doc ID] = '" + DocID + "'");
                                    if (DRRHeaders.Length > 0 && DRRItems.Length > 0)
                                    {
                                        DataTable dtHead = DRRHeaders.CopyToDataTable();
                                        DataTable dtItems = DRRItems.CopyToDataTable();
                                        dt = DocID;
                                        if (DocID.Contains('/'))
                                        {
                                            strFileName = DocID.Replace('/', '_') + ".pdf";
                                        }
                                        else
                                        {
                                            strFileName = DocID + ".pdf";
                                        }
                                        DCSExportPdf(dtHead, dtItems);
                                    }
                                }
                                string destPath = FPt + "Upload Files\\Customize Print PDF\\";
                                string destFileName = "BillPrint_" + DateTime.Now.ToString("yyyyMMddHHmmss") + ".pdf";
                                if (!Directory.Exists(destPath))
                                {
                                    Directory.CreateDirectory(destPath);
                                }
                                MergePDFFiles(strFilePath, destPath + destFileName);
                                if (Directory.Exists(strFilePath))
                                {
                                    Directory.Delete(strFilePath, true); // true = delete subfolders & files
                                }
                                MTM.Add(new ImportResults()
                                {
                                    ID = "0",
                                    Msg = "Document Created Successfully.",
                                    FileName = destFileName,
                                    FilePath = destPath + destFileName,
                                });                                
                            }
                            else
                            {
                                //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Error Files\\";
                                strFilePath = FPt + "Error Files\\";
                                strFileName = "CustomiziBill_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                //strSheetName = "Data";
                                ExportToExcelTwoSheet(dtHeaderWrongValues, "Header", dtItemsWrongValues, "Items");
                                MTM.Add(new ImportResults()
                                {
                                    ID = "1",
                                    Msg = "Data Not Saved. Error occured in some documents. See error list in downloads.",
                                    FileName = strFileName + strExtension,
                                    FilePath = strFilePath + strFileName + strExtension,
                                    Total = Convert.ToString(dtHeaderWrongValues.Rows.Count),
                                    Saved = Convert.ToString(dtHeaderCorrectValues.Rows.Count),
                                    UnSaved = Convert.ToString(dtHeaderWrongValues.Rows.Count),
                                });
                            }
                            return Ok(MTM);
                        }
                        else
                        {
                            if (dtHeaderData.Rows.Count == 0 && dtItemsData.Rows.Count == 0)
                            {
                                Msg = "0.1";// no records found in both sheet;
                            }
                            else if (dtHeaderData.Rows.Count == 0)
                            {
                                Msg = "0.2";// no records found in Header sheet;
                            }
                            else if (dtItemsData.Rows.Count == 0)
                            {
                                Msg = "0.3";// no records found in Items sheet;
                            }
                        }
                    }
                    else
                    {
                        if (!blHeaderResult && !blItemsResult)
                        {
                            Msg = "21";// Header and Items column names mismatching
                        }
                        else if (!blHeaderResult)
                        {
                            Msg = "22";// Header column names mismatching
                        }
                        else if (!blItemsResult)
                        {
                            Msg = "23";// Items column names mismatching
                        }
                    }
                }
                else
                {
                    Msg = "1";// file not choosing
                }
            }
            catch (Exception ex)
            {
                MTM.Add(new ImportResults()
                {
                    ID = "2",
                    Msg = ex.Message + " Inv No : " + dt,
                });
                return Ok(MTM);
            }
            return Ok(Msg);
        }
        public string HeaderValiation(DataTable dtCheck)
        {
            string RowError = "";
            return RowError;
        }
        public string ItemsValiation(DataTable dtCheck)
        {
            string RowError = "";
            //"MRP","Price","Qty","Discount Amount","Tax Name","Tax Amount","Net Amount"
            decimal Price = 0, Qty = 0, DiscAmt = 0, TaxAmt = 0, NetAmt = 0;
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Doc ID"].ToString()))
            {
                RowError += "Doc ID : Doc ID should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["MRP"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["MRP"].ToString()))
                {
                    RowError += "MRP : Invalid character(Numeric Only)\n";
                }                
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Price"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Price"].ToString()))
                {
                    RowError += "MRP : Invalid character(Numeric Only)\n";
                }
                else
                {
                    Price = objBL.BL_dValidation(dtCheck.Rows[0]["Price"].ToString());
                }
            }
            else
            {
                Price = 0;
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Qty"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Qty"].ToString()))
                {
                    RowError += "Qty : Invalid character(Numeric Only)\n";
                }
                else
                {
                    Qty = objBL.BL_dValidation(dtCheck.Rows[0]["Qty"].ToString());
                }
            }
            else
            {
                Qty = 0;
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Discount Amount"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Discount Amount"].ToString()))
                {
                    RowError += "Discount Amount : Invalid character(Numeric Only)\n";
                }
                else
                {
                    DiscAmt = objBL.BL_dValidation(dtCheck.Rows[0]["Discount Amount"].ToString());
                }
            }
            else
            {
                DiscAmt = 0;
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Tax Amount"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Tax Amount"].ToString()))
                {
                    RowError += "Tax Amount : Invalid character(Numeric Only)\n";
                }
                else
                {
                    TaxAmt = objBL.BL_dValidation(dtCheck.Rows[0]["Tax Amount"].ToString());
                }
            }
            else
            {
                TaxAmt = 0;
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Net Amount"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Net Amount"].ToString()))
                {
                    RowError += "Net Amount : Invalid character(Numeric Only)\n";
                }
                else
                {
                    NetAmt = objBL.BL_dValidation(dtCheck.Rows[0]["Net Amount"].ToString());
                }
            }
            else
            {
                NetAmt = 0;
            }
            decimal TaxPern = objBL.BL_dValidation(Regex.Match(dtCheck.Rows[0]["Tax Name"].ToString(), @"\d+").Value);
            decimal GrossAmt = ((Qty * Price) - DiscAmt);
            decimal SumofNetAmt = GrossAmt * (1 + (TaxPern / 100));
            decimal Round2SumofNetAmt = Math.Round(SumofNetAmt, 2);
            decimal Round2NetAmt = Math.Round(NetAmt, 2);
            decimal Rount2Qty = Math.Round(Qty, 2);
            decimal Rount2Price = Math.Round(Price, 2);
            decimal Rount2DiscAmt = Math.Round(DiscAmt, 2);
            decimal Rount2TaxAmt = Math.Round(TaxAmt, 2);
            if (Math.Abs(Round2SumofNetAmt - Round2NetAmt) > 1) //if (Round2SumofNetAmt != Round2NetAmt)
            {
                string strFormula = "(" + Rount2Qty + " * " + Rount2Price + ")" + " + " + Rount2TaxAmt + " = "+ Round2SumofNetAmt;
                RowError = "Amount mismatch. Sum of product value[" + Round2SumofNetAmt + "] and Net Amount[" + Round2NetAmt + "] mismatched";
            }
            return RowError;
        }
        static void MergePDFFiles(string folderPath, string destinationFile)
        {
            string[] pdfFiles = Directory.GetFiles(folderPath, "*.pdf");

            using (FileStream stream = new FileStream(destinationFile, FileMode.Create))
            using (Document doc = new Document())
            using (PdfCopy pdf = new PdfCopy(doc, stream))
            {
                doc.Open();
                foreach (string file in pdfFiles)
                {
                    using (PdfReader reader = new PdfReader(file))
                    {
                        for (int i = 1; i <= reader.NumberOfPages; i++)
                        {
                            pdf.AddPage(pdf.GetImportedPage(reader, i));
                        }
                    }
                }
            }
        }
        [System.Web.Http.HttpGet]
        [System.Web.Http.Route("api/customizebilltemplate")]
        public HttpResponseMessage OpenTemplate()
        {
            List<string> strHeaders = CustomBillPrintHeaderTemp();
            List<string> strItems = CustomBillPrintItemsTemp();
            DataTable dtHeaders = new DataTable();
            DataTable dtItems = new DataTable();            
            string FPt = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"];
            //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "\\Export Data\\";
            strFilePath = FPt + "\\Export Data\\";
            strFileName = "CustomizeBillTemplate_" + DateTime.Now.ToString("yyyyMMddHHmmss");
            foreach (string strHeaderName in strHeaders)
            {
                dtHeaders.Columns.Add(strHeaderName, typeof(string));
            }
            foreach (string strItemsName in strItems)
            {
                dtItems.Columns.Add(strItemsName, typeof(string));
            }
            ExportToExcelTwoSheet(dtHeaders, "Header", dtItems, "Items");
            var sDocument = strFilePath + strFileName + strExtension;
            byte[] fileBytes = System.IO.File.ReadAllBytes(sDocument);
            string fileName = strFileName + strExtension;
            //return File(fileBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
            if (!File.Exists(strFilePath + strFileName + strExtension))
                return new HttpResponseMessage(HttpStatusCode.NotFound);

            var result = new HttpResponseMessage(HttpStatusCode.OK);
            var stream = new FileStream(strFilePath + strFileName + strExtension, FileMode.Open, FileAccess.Read);
            result.Content = new StreamContent(stream);
            result.Content.Headers.ContentType = new MediaTypeHeaderValue("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
            result.Content.Headers.ContentDisposition = new ContentDispositionHeaderValue("attachment")
            {
                FileName = fileName
            };
            return result;
        }
        public void ExportToExcelTwoSheet(DataTable DtDataSheet1, string Sheet1Name, DataTable DtDataSheet2, string Sheet2Name)
        {
            try
            {
                //Exporting to Excel
                if (!Directory.Exists(strFilePath))
                {
                    Directory.CreateDirectory(strFilePath);
                }
                using (XLWorkbook wb = new XLWorkbook())
                {
                    Int32 len = Sheet1Name.Length;
                    wb.Worksheets.Add(DtDataSheet1, Sheet1Name.Substring(0, len).Trim());
                    len = Sheet2Name.Length;
                    wb.Worksheets.Add(DtDataSheet2, Sheet2Name.Substring(0, len).Trim());
                    wb.SaveAs(strFilePath + strFileName + strExtension);
                }
            }
            catch (IOException ex)
            {
                objBL.BL_WriteErrorMsginLog("Import Export", "ExportToExcelTwoSheet", ex.Message);
            }
            catch (Exception ex)
            {
                objBL.BL_WriteErrorMsginLog("Import Export", "ExportToExcelTwoSheet 1", ex.Message);
                throw;
            }
        }
        public void TransactionColumnValidation(List<string> lst, string sSheetName, ref bool blResult)
        {
            try
            {
                blResult = true;
                List<string> lstdtColumn = new List<string>();
                string ffp = strFilePath + strFileName;
                SpreadsheetDocument docSelected = SpreadsheetDocument.Open(strFilePath + strFileName, false);
                IEnumerable<Sheet> AllSheet = docSelected.WorkbookPart.Workbook.Descendants<Sheet>();
                strSheetName = sSheetName;
                Sheet sCurrent = GetSelectedSheet(AllSheet);
                if (sCurrent != null)
                {
                    Worksheet worksheet = (docSelected.WorkbookPart.GetPartById(sCurrent.Id.Value) as WorksheetPart).Worksheet;
                    IEnumerable<Row> rows = worksheet.GetFirstChild<SheetData>().Descendants<Row>();
                    // Add Header Columns
                    foreach (Row row in rows)
                    {
                        if (row.RowIndex.Value == 1)
                        {
                            foreach (Cell cell in row.Descendants<Cell>())
                            {
                                lstdtColumn.Add(GetValue(docSelected, cell));
                            }
                        }
                        break;
                    }
                    // Verify Columns Count
                    if (lst.Count != lstdtColumn.Count)
                    {
                        blResult = false;
                    }
                    string ErrMsg = "";
                    // Verify Columns Names Are Same Or Not
                    foreach (string str in lst)
                    {
                        if (!lstdtColumn.Contains(str))
                        {
                            ErrMsg = str;
                            blResult = false;
                            break;
                        }
                    }
                    if (blResult)
                    {
                        GetTransactionDataRecords(docSelected, rows, sSheetName);
                        // Get the elapsed time as a TimeSpan value.
                    }
                    //docSelected.Close();
                }
            }
            catch (IOException)
            {

            }
            catch (Exception)
            {
                throw;
            }
        }
        public void GetTable(SpreadsheetDocument docSelected, IEnumerable<Row> rows)
        {
            DataTable dCheck = new DataTable();
            List<string> lstv = new List<string>();
            // Iterate Every Rows In Excel Sheet
            int TotalRowCount = rows.Count();

            decimal dRowFact = (decimal)TotalRowCount / 100;

            int TempRowCount = 0;

            foreach (Row row in rows)
            {
                if (row.RowIndex.Value == 1)
                {
                    foreach (Cell cell in row.Descendants<Cell>())
                    {
                        dCheck.Columns.Add(GetValue(docSelected, cell));
                        lstv.Add(Regex.Replace(cell.CellReference, @"[\d-]", string.Empty));
                    }
                }
                else
                {
                    dCheck.Rows.Add();
                    int nCount = 0, index = 0, TempCount;
                    foreach (Cell cell in row.Descendants<Cell>())
                    {
                        var vCellHeader = Regex.Replace(cell.CellReference, @"[\d-]", string.Empty);
                        var Temp = lstv[nCount];
                        if (lstv[nCount] != vCellHeader)
                        {
                            index = lstv.FindIndex(x => x.StartsWith(vCellHeader));
                            TempCount = nCount;
                            while (index > 0 && index > TempCount)
                            {
                                dCheck.Rows[dCheck.Rows.Count - 1][nCount] = null;
                                nCount++;
                                index--;
                            }
                        }
                        // Added By Sriram G
                        // Excel Cell Value Decimal Should be RoundOff 6 Digits
                        decimal dOutValue = 0.00M;
                        string strCellValue = GetValue(docSelected, cell);
                        //if (!string.IsNullOrEmpty(strCellValue))
                        //{
                        //    if (strCellValue.Contains('.'))
                        //    {
                        //        if (decimal.TryParse(strCellValue, out dOutValue))
                        //        {
                        //            strCellValue = Convert.ToString(Math.Round(Convert.ToDecimal(strCellValue), 6));
                        //        }
                        //    }
                        //}
                        dCheck.Rows[dCheck.Rows.Count - 1][nCount] = strCellValue;
                        nCount++;
                    }
                }

                TempRowCount++;
            }
            dtData = dCheck;
        }
        public void GetTransactionDataRecords(SpreadsheetDocument docSelected, IEnumerable<Row> rows, string HeaderorItems)
        {
            DataTable dCheck = new DataTable();
            List<string> lstv = new List<string>();
            // Iterate Every Rows In Excel Sheet
            int TotalRowCount = rows.Count();

            decimal dRowFact = (decimal)TotalRowCount / 100;

            int TempRowCount = 0;

            foreach (Row row in rows)
            {
                if (row.RowIndex.Value == 1)
                {
                    foreach (Cell cell in row.Descendants<Cell>())
                    {
                        dCheck.Columns.Add(GetValue(docSelected, cell));
                        lstv.Add(Regex.Replace(cell.CellReference, @"[\d-]", string.Empty));
                    }
                }
                else
                {
                    dCheck.Rows.Add();
                    int nCount = 0, index = 0, TempCount;
                    foreach (Cell cell in row.Descendants<Cell>())
                    {
                        var vCellHeader = Regex.Replace(cell.CellReference, @"[\d-]", string.Empty);
                        var Temp = lstv[nCount];
                        if (lstv[nCount] != vCellHeader)
                        {
                            index = lstv.FindIndex(x => x.StartsWith(vCellHeader));
                            TempCount = nCount;
                            while (index > 0 && index > TempCount)
                            {
                                dCheck.Rows[dCheck.Rows.Count - 1][nCount] = null;
                                nCount++;
                                index--;
                            }
                        }
                        // Added By Sriram G
                        // Excel Cell Value Decimal Should be RoundOff 6 Digits
                        decimal dOutValue = 0.00M;
                        string strCellValue = GetValue(docSelected, cell);
                        if (!string.IsNullOrEmpty(strCellValue))
                        {
                            if (strCellValue.Contains('.'))
                            {
                                if (decimal.TryParse(strCellValue, out dOutValue))
                                {
                                    strCellValue = Convert.ToString(Math.Round(Convert.ToDecimal(strCellValue), 6));
                                }
                            }
                        }
                        dCheck.Rows[dCheck.Rows.Count - 1][nCount] = strCellValue;
                        nCount++;
                    }
                }

                TempRowCount++;
            }
            if (HeaderorItems == "Header")//Header data
            {
                dtHeaderData = dCheck;
            }
            else//Items data
            {
                dtItemsData = dCheck;
            }
        }
        private string GetValue(SpreadsheetDocument doc, Cell cell)
        {
            try
            {
                if (cell.DataType != null && cell.DataType.Value == CellValues.SharedString)
                {
                    return doc.WorkbookPart.SharedStringTablePart.SharedStringTable.ChildElements[(int.Parse(cell.CellValue.InnerText))].InnerText;
                    return null;
                }
                else
                if (cell.StyleIndex != null)
                {
                    CellFormat cf = doc.WorkbookPart.WorkbookStylesPart.Stylesheet.CellFormats.ChildElements[int.Parse(cell.StyleIndex.InnerText)] as CellFormat;
                    if (cf.NumberFormatId == 14)
                    {
                        return DateTime.FromOADate(double.Parse(cell.CellValue.InnerText)).ToString("dd/MM/yyyy");
                    }
                    return cell.InnerText;
                }
                else
                {
                    return cell.InnerText;
                }
            }
            catch (NullReferenceException)
            {
                return null;
            }
            catch
            {
                throw;
            }
        }
        private Sheet GetSelectedSheet(IEnumerable<Sheet> Sheets)
        {
            foreach (Sheet sName in Sheets)
            {
                if (sName.Name == strSheetName)
                {
                    return sName;
                }
            }
            return null;
        }
        public static List<string> CustomBillPrintHeaderTemp()
        {
            return new List<string>()
            {
                "Company Name",
                "Billing Address 1",
                "Billing Address 2",
                "Billing Address 3",
                "Mobile No",
                "GSTIN",
                "Doc ID",
                "Date",
                "Party Name",
                "Party Billing Address 1",
                "Party Billing Address 2",
                "Party Billing Address 3",
                "Party Mobile No",
                "Party GSTIN"
            };
        }
        public static List<string> CustomBillPrintHeaderTempwWithError()
        {
            return new List<string>()
            {
                "Company Name",
                "Billing Address 1",
                "Billing Address 2",
                "Billing Address 3",
                "Mobile No",
                "GSTIN",
                "Doc ID",
                "Date",
                "Party Name",
                "Party Billing Address 1",
                "Party Billing Address 2",
                "Party Billing Address 3",
                "Party Mobile No",
                "Party GSTIN",
                "Error"
            };
        }
        public static List<string> CustomBillPrintItemsTemp()
        {
            return new List<string>()
            {
                "Doc ID",
                "Product Name",
                "HSN",
                "MRP",
                "Price",
                "Qty",
                "Discount Amount",
                "Tax Name",
                "Tax Amount",
                "Net Amount"
            };
        }
        public static List<string> CustomBillPrintItemsTempWithError()
        {
            return new List<string>()
            {
                "Doc ID",
                "Product Name",
                "HSN",
                "MRP",
                "Price",
                "Qty",
                "Discount Amount",
                "Tax Name",
                "Tax Amount",
                "Net Amount",
                "Error"
            };
        }
        public void DCSExportPdf(DataTable dtHeader,DataTable dtItems)
        {
            bool allHSNEmpty = !dtItems.AsEnumerable()
                               .Any(row => row["HSN"] != DBNull.Value
                                        && !string.IsNullOrWhiteSpace(row["HSN"].ToString()));
            if (allHSNEmpty)
            {
                dtItems.Columns.Remove("HSN");
            }
            //bool allDiscAmtEmpty = !dtItems.AsEnumerable()
            //                   .Any(row => row["Discount Amount"] != DBNull.Value
            //                            && !string.IsNullOrWhiteSpace(row["Discount Amount"].ToString()));
            bool allDiscAmtEmpty = !dtItems.AsEnumerable().Any(row => row["Discount Amount"] != DBNull.Value
             && decimal.TryParse(row["Discount Amount"].ToString(), out decimal val)
             && val > 0);
            if (allDiscAmtEmpty)
            {
                dtItems.Columns.Remove("Discount Amount");
            }
            PdfPTable pdfTableDocHeader = new PdfPTable(1);
            pdfTableDocHeader.DefaultCell.Padding = 3;
            pdfTableDocHeader.TotalWidth = PageSize.A4.Width;
            pdfTableDocHeader.LockedWidth = false;
            pdfTableDocHeader.HorizontalAlignment = Element.ALIGN_LEFT;
            pdfTableDocHeader.DefaultCell.BorderWidth = 0;
            float[] fCellWidthParam = new float[1] { PageSize.A4.Width };
            pdfTableDocHeader.SetWidths(fCellWidthParam);
            PdfPCell cellHead = new PdfPCell(new Phrase("TAX INVOICE", new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 9, 1, BaseColor.BLACK)));
            cellHead.HorizontalAlignment = Element.ALIGN_CENTER;
            cellHead.Padding = 3;
            cellHead.Border = Rectangle.TOP_BORDER | Rectangle.RIGHT_BORDER | Rectangle.BOTTOM_BORDER | Rectangle.LEFT_BORDER;
            pdfTableDocHeader.AddCell(cellHead);

            PdfPTable pdfTableParam = new PdfPTable(3);
            pdfTableParam.DefaultCell.Padding = 3;
            pdfTableParam.TotalWidth = PageSize.A4.Width;
            pdfTableParam.LockedWidth = false;
            pdfTableParam.HorizontalAlignment = Element.ALIGN_LEFT;
            pdfTableParam.DefaultCell.BorderWidth = 0;
            fCellWidthParam = new float[3] { 200,150,245 };
            pdfTableParam.SetWidths(fCellWidthParam);            
            #region Header - Row 1
            PdfPCell cell22 = new PdfPCell(new Phrase(dtHeader.Rows[0]["Company Name"].ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 9, 1, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border = Rectangle.RIGHT_BORDER;// | Rectangle.LEFT_BORDER | Rectangle.TOP_BORDER;
            pdfTableParam.AddCell(cell22);
            cell22 = new PdfPCell(new Phrase("GST INVOICE", new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 9, 1, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_CENTER;
            cell22.Padding = 3;
            cell22.Border = Rectangle.RIGHT_BORDER;// | Rectangle.LEFT_BORDER | Rectangle.TOP_BORDER;
            pdfTableParam.AddCell(cell22);
            cell22 = new PdfPCell(new Phrase(dtHeader.Rows[0]["Party Name"].ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 9, 1, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border = 0;//Rectangle.RIGHT_BORDER;//| Rectangle.LEFT_BORDER | Rectangle.TOP_BORDER;
            pdfTableParam.AddCell(cell22);
            #endregion
            #region Header - Row 2
            cell22 = new PdfPCell(new Phrase(dtHeader.Rows[0]["Billing Address 1"].ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 7, 0, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border = Rectangle.RIGHT_BORDER;//| Rectangle.LEFT_BORDER;
            pdfTableParam.AddCell(cell22);
            cell22 = new PdfPCell(new Phrase("Doc ID      : " + dtHeader.Rows[0]["Doc ID"].ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 9, 1, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border = Rectangle.RIGHT_BORDER;//| Rectangle.LEFT_BORDER;
            pdfTableParam.AddCell(cell22);
            cell22 = new PdfPCell(new Phrase(dtHeader.Rows[0]["Party Billing Address 1"].ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 7, 0, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border = 0;//Rectangle.RIGHT_BORDER;//| Rectangle.LEFT_BORDER;
            pdfTableParam.AddCell(cell22);
            #endregion
            #region Header - Row 3
            cell22 = new PdfPCell(new Phrase(dtHeader.Rows[0]["Billing Address 2"].ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 7, 0, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border = Rectangle.RIGHT_BORDER;// | Rectangle.LEFT_BORDER;
            pdfTableParam.AddCell(cell22);
            cell22 = new PdfPCell(new Phrase("Doc Date : " + dtHeader.Rows[0]["Date"].ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 10, 1, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border = Rectangle.RIGHT_BORDER;// | Rectangle.LEFT_BORDER;
            pdfTableParam.AddCell(cell22);
            cell22 = new PdfPCell(new Phrase(dtHeader.Rows[0]["Party Billing Address 2"].ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 7, 0, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border = 0;//Rectangle.RIGHT_BORDER;//| Rectangle.LEFT_BORDER;
            pdfTableParam.AddCell(cell22);
            #endregion
            #region Header - Row 4
            cell22 = new PdfPCell(new Phrase(dtHeader.Rows[0]["Billing Address 3"].ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 7, 0, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border = Rectangle.RIGHT_BORDER;// | Rectangle.LEFT_BORDER;
            pdfTableParam.AddCell(cell22);
            cell22 = new PdfPCell(new Phrase("", new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 10, 1, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border = Rectangle.RIGHT_BORDER;// | Rectangle.LEFT_BORDER;
            pdfTableParam.AddCell(cell22);
            cell22 = new PdfPCell(new Phrase(dtHeader.Rows[0]["Party Billing Address 3"].ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 7, 0, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border = 0;//Rectangle.RIGHT_BORDER;// | Rectangle.LEFT_BORDER;
            pdfTableParam.AddCell(cell22);
            #endregion
            #region Header - Row 5
            cell22 = new PdfPCell(new Phrase("Mobile No : "+dtHeader.Rows[0]["Mobile No"].ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 7, 0, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border = Rectangle.RIGHT_BORDER;// | Rectangle.LEFT_BORDER;
            pdfTableParam.AddCell(cell22);
            cell22 = new PdfPCell(new Phrase("", new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 10, 1, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border = Rectangle.RIGHT_BORDER;// | Rectangle.LEFT_BORDER;
            pdfTableParam.AddCell(cell22);
            cell22 = new PdfPCell(new Phrase("Mobile No : " + dtHeader.Rows[0]["Party Mobile No"].ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 7, 0, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border = 0;//Rectangle.RIGHT_BORDER;//| Rectangle.LEFT_BORDER;
            pdfTableParam.AddCell(cell22);
            #endregion
            #region Header - Row 6
            cell22 = new PdfPCell(new Phrase("GSTIN : " + dtHeader.Rows[0]["GSTIN"].ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 7, 0, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border =  Rectangle.RIGHT_BORDER;//| Rectangle.BOTTOM_BORDER | Rectangle.LEFT_BORDER;
            pdfTableParam.AddCell(cell22);
            cell22 = new PdfPCell(new Phrase("", new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 10, 1, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border =  Rectangle.RIGHT_BORDER;//| Rectangle.BOTTOM_BORDER | Rectangle.LEFT_BORDER;
            pdfTableParam.AddCell(cell22);
            cell22 = new PdfPCell(new Phrase("GSTIN : " + dtHeader.Rows[0]["Party GSTIN"].ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 7, 0, BaseColor.BLACK)));
            cell22.HorizontalAlignment = Element.ALIGN_LEFT;
            cell22.Padding = 3;
            cell22.Border = 0;// Rectangle.RIGHT_BORDER;//| Rectangle.BOTTOM_BORDER | Rectangle.LEFT_BORDER;
            pdfTableParam.AddCell(cell22);
            #endregion
            pdfTableParam.SpacingAfter = 1;
            int nColumnCount = dtItems.Columns.Count;
            PdfPTable pdfTableDEP = new PdfPTable(nColumnCount);
            pdfTableDEP.DefaultCell.Padding = 5;
            pdfTableDEP.TotalWidth = PageSize.A4.Width;
            pdfTableDEP.LockedWidth = false;
            pdfTableDEP.HorizontalAlignment = Element.ALIGN_LEFT;
            pdfTableDEP.DefaultCell.BorderWidth = 0;

            float[] fCellWidth = new float[nColumnCount];
            for (int nArrayLoop = 0; nArrayLoop < fCellWidth.Length; nArrayLoop++)
            {
                fCellWidth[nArrayLoop] = nArrayLoop == 0 ? 20 : nArrayLoop == 1 ? 150 : 45;
            }
            pdfTableDEP.SetWidths(fCellWidth);
            foreach (DataColumn column in dtItems.Columns)
            {
                    PdfPCell cell = new PdfPCell(new Phrase(column.ColumnName == "Doc ID" ? "#": column.ColumnName.ToUpper(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.HELVETICA, 8, 1, BaseColor.BLACK)));
                    cell.HorizontalAlignment = Element.ALIGN_CENTER;
                //cell.BackgroundColor = BaseColor.GRAY;
                cell.Border = Rectangle.TOP_BORDER | Rectangle.BOTTOM_BORDER;
                pdfTableDEP.AddCell(cell);                
            }
            //Creating iTextSharp Table from the DataTable data
            PdfPTable pdfTableCS = new PdfPTable(dtItems.Columns.Count);
            pdfTableCS.DefaultCell.PaddingBottom = 5;
            pdfTableCS.TotalWidth = PageSize.A4.Width;
            pdfTableCS.LockedWidth = false;
            pdfTableCS.HorizontalAlignment = Element.ALIGN_LEFT;
            pdfTableCS.DefaultCell.BorderWidth = 0;

            fCellWidth = new float[dtItems.Columns.Count];
            for (int nArrayLoop = 0; nArrayLoop < fCellWidth.Length; nArrayLoop++)
            {
                fCellWidth[nArrayLoop] = nArrayLoop == 0 ? 20 : nArrayLoop == 1 ? 150 : 45;
            }
            pdfTableCS.SetWidths(fCellWidth);            
            for (int nRowCount = 0; nRowCount < dtItems.Rows.Count; nRowCount++)
            {
                int iscc = nRowCount % 2;
                for (int j = 0; j < dtItems.Columns.Count; j++)
                {
                    string ColName = dtItems.Columns[j].ColumnName;
                    
                    bool IsAllignLeft = new[] { "Product Name", "HSN", "Tax Name" }
                        .Contains(ColName);
                    string CellValue = dtItems.Rows[nRowCount][j].ToString();                    
                    string CellContent = j == 0 ? Convert.ToString(nRowCount + 1) + "." :
                        IsAllignLeft ? Convert.ToString(dtItems.Rows[nRowCount][j]) :                        
                        !string.IsNullOrEmpty(CellValue) ? Convert.ToString(Math.Round(Convert.ToDouble(CellValue), 2).ToString("F2")) : "0.00";

                    PdfPCell cell = new PdfPCell(new Phrase(CellContent, new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 8, 0, BaseColor.BLACK)));
                    cell.HorizontalAlignment = IsAllignLeft ? Element.ALIGN_LEFT : Element.ALIGN_RIGHT;
                    //cell.Border = j == (dtItems.Columns.Count -1) ? Rectangle.BOTTOM_BORDER | Rectangle.LEFT_BORDER | Rectangle.RIGHT_BORDER | Rectangle.TOP_BORDER : 
                    //    Rectangle.BOTTOM_BORDER | Rectangle.LEFT_BORDER | Rectangle.TOP_BORDER;
                    cell.Border = 0;
                    cell.PaddingBottom = 10;
                    cell.PaddingRight = 3;
                    pdfTableCS.AddCell(cell);
                }
            }
            pdfTableCS.SpacingAfter = 5;
            //FOOTER
            PdfPTable pdfTableDocFooter = new PdfPTable(3);
            pdfTableDocFooter.DefaultCell.Padding = 3;
            pdfTableDocFooter.TotalWidth = PageSize.A4.Width;
            pdfTableDocFooter.LockedWidth = false;
            pdfTableDocFooter.HorizontalAlignment = Element.ALIGN_LEFT;
            pdfTableDocFooter.DefaultCell.BorderWidth = 0;
            float[] fCellWidthParamfooter = new float[3] { 400, 100, 95 };
            pdfTableDocFooter.SetWidths(fCellWidthParamfooter);
            //Bank Name : UNION BANK OF INDIA, CHROMPET
            //A/c No : 239011010000099
            //IFSC Code : UBIN0823902
            double Tax = dtItems.AsEnumerable()
                     .Where(r => !string.IsNullOrEmpty(r["Tax Amount"].ToString()))
                     .Sum(r => Convert.ToDouble(r["Tax Amount"]));
            double Net = dtItems.AsEnumerable()
                     .Where(r => !string.IsNullOrEmpty(r["Net Amount"].ToString()))
                     .Sum(r => Convert.ToDouble(r["Net Amount"]));

            double DiscAmt = 0.00;
                if (!allDiscAmtEmpty) {
                DiscAmt = dtItems.AsEnumerable()
                                  .Where(r => !string.IsNullOrEmpty(r["Discount Amount"].ToString()))
                                  .Sum(r => Convert.ToDouble(r["Discount Amount"]));
            }
            decimal Gross = objBL.BL_dValidation(Net) - objBL.BL_dValidation(Tax);
            string AmountLabelInfos = "Disc Amount : "+ "\n\n" +
                "Gross Amount : "  + "\n\n" +
                "Tax Amount : " + "\n\n" +
                "Net Amount : " ;
            string AmountInfos = Convert.ToString(Math.Round((DiscAmt), 2).ToString("F2")) + "\n\n" +
                Convert.ToString(Math.Round((Gross), 2).ToString("F2")) + "\n\n" +
                Convert.ToString(Math.Round((Tax), 2).ToString("F2")) + "\n\n" +
                Convert.ToString(Math.Round((Net), 2).ToString("F2"));

            //Footer tax
            DataTable dtDistinctTax = new DataTable();
            dtDistinctTax = dtItems.DefaultView.ToTable(true, dtItems.Columns["Tax Name"].ColumnName);
            string sortExpression = string.Format("{0}", "Tax Name");
            dtDistinctTax.DefaultView.Sort = sortExpression + " ASC";
            dtDistinctTax = dtDistinctTax.DefaultView.ToTable();
            PdfPTable pdfTableFooterTax = new PdfPTable(5);
            pdfTableFooterTax.DefaultCell.Padding = 5;
            pdfTableFooterTax.TotalWidth = 300;
            pdfTableFooterTax.LockedWidth = true;
            pdfTableFooterTax.HorizontalAlignment = Element.ALIGN_LEFT;
            pdfTableFooterTax.DefaultCell.BorderWidth = 0;
            float[] fCellWidthFooterTax = new float[5] { 80, 50, 60, 50, 60 };
            pdfTableFooterTax.SetWidths(fCellWidthFooterTax);            
            string[] FooterTaxColumns = new[] { "Sale Amt", "CGST(%)", "CGST Amt", "SGST(%)", "SGST Amt" };
            foreach (string column in FooterTaxColumns)
            {
                PdfPCell cell = new PdfPCell(new Phrase(column, new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.HELVETICA, 7, 1, BaseColor.BLACK)));
                cell.HorizontalAlignment = Element.ALIGN_CENTER;
                //cell.BackgroundColor = BaseColor.GRAY;
                cell.Border = Rectangle.BOTTOM_BORDER;
                pdfTableFooterTax.AddCell(cell);
            }
            for (int i = 0; i < dtDistinctTax.Rows.Count; i++)
            {
                string TaxName = dtDistinctTax.Rows[i][0].ToString();
                decimal tNet = dtItems.AsEnumerable()
    .Where(r => !string.IsNullOrEmpty(r["Net Amount"].ToString())
             && r["Tax Name"].ToString() == TaxName)
    .Sum(r => Convert.ToDecimal(r["Net Amount"]));
                decimal tTaxAmt = dtItems.AsEnumerable()
    .Where(r => !string.IsNullOrEmpty(r["Tax Amount"].ToString())
             && r["Tax Name"].ToString() == TaxName)
    .Sum(r => Convert.ToDecimal(r["Tax Amount"]));
                decimal GSTGross = tNet - tTaxAmt;
                decimal TaxPern = objBL.BL_dValidation(Regex.Match(TaxName, @"\d+").Value);                
                decimal CSGSTPern = Math.Round(TaxPern / 2,2);
                decimal CSGSTAmt = ((Math.Round((GSTGross), 2) * CSGSTPern) / 100);
                PdfPCell cell = new PdfPCell(new Phrase(Math.Round(GSTGross, 2).ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.HELVETICA, 7, 1, BaseColor.BLACK)));
                cell.HorizontalAlignment = Element.ALIGN_CENTER;
                cell.Border = 0;
                pdfTableFooterTax.AddCell(cell);
                cell = new PdfPCell(new Phrase(Math.Round((CSGSTPern), 2).ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.HELVETICA, 7, 1, BaseColor.BLACK)));
                cell.HorizontalAlignment = Element.ALIGN_CENTER;
                cell.Border = 0;
                pdfTableFooterTax.AddCell(cell);
                cell = new PdfPCell(new Phrase(Math.Round((CSGSTAmt), 2).ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.HELVETICA, 7, 1, BaseColor.BLACK)));
                cell.HorizontalAlignment = Element.ALIGN_CENTER;
                cell.Border = 0;
                pdfTableFooterTax.AddCell(cell);
                cell = new PdfPCell(new Phrase(Math.Round((CSGSTPern), 2).ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.HELVETICA, 7, 1, BaseColor.BLACK)));
                cell.HorizontalAlignment = Element.ALIGN_CENTER;
                cell.Border = 0;
                pdfTableFooterTax.AddCell(cell);
                cell = new PdfPCell(new Phrase(Math.Round((CSGSTAmt), 2).ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.HELVETICA, 7, 1, BaseColor.BLACK)));
                cell.HorizontalAlignment = Element.ALIGN_CENTER;
                cell.Border = 0;
                pdfTableFooterTax.AddCell(cell);
            }
            //
            PdfPCell Footercell1 = new PdfPCell(pdfTableFooterTax);
            Footercell1.HorizontalAlignment = Element.ALIGN_LEFT;
            Footercell1.Padding = 5;
            Footercell1.Border = Rectangle.TOP_BORDER | Rectangle.BOTTOM_BORDER;
            pdfTableDocFooter.AddCell(Footercell1);
            Footercell1 = new PdfPCell(new Phrase(AmountLabelInfos, new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 8, 0, BaseColor.BLACK)));
            Footercell1.HorizontalAlignment = Element.ALIGN_RIGHT;
            Footercell1.Padding = 5;
            Footercell1.Border = Rectangle.TOP_BORDER |  Rectangle.BOTTOM_BORDER | Rectangle.LEFT_BORDER;
            pdfTableDocFooter.AddCell(Footercell1);
            Footercell1 = new PdfPCell(new Phrase(AmountInfos, new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 9, 1, BaseColor.BLACK)));
            Footercell1.HorizontalAlignment = Element.ALIGN_RIGHT;
            Footercell1.Padding = 5;
            Footercell1.Border = Rectangle.TOP_BORDER |  Rectangle.BOTTOM_BORDER | Rectangle.LEFT_BORDER;
            pdfTableDocFooter.AddCell(Footercell1);
            //amount in words
            PdfPTable pdfTableDocFooterAMTWRD = new PdfPTable(1);
            pdfTableDocFooterAMTWRD.DefaultCell.Padding = 3;
            pdfTableDocFooterAMTWRD.TotalWidth = PageSize.A4.Width;
            pdfTableDocFooterAMTWRD.LockedWidth = false;
            pdfTableDocFooterAMTWRD.HorizontalAlignment = Element.ALIGN_LEFT;
            pdfTableDocFooterAMTWRD.DefaultCell.BorderWidth = 0;
            float[] fCellWidthParamfooterAMTWRD = new float[1] { 595 };
            pdfTableDocFooterAMTWRD.SetWidths(fCellWidthParamfooterAMTWRD);
            DataTable dtAMTword = objBL.BL_ExecuteSqlQuery("select dbo.fnConvertAmountinWords(" + Math.Round(objBL.BL_dValidation(Net), 2).ToString() + ")");
            string Amountinwords = dtAMTword.Rows.Count > 0 ? dtAMTword.Rows[0][0].ToString() : "";
            PdfPCell FootercellAMTWRD = new PdfPCell(new Phrase(Amountinwords, new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 8, 1, BaseColor.BLACK)));
            FootercellAMTWRD.HorizontalAlignment = Element.ALIGN_LEFT;
            FootercellAMTWRD.Padding = 5;
            FootercellAMTWRD.Border = Rectangle.TOP_BORDER | Rectangle.BOTTOM_BORDER;
            pdfTableDocFooterAMTWRD.AddCell(FootercellAMTWRD);
            //QR Code generate
            MessagingToolkit.QRCode.Codec.QRCodeEncoder encoder = new MessagingToolkit.QRCode.Codec.QRCodeEncoder();
            encoder.QRCodeScale = 8;
            //encoder.QRCodeEncodeMode = MessagingToolkit.QRCode.Codec.QRCodeEncoder.ENCODE_MODE.ALPHA_NUMERIC;
            string Content = string.Format("upi://pay?pa={0}&pn={1}&cu=INR&am={2}&tn={3}", "QR918056388388-0100@unionbankofindia",
                dtHeader.Rows[0][0].ToString(), Math.Round(objBL.BL_dValidation(Net), 2).ToString(),
                dtHeader.Rows[0]["Doc ID"].ToString()+'-'+ dtHeader.Rows[0]["Date"].ToString() + '-' + dtHeader.Rows[0]["Party Name"].ToString());
            Bitmap bmp = new Bitmap(encoder.Encode(Content), new Size(100, 100));
            iTextSharp.text.Image qrImage;
            using (var ms = new MemoryStream())
            {
                bmp.Save(ms, System.Drawing.Imaging.ImageFormat.Png);
                qrImage = iTextSharp.text.Image.GetInstance(ms.ToArray());
            }
            //
            //bank
            string BankInfos = "Bank Name : UNION BANK OF INDIA, CHROMPET" + "\n\n" + "A/c No : 239011010000099" + "\n\n" + "IFSC Code : UBIN0823902";

            PdfPTable pdfTableDocFooterBank = new PdfPTable(3);
            pdfTableDocFooterBank.DefaultCell.Padding = 3;
            pdfTableDocFooterBank.TotalWidth = PageSize.A4.Width;
            pdfTableDocFooterBank.LockedWidth = false;
            pdfTableDocFooterBank.HorizontalAlignment = Element.ALIGN_LEFT;
            pdfTableDocFooterBank.DefaultCell.BorderWidth = 0;
            float[] fCellWidthParamfooter1 = new float[3] {100, 300, 195 };
            pdfTableDocFooterBank.SetWidths(fCellWidthParamfooter1);
            PdfPCell Footercell2 = new PdfPCell(qrImage, true);
            Footercell2.HorizontalAlignment = Element.ALIGN_LEFT;
            Footercell2.Padding = 5;
            Footercell2.Border = 0 ;
            pdfTableDocFooterBank.AddCell(Footercell2);
            Footercell2 = new PdfPCell(new Phrase(BankInfos, new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 8, 1, BaseColor.BLACK)));
            Footercell2.HorizontalAlignment = Element.ALIGN_LEFT;
            Footercell2.Padding = 5;
            Footercell2.Border = Rectangle.TOP_BORDER | Rectangle.RIGHT_BORDER  ;
            pdfTableDocFooterBank.AddCell(Footercell2);
            Footercell2 = new PdfPCell(new Phrase("\n\n\n\n\n\nFor " + dtHeader.Rows[0][0].ToString(), new iTextSharp.text.Font(iTextSharp.text.Font.FontFamily.TIMES_ROMAN, 8, 1, BaseColor.BLACK)));
            Footercell2.HorizontalAlignment = Element.ALIGN_RIGHT;
            Footercell2.Padding = 5;
            Footercell2.Border = Rectangle.TOP_BORDER ;
            pdfTableDocFooterBank.AddCell(Footercell2);            
            //Exporting to PDF
            if (!Directory.Exists(strFilePath))
            {
                Directory.CreateDirectory(strFilePath);
            }
            using (FileStream stream = new FileStream(strFilePath + strFileName, FileMode.Create))
            {
                Document pdfDoc = new Document(PageSize.A4, 20f, 20f, 20f, 20f);
                pdfDoc.AddCreationDate();
                PdfWriter.GetInstance(pdfDoc, stream);
                pdfTableDocHeader.WidthPercentage = 100;
                pdfTableParam.WidthPercentage = 100;
                pdfTableDEP.WidthPercentage = 100;
                pdfTableCS.WidthPercentage = 100;
                pdfTableDocFooter.WidthPercentage = 100;
                pdfTableDocFooterAMTWRD.WidthPercentage = 100;
                pdfTableDocFooterBank.WidthPercentage = 100;
                pdfDoc.Open();
                //pdfDoc.Add(pdfTableDocHeader);
                pdfDoc.Add(pdfTableParam);//Comp Name & DSC Label
                pdfDoc.Add(pdfTableDEP); 
                pdfDoc.Add(pdfTableCS);//pdfTableCS
                //pdfDoc.Add(pdfTableFooterTax);
                pdfDoc.Add(pdfTableDocFooter);
                pdfDoc.Add(pdfTableDocFooterAMTWRD);
                pdfDoc.Add(pdfTableDocFooterBank);                
                pdfDoc.Close();
                stream.Close();
            }
        }
    }
}
