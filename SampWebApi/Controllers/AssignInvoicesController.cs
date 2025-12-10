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
    public class AssignInvoicesController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/assigninvoices/getdata")]
        public IHttpActionResult GetData(string Mode, string ID, string BeatID, string SalesmanID, string Party, string FromDate, string ToDate, string Showall)
        {
            DataTable DDT = new DataTable();
            if (Mode == "1")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetAssignInvoices", Mode);
                List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new CustomerVendorModel
                    {
                        FType = DDT.Rows[i][0].ToString(),
                        Form = DDT.Rows[i][1].ToString(),
                        ID = DDT.Rows[i][2].ToString(),
                        Code = DDT.Rows[i][3].ToString(),
                        Name = DDT.Rows[i][4].ToString(),
                    });
                }
                return Ok(list);
            }
            else if (Mode == "2")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetAssignInvoices", Mode, 0, BeatID, SalesmanID, Party, FromDate, ToDate, Showall);
                List<AssignInvoiceHeader> list = new List<AssignInvoiceHeader>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new AssignInvoiceHeader
                    {
                        ID = DDT.Rows[i]["ID"].ToString(),
                        DocID = DDT.Rows[i]["DocID"].ToString(),
                        Date = DDT.Rows[i]["DocDate"].ToString(),
                        RefNo = DDT.Rows[i]["RefNo"].ToString(),                        
                        SalesmanID = DDT.Rows[i]["Salesman"].ToString(),
                        Status = DDT.Rows[i]["Status"].ToString(),
                        DetailStatusCount = DDT.Rows[i]["DetailSts"].ToString(),
                        CollInvCount = DDT.Rows[i]["coldtl"].ToString(),
                        TotalInvCount = DDT.Rows[i]["InvoiceCount"].ToString(),
                        CBy = DDT.Rows[i]["UserName"].ToString(),
                        CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                        StatusID = DDT.Rows[i]["StatusID"].ToString(),
                    });
                }

                var data = from users in list
                           select
                               new
                               {
                                   ID = users.ID,
                                   DocID = users.DocID,
                                   Date = users.Date,
                                   RefNo = users.RefNo,                                   
                                   Salesman = users.SalesmanID,
                                   Status = users.Status,
                                   DetailStatusCount = users.DetailStatusCount,
                                   CollInvCount = users.CollInvCount,
                                   TotalInvCount = users.TotalInvCount,
                                   StatusID = users.StatusID,
                                   CBy = users.CBy,
                                   CDate = users.CDate,
                               };

                return Ok(data);
            }
            else if (Mode == "3")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetAssignInvoices", Mode, ID, BeatID, SalesmanID, Party, FromDate, ToDate, Showall);
                List<AssignInvoiceHeader> list = new List<AssignInvoiceHeader>();
                if (DDT.Rows.Count > 0)
                {
                    DataTable DDT1 = bl.BL_ExecuteParamSP("uspGetSetAssignInvoices", 4, ID, BeatID, SalesmanID, Party, FromDate, ToDate, Showall);
                    List<AssignInvoiceDetails> listDetails = new List<AssignInvoiceDetails>();
                    for (int i = 0; i < DDT1.Rows.Count; i++)
                    {
                        listDetails.Add(new AssignInvoiceDetails
                        {
                            ID = DDT1.Rows[i]["ID"].ToString(),
                            DocId = DDT1.Rows[i]["DocID"].ToString(),
                            DocDate = DDT1.Rows[i]["Date"].ToString(),
                            RefNo = DDT1.Rows[i]["RefNo"].ToString(),
                            Beat = DDT1.Rows[i]["Beat"].ToString(),
                            Salesman = DDT1.Rows[i]["Salesman"].ToString(),
                            Customer = DDT1.Rows[i]["Customer"].ToString(),
                            NetAmt = DDT1.Rows[i]["NetAmt"].ToString(),
                            Balance = DDT1.Rows[i]["Balance"].ToString(),
                            Ageing = DDT1.Rows[i]["Ageing"].ToString(),
                            Status = DDT1.Rows[i]["Status"].ToString(),
                            AssignedInvoiceCount = DDT1.Rows[i]["AssignedInvoiceCount"].ToString(),
                        });
                    }
                    var data = from users in listDetails
                               select
                                   new
                                   {
                                       ID = users.ID,
                                       DocID = users.DocId,
                                       Date = users.DocDate,
                                       RefNo = users.RefNo,
                                       Beat = users.Beat,
                                       Salesman = users.Salesman,
                                       Customer = users.Customer,
                                       NetAmt = users.NetAmt,
                                       Balance = users.Balance,
                                       Ageing = users.Ageing,
                                       Status = users.Status,
                                       AssignedInvoiceCount = users.AssignedInvoiceCount,
                                   };
                    string InvoiceJSONCONV = JsonConvert.SerializeObject(data);
                    list.Add(new AssignInvoiceHeader
                    {
                        ID = DDT.Rows[0]["ID"].ToString(),
                        DocID = DDT.Rows[0]["DocID"].ToString(),
                        Date = Convert.ToDateTime(DDT.Rows[0]["DocDate"].ToString()).ToString("yyyy-MM-dd"),
                        RefNo = DDT.Rows[0]["RefNo"].ToString(),
                        SalesmanID = DDT.Rows[0]["SalesmanID"].ToString(),
                        Status = DDT.Rows[0]["Status"].ToString(),
                        
                        lstJsonAssignDetails = InvoiceJSONCONV
                    });
                }
                return Ok(list);
            }
            else if (Mode == "5")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetAssignInvoices", Mode, 0, BeatID, SalesmanID, Party, FromDate, ToDate, Showall);
                List<AssignInvoiceDetails> list = new List<AssignInvoiceDetails>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new AssignInvoiceDetails
                    {
                        ID = DDT.Rows[i]["ID"].ToString(),
                        DocId = DDT.Rows[i]["DocID"].ToString(),
                        DocDate = DDT.Rows[i]["Date"].ToString(),
                        RefNo = DDT.Rows[i]["RefNo"].ToString(),
                        Beat = DDT.Rows[i]["Beat"].ToString(),
                        Salesman = DDT.Rows[i]["Salesman"].ToString(),
                        Customer = DDT.Rows[i]["Customer"].ToString(),
                        NetAmt = DDT.Rows[i]["NetAmt"].ToString(),
                        Balance = DDT.Rows[i]["Balance"].ToString(),
                        Ageing = DDT.Rows[i]["Ageing"].ToString(),
                        AssignedInvoiceCount = DDT.Rows[i]["AssignedInvoiceCount"].ToString(),
                    });
                }

                var data = from users in list
                           select
                               new
                               {
                                   ID = users.ID,
                                   DocID = users.DocId,
                                   Date = users.DocDate,
                                   RefNo = users.RefNo,
                                   Beat = users.Beat,
                                   Salesman = users.Salesman,
                                   Customer = users.Customer,
                                   NetAmt = users.NetAmt,
                                   Balance = users.Balance,
                                   Ageing = users.Ageing,
                                   AssignedInvoiceCount = users.AssignedInvoiceCount,
                               };

                return Ok(data);
            }
            return Ok();
        }

        [HttpPost]
        [Route("api/assigninvoices/save")]
        public IHttpActionResult Save(AssignInvoiceHeader listTrans)
        {
            if (listTrans != null)
            {
                DataTable dtDocument = new DataTable();
                dtDocument.Columns.Add("TransName");
                dtDocument.Columns.Add("Status", typeof(int)).DefaultValue = 1;
                dtDocument.Columns.Add("DocumentId", typeof(int)).DefaultValue = 0;
                DataTable dtInvoices = bl.ConvertListToDataTable(listTrans.lstAssignDetails);
                List<SaveMessage> list = new List<SaveMessage>();
                if (listTrans.TransMode != "4")
                {
                    for (int i = 0; i < dtInvoices.Rows.Count; i++)
                    {
                        int nInvID = bl.BL_nValidation(Convert.ToString(dtInvoices.Rows[i]["ID"]));
                        DataRow dtRow = dtDocument.NewRow();
                        dtRow[0] = (i + 1);
                        dtRow[1] = 1;
                        dtRow[2] = nInvID;
                        dtDocument.Rows.Add(dtRow);
                    }
                    string nMode = listTrans.TransMode == "3" ? "1" : listTrans.TransMode;
                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspManageAssignInvoices", nMode, bl.BL_nValidation(listTrans.TransID), bl.BL_nValidation(listTrans.ID),
                        listTrans.Date, listTrans.SalesmanID, listTrans.RefNo, listTrans.UDFId, listTrans.CBy, bl.BL_nValidation(listTrans.Status), bl.BL_nValidation(listTrans.CurrentStatus), dtDocument);
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
                        bl.bl_Transaction(1);
                        bl.bl_ManageTrans("uspManageAssignInvoices", 7, 0, nBillScopeID,
                             null, listTrans.SalesmanID, null, null, null, null, null, dtDocument);
                        bl.bl_Transaction(2);
                        list.Add(new SaveMessage()
                        {
                            ID = nBillScopeID.ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                        return Ok(list);
                    }
                }
                else
                {
                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspManageAssignInvoices", listTrans.TransMode, bl.BL_nValidation(listTrans.TransID), bl.BL_nValidation(listTrans.ID),
                        listTrans.Date, listTrans.SalesmanID, listTrans.RefNo, listTrans.UDFId, listTrans.CBy, bl.BL_nValidation(listTrans.Status), bl.BL_nValidation(listTrans.CurrentStatus), dtDocument);
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
                        int nBillScopeID = bl.BL_nValidation(listTrans.TransID);
                        
                        list.Add(new SaveMessage()
                        {
                            ID = nBillScopeID.ToString(),
                            MsgID = "0",
                            Message = "Cancelled Successfully"
                        });
                        return Ok(list);
                    }
                }
            }
            return Ok();
        }
    }
}
