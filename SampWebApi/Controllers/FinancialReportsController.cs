using DocumentFormat.OpenXml.Spreadsheet;
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
using System.Windows.Forms;
using static System.Windows.Forms.VisualStyles.VisualStyleElement.TreeView;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class FinancialReportsController : ApiController
    {
        public string strExtension = ".xlsx";
        public string strFileName = "";
        public string strSheetName { get; set; }
        public string strFilePath
        {
            get; set;
        }
        DataTable dtAddAccDetails = new DataTable();
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/FinancialReportpermissions")]
        public IHttpActionResult GetPermissionsReports(string UID)
        {
            try
            {
                DataSet ds = new DataSet();
                DataTable dtRes = bl.BL_ExecuteParamSP("uspManageUsers", 4, UID);
                string RID = dtRes.Rows[0]["RoleID"].ToString();
                DataTable dtReportParent = bl.BL_ExecuteParamSP("uspFinancialReportPermission", 1, RID);
                dtReportParent.TableName = "ParentFinRepMenu";
                ds.Tables.Add(dtReportParent);
                DataTable dtReportPermission = bl.BL_ExecuteParamSP("uspFinancialReportPermission", 2, RID, UID);
                dtReportPermission.TableName = "UserFinRepMenus";
                ds.Tables.Add(dtReportPermission);
                string dtjson = JsonConvert.SerializeObject(ds);
                return Ok(dtjson);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("FinancialReports", "FinancialReportpermissions", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/financialreportparameters/get")]
        public IHttpActionResult GetData(string Mode, string ReportID, string ALName = null)
        {
            try
            {
                DataTable DDT = new DataTable();
                if (Mode == "0")
                {
                    DDT = bl.BL_ExecuteParamSP("uspManageFinancialReports", Mode, ReportID);
                    string JSONCONV = JsonConvert.SerializeObject(DDT);
                    return Ok(JSONCONV);
                }
                if (Mode == "1")
                {
                    DDT = bl.BL_ExecuteParamSP("uspManageFinancialReports", Mode, ReportID);
                    List<ReportParameters> list = new List<ReportParameters>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new ReportParameters
                        {
                            ParameterID = DDT.Rows[i]["ParameterID"].ToString(),
                            ReportID = DDT.Rows[i]["ReportID"].ToString(),
                            ParameterName = DDT.Rows[i]["ParameterName"].ToString(),
                            ParameterType = DDT.Rows[i]["ParameterType"].ToString(),
                            IsMandatory = DDT.Rows[i]["IsMandatory"].ToString(),
                            ParamOrder = DDT.Rows[i]["ParamOrder"].ToString(),
                            AutolistName = DDT.Rows[i]["AutolistName"].ToString()
                        });
                    }
                    return Ok(list);
                }
                else if (Mode == "2")
                {
                    List<SingleMasterModel> list = new List<SingleMasterModel>();
                    DDT = bl.BL_ExecuteParamSP("uspManageFinancialReports", Mode, ReportID, ALName);
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new SingleMasterModel
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
                bl.BL_WriteErrorMsginLog("FinancialReports", "financialreportparameters/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/financialreportgenerate/get")]
        public IHttpActionResult GeerateData(ReportParameters listParams)
        {
            try
            {
                DataTable DDT = new DataTable();
                if (listParams != null)
                {
                    object[] objParamValue = new object[listParams.lstvFilters.Count];
                    for (int i = 0; i < objParamValue.Length; i++)
                    {
                        objParamValue[i] = !string.IsNullOrEmpty(listParams.lstvFilters[i].Param1) ? listParams.lstvFilters[i].Param1 : null;
                    }
                    DDT = bl.BL_ExecuteParamSP(listParams.ProcedureName, objParamValue);//, listParams.Param2, listParams.Param3, listParams.Param4
                    if (DDT.Rows.Count > 0)
                    {
                        if (listParams.ReportID != "37" && listParams.ReportID != "18" && listParams.ReportID != "20")
                        {
                            string JSONCONV = JsonConvert.SerializeObject(DDT);
                            return Ok(JSONCONV);
                        }
                        else if (listParams.ReportID == "18" || listParams.ReportID == "20")//Profit & Loss
                        {
                            // Create DataTable
                            DataTable dt = new DataTable("AccountSummary");
                            // Define Columns
                            dt.Columns.Add("AccGroupID", typeof(int));
                            dt.Columns.Add("AccGroupName", typeof(string));
                            dt.Columns.Add("Debit", typeof(string));
                            dt.Columns.Add("Credit", typeof(string));
                            dt.Columns.Add("AccType", typeof(string));
                            dt.Columns.Add("SelAccGroupID", typeof(int));
                            dt.Columns.Add("SelAccGroupName", typeof(string));
                            // Add Row
                            dt.Rows.Add(0, "Trading Account", "", "", "Account", 0, "");
                            decimal dTradingTotalDebit = 0, dTradingTotalCredit = 0, SalesAccAmount = 0, ClosingStkAmount = 0, IncomeDirectAmount = 0, OpeningStockAmount = 0,
                                PurchaseAccountAmount = 0, BranchTransferAmount = 0, ExpenditureDirectAmount = 0;
                            //17 - Sales Account
                            SalesAccAmount = DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Debit"])) - DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Credit"]));
                            dTradingTotalDebit = SalesAccAmount >= 0 ? SalesAccAmount : 0.00M;
                            dTradingTotalCredit = SalesAccAmount < 0 ? Math.Abs(SalesAccAmount) : 0.00M;
                            DataRow dr = dt.NewRow();
                            dr["AccGroupID"] = 17;
                            dr["AccGroupName"] = "Sales Account";
                            dr["Debit"] = SalesAccAmount >= 0 ? SalesAccAmount : 0.00m;// DDT.Rows[0][2];
                            dr["Credit"] = SalesAccAmount < 0 ? Math.Abs(SalesAccAmount) : 0.00m;
                            dr["AccType"] = "Group";
                            dr["SelAccGroupID"] = 0;
                            dr["SelAccGroupName"] = "";
                            dt.Rows.Add(dr);
                            //72 - Closing Stock
                            DDT = bl.BL_ExecuteParamSP("uspFinRepProfitLossstage1", objParamValue[0], objParamValue[1], objParamValue[2],
                                objParamValue[3], 72);
                            if (DDT.Rows.Count > 0)
                            {
                                ClosingStkAmount = DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Debit"])) - DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Credit"]));
                                dTradingTotalDebit = ClosingStkAmount >= 0 ? ClosingStkAmount : 0.00M;
                                dTradingTotalCredit = ClosingStkAmount < 0 ? Math.Abs(ClosingStkAmount) : 0.00M;
                                dr = dt.NewRow();
                                dr["AccGroupID"] = 72;
                                dr["AccGroupName"] = "Closing Stock";
                                dr["Debit"] = ClosingStkAmount >= 0 ? ClosingStkAmount : 0.00m;// DDT.Rows[0][2];
                                dr["Credit"] = ClosingStkAmount < 0 ? Math.Abs(ClosingStkAmount) : 0.00m;
                                dr["AccType"] = "Group";
                                dr["SelAccGroupID"] = 0;
                                dr["SelAccGroupName"] = "";
                                dt.Rows.Add(dr);
                            }
                            //10 - Income Direct
                            DDT = bl.BL_ExecuteParamSP("uspFinRepProfitLossstage1", objParamValue[0], objParamValue[1], objParamValue[2],
                                objParamValue[3], 10);
                            if (DDT.Rows.Count > 0)
                            {
                                IncomeDirectAmount = DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Debit"])) - DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Credit"]));
                                dTradingTotalDebit = IncomeDirectAmount >= 0 ? IncomeDirectAmount : 0.00M;
                                dTradingTotalCredit = IncomeDirectAmount < 0 ? Math.Abs(IncomeDirectAmount) : 0.00M;
                                dr = dt.NewRow();
                                dr["AccGroupID"] = 10;
                                dr["AccGroupName"] = "Income Direct";
                                dr["Debit"] = IncomeDirectAmount >= 0 ? IncomeDirectAmount : 0.00m;// DDT.Rows[0][2];
                                dr["Credit"] = IncomeDirectAmount < 0 ? Math.Abs(IncomeDirectAmount) : 0.00m;
                                dr["AccType"] = "Group";
                                dr["SelAccGroupID"] = 0;
                                dr["SelAccGroupName"] = "";
                                dt.Rows.Add(dr);
                            }
                            //73 - Opening Stock
                            DDT = bl.BL_ExecuteParamSP("uspFinRepProfitLossstage1", objParamValue[0], objParamValue[1], objParamValue[2],
                                objParamValue[3], 73);
                            if (DDT.Rows.Count > 0)
                            {
                                OpeningStockAmount = DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Debit"])) - DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Credit"]));
                                dTradingTotalDebit = OpeningStockAmount >= 0 ? OpeningStockAmount : 0.00M;
                                dTradingTotalCredit = OpeningStockAmount < 0 ? Math.Abs(OpeningStockAmount) : 0.00M;
                                dr = dt.NewRow();
                                dr["AccGroupID"] = 73;
                                dr["AccGroupName"] = "Opening Stock";
                                dr["Debit"] = OpeningStockAmount >= 0 ? OpeningStockAmount : 0.00m;// DDT.Rows[0][2];
                                dr["Credit"] = OpeningStockAmount < 0 ? Math.Abs(OpeningStockAmount) : 0.00m;
                                dr["AccType"] = "Group";
                                dr["SelAccGroupID"] = 0;
                                dr["SelAccGroupName"] = "";
                                dt.Rows.Add(dr);
                            }
                            //15 - Purchase Account
                            DDT = bl.BL_ExecuteParamSP("uspFinRepProfitLossstage1", objParamValue[0], objParamValue[1], objParamValue[2],
                                objParamValue[3], 15);
                            if (DDT.Rows.Count > 0)
                            {
                                PurchaseAccountAmount = DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Debit"])) - DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Credit"]));
                                dTradingTotalDebit = PurchaseAccountAmount >= 0 ? PurchaseAccountAmount : 0.00M;
                                dTradingTotalCredit = PurchaseAccountAmount < 0 ? Math.Abs(PurchaseAccountAmount) : 0.00M;
                                dr = dt.NewRow();
                                dr["AccGroupID"] = 15;
                                dr["AccGroupName"] = "Purchase Account";
                                dr["Debit"] = PurchaseAccountAmount >= 0 ? PurchaseAccountAmount : 0.00m;// DDT.Rows[0][2];
                                dr["Credit"] = PurchaseAccountAmount < 0 ? Math.Abs(PurchaseAccountAmount) : 0.00m;
                                dr["AccType"] = "Group";
                                dr["SelAccGroupID"] = 0;
                                dr["SelAccGroupName"] = "";
                                dt.Rows.Add(dr);
                            }

                            //62 - Branch Transfer
                            DDT = bl.BL_ExecuteParamSP("uspFinRepProfitLossstage1", objParamValue[0], objParamValue[1], objParamValue[2],
                                objParamValue[3], 62);
                            if (DDT.Rows.Count > 0)
                            {
                                BranchTransferAmount = DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Debit"])) - DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Credit"]));
                                dTradingTotalDebit = BranchTransferAmount >= 0 ? BranchTransferAmount : 0.00M;
                                dTradingTotalCredit = BranchTransferAmount < 0 ? Math.Abs(BranchTransferAmount) : 0.00M;
                                dr = dt.NewRow();
                                dr["AccGroupID"] = 62;
                                dr["AccGroupName"] = "Branch Transfer";
                                dr["Debit"] = BranchTransferAmount >= 0 ? BranchTransferAmount : 0.00m;// DDT.Rows[0][2];
                                dr["Credit"] = BranchTransferAmount < 0 ? Math.Abs(BranchTransferAmount) : 0.00m;
                                dr["AccType"] = "Group";
                                dr["SelAccGroupID"] = 0;
                                dr["SelAccGroupName"] = "";
                                dt.Rows.Add(dr);
                            }
                            //18 - Expenditure Direct
                            DDT = bl.BL_ExecuteParamSP("uspFinRepProfitLossstage1", objParamValue[0], objParamValue[1], objParamValue[2],
                                objParamValue[3], 18);
                            if (DDT.Rows.Count > 0)
                            {
                                ExpenditureDirectAmount = DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Debit"])) - DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Credit"]));
                                dTradingTotalDebit = ExpenditureDirectAmount >= 0 ? ExpenditureDirectAmount : 0.00M;
                                dTradingTotalCredit = ExpenditureDirectAmount < 0 ? Math.Abs(ExpenditureDirectAmount) : 0.00M;

                                dr = dt.NewRow();
                                dr["AccGroupID"] = 18;
                                dr["AccGroupName"] = "Expenditure Direct";
                                dr["Debit"] = ExpenditureDirectAmount >= 0 ? ExpenditureDirectAmount : 0.00m;// DDT.Rows[0][2];
                                dr["Credit"] = ExpenditureDirectAmount < 0 ? Math.Abs(ExpenditureDirectAmount) : 0.00m;
                                dr["AccType"] = "Group";
                                dr["SelAccGroupID"] = 0;
                                dr["SelAccGroupName"] = "";
                                dt.Rows.Add(dr);
                            }

                            decimal dTotalAmt = SalesAccAmount + ClosingStkAmount + ExpenditureDirectAmount +
                            IncomeDirectAmount + PurchaseAccountAmount + OpeningStockAmount + BranchTransferAmount;

                            dr = dt.NewRow();
                            dr["AccGroupID"] = 0;
                            dr["AccGroupName"] = dTotalAmt < 0 ? "Gross Profit" : "Gross Loss";
                            dr["Debit"] = dTotalAmt < 0 ? dTotalAmt : 0.00m;// DDT.Rows[0][2];
                            dr["Credit"] = dTotalAmt >= 0 ? dTotalAmt : 0.00m;
                            dr["AccType"] = "";
                            dr["SelAccGroupID"] = 0;
                            dr["SelAccGroupName"] = "";
                            dt.Rows.Add(dr);

                            dTradingTotalDebit += dTotalAmt <= 0 ? Math.Abs(dTotalAmt) : 0.00M;
                            dTradingTotalCredit += dTotalAmt > 0 ? dTotalAmt : 0.00M;

                            dr = dt.NewRow();
                            dr["AccGroupID"] = 0;
                            dr["AccGroupName"] = "Total";
                            dr["Debit"] = dTradingTotalDebit;// DDT.Rows[0][2];
                            dr["Credit"] = dTradingTotalCredit;
                            dr["AccType"] = "";
                            dr["SelAccGroupID"] = 0;
                            dr["SelAccGroupName"] = "";
                            dt.Rows.Add(dr);

                            dt.Rows.Add(0, "", "", "", "", 0, "");
                            dt.Rows.Add(0, "Profit & Loss Account", "", "", "", 0, "");
                            dr = dt.NewRow();
                            dr["AccGroupID"] = 0;
                            dr["AccGroupName"] = dTotalAmt < 0 ? "Gross Profit" : "Gross Loss";
                            dr["Debit"] = dTotalAmt >= 0 ? dTotalAmt : 0.00m;// DDT.Rows[0][2];
                            dr["Credit"] = dTotalAmt < 0 ? dTotalAmt : 0.00m;
                            dr["AccType"] = "";
                            dr["SelAccGroupID"] = 0;
                            dr["SelAccGroupName"] = "";
                            dt.Rows.Add(dr);

                            decimal dDiffIncomeIndirectAmount = 0, dDiffExpenditureIndirectAmount = 0, dPLTotalDebit = 0, dPLTotalCredit = 0;
                            // 11 => Income Indirect Acc Group
                            DDT = bl.BL_ExecuteParamSP("uspFinRepProfitLossstage1", objParamValue[0], objParamValue[1], objParamValue[2],
                               objParamValue[3], 11);
                            if (DDT.Rows.Count > 0)
                            {
                                dDiffIncomeIndirectAmount = DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Debit"])) - DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Credit"]));
                                dPLTotalDebit = dDiffIncomeIndirectAmount >= 0 ? dDiffIncomeIndirectAmount : 0.00M;
                                dPLTotalCredit = dDiffIncomeIndirectAmount < 0 ? Math.Abs(dDiffIncomeIndirectAmount) : 0.00M;

                                dr = dt.NewRow();
                                dr["AccGroupID"] = 11;
                                dr["AccGroupName"] = "Income Indirect";
                                dr["Debit"] = dDiffIncomeIndirectAmount >= 0 ? dDiffIncomeIndirectAmount : 0.00m;// DDT.Rows[0][2];
                                dr["Credit"] = dDiffIncomeIndirectAmount < 0 ? Math.Abs(dDiffIncomeIndirectAmount) : 0.00m;
                                dr["AccType"] = "Group";
                                dr["SelAccGroupID"] = 0;
                                dr["SelAccGroupName"] = "";
                                dt.Rows.Add(dr);
                            }

                            // 8 => Expenditure Indirect
                            DDT = bl.BL_ExecuteParamSP("uspFinRepProfitLossstage1", objParamValue[0], objParamValue[1], objParamValue[2],
                               objParamValue[3], 8);
                            if (DDT.Rows.Count > 0)
                            {
                                dDiffExpenditureIndirectAmount = DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Debit"])) - DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Credit"]));
                                dPLTotalDebit = dDiffExpenditureIndirectAmount >= 0 ? dDiffExpenditureIndirectAmount : 0.00M;
                                dPLTotalCredit = dDiffExpenditureIndirectAmount < 0 ? Math.Abs(dDiffExpenditureIndirectAmount) : 0.00M;

                                dr = dt.NewRow();
                                dr["AccGroupID"] = 8;
                                dr["AccGroupName"] = "Expenditure Indirect";
                                dr["Debit"] = dDiffExpenditureIndirectAmount >= 0 ? dDiffExpenditureIndirectAmount : 0.00m;// DDT.Rows[0][2];
                                dr["Credit"] = dDiffExpenditureIndirectAmount < 0 ? Math.Abs(dDiffExpenditureIndirectAmount) : 0.00m;
                                dr["AccType"] = "Group";
                                dr["SelAccGroupID"] = 0;
                                dr["SelAccGroupName"] = "";
                                dt.Rows.Add(dr);
                            }
                            decimal dTempTotalAmt = dTotalAmt;
                            dTotalAmt = dTotalAmt + dDiffIncomeIndirectAmount + dDiffExpenditureIndirectAmount;

                            // This Variable Return Profit And Loss Amont For Balance Sheet Report Only. 
                            // Cannot Use  Anywhere
                            decimal nBalanceSheetProfitAndLossValue = dTotalAmt;

                            dPLTotalDebit += Math.Abs(dTotalAmt);

                            dr = dt.NewRow();
                            dr["AccGroupID"] = 0;
                            dr["AccGroupName"] = dTotalAmt < 0 ? "Net Profit" : "Net Loss";
                            dr["Debit"] = dTotalAmt >= 0 ? dTotalAmt : 0.00m;// DDT.Rows[0][2];
                            dr["Credit"] = dTotalAmt < 0 ? dTotalAmt : 0.00m;
                            dr["AccType"] = "";
                            dr["SelAccGroupID"] = 0;
                            dr["SelAccGroupName"] = "";
                            dt.Rows.Add(dr);


                            dr = dt.NewRow();
                            dr["AccGroupID"] = 0;
                            dr["AccGroupName"] = "Total";
                            dr["Debit"] = dPLTotalDebit + (dTempTotalAmt >= 0.00M ? dTempTotalAmt : 0.00M);// DDT.Rows[0][2];
                            dr["Credit"] = Math.Abs(dPLTotalCredit) + (dTempTotalAmt >= 0.00M ? 0.00M : Math.Abs(dTempTotalAmt));
                            dr["AccType"] = "";
                            dr["SelAccGroupID"] = 0;
                            dr["SelAccGroupName"] = "";
                            dt.Rows.Add(dr);
                            if (listParams.ReportID == "18")
                            {
                                string JSONCONV = JsonConvert.SerializeObject(dt);
                                return Ok(JSONCONV);
                            }
                            else
                            {
                                decimal dTotalCredit = 0.00M;
                                decimal dTotalDebit = 0.00M;
                                dTotalDebit += nBalanceSheetProfitAndLossValue >= 0 ? nBalanceSheetProfitAndLossValue : 0;
                                dTotalCredit += nBalanceSheetProfitAndLossValue < 0 ? Math.Abs(nBalanceSheetProfitAndLossValue) : 0;
                                dt.Rows.Clear();
                                dr = dt.NewRow();
                                dr["AccGroupID"] = 0;
                                dr["AccGroupName"] = nBalanceSheetProfitAndLossValue >= 0 ? "Loss for The Period" : "Profit for The Period";
                                dr["Debit"] = nBalanceSheetProfitAndLossValue >= 0 ? nBalanceSheetProfitAndLossValue : 0;// DDT.Rows[0][2];
                                dr["Credit"] = nBalanceSheetProfitAndLossValue < 0 ? Math.Abs(nBalanceSheetProfitAndLossValue) : 0;
                                dr["AccType"] = "Report";
                                dr["SelAccGroupID"] = 0;
                                dr["SelAccGroupName"] = "";
                                dt.Rows.Add(dr);
                                //SELECT FAGroup,AccountGroupName FROM tblFAGroup WHERE TypeID=1 AND ParentGroup=0
                                //Asset Group Data
                                dt.Rows.Add(0, "", "", "", "", 0, "");
                                dt.Rows.Add(0, "Asset", "", "", "", 0, "");
                                DataTable dtFagrps = bl.BL_ExecuteSqlQuery("SELECT FAGroup,AccountGroupName FROM tblFAGroup WHERE TypeID=1 AND ParentGroup=0");
                                for (int i = 0; i < dtFagrps.Rows.Count; i++)
                                {
                                    int FAGID = bl.BL_nValidation(dtFagrps.Rows[i][0]);
                                    string FAGName = dtFagrps.Rows[i][1].ToString();
                                    DDT = bl.BL_ExecuteParamSP("uspFinRepProfitLossstage1", objParamValue[0], objParamValue[1], objParamValue[2],
                               objParamValue[3], FAGID);

                                    decimal fag1 = DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Debit"])) - DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Credit"]));
                                    dTotalDebit += fag1 >= 0 ? fag1 : 0.00M;
                                    dTotalCredit += fag1 < 0 ? Math.Abs(fag1) : 0.00M;


                                    dr = dt.NewRow();
                                    dr["AccGroupID"] = FAGID;
                                    dr["AccGroupName"] = FAGName;
                                    dr["Debit"] = fag1 >= 0 ? fag1 : 0.00m;// DDT.Rows[0][2];
                                    dr["Credit"] = fag1 < 0 ? Math.Abs(fag1) : 0.00m;
                                    dr["AccType"] = "Group";
                                    dr["SelAccGroupID"] = 0;
                                    dr["SelAccGroupName"] = "";
                                    dt.Rows.Add(dr);
                                }
                                //Liablities Group Data
                                dt.Rows.Add(0, "", "", "", "", 0, "");
                                dt.Rows.Add(0, "Liablities", "", "", "", 0, "");
                                //Capital Account Data
                                // 3 => Capital Account
                                DDT = bl.BL_ExecuteParamSP("uspFinRepProfitLossstage1", objParamValue[0], objParamValue[1], objParamValue[2],
                                   objParamValue[3], 3);
                                if (DDT.Rows.Count > 0)
                                {
                                    decimal CapAccData = DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Debit"])) - DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Credit"]));
                                    dTotalDebit = CapAccData >= 0 ? CapAccData : 0.00M;
                                    dTotalCredit = CapAccData < 0 ? Math.Abs(CapAccData) : 0.00M;

                                    dr = dt.NewRow();
                                    dr["AccGroupID"] = 3;
                                    dr["AccGroupName"] = "Capital Account";
                                    dr["Debit"] = CapAccData >= 0 ? CapAccData : 0.00m;// DDT.Rows[0][2];
                                    dr["Credit"] = CapAccData < 0 ? Math.Abs(CapAccData) : 0.00m;
                                    dr["AccType"] = "Group";
                                    dr["SelAccGroupID"] = 0;
                                    dr["SelAccGroupName"] = "";
                                    dt.Rows.Add(dr);
                                }
                                //Other Group Data(Borrowings - Long Term,Borrowings - Short Term,,Current Liabilities & Provisions,etc)
                                dtFagrps = bl.BL_ExecuteSqlQuery("SELECT FAGroup,AccountGroupName FROM tblFAGroup WHERE TypeID=7 AND ParentGroup=0");
                                for (int i = 0; i < dtFagrps.Rows.Count; i++)
                                {
                                    int FAGID = bl.BL_nValidation(dtFagrps.Rows[i][0]);
                                    string FAGName = dtFagrps.Rows[i][1].ToString();
                                    DDT = bl.BL_ExecuteParamSP("uspFinRepProfitLossstage1", objParamValue[0], objParamValue[1], objParamValue[2],
                               objParamValue[3], FAGID);

                                    decimal fag1 = DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Debit"])) - DDT.AsEnumerable().Sum(r => Convert.ToDecimal(r["Credit"]));
                                    dTotalDebit += fag1 >= 0 ? fag1 : 0.00M;
                                    dTotalCredit += fag1 < 0 ? Math.Abs(fag1) : 0.00M;


                                    dr = dt.NewRow();
                                    dr["AccGroupID"] = FAGID;
                                    dr["AccGroupName"] = FAGName;
                                    dr["Debit"] = fag1 >= 0 ? fag1 : 0.00m;// DDT.Rows[0][2];
                                    dr["Credit"] = fag1 < 0 ? Math.Abs(fag1) : 0.00m;
                                    dr["AccType"] = "Group";
                                    dr["SelAccGroupID"] = 0;
                                    dr["SelAccGroupName"] = "";
                                    dt.Rows.Add(dr);
                                }

                                dr = dt.NewRow();
                                dr["AccGroupID"] = 0;
                                dr["AccGroupName"] = "Total";
                                dr["Debit"] = dPLTotalDebit + (dTempTotalAmt >= 0.00M ? dTempTotalAmt : 0.00M);// DDT.Rows[0][2];
                                dr["Credit"] = Math.Abs(dPLTotalCredit) + (dTempTotalAmt >= 0.00M ? 0.00M : Math.Abs(dTempTotalAmt));
                                dr["AccType"] = "";
                                dr["SelAccGroupID"] = 0;
                                dr["SelAccGroupName"] = "";
                                dt.Rows.Add(dr);
                                string JSONCONV = JsonConvert.SerializeObject(dt);
                                return Ok(JSONCONV);
                            }
                        }
                        else if (listParams.ReportID == "37")//Detail Trail Balance Type 2
                        {
                            DetailTBType2Parent(DDT);
                            int nParentID;
                            DataTable dtParent = bl.BL_ExecuteSqlQuery("SELECT AccountGroupName,LevelID,ParentGroup ,FAGroup AccountGroupId FROM tblFAGroup WHERE LevelID = 1 Order by AccountGroupName");
                            foreach (DataRow dr in dtParent.Rows)
                            {
                                nParentID = Convert.ToInt32(dr[3].ToString());
                                if (Convert.ToInt32(dr[2].ToString()) == 0)
                                {
                                    decimal crsum = dtAddAccDetails.AsEnumerable().Where(r => r.Field<int>("CommonPariD") == nParentID).Sum(r => r.Field<decimal>("Credit"));
                                    decimal drsum = dtAddAccDetails.AsEnumerable().Where(r => r.Field<int>("CommonPariD") == nParentID).Sum(r => r.Field<decimal>("Debit"));
                                    for (int i = 0; i < dtAddAccDetails.Rows.Count; i++)
                                    {
                                        if (crsum == 0 && crsum == 0)
                                        {
                                            break;
                                        }
                                        if (nParentID == Convert.ToInt32(dtAddAccDetails.Rows[i][1]) && Convert.ToString(dtAddAccDetails.Rows[i][0]) == "Account Group")
                                        {
                                            dtAddAccDetails.Rows[i][4] = Convert.ToString(crsum);
                                            dtAddAccDetails.Rows[i][5] = Convert.ToString(drsum);
                                            break;
                                        }
                                    }
                                }
                            }
                            dtAddAccDetails.Columns.Remove("LevelID");
                            dtAddAccDetails.Columns.Remove("CommonPariD");
                            string JSONCONV = JsonConvert.SerializeObject(dtAddAccDetails);
                            return Ok(JSONCONV);
                        }
                        else
                        {
                            return Ok();
                        }
                    }
                    else
                    {
                        return Ok();
                    }
                }
                else
                {

                    return Ok();
                }
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("FinancialReports", "financialreportgenerate/get", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/financialrepcolumnsettings/getcolumnsettings")]
        public IHttpActionResult GetGendralColumnData(string Mode, string FormID, string TableID, string FormorReport)
        {
            try
            {
                if (Mode == "1")
                {
                    DataTable dtResult = bl.BL_ExecuteParamSP("uspGetGendralColumnSettings", Mode, FormID, TableID, FormorReport);
                    string JSONCONV = JsonConvert.SerializeObject(dtResult);
                    return Ok(JSONCONV);
                }
                if (Mode == "2")
                {
                    List<ColumnSettingsDataModel> list = new List<ColumnSettingsDataModel>();
                    DataTable dtResult = bl.BL_ExecuteParamSP("uspGetGendralColumnSettings", Mode, FormID, TableID, FormorReport);
                    for (int i = 0; i < dtResult.Rows.Count; i++)
                    {
                        //field	header	type	width	align	visible	EnableColumnMenu	ShowinColumnOption	Total	TotalYN	EnableSum	EnableAvg	precision	ClickPopup
                        list.Add(new ColumnSettingsDataModel()
                        {
                            field = dtResult.Rows[i]["ColumnName"].ToString(),
                            header = dtResult.Rows[i]["DisplayColumnName"].ToString(),
                            type = "label",
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
                            precision = dtResult.Rows[i]["precision"].ToString(),
                            PrintYN = dtResult.Rows[i]["PrintYN"].ToString() == "1" ? true : false,
                            Printwidth = Convert.ToInt32(dtResult.Rows[i]["PrintWidth"].ToString()),
                            PrintColumnName = dtResult.Rows[i]["PrintColumnName"].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("FinancialReports", "financialrepcolumnsettings/getcolumnsettings", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/financialrepcolumnsettings/Savecolumnsettings")]
        public IHttpActionResult saveGenColumnData(List<ColumnSettingsModel> ColumnSettingData)
        {
            try
            {
                if (ColumnSettingData != null)
                {
                    var list = new List<object>();
                    foreach (ColumnSettingsModel item in ColumnSettingData)
                    {
                        bl.BL_ExecuteParamSP("uspSaveGendralColumnSettings", 1, item.FormID, item.TableID, item.ColumnID, item.FormorReport,
                          item.DisplayColumnName, item.Width, item.Visible, item.Alignment, item.DisplayIndex, item.TotalYN, item.EnableSum,
                          item.EnableAvg, item.EnableCount, item.EnableUnique, item.EnableColumnMenu, item.ShowinColumnOption, item.PrintYN ? 1 : 0, item.PrintColumnName,
                          item.Printwidth);
                    }
                    List<ColumnSettingsDataModel> Columnlist = new List<ColumnSettingsDataModel>();
                    DataTable dtResult = bl.BL_ExecuteParamSP("uspGetGendralColumnSettings", 2, ColumnSettingData[0].FormID, ColumnSettingData[0].TableID, ColumnSettingData[0].FormorReport);
                    for (int i = 0; i < dtResult.Rows.Count; i++)
                    {
                        //field	header	type	width	align	visible	EnableColumnMenu	ShowinColumnOption	Total	TotalYN	EnableSum	EnableAvg	precision	ClickPopup
                        Columnlist.Add(new ColumnSettingsDataModel()
                        {
                            field = dtResult.Rows[i]["ColumnName"].ToString(),
                            header = dtResult.Rows[i]["DisplayColumnName"].ToString(),
                            type = "label",
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
                            precision = dtResult.Rows[i]["precision"].ToString(),
                            PrintYN = dtResult.Rows[i]["PrintYN"].ToString() == "1" ? true : false,
                            Printwidth = Convert.ToInt32(dtResult.Rows[i]["PrintWidth"].ToString()),
                            PrintColumnName = dtResult.Rows[i]["PrintColumnName"].ToString(),
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
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("FinancialReports", "financialrepcolumnsettings/Savecolumnsettings", ex.Message);
            }
            return Ok();
        }

        int CommonParID = 0;
        private void DetailTBType2Parent(DataTable dtHeader)
        {
            dtAddAccDetails.Rows.Clear();
            dtAddAccDetails.Columns.Clear();
            if (dtAddAccDetails.Columns.Count == 0)
            {
                dtAddAccDetails.Columns.Add("Type", typeof(string));
                dtAddAccDetails.Columns.Add("AccountID", typeof(int));
                dtAddAccDetails.Columns.Add("Particulars", typeof(string));
                dtAddAccDetails.Columns.Add("LevelID", typeof(int));
                dtAddAccDetails.Columns.Add("Credit", typeof(decimal));
                dtAddAccDetails.Columns.Add("Debit", typeof(decimal));
                dtAddAccDetails.Columns.Add("CommonPariD", typeof(int));
            }
            TreeNode tnParent = null;
            int nLevelID;
            int nParentID;
            DataTable dtParent = bl.BL_ExecuteSqlQuery("SELECT AccountGroupName,LevelID,ParentGroup ,FAGroup AccountGroupId FROM tblFAGroup WHERE LevelID = 1 Order by AccountGroupName");
            decimal CrValue = 0, DrValue = 0;
            decimal SumCrValue = 0, SumDrValue = 0;
            int ndtRowID = 0;
            foreach (DataRow dr in dtParent.Rows)
            {
                nParentID = Convert.ToInt16(dr[3].ToString());
                CommonParID = nParentID;
                if (Convert.ToInt16(dr[2].ToString()) == 0)
                {
                    decimal crsum = dtHeader.AsEnumerable().Where(r => r.Field<int>("AccGrpID") == nParentID).Sum(r => r.Field<decimal>("Credit"));
                    decimal drsum = dtHeader.AsEnumerable().Where(r => r.Field<int>("AccGrpID") == nParentID).Sum(r => r.Field<decimal>("Debit"));
                    SumCrValue = 0;// dtRawData.AsEnumerable().Where(r => r.Field<int>("AccGrpID") == nParentID).Sum(r => r.Field<decimal>("Credit"));
                    SumDrValue = 0;// dtRawData.AsEnumerable().Where(r => r.Field<int>("AccGrpID") == nParentID).Sum(r => r.Field<decimal>("Debit"));

                    DataRow drr = dtAddAccDetails.NewRow();
                    drr[0] = "Account Group";
                    drr[1] = nParentID;
                    drr[2] = dr[0].ToString();
                    drr[3] = 1;
                    drr[4] = crsum;// crsum > 0 ? crsum.ToString() : ""; // SumCrValue > 0 ? SumCrValue.ToString() : "";
                    drr[5] = drsum;// drsum > 0 ? drsum.ToString() : ""; // SumDrValue > 0 ? SumDrValue.ToString() : "";
                    drr[6] = CommonParID;
                    dtAddAccDetails.Rows.Add(drr);
                    ndtRowID = (dtAddAccDetails.Rows.Count - 1);
                    //DataTable dtAcc = GKSShineBL.BL_ExecuteSqlQuery("SELECT AccountId,AccountName from tblFAAccount WHERE AccountGroup =" + nParentID);
                    DataTable dtAcc = new DataTable();
                    DataRow[] drrAcc = dtHeader.Select("AccGrpID = " + nParentID, string.Empty);
                    if (drrAcc.Length > 0)
                    {
                        dtAcc = drrAcc.CopyToDataTable();
                    }

                    for (int i = 0; i < dtAcc.Rows.Count; i++)
                    {

                        CrValue = Convert.ToDecimal(dtAcc.Rows[i]["Credit"].ToString());
                        DrValue = Convert.ToDecimal(dtAcc.Rows[i]["Debit"].ToString());
                        SumCrValue += CrValue;
                        SumDrValue += DrValue;

                        drr = dtAddAccDetails.NewRow();
                        drr[0] = "Account Name";
                        drr[1] = dtAcc.Rows[i][1].ToString();
                        drr[2] = " * " + dtAcc.Rows[i][3].ToString();
                        drr[3] = 2;
                        drr[4] = CrValue;// CrValue > 0 ? CrValue.ToString() : "";
                        drr[5] = DrValue;// DrValue > 0 ? DrValue.ToString() : "";
                        drr[6] = 0;
                        dtAddAccDetails.Rows.Add(drr);

                    }
                    //dtAddAccDetails.Rows[ndtRowID]["Credit"] = SumCrValue;
                    //dtAddAccDetails.Rows[ndtRowID]["Debit"] = SumDrValue;

                    nLevelID = Convert.ToInt16(dr[1].ToString());
                    //tnParent = treeCustomerHierarchyDefn.Nodes.Add(dr[0].ToString());
                    //tnParent.BackColor = Color.Aqua;
                    DetailTBType2Child(dtHeader,nLevelID + 1, tnParent, nParentID, ndtRowID);
                }
            }
        }
        public string Retunarrow(int No, string AccType)
        {
            string arr = "";
            for (int i = 0; i < No; i++)
            {
                arr += "     ";
            }
            return arr + (AccType == "Account Group" ? "> " : "* ");
        }
        private void DetailTBType2Child(DataTable dtHeader, int i, TreeNode parent, int nParentID, int ParRowID)
        {
            try
            {
                TreeNode child = null;
                int nChildID;
                DataTable lvl2 = bl.BL_ExecuteSqlQuery("SELECT AccountGroupName," + nParentID + "," + i + ",FAGroup AccountGroupId FROM tblFAGroup WHERE ParentGroup = " + nParentID + " AND LevelID = " + i + " ORDER BY AccountGroupName"); //BL_GetLevelbyData("FAGroupHiera", nParentID.ToString(), i.ToString());
                int d = lvl2.Rows.Count;
                string arrow = "";
                decimal SumCrValue = 0, SumDrValue = 0;
                decimal CrValue = 0, DrValue = 0;
                int ndtRowID = 0;
                foreach (DataRow dr in lvl2.Rows)
                {
                    string strkhg = dr[0].ToString();
                    //child = parent.Nodes.Add(dr[0].ToString());
                    nChildID = Convert.ToInt16(dr[3].ToString());
                    arrow = Retunarrow(i, "Account Group");
                    decimal crsum = dtHeader.AsEnumerable().Where(r => r.Field<int>("AccGrpID") == nChildID).Sum(r => r.Field<decimal>("Credit"));
                    decimal drsum = dtHeader.AsEnumerable().Where(r => r.Field<int>("AccGrpID") == nChildID).Sum(r => r.Field<decimal>("Debit"));
                    SumCrValue = 0;// dtRawData.AsEnumerable().Where(r => r.Field<int>("AccGrpID") == nChildID).Sum(r => r.Field<decimal>("Credit"));
                    SumDrValue = 0;// dtRawData.AsEnumerable().Where(r => r.Field<int>("AccGrpID") == nChildID).Sum(r => r.Field<decimal>("Debit"));

                    DataRow drr = dtAddAccDetails.NewRow();
                    drr[0] = "Account Group";
                    drr[1] = nChildID;
                    drr[2] = arrow + dr[0].ToString();
                    drr[3] = (i);
                    drr[4] = crsum;// crsum > 0 ? crsum.ToString() : ""; //SumCrValue > 0 ? SumCrValue.ToString() : "";
                    drr[5] = drsum;// drsum > 0 ? drsum.ToString() : ""; //SumDrValue > 0 ? SumDrValue.ToString() : "";
                    drr[6] = CommonParID;
                    dtAddAccDetails.Rows.Add(drr);
                    ndtRowID = (dtAddAccDetails.Rows.Count - 1);

                    DataTable dtAcc = new DataTable();
                    DataRow[] drrAcc = dtHeader.Select("AccGrpID = " + nChildID, string.Empty);
                    if (drrAcc.Length > 0)
                    {
                        dtAcc = drrAcc.CopyToDataTable();
                    }

                    //DataTable dtAcc = GKSShineBL.BL_ExecuteSqlQuery("SELECT AccountId,AccountName from tblFAAccount WHERE AccountGroup =" + nChildID);
                    arrow = Retunarrow(i + 1, "Account Name");
                    for (int k = 0; k < dtAcc.Rows.Count; k++)
                    {
                        CrValue = Convert.ToDecimal(dtAcc.Rows[k]["Credit"].ToString());
                        DrValue = Convert.ToDecimal(dtAcc.Rows[k]["Debit"].ToString());
                        SumCrValue += CrValue;
                        SumDrValue += DrValue;

                        if (CrValue > 0 || DrValue > 0)
                        {
                            drr = dtAddAccDetails.NewRow();
                            drr[0] = "Account Name";
                            drr[1] = dtAcc.Rows[k][1].ToString();
                            drr[2] = arrow + dtAcc.Rows[k][3].ToString();
                            drr[3] = (i + 1);
                            drr[4] = CrValue;// CrValue > 0 ? CrValue.ToString() : "";
                            drr[5] = DrValue;// DrValue > 0 ? DrValue.ToString() : "";
                            drr[6] = 0;
                            dtAddAccDetails.Rows.Add(drr);
                        }
                    }
                    int n = Convert.ToInt16(dr[1].ToString());
                    DetailTBType2Child(dtHeader,i + 1, child, nChildID, ndtRowID);
                }
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("DetailTBType2Child", "populateTreeView", ex.Message);
            }
        }
    }
}
