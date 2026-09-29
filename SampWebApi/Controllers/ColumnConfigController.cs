using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Linq.Expressions;
using System.Net;
using System.Net.Http;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Web.Http;
using System.Web.Http.Cors;

namespace SampWebApi.Controllers
{
    public class ColumnConfigController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/columnconfig/get")]
        public IHttpActionResult GetData(int Mode, int? FormOrReport = null, int? FormID = null, int? TableID = null)
        {
            try
            {
                DataTable dt = bl.BL_ExecuteParamSP("uspGetColumnConfiguration",
                                    Mode,
                                    (object)FormOrReport ?? DBNull.Value,
                                    (object)FormID ?? DBNull.Value,
                                    (object)TableID ?? DBNull.Value);

                return Ok(JsonConvert.SerializeObject(dt));
            }
            catch (Exception ex)
            {
                return InternalServerError(ex);
            }
        }

        [HttpPost]
        [Route("api/columnconfig/saveColumnConfiguration")]
        public IHttpActionResult saveGenColumnData(List<ColumnSettingsModel> ColumnSettingData)
        {
            try
            {
                if (ColumnSettingData != null)
                {
                    var list = new List<object>();
                    foreach (ColumnSettingsModel item in ColumnSettingData)
                    {
                        bl.BL_ExecuteParamSP("uspSaveColumnConfiguration", 1, item.FormID, item.TableID, item.ColumnID, item.FormorReport,
                          item.DisplayColumnName, item.Width, item.Visible, item.Alignment, item.DisplayIndex, item.TotalYN, item.EnableSum,
                          item.EnableAvg, item.EnableCount, item.EnableUnique, item.EnableColumnMenu, item.ShowinColumnOption, item.PrintYN ? 1 : 0, item.PrintColumnName,
                          !string.IsNullOrEmpty(item.Printwidth.ToString()) ? item.Printwidth : 0,
                          !string.IsNullOrEmpty(item.ColumnType.ToString()) ? item.ColumnType : "1", item.Permission);
                    }
                    List<ColumnSettingsDataModel> Columnlist = new List<ColumnSettingsDataModel>();
                    DataTable dtResult = bl.BL_ExecuteParamSP("uspGetColumnConfiguration", 4, ColumnSettingData[0].FormorReport, ColumnSettingData[0].FormID, ColumnSettingData[0].TableID);
                    for (int i = 0; i < dtResult.Rows.Count; i++)
                    {
                        string coltype = !string.IsNullOrEmpty(dtResult.Rows[i]["ColumnType"].ToString()) ? dtResult.Rows[i]["ColumnType"].ToString() : "1";

                        Columnlist.Add(new ColumnSettingsDataModel()
                        {
                            field = dtResult.Rows[i]["ColumnName"].ToString(),
                            header = dtResult.Rows[i]["DisplayColumnName"].ToString(),
                            type = coltype == "3" ? "labeldecimal" : coltype == "2" ? "labelnumber" : coltype == "4" ? "labeldate" : "label",
                            ColumnType = coltype,
                            width = Convert.ToInt32(dtResult.Rows[i]["Width"].ToString()),
                            align = dtResult.Rows[i]["Alignment"].ToString() == "1" ? "left" : dtResult.Rows[i]["Alignment"].ToString() == "2" ? "right" : "center",
                            visible = dtResult.Rows[i]["Visible"].ToString() == "1" ? true : false,
                            EnableColumnMenu = dtResult.Rows[i]["EnableColumnMenu"].ToString() == "1" ? true : false,
                            ShowinColumnOption = dtResult.Rows[i]["ShowinColumnOption"].ToString() == "0" ? false : true,
                            Total = dtResult.Rows[i]["Total"].ToString() == "0" ? true : false,
                            TotalYN = dtResult.Rows[i]["TotalYN"].ToString(),
                            EnableSum = dtResult.Rows[i]["EnableSum"].ToString() == "1" ? true : false,
                            EnableAvg = dtResult.Rows[i]["EnableAvg"].ToString() == "1" ? true : false,
                            EnableCount = dtResult.Rows[i]["EnableCount"].ToString() == "1" ? true : false,
                            EnableUnique = dtResult.Rows[i]["EnableUnique"].ToString() == "1" ? true : false,
                            ClickPopup = dtResult.Rows[i]["ClickPopup"].ToString() == "1" ? true : false,
                            PrintYN = dtResult.Rows[i]["PrintYN"].ToString() == "1" ? true : false,
                            Printwidth = Convert.ToInt32(dtResult.Rows[i]["PrintWidth"].ToString()),
                            PrintColumnName = dtResult.Rows[i]["PrintColumnName"].ToString(),
                            Permission = Convert.ToInt32(dtResult.Rows[i]["Permission"].ToString()),
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
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("ColumnConfig", "columnconfig/saveColumnConfiguration", ex.Message);
                return Ok(new List<object> { new { MsgID = "1", Message = ex.Message } });
            }
            return Ok();
        }
    }
}
