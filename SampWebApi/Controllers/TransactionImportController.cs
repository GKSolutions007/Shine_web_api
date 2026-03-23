using DocumentFormat.OpenXml.Wordprocessing;
using Microsoft.Ajax.Utilities;
using SampWebApi.BuisnessLayer;
using SampWebApi.Import_Utility;
using SampWebApi.Models;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading;
using System.Threading.Tasks;
using System.Web;
using System.Web.Http;
using static System.Windows.Forms.VisualStyles.VisualStyleElement.TreeView;

namespace SampWebApi.Controllers
{
    public class TransactionImportController : ApiController
    {
        clsBusinessLayer objBL = new clsBusinessLayer();
        public string strExtension = ".xlsx";
        public string strFileName = "";
        public string strSheetName { get; set; }
        public string strFilePath
        {
            get; set;
        }
        public int BranchID { get; set; }
        public int VendorID { get; set; }
        public int CustomerID { get; set; }
        public int PriceTypeID { get; set; }
        public int TaxTypeID { get; set; }
        public int ProductID { get; set; }
        public int BeatID { get; set; }
        public int SalesmanID { get; set; }
        public int TaxID { get; set; }
        public int UOMID { get; set; }
        public DataTable dtData { get; set; }
        public DataTable dtHeaderData { get; set; }
        public DataTable dtItemsData { get; set; }
        public class ExportJobStatus
        {
            public int Progress { get; set; } = 0;
            public string ProgressMessage { get; set; }
            public string FilePath { get; set; }
            public bool IsCompleted { get; set; } = false;
        }
        public static class ExportJobManager
        {
            public static Dictionary<string, ExportJobStatus> Jobs = new Dictionary<string, ExportJobStatus>();
        }
        public class ExportRequest
        {
            public int TransID { get; set; }
            public string TransName { get; set; }
            public string FromDate { get; set; }
            public string ToDate { get; set; }
        }
        [System.Web.Http.HttpGet]
        [System.Web.Http.Route("api/transactionimport/template")]
        public HttpResponseMessage ExportTemplate(int TransID, string TransName, string FromDate = null, string ToDate = null)
        {
            strFilePath = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"];
            strFileName = TransName + "_" + DateTime.Now.ToString("yyyyMMddHHmmss");
            clsExportData objExport = new clsExportData();
            objExport.strFileName = strFileName;
            objExport.strFilePath = strFilePath;
            if (TransID == 1)//"Sales,Bill,SR,PR"
            {
                DataSet dtset = new DataSet("Help Data");
                dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 1));
                dtset.Tables[0].TableName = "Sample - Header";
                dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 2));
                dtset.Tables[1].TableName = "Sample - Details";
                //dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 3));
                //dtset.Tables[2].TableName = "Sample - SerialInfo";
                dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 4));
                dtset.Tables[2].TableName = "Help";
                objExport.OpenTransTemplate(
                    Import_Utility.clsExportData.AddSalesHeaderColumnForExport(false),
                           Import_Utility.clsExportData.AddSalesDetailColumnForExport(false));
                objExport.AddingHelptoExcel(objExport.strFilePath + objExport.strFileName + ".xlsx", 3, dtset);
            }


            var sDocument = strFilePath + strFileName + strExtension;
            string fileName = strFileName + strExtension;
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

        [System.Web.Http.HttpPost]
        [System.Web.Http.Route("api/transactionimport/startexport")]
        public IHttpActionResult StartExport([FromBody] ExportRequest req)//int TransID, string TransName, string FromDate = null, string ToDate = null
        {
            string jobId = Guid.NewGuid().ToString();

            ExportJobManager.Jobs[jobId] = new ExportJobStatus();
            int TransID = req.TransID;
            string TransName = req.TransName;
            string FromDate = req.FromDate;
            string ToDate = req.ToDate;
            Task.Run(() => GenerateExcel(jobId, TransID, TransName, FromDate, ToDate));

            return Ok(jobId);
        }
        private void GenerateExcel(string jobId, int TransID, string TransName, string FromDate, string ToDate)
        {
            try
            {
                var job = ExportJobManager.Jobs[jobId];

                string strFilePath = ConfigurationManager.AppSettings["SupportFilePath"];
                string strFileName = TransName + "_export_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                string fullPath = strFilePath + strFileName + ".xlsx";

                clsExportData objExport = new clsExportData();
                objExport.strFileName = strFileName;
                objExport.strFilePath = strFilePath;

                job.Progress = 10;
                job.ProgressMessage = "Initialize...";//Thread.Sleep(3000);
                
                if (TransID == 1)
                {
                    DataSet dtRecords = new DataSet();
                    job.ProgressMessage = "Fetch Header Data..."; //Thread.Sleep(3000);
                    dtRecords.Tables.Add(objBL.BL_ExecuteParamSP("uspExportTransactionImport", TransID, 1, FromDate, ToDate));
                    job.Progress = 25;
                    job.ProgressMessage = "Fetch Detail Data..."; //Thread.Sleep(3000);
                    dtRecords.Tables.Add(objBL.BL_ExecuteParamSP("uspExportTransactionImport", TransID, 2, FromDate, ToDate));
                    job.Progress = 40;
                    job.ProgressMessage = "Fetch Serial Data..."; //Thread.Sleep(3000);
                    //dtRecords.Tables.Add(objBL.BL_ExecuteParamSP("uspExportTransactionImport", TransID, 3, FromDate, ToDate));
                    job.Progress = 50;
                    job.ProgressMessage = "Fetch Help Data..."; //Thread.Sleep(3000);
                    DataSet dtset = new DataSet("Help Data");                    
                    dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 1));
                    dtset.Tables[0].TableName = "Header";
                    job.Progress = 65;                    
                    job.ProgressMessage = "Detail Data Export..."; //Thread.Sleep(3000);
                    dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 2));
                    dtset.Tables[1].TableName = "Detail";
                    job.Progress = 75;
                    //job.ProgressMessage = "Serial Data Export...";
                    //dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 3));
                    //dtset.Tables[0].TableName = "Serial";
                    //job.Progress = 80;
                    dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 4));
                    dtset.Tables[2].TableName = "Help";
                    job.Progress = 85;
                    
                    job.ProgressMessage = "Creating Excel File..."; //Thread.Sleep(3000);
                    objExport.TransImport_ExportToExcel(dtRecords.Tables[0], dtRecords.Tables[1], true);
                    job.Progress = 90;
                    
                    objExport.AddingHelptoExcel(fullPath, 3, dtset);
                    job.ProgressMessage = "Downloading...";                    
                }

                job.Progress = 100;
                job.FilePath = fullPath;
                job.IsCompleted = true;
            }
            catch
            {
                ExportJobManager.Jobs[jobId].Progress = -1;
            }
        }

        [System.Web.Http.HttpGet]
        [System.Web.Http.Route("api/transactionimport/progress")]
        public IHttpActionResult GetProgress(string jobId)
        {
            if (!ExportJobManager.Jobs.ContainsKey(jobId))
                return NotFound();

            var job = ExportJobManager.Jobs[jobId];

            return Ok(new
            {
                progress = job.Progress,
                progressMessage = job.ProgressMessage,
                completed = job.IsCompleted
            });
        }

        [System.Web.Http.HttpGet]
        [System.Web.Http.Route("api/transactionimport/download")]
        public HttpResponseMessage Download(string jobId)
        {
            if (!ExportJobManager.Jobs.ContainsKey(jobId))
                return new HttpResponseMessage(HttpStatusCode.NotFound);

            var job = ExportJobManager.Jobs[jobId];

            if (!System.IO.File.Exists(job.FilePath))
                return new HttpResponseMessage(HttpStatusCode.NotFound);

            var result = new HttpResponseMessage(HttpStatusCode.OK);
            var stream = new FileStream(job.FilePath, FileMode.Open, FileAccess.Read);

            result.Content = new StreamContent(stream);
            result.Content.Headers.ContentType =
                new System.Net.Http.Headers.MediaTypeHeaderValue("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");

            result.Content.Headers.ContentDisposition =
                new System.Net.Http.Headers.ContentDispositionHeaderValue("attachment")
                {
                    FileName = Path.GetFileName(job.FilePath)
                };

            return result;
        }
        public class FileData
        {
            public string FileName { get; set; }
            public string FilePath { get; set; }
            public byte[] Content { get; set; }
        }
        [System.Web.Http.HttpPost]
        [System.Web.Http.Route("api/transactionimport/startimport")]
        public IHttpActionResult StartImport()//int TransID, string TransName, string FromDate = null, string ToDate = null
        {
            string jobId = Guid.NewGuid().ToString();
            //HttpFileCollection file = HttpContext.Current.Request.Files;
            var files = new List<FileData>();
            string TransID = HttpContext.Current.Request.Files.AllKeys[0].ToString();
            string TransName = HttpContext.Current.Request.Files.AllKeys[1].ToString();
            string fileName = HttpContext.Current.Request.Files[2].FileName;
            string fileContentType = HttpContext.Current.Request.Files[2].ContentType;
            string UserID = HttpContext.Current.Request.Files.AllKeys[2].ToString();

            for (int i = 3; i < HttpContext.Current.Request.Files.Count; i++)
            {
                var file = HttpContext.Current.Request.Files[i];

                if (file != null && file.ContentLength > 0)
                {
                    using (var ms = new MemoryStream())
                    {
                        file.InputStream.CopyTo(ms);

                        files.Add(new FileData
                        {
                            FileName = file.FileName,
                            Content = ms.ToArray()
                        });
                    }
                }
            }
            List<ImportResults> MTM = new List<ImportResults>();
            ExportJobManager.Jobs[jobId] = new ExportJobStatus();            
            Task.Run(() => {
                MTM = RunTransactionImport(jobId, TransID, TransName, UserID, files);
               
                return Ok(MTM);
            });

            return Ok(jobId);
        }
        public List<ImportResults> RunTransactionImport(string jobId, string TransID,string TransName, string UserID, List<FileData> httpFile)
        {
            string Msg = "";
            string dt = "";
            List<ImportResults> MTM = new List<ImportResults>();
            try
            {

                var job = ExportJobManager.Jobs[jobId];
                job.Progress = 5;
                job.ProgressMessage = "Initialize..."; //Thread.Sleep(3000);
                //var file = HttpContext.Current.Request.Files.Count > 1 ? HttpContext.Current.Request.Files[0] : null;
                //var data = Request.Files[0].InputStream.Read;                                                       
                if (httpFile.Count  > 0)
                {
                    string fileName = "";                                        
                    job.Progress = 10;
                    job.ProgressMessage = "Read file data..."; //Thread.Sleep(3000);
                    //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Upload Files\\";
                    clsExportData clsExport = new clsExportData();
                    string FPt = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"];
                    strFilePath = FPt + "Upload Files\\";
                    clsExport.strFilePath = FPt + "Upload Files\\";
                    strFileName = TransName + "_Upload_" + DateTime.Now.ToString("yyyyMMddHHmmss") + ".xlsx";
                    clsExport.strFileName = TransName + "_Upload_" + DateTime.Now.ToString("yyyyMMddHHmmss") + ".xlsx";
                    if (!Directory.Exists(strFilePath))
                    {
                        Directory.CreateDirectory(strFilePath);
                    }
                    job.Progress = 20;
                    job.ProgressMessage = "Save as file..."; //Thread.Sleep(3000);
                    var file = httpFile[0];
                    //file.SaveAs(strFilePath + strFileName);                    
                    string fullPath = Path.Combine(strFilePath, strFileName);

                    File.WriteAllBytes(fullPath, file.Content);
                    job.Progress = 25;
                    job.ProgressMessage = "File saved successfully..."; //Thread.Sleep(3000);
                    bool blHeaderResult = true, blItemsResult = true;
                    List<string> lstHeader = null;
                    List<string> lstItems = null;
                    
                    ImportFieldValidations importValidations = new ImportFieldValidations();
                    job.Progress = 30;
                    job.ProgressMessage = "Validate Header Columns..."; //Thread.Sleep(3000);
                    #region Header Validation
                    if (TransID == "1")//'SALES,BILL,SR,PR'
                    {
                        //Import_Utility.clsExportData.AddSalesHeaderColumnForExport(false),
                        //Import_Utility.clsExportData.AddSalesDetailColumnForExport(false)
                        lstHeader = clsExportData.AddSalesHeaderColumnForExport(false);
                    }
                    bool HeaderErrorColAlreadyExists = false;
                    dtHeaderData = clsExport.TransactionColumnValidation(lstHeader, "Header", ref blHeaderResult);
                    if (!blHeaderResult)
                    {
                        if (TransID == "1")//'SALES,BILL,SR,PR'
                        {
                            lstHeader = clsExportData.AddSalesHeaderColumnForExport(true);
                        }
                        dtHeaderData = clsExport.TransactionColumnValidation(lstHeader, "Header", ref blHeaderResult);
                        HeaderErrorColAlreadyExists = true;
                    }
                    #endregion
                    job.Progress = 35;
                    job.ProgressMessage = "Validate Detail Columns..."; Thread.Sleep(3000);
                    #region Items Validation
                    if (TransID == "1")//'SALES,BILL,SR,PR' Items
                    {
                        lstItems = clsExportData.AddSalesDetailColumnForExport(false);
                    }
                    bool ItemsErrorColAlreadyExists = false;
                    dtItemsData = clsExport.TransactionColumnValidation(lstItems, "Items", ref blHeaderResult);
                    if (!blHeaderResult)
                    {
                        if (TransID == "1")//'SALES,BILL,SR,PR' Items
                        {
                            lstItems = clsExportData.AddSalesDetailColumnForExport(true);
                        }
                        dtItemsData = clsExport.TransactionColumnValidation(lstItems, "Items", ref blHeaderResult);
                        ItemsErrorColAlreadyExists = true;
                    }
                    #endregion
                    if (blHeaderResult && blItemsResult)
                    {
                        job.Progress = 40;
                        job.ProgressMessage = "Data Validation Initiated..."; Thread.Sleep(3000);
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
                        if (TransID == "1")
                        {
                            if (dtHeaderData.Rows.Count > 0 && dtItemsData.Rows.Count > 0)
                            {
                                job.Progress = 50;
                                job.ProgressMessage = "Validate Header Data..."; Thread.Sleep(3000);
                                int nIndex = 1;
                                bool NoErrorsinHeader = true, NoErrorsinItems = true;
                                #region Header data validation
                                foreach (DataRow item in dtHeaderData.Rows)
                                {
                                    DataTable dtValidate = dtHeaderData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = importValidations.SaleSRBillPRHeaderValidation(dtValidate);
                                    //if (string.IsNullOrEmpty(RowError))
                                    //{
                                    //    DataRow drW = dtHeaderWrongValues.NewRow();
                                    //    drW["Branch Name *"] = importValidations.BranchID;// item.ItemArray[0];
                                    //    drW["Ref No *"] = item.ItemArray[1];
                                    //    drW["Date *"] = item.ItemArray[2];
                                    //    drW["Party Name *"] = item.ItemArray[3];
                                    //    drW["Trade Discount %"] = item.ItemArray[4];
                                    //    drW["Trade Discount Amount"] = item.ItemArray[5];
                                    //    drW["Additional Discount %"] = item.ItemArray[6];
                                    //    drW["Additional Discount Amount"] = item.ItemArray[7];
                                    //    drW["Freight"] = item.ItemArray[8];
                                    //    drW["Other Charge Amount"] = item.ItemArray[9];
                                    //    drW["Remarks"] = item.ItemArray[10];
                                    //    drW["Narration"] = item.ItemArray[11];
                                    //    drW["Net Amount *"] = item.ItemArray[12];
                                    //    drW["Error"] = RowError;
                                    //    dtHeaderWrongValues.Rows.Add(drW);
                                    //    //Correct values only
                                    //    DataRow drC = dtHeaderCorrectValues.NewRow();
                                    //    drC["Branch Name *"] = BranchID;
                                    //    drC["Ref No *"] = item.ItemArray[1];
                                    //    drC["Date *"] = item.ItemArray[2];
                                    //    drC["Party Name *"] = CustomerID;
                                    //    drC["PriceTypeID"] = PriceTypeID;
                                    //    drC["TaxTypeID"] = TaxTypeID;
                                    //    drC["Trade Discount %"] = item.ItemArray[4];
                                    //    drC["Trade Discount Amount"] = item.ItemArray[5];
                                    //    drC["Additional Discount %"] = item.ItemArray[6];
                                    //    drC["Additional Discount Amount"] = item.ItemArray[7];
                                    //    drC["Freight"] = item.ItemArray[8];
                                    //    drC["Other Charge Amount"] = item.ItemArray[9];
                                    //    drC["Remarks"] = item.ItemArray[10];
                                    //    drC["Narration"] = item.ItemArray[11];
                                    //    drC["Net Amount *"] = item.ItemArray[12];
                                    //    drC["Error"] = nIndex;
                                    //    dtHeaderCorrectValues.Rows.Add(drC);
                                    //    nIndex++;
                                    //}
                                    //else
                                    //{
                                    //    NoErrorsinHeader = false;
                                    //    DataRow drW = dtHeaderWrongValues.NewRow();
                                    //    drW["Branch Name *"] = item.ItemArray[0];
                                    //    drW["Ref No *"] = item.ItemArray[1];
                                    //    drW["Date *"] = item.ItemArray[2];
                                    //    drW["Party Name *"] = item.ItemArray[3];
                                    //    drW["Trade Discount %"] = item.ItemArray[4];
                                    //    drW["Trade Discount Amount"] = item.ItemArray[5];
                                    //    drW["Additional Discount %"] = item.ItemArray[6];
                                    //    drW["Additional Discount Amount"] = item.ItemArray[7];
                                    //    drW["Freight"] = item.ItemArray[8];
                                    //    drW["Other Charge Amount"] = item.ItemArray[9];
                                    //    drW["Remarks"] = item.ItemArray[10];
                                    //    drW["Narration"] = item.ItemArray[11];
                                    //    drW["Net Amount *"] = item.ItemArray[12];
                                    //    drW["Error"] = RowError;
                                    //    dtHeaderWrongValues.Rows.Add(drW);
                                    //}
                                }
                                #endregion
                                #region Items data validation
                                job.Progress = 60;
                                job.ProgressMessage = "Validate Detail Data..."; Thread.Sleep(3000);
                                #endregion
                                #region save
                                job.Progress = 75;
                                job.ProgressMessage = "Data Save Progress..."; Thread.Sleep(10000);
                                #endregion
                                job.Progress = 100;
                                job.ProgressMessage = "Data Saved Successfully...";
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
                }
            }
            catch (Exception ex)
            {
                MTM.Add(new ImportResults()
                {
                    ID = "2",
                    Msg = ex.Message,
                });
                return MTM;
                Console.WriteLine(ex.ToString());
            }
            return MTM;
        }
       
    }
}
