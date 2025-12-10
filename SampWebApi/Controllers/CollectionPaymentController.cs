using Microsoft.Extensions.Logging;
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
using System.Web.Http.Cors;
using System.Web.UI;
using System.Windows.Forms;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class CollectionPaymentController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        public DataTable dtDenominationPMDetail = new DataTable();
        DataTable dtMopDetails = new DataTable("MOP"), dtDetail = new DataTable("CollectionDetail"), dtHeader = new DataTable("CollectionHeader");
        [HttpGet]
        [Route("api/collectionpayment/get")]
        public IHttpActionResult GetData(string Mode, string DocPrefix, string CodeName, string ID = null, string BranchID = "0", string Date = "")
        {
            DataTable DDT = new DataTable();
            if (Mode == "1" || Mode == "5")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetCollPayData", Mode, ID,CodeName,  DocPrefix);
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
            if (Mode == "2")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetCollPayData", Mode, CodeName, 0, DocPrefix);
                List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    string CloseBal = "0.00", crdrType = "Cr";
                    DataTable DTCloseBal = bl.BL_ExecuteParamSP("uspLoadClosingBalance", 1, DDT.Rows[i]["FAID"].ToString());
                    if (DTCloseBal.Rows.Count > 0)
                    {
                        CloseBal = DTCloseBal.Rows[0][0].ToString();
                        crdrType = DTCloseBal.Rows[0][1].ToString();
                    }
                    string strBeatID = "0", strSalesmanID = "0";

                    DataTable dtBSM = bl.BL_ExecuteParamSP("uspGetSetCollPayData", 32, DDT.Rows[i]["ID"].ToString(), null, DocPrefix);
                    if (dtBSM.Rows.Count > 0)
                    {
                        strBeatID = dtBSM.Rows[0]["BeatID"].ToString();
                        strSalesmanID = dtBSM.Rows[0]["SalesmanID"].ToString();
                    }
                    
                    list.Add(new CustomerVendorModel
                    {
                        ID = DDT.Rows[i]["ID"].ToString(),
                        Code = DDT.Rows[i]["Code"].ToString(),
                        Name = DDT.Rows[i]["Name"].ToString(),
                        Billadd1 = DDT.Rows[i]["Billadd1"].ToString(),
                        Billadd2 = DDT.Rows[i]["Billadd2"].ToString(),
                        Billadd3 = DDT.Rows[i]["Billadd3"].ToString(),
                        Shipadd1 = DDT.Rows[i]["Shipadd1"].ToString(),
                        shipadd2 = DDT.Rows[i]["shipadd2"].ToString(),
                        Shipadd3 = DDT.Rows[i]["Shipadd3"].ToString(),
                        Pincode = DDT.Rows[i]["Pincode"].ToString(),
                        ContactPerson = DDT.Rows[i]["ContactPerson"].ToString(),
                        Ph1 = DDT.Rows[i]["Ph1"].ToString(),
                        Ph2 = DDT.Rows[i]["Ph2"].ToString(),
                        Mob1 = DDT.Rows[i]["Mob1"].ToString(),
                        Mob2 = DDT.Rows[i]["Mob2"].ToString(),
                        Email = DDT.Rows[i]["Email"].ToString(),
                        PANNumber = DDT.Rows[i]["PANNumber"].ToString(),
                        AadharNo = DDT.Rows[i]["AadharNo"].ToString(),
                        DLNo20 = DDT.Rows[i]["DLNo20"].ToString(),
                        DLNo21 = DDT.Rows[i]["DLNo21"].ToString(),
                        FSSAINo = DDT.Rows[i]["FSSAINo"].ToString(),
                        StateID = DDT.Rows[i]["StateID"].ToString(),
                        GSTIN = DDT.Rows[i]["GSTIN"].ToString(),
                        CreditTermID = DDT.Rows[i]["CreditTermID"].ToString(),
                        PaymentModeID = DDT.Rows[i]["PaymentModeID"].ToString(),
                        FAID = DDT.Rows[i]["FAID"].ToString(),
                        Active = DDT.Rows[i]["Active"].ToString(),
                        Ratings = DDT.Rows[i]["Rating"].ToString(),
                        OSValue = CloseBal,
                        CreditlimitOS = crdrType,
                        BeatID = strBeatID,
                        SalesmanID = strSalesmanID
                    });
                }
                return Ok(list);
            }
            if (Mode == "3")
            {
                List<CustomerVendorModel> listParty = new List<CustomerVendorModel>();
                List<CollectionPaymentModel> listCollPay = new List<CollectionPaymentModel>();
                List<CollPayDetails> listCollPayDetails = new List<CollPayDetails>();

                DataTable dtFHeader = bl.BL_ExecuteParamSP("uspLoadCollPaymentDetail", DocPrefix, ID, "Header");
                DataTable dtFFooter = bl.BL_ExecuteParamSP("uspLoadCollPaymentDetail", DocPrefix, ID, "Detail");
                DataTable dtFMOP = bl.BL_ExecuteParamSP("uspLoadCollPaymentDetail", DocPrefix, ID, "Mop");

                if (dtFHeader.Rows.Count > 0)
                {
                    DataTable DDTParty = bl.BL_ExecuteParamSP("uspGetSetCollPayData", 3, dtFHeader.Rows[0]["PartyID"].ToString(), 0, DocPrefix);
                    if (DDTParty.Rows.Count > 0)
                    {
                        for (int i = 0; i < DDTParty.Rows.Count; i++)
                        {
                            string CloseBal = "0.00", crdrType = "Cr";
                            DataTable DTCloseBal = bl.BL_ExecuteParamSP("uspLoadClosingBalance", 1, DDTParty.Rows[0]["FAID"].ToString());
                            if (DTCloseBal.Rows.Count > 0)
                            {
                                CloseBal = DTCloseBal.Rows[0][0].ToString();
                                crdrType = DTCloseBal.Rows[0][1].ToString();
                            }
                            listParty.Add(new CustomerVendorModel
                            {
                                ID = DDTParty.Rows[0]["ID"].ToString(),
                                Code = DDTParty.Rows[0]["Code"].ToString(),
                                Name = DDTParty.Rows[0]["Name"].ToString(),
                                Billadd1 = DDTParty.Rows[0]["Billadd1"].ToString(),
                                Billadd2 = DDTParty.Rows[0]["Billadd2"].ToString(),
                                Billadd3 = DDTParty.Rows[0]["Billadd3"].ToString(),
                                Shipadd1 = DDTParty.Rows[0]["Shipadd1"].ToString(),
                                shipadd2 = DDTParty.Rows[0]["shipadd2"].ToString(),
                                Shipadd3 = DDTParty.Rows[0]["Shipadd3"].ToString(),
                                Pincode = DDTParty.Rows[0]["Pincode"].ToString(),
                                ContactPerson = DDTParty.Rows[0]["ContactPerson"].ToString(),
                                Ph1 = DDTParty.Rows[0]["Ph1"].ToString(),
                                Ph2 = DDTParty.Rows[0]["Ph2"].ToString(),
                                Mob1 = DDTParty.Rows[0]["Mob1"].ToString(),
                                Mob2 = DDTParty.Rows[0]["Mob2"].ToString(),
                                Email = DDTParty.Rows[0]["Email"].ToString(),
                                PANNumber = DDTParty.Rows[0]["PANNumber"].ToString(),
                                AadharNo = DDTParty.Rows[0]["AadharNo"].ToString(),
                                DLNo20 = DDTParty.Rows[0]["DLNo20"].ToString(),
                                DLNo21 = DDTParty.Rows[0]["DLNo21"].ToString(),
                                FSSAINo = DDTParty.Rows[0]["FSSAINo"].ToString(),
                                StateID = DDTParty.Rows[0]["StateID"].ToString(),
                                GSTIN = DDTParty.Rows[0]["GSTIN"].ToString(),
                                CreditTermID = DDTParty.Rows[0]["CreditTermID"].ToString(),
                                PaymentModeID = DDTParty.Rows[0]["PaymentModeID"].ToString(),
                                FAID = DDTParty.Rows[0]["FAID"].ToString(),
                                Active = DDTParty.Rows[0]["Active"].ToString(),
                                Ratings = DDTParty.Rows[0]["Rating"].ToString(),
                                OSValue = CloseBal,
                                CreditlimitOS = crdrType
                            });
                        }
                    }

                    string StrNEFTNo = "", StrBankAccID = "", StrBankAccNo = "", StrChequeID = "", StrChequeNo = "",
                                StrChequeDate = "", StrIFSC = "", StrBankID = "", StrBankName = "", StrBranch = "";
                    if (dtFMOP.Rows.Count > 0)
                    {
                        StrNEFTNo = dtFMOP.Rows[0]["NeftID"].ToString();
                        StrBankAccID = dtFMOP.Rows[0]["ID"].ToString();
                        StrBankAccNo = dtFMOP.Rows[0]["AccountNo"].ToString();
                        StrChequeID = dtFMOP.Rows[0]["ChequeDDNumber"].ToString();
                        StrChequeNo = dtFMOP.Rows[0]["ChequeDDNumber"].ToString();
                        StrChequeDate = Convert.ToDateTime(dtFMOP.Rows[0]["Date"].ToString()).ToString("yyyy-MM-dd");
                        StrNEFTNo = dtFMOP.Rows[0]["NeftID"].ToString();
                        StrIFSC = dtFMOP.Rows[0]["IFSC"].ToString();
                        StrBankID = dtFMOP.Rows[0]["BankID"].ToString();
                        StrBankName = dtFMOP.Rows[0]["BankName"].ToString();
                        StrBranch = dtFMOP.Rows[0]["BranchName"].ToString();
                    }

                    if (dtFFooter.Rows.Count > 0)
                    {
                        for (int i = 0; i < dtFFooter.Rows.Count; i++)
                        {
                            string strDocPrefix = dtFFooter.Rows[i]["DocPrefix"].ToString();
                            string TypeID = strDocPrefix == "16" || strDocPrefix == "19" || strDocPrefix == "18" || strDocPrefix == "12" ||
                                (strDocPrefix == "18" && strDocPrefix == "5") || (strDocPrefix == "19" && strDocPrefix == "4") ? "1" : "2";

                            listCollPayDetails.Add(new CollPayDetails
                            {
                                TypeID = TypeID,
                                DocID = dtFFooter.Rows[i]["DocID"].ToString(),
                                Tran_Date = dtFFooter.Rows[i]["DocDate"].ToString(),
                                DocRef = dtFFooter.Rows[i]["RefNo"].ToString(),
                                TransName = dtFFooter.Rows[i]["TransName"].ToString(),
                                NetAmt = dtFFooter.Rows[i]["DocumentAmount"].ToString(),
                                Balance = "0",
                                CollAmt = dtFFooter.Rows[i]["NetAmount"].ToString(),
                                ID = dtFFooter.Rows[i]["DocID"].ToString(),
                                FAID = dtFHeader.Rows[0]["AccID"].ToString(),
                                DocPrefix = strDocPrefix,
                                DocValue = dtFFooter.Rows[i]["DocID"].ToString(),
                                UDFDocId = dtFFooter.Rows[i]["UDFDocId"].ToString(),
                                AdjAmt = dtFFooter.Rows[i]["AdjAmt"].ToString(),
                                DiscPern = dtFFooter.Rows[i]["DiscPern"].ToString(),
                                DiscAmt = dtFFooter.Rows[i]["DiscAmt"].ToString(),
                                FullAdjYN = dtFFooter.Rows[i]["FullyAdj"].ToString(),
                                TotalAdjAmt = dtFFooter.Rows[i]["TotalAmtAdj"].ToString(),
                            });
                        }
                    }
                    listCollPay.Add(new CollectionPaymentModel
                    {
                        ID = dtFHeader.Rows[0]["ID"].ToString(),
                        DocId = dtFHeader.Rows[0]["DocId"].ToString(),
                        DocDate = Convert.ToDateTime(dtFHeader.Rows[0]["DocDate"].ToString()).ToString("yyyy-MM-dd"),
                        CustomerID = dtFHeader.Rows[0]["PartyID"].ToString(),
                        BeatID = dtFHeader.Rows[0]["BeatID"].ToString(),
                        SalesmanID = dtFHeader.Rows[0]["SalesmanID"].ToString(),
                        RefNo = dtFHeader.Rows[0]["RefNo"].ToString(),
                        PaymentModeID = dtFHeader.Rows[0]["PaymentModeID"].ToString(),
                        CollAmt = dtFHeader.Rows[0]["RecdAmt"].ToString(),
                        Status = dtFHeader.Rows[0]["Status"].ToString(),
                        CurrentStatus = dtFHeader.Rows[0]["Status"].ToString(),
                        UDFId = dtFHeader.Rows[0]["UDFId"].ToString(),
                        Remarks = dtFHeader.Rows[0]["Remarks"].ToString(),
                        Narration = dtFHeader.Rows[0]["Narration"].ToString(),
                        VisaPern = dtFHeader.Rows[0]["VisaPern"].ToString(),
                        VisaAmt = dtFHeader.Rows[0]["VisaAmt"].ToString(),
                        NEFTNo = StrNEFTNo,
                        BankAccID = StrBankAccID,
                        BankAccNo = StrBankAccNo,
                        ChequeID = StrChequeID,
                        ChequeNo = StrChequeNo,
                        ChequeDate = StrChequeDate,
                        IFSC = StrIFSC,
                        BankID = StrBankID,
                        BankName = StrBankName,
                        Branch = StrBranch,
                        lstvPartyDtl = listParty,
                        lstCollPayDtl = listCollPayDetails
                    });
                }
                return Ok(listCollPay);
            }
            if (Mode == "33")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetCollPayData", Mode, CodeName, ID, DocPrefix);
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
            if(Mode == "6")
            {
                List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                DDT = bl.BL_ExecuteParamSP("uspGetSetCollPayData", Mode, CodeName, ID, DocPrefix);
                if (DDT.Rows.Count > 0)
                {
                    list.Add(new CustomerVendorModel
                    {
                        ID = DDT.Rows[0]["PartyID"].ToString(),
                        Code = DDT.Rows[0]["Code"].ToString(),
                        Name = DDT.Rows[0]["Name"].ToString(),
                    });
                }
                return Ok(list);
            }
            if (Mode == "7")
            {
                List<PaymentmodeInfo> list = new List<PaymentmodeInfo>();
                DataTable dtPartyBank = bl.BL_ExecuteParamSP("uspGetSetCollPayData", Mode, null, ID, DocPrefix);
                if (dtPartyBank.Rows.Count > 0)
                {
                    for (int i = 0; i < dtPartyBank.Rows.Count; i++)
                    {
                        list.Add(new PaymentmodeInfo
                        {
                            Bank = dtPartyBank.Rows[i]["BankName"].ToString(),
                            Branch = dtPartyBank.Rows[i]["BranchName"].ToString(),
                            IFSC = dtPartyBank.Rows[i]["IfscCode"].ToString(),
                        });
                    }                   
                }                
                return Ok(list);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/collectionpayment/getosdocs")]
        public IHttpActionResult getosdocs(string Mode, string DocPrefix, string PartyID = null, string BranchID = "0", string Date = "", string TransID = "0")
        {
            List<CollPayDetails> list = new List<CollPayDetails>();
            string strExPayable = string.Empty;
            string strExReceivable = string.Empty;
            if (DocPrefix == "19")
            {
                strExPayable = "Voucher = 'Payable'";
                strExReceivable = "Voucher = 'Receivable'";
            }
            else if (DocPrefix == "18")
            {
                strExPayable = "Voucher = 'Receivable'";
                strExReceivable = "Voucher = 'Payable'";
            }
            DataTable DDT = new DataTable();
            if (DocPrefix == "19")
                DDT = bl.BL_ExecuteParamSP("uspGetAdjusmentDoc", PartyID, Convert.ToDateTime(Date), TransID, Mode);
            else
                DDT = bl.BL_ExecuteParamSP("uspGetAdjusmentDocForPY", PartyID, Convert.ToDateTime(Date), TransID, Mode);

            if (DDT.Rows.Count > 0)
            {                
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    //"DocId	DocDate	NoteValue	Ident	DocPrefix	DocValue	PartyId	Balance	TransName	DocRefNo	UDFDocId"                   
                    list.Add(new CollPayDetails
                    {
                        TypeID = "1",
                        DocID = DDT.Rows[i]["DocId"].ToString(),
                        Tran_Date = DDT.Rows[i]["DocDate"].ToString(),
                        DocRef = DDT.Rows[i]["DocRefNo"].ToString(),
                        TransName = DDT.Rows[i]["TransName"].ToString(),
                        NetAmt = DDT.Rows[i]["NoteValue"].ToString(),
                        Balance = DDT.Rows[i]["Balance"].ToString(),
                        ID = DDT.Rows[i]["Ident"].ToString(),
                        FAID = DDT.Rows[i]["PartyId"].ToString(),
                        DocPrefix = DDT.Rows[i]["DocPrefix"].ToString(),
                        DocValue = DDT.Rows[i]["DocValue"].ToString(),
                        UDFDocId = DDT.Rows[i]["UDFDocId"].ToString(),
                    });
                }
                DataTable dtOCOP = bl.BL_ExecuteParamSP("uspGetAccDetailsForOtherColl", DDT.Rows[0]["PartyId"].ToString(), Date);
                DataRow[] dtTopGridRows = dtOCOP.Select(strExPayable);
                for (int i = 0; i < dtTopGridRows.Length; i++)
                {
                    list.Add(new CollPayDetails
                    {
                        TypeID = "1",
                        DocID = dtTopGridRows[i]["DocID"].ToString(),
                        Tran_Date = dtTopGridRows[i]["DocDate"].ToString(),
                        DocRef = dtTopGridRows[i]["RefNo"].ToString(),
                        TransName = dtTopGridRows[i]["TransName"].ToString(),
                        NetAmt = dtTopGridRows[i]["NetAmount"].ToString(),
                        Balance = dtTopGridRows[i]["Balance"].ToString(),
                        ID = dtTopGridRows[i]["ID"].ToString(),
                        FAID = dtTopGridRows[i]["PartyID"].ToString(),
                        DocPrefix = dtTopGridRows[i]["TransID"].ToString(),
                        DocValue = dtTopGridRows[i]["DocValue"].ToString(),
                        UDFDocId = dtTopGridRows[i]["UDFDocId"].ToString(),
                    });
                }
            }
            if (DocPrefix == "19")
                DDT = bl.BL_ExecuteParamSP("uspGetPendingInv", PartyID, Convert.ToDateTime(Date), TransID, Mode);
            else
                DDT = bl.BL_ExecuteParamSP("uspGetPendingBill", PartyID, Convert.ToDateTime(Date), TransID, Mode);

            if (DDT.Rows.Count > 0)
            {                
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new CollPayDetails
                    {
                        TypeID = "2",
                        DocID = DDT.Rows[i]["DocID"].ToString(),
                        Tran_Date = DDT.Rows[i]["Tran_Date"].ToString(),
                        DocRef = DDT.Rows[i]["DocRef"].ToString(),
                        TransName = DDT.Rows[i]["TransName"].ToString(),
                        NetAmt = DDT.Rows[i]["NetAmt"].ToString(),
                        Balance = DDT.Rows[i]["Balance"].ToString(),
                        ID = DDT.Rows[i]["ID"].ToString(),
                        FAID = DDT.Rows[i]["FAID"].ToString(),
                        DocPrefix = DDT.Rows[i]["DocPrefix"].ToString(),
                        DocValue = DDT.Rows[i]["DocValue"].ToString(),
                        UDFDocId = DDT.Rows[i]["UDFDocId"].ToString(),

                    });
                }
                DataTable dtOCOP = bl.BL_ExecuteParamSP("uspGetAccDetailsForOtherColl", DDT.Rows[0]["FAID"].ToString(), Date);
                DataRow[] dtTopGridRows = dtOCOP.Select(strExReceivable);
                for (int i = 0; i < dtTopGridRows.Length; i++)
                {
                    list.Add(new CollPayDetails
                    {
                        TypeID = "2",
                        DocID = dtTopGridRows[i]["DocID"].ToString(),
                        Tran_Date = dtTopGridRows[i]["DocDate"].ToString(),
                        DocRef = dtTopGridRows[i]["RefNo"].ToString(),
                        TransName = dtTopGridRows[i]["TransName"].ToString(),
                        NetAmt = dtTopGridRows[i]["NetAmount"].ToString(),
                        Balance = dtTopGridRows[i]["Balance"].ToString(),
                        ID = dtTopGridRows[i]["ID"].ToString(),
                        FAID = dtTopGridRows[i]["PartyID"].ToString(),
                        DocPrefix = dtTopGridRows[i]["TransID"].ToString(),
                        DocValue = dtTopGridRows[i]["DocValue"].ToString(),
                        UDFDocId = dtTopGridRows[i]["UDFDocId"].ToString(),
                    });
                }
            }
            return Ok(list);
        }
        [HttpGet]
        [Route("api/collectionpayment/getfilterdata")]
        public IHttpActionResult GetFilterData(string Mode, string TransID, string Party, string FromDate, string ToDate, string Showall)
        {
            DataTable DDT = bl.BL_ExecuteParamSP("uspFilterCollectionPayment", Mode, TransID, Party, FromDate, ToDate, Showall);
            List<CollectionPaymentModel> list = new List<CollectionPaymentModel>();
            for (int i = 0; i < DDT.Rows.Count; i++)
            {
                list.Add(new CollectionPaymentModel
                {
                    ID = DDT.Rows[i]["ID"].ToString(),
                    DocId = DDT.Rows[i]["DocID"].ToString(),
                    DocDate = DDT.Rows[i]["DocDate"].ToString(),
                    RefNo = DDT.Rows[i]["RefNo"].ToString(),
                    PartyName = DDT.Rows[i]["Name"].ToString(),
                    CollAmt = DDT.Rows[i]["Amount"].ToString(),
                    Balance = DDT.Rows[i]["Balance"].ToString(),                    
                    Status = DDT.Rows[i]["Status"].ToString(),
                    StatusID = DDT.Rows[i]["StatusID"].ToString(),
                    PaymentModeID = DDT.Rows[i]["PaymentMode"].ToString(),
                    UDFDocId = DDT.Rows[i]["UDN"].ToString(),
                    CBy = DDT.Rows[i]["UserName"].ToString(),
                    CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                });
            }
            return Ok(list);
        }
        [HttpPost]
        [Route("api/collectionpayment/save")]
        public IHttpActionResult SaveCP(CollectionPaymentModel listTrans)
        {
            if (listTrans != null)
            {
                List<SaveMessage> list = new List<SaveMessage>();
                if (listTrans.TransMode != "4")
                {
                    dtDenominationPMDetail.Columns.Add("ColDetailDid", typeof(int));
                    dtDenominationPMDetail.Columns.Add("ColDetailDenomination", typeof(int));
                    dtDenominationPMDetail.Columns.Add("ColtotCoupons", typeof(int));
                    dtDenominationPMDetail.Columns.Add("ColDetailCount", typeof(string));
                    dtDenominationPMDetail.Columns.Add("ColDetailAmount", typeof(decimal));
                    bl.BL_AddCollectionData(dtHeader, dtDetail, dtMopDetails);
                    DataTable dtAdjRefId = new DataTable(), dtTVPTable = new DataTable();
                    DataTable dtAcc = bl.BL_ExecuteParamSP("uspGetSetCollPayData", 3, listTrans.CustomerID, 0, listTrans.TransID);
                    int AccID = dtAcc.Rows.Count > 0 ? bl.BL_nValidation(dtAcc.Rows[0]["FAID"].ToString()) : 0;
                    int nPaymentMode = bl.BL_nValidation(listTrans.PaymentModeID);
                    DataRow CustRow = dtHeader.NewRow();
                    CustRow["Date"] = listTrans.DocDate;
                    CustRow["CoLLPYType"] = 0;
                    CustRow["AccID"] = AccID;
                    CustRow["ColAmt"] = listTrans.CollAmt;
                    CustRow["Balance"] = bl.BL_dValidation(listTrans.AdvanceAmount);
                    CustRow["DocRefNo"] = listTrans.RefNo;
                    CustRow["ColMode"] = nPaymentMode;
                    CustRow["Status"] = 1;
                    CustRow["ExAccId"] = 0;
                    CustRow["UID"] = listTrans.UserID;
                    CustRow["Type"] = 0;
                    CustRow["SerialNo"] = 1;
                    CustRow["VisaPern"] = bl.BL_dValidation(listTrans.VisaPern);
                    CustRow["VisaAmt"] = bl.BL_dValidation(listTrans.VisaAmt);
                    dtHeader.Rows.Add(CustRow);
                    dtMopDetails.Rows.Clear();

                    DataRow MopRow = dtMopDetails.NewRow();
                    MopRow["AccID"] = AccID;
                    if (listTrans.TransID == "19")//collection
                    {

                        MopRow["Mode"] = nPaymentMode;

                        if (nPaymentMode == 2 || nPaymentMode == 3)
                        {
                            MopRow["[Cheque/DD Number]"] = (listTrans.NEFTNo.Trim());
                        }
                        if (nPaymentMode == 4 || nPaymentMode == 5)
                        {
                            MopRow["Neft"] = (listTrans.NEFTNo.Trim());
                        }
                        if (nPaymentMode == 2 || nPaymentMode == 3 || nPaymentMode == 4)
                        {
                            MopRow["Date"] = listTrans.ChequeDate;
                        }
                        else
                        {
                            MopRow["Date"] = listTrans.DocDate;
                        }
                        MopRow["BankAccId"] = bl.BL_nValidation(listTrans.BankAccID);
                        MopRow["Amt"] = bl.BL_dValidation(listTrans.CollAmt);
                        MopRow["IFSC"] = (listTrans.IFSC);
                        MopRow["Bank"] = (listTrans.BankName);
                        MopRow["Branch"] = (listTrans.Branch);
                        MopRow["PayAt"] = null;
                        MopRow["BankAccNo"] = (listTrans.BankAccNo);
                        MopRow["ChequeBkRefNo"] = "";
                        MopRow["ChequeBookID"] = 0;
                    }
                    else if (listTrans.TransID == "18")//payment
                    {
                        MopRow["Mode"] = nPaymentMode;
                        if (nPaymentMode == 2)
                        {
                            MopRow["[Cheque/DD Number]"] = listTrans.ChequeID;
                        }
                        if (nPaymentMode == 3)
                        {
                            MopRow["[Cheque/DD Number]"] = (listTrans.ChequeNo.Trim());
                        }
                        if (nPaymentMode == 4 || nPaymentMode == 5)
                        {
                            MopRow["Neft"] = (listTrans.NEFTNo.Trim());
                        }
                        if (nPaymentMode == 2 || nPaymentMode == 3 || nPaymentMode == 4)
                        {
                            MopRow["Date"] = listTrans.ChequeDate;
                        }
                        else
                        {
                            MopRow["Date"] = listTrans.DocDate;
                        }
                        MopRow["BankAccId"] = bl.BL_nValidation(listTrans.BankAccID);
                        MopRow["Amt"] = bl.BL_dValidation(listTrans.CollAmt);
                        MopRow["IFSC"] = (listTrans.IFSC);
                        MopRow["Bank"] = (listTrans.BankName);
                        MopRow["Branch"] = (listTrans.Branch);
                        MopRow["PayAt"] = null;
                        MopRow["BankAccNo"] = (listTrans.BankAccNo);
                        if (nPaymentMode == 2)
                        {
                            MopRow["ChequeBkRefNo"] = listTrans.ChequeNo;
                        }
                        MopRow["ChequeBookID"] = 0;
                    }
                    MopRow["SerialNo"] = 1;
                    MopRow["RecdAmt"] = bl.BL_dValidation(listTrans.CollAmt);
                    dtMopDetails.Rows.Add(MopRow);
                    decimal dBalanceAmt = 0.00M;
                    DataTable dtDocs = bl.ConvertListToDataTable(listTrans.lstCollPayDtl);
                    for (int i = 0; i < dtDocs.Rows.Count; i++)
                    {
                        int DocTypePorR = bl.BL_nValidation(dtDocs.Rows[i][0].ToString());
                        if (DocTypePorR == 1)
                        {//grid 1

                            DataRow InvRow = dtDetail.NewRow();
                            InvRow["AccID"] = bl.BL_nValidation(dtDocs.Rows[i]["FAID"]);
                            InvRow["DocPrefix"] = bl.BL_nValidation(dtDocs.Rows[i]["DocPrefix"]);
                            InvRow["DocValue"] = bl.BL_nValidation(dtDocs.Rows[i]["DocValue"]);
                            InvRow["DocID"] = bl.BL_nValidation(dtDocs.Rows[i]["ID"]);
                            InvRow["DocDate"] = DateTime.ParseExact(Convert.ToString(dtDocs.Rows[i]["Tran_Date"]), "dd/MM/yyyy", CultureInfo.InvariantCulture);
                            InvRow["Balance"] = bl.BL_dValidation(Convert.ToString(dtDocs.Rows[i]["Balance"]));
                            InvRow["ColValue"] = bl.BL_dValidation(Convert.ToString(dtDocs.Rows[i]["CollAmt"]));//"NetAmt"
                            InvRow["AdjAmt"] = 0.00M;
                            InvRow["DiscPer"] = "0";
                            InvRow["DiscAmt"] = 0.00M;
                            InvRow["FullyAdj"] = 0;
                            InvRow["FullyAdjAmt"] = 0.00M;
                            dBalanceAmt = bl.BL_dValidation(Convert.ToString(dtDocs.Rows[i]["Balance"]))
                                            - bl.BL_dValidation(Convert.ToString(dtDocs.Rows[i]["CollAmt"]));
                            if (dBalanceAmt > 0.01M)
                            {
                                dBalanceAmt = 0.00M;
                            }
                            InvRow["TotalAmtAdj"] = bl.BL_dValidation(Convert.ToString(dtDocs.Rows[i]["CollAmt"])) + dBalanceAmt;
                            InvRow["TranType"] = 1;
                            InvRow["SerialNo"] = 1;
                            dtDetail.Rows.Add(InvRow);
                        }
                        else if (DocTypePorR == 2)
                        {
                            DataRow InvRow = dtDetail.NewRow();
                            InvRow["AccID"] = bl.BL_nValidation(dtDocs.Rows[i]["FAID"]);
                            InvRow["DocPrefix"] = bl.BL_nValidation(dtDocs.Rows[i]["DocPrefix"]);
                            InvRow["DocValue"] = bl.BL_nValidation(dtDocs.Rows[i]["DocValue"]);
                            InvRow["DocID"] = bl.BL_nValidation(dtDocs.Rows[i]["ID"]);
                            InvRow["DocDate"] = DateTime.ParseExact(Convert.ToString(dtDocs.Rows[i]["Tran_Date"]), "dd/MM/yyyy", CultureInfo.InvariantCulture);
                            InvRow["Balance"] = bl.BL_dValidation(Convert.ToString(dtDocs.Rows[i]["Balance"]));
                            InvRow["ColValue"] = bl.BL_dValidation(Convert.ToString(dtDocs.Rows[i]["CollAmt"]));//NetAmt
                            //TypeID	DocID	Tran_Date	DocRef	TransName	NetAmt	Balance	ID	FAID	DocPrefix	
                            //DocValue	UDFDocId	CollAmt	AdjAmt	DiscPern	DiscAmt	FullAdjYN	TotalAdjAmt
                            InvRow["AdjAmt"] = bl.BL_dValidation(Convert.ToString(dtDocs.Rows[i]["AdjAmt"]));
                            InvRow["DiscPer"] = Convert.ToString(Convert.ToString(dtDocs.Rows[i]["DiscPern"]));
                            InvRow["DiscAmt"] = bl.BL_dValidation(Convert.ToString(dtDocs.Rows[i]["DiscAmt"]));
                            int nFullyAdj = bl.BL_nValidation(dtDocs.Rows[i]["FullAdjYN"]);
                            decimal dWriteOffAmount = 0.00M;
                            if (nFullyAdj == 0)
                            {
                                dWriteOffAmount = bl.BL_dValidation(Convert.ToString(dtDocs.Rows[i]["Balance"])) - bl.BL_dValidation(Convert.ToString(Convert.ToString(dtDocs.Rows[i]["TotalAdjAmt"])));
                                dBalanceAmt = bl.BL_dValidation(Convert.ToString(dtDocs.Rows[i]["Balance"])) - bl.BL_dValidation(Convert.ToString(Convert.ToString(dtDocs.Rows[i]["TotalAdjAmt"])));
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
                            InvRow["FullyAdjAmt"] = bl.BL_dValidation(Convert.ToString(Convert.ToString(dtDocs.Rows[i]["WriteOffAmt"]))) + dWriteOffAmount;
                            InvRow["TotalAmtAdj"] = bl.BL_dValidation(Convert.ToString(Convert.ToString(dtDocs.Rows[i]["TotalAdjAmt"])))
                                                    + dBalanceAmt + dWriteOffAmount;
                            InvRow["TranType"] = 1;
                            InvRow["SerialNo"] = 1;
                            dtDetail.Rows.Add(InvRow);
                        }
                    }
                    bl.bl_Transaction(1);
                    DataTable dtResult = new DataTable();
                    dtResult = bl.bl_ManageTrans("uspManageFullColl",
                        listTrans.TransID, bl.BL_nValidation(listTrans.UDFId), dtHeader, dtDetail, dtMopDetails,
                        0,
                        listTrans.BeatID,
                        listTrans.SalesmanID,
                        0,
                        dtDenominationPMDetail, listTrans.TransMode == "1" || listTrans.TransMode == "3" ? "1" : "3", bl.BL_nValidation(listTrans.ID),
                        listTrans.TransMode == "1" ? "1" : listTrans.CurrentStatus,
                        0, listTrans.Remarks, listTrans.Narration);
                    if (dtResult.Columns.Count == 1)
                    {
                        int nScopeInvID = bl.BL_nValidation(dtResult.Rows[0][0].ToString());
                        bl.bl_Transaction(2);
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
                            DataRow[] drr = dtDocs.Select("ID = '" + nDocIdent + "'", null);
                            if (drr.Length > 0)
                            {
                                string DocID = drr[0]["DocID"].ToString();
                                string DocDate = drr[0]["Tran_Date"].ToString();
                                string TransName = drr[0]["TransName"].ToString();
                                if (strErrorList[0].Trim().ToUpper() == "DOCUMENTAMOUNT")
                                {
                                    ErrMsg = "Document amount was changed (" + DocID + " ," + DocDate + ", " + TransName + ")";
                                }
                                if (strErrorList[0].Trim().ToUpper() == "DOCUMENTSTATUS")
                                {
                                    ErrMsg = "This document already processed (" + DocID + " ," + DocDate + ", " + TransName + ")";
                                }

                            }
                            if (nDocPrefix == 15 || nDocPrefix == 1 || nDocPrefix == 7)
                            {
                            }
                            else
                            {
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
                else
                {
                    string ErrMsg = "";
                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspCancelCollection", listTrans.TransID,
                        listTrans.ID,
                        listTrans.UserID,
                        1,
                        listTrans.Status, listTrans.Remarks, listTrans.Narration);
                    if (dtResult.Rows.Count > 0)
                    {
                        string[] strErrorList = dtResult.Rows[0][0].ToString().Split('$');
                        if (strErrorList[0].Trim().ToUpper() == "ACC")
                        {
                            ErrMsg = "Account name already deactivated";
                        }
                        if (strErrorList[0].Trim().ToUpper() == "CANCELLED")
                        {
                            ErrMsg = "Document already cancelled";
                        }
                        if (strErrorList[0].Trim().ToUpper() == "TYPE")
                        {
                            ErrMsg = "Collection Type Status Already Changed";
                        }
                        if (strErrorList[0].Trim().ToUpper() == "PAYMENT")
                        {
                            ErrMsg = "This document already processed";
                        }
                        if (strErrorList[0].Trim().ToUpper() == "SETTLED")
                        {
                            ErrMsg = "Coupon Status Already Changed";
                        }
                        if (strErrorList[0].Trim().ToUpper() == "PROCESSED")
                        {
                            ErrMsg = "This document already processed";
                        }
                        if (strErrorList[0].Trim().ToUpper() == "BAL")
                        {
                            ErrMsg = "You don't have amount to cancel document";
                        }
                        if (strErrorList[0].Trim().ToUpper() == "PROC")
                        {
                            ErrMsg = "This document already processed";
                        }
                        bl.bl_Transaction(3);
                        list.Add(new SaveMessage()
                        {
                            ID = 0.ToString(),
                            MsgID = "1",
                            Message = ErrMsg
                        });
                        return Ok(list);
                    }
                    else
                    {
                        bl.bl_Transaction(2);
                        list.Add(new SaveMessage()
                        {
                            ID = 0.ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                        return Ok(list);
                    }
                }
            }
            return Ok();
        }
    }
}
