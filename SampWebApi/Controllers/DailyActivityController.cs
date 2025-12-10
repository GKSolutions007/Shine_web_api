using DocumentFormat.OpenXml.Bibliography;
using DocumentFormat.OpenXml.Office2010.Excel;
using DocumentFormat.OpenXml.Office2010.ExcelAc;
using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using static System.Windows.Forms.VisualStyles.VisualStyleElement.ListView;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class DailyActivityController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/dailyactivity/getdata")]
        public IHttpActionResult GetData(string Mode, string ID, string SalesmanID = "")
        {
            DataTable DDT = new DataTable();
            if (Mode == "1" || Mode == "2")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetsetDailyactivityData", Mode, ID, SalesmanID);
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
            
            return Ok();
        }
        [HttpGet]
        [Route("api/dailyactivity/itemfilter")]
        public IHttpActionResult GetProductFilter(string Mode, string CustomerID, string BranchID, string FilterType, string FilterValue = "")
        {
            DataTable DDT = bl.BL_ExecuteParamSP("uspGetsetDailyactivityData", Mode, CustomerID, BranchID, FilterType, FilterValue);
            List<DailyActivityDetails> list = new List<DailyActivityDetails>();
            for (int i = 0; i < DDT.Rows.Count; i++)
            {
                list.Add(new DailyActivityDetails
                {
                    ID = DDT.Rows[i][0].ToString(),
                    Name = DDT.Rows[i][1].ToString(),
                    PriceDesc = DDT.Rows[i][2].ToString(),
                    Rate = DDT.Rows[i][3].ToString(),
                    Discount = DDT.Rows[i][4].ToString(),
                    MRP = DDT.Rows[i][5].ToString(),
                });
            }
            string str = "";
            var dtjsonData = new
            {
                data = from users in list
                       select
                           new
                           {
                               ID = users.ID,
                               Name = users.Name,
                               PriceDesc = users.PriceDesc,
                               Rate = users.Rate,
                               Discount = users.Discount,
                               MRP = users.MRP,
                           }
            };
            return Ok(dtjsonData);
        }
        [HttpPost]
        [Route("api/dailyactivity/save")]
        public IHttpActionResult Save(DailyActivity listTrans)
        {
            if (listTrans != null)
            {
                DataTable dtProd = new DataTable();
                if (dtProd.Columns.Count == 0)
                {
                    dtProd.Columns.Add("ProdId", typeof(int));
                    dtProd.Columns.Add("UomId", typeof(int));
                    dtProd.Columns.Add("Qty", typeof(decimal));
                    dtProd.Columns.Add("Price", typeof(decimal));
                    dtProd.Columns.Add("OrgPrice", typeof(decimal));
                    dtProd.Columns.Add("Amount", typeof(decimal), "(Qty*Price)");
                    dtProd.Columns.Add("DiscPern", typeof(decimal));
                    dtProd.Columns.Add("DiscAmt", typeof(decimal), "(DiscPern*Amount)/100");
                    dtProd.Columns.Add("ConversionRate", typeof(decimal));
                    dtProd.Columns.Add("Serial", typeof(int));
                }
                DataTable dtProducts = bl.ConvertListToDataTable(listTrans.lstProdDetails);
                for (int j = 0; j < dtProducts.Rows.Count; j++)
                {
                    DataRow dtRow = dtProd.NewRow();
                    dtRow[0] = Convert.ToString(dtProducts.Rows[j]["ID"]);
                    dtRow[1] = 0;
                    dtRow[2] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[j]["Qty"]));
                    dtRow[3] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[j]["AppPrice"]));
                    dtRow[4] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[j]["Rate"]));
                    dtRow[6] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[j]["Discount"]));
                    dtRow[8] = 1;
                    dtRow[9] = (j + 1);
                    dtProd.Rows.Add(dtRow);
                }
                List<SaveMessage> list = new List<SaveMessage>();
                string formattedDate = DateTime.Today.ToString("yyyy-MM-dd");
                string dt = Convert.ToDateTime(formattedDate).ToString();//"yyyy-MM-dd"
                bl.bl_Transaction(1);
                DataTable dtResult = bl.bl_ManageTrans("uspManageOrderTakenImport", dtProd, 1, 0, dt, listTrans.BranchID,
                                           listTrans.CustomerID, bl.BL_nValidation(listTrans.BeatID), bl.BL_nValidation(listTrans.SalesManID), null, 
                                           bl.BL_dValidation(listTrans.AddnlDisc),
                                           bl.BL_dValidation(listTrans.TrdDisc), 1, 0, null, bl.BL_nValidation(listTrans.UserID), 2, listTrans.ActivityID,listTrans.FeedBack);
                if (dtResult.Rows.Count > 0)
                {
                    bl.bl_Transaction(2);
                    int nBillScopeID = bl.BL_nValidation(dtResult.Rows[0][0]);
                    list.Add(new SaveMessage()
                    {
                        ID = nBillScopeID.ToString(),
                        MsgID = "0",
                        Message = "Saved Successfully"
                    });
                }
                else
                {
                    bl.bl_Transaction(3);
                    list.Add(new SaveMessage()
                    {
                        ID = 0.ToString(),
                        MsgID = "1",
                        Message = "Data note Saved"
                    });
                }
                return Ok(list);                               
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/mobilecollection/getdata")]
        public IHttpActionResult GetMOBCOLLData(string Mode, string ID, string SalesmanID = "", string FilterType = "")
        {
            DataTable DDT = new DataTable();
            if (Mode == "1" || Mode == "2")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetsetMobileCollectionData", Mode, ID, SalesmanID, FilterType);
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
            else if (Mode == "4")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetsetMobileCollectionData", Mode, ID, SalesmanID, FilterType);
                List<adjDocs> list = new List<adjDocs>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new adjDocs
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        Docprefix = DDT.Rows[i][1].ToString(),
                        Docid = DDT.Rows[i][2].ToString(),
                        Docdate = DDT.Rows[i][3].ToString(),
                        Refno = DDT.Rows[i][4].ToString(),
                        NetAmt = DDT.Rows[i][5].ToString(),
                        Balance = DDT.Rows[i][6].ToString(),
                        AssignInvoiceID = DDT.Rows[i][7].ToString(),
                    });
                }
               var data = from users in list
                       select
                           new
                           {
                               ID = users.ID,
                               Docprefix = users.Docprefix,
                               Docid = users.Docid,
                               Docdate = users.Docdate,
                               Refno = users.Refno,
                               NetAmt = users.NetAmt,
                               Balance = users.Balance,
                               AssignInvoiceID = users.AssignInvoiceID,
                           };
                return Ok(data);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/mobilecollection/save")]
        public IHttpActionResult Savemobcoll(CollectionModel listTrans)
        {
            if (listTrans != null)
            {
                DataTable dtDetail = new DataTable();
                dtDetail.Columns.Add("AccID", typeof(int));
                dtDetail.Columns.Add("DocPrefix", typeof(int));
                dtDetail.Columns.Add("DocValue", typeof(int));
                dtDetail.Columns.Add("DocID", typeof(int));
                dtDetail.Columns.Add("DocDate", typeof(DateTime));
                dtDetail.Columns.Add("Balance", typeof(decimal));
                dtDetail.Columns.Add("ColValue", typeof(decimal));
                dtDetail.Columns.Add("AdjAmt", typeof(decimal));
                dtDetail.Columns.Add("DiscPer", typeof(string));
                dtDetail.Columns.Add("DiscAmt", typeof(decimal));
                dtDetail.Columns.Add("FullyAdj", typeof(int));
                dtDetail.Columns.Add("FullyAdjAmt", typeof(decimal));
                dtDetail.Columns.Add("TotalAmtAdj", typeof(decimal));
                dtDetail.Columns.Add("TranType", typeof(int));
                dtDetail.Columns.Add("SerialNo", typeof(int));

                DataTable dtInvoices = bl.ConvertListToDataTable(listTrans.lstadjdocs);
                for (int j = 0; j < dtInvoices.Rows.Count; j++)
                {
                    string ID = Convert.ToString(dtInvoices.Rows[j]["ID"]);
                    DataRow dtRow = dtDetail.NewRow();
                    dtRow["Docid"] = Convert.ToString(dtInvoices.Rows[j]["ID"]);
                    dtRow["DocPrefix"] = Convert.ToString(dtInvoices.Rows[j]["DocPrefix"]);
                    dtRow["DocDate"] = Convert.ToString(dtInvoices.Rows[j]["Docdate"]);
                    dtRow["Balance"] = bl.BL_dValidation(Convert.ToString(dtInvoices.Rows[j]["Balance"]));
                    dtRow["ColValue"] = bl.BL_dValidation(Convert.ToString(dtInvoices.Rows[j]["NetAmt"]));
                    dtRow["AdjAmt"] = bl.BL_dValidation(Convert.ToString(dtInvoices.Rows[j]["AmtAdj"]));
                    dtRow["DiscAmt"] = bl.BL_dValidation(Convert.ToString(dtInvoices.Rows[j]["Ohtercharges"]));
                    dtRow["TranType"] = bl.BL_dValidation(Convert.ToString(dtInvoices.Rows[j]["AssignInvoiceID"]));
                    dtRow["SerialNo"] = (j + 1);
                    dtDetail.Rows.Add(dtRow);
                }
                List<SaveMessage> list = new List<SaveMessage>();
                string formattedDate = DateTime.Today.ToString("yyyy-MM-dd");
                string dt = Convert.ToDateTime(DateTime.Today).ToString("yyyy-MM-dd");//"yyyy-MM-dd"                
                string chqdate = !string.IsNullOrEmpty(listTrans.Chequedate) ? Convert.ToDateTime(listTrans.Chequedate).ToString("yyyy-MM-dd") : null;
                try
                {
                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspManageMobileCollection", dtDetail, 1, 0, dt,
                                               listTrans.CustomerID, bl.BL_nValidation(listTrans.BeatID), bl.BL_nValidation(listTrans.SalesManID),
                                               bl.BL_nValidation(listTrans.PaymentmodeID),
                                               bl.BL_dValidation(listTrans.collectedamt), 0,
                                               listTrans.Chequeno, chqdate,
                                               listTrans.BankACno, listTrans.BankID, listTrans.ifsc, 1, bl.BL_nValidation(listTrans.UserID));
                    if (dtResult.Rows.Count > 0)
                    {
                        bl.bl_Transaction(2);
                        int nBillScopeID = bl.BL_nValidation(dtResult.Rows[0][0]);
                        list.Add(new SaveMessage()
                        {
                            ID = nBillScopeID.ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        bl.bl_Transaction(3);
                        list.Add(new SaveMessage()
                        {
                            ID = 0.ToString(),
                            MsgID = "1",
                            Message = "Data note Saved"
                        });
                    }
                }
                catch (Exception ex)
                {
                    bl.bl_Transaction(3);
                    list.Add(new SaveMessage()
                    {
                        ID = 0.ToString(),
                        MsgID = "1",
                        Message = ex.Message
                    });
                }
                return Ok(list);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/webcollection/getdata")]
        public IHttpActionResult GetWEBCOLLECTIONData(string Mode,string ID,string UserID = "")
        {
            DataTable DDT = new DataTable();
            if (Mode == "1")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetWebCollectionData", Mode);
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
            if(Mode == "4")
            {
                string[] Ids = ID.Split(',');
                for (int i = 0; i < Ids.Length; i++)
                {
                    DDT = bl.BL_ExecuteParamSP("uspGetSetWebCollectionData", Mode, Ids[i]);
                }                
            }
            if (Mode == "5")
            {
                List<SaveMessage> list = new List<SaveMessage>();
                DataTable dtDenominationPMDetail = new DataTable();DataTable dtMopDetails = new DataTable("MOP"), dtDetail = new DataTable("CollectionDetail"), dtHeader = new DataTable("CollectionHeader");
                dtDenominationPMDetail.Columns.Add("ColDetailDid", typeof(int));
                dtDenominationPMDetail.Columns.Add("ColDetailDenomination", typeof(int));
                dtDenominationPMDetail.Columns.Add("ColtotCoupons", typeof(int));
                dtDenominationPMDetail.Columns.Add("ColDetailCount", typeof(string));
                dtDenominationPMDetail.Columns.Add("ColDetailAmount", typeof(decimal));
                bl.BL_AddCollectionData(dtHeader, dtDetail, dtMopDetails);
                DataTable dtAdjRefId = new DataTable(), dtTVPTable = new DataTable();
                List<int> CollectionIDs = ID.Split(',').Select(int.Parse).OrderBy(n => n).ToList();
                for (int i = 0; i < CollectionIDs.Count; i++)
                {
                    int CollectionID = Convert.ToInt32(CollectionIDs[i]);
                    DataTable dtColHeader = bl.BL_ExecuteParamSP("uspGetSetWebCollectionData", 5, CollectionID);
                    
                    //DDT = bl.BL_ExecuteParamSP("uspGetSetWebCollectionData", Mode, CollectionIDs[i]);
                    int nPaymentMode = bl.BL_nValidation(dtColHeader.Rows[0]["PaymentID"]);
                    decimal dAmt = bl.BL_dValidation(dtColHeader.Rows[0]["Amt"]);
                    dtHeader.Rows.Clear();
                    DataRow CustRow = dtHeader.NewRow();
                    CustRow["Date"] = dtColHeader.Rows[0]["DocDate"];
                    CustRow["CoLLPYType"] = 0;
                    CustRow["AccID"] = dtColHeader.Rows[0]["FAID"];
                    CustRow["ColAmt"] = dAmt;
                    CustRow["Balance"] = bl.BL_dValidation(0);
                    CustRow["DocRefNo"] = "Web Collection";
                    CustRow["ColMode"] = nPaymentMode;
                    CustRow["Status"] = 1;
                    CustRow["ExAccId"] = 0;
                    CustRow["UID"] = UserID;
                    CustRow["Type"] = 0;
                    CustRow["SerialNo"] = 1;
                    CustRow["VisaPern"] = bl.BL_dValidation(0);
                    CustRow["VisaAmt"] = bl.BL_dValidation(0);
                    dtHeader.Rows.Add(CustRow);

                    dtMopDetails.Rows.Clear();

                    DataRow MopRow = dtMopDetails.NewRow();
                    MopRow["AccID"] = dtColHeader.Rows[0]["FAID"];
                    
                        MopRow["Mode"] = nPaymentMode;

                        if (nPaymentMode == 2 || nPaymentMode == 3)
                        {
                            MopRow["[Cheque/DD Number]"] = (dtColHeader.Rows[0]["ChequeNo"]);
                        }
                        if (nPaymentMode == 4 || nPaymentMode == 5)
                        {
                            MopRow["Neft"] = (dtColHeader.Rows[0]["ChequeNo"]);
                        }
                        if (nPaymentMode == 2 || nPaymentMode == 3 || nPaymentMode == 4)
                        {
                            MopRow["Date"] = dtColHeader.Rows[0]["ChequeDate"];
                        }
                        else
                        {
                            MopRow["Date"] = dtColHeader.Rows[0]["DocDate"];
                        }
                        MopRow["BankAccId"] = bl.BL_nValidation(dtColHeader.Rows[0]["BankAccountID"]);
                        MopRow["Amt"] = dAmt;
                        MopRow["IFSC"] =dtColHeader.Rows[0]["IFSCcode"];
                        MopRow["Bank"] = bl.BL_nValidation(dtColHeader.Rows[0]["BankID"]);
                        MopRow["Branch"] = dtColHeader.Rows[0]["BranchName"];
                        MopRow["PayAt"] = null;
                        MopRow["BankAccNo"] = dtColHeader.Rows[0]["BankAcNo"];
                        MopRow["ChequeBkRefNo"] = "";
                        MopRow["ChequeBookID"] = 0;
                    dtMopDetails.Rows.Add(MopRow);
                    dtDetail.Rows.Clear();
                    DataTable dtColDetails = bl.BL_ExecuteParamSP("uspGetSetWebCollectionData", 6, CollectionID);
                    for (int J = 0; J < dtColDetails.Rows.Count; J++)
                    {
                        DataRow InvRow = dtDetail.NewRow();
                        InvRow["AccID"] = bl.BL_nValidation(dtColHeader.Rows[0]["FAID"]);
                        InvRow["DocPrefix"] = bl.BL_nValidation(dtColDetails.Rows[J]["InvDocPrefix"]);
                        InvRow["DocValue"] = bl.BL_nValidation(dtColDetails.Rows[J]["DocValue"]);
                        InvRow["DocID"] = bl.BL_nValidation(dtColDetails.Rows[J]["InvoiceID"]);
                        InvRow["DocDate"] = Convert.ToString(dtColDetails.Rows[J]["InvDate"]);// DateTime.ParseExact(Convert.ToString(dtColDetails.Rows[J]["InvDate"]), "dd/MM/yyyy", CultureInfo.InvariantCulture);
                        InvRow["Balance"] = bl.BL_dValidation(Convert.ToString(dtColDetails.Rows[J]["InvBalance"]));
                        InvRow["ColValue"] = bl.BL_dValidation(Convert.ToString(dtColDetails.Rows[J]["AdjAmt"]));
                        InvRow["AdjAmt"] = bl.BL_dValidation(Convert.ToString(dtColDetails.Rows[J]["WriteOff"]));
                        InvRow["DiscPer"] = 0;
                        InvRow["DiscAmt"] = 0;
                        decimal dbal = bl.BL_dValidation(dtColDetails.Rows[J]["InvBalance"]);
                        decimal dCollValue = bl.BL_dValidation(dtColDetails.Rows[J]["AdjAmt"]);
                        decimal dAdjAmt = bl.BL_dValidation(dtColDetails.Rows[J]["WriteOff"]);
                        int nFullyAdj = (dbal == (dCollValue + (dAdjAmt < 0 ? 0 : dAdjAmt))) ? 1 : 0;                       
                        InvRow["FullyAdj"] = nFullyAdj;
                        InvRow["FullyAdjAmt"] = 0;
                        InvRow["TotalAmtAdj"] = bl.BL_dValidation(dtColDetails.Rows[J]["TotAdjAmt"]);
                        InvRow["TranType"] = 1;
                        InvRow["SerialNo"] = 1;
                        dtDetail.Rows.Add(InvRow);
                    }
                    int nBeatID = bl.BL_nValidation(dtColHeader.Rows[0]["BeatID"]);
                    int nSMID = bl.BL_nValidation(dtColHeader.Rows[0]["SalesmanID"]);
                    bl.bl_Transaction(1);
                    DataTable dtResult = new DataTable();
                    dtResult = bl.bl_ManageTrans("uspManageFullColl",
                        19, bl.BL_nValidation(0), dtHeader, dtDetail, dtMopDetails,
                        0,
                        nBeatID,
                        nSMID,
                        0,
                        dtDenominationPMDetail, 1, 0,
                        1,
                        0, "Web Collection", null);
                    if (dtResult.Columns.Count == 1)
                    {
                        int nScopeInvID = bl.BL_nValidation(dtResult.Rows[0][0].ToString());
                        
                        bl.bl_Transaction(2);
                        bl.BL_ExecuteParamSP("uspGetSetWebCollectionData", 7, CollectionID, nScopeInvID);
                        list.Add(new SaveMessage()
                        {
                            ID = nScopeInvID.ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                        return Ok(list);
                    }
                    else
                    {
                        bl.bl_Transaction(3);
                        string ErrMsg = "";
                        string[] strErrorList = dtResult.Rows[0][0].ToString().Split('$');
                        if (strErrorList.Length == 1)
                        {
                            if (strErrorList[0].Trim().ToUpper() == "PAYMENTSTATUS")
                            {
                                ErrMsg = "Payment mode status changed";
                            }
                            if (strErrorList[0].Trim().ToUpper() == "ACC")
                            {
                                ErrMsg = "Account name already deactivated";
                            }
                            if (strErrorList[0].Trim().ToUpper() == "CASH")
                            {
                                ErrMsg = "You don't have enough amount in account";
                            }
                            if (strErrorList[0].Trim().ToUpper() == "BANKACC")
                            {
                                ErrMsg = "Bank Account already deactivated";
                            }
                            if (strErrorList[0].Trim().ToUpper() == "BALANCE")
                            {
                                ErrMsg = "You don't have enough amount in account";
                            }
                            if (strErrorList[0].Trim().ToUpper() == "CHEQUE")
                            {
                                ErrMsg = "Cheque book permission changed";
                            }
                            if (strErrorList[0].Trim().ToUpper() == "CHEQUESTATUS")
                            {
                                ErrMsg = "Cheque book status already changed";
                            }
                            if (strErrorList[0].Trim().ToUpper() == "DOCUMENTSTATUS")
                            {
                                ErrMsg = "This document already processed";
                            }
                        }
                        else
                        {
                            int nDocPrefix = bl.BL_nValidation(strErrorList[1]);
                            int nDocIdent = bl.BL_nValidation(strErrorList[2]);
                            if (strErrorList[0].Trim().ToUpper() == "DOCUMENTAMOUNT")
                            {
                                ErrMsg = "Document amount was changed";
                            }
                            if (strErrorList[0].Trim().ToUpper() == "DOCUMENTSTATUS")
                            {
                                ErrMsg = "This document already processed";
                            }
                        }
                        list.Add(new SaveMessage()
                        {
                            ID = 0.ToString(),
                            MsgID = "0",
                            Message = ErrMsg
                        });
                        return Ok(list);
                    }
                }
            }
            if (Mode == "8")
            {
                List<adjDocs> list = new List<adjDocs>();
                DDT = bl.BL_ExecuteParamSP("uspGetSetWebCollectionData", Mode, ID);
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new adjDocs
                    {
                        Docid = DDT.Rows[i][0].ToString(),
                        Docdate = DDT.Rows[i][1].ToString(),
                        Refno = DDT.Rows[i][2].ToString(),
                        NetAmt = DDT.Rows[i][3].ToString(),
                        Amtadj = DDT.Rows[i][4].ToString(),
                        Ohtercharges = DDT.Rows[i][5].ToString(),                        
                    });
                }
                return Ok(list);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/webcollection/filterdata")]
        public IHttpActionResult GetwebcollectionFilter(string Mode, string ID, string SalesmanID, string CustomerID, string PayModeID, string ChequeDate, string AllowDate)
        {
            if (Mode == "2")
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetWebCollectionData", Mode, ID, SalesmanID, CustomerID, PayModeID, ChequeDate, AllowDate);
                List<CollectionModel> list = new List<CollectionModel>();
                string Cash = "0.00 / 0", Cheque = "0.00 / 0", Bank = "0.00 / 0";
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    if (DDT.Rows[i][0].ToString() == "1")
                    {
                        Cash = DDT.Rows[i][2].ToString() + " / " + DDT.Rows[i][1].ToString();
                    }
                    if (DDT.Rows[i][0].ToString() == "2")
                    {
                        Cheque = DDT.Rows[i][2].ToString() + " / " + DDT.Rows[i][1].ToString();
                    }
                    if (DDT.Rows[i][0].ToString() == "4")
                    {
                        Bank = DDT.Rows[i][2].ToString() + " / " + DDT.Rows[i][1].ToString();
                    }
                }
                list.Add(new CollectionModel
                {
                    CashValue = Cash,
                    ChequeValue = Cheque,
                    BankTransferValue = Bank                    
                });
                return Ok(list);
            }
            if (Mode == "3")
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetWebCollectionData", Mode, ID, SalesmanID, CustomerID, PayModeID, ChequeDate, AllowDate);
                List<CollectionModel> list = new List<CollectionModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new CollectionModel
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        Date = DDT.Rows[i][1].ToString(),
                        BeatName = DDT.Rows[i][2].ToString(),
                        SalesManName = DDT.Rows[i][3].ToString(),
                        CustomerName = DDT.Rows[i][4].ToString(),
                        Paymentmode = DDT.Rows[i][5].ToString(),
                        collectedamt = DDT.Rows[i][6].ToString(),
                        Chequedate = DDT.Rows[i][7].ToString(),
                        Chequeno = DDT.Rows[i][8].ToString(),
                    });
                }
                string str = "";

               var data = from users in list
                       select
                           new
                           {
                               ID = users.ID,
                               Date = users.Date,
                               BeatName = users.BeatName,
                               SalesManName = users.SalesManName,
                               CustomerName = users.CustomerName,
                               Paymentmode = users.Paymentmode,
                               collectedamt = users.collectedamt,
                               Chequedate = users.Chequedate,
                               Chequeno = users.Chequeno,
                           };
                
                return Ok(data);
            }
            return Ok();
        }
    }
}