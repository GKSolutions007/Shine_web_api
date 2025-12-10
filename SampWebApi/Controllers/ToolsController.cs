using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Web.Http;
using System.Web.Script.Serialization;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class ToolsController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/printprofileconfig/get")]
        public IHttpActionResult GetProfile()
        {
            DataTable DDT = bl.BL_ExecuteParamSP("uspManagePrintProfileconfig",1);
            string val = JsonConvert.SerializeObject(DDT);
            return Ok(val);
        }
        [HttpGet]
        [Route("api/printprofileconfig/getprofile")]
        public IHttpActionResult GetProfilebyid(string TransID)
        {
            DataTable DDT = bl.BL_ExecuteParamSP("uspManagePrintProfileconfig", 3, TransID);
            string val = JsonConvert.SerializeObject(DDT);
            return Ok(val);
        }
        [HttpPost]
        [Route("api/printprofileconfig/save")]
        public IHttpActionResult saveupdateproductlocation(List<PrintProfileConfig> lstProfiles)
        {
            List<SaveMessage> list = new List<SaveMessage>();
            if (lstProfiles != null)
            {
                foreach (PrintProfileConfig item in lstProfiles)
                {
                    bl.BL_ExecuteParamSP("uspManagePrintProfileconfig", 2, item.TransID, item.ConfigID, item.DefaultConfig, item.UserID);
                }
                list.Add(new SaveMessage()
                {
                    ID = 0.ToString(),
                    MsgID = "0",
                    Message = "Saved successfully"
                });
                return Ok(list);
            }
            list.Add(new SaveMessage()
            {
                ID = 0.ToString(),
                MsgID = "1",
                Message = "Data not saved. Try again"
            });
            return Ok(list);
        }
        [HttpGet]
        [Route("api/transactionvariant/gettrans")]
        public IHttpActionResult GetTrans(int Mode, int PartyType)
        {
            if (Mode == 1)
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspManageTransVariant", Mode);
                string val = JsonConvert.SerializeObject(DDT);
                return Ok(val);
            }
            else if(Mode == 2)
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspManageTransVariant", Mode, PartyType);
                string val = JsonConvert.SerializeObject(DDT);
                return Ok(val);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/maprole/getroles")]
        public IHttpActionResult GetRoleNames(int RoleID)
        {
            var RolesList = new List<object>();
            DataTable dtComboBoxData = bl.BL_ExecuteParamSP("uspManageUsers", 7, RoleID);
            if(dtComboBoxData.Rows.Count > 0)
            {
                for (int i = 0; i < dtComboBoxData.Rows.Count; i++)
                {
                    RolesList.Add(new
                    {
                        RoleID = dtComboBoxData.Rows[i][0].ToString(),
                        RoleName = dtComboBoxData.Rows[i][1].ToString()
                    });
                }
            }
            return Ok(RolesList);
        }
        [HttpGet]
        [Route("api/maprole/gettreedata")]
        public string GetTreeData(string RoleID, string UID)
        {
            if (!string.IsNullOrEmpty(RoleID.Trim()))
            {
                //DataTable dtCheckNameExists = (DataTable)Session["tempUserName"];
                //DataRow[] dr = dtCheckNameExists.Select("UserName = '" + strRoleName.Trim() + "'");
                //if (dr.Count() > 0)
                //{
                DataTable dt = bl.BL_ExecuteParamSP("uspGetMapRoleMenus", RoleID.Trim(), UID);
                if (dt.Rows.Count > 0)
                {
                    MapRoleModel root = new MapRoleModel { id = "MapRole", children = { }, state = new clsState() { selected = false }, text = "Map Role" };
                    DataView view = new DataView(dt);
                    view.RowFilter = "MenuParentId=0";
                    view.Sort = "MenuId";
                    foreach (DataRowView kvp in view)
                    {
                        string parentId = kvp["MenuId"].ToString();
                        MapRoleModel node = new MapRoleModel { id = kvp["MenuId"].ToString(), state = new clsState() { selected = false }, text = kvp["MenuName"].ToString() };
                        root.children.Add(node);
                        AddChildItems(dt, node, parentId);
                    }
                    string finalmenus = (new JavaScriptSerializer().Serialize(root));
                    return (finalmenus);
                }
                //}
            }
            return (new JavaScriptSerializer().Serialize(null));
        }

        private void AddChildItems(DataTable dt, MapRoleModel parentNode, string ParentId)
        {
            DataView viewItem = new DataView(dt);
            viewItem.RowFilter = "MenuParentId=" + ParentId;
            foreach (DataRowView childView in viewItem)
            {
                DataView viewItemChecking = new DataView(dt);
                viewItemChecking.RowFilter = "MenuParentId=" + childView["MenuId"].ToString();
                bool IsTrue = (viewItemChecking.Count > 0 ? false : Convert.ToBoolean(Convert.ToInt32(childView["Permission"])));

                MapRoleModel node = new MapRoleModel { id = childView["MenuId"].ToString(), state = new clsState() { selected = IsTrue }, text = childView["MenuName"].ToString() };
                parentNode.children.Add(node);
                string pId = childView["MenuId"].ToString();
                AddChildChildItems(dt, node, pId);
            }
        }

        private void AddChildChildItems(DataTable dt, MapRoleModel parentNode, string ParentId)
        {
            DataView viewItem = new DataView(dt);
            viewItem.RowFilter = "MenuParentId=" + ParentId;
            foreach (DataRowView childChildView in viewItem)
            {
                MapRoleModel node = new MapRoleModel { id = childChildView["MenuId"].ToString(), state = new clsState() { selected = Convert.ToBoolean(Convert.ToInt32(childChildView["Permission"])) }, text = childChildView["MenuName"].ToString() };
                parentNode.children.Add(node);
            }
        }
        [HttpPost]
        [Route("api/maprole/savemaprole")]
        public IHttpActionResult SaveMapUserDetails([FromBody] SaveMapRoleRequest request)
        {
            string strMsg = "";
            try
            {
                List<checkedIDs> checked_ids = request.checked_ids;
                string RoleName = request.RoleName; string UID = request.UID;
                int UserID = Convert.ToInt32(UID);
                if (!string.IsNullOrEmpty(RoleName))
                {
                    if (checked_ids != null)
                    {
                        int Index = 1;
                        if (checked_ids.Count > 0)
                        {
                            foreach (checkedIDs chkIDs in checked_ids)
                            {
                                //if (chkIDs.IDs > 0)
                                {
                                    bl.BL_ExecuteParamSP("uspUpdateMapRoleMenus", 1, RoleName, UserID, chkIDs.IDs, Index);
                                    Index++;
                                }
                            }
                            strMsg = "Saved Successfully";
                        }
                    }
                    else
                    {
                        bl.BL_ExecuteParamSP("uspUpdateMapRoleMenus", 2, RoleName, UserID, null, 1);
                    }
                }
            }
            catch (Exception ex)
            {
                throw ex;
            }

            return Ok(strMsg);
        }
    }
}
