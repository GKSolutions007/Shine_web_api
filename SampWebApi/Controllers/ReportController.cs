using ClosedXML.Excel;
using DocumentFormat.OpenXml.Bibliography;
using DocumentFormat.OpenXml.Drawing;
using DocumentFormat.OpenXml.Vml;
using DocumentFormat.OpenXml.Wordprocessing;
using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Web.Http;
using System.Web.Http.Cors;
using System.Web.Http.Results;
using System.Windows.Interop;
using System.Xml.Linq;
using WebGrease.Activities;
using static System.Net.WebRequestMethods;
using static System.Windows.Forms.VisualStyles.VisualStyleElement;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class ReportController : ApiController
    {
        public string strExtension = ".xlsx";
        public string strFileName = "";
        public string strSheetName { get; set; }
        public string strFilePath
        {
            get; set;
        }
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/Reportpermissions")]
        public IHttpActionResult GetPermissionsReports(string UID)
        {
            DataSet ds = new DataSet();
            DataTable dtRes = bl.BL_ExecuteParamSP("uspManageUsers", 4, UID);            
            string RID = dtRes.Rows[0]["RoleID"].ToString();
            DataTable dtReportParent = bl.BL_ExecuteParamSP("uspReportPermission", 1, RID);
            dtReportParent.TableName = "ParentRepMenu";
            ds.Tables.Add(dtReportParent);
            DataTable dtReportPermission = bl.BL_ExecuteParamSP("uspReportPermission", 2, RID, UID);
            dtReportPermission.TableName = "UserRepMenus";
            ds.Tables.Add(dtReportPermission);
            string dtjson = JsonConvert.SerializeObject(ds);
            return Ok(dtjson);
        }
            [HttpGet]
        [Route("api/reportparameters/get")]
        public IHttpActionResult GetData(string Mode, string ReportID, string ALName = null)
        {
            DataTable DDT = new DataTable();
            if (Mode == "0")
            {
                DDT = bl.BL_ExecuteParamSP("uspManageReports", Mode, ReportID);
                string JSONCONV = JsonConvert.SerializeObject(DDT);
                return Ok(JSONCONV);
            }
            if (Mode == "1")
            {
                DDT = bl.BL_ExecuteParamSP("uspManageReports", Mode, ReportID);
                List<ReportParameters> list = new List<ReportParameters>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new ReportParameters
                    {
                        ParameterID = DDT.Rows[i]["ParameterID"].ToString(),
                        ReportID = DDT.Rows[i]["ReportID"].ToString(),
                        ParameterName = DDT.Rows[i]["ParameterName"].ToString(),
                        ParameterType = DDT.Rows[i]["ParameterType"].ToString(),
                        IsMandatory = DDT.Rows[i]["IsMandatory"].ToString(),
                        ParamOrder = DDT.Rows[i]["ParamOrder"].ToString(),
                        AutolistName = DDT.Rows[i]["AutolistName"].ToString()
                    });
                }
                return Ok(list);
            }
            else if (Mode == "2")
            {
                List<SingleMasterModel> list = new List<SingleMasterModel>();
                DDT = bl.BL_ExecuteParamSP("uspManageReports", Mode, ReportID, ALName);
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new SingleMasterModel
                    {
                        ID = DDT.Rows[i]["ID"].ToString(),
                        Name = DDT.Rows[i]["Name"].ToString(),
                    });
                }
                return Ok(list);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/reportgenerate/get")]
        public IHttpActionResult GeerateData(ReportParameters listParams)
        {
            DataTable DDT = new DataTable();
            if (listParams != null)
            {
                object[] objParamValue = new object[listParams.lstvFilters.Count];
                for (int i = 0; i < objParamValue.Length; i++)
                {
                    objParamValue[i] = !string.IsNullOrEmpty(listParams.lstvFilters[i].Param1) ? listParams.lstvFilters[i].Param1 : null;
                }
                DDT = bl.BL_ExecuteParamSP(listParams.ProcedureName, objParamValue);//, listParams.Param2, listParams.Param3, listParams.Param4
                if (DDT.Rows.Count > 0)
                {
                    string JSONCONV = JsonConvert.SerializeObject(DDT);
                    return Ok(JSONCONV);
                }
                else
                {
                    return Ok();
                }
            }
            else
            {
                return Ok();
            }
        }

            public void ExportToExcel(DataTable DtData)
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
                    Int32 len = strSheetName.Length;
                    wb.Worksheets.Add(DtData, strSheetName.Substring(0, len).Trim());
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
                    Int32 len = strSheetName.Length;
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
        [HttpPost]
        [Route("api/reportexport/export")]
        public IHttpActionResult ExportData(ReportParameters listParams)
        {
            DataTable DDT = new DataTable();
            HttpResponseMessage response = new HttpResponseMessage(HttpStatusCode.OK)
            {
                //Content = new ByteArrayContent(fileBytes)
            };
            if (listParams != null)
            {
                object[] objParamValue = new object[listParams.lstvFilters.Count];
                for (int i = 0; i < objParamValue.Length; i++)
                {
                    objParamValue[i] = !string.IsNullOrEmpty(listParams.lstvFilters[i].Param1) ? listParams.lstvFilters[i].Param1 : null;
                }
                DDT = bl.BL_ExecuteParamSP(listParams.ProcedureName, objParamValue);//, listParams.Param2, listParams.Param3, listParams.Param4
                if (DDT.Rows.Count > 0)
                {
                    strSheetName = "Data";
                    strFileName = "Report_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                    //string JSONCONV = JsonConvert.SerializeObject(DDT);
                    ExportToExcel(DDT);
                    var sDocument = strFilePath + strFileName + strExtension;
                    byte[] fileBytes = System.IO.File.ReadAllBytes(sDocument);
                    string fileName = strFileName + strExtension;
                    
                    return Ok(fileName);
                }
                else
                {
                    return Ok();
                }
            }
            else
            {
                return Ok();
            }
        }

        [HttpGet]
        [Route("api/gstreportexport/gstexport")]
        public HttpResponseMessage GSTExportData(string FromDate,string ToDate,string EInvOnly)
        {
            DataSet dtGSTData = new DataSet();

            DataTable DDT = new DataTable();
            DataSet DS = new DataSet();
            DataTable dtdata = bl.BL_ExecuteParamSP("uspGetFullGSTInfoReport", "S", FromDate,ToDate);
            DS.Tables.Add(dtdata); DS.Tables[0].TableName = "Sales";
            
            dtdata = bl.BL_ExecuteParamSP("uspGetFullGSTInfoReport", "SR", FromDate,ToDate);
            DS.Tables.Add(dtdata); DS.Tables[1].TableName = "Sales Return";
            
            dtdata = bl.BL_ExecuteParamSP("uspGetFullGSTInfoReport", "P", FromDate,ToDate);
            DS.Tables.Add(dtdata); DS.Tables[2].TableName = "Purchase";
            
            dtdata = bl.BL_ExecuteParamSP("uspGetFullGSTInfoReport", "PR", FromDate,ToDate);
            DS.Tables.Add(dtdata); DS.Tables[3].TableName = "Purchase Return";
            
            dtdata = bl.BL_ExecuteParamSP("uspGetFullGSTInfoReport", "PV", FromDate,ToDate);
            DS.Tables.Add(dtdata); DS.Tables[4].TableName = "Payable Voucher";
            dtdata = bl.BL_ExecuteParamSP("uspGetFullGSTInfoReport", "RV", FromDate,ToDate);
            DS.Tables.Add(dtdata); DS.Tables[5].TableName = "Recievable Vouncer";
           

            dtdata = bl.BL_ExecuteParamSP("uspLatestGSTReportInfo", "b2b", FromDate,ToDate, EInvOnly);
            DS.Tables.Add(dtdata); DS.Tables[6].TableName = "b2b";
            
            dtdata = bl.BL_ExecuteParamSP("uspLatestGSTReportInfo", "b2cl", FromDate,ToDate, EInvOnly);
            DS.Tables.Add(dtdata); DS.Tables[7].TableName = "b2cl";
            
            dtdata = bl.BL_ExecuteParamSP("uspLatestGSTReportInfo", "b2cs", FromDate,ToDate, EInvOnly);
            DS.Tables.Add(dtdata); DS.Tables[8].TableName = "b2cs";
            
            dtdata = bl.BL_ExecuteParamSP("uspLatestGSTReportInfo", "cdnr", FromDate,ToDate, EInvOnly);
            DS.Tables.Add(dtdata); DS.Tables[9].TableName = "cdnr";
           
            dtdata = bl.BL_ExecuteParamSP("uspLatestGSTReportInfo", "cdnur", FromDate,ToDate, EInvOnly);
            DS.Tables.Add(dtdata); DS.Tables[10].TableName = "cdnur";
            
            dtdata = bl.BL_ExecuteParamSP("uspLatestGSTReportInfo", "HSN", FromDate,ToDate, EInvOnly);
            DS.Tables.Add(dtdata); DS.Tables[11].TableName = "HSN";
            
            dtdata = bl.BL_ExecuteParamSP("uspLatestGSTReportInfo", "HSNB2B", FromDate,ToDate, EInvOnly);
            DS.Tables.Add(dtdata); DS.Tables[12].TableName = "hsn(b2b)";
            dtdata = bl.BL_ExecuteParamSP("uspLatestGSTReportInfo", "HSNB2C", FromDate,ToDate, EInvOnly);
            DS.Tables.Add(dtdata); DS.Tables[13].TableName = "hsn(b2c)";
            
            dtdata = bl.BL_ExecuteParamSP("uspLatestGSTReportInfo", "Extempted", FromDate,ToDate, EInvOnly);
            DS.Tables.Add(dtdata); DS.Tables[14].TableName = "Extempted";
            
            dtdata = bl.BL_ExecuteParamSP("uspLatestGSTReportInfo", "Documents", FromDate,ToDate, EInvOnly);
            DS.Tables.Add(dtdata); DS.Tables[15].TableName = "Documents";
            
           
                strSheetName = "Data";
                strFileName = "GST_Report_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                //string JSONCONV = JsonConvert.SerializeObject(DDT);
                ExportToExcelbyDataSet(DS);
                var sDocument = strFilePath + strFileName + strExtension;
                byte[] fileBytes = System.IO.File.ReadAllBytes(sDocument);
                string fileName = strFileName + strExtension;
                //return File(fileBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
                if (!System.IO.File.Exists(strFilePath + strFileName + strExtension))
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
        [HttpGet]
        [Route("api/reportscript/get")]
        public HttpResponseMessage GetreportscriptData(string ReportID, string ReportName)
        {
            string strAppStartPath = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"] + "\\Report_Script_Data\\";
            if (!Directory.Exists(strAppStartPath))
            {
                Directory.CreateDirectory(strAppStartPath);
            }
            string strFileName = ReportName + "_" + DateTime.Now.ToString("yyyymmddhhmmss") + ".txt";
            using (StreamWriter sw = System.IO.File.CreateText(System.IO.Path.Combine(strAppStartPath, strFileName)))
            {
                DataTable dt = new DataTable();
                for (int nCount = 1; nCount <= 10; nCount++)
                {
                    dt = bl.BL_ExecuteParamSP("uspReportScript", nCount, ReportID);
                    if (dt.Rows.Count > 0)
                    {
                        for (int iRow = 0; iRow < dt.Rows.Count; iRow++)
                        {
                            if (nCount == 8)
                            {
                                string strQuery = dt.Rows[iRow][0].ToString(), strColumnQuery = "";
                                for (int iCol = 1; iCol < dt.Columns.Count; iCol++)
                                {
                                    strColumnQuery = strColumnQuery + (string.IsNullOrEmpty(Convert.ToString(dt.Rows[iRow][iCol])) ? (iCol == dt.Columns.Count - 1 ? "NULL" : "NULL,")
                                        : "'" + Convert.ToString(dt.Rows[iRow][iCol]) + (iCol == dt.Columns.Count - 1 ? "'" : "',"));
                                }
                                strQuery = strQuery + strColumnQuery + ")";
                                sw.WriteLine(strQuery);
                                if (iRow == (dt.Rows.Count - 1))
                                {
                                    sw.WriteLine("GO");
                                }
                            }
                            else
                            {
                                if (!string.IsNullOrEmpty(Convert.ToString(dt.Rows[iRow][0]).Trim()))
                                    sw.WriteLine(Convert.ToString(dt.Rows[iRow][0]).Trim());
                            }
                        }
                        sw.WriteLine("");
                    }

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
        [HttpGet]
        [Route("api/reportcolumnsettings/getRepColumnSettings")]
        public IHttpActionResult GetColumnData(string Mode,string ReportID,string TableID)
        {
            if(Mode == "1")
            {
                DataTable dtResult = bl.BL_ExecuteParamSP("uspGetSetReportColumnSettings", Mode, ReportID, TableID);
                string JSONCONV = JsonConvert.SerializeObject(dtResult);
                return Ok(JSONCONV);
            }
            if (Mode == "2")
            {
                List<ReportColumnDataModel> list = new List<ReportColumnDataModel>();
                DataTable dtResult = bl.BL_ExecuteParamSP("uspGetSetReportColumnSettings", Mode, ReportID, TableID);
                for (int i = 0; i < dtResult.Rows.Count; i++)
                {
                    //ReportID	TableID	ColumnID	ColumnName	DisplayColumnName	Width	Visible	Alignment	DisplayIndex	IsHiddenColumn                    
                    list.Add(new ReportColumnDataModel()
                    {
                        field = dtResult.Rows[i]["ColumnName"].ToString(),
                        headerText = dtResult.Rows[i]["DisplayColumnName"].ToString(),
                        visible = dtResult.Rows[i]["Visible"].ToString() == "1" ? true : false,
                        width = dtResult.Rows[i]["Width"].ToString(),
                        showInColumnChooser = dtResult.Rows[i]["IsHiddenColumn"].ToString() == "1" ? false : true,
                        textAlign = dtResult.Rows[i]["Alignment"].ToString() == "1" ? "left" : dtResult.Rows[i]["Alignment"].ToString() == "2" ? "right" :  "center",
                        Total = dtResult.Rows[i]["Total"].ToString(),
                        TotalYN = dtResult.Rows[i]["TotalYN"].ToString(),
                    });
                }                
                return Ok(list);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/reportcolumnsettings/SaveRepColumnSettings")]
        public IHttpActionResult GetColumnData(List<ReportModel> ColumnSettingData)
        {
            if (ColumnSettingData != null)
            {
                List<SaveMessage> list = new List<SaveMessage>();
                foreach (ReportModel item in ColumnSettingData)
                {
                    bl.BL_ExecuteParamSP("uspSaveReportColumnSettings", item.ReportID, item.TableID, item.ColumnID, item.ColumnName,
                      item.DisplayColumnName, item.Width, item.Visible, item.Alignment, item.DisplayIndex,item.TotalYN);
                }
                list.Add(new SaveMessage()
                {
                    MsgID = "0",
                    Message = "Saved Successfully"
                });
                return Ok(list);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/commonfilter/commonfilterdata")]
        public IHttpActionResult commonfilterdata([FromBody] CommonDocsFilter FilterData)
        {
            DataTable DDT = new DataTable();
            HttpResponseMessage response = new HttpResponseMessage(HttpStatusCode.OK)
            {
                //Content = new ByteArrayContent(fileBytes)
            };
            if (FilterData != null)
            {
                string DocValue = "";
                if (!string.IsNullOrEmpty(FilterData.DocRange))
                {
                    DataTable dtRanges = bl.BL_StringSplitCommaHyphen(FilterData.DocRange);

                    for (int i = 0; i < dtRanges.Rows.Count; i++)
                    {
                        DocValue += "'" + dtRanges.Rows[i][0].ToString() + "',";
                    }
                }
                DataTable dtResult = bl.BL_ExecuteParamSP("uspCommonDocumentFilter", FilterData.TransID, FilterData.FromDate, FilterData.ToDate,
                    DocValue, FilterData.Party, FilterData.FilterType);
                string JSONCONV = JsonConvert.SerializeObject(dtResult);
                return Ok(JSONCONV);
            }
            return Ok();
        }
    }
}   
