using DocumentFormat.OpenXml.VariantTypes;
using DocumentFormat.OpenXml.Wordprocessing;
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
using System.Web;
using System.Web.Http;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class DeliveryController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/delivery/get")]
        public IHttpActionResult GetData(string Mode, string ID)
        {
            try
            {
                DataTable DDT = new DataTable();
                if (Mode == "1")
                {
                    DataSet dtDelivData = bl.BL_ExecuteParamSPDataset("uspGetSetDelivery", Mode);
                    return Ok(dtDelivData);
                }
                if (Mode == "3")
                {
                    DataSet dtDelivData = bl.BL_ExecuteParamSPDataset("uspGetSetDelivery", Mode, ID);
                    return Ok(dtDelivData);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Delivery", "delivery/get", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/delivery/filterdata")]
        public IHttpActionResult Getfilterdata(string Mode, string FromDate, string ToDate, string ShowAll)
        {
            try
            {
                DataTable DDT = new DataTable();
                DataTable dtDelivData = bl.BL_ExecuteParamSP("uspGetSetDelivery", Mode, 0, FromDate, ToDate, ShowAll);
                return Ok(dtDelivData);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Delivery", "delivery/filterdata", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/delivery/invoicedata")]
        public IHttpActionResult Getinvoicedata(DeliveryProductFilter deliveryfilter)
        {
            try
            {
                if (deliveryfilter == null) return Ok();

                DataView dtView = new DataView(bl.BL_StringSplitCommaHyphen(deliveryfilter.DocumentIDs.Trim()));
                DataTable dtDocIDs = dtView.ToTable(true, "SerialNo");
                string DocIDs = "";
                for (int i = 0; i < dtDocIDs.Rows.Count; i++)
                {
                    DocIDs += dtDocIDs.Rows[i][0].ToString() + ',';
                }
                DocIDs = !string.IsNullOrEmpty(DocIDs) ? DocIDs.Remove(DocIDs.Length - 1) : DocIDs;
                DataTable DDT = new DataTable();
                DataTable dtDelivData = bl.BL_ExecuteParamSP("uspLoadDeliveryDocumentData_new", deliveryfilter.BranchID, deliveryfilter.TransMode,
                    deliveryfilter.DeliveryID, deliveryfilter.CustomerID, deliveryfilter.BeatID, deliveryfilter.SalesmanID
                    , deliveryfilter.FromDate, deliveryfilter.ToDate, deliveryfilter.InclDoc, DocIDs);
                return Ok(dtDelivData);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Delivery", "delivery/invoicedata", ex.Message);
            }
            return Ok();
        }
            [HttpPost]
        [Route("api/delivery/invoiceproducts")]
        public IHttpActionResult Getinvoiceproducts(DeliveryProductFilter deliveryfilter)
        {
            try
            {
                if (deliveryfilter == null) return Ok();
                DataTable dtSelDocs = new DataTable("Docs");
                dtSelDocs.Columns.Add("TransName", typeof(string));
                dtSelDocs.Columns.Add("Status", typeof(int));
                dtSelDocs.Columns.Add("DocumentID", typeof(int));
                DataView dtView = new DataView(bl.BL_StringSplitCommaHyphen(deliveryfilter.DocumentIDs.Trim()));
                DataTable dtDocIDs = dtView.ToTable(true, "SerialNo");
                for (int i = 0; i < dtDocIDs.Rows.Count; i++)
                {
                    DataRow drr = dtSelDocs.NewRow();
                    drr["TransName"] = "Delivery";
                    drr["DocumentID"] = dtDocIDs.Rows[i][0].ToString();
                    drr["Status"] = (i + 1);
                    dtSelDocs.Rows.Add(drr);
                }
                bl.bl_Transaction(1);
                DataTable dtProductData = bl.bl_ManageTrans("uspLoadDeliveryProductData", deliveryfilter.BranchID, deliveryfilter.TransMode,
                    deliveryfilter.DeliveryID, dtSelDocs);
                bl.bl_Transaction(2);
                return Ok(dtProductData);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Delivery", "delivery/invoiceproducts", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/delivery/save")]
        public IHttpActionResult Save(DeliveryModel listTrans)
        {
            try
            {
                List<SaveMessage> list = new List<SaveMessage>();
                if (listTrans != null)
                {
                    DataView dtView = new DataView(bl.BL_StringSplitCommaHyphen(listTrans.DocumentIDs.Trim()));
                    DataTable dtDocIDs = dtView.ToTable(true, "SerialNo");
                    DataTable dtSelDocs = new DataTable("Docs");
                    dtSelDocs.Columns.Add("TransName", typeof(string));
                    dtSelDocs.Columns.Add("Status", typeof(int));
                    dtSelDocs.Columns.Add("DocumentID", typeof(int));
                    for (int i = 0; i < dtDocIDs.Rows.Count; i++)
                    {
                        DataRow drr = dtSelDocs.NewRow();
                        drr["TransName"] = "Delivery";
                        drr["DocumentID"] = dtDocIDs.Rows[i][0].ToString();
                        drr["Status"] = (i + 1);
                        dtSelDocs.Rows.Add(drr);
                    }
                    int nTransMode = bl.BL_nValidation(listTrans.TransMode);
                    if (nTransMode != 6)
                    {
                        bl.bl_Transaction(1);
                        DataTable dtInvoiceData = bl.bl_ManageTrans("uspValidateDeliveryDocumentData", listTrans.FilterBranch,
                            listTrans.TransMode, bl.BL_nValidation(listTrans.ID), dtSelDocs);
                        bl.bl_Transaction(2);
                        if (dtInvoiceData.Rows.Count > 0)
                        {

                            string DocsID = "";
                            for (int i = 0; i < dtInvoiceData.Rows.Count; i++)
                            {
                                DocsID += dtInvoiceData.Rows[i][0].ToString() + ",";
                            }

                            list.Add(new SaveMessage()
                            {
                                ID = 0.ToString(),
                                MsgID = "2",
                                Message = DocsID//"<code>" + DocsID + "</code> Document Already Mapped"
                            });
                            return Ok(list);
                        }
                    }
                    bl.bl_Transaction(1);
                    try
                    {
                        DataTable dtResult = bl.bl_ManageTrans("uspManageDelivery", listTrans.TransMode, bl.BL_nValidation(listTrans.ID), bl.BL_nValidation(listTrans.DocPrefix), listTrans.DocDate,
                            bl.BL_nValidation(listTrans.BranchID), bl.BL_nValidation(listTrans.SalesmanID),
                            bl.BL_nValidation(listTrans.VehicleID), listTrans.DocumentIDs, bl.BL_nValidation(listTrans.Status),
                            bl.BL_nValidation(listTrans.CurrentStatus), listTrans.RefNo, listTrans.Remarks, listTrans.Narration,
                            listTrans.UID);
                        if (dtResult.Columns.Count > 1)
                        {
                            bl.bl_Transaction(3);
                            string[] strErrorList = dtResult.Rows[0][0].ToString().Split('$');
                            list.Add(new SaveMessage()
                            {
                                ID = 0.ToString(),
                                MsgID = "1",
                                Message = dtResult.Rows[0][0].ToString()
                            });
                            return Ok(list);
                        }
                        else
                        {
                            bl.bl_Transaction(2);
                            int nBillScopeID = bl.BL_nValidation(dtResult.Rows[0][0]);
                            list.Add(new SaveMessage()
                            {
                                ID = nBillScopeID.ToString(),
                                MsgID = "0",
                                Message = "Saved Successfully"
                            });
                            return Ok(list);
                        }
                    }
                    catch (Exception ex)
                    {
                        bl.bl_Transaction(3);
                        bl.BL_WriteErrorMsginLog("Delivery", "Save", ex.Message);
                        list.Add(new SaveMessage()
                        {
                            ID = 0.ToString(),
                            MsgID = "1",
                            Message = ex.Message
                        });
                        return Ok(list);
                    }
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Delivery", "delivery/save", ex.Message);
            }
            return Ok();
        }
    }
}
