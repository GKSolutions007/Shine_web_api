using DocumentFormat.OpenXml.Bibliography;
using DocumentFormat.OpenXml.Office2010.ExcelAc;
using DocumentFormat.OpenXml.VariantTypes;
using DocumentFormat.OpenXml.Wordprocessing;
using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Web.Http;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class AccountsController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        public DataTable dtDenominationPMDetail = new DataTable();
        DataTable dtMopDetails = new DataTable("MOP"), dtDetail = new DataTable("CollectionDetail"), dtHeader = new DataTable("CollectionHeader");
        string connectionString = clsEncryptDecrypt.Decrypt(ConfigurationManager.ConnectionStrings["Connections"].ConnectionString);
        [HttpGet]
        [Route("api/creditdebitnote/get")]
        public IHttpActionResult GetData(string TransID, string Mode, string ID)
        {
            if (Mode == "1")
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspGetSetCreditDebitNoteData", Mode, TransID);
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
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetCreditDebitNoteData", Mode, TransID);
                List<AccouuntsModel> list = new List<AccouuntsModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new AccouuntsModel
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        DocID = DDT.Rows[i][1].ToString(),
                        DocDate = DDT.Rows[i][2].ToString(),
                        RefNo = DDT.Rows[i][3].ToString(),
                        PartyID = DDT.Rows[i][4].ToString(),
                        FAID = DDT.Rows[i][5].ToString(),
                        NoteValue = DDT.Rows[i][6].ToString(),
                        Balance = DDT.Rows[i][7].ToString(),
                        Status = DDT.Rows[i][8].ToString()
                    });
                }
                return Ok(list);
            }
            if (Mode == "3")
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetCreditDebitNoteData", Mode, TransID, ID);
                List<AccouuntsModel> list = new List<AccouuntsModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new AccouuntsModel
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        DocID = DDT.Rows[i][1].ToString(),
                        DocDate = Convert.ToDateTime(DDT.Rows[i][2].ToString()).ToString("yyyy-MM-dd"),
                        RefNo = DDT.Rows[i][4].ToString(),
                        PartyID = DDT.Rows[i][5].ToString(),
                        FAID = DDT.Rows[i][6].ToString(),
                        NoteValue = DDT.Rows[i][7].ToString(),
                        Balance = DDT.Rows[i][8].ToString(),
                        Status = DDT.Rows[i][9].ToString(),
                        Remark = DDT.Rows[i][10].ToString(),
                        Narration = DDT.Rows[i][11].ToString(),
                        UDFId = "0"
                    });
                }
                return Ok(list);
            }
            return Ok();
        }


        [HttpGet]
        [Route("api/creditdebitnote/getfilterdata")]
        public IHttpActionResult GetCDFilterData(string Mode, string TransID, string AccName, string Party, string FromDate, string ToDate, string Showall)
        {
            DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetCreditDebitNoteData", Mode, TransID, 0, AccName, Party, FromDate, ToDate, Showall);
            List<AccouuntsModel> list = new List<AccouuntsModel>();
            for (int i = 0; i < DDT.Rows.Count; i++)
            {
                list.Add(new AccouuntsModel
                {
                    ID = DDT.Rows[i][0].ToString(),
                    DocID = DDT.Rows[i][1].ToString(),
                    DocDate = DDT.Rows[i][2].ToString(),
                    RefNo = DDT.Rows[i][3].ToString(),
                    PartyID = DDT.Rows[i][4].ToString(),
                    FAID = DDT.Rows[i][5].ToString(),
                    NoteValue = DDT.Rows[i][6].ToString(),
                    Balance = DDT.Rows[i][7].ToString(),
                    Status = DDT.Rows[i][8].ToString(),
                    CBy = DDT.Rows[i]["UserName"].ToString(),
                    CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                    StatusID = DDT.Rows[i]["StatusID"].ToString(),
                });
            }
            return Ok(list);
        }
        [HttpPost]
        [Route("api/creditdebitnote/save")]
        public IHttpActionResult Save(AccouuntsModel listTrans)
        {
            if (listTrans != null)
            {
                List<SaveMessage> list = new List<SaveMessage>();
                if (listTrans.TransMode != "4")
                {

                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspManageCreditDebitNote", listTrans.TransMode, bl.BL_nValidation(listTrans.ID), listTrans.TransID,
                        listTrans.DocDate, listTrans.RefNo, listTrans.PartyID, listTrans.FAID, listTrans.TransID == "4" ? bl.BL_dValidation(listTrans.NoteValue) : 0,
                        listTrans.TransID == "5" ? bl.BL_dValidation(listTrans.NoteValue) : 0, listTrans.Remark, listTrans.Narration, listTrans.CBy,
                        bl.BL_nValidation(listTrans.Status), bl.BL_nValidation(listTrans.UDFId), bl.BL_nValidation(listTrans.CurrentStatus));
                    if (dtResult.Columns.Count > 1)
                    {
                        bl.bl_Transaction(3);
                        string[] strErrorList = dtResult.Rows[0][0].ToString().Split('$');
                        //if (strErrorList.Length == 1)
                        //{
                        //    if (strErrorList[0].Trim().ToUpper() == "ACC")
                        //    {
                        //        SetErrorAndFocus(txtVendName, 289);
                        //    }
                        //    else if (strErrorList[0].Trim().ToUpper() == "BANKACC")
                        //    {
                        //        SetErrorAndFocus(cmdSave, 289);
                        //    }                        
                        //}
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
                else// for cancel
                {
                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspManageCreditDebitNoteCancel", listTrans.TransID, listTrans.ID, listTrans.CBy, listTrans.CurrentStatus, listTrans.Remark, listTrans.Narration);
                    if (dtResult.Rows.Count > 0)
                    {
                        bl.bl_Transaction(3);
                        list.Add(new SaveMessage()
                        {
                            ID = 1.ToString(),
                            MsgID = "1",
                            Message = dtResult.Rows[0][0].ToString()
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
                return Ok(0);
            }
            return Ok("No data found");
        }
        [HttpGet]
        [Route("api/prvoucher/get")]
        public IHttpActionResult GetPRVData(string TransID, string Mode, string ID)
        {
            if (Mode == "1")
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspGetSetVoucherData", Mode, TransID);
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
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetVoucherData", Mode, TransID);
                List<AccouuntsModel> list = new List<AccouuntsModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new AccouuntsModel
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        DocID = DDT.Rows[i][1].ToString(),
                        DocDate = DDT.Rows[i][2].ToString(),
                        RefNo = DDT.Rows[i][3].ToString(),
                        PartyID = DDT.Rows[i][4].ToString(),
                        FAID = DDT.Rows[i][5].ToString(),
                        GoodsAmt = DDT.Rows[i][6].ToString(),
                        TaxAmt = DDT.Rows[i][7].ToString(),
                        NetAmt = DDT.Rows[i][8].ToString(),
                        Balance = DDT.Rows[i][9].ToString(),
                        Status = DDT.Rows[i][10].ToString(),
                        StatusID = DDT.Rows[i][11].ToString(),
                        CBy = DDT.Rows[i]["UserName"].ToString(),
                        CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                    });
                }
                return Ok(list);
            }
            if (Mode == "3")
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetVoucherData", Mode, TransID, ID);
                List<AccouuntsModel> list = new List<AccouuntsModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new AccouuntsModel
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        DocID = DDT.Rows[i][1].ToString(),
                        DocDate = Convert.ToDateTime(DDT.Rows[i][2].ToString()).ToString("yyyy-MM-dd"),
                        RefNo = DDT.Rows[i][4].ToString(),
                        PartyID = DDT.Rows[i][5].ToString(),
                        FAID = DDT.Rows[i][6].ToString(),
                        NoteValue = DDT.Rows[i][7].ToString(),
                        Balance = DDT.Rows[i][8].ToString(),
                        Status = DDT.Rows[i][9].ToString(),
                        Remark = DDT.Rows[i][10].ToString(),
                        Narration = DDT.Rows[i][11].ToString(),
                        UDFId = "0",
                        TaxID = DDT.Rows[i][12].ToString(),
                        TaxPern = DDT.Rows[i][13].ToString(),
                        DiscPern = DDT.Rows[i][14].ToString(),
                        DiscAmt = DDT.Rows[i][15].ToString(),
                        GrossAmt = DDT.Rows[i][16].ToString(),
                        TaxAmt = DDT.Rows[i][17].ToString(),
                        NetAmt = DDT.Rows[i][18].ToString(),
                        TDSAmt = DDT.Rows[i][19].ToString(),
                        SACHSN = DDT.Rows[i][20].ToString(),
                    });
                }
                return Ok(list);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/prvoucher/getfilterdata")]
        public IHttpActionResult GetPRFilterData(string Mode, string TransID, string AccName, string Party, string FromDate, string ToDate, string Showall)
        {
            DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetVoucherData", Mode, TransID, 0, AccName, Party, FromDate, ToDate, Showall);
            List<AccouuntsModel> list = new List<AccouuntsModel>();
            for (int i = 0; i < DDT.Rows.Count; i++)
            {
                list.Add(new AccouuntsModel
                {
                    ID = DDT.Rows[i][0].ToString(),
                    DocID = DDT.Rows[i][1].ToString(),
                    DocDate = DDT.Rows[i][2].ToString(),
                    RefNo = DDT.Rows[i][3].ToString(),
                    PartyID = DDT.Rows[i][4].ToString(),
                    FAID = DDT.Rows[i][5].ToString(),
                    GoodsAmt = DDT.Rows[i][6].ToString(),
                    TaxAmt = DDT.Rows[i][7].ToString(),
                    NetAmt = DDT.Rows[i][8].ToString(),
                    Balance = DDT.Rows[i][9].ToString(),
                    Status = DDT.Rows[i][10].ToString(),
                    StatusID = DDT.Rows[i][11].ToString(),
                    CBy = DDT.Rows[i]["UserName"].ToString(),
                    CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                });
            }
            return Ok(list);
        }

        [HttpPost]
        [Route("api/prvoucher/save")]
        public IHttpActionResult SavePRV(AccouuntsModel listTrans)
        {
            if (listTrans != null)
            {
                List<SaveMessage> list = new List<SaveMessage>();
                //if (listTrans.TransMode != "4")
                {

                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspManagePRVoucher", listTrans.TransMode, listTrans.TransID, bl.BL_nValidation(listTrans.ID),
                        listTrans.DocDate, listTrans.RefNo, listTrans.PartyID, listTrans.FAID, bl.BL_dValidation(listTrans.NoteValue),
                        bl.BL_dValidation(listTrans.DiscAmt), bl.BL_nValidation(listTrans.TaxID), bl.BL_dValidation(listTrans.TaxPern),
                        bl.BL_dValidation(listTrans.GrossAmt), bl.BL_dValidation(listTrans.TaxAmt), bl.BL_dValidation(listTrans.NetAmt),
                        listTrans.Remark, listTrans.Narration, listTrans.CBy, 0, bl.BL_nValidation(listTrans.UDFId), 0, 0, listTrans.SACHSN,
                        bl.BL_dValidation(listTrans.TDSAmt), bl.BL_nValidation(listTrans.CurrentStatus));
                    if (dtResult.Columns.Count > 1)
                    {
                        bl.bl_Transaction(3);
                        string[] strErrorList = dtResult.Rows[0][0].ToString().Split('$');
                        //if (strErrorList.Length == 1)
                        //{
                        //    if (strErrorList[0].Trim().ToUpper() == "ACC")
                        //    {
                        //        SetErrorAndFocus(txtVendName, 289);
                        //    }
                        //    else if (strErrorList[0].Trim().ToUpper() == "BANKACC")
                        //    {
                        //        SetErrorAndFocus(cmdSave, 289);
                        //    }                        
                        //}
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
                return Ok(0);
            }
            return Ok("No data found");
        }
        [HttpGet]
        [Route("api/contra/get")]
        public IHttpActionResult GetDataContra(string TransID, string Mode, string ID, string Value)
        {
            if (Mode == "1" || Mode == "4")
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspGetSetContraData", Mode, TransID, Value, ID);
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
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetContraData", Mode, TransID);
                List<AccouuntsModel> list = new List<AccouuntsModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new AccouuntsModel
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        DocID = DDT.Rows[i][1].ToString(),
                        DocDate = DDT.Rows[i][2].ToString(),
                        RefNo = DDT.Rows[i][3].ToString(),
                        ContType = DDT.Rows[i][4].ToString(),
                        ContMode = DDT.Rows[i][5].ToString(),
                        PartyID = DDT.Rows[i][6].ToString(),
                        FAID = DDT.Rows[i][7].ToString(),
                        NoteValue = DDT.Rows[i][8].ToString(),
                        Balance = DDT.Rows[i][9].ToString(),
                        Status = DDT.Rows[i][10].ToString(),
                        StatusID = DDT.Rows[i][11].ToString(),
                    });
                }
                return Ok(list);
            }
            if (Mode == "3")
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetContraData", Mode, TransID, null, ID);
                List<AccouuntsModel> list = new List<AccouuntsModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new AccouuntsModel
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        DocID = DDT.Rows[i][1].ToString(),
                        DocDate = Convert.ToDateTime(DDT.Rows[i][4].ToString()).ToString("yyyy-MM-dd"),
                        ContType = DDT.Rows[i][5].ToString(),
                        ContMode = DDT.Rows[i][6].ToString(),
                        RefNo = DDT.Rows[i][7].ToString(),
                        NoteValue = DDT.Rows[i][8].ToString(),
                        Balance = DDT.Rows[i][9].ToString(),
                        PartyID = DDT.Rows[i][10].ToString(),
                        NEFTNo = DDT.Rows[i][11].ToString(),
                        ChequeNo = DDT.Rows[i][12].ToString(),
                        Salesman = DDT.Rows[i][14].ToString(),
                        FAID = DDT.Rows[i][15].ToString(),
                        Remark = DDT.Rows[i][16].ToString(),
                        Narration = DDT.Rows[i][17].ToString(),
                        Status = DDT.Rows[i]["Status"].ToString(),
                        UDFId = "0"
                    });
                }
                return Ok(list);
            }
            if (Mode == "6" || Mode == "7")
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspLoadClosingBalance", 1, ID, Value);
                List<AccouuntsModel> list = new List<AccouuntsModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new AccouuntsModel
                    {
                        Balance = DDT.Rows[i][0].ToString(),
                        ContType = DDT.Rows[i][1].ToString(),
                    });
                }
                return Ok(list);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/contra/getfilterdata")]
        public IHttpActionResult GetContFilterData(string Mode, string TransID, string AccName, string FromDate, string ToDate, string Showall)
        {
            DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetContraData", Mode, TransID, null, 0, AccName, FromDate, ToDate, Showall);
            List<AccouuntsModel> list = new List<AccouuntsModel>();
            for (int i = 0; i < DDT.Rows.Count; i++)
            {
                list.Add(new AccouuntsModel
                {
                    ID = DDT.Rows[i][0].ToString(),
                    DocID = DDT.Rows[i][1].ToString(),
                    DocDate = DDT.Rows[i][2].ToString(),
                    RefNo = DDT.Rows[i][3].ToString(),
                    ContType = DDT.Rows[i][4].ToString(),
                    ContMode = DDT.Rows[i][5].ToString(),
                    PartyID = DDT.Rows[i][6].ToString(),
                    FAID = DDT.Rows[i][7].ToString(),
                    NoteValue = DDT.Rows[i][8].ToString(),
                    Balance = DDT.Rows[i][9].ToString(),
                    Status = DDT.Rows[i][10].ToString(),
                    StatusID = DDT.Rows[i][11].ToString(),
                    CBy = DDT.Rows[i]["UserName"].ToString(),
                    CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                });
            }
            return Ok(list);
        }

        [HttpPost]
        [Route("api/contra/save")]
        public IHttpActionResult SaveContra(AccouuntsModel listTrans)
        {
            if (listTrans != null)
            {
                List<SaveMessage> list = new List<SaveMessage>();
                //if (listTrans.TransMode != "4")
                {
                    string ChqID = "0", ChqNo = "", ChqRefNo = "";

                    if (listTrans.ContMode == "2")
                    {
                        if (!string.IsNullOrEmpty(listTrans.ChequeNo))
                        {
                            string[] CHQ = listTrans.ChequeNo.Split('-');
                            ChqRefNo = CHQ[0].ToString().Trim();
                            ChqID = CHQ[1].ToString().Trim();
                            ChqNo = listTrans.ChequeNo;
                            DataTable dtBankAccdtl = bl.BL_ExecuteParamSP("uspGetSetContraData", 5, bl.BL_nValidation(listTrans.PartyID));
                            if (dtBankAccdtl.Rows.Count > 0)
                            {
                                DataTable dtCheckCheque = bl.BL_ExecuteParamSP("uspCheckChequeStatusByNum", ChqRefNo, ChqID, bl.BL_nValidation(dtBankAccdtl.Rows[0][0]), bl.BL_nValidation(listTrans.ID));
                                if (dtCheckCheque.Rows.Count == 0)
                                {
                                    list.Add(new SaveMessage()
                                    {
                                        ID = 0.ToString(),
                                        MsgID = "1",
                                        Message = "Cheque"
                                    });
                                    return Ok(list);
                                }
                            }
                        }
                    }
                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspManageTranContra", listTrans.TransMode, bl.BL_nValidation(listTrans.ID), listTrans.DocDate, listTrans.ContType,
                        listTrans.ContMode, listTrans.Salesman, bl.BL_dValidation(listTrans.NoteValue), listTrans.RefNo, listTrans.PartyID, listTrans.NEFTNo, ChqID, ChqNo,
                          listTrans.FAID, listTrans.Narration, listTrans.Remark, listTrans.CBy, bl.BL_nValidation(listTrans.UDFId),
                        0, null, bl.BL_nValidation(listTrans.CurrentStatus));
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
                return Ok(0);
            }
            return Ok("No data found");
        }
        [HttpGet]
        [Route("api/journalentry/get")]
        public IHttpActionResult GetDatajv(string TransID, string Mode, string ID)
        {
            if (Mode == "1")
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspGetSetJournalEntryData", Mode, TransID);
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
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetJournalEntryData", Mode, TransID);
                List<AccouuntsModel> list = new List<AccouuntsModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new AccouuntsModel
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        DocID = DDT.Rows[i][1].ToString(),
                        DocDate = DDT.Rows[i][2].ToString(),
                        RefNo = DDT.Rows[i][3].ToString(),
                        PartyID = DDT.Rows[i][4].ToString(),
                        GrossAmt = DDT.Rows[i][5].ToString(),
                        NetAmt = DDT.Rows[i][6].ToString(),
                        Balance = DDT.Rows[i][7].ToString(),
                        Status = DDT.Rows[i][8].ToString()
                    });
                }
                return Ok(list);
            }
            if (Mode == "3")
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetJournalEntryData", Mode, TransID, null, ID);
                List<AccouuntsModel> list = new List<AccouuntsModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new AccouuntsModel
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        DocID = DDT.Rows[i][1].ToString(),
                        DocDate = Convert.ToDateTime(DDT.Rows[i][2].ToString()).ToString("yyyy-MM-dd"),
                        RefNo = DDT.Rows[i][3].ToString(),
                        FAID = DDT.Rows[i][4].ToString(),
                        PartyID = DDT.Rows[i][5].ToString(),
                        GrossAmt = DDT.Rows[i][6].ToString(),
                        NetAmt = DDT.Rows[i][7].ToString(),
                        Balance = DDT.Rows[i][8].ToString(),
                        Status = DDT.Rows[i][10].ToString(),
                        Remark = DDT.Rows[i][11].ToString(),
                        Narration = DDT.Rows[i][12].ToString(),
                        FAType = DDT.Rows[i][13].ToString(),
                        AdjYN = DDT.Rows[i][14].ToString(),
                        UDFId = "0"
                    });
                }
                return Ok(list);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/journalentry/getfilterdata")]
        public IHttpActionResult GetJEFilterData(string Mode, string TransID, string AccName, string FromDate, string ToDate, string Showall)
        {
            DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetJournalEntryData", Mode, TransID, null, 0, AccName, FromDate, ToDate, Showall);
            List<AccouuntsModel> list = new List<AccouuntsModel>();
            for (int i = 0; i < DDT.Rows.Count; i++)
            {
                list.Add(new AccouuntsModel
                {
                    ID = DDT.Rows[i][0].ToString(),
                    DocID = DDT.Rows[i][1].ToString(),
                    DocDate = DDT.Rows[i][2].ToString(),
                    RefNo = DDT.Rows[i][3].ToString(),
                    PartyID = DDT.Rows[i][4].ToString(),
                    GrossAmt = DDT.Rows[i][5].ToString(),
                    NetAmt = DDT.Rows[i][6].ToString(),
                    Balance = DDT.Rows[i][7].ToString(),
                    Status = DDT.Rows[i][8].ToString(),
                    StatusID = DDT.Rows[i][9].ToString(),
                    CBy = DDT.Rows[i]["UserName"].ToString(),
                    CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                });
            }
            return Ok(list);
        }
        [HttpPost]
        [Route("api/journalentry/save")]
        public IHttpActionResult SaveJV(AccouuntsModel listTrans)
        {
            if (listTrans != null)
            {
                List<SaveMessage> list = new List<SaveMessage>();
                if (listTrans.TransMode != "4")
                {
                    DataTable dtAdjRefId = new DataTable(), dtTVPTable = new DataTable();
                    dtAdjRefId.Columns.Add("Accid", typeof(int));
                    dtAdjRefId.Columns.Add("NoteId", typeof(int));
                    dtAdjRefId.Columns.Add("Balance", typeof(decimal));
                    dtAdjRefId.Columns.Add("DocDate", typeof(DateTime));
                    dtAdjRefId.Columns.Add("TransType", typeof(string));
                    if (dtTVPTable.Columns.Count == 0)
                    {
                        dtTVPTable.Columns.Add("DocDate", typeof(DateTime));
                        dtTVPTable.Columns.Add("DocRef", typeof(string));
                        dtTVPTable.Columns.Add("AccId", typeof(int));
                        dtTVPTable.Columns.Add("IfAdj", typeof(string));
                        dtTVPTable.Columns.Add("Debit", typeof(decimal));
                        dtTVPTable.Columns.Add("Credit", typeof(decimal));
                        dtTVPTable.Columns.Add("Remarks", typeof(string));
                        dtTVPTable.Columns.Add("Narration", typeof(string));
                        dtTVPTable.Columns.Add("UID", typeof(int));
                    }
                    foreach (JournalEntry item in listTrans.JVData)
                    {
                        DataRow dr = dtTVPTable.NewRow();
                        dr["DocDate"] = listTrans.DocDate;
                        dr["DocRef"] = listTrans.RefNo;
                        dr["AccId"] = item.AccID;
                        dr["IfAdj"] = item.AdjYN;
                        dr["Debit"] = bl.BL_dValidation(item.Debit);
                        dr["Credit"] = bl.BL_dValidation(item.Credit);
                        dr["Remarks"] = item.Remarks;
                        dr["Narration"] = listTrans.Narration;
                        dr["UID"] = listTrans.CBy;
                        dtTVPTable.Rows.Add(dr);
                    }
                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspManageFAJournal", dtTVPTable, dtAdjRefId, bl.BL_nValidation(listTrans.UDFId),
                        listTrans.TransMode, bl.BL_nValidation(listTrans.CurrentStatus), bl.BL_nValidation(listTrans.ID), listTrans.CBy,0,listTrans.Narration);
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
                else
                {
                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspManageFAJournalCancel", listTrans.TransMode, listTrans.CurrentStatus, listTrans.ID, listTrans.CBy, null, 0, null, listTrans.Narration);
                    if (dtResult.Rows.Count > 0)
                    {
                        bl.bl_Transaction(3);
                        list.Add(new SaveMessage()
                        {
                            ID = 1.ToString(),
                            MsgID = "1",
                            Message = dtResult.Rows[0][0].ToString()
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
                return Ok(0);
            }
            return Ok("No data found");
        }
        [HttpGet]
        [Route("api/othercollectionpayment/get")]
        public IHttpActionResult GetDatatherCollpay(string TransID, string Mode, string ID, string Value)
        {
            if (Mode == "1" || Mode == "4")
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspGetSetOtherCollPayData", Mode, TransID, Value, ID);
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
                if (Mode == "1")
                {
                    DDT = bl.BL_ExecuteParamSP("uspGetSetOtherCollPayData", 111, 0);
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
                }
                return Ok(list);
            }
            if (Mode == "2")
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetOtherCollPayData", Mode, TransID);
                List<AccouuntsModel> list = new List<AccouuntsModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new AccouuntsModel
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        DocID = DDT.Rows[i][1].ToString(),
                        DocDate = DDT.Rows[i][2].ToString(),
                        OCPType = DDT.Rows[i][3].ToString(),
                        RefNo = DDT.Rows[i][4].ToString(),
                        ContType = DDT.Rows[i][5].ToString(),
                        PartyID = DDT.Rows[i][6].ToString(),
                        FAID = DDT.Rows[i][7].ToString(),
                        NoteValue = DDT.Rows[i][8].ToString(),
                        Balance = DDT.Rows[i][9].ToString(),
                        Status = DDT.Rows[i][10].ToString(),
                        StatusID = DDT.Rows[i][11].ToString()
                    });
                }
                return Ok(list);
            }
            if (Mode == "3")
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetOtherCollPayData", Mode, TransID, null, ID);
                List<AccouuntsModel> list = new List<AccouuntsModel>();
                if (DDT.Rows.Count > 0)
                {
                    List<OtherCollPayPMDetails> listOCPM = new List<OtherCollPayPMDetails>();
                    DataTable dtPM = bl.BL_ExecuteParamSP("uspGetSetOtherCollPayData", 6, TransID, null, ID);
                    for (int i = 0; i < dtPM.Rows.Count; i++)
                    {
                        listOCPM.Add(new OtherCollPayPMDetails
                        {
                            ID = dtPM.Rows[i][0].ToString(),
                            Amount = dtPM.Rows[i][1].ToString(),
                            PaymentMode = dtPM.Rows[i][2].ToString(),
                            ChequeID = dtPM.Rows[i][3].ToString().Trim(),
                            BankAccID = dtPM.Rows[i][4].ToString(),
                            NeftID = dtPM.Rows[i][5].ToString(),
                            Date = Convert.ToDateTime(dtPM.Rows[i][6].ToString()).ToString("yyyy-MM-dd"),
                            PayAt = dtPM.Rows[i][7].ToString(),
                            IfscCode = dtPM.Rows[i][8].ToString(),
                            BankName = dtPM.Rows[i][9].ToString(),
                            BranchName = dtPM.Rows[i][10].ToString(),
                            AmtRecd = dtPM.Rows[i][11].ToString(),
                            Status = dtPM.Rows[i][12].ToString(),
                        });
                    }
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new AccouuntsModel
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            DocID = DDT.Rows[i][1].ToString(),
                            DocDate = Convert.ToDateTime(DDT.Rows[i][2].ToString()).ToString("yyyy-MM-dd"),
                            OCPType = DDT.Rows[i][3].ToString(),
                            RefNo = DDT.Rows[i][4].ToString(),
                            ContType = DDT.Rows[i][5].ToString(),
                            PartyID = DDT.Rows[i][6].ToString(),
                            FAID = DDT.Rows[i][7].ToString(),
                            NoteValue = DDT.Rows[i][8].ToString(),
                            Balance = DDT.Rows[i][9].ToString(),
                            Status = DDT.Rows[i][10].ToString(),
                            StatusID = DDT.Rows[i][11].ToString(),
                            Remark = DDT.Rows[i][12].ToString(),
                            Narration = DDT.Rows[i][13].ToString(),
                            UDFId = DDT.Rows[i][14].ToString(),
                            VisaAmt = DDT.Rows[i][15].ToString(),
                            VisaPern = DDT.Rows[i][16].ToString(),
                            ContMode = DDT.Rows[i][17].ToString(),
                            OCPPMData = listOCPM
                        });
                    }
                }
                return Ok(list);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/othercollectionpayment/getfilterdata")]
        public IHttpActionResult GetOCPFilterData(string Mode, string TransID, string AccName, string Party, string FromDate, string ToDate, string Showall)
        {
            DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetOtherCollPayData", Mode, TransID, null, 0, AccName, Party, FromDate, ToDate, Showall);
            List<AccouuntsModel> list = new List<AccouuntsModel>();
            for (int i = 0; i < DDT.Rows.Count; i++)
            {
                list.Add(new AccouuntsModel
                {
                    ID = DDT.Rows[i][0].ToString(),
                    DocID = DDT.Rows[i][1].ToString(),
                    DocDate = DDT.Rows[i][2].ToString(),
                    OCPType = DDT.Rows[i][3].ToString(),
                    RefNo = DDT.Rows[i][4].ToString(),
                    ContType = DDT.Rows[i][5].ToString(),
                    PartyID = DDT.Rows[i][6].ToString(),
                    FAID = DDT.Rows[i][7].ToString(),
                    NoteValue = DDT.Rows[i][8].ToString(),
                    Balance = DDT.Rows[i][9].ToString(),
                    Status = DDT.Rows[i][10].ToString(),
                    StatusID = DDT.Rows[i][11].ToString(),
                    CBy = DDT.Rows[i]["UserName"].ToString(),
                    CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                });
            }
            return Ok(list);
        }
        [HttpPost]
        [Route("api/othercollectionpayment/save")]
        public IHttpActionResult SaveOCP(AccouuntsModel listTrans)
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


                    int nPayMode = bl.BL_nValidation(listTrans.ContType);
                    int nTransType = bl.BL_nValidation(listTrans.TransID);
                    DataTable dtAcc = bl.BL_ExecuteParamSP("uspGetSetOtherCollPayData", 5, 0, listTrans.PartyID);
                    string PartyID = dtAcc.Rows.Count > 0 ? dtAcc.Rows[0][0].ToString() : "0";
                    dtAcc = bl.BL_ExecuteParamSP("uspGetSetOtherCollPayData", 5, 0, listTrans.FAID);
                    string ExpID = dtAcc.Rows.Count > 0 ? dtAcc.Rows[0][0].ToString() : "0";
                    DataRow CustRow = dtHeader.NewRow();
                    CustRow["Date"] = listTrans.DocDate;
                    CustRow["CoLLPYType"] = listTrans.OCPType;
                    CustRow["AccID"] = bl.BL_nValidation(PartyID);
                    CustRow["ColAmt"] = listTrans.NoteValue;
                    CustRow["Balance"] = 0;
                    CustRow["DocRefNo"] = listTrans.RefNo;
                    CustRow["ColMode"] = nPayMode;
                    CustRow["Status"] = 1;
                    CustRow["ExAccId"] = bl.BL_nValidation(ExpID);
                    CustRow["UID"] = listTrans.CBy;
                    CustRow["Type"] = 0;
                    CustRow["SerialNo"] = 1;
                    CustRow["VisaPern"] = bl.BL_dValidation(listTrans.VisaPern);
                    CustRow["VisaAmt"] = bl.BL_dValidation(listTrans.VisaAmt);
                    dtHeader.Rows.Add(CustRow);
                    dtMopDetails.Rows.Clear();
                    DataRow dtRow = dtMopDetails.NewRow();
                    if (listTrans.OCPType == "3")
                    {
                        dtRow["AccID"] = bl.BL_nValidation(PartyID);
                    }
                    else if (listTrans.OCPType == "2")
                    {
                        dtRow["AccID"] = bl.BL_nValidation(ExpID);
                    }
                    dtRow["Mode"] = nPayMode;
                    dtRow["Date"] = Convert.ToDateTime(listTrans.DocDate).Date;
                    if (nPayMode == 2)
                    {
                        string[] chq = listTrans.ChequeNo.Split('-');
                        if (nTransType == 10)
                        {
                            dtRow["[Cheque/DD Number]"] = listTrans.NEFTNo;// GKSShineBL.BL_TitleCase(txtNo.Text.Trim());
                        }
                        if (nTransType == 11)
                        {
                            dtRow["BankAccNo"] = "";// GKSShineBL.BL_TitleCase(txtBankAccNo.Text.Trim());
                            dtRow["BankAccId"] = listTrans.BankAccID;//GKSShineBL.BL_nValidation(txtBankAccNo.Tag);
                            dtRow["[Cheque/DD Number]"] = !string.IsNullOrEmpty(listTrans.ChequeNo) ? chq[1].ToString() : "0";//GKSShineBL.BL_nValidation(txtNo.Tag);
                            dtRow["ChequeBkRefNo"] = listTrans.ChequeNo;//GKSShineBL.BL_TitleCase(txtNo.Text.Trim());
                        }
                    }
                    if (nPayMode == 3)
                    {
                        dtRow["[Cheque/DD Number]"] = listTrans.ChequeNo;//GKSShineBL.BL_TitleCase(txtNo.Text.Trim());
                        if (nTransType == 11)
                        {
                            dtRow["BankAccNo"] = "";//GKSShineBL.BL_TitleCase(txtBankAccNo.Text.Trim());
                            dtRow["BankAccId"] = listTrans.BankAccID;//GKSShineBL.BL_nValidation(txtBankAccNo.Tag);
                        }
                    }
                    if (nPayMode == 4 || nPayMode == 5)
                    {
                        dtRow["Neft"] = listTrans.NEFTNo;//GKSShineBL.BL_TitleCase(txtNo.Text.Trim());
                        dtRow["BankAccNo"] = "";//GKSShineBL.BL_TitleCase(txtBankAccNo.Text.Trim());
                        dtRow["BankAccId"] = listTrans.BankAccID;//Convert.ToInt32(txtBankAccNo.Tag);
                    }

                    dtRow["PayAt"] = "";
                    dtRow["IFSC"] = listTrans.IFSC;//GKSShineBL.BL_TitleCase(txtIFSCCode.Text.Trim());
                    dtRow["Bank"] = listTrans.BankID;//GKSShineBL.BL_TitleCase(txtBank.Text.Trim());
                    dtRow["Branch"] = listTrans.Branch;//GKSShineBL.BL_TitleCase(txtBranch.Text.Trim());
                    dtRow["Amt"] = bl.BL_dValidation(listTrans.NoteValue);
                    dtRow["SerialNo"] = 1;
                    dtMopDetails.Rows.Add(dtRow);
                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspManageFullColl", listTrans.TransID, bl.BL_nValidation(listTrans.UDFId), dtHeader, dtDetail, dtMopDetails,
                         0, 0, 0, 0, dtDenominationPMDetail, listTrans.TransMode == "1" || listTrans.TransMode == "3" ? "1" : "3", bl.BL_nValidation(listTrans.ID),
                         listTrans.CurrentStatus, bl.BL_nValidation(listTrans.ContMode), listTrans.Remark, listTrans.Narration);
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
                else
                {
                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspCancelCollection", listTrans.TransID, listTrans.ID, listTrans.CBy, 1, listTrans.CurrentStatus
                        , listTrans.Remark, listTrans.Narration);
                    if (dtResult.Rows.Count > 0)
                    {
                        bl.bl_Transaction(3);
                        list.Add(new SaveMessage()
                        {
                            ID = 1.ToString(),
                            MsgID = "1",
                            Message = dtResult.Rows[0][0].ToString()
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
                return Ok(0);
            }
            return Ok("No data found");
        }
        [HttpGet]
        [Route("api/dailycashexpenses/get")]
        public IHttpActionResult GetExpensesData()
        {
            DataTable DDT = bl.BL_ExecuteParamSP("uspLoadBulkExpeses");
            if (DDT.Rows.Count > 0)
            {
                string JSONCONV = JsonConvert.SerializeObject(DDT);
                return Ok(JSONCONV);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/dailycashexpenses/save")]
        public IHttpActionResult Savedailycashexp(CollectionPaymentModel listTrans)
        {
            if (listTrans != null)
            {
                List<SaveMessage> list = new List<SaveMessage>();
                    dtDenominationPMDetail.Columns.Add("ColDetailDid", typeof(int));
                    dtDenominationPMDetail.Columns.Add("ColDetailDenomination", typeof(int));
                    dtDenominationPMDetail.Columns.Add("ColtotCoupons", typeof(int));
                    dtDenominationPMDetail.Columns.Add("ColDetailCount", typeof(string));
                    dtDenominationPMDetail.Columns.Add("ColDetailAmount", typeof(decimal));
                    bl.BL_AddCollectionData(dtHeader, dtDetail, dtMopDetails);
                    DataTable dtAdjRefId = new DataTable(), dtTVPTable = new DataTable();
                DataTable dtAccDetails = bl.listConvertToDataTable(listTrans.lstCollPayDtl);
                for (int i = 0; i < dtAccDetails.Rows.Count; i++)
                {
                    int nAccID = bl.BL_nValidation(dtAccDetails.Rows[i]["FAID"]);
                    decimal dAmount = bl.BL_dValidation(dtAccDetails.Rows[i]["CollAmt"]);
                    string strNarration = dtAccDetails.Rows[i]["TransName"].ToString();
                    dtHeader.Rows.Clear();
                    DataRow CustRow = dtHeader.NewRow();
                    CustRow["Date"] = listTrans.DocDate;
                    CustRow["CoLLPYType"] = "2";
                    CustRow["AccID"] = 0;
                    CustRow["ColAmt"] = dAmount;
                    CustRow["Balance"] = 0;
                    CustRow["DocRefNo"] = dtAccDetails.Rows[i]["DocRef"].ToString();
                    CustRow["ColMode"] = 1;
                    CustRow["Status"] = 1;
                    CustRow["ExAccId"] = nAccID;
                    CustRow["UID"] = listTrans.UserID;
                    CustRow["Type"] = 0;
                    CustRow["SerialNo"] = 1;
                    CustRow["VisaPern"] =0;
                    CustRow["VisaAmt"] = 0;
                    dtHeader.Rows.Add(CustRow);

                    dtMopDetails.Rows.Clear();
                    DataRow dtRow = dtMopDetails.NewRow();
                    dtRow["AccID"] = nAccID;
                    dtRow["Mode"] = 1;
                    dtRow["Date"] = listTrans.DocDate;
                    dtRow["[Cheque/DD Number]"] = null;
                    dtRow["BankAccNo"] = null;
                    dtRow["BankAccId"] = 0;
                    dtRow["ChequeBkRefNo"] = null;
                    dtRow["Neft"] = null;
                    dtRow["PayAt"] = null;
                    dtRow["IFSC"] = null;
                    dtRow["Bank"] = null;
                    dtRow["Branch"] = null;
                    dtRow["Amt"] = dAmount;
                    dtRow["SerialNo"] = 1;
                    dtMopDetails.Rows.Add(dtRow);


                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspManageFullColl", 11, bl.BL_nValidation(listTrans.UDFId), dtHeader, dtDetail, dtMopDetails,
                         0, 0, 0, 0, dtDenominationPMDetail, 1, bl.BL_nValidation(listTrans.ID),
                         listTrans.CurrentStatus, 0, listTrans.Remarks, strNarration);
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
                    }
                }
                list.Add(new SaveMessage()
                {
                    ID = "0",
                    MsgID = "0",
                    Message = "Saved Successfully"
                });
                return Ok(list);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/chequedeposit/get")]
        public IHttpActionResult GetDataCHQDEP( string Mode, string TransID, string ID, string ToDate, string ShowBounce)
        {
            if (Mode == "1")
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspGetSetChequeDepositData", Mode, TransID);
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
                List<chequedepositdocuments> list = new List<chequedepositdocuments>();
                DataTable DDT = bl.BL_ExecuteParamSP("uspDepositdetail", ID, ToDate, ShowBounce);
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new chequedepositdocuments
                    {
                        AccID = DDT.Rows[i]["AccID"].ToString(),
                        AccName = DDT.Rows[i]["AccName"].ToString(),
                        ChqorDDNo = DDT.Rows[i]["ChqorDDNo"].ToString(),
                        ChqDate = DDT.Rows[i]["ChqDate"].ToString(),
                        BankName = DDT.Rows[i]["BankName"].ToString(),
                        BranchName = DDT.Rows[i]["BranchName"].ToString(),
                        CollAmt = DDT.Rows[i]["CollAmt"].ToString(),
                        PayMode = DDT.Rows[i]["PayMode"].ToString(),
                        Desc = DDT.Rows[i]["Desc"].ToString(),
                        Status = DDT.Rows[i]["Status"].ToString(),
                        ColID = DDT.Rows[i]["ColID"].ToString(),
                        DepID = DDT.Rows[i]["DepID"].ToString(),
                        IFSCCode = DDT.Rows[i]["IFSCCode"].ToString(),
                    });
                }
                return Ok(list);
            }
            if (Mode == "3")
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetJournalEntryData", Mode, TransID, null, ID);
                List<AccouuntsModel> list = new List<AccouuntsModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new AccouuntsModel
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        DocID = DDT.Rows[i][1].ToString(),
                        DocDate = Convert.ToDateTime(DDT.Rows[i][2].ToString()).ToString("yyyy-MM-dd"),
                        RefNo = DDT.Rows[i][3].ToString(),
                        FAID = DDT.Rows[i][4].ToString(),
                        PartyID = DDT.Rows[i][5].ToString(),
                        GrossAmt = DDT.Rows[i][6].ToString(),
                        NetAmt = DDT.Rows[i][7].ToString(),
                        Balance = DDT.Rows[i][8].ToString(),
                        Status = DDT.Rows[i][10].ToString(),
                        Remark = DDT.Rows[i][11].ToString(),
                        Narration = DDT.Rows[i][12].ToString(),
                        FAType = DDT.Rows[i][13].ToString(),
                        AdjYN = DDT.Rows[i][14].ToString(),
                        UDFId = "0"
                    });
                }
                return Ok(list);
            }            
            return Ok();
        }
        [HttpGet]
        [Route("api/chequedeposit/cancel")]
        public IHttpActionResult GetChqDepFilterData(string TransID, string ID,string UserID)
        {
            List<SaveMessage> list = new List<SaveMessage>();
            bl.bl_Transaction(1);
            DataTable dtResult = bl.bl_ManageTrans("uspManageChequeDeposit", bl.BL_nValidation(ID), 4, bl.BL_nValidation(UserID));
            if (dtResult.Columns.Count > 1)
            {
                bl.bl_Transaction(3);
                string strmsg = "";
                int nCheck = bl.BL_nValidation(dtResult.Rows[0][0].ToString());
                if (nCheck == 1)
                {
                    strmsg = "Deposit Account Already deactivated";
                }
                else if (nCheck == 2)
                {
                    strmsg = "This document already processed";
                }
                else if (nCheck == 3)
                {
                    strmsg = "Deposit Account Already deactivated";
                }
                list.Add(new SaveMessage()
                {
                    ID = 0.ToString(),
                    MsgID = "1",
                    Message = strmsg
                });
                return Ok(list);
            }
            else
            {
                bl.bl_Transaction(2);
            }
            list.Add(new SaveMessage()
            {
                ID = "0",
                MsgID = "0",
                Message = "Saved Successfully"
            });
            return Ok(list);
        }
        [HttpGet]
        [Route("api/chequedeposit/getfilterdata")]
        public IHttpActionResult GetChqDepFilterData(string Mode, string TransID, string AccName, string Party, string FromDate, string ToDate, string Showall)
        {
            List<AccouuntsModel> list = new List<AccouuntsModel>();
            DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetChequeDepositData", Mode, TransID, AccName, Party, FromDate, ToDate, Showall);
            for (int i = 0; i < DDT.Rows.Count; i++)
            {
                list.Add(new AccouuntsModel
                {
                    ID = DDT.Rows[i]["DepositID"].ToString(),
                    DocID = DDT.Rows[i]["DocID"].ToString(),
                    DocDate = DDT.Rows[i]["ChequeDate"].ToString(),
                    ChequeNo = DDT.Rows[i]["ChequeNo"].ToString(),
                    BankAccID = DDT.Rows[i]["AccountNo"].ToString(),
                    BankName = DDT.Rows[i]["BankName"].ToString(),
                    Salesman = DDT.Rows[i]["Name"].ToString(),
                    StatusID = DDT.Rows[i]["Status"].ToString(),
                    Status = DDT.Rows[i]["Description"].ToString(),
                    NetAmt = DDT.Rows[i]["Amount"].ToString(),
                    PartyID = DDT.Rows[i]["Party Name"].ToString(),
                    IFSC = DDT.Rows[i]["ifscCode"].ToString(),
                    CBy = DDT.Rows[i]["UserName"].ToString(),
                    CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                });
            }
            return Ok(list);
        }
        [HttpPost]
        [Route("api/chequedeposit/save")]
        public IHttpActionResult Savechequedeposit(chequedeposit listTrans)
        {
            if (listTrans != null)
            {
                List<SaveMessage> list = new List<SaveMessage>();
                DataTable dtCheqs = bl.listConvertToDataTable(listTrans.chequedepositsdocs);
                for (int i = 0; i < dtCheqs.Rows.Count; i++)
                {                   
                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspManageChequeDeposit", bl.BL_nValidation(dtCheqs.Rows[i]["DepID"]), 1, bl.BL_nValidation(listTrans.CBy)
                        , bl.BL_nValidation(dtCheqs.Rows[i]["ColID"]), listTrans.DocDate, listTrans.DepositAccID, listTrans.SalesmanID, null, null,
                        bl.BL_nValidation(dtCheqs.Rows[i]["Status"]), 0);
                    if (dtResult.Columns.Count > 1)
                    {
                        bl.bl_Transaction(3);
                        string strmsg = "";
                        int nCheck = bl.BL_nValidation(dtResult.Rows[0][0].ToString());
                        if(nCheck == 1)
                        {
                            strmsg = "Deposit Account Already deactivated";
                        }
                        else if (nCheck == 2)
                        {
                            strmsg = "This document already processed";
                        }
                        else if (nCheck == 3)
                        {
                            strmsg = "Deposit Account Already deactivated";
                        }
                        list.Add(new SaveMessage()
                        {
                            ID = 0.ToString(),
                            MsgID = "1",
                            Message = strmsg
                        });
                        return Ok(list);
                    }
                    else
                    {
                        bl.bl_Transaction(2);
                    }
                }                
                list.Add(new SaveMessage()
                {
                    ID = "0",
                    MsgID = "0",
                    Message = "Saved Successfully"
                });
                return Ok(list);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/bouncerealisation/get")]
        public IHttpActionResult GetDataCHQBR(string Mode, string TransID)
        {
            if (Mode == "1")
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspGetSetChequeBounceRealiseData", Mode, TransID);
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
        [Route("api/bouncerealisation/getfilterdata")]
        public IHttpActionResult GetChqBRFilterData(string Mode, string TransID, string AccName, string Party, string FromDate, string ToDate, string Showall)
        {
            List<AccouuntsModel> list = new List<AccouuntsModel>();
            string ChangeMode = TransID == "1" ? "3" : Mode.ToString();
            DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetChequeBounceRealiseData", ChangeMode, TransID, AccName, Party, FromDate, ToDate, Showall);
            for (int i = 0; i < DDT.Rows.Count; i++)
            {
                list.Add(new AccouuntsModel
                {
                    ID = DDT.Rows[i]["DepositID"].ToString(),
                    DocID = DDT.Rows[i]["DocID"].ToString(),
                    DocDate = DDT.Rows[i]["ChequeDate"].ToString(),
                    ChequeNo = DDT.Rows[i]["ChequeNo"].ToString(),
                    BankAccID = DDT.Rows[i]["AccountNo"].ToString(),
                    BankName = DDT.Rows[i]["BankName"].ToString(),
                    Salesman = DDT.Rows[i]["Name"].ToString(),
                    StatusID = DDT.Rows[i]["Status"].ToString(),
                    Status = DDT.Rows[i]["Description"].ToString(),
                    NetAmt = DDT.Rows[i]["Amount"].ToString(),
                    PartyID = DDT.Rows[i]["Party Name"].ToString(),
                    IFSC = DDT.Rows[i]["ifscCode"].ToString(),
                });
            }
            return Ok(list);
        }
        [HttpPost]
        [Route("api/bouncerealisation/save")]
        public IHttpActionResult SavechequeBR(chequedeposit listTrans)
        {
            if (listTrans != null)
            {
                List<SaveMessage> list = new List<SaveMessage>();
                DataTable dtCheqs = bl.listConvertToDataTable(listTrans.chequedepositsdocs);
                for (int i = 0; i < dtCheqs.Rows.Count; i++)
                {
                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspManageChequeDeposit", bl.BL_nValidation(dtCheqs.Rows[i]["DepID"]), listTrans.TransMode, bl.BL_nValidation(listTrans.CBy)
                        , null, null, null, null, bl.BL_nValidation(listTrans.BankCharge), listTrans.ChequeBRDate,
                        bl.BL_nValidation(dtCheqs.Rows[i]["Status"]), 0);
                    if (dtResult.Columns.Count > 1)
                    {
                        bl.bl_Transaction(3);
                        string strmsg = "";
                        int nCheck = bl.BL_nValidation(dtResult.Rows[0][0].ToString());
                        if (nCheck == 1)
                        {
                            strmsg = "Deposit Account Already deactivated";
                        }
                        else if (nCheck == 2)
                        {
                            strmsg = "This document already processed";
                        }
                        else if (nCheck == 3)
                        {
                            strmsg = "Deposit Account Already deactivated";
                        }
                        list.Add(new SaveMessage()
                        {
                            ID = 0.ToString(),
                            MsgID = "1",
                            Message = strmsg
                        });
                        return Ok(list);
                    }
                    else
                    {
                        bl.bl_Transaction(2);
                    }
                }
                list.Add(new SaveMessage()
                {
                    ID = "0",
                    MsgID = "0",
                    Message = "Saved Successfully"
                });
                return Ok(list);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/bouncerealisation/cancel")]
        public IHttpActionResult GetChqBRFilterData(string TransID, string ID, string UserID,string Status)
        {
            List<SaveMessage> list = new List<SaveMessage>();
            bl.bl_Transaction(1);
            DataTable dtResult = bl.bl_ManageTrans("uspManageChequeDeposit", bl.BL_nValidation(ID), 2, bl.BL_nValidation(UserID),
                null,null,null, null, null, null, Status);
            if (dtResult.Columns.Count > 1)
            {
                bl.bl_Transaction(3);
                string strmsg = "";
                int nCheck = bl.BL_nValidation(dtResult.Rows[0][0].ToString());
                if (nCheck == 1)
                {
                    strmsg = "Deposit Account Already deactivated";
                }
                else if (nCheck == 2)
                {
                    strmsg = "This document already processed";
                }
                else if (nCheck == 3)
                {
                    strmsg = "Deposit Account Already deactivated";
                }
                list.Add(new SaveMessage()
                {
                    ID = 0.ToString(),
                    MsgID = "1",
                    Message = strmsg
                });
                return Ok(list);
            }
            else
            {
                bl.bl_Transaction(2);
            }
            list.Add(new SaveMessage()
            {
                ID = "0",
                MsgID = "0",
                Message = "Saved Successfully"
            });
            return Ok(list);
        }
        [HttpGet]
        [Route("api/brsdata/get")]
        public IHttpActionResult GetBRSData(string Mode, string AccNo, string Party, string FromDate, string ToDate, string Showblank)
        {
            if (Mode == "1")
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspgetsetBRSData", Mode);
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
                DataTable DDT = bl.BL_ExecuteParamSP("uspgetsetBRSData", Mode, AccNo, Party, FromDate, ToDate, Showblank);
                if (DDT.Rows.Count > 0)
                {
                    string JSONCONV = JsonConvert.SerializeObject(DDT);
                    return Ok(JSONCONV);
                }
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/brsdata/save")]
        public IHttpActionResult Savebrsdata(List<BRSData> listTrans)
        {
            if (listTrans != null)
            {
                DataTable dtSave = new DataTable();
                dtSave.Columns.Add("SNO", typeof(int));
                dtSave.Columns.Add("JVID", typeof(string));
                dtSave.Columns.Add("DocValue", typeof(string));
                dtSave.Columns.Add("TRANDATE", typeof(string));
                dtSave.Columns.Add("BRSDATE", typeof(string));
                
                List<SaveMessage> list = new List<SaveMessage>();
                DataTable dtCheqs = bl.listConvertToDataTable(listTrans);
                int nCount = 1;
                for (int i = 0; i < dtCheqs.Rows.Count; i++)
                {
                    int nJVID = bl.BL_nValidation(dtCheqs.Rows[i]["JVID"]);
                    if(nJVID > 0)
                    {                        
                        string BRSDATE =  Convert.ToString(dtCheqs.Rows[i]["BRSDate"]);
                        DataRow drSave = dtSave.NewRow();
                        drSave["SNO"] = nCount;
                        drSave["JVID"] = nJVID;
                        drSave["DocValue"] = Convert.ToString(dtCheqs.Rows[i]["DocValue"]);
                        drSave["BRSDATE"] = !string.IsNullOrEmpty(BRSDATE) ? BRSDATE : "";
                        drSave["TRANDATE"] = Convert.ToDateTime(dtCheqs.Rows[i]["DocDate"].ToString()).ToString("yyyy-MM-dd");
                        dtSave.Rows.Add(drSave);
                        nCount++;
                    }                                    
                }
                bl.bl_Transaction(1);
                DataTable dtResult = bl.bl_ManageTrans("uspManageBRS", dtSave);
                bl.bl_Transaction(2);
                list.Add(new SaveMessage()
                {
                    ID = "0",
                    MsgID = "0",
                    Message = "Saved Successfully"
                });
                return Ok(list);
            }
            return Ok();
        }
    }
}
