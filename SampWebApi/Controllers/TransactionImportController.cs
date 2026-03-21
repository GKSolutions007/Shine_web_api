using SampWebApi.BuisnessLayer;
using SampWebApi.Import_Utility;
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
        [System.Web.Http.HttpGet]
        [System.Web.Http.Route("api/transactionimport/template")]
        public HttpResponseMessage ExportData(int TransID, string TransName, string FromDate = null, string ToDate = null)
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
                dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 3));
                dtset.Tables[2].TableName = "Sample - SerialInfo";
                dtset.Tables.Add(objBL.BL_ExecuteParamSP("uspSampleDataforImport", TransID, 4));
                dtset.Tables[3].TableName = "Help";
                objExport.OpenTransTemplate(
                    Import_Utility.clsExportData.AddSalesHeaderColumnForExport(false),
                           Import_Utility.clsExportData.AddSalesDetailColumnForExport(false),
                           Import_Utility.clsExportData.AddSalesSerialInfoColumnForExport(false));
                objExport.AddingHelptoExcel(objExport.strFilePath + objExport.strFileName + ".xlsx", 4, dtset);
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

    }
}
