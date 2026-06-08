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
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspManagePrintProfileconfig", 1);
                string val = JsonConvert.SerializeObject(DDT);
                return Ok(val);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Tools", "printprofileconfig/get", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/printprofileconfig/getprofile")]
        public IHttpActionResult GetProfilebyid(string TransID)
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspManagePrintProfileconfig", 3, TransID);
                string val = JsonConvert.SerializeObject(DDT);
                return Ok(val);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Tools", "printprofileconfig/getprofile", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/printprofileconfig/save")]
        public IHttpActionResult saveupdateproductlocation(List<PrintProfileConfig> lstProfiles)
        {
            try
            {
                List<SaveMessage> list = new List<SaveMessage>();
                if (lstProfiles != null)
                {
                    foreach (PrintProfileConfig item in lstProfiles)
                    {
                        bl.BL_ExecuteParamSP("uspManagePrintProfileconfig", 2, item.TransID, item.ConfigID, item.DefaultConfig, item.AutoMail,
                            item.UserID);
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
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Tools", "printprofileconfig/save", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/transactionvariant/gettrans")]
        public IHttpActionResult GetTrans(int Mode, int PartyType)
        {
            try
            {
                if (Mode == 1)
                {
                    DataTable DDT = bl.BL_ExecuteParamSP("uspManageTransVariant", Mode);
                    string val = JsonConvert.SerializeObject(DDT);
                    return Ok(val);
                }
                else if (Mode == 2)
                {
                    DataTable DDT = bl.BL_ExecuteParamSP("uspManageTransVariant", Mode, PartyType);
                    string val = JsonConvert.SerializeObject(DDT);
                    return Ok(val);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Tools", "transactionvariant/gettrans", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/maprole/getroles")]
        public IHttpActionResult GetRoleNames(int RoleID)
        {
            try
            {
                var RolesList = new List<object>();
                DataTable dtComboBoxData = bl.BL_ExecuteParamSP("uspManageUsers", 7, RoleID);
                if (dtComboBoxData.Rows.Count > 0)
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
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Tools", "maprole/getroles", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/maprole/gettreedata")]
        public IHttpActionResult GetTreeData(string RoleID, string UID)
        {
            try
            {
                if (!string.IsNullOrEmpty(RoleID.Trim()))
                {
                    //DataTable dtCheckNameExists = (DataTable)Session["tempUserName"];
                    //DataRow[] dr = dtCheckNameExists.Select("UserName = '" + strRoleName.Trim() + "'");
                    //if (dr.Count() > 0)
                    //{
                    string WebPerm = "", MobilePerm = "";
                    DataTable dt = bl.BL_ExecuteParamSP("uspGetMapRoleMenus", RoleID.Trim(), UID, 0);

                    if (dt.Rows.Count > 0)
                    {
                        MapRoleModel root = new MapRoleModel { id = "MapRole", children = { }, state = new clsState() { selected = false }, text = "Web Permissions" };
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
                        WebPerm = (new JavaScriptSerializer().Serialize(root));
                    }
                    dt = bl.BL_ExecuteParamSP("uspGetMapRoleMenus", RoleID.Trim(), UID, 1);

                    if (dt.Rows.Count > 0)
                    {
                        MapRoleModel root = new MapRoleModel { id = "MobileMapRole", children = { }, state = new clsState() { selected = false }, text = "Mobile Permissions" };
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
                        MobilePerm = (new JavaScriptSerializer().Serialize(root));
                    }
                    //}
                    var objPermissions = new List<object>();
                    objPermissions.Add(new
                    {
                        WebPermissions = WebPerm,
                        MobilePermissions = MobilePerm
                    });
                    return Ok(objPermissions);

                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Tools", "maprole/gettreedata", ex.Message);
            }
            return Ok();// (new JavaScriptSerializer().Serialize(null));
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
                bl.BL_WriteErrorMsginLog("Tools", "maprole/savemaprole", ex.Message);
            }

            return Ok(strMsg);
        }

        [HttpGet]
        [Route("api/BranchMapping/get")]
        public IHttpActionResult GetBranchMapping(int RoleID)
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspManageBranchMapping", 1, RoleID);


                return Ok(DDT);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Tools", "BranchMapping/get", ex.Message);
            }
            return Ok();
        }

        [HttpPost]
        [Route("api/BranchMapping/save")]
        public IHttpActionResult saveupdateBranch(List<BranchMapping> lstProfiles)
        {
            try
            {
                List<SaveMessage> list = new List<SaveMessage>();
                if (lstProfiles != null)
                {
                    foreach (BranchMapping item in lstProfiles)
                    {
                        bl.BL_ExecuteParamSP("uspManageBranchMapping", 2, item.RoleID, item.BranchID, item.Active, item.SetAsDefault,
                            item.UserID);
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
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Tools", "BranchMapping/save", ex.Message);
            }
            return Ok();
        }


        [HttpGet]
        [Route("api/BranchMapping/getByRole")]
        public IHttpActionResult GetBranchesByRole(int RoleID)
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetBranchByRoles", RoleID);
                return Ok(DDT);
            }
            catch(Exception ex )
            {
                bl.BL_WriteErrorMsginLog("Tools", "BranchMapping/getByRole", ex.Message);
            }
            return Ok();
        }

    }
}
