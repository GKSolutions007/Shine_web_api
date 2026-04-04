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
        DataTable dtBillHeader = new DataTable(), dtPRHeader = new DataTable(), dtSalesHeader = new DataTable(), dtSRHeader = new DataTable(),
            dtBillDetail = new DataTable(), dtPRDetail = new DataTable(), dtSalesDetail = new DataTable(), dtSRDetail = new DataTable();
        public class ExportJobStatus
        {
            public int Progress { get; set; } = 0;
            public string ProgressMessage { get; set; }
            public string FilePath { get; set; }
            public bool IsCompleted { get; set; } = false;
            public int ErrorID { get; set; } = 0;
            public string ErrorMessage { get; set; }
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
                    job.ProgressMessage = "Downloading...";
                    objExport.AddingHelptoExcel(fullPath, 3, dtset);
                    job.ProgressMessage = "Downloaded.";
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
                completed = job.IsCompleted,
                ErrorID = job.ErrorID,
                ErrorMessage = job.ErrorMessage,
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
            clsExportData clsExport = new clsExportData();

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
                    
                    string FPt = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"];
                    strFilePath = FPt + "Upload Files\\";
                    clsExport.strFilePath = FPt + "Upload Files\\";
                    strFileName = TransName + "_Upload_" + DateTime.Now.ToString("yyyyMMddHHmmss") + ".xlsx";
                    clsExport.strFileName = strFileName;
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
                    job.ProgressMessage = "Validate Detail Columns..."; //Thread.Sleep(3000);
                    #region Items Validation
                    if (TransID == "1")//'SALES,BILL,SR,PR' Items
                    {
                        lstItems = clsExportData.AddSalesDetailColumnForExport(false);
                    }
                    bool ItemsErrorColAlreadyExists = false;
                    dtItemsData = clsExport.TransactionColumnValidation(lstItems, "Detail", ref blItemsResult);
                    if (!blItemsResult)
                    {
                        if (TransID == "1")//'SALES,BILL,SR,PR' Items
                        {
                            lstItems = clsExportData.AddSalesDetailColumnForExport(true);
                        }
                        dtItemsData = clsExport.TransactionColumnValidation(lstItems, "Detail", ref blItemsResult);
                        ItemsErrorColAlreadyExists = true;
                    }
                    #endregion
                    if (blHeaderResult && blItemsResult)
                    {
                        job.Progress = 40;
                        job.ProgressMessage = "Data Validation Initiated..."; //Thread.Sleep(3000);
                        DataTable dtHeaderCorrectValues = new DataTable();
                        DataTable dtHeaderWrongValues = new DataTable();
                        foreach (string str in lstHeader)
                        {
                            dtHeaderCorrectValues.Columns.Add(str);
                            dtHeaderWrongValues.Columns.Add(str);
                        }
                        if (!HeaderErrorColAlreadyExists)
                        {
                            dtHeaderCorrectValues.Columns.Add("ERROR");
                            dtHeaderWrongValues.Columns.Add("ERROR");
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
                            dtItemsCorrectValues.Columns.Add("ERROR");
                            dtItemsWrongValues.Columns.Add("ERROR");
                        }
                        if (TransID == "1")
                        {
                            if (dtHeaderData.Rows.Count > 0 && dtItemsData.Rows.Count > 0)
                            {
                                job.Progress = 50;
                                job.ProgressMessage = "Validate Header Data..."; //Thread.Sleep(3000);
                                int currentProgress = job.Progress;
                                int nIndex = 1;
                                bool NoErrorsinHeader = true, NoErrorsinItems = true;
                                //int TotHeaderRow = dtHeaderData.Rows.Count;
                                //int CalcProgressPern = 10;
                                //decimal pernperrow = Math.Round(Convert.ToDecimal(TotHeaderRow) / 10, 0);
                                #region Header data validation
                                foreach (DataRow item in dtHeaderData.Rows)
                                {
                                    //currentProgress = currentProgress + Convert.ToInt32(pernperrow);
                                    //job.Progress = currentProgress;
                                    //Thread.Sleep(1000);
                                    DataTable dtValidate = dtHeaderData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = importValidations.SaleSRBillPRHeaderValidation(dtValidate);
                                    string DocID = dtValidate.Rows[0]["DOC ID *"].ToString();
                                    int count = dtHeaderData.AsEnumerable().Count(row => row["DOC ID *"].ToString() == DocID);
                                    if(count > 1)
                                    {
                                        RowError += "Doc ID : Doc ID " + DocID + " exists multiple times in the data. Please ensure each Doc ID is unique.\n";
                                    }
                                    RowError += importValidations.SaleSRBillPRNetAmtValidation(dtValidate, dtItemsData);
                                    if (string.IsNullOrEmpty(RowError)) 
                                    {
                                        DataRow drW = dtHeaderWrongValues.NewRow();
                                        drW["DOC ID *"] = dtValidate.Rows[0]["DOC ID *"].ToString();
                                        drW["DOC PREFIX *"] = dtValidate.Rows[0]["DOC PREFIX *"].ToString();
                                        drW["BRANCH NAME *"] = dtValidate.Rows[0]["BRANCH NAME *"].ToString();
                                        drW["DOC DATE *"] = dtValidate.Rows[0]["DOC DATE *"].ToString();
                                        drW["PARTY NAME *"] = dtValidate.Rows[0]["PARTY NAME *"].ToString();
                                        drW["PAYMENT MODE *"] = dtValidate.Rows[0]["PAYMENT MODE *"].ToString();
                                        drW["CREDIT TERM *"] = dtValidate.Rows[0]["CREDIT TERM *"].ToString();
                                        drW["ADDITIONAL DISCOUNT"] = dtValidate.Rows[0]["ADDITIONAL DISCOUNT"].ToString();
                                        drW["TRADE DISCOUNT"] = dtValidate.Rows[0]["TRADE DISCOUNT"].ToString();
                                        drW["FRIEGHT"] = dtValidate.Rows[0]["FRIEGHT"].ToString();
                                        drW["OTHER CHARGE"] = dtValidate.Rows[0]["OTHER CHARGE"].ToString();
                                        drW["NET AMOUNT *"] = dtValidate.Rows[0]["NET AMOUNT *"].ToString();
                                        drW["STATUS *"] = dtValidate.Rows[0]["STATUS *"].ToString();
                                        drW["BEAT NAME"] = dtValidate.Rows[0]["BEAT NAME"].ToString();
                                        drW["SALESMAN NAME"] = dtValidate.Rows[0]["SALESMAN NAME"].ToString();
                                        drW["WRITEOFF AMT"] = dtValidate.Rows[0]["WRITEOFF AMT"].ToString();
                                        drW["TRANSACTION TYPE"] = dtValidate.Rows[0]["TRANSACTION TYPE"].ToString();
                                        drW["RETURN TYPE"] = dtValidate.Rows[0]["RETURN TYPE"].ToString();
                                        drW["REMARKS"] = dtValidate.Rows[0]["REMARKS"].ToString();
                                        drW["TRANSPORT MODE"] = dtValidate.Rows[0]["TRANSPORT MODE"].ToString();
                                        drW["TRANSPORT TYPE"] = dtValidate.Rows[0]["TRANSPORT TYPE"].ToString();
                                        drW["VECHICLE NUMBER"] = dtValidate.Rows[0]["VECHICLE NUMBER"].ToString();
                                        drW["TRANSPORT ID"] = dtValidate.Rows[0]["TRANSPORT ID"].ToString();
                                        drW["TRANSPORT NAME"] = dtValidate.Rows[0]["TRANSPORT NAME"].ToString();
                                        drW["DISTANCE"] = dtValidate.Rows[0]["DISTANCE"].ToString();
                                        drW["IRN"] = dtValidate.Rows[0]["IRN"].ToString();
                                        drW["ACKNOWLEDGE NO"] = dtValidate.Rows[0]["ACKNOWLEDGE NO"].ToString();
                                        drW["ACKNOWLEDGE DATE"] = dtValidate.Rows[0]["ACKNOWLEDGE DATE"].ToString();
                                        drW["ACKNOWLEDGE STATUS"] = dtValidate.Rows[0]["ACKNOWLEDGE STATUS"].ToString();
                                        drW["SIGNED QRCODE"] = dtValidate.Rows[0]["SIGNED QRCODE"].ToString();
                                        drW["EWAY BILL NO"] = dtValidate.Rows[0]["EWAY BILL NO"].ToString();
                                        drW["ERROR"] = RowError;
                                        dtHeaderWrongValues.Rows.Add(drW);
                                        //Correct values only
                                        DataRow drC = dtHeaderCorrectValues.NewRow();
                                        drC["DOC ID *"] = dtValidate.Rows[0]["DOC ID *"].ToString();
                                        drC["DOC PREFIX *"] = dtValidate.Rows[0]["DOC PREFIX *"].ToString();
                                        drC["BRANCH NAME *"] = importValidations.BranchID;
                                        drC["DOC DATE *"] = dtValidate.Rows[0]["DOC DATE *"].ToString();
                                        drC["PARTY NAME *"] = importValidations.PartyID;
                                        drC["PAYMENT MODE *"] = importValidations.PaymentModeID;
                                        drC["CREDIT TERM *"] = importValidations.CreditTermID;
                                        drC["ADDITIONAL DISCOUNT"] = dtValidate.Rows[0]["ADDITIONAL DISCOUNT"].ToString();
                                        drC["TRADE DISCOUNT"] = dtValidate.Rows[0]["TRADE DISCOUNT"].ToString();
                                        drC["FRIEGHT"] = dtValidate.Rows[0]["FRIEGHT"].ToString();
                                        drC["OTHER CHARGE"] = dtValidate.Rows[0]["OTHER CHARGE"].ToString();
                                        drC["NET AMOUNT *"] = dtValidate.Rows[0]["NET AMOUNT *"].ToString();
                                        drC["STATUS *"] = importValidations.StatusID;
                                        drC["BEAT NAME"] = importValidations.BeatID;
                                        drC["SALESMAN NAME"] = importValidations.SalesmanID;
                                        drC["WRITEOFF AMT"] = dtValidate.Rows[0]["WRITEOFF AMT"].ToString();
                                        drC["TRANSACTION TYPE"] = dtValidate.Rows[0]["TRANSACTION TYPE"].ToString();
                                        drC["RETURN TYPE"] = importValidations.ReturnTypeID;
                                        drC["REMARKS"] = dtValidate.Rows[0]["REMARKS"].ToString();
                                        drC["TRANSPORT MODE"] = dtValidate.Rows[0]["TRANSPORT MODE"].ToString();
                                        drC["TRANSPORT TYPE"] = dtValidate.Rows[0]["TRANSPORT TYPE"].ToString();
                                        drC["VECHICLE NUMBER"] = importValidations.VehicleID;
                                        drC["TRANSPORT ID"] = dtValidate.Rows[0]["TRANSPORT ID"].ToString();
                                        drC["TRANSPORT NAME"] = dtValidate.Rows[0]["TRANSPORT NAME"].ToString();
                                        drC["DISTANCE"] = dtValidate.Rows[0]["DISTANCE"].ToString();
                                        drC["IRN"] = dtValidate.Rows[0]["IRN"].ToString();
                                        drC["ACKNOWLEDGE NO"] = dtValidate.Rows[0]["ACKNOWLEDGE NO"].ToString();
                                        drC["ACKNOWLEDGE DATE"] = dtValidate.Rows[0]["ACKNOWLEDGE DATE"].ToString();
                                        drC["ACKNOWLEDGE STATUS"] = dtValidate.Rows[0]["ACKNOWLEDGE STATUS"].ToString();
                                        drC["SIGNED QRCODE"] = dtValidate.Rows[0]["SIGNED QRCODE"].ToString();
                                        drC["EWAY BILL NO"] = dtValidate.Rows[0]["EWAY BILL NO"].ToString();
                                        drC["Error"] = nIndex;
                                        dtHeaderCorrectValues.Rows.Add(drC);
                                        nIndex++;
                                    }
                                    else
                                    {
                                        NoErrorsinHeader = false;
                                        DataRow drW = dtHeaderWrongValues.NewRow();
                                        drW["DOC ID *"] = dtValidate.Rows[0]["DOC ID *"].ToString();
                                        drW["DOC PREFIX *"] = dtValidate.Rows[0]["DOC PREFIX *"].ToString();
                                        drW["BRANCH NAME *"] = dtValidate.Rows[0]["BRANCH NAME *"].ToString();
                                        drW["DOC DATE *"] = dtValidate.Rows[0]["DOC DATE *"].ToString();
                                        drW["PARTY NAME *"] = dtValidate.Rows[0]["PARTY NAME *"].ToString();
                                        drW["PAYMENT MODE *"] = dtValidate.Rows[0]["PAYMENT MODE *"].ToString();
                                        drW["CREDIT TERM *"] = dtValidate.Rows[0]["CREDIT TERM *"].ToString();
                                        drW["ADDITIONAL DISCOUNT"] = dtValidate.Rows[0]["ADDITIONAL DISCOUNT"].ToString();
                                        drW["TRADE DISCOUNT"] = dtValidate.Rows[0]["TRADE DISCOUNT"].ToString();
                                        drW["FRIEGHT"] = dtValidate.Rows[0]["FRIEGHT"].ToString();
                                        drW["OTHER CHARGE"] = dtValidate.Rows[0]["OTHER CHARGE"].ToString();
                                        drW["NET AMOUNT *"] = dtValidate.Rows[0]["NET AMOUNT *"].ToString();
                                        drW["STATUS *"] = dtValidate.Rows[0]["STATUS *"].ToString();
                                        drW["BEAT NAME"] = dtValidate.Rows[0]["BEAT NAME"].ToString();
                                        drW["SALESMAN NAME"] = dtValidate.Rows[0]["SALESMAN NAME"].ToString();
                                        drW["WRITEOFF AMT"] = dtValidate.Rows[0]["WRITEOFF AMT"].ToString();
                                        drW["TRANSACTION TYPE"] = dtValidate.Rows[0]["TRANSACTION TYPE"].ToString();
                                        drW["RETURN TYPE"] = dtValidate.Rows[0]["RETURN TYPE"].ToString();
                                        drW["REMARKS"] = dtValidate.Rows[0]["REMARKS"].ToString();
                                        drW["TRANSPORT MODE"] = dtValidate.Rows[0]["TRANSPORT MODE"].ToString();
                                        drW["TRANSPORT TYPE"] = dtValidate.Rows[0]["TRANSPORT TYPE"].ToString();
                                        drW["VECHICLE NUMBER"] = dtValidate.Rows[0]["VECHICLE NUMBER"].ToString();
                                        drW["TRANSPORT ID"] = dtValidate.Rows[0]["TRANSPORT ID"].ToString();
                                        drW["TRANSPORT NAME"] = dtValidate.Rows[0]["TRANSPORT NAME"].ToString();
                                        drW["DISTANCE"] = dtValidate.Rows[0]["DISTANCE"].ToString();
                                        drW["IRN"] = dtValidate.Rows[0]["IRN"].ToString();
                                        drW["ACKNOWLEDGE NO"] = dtValidate.Rows[0]["ACKNOWLEDGE NO"].ToString();
                                        drW["ACKNOWLEDGE DATE"] = dtValidate.Rows[0]["ACKNOWLEDGE DATE"].ToString();
                                        drW["ACKNOWLEDGE STATUS"] = dtValidate.Rows[0]["ACKNOWLEDGE STATUS"].ToString();
                                        drW["SIGNED QRCODE"] = dtValidate.Rows[0]["SIGNED QRCODE"].ToString();
                                        drW["EWAY BILL NO"] = dtValidate.Rows[0]["EWAY BILL NO"].ToString();
                                        drW["ERROR"] = RowError;
                                        dtHeaderWrongValues.Rows.Add(drW);
                                    }
                                }
                                #endregion
                                #region Items data validation
                                job.Progress = 60;
                                job.ProgressMessage = "Validate Detail Data..."; //Thread.Sleep(3000);                                                                
                                nIndex = 1;                                
                                foreach (DataRow item in dtItemsData.Rows)
                                {                                                                        
                                    DataTable dtValidate = dtItemsData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = importValidations.SaleSRBillPRDetailValidation(dtValidate);
                                    if (string.IsNullOrEmpty(RowError))
                                    {
                                        DataRow drW = dtItemsWrongValues.NewRow();
                                        drW["DOC ID *"] = dtValidate.Rows[0]["DOC ID *"].ToString();
                                        drW["PRODUCT NAME *"] = dtValidate.Rows[0]["PRODUCT NAME *"].ToString();
                                        drW["BATCH NUMBER"] = dtValidate.Rows[0]["BATCH NUMBER"].ToString();
                                        drW["PKD DATE"] = dtValidate.Rows[0]["PKD DATE"].ToString();
                                        drW["EXPIRY DATE"] = dtValidate.Rows[0]["EXPIRY DATE"].ToString();
                                        drW["ACTUAL QTY"] = dtValidate.Rows[0]["ACTUAL QTY"].ToString();
                                        drW["DAMAGE QTY"] = dtValidate.Rows[0]["DAMAGE QTY"].ToString();
                                        drW["FREE QTY"] = dtValidate.Rows[0]["FREE QTY"].ToString();
                                        drW["UOM PURCHASE PRICE"] = dtValidate.Rows[0]["UOM PURCHASE PRICE"].ToString();
                                        drW["UOM SALE PRICE"] = dtValidate.Rows[0]["UOM SALE PRICE"].ToString();
                                        drW["UOM ECP PRICE"] = dtValidate.Rows[0]["UOM ECP PRICE"].ToString();
                                        drW["UOM SPL PRICE"] = dtValidate.Rows[0]["UOM SPL PRICE"].ToString();
                                        drW["UOM MRP PRICE"] = dtValidate.Rows[0]["UOM MRP PRICE"].ToString();
                                        drW["RETURN PRICE"] = dtValidate.Rows[0]["RETURN PRICE"].ToString();
                                        drW["TAX NAME *"] = dtValidate.Rows[0]["TAX NAME *"].ToString();
                                        drW["PRODUCT DISCOUNT"] = dtValidate.Rows[0]["PRODUCT DISCOUNT"].ToString();
                                        drW["REASON NAME"] = dtValidate.Rows[0]["REASON NAME"].ToString();
                                        drW["Error"] = RowError;
                                        dtItemsWrongValues.Rows.Add(drW);

                                        DataRow drC = dtItemsCorrectValues.NewRow();
                                        drC["DOC ID *"] = dtValidate.Rows[0]["DOC ID *"].ToString();
                                        drC["PRODUCT NAME *"] = importValidations.ProductID;
                                        drC["BATCH NUMBER"] = dtValidate.Rows[0]["BATCH NUMBER"].ToString();
                                        drC["PKD DATE"] = dtValidate.Rows[0]["PKD DATE"].ToString();
                                        drC["EXPIRY DATE"] = dtValidate.Rows[0]["EXPIRY DATE"].ToString();
                                        drC["ACTUAL QTY"] = dtValidate.Rows[0]["ACTUAL QTY"].ToString();
                                        drC["DAMAGE QTY"] = dtValidate.Rows[0]["DAMAGE QTY"].ToString();
                                        drC["FREE QTY"] = dtValidate.Rows[0]["FREE QTY"].ToString();
                                        drC["UOM PURCHASE PRICE"] = dtValidate.Rows[0]["UOM PURCHASE PRICE"].ToString();
                                        drC["UOM SALE PRICE"] = dtValidate.Rows[0]["UOM SALE PRICE"].ToString();
                                        drC["UOM ECP PRICE"] = dtValidate.Rows[0]["UOM ECP PRICE"].ToString();
                                        drC["UOM SPL PRICE"] = dtValidate.Rows[0]["UOM SPL PRICE"].ToString();
                                        drC["UOM MRP PRICE"] = dtValidate.Rows[0]["UOM MRP PRICE"].ToString();
                                        drC["RETURN PRICE"] = dtValidate.Rows[0]["RETURN PRICE"].ToString();
                                        drC["TAX NAME *"] = importValidations.TaxID;
                                        drC["PRODUCT DISCOUNT"] = dtValidate.Rows[0]["PRODUCT DISCOUNT"].ToString();
                                        drC["REASON NAME"] = importValidations.ReasonID;
                                        drC["Error"] = nIndex;
                                        dtItemsCorrectValues.Rows.Add(drC);
                                        nIndex++;
                                    }
                                    else
                                    {                                        
                                        NoErrorsinItems = false;
                                        DataRow drW = dtItemsWrongValues.NewRow();
                                        drW["DOC ID *"] = dtValidate.Rows[0]["DOC ID *"].ToString();
                                        drW["PRODUCT NAME *"] = dtValidate.Rows[0]["PRODUCT NAME *"].ToString();
                                        drW["BATCH NUMBER"] = dtValidate.Rows[0]["BATCH NUMBER"].ToString();
                                        drW["PKD DATE"] = dtValidate.Rows[0]["PKD DATE"].ToString();
                                        drW["EXPIRY DATE"] = dtValidate.Rows[0]["EXPIRY DATE"].ToString();
                                        drW["ACTUAL QTY"] = dtValidate.Rows[0]["ACTUAL QTY"].ToString();
                                        drW["DAMAGE QTY"] = dtValidate.Rows[0]["DAMAGE QTY"].ToString();
                                        drW["FREE QTY"] = dtValidate.Rows[0]["FREE QTY"].ToString();
                                        drW["UOM PURCHASE PRICE"] = dtValidate.Rows[0]["UOM PURCHASE PRICE"].ToString();
                                        drW["UOM SALE PRICE"] = dtValidate.Rows[0]["UOM SALE PRICE"].ToString();
                                        drW["UOM ECP PRICE"] = dtValidate.Rows[0]["UOM ECP PRICE"].ToString();
                                        drW["UOM SPL PRICE"] = dtValidate.Rows[0]["UOM SPL PRICE"].ToString();
                                        drW["UOM MRP PRICE"] = dtValidate.Rows[0]["UOM MRP PRICE"].ToString();
                                        drW["RETURN PRICE"] = dtValidate.Rows[0]["RETURN PRICE"].ToString();
                                        drW["TAX NAME *"] = dtValidate.Rows[0]["TAX NAME *"].ToString();
                                        drW["PRODUCT DISCOUNT"] = dtValidate.Rows[0]["PRODUCT DISCOUNT"].ToString();
                                        drW["REASON NAME"] = dtValidate.Rows[0]["REASON NAME"].ToString();
                                        drW["ERROR"] = RowError;
                                        dtItemsWrongValues.Rows.Add(drW);
                                    }                                    
                                }                               
                                #endregion
                                #region save
                                if (NoErrorsinHeader && NoErrorsinItems)
                                {
                                    DataTable dtResult = new DataTable();
                                    job.Progress = 75;
                                    job.ProgressMessage = "Bill Save Progress..."; //Thread.Sleep(10000);
                                    DataRow[] drbills = dtHeaderCorrectValues.Select("[DOC PREFIX *] = 'Bill'", "[DOC ID *] ASC");
                                    if (drbills.Length > 0)
                                    {
                                        dtBillHeader = drbills.CopyToDataTable();
                                    }
                                    if (dtBillHeader.Rows.Count > 0)
                                    {
                                        dtResult = importValidations.SavePurchaseBill(dtBillHeader, dtItemsCorrectValues, UserID);
                                        int BillNotCompletecount = dtResult.AsEnumerable().Count(row => row["Error"].ToString() != "Completed");
                                        if (BillNotCompletecount > 0)
                                        {
                                            job.ProgressMessage = "Error Occured when Save Bill...";
                                            foreach (DataRow item in dtResult.Rows)
                                            {
                                                string DocPrefix = item["DocPrefix"].ToString();
                                                string DocID = item["DocID"].ToString();
                                                string DocDate = item["DocDate"].ToString();
                                                string ErrororInfoMsg = item["Error"].ToString();
                                                dtHeaderWrongValues.AsEnumerable()
                                                .Where(r => r.Field<string>("DOC ID *") == DocID &&
                                                (r.Field<string>("DOC Prefix *") ?? "").ToLower() == (DocPrefix ?? "").ToLower())
                                                .ToList().ForEach(r => r["ERROR"] = ErrororInfoMsg);

                                                dtItemsWrongValues.AsEnumerable()
                                                                        .Where(r => r.Field<string>("DOC ID *") == DocID)
                                                                        .ToList()
                                                                        .ForEach(r => r["ERROR"] = ErrororInfoMsg);
                                            }
                                            strFileName = TransName + "_error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                            clsExport.strFileName = strFileName;
                                            clsExport.TransImport_ExportToExcel(dtHeaderWrongValues, dtItemsWrongValues, true);
                                            DataSet dtset = new DataSet("Help Data");
                                            dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 1));
                                            dtset.Tables[0].TableName = "Header";
                                            dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 2));
                                            dtset.Tables[1].TableName = "Detail";
                                            dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 4));
                                            dtset.Tables[2].TableName = "Help";
                                            job.ProgressMessage = "Bill Errors Downloading ...";
                                            fullPath = Path.Combine(strFilePath, strFileName + ".xlsx");
                                            clsExport.AddingHelptoExcel(fullPath, 3, dtset);
                                            job.ProgressMessage = "Bill Errors Downloaded ...";
                                            job.FilePath = fullPath;
                                            job.IsCompleted = true;
                                            MTM.Add(new ImportResults()
                                            {
                                                ID = "2",
                                                Msg = "Error occured when Save Bill",
                                            });
                                            return MTM;
                                        }
                                        //else
                                        //{
                                        //    job.Progress = 100;
                                        //    job.ProgressMessage = "Data Saved Successfully...";
                                        //    job.IsCompleted = true;
                                        //}
                                    }
                                    job.Progress = 80;
                                    job.ProgressMessage = "SR Save Progress..."; //Thread.Sleep(10000);
                                    DataRow[] drsrs = dtHeaderCorrectValues.Select("[DOC PREFIX *] = 'SR'", "[DOC ID *] ASC");
                                    if (drsrs.Length > 0)
                                    {
                                        dtSRHeader = drsrs.CopyToDataTable();
                                    }                                    
                                    if (dtSRHeader.Rows.Count > 0)
                                    {
                                        dtResult = importValidations.SaveSalesReturn(dtSRHeader, dtItemsCorrectValues, UserID);
                                        int SRNotCompletecount = dtResult.AsEnumerable().Count(row => row["Error"].ToString() != "Completed");
                                        if (SRNotCompletecount > 0)
                                        {
                                            job.ProgressMessage = "Error Occured when Save SR...";
                                            foreach (DataRow item in dtResult.Rows)
                                            {
                                                string DocPrefix = item["DocPrefix"].ToString();
                                                string DocID = item["DocID"].ToString();
                                                string DocDate = item["DocDate"].ToString();
                                                string ErrororInfoMsg = item["Error"].ToString();
                                                dtHeaderWrongValues.AsEnumerable()
                                                .Where(r => r.Field<string>("DOC ID *") == DocID &&
                                                (r.Field<string>("DOC Prefix *") ?? "").ToLower() == (DocPrefix ?? "").ToLower())
                                                .ToList().ForEach(r => r["ERROR"] = ErrororInfoMsg);

                                                dtItemsWrongValues.AsEnumerable()
                                                                        .Where(r => r.Field<string>("DOC ID *") == DocID)
                                                                        .ToList()
                                                                        .ForEach(r => r["ERROR"] = ErrororInfoMsg);
                                            }
                                            strFileName = TransName + "_error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                            clsExport.strFileName = strFileName;
                                            clsExport.TransImport_ExportToExcel(dtHeaderWrongValues, dtItemsWrongValues, true);
                                            DataSet dtset = new DataSet("Help Data");
                                            dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 1));
                                            dtset.Tables[0].TableName = "Header";
                                            dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 2));
                                            dtset.Tables[1].TableName = "Detail";
                                            dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 4));
                                            dtset.Tables[2].TableName = "Help";
                                            job.ProgressMessage = "SR Errors Downloading ...";
                                            fullPath = Path.Combine(strFilePath, strFileName + ".xlsx");
                                            clsExport.AddingHelptoExcel(fullPath, 3, dtset);
                                            job.ProgressMessage = "SR Errors Downloaded ...";
                                            job.FilePath = fullPath;
                                            job.IsCompleted = true;
                                            MTM.Add(new ImportResults()
                                            {
                                                ID = "2",
                                                Msg = "Error occured when Save SR",
                                            });
                                            return MTM;
                                        }
                                    }
                                    job.Progress = 85;
                                    job.ProgressMessage = "Sales Save Progress..."; //Thread.Sleep(10000);
                                    DataRow[] drinvoicess = dtHeaderCorrectValues.Select("[DOC PREFIX *] = 'Sales'", "[DOC ID *] ASC");
                                    if (drinvoicess.Length > 0)
                                    {
                                        dtSalesHeader = drinvoicess.CopyToDataTable();
                                    }
                                    if (dtSalesHeader.Rows.Count > 0)
                                    {
                                        dtResult = importValidations.SaveSales(dtSalesHeader, dtItemsCorrectValues, UserID);
                                        int InvoiceNotCompletecount = dtResult.AsEnumerable().Count(row => row["Error"].ToString() != "Completed");
                                        if (InvoiceNotCompletecount > 0)
                                        {
                                            job.ProgressMessage = "Error Occured when Save Sales...";
                                            foreach (DataRow item in dtResult.Rows)
                                            {
                                                string DocPrefix = item["DocPrefix"].ToString();
                                                string DocID = item["DocID"].ToString();
                                                string DocDate = item["DocDate"].ToString();
                                                string ErrororInfoMsg = item["Error"].ToString();
                                                dtHeaderWrongValues.AsEnumerable()
                                                .Where(r => r.Field<string>("DOC ID *") == DocID &&
                                                (r.Field<string>("DOC Prefix *") ?? "").ToLower() == (DocPrefix ?? "").ToLower())
                                                .ToList().ForEach(r => r["ERROR"] = ErrororInfoMsg);

                                                dtItemsWrongValues.AsEnumerable()
                                                                        .Where(r => r.Field<string>("DOC ID *") == DocID)
                                                                        .ToList()
                                                                        .ForEach(r => r["ERROR"] = ErrororInfoMsg);
                                            }
                                            strFileName = TransName + "_error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                            clsExport.strFileName = strFileName;
                                            clsExport.TransImport_ExportToExcel(dtHeaderWrongValues, dtItemsWrongValues, true);
                                            DataSet dtset = new DataSet("Help Data");
                                            dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 1));
                                            dtset.Tables[0].TableName = "Header";
                                            dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 2));
                                            dtset.Tables[1].TableName = "Detail";
                                            dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 4));
                                            dtset.Tables[2].TableName = "Help";
                                            job.ProgressMessage = "Sales Errors Downloading ...";
                                            fullPath = Path.Combine(strFilePath, strFileName + ".xlsx");
                                            clsExport.AddingHelptoExcel(fullPath, 3, dtset);
                                            job.ProgressMessage = "Sales Errors Downloaded ...";
                                            job.FilePath = fullPath;
                                            job.IsCompleted = true;
                                            MTM.Add(new ImportResults()
                                            {
                                                ID = "2",
                                                Msg = "Error occured when Save Sales",
                                            });
                                            return MTM;
                                        }
                                    }
                                    //purchase return
                                    job.Progress = 90;
                                    job.ProgressMessage = "PR Save Progress..."; //Thread.Sleep(10000);
                                    DataRow[] drprss = dtHeaderCorrectValues.Select("[DOC PREFIX *] = 'PR'", "[DOC ID *] ASC");
                                    if (drprss.Length > 0)
                                    {
                                        dtPRHeader = drprss.CopyToDataTable();
                                    }
                                    if (dtPRHeader.Rows.Count > 0)
                                    {
                                        dtResult = importValidations.SavePurchaseReturn(dtPRHeader, dtItemsCorrectValues, UserID);
                                        int PRNotCompletecount = dtResult.AsEnumerable().Count(row => row["Error"].ToString() != "Completed");
                                        if (PRNotCompletecount > 0)
                                        {
                                            job.ProgressMessage = "Error Occured when Save PR...";
                                            foreach (DataRow item in dtResult.Rows)
                                            {
                                                string DocPrefix = item["DocPrefix"].ToString();
                                                string DocID = item["DocID"].ToString();
                                                string DocDate = item["DocDate"].ToString();
                                                string ErrororInfoMsg = item["Error"].ToString();
                                                dtHeaderWrongValues.AsEnumerable()
                                                .Where(r => r.Field<string>("DOC ID *") == DocID &&
                                                (r.Field<string>("DOC Prefix *") ?? "").ToLower() == (DocPrefix ?? "").ToLower())
                                                .ToList().ForEach(r => r["ERROR"] = ErrororInfoMsg);

                                                dtItemsWrongValues.AsEnumerable()
                                                                        .Where(r => r.Field<string>("DOC ID *") == DocID)
                                                                        .ToList()
                                                                        .ForEach(r => r["ERROR"] = ErrororInfoMsg);
                                            }
                                            strFileName = TransName + "_error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                            clsExport.strFileName = strFileName;
                                            clsExport.TransImport_ExportToExcel(dtHeaderWrongValues, dtItemsWrongValues, true);
                                            DataSet dtset = new DataSet("Help Data");
                                            dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 1));
                                            dtset.Tables[0].TableName = "Header";
                                            dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 2));
                                            dtset.Tables[1].TableName = "Detail";
                                            dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 4));
                                            dtset.Tables[2].TableName = "Help";
                                            job.ProgressMessage = "PR Errors Downloading ...";
                                            fullPath = Path.Combine(strFilePath, strFileName + ".xlsx");
                                            clsExport.AddingHelptoExcel(fullPath, 3, dtset);
                                            job.ProgressMessage = "PR Errors Downloaded ...";
                                            job.FilePath = fullPath;
                                            job.IsCompleted = true;
                                            MTM.Add(new ImportResults()
                                            {
                                                ID = "2",
                                                Msg = "Error occured when Save Sales",
                                            });
                                            return MTM;
                                        }
                                    }

                                    job.Progress = 100;
                                    job.ProgressMessage = "Data Saved Successfully...";
                                    job.IsCompleted = true;
                                }
                                else
                                {
                                    strFileName = TransName + "_error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                    clsExport.strFileName = strFileName;
                                    clsExport.TransImport_ExportToExcel(dtHeaderWrongValues, dtItemsWrongValues, true);
                                    DataSet dtset = new DataSet("Help Data");
                                    dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 1));
                                    dtset.Tables[0].TableName = "Header";                                    
                                    job.ProgressMessage = "Detail Data Export..."; //Thread.Sleep(3000);
                                    dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 2));
                                    dtset.Tables[1].TableName = "Detail";                                                                        
                                    //dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 3));
                                    //dtset.Tables[0].TableName = "Serial";                                    
                                    dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 4));
                                    dtset.Tables[2].TableName = "Help";
                                    job.ProgressMessage = "Error occured. Downloading errors...";
                                    fullPath = Path.Combine(strFilePath, strFileName + ".xlsx");
                                    clsExport.AddingHelptoExcel(fullPath, 3, dtset);
                                    job.ProgressMessage = "Error occured. Errors Downloaded ...";
                                    job.FilePath = fullPath;

                                    job.IsCompleted = true;
                                }                                   
                                #endregion
                                
                            }
                            else
                            {
                                if (dtHeaderData.Rows.Count == 0 && dtItemsData.Rows.Count == 0)
                                {
                                    job.ErrorID = 1;
                                    job.ErrorMessage = "No Records found in Header and Items Sheet";                                   
                                    job.IsCompleted = true;
                                }
                                else if (dtHeaderData.Rows.Count == 0)
                                {
                                    job.ErrorID = 2;
                                    job.ErrorMessage = "No Records found in Header Sheet";
                                    job.IsCompleted = true;
                                }
                                else if (dtItemsData.Rows.Count == 0)
                                {
                                    job.ErrorID = 3;
                                    job.ErrorMessage = "No Records found in Items Sheet";
                                    job.IsCompleted = true;
                                }
                            }
                        }
                        
                    }
                    else
                    {
                        if (!blHeaderResult && !blItemsResult)
                        {
                            job.ErrorID = 21;
                            job.ErrorMessage = "Column Name mismatching in Header and Items Sheet";                            
                            job.IsCompleted = true;
                        }
                        else if (!blHeaderResult)
                        {                            
                            job.ErrorID = 22;
                            job.ErrorMessage = "Column Name mismatching in Header Sheet";
                            job.IsCompleted = true;
                        }
                        else if (!blItemsResult)
                        {
                            job.ErrorID = 23;
                            job.ErrorMessage = "Column Name mismatching in Items Sheet";
                            job.IsCompleted = true;
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
