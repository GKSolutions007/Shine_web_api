using SampWebApi.BuisnessLayer;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Data;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using System.Configuration;
using System.Threading.Tasks;
using SampWebApi.Import_Utility;
using SampWebApi.Models;
using System.IO;
using System.Web;
using System.Net.Http.Headers;

namespace SampWebApi.Controllers
{
   
    public class ShinecodesController : ApiController
    {
        clsBusinessLayer objBL = new clsBusinessLayer();
        string connectionString = clsEncryptDecrypt.Decrypt(ConfigurationManager.ConnectionStrings["ShinecodeConnection"].ConnectionString);

        public string strExtension = ".xlsx";
        public string strFileName = "";
        public string strSheetName { get; set; }
        public string strFilePath
        {
            get; set;
        }        
        public DataTable dtData { get; set; }
        public DataTable dtHeaderData { get; set; }
        public DataTable dtItemsData { get; set; }
        DataTable dtBillHeader = new DataTable(), dtPRHeader = new DataTable(), dtSalesHeader = new DataTable(), dtSRHeader = new DataTable(),
            dtBillDetail = new DataTable(), dtPRDetail = new DataTable(), dtSalesDetail = new DataTable(), dtSRDetail = new DataTable();
        [CookieAuthorize]
        [HttpGet]
        [Route("api/shinecode/masterdata")]
        public IHttpActionResult resetlogin(string mastertype)
        {
            try
            {

                DataTable DDT = new DataTable();
                using (var conn = new SqlConnection(connectionString))
                {
                    conn.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspgetMasterdata", conn);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", 1);
                    sqlCommand.Parameters.AddWithValue("@Mastertype", mastertype);
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    conn.Close();
                }
                return Ok(DDT);
            }
            catch (Exception ex)
            {
                objBL.BL_WriteErrorMsginLog("Login", "resetlogin", ex.Message);
            }
            return Ok();
        }
        [System.Web.Http.HttpGet]
        [System.Web.Http.Route("api/shinecode/template")]
        public HttpResponseMessage ExportTemplate(int TransID, string TransName, string FromDate = null, string ToDate = null)
        {
            try
            {
                strFilePath = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"];
                strFileName = TransName + "_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                clsExportData objExport = new clsExportData();
                objExport.strFileName = strFileName;
                objExport.strFilePath = strFilePath;
                if (TransID == 1 || TransID == 2 || TransID == 3 || TransID == 4)
                {                   
                    objExport.OpenTransTemplate(
                        TransID == 1 ? Import_Utility.clsExportData.AddSC_Customers(false) :
                        TransID == 2 ? Import_Utility.clsExportData.AddSC_Product(false) :
                        Import_Utility.clsExportData.AddSC_Vendor(false));
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
            catch (Exception ex)
            {
                objBL.BL_WriteErrorMsginLog("TransactionImport", "transactionimport/template", ex.Message);
                return null;
            }
        }
        [System.Web.Http.HttpPost]
        [System.Web.Http.Route("api/shinecode/startexport")]
        public IHttpActionResult StartExport([FromBody] ExportRequest req)//int TransID, string TransName, string FromDate = null, string ToDate = null
        {
            try
            {
                string jobId = Guid.NewGuid().ToString();

                ExportJobManager.Jobs[jobId] = new ExportJobStatus();
                int TransID = req.TransID;
                string TransName = req.TransName;
                string FromDate = req.FromDate;
                string ToDate = req.ToDate;
                int exptype = req.ExportType;
                Task.Run(() => GenerateExcel(jobId, exptype,TransID, TransName, FromDate, ToDate));

                return Ok(jobId);
            }
            catch (Exception ex)
            {
                objBL.BL_WriteErrorMsginLog("Shinecodes", "shinecode/startexport", ex.Message);
            }
            return Ok();
        }
        private void GenerateExcel(string jobId,int ExportType, int TransID, string TransName, string FromDate, string ToDate)
        {
            try
            {
                var job = ExportJobManager.Jobs[jobId];

                string strFilePath = ConfigurationManager.AppSettings["SupportFilePath"];
                string strFileName = (ExportType == 2 ? "My_" : "SC_") + TransName + "_export_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                string fullPath = strFilePath + strFileName + ".xlsx";

                clsExportData objExport = new clsExportData();
                objExport.strFileName = strFileName;
                objExport.strFilePath = strFilePath;

                job.Progress = 10;
                job.ProgressMessage = "Initialize...";//Thread.Sleep(3000);

                if (TransID == 1 || TransID == 2 || TransID == 3)
                {
                    job.Progress = 20;
                    job.ProgressMessage = "Fetching data...";//Thread.Sleep(3000);
                    DataTable DDT = new DataTable();
                    if (ExportType == 1)
                    {
                        using (var conn = new SqlConnection(connectionString))
                        {
                            conn.Open();
                            SqlCommand sqlCommand = new SqlCommand("uspgetMasterdata", conn);
                            sqlCommand.CommandType = CommandType.StoredProcedure;
                            sqlCommand.Parameters.AddWithValue("@Mode", 1);
                            sqlCommand.Parameters.AddWithValue("@Mastertype", TransID);
                            SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                            SDA.Fill(DDT);
                            conn.Close();
                        }
                    }
                    else
                    {
                        DDT = objBL.BL_ExecuteParamSP("uspgetShinecodeMasterdata", 1, TransID);
                    }
                    job.Progress = 40;
                    job.ProgressMessage = "Data fetched...";//Thread.Sleep(3000);

                    job.Progress = 60;
                    job.ProgressMessage = "Creating Excel File..."; //Thread.Sleep(3000);
                    objExport.TransImport_ExportToExcel(DDT, true);
                    job.Progress = 90;
                    job.ProgressMessage = "Downloading...";
                    //objExport.AddingHelptoExcel(fullPath, 3, dtset);
                    job.ProgressMessage = "Downloaded.";
                }                
                job.Progress = 100;
                job.FilePath = fullPath;
                job.IsCompleted = true;
            }
            catch (Exception ex)
            {
                ExportJobManager.Jobs[jobId].Progress = -1;
                objBL.BL_WriteErrorMsginLog("Shinecodes", "GenerateExcel", ex.Message);
            }
        }
        [System.Web.Http.HttpGet]
        [System.Web.Http.Route("api/shinecode/progress")]
        public IHttpActionResult GetProgress(string jobId)
        {
            try
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
            catch (Exception ex)
            {
                objBL.BL_WriteErrorMsginLog("Shinecodes", "shinecode/progress", ex.Message);
                return Ok();
            }
        }

        [System.Web.Http.HttpGet]
        [System.Web.Http.Route("api/shinecode/download")]
        public HttpResponseMessage Download(string jobId)
        {
            try
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
            catch (Exception ex)
            {
                objBL.BL_WriteErrorMsginLog("Shinecodes", "shinecode/download", ex.Message);
                return null;
            }

        }
        public class FileData
        {
            public string FileName { get; set; }
            public string FilePath { get; set; }
            public byte[] Content { get; set; }
        }
        [System.Web.Http.HttpPost]
        [System.Web.Http.Route("api/shinecode/startimport")]
        public IHttpActionResult StartImport()//int TransID, string TransName, string FromDate = null, string ToDate = null
        {
            try
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
                Task.Run(() =>
                {
                    MTM = RunTransactionImport(jobId, TransID, TransName, UserID, files);

                    return Ok(MTM);
                });

                return Ok(jobId);
            }
            catch (Exception ex)
            {
                objBL.BL_WriteErrorMsginLog("Shinecodes", "shinecode/startimport", ex.Message);
                return Ok();
            }
        }
        public List<ImportResults> RunTransactionImport(string jobId, string TransID, string TransName, string UserID, List<FileData> httpFile)
        {
            string Msg = "";
            string dt = "";
            List<ImportResults> MTM = new List<ImportResults>();
            clsExportData clsExport = new clsExportData();
            var job = ExportJobManager.Jobs[jobId];
            try
            {

                job.Progress = 5;
                job.ProgressMessage = "Initialize..."; //Thread.Sleep(3000);
                //var file = HttpContext.Current.Request.Files.Count > 1 ? HttpContext.Current.Request.Files[0] : null;
                //var data = Request.Files[0].InputStream.Read;                                                       
                if (httpFile.Count > 0)
                {
                    string fileName = "";
                    job.Progress = 10;
                    job.ProgressMessage = "Read file data..."; //Thread.Sleep(3000);
                                                               //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Upload Files\\";

                    string FPt = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"];
                    strFilePath = FPt + "Upload Files\\";
                    clsExport.strFilePath = FPt + "Upload Files\\";
                    strFileName = TransName + "_SCUpload_" + DateTime.Now.ToString("yyyyMMddHHmmss") + ".xlsx";
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
                    job.ProgressMessage = "Validate Columns..."; //Thread.Sleep(3000);
                    bool HeaderErrorColAlreadyExists = false;
                    #region Header Column Validation
                    
                    if (TransID == "1")//Customer
                    {
                        lstHeader = clsExportData.AddSC_Customers(false);
                        dtHeaderData = clsExport.TransactionColumnValidation(lstHeader, "Header", ref blHeaderResult);
                        if (!blHeaderResult)
                        {
                            lstHeader = clsExportData.AddSC_Customers(true);
                            dtHeaderData = clsExport.TransactionColumnValidation(lstHeader, "Header", ref blHeaderResult);
                            HeaderErrorColAlreadyExists = true;
                        }
                    }
                    else if (TransID == "2")//Product
                    {
                        lstHeader = clsExportData.AddSC_Product(false);
                        dtHeaderData = clsExport.TransactionColumnValidation(lstHeader, "Header", ref blHeaderResult);
                        if (!blHeaderResult)
                        {
                            lstHeader = clsExportData.AddSC_Product(true);
                            dtHeaderData = clsExport.TransactionColumnValidation(lstHeader, "Header", ref blHeaderResult);
                            HeaderErrorColAlreadyExists = true;
                        }
                    }
                    else if (TransID == "3")//Vendor
                    {
                        lstHeader = clsExportData.AddSC_Vendor(false);
                        dtHeaderData = clsExport.TransactionColumnValidation(lstHeader, "Header", ref blHeaderResult);
                        if (!blHeaderResult)
                        {
                            lstHeader = clsExportData.AddSC_Vendor(true);
                            dtHeaderData = clsExport.TransactionColumnValidation(lstHeader, "Header", ref blHeaderResult);
                            HeaderErrorColAlreadyExists = true;
                        }
                    }
                    
                    #endregion
                    job.Progress = 35;
                    if (blHeaderResult)
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
                        
                        
                        if (TransID == "1")//Customer
                        {
                            DataTable dtCustomer = new DataTable();
                            dtCustomer.Columns.Add("Serial", typeof(int));
                            dtCustomer.Columns.Add("Code", typeof(string));
                            dtCustomer.Columns.Add("Name", typeof(string));
                            dtCustomer.Columns.Add("Shinecode", typeof(string));
                            dtCustomer.Columns.Add("Address", typeof(string));
                            dtCustomer.Columns.Add("GSTNo", typeof(string));
                            dtCustomer.Columns.Add("ACTIVE", typeof(string));
                            
                            if (dtHeaderData.Rows.Count > 0)
                            {
                                job.Progress = 50;
                                job.ProgressMessage = "Validate Data..."; //Thread.Sleep(3000);
                                int currentProgress = job.Progress;
                                int nIndex = 1;
                                bool NoErrorsinHeader = true, NoErrorsinItems = true;
                                #region Header data validation
                                foreach (DataRow item in dtHeaderData.Rows)
                                {
                                    DataTable dtValidate = dtHeaderData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = importValidations.SC_CustomerValidation(dtValidate);
                                    //"CODE *",   "NAME *", "SHINE CODE *", "ADDRESS", "GST NUMBER",  "ACTIVE *"
                                    //"CODE *",   "NAME *", "SHINE CODE *", "HSN", "MFR NAME",  "ACTIVE *"
                                    if (string.IsNullOrEmpty(RowError))
                                    {
                                        DataRow drW = dtHeaderWrongValues.NewRow();
                                        drW["CODE *"] = dtValidate.Rows[0]["CODE *"].ToString();
                                        drW["NAME *"] = dtValidate.Rows[0]["NAME *"].ToString();
                                        drW["SHINE CODE *"] = dtValidate.Rows[0]["SHINE CODE *"].ToString();
                                        drW["ADDRESS"] = dtValidate.Rows[0]["ADDRESS"].ToString();
                                        drW["GST NUMBER"] = dtValidate.Rows[0]["GST NUMBER"].ToString();
                                        drW["ACTIVE *"] = dtValidate.Rows[0]["ACTIVE *"].ToString();
                                        drW["ERROR"] = RowError;
                                        dtHeaderWrongValues.Rows.Add(drW);
                                        //Correct values only
                                        DataRow drC = dtCustomer.NewRow();
                                        drC["Code"] = dtValidate.Rows[0]["CODE *"].ToString();
                                        drC["Name"] = dtValidate.Rows[0]["NAME *"].ToString();
                                        drC["Shinecode"] = dtValidate.Rows[0]["SHINE CODE *"].ToString();
                                        drC["Address"] = dtValidate.Rows[0]["ADDRESS"].ToString();
                                        drC["GSTNo"] = dtValidate.Rows[0]["GST NUMBER"].ToString();
                                        drC["Active"] = dtValidate.Rows[0]["ACTIVE *"].ToString();                                        
                                        drC["Serial"] = nIndex;
                                        dtCustomer.Rows.Add(drC);
                                        nIndex++;
                                    }
                                    else
                                    {
                                        NoErrorsinHeader = false;
                                        DataRow drW = dtHeaderWrongValues.NewRow();
                                        drW["CODE *"] = dtValidate.Rows[0]["CODE *"].ToString();
                                        drW["NAME *"] = dtValidate.Rows[0]["NAME *"].ToString();
                                        drW["SHINE CODE *"] = dtValidate.Rows[0]["SHINE CODE *"].ToString();
                                        drW["ADDRESS"] = dtValidate.Rows[0]["ADDRESS"].ToString();
                                        drW["GST NUMBER"] = dtValidate.Rows[0]["GST NUMBER"].ToString();
                                        drW["ACTIVE *"] = dtValidate.Rows[0]["ACTIVE *"].ToString();
                                        drW["ERROR"] = RowError;
                                        dtHeaderWrongValues.Rows.Add(drW);
                                    }
                                }
                                #endregion
                                
                                #region save
                                if (NoErrorsinHeader)
                                {
                                    DataTable dtResult = new DataTable();
                                    job.Progress = 85;
                                    job.ProgressMessage = "Customer Save Progress..."; //Thread.Sleep(10000);
                                    
                                    if (dtCustomer.Rows.Count > 0)
                                    {
                                        
                                        dtResult = SaveSCCustomerMaster(dtCustomer);
                                        if (dtResult.Columns.Count == 3)
                                        {
                                            job.ProgressMessage = "Error Occured when Save Customer...";                                            
                                            strFileName = TransName + "_error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                            clsExport.strFileName = strFileName;
                                            clsExport.TransImport_ExportToExcel(dtHeaderWrongValues, false);                                           
                                            job.ProgressMessage = "Customer Errors Downloading ...";
                                            fullPath = Path.Combine(strFilePath, strFileName + ".xlsx");                                            
                                            job.ProgressMessage = "Customer Errors Downloaded ...";
                                            job.FilePath = fullPath;
                                            job.IsCompleted = true;
                                            MTM.Add(new ImportResults()
                                            {
                                                ID = "2",
                                                Msg = "Error occured when Save Customer",
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
                                    clsExport.TransImport_ExportToExcel(dtHeaderWrongValues, false);                                    
                                    job.ProgressMessage = "Error occured. Downloading errors...";
                                    fullPath = Path.Combine(strFilePath, strFileName + ".xlsx");                                   
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
                        else if (TransID == "3")//Vendor
                        {
                            DataTable dtCustomer = new DataTable();
                            dtCustomer.Columns.Add("Serial", typeof(int));
                            dtCustomer.Columns.Add("Code", typeof(string));
                            dtCustomer.Columns.Add("Name", typeof(string));
                            dtCustomer.Columns.Add("Shinecode", typeof(string));
                            dtCustomer.Columns.Add("Address", typeof(string));
                            dtCustomer.Columns.Add("GSTNo", typeof(string));
                            dtCustomer.Columns.Add("ACTIVE", typeof(string));

                            if (dtHeaderData.Rows.Count > 0)
                            {
                                job.Progress = 50;
                                job.ProgressMessage = "Validate Data..."; //Thread.Sleep(3000);
                                int currentProgress = job.Progress;
                                int nIndex = 1;
                                bool NoErrorsinHeader = true, NoErrorsinItems = true;
                                #region Header data validation
                                foreach (DataRow item in dtHeaderData.Rows)
                                {
                                    DataTable dtValidate = dtHeaderData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = importValidations.SC_VendorValidation(dtValidate);
                                    //"CODE *",   "NAME *", "SHINE CODE *", "ADDRESS", "GST NUMBER",  "ACTIVE *"
                                    //"CODE *",   "NAME *", "SHINE CODE *", "HSN", "MFR NAME",  "ACTIVE *"
                                    if (string.IsNullOrEmpty(RowError))
                                    {
                                        DataRow drW = dtHeaderWrongValues.NewRow();
                                        drW["CODE *"] = dtValidate.Rows[0]["CODE *"].ToString();
                                        drW["NAME *"] = dtValidate.Rows[0]["NAME *"].ToString();
                                        drW["SHINE CODE *"] = dtValidate.Rows[0]["SHINE CODE *"].ToString();
                                        drW["ADDRESS"] = dtValidate.Rows[0]["ADDRESS"].ToString();
                                        drW["GST NUMBER"] = dtValidate.Rows[0]["GST NUMBER"].ToString();
                                        drW["ACTIVE *"] = dtValidate.Rows[0]["ACTIVE *"].ToString();
                                        drW["ERROR"] = RowError;
                                        dtHeaderWrongValues.Rows.Add(drW);
                                        //Correct values only
                                        DataRow drC = dtCustomer.NewRow();
                                        drC["Code"] = dtValidate.Rows[0]["CODE *"].ToString();
                                        drC["Name"] = dtValidate.Rows[0]["NAME *"].ToString();
                                        drC["Shinecode"] = dtValidate.Rows[0]["SHINE CODE *"].ToString();
                                        drC["Address"] = dtValidate.Rows[0]["ADDRESS"].ToString();
                                        drC["GSTNo"] = dtValidate.Rows[0]["GST NUMBER"].ToString();
                                        drC["Active"] = dtValidate.Rows[0]["ACTIVE *"].ToString();
                                        drC["Serial"] = nIndex;
                                        dtCustomer.Rows.Add(drC);
                                        nIndex++;
                                    }
                                    else
                                    {
                                        NoErrorsinHeader = false;
                                        DataRow drW = dtHeaderWrongValues.NewRow();
                                        drW["CODE *"] = dtValidate.Rows[0]["CODE *"].ToString();
                                        drW["NAME *"] = dtValidate.Rows[0]["NAME *"].ToString();
                                        drW["SHINE CODE *"] = dtValidate.Rows[0]["SHINE CODE *"].ToString();
                                        drW["ADDRESS"] = dtValidate.Rows[0]["ADDRESS"].ToString();
                                        drW["GST NUMBER"] = dtValidate.Rows[0]["GST NUMBER"].ToString();
                                        drW["ACTIVE *"] = dtValidate.Rows[0]["ACTIVE *"].ToString();
                                        drW["ERROR"] = RowError;
                                        dtHeaderWrongValues.Rows.Add(drW);
                                    }
                                }
                                #endregion

                                #region save
                                if (NoErrorsinHeader)
                                {
                                    DataTable dtResult = new DataTable();
                                    job.Progress = 85;
                                    job.ProgressMessage = "Vendor Save Progress..."; //Thread.Sleep(10000);

                                    if (dtCustomer.Rows.Count > 0)
                                    {

                                        dtResult = SaveSCVendorMaster(dtCustomer);
                                        if (dtResult.Columns.Count == 3)
                                        {
                                            job.ProgressMessage = "Error Occured when Save Vendor...";
                                            strFileName = TransName + "_error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                            clsExport.strFileName = strFileName;
                                            clsExport.TransImport_ExportToExcel(dtHeaderWrongValues, false);
                                            job.ProgressMessage = "Vendor Errors Downloading ...";
                                            fullPath = Path.Combine(strFilePath, strFileName + ".xlsx");
                                            job.ProgressMessage = "Vendor Errors Downloaded ...";
                                            job.FilePath = fullPath;
                                            job.IsCompleted = true;
                                            MTM.Add(new ImportResults()
                                            {
                                                ID = "2",
                                                Msg = "Error occured when Save Vendor",
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
                                    clsExport.TransImport_ExportToExcel(dtHeaderWrongValues, false);
                                    job.ProgressMessage = "Error occured. Downloading errors...";
                                    fullPath = Path.Combine(strFilePath, strFileName + ".xlsx");
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
                        else if (TransID == "2")//Product
                        {
                            DataTable dtProduct = new DataTable();
                            dtProduct.Columns.Add("Serial", typeof(int));
                            dtProduct.Columns.Add("Code", typeof(string));
                            dtProduct.Columns.Add("Name", typeof(string));
                            dtProduct.Columns.Add("Shinecode", typeof(string));
                            dtProduct.Columns.Add("HSN", typeof(string));
                            dtProduct.Columns.Add("MfrName", typeof(string));
                            dtProduct.Columns.Add("ACTIVE", typeof(string));

                            if (dtHeaderData.Rows.Count > 0)
                            {
                                job.Progress = 50;
                                job.ProgressMessage = "Validate Data..."; //Thread.Sleep(3000);
                                int currentProgress = job.Progress;
                                int nIndex = 1;
                                bool NoErrorsinHeader = true, NoErrorsinItems = true;
                                #region Header data validation
                                foreach (DataRow item in dtHeaderData.Rows)
                                {
                                    DataTable dtValidate = dtHeaderData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = importValidations.SC_ProductValidation(dtValidate);
                                    //"CODE *",   "NAME *", "SHINE CODE *", "ADDRESS", "GST NUMBER",  "ACTIVE *"
                                    //"CODE *",   "NAME *", "SHINE CODE *", "HSN", "MFR NAME",  "ACTIVE *"
                                    if (string.IsNullOrEmpty(RowError))
                                    {
                                        DataRow drW = dtHeaderWrongValues.NewRow();
                                        drW["CODE *"] = dtValidate.Rows[0]["CODE *"].ToString();
                                        drW["NAME *"] = dtValidate.Rows[0]["NAME *"].ToString();
                                        drW["SHINE CODE *"] = dtValidate.Rows[0]["SHINE CODE *"].ToString();
                                        drW["HSN"] = dtValidate.Rows[0]["HSN"].ToString();
                                        drW["MFR NAME"] = dtValidate.Rows[0]["MFR NAME"].ToString();
                                        drW["ACTIVE *"] = dtValidate.Rows[0]["ACTIVE *"].ToString();
                                        drW["ERROR"] = RowError;
                                        dtHeaderWrongValues.Rows.Add(drW);
                                        //Correct values only
                                        DataRow drC = dtProduct.NewRow();
                                        drC["Code"] = dtValidate.Rows[0]["CODE *"].ToString();
                                        drC["Name"] = dtValidate.Rows[0]["NAME *"].ToString();
                                        drC["Shinecode"] = dtValidate.Rows[0]["SHINE CODE *"].ToString();
                                        drC["HSN"] = dtValidate.Rows[0]["HSN"].ToString();
                                        drC["MfrName"] = dtValidate.Rows[0]["MFR NAME"].ToString();
                                        drC["Active"] = dtValidate.Rows[0]["ACTIVE *"].ToString();
                                        drC["Serial"] = nIndex;
                                        dtProduct.Rows.Add(drC);
                                        nIndex++;
                                    }
                                    else
                                    {
                                        NoErrorsinHeader = false;
                                        DataRow drW = dtHeaderWrongValues.NewRow();
                                        drW["CODE *"] = dtValidate.Rows[0]["CODE *"].ToString();
                                        drW["NAME *"] = dtValidate.Rows[0]["NAME *"].ToString();
                                        drW["SHINE CODE *"] = dtValidate.Rows[0]["SHINE CODE *"].ToString();
                                        drW["HSN"] = dtValidate.Rows[0]["HSN"].ToString();
                                        drW["MFR NAME"] = dtValidate.Rows[0]["MFR NAME"].ToString();
                                        drW["ACTIVE *"] = dtValidate.Rows[0]["ACTIVE *"].ToString();
                                        drW["ERROR"] = RowError;
                                        dtHeaderWrongValues.Rows.Add(drW);
                                    }
                                }
                                #endregion

                                #region save
                                if (NoErrorsinHeader)
                                {
                                    DataTable dtResult = new DataTable();
                                    job.Progress = 85;
                                    job.ProgressMessage = "Product Save Progress..."; //Thread.Sleep(10000);

                                    if (dtProduct.Rows.Count > 0)
                                    {

                                        dtResult = SaveSCProductMaster(dtProduct);
                                        if (dtResult.Columns.Count == 3)
                                        {
                                            job.ProgressMessage = "Error Occured when Save Product...";
                                            strFileName = TransName + "_error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                            clsExport.strFileName = strFileName;
                                            clsExport.TransImport_ExportToExcel(dtHeaderWrongValues, false);
                                            job.ProgressMessage = "Product Errors Downloading ...";
                                            fullPath = Path.Combine(strFilePath, strFileName + ".xlsx");
                                            job.ProgressMessage = "Product Errors Downloaded ...";
                                            job.FilePath = fullPath;
                                            job.IsCompleted = true;
                                            MTM.Add(new ImportResults()
                                            {
                                                ID = "2",
                                                Msg = "Error occured when Save Product",
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
                                    clsExport.TransImport_ExportToExcel(dtHeaderWrongValues, false);
                                    job.ProgressMessage = "Error occured. Downloading errors...";
                                    fullPath = Path.Combine(strFilePath, strFileName + ".xlsx");
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
                job.ErrorID = 24;
                job.ErrorMessage = ex.Message;
                job.IsCompleted = true;
                objBL.BL_WriteErrorMsginLog("Transaction Import", "RunTransactionImport", ex.Message);
                MTM.Add(new ImportResults()
                {
                    ID = "2",
                    Msg = ex.Message,
                });
                return MTM;
            }
            return MTM;
        }
        public DataTable SaveSCCustomerMaster(DataTable dtTVP)
        {
            DataTable dtResult = new DataTable();

            using (SqlConnection con = new SqlConnection(connectionString))
            {
                con.Open();

                SqlTransaction tran = con.BeginTransaction();

                try
                {
                    using (SqlCommand cmd = new SqlCommand("dbo.usp_ImportCustomerMaster", con, tran))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;

                        SqlParameter tvp = cmd.Parameters.Add("@Customers", SqlDbType.Structured);
                        tvp.TypeName = "dbo.tvpSCPartyMaster";
                        tvp.Value = dtTVP;

                        using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                        {
                            da.Fill(dtResult);
                        }
                    }

                    // Commit if everything succeeds
                    tran.Commit();
                }
                catch (Exception)
                {
                    // Rollback on any error
                    try
                    {
                        tran.Rollback();
                    }
                    catch
                    {
                        // Ignore rollback exceptions
                    }

                    throw;
                }

                return dtResult;
            }
        }
        public DataTable SaveSCVendorMaster(DataTable dtTVP)
        {
            DataTable dtResult = new DataTable();

            using (SqlConnection con = new SqlConnection(connectionString))
            {
                con.Open();

                SqlTransaction tran = con.BeginTransaction();

                try
                {
                    using (SqlCommand cmd = new SqlCommand("dbo.usp_ImportVendorMaster", con, tran))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;

                        SqlParameter tvp = cmd.Parameters.Add("@Vendors", SqlDbType.Structured);
                        tvp.TypeName = "dbo.tvpSCPartyMaster";
                        tvp.Value = dtTVP;

                        using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                        {
                            da.Fill(dtResult);
                        }
                    }

                    // Commit if everything succeeds
                    tran.Commit();
                }
                catch (Exception)
                {
                    // Rollback on any error
                    try
                    {
                        tran.Rollback();
                    }
                    catch
                    {
                        // Ignore rollback exceptions
                    }

                    throw;
                }

                return dtResult;
            }
        }
        public DataTable SaveSCProductMaster(DataTable dtTVP)
        {
            DataTable dtResult = new DataTable();

            using (SqlConnection con = new SqlConnection(connectionString))
            {
                con.Open();

                SqlTransaction tran = con.BeginTransaction();

                try
                {
                    using (SqlCommand cmd = new SqlCommand("dbo.usp_ImportProductMaster", con, tran))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;

                        SqlParameter tvp = cmd.Parameters.Add("@Products", SqlDbType.Structured);
                        tvp.TypeName = "dbo.tvpProductMaster";
                        tvp.Value = dtTVP;

                        using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                        {
                            da.Fill(dtResult);
                        }
                    }

                    // Commit if everything succeeds
                    tran.Commit();
                }
                catch (Exception)
                {
                    // Rollback on any error
                    try
                    {
                        tran.Rollback();
                    }
                    catch
                    {
                        // Ignore rollback exceptions
                    }

                    throw;
                }

                return dtResult;
            }
        }
    }
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
        public int ExportType { get; set; }
    }
}
