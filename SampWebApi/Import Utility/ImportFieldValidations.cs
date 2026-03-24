using DocumentFormat.OpenXml.Wordprocessing;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
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
        public int StatusID { get; set; }
        public int CreditTermID { get; set; }
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
        public string SaleSRBillPRHeaderValidation(DataTable dtCheck)
        {
            string RowError = "";
            #region Mandatory Field Validation
            
            ValidateAlphaNumericSplField(dtCheck.Rows[0], "DOC ID *", true, ref RowError);
            
            string strDocPrefix = dtCheck.Rows[0]["DOC PREFIX *"].ToString().ToLower();
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
                    DataTable dt = new DataTable();
                    if (strDocPrefix == "sale" || strDocPrefix == "sr")
                    {
                        dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 8, 3, dtCheck.Rows[0]["PARTY NAME *"].ToString());
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
                    else if (strDocPrefix == "bill" || strDocPrefix == "pr")
                    {
                        dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 4, 3, dtCheck.Rows[0]["PARTY NAME *"].ToString());
                        if (dt.Rows.Count == 0)
                        {
                            RowError += "* PARTY NAME(" + dtCheck.Rows[0]["BRANCH NAME *"].ToString() + ") not found in Database\n";
                            VendorID = 0;
                            TaxTypeID = 0;
                        }
                        else
                        {
                            VendorID = Convert.ToInt32(dt.Rows[0][0].ToString());                            
                            TaxTypeID = Convert.ToInt32(dt.Rows[0]["TaxTypeID"].ToString());
                        }
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
            if(strDocPrefix == "Sale" || strDocPrefix == "pr")
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

            string[] fields = {"REMARKS","TRANSPORT ID","TRANSPORT NAME","IRN","ACKNOWLEDGE NO"};

            DataRow row = dtCheck.Rows[0];

            foreach (var field in fields)
            {
                ValidateAlphaNumericSplField(row, field, false, ref RowError);
            }

            #endregion
            return RowError;
        }
        public string SaleSRBillPRDetailValidation(DataTable dtCheck)
        {
            string RowError = "";
            DataRow row = dtCheck.Rows[0];
            #region Mandatory Field Validation
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
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 5, 3, dtCheck.Rows[0]["PRODUCT NAME *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* PRODUCT NAME(" + dtCheck.Rows[0]["PRODUCT NAME *"].ToString() + ") not found in Database\n";
                        ProductID = 0;
                    }
                    else
                    {
                        ProductID = Convert.ToInt32(dt.Rows[0][0].ToString());
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
            #endregion
            #region Non-Mandatory Field Validations
            ValidateAlphaNumericSplField(row, "BATCH NUMBER", false, ref RowError);
            
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PKD DATE"].ToString()))
            {
                if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["PKD DATE"].ToString()))
                {
                    RowError += "PKD DATE : Invalid Date Format(Format : dd/MM/yyyy)\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
            {
                if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["EXPIRY DATE"].ToString()))
                {
                    RowError += "EXPIRY DATE : Invalid Date Format(Format : dd/MM/yyyy)\n";
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
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 5, 3, dtCheck.Rows[0]["REASON NAME"].ToString());
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
        public string SaleSRBillPRNetAmtValidation(DataTable dtHeaderrow, DataTable dtItemsData)
        {
            try
            {
                string RowError = "";
                var header = dtHeaderrow.Rows[0];
                string strDocID = header["DOC ID *"].ToString();
                string strDocPrefix = header["DOC PREFIX *"].ToString().ToLower();
                // Filter items
                var items = dtItemsData.AsEnumerable()
                    .Where(r => r["DOC ID *"].ToString() == strDocID)
                    .ToList();

                if (!items.Any())
                    return $"No Item Details found for this Doc ID - {strDocID}";

                // Header values
                decimal tradeDiscPern = objBL.BL_dValidation(header["TRADE DISCOUNT"].ToString());
                decimal addnlDiscPern = objBL.BL_dValidation(header["ADDITIONAL DISCOUNT"].ToString());
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
                         price = objBL.BL_dValidation(row["UOM PURCHASE PRICE"].ToString());
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
                        return $"Net Amount Mismatch between Header ({Math.Round(headerNetAmt,2)}) and Detail ({Math.Round(itemNetAmt,2)})";
                    }
                }
                return RowError;
            }
            catch (Exception ex)
            {
                throw ex;
            }
        }
        void ValidateNumericField(DataRow row, string columnName,bool IsMandatory, ref string rowError)
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

        public DataTable SavePurchaseBill(DataTable dtHeader,DataTable dtItems, string UID)
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
                string strDocID = headerRow["DOC ID *"].ToString();
                string strDocPrefix = headerRow["DOC PREFIX *"].ToString().ToLower();
                decimal tradeDiscPern = objBL.BL_dValidation(headerRow["TRADE DISCOUNT"].ToString());
                decimal addnlDiscPern = objBL.BL_dValidation(headerRow["ADDITIONAL DISCOUNT"].ToString());
                decimal otherChargePern = objBL.BL_dValidation(headerRow["OTHER CHARGE"].ToString());
                decimal headerNetAmt = objBL.BL_dValidation(headerRow["NET AMOUNT *"].ToString());
                decimal otherChargeAmt = (headerNetAmt * otherChargePern) / 100;
                DataTable dtPartyData= objBL.BL_ExecuteSqlQuery("SELECT * FROM tblMasterVendor WHERE ID = " + Convert.ToString(headerRow["PARTY NAME *"]));
                int TaxTypeID = objBL.BL_nValidation(dtPartyData.Rows[0]["TaxTypeID"].ToString());
                decimal taxValue = 0,uomcr = 0, qty = 0, freeqty=0, dmgQty = 0, prodDiscPern = 0;
                decimal price = 0, Saleprice = 0, ECPprice = 0, SPLprice = 0, MRP = 0, Returnprice = 0;
                decimal goodsAmt = 0, prodDiscAmt = 0, baseAmt = 0,BillTransAmount = 0,BillDiffAmt = 0, dUomTax = 0;
                decimal CumGross = 0, CumGoods = 0, CumTax = 0, CumNet = 0, CumProdDiscAmt = 0, CumTradeDiscAmt = 0,
                    CumAddnlDiscAmt = 0, CumDiffGross = 0, CumDiffNet = 0;
                decimal tradeDiscAmt = 0, addnlDiscAmt = 0, grossAmt = 0, taxAmt = 0, itemNetAmt = 0;
                int BaseUOMID = 0, TrackInvYN = 0, TrackBatchYN = 0, TrackPKDYN = 0;
                string HSN = "";
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
                    uomcr= objBL.BL_dValidation(dtProductData.Rows[0]["BaseCR"]);
                    HSN = dtProductData.Rows[0]["HSNCode"].ToString();
                    BillTransAmount = dtItemTransPrices.Rows.Count > 0 ? objBL.BL_dValidation(dtItemTransPrices.Rows[0]["PurchaseBillPrice"]) : 0;
                    // Values
                    qty = objBL.BL_dValidation(row["ACTUAL QTY"].ToString());
                    freeqty = objBL.BL_dValidation(row["FREE QTY"].ToString());
                    dmgQty = objBL.BL_dValidation(row["DAMAGE QTY"].ToString());
                    price = objBL.BL_dValidation(row["UOM PURCHASE PRICE"].ToString());

                    Saleprice = objBL.BL_dValidation(row["UOM SALE PRICE"].ToString());
                    ECPprice = objBL.BL_dValidation(row["UOM ECP PRICE"].ToString());
                    SPLprice = objBL.BL_dValidation(row["UOM SPL PRICE"].ToString());
                    MRP = objBL.BL_dValidation(row["UOM MRP PRICE"].ToString());
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
                    BillDiffAmt = price - BillTransAmount;
                    CumDiffGross += BillDiffAmt;
                    CumDiffNet += ((BillDiffAmt * taxValue) / 100);
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
                                objBL.BL_dValidation(CumNet), headerRow["DOC ID *"], 0,
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
                    objBL.bl_Transaction(3);
                    return dtResult;
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
                            dQtnGrossAmount = objBL.BL_dValidation(dtProd.Rows[nCount]["GrossAmt"]);
                            dQtys = (objBL.BL_dValidation(dtProd.Rows[nCount]["Qty"]) + objBL.BL_dValidation(dtProd.Rows[nCount]["DamageQty"])) * 1;// objBL.BL_dValidation(dtResult.Rows[0][0]);

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
                                    dr["TaxCompAmount"] = ValidtoCalc ? ((dQtnGrossAmount * objBL.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2])) / 100) :
                                            objBL.BL_dValidation(dtTaxCompInfo.Rows[nTaxComp][2]) * dQtys;
                                    dr["GrossAmount"] = dQtnGrossAmount;
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

                    objBL.bl_Transaction(2);
                    objBL.BL_UpdateclosingDateforPosting(1, nBillScopeID, Convert.ToDateTime(headerRow["DOC DATE *"]));                    
                }
            }
          
            return dtResult;
        }
    }
}