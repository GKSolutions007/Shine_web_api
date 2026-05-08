using DocumentFormat.OpenXml.Spreadsheet;
using DocumentFormat.OpenXml.Wordprocessing;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;
using System.Windows.Forms;
using static iTextSharp.text.pdf.qrcode.Version;
using static System.Windows.Forms.VisualStyles.VisualStyleElement.TreeView;

namespace SampWebApi.Import_Utility
{
    public class ImportFieldValidations
    {
        clsBusinessLayer objBL = new clsBusinessLayer();
        public int BranchID { get; set; }
        public int PartyID { get; set; }
        public int PriceTypeID { get; set; }
        public int PaymentModeID { get; set; }
        public int StatusID { get; set; }
        public int CreditTermID { get; set; } = 0;
        public int TaxTypeID { get; set; }
        public int ProductID { get; set; }
        public int BeatID { get; set; }
        public int SalesmanID { get; set; }
        public int TaxID { get; set; }
        public int UOMID { get; set; }
        public int VehicleID { get; set; } = 0;
        public int TransactionTypeSFD { get; set; }
        public int ReturnTypeID { get; set; } = 0;
        public int ReasonID { get; set; } = 0;
        public decimal TaxPern { get; set; } = 0;
        #region Fields for Save
        decimal taxValue = 0, uomcr = 0, qty = 0, freeqty = 0, dmgQty = 0, prodDiscPern = 0;
        decimal price = 0, Saleprice = 0, ECPprice = 0, SPLprice = 0, MRP = 0, Returnprice = 0;
        decimal goodsAmt = 0, prodDiscAmt = 0, baseAmt = 0, BillTransAmount = 0, BillDiffAmt = 0, dUomTax = 0;
        decimal CumGross = 0, CumGoods = 0, CumTax = 0, CumNet = 0, CumProdDiscAmt = 0, CumTradeDiscAmt = 0,
            CumAddnlDiscAmt = 0, CumDiffGross = 0, CumDiffNet = 0;
        decimal tradeDiscAmt = 0, addnlDiscAmt = 0, grossAmt = 0, taxAmt = 0, itemNetAmt = 0;
        int BaseUOMID = 0, TrackInvYN = 0, TrackBatchYN = 0, TrackPKDYN = 0, TrackSerialYN = 0;
        string HSN = "";
        #endregion
        //int docidcheckmode = strDocPrefix == "bill" ? 19 : strDocPrefix == "pr" ? 20 : strDocPrefix == "sales" ? 21 : strDocPrefix == "sr" ? 22 : 0;
        public string SaleSRBillPRHeaderValidation(DataTable dtCheck)
        {
            string RowError = "";
            #region Mandatory Field Validation

            ValidateAlphaNumericSplField(dtCheck.Rows[0], "DOC ID *", true, ref RowError);
            string strDocPrefix = dtCheck.Rows[0]["DOC PREFIX *"].ToString().ToLower();
            int docidcheckmode = strDocPrefix == "bill" ? 19 : strDocPrefix == "pr" ? 20 : strDocPrefix == "sales" ? 21 : strDocPrefix == "sr" ? 22 : 0;
            DataTable dtdocidcheck = objBL.BL_ExecuteParamSP("uspgetsetImportExport", docidcheckmode, 3, dtCheck.Rows[0]["DOC ID *"].ToString());
            if (dtdocidcheck.Rows.Count > 0)
            {
                RowError += "* DOC ID(" + dtCheck.Rows[0]["DOC ID *"].ToString() + ") already exists/imported\n";
            }
            if (!string.IsNullOrEmpty(strDocPrefix))
            {
                if (!objBL.BL_AlphaNumericSpl(strDocPrefix))
                {
                    RowError += "DOC PREFIX * : Invalid Characters\n";
                }
                else
                {
                    var validPrefixes = new[] { "bill", "sr", "pr", "sales" };
                    if (!validPrefixes.Contains(strDocPrefix))
                    {
                        RowError += "DOC PREFIX Should be [Bill = BILL, Purchase Return = PR, Sales = SALES, Sales Return = SR]\n";
                    }
                }
            }
            else
            {
                RowError += "DOC PREFIX * : DOC ID should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["DOC DATE *"].ToString()))
            {
                if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["DOC DATE *"].ToString()))
                {
                    RowError += "DOC DATE * : Invalid Date Format(Format : dd/MM/yyyy)\n";
                }
            }
            else
            {
                RowError += "DOC DATE * : DOC DATE should not be empty\n";
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
                        RowError += "* BRANCH NAME(" + dtCheck.Rows[0]["BRANCH NAME *"].ToString() + ") not found in Database\n";
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
                    DataTable dt = new DataTable();
                    if (strDocPrefix == "sales" || strDocPrefix == "sr")
                    {
                        dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 8, 3, dtCheck.Rows[0]["PARTY NAME *"].ToString());
                        if (dt.Rows.Count == 0)
                        {
                            RowError += "* PARTY NAME(" + dtCheck.Rows[0]["BRANCH NAME *"].ToString() + ") not found in Database\n";
                            PartyID = 0;
                            PriceTypeID = 0;
                            TaxTypeID = 0;
                        }
                        else
                        {
                            PartyID = Convert.ToInt32(dt.Rows[0][0].ToString());
                            PriceTypeID = Convert.ToInt32(dt.Rows[0]["PriceTypeID"].ToString());
                            TaxTypeID = Convert.ToInt32(dt.Rows[0]["TaxTypeID"].ToString());
                        }
                    }
                    else if (strDocPrefix == "bill" || strDocPrefix == "pr")
                    {
                        dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 4, 3, dtCheck.Rows[0]["PARTY NAME *"].ToString());
                        if (dt.Rows.Count == 0)
                        {
                            RowError += "* PARTY NAME(" + dtCheck.Rows[0]["BRANCH NAME *"].ToString() + ") not found in Database\n";
                            PartyID = 0;
                            TaxTypeID = 0;
                        }
                        else
                        {
                            PartyID = Convert.ToInt32(dt.Rows[0][0].ToString());
                            TaxTypeID = Convert.ToInt32(dt.Rows[0]["TaxTypeID"].ToString());
                        }
                    }
                }
            }
            else
            {
                RowError += "PARTY NAME * : PARTY NAME should not be empty\n";
            }
            if (strDocPrefix == "sales" || strDocPrefix == "bill")
            {
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
                            CreditTermID = 0;
                        }
                        else
                        {
                            CreditTermID = Convert.ToInt32(dt.Rows[0][0].ToString());
                        }
                    }
                }
                else
                {
                    RowError += "CREDIT TERM * : CREDIT TERM should not be empty\n";
                }
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
                        StatusID = 0;
                    }
                    else
                    {
                        StatusID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "STATUS * : STATUS should not be empty\n";
            }
            ValidateNumericField(dtCheck.Rows[0], "NET AMOUNT *", true, ref RowError);
            #endregion
            #region Non-Mandatory Field Validations

            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["BEAT NAME"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["BEAT NAME"].ToString()))
                {
                    RowError += "BEAT NAME : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 9, 3, dtCheck.Rows[0]["BEAT NAME"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "BEAT NAME(" + dtCheck.Rows[0]["BEAT NAME"].ToString() + ") not found in Database\n";
                        BeatID = 0;
                    }
                    else
                    {
                        BeatID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                BeatID = 0;
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["SALESMAN NAME"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["SALESMAN NAME"].ToString()))
                {
                    RowError += "SALESMAN NAME : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 10, 3, dtCheck.Rows[0]["SALESMAN NAME"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "SALESMAN NAME(" + dtCheck.Rows[0]["SALESMAN NAME"].ToString() + ") not found in Database\n";
                        SalesmanID = 0;
                    }
                    else
                    {
                        SalesmanID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                SalesmanID = 0;
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["VECHICLE NUMBER"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["VECHICLE NUMBER"].ToString()))
                {
                    RowError += "VECHICLE NUMBER : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 17, 3, dtCheck.Rows[0]["VECHICLE NUMBER"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "VECHICLE NUMBER(" + dtCheck.Rows[0]["VECHICLE NUMBER"].ToString() + ") not found in Database\n";
                        VehicleID = 0;
                    }
                    else
                    {
                        VehicleID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                VehicleID = 0;
            }

            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["OTHER CHARGE"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["OTHER CHARGE"].ToString()))
                {
                    RowError += "OTHER CHARGE : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["OTHER CHARGE"].ToString()) > 100)
                    {
                        RowError += "OTHER CHARGE : OTHER CHARGE % should be less than 100 only\n";
                    }
                }
            }
            if (strDocPrefix == "Sale" || strDocPrefix == "pr")
            {
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TRANSACTION TYPE"].ToString()))
                {
                    if (!objBL.BL_Numeric(dtCheck.Rows[0]["TRANSACTION TYPE"].ToString()))
                    {
                        RowError += "TRANSACTION TYPE : Invalid character(Numeric Only)\n";
                    }
                    else
                    {
                        var validtranstype = new[] { "1", "2", "3" };
                        if (!validtranstype.Contains(dtCheck.Rows[0]["TRANSACTION TYPE"].ToString()))
                        {
                            RowError += "TRANSACTION TYPE : Must be a Number (1 - Sales Invoice,2 - Saleable Return,3 - Damage Return)";
                        }
                    }
                }
            }
            if (strDocPrefix == "sr" || strDocPrefix == "pr")
            {
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["RETURN TYPE"].ToString()))
                {
                    if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["RETURN TYPE"].ToString()))
                    {
                        RowError += "RETURN TYPE : Invalid character(Numeric Only)\n";
                    }
                    else
                    {
                        DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 18, 3, dtCheck.Rows[0]["RETURN TYPE"].ToString());
                        if (dt.Rows.Count == 0)
                        {
                            RowError += "RETURN TYPE(" + dtCheck.Rows[0]["RETURN TYPE"].ToString() + ") not found in Database\n";
                            ReturnTypeID = 0;
                        }
                        else
                        {
                            ReturnTypeID = Convert.ToInt32(dt.Rows[0][0].ToString());
                        }
                    }
                }
                else
                {
                    ReturnTypeID = 0;
                }
            }

            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TRANSPORT MODE"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["TRANSPORT MODE"].ToString()))
                {
                    RowError += "TRANSPORT MODE : Invalid character\n";
                }
                else
                {
                    var validtransportmode = new[] { "Road", "Rail", "Air", "Ship/Road cum ship" };
                    if (!validtransportmode.Contains(dtCheck.Rows[0]["TRANSPORT MODE"].ToString()))
                    {
                        RowError += "TRANSPORT MODE : Transport Mode Must be Road, Rail, Air ,Ship/Road cum ship";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TRANSPORT TYPE"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["TRANSPORT TYPE"].ToString()))
                {
                    RowError += "TRANSPORT TYPE : Invalid character\n";
                }
                else
                {
                    var validtransportmode = new[] { "Regular", "ODC" };
                    if (!validtransportmode.Contains(dtCheck.Rows[0]["TRANSPORT TYPE"].ToString()))
                    {
                        RowError += "TRANSPORT TYPE : Transport Type Must be Regular, ODC";
                    }
                }
            }

            ValidatePercentageNumericField(dtCheck.Rows[0], "ADDITIONAL DISCOUNT", false, ref RowError);
            ValidatePercentageNumericField(dtCheck.Rows[0], "TRADE DISCOUNT", false, ref RowError);
            ValidateNumericField(dtCheck.Rows[0], "FRIEGHT", false, ref RowError);
            ValidateNumericField(dtCheck.Rows[0], "WRITEOFF AMT", false, ref RowError);
            ValidateNumericOnlyField(dtCheck.Rows[0], "DISTANCE", false, ref RowError);

            string[] fields = { "REMARKS", "TRANSPORT ID", "TRANSPORT NAME", "IRN", "ACKNOWLEDGE NO" };

            DataRow row = dtCheck.Rows[0];

            foreach (var field in fields)
            {
                ValidateAlphaNumericSplField(row, field, false, ref RowError);
            }

            #endregion
            return RowError;
        }
        #region Sales Header Validation
        public string SaleHeaderValidation(DataTable dtCheck)
        {
            string RowError = "";
            #region Branch & Doc ID
            ValidateAlphaNumericSplField(dtCheck.Rows[0], "DOC ID *", true, ref RowError);
            DataTable dtdocidcheck = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 21, 3, dtCheck.Rows[0]["DOC ID *"].ToString());
            if (dtdocidcheck.Rows.Count > 0)
            {
                RowError += "* DOC ID(" + dtCheck.Rows[0]["DOC ID *"].ToString() + ") already exists/imported\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["DOC DATE *"].ToString()))
            {
                if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["DOC DATE *"].ToString()))
                {
                    RowError += "DOC DATE * : Invalid Date Format(Format : dd/MM/yyyy)\n";
                }
            }
            else
            {
                RowError += "DOC DATE * : DOC DATE should not be empty\n";
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
                        RowError += "* BRANCH NAME(" + dtCheck.Rows[0]["BRANCH NAME *"].ToString() + ") not found in Database\n";
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
            #endregion
            #region Beat & Salesman
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["BEAT NAME"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["BEAT NAME"].ToString()))
                {
                    RowError += "BEAT NAME : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 9, 3, dtCheck.Rows[0]["BEAT NAME"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "BEAT NAME(" + dtCheck.Rows[0]["BEAT NAME"].ToString() + ") not found in Database\n";
                        BeatID = 0;
                    }
                    else
                    {
                        BeatID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                BeatID = 0;
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["SALESMAN NAME"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["SALESMAN NAME"].ToString()))
                {
                    RowError += "SALESMAN NAME : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 10, 3, dtCheck.Rows[0]["SALESMAN NAME"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "SALESMAN NAME(" + dtCheck.Rows[0]["SALESMAN NAME"].ToString() + ") not found in Database\n";
                        SalesmanID = 0;
                    }
                    else
                    {
                        SalesmanID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                SalesmanID = 0;
            }
            #endregion
            #region Party , Payment Mode & Credit Term
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
                        RowError += "* PARTY NAME(" + dtCheck.Rows[0]["PARTY NAME *"].ToString() + ") not found in Database\n";
                        PartyID = 0;
                        PriceTypeID = 0;
                        TaxTypeID = 0;
                    }
                    else
                    {
                        PartyID = Convert.ToInt32(dt.Rows[0][0].ToString());
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
                        CreditTermID = 0;
                    }
                    else
                    {
                        CreditTermID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "CREDIT TERM * : CREDIT TERM should not be empty\n";
            }

            #endregion
            #region ADDITIONAL, TRADE Disc,FRIEGHT,WRITEOFF,Other Charge,DISTANCE & Net Amount
            ValidatePercentageNumericField(dtCheck.Rows[0], "ADDITIONAL DISCOUNT %", false, ref RowError);
            ValidatePercentageNumericField(dtCheck.Rows[0], "TRADE DISCOUNT %", false, ref RowError);
            ValidateNumericField(dtCheck.Rows[0], "FRIEGHT", false, ref RowError);
            ValidateNumericField(dtCheck.Rows[0], "WRITEOFF AMT", false, ref RowError);
            ValidateNumericOnlyField(dtCheck.Rows[0], "DISTANCE", false, ref RowError);
            ValidateNumericField(dtCheck.Rows[0], "NET AMOUNT *", true, ref RowError);
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["OTHER CHARGE %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["OTHER CHARGE %"].ToString()))
                {
                    RowError += "OTHER CHARGE % : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["OTHER CHARGE %"].ToString()) > 100)
                    {
                        RowError += "OTHER CHARGE % : OTHER CHARGE % should be less than 100 only\n";
                    }
                }
            }
            #endregion
            #region Status
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
                        StatusID = 0;
                    }
                    else
                    {
                        StatusID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "STATUS * : STATUS should not be empty\n";
            }
            #endregion
            #region VECHICLE, TRANSPORT MODE, TRANSPORT TYPE
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["VECHICLE NUMBER"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["VECHICLE NUMBER"].ToString()))
                {
                    RowError += "VECHICLE NUMBER : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 17, 3, dtCheck.Rows[0]["VECHICLE NUMBER"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "VECHICLE NUMBER(" + dtCheck.Rows[0]["VECHICLE NUMBER"].ToString() + ") not found in Database\n";
                        VehicleID = 0;
                    }
                    else
                    {
                        VehicleID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                VehicleID = 0;
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TRANSPORT MODE"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["TRANSPORT MODE"].ToString()))
                {
                    RowError += "TRANSPORT MODE : Invalid character\n";
                }
                else
                {
                    var validtransportmode = new[] { "Road", "Rail", "Air", "Ship/Road cum ship" };
                    if (!validtransportmode.Contains(dtCheck.Rows[0]["TRANSPORT MODE"].ToString()))
                    {
                        RowError += "TRANSPORT MODE : Transport Mode Must be Road, Rail, Air ,Ship/Road cum ship";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TRANSPORT TYPE"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["TRANSPORT TYPE"].ToString()))
                {
                    RowError += "TRANSPORT TYPE : Invalid character\n";
                }
                else
                {
                    var validtransportmode = new[] { "Regular", "ODC" };
                    if (!validtransportmode.Contains(dtCheck.Rows[0]["TRANSPORT TYPE"].ToString()))
                    {
                        RowError += "TRANSPORT TYPE : Transport Type Must be Regular, ODC";
                    }
                }
            }

            #endregion
            #region  REMARKS, TRANSPORT ID, TRANSPORT NAME, IRN, ACKNOWLEDGE NO & E-WAY NOO
            string[] fields = { "REMARKS", "TRANSPORT ID", "TRANSPORT NAME", "IRN", "ACKNOWLEDGE NO", "ACKNOWLEDGE STATUS" };

            DataRow row = dtCheck.Rows[0];

            foreach (var field in fields)
            {
                ValidateAlphaNumericSplField(row, field, false, ref RowError);
            }

            ValidateNumericOnlyField(dtCheck.Rows[0], "EWAY BILL NO", false, ref RowError);
            #endregion
            return RowError;
        }
        #endregion        
        #region Sale Detail Validation
        public string SaleDetailValidation(DataTable dtCheck)
        {
            string RowError = "";
            DataRow row = dtCheck.Rows[0];
            DataTable dtProdData = new DataTable();
            #region Doc ID
            string strDocID = dtCheck.Rows[0]["DOC ID *"].ToString();
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
            #endregion
            #region Product Name
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PRODUCT NAME *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["PRODUCT NAME *"].ToString()))
                {
                    RowError += "PRODUCT NAME * : Invalid Characters\n";
                }
                else
                {
                    dtProdData = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 5, 3, dtCheck.Rows[0]["PRODUCT NAME *"].ToString());
                    if (dtProdData.Rows.Count == 0)
                    {
                        RowError += "* PRODUCT NAME(" + dtCheck.Rows[0]["PRODUCT NAME *"].ToString() + ") not found in Database\n";
                        ProductID = 0;
                    }
                    else
                    {
                        ProductID = Convert.ToInt32(dtProdData.Rows[0][0].ToString());
                        TrackPKDYN = Convert.ToBoolean(dtProdData.Rows[0]["TrackPDK"].ToString()) ? 1 : 0;
                        TrackBatchYN = Convert.ToBoolean(dtProdData.Rows[0]["TrackBatch"].ToString()) ? 1 : 0;
                        TrackInvYN = Convert.ToBoolean(dtProdData.Rows[0]["TrackInventory"].ToString()) ? 1 : 0;
                    }
                }
            }
            else
            {
                RowError += "PRODUCT NAME * : PRODUCT Name should not be empty\n";
            }
            #endregion
            #region Tax ame
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TAX NAME *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["TAX NAME *"].ToString()))
                {
                    RowError += "TAX NAME * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 6, 3, dtCheck.Rows[0]["TAX NAME *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* TAX NAME(" + dtCheck.Rows[0]["TAX NAME *"].ToString() + ") not found in Database\n";
                        TaxID = 0;
                    }
                    else
                    {
                        TaxID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "TAX NAME * : TAX Name should not be empty\n";
            }
            #endregion
            #region Batch No , PKD & Expiry
            ValidateAlphaNumericSplField(row, "BATCH NUMBER", (ProductID > 0 && TrackBatchYN > 0), ref RowError);
            if (ProductID > 0 && TrackPKDYN > 0)
            {
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PKD DATE"].ToString()))
                {
                    if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["PKD DATE"].ToString()))
                    {
                        RowError += "PKD DATE : Invalid Date Format(Format : dd/MM/yyyy)\n";
                    }
                }
                else
                {
                    RowError += "PKD DATE * : PKD DATE should not be empty\n";
                }
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                {
                    if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                    {
                        RowError += "EXPIRY DATE : Invalid Date Format(Format : dd/MM/yyyy)\n";
                    }
                }
                else
                {
                    RowError += "EXPIRY DATE * : EXPIRY DATE should not be empty\n";
                }
            }
            else
            {
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PKD DATE"].ToString()))
                {
                    RowError += "PKD DATE : PKD No Product. Remove Date\n";
                }
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                {
                    RowError += "EXPIRY DATE : PKD No Product. Remove Date\n";
                }
            }
            #endregion
            #region QTY,PRICE,MRP,PRODUCT DISCOUNT
            string[] fields = {"QTY *","PRICE *","MRP *"};
            foreach (var field in fields)
            {
                ValidateNumericField(row, field, false, ref RowError);
            }
            ValidatePercentageNumericField(row, "PRODUCT DISCOUNT", false, ref RowError);

            #endregion
            #region REASON
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["REASON NAME"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["REASON NAME"].ToString()))
                {
                    RowError += "REASON NAME : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 23, 3, dtCheck.Rows[0]["REASON NAME"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* REASON NAME(" + dtCheck.Rows[0]["REASON NAME"].ToString() + ") not found in Database\n";
                        ReasonID = 0;
                    }
                    else
                    {
                        ReasonID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            #endregion
            return RowError;
        }
        #endregion        
        #region Bill Header Validation
        public string BillHeaderValidation(DataTable dtCheck)
        {
            string RowError = "";
            #region Branch & Doc ID
            ValidateAlphaNumericSplField(dtCheck.Rows[0], "DOC ID *", true, ref RowError);
            
            DataTable dtdocidcheck = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 19, 3, dtCheck.Rows[0]["DOC ID *"].ToString());
            if (dtdocidcheck.Rows.Count > 0)
            {
                RowError += "* DOC ID(" + dtCheck.Rows[0]["DOC ID *"].ToString() + ") already exists/imported\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["DOC DATE *"].ToString()))
            {
                if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["DOC DATE *"].ToString()))
                {
                    RowError += "DOC DATE * : Invalid Date Format(Format : dd/MM/yyyy)\n";
                }
            }
            else
            {
                RowError += "DOC DATE * : DOC DATE should not be empty\n";
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
                        RowError += "* BRANCH NAME(" + dtCheck.Rows[0]["BRANCH NAME *"].ToString() + ") not found in Database\n";
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
            #endregion            
            #region Party , Payment Mode & Credit Term
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PARTY NAME *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["PARTY NAME *"].ToString()))
                {
                    RowError += "PARTY NAME * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 4, 3, dtCheck.Rows[0]["PARTY NAME *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* PARTY NAME(" + dtCheck.Rows[0]["PARTY NAME *"].ToString() + ") not found in Database\n";
                        PartyID = 0;                        
                        TaxTypeID = 0;
                    }
                    else
                    {
                        PartyID = Convert.ToInt32(dt.Rows[0][0].ToString());
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
                        CreditTermID = 0;
                    }
                    else
                    {
                        CreditTermID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "CREDIT TERM * : CREDIT TERM should not be empty\n";
            }

            #endregion
            #region ADDITIONAL, TRADE Disc,FRIEGHT,WRITEOFF,Other Charge,DISTANCE & Net Amount
            ValidatePercentageNumericField(dtCheck.Rows[0], "ADDITIONAL DISCOUNT %", false, ref RowError);
            ValidatePercentageNumericField(dtCheck.Rows[0], "TRADE DISCOUNT %", false, ref RowError);
            ValidateNumericField(dtCheck.Rows[0], "FRIEGHT", false, ref RowError);
            ValidateNumericField(dtCheck.Rows[0], "WRITEOFF AMT", false, ref RowError);
            ValidateNumericOnlyField(dtCheck.Rows[0], "DISTANCE", false, ref RowError);
            ValidateNumericField(dtCheck.Rows[0], "NET AMOUNT *", true, ref RowError);
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["OTHER CHARGE %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["OTHER CHARGE %"].ToString()))
                {
                    RowError += "OTHER CHARGE % : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["OTHER CHARGE %"].ToString()) > 100)
                    {
                        RowError += "OTHER CHARGE % : OTHER CHARGE % should be less than 100 only\n";
                    }
                }
            }
            #endregion
            #region Status
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
                        StatusID = 0;
                    }
                    else
                    {
                        StatusID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "STATUS * : STATUS should not be empty\n";
            }
            #endregion
            #region VECHICLE, TRANSPORT MODE, TRANSPORT TYPE
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["VECHICLE NUMBER"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["VECHICLE NUMBER"].ToString()))
                {
                    RowError += "VECHICLE NUMBER : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 17, 3, dtCheck.Rows[0]["VECHICLE NUMBER"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "VECHICLE NUMBER(" + dtCheck.Rows[0]["VECHICLE NUMBER"].ToString() + ") not found in Database\n";
                        VehicleID = 0;
                    }
                    else
                    {
                        VehicleID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                VehicleID = 0;
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TRANSPORT MODE"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["TRANSPORT MODE"].ToString()))
                {
                    RowError += "TRANSPORT MODE : Invalid character\n";
                }
                else
                {
                    var validtransportmode = new[] { "Road", "Rail", "Air", "Ship/Road cum ship" };
                    if (!validtransportmode.Contains(dtCheck.Rows[0]["TRANSPORT MODE"].ToString()))
                    {
                        RowError += "TRANSPORT MODE : Transport Mode Must be Road, Rail, Air ,Ship/Road cum ship";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TRANSPORT TYPE"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["TRANSPORT TYPE"].ToString()))
                {
                    RowError += "TRANSPORT TYPE : Invalid character\n";
                }
                else
                {
                    var validtransportmode = new[] { "Regular", "ODC" };
                    if (!validtransportmode.Contains(dtCheck.Rows[0]["TRANSPORT TYPE"].ToString()))
                    {
                        RowError += "TRANSPORT TYPE : Transport Type Must be Regular, ODC";
                    }
                }
            }

            #endregion
            #region  REMARKS, TRANSPORT ID, TRANSPORT NAME, IRN, ACKNOWLEDGE NO & E-WAY NOO
            string[] fields = { "REMARKS", "TRANSPORT ID", "TRANSPORT NAME", "IRN", "ACKNOWLEDGE NO", "ACKNOWLEDGE STATUS" };

            DataRow row = dtCheck.Rows[0];

            foreach (var field in fields)
            {
                ValidateAlphaNumericSplField(row, field, false, ref RowError);
            }

            ValidateNumericOnlyField(dtCheck.Rows[0], "EWAY BILL NO", false, ref RowError);
            #endregion
            return RowError;
        }
        #endregion
        #region Bill Detail Validation
        public string BillDetailValidation(DataTable dtCheck)
        {
            string RowError = "";
            DataRow row = dtCheck.Rows[0];
            DataTable dtProdData = new DataTable();
            #region Doc ID
            string strDocID = dtCheck.Rows[0]["DOC ID *"].ToString();
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
            #endregion
            #region Product Name
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PRODUCT NAME *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["PRODUCT NAME *"].ToString()))
                {
                    RowError += "PRODUCT NAME * : Invalid Characters\n";
                }
                else
                {
                    dtProdData = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 5, 3, dtCheck.Rows[0]["PRODUCT NAME *"].ToString());
                    if (dtProdData.Rows.Count == 0)
                    {
                        RowError += "* PRODUCT NAME(" + dtCheck.Rows[0]["PRODUCT NAME *"].ToString() + ") not found in Database\n";
                        ProductID = 0;
                    }
                    else
                    {
                        ProductID = Convert.ToInt32(dtProdData.Rows[0][0].ToString());
                        TrackPKDYN = Convert.ToBoolean(dtProdData.Rows[0]["TrackPDK"].ToString()) ? 1 : 0;
                        TrackBatchYN = Convert.ToBoolean(dtProdData.Rows[0]["TrackBatch"].ToString()) ? 1 : 0;
                        TrackInvYN = Convert.ToBoolean(dtProdData.Rows[0]["TrackInventory"].ToString()) ? 1 : 0;
                    }
                }
            }
            else
            {
                RowError += "PRODUCT NAME * : PRODUCT Name should not be empty\n";
            }
            #endregion
            #region Tax ame
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TAX NAME *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["TAX NAME *"].ToString()))
                {
                    RowError += "TAX NAME * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 6, 3, dtCheck.Rows[0]["TAX NAME *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* TAX NAME(" + dtCheck.Rows[0]["TAX NAME *"].ToString() + ") not found in Database\n";
                        TaxID = 0;
                    }
                    else
                    {
                        TaxID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "TAX NAME * : TAX Name should not be empty\n";
            }
            #endregion
            #region Batch No , PKD & Expiry
            ValidateAlphaNumericSplField(row, "BATCH NUMBER", (ProductID > 0 && TrackBatchYN > 0), ref RowError);
            if (ProductID > 0 && TrackPKDYN > 0)
            {
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PKD DATE"].ToString()))
                {
                    if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["PKD DATE"].ToString()))
                    {
                        RowError += "PKD DATE : Invalid Date Format(Format : dd/MM/yyyy)\n";
                    }
                }
                else
                {
                    RowError += "PKD DATE * : PKD DATE should not be empty\n";
                }
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                {
                    if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                    {
                        RowError += "EXPIRY DATE : Invalid Date Format(Format : dd/MM/yyyy)\n";
                    }
                }
                else
                {
                    RowError += "EXPIRY DATE * : EXPIRY DATE should not be empty\n";
                }
            }
            else
            {
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PKD DATE"].ToString()))
                {
                    RowError += "PKD DATE : PKD No Product. Remove Date\n";
                }
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                {
                    RowError += "EXPIRY DATE : PKD No Product. Remove Date\n";
                }
            }
            #endregion
            #region "ACTUAL QTY", "DAMAGE QTY", "FREE QTY", "PURCHASE PRICE", "SALE PRICE", "ECP PRICE","SPL PRICE", "RETURN PRICE", "MRP *"


            string[] fields = { "ACTUAL QTY", "DAMAGE QTY", "FREE QTY", "PURCHASE PRICE", "SALE PRICE", "ECP PRICE",
                "SPL PRICE", "RETURN PRICE", "MRP" };
            foreach (var field in fields)
            {
                ValidateNumericField(row, field, false, ref RowError);
            }
            decimal qty = objBL.BL_dValidation(dtCheck.Rows[0]["ACTUAL QTY"].ToString());
            decimal DAMAGEqty = objBL.BL_dValidation(dtCheck.Rows[0]["DAMAGE QTY"].ToString());
            decimal FREEqty = objBL.BL_dValidation(dtCheck.Rows[0]["FREE QTY"].ToString());
            if(qty == 0 && DAMAGEqty == 0 && FREEqty == 0)
            {
                RowError += "QTY : Qty should not be empty. Give value in anyone QTY\n";
            }
            ValidatePercentageNumericField(row, "PRODUCT DISCOUNT", false, ref RowError);

            #endregion
            #region REASON
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["REASON NAME"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["REASON NAME"].ToString()))
                {
                    RowError += "REASON NAME : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 23, 3, dtCheck.Rows[0]["REASON NAME"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* REASON NAME(" + dtCheck.Rows[0]["REASON NAME"].ToString() + ") not found in Database\n";
                        ReasonID = 0;
                    }
                    else
                    {
                        ReasonID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            #endregion
            return RowError;
        }

        #endregion
        #region Sales Return Header Validation
        public string SaleReturnHeaderValidation(DataTable dtCheck)
        {
            string RowError = "";
            #region Branch & Doc ID
            ValidateAlphaNumericSplField(dtCheck.Rows[0], "DOC ID *", true, ref RowError);
            
            DataTable dtdocidcheck = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 22, 3, dtCheck.Rows[0]["DOC ID *"].ToString());
            if (dtdocidcheck.Rows.Count > 0)
            {
                RowError += "* DOC ID(" + dtCheck.Rows[0]["DOC ID *"].ToString() + ") already exists/imported\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["DOC DATE *"].ToString()))
            {
                if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["DOC DATE *"].ToString()))
                {
                    RowError += "DOC DATE * : Invalid Date Format(Format : dd/MM/yyyy)\n";
                }
            }
            else
            {
                RowError += "DOC DATE * : DOC DATE should not be empty\n";
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
                        RowError += "* BRANCH NAME(" + dtCheck.Rows[0]["BRANCH NAME *"].ToString() + ") not found in Database\n";
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
            #endregion
            #region Beat & Salesman
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["BEAT NAME"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["BEAT NAME"].ToString()))
                {
                    RowError += "BEAT NAME : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 9, 3, dtCheck.Rows[0]["BEAT NAME"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "BEAT NAME(" + dtCheck.Rows[0]["BEAT NAME"].ToString() + ") not found in Database\n";
                        BeatID = 0;
                    }
                    else
                    {
                        BeatID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                BeatID = 0;
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["SALESMAN NAME"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["SALESMAN NAME"].ToString()))
                {
                    RowError += "SALESMAN NAME : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 10, 3, dtCheck.Rows[0]["SALESMAN NAME"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "SALESMAN NAME(" + dtCheck.Rows[0]["SALESMAN NAME"].ToString() + ") not found in Database\n";
                        SalesmanID = 0;
                    }
                    else
                    {
                        SalesmanID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                SalesmanID = 0;
            }
            #endregion
            #region Party 
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
                        RowError += "* PARTY NAME(" + dtCheck.Rows[0]["PARTY NAME *"].ToString() + ") not found in Database\n";
                        PartyID = 0;
                        PriceTypeID = 0;
                        TaxTypeID = 0;
                    }
                    else
                    {
                        PartyID = Convert.ToInt32(dt.Rows[0][0].ToString());
                        PriceTypeID = Convert.ToInt32(dt.Rows[0]["PriceTypeID"].ToString());
                        TaxTypeID = Convert.ToInt32(dt.Rows[0]["TaxTypeID"].ToString());
                    }

                }
            }
            else
            {
                RowError += "PARTY NAME * : PARTY NAME should not be empty\n";
            }


            #endregion
            #region ADDITIONAL, TRADE Disc,FRIEGHT,WRITEOFF,Other Charge,DISTANCE & Net Amount
            ValidatePercentageNumericField(dtCheck.Rows[0], "ADDITIONAL DISCOUNT %", false, ref RowError);
            ValidatePercentageNumericField(dtCheck.Rows[0], "TRADE DISCOUNT %", false, ref RowError);
            ValidateNumericField(dtCheck.Rows[0], "FRIEGHT", false, ref RowError);
            ValidateNumericField(dtCheck.Rows[0], "WRITEOFF AMT", false, ref RowError);
            ValidateNumericOnlyField(dtCheck.Rows[0], "DISTANCE", false, ref RowError);
            ValidateNumericField(dtCheck.Rows[0], "NET AMOUNT *", true, ref RowError);
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["OTHER CHARGE %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["OTHER CHARGE %"].ToString()))
                {
                    RowError += "OTHER CHARGE % : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["OTHER CHARGE %"].ToString()) > 100)
                    {
                        RowError += "OTHER CHARGE % : OTHER CHARGE % should be less than 100 only\n";
                    }
                }
            }
            #endregion
            #region Status
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
                        StatusID = 0;
                    }
                    else
                    {
                        StatusID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "STATUS * : STATUS should not be empty\n";
            }
            #endregion
            #region Tranacion Type & Return Type

            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TRANSACTION TYPE"].ToString()))
            {
                if (!objBL.BL_Numeric(dtCheck.Rows[0]["TRANSACTION TYPE"].ToString()))
                {
                    RowError += "TRANSACTION TYPE : Invalid character(Numeric Only)\n";
                }
                else
                {
                    var validtranstype = new[] { "2", "3" };
                    if (!validtranstype.Contains(dtCheck.Rows[0]["TRANSACTION TYPE"].ToString()))
                    {
                        RowError += "TRANSACTION TYPE : Must be a Number (2 - Saleable Return,3 - Damage Return)";
                    }
                }
            }


            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["RETURN TYPE"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["RETURN TYPE"].ToString()))
                {
                    RowError += "RETURN TYPE : Invalid character(Numeric Only)\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 18, 3, dtCheck.Rows[0]["RETURN TYPE"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "RETURN TYPE(" + dtCheck.Rows[0]["RETURN TYPE"].ToString() + ") not found in Database\n";
                        ReturnTypeID = 0;
                    }
                    else
                    {
                        ReturnTypeID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                ReturnTypeID = 0;
            }

            #endregion
            #region VECHICLE, TRANSPORT MODE, TRANSPORT TYPE
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["VECHICLE NUMBER"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["VECHICLE NUMBER"].ToString()))
                {
                    RowError += "VECHICLE NUMBER : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 17, 3, dtCheck.Rows[0]["VECHICLE NUMBER"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "VECHICLE NUMBER(" + dtCheck.Rows[0]["VECHICLE NUMBER"].ToString() + ") not found in Database\n";
                        VehicleID = 0;
                    }
                    else
                    {
                        VehicleID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                VehicleID = 0;
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TRANSPORT MODE"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["TRANSPORT MODE"].ToString()))
                {
                    RowError += "TRANSPORT MODE : Invalid character\n";
                }
                else
                {
                    var validtransportmode = new[] { "Road", "Rail", "Air", "Ship/Road cum ship" };
                    if (!validtransportmode.Contains(dtCheck.Rows[0]["TRANSPORT MODE"].ToString()))
                    {
                        RowError += "TRANSPORT MODE : Transport Mode Must be Road, Rail, Air ,Ship/Road cum ship";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TRANSPORT TYPE"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["TRANSPORT TYPE"].ToString()))
                {
                    RowError += "TRANSPORT TYPE : Invalid character\n";
                }
                else
                {
                    var validtransportmode = new[] { "Regular", "ODC" };
                    if (!validtransportmode.Contains(dtCheck.Rows[0]["TRANSPORT TYPE"].ToString()))
                    {
                        RowError += "TRANSPORT TYPE : Transport Type Must be Regular, ODC";
                    }
                }
            }

            #endregion
            #region  REMARKS, TRANSPORT ID, TRANSPORT NAME, IRN, ACKNOWLEDGE NO & E-WAY NOO
            string[] fields = { "REMARKS", "TRANSPORT ID", "TRANSPORT NAME", "IRN", "ACKNOWLEDGE NO", "ACKNOWLEDGE STATUS" };

            DataRow row = dtCheck.Rows[0];

            foreach (var field in fields)
            {
                ValidateAlphaNumericSplField(row, field, false, ref RowError);
            }

            ValidateNumericOnlyField(dtCheck.Rows[0], "EWAY BILL NO", false, ref RowError);
            #endregion
            return RowError;
        }
        #endregion
        #region Sales Return Detail Validation
        public string SaleReturnDetailValidation(DataTable dtCheck)
        {
            string RowError = "";
            DataRow row = dtCheck.Rows[0];
            DataTable dtProdData = new DataTable();
            #region Doc ID
            string strDocID = dtCheck.Rows[0]["DOC ID *"].ToString();
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
            #endregion
            #region Product Name
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PRODUCT NAME *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["PRODUCT NAME *"].ToString()))
                {
                    RowError += "PRODUCT NAME * : Invalid Characters\n";
                }
                else
                {
                    dtProdData = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 5, 3, dtCheck.Rows[0]["PRODUCT NAME *"].ToString());
                    if (dtProdData.Rows.Count == 0)
                    {
                        RowError += "* PRODUCT NAME(" + dtCheck.Rows[0]["PRODUCT NAME *"].ToString() + ") not found in Database\n";
                        ProductID = 0;
                    }
                    else
                    {
                        ProductID = Convert.ToInt32(dtProdData.Rows[0][0].ToString());
                        TrackPKDYN = Convert.ToBoolean(dtProdData.Rows[0]["TrackPDK"].ToString()) ? 1 : 0;
                        TrackBatchYN = Convert.ToBoolean(dtProdData.Rows[0]["TrackBatch"].ToString()) ? 1 : 0;
                        TrackInvYN = Convert.ToBoolean(dtProdData.Rows[0]["TrackInventory"].ToString()) ? 1 : 0;
                    }
                }
            }
            else
            {
                RowError += "PRODUCT NAME * : PRODUCT Name should not be empty\n";
            }
            #endregion
            #region Tax ame
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TAX NAME *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["TAX NAME *"].ToString()))
                {
                    RowError += "TAX NAME * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 6, 3, dtCheck.Rows[0]["TAX NAME *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* TAX NAME(" + dtCheck.Rows[0]["TAX NAME *"].ToString() + ") not found in Database\n";
                        TaxID = 0;
                    }
                    else
                    {
                        TaxID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "TAX NAME * : TAX Name should not be empty\n";
            }
            #endregion
            #region Batch No , PKD & Expiry
            ValidateAlphaNumericSplField(row, "BATCH NUMBER", (ProductID > 0 && TrackBatchYN > 0), ref RowError);
            if (ProductID > 0 && TrackPKDYN > 0)
            {
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PKD DATE"].ToString()))
                {
                    if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["PKD DATE"].ToString()))
                    {
                        RowError += "PKD DATE : Invalid Date Format(Format : dd/MM/yyyy)\n";
                    }
                }
                else
                {
                    RowError += "PKD DATE * : PKD DATE should not be empty\n";
                }
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                {
                    if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                    {
                        RowError += "EXPIRY DATE : Invalid Date Format(Format : dd/MM/yyyy)\n";
                    }
                }
                else
                {
                    RowError += "EXPIRY DATE * : EXPIRY DATE should not be empty\n";
                }
            }
            else
            {
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PKD DATE"].ToString()))
                {
                    RowError += "PKD DATE : PKD No Product. Remove Date\n";
                }
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                {
                    RowError += "EXPIRY DATE : PKD No Product. Remove Date\n";
                }
            }
            #endregion
            #region QTY,PRICE,MRP,PRODUCT DISCOUNT
            string[] fields = { "QTY *", "PRICE *", "MRP *" };
            foreach (var field in fields)
            {
                ValidateNumericField(row, field, false, ref RowError);
            }
            ValidatePercentageNumericField(row, "PRODUCT DISCOUNT", false, ref RowError);

            #endregion
            #region REASON
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["REASON NAME"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["REASON NAME"].ToString()))
                {
                    RowError += "REASON NAME : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 23, 3, dtCheck.Rows[0]["REASON NAME"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* REASON NAME(" + dtCheck.Rows[0]["REASON NAME"].ToString() + ") not found in Database\n";
                        ReasonID = 0;
                    }
                    else
                    {
                        ReasonID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            #endregion
            return RowError;
        }
        #endregion        
        #region Purchase Return Header Validation
        public string PurchaseReturnHeaderValidation(DataTable dtCheck)
        {
            string RowError = "";
            #region Branch & Doc ID
            ValidateAlphaNumericSplField(dtCheck.Rows[0], "DOC ID *", true, ref RowError);
            
            DataTable dtdocidcheck = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 20, 3, dtCheck.Rows[0]["DOC ID *"].ToString());
            if (dtdocidcheck.Rows.Count > 0)
            {
                RowError += "* DOC ID(" + dtCheck.Rows[0]["DOC ID *"].ToString() + ") already exists/imported\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["DOC DATE *"].ToString()))
            {
                if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["DOC DATE *"].ToString()))
                {
                    RowError += "DOC DATE * : Invalid Date Format(Format : dd/MM/yyyy)\n";
                }
            }
            else
            {
                RowError += "DOC DATE * : DOC DATE should not be empty\n";
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
                        RowError += "* BRANCH NAME(" + dtCheck.Rows[0]["BRANCH NAME *"].ToString() + ") not found in Database\n";
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
            #endregion            
            #region Party
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PARTY NAME *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["PARTY NAME *"].ToString()))
                {
                    RowError += "PARTY NAME * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 4, 3, dtCheck.Rows[0]["PARTY NAME *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* PARTY NAME(" + dtCheck.Rows[0]["PARTY NAME *"].ToString() + ") not found in Database\n";
                        PartyID = 0;
                        TaxTypeID = 0;
                    }
                    else
                    {
                        PartyID = Convert.ToInt32(dt.Rows[0][0].ToString());
                        TaxTypeID = Convert.ToInt32(dt.Rows[0]["TaxTypeID"].ToString());
                    }

                }
            }
            else
            {
                RowError += "PARTY NAME * : PARTY NAME should not be empty\n";
            }
            #endregion
            #region ADDITIONAL, TRADE Disc,FRIEGHT,WRITEOFF,Other Charge,DISTANCE & Net Amount
            ValidatePercentageNumericField(dtCheck.Rows[0], "ADDITIONAL DISCOUNT %", false, ref RowError);
            ValidatePercentageNumericField(dtCheck.Rows[0], "TRADE DISCOUNT %", false, ref RowError);
            ValidateNumericField(dtCheck.Rows[0], "FRIEGHT", false, ref RowError);
            ValidateNumericField(dtCheck.Rows[0], "WRITEOFF AMT", false, ref RowError);
            ValidateNumericOnlyField(dtCheck.Rows[0], "DISTANCE", false, ref RowError);
            ValidateNumericField(dtCheck.Rows[0], "NET AMOUNT *", true, ref RowError);
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["OTHER CHARGE %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["OTHER CHARGE %"].ToString()))
                {
                    RowError += "OTHER CHARGE % : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["OTHER CHARGE %"].ToString()) > 100)
                    {
                        RowError += "OTHER CHARGE % : OTHER CHARGE % should be less than 100 only\n";
                    }
                }
            }
            #endregion
            #region Status
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
                        StatusID = 0;
                    }
                    else
                    {
                        StatusID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "STATUS * : STATUS should not be empty\n";
            }
            #endregion
            #region Return Type
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["RETURN TYPE"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["RETURN TYPE"].ToString()))
                {
                    RowError += "RETURN TYPE : Invalid character(Numeric Only)\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 18, 3, dtCheck.Rows[0]["RETURN TYPE"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "RETURN TYPE(" + dtCheck.Rows[0]["RETURN TYPE"].ToString() + ") not found in Database\n";
                        ReturnTypeID = 0;
                    }
                    else
                    {
                        ReturnTypeID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                ReturnTypeID = 0;
            }
            #endregion
            #region VECHICLE, TRANSPORT MODE, TRANSPORT TYPE
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["VECHICLE NUMBER"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["VECHICLE NUMBER"].ToString()))
                {
                    RowError += "VECHICLE NUMBER : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 17, 3, dtCheck.Rows[0]["VECHICLE NUMBER"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "VECHICLE NUMBER(" + dtCheck.Rows[0]["VECHICLE NUMBER"].ToString() + ") not found in Database\n";
                        VehicleID = 0;
                    }
                    else
                    {
                        VehicleID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                VehicleID = 0;
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TRANSPORT MODE"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["TRANSPORT MODE"].ToString()))
                {
                    RowError += "TRANSPORT MODE : Invalid character\n";
                }
                else
                {
                    var validtransportmode = new[] { "Road", "Rail", "Air", "Ship/Road cum ship" };
                    if (!validtransportmode.Contains(dtCheck.Rows[0]["TRANSPORT MODE"].ToString()))
                    {
                        RowError += "TRANSPORT MODE : Transport Mode Must be Road, Rail, Air ,Ship/Road cum ship";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TRANSPORT TYPE"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["TRANSPORT TYPE"].ToString()))
                {
                    RowError += "TRANSPORT TYPE : Invalid character\n";
                }
                else
                {
                    var validtransportmode = new[] { "Regular", "ODC" };
                    if (!validtransportmode.Contains(dtCheck.Rows[0]["TRANSPORT TYPE"].ToString()))
                    {
                        RowError += "TRANSPORT TYPE : Transport Type Must be Regular, ODC";
                    }
                }
            }

            #endregion
            #region  REMARKS, TRANSPORT ID, TRANSPORT NAME, IRN, ACKNOWLEDGE NO & E-WAY NOO
            string[] fields = { "REMARKS", "TRANSPORT ID", "TRANSPORT NAME", "IRN", "ACKNOWLEDGE NO", "ACKNOWLEDGE STATUS" };

            DataRow row = dtCheck.Rows[0];

            foreach (var field in fields)
            {
                ValidateAlphaNumericSplField(row, field, false, ref RowError);
            }

            ValidateNumericOnlyField(dtCheck.Rows[0], "EWAY BILL NO", false, ref RowError);
            #endregion
            return RowError;
        }
        #endregion        
        #region Purchase Return Detail Validation
        public string PurchaseReturnDetailValidation(DataTable dtCheck)
        {
            string RowError = "";
            DataRow row = dtCheck.Rows[0];
            DataTable dtProdData = new DataTable();
            #region Doc ID
            string strDocID = dtCheck.Rows[0]["DOC ID *"].ToString();
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
            #endregion
            #region Product Name
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PRODUCT NAME *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["PRODUCT NAME *"].ToString()))
                {
                    RowError += "PRODUCT NAME * : Invalid Characters\n";
                }
                else
                {
                    dtProdData = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 5, 3, dtCheck.Rows[0]["PRODUCT NAME *"].ToString());
                    if (dtProdData.Rows.Count == 0)
                    {
                        RowError += "* PRODUCT NAME(" + dtCheck.Rows[0]["PRODUCT NAME *"].ToString() + ") not found in Database\n";
                        ProductID = 0;
                    }
                    else
                    {
                        ProductID = Convert.ToInt32(dtProdData.Rows[0][0].ToString());
                        TrackPKDYN = Convert.ToBoolean(dtProdData.Rows[0]["TrackPDK"].ToString()) ? 1 : 0;
                        TrackBatchYN = Convert.ToBoolean(dtProdData.Rows[0]["TrackBatch"].ToString()) ? 1 : 0;
                        TrackInvYN = Convert.ToBoolean(dtProdData.Rows[0]["TrackInventory"].ToString()) ? 1 : 0;
                    }
                }
            }
            else
            {
                RowError += "PRODUCT NAME * : PRODUCT Name should not be empty\n";
            }
            #endregion
            #region Tax ame
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TAX NAME *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["TAX NAME *"].ToString()))
                {
                    RowError += "TAX NAME * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 6, 3, dtCheck.Rows[0]["TAX NAME *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* TAX NAME(" + dtCheck.Rows[0]["TAX NAME *"].ToString() + ") not found in Database\n";
                        TaxID = 0;
                    }
                    else
                    {
                        TaxID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "TAX NAME * : TAX Name should not be empty\n";
            }
            #endregion
            #region Batch No , PKD & Expiry
            ValidateAlphaNumericSplField(row, "BATCH NUMBER", (ProductID > 0 && TrackBatchYN > 0), ref RowError);
            if (ProductID > 0 && TrackPKDYN > 0)
            {
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PKD DATE"].ToString()))
                {
                    if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["PKD DATE"].ToString()))
                    {
                        RowError += "PKD DATE : Invalid Date Format(Format : dd/MM/yyyy)\n";
                    }
                }
                else
                {
                    RowError += "PKD DATE * : PKD DATE should not be empty\n";
                }
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                {
                    if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                    {
                        RowError += "EXPIRY DATE : Invalid Date Format(Format : dd/MM/yyyy)\n";
                    }
                }
                else
                {
                    RowError += "EXPIRY DATE * : EXPIRY DATE should not be empty\n";
                }
            }
            else
            {
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PKD DATE"].ToString()))
                {
                    RowError += "PKD DATE : PKD No Product. Remove Date\n";
                }
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                {
                    RowError += "EXPIRY DATE : PKD No Product. Remove Date\n";
                }
            }
            #endregion
            #region "ACTUAL QTY", "DAMAGE QTY", "FREE QTY", "PURCHASE PRICE" "MRP *"


            string[] fields = { "ACTUAL QTY", "DAMAGE QTY", "FREE QTY", "PURCHASE PRICE",  "MRP" };
            foreach (var field in fields)
            {
                ValidateNumericField(row, field, false, ref RowError);
            }
            decimal qty = objBL.BL_dValidation(dtCheck.Rows[0]["ACTUAL QTY"].ToString());
            decimal DAMAGEqty = objBL.BL_dValidation(dtCheck.Rows[0]["DAMAGE QTY"].ToString());
            decimal FREEqty = objBL.BL_dValidation(dtCheck.Rows[0]["FREE QTY"].ToString());
            if (qty == 0 && DAMAGEqty == 0 && FREEqty == 0)
            {
                RowError += "QTY : Qty should not be empty. Give value in anyone QTY\n";
            }
            ValidatePercentageNumericField(row, "PRODUCT DISCOUNT", false, ref RowError);

            #endregion
            #region REASON
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["REASON NAME"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["REASON NAME"].ToString()))
                {
                    RowError += "REASON NAME : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 23, 3, dtCheck.Rows[0]["REASON NAME"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* REASON NAME(" + dtCheck.Rows[0]["REASON NAME"].ToString() + ") not found in Database\n";
                        ReasonID = 0;
                    }
                    else
                    {
                        ReasonID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            #endregion
            return RowError;
        }

        #endregion
        public string SaleSRBillPRDetailValidation(DataTable dtCheck,string DocType)
        {
            string RowError = "";
            DataRow row = dtCheck.Rows[0];
            DataTable dtProdData = new DataTable();
            #region Mandatory Field Validation
            string strDocID = dtCheck.Rows[0]["DOC ID *"].ToString();
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
            
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PRODUCT NAME *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["PRODUCT NAME *"].ToString()))
                {
                    RowError += "PRODUCT NAME * : Invalid Characters\n";
                }
                else
                {
                    dtProdData = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 5, 3, dtCheck.Rows[0]["PRODUCT NAME *"].ToString());
                    if (dtProdData.Rows.Count == 0)
                    {
                        RowError += "* PRODUCT NAME(" + dtCheck.Rows[0]["PRODUCT NAME *"].ToString() + ") not found in Database\n";
                        ProductID = 0;
                    }
                    else
                    {
                        ProductID = Convert.ToInt32(dtProdData.Rows[0][0].ToString());
                        TrackPKDYN = Convert.ToBoolean(dtProdData.Rows[0]["TrackPDK"].ToString()) ? 1 : 0;
                        TrackBatchYN = Convert.ToBoolean(dtProdData.Rows[0]["TrackBatch"].ToString()) ? 1 : 0;
                        TrackInvYN = Convert.ToBoolean(dtProdData.Rows[0]["TrackInventory"].ToString()) ? 1 : 0;
                    }
                }
            }
            else
            {
                RowError += "PRODUCT NAME * : PRODUCT Name should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["TAX NAME *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["TAX NAME *"].ToString()))
                {
                    RowError += "TAX NAME * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 6, 3, dtCheck.Rows[0]["TAX NAME *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* TAX NAME(" + dtCheck.Rows[0]["TAX NAME *"].ToString() + ") not found in Database\n";
                        TaxID = 0;
                    }
                    else
                    {
                        TaxID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "TAX NAME * : TAX Name should not be empty\n";
            }
            if (DocType.ToLower() == "bill" || DocType.ToLower() == "pr")
            {
                if (TrackInvYN == 0)
                {
                    RowError += "* Track Inventory No Products should not be allowed\n";
                }
            }
            #endregion
            #region Non-Mandatory Field Validations
            
            ValidateAlphaNumericSplField(row, "BATCH NUMBER", (ProductID > 0 && TrackBatchYN > 0), ref RowError);
            if (ProductID > 0 && TrackPKDYN > 0)
            {
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PKD DATE"].ToString()))
                {
                    if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["PKD DATE"].ToString()))
                    {
                        RowError += "PKD DATE : Invalid Date Format(Format : dd/MM/yyyy)\n";
                    }
                }
                else
                {
                    RowError += "PKD DATE * : PKD DATE should not be empty\n";
                }
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                {
                    if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                    {
                        RowError += "EXPIRY DATE : Invalid Date Format(Format : dd/MM/yyyy)\n";
                    }
                }
                else
                {
                    RowError += "EXPIRY DATE * : EXPIRY DATE should not be empty\n";
                }
            }
            else
            {
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PKD DATE"].ToString()))
                {
                    RowError += "PKD DATE : PKD No Product. Remove Date\n";
                }
                if (!string.IsNullOrEmpty(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                {
                    RowError += "EXPIRY DATE : PKD No Product. Remove Date\n";
                }
            }
            
            string[] fields = {"ACTUAL QTY","DAMAGE QTY","FREE QTY","UOM PURCHASE PRICE",
                                "UOM SALE PRICE","UOM ECP PRICE","UOM SPL PRICE","UOM MRP PRICE",
                                 "RETURN PRICE"};



            foreach (var field in fields)
            {
                ValidateNumericField(row, field, false, ref RowError);
            }
            ValidatePercentageNumericField(row, "PRODUCT DISCOUNT", false, ref RowError);
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["REASON NAME"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["REASON NAME"].ToString()))
                {
                    RowError += "REASON NAME : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 23, 3, dtCheck.Rows[0]["REASON NAME"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* REASON NAME(" + dtCheck.Rows[0]["REASON NAME"].ToString() + ") not found in Database\n";
                        ReasonID = 0;
                    }
                    else
                    {
                        ReasonID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            #endregion
            return RowError;
        }
        public string SaleSRBillPRNetAmtValidation(DataTable dtHeaderrow, DataTable dtItemsData,string strDocPrefix)
        {
            try
            {
                string RowError = "";
                var header = dtHeaderrow.Rows[0];
                string strDocID = header["DOC ID *"].ToString();
                //string strDocPrefix = header["DOC PREFIX *"].ToString().ToLower();
                // Filter items
                var items = dtItemsData.AsEnumerable()
                    .Where(r => r["DOC ID *"].ToString() == strDocID)
                    .ToList();

                if (!items.Any())
                    return $"No Item Details found for this Doc ID - {strDocID}";

                // Header values
                decimal tradeDiscPern = objBL.BL_dValidation(header["TRADE DISCOUNT %"].ToString());
                decimal addnlDiscPern = objBL.BL_dValidation(header["ADDITIONAL DISCOUNT %"].ToString());
                decimal headerNetAmt = objBL.BL_dValidation(header["NET AMOUNT *"].ToString());

                decimal itemNetAmt = 0;
                // Declare once (outside loop)
                decimal taxValue = 0, qty = 0, dmgQty = 0, price = 0, prodDiscPern = 0;
                decimal goodsAmt = 0, prodDiscAmt = 0, baseAmt = 0;
                decimal tradeDiscAmt = 0, addnlDiscAmt = 0, grossAmt = 0, taxAmt = 0;
                if (strDocPrefix == "bill" || strDocPrefix == "pr")
                {
                    foreach (var row in items)
                    {
                        // Get tax %
                        var taxDt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 6, 3, row["TAX NAME *"].ToString());
                        taxValue = objBL.BL_dValidation(taxDt.Rows[0]["GST"].ToString());

                        // Values
                        qty = objBL.BL_dValidation(row["ACTUAL QTY"].ToString());
                        dmgQty = objBL.BL_dValidation(row["DAMAGE QTY"].ToString());
                        price = objBL.BL_dValidation(row["PURCHASE PRICE"].ToString());
                        prodDiscPern = objBL.BL_dValidation(row["PRODUCT DISCOUNT"].ToString());

                        // Calculations
                        goodsAmt = (qty + dmgQty) * price;
                        prodDiscAmt = goodsAmt * prodDiscPern / 100;

                        baseAmt = goodsAmt - prodDiscAmt;

                        tradeDiscAmt = baseAmt * tradeDiscPern / 100;
                        addnlDiscAmt = baseAmt * addnlDiscPern / 100;

                        grossAmt = baseAmt - (tradeDiscAmt + addnlDiscAmt);
                        taxAmt = grossAmt * taxValue / 100;

                        itemNetAmt += grossAmt + taxAmt;
                    }

                    decimal netDiff = headerNetAmt - itemNetAmt;

                    if (Math.Abs(netDiff) > 1)
                    {
                        return $"Net Amount Mismatch between Header ({Math.Round(headerNetAmt, 2)}) and Detail ({Math.Round(itemNetAmt, 2)})";
                    }
                }
                return RowError;
            }
            catch (Exception ex)
            {
                throw ex;
            }
        }
        void ValidateNumericField(DataRow row, string columnName, bool IsMandatory, ref string rowError)
        {
            string value = row[columnName]?.ToString();

            if (!string.IsNullOrEmpty(value))
            {
                if (!objBL.BL_NumericWithDecimal(value))
                {
                    rowError += $"{columnName} : Invalid character (Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(value) < 0)
                    {
                        rowError += $"{columnName} : Value should be greater than or equal to 0 only\n";
                    }
                }
            }
            else if (IsMandatory)
            {
                rowError += $"{columnName} : Value should not be empty\n";
            }
        }
        void ValidatePercentageNumericField(DataRow row, string columnName, bool IsMandatory, ref string rowError)
        {
            string value = row[columnName]?.ToString();

            if (!string.IsNullOrEmpty(value))
            {
                if (!objBL.BL_NumericWithDecimal(value))
                {
                    rowError += $"{columnName} : Invalid character (Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(value) > 100)
                    {
                        rowError += $"{columnName} : Value should be less than 100 only\n";
                    }
                    if (objBL.BL_dValidation(value) < 0)
                    {
                        rowError += $"{columnName} : Value should be greater than or equal to 0 only\n";
                    }
                }
            }
            else if (IsMandatory)
            {
                rowError += $"{columnName} : Value should not be empty\n";
            }
        }
        void ValidateAlphaNumericSplField(DataRow row, string columnName, bool IsMandatory, ref string rowError)
        {
            string value = row[columnName]?.ToString();

            if (!string.IsNullOrEmpty(value))
            {
                if (!objBL.BL_AlphaNumericSpl(value))
                {
                    rowError += $"{columnName} : Invalid character\n";
                }
            }
            else if (IsMandatory)
            {
                rowError += $"{columnName} : Value should not be empty\n";
            }
        }
        void ValidateNumericOnlyField(DataRow row, string columnName, bool IsMandatory, ref string rowError)
        {
            string value = row[columnName]?.ToString();

            if (!string.IsNullOrEmpty(value))
            {
                if (!objBL.BL_Numeric(value))
                {
                    rowError += $"{columnName} : Invalid character\n";
                }
                if (objBL.BL_dValidation(value) < 0)
                {
                    rowError += $"{columnName} : Value should be greater than or equal to 0 only\n";
                }
            }
            else if (IsMandatory)
            {
                rowError += $"{columnName} : Value should not be empty\n";
            }
        }

        public DataTable SavePurchaseBill(DataTable dtHeader, DataTable dtItems, string UID)
        {
            DataTable dtSaveResponse = new DataTable();
            dtSaveResponse.Columns.Add("DocPrefix", typeof(string));
            dtSaveResponse.Columns.Add("DocID", typeof(string));
            dtSaveResponse.Columns.Add("DocDate", typeof(string));
            dtSaveResponse.Columns.Add("Error", typeof(string));
            string strDocID = "", strDocPrefix = "Bill", strDocDate = "";
            try
            {
                DataTable dtResult = new DataTable();
                DataTable dtPMDetail = new DataTable(), dtProd = new DataTable(),
                    dtDenominationPMDetail = new DataTable(), dtGSTInfo = new DataTable();
                #region Datatable Column Create
                dtPMDetail.Columns.Add("AccID", typeof(int));
                dtPMDetail.Columns.Add("ModeId", typeof(int));
                dtPMDetail.Columns.Add("BankAccNo", typeof(string));
                dtPMDetail.Columns.Add("BankAccId", typeof(int));
                dtPMDetail.Columns.Add("chqDDNoId", typeof(int));
                dtPMDetail.Columns.Add("ChequeDDNo", typeof(string));
                dtPMDetail.Columns.Add("Date", typeof(string));
                dtPMDetail.Columns.Add("PayAt", typeof(string));
                dtPMDetail.Columns.Add("IFSC", typeof(string));
                dtPMDetail.Columns.Add("Bank", typeof(string));
                dtPMDetail.Columns.Add("Branch", typeof(string));
                dtPMDetail.Columns.Add("Amt", typeof(decimal));
                dtPMDetail.Columns.Add("SerialNumber", typeof(int));
                dtPMDetail.Columns.Add("RecdAmt", typeof(decimal));
                dtPMDetail.Columns.Add("OriginalCollAmt", typeof(decimal));
                dtPMDetail.Columns.Add("VisaPern", typeof(decimal));
                dtPMDetail.Columns.Add("VisaAmt", typeof(decimal));
                //
                dtProd.Columns.Add("ProdId", typeof(int));
                dtProd.Columns.Add("UomId", typeof(int));
                dtProd.Columns.Add("UomGrpID", typeof(int));
                dtProd.Columns.Add("UOMCR", typeof(decimal));
                dtProd.Columns.Add("HSN", typeof(string));
                dtProd.Columns.Add("BatchNo", typeof(string));
                dtProd.Columns.Add("PKD", typeof(string));
                dtProd.Columns.Add("Expiry", typeof(string));
                dtProd.Columns.Add("Qty", typeof(decimal));
                dtProd.Columns.Add("FreeQty", typeof(decimal));
                dtProd.Columns.Add("DamageQty", typeof(decimal));
                dtProd.Columns.Add("PurchasePrice", typeof(decimal));
                dtProd.Columns.Add("SalePrice", typeof(decimal));
                dtProd.Columns.Add("ECP", typeof(decimal));
                dtProd.Columns.Add("MRP", typeof(decimal));
                dtProd.Columns.Add("SPLPrice", typeof(decimal));
                dtProd.Columns.Add("ReturnPrice", typeof(decimal));
                dtProd.Columns.Add("TaxID", typeof(int));
                dtProd.Columns.Add("TaxTypeId", typeof(int));
                dtProd.Columns.Add("TaxPercentage", typeof(decimal));
                dtProd.Columns.Add("GoodsAmt", typeof(decimal));
                dtProd.Columns.Add("ProdDiscPercent", typeof(decimal));
                dtProd.Columns.Add("TradeDiscPercent", typeof(decimal));
                dtProd.Columns.Add("AddnlDiscPercent", typeof(decimal));
                dtProd.Columns.Add("GrossAmt", typeof(decimal));
                dtProd.Columns.Add("TaxAmt", typeof(decimal));
                dtProd.Columns.Add("NetAmt", typeof(decimal));
                dtProd.Columns.Add("InventoryId", typeof(int));
                dtProd.Columns.Add("InclusiveYesNo", typeof(int)).DefaultValue = 0;
                dtProd.Columns.Add("ReasonID", typeof(int)).DefaultValue = 0;
                dtProd.Columns.Add("LocationID", typeof(int)).DefaultValue = 0;
                dtProd.Columns.Add("DiffAmt", typeof(int)).DefaultValue = 0;
                //
                dtDenominationPMDetail.Columns.Add("ColDetailDid", typeof(int));
                dtDenominationPMDetail.Columns.Add("ColDetailDenomination", typeof(int));
                dtDenominationPMDetail.Columns.Add("ColtotCoupons", typeof(int));
                dtDenominationPMDetail.Columns.Add("ColDetailCount", typeof(string));
                dtDenominationPMDetail.Columns.Add("ColDetailAmount", typeof(decimal));
                //
                dtGSTInfo.Columns.Add("TransID", typeof(int));
                dtGSTInfo.Columns.Add("TransIdentID", typeof(int));
                dtGSTInfo.Columns.Add("ProdID", typeof(int));
                dtGSTInfo.Columns.Add("TaxID", typeof(int));
                dtGSTInfo.Columns.Add("GSTTaxTypeID", typeof(int));
                dtGSTInfo.Columns.Add("TaxTypeID", typeof(int));
                dtGSTInfo.Columns.Add("TaxCompID", typeof(int));
                dtGSTInfo.Columns.Add("TaxCompPern", typeof(decimal));
                dtGSTInfo.Columns.Add("TaxCompAmount", typeof(decimal));
                dtGSTInfo.Columns.Add("GrossAmount", typeof(decimal));
                dtGSTInfo.Columns.Add("TransSerial", typeof(int));
                dtGSTInfo.Columns.Add("SerialNo", typeof(int));
                #endregion
                for (int i = 0; i < dtHeader.Rows.Count; i++)
                {
                    var headerRow = dtHeader.Rows[i];
                    strDocID = headerRow["DOC ID *"].ToString();                    
                    strDocDate = headerRow["DOC Date *"].ToString();
                    decimal tradeDiscPern = objBL.BL_dValidation(headerRow["TRADE DISCOUNT %"].ToString());
                    decimal addnlDiscPern = objBL.BL_dValidation(headerRow["ADDITIONAL DISCOUNT %"].ToString());
                    decimal otherChargePern = objBL.BL_dValidation(headerRow["OTHER CHARGE %"].ToString());
                    decimal headerNetAmt = objBL.BL_dValidation(headerRow["NET AMOUNT *"].ToString());
                    decimal otherChargeAmt = (headerNetAmt * otherChargePern) / 100;
                    DataTable dtPartyData = objBL.BL_ExecuteSqlQuery("SELECT * FROM tblMasterCustomer WHERE ID = " + Convert.ToString(headerRow["PARTY NAME *"]));
                    int TaxTypeID = objBL.BL_nValidation(dtPartyData.Rows[0]["TaxTypeID"].ToString());
                    
                    // Filter items
                    var items = dtItems.AsEnumerable()
                        .Where(r => r["DOC ID *"].ToString() == strDocID)
                        .ToList();

                    foreach (var row in items)
                    {
                        // Get tax %
                        var taxDt = objBL.BL_ExecuteSqlQuery("SELECT * FROM tblMasterTax WHERE TaxID = " + row["TAX NAME *"].ToString());
                        taxValue = objBL.BL_dValidation(taxDt.Rows[0]["GST"].ToString());
                        // Prod Data
                        DataTable dtProductData = objBL.BL_ExecuteSqlQuery("SELECT * FROM tblMasterProduct WHERE ID = " + Convert.ToString(row["PRODUCT NAME *"]));
                        DataTable dtItemTransPrices = objBL.BL_ExecuteSqlQuery("select * from tblProductTransactionprices where ID = " + Convert.ToString(row["PRODUCT NAME *"]));
                        BaseUOMID = objBL.BL_nValidation(dtProductData.Rows[0]["BaseUomID"]);
                        uomcr = objBL.BL_dValidation(dtProductData.Rows[0]["BaseCR"]);
                        HSN = dtProductData.Rows[0]["HSNCode"].ToString();
                        var Proditems = items.AsEnumerable()
                        .Where(r => r["PRODUCT NAME *"].ToString() == strDocID)
                        .ToList();
                        BillTransAmount = dtItemTransPrices.Rows.Count > 0 ? objBL.BL_dValidation(dtItemTransPrices.Rows[0]["PurchaseBillPrice"]) : 0;
                        // Values
                        qty = objBL.BL_dValidation(row["ACTUAL QTY"].ToString());
                        freeqty = objBL.BL_dValidation(row["FREE QTY"].ToString());
                        dmgQty = objBL.BL_dValidation(row["DAMAGE QTY"].ToString());
                        price = objBL.BL_dValidation(row["PURCHASE PRICE"].ToString());

                        Saleprice = objBL.BL_dValidation(row["SALE PRICE"].ToString());
                        ECPprice = objBL.BL_dValidation(row["ECP PRICE"].ToString());
                        SPLprice = objBL.BL_dValidation(row["SPL PRICE"].ToString());
                        MRP = objBL.BL_dValidation(row["MRP"].ToString());
                        Returnprice = objBL.BL_dValidation(row["RETURN PRICE"].ToString());

                        prodDiscPern = objBL.BL_dValidation(row["PRODUCT DISCOUNT"].ToString());

                        // Calculations
                        goodsAmt = (qty + dmgQty) * price;

                        prodDiscAmt = goodsAmt * prodDiscPern / 100;
                        CumProdDiscAmt += prodDiscAmt;
                        baseAmt = goodsAmt - prodDiscAmt;

                        tradeDiscAmt = baseAmt * tradeDiscPern / 100;
                        addnlDiscAmt = baseAmt * addnlDiscPern / 100;
                        CumTradeDiscAmt += tradeDiscAmt;
                        CumAddnlDiscAmt += addnlDiscAmt;
                        grossAmt = baseAmt - (tradeDiscAmt + addnlDiscAmt);
                        taxAmt = grossAmt * taxValue / 100;

                        itemNetAmt = grossAmt + taxAmt;
                        CumNet += itemNetAmt;
                        var PerQty = grossAmt / qty;
                        BillDiffAmt = BillTransAmount - PerQty;
                        decimal caldiffamt = BillDiffAmt * (qty);
                        CumDiffGross += caldiffamt;
                        CumDiffNet += caldiffamt + ((caldiffamt * taxValue) / 100);
                        //BillDiffAmt = price - BillTransAmount;
                        //decimal caldiffamt = BillDiffAmt * (qty + dmgQty);
                        //CumDiffGross += caldiffamt;
                        //CumDiffNet += caldiffamt + ((caldiffamt * taxValue) / 100);
                        DataRow dtRow = dtProd.NewRow();
                        dtRow["ProdId"] = objBL.BL_nValidation(Convert.ToString(row["PRODUCT NAME *"]));
                        dtRow["UomId"] = BaseUOMID;
                        dtRow["UOMCR"] = uomcr;
                        dtRow["HSN"] = HSN;
                        string PKD = !string.IsNullOrEmpty(row["PKD DATE"].ToString()) ? Convert.ToDateTime(row["PKD DATE"].ToString()).ToString("dd/MM/yyyy") : null;
                        string Exp = !string.IsNullOrEmpty(row["EXPIRY DATE"].ToString()) ? Convert.ToDateTime(row["EXPIRY DATE"].ToString()).ToString("dd/MM/yyyy") : null;
                        dtRow["BatchNo"] = row["BATCH NUMBER"].ToString();
                        dtRow["PKD"] = PKD;// iRow["PKDDate"].ToString();
                        dtRow["Expiry"] = Exp;// iRow["ExpiryDate"].ToString();
                        dtRow["Qty"] = qty;
                        dtRow["FreeQty"] = freeqty;
                        dtRow["DamageQty"] = dmgQty;
                        dtRow["PurchasePrice"] = price;
                        dtRow["SalePrice"] = Saleprice;
                        dtRow["ECP"] = ECPprice;
                        dtRow["MRP"] = MRP;
                        dtRow["SPLPrice"] = SPLprice;
                        dtRow["ReturnPrice"] = Returnprice;
                        dtRow["TaxID"] = objBL.BL_nValidation(Convert.ToString(row["TAX NAME *"]));
                        dtRow["TaxTypeId"] = TaxTypeID;
                        dtRow["TaxPercentage"] = taxValue;
                        dtRow["GoodsAmt"] = grossAmt;// objBL.BL_dValidation(iRow["GoodsAmt"].ToString()); // GoodsAmt
                        dtRow["ProdDiscPercent"] = prodDiscPern;
                        dtRow["TradeDiscPercent"] = tradeDiscPern;
                        dtRow["AddnlDiscPercent"] = addnlDiscPern;
                        dtRow["GrossAmt"] = grossAmt; // gross
                        dtRow["TaxAmt"] = taxAmt + objBL.BL_dValidation(dUomTax); // tax
                        dtRow["NetAmt"] = itemNetAmt + objBL.BL_dValidation(dUomTax); // net
                        dtRow["InventoryId"] = 0;// objBL.BL_nValidation(iRow["InventoryId"].ToString());
                        dtRow["InclusiveYesNo"] = 0;
                        dtRow["ReasonID"] = objBL.BL_nValidation(Convert.ToString(row["REASON NAME"]));
                        dtRow["LocationID"] = 0;
                        dtRow["DiffAmt"] = BillDiffAmt;
                        dtProd.Rows.Add(dtRow);
                    }
                    CumGross = dtProd.AsEnumerable().Sum(grs => grs.Field<decimal>("GrossAmt"));
                    CumTax = dtProd.AsEnumerable().Sum(grs => grs.Field<decimal>("TaxAmt"));
                    CumNet = dtProd.AsEnumerable().Sum(grs => grs.Field<decimal>("NetAmt"));

                    decimal RoundoffAmt = headerNetAmt - CumNet;

                    objBL.bl_Transaction(1);
                    dtResult = objBL.bl_ManageTrans("uspManageTransPurchaseBill", 1, 0, objBL.BL_nValidation(headerRow["BRANCH NAME *"]), 1,
                                    headerRow["DOC DATE *"], headerRow["PARTY NAME *"], objBL.BL_dValidation(CumGross), objBL.BL_dValidation(CumTax),
                                    objBL.BL_dValidation(headerNetAmt), headerRow["DOC ID *"], 0,
                                    TaxTypeID, headerRow["CREDIT TERM *"], null, headerRow["PAYMENT MODE *"], objBL.BL_nValidation(headerRow["VECHICLE NUMBER"]),
                                    objBL.BL_dValidation(headerRow["FRIEGHT"]),
                                    objBL.BL_dValidation(otherChargePern), objBL.BL_dValidation(otherChargeAmt),
                                    0, objBL.BL_dValidation(tradeDiscPern),
                                    objBL.BL_dValidation(addnlDiscPern), CumProdDiscAmt,
                                    CumTradeDiscAmt, CumAddnlDiscAmt,
                                    objBL.BL_dValidation(headerRow["WRITEOFF AMT"]), UID,
                                    RoundoffAmt, dtProd,
                                    dtPMDetail, 0, 1, 0, 0, null, 0, 0, 0, 0,
                                    headerRow["REMARKS"], "Import Data", 0, dtDenominationPMDetail,
                                    CumDiffGross, CumDiffNet);
                    if (dtResult.Columns.Count > 1)
                    {
                        DataRow drresp = dtSaveResponse.NewRow();
                        drresp["DocPrefix"] = strDocPrefix;
                        drresp["DocID"] = strDocID;
                        drresp["DocDate"] = strDocDate;
                        drresp["Error"] = dtResult.Rows[0][0].ToString();
                        dtSaveResponse.Rows.Add(drresp);
                        objBL.bl_Transaction(3);
                        break;
                    }
                    else
                    {
                        int nBillScopeID = objBL.BL_nValidation(dtResult.Rows[0][0]);

                        if (dtProd.Rows.Count > 0)
                        {
                            int nProdID = 0, nTaxID = 0, nTaxTypeID = 0, SRSerial = 1, nTranSerial = 1;
                            decimal dQtnGrossAmount = 0.00M, dQtys = 0.00M;
                            dtGSTInfo.Rows.Clear();
                            for (int nCount = 0; nCount < dtProd.Rows.Count; nCount++)
                            {
                                //if (objBL.BL_dValidation(dtProd.Rows[nCount]["Qty"]) > 0)
                                //{
                                nProdID = objBL.BL_nValidation(dtProd.Rows[nCount]["ProdId"]);
                                nTaxID = objBL.BL_nValidation(dtProd.Rows[nCount]["TaxID"]);
                                nTaxTypeID = TaxTypeID;
                                DataTable dtMTdetail = objBL.bl_ManageTrans("uspGetTaxCumulative", nTaxID, nTaxTypeID, 1);
                                decimal dApponMRPCum = dtMTdetail.Select("AppOn = -1").Select(r => Convert.ToDecimal(r["CumulativeTax"])).DefaultIfEmpty(0).Sum();
                                decimal dMRP = objBL.BL_dValidation(dtProd.Rows[nCount]["MRP"]);
                                dQtnGrossAmount = objBL.BL_dValidation(dtProd.Rows[nCount]["GrossAmt"]);
                                dQtys = (objBL.BL_dValidation(dtProd.Rows[nCount]["Qty"]) + objBL.BL_dValidation(dtProd.Rows[nCount]["DamageQty"])) * 1;// objBL.BL_dValidation(dtResult.Rows[0][0]);
                                decimal newgrossamt = dApponMRPCum == 0 ? dQtnGrossAmount : objBL.ReturnGrossorMRPTaxAmt(1, nTaxID, nTaxTypeID, dQtnGrossAmount,
                                               dMRP * dQtys);
                                DataTable dtTaxCompInfo = objBL.bl_ManageTrans("uspGetTaxCompInfo", nTaxID, nTaxTypeID);
                                if (dtTaxCompInfo.Rows.Count > 0)
                                {
                                    bool ValidtoCalc = false;

                                    for (int nTaxComp = 0; nTaxComp < dtTaxCompInfo.Rows.Count; nTaxComp++)
                                    {
                                        ValidtoCalc = true; //nTaxTypeID == 2 && objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 1 ||
                                                            //nTaxTypeID == 1 && objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 2 ? false : true;
                                        DataRow dr = dtGSTInfo.NewRow();
                                        dr["TransID"] = 1;
                                        dr["TransIdentID"] = nBillScopeID;
                                        dr["ProdID"] = nProdID;
                                        dr["TaxID"] = nTaxID;
                                        dr["GSTTaxTypeID"] = objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]);
                                        dr["TaxTypeID"] = nTaxTypeID;
                                        dr["TaxCompID"] = objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][0]);
                                        dr["TaxCompPern"] = objBL.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2]);
                                        dr["TaxCompAmount"] = ValidtoCalc ? ((newgrossamt * objBL.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2])) / 100) :
                                                objBL.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2]) * dQtys;//dQtnGrossAmount
                                        dr["GrossAmount"] = newgrossamt;// dQtnGrossAmount;
                                                                        //dr["TransSerial"] = nTranSerial;
                                        dr["TransSerial"] = (nCount + 1);
                                        dr["SerialNo"] = SRSerial;
                                        dtGSTInfo.Rows.Add(dr);
                                        SRSerial++;
                                    }
                                    nTranSerial++;
                                }
                                //}
                            }
                            if (dtGSTInfo.Rows.Count > 0)
                            {
                                objBL.bl_ManageTrans("uspSaveTranGSTInfo", dtGSTInfo);
                            }
                        }

                        DataRow drresp = dtSaveResponse.NewRow();
                        drresp["DocPrefix"] = strDocPrefix;
                        drresp["DocID"] = strDocID;
                        drresp["DocDate"] = strDocDate;
                        drresp["Error"] = "Completed";
                        dtSaveResponse.Rows.Add(drresp);
                        objBL.bl_Transaction(2);
                        objBL.BL_UpdateclosingDateforPosting(1, nBillScopeID, Convert.ToDateTime(headerRow["DOC DATE *"]));
                    }
                }
            }
            catch (Exception ex)
            {
                DataRow drresp = dtSaveResponse.NewRow();
                drresp["DocPrefix"] = strDocPrefix;
                drresp["DocID"] = strDocID;
                drresp["DocDate"] = strDocDate;
                drresp["Error"] = ex.Message;
                dtSaveResponse.Rows.Add(drresp);
            }
            finally
            {
            }
            return dtSaveResponse;
        }
        public DataTable SavePurchaseReturn(DataTable dtHeader, DataTable dtItems, string UID)
        {
            DataTable dtSaveResponse = new DataTable();
            dtSaveResponse.Columns.Add("DocPrefix", typeof(string));
            dtSaveResponse.Columns.Add("DocID", typeof(string));
            dtSaveResponse.Columns.Add("DocDate", typeof(string));
            dtSaveResponse.Columns.Add("Error", typeof(string));
            string strDocID = "", strDocPrefix = "PR", strDocDate = "";
            try
            {
                DataTable dtResult = new DataTable();
                DataTable dtPMDetail = new DataTable(), dtProd = new DataTable(), dtGSTInfo = new DataTable();
                #region Datatable Column Create                                
                dtProd.Columns.Add("ProdId", typeof(int));
                dtProd.Columns.Add("UomId", typeof(int));
                dtProd.Columns.Add("UomGrpID", typeof(int));
                dtProd.Columns.Add("UOMCR", typeof(decimal));
                dtProd.Columns.Add("HSN", typeof(string));
                dtProd.Columns.Add("BatchNo", typeof(string));
                dtProd.Columns.Add("PKD", typeof(string));
                dtProd.Columns.Add("Expiry", typeof(string));
                dtProd.Columns.Add("Qty", typeof(decimal));
                dtProd.Columns.Add("FreeQty", typeof(decimal));
                dtProd.Columns.Add("DamageQty", typeof(decimal));
                dtProd.Columns.Add("PurchasePrice", typeof(decimal));
                dtProd.Columns.Add("SalePrice", typeof(decimal));
                dtProd.Columns.Add("ECP", typeof(decimal));
                dtProd.Columns.Add("MRP", typeof(decimal));
                dtProd.Columns.Add("SPLPrice", typeof(decimal));
                dtProd.Columns.Add("ReturnPrice", typeof(decimal));
                dtProd.Columns.Add("TaxID", typeof(int));
                dtProd.Columns.Add("TaxTypeId", typeof(int));
                dtProd.Columns.Add("TaxPercentage", typeof(decimal));
                dtProd.Columns.Add("GoodsAmt", typeof(decimal));
                dtProd.Columns.Add("ProdDiscPercent", typeof(decimal));
                dtProd.Columns.Add("TradeDiscPercent", typeof(decimal));
                dtProd.Columns.Add("AddnlDiscPercent", typeof(decimal));
                dtProd.Columns.Add("GrossAmt", typeof(decimal));
                dtProd.Columns.Add("TaxAmt", typeof(decimal));
                dtProd.Columns.Add("NetAmt", typeof(decimal));
                dtProd.Columns.Add("InventoryId", typeof(int));
                dtProd.Columns.Add("InclusiveYesNo", typeof(int)).DefaultValue = 0;
                dtProd.Columns.Add("ReasonID", typeof(int)).DefaultValue = 0;
                dtProd.Columns.Add("LocationID", typeof(int)).DefaultValue = 0;
                dtProd.Columns.Add("DiffAmt", typeof(int)).DefaultValue = 0;
                //
                dtGSTInfo.Columns.Add("TransID", typeof(int));
                dtGSTInfo.Columns.Add("TransIdentID", typeof(int));
                dtGSTInfo.Columns.Add("ProdID", typeof(int));
                dtGSTInfo.Columns.Add("TaxID", typeof(int));
                dtGSTInfo.Columns.Add("GSTTaxTypeID", typeof(int));
                dtGSTInfo.Columns.Add("TaxTypeID", typeof(int));
                dtGSTInfo.Columns.Add("TaxCompID", typeof(int));
                dtGSTInfo.Columns.Add("TaxCompPern", typeof(decimal));
                dtGSTInfo.Columns.Add("TaxCompAmount", typeof(decimal));
                dtGSTInfo.Columns.Add("GrossAmount", typeof(decimal));
                dtGSTInfo.Columns.Add("TransSerial", typeof(int));
                dtGSTInfo.Columns.Add("SerialNo", typeof(int));
                #endregion
                for (int i = 0; i < dtHeader.Rows.Count; i++)
                {
                    var headerRow = dtHeader.Rows[i];
                    strDocID = headerRow["DOC ID *"].ToString();                    
                    strDocDate = headerRow["DOC Date *"].ToString();
                    decimal tradeDiscPern = objBL.BL_dValidation(headerRow["TRADE DISCOUNT %"].ToString());
                    decimal addnlDiscPern = objBL.BL_dValidation(headerRow["ADDITIONAL DISCOUNT %"].ToString());
                    decimal otherChargePern = objBL.BL_dValidation(headerRow["OTHER CHARGE %"].ToString());
                    decimal headerNetAmt = objBL.BL_dValidation(headerRow["NET AMOUNT *"].ToString());
                    decimal otherChargeAmt = (headerNetAmt * otherChargePern) / 100;
                    DataTable dtPartyData = objBL.BL_ExecuteSqlQuery("SELECT * FROM tblMasterCustomer WHERE ID = " + Convert.ToString(headerRow["PARTY NAME *"]));
                    int TaxTypeID = objBL.BL_nValidation(dtPartyData.Rows[0]["TaxTypeID"].ToString());

                    // Filter items
                    var items = dtItems.AsEnumerable()
                        .Where(r => r["DOC ID *"].ToString() == strDocID)
                        .ToList();

                    foreach (var row in items)
                    {
                        // Get tax %
                        var taxDt = objBL.BL_ExecuteSqlQuery("SELECT * FROM tblMasterTax WHERE TaxID = " + row["TAX NAME *"].ToString());
                        taxValue = objBL.BL_dValidation(taxDt.Rows[0]["GST"].ToString());
                        // Prod Data
                        DataTable dtProductData = objBL.BL_ExecuteSqlQuery("SELECT * FROM tblMasterProduct WHERE ID = " + Convert.ToString(row["PRODUCT NAME *"]));
                        DataTable dtItemTransPrices = objBL.BL_ExecuteSqlQuery("select * from tblProductTransactionprices where ID = " + Convert.ToString(row["PRODUCT NAME *"]));
                        BaseUOMID = objBL.BL_nValidation(dtProductData.Rows[0]["BaseUomID"]);
                        uomcr = objBL.BL_dValidation(dtProductData.Rows[0]["BaseCR"]);
                        HSN = dtProductData.Rows[0]["HSNCode"].ToString();
                        BillTransAmount = dtItemTransPrices.Rows.Count > 0 ? objBL.BL_dValidation(dtItemTransPrices.Rows[0]["PurchaseReturnPrice"]) : 0;
                        // Values
                        qty = objBL.BL_dValidation(row["ACTUAL QTY"].ToString());
                        freeqty = objBL.BL_dValidation(row["FREE QTY"].ToString());
                        dmgQty = objBL.BL_dValidation(row["DAMAGE QTY"].ToString());
                        price = objBL.BL_dValidation(row["PURCHASE PRICE"].ToString());

                        MRP = objBL.BL_dValidation(row["MRP"].ToString());
                        prodDiscPern = objBL.BL_dValidation(row["PRODUCT DISCOUNT"].ToString());

                        // Calculations
                        goodsAmt = (qty + dmgQty) * price;

                        prodDiscAmt = goodsAmt * prodDiscPern / 100;
                        CumProdDiscAmt += prodDiscAmt;
                        baseAmt = goodsAmt - prodDiscAmt;

                        tradeDiscAmt = baseAmt * tradeDiscPern / 100;
                        addnlDiscAmt = baseAmt * addnlDiscPern / 100;
                        CumTradeDiscAmt += tradeDiscAmt;
                        CumAddnlDiscAmt += addnlDiscAmt;
                        grossAmt = baseAmt - (tradeDiscAmt + addnlDiscAmt);
                        taxAmt = grossAmt * taxValue / 100;

                        itemNetAmt = grossAmt + taxAmt;
                        CumNet += itemNetAmt;
                        var PerQty = grossAmt / qty;
                        BillDiffAmt = PerQty - BillTransAmount;
                        decimal caldiffamt = BillDiffAmt * (qty);
                        CumDiffGross += caldiffamt;
                        CumDiffNet += caldiffamt + ((caldiffamt * taxValue) / 100);
                        //BillDiffAmt = price - BillTransAmount;
                        //decimal caldiffamt = BillDiffAmt * (qty + dmgQty);
                        //CumDiffGross += caldiffamt;
                        //CumDiffNet += caldiffamt + ((caldiffamt * taxValue) / 100);
                        DataRow dtRow = dtProd.NewRow();
                        dtRow["ProdId"] = objBL.BL_nValidation(Convert.ToString(row["PRODUCT NAME *"]));
                        dtRow["UomId"] = BaseUOMID;
                        dtRow["UOMCR"] = uomcr;
                        dtRow["HSN"] = HSN;
                        string PKD = !string.IsNullOrEmpty(row["PKD DATE"].ToString()) ? Convert.ToDateTime(row["PKD DATE"].ToString()).ToString("dd/MM/yyyy") : null;
                        string Exp = !string.IsNullOrEmpty(row["EXPIRY DATE"].ToString()) ? Convert.ToDateTime(row["EXPIRY DATE"].ToString()).ToString("dd/MM/yyyy") : null;
                        dtRow["BatchNo"] = row["BATCH NUMBER"].ToString();
                        dtRow["PKD"] = PKD;// iRow["PKDDate"].ToString();
                        dtRow["Expiry"] = Exp;// iRow["ExpiryDate"].ToString();
                        dtRow["Qty"] = qty;
                        dtRow["FreeQty"] = freeqty;
                        dtRow["DamageQty"] = dmgQty;
                        dtRow["PurchasePrice"] = price;
                        dtRow["SalePrice"] = Saleprice;
                        dtRow["ECP"] = ECPprice;
                        dtRow["MRP"] = MRP;
                        dtRow["SPLPrice"] = SPLprice;
                        dtRow["ReturnPrice"] = Returnprice;
                        dtRow["TaxID"] = objBL.BL_nValidation(Convert.ToString(row["TAX NAME *"]));
                        dtRow["TaxTypeId"] = TaxTypeID;
                        dtRow["TaxPercentage"] = taxValue;
                        dtRow["GoodsAmt"] = goodsAmt;// objBL.BL_dValidation(iRow["GoodsAmt"].ToString()); // GoodsAmt
                        dtRow["ProdDiscPercent"] = prodDiscPern;
                        dtRow["TradeDiscPercent"] = tradeDiscPern;
                        dtRow["AddnlDiscPercent"] = addnlDiscPern;
                        dtRow["GrossAmt"] = grossAmt; // gross
                        dtRow["TaxAmt"] = taxAmt + objBL.BL_dValidation(dUomTax); // tax
                        dtRow["NetAmt"] = itemNetAmt + objBL.BL_dValidation(dUomTax); // net
                        dtRow["InventoryId"] = 0;// objBL.BL_nValidation(iRow["InventoryId"].ToString());
                        dtRow["InclusiveYesNo"] = 0;
                        dtRow["ReasonID"] = objBL.BL_nValidation(Convert.ToString(row["REASON NAME"]));
                        dtRow["LocationID"] = 0;
                        dtRow["DiffAmt"] = BillDiffAmt;
                        dtProd.Rows.Add(dtRow);
                    }
                    CumGross = dtProd.AsEnumerable().Sum(grs => grs.Field<decimal>("GrossAmt"));
                    CumTax = dtProd.AsEnumerable().Sum(grs => grs.Field<decimal>("TaxAmt"));
                    CumNet = dtProd.AsEnumerable().Sum(grs => grs.Field<decimal>("NetAmt"));

                    decimal RoundoffAmt = headerNetAmt - CumNet;

                    objBL.bl_Transaction(1);
                    dtResult = objBL.bl_ManageTrans("uspManagePRHeader", 1, 6, UID, 0, headerRow["REMARKS"], "Import Data",
                               objBL.BL_nValidation(headerRow["BRANCH NAME *"]), headerRow["PARTY NAME *"], headerRow["DOC DATE *"], CumProdDiscAmt, CumGross, CumTax,
                               headerNetAmt, headerRow["DOC ID *"], 7, 0,
                               TaxTypeID, objBL.BL_nValidation(headerRow["VECHICLE NUMBER"]), objBL.BL_dValidation(tradeDiscPern), objBL.BL_dValidation(CumTradeDiscAmt),
                               objBL.BL_dValidation(addnlDiscPern), objBL.BL_dValidation(CumAddnlDiscAmt),
                               objBL.BL_dValidation(headerRow["FRIEGHT"]), objBL.BL_dValidation(otherChargePern), objBL.BL_dValidation(otherChargeAmt),
                               objBL.BL_dValidation(headerRow["WRITEOFF AMT"]), objBL.BL_dValidation(RoundoffAmt), 0, objBL.BL_dValidation(headerRow["RETURN TYPE"]),
                               1, null, 0, 0, 1, 0, 1, CumDiffGross, CumDiffNet);
                   
                    if (dtResult.Columns.Count > 1)
                    {
                        DataRow drresp = dtSaveResponse.NewRow();
                        drresp["DocPrefix"] = strDocPrefix;
                        drresp["DocID"] = strDocID;
                        drresp["DocDate"] = strDocDate;
                        drresp["Error"] = dtResult.Rows[0][0].ToString();
                        dtSaveResponse.Rows.Add(drresp);
                        objBL.bl_Transaction(3);
                        break;
                    }
                    else
                    {
                        int nBillScopeID = objBL.BL_nValidation(dtResult.Rows[0][0]);
                        for (int j = 0; j < dtProd.Rows.Count; j++)
                        {
                            

                            var iRow = dtProd.Rows[j];
                            int nProdID = objBL.BL_nValidation(Convert.ToString(dtProd.Rows[j]["ProdId"]));
                            string pkd = !string.IsNullOrEmpty(iRow["PKD"].ToString()) ? Convert.ToDateTime(iRow["PKD"]).ToString("yyyy-MM-dd") : null;
                            string exp = !string.IsNullOrEmpty(iRow["Expiry"].ToString()) ? Convert.ToDateTime(iRow["Expiry"]).ToString("yyyy-MM-dd") : null;
                            DataTable dtResultDetail = objBL.bl_ManageTrans("uspManagePRDetail", headerRow["DOC DATE *"], nBillScopeID, nProdID, 
                                objBL.BL_nValidation(iRow["UomId"]),
                                objBL.BL_dValidation(iRow["Qty"].ToString()), objBL.BL_dValidation(iRow["FreeQty"].ToString()), objBL.BL_dValidation(iRow["DamageQty"].ToString()),
                                iRow["BatchNo"].ToString(), pkd, exp, objBL.BL_dValidation(iRow["PurchasePrice"].ToString()),
                                objBL.BL_dValidation(iRow["MRP"].ToString()), 0, objBL.BL_dValidation(iRow["PurchasePrice"].ToString()),
                                objBL.BL_dValidation(iRow["TaxPercentage"].ToString()), objBL.BL_dValidation(iRow["GoodsAmt"].ToString()),
                                objBL.BL_dValidation(iRow["ProdDiscPercent"].ToString()), objBL.BL_dValidation(iRow["GrossAmt"].ToString()),
                                objBL.BL_dValidation(iRow["TaxAmt"].ToString()), 
                                objBL.BL_dValidation(iRow["NetAmt"].ToString()), objBL.BL_nValidation(iRow["TaxID"].ToString()), TaxTypeID, 
                                objBL.BL_nValidation(iRow["ReasonID"].ToString()), (j + 1), objBL.BL_nValidation(iRow["TaxID"].ToString()), 1, (i + 1),
                                objBL.BL_dValidation(Convert.ToString(iRow["TradeDiscPercent"])), objBL.BL_dValidation(iRow["AddnlDiscPercent"]), 1,
                                objBL.BL_nValidation(headerRow["BRANCH NAME *"]), 1, objBL.BL_dValidation(iRow["UOMCR"].ToString()),
                                objBL.BL_dValidation(iRow["DiffAmt"]));
                            if (dtResultDetail.Rows.Count > 0)
                            {                                
                                DataRow drresp1 = dtSaveResponse.NewRow();
                                drresp1["DocPrefix"] = strDocPrefix;
                                drresp1["DocID"] = strDocID;
                                drresp1["DocDate"] = strDocDate;
                                drresp1["Error"] = "Qty Mismatched";
                                dtSaveResponse.Rows.Add(drresp1);
                                objBL.bl_Transaction(3);
                                break;
                            }
                        }


                        if (dtProd.Rows.Count > 0)
                        {
                            if (dtSaveResponse.Rows.Count > 0) break;
                            int nProdID = 0, nTaxID = 0, nTaxTypeID = 0, SRSerial = 1, nTranSerial = 1;
                            decimal dQtnGrossAmount = 0.00M, dQtys = 0.00M;
                            dtGSTInfo.Rows.Clear();
                            for (int nCount = 0; nCount < dtProd.Rows.Count; nCount++)
                            {
                                //if (objBL.BL_dValidation(dtProd.Rows[nCount]["Qty"]) > 0)
                                //{
                                nProdID = objBL.BL_nValidation(dtProd.Rows[nCount]["ProdId"]);
                                nTaxID = objBL.BL_nValidation(dtProd.Rows[nCount]["TaxID"]);
                                nTaxTypeID = TaxTypeID;
                                DataTable dtMTdetail = objBL.bl_ManageTrans("uspGetTaxCumulative", nTaxID, nTaxTypeID, 1);
                                decimal dApponMRPCum = dtMTdetail.Select("AppOn = -1").Select(r => Convert.ToDecimal(r["CumulativeTax"])).DefaultIfEmpty(0).Sum();
                                decimal dMRP = objBL.BL_dValidation(dtProd.Rows[nCount]["MRP"]);
                                dQtnGrossAmount = objBL.BL_dValidation(dtProd.Rows[nCount]["GrossAmt"]);
                                dQtys = (objBL.BL_dValidation(dtProd.Rows[nCount]["Qty"]) + objBL.BL_dValidation(dtProd.Rows[nCount]["DamageQty"])) * 1;// objBL.BL_dValidation(dtResult.Rows[0][0]);
                                decimal newgrossamt = dApponMRPCum == 0 ? dQtnGrossAmount : objBL.ReturnGrossorMRPTaxAmt(1, nTaxID, nTaxTypeID, dQtnGrossAmount,
                                               dMRP * dQtys);
                                DataTable dtTaxCompInfo = objBL.bl_ManageTrans("uspGetTaxCompInfo", nTaxID, nTaxTypeID);
                                if (dtTaxCompInfo.Rows.Count > 0)
                                {
                                    bool ValidtoCalc = false;

                                    for (int nTaxComp = 0; nTaxComp < dtTaxCompInfo.Rows.Count; nTaxComp++)
                                    {
                                        ValidtoCalc = true; //nTaxTypeID == 2 && objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 1 ||
                                                            //nTaxTypeID == 1 && objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 2 ? false : true;
                                        DataRow dr = dtGSTInfo.NewRow();
                                        dr["TransID"] = 12;
                                        dr["TransIdentID"] = nBillScopeID;
                                        dr["ProdID"] = nProdID;
                                        dr["TaxID"] = nTaxID;
                                        dr["GSTTaxTypeID"] = objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]);
                                        dr["TaxTypeID"] = nTaxTypeID;
                                        dr["TaxCompID"] = objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][0]);
                                        dr["TaxCompPern"] = objBL.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2]);
                                        dr["TaxCompAmount"] = ValidtoCalc ? ((newgrossamt * objBL.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2])) / 100) :
                                                objBL.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2]) * dQtys;//dQtnGrossAmount
                                        dr["GrossAmount"] = newgrossamt;// dQtnGrossAmount;
                                                                        //dr["TransSerial"] = nTranSerial;
                                        dr["TransSerial"] = (nCount + 1);
                                        dr["SerialNo"] = SRSerial;
                                        dtGSTInfo.Rows.Add(dr);
                                        SRSerial++;
                                    }
                                    nTranSerial++;
                                }
                                //}
                            }
                            if (dtGSTInfo.Rows.Count > 0)
                            {
                                objBL.bl_ManageTrans("uspSaveTranGSTInfo", dtGSTInfo);
                            }
                        }

                        DataRow drresp = dtSaveResponse.NewRow();
                        drresp["DocPrefix"] = strDocPrefix;
                        drresp["DocID"] = strDocID;
                        drresp["DocDate"] = strDocDate;
                        drresp["Error"] = "Completed";
                        dtSaveResponse.Rows.Add(drresp);
                        objBL.bl_Transaction(2);
                        objBL.BL_UpdateclosingDateforPosting(1, nBillScopeID, Convert.ToDateTime(headerRow["DOC DATE *"]));
                    }
                }
            }
            catch (Exception ex)
            {
                DataRow drresp = dtSaveResponse.NewRow();
                drresp["DocPrefix"] = strDocPrefix;
                drresp["DocID"] = strDocID;
                drresp["DocDate"] = strDocDate;
                drresp["Error"] = ex.Message;
                dtSaveResponse.Rows.Add(drresp);
            }
            finally
            {
            }
            return dtSaveResponse;
        }
        public DataTable SaveSalesReturn(DataTable dtHeader, DataTable dtItems, string UID)
        {
            DataTable dtSaveResponse = new DataTable();
            dtSaveResponse.Columns.Add("DocPrefix", typeof(string));
            dtSaveResponse.Columns.Add("DocID", typeof(string));
            dtSaveResponse.Columns.Add("DocDate", typeof(string));
            dtSaveResponse.Columns.Add("Error", typeof(string));
            string strDocID = "", strDocPrefix = "SR", strDocDate = "";
            try
            {
                #region Datatable Declaration
                DataTable dtTempBachInfo = new DataTable(), dtProd = new DataTable(),
                    dtDocument = new DataTable(), dtGSTInfo = new DataTable(), dtSerialInfo = new DataTable();
                //
                dtProd.Columns.Add("ProdId", typeof(int));
                dtProd.Columns.Add("InventoryYesNo", typeof(int));
                dtProd.Columns.Add("BatchYesNo", typeof(int));
                dtProd.Columns.Add("PKDYesNo", typeof(int));
                dtProd.Columns.Add("SerialYesNo", typeof(int));
                dtProd.Columns.Add("BaseUomPrice", typeof(decimal));
                dtProd.Columns.Add("UomId", typeof(int));
                dtProd.Columns.Add("UomQty", typeof(decimal));
                dtProd.Columns.Add("UomPrice", typeof(decimal));
                dtProd.Columns.Add("GoodsAmt", typeof(decimal));
                dtProd.Columns.Add("UserDisc", typeof(decimal));
                dtProd.Columns.Add("UserDiscAmt", typeof(decimal));
                dtProd.Columns.Add("ProdDisc", typeof(decimal));
                dtProd.Columns.Add("ProdDiscAmt", typeof(decimal));
                dtProd.Columns.Add("TradeDisc", typeof(decimal));
                dtProd.Columns.Add("TradeDiscPern", typeof(decimal));
                dtProd.Columns.Add("AddnlDisc", typeof(decimal));
                dtProd.Columns.Add("AddnlDiscPern", typeof(decimal));
                dtProd.Columns.Add("GrossAmt", typeof(decimal));
                dtProd.Columns.Add("TaxId", typeof(int));
                dtProd.Columns.Add("TaxPercentage", typeof(decimal));
                dtProd.Columns.Add("TaxAmt", typeof(decimal));
                dtProd.Columns.Add("NetAmt", typeof(decimal));
                dtProd.Columns.Add("ReasonId", typeof(int));
                dtProd.Columns.Add("Serial", typeof(int));
                dtProd.Columns.Add("BatchNumber", typeof(string));
                dtProd.Columns.Add("PkgDate", typeof(string));
                dtProd.Columns.Add("ExpiryDate", typeof(string));
                dtProd.Columns.Add("InventoryPrice", typeof(decimal));
                dtProd.Columns.Add("MRP", typeof(decimal));
                dtProd.Columns.Add("InvQtyType", typeof(int));
                dtProd.Columns.Add("TempBatchInvId", typeof(int));
                dtProd.Columns.Add("UomCR", typeof(decimal));
                dtProd.Columns.Add("DiffAmt", typeof(decimal));
                //
                dtGSTInfo.Columns.Add("TransID", typeof(int));
                dtGSTInfo.Columns.Add("TransIdentID", typeof(int));
                dtGSTInfo.Columns.Add("ProdID", typeof(int));
                dtGSTInfo.Columns.Add("TaxID", typeof(int));
                dtGSTInfo.Columns.Add("GSTTaxTypeID", typeof(int));
                dtGSTInfo.Columns.Add("TaxTypeID", typeof(int));
                dtGSTInfo.Columns.Add("TaxCompID", typeof(int));
                dtGSTInfo.Columns.Add("TaxCompPern", typeof(decimal));
                dtGSTInfo.Columns.Add("TaxCompAmount", typeof(decimal));
                dtGSTInfo.Columns.Add("GrossAmount", typeof(decimal));
                dtGSTInfo.Columns.Add("TransSerial", typeof(int));
                dtGSTInfo.Columns.Add("SerialNo", typeof(int));
                //
                DataColumn column = new DataColumn("Serial");
                column.DataType = System.Type.GetType("System.Int32");
                column.AutoIncrement = true;
                column.AutoIncrementSeed = 1;
                column.AutoIncrementStep = 1;
                dtTempBachInfo.Columns.Add(column);
                dtTempBachInfo.Columns.Add("ProdId", typeof(int));
                dtTempBachInfo.Columns.Add("Batch", typeof(string));
                dtTempBachInfo.Columns.Add("PKD", typeof(string));
                dtTempBachInfo.Columns.Add("Expiry", typeof(string));
                dtTempBachInfo.Columns.Add("PPrice", typeof(decimal));
                dtTempBachInfo.Columns.Add("SPrice", typeof(decimal));
                dtTempBachInfo.Columns.Add("ECP", typeof(decimal));
                dtTempBachInfo.Columns.Add("MRP", typeof(decimal));
                dtTempBachInfo.Columns.Add("SPLPrice", typeof(decimal));
                dtTempBachInfo.Columns.Add("ReturnPrice", typeof(decimal));
                dtTempBachInfo.Columns.Add("TaxId", typeof(int));
                dtTempBachInfo.Columns.Add("TaxTypeId", typeof(int));
                dtTempBachInfo.Columns.Add("InclusiveYesNo", typeof(int));
                dtTempBachInfo.Columns.Add("BatchType", typeof(int));
                dtTempBachInfo.Columns.Add("HiddenRowID", typeof(int));
                dtDocument.Columns.Add("TransName");
                dtDocument.Columns.Add("Status", typeof(int)).DefaultValue = 0;
                dtDocument.Columns.Add("DocumentId", typeof(int)).DefaultValue = 0;
                //Serial Table
                dtSerialInfo.Columns.Add("Index", typeof(int));
                dtSerialInfo.Columns.Add("ProdId", typeof(int));
                dtSerialInfo.Columns.Add("Serial", typeof(string));
                #endregion
                for (int i = 0; i < dtHeader.Rows.Count; i++)
                {
                    var headerRow = dtHeader.Rows[i];
                    strDocID = headerRow["DOC ID *"].ToString();
                    //strDocPrefix = headerRow["DOC PREFIX *"].ToString().ToLower();
                    strDocDate = headerRow["DOC Date *"].ToString();
                    int TransType = objBL.BL_nValidation(headerRow["TRANSACTION TYPE"].ToString());
                    decimal tradeDiscPern = objBL.BL_dValidation(headerRow["TRADE DISCOUNT %"].ToString());
                    decimal addnlDiscPern = objBL.BL_dValidation(headerRow["ADDITIONAL DISCOUNT %"].ToString());
                    decimal otherChargePern = objBL.BL_dValidation(headerRow["OTHER CHARGE %"].ToString());
                    decimal headerNetAmt = objBL.BL_dValidation(headerRow["NET AMOUNT *"].ToString());
                    decimal otherChargeAmt = (headerNetAmt * otherChargePern) / 100;
                    DataTable dtPartyData = objBL.BL_ExecuteSqlQuery("SELECT * FROM tblMasterCustomer WHERE ID = " + Convert.ToString(headerRow["PARTY NAME *"]));
                    int TaxTypeID = objBL.BL_nValidation(dtPartyData.Rows[0]["TaxTypeID"].ToString());

                    // Filter items
                    var items = dtItems.AsEnumerable()
                        .Where(r => r["DOC ID *"].ToString() == strDocID)
                        .ToList();
                    int nSerial = 1;
                    foreach (var row in items)
                    {
                        // Get tax %
                        var taxDt = objBL.BL_ExecuteSqlQuery("SELECT * FROM tblMasterTax WHERE TaxID = " + row["TAX NAME *"].ToString());
                        taxValue = objBL.BL_dValidation(taxDt.Rows[0]["GST"].ToString());
                        // Prod Data
                        DataTable dtProductData = objBL.BL_ExecuteSqlQuery("SELECT * FROM tblMasterProduct WHERE ID = " + Convert.ToString(row["PRODUCT NAME *"]));
                        DataTable dtItemTransPrices = objBL.BL_ExecuteSqlQuery("select * from tblProductTransactionprices where ID = " + Convert.ToString(row["PRODUCT NAME *"]));
                        BaseUOMID = objBL.BL_nValidation(dtProductData.Rows[0]["BaseUomID"]);
                        TrackInvYN =  Convert.ToInt32(dtProductData.Rows[0]["TrackInventory"]);
                        TrackBatchYN = Convert.ToInt32(dtProductData.Rows[0]["TrackBatch"]);
                        TrackPKDYN = Convert.ToInt32(dtProductData.Rows[0]["TrackPDK"]);
                        TrackSerialYN = Convert.ToInt32(dtProductData.Rows[0]["TrackSerial"]);
                        uomcr = objBL.BL_dValidation(dtProductData.Rows[0]["BaseCR"]);
                        HSN = dtProductData.Rows[0]["HSNCode"].ToString();
                        BillTransAmount = dtItemTransPrices.Rows.Count > 0 ? objBL.BL_dValidation(dtItemTransPrices.Rows[0]["SalesReturnPrice"]) : 0;
                        // Values
                        qty = objBL.BL_dValidation(row["QTY *"].ToString());
                        freeqty = 0;// objBL.BL_dValidation(row["FREE QTY"].ToString());
                        dmgQty = 0;//objBL.BL_dValidation(row["DAMAGE QTY"].ToString());
                        //price = objBL.BL_dValidation(row["PRICE *"].ToString());

                        Saleprice = objBL.BL_dValidation(row["PRICE *"].ToString());
                        //ECPprice = objBL.BL_dValidation(row["UOM ECP PRICE"].ToString());
                        //SPLprice = objBL.BL_dValidation(row["UOM SPL PRICE"].ToString());
                        MRP = objBL.BL_dValidation(row["MRP *"].ToString());
                        //Returnprice = objBL.BL_dValidation(row["RETURN PRICE"].ToString());

                        prodDiscPern = objBL.BL_dValidation(row["PRODUCT DISCOUNT"].ToString());

                        // Calculations
                        goodsAmt = (qty + dmgQty) * Saleprice;

                        prodDiscAmt = goodsAmt * prodDiscPern / 100;
                        CumProdDiscAmt += prodDiscAmt;
                        baseAmt = goodsAmt - prodDiscAmt;

                        tradeDiscAmt = baseAmt * tradeDiscPern / 100;
                        addnlDiscAmt = baseAmt * addnlDiscPern / 100;
                        CumTradeDiscAmt += tradeDiscAmt;
                        CumAddnlDiscAmt += addnlDiscAmt;
                        grossAmt = baseAmt - (tradeDiscAmt + addnlDiscAmt);
                        taxAmt = grossAmt * taxValue / 100;

                        itemNetAmt = grossAmt + taxAmt;
                        CumNet += itemNetAmt;

                        var PerQty = grossAmt / qty;
                        BillDiffAmt = BillTransAmount - PerQty;
                        decimal caldiffamt = BillDiffAmt * (qty);
                        CumDiffGross += caldiffamt;
                        CumDiffNet += caldiffamt + ((caldiffamt * taxValue) / 100);                       
                        DataRow dtRow = dtProd.NewRow();                        
                        //klfjslfjsladfsladfjsla;dfjsadlkfjslad;fjsdal;f
                        dtRow["ProdId"] = objBL.BL_nValidation(Convert.ToString(row["PRODUCT NAME *"]));
                        dtRow["InventoryYesNo"] = TrackInvYN;
                        dtRow["BatchYesNo"] = TrackBatchYN;
                        dtRow["PKDYesNo"] = TrackPKDYN;
                        dtRow["SerialYesNo"] = TrackSerialYN;
                        dtRow["BaseUomPrice"] = Saleprice;
                        dtRow["UomId"] = BaseUOMID;
                        dtRow["UomQty"] = qty;
                        dtRow["UomPrice"] = Saleprice;
                        dtRow["GoodsAmt"] = goodsAmt;
                        dtRow["UserDisc"] = 0;
                        dtRow["UserDiscAmt"] = 0;
                        dtRow["ProdDisc"] = prodDiscPern;
                        dtRow["ProdDiscAmt"] = prodDiscAmt;
                        dtRow["TradeDisc"] = tradeDiscAmt;
                        dtRow["TradeDiscPern"] = tradeDiscPern;
                        dtRow["AddnlDisc"] = addnlDiscAmt;
                        dtRow["AddnlDiscPern"] = addnlDiscPern;
                        dtRow["GrossAmt"] = grossAmt;
                        dtRow["TaxId"] = TaxID;
                        dtRow["TaxPercentage"] = taxValue;
                        dtRow["TaxAmt"] = taxAmt;
                        dtRow["NetAmt"] = itemNetAmt;
                        dtRow["ReasonId"] = objBL.BL_nValidation(Convert.ToString(row["REASON NAME"]));
                        dtRow["Serial"] = nSerial;
                        dtRow["BatchNumber"] = row["BATCH NUMBER"].ToString();
                        string PKD = !string.IsNullOrEmpty(row["PKD DATE"].ToString()) ? Convert.ToDateTime(row["PKD DATE"].ToString()).ToString("dd/MM/yyyy") : null;
                        string Exp = !string.IsNullOrEmpty(row["EXPIRY DATE"].ToString()) ? Convert.ToDateTime(row["EXPIRY DATE"].ToString()).ToString("dd/MM/yyyy") : null;
                        dtRow["PkgDate"] = PKD;
                        dtRow["ExpiryDate"] = Exp;
                        dtRow["InventoryPrice"] = Saleprice;
                        dtRow["MRP"] = MRP;
                        dtRow["UomCR"] = uomcr;
                        dtRow["InvQtyType"] = 1;
                        dtRow["TempBatchInvId"] = 0;
                        dtRow["DiffAmt"] = BillDiffAmt;
                        dtProd.Rows.Add(dtRow);
                        nSerial++;
                    }
                    CumGross = dtProd.AsEnumerable().Sum(grs => grs.Field<decimal>("GrossAmt"));
                    CumTax = dtProd.AsEnumerable().Sum(grs => grs.Field<decimal>("TaxAmt"));
                    CumNet = dtProd.AsEnumerable().Sum(grs => grs.Field<decimal>("NetAmt"));

                    decimal RoundoffAmt = headerNetAmt - CumNet;
                    decimal TotDiscAmt = CumProdDiscAmt + CumTradeDiscAmt + CumAddnlDiscAmt;
                    string strStatus = TransType == 2 ? "6" : "7";
                    string strtranstype= TransType == 2 ? "1" : "2";
                    objBL.bl_Transaction(1);
                    DataTable dtResult = objBL.bl_ManageTrans("uspManageSalesReturn", strStatus, UID,16,0,
                                      headerRow["DOC DATE *"], headerRow["DOC DATE *"], objBL.BL_nValidation(headerRow["BEAT NAME"]), objBL.BL_nValidation(headerRow["SALESMAN NAME"]),
                                     headerRow["BRANCH NAME *"], headerRow["PARTY NAME *"], 4, TaxTypeID, 7, 0,
                                     0, headerRow["DOC ID *"], objBL.BL_dValidation(headerRow["FRIEGHT"]), objBL.BL_dValidation(otherChargePern), objBL.BL_dValidation(otherChargeAmt),
                                     objBL.BL_dValidation(RoundoffAmt), objBL.BL_dValidation(headerRow["WRITEOFF AMT"]), 0, objBL.BL_dValidation(tradeDiscPern), objBL.BL_dValidation(CumTradeDiscAmt),
                                     objBL.BL_dValidation(CumProdDiscAmt), objBL.BL_dValidation(addnlDiscPern), objBL.BL_dValidation(CumAddnlDiscAmt),
                                     objBL.BL_dValidation(CumGross), objBL.BL_dValidation(CumTax), TotDiscAmt,
                                     objBL.BL_dValidation(headerNetAmt), 0, dtProd, dtTempBachInfo, strtranstype, objBL.BL_nValidation(headerRow["RETURN TYPE"]),
                                     null, 0, 0, 0, 0,
                                     headerRow["REMARKS"], "Import Data", 0, CumDiffGross, CumDiffNet);
                    if (dtResult.Columns.Count > 1)
                    {
                        objBL.bl_Transaction(3);
                        string msg = "", RowID = "-1";
                        string[] strErrorList = dtResult.Rows[0][0].ToString().Split('$');
                        if ("DocumentStatus" == strErrorList[0].Trim())
                        {
                            msg = "Adjusted document status changed";
                        }
                        else if ("DocumentAmount" == strErrorList[0].Trim())
                        {
                            msg = "Adjusted document amount changed";
                        }
                        else if ("BankAcc" == strErrorList[0].Trim())
                        {
                            msg = "Account de-active in multipayment mode popup";
                        }
                        else if ("6" == strErrorList[0].Trim())
                        {
                            msg = "Product classification changed";
                            RowID = dtResult.Columns.Count == 4 ? dtResult.Rows[0][3].ToString() : "0";
                        }
                        DataRow drresp = dtSaveResponse.NewRow();
                        drresp["DocPrefix"] = strDocPrefix;
                        drresp["DocID"] = strDocID;
                        drresp["DocDate"] = strDocDate;
                        drresp["Error"] = msg;
                        dtSaveResponse.Rows.Add(drresp);
                        break;
                    }
                    else
                    {
                        //bl.bl_Transaction(2);
                        int nBillScopeID = objBL.BL_nValidation(dtResult.Rows[0][0]);
                        if (dtProd.Rows.Count > 0)
                        {
                            int nProdID = 0, nTaxID = 0, nTaxTypeID = 0, SRSerial = 1, nTranSerial = 1;
                            decimal dQtnGrossAmount = 0.00M, dQtys = 0.00M;
                            dtGSTInfo.Rows.Clear();
                            for (int nCount = 0; nCount < dtProd.Rows.Count; nCount++)
                            {
                                //if (objBL.BL_dValidation(dtProd.Rows[nCount]["Qty"]) > 0)
                                //{
                                nProdID = objBL.BL_nValidation(dtProd.Rows[nCount]["ProdId"]);
                                nTaxID = objBL.BL_nValidation(dtProd.Rows[nCount]["TaxID"]);
                                nTaxTypeID = TaxTypeID;
                                DataTable dtMTdetail = objBL.bl_ManageTrans("uspGetTaxCumulative", nTaxID, nTaxTypeID, 1);
                                decimal dApponMRPCum = dtMTdetail.Select("AppOn = -1").Select(r => Convert.ToDecimal(r["CumulativeTax"])).DefaultIfEmpty(0).Sum();
                                decimal dMRP = objBL.BL_dValidation(dtProd.Rows[nCount]["MRP"]);
                                dQtnGrossAmount = objBL.BL_dValidation(dtProd.Rows[nCount]["GrossAmt"]);

                                //DataTable getConvFact = objBL.BL_ExecuteSqlQuery("select dbo.fnGetConvertionFact(" + objBL.BL_nValidation(dtProd.Rows[nCount]["UomGrpID"]) + "," + objBL.BL_nValidation(dtProd.Rows[nCount]["UomId"]) + ")");

                                dQtys = (objBL.BL_dValidation(dtProd.Rows[nCount]["UomQty"])) * 1;// objBL.BL_dValidation(dtResult.Rows[0][0]);
                                decimal newgrossamt = dApponMRPCum == 0 ? dQtnGrossAmount : objBL.ReturnGrossorMRPTaxAmt(1, nTaxID, nTaxTypeID, dQtnGrossAmount,
                                               dMRP * dQtys);
                                DataTable dtTaxCompInfo = objBL.bl_ManageTrans("uspGetTaxCompInfo", nTaxID, nTaxTypeID);
                                if (dtTaxCompInfo.Rows.Count > 0)
                                {
                                    bool ValidtoCalc = false;

                                    for (int nTaxComp = 0; nTaxComp < dtTaxCompInfo.Rows.Count; nTaxComp++)
                                    {
                                        ValidtoCalc = true;//nTaxTypeID == 2 && objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 1 ||
                                                           //nTaxTypeID == 1 && objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 2 ? false : true;
                                        DataRow dr = dtGSTInfo.NewRow();
                                        dr["TransID"] = 16;
                                        dr["TransIdentID"] = nBillScopeID;
                                        dr["ProdID"] = nProdID;
                                        dr["TaxID"] = nTaxID;
                                        dr["GSTTaxTypeID"] = objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]);
                                        dr["TaxTypeID"] = nTaxTypeID;
                                        dr["TaxCompID"] = objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][0]);
                                        dr["TaxCompPern"] = objBL.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2]);
                                        dr["TaxCompAmount"] = ValidtoCalc ? ((newgrossamt * objBL.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2])) / 100) :
                                                objBL.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2]) * dQtys;//dQtnGrossAmount
                                        dr["GrossAmount"] = newgrossamt;//dQtnGrossAmount
                                        //dr["TransSerial"] = nTranSerial;
                                        dr["TransSerial"] = (nCount + 1);
                                        dr["SerialNo"] = SRSerial;
                                        dtGSTInfo.Rows.Add(dr);
                                        SRSerial++;
                                    }
                                    nTranSerial++;
                                }
                                //}
                            }
                            if (dtGSTInfo.Rows.Count > 0)
                            {
                                objBL.bl_ManageTrans("uspSaveTranGSTInfo", dtGSTInfo);
                            }
                        }
                        DataRow drresp = dtSaveResponse.NewRow();
                        drresp["DocPrefix"] = strDocPrefix;
                        drresp["DocID"] = strDocID;
                        drresp["DocDate"] = strDocDate;
                        drresp["Error"] = "Completed";
                        dtSaveResponse.Rows.Add(drresp);
                        objBL.bl_Transaction(2);
                        objBL.BL_UpdateclosingDateforPosting(16, nBillScopeID, Convert.ToDateTime(headerRow["DOC DATE *"]));
                    }
                }
            }
            catch (Exception ex)
            {
            }
            finally
            {

            }
            return dtSaveResponse;
        }
        public DataTable SaveSales(DataTable dtHeader, DataTable dtItems, string UID)
        {
            DataTable dtSaveResponse = new DataTable();
            dtSaveResponse.Columns.Add("DocPrefix", typeof(string));
            dtSaveResponse.Columns.Add("DocID", typeof(string));
            dtSaveResponse.Columns.Add("DocDate", typeof(string));
            dtSaveResponse.Columns.Add("Error", typeof(string));
            string strDocID = "", strDocPrefix = "Sales", strDocDate = "";
            try
            {
                #region Datatable Declaration
                DataTable dtProd = new DataTable(),
                    dtDocument = new DataTable(), dtGSTInfo = new DataTable(), dtSerialInfo = new DataTable();
                //
                dtProd.Columns.Add("ProdId", typeof(int));
                dtProd.Columns.Add("InventoryYesNo", typeof(int));
                dtProd.Columns.Add("BatchYesNo", typeof(int));
                dtProd.Columns.Add("PKDYesNo", typeof(int));
                dtProd.Columns.Add("SerialYesNo", typeof(int));
                dtProd.Columns.Add("BaseUomPrice", typeof(decimal));
                dtProd.Columns.Add("UomId", typeof(int));
                dtProd.Columns.Add("UomQty", typeof(decimal));
                dtProd.Columns.Add("UomPrice", typeof(decimal));
                dtProd.Columns.Add("GoodsAmt", typeof(decimal));
                dtProd.Columns.Add("UserDisc", typeof(decimal));
                dtProd.Columns.Add("UserDiscAmt", typeof(decimal));
                dtProd.Columns.Add("ProdDisc", typeof(decimal));
                dtProd.Columns.Add("ProdDiscAmt", typeof(decimal));
                dtProd.Columns.Add("TradeDisc", typeof(decimal));
                dtProd.Columns.Add("TradeDiscPern", typeof(decimal));
                dtProd.Columns.Add("AddnlDisc", typeof(decimal));
                dtProd.Columns.Add("AddnlDiscPern", typeof(decimal));
                dtProd.Columns.Add("GrossAmt", typeof(decimal));
                dtProd.Columns.Add("TaxId", typeof(int));
                dtProd.Columns.Add("TaxPercentage", typeof(decimal));
                dtProd.Columns.Add("TaxAmt", typeof(decimal));
                dtProd.Columns.Add("NetAmt", typeof(decimal));
                dtProd.Columns.Add("ReasonId", typeof(int));
                dtProd.Columns.Add("Serial", typeof(int));
                dtProd.Columns.Add("BatchNumber", typeof(string));
                dtProd.Columns.Add("PkgDate", typeof(string));
                dtProd.Columns.Add("ExpiryDate", typeof(string));
                dtProd.Columns.Add("InventoryPrice", typeof(decimal));
                dtProd.Columns.Add("MRP", typeof(decimal));
                dtProd.Columns.Add("InvQtyType", typeof(int));
                dtProd.Columns.Add("TempBatchInvId", typeof(int));
                dtProd.Columns.Add("UomCR", typeof(decimal));
                dtProd.Columns.Add("DiffAmt", typeof(decimal));
                //
                dtGSTInfo.Columns.Add("TransID", typeof(int));
                dtGSTInfo.Columns.Add("TransIdentID", typeof(int));
                dtGSTInfo.Columns.Add("ProdID", typeof(int));
                dtGSTInfo.Columns.Add("TaxID", typeof(int));
                dtGSTInfo.Columns.Add("GSTTaxTypeID", typeof(int));
                dtGSTInfo.Columns.Add("TaxTypeID", typeof(int));
                dtGSTInfo.Columns.Add("TaxCompID", typeof(int));
                dtGSTInfo.Columns.Add("TaxCompPern", typeof(decimal));
                dtGSTInfo.Columns.Add("TaxCompAmount", typeof(decimal));
                dtGSTInfo.Columns.Add("GrossAmount", typeof(decimal));
                dtGSTInfo.Columns.Add("TransSerial", typeof(int));
                dtGSTInfo.Columns.Add("SerialNo", typeof(int));
                //
                dtDocument.Columns.Add("TransName");
                dtDocument.Columns.Add("Status", typeof(int)).DefaultValue = 0;
                dtDocument.Columns.Add("DocumentId", typeof(int)).DefaultValue = 0;
                //Serial Table
                dtSerialInfo.Columns.Add("Index", typeof(int));
                dtSerialInfo.Columns.Add("ProdId", typeof(int));
                dtSerialInfo.Columns.Add("Serial", typeof(string));
                #endregion
                for (int i = 0; i < dtHeader.Rows.Count; i++)
                {
                    var headerRow = dtHeader.Rows[i];
                    strDocID = headerRow["DOC ID *"].ToString();                    
                    strDocDate = headerRow["DOC Date *"].ToString();
                    //int TransType = objBL.BL_nValidation(headerRow["TRANSACTION TYPE"].ToString());
                    decimal tradeDiscPern = objBL.BL_dValidation(headerRow["TRADE DISCOUNT %"].ToString());
                    decimal addnlDiscPern = objBL.BL_dValidation(headerRow["ADDITIONAL DISCOUNT %"].ToString());
                    decimal otherChargePern = objBL.BL_dValidation(headerRow["OTHER CHARGE %"].ToString());
                    decimal headerNetAmt = objBL.BL_dValidation(headerRow["NET AMOUNT *"].ToString());
                    decimal otherChargeAmt = (headerNetAmt * otherChargePern) / 100;
                    DataTable dtPartyData = objBL.BL_ExecuteSqlQuery("SELECT * FROM tblMasterCustomer WHERE ID = " + Convert.ToString(headerRow["PARTY NAME *"]));
                    int TaxTypeID = objBL.BL_nValidation(dtPartyData.Rows[0]["TaxTypeID"].ToString());

                    // Filter items
                    var items = dtItems.AsEnumerable()
                        .Where(r => r["DOC ID *"].ToString() == strDocID)
                        .ToList();
                    int nSerial = 1;
                    foreach (var row in items)
                    {
                        // Get tax %
                        var taxDt = objBL.BL_ExecuteSqlQuery("SELECT * FROM tblMasterTax WHERE TaxID = " + row["TAX NAME *"].ToString());
                        taxValue = objBL.BL_dValidation(taxDt.Rows[0]["GST"].ToString());
                        // Prod Data
                        DataTable dtProductData = objBL.BL_ExecuteSqlQuery("SELECT * FROM tblMasterProduct WHERE ID = " + Convert.ToString(row["PRODUCT NAME *"]));
                        DataTable dtItemTransPrices = objBL.BL_ExecuteSqlQuery("select * from tblProductTransactionprices where ID = " + Convert.ToString(row["PRODUCT NAME *"]));
                        BaseUOMID = objBL.BL_nValidation(dtProductData.Rows[0]["BaseUomID"]);
                        TrackInvYN = Convert.ToInt32(dtProductData.Rows[0]["TrackInventory"]);
                        TrackBatchYN = Convert.ToInt32(dtProductData.Rows[0]["TrackBatch"]);
                        TrackPKDYN = Convert.ToInt32(dtProductData.Rows[0]["TrackPDK"]);
                        TrackSerialYN = Convert.ToInt32(dtProductData.Rows[0]["TrackSerial"]);
                        uomcr = objBL.BL_dValidation(dtProductData.Rows[0]["BaseCR"]);
                        HSN = dtProductData.Rows[0]["HSNCode"].ToString();
                        BillTransAmount = dtItemTransPrices.Rows.Count > 0 ? objBL.BL_dValidation(dtItemTransPrices.Rows[0]["InvoicePrice"]) : 0;
                        // Values
                        qty = objBL.BL_dValidation(row["QTY *"].ToString());                        
                        //price = objBL.BL_dValidation(row["UOM PURCHASE PRICE"].ToString());

                        Saleprice = objBL.BL_dValidation(row["PRICE *"].ToString());
                        //ECPprice = objBL.BL_dValidation(row["UOM ECP PRICE"].ToString());
                        //SPLprice = objBL.BL_dValidation(row["UOM SPL PRICE"].ToString());
                        MRP = objBL.BL_dValidation(row["MRP *"].ToString());
                        decimal MRPExcl = MRP / (1 + (taxValue / 100));                        

                        prodDiscPern = objBL.BL_dValidation(row["PRODUCT DISCOUNT"].ToString());

                        // Calculations
                        goodsAmt = (qty + dmgQty) * Saleprice;

                        prodDiscAmt = goodsAmt * prodDiscPern / 100;
                        CumProdDiscAmt += prodDiscAmt;
                        baseAmt = goodsAmt - prodDiscAmt;

                        tradeDiscAmt = baseAmt * tradeDiscPern / 100;
                        addnlDiscAmt = baseAmt * addnlDiscPern / 100;
                        CumTradeDiscAmt += tradeDiscAmt;
                        CumAddnlDiscAmt += addnlDiscAmt;
                        grossAmt = baseAmt - (tradeDiscAmt + addnlDiscAmt);
                        taxAmt = grossAmt * taxValue / 100;

                        itemNetAmt = grossAmt + taxAmt;
                        CumNet += itemNetAmt;
                        var PerQty = grossAmt / qty;
                        BillDiffAmt = PerQty - BillTransAmount;
                        decimal caldiffamt = BillDiffAmt * (qty);
                        CumDiffGross += caldiffamt;
                        CumDiffNet += caldiffamt + ((caldiffamt * taxValue) / 100);
                        
                        DataRow dtRow = dtProd.NewRow();
                        //klfjslfjsladfsladfjsla;dfjsadlkfjslad;fjsdal;f
                        dtRow["ProdId"] = objBL.BL_nValidation(Convert.ToString(row["PRODUCT NAME *"]));
                        dtRow["InventoryYesNo"] = TrackInvYN;
                        dtRow["BatchYesNo"] = TrackBatchYN;
                        dtRow["PKDYesNo"] = TrackPKDYN;
                        dtRow["SerialYesNo"] = TrackSerialYN;
                        dtRow["BaseUomPrice"] = Saleprice;
                        dtRow["UomId"] = BaseUOMID;
                        dtRow["UomQty"] = qty;
                        dtRow["UomPrice"] = Saleprice;
                        dtRow["GoodsAmt"] = goodsAmt;
                        dtRow["UserDisc"] = 0;
                        dtRow["UserDiscAmt"] = 0;
                        dtRow["ProdDisc"] = prodDiscPern;
                        dtRow["ProdDiscAmt"] = prodDiscAmt;
                        dtRow["TradeDisc"] = tradeDiscAmt;
                        dtRow["TradeDiscPern"] = tradeDiscPern;
                        dtRow["AddnlDisc"] = addnlDiscAmt;
                        dtRow["AddnlDiscPern"] = addnlDiscPern;
                        dtRow["GrossAmt"] = grossAmt;
                        dtRow["TaxId"] = TaxID;
                        dtRow["TaxPercentage"] = taxValue;
                        dtRow["TaxAmt"] = taxAmt;
                        dtRow["NetAmt"] = itemNetAmt;
                        dtRow["ReasonId"] = objBL.BL_nValidation(Convert.ToString(row["REASON NAME"]));
                        dtRow["Serial"] = nSerial;
                        dtRow["BatchNumber"] = row["BATCH NUMBER"].ToString();
                        string PKD = !string.IsNullOrEmpty(row["PKD DATE"].ToString()) ? Convert.ToDateTime(row["PKD DATE"].ToString()).ToString("dd/MM/yyyy") : null;
                        string Exp = !string.IsNullOrEmpty(row["EXPIRY DATE"].ToString()) ? Convert.ToDateTime(row["EXPIRY DATE"].ToString()).ToString("dd/MM/yyyy") : null;
                        dtRow["PkgDate"] = PKD;
                        dtRow["ExpiryDate"] = Exp;
                        dtRow["InventoryPrice"] = MRPExcl;// Saleprice;
                        dtRow["MRP"] = MRP;
                        dtRow["UomCR"] = uomcr;
                        dtRow["InvQtyType"] = 1;
                        dtRow["TempBatchInvId"] = 0;
                        dtRow["DiffAmt"] = BillDiffAmt;
                        dtProd.Rows.Add(dtRow);
                        nSerial++;
                    }
                    CumGross = dtProd.AsEnumerable().Sum(grs => grs.Field<decimal>("GrossAmt"));
                    CumTax = dtProd.AsEnumerable().Sum(grs => grs.Field<decimal>("TaxAmt"));
                    CumNet = dtProd.AsEnumerable().Sum(grs => grs.Field<decimal>("NetAmt"));

                    decimal RoundoffAmt = headerNetAmt - CumNet;
                    decimal TotDiscAmt = CumProdDiscAmt + CumTradeDiscAmt + CumAddnlDiscAmt;                                       
                    objBL.bl_Transaction(1);

                    DataTable dtResult = objBL.bl_ManageTrans("uspManageSalesHeader", 1, UID,
                         15, 0, headerRow["DOC DATE *"], headerRow["DOC DATE *"], objBL.BL_nValidation(headerRow["BEAT NAME"]), objBL.BL_nValidation(headerRow["SALESMAN NAME"]),
                                     headerRow["BRANCH NAME *"], headerRow["PARTY NAME *"], 4, TaxTypeID, 7, objBL.BL_nValidation(headerRow["CREDIT TERM *"]),
                         0, headerRow["DOC ID *"], objBL.BL_dValidation(headerRow["FRIEGHT"]), objBL.BL_dValidation(otherChargePern), objBL.BL_dValidation(otherChargeAmt),
                                     objBL.BL_dValidation(RoundoffAmt), objBL.BL_dValidation(headerRow["WRITEOFF AMT"]), 0, objBL.BL_dValidation(tradeDiscPern), objBL.BL_dValidation(CumTradeDiscAmt),
                                     objBL.BL_dValidation(CumProdDiscAmt), objBL.BL_dValidation(addnlDiscPern), objBL.BL_dValidation(CumAddnlDiscAmt),
                                     objBL.BL_dValidation(CumGross), objBL.BL_dValidation(CumTax), TotDiscAmt,
                                     objBL.BL_dValidation(headerNetAmt), 0, dtDocument, dtProd, dtSerialInfo, 1, 1, null, 0, 0, 0, 0,
                         headerRow["REMARKS"], "Import Data", 0, 1, objBL.BL_nValidation(headerRow["VECHICLE NUMBER"]), objBL.BL_nValidation(headerRow["DISTANCE"]),
                         headerRow["TRANSPORT TYPE"], headerRow["TRANSPORT MODE"], headerRow["TRANSPORT ID"], headerRow["TRANSPORT NAME"],
                         CumDiffGross, CumDiffNet);
                    
                    if (dtResult.Columns.Count > 1)
                    {
                        objBL.bl_Transaction(3);
                        string msg = "", RowID = "-1";
                        string[] strErrorList = dtResult.Rows[0][0].ToString().Split('$');
                        if ("DocumentStatus" == strErrorList[0].Trim())
                        {
                            msg = "Adjusted document status changed";
                        }
                        else if ("DocumentAmount" == strErrorList[0].Trim())
                        {
                            msg = "Adjusted document amount changed";
                        }
                        else if ("BankAcc" == strErrorList[0].Trim())
                        {
                            msg = "Account de-active in multipayment mode popup";
                        }
                        else if ("6" == strErrorList[0].Trim())
                        {
                            msg = "Product classification changed";
                            RowID = dtResult.Columns.Count == 4 ? dtResult.Rows[0][3].ToString() : "0";
                        }
                        else if ("13" == strErrorList[0].Trim())
                        {
                            msg = "Qty Mismatched";
                            RowID = dtResult.Rows[0][3].ToString();
                        }
                        else
                        {
                            msg = dtResult.Rows[0][0].ToString();
                        }
                        DataRow drresp = dtSaveResponse.NewRow();
                        drresp["DocPrefix"] = strDocPrefix;
                        drresp["DocID"] = strDocID;
                        drresp["DocDate"] = strDocDate;
                        drresp["Error"] = msg;
                        dtSaveResponse.Rows.Add(drresp);
                        break;
                    }
                    else
                    {
                        //bl.bl_Transaction(2);
                        int nBillScopeID = objBL.BL_nValidation(dtResult.Rows[0][0]);
                        if (dtProd.Rows.Count > 0)
                        {
                            int nProdID = 0, nTaxID = 0, nTaxTypeID = 0, SRSerial = 1, nTranSerial = 1;
                            decimal dQtnGrossAmount = 0.00M, dQtys = 0.00M;
                            dtGSTInfo.Rows.Clear();
                            for (int nCount = 0; nCount < dtProd.Rows.Count; nCount++)
                            {
                                //if (objBL.BL_dValidation(dtProd.Rows[nCount]["Qty"]) > 0)
                                //{
                                nProdID = objBL.BL_nValidation(dtProd.Rows[nCount]["ProdId"]);
                                nTaxID = objBL.BL_nValidation(dtProd.Rows[nCount]["TaxID"]);
                                nTaxTypeID = TaxTypeID;
                                DataTable dtMTdetail = objBL.bl_ManageTrans("uspGetTaxCumulative", nTaxID, nTaxTypeID, 1);
                                decimal dApponMRPCum = dtMTdetail.Select("AppOn = -1").Select(r => Convert.ToDecimal(r["CumulativeTax"])).DefaultIfEmpty(0).Sum();
                                decimal dMRP = objBL.BL_dValidation(dtProd.Rows[nCount]["MRP"]);
                                dQtnGrossAmount = objBL.BL_dValidation(dtProd.Rows[nCount]["GrossAmt"]);

                                //DataTable getConvFact = objBL.BL_ExecuteSqlQuery("select dbo.fnGetConvertionFact(" + objBL.BL_nValidation(dtProd.Rows[nCount]["UomGrpID"]) + "," + objBL.BL_nValidation(dtProd.Rows[nCount]["UomId"]) + ")");

                                dQtys = (objBL.BL_dValidation(dtProd.Rows[nCount]["UomQty"])) * 1;// objBL.BL_dValidation(dtResult.Rows[0][0]);
                                decimal newgrossamt = dApponMRPCum == 0 ? dQtnGrossAmount : objBL.ReturnGrossorMRPTaxAmt(1, nTaxID, nTaxTypeID, dQtnGrossAmount,
                                               dMRP * dQtys);
                                DataTable dtTaxCompInfo = objBL.bl_ManageTrans("uspGetTaxCompInfo", nTaxID, nTaxTypeID);
                                if (dtTaxCompInfo.Rows.Count > 0)
                                {
                                    bool ValidtoCalc = false;

                                    for (int nTaxComp = 0; nTaxComp < dtTaxCompInfo.Rows.Count; nTaxComp++)
                                    {
                                        ValidtoCalc = true;//nTaxTypeID == 2 && objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 1 ||
                                                           //nTaxTypeID == 1 && objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 2 ? false : true;
                                        DataRow dr = dtGSTInfo.NewRow();
                                        dr["TransID"] = 15;
                                        dr["TransIdentID"] = nBillScopeID;
                                        dr["ProdID"] = nProdID;
                                        dr["TaxID"] = nTaxID;
                                        dr["GSTTaxTypeID"] = objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]);
                                        dr["TaxTypeID"] = nTaxTypeID;
                                        dr["TaxCompID"] = objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][0]);
                                        dr["TaxCompPern"] = objBL.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2]);
                                        dr["TaxCompAmount"] = ValidtoCalc ? ((newgrossamt * objBL.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2])) / 100) :
                                                objBL.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2]) * dQtys;//dQtnGrossAmount
                                        dr["GrossAmount"] = newgrossamt;//dQtnGrossAmount
                                        //dr["TransSerial"] = nTranSerial;
                                        dr["TransSerial"] = (nCount + 1);
                                        dr["SerialNo"] = SRSerial;
                                        dtGSTInfo.Rows.Add(dr);
                                        SRSerial++;
                                    }
                                    nTranSerial++;
                                }
                                //}
                            }
                            if (dtGSTInfo.Rows.Count > 0)
                            {
                                objBL.bl_ManageTrans("uspSaveTranGSTInfo", dtGSTInfo);
                            }
                        }
                        DataRow drresp = dtSaveResponse.NewRow();
                        drresp["DocPrefix"] = strDocPrefix;
                        drresp["DocID"] = strDocID;
                        drresp["DocDate"] = strDocDate;
                        drresp["Error"] = "Completed";
                        dtSaveResponse.Rows.Add(drresp);
                        objBL.bl_Transaction(2);
                        objBL.BL_UpdateclosingDateforPosting(16, nBillScopeID, Convert.ToDateTime(headerRow["DOC DATE *"]));
                    }
                }
            }
            catch (Exception ex)
            {
            }
            finally
            {

            }
            return dtSaveResponse;
        }
    }
}