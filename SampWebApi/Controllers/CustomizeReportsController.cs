using ClosedXML.Excel;
using DocumentFormat.OpenXml.Drawing;
using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Web.Http;

namespace SampWebApi.Controllers
{
    public class CustomizeReportsController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        public string strExtension = ".xlsx";
        public string strFileName = "";
        public string strSheetName { get; set; }
        public string strFilePath
        {
            get; set;
        }
        [HttpGet]
        [Route("api/initiatecustomizereport")]
        public IHttpActionResult GetPermissionsReports(string Mode, string ID, string ALName)
        {
            try
            {
                DataTable dtPermissions = bl.BL_ExecuteParamSP("uspManageCustomizeReport", Mode, ID, ALName);
                string dtjson = JsonConvert.SerializeObject(dtPermissions);
                return Ok(dtjson);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CustomizeReports", "initiatecustomizereport", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/initiatecustomizereport/generate")]
        public IHttpActionResult GeerateData(ReportParameters listParams)
        {
            try
            {
                DataTable DDT = new DataTable();
                List<ImportResults> ReportResult = new List<ImportResults>();

                if (listParams != null)
                {
                    string ReportID = listParams.ReportID;
                    DataTable dtReportInfo = bl.BL_ExecuteParamSP("uspManageCustomizeReport", 3, ReportID);
                    if (dtReportInfo.Rows.Count > 0)
                    {
                        string ProcedureName = dtReportInfo.Rows[0]["ProcedureNames"].ToString();
                        string SheetNames = dtReportInfo.Rows[0]["SheetNames"].ToString();
                        string ReportName = dtReportInfo.Rows[0]["ReportName"].ToString().Replace('&', '_');
                        string[] lstProcedures = ProcedureName.Split(',');
                        string[] lstSheetNames = SheetNames.Split(',');
                        object[] objParamValue = new object[listParams.lstvFilters.Count];
                        for (int i = 0; i < objParamValue.Length; i++)
                        {
                            objParamValue[i] = !string.IsNullOrEmpty(listParams.lstvFilters[i].Param1) ? listParams.lstvFilters[i].Param1 : null;
                        }
                        DataSet dsReportData = new DataSet();
                        for (int i = 0; i < lstProcedures.Length; i++)
                        {
                            ProcedureName = lstProcedures[i].ToString();
                            SheetNames = lstSheetNames[i].ToString();
                            DDT = bl.BL_ExecuteParamSP(ProcedureName, objParamValue);//, listParams.Param2, listParams.Param3, listParams.Param4
                            dsReportData.Tables.Add(DDT);
                            dsReportData.Tables[i].TableName = SheetNames;
                        }
                        if (dsReportData.Tables.Count > 0)
                        {
                            strFileName = ReportName + "_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                            //string JSONCONV = JsonConvert.SerializeObject(DDT);
                            ExportToExcelbyDataSet(dsReportData);
                            var sDocument = strFilePath + strFileName + strExtension;
                            string fileName = strFileName + strExtension;

                            ReportResult.Add(new ImportResults()
                            {
                                ID = "0",
                                Msg = "Excel file created",
                                FileName = strFileName + strExtension,
                                FilePath = strFilePath + strFileName + strExtension,
                            });
                            return Ok(ReportResult);
                        }
                    }
                }
                ReportResult.Add(new ImportResults()
                {
                    ID = "1",
                    Msg = "Invalid Inputs",
                });

                return Ok(ReportResult);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CutomizeReports", "initiatecustomizereport/generate", ex.Message);
            }
            return Ok();
        }
        public void ExportToExcelbyDataSet(DataSet DtData)
        {
            try
            {
                //ReportExport\
                string FPt = AppDomain.CurrentDomain.BaseDirectory;
                strFilePath = FPt + "ReportExport\\";

                //Exporting to Excel
                if (!Directory.Exists(strFilePath))
                {
                    Directory.CreateDirectory(strFilePath);
                }
                using (XLWorkbook wb = new XLWorkbook())
                {
                    wb.Worksheets.Add(DtData);
                    wb.SaveAs(strFilePath + strFileName + strExtension);
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
        [HttpGet]
        [Route("api/customizereport/download")]
        public HttpResponseMessage DownloadData(string FPath, string FName)
        {
            try
            {
                string fileName = FName;
                if (!File.Exists(FPath))
                    return new HttpResponseMessage(HttpStatusCode.NotFound);

                var result = new HttpResponseMessage(HttpStatusCode.OK);
                var stream = new FileStream(FPath, FileMode.Open, FileAccess.Read);
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
                bl.BL_WriteErrorMsginLog("CutomizeReports", "customizereport/download", ex.Message);
            }
            return new HttpResponseMessage(HttpStatusCode.OK);
        }
    }
}
