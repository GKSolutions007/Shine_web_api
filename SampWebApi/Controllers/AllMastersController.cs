using DocumentFormat.OpenXml.Office.CustomXsn;
using DocumentFormat.OpenXml.Office2010.Excel;
using DocumentFormat.OpenXml.Office2010.ExcelAc;
using DocumentFormat.OpenXml.Spreadsheet;
using DocumentFormat.OpenXml.Wordprocessing;
using Ionic.Zip;
using iTextSharp.text;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Org.BouncyCastle.Math.EC;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web;
using System.Web.Http;
using System.Web.Http.Cors;
using System.Windows.Interop;
namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class AllMastersController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        string connectionString = clsEncryptDecrypt.Decrypt(ConfigurationManager.ConnectionStrings["Connections"].ConnectionString);
        [HttpGet]
        [Route("api/homescreendraft/get")]
        public IHttpActionResult GetData(string Mode, string Trans,string ID ="1")
        {
            try
            {
                DataTable DDT = new DataTable();
                if (Mode == "1")
                {
                    DDT = bl.BL_ExecuteParamSP("uspHomescreenData", Mode, Trans);
                    List<SingleMasterModel> list = new List<SingleMasterModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new SingleMasterModel
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            Name = DDT.Rows[i][1].ToString(),
                            Value = DDT.Rows[i][2].ToString(),
                            Mode = HttpUtility.UrlEncode(clsEncryptDecrypt.Encrypt(DDT.Rows[i][1].ToString()))
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "2")
                {
                    DDT = bl.BL_ExecuteParamSP("uspHomescreenData", Mode, Trans);
                    List<PurchaseModel> list = new List<PurchaseModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new PurchaseModel
                        {
                            ID = HttpUtility.UrlEncode(clsEncryptDecrypt.Encrypt(DDT.Rows[i][0].ToString())),
                            DocID = DDT.Rows[i][1].ToString(),
                            Date = DDT.Rows[i][2].ToString(),
                            RefNo = DDT.Rows[i][3].ToString(),
                            BranchID = DDT.Rows[i][4].ToString(),
                            IsDraft = DDT.Rows[i][5].ToString(),
                            DraftID = DDT.Rows[i][6].ToString(),
                            VendorName = DDT.Rows[i][7].ToString(),
                            GrossAmt = DDT.Rows[i][8].ToString(),
                            TaxAmt = DDT.Rows[i][9].ToString(),
                            NetAmt = DDT.Rows[i][10].ToString(),
                            TransMode = HttpUtility.UrlEncode(clsEncryptDecrypt.Encrypt("1")),
                            EncDocPrefix = HttpUtility.UrlEncode(clsEncryptDecrypt.Encrypt(DDT.Rows[i][11].ToString())),
                            TransID = DDT.Rows[i][11].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "3")
                {
                    DDT = bl.BL_ExecuteParamSP("uspHomescreenCollectionData", Trans);
                    string Jsondata = JsonConvert.SerializeObject(DDT);
                    return Ok(Jsondata);
                }
                if (Mode == "4" || Mode == "5")
                {
                    DDT = bl.BL_ExecuteParamSP("uspHomescreenData", Mode, "");
                    string Jsondata = JsonConvert.SerializeObject(DDT);
                    return Ok(Jsondata);
                }
                if (Mode == "6")
                {
                    DataSet DDTd = bl.BL_ExecuteParamSPDataset("uspHomescreenData", Mode, Trans);
                    return Ok(DDTd);
                }
                if (Mode == "7")
                {
                    DDT = bl.BL_ExecuteParamSP("uspHomescreenTransactionsData", Trans);
                    string Jsondata = JsonConvert.SerializeObject(DDT);
                    return Ok(Jsondata);
                }
                if (Mode == "8" || Mode == "9" || Mode == "11")
                {
                    DDT = bl.BL_ExecuteParamSP("uspHomescreenData", Mode, Trans);
                    string Jsondata = JsonConvert.SerializeObject(DDT);
                    return Ok(Jsondata);
                }
                if (Mode == "10")
                {
                    DataSet dtbrdata = bl.BL_ExecuteParamSPDataset("uspHomescreenData", Mode, Trans);
                    string Jsondata = JsonConvert.SerializeObject(dtbrdata);
                    return Ok(Jsondata);
                }
                if (Mode == "12")
                {
                    DataTable dtbrdata = bl.BL_ExecuteParamSP("uspHomescreenData", Mode, Trans, ID);
                    return Ok(dtbrdata);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "homescreendraft/get", ex.Message);
            }
            return Ok();
        }

        [HttpGet]
        [Route("api/getfilterdates/get")]
        public IHttpActionResult GetFilterDates()
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetFilterDates");
                string val = JsonConvert.SerializeObject(DDT);
                return Ok(val);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "getfilterdates/get", ex.Message);
            }
                return Ok();
        }

        [HttpGet]
        [Route("api/quicaccessdocument/validate")]
        public IHttpActionResult validateQADocs(string TransID, string strDocID)
        {
            try
            {
                DataTable dtDoc = bl.BL_ExecuteParamSP("uspGetIDfromDocIDforQuickAccess", TransID, strDocID);
                List<SaveMessage> listProd = new List<SaveMessage>();
                for (int i = 0; i < dtDoc.Rows.Count; i++)
                {
                    listProd.Add(new SaveMessage()
                    {
                        Message = "ID Fetched",
                        MsgID = "0",
                        ID = HttpUtility.UrlEncode(clsEncryptDecrypt.Encrypt(dtDoc.Rows[0]["ID"].ToString())),
                    });
                    return Ok(listProd);
                }
                listProd.Add(new SaveMessage()
                {
                    Message = "No document found for this Doc ID",
                    MsgID = "1",
                });
                return Ok(listProd);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "quicaccessdocument/validate", ex.Message);
            }
            return Ok();
        }

        [HttpGet]
        [Route("api/singlemaster/get")]
        public IHttpActionResult GetSMData(string FormID, string Mode, string Name)
        {
            try
            {
                if (Mode == "3" || Mode == "4")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspManageSingleMaster", FormID, Mode, 0, Name);
                    List<SingleMasterModel> list = new List<SingleMasterModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new SingleMasterModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                            Active = DDT.Rows[i]["Active"].ToString(),
                            CBy = DDT.Rows[i]["UserName"].ToString(),
                            CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "singlemaster/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/singlemaster/save")]
        public IHttpActionResult Save(SingleMasterModel lstMaster)
        {
            try
            {
                if (lstMaster != null)
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageSingleMaster", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@FormID", lstMaster.FormID);
                    sqlCommand.Parameters.AddWithValue("@Mode", lstMaster.Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", lstMaster.ID);
                    sqlCommand.Parameters.AddWithValue("@Name", lstMaster.Name);
                    sqlCommand.Parameters.AddWithValue("@Active", lstMaster.Active);
                    sqlCommand.Parameters.AddWithValue("@CBy", lstMaster.UserID);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<SaveMessage> list = new List<SaveMessage>();
                    if (DDT.Columns.Count == 1)
                    {
                        //Success message
                        list.Add(new SaveMessage()
                        {
                            ID = DDT.Rows[0][0].ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        //Error message
                        list.Add(new SaveMessage()
                        {
                            ID = "0",
                            MsgID = "1",
                            Message = "Name already exists"
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "singlemaster/save", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/taxcompgift/get")]
        public IHttpActionResult GetTaxCompData(string FormID, string Mode, string Name)
        {
            try
            {
                if (Mode == "3" || Mode == "4")
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageTaxCompGift", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@FormID", FormID);
                    sqlCommand.Parameters.AddWithValue("@Mode", Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", 0);
                    sqlCommand.Parameters.AddWithValue("@Name", Name);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<SingleMasterModel> list = new List<SingleMasterModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new SingleMasterModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                            Value = DDT.Rows[i]["Value"].ToString(),
                            Active = DDT.Rows[i]["Active"].ToString(),
                            CBy = DDT.Rows[i]["UserName"].ToString(),
                            CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "taxcompgift/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/taxcompgift/save")]
        public IHttpActionResult SaveTaxComp(SingleMasterModel lstMaster)
        {
            try
            {
                if (lstMaster != null)
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageTaxCompGift", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@FormID", lstMaster.FormID);
                    sqlCommand.Parameters.AddWithValue("@Mode", lstMaster.Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", lstMaster.ID);
                    sqlCommand.Parameters.AddWithValue("@Name", lstMaster.Name);
                    sqlCommand.Parameters.AddWithValue("@Value", lstMaster.Value);
                    sqlCommand.Parameters.AddWithValue("@Active", lstMaster.Active);
                    sqlCommand.Parameters.AddWithValue("@CBy", lstMaster.UserID);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<SaveMessage> list = new List<SaveMessage>();
                    if (DDT.Columns.Count == 1)
                    {
                        //Success message
                        list.Add(new SaveMessage()
                        {
                            ID = DDT.Rows[0][0].ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        //Error message
                        list.Add(new SaveMessage()
                        {
                            ID = "0",
                            MsgID = "1",
                            Message = "Name already exists"
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "taxcompgift/save", ex.Message);
            }
            return Ok();
        }

        [HttpGet]
        [Route("api/taxmaster/get")]
        public IHttpActionResult GetTaxData(string Mode, string ID)
        {
            try
            {
                if (Mode == "1")
                {
                    DataSet DDT = bl.BL_ExecuteParamSPDataset("uspGetSetTaxMaster", Mode);
                    string TaxData = JsonConvert.SerializeObject(DDT);
                    return Ok(TaxData);
                }
                else if (Mode == "2")
                {
                    DataSet DDT = bl.BL_ExecuteParamSPDataset("uspGetSetTaxMaster", Mode, ID);
                    string TaxData = JsonConvert.SerializeObject(DDT);
                    return Ok(TaxData);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "taxmaster/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/taxmaster/save")]
        public IHttpActionResult SaveTaxMaster(Tax lstMaster)
        {
            List<SaveMessage> list = new List<SaveMessage>();
            try
            {
                if (lstMaster != null)
                {
                    DataTable dtTaxDetail = new DataTable();

                    dtTaxDetail.Columns.Add("TaxID", typeof(int));
                    dtTaxDetail.Columns.Add("TaxTypeID", typeof(int));
                    dtTaxDetail.Columns.Add("TaxCompID", typeof(int));
                    dtTaxDetail.Columns.Add("TaxRate", typeof(decimal));
                    dtTaxDetail.Columns.Add("AppOn", typeof(int));
                    dtTaxDetail.Columns.Add("PartOff", typeof(int));
                    dtTaxDetail.Columns.Add("CumulativeTax", typeof(decimal));
                    dtTaxDetail.Columns.Add("GSTTaxType", typeof(int));

                    foreach(TaxDetil taxDetil in lstMaster.lstTaxDetil)
                    {
                        DataRow dr = dtTaxDetail.NewRow();
                        dr["TaxID"] = 0;
                        dr["TaxTypeID"] = taxDetil.TaxTypeID;
                        dr["TaxCompID"] = taxDetil.TaxCompID;
                        dr["TaxRate"] = taxDetil.TaxPern;
                        dr["AppOn"] = taxDetil.ApponID;
                        dr["PartOff"] = taxDetil.Partoff;
                        dr["CumulativeTax"] = taxDetil.Cumulative;
                        dr["GSTTaxType"] = taxDetil.GSTTypeID;
                        dtTaxDetail.Rows.Add(dr);
                    }

                    bl.bl_Transaction(1);
                    DataTable DDT = bl.bl_ManageTrans("uspManageTax", lstMaster.Mode, bl.BL_nValidation(lstMaster.ID), lstMaster.Name,
                        bl.BL_dValidation(lstMaster.GST), bl.BL_dValidation(lstMaster.IGST),
                        bl.BL_dValidation(lstMaster.GUOM), bl.BL_dValidation(lstMaster.IUOM), dtTaxDetail, lstMaster.UserID, lstMaster.Active);
                    if (DDT.Columns.Count == 1)
                    {
                        bl.bl_Transaction(2);
                        list.Add(new SaveMessage()
                        {
                            ID = 0.ToString(),
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
                            Message = DDT.Rows[0][0].ToString()
                        });
                    }
                    return Ok(list);
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
                bl.BL_WriteErrorMsginLog("Tax Master", "SaveTaxMaster", ex.Message);
            }
            return Ok(list);
        }
        [HttpGet]
        [Route("api/bankaccount/get")]
        public IHttpActionResult GetBAData(string Mode, string Name)
        {
            try
            {
                if (Mode == "3" || Mode == "4")
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageBankAccount", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", 0);
                    sqlCommand.Parameters.AddWithValue("@AccountNo", Name);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<BankAccount> list = new List<BankAccount>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new BankAccount
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            AccountNo = DDT.Rows[i][1].ToString(),
                            AccountName = DDT.Rows[i][2].ToString(),
                            BankID = DDT.Rows[i][3].ToString(),
                            BankName = DDT.Rows[i][4].ToString(),
                            BranchName = DDT.Rows[i][5].ToString(),
                            IFSCCode = DDT.Rows[i][6].ToString(),
                            MICR = DDT.Rows[i][7].ToString(),
                            Active = DDT.Rows[i][8].ToString(),
                            SetDefault = DDT.Rows[i][9].ToString(),
                            CBy = DDT.Rows[i]["UserName"].ToString(),
                            CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "5")
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageBankAccount", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", 0);
                    sqlCommand.Parameters.AddWithValue("@AccountNo", Name);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<Salesman> list = new List<Salesman>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new Salesman
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "bankaccount/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/bankaccount/save")]
        public IHttpActionResult SaveBankAccont(BankAccount lstMaster)
        {
            try
            {
                if (lstMaster != null)
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageBankAccount", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", lstMaster.Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", lstMaster.ID);
                    sqlCommand.Parameters.AddWithValue("@AccountNo", lstMaster.AccountNo);
                    sqlCommand.Parameters.AddWithValue("@AccountName", lstMaster.AccountName);
                    sqlCommand.Parameters.AddWithValue("@BankID", lstMaster.BankID);
                    sqlCommand.Parameters.AddWithValue("@BranchName", lstMaster.BranchName);
                    sqlCommand.Parameters.AddWithValue("@IFSCCode", lstMaster.IFSCCode);
                    sqlCommand.Parameters.AddWithValue("@MICR", lstMaster.MICR);
                    sqlCommand.Parameters.AddWithValue("@Active", lstMaster.Active);
                    sqlCommand.Parameters.AddWithValue("@SetDefault", lstMaster.SetDefault);
                    sqlCommand.Parameters.AddWithValue("@CBy", lstMaster.UserID);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<SaveMessage> list = new List<SaveMessage>();
                    if (DDT.Columns.Count == 1)
                    {
                        //Success message
                        list.Add(new SaveMessage()
                        {
                            ID = DDT.Rows[0][0].ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        //Error message
                        list.Add(new SaveMessage()
                        {
                            ID = DDT.Rows[0][0].ToString(),
                            MsgID = "1",
                            Message = "Account No already exists"
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "bankaccount/save", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/financialaccount/get")]
        public IHttpActionResult GetFAData(string Mode, string Name,string BranchID = "0")
        {
            try
            {
                if (Mode == "3" || Mode == "6")
                {
                    DataTable DDT = bl.BL_ExecuteParamSP("uspManageFinancialAccount", Mode, 0, Name);
                    List<FinancialAccount> list = new List<FinancialAccount>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new FinancialAccount
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            AccountName = DDT.Rows[i]["AccountName"].ToString(),
                            FaGroup = DDT.Rows[i]["FaGroup"].ToString(),
                            OpenBalance = DDT.Rows[i]["OpenBalance"].ToString(),
                            SACCode = DDT.Rows[i]["SACCode"].ToString(),
                            PAN = DDT.Rows[i]["PAN"].ToString(),
                            FAType = DDT.Rows[i]["FAType"].ToString(),
                            Active = DDT.Rows[i]["Active"].ToString(),
                            CloseBal = DDT.Rows[i]["CloseBal"].ToString() + " " + DDT.Rows[i]["CrDr"].ToString(),
                            UserAccount = DDT.Rows[i]["UserAccount"].ToString(),
                            CBy = DDT.Rows[i]["UserName"].ToString(),
                            CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "5")
                {
                    DataTable DDT = bl.BL_ExecuteParamSP("uspManageFinancialAccount", Mode, 0, Name);
                    List<Salesman> list = new List<Salesman>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new Salesman
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            Name = DDT.Rows[i][1].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "7")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspManageFinancialAccount", Mode);
                    List<SingleMasterModel> list = new List<SingleMasterModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new SingleMasterModel
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            Name = DDT.Rows[i][1].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "8")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspManageFinancialAccount", Mode, Name, BranchID);
                    List<FinancialAccount> list = new List<FinancialAccount>();
                    if (DDT.Rows.Count > 0)
                    {
                        list.Add(new FinancialAccount
                        {
                            FAType = DDT.Rows[0][0].ToString(),
                            OpenBalance = DDT.Rows[0][1].ToString(),
                            CloseBal = DDT.Rows[0][2].ToString(),
                        });
                    }
                    else
                    {
                        list.Add(new FinancialAccount
                        {
                            FAType = "1",
                            OpenBalance = "0.00",
                            CloseBal = "0.00 Cr",
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "financialaccount/get", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/financialaccount/getalldata")]
        public IHttpActionResult GetFAallData(string Mode, string Name)
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspManageFinancialAccount", Mode, 0, Name);
                string dtjson = JsonConvert.SerializeObject(DDT);
                if (!string.IsNullOrEmpty(dtjson))
                {
                    List<FinancialAccount> jsonlist = JsonConvert.DeserializeObject<List<FinancialAccount>>(dtjson);
                    var data = from users in jsonlist
                               select
                                   new
                                   {
                                       ID = users.ID,
                                       AccountName = users.AccountName,
                                       OpenBalance = users.OpenBalance,
                                       FaGroup = users.FaGroup,
                                       SACCode = users.SACCode,
                                       PAN = users.PAN,
                                       FAType = users.FAType,
                                       UserAccount = users.UserAccount,
                                       CloseBal = users.CloseBal + " " + users.CrDr,
                                       Active = users.Active,
                                       CBy = users.UserName,
                                       CDate = users.LastActionTime
                                   };
                    return Ok(data);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "financialaccount/getalldata", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/financialaccount/save")]
        public IHttpActionResult SaveFinancialAccont(FinancialAccount lstMaster)
        {
            try
            {
                if (lstMaster != null)
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageFinancialAccount", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", lstMaster.Mode);
                    sqlCommand.Parameters.AddWithValue("@FAID", lstMaster.ID);
                    sqlCommand.Parameters.AddWithValue("@AccountName", lstMaster.AccountName);
                    sqlCommand.Parameters.AddWithValue("@AccountGroup", lstMaster.FaGroup);
                    sqlCommand.Parameters.AddWithValue("@OpeningBalance", lstMaster.OpenBalance);
                    sqlCommand.Parameters.AddWithValue("@SACCode", lstMaster.SACCode);
                    sqlCommand.Parameters.AddWithValue("@PANNumber", lstMaster.PAN);
                    sqlCommand.Parameters.AddWithValue("@FATypeID", lstMaster.FAType);
                    sqlCommand.Parameters.AddWithValue("@UserAccount", lstMaster.UserAccount);
                    sqlCommand.Parameters.AddWithValue("@Active", lstMaster.Active);
                    sqlCommand.Parameters.AddWithValue("@CBy", lstMaster.UserID);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<SaveMessage> list = new List<SaveMessage>();
                    if (DDT.Columns.Count == 1)
                    {
                        //Success message
                        list.Add(new SaveMessage()
                        {
                            ID = DDT.Rows[0][0].ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        //Error message
                        list.Add(new SaveMessage()
                        {
                            ID = "0",
                            MsgID = "1",
                            Message = DDT.Rows[0][0].ToString()
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "financialaccount/save", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/financialaccountgroup/get")]
        public IHttpActionResult GetFAGrpData(string Mode, string Name)
        {
            try
            {
                if (Mode == "3" || Mode == "4")
                {
                    DataTable DDT = bl.BL_ExecuteParamSP("uspManageFinancialAccountGroup", Mode, 0, Name);
                    List<FinancialAccountGroup> list = new List<FinancialAccountGroup>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new FinancialAccountGroup
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            FAGrpName = DDT.Rows[i][1].ToString(),
                            TypeID = DDT.Rows[i][2].ToString(),
                            TypeName = DDT.Rows[i][3].ToString(),
                            ParentGrp = DDT.Rows[i][4].ToString(),
                            Active = DDT.Rows[i][5].ToString(),
                            UserAccount = DDT.Rows[i][6].ToString(),
                            CBy = DDT.Rows[i]["UserName"].ToString(),
                            CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "5" || Mode == "6")
                {
                    DataTable DDT = bl.BL_ExecuteParamSP("uspManageFinancialAccountGroup", Mode, 0, Name);
                    List<Salesman> list = new List<Salesman>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new Salesman
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            Name = DDT.Rows[i][1].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "financialaccountgroup/get", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/financialaccountgroup/getalldata")]
        public IHttpActionResult GetFAGrpAllData(string Mode, string Name)
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspManageFinancialAccountGroup", Mode, 0, Name);
                string dtjson = JsonConvert.SerializeObject(DDT);
                if (!string.IsNullOrEmpty(dtjson))
                {
                    List<FinancialAccountGroup> jsonlist = JsonConvert.DeserializeObject<List<FinancialAccountGroup>>(dtjson);
                    var data = from users in jsonlist
                               select
                                   new
                                   {
                                       ID = users.ID,
                                       FAGrpName = users.FAGrpName,
                                       TypeID = users.TypeID,
                                       TypeName = users.TypeName,
                                       ParentGrp = users.ParentGrp,
                                       Active = users.Active,
                                       UserAccount = users.UserAccount,
                                       CBy = users.UserName,
                                       CDate = users.LastActionTime
                                   };
                    return Ok(data);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "financialaccountgroup/getalldata", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/financialaccountgroup/save")]
        public IHttpActionResult SaveFinancialAccontGroup(FinancialAccountGroup lstMaster)
        {
            try
            {
                if (lstMaster != null)
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();

                    SqlCommand sqlCommand = new SqlCommand("uspManageFinancialAccountGroup", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", lstMaster.Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", lstMaster.ID);
                    sqlCommand.Parameters.AddWithValue("@AccountGroupName", lstMaster.FAGrpName);
                    sqlCommand.Parameters.AddWithValue("@ParentGroup", lstMaster.ParentGrp);
                    sqlCommand.Parameters.AddWithValue("@TypeID", lstMaster.TypeID);
                    sqlCommand.Parameters.AddWithValue("@UserGroup", lstMaster.UserAccount);
                    sqlCommand.Parameters.AddWithValue("@LevelID", lstMaster.LevelID);
                    sqlCommand.Parameters.AddWithValue("@Active", lstMaster.Active);
                    sqlCommand.Parameters.AddWithValue("@CBy", lstMaster.UserID);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<SaveMessage> list = new List<SaveMessage>();
                    if (DDT.Columns.Count == 1)
                    {
                        //Success message
                        list.Add(new SaveMessage()
                        {
                            ID = DDT.Rows[0][0].ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        //Error message
                        list.Add(new SaveMessage()
                        {
                            ID = DDT.Rows[0][0].ToString(),
                            MsgID = "1",
                            Message = "Account No already exists"
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "financialaccountgroup/save", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/faopening/get")]
        public IHttpActionResult GetfaopeingData(string Mode, string ID)
        {
            try
            {
                if (Mode == "1")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspgetsetFAAccOpening", Mode);
                    string Masterdata = JsonConvert.SerializeObject(DDT);
                    return Ok(Masterdata);
                }
                else if (Mode == "2")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspgetsetFAAccOpening", Mode, ID);
                    string Masterdata = JsonConvert.SerializeObject(DDT);
                    return Ok(Masterdata);
                }
                else if (Mode == "3")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspgetsetFAAccOpening", Mode, ID);
                    string Masterdata = JsonConvert.SerializeObject(DDT);
                    return Ok(Masterdata);
                }
                else if (Mode == "4")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspgetsetFAAccOpening", Mode);
                    string Masterdata = JsonConvert.SerializeObject(DDT);
                    return Ok(Masterdata);
                }
                else if (Mode == "5")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspgetsetFAAccOpening", Mode);
                    List<SingleMasterModel> list = new List<SingleMasterModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new SingleMasterModel
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            Name = DDT.Rows[i][1].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "faopening/get", ex.Message);
            }
            return Ok();
        }
        //FAOpening
        [HttpPost]
        [Route("api/faopening/save")]
        public IHttpActionResult Savedocumentseries(FAOpening lstMaster)
        {
            try
            {
                List<SaveMessage> list = new List<SaveMessage>();
                DataTable dtFAAccData = new DataTable();
                DataColumn column = new DataColumn("ID");
                column.DataType = System.Type.GetType("System.Int32");
                column.AutoIncrement = true;
                column.AutoIncrementSeed = 1;
                column.AutoIncrementStep = 1;
                dtFAAccData.Columns.Add(column);
                dtFAAccData.Columns.Add("FAID", typeof(int));
                dtFAAccData.Columns.Add("FAType", typeof(int));
                dtFAAccData.Columns.Add("OpeningValue", typeof(decimal));
                foreach (clsAccOpeningValues item in lstMaster.lstAccOpeningvalues)
                {
                    DataRow dr = dtFAAccData.NewRow();
                    dr[1] = item.FAID;
                    dr[2] = item.FAType;
                    dr[3] = item.OpeningValue;
                    dtFAAccData.Rows.Add(dr);
                }
                bl.bl_Transaction(1);
                DataTable dt = bl.bl_ManageTrans("uspSaveFAAccOpening", lstMaster.Mode, !string.IsNullOrEmpty(lstMaster.ID) ? lstMaster.ID : "0", lstMaster.BranchID, lstMaster.Period, lstMaster.UserID,
                    dtFAAccData);
                if (dt.Columns.Count > 1)
                {
                    bl.bl_Transaction(3);
                    list.Add(new SaveMessage
                    {
                        MsgID = "1",
                        Message = dt.Rows[0][0].ToString()
                    });
                    return Ok(list);
                }
                bl.bl_Transaction(2);
                list.Add(new SaveMessage
                {
                    MsgID = "0",
                    Message = "Saved successfully"
                });
                return Ok(list);
            }
           catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "faopening/save", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/chequebook/get")]
        public IHttpActionResult GetCBData(string Mode, string Name)
        {
            try
            {
                if (Mode == "5")
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageChequeBook", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", 0);
                    sqlCommand.Parameters.AddWithValue("@ChequeBookreferNo", Name);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<Chequebook> list = new List<Chequebook>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new Chequebook
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            Refno = DDT.Rows[i][1].ToString(),
                            StartingNo = DDT.Rows[i][2].ToString(),
                            NoofLeaves = DDT.Rows[i][3].ToString(),
                            BankAccID = DDT.Rows[i][4].ToString(),
                            BankAccName = DDT.Rows[i][5].ToString(),
                            Active = DDT.Rows[i][6].ToString(),
                            CBy = DDT.Rows[i]["UserName"].ToString(),
                            CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "6" || Mode == "7" || Mode == "8")
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageChequeBook", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", Name);
                    sqlCommand.Parameters.AddWithValue("@ChequeBookreferNo", Name);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<ChequebookDetil> list = new List<ChequebookDetil>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new ChequebookDetil
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            ChequeNo = DDT.Rows[i]["Name"].ToString(),
                            Status = DDT.Rows[i]["Status"].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "chequebook/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/chequebook/save")]
        public IHttpActionResult SaveCB(Chequebook lstMaster)
        {
            try
            {
                if (lstMaster != null)
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageChequeBook", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", lstMaster.Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", lstMaster.ID);
                    sqlCommand.Parameters.AddWithValue("@ChequeBookreferNo", lstMaster.Refno);
                    sqlCommand.Parameters.AddWithValue("@StartingChequeNo", lstMaster.StartingNo);
                    sqlCommand.Parameters.AddWithValue("@NoofLeaves", lstMaster.NoofLeaves);
                    sqlCommand.Parameters.AddWithValue("@BankAccountID", lstMaster.BankAccID);
                    sqlCommand.Parameters.AddWithValue("@Active", lstMaster.Active);
                    sqlCommand.Parameters.AddWithValue("@CBy", lstMaster.UserID);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<SaveMessage> list = new List<SaveMessage>();
                    if (DDT.Columns.Count == 1)
                    {
                        var ID = Convert.ToInt32(DDT.Rows[0][0].ToString());
                        var IsDeleted = false;
                        foreach (ChequebookDetil item in lstMaster.CBDetails)
                        {
                            SqlConnection sqlConnection1 = new SqlConnection(connectionString);
                            sqlConnection1.Open();
                            SqlCommand sqlCommand1 = new SqlCommand("uspManageChequeBook", sqlConnection1);
                            sqlCommand1.CommandType = CommandType.StoredProcedure;
                            sqlCommand1.Parameters.AddWithValue("@Mode", "3");
                            sqlCommand1.Parameters.AddWithValue("@ID", ID);
                            sqlCommand1.Parameters.AddWithValue("@ChequeBookreferNo", item.ChequeNo);
                            sqlCommand1.Parameters.AddWithValue("@StartingChequeNo", item.Status);
                            sqlCommand1.Parameters.AddWithValue("@NoofLeaves", IsDeleted ? 1 : 0);
                            DDT = new DataTable();
                            SqlDataAdapter SDA1 = new SqlDataAdapter(sqlCommand1);
                            SDA1.Fill(DDT);
                            sqlConnection1.Close();
                            IsDeleted = true;
                        }
                        //Success message
                        list.Add(new SaveMessage()
                        {
                            ID = ID.ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        //Error message
                        list.Add(new SaveMessage()
                        {
                            ID = DDT.Rows[0][0].ToString(),
                            MsgID = "1",
                            Message = "Name already exists"
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "chequebook/save", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/salesman/get")]
        public IHttpActionResult GetSalesman(string Mode, string Name)
        {
            try
            {
                if (Mode == "3" || Mode == "4")
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageSalesman", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", 0);
                    sqlCommand.Parameters.AddWithValue("@Name", Name);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<Salesman> list = new List<Salesman>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new Salesman
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                            DOB = !string.IsNullOrEmpty(DDT.Rows[i]["DOB"].ToString()) ? Convert.ToDateTime(DDT.Rows[i]["DOB"]).ToString("yyy-MM-dd") : "",
                            DOJ = !string.IsNullOrEmpty(DDT.Rows[i]["DOJ"].ToString()) ? Convert.ToDateTime(DDT.Rows[i]["DOJ"]).ToString("yyy-MM-dd") : "",
                            MobileNo = DDT.Rows[i]["MobileNo"].ToString(),
                            AadharNo = DDT.Rows[i]["AadharNo"].ToString(),
                            PANNumber = DDT.Rows[i]["PANNumber"].ToString(),
                            Address = DDT.Rows[i]["Address"].ToString(),
                            SalesmanGroupID = DDT.Rows[i]["SalesmanGroupID"].ToString(),
                            SalesmanGroupName = DDT.Rows[i]["SalesmanGroupName"].ToString(),
                            Active = DDT.Rows[i]["Active"].ToString(),
                            CBy = DDT.Rows[i]["UserName"].ToString(),
                            CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "5")
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageSalesman", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", 0);
                    sqlCommand.Parameters.AddWithValue("@Name", Name);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<Salesman> list = new List<Salesman>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new Salesman
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "salesman/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/salesman/save")]
        public IHttpActionResult SaveSalesman(Salesman lstMaster)
        {
            try
            {
                if (lstMaster != null)
                {
                    string DOB = !string.IsNullOrEmpty(lstMaster.DOB) ? Convert.ToDateTime(lstMaster.DOB).ToString("yyy-MM-dd") : null;
                    string DOJ = !string.IsNullOrEmpty(lstMaster.DOJ) ? Convert.ToDateTime(lstMaster.DOJ).ToString("yyy-MM-dd") : null;
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageSalesman", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", lstMaster.Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", lstMaster.ID);
                    sqlCommand.Parameters.AddWithValue("@Name", lstMaster.Name);
                    sqlCommand.Parameters.AddWithValue("@DOB", DOB);
                    sqlCommand.Parameters.AddWithValue("@DOJ", DOJ);
                    sqlCommand.Parameters.AddWithValue("@MobileNo", lstMaster.MobileNo);
                    sqlCommand.Parameters.AddWithValue("@AadharNo", lstMaster.AadharNo);
                    sqlCommand.Parameters.AddWithValue("@PANNumber", lstMaster.PANNumber);
                    sqlCommand.Parameters.AddWithValue("@Address", lstMaster.Address);
                    sqlCommand.Parameters.AddWithValue("@SalesmanGroupID", lstMaster.SalesmanGroupID);
                    sqlCommand.Parameters.AddWithValue("@Active", lstMaster.Active);
                    sqlCommand.Parameters.AddWithValue("@UserID", lstMaster.UserID);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<SaveMessage> list = new List<SaveMessage>();
                    if (DDT.Columns.Count == 1)
                    {
                        //Success message
                        list.Add(new SaveMessage()
                        {
                            ID = DDT.Rows[0][0].ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        //Error message
                        list.Add(new SaveMessage()
                        {
                            ID = "1",
                            MsgID = "1",
                            Message = DDT.Rows[0][0].ToString()
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "salesman/save", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/branchoffice/get")]
        public IHttpActionResult GetBranchOffice(string Mode, string Name)
        {
            try
            {
                if (Mode == "3" || Mode == "4")
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageBranchOffice", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", Name);
                    sqlCommand.Parameters.AddWithValue("@Code", Name);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<BranchOffice> list = new List<BranchOffice>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new BranchOffice
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Code = DDT.Rows[i]["Code"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                            Billadd1 = DDT.Rows[i]["Billadd1"].ToString(),
                            Billadd2 = DDT.Rows[i]["Billadd2"].ToString(),
                            Billadd3 = DDT.Rows[i]["Billadd3"].ToString(),
                            ContactPerson = DDT.Rows[i]["ContactPerson"].ToString(),
                            Ph1 = DDT.Rows[i]["Ph1"].ToString(),
                            Mob1 = DDT.Rows[i]["Mob1"].ToString(),
                            Email = DDT.Rows[i]["Email"].ToString(),
                            StateID = DDT.Rows[i]["StateID"].ToString(),
                            GSTIN = DDT.Rows[i]["GSTIN"].ToString(),
                            Active = DDT.Rows[i]["Active"].ToString(),
                            UserID = DDT.Rows[i]["CBy"].ToString(),
                            CBy = DDT.Rows[i]["UserName"].ToString(),
                            CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                            StateName = DDT.Rows[i]["StateName"].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "5")
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageBranchOffice", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", 0);
                    sqlCommand.Parameters.AddWithValue("@Name", Name);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<Salesman> list = new List<Salesman>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new Salesman
                        {
                            ID = DDT.Rows[i]["StateID"].ToString(),
                            Name = DDT.Rows[i]["StateName"].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "branchoffice/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/branchoffice/save")]
        public IHttpActionResult Savebranchoffice(BranchOffice lstMaster)
        {
            try
            {
                if (lstMaster != null)
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageBranchOffice", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", lstMaster.Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", lstMaster.ID);
                    sqlCommand.Parameters.AddWithValue("@Code", lstMaster.Code);
                    sqlCommand.Parameters.AddWithValue("@Name", lstMaster.Name);
                    sqlCommand.Parameters.AddWithValue("@Billadd1", lstMaster.Billadd1);
                    sqlCommand.Parameters.AddWithValue("@Billadd2", lstMaster.Billadd2);
                    sqlCommand.Parameters.AddWithValue("@Billadd3", lstMaster.Billadd3);
                    sqlCommand.Parameters.AddWithValue("@ContactPerson", lstMaster.ContactPerson);
                    sqlCommand.Parameters.AddWithValue("@Ph1", lstMaster.Ph1);
                    sqlCommand.Parameters.AddWithValue("@Mob1", lstMaster.Mob1);
                    sqlCommand.Parameters.AddWithValue("@Email", lstMaster.Email);
                    sqlCommand.Parameters.AddWithValue("@StateID", lstMaster.StateID);
                    sqlCommand.Parameters.AddWithValue("@GSTIN", lstMaster.GSTIN);
                    sqlCommand.Parameters.AddWithValue("@Active", lstMaster.Active);
                    sqlCommand.Parameters.AddWithValue("@UserID", lstMaster.UserID);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<SaveMessage> list = new List<SaveMessage>();
                    if (DDT.Columns.Count == 1)
                    {
                        //Success message
                        list.Add(new SaveMessage()
                        {
                            ID = DDT.Rows[0][0].ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        //Error message
                        list.Add(new SaveMessage()
                        {
                            ID = "0",
                            MsgID = "1",
                            Message = DDT.Rows[0][0].ToString()
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "branchoffice/save", ex.Message);
            }
            return Ok();
        }
        [Route("api/vehicle/get")]
        public IHttpActionResult Getvehicle(string Mode, string Name)
        {
            try
            {
                if (Mode == "3" || Mode == "4")
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageVehicle", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", 0);
                    sqlCommand.Parameters.AddWithValue("@VehicleNo", Name);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<Vehicle> list = new List<Vehicle>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new Vehicle
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            VehicleNo = DDT.Rows[i]["VehicleNo"].ToString(),
                            VehicleName = DDT.Rows[i]["VehicleName"].ToString(),
                            DOPurchase = !string.IsNullOrEmpty(DDT.Rows[i]["DOPurchase"].ToString()) ? Convert.ToDateTime(DDT.Rows[i]["DOPurchase"]).ToString("yyy-MM-dd") : "",
                            InsuranceDate = !string.IsNullOrEmpty(DDT.Rows[i]["InsuranceDate"].ToString()) ? Convert.ToDateTime(DDT.Rows[i]["InsuranceDate"]).ToString("yyy-MM-dd") : "",
                            InsuranceExpire = !string.IsNullOrEmpty(DDT.Rows[i]["InsuranceExpire"].ToString()) ? Convert.ToDateTime(DDT.Rows[i]["InsuranceExpire"]).ToString("yyy-MM-dd") : "",
                            FCDate = !string.IsNullOrEmpty(DDT.Rows[i]["FCDate"].ToString()) ? Convert.ToDateTime(DDT.Rows[i]["FCDate"]).ToString("yyy-MM-dd") : "",
                            Active = DDT.Rows[i]["Active"].ToString(),
                            UserID = DDT.Rows[i]["CBy"].ToString(),
                            CBy = DDT.Rows[i]["UserName"].ToString(),
                            CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "vehicle/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/vehicle/save")]
        public IHttpActionResult Savevehicle(Vehicle lstMaster)
        {
            try
            {
                if (lstMaster != null)
                {
                    string DOPurchase = !string.IsNullOrEmpty(lstMaster.DOPurchase) ? Convert.ToDateTime(lstMaster.DOPurchase).ToString("yyy-MM-dd") : null;
                    string InsuranceDate = !string.IsNullOrEmpty(lstMaster.InsuranceDate) ? Convert.ToDateTime(lstMaster.InsuranceDate).ToString("yyy-MM-dd") : null;
                    string InsuranceExpire = !string.IsNullOrEmpty(lstMaster.InsuranceExpire) ? Convert.ToDateTime(lstMaster.InsuranceExpire).ToString("yyy-MM-dd") : null;
                    string FCDate = !string.IsNullOrEmpty(lstMaster.FCDate) ? Convert.ToDateTime(lstMaster.FCDate).ToString("yyy-MM-dd") : null;
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageVehicle", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", lstMaster.Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", lstMaster.ID);
                    sqlCommand.Parameters.AddWithValue("@VehicleNo", lstMaster.VehicleNo);
                    sqlCommand.Parameters.AddWithValue("@VehicleName", lstMaster.VehicleName);
                    sqlCommand.Parameters.AddWithValue("@DOPurchase", DOPurchase);
                    sqlCommand.Parameters.AddWithValue("@InsuranceDate", InsuranceDate);
                    sqlCommand.Parameters.AddWithValue("@InsuranceExpire", InsuranceExpire);
                    sqlCommand.Parameters.AddWithValue("@FCDate", FCDate);
                    sqlCommand.Parameters.AddWithValue("@Active", lstMaster.Active);
                    sqlCommand.Parameters.AddWithValue("@UserID", lstMaster.UserID);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<SaveMessage> list = new List<SaveMessage>();
                    if (DDT.Columns.Count == 1)
                    {
                        //Success message
                        list.Add(new SaveMessage()
                        {
                            ID = DDT.Rows[0][0].ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        //Error message
                        list.Add(new SaveMessage()
                        {
                            ID = "0",
                            MsgID = "1",
                            Message = DDT.Rows[0][0].ToString()
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "vehicle/save", ex.Message);
            }
            return Ok();
        }
        [Route("api/service/get")]
        public IHttpActionResult Getservice(string Mode, string Name)
        {
            try
            {
                if (Mode == "3" || Mode == "4")
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageService", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", 0);
                    sqlCommand.Parameters.AddWithValue("@Name", Name);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<Service> list = new List<Service>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new Service
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                            TaxID = DDT.Rows[i]["TaxID"].ToString(),
                            TaxName = DDT.Rows[i]["TaxName"].ToString(),
                            SACCode = DDT.Rows[i]["SACCode"].ToString(),
                            Inwardprice = DDT.Rows[i]["Inwardprice"].ToString(),
                            Outwardprice = DDT.Rows[i]["Outwardprice"].ToString(),
                            Active = DDT.Rows[i]["Active"].ToString(),
                            CBy = DDT.Rows[i]["UserName"].ToString(),
                            CDate = DDT.Rows[i]["LastActionTime"].ToString(),

                        });
                    }
                    return Ok(list);
                }
                if (Mode == "5")
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageService", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", 0);
                    sqlCommand.Parameters.AddWithValue("@Name", Name);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<Service> list = new List<Service>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new Service
                        {
                            ID = DDT.Rows[i]["TaxID"].ToString(),
                            Name = DDT.Rows[i]["TaxName"].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "service/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/service/save")]
        public IHttpActionResult Saveservice(Service lstMaster)
        {
            try
            {
                if (lstMaster != null)
                {
                    SqlConnection sqlConnection = new SqlConnection(connectionString);
                    sqlConnection.Open();
                    SqlCommand sqlCommand = new SqlCommand("uspManageService", sqlConnection);
                    sqlCommand.CommandType = CommandType.StoredProcedure;
                    sqlCommand.Parameters.AddWithValue("@Mode", lstMaster.Mode);
                    sqlCommand.Parameters.AddWithValue("@ID", lstMaster.ID);
                    sqlCommand.Parameters.AddWithValue("@Name", lstMaster.Name);
                    sqlCommand.Parameters.AddWithValue("@TaxID", lstMaster.TaxID);
                    sqlCommand.Parameters.AddWithValue("@SACCode", lstMaster.SACCode);
                    sqlCommand.Parameters.AddWithValue("@Inwardprice", !string.IsNullOrEmpty(lstMaster.Inwardprice) ? lstMaster.Inwardprice : "0");
                    sqlCommand.Parameters.AddWithValue("@Outwardprice", !string.IsNullOrEmpty(lstMaster.Outwardprice) ? lstMaster.Outwardprice : "0");
                    sqlCommand.Parameters.AddWithValue("@Active", lstMaster.Active);
                    sqlCommand.Parameters.AddWithValue("@UserID", lstMaster.UserID);
                    DataTable DDT = new DataTable();
                    SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                    SDA.Fill(DDT);
                    sqlConnection.Close();
                    List<SaveMessage> list = new List<SaveMessage>();
                    if (DDT.Columns.Count == 1)
                    {
                        //Success message
                        list.Add(new SaveMessage()
                        {
                            ID = DDT.Rows[0][0].ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        //Error message
                        list.Add(new SaveMessage()
                        {
                            ID = "0",
                            MsgID = "1",
                            Message = DDT.Rows[0][0].ToString()
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "service/save", ex.Message);
            }
            return Ok();
        }
        [Route("api/colorsettings/get")]
        public IHttpActionResult Getcolors(string Mode, string Name)
        {
            try
            {
                if (Mode == "1")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspManageColorSettings", 1, Name);
                    List<ColorSettings> list = new List<ColorSettings>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new ColorSettings
                        {
                            MenuHeader = DDT.Rows[i]["MenuHeader"].ToString(),
                            AddButton = DDT.Rows[i]["AddButton"].ToString(),
                            SaveButton = DDT.Rows[i]["SaveButton"].ToString(),
                            ClearButton = DDT.Rows[i]["ClearButton"].ToString(),
                            CloseButton = DDT.Rows[i]["CloseButton"].ToString(),
                            PDFButton = DDT.Rows[i]["PDFButton"].ToString(),

                            EditButton = DDT.Rows[i]["EditButton"].ToString(),
                            CancelButton = DDT.Rows[i]["CancelButton"].ToString(),
                            VariantButton = DDT.Rows[i]["VariantButton"].ToString(),

                            PreviewButton = DDT.Rows[i]["PreviewButton"].ToString(),
                            PopupHeader = DDT.Rows[i]["PopupHeader"].ToString(),
                            PopupFooter = DDT.Rows[i]["PopupFooter"].ToString(),
                            ConfirmPopupYes = DDT.Rows[i]["ConfirmPopupYes"].ToString(),
                            ConfirmPopupNo = DDT.Rows[i]["ConfirmPopupNo"].ToString(),
                            SubMenuColor = DDT.Rows[i]["SubMenuColor"].ToString(),
                            MenuColor = DDT.Rows[i]["MenuColor"].ToString(),
                            CompanyNameColor = DDT.Rows[i]["CompanyNameColor"].ToString(),
                            GridHeaderBackGround = DDT.Rows[i]["GridHeaderBackGround"].ToString(),
                            GridHeaderTextColor = DDT.Rows[i]["GridHeaderTextColor"].ToString(),
                            PopupHeaderText = DDT.Rows[i]["PopupHeaderText"].ToString(),
                            DraftButton = DDT.Rows[i]["DraftButton"].ToString(),

                            AutocompleteBG = DDT.Rows[i]["AutocompleteBG"].ToString(),
                            AutocompleteLine1 = DDT.Rows[i]["AutocompleteLine1"].ToString(),
                            AutocompleteLine2 = DDT.Rows[i]["AutocompleteLine2"].ToString(),
                            ButtonTextColor = DDT.Rows[i]["ButtonTextColor"].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "colorsettings/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/colorsettings/save")]
        public IHttpActionResult Savecolor(ColorSettings lstMaster)
        {
            try
            {
                if (lstMaster != null)
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspManageColorSettings", 2, lstMaster.ThemeID, lstMaster.UID, lstMaster.MenuHeader, lstMaster.AddButton, lstMaster.SaveButton, lstMaster.ClearButton,
                                lstMaster.CloseButton, lstMaster.PDFButton, lstMaster.PreviewButton, lstMaster.PopupHeader, lstMaster.PopupFooter,
                                lstMaster.ConfirmPopupYes, lstMaster.ConfirmPopupNo, lstMaster.SubMenuColor, lstMaster.MenuColor, lstMaster.CompanyNameColor,
                                lstMaster.GridHeaderBackGround, lstMaster.GridHeaderTextColor, lstMaster.PopupHeaderText, lstMaster.DraftButton,
                                lstMaster.AutocompleteBG, lstMaster.AutocompleteLine1, lstMaster.AutocompleteLine2, lstMaster.ButtonTextColor,
                                lstMaster.EditButton, lstMaster.CancelButton, lstMaster.VariantButton);
                    List<SaveMessage> list = new List<SaveMessage>();
                    if (DDT.Columns.Count == 1)
                    {
                        //Success message
                        list.Add(new SaveMessage()
                        {
                            ID = DDT.Rows[0][0].ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        //Error message
                        list.Add(new SaveMessage()
                        {
                            ID = "0",
                            MsgID = "1",
                            Message = "Name already exists"
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "colorsettings/save", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/applicationconfig/get")]
        public IHttpActionResult Getappconfig(string Mode, string Name)
        {
            try
            {
                if (Mode == "1")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspManageApplicationConfig", 1);
                    List<ApplicationConfig> list = new List<ApplicationConfig>();
                    List<PaymodeAppconfig> pmlist = new List<PaymodeAppconfig>();
                    DataTable dtPM = bl.BL_ExecuteParamSP("uspManageApplicationConfig", 4);
                    for (int i = 0; i < dtPM.Rows.Count; i++)
                    {
                        pmlist.Add(new PaymodeAppconfig
                        {
                            ID = dtPM.Rows[i][0].ToString(),
                            Name = dtPM.Rows[i][1].ToString(),
                            Active = dtPM.Rows[i][2].ToString(),
                            Order = dtPM.Rows[i][3].ToString(),
                            Code = dtPM.Rows[i][4].ToString(),
                            TypeID = dtPM.Rows[i][5].ToString(),
                        });
                    }
                    List<PasswordSettingAppconfig> lstpwd = new List<PasswordSettingAppconfig>();
                    DataTable dtPWD = bl.BL_ExecuteParamSP("uspManageApplicationConfig", 7);
                    for (int i = 0; i < dtPWD.Rows.Count; i++)
                    {
                        lstpwd.Add(new PasswordSettingAppconfig
                        {
                            ID = dtPWD.Rows[i][0].ToString(),
                            Name = dtPWD.Rows[i][1].ToString(),
                            Active = dtPWD.Rows[i][3].ToString(),
                            Passwords = clsEncryptDecrypt.Decrypt(dtPWD.Rows[i][2].ToString()),
                        });
                    }
                    //lstConfigPasswords
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new ApplicationConfig
                        {
                            CaseType = DDT.Rows[i]["CaseType"].ToString(),
                            Confirmpopup = DDT.Rows[i]["Confirmpopup"].ToString(),
                            Roundoff = DDT.Rows[i]["Roundoff"].ToString(),
                            RoundoffValue = DDT.Rows[i]["RoundoffValue"].ToString(),
                            SMTPHost = DDT.Rows[i]["SMTPHost"].ToString(),
                            EMail = DDT.Rows[i]["EMail"].ToString(),
                            Password = clsEncryptDecrypt.Decrypt(DDT.Rows[i]["Password"].ToString()),
                            DecimalValues = DDT.Rows[i]["DecimalValues"].ToString(),
                            Showallstatus = DDT.Rows[i]["Showallstatus"].ToString(),
                            ItemOrderby = DDT.Rows[i]["ItemOrderby"].ToString(),
                            EnableReturnPrice = DDT.Rows[i]["EnableReturnPrice"].ToString(),
                            VisaPern = DDT.Rows[i]["VisaPern"].ToString(),
                            DefaultCustID = DDT.Rows[i]["DefaultCustID"].ToString(),
                            UPIID = DDT.Rows[i]["UPIID"].ToString(),
                            UPIName = DDT.Rows[i]["UPIName"].ToString(),
                            WriteoffAmt = DDT.Rows[i]["WriteoffAmt"].ToString(),
                            AllSalesmanInvoice = DDT.Rows[i]["AllSalesmanInvoice"].ToString(),
                            AllowPrint = DDT.Rows[i]["AllowPrint"].ToString(),
                            ApplySchemeinQuotation = DDT.Rows[i]["ApplySchemeinQuotation"].ToString(),
                            SelectinvoiceinSR = DDT.Rows[i]["SelectinvoiceinSR"].ToString(),
                            ClearConfirmpopup = DDT.Rows[i]["ClearConfirmpopup"].ToString(),
                            CloseConfirmpopup = DDT.Rows[i]["CloseConfirmpopup"].ToString(),
                            BackupPath = DDT.Rows[i]["BackupPath"].ToString(),
                            InvoiceStockOnlyProduct = DDT.Rows[i]["InvoiceStockOnlyProduct"].ToString(),
                            PurchaseOneView = DDT.Rows[i]["PurchaseOneView"].ToString(),
                            SalesOneView = DDT.Rows[i]["SalesOneView"].ToString(),
                            FilterDate = DDT.Rows[i]["FilterDate"].ToString(),
                            ItemsperPage = DDT.Rows[i]["ItemsperPage"].ToString(),
                            Invoiceallowduplicateitem = DDT.Rows[i]["Invoiceallowduplicateitem"].ToString(),
                            CommonAgeingCreditDays = DDT.Rows[i]["CommonAgeingCreditDays"].ToString(),
                            RestrictBlocklistinInvoice = DDT.Rows[i]["RestrictBlocklistinInvoice"].ToString(),
                            RetainDate = DDT.Rows[i]["RetainDate"].ToString(),
                            BeatMandatoryinCustomer = DDT.Rows[i]["BeatMandatoryinCustomer"].ToString(),
                            DraftAutoSaveTimeInterval = DDT.Rows[i]["DraftAutoSaveTimeInterval"].ToString(),
                            HomePeriod = DDT.Rows[i]["HomePeriod"].ToString(),
                            AutoRefresh = DDT.Rows[i]["AutoRefresh"].ToString(),
                            CTPAmount = DDT.Rows[i]["CTPAmount"].ToString(),
                            CTPPoint = DDT.Rows[i]["CTPPoint"].ToString(),
                            CTPPerPointAmount = DDT.Rows[i]["CTPPerPointAmount"].ToString(),
                            UpdateVendorinProduct = DDT.Rows[i]["UpdateVendorinProduct"].ToString(),
                            Radius = DDT.Rows[i]["Radius"].ToString(),
                            SpotSalesPriceMode = DDT.Rows[i]["SpotSalesPriceMode"].ToString(),
                            lstPaymode = pmlist,
                            lstConfigPasswords = lstpwd
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "3")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspManageApplicationConfig", Mode);
                    List<SingleMasterModel> list = new List<SingleMasterModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new SingleMasterModel
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            Name = DDT.Rows[i][1].ToString(),
                        });
                    }
                    return Ok(list);
                }
                else
                {
                    DataTable DDT = bl.BL_ExecuteParamSP("uspManageApplicationConfig", Mode);
                    List<PaymodeAppconfig> pmlist = new List<PaymodeAppconfig>();
                    List<PasswordSettingAppconfig> lstpwd = new List<PasswordSettingAppconfig>();
                    List<ApplicationConfig> list = new List<ApplicationConfig>();
                    //lstConfigPasswords
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new ApplicationConfig
                        {
                            CaseType = DDT.Rows[i]["CaseType"].ToString(),
                            Confirmpopup = DDT.Rows[i]["Confirmpopup"].ToString(),
                            Roundoff = DDT.Rows[i]["Roundoff"].ToString(),
                            RoundoffValue = DDT.Rows[i]["RoundoffValue"].ToString(),
                            SMTPHost = DDT.Rows[i]["SMTPHost"].ToString(),
                            EMail = DDT.Rows[i]["EMail"].ToString(),
                            Password = clsEncryptDecrypt.Decrypt(DDT.Rows[i]["Password"].ToString()),
                            DecimalValues = DDT.Rows[i]["DecimalValues"].ToString(),
                            Showallstatus = DDT.Rows[i]["Showallstatus"].ToString(),
                            ItemOrderby = DDT.Rows[i]["ItemOrderby"].ToString(),
                            EnableReturnPrice = DDT.Rows[i]["EnableReturnPrice"].ToString(),
                            VisaPern = DDT.Rows[i]["VisaPern"].ToString(),
                            DefaultCustID = DDT.Rows[i]["DefaultCustID"].ToString(),
                            UPIID = DDT.Rows[i]["UPIID"].ToString(),
                            UPIName = DDT.Rows[i]["UPIName"].ToString(),
                            WriteoffAmt = DDT.Rows[i]["WriteoffAmt"].ToString(),
                            AllSalesmanInvoice = DDT.Rows[i]["AllSalesmanInvoice"].ToString(),
                            AllowPrint = DDT.Rows[i]["AllowPrint"].ToString(),
                            ApplySchemeinQuotation = DDT.Rows[i]["ApplySchemeinQuotation"].ToString(),
                            SelectinvoiceinSR = DDT.Rows[i]["SelectinvoiceinSR"].ToString(),
                            ClearConfirmpopup = DDT.Rows[i]["ClearConfirmpopup"].ToString(),
                            CloseConfirmpopup = DDT.Rows[i]["CloseConfirmpopup"].ToString(),
                            BackupPath = DDT.Rows[i]["BackupPath"].ToString(),
                            InvoiceStockOnlyProduct = DDT.Rows[i]["InvoiceStockOnlyProduct"].ToString(),
                            PurchaseOneView = DDT.Rows[i]["PurchaseOneView"].ToString(),
                            SalesOneView = DDT.Rows[i]["SalesOneView"].ToString(),
                            FilterDate = DDT.Rows[i]["FilterDate"].ToString(),
                            ItemsperPage = DDT.Rows[i]["ItemsperPage"].ToString(),
                            Invoiceallowduplicateitem = DDT.Rows[i]["Invoiceallowduplicateitem"].ToString(),
                            CommonAgeingCreditDays = DDT.Rows[i]["CommonAgeingCreditDays"].ToString(),
                            RestrictBlocklistinInvoice = DDT.Rows[i]["RestrictBlocklistinInvoice"].ToString(),
                            RetainDate = DDT.Rows[i]["RetainDate"].ToString(),
                            BeatMandatoryinCustomer = DDT.Rows[i]["BeatMandatoryinCustomer"].ToString(),
                            DraftAutoSaveTimeInterval = DDT.Rows[i]["DraftAutoSaveTimeInterval"].ToString(),
                            HomePeriod = DDT.Rows[i]["HomePeriod"].ToString(),
                            AutoRefresh = DDT.Rows[i]["AutoRefresh"].ToString(),
                            CTPAmount = DDT.Rows[i]["CTPAmount"].ToString(),
                            CTPPoint = DDT.Rows[i]["CTPPoint"].ToString(),
                            CTPPerPointAmount = DDT.Rows[i]["CTPPerPointAmount"].ToString(),
                            UpdateVendorinProduct = DDT.Rows[i]["UpdateVendorinProduct"].ToString(),
                            Radius = DDT.Rows[i]["Radius"].ToString(),
                            SpotSalesPriceMode = DDT.Rows[i]["SpotSalesPriceMode"].ToString(),
                            lstPaymode = pmlist,
                            lstConfigPasswords = lstpwd
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "applicationconfig/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/applicationconfig/save")]
        public IHttpActionResult SaveAppconfig(ApplicationConfig lstMaster)
        {
            try
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspManageApplicationConfig", 2, lstMaster.CaseType, lstMaster.Confirmpopup, lstMaster.Roundoff, lstMaster.RoundoffValue,
                            lstMaster.SMTPHost, lstMaster.EMail, clsEncryptDecrypt.Encrypt(lstMaster.Password), lstMaster.DecimalValues, lstMaster.Showallstatus,
                            lstMaster.ItemOrderby, lstMaster.EnableReturnPrice, lstMaster.VisaPern, lstMaster.DefaultCustID, lstMaster.UPIID,
                            lstMaster.UPIName, lstMaster.WriteoffAmt, lstMaster.AllSalesmanInvoice, lstMaster.AllowPrint, lstMaster.ApplySchemeinQuotation,
                            lstMaster.SelectinvoiceinSR, lstMaster.ClearConfirmpopup, lstMaster.CloseConfirmpopup, lstMaster.BackupPath,
                            lstMaster.InvoiceStockOnlyProduct, lstMaster.SalesOneView, lstMaster.PurchaseOneView, lstMaster.FilterDate, lstMaster.ItemsperPage,
                            lstMaster.Invoiceallowduplicateitem, lstMaster.CommonAgeingCreditDays, lstMaster.RestrictBlocklistinInvoice, lstMaster.RetainDate,
                            lstMaster.BeatMandatoryinCustomer, lstMaster.DraftAutoSaveTimeInterval, lstMaster.HomePeriod, lstMaster.AutoRefresh, lstMaster.CTPAmount,
                            lstMaster.CTPPoint, lstMaster.CTPPerPointAmount, lstMaster.UpdateVendorinProduct, lstMaster.Radius, lstMaster.SpotSalesPriceMode);

                foreach (PaymodeAppconfig item in lstMaster.lstPaymode)
                {
                    if (item.TypeID == "1")
                    {
                        bl.BL_ExecuteParamSP("uspManageApplicationConfig", 5, item.ID, item.Active, item.Order);
                    }
                    else if (item.TypeID == "2")
                    {
                        bl.BL_ExecuteParamSP("uspManageApplicationConfig", 6, item.ID, item.Active);
                    }
                    else if (item.TypeID == "4")
                    {
                        bl.BL_ExecuteParamSP("uspManageApplicationConfig", 10, item.ID, item.Active, item.Order);
                    }
                }
                foreach (PasswordSettingAppconfig item in lstMaster.lstConfigPasswords)
                {
                    bl.BL_ExecuteParamSP("uspManageApplicationConfig", 8, item.ID, clsEncryptDecrypt.Encrypt(item.Passwords));
                }
                List<SaveMessage> list = new List<SaveMessage>();
                if (DDT.Columns.Count == 1)
                {
                    //Success message
                    list.Add(new SaveMessage()
                    {
                        ID = DDT.Rows[0][0].ToString(),
                        MsgID = "0",
                        Message = "Saved Successfully"
                    });
                }
                else
                {
                    //Error message
                    list.Add(new SaveMessage()
                    {
                        ID = "0",
                        MsgID = "1",
                        Message = "Name already exists"
                    });
                }
                return Ok(list);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "applicationconfig/save", ex.Message);
            }
            return Ok();
        }

        [HttpGet]
        [Route("api/menuorder/get")]
        public IHttpActionResult GetmenuorderData(string Mode,int Type, string Name)
        {
            try
            {
                if (Mode == "1" || Mode == "2")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspManageMenuOrder", Mode, Type, Name, 0);
                    List<SingleMasterModel> list = new List<SingleMasterModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new SingleMasterModel
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            Name = DDT.Rows[i][1].ToString(),
                            Value = DDT.Rows[i][2].ToString(),
                            Favourite = DDT.Columns.Contains("Favourite") ? Convert.ToInt32(DDT.Rows[i]["Favourite"]) : 0
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "menuorder/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/menuorder/save")]
        public IHttpActionResult Savemenuorder(SingleMasterModel lstMaster)
        {
            try
            {
                foreach (clsMenuorder item in lstMaster.lstMenus)
                {
                    Console.WriteLine($"MenuID={item.MenuID}, Order={item.Order}, Favourite={item.Favourite}");

                    bl.BL_ExecuteParamSP("uspManageMenuOrder", 3, 0, item.MenuID, item.Order, item.Favourite);
                }
                List<SaveMessage> list = new List<SaveMessage>();
                list.Add(new SaveMessage
                {
                    MsgID = "0",
                    Message = "Saved successfully"
                });
                return Ok(list);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "menuorder/save", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/documentseries/get")]
        public IHttpActionResult GetdocumentseriesData(string Mode, string ID)
        {
            try
            {
                if (Mode == "1")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspManageDocumentSeries", Mode);
                    string Masterdata = JsonConvert.SerializeObject(DDT);
                    return Ok(Masterdata);
                }
                else if (Mode == "2")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspManageDocumentSeries", Mode);
                    string Masterdata = JsonConvert.SerializeObject(DDT);
                    return Ok(Masterdata);
                }
                else if (Mode == "3")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspManageDocumentSeries", Mode, ID);
                    string Masterdata = JsonConvert.SerializeObject(DDT);
                    return Ok(Masterdata);
                }
                else if (Mode == "4")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspManageDocumentSeries", Mode);
                    List<SingleMasterModel> list = new List<SingleMasterModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new SingleMasterModel
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            Name = DDT.Rows[i][1].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "documentseries/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/documentseries/save")]
        public IHttpActionResult Savedocumentseries(DocumentSeries lstMaster)
        {
            try
            {
                List<SaveMessage> list = new List<SaveMessage>();
                int alreadycheck = 0, verifyID = 0;
                foreach (clsDocSeries item in lstMaster.lstDocSeries)
                {
                    DataTable dt = bl.BL_ExecuteParamSP("uspSaveDocumentSeries", 3,
                        !string.IsNullOrEmpty(lstMaster.ID) ? lstMaster.ID : "0", lstMaster.BranchID, item.ID, item.Prefix, item.DocValue,
                        lstMaster.FromDate, lstMaster.ToDate, lstMaster.UserID, !string.IsNullOrEmpty(lstMaster.orgFromDate) ? lstMaster.orgFromDate : null,
                         !string.IsNullOrEmpty(lstMaster.orgToDate) ? lstMaster.orgToDate : null,
                         !string.IsNullOrEmpty(lstMaster.orgBranchID) ? lstMaster.orgBranchID : "0", alreadycheck, verifyID);
                    if (dt.Columns.Count > 1)
                    {
                        list.Add(new SaveMessage
                        {
                            MsgID = "1",
                            Message = dt.Rows[0][0].ToString()
                        });
                        return Ok(list);
                    }
                    verifyID = 0;// bl.BL_nValidation(dt.Rows[0][0].ToString());
                    alreadycheck = 1;
                }
                alreadycheck = 0; verifyID = 0;
                foreach (clsDocSeries item in lstMaster.lstDocSeries)
                {
                    DataTable dt = bl.BL_ExecuteParamSP("uspSaveDocumentSeries", lstMaster.Mode,
                        !string.IsNullOrEmpty(lstMaster.ID) ? lstMaster.ID : "0", lstMaster.BranchID, item.ID, item.Prefix, item.DocValue,
                        lstMaster.FromDate, lstMaster.ToDate, lstMaster.UserID, !string.IsNullOrEmpty(lstMaster.orgFromDate) ? lstMaster.orgFromDate : null,
                         !string.IsNullOrEmpty(lstMaster.orgToDate) ? lstMaster.orgToDate : null,
                         !string.IsNullOrEmpty(lstMaster.orgBranchID) ? lstMaster.orgBranchID : "0", alreadycheck, verifyID);
                    if (dt.Columns.Count > 1)
                    {
                        list.Add(new SaveMessage
                        {
                            MsgID = "1",
                            Message = dt.Rows[0][0].ToString()
                        });
                        return Ok(list);
                    }
                    verifyID = bl.BL_nValidation(dt.Rows[0][0].ToString());
                    alreadycheck = 1;
                }

                list.Add(new SaveMessage
                {
                    MsgID = "0",
                    Message = "Saved successfully"
                });
                return Ok(list);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "documentseries/save", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/companydetails/get")]
        public IHttpActionResult GetcompanydetailsData(string Mode)
        {
            try
            {
                if (Mode == "1")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspManageUpdateCompanyDetail", Mode);
                    List<CompanyDeatils> list = new List<CompanyDeatils>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        List<PaymodeAppconfig> lststa = new List<PaymodeAppconfig>();
                        DataTable STATE = bl.BL_ExecuteParamSP("uspManageUpdateCompanyDetail", 2);
                        for (int J = 0; J < STATE.Rows.Count; J++)
                        {
                            lststa.Add(new PaymodeAppconfig
                            {
                                ID = STATE.Rows[J]["StateID"].ToString(),
                                Name = STATE.Rows[J]["StateName"].ToString(),
                            });
                        }
                        
                        string ValidExpDate = " -- ",ValidExpDays = "0";
                        if (!string.IsNullOrEmpty(DDT.Rows[i]["ExpiryDate"].ToString()))
                        {
                           DateTime ExpDate = Convert.ToDateTime(clsEncryptDecrypt.Decrypt(DDT.Rows[i]["ExpiryDate"].ToString()));
                            ValidExpDate = ExpDate.ToString("dd/MMM/yyyy");
                            ValidExpDays = (ExpDate - DateTime.Now).Days.ToString();
                        }
                        string webdevs = null, mobdevs = null;
                        if (!string.IsNullOrEmpty(DDT.Rows[i]["WebDevices"].ToString()))
                        {
                            webdevs = clsEncryptDecrypt.Decrypt(DDT.Rows[i]["WebDevices"].ToString());
                        }
                        if (!string.IsNullOrEmpty(DDT.Rows[i]["MobileDevices"].ToString()))
                        {
                            mobdevs = clsEncryptDecrypt.Decrypt(DDT.Rows[i]["MobileDevices"].ToString());
                        }
                        list.Add(new CompanyDeatils
                        {
                            CompanyId = DDT.Rows[i]["CompanyId"].ToString(),
                            CompanyCode = DDT.Rows[i]["CompanyCode"].ToString(),
                            CompanyName = DDT.Rows[i]["CompanyName"].ToString(),
                            StateID = DDT.Rows[i]["StateID"].ToString(),
                            Address = DDT.Rows[i]["Address"].ToString(),
                            Country = DDT.Rows[i]["Country"].ToString(),
                            State = DDT.Rows[i]["State"].ToString(),
                            City = DDT.Rows[i]["City"].ToString(),
                            Pincode = DDT.Rows[i]["Pincode"].ToString(),
                            Contact_Person = DDT.Rows[i]["Contact_Person"].ToString(),
                            MobileNo = DDT.Rows[i]["MobileNo"].ToString(),
                            PhoneNo = DDT.Rows[i]["PhoneNo"].ToString(),
                            Website = DDT.Rows[i]["Website"].ToString(),
                            Email = DDT.Rows[i]["Email"].ToString(),
                            CCEmail = DDT.Rows[i]["CCEmail"].ToString(),
                            FSSAI = DDT.Rows[i]["FSSAI"].ToString(),
                            AadharNo = DDT.Rows[i]["AadharNo"].ToString(),
                            PANNo = DDT.Rows[i]["PANNo"].ToString(),
                            GSTIN = DDT.Rows[i]["GSTIN"].ToString(),
                            Dl_20 = DDT.Rows[i]["Dl_20"].ToString(),
                            Dl_21 = DDT.Rows[i]["Dl_21"].ToString(),
                            ExpiryDate = ValidExpDate,
                            ExpiryDays = ValidExpDays,
                            WebDevices = webdevs,
                            MobileDevices = mobdevs,
                            F_SD = Convert.ToDateTime(DDT.Rows[i]["F_SD"].ToString()).ToString("yyyy-MM-dd"),
                            F_ED = Convert.ToDateTime(DDT.Rows[i]["F_ED"].ToString()).ToString("yyyy-MM-dd"),
                            lstState = lststa
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "companydetails/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/companydetails/save")]
        public IHttpActionResult Savecompanydetails(CompanyDeatils lstMaster)
        {
            try
            {
                string webdevs = null, mobdevs = null;
                if (!string.IsNullOrEmpty(lstMaster.WebDevices))
                {
                    webdevs = clsEncryptDecrypt.Encrypt(lstMaster.WebDevices);
                }
                if (!string.IsNullOrEmpty(lstMaster.MobileDevices))
                {
                    mobdevs = clsEncryptDecrypt.Encrypt(lstMaster.MobileDevices);
                }
                bl.BL_ExecuteParamSP("uspManageUpdateCompanyDetail", 3, lstMaster.CompanyId, lstMaster.CompanyCode, lstMaster.CompanyName, lstMaster.StateID,
                     lstMaster.Address, lstMaster.Country, lstMaster.State, lstMaster.City, lstMaster.Pincode, lstMaster.Contact_Person, lstMaster.MobileNo,
                     lstMaster.PhoneNo, lstMaster.Website, lstMaster.Email, lstMaster.FSSAI, lstMaster.AadharNo, lstMaster.PANNo, lstMaster.GSTIN, lstMaster.Dl_20,
                     lstMaster.Dl_21, lstMaster.CCEmail, lstMaster.F_SD, lstMaster.F_ED, webdevs, mobdevs);
                List<SaveMessage> list = new List<SaveMessage>();
                list.Add(new SaveMessage
                {
                    MsgID = "0",
                    Message = "Saved successfully"
                });
                return Ok(list);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "companydetails/save", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/discountscheme/getalldata")]
        public IHttpActionResult GetAllVendorData(string Mode, string Name)
        {
            try
            {
                List<DiscountScheme> list = new List<DiscountScheme>();
                DataTable DDT = bl.BL_ExecuteParamSP("uspgetsetDiscountSchemeData", Mode);
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new DiscountScheme
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        Name = DDT.Rows[i][1].ToString(),
                        ReplaceExists = DDT.Rows[i][2].ToString(),
                        FromDate = DDT.Rows[i][3].ToString(),
                        ToDate = DDT.Rows[i][4].ToString(),
                        Active = DDT.Rows[i][5].ToString(),
                        CustomerCount = DDT.Rows[i][6].ToString(),
                        ProductCount = DDT.Rows[i][7].ToString(),
                        CBy = DDT.Rows[i]["UserName"].ToString(),
                        CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                    });
                }

                var data = from users in list
                           select
                               new
                               {
                                   ID = users.ID,
                                   Name = users.Name,
                                   ReplaceExists = users.ReplaceExists,
                                   FromDate = users.FromDate,
                                   ToDate = users.ToDate,
                                   Active = users.Active,
                                   CustomerCount = users.CustomerCount,
                                   ProductCount = users.ProductCount,
                                   CBy = users.CBy,
                                   CDate = users.CDate
                               };

                return Ok(data);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "discountscheme/getalldata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/discountscheme/get")]
        public IHttpActionResult GetdiscountschemeData(string Mode, string Name)
        {
            try
            {
                if (Mode == "1")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspgetsetDiscountSchemeData", Mode);
                    List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new CustomerVendorModel
                        {
                            FType = DDT.Rows[i][0].ToString(),
                            Form = DDT.Rows[i][1].ToString(),
                            ID = DDT.Rows[i][2].ToString(),
                            Name = DDT.Rows[i][3].ToString()
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "2")
                {
                    List<DiscountScheme> list = new List<DiscountScheme>();
                    DataTable DDT = bl.BL_ExecuteParamSP("uspgetsetDiscountSchemeData", Mode);
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new DiscountScheme
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            Name = DDT.Rows[i][1].ToString(),
                            ReplaceExists = DDT.Rows[i][2].ToString(),
                            FromDate = DDT.Rows[i][3].ToString(),
                            ToDate = DDT.Rows[i][4].ToString(),
                            Active = DDT.Rows[i][5].ToString(),
                            CustomerCount = DDT.Rows[i][6].ToString(),
                            ProductCount = DDT.Rows[i][7].ToString()
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "3")
                {
                    List<DiscountScheme> list = new List<DiscountScheme>();
                    DataTable DDT = bl.BL_ExecuteParamSP("uspgetsetDiscountSchemeData", Mode, Name);
                    if (DDT.Rows.Count > 0)
                    {
                        List<DiscountSchemeCustomer> listCust = new List<DiscountSchemeCustomer>();
                        List<DiscountSchemeProduct> listProd = new List<DiscountSchemeProduct>();
                        DataTable dtCust = bl.BL_ExecuteParamSP("uspgetsetDiscountSchemeData", 31, DDT.Rows[0][0].ToString());
                        for (int i = 0; i < dtCust.Rows.Count; i++)
                        {
                            listCust.Add(new DiscountSchemeCustomer
                            {
                                CustomerID = dtCust.Rows[i][0].ToString(),
                                Code = dtCust.Rows[i][1].ToString(),
                                Name = dtCust.Rows[i][2].ToString(),
                            });
                        }

                        var data = from users in listCust
                                   select
                                       new
                                       {
                                           CustomerID = users.CustomerID,
                                           Code = users.Code,
                                           Name = users.Name
                                       };

                        string CustomerJSONCONV = JsonConvert.SerializeObject(data);
                        DataTable dtProd = bl.BL_ExecuteParamSP("uspgetsetDiscountSchemeData", 32, DDT.Rows[0][0].ToString());
                        for (int i = 0; i < dtProd.Rows.Count; i++)
                        {
                            listProd.Add(new DiscountSchemeProduct
                            {
                                ProductID = dtProd.Rows[i][0].ToString(),
                                Code = dtProd.Rows[i][1].ToString(),
                                Name = dtProd.Rows[i][2].ToString(),
                                ProdDiscPern = dtProd.Rows[i][3].ToString(),
                                ProdDiscAmt = dtProd.Rows[i][4].ToString(),
                                TradeDiscPern = dtProd.Rows[i][5].ToString(),
                                TradeDiscAmt = dtProd.Rows[i][6].ToString(),
                            });
                        }
                        var data1 = from users in listProd
                                    select
                                            new
                                            {
                                                ProductID = users.ProductID,
                                                Code = users.Code,
                                                Name = users.Name,
                                                ProdDiscPern = users.ProdDiscPern,
                                                ProdDiscAmt = users.ProdDiscAmt,
                                                TradeDiscPern = users.TradeDiscPern,
                                                TradeDiscAmt = users.TradeDiscAmt,
                                            };
                        string ProductJSONCONV = JsonConvert.SerializeObject(data1);
                        list.Add(new DiscountScheme
                        {
                            ID = DDT.Rows[0][0].ToString(),
                            Name = DDT.Rows[0][1].ToString(),
                            ReplaceExists = DDT.Rows[0][2].ToString(),
                            FromDate = Convert.ToDateTime(DDT.Rows[0][3].ToString()).ToString("yyyy-MM-dd"),
                            ToDate = Convert.ToDateTime(DDT.Rows[0][4].ToString()).ToString("yyyy-MM-dd"),
                            Active = DDT.Rows[0][5].ToString(),
                            MapByID = DDT.Rows[0]["ApplyIn"].ToString(),
                            lstCustomers = CustomerJSONCONV,
                            lstProducts = ProductJSONCONV,
                            lstSchemeCustomer = listCust,
                            lstSchemeProduct = listProd
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "discountscheme/get", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/discountscheme/getfilterdata")]
        public IHttpActionResult GetdiscountschemefilterData(string Mode, string Type, string CustTypeorManuf, string BeatorBrand, 
            string SalesmanorCategory, string CustomerorProduct,string MapBy)
        {
            try
            {
                if (Mode == "4")
                {
                    DataTable DDT = new DataTable();
                    DDT = bl.BL_ExecuteParamSP("uspgetsetDiscountSchemeData", Mode, Type, CustTypeorManuf, BeatorBrand, SalesmanorCategory,
                        CustomerorProduct, MapBy);
                    List<DiscountschemeDetail> list = new List<DiscountschemeDetail>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new DiscountschemeDetail
                        {
                            FType = Type,
                            ID = DDT.Rows[i][0].ToString(),
                            Code = DDT.Rows[i][1].ToString(),
                            Name = DDT.Rows[i][2].ToString()
                        });
                    }
                    string IDColName = Type == "1" ? "CustomerID" : "ProductID";

                    if (Type == "1")
                    {
                        var data = from users in list
                                   select
                                       new
                                       {
                                           CustomerID = users.ID,
                                           Code = users.Code,
                                           Name = users.Name
                                       };
                        return Ok(data);
                    }
                    else
                    {
                        var data = from users in list
                                   select
                                       new
                                       {
                                           ProductID = users.ID,
                                           Code = users.Code,
                                           Name = users.Name
                                       };
                        return Ok(data);
                    }


                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "discountscheme/getfilterdata", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/discountscheme/save")]
        public IHttpActionResult Savediscountschemedetails(DiscountScheme lstMaster)
        {
            List<SaveMessage> list = new List<SaveMessage>();

            try
            {
                DataTable dtCustProdDisc = new DataTable();
                dtCustProdDisc.Columns.Add("CustID", typeof(int));
                dtCustProdDisc.Columns.Add("ProdID", typeof(int));
                dtCustProdDisc.Columns.Add("ProdDisc", typeof(decimal));
                dtCustProdDisc.Columns.Add("ProdDiscAmt", typeof(decimal));
                dtCustProdDisc.Columns.Add("TradeDisc", typeof(decimal));
                dtCustProdDisc.Columns.Add("TradeDiscAmt", typeof(decimal));
                dtCustProdDisc.Columns.Add("Serial", typeof(int));
                DataTable dtCustomers = new DataTable();
                dtCustomers.Columns.Add("TransName", typeof(string));
                dtCustomers.Columns.Add("Status", typeof(int));
                dtCustomers.Columns.Add("DocumentId", typeof(int));

                int nRow = 0;
                foreach (DiscountSchemeCustomer item in lstMaster.lstSchemeCustomer)
                {
                    int nCustID = Convert.ToInt32(item.CustomerID);
                    dtCustomers.Rows.Add();
                    dtCustomers.Rows[nRow]["DocumentId"] = nCustID;
                    dtCustomers.Rows[nRow]["TransName"] = "Discount Scheme";
                    dtCustomers.Rows[nRow]["Status"] = (nRow+1);
                    nRow++;
                }
                nRow = 0;
                foreach (DiscountSchemeProduct itemProduct in lstMaster.lstSchemeProduct)
                {
                    dtCustProdDisc.Rows.Add();
                    dtCustProdDisc.Rows[nRow]["CustID"] = 0;
                    dtCustProdDisc.Rows[nRow]["ProdID"] = Convert.ToInt32(itemProduct.ProductID);
                    dtCustProdDisc.Rows[nRow]["ProdDisc"] = Convert.ToDecimal(itemProduct.ProdDiscPern);
                    dtCustProdDisc.Rows[nRow]["ProdDiscAmt"] = Convert.ToDecimal(itemProduct.ProdDiscAmt);
                    dtCustProdDisc.Rows[nRow]["TradeDisc"] = Convert.ToDecimal(itemProduct.TradeDiscPern);
                    dtCustProdDisc.Rows[nRow]["TradeDiscAmt"] = Convert.ToDecimal(itemProduct.TradeDiscAmt);
                    dtCustProdDisc.Rows[nRow]["Serial"] = (nRow+1);
                    nRow++;
                }
                bl.bl_Transaction(1);
                DataTable dtResult = bl.bl_ManageTrans("uspSaveSchemeDiscount", bl.BL_nValidation(lstMaster.ID), lstMaster.Name,
                    lstMaster.ReplaceExists, lstMaster.FromDate, lstMaster.ToDate, lstMaster.Active,
                    lstMaster.UserID, dtCustProdDisc, dtCustomers, lstMaster.MapByID);
                if (dtResult.Columns.Count > 1)
                {
                    bl.bl_Transaction(3);
                    list.Add(new SaveMessage()
                    {
                        ID = 0.ToString(),
                        MsgID = "1",
                        Message = "Name already exists"
                    });
                    return Ok(list);
                }
                else
                {
                    bl.bl_Transaction(2);
                    int ScopeID = bl.BL_nValidation(dtResult.Rows[0][0]);
                    list.Add(new SaveMessage()
                    {
                        ID = ScopeID.ToString(),
                        MsgID = "0",
                        Message = "Saved Successfully"
                    });
                    return Ok(list);
                }
                
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Discount Scheme", "Save", ex.Message);
                list.Add(new SaveMessage()
                {
                    ID = 0.ToString(),
                    MsgID = "1",
                    Message = ex.Message
                });
                return Ok(list);
            }
        }
        [HttpGet]
        [Route("api/verifyapppassword/verify")]
        public IHttpActionResult checkAPPPASSOWRD(string ID, string Pwd)
        {
            try
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspManageApplicationConfig", 9, ID);
                List<SaveMessage> list = new List<SaveMessage>();
                if (DDT.Rows.Count > 0)
                {
                    string decryptpwd = clsEncryptDecrypt.Decrypt(DDT.Rows[0][2].ToString());
                    if (Pwd == decryptpwd)
                    {
                        list.Add(new SaveMessage
                        {
                            Message = "Password Valid",
                            MsgID = "0",
                        });
                    }
                    else
                    {
                        list.Add(new SaveMessage
                        {
                            Message = "Invalid Password",
                            MsgID = "1",
                        });
                    }
                }
                else
                {
                    list.Add(new SaveMessage
                    {
                        Message = "Password not found or De-activated",
                        MsgID = "2",
                    });
                }
                return Ok(list);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "verifyapppassword/verify", ex.Message);
            }
            return Ok();
        }

        [HttpGet]
        [Route("api/transactionprint/get")]
        public IHttpActionResult GetTransPrintData(string Mode, string Name)
        {
            try
            {
                DataTable DDT = new DataTable();
                if (Mode == "1")
                {
                    DDT = bl.BL_ExecuteParamSP("uspManageTransactionPrint", Mode);
                    List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new CustomerVendorModel
                        {
                            FType = DDT.Rows[i][0].ToString(),
                            Form = DDT.Rows[i][1].ToString(),
                            ID = DDT.Rows[i][2].ToString(),
                            Name = DDT.Rows[i][3].ToString(),
                            Code = DDT.Rows[i][4].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "transactionprint/get", ex.Message);
            }
            return Ok();
        }


        public void Powershellzip(string sourceFile, string zipFile)
        {
            //string sourceFile = @"D:\Host\NewWebShineAPI\BAK\BK_GKBS01_APR2024_20250503165738540.BAK";
            //string zipFile = @"D:\Host\NewWebShineAPI\BAK\BK_GKBS01_APR2024_20250503165738540.zip";

            string powershellCommand = $"Compress-Archive -Path '{sourceFile}' -DestinationPath '{zipFile}' -Force";

            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = "powershell",
                Arguments = $"-Command \"{powershellCommand}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };

            try
            {
                using (Process process = Process.Start(psi))
                {
                    string output = process.StandardOutput.ReadToEnd();
                    string error = process.StandardError.ReadToEnd();
                    process.WaitForExit();

                }
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Backup", "Powershellzip", ex.Message);
                throw ex;
            }
        }

        [HttpGet]
        [Route("api/oneview/getparty")]
        public IHttpActionResult GetOneViewparty(string Type)
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspOneView", 0, 0, Type);
                List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new CustomerVendorModel
                    {
                        ID = DDT.Rows[i][0].ToString(),
                        Name = DDT.Rows[i][2].ToString(),
                        Code = DDT.Rows[i][1].ToString(),
                    });
                }
                return Ok(list);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "oneview/getparty", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/oneview/getdata")]
        public IHttpActionResult GetOneViewData(string Type, string PartyID)
        {
            try
            {
                DataTable dtParty = bl.BL_ExecuteParamSP("uspOneView", 1, PartyID, Type);
                string jsonParty = JsonConvert.SerializeObject(dtParty);
                DataTable dtTrans = bl.BL_ExecuteParamSP("uspOneView", 2, PartyID, Type);
                string jsonTrans = JsonConvert.SerializeObject(dtTrans);
                DataTable dtOS = bl.BL_ExecuteParamSP("uspOneView", 3, PartyID, Type);
                string jsonOS = JsonConvert.SerializeObject(dtOS);

                DataTable dtTopProds = bl.BL_ExecuteParamSP("uspOneView", 4, PartyID, Type);
                string jsonProds = JsonConvert.SerializeObject(dtTopProds);
                DataTable dtCheque = bl.BL_ExecuteParamSP("uspOneView", 5, PartyID, Type);
                string jsonCheque = JsonConvert.SerializeObject(dtCheque);

                DataTable dtLedger = bl.BL_ExecuteParamSP("uspOneView", 6, PartyID, Type);
                string jsonLedger = JsonConvert.SerializeObject(dtLedger);

                DataTable dtMonthly = bl.BL_ExecuteParamSP("uspOneView", 7, PartyID, Type);
                string jsonMonthly = JsonConvert.SerializeObject(dtMonthly);

                List<OneViewData> list = new List<OneViewData>();
                list.Add(new OneViewData()
                {
                    PartyDetails = jsonParty,
                    TransDetails = jsonTrans,
                    OutstandingDetails = jsonOS,
                    TopProductsDetails = jsonProds,
                    ChequeDetails = jsonCheque,
                    LedgetDetails = jsonLedger,
                    MonthlySalesDetails = jsonMonthly
                });
                return Ok(list);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "oneview/getdata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/updateproductlocation/get")]
        public IHttpActionResult Getupdateproductlocation(string Mode,string BranchID)
        {
            try
            {
                DataTable dtSerialInfo = new DataTable();
                DataColumn column = new DataColumn("Index");
                column.DataType = System.Type.GetType("System.Int32");
                column.AutoIncrement = true;
                column.AutoIncrementSeed = 1;
                column.AutoIncrementStep = 1;
                dtSerialInfo.Columns.Add(column);
                dtSerialInfo.Columns.Add("ProdId", typeof(int));
                dtSerialInfo.Columns.Add("Serial", typeof(string));
                if (Mode == "1")
                {
                    bl.bl_Transaction(1);
                    DataTable DDT = bl.bl_ManageTrans("uspManageUpdateproductlocation", Mode, 0, dtSerialInfo);
                    bl.bl_Transaction(2);
                    List<CustomerVendorModel> list = new List<CustomerVendorModel>();

                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        var fType = DDT.Rows[i]["FType"].ToString();
                        var id = DDT.Rows[i]["ID"].ToString();
                        var name = DDT.Rows[i]["Name"].ToString();

                        var item = new CustomerVendorModel
                        {
                            FType = fType,   // 1 = Location, 2 = Branch
                            ID = id,
                            Name = name
                        };

                        // Optionally set BranchID/BranchName if it's a branch
                        if (fType == "2")
                        {
                            item.BranchID = id;
                            item.BranchName = name;
                        }

                        list.Add(item);
                    }

                    return Ok(list);
                }
                if (Mode == "2")
                {
                    bl.bl_Transaction(1);
                    DataTable DDT = bl.bl_ManageTrans("uspManageUpdateproductlocation", Mode, BranchID, dtSerialInfo);
                    bl.bl_Transaction(2);
                    string ProdData = JsonConvert.SerializeObject(DDT, Formatting.Indented);
                    return Ok(ProdData);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "updateproductlocation/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/updateproductlocation/save")]
        public IHttpActionResult saveupdateproductlocation(List<ProductModel> lstProd)
        {
            try
            {
                List<SaveMessage> list = new List<SaveMessage>();
                if (lstProd != null)
                {
                    DataTable dtSerialInfo = new DataTable();
                    DataColumn column = new DataColumn("Index");
                    column.DataType = System.Type.GetType("System.Int32");
                    column.AutoIncrement = true;
                    column.AutoIncrementSeed = 1;
                    column.AutoIncrementStep = 1;
                    dtSerialInfo.Columns.Add(column);
                    dtSerialInfo.Columns.Add("ProdId", typeof(int));
                    dtSerialInfo.Columns.Add("Serial", typeof(string));
                    int BranchID = 0;
                    foreach (ProductModel item in lstProd)
                    {

                        DataRow dataRow = dtSerialInfo.NewRow();
                        dataRow[1] = item.ID;
                        dataRow[2] = item.LocationID;
                        dtSerialInfo.Rows.Add(dataRow);
                        BranchID = Convert.ToInt32(item.BranchID);
                    }
                    bl.bl_Transaction(1);
                    bl.bl_ManageTrans("uspManageUpdateproductlocation", 3, BranchID, dtSerialInfo);
                    bl.bl_Transaction(2);
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
                bl.BL_WriteErrorMsginLog("AllMaster", "updateproductlocation/save", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/singlemaster/getactivedata")]
        public IHttpActionResult GetSMData(string FormID)
        {
            try
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspGetSinglemasterdata", FormID);
                List<SingleMasterModel> list = new List<SingleMasterModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    list.Add(new SingleMasterModel
                    {
                        ID = DDT.Rows[i]["ID"].ToString(),
                        Name = DDT.Rows[i]["Name"].ToString(),
                        Active = DDT.Rows[i]["Active"].ToString(),
                    });
                }
                return Ok(list);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("AllMaster", "singlemaster/getactivedata", ex.Message);
            }
            return Ok();
        }
    }  
}
