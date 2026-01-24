using DocumentFormat.OpenXml.Spreadsheet;
using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class FinancialReportsController : ApiController
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
        [Route("api/FinancialReportpermissions")]
        public IHttpActionResult GetPermissionsReports(string UID)
        {
            DataSet ds = new DataSet();
            DataTable dtRes = bl.BL_ExecuteParamSP("uspManageUsers", 4, UID);
            string RID = dtRes.Rows[0]["RoleID"].ToString();
            DataTable dtReportParent = bl.BL_ExecuteParamSP("uspFinancialReportPermission", 1, RID);
            dtReportParent.TableName = "ParentFinRepMenu";
            ds.Tables.Add(dtReportParent);
            DataTable dtReportPermission = bl.BL_ExecuteParamSP("uspFinancialReportPermission", 2, RID, UID);
            dtReportPermission.TableName = "UserFinRepMenus";
            ds.Tables.Add(dtReportPermission);
            string dtjson = JsonConvert.SerializeObject(ds);
            return Ok(dtjson);
        }
        [HttpGet]
        [Route("api/financialreportparameters/get")]
        public IHttpActionResult GetData(string Mode, string ReportID, string ALName = null)
        {
            DataTable DDT = new DataTable();
            if (Mode == "0")
            {
                DDT = bl.BL_ExecuteParamSP("uspManageFinancialReports", Mode, ReportID);
                string JSONCONV = JsonConvert.SerializeObject(DDT);
                return Ok(JSONCONV);
            }
            if (Mode == "1")
            {
                DDT = bl.BL_ExecuteParamSP("uspManageFinancialReports", Mode, ReportID);
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
                DDT = bl.BL_ExecuteParamSP("uspManageFinancialReports", Mode, ReportID, ALName);
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
        [Route("api/financialreportgenerate/get")]
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
        [HttpGet]
        [Route("api/financialrepcolumnsettings/getcolumnsettings")]
        public IHttpActionResult GetGendralColumnData(string Mode, string FormID, string TableID, string FormorReport)
        {
            if (Mode == "1")
            {
                DataTable dtResult = bl.BL_ExecuteParamSP("uspGetGendralColumnSettings", Mode, FormID, TableID, FormorReport);
                string JSONCONV = JsonConvert.SerializeObject(dtResult);
                return Ok(JSONCONV);
            }
            if (Mode == "2")
            {
                List<ColumnSettingsDataModel> list = new List<ColumnSettingsDataModel>();
                DataTable dtResult = bl.BL_ExecuteParamSP("uspGetGendralColumnSettings", Mode, FormID, TableID, FormorReport);
                for (int i = 0; i < dtResult.Rows.Count; i++)
                {
                    //field	header	type	width	align	visible	EnableColumnMenu	ShowinColumnOption	Total	TotalYN	EnableSum	EnableAvg	precision	ClickPopup
                    list.Add(new ColumnSettingsDataModel()
                    {
                        field = dtResult.Rows[i]["ColumnName"].ToString(),
                        header = dtResult.Rows[i]["DisplayColumnName"].ToString(),
                        type = "label",
                        width = Convert.ToInt32(dtResult.Rows[i]["Width"].ToString()),
                        align = dtResult.Rows[i]["Alignment"].ToString() == "1" ? "left" : dtResult.Rows[i]["Alignment"].ToString() == "2" ? "right" : "center",
                        visible = dtResult.Rows[i]["Visible"].ToString() == "1" ? true : false,
                        EnableColumnMenu = dtResult.Rows[i]["EnableColumnMenu"].ToString() == "1" ? true : false,
                        ShowinColumnOption = dtResult.Rows[i]["ShowinColumnOption"].ToString() == "0" ? false : true,
                        Total = dtResult.Rows[i]["Total"].ToString() == "0" ? true : false,
                        TotalYN = dtResult.Rows[i]["TotalYN"].ToString(),
                        EnableSum = dtResult.Rows[i]["EnableSum"].ToString() == "1" ? true : false,
                        EnableAvg = dtResult.Rows[i]["EnableAvg"].ToString() == "1" ? true : false,
                        ClickPopup = dtResult.Rows[i]["ClickPopup"].ToString() == "1" ? true : false,
                        precision = dtResult.Rows[i]["precision"].ToString(),
                        PrintYN = dtResult.Rows[i]["PrintYN"].ToString() == "1" ? true : false,
                        Printwidth = Convert.ToInt32(dtResult.Rows[i]["PrintWidth"].ToString()),
                        PrintColumnName = dtResult.Rows[i]["PrintColumnName"].ToString(),
                    });
                }
                return Ok(list);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/financialrepcolumnsettings/Savecolumnsettings")]
        public IHttpActionResult saveGenColumnData(List<ColumnSettingsModel> ColumnSettingData)
        {
            if (ColumnSettingData != null)
            {
                var list = new List<object>();
                foreach (ColumnSettingsModel item in ColumnSettingData)
                {
                    bl.BL_ExecuteParamSP("uspSaveGendralColumnSettings", 1, item.FormID, item.TableID, item.ColumnID, item.FormorReport,
                      item.DisplayColumnName, item.Width, item.Visible, item.Alignment, item.DisplayIndex, item.TotalYN, item.EnableSum,
                      item.EnableAvg, item.EnableColumnMenu, item.ShowinColumnOption,item.PrintYN ? 1 : 0, item.PrintColumnName,
                      item.Printwidth);
                }
                List<ColumnSettingsDataModel> Columnlist = new List<ColumnSettingsDataModel>();
                DataTable dtResult = bl.BL_ExecuteParamSP("uspGetGendralColumnSettings", 2, ColumnSettingData[0].FormID, ColumnSettingData[0].TableID, ColumnSettingData[0].FormorReport);
                for (int i = 0; i < dtResult.Rows.Count; i++)
                {
                    //field	header	type	width	align	visible	EnableColumnMenu	ShowinColumnOption	Total	TotalYN	EnableSum	EnableAvg	precision	ClickPopup
                    Columnlist.Add(new ColumnSettingsDataModel()
                    {
                        field = dtResult.Rows[i]["ColumnName"].ToString(),
                        header = dtResult.Rows[i]["DisplayColumnName"].ToString(),
                        type = "label",
                        width = Convert.ToInt32(dtResult.Rows[i]["Width"].ToString()),
                        align = dtResult.Rows[i]["Alignment"].ToString() == "1" ? "left" : dtResult.Rows[i]["Alignment"].ToString() == "2" ? "right" : "center",
                        visible = dtResult.Rows[i]["Visible"].ToString() == "1" ? true : false,
                        EnableColumnMenu = dtResult.Rows[i]["EnableColumnMenu"].ToString() == "1" ? true : false,
                        ShowinColumnOption = dtResult.Rows[i]["ShowinColumnOption"].ToString() == "0" ? false : true,
                        Total = dtResult.Rows[i]["Total"].ToString() == "0" ? true : false,
                        TotalYN = dtResult.Rows[i]["TotalYN"].ToString(),
                        EnableSum = dtResult.Rows[i]["EnableSum"].ToString() == "1" ? true : false,
                        EnableAvg = dtResult.Rows[i]["EnableAvg"].ToString() == "1" ? true : false,
                        ClickPopup = dtResult.Rows[i]["ClickPopup"].ToString() == "1" ? true : false,
                        precision = dtResult.Rows[i]["precision"].ToString(),
                        PrintYN = dtResult.Rows[i]["PrintYN"].ToString() == "1" ? true : false,
                        Printwidth = Convert.ToInt32(dtResult.Rows[i]["PrintWidth"].ToString()),
                        PrintColumnName = dtResult.Rows[i]["PrintColumnName"].ToString(),
                    });
                }
                list.Add(new
                {
                    MsgID = "0",
                    Message = "Saved Successfully",
                    ColumnData = Columnlist
                });
                return Ok(list);
            }
            return Ok();
        }
    }
}
