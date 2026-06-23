using DocumentFormat.OpenXml.Bibliography;
using Microsoft.Office.Interop.Excel;
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
using DataTable = System.Data.DataTable;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class BulkCollectionController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        public DataTable dtDenominationPMDetail = new DataTable();
        DataTable dtMopDetails = new DataTable("MOP"), dtDetail = new DataTable("CollectionDetail"), dtHeader = new DataTable("CollectionHeader");
        [HttpGet]
        [Route("api/bulkcollection/filterdata")]
        public IHttpActionResult Getfilterdata(string Mode)
        {
            try
            {
                DataSet DDT = bl.BL_ExecuteParamSPDataset("uspgetsetBulkCollection", Mode);
                return Ok(DDT);               
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Bulk Collection", "Getfilterdata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/bulkcollection/documentdata")]
        public IHttpActionResult documentdata(string Branch,string Beat,string Salesman,string Party,string AsonDate)
        {
            try
            {
                System.Data.DataTable DDT = bl.BL_ExecuteParamSP("uspBulkCollectionData", Branch, Beat, Salesman, Party, AsonDate);
                return Ok(DDT);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Bulk Collection", "documentdata", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/bulkcollection/save")]
        public IHttpActionResult Save(BulkCollectionModel bulkcollectiondata)
        {
            var list = new List<object>();
            DataTable dtResponse = new DataTable();
            dtResponse.Columns.Add("ResponseType", typeof(string));//Error,Success
            dtResponse.Columns.Add("ResponseApplyby", typeof(int));//1 - Docwise,2 - FAID wise(Partywise),3 - Common
            dtResponse.Columns.Add("TransID", typeof(int));
            dtResponse.Columns.Add("ID", typeof(int));
            dtResponse.Columns.Add("FAID", typeof(int));
            dtResponse.Columns.Add("ResponseMessage", typeof(string));
            try
            {                
                if (bulkcollectiondata != null)
                {
                    if (bulkcollectiondata.AdjDocs.Count > 0)
                    {
                        
                        #region Validate Document current state
                        DataTable dtDocs = new DataTable();
                        DataColumn column = new DataColumn("Ident");
                        column.DataType = System.Type.GetType("System.Int32");
                        column.AutoIncrement = true;
                        column.AutoIncrementSeed = 1;
                        column.AutoIncrementStep = 1;
                        dtDocs.Columns.Add(column);
                        dtDocs.Columns.Add("TransID", typeof(int));
                        dtDocs.Columns.Add("ID", typeof(int));
                        dtDocs.Columns.Add("FAID", typeof(int));
                        dtDocs.Columns.Add("Balance", typeof(decimal));
                        for (int i = 0; i < bulkcollectiondata.AdjDocs.Count; i++)
                        {
                            //decimal CashAmt = bl.BL_dValidation(bulkcollectiondata.AdjDocs[i].CashAmt);
                            //decimal ChqBTAmt = bl.BL_dValidation(bulkcollectiondata.AdjDocs[i].ChqBTAmt);
                            DataRow dtRow = dtDocs.NewRow();
                            dtRow["TransID"] = (bulkcollectiondata.AdjDocs[i].TransID);
                            dtRow["ID"] = (bulkcollectiondata.AdjDocs[i].ID);
                            dtRow["FAID"] = (bulkcollectiondata.AdjDocs[i].FAID);
                            dtRow["Balance"] = Math.Abs(bulkcollectiondata.AdjDocs[i].Balance);
                            dtDocs.Rows.Add(dtRow);
                        }
                        bl.bl_Transaction(1);
                        DataTable dtDocResult = bl.bl_ManageTrans("uspBulkCollectionValidateDoc", dtDocs);
                        bl.bl_Transaction(2);
                        if (dtDocResult.Rows.Count > 0)
                        {
                            for (int i = 0; i < dtDocResult.Rows.Count; i++)
                            {
                                DataRow dtRow = dtResponse.NewRow();
                                dtRow["ResponseType"] = "Error";
                                dtRow["ResponseApplyby"] = "1";
                                dtRow["TransID"] = dtDocResult.Rows[i][0];
                                dtRow["ID"] = dtDocResult.Rows[i][1];
                                dtRow["FAID"] = dtDocResult.Rows[i][2];
                                dtRow["ResponseMessage"] = dtDocResult.Rows[i][3];
                                dtResponse.Rows.Add(dtRow);
                            }
                            //list.Add(new
                            //{
                            //    ID = 0.ToString(),
                            //    MsgID = "2",
                            //    Message = "Error in some documents",
                            //    ErrorDocs = dtDocResult
                            //});
                        }
                        #endregion
                        #region Save data
                        dtDenominationPMDetail.Columns.Add("ColDetailDid", typeof(int));
                        dtDenominationPMDetail.Columns.Add("ColDetailDenomination", typeof(int));
                        dtDenominationPMDetail.Columns.Add("ColtotCoupons", typeof(int));
                        dtDenominationPMDetail.Columns.Add("ColDetailCount", typeof(string));
                        dtDenominationPMDetail.Columns.Add("ColDetailAmount", typeof(decimal));
                        bl.BL_AddCollectionData(dtHeader, dtDetail, dtMopDetails);
                        DataTable dtAdjRefId = new DataTable(), dtTVPTable = new DataTable();
                        List<int> uniqueFAIDs = bulkcollectiondata.AdjDocs.Select(x => x.FAID).Distinct().ToList();
                        decimal dBalanceAmt = 0.00M;
                        for (int i = 0; i < uniqueFAIDs.Count; i++)
                        {
                            int FAID = bl.BL_nValidation(uniqueFAIDs[i]);
                            bool existsError = dtDocResult.AsEnumerable().Any(r => r.Field<int>("FAID") == FAID);
                            if (!existsError)
                            {
                                List<BulkCollectionDocs> matchedDocs = bulkcollectiondata.AdjDocs.Where(x => x.FAID == FAID).ToList();
                                if (matchedDocs.Count > 0)
                                {
                                    decimal totalCashAmt = matchedDocs?.Sum(x => x.CashAmt) ?? 0;
                                    decimal totalCqbtAmt = matchedDocs?.Sum(x => x.ChqBTAmt) ?? 0;

                                    List<BulkCollectionDocs> cashdocs = matchedDocs.Where(x => Math.Abs(x.CashAmt) > 0).ToList();
                                    List<BulkCollectionDocs> chqbtdocs = matchedDocs.Where(x => Math.Abs(x.ChqBTAmt) > 0).ToList();
                                    #region Cash Collection Save
                                    if (cashdocs.Count > 0)
                                    {
                                        dtHeader.Rows.Clear(); dtMopDetails.Rows.Clear(); dtDetail.Rows.Clear();
                                        decimal negadjsum= matchedDocs.Where(x => x.CashAmt < 0).Sum(x => x.CashAmt);
                                        decimal posadjsum = matchedDocs.Where(x => x.CashAmt >= 0).Sum(x => x.CashAmt);
                                        decimal negothersum = matchedDocs.Sum(x => x.OtherAmt);
                                        decimal HeaderCollAmt = (posadjsum - Math.Abs(negadjsum)) + Math.Abs(negothersum);
                                        if(HeaderCollAmt < 0)
                                        {
                                            DataRow dtRow = dtResponse.NewRow();
                                            dtRow["ResponseType"] = "Error";
                                            dtRow["ResponseApplyby"] = "2";
                                            dtRow["TransID"] = "0";
                                            dtRow["ID"] = "0";
                                            dtRow["FAID"] = FAID;
                                            dtRow["ResponseMessage"] = "Sum of Adjustment amount should be Greater than 0 (Credit(+) Adj :" + posadjsum + ",Debit(-) Adj :" + negadjsum + ", Diff : -" + HeaderCollAmt + ")";
                                            dtResponse.Rows.Add(dtRow);
                                            continue;
                                        }
                                        decimal totalcashadjamts = cashdocs?.Sum(x => x.TotalAdjusted) ?? 0;
                                        //decimal AdvAmt = (totalCashAmt - totalcashadjamts);
                                        //header
                                        DataRow CustRow = dtHeader.NewRow();
                                        CustRow["Date"] = bulkcollectiondata.DocDate;
                                        CustRow["CoLLPYType"] = 0;
                                        CustRow["AccID"] = FAID;
                                        CustRow["ColAmt"] = HeaderCollAmt;
                                        CustRow["Balance"] = bl.BL_dValidation(0);//AdvAmt
                                        CustRow["DocRefNo"] = "Bulk Collection";
                                        CustRow["ColMode"] = HeaderCollAmt == 0 ? 9 : 1;
                                        CustRow["Status"] = 1;
                                        CustRow["ExAccId"] = 0;
                                        CustRow["UID"] = bulkcollectiondata.UserID;
                                        CustRow["Type"] = 0;
                                        CustRow["SerialNo"] = 1;
                                        CustRow["VisaPern"] = 0;
                                        CustRow["VisaAmt"] = 0;
                                        dtHeader.Rows.Add(CustRow);
                                        //mop
                                        DataRow MopRow = dtMopDetails.NewRow();
                                        MopRow["AccID"] = FAID;
                                        MopRow["Mode"] = HeaderCollAmt > 0 ? 1 : 9;
                                        MopRow["Date"] = bulkcollectiondata.DocDate;
                                        MopRow["Amt"] = HeaderCollAmt;
                                        MopRow["SerialNo"] = 1;
                                        MopRow["RecdAmt"] = bl.BL_dValidation(HeaderCollAmt);
                                        dtMopDetails.Rows.Add(MopRow);
                                        //details
                                        for (int k = 0; k < cashdocs.Count; k++)
                                        {
                                            decimal bal = Math.Abs(bl.BL_dValidation(cashdocs[k].Balance));
                                            DataRow InvRow = dtDetail.NewRow();
                                            InvRow["AccID"] = FAID;
                                            InvRow["DocPrefix"] = (cashdocs[k].TransID);
                                            InvRow["DocValue"] = (cashdocs[k].DocValue);
                                            InvRow["DocID"] = (cashdocs[k].ID);
                                            InvRow["DocDate"] = DateTime.ParseExact(Convert.ToString(cashdocs[k].DocDate), "dd-MMM-yyyy", CultureInfo.InvariantCulture);
                                            InvRow["Balance"] = bal;
                                            InvRow["ColValue"] = Math.Abs(bl.BL_dValidation(cashdocs[k].CashAmt));
                                            InvRow["AdjAmt"] = Math.Abs(bl.BL_dValidation(cashdocs[k].OtherAmt));
                                            InvRow["DiscPer"] = Math.Abs(bl.BL_dValidation(cashdocs[k].DiscPct));
                                            InvRow["DiscAmt"] = Math.Abs(bl.BL_dValidation(cashdocs[k].DiscAmt));
                                            int nFullyAdj = 0;
                                            decimal dWriteOffAmount = 0.00M;
                                            if (nFullyAdj == 0)
                                            {
                                                dWriteOffAmount = bal - Math.Abs(bl.BL_dValidation(cashdocs[k].TotalAdjusted));
                                                dBalanceAmt = bal - Math.Abs(bl.BL_dValidation(cashdocs[k].TotalAdjusted));
                                                if (dBalanceAmt < 0.01M)
                                                {
                                                    nFullyAdj = 1;
                                                    dWriteOffAmount = (dWriteOffAmount > 0.00M && dWriteOffAmount < 0.01M ? dWriteOffAmount : 0.00M);
                                                    dBalanceAmt = dWriteOffAmount;
                                                }
                                                else
                                                {
                                                    dBalanceAmt = 0.00M;
                                                    dWriteOffAmount = 0.00M;
                                                }
                                            }
                                            InvRow["FullyAdj"] = nFullyAdj;
                                            InvRow["FullyAdjAmt"] = (bl.BL_dValidation(cashdocs[k].OtherAmt)) + dWriteOffAmount;
                                            InvRow["TotalAmtAdj"] = Math.Abs(bl.BL_dValidation(cashdocs[k].TotalAdjusted))
                                                                    + dBalanceAmt + dWriteOffAmount;
                                            InvRow["TranType"] = 1;
                                            InvRow["SerialNo"] = 1;
                                            InvRow["ReasonID"] = 0;
                                            dtDetail.Rows.Add(InvRow);
                                        }
                                        
                                        //Cash collection save
                                        bl.bl_Transaction(1);
                                        DataTable dtResult = bl.bl_ManageTrans("uspManageFullColl",
                                               bulkcollectiondata.DocPrefix, 0, dtHeader, dtDetail, dtMopDetails, 0,
                                               cashdocs[0].BeatID, cashdocs[0].SalesmanID, 0,
                                               dtDenominationPMDetail, 1, 0, 1, 0, cashdocs[0].Remarks,
                                               cashdocs[0].Narration, bulkcollectiondata.BranchID);
                                        if (dtResult.Columns.Count == 1)
                                        {
                                            int nScopeInvID = bl.BL_nValidation(dtResult.Rows[0][0].ToString());
                                            bl.bl_Transaction(2);
                                            DataRow dtRow = dtResponse.NewRow();
                                            dtRow["ResponseType"] = "Success";
                                            dtRow["ResponseApplyby"] = "2";
                                            dtRow["TransID"] = "0";
                                            dtRow["ID"] = "0";
                                            dtRow["FAID"] = FAID;
                                            dtRow["ResponseMessage"] = "Saved Successfully";
                                            dtResponse.Rows.Add(dtRow);
                                            //list.Add(new SaveMessage()
                                            //{
                                            //    ID = nScopeInvID.ToString(),
                                            //    MsgID = "0",
                                            //    Message = "Saved Successfully"
                                            //});
                                            //return Ok(list);
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
                                                else if (strErrorList[0].Trim().ToUpper() == "ACC")
                                                {
                                                    ErrMsg = "Account name already deactivated";
                                                }
                                                else if (strErrorList[0].Trim().ToUpper() == "CASH")
                                                {
                                                    ErrMsg = "You don't have enough amount in account";
                                                }
                                                else if (strErrorList[0].Trim().ToUpper() == "BANKACC")
                                                {
                                                    ErrMsg = "Bank Account already deactivated";
                                                }
                                                else if (strErrorList[0].Trim().ToUpper() == "BALANCE")
                                                {
                                                    ErrMsg = "You don't have enough amount in account";
                                                }
                                                else if (strErrorList[0].Trim().ToUpper() == "CHEQUE")
                                                {
                                                    ErrMsg = "Cheque book permission changed";
                                                }
                                                else if (strErrorList[0].Trim().ToUpper() == "CHEQUESTATUS")
                                                {
                                                    ErrMsg = "Cheque book status already changed";
                                                }
                                                else if (strErrorList[0].Trim().ToUpper() == "DOCUMENTSTATUS")
                                                {
                                                    ErrMsg = "This document already processed";
                                                }
                                                else
                                                {
                                                    ErrMsg = strErrorList[0].Trim();
                                                }
                                                DataRow dtRow = dtResponse.NewRow();
                                                dtRow["ResponseType"] = "Error";
                                                dtRow["ResponseApplyby"] = "2";
                                                dtRow["TransID"] = "0";
                                                dtRow["ID"] = "0";
                                                dtRow["FAID"] = FAID;
                                                dtRow["ResponseMessage"] = ErrMsg;
                                                dtResponse.Rows.Add(dtRow);
                                            }
                                            else
                                            {
                                                int nDocPrefix = bl.BL_nValidation(strErrorList[1]);
                                                int nDocIdent = bl.BL_nValidation(strErrorList[2]);
                                                DataRow[] drr = dtDocs.Select("ID = '" + nDocIdent + "'", null);
                                                if (drr.Length > 0)
                                                {
                                                    //string DocID = drr[0]["DocID"].ToString();
                                                    //string DocDate = drr[0]["Tran_Date"].ToString();
                                                    //string TransName = drr[0]["TransName"].ToString();
                                                    //if (strErrorList[0].Trim().ToUpper() == "DOCUMENTAMOUNT")
                                                    //{
                                                    //    ErrMsg = "Document amount was changed (" + DocID + " ," + DocDate + ", " + TransName + ")";
                                                    //}
                                                    //if (strErrorList[0].Trim().ToUpper() == "DOCUMENTSTATUS")
                                                    //{
                                                    //    ErrMsg = "This document already processed (" + DocID + " ," + DocDate + ", " + TransName + ")";
                                                    //}
                                                    //else
                                                    //{
                                                        
                                                    //}
                                                    ErrMsg = strErrorList[0];
                                                    DataRow dtRow = dtResponse.NewRow();
                                                    dtRow["ResponseType"] = "Error";
                                                    dtRow["ResponseApplyby"] = "1";
                                                    dtRow["TransID"] = nDocPrefix;
                                                    dtRow["ID"] = nDocIdent;
                                                    dtRow["FAID"] = FAID;
                                                    dtRow["ResponseMessage"] = ErrMsg;
                                                    dtResponse.Rows.Add(dtRow);
                                                }
                                                if (nDocPrefix == 15 || nDocPrefix == 1 || nDocPrefix == 7)
                                                {
                                                }
                                                else
                                                {
                                                }
                                            }
                                            //list.Add(new SaveMessage()
                                            //{
                                            //    ID = 0.ToString(),
                                            //    MsgID = "1",
                                            //    Message = ErrMsg
                                            //});
                                            //return Ok(list);
                                        }
                                    }
                                    #endregion
                                    #region Cheque/Bank Transfer Collection Save
                                    if (chqbtdocs.Count > 0)
                                    {
                                        dtHeader.Rows.Clear(); dtMopDetails.Rows.Clear(); dtDetail.Rows.Clear();
                                        int nPaymentMode = 2;
                                        decimal negadjsum = matchedDocs.Where(x => x.ChqBTAmt < 0).Sum(x => x.ChqBTAmt);
                                        decimal posadjsum = matchedDocs.Where(x => x.ChqBTAmt >= 0).Sum(x => x.ChqBTAmt);
                                        decimal negothersum = matchedDocs.Sum(x => x.OtherAmt);
                                        decimal HeaderCollAmt = (posadjsum - Math.Abs(negadjsum)) + Math.Abs(negothersum);
                                        if (HeaderCollAmt < 0)
                                        {
                                            DataRow dtRow = dtResponse.NewRow();
                                            dtRow["ResponseType"] = "Error";
                                            dtRow["ResponseApplyby"] = "2";
                                            dtRow["TransID"] = "0";
                                            dtRow["ID"] = "0";
                                            dtRow["FAID"] = FAID;
                                            dtRow["ResponseMessage"] = "Sum of Adjustment amount should be Greater than 0 (Credit Adj :" + posadjsum + ",Debit Adj :" + negadjsum + ", Diff : -" + HeaderCollAmt + ")";
                                            dtResponse.Rows.Add(dtRow);
                                            continue;
                                        }
                                        decimal totalchqbtadjamts = chqbtdocs?.Sum(x => x.TotalAdjusted) ?? 0;
                                        
                                        nPaymentMode = bl.BL_nValidation(chqbtdocs[0].Payments[0].mode);
                                        //header
                                        DataRow CustRow = dtHeader.NewRow();
                                        CustRow["Date"] = bulkcollectiondata.DocDate;
                                        CustRow["CoLLPYType"] = 0;
                                        CustRow["AccID"] = FAID;
                                        CustRow["ColAmt"] = HeaderCollAmt;
                                        CustRow["Balance"] = bl.BL_dValidation(0);
                                        CustRow["DocRefNo"] = "Bulk Collection";
                                        CustRow["ColMode"] = nPaymentMode;
                                        CustRow["Status"] = 1;
                                        CustRow["ExAccId"] = 0;
                                        CustRow["UID"] = bulkcollectiondata.UserID;
                                        CustRow["Type"] = 0;
                                        CustRow["SerialNo"] = 1;
                                        CustRow["VisaPern"] = 0;
                                        CustRow["VisaAmt"] = 0;
                                        dtHeader.Rows.Add(CustRow);

                                        //mop
                                        DataRow MopRow = dtMopDetails.NewRow();
                                        MopRow["AccID"] = FAID;
                                        MopRow["Mode"] = nPaymentMode;

                                        if (nPaymentMode == 2)
                                        {
                                            MopRow["[Cheque/DD Number]"] = chqbtdocs[0].Payments[0].chqNo;// (chqbtdocs[].NEFTNo.Trim());
                                        }
                                        if (nPaymentMode == 4 || nPaymentMode == 5)
                                        {
                                            MopRow["Neft"] = chqbtdocs[0].Payments[0].refNo;// (listTrans.NEFTNo.Trim());
                                        }
                                        if (nPaymentMode == 2)
                                        {
                                            MopRow["Date"] = chqbtdocs[0].Payments[0].chqDate;// listTrans.ChequeDate;
                                        }
                                        else
                                        {
                                            MopRow["Date"] = bulkcollectiondata.DocDate;// listTrans.DocDate;
                                        }
                                        MopRow["BankAccId"] = chqbtdocs[0].Payments[0].bankAcc;//bl.BL_nValidation(listTrans.BankAccID);
                                        MopRow["Amt"] = Math.Abs(bl.BL_dValidation(totalchqbtadjamts));
                                        MopRow["IFSC"] = chqbtdocs[0].Payments[0].ifsc;// (listTrans.IFSC);
                                        MopRow["Bank"] = chqbtdocs[0].Payments[0].bank;// (listTrans.BankName);
                                        MopRow["Branch"] = chqbtdocs[0].Payments[0].branch;//(listTrans.Branch);
                                        MopRow["PayAt"] = null;
                                        MopRow["BankAccNo"] = "";// (listTrans.BankAccNo);
                                        MopRow["ChequeBkRefNo"] = "";
                                        MopRow["ChequeBookID"] = 0;
                                        MopRow["SerialNo"] = 1;
                                        MopRow["RecdAmt"] = bl.BL_dValidation(totalchqbtadjamts);
                                        dtMopDetails.Rows.Add(MopRow);
                                        for (int k = 0; k < chqbtdocs.Count; k++)
                                        {
                                            decimal bal = Math.Abs(bl.BL_dValidation(chqbtdocs[k].Balance));
                                            DataRow InvRow = dtDetail.NewRow();
                                            InvRow["AccID"] = FAID;
                                            InvRow["DocPrefix"] = (chqbtdocs[k].TransID);
                                            InvRow["DocValue"] = (chqbtdocs[k].DocValue);
                                            InvRow["DocID"] = (chqbtdocs[k].ID);
                                            InvRow["DocDate"] = DateTime.ParseExact(Convert.ToString(chqbtdocs[k].DocDate), "dd-MMM-yyyy", CultureInfo.InvariantCulture);
                                            InvRow["Balance"] = bal;
                                            InvRow["ColValue"] = Math.Abs(bl.BL_dValidation(chqbtdocs[k].ChqBTAmt));
                                            InvRow["AdjAmt"] = Math.Abs(bl.BL_dValidation(chqbtdocs[k].OtherAmt));
                                            InvRow["DiscPer"] = Math.Abs(chqbtdocs[k].DiscPct);
                                            InvRow["DiscAmt"] = Math.Abs(bl.BL_dValidation(chqbtdocs[k].DiscAmt));
                                            int nFullyAdj = 0;
                                            decimal dWriteOffAmount = 0.00M;
                                            if (nFullyAdj == 0)
                                            {
                                                dWriteOffAmount = bal - Math.Abs(bl.BL_dValidation(chqbtdocs[k].TotalAdjusted));
                                                dBalanceAmt = bal - Math.Abs(bl.BL_dValidation(chqbtdocs[k].TotalAdjusted));
                                                if (dBalanceAmt < 0.01M)
                                                {
                                                    nFullyAdj = 1;
                                                    dWriteOffAmount = (dWriteOffAmount > 0.00M && dWriteOffAmount < 0.01M ? dWriteOffAmount : 0.00M);
                                                    dBalanceAmt = dWriteOffAmount;
                                                }
                                                else
                                                {
                                                    dBalanceAmt = 0.00M;
                                                    dWriteOffAmount = 0.00M;
                                                }
                                            }
                                            InvRow["FullyAdj"] = nFullyAdj;
                                            InvRow["FullyAdjAmt"] = (bl.BL_dValidation(chqbtdocs[k].OtherAmt)) + dWriteOffAmount;
                                            InvRow["TotalAmtAdj"] = Math.Abs(bl.BL_dValidation(chqbtdocs[k].TotalAdjusted))
                                                                    + dBalanceAmt + dWriteOffAmount;
                                            InvRow["TranType"] = 1;
                                            InvRow["SerialNo"] = 1;
                                            InvRow["ReasonID"] = 0;
                                            dtDetail.Rows.Add(InvRow);
                                        }
                                        
                                        //Cheque/Bank Transfer collection save
                                        bl.bl_Transaction(1);
                                        DataTable dtResult = bl.bl_ManageTrans("uspManageFullColl",
                                               bulkcollectiondata.DocPrefix, 0, dtHeader, dtDetail, dtMopDetails, 0,
                                               chqbtdocs[0].BeatID, chqbtdocs[0].SalesmanID, 0,
                                               dtDenominationPMDetail, 1, 0, 1, 0, chqbtdocs[0].Remarks,
                                               chqbtdocs[0].Narration, bulkcollectiondata.BranchID);
                                        if (dtResult.Columns.Count == 1)
                                        {
                                            int nScopeInvID = bl.BL_nValidation(dtResult.Rows[0][0].ToString());
                                            bl.bl_Transaction(2);
                                            DataRow dtRow = dtResponse.NewRow();
                                            dtRow["ResponseType"] = "Success";
                                            dtRow["ResponseApplyby"] = "2";
                                            dtRow["TransID"] = "0";
                                            dtRow["ID"] = "0";
                                            dtRow["FAID"] = FAID;
                                            dtRow["ResponseMessage"] = "Saved Successfully";
                                            dtResponse.Rows.Add(dtRow);
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
                                                else if (strErrorList[0].Trim().ToUpper() == "ACC")
                                                {
                                                    ErrMsg = "Account name already deactivated";
                                                }
                                                else if (strErrorList[0].Trim().ToUpper() == "CASH")
                                                {
                                                    ErrMsg = "You don't have enough amount in account";
                                                }
                                                else if (strErrorList[0].Trim().ToUpper() == "BANKACC")
                                                {
                                                    ErrMsg = "Bank Account already deactivated";
                                                }
                                                else if (strErrorList[0].Trim().ToUpper() == "BALANCE")
                                                {
                                                    ErrMsg = "You don't have enough amount in account";
                                                }
                                                else if (strErrorList[0].Trim().ToUpper() == "CHEQUE")
                                                {
                                                    ErrMsg = "Cheque book permission changed";
                                                }
                                                else if (strErrorList[0].Trim().ToUpper() == "CHEQUESTATUS")
                                                {
                                                    ErrMsg = "Cheque book status already changed";
                                                }
                                                else if (strErrorList[0].Trim().ToUpper() == "DOCUMENTSTATUS")
                                                {
                                                    ErrMsg = "This document already processed";
                                                }
                                                else
                                                {
                                                    ErrMsg = strErrorList[0].Trim();
                                                }
                                                DataRow dtRow = dtResponse.NewRow();
                                                dtRow["ResponseType"] = "Error";
                                                dtRow["ResponseApplyby"] = "2";
                                                dtRow["TransID"] = "0";
                                                dtRow["ID"] = "0";
                                                dtRow["FAID"] = FAID;
                                                dtRow["ResponseMessage"] = ErrMsg;
                                                dtResponse.Rows.Add(dtRow);
                                            }
                                            else
                                            {
                                                int nDocPrefix = bl.BL_nValidation(strErrorList[1]);
                                                int nDocIdent = bl.BL_nValidation(strErrorList[2]);
                                                DataRow[] drr = dtDocs.Select("ID = '" + nDocIdent + "'", null);
                                                if (drr.Length > 0)
                                                {
                                                    //string DocID = drr[0]["DocID"].ToString();
                                                    //string DocDate = drr[0]["Tran_Date"].ToString();
                                                    //string TransName = drr[0]["TransName"].ToString();
                                                    //if (strErrorList[0].Trim().ToUpper() == "DOCUMENTAMOUNT")
                                                    //{
                                                    //    ErrMsg = "Document amount was changed (" + DocID + " ," + DocDate + ", " + TransName + ")";
                                                    //}
                                                    //if (strErrorList[0].Trim().ToUpper() == "DOCUMENTSTATUS")
                                                    //{
                                                    //    ErrMsg = "This document already processed (" + DocID + " ," + DocDate + ", " + TransName + ")";
                                                    //}
                                                    //else
                                                    //{
                                                        
                                                    //}
                                                    ErrMsg = strErrorList[0];
                                                    DataRow dtRow = dtResponse.NewRow();
                                                    dtRow["ResponseType"] = "Error";
                                                    dtRow["ResponseApplyby"] = "1";
                                                    dtRow["TransID"] = nDocPrefix;
                                                    dtRow["ID"] = nDocIdent;
                                                    dtRow["FAID"] = FAID;
                                                    dtRow["ResponseMessage"] = ErrMsg;
                                                    dtResponse.Rows.Add(dtRow);
                                                }
                                                
                                            }                                            
                                        }
                                    }
                                    #endregion
                                }
                            }
                        }                        
                        #endregion
                        //return Ok();
                    }
                    else
                    {
                        DataRow dtRow = dtResponse.NewRow();
                        dtRow["ResponseType"] = "Error";
                        dtRow["ResponseApplyby"] = "3";
                        dtRow["TransID"] = "0";
                        dtRow["ID"] = "0";
                        dtRow["FAID"] = "0";
                        dtRow["ResponseMessage"] = "Adjust atleast one document";
                        dtResponse.Rows.Add(dtRow);
                    }
                }
                else
                {
                    DataRow dtRow = dtResponse.NewRow();
                    dtRow["ResponseType"] = "Error";
                    dtRow["ResponseApplyby"] = "3";
                    dtRow["TransID"] = "0";
                    dtRow["ID"] = "0";
                    dtRow["FAID"] = "0";
                    dtRow["ResponseMessage"] = "Payload not found";
                    dtResponse.Rows.Add(dtRow);                    
                }
            }
            catch (Exception ex)
            {
                DataRow dtRow = dtResponse.NewRow();
                dtRow["ResponseType"] = "Error";
                dtRow["ResponseApplyby"] = "3";
                dtRow["TransID"] = "0";
                dtRow["ID"] = "0";
                dtRow["FAID"] = "0";
                dtRow["ResponseMessage"] = ex.Message;
                dtResponse.Rows.Add(dtRow);
                bl.BL_WriteErrorMsginLog("Bulk Collection", "save", ex.Message);
            }
            bool Allsuccess = dtResponse.Select("ResponseType = 'Error'", null).Length == 0;
            return Ok(new {
                Success = Allsuccess,
                Response = dtResponse
            });
        }
    }
    public class BulkCollectionModel
    {
        public int? BranchID { get; set; }
        public string DocDate { get; set; }
        public string DocPrefix { get; set; }
        public string UserID { get; set; }
        public List<BulkCollectionDocs> AdjDocs { get; set; }
    }
    public class BulkCollectionDocs
    {
        public int TransID { get; set; }

        public int ID { get; set; }

        public int FAID { get; set; }

        public int BeatID { get; set; }

        public int SalesmanID { get; set; }
        public string DocValue { get; set; }
        public string DocDate { get; set; }
        public decimal Balance { get; set; }

        public decimal CashAmt { get; set; }

        public decimal ChqBTAmt { get; set; }

        public decimal DiscPct { get; set; }

        public decimal DiscAmt { get; set; }

        public decimal OtherPct { get; set; }

        public decimal OtherAmt { get; set; }

        public decimal TotalAdjusted { get; set; }

        public List<Payment> Payments { get; set; }

        public string Remarks { get; set; } = string.Empty;

        public string Narration { get; set; } = string.Empty;
    }

    public class Payment
    {
        public string mode { get; set; } = string.Empty;

        public decimal amount { get; set; }

        public string displaypmmode { get; set; } = string.Empty;

        public string chqNo { get; set; } = string.Empty;

        public string chqDate { get; set; } = string.Empty;

        public string bank { get; set; } = string.Empty;

        public string branch { get; set; } = string.Empty;

        public string ifsc { get; set; } = string.Empty;

        public string bankAcc { get; set; } = string.Empty;

        public string refNo { get; set; } = string.Empty;

        public string transferMode { get; set; } = string.Empty;
    }
}
