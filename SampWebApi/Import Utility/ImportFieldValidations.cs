using SampWebApi.BuisnessLayer;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;
using static System.Windows.Forms.VisualStyles.VisualStyleElement.TreeView;

namespace SampWebApi.Import_Utility
{    
    public class ImportFieldValidations
    {
        clsBusinessLayer objBL = new clsBusinessLayer();
        public int BranchID { get; set; }
        public int VendorID { get; set; }
        public int CustomerID { get; set; }
        public int PriceTypeID { get; set; }
        public int PaymentModeID { get; set; }
        public int CreditTermID { get; set; }
        public int TaxTypeID { get; set; }
        public int ProductID { get; set; }
        public int BeatID { get; set; }
        public int SalesmanID { get; set; }
        public int TaxID { get; set; }
        public int UOMID { get; set; }
        public string SaleSRBillPRHeaderValidation(DataTable dtCheck)
        {
            string RowError = "";
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["DOC ID *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["DOC ID *"].ToString()))
                {
                    RowError += "DOC ID * : Invalid Characters\n";
                }
            }
            else
            {
                RowError += "DOC ID * : DOC ID should not be empty\n";
            }
            string strDocPrefix = dtCheck.Rows[0]["DOC PREFIX *"].ToString().ToLower();
            if (!string.IsNullOrEmpty(strDocPrefix))
            {
                if (!objBL.BL_AlphaNumericSpl(strDocPrefix))
                {
                    RowError += "DOC PREFIX * : Invalid Characters\n";
                }
                else
                {
                    var validPrefixes = new[] { "bill", "sr", "pr", "sale" };
                    if (!validPrefixes.Contains(strDocPrefix))
                    {
                        RowError += "DOC PREFIX Should be [Bill = BILL, Purchase Return = PR, Sales = SALES, Sales Return = SR]";
                    }
                }
            }
            else
            {
                RowError += "DOC PREFIX * : DOC ID should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["DATE *"].ToString()))
            {
                if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["DATE *"].ToString()))
                {
                    RowError += "DATE * : Invalid Date Format(Format : dd/MM/yyyy)\n";
                }
            }
            else
            {
                RowError += "DATE * : DATE should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["BRANCH NAME *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["BRANCH NAME *"].ToString()))
                {
                    RowError += "BRANCH NAME * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 7, 3, dtCheck.Rows[0]["BRANCH NAME *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* BRANCH NAME("+ dtCheck.Rows[0]["BRANCH NAME *"].ToString() + ") not found in Database\n";
                        BranchID = 0;
                    }
                    else
                    {
                        BranchID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "BRANCH NAME * : Branch Name should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PARTY NAME *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["PARTY NAME *"].ToString()))
                {
                    RowError += "PARTY NAME * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 8, 3, dtCheck.Rows[0]["PARTY NAME *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* PARTY NAME(" + dtCheck.Rows[0]["BRANCH NAME *"].ToString() + ") not found in Database\n";
                        CustomerID = 0;
                        PriceTypeID = 0;
                        TaxTypeID = 0;
                    }
                    else
                    {
                        CustomerID = Convert.ToInt32(dt.Rows[0][0].ToString());
                        PriceTypeID = Convert.ToInt32(dt.Rows[0]["PriceTypeID"].ToString());
                        TaxTypeID = Convert.ToInt32(dt.Rows[0]["TaxTypeID"].ToString());
                    }
                }
            }
            else
            {
                RowError += "PARTY NAME * : PARTY NAME should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PAYMENT MODE *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["PAYMENT MODE *"].ToString()))
                {
                    RowError += "PAYMENT MODE * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 14, 3, dtCheck.Rows[0]["PAYMENT MODE *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* PAYMENT MODE(" + dtCheck.Rows[0]["PAYMENT MODE *"].ToString() + ") not found in Database\n";
                        PaymentModeID = 0;
                    }
                    else
                    {
                        PaymentModeID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "PAYMENT MODE * : PAYMENT MODE should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["CREDIT TERM *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["CREDIT TERM *"].ToString()))
                {
                    RowError += "CREDIT TERM * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 15, 3, dtCheck.Rows[0]["CREDIT TERM *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* CREDIT TERM(" + dtCheck.Rows[0]["CREDIT TERM *"].ToString() + ") not found in Database\n";
                        PaymentModeID = 0;
                    }
                    else
                    {
                        PaymentModeID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "CREDIT TERM * : CREDIT TERM should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["STATUS *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["STATUS *"].ToString()))
                {
                    RowError += "STATUS * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 16, 3, dtCheck.Rows[0]["STATUS *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* STATUS(" + dtCheck.Rows[0]["STATUS *"].ToString() + ") not found in Database\n";
                        PaymentModeID = 0;
                    }
                    else
                    {
                        PaymentModeID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "STATUS * : STATUS should not be empty\n";
            }
            return RowError;
        }
    }
}