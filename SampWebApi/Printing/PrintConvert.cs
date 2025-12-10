using SampWebApi.BuisnessLayer;
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing.Printing;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Web;
using System.Windows.Forms;

namespace SampWebApi.Printing
{
    public class PrintConvert
    {
        #region public Properties
        public clsBusinessLayer GKS_BL { get; set; }
        public string strHeaderSP { get; set; }
        public string strBodySP { get; set; }
        public string strFooterSP { get; set; }
        public int nTransId { get; set; }
        //public IStatusMessage objmdi { get; set; }
        public Form PrintForm = new Form();
        public PaperSize paperSize { get; set; }
        public int nConfigId { get; set; }
        public DataTable dtGetConfigPage { get; set; }
        public int nTransType { get; set; }
        public int nSalesSerialWisePrint { get; set; }
        #endregion

        #region Private Properties
        private DataTable dtGetHeaderVal = new DataTable(), dtGetSpecialVal = new DataTable(), dtGetBodyVal = new DataTable();
        private float YPositionDiff = 0, bodyFontHeight = 0;
        int totalnumber = 0, itemperpage = 0, nFormHeight = 0, nSRPrintIndex = 0;
        public decimal dfinalPrintingFormHeight = 0.00M;
        #endregion

        public void LoadForm()
        {
            PrintForm.Width = paperSize.Width;// +5;
            GetRecordFromDB();//Load Record From DB
            SetHeaderLabel(); // Draw  Head Label
            SetHeaderValue(); // Draw Head value
            SetBody();
            //PrintForm.Show();
            //Set Form Height Dynamically
            int ncheck = nFormHeight + 140;
            if (ncheck <= 1000)
            {
                dfinalPrintingFormHeight = nFormHeight + 50;
            }
            else
            {
                dfinalPrintingFormHeight = nFormHeight + 140;
            }
            PrintForm.Height = ncheck;
        }

        //Load Record From DB for specified Transaction
        private void GetRecordFromDB()
        {

            try
            {
                dtGetHeaderVal = GKS_BL.BL_ExecuteParamSP(strHeaderSP, nTransId);
                dtGetSpecialVal = GKS_BL.BL_ExecuteParamSP(strFooterSP);
                //Sales Transaction pass Two Parameters based on Serial wies print or Without serial
                if (nTransType == 4)
                {
                    //one mention for one column add additional for Product Serial
                    using (DataTable dtTemp = GKS_BL.BL_ExecuteParamSP(strBodySP, Convert.ToInt32(dtGetHeaderVal.Rows[0][0]), 1))
                    {
                        dtGetBodyVal = dtTemp.Clone();
                        //dtGetBodyVal = GKS_BL.BL_ExecuteParamSP(strBodySP, Convert.ToInt32(dtGetHeaderVal.Rows[0][0]), nSalesSerialWisePrint);
                        foreach (DataRow iRowBody in dtTemp.Rows)
                        {
                            dtGetBodyVal.ImportRow(iRowBody);
                            //Future set app config level print sales Invoice with Product Serial
                            if (nSalesSerialWisePrint == 1)
                            {
                                //get Serial from Detail based on row serial column and Inv Id
                                using (DataTable dtSerial = GKS_BL.BL_ExecuteParamSP("uspGetProductSerialForPrint",
                                    Convert.ToInt32(dtGetHeaderVal.Rows[0][0]),
                                    Convert.ToInt32(iRowBody["Serial"])))
                                {
                                    //product serial add to print datatable
                                    foreach (DataRow item in dtSerial.Rows)
                                    {
                                        DataRow dr = dtGetBodyVal.NewRow();
                                        dr["ProdSerial"] = item["ProdSerial"];
                                        dtGetBodyVal.Rows.Add(dr);
                                    }
                                }
                            }
                        }
                    }
                    //Print Sales Return Detail if Adjust for that sales document
                    using (DataTable dt = GKS_BL.BL_ExecuteParamSP("uspGetAdjustedSalesReturnInvoice", Convert.ToInt32(dtGetHeaderVal.Rows[0][0])))
                    {
                        if (dt.Rows.Count > 0)
                        {
                            nSRPrintIndex = dtGetBodyVal.Rows.Count;
                        }
                        foreach (DataRow IRow in dt.Rows)
                        {
                            //Get Sales Return Detail
                            using (DataTable dtSaleReturn = GKS_BL.BL_ExecuteParamSP(strBodySP, Convert.ToInt32(IRow[0])))
                            {
                                //Sales return Moves to Sales Detail Table
                                foreach (DataRow item in dtSaleReturn.Rows)
                                {
                                    dtGetBodyVal.ImportRow(item);
                                }
                            }
                        }
                    }
                }
                //Other Transaction as Fallow
                else
                {
                    dtGetBodyVal = GKS_BL.BL_ExecuteParamSP(strBodySP, nTransId);
                }
            }
            catch (Exception)
            {
                throw;
            }
        }

        /// <summary>
        ///set paper only header and labels
        /// </summary>
        /// <param name="g">Draw a string using graphics </param>
        private void SetHeaderLabel()
        {
            try
            {
                if (dtGetConfigPage.Rows.Count > 0)
                {
                    //Header Label Printing
                    DataRow[] drHeader = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Label' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Header'");
                    if (drHeader.Length > 0)
                    {
                        foreach (DataRow row in drHeader)
                        {
                            if (row[14].ToString() == "Label" && row[18].ToString() == "Header")
                            {
                                SetFontStyle(row, null, 0, 0, "Label", 0);
                            }
                        }
                    }
                    //Image Printing
                    drHeader = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Image' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Header'");
                    if (drHeader.Length > 0)
                    {
                        foreach (DataRow row in drHeader)
                        {
                            SetFontStyle(row, null, 0, 0, "Image", 0);
                        }
                    }
                    //Barcode Printing
                    drHeader = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Barcode' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Barcode'");
                    if (drHeader.Length > 0 && dtGetHeaderVal.Rows.Count > 0)
                    {
                        foreach (DataRow row in drHeader)
                        {
                            SetFontStyle(row, dtGetHeaderVal, 0, 0, "Barcode", 0);
                        }
                    }
                }
            }
            catch (Exception)
            {
                //objmdi.ShowMessage("Unable to Print SetHeaderLabel", GKS_BL.ToolStripErrorMsg);
            }
        }

        /// <summary>
        /// Header Value Printing Based Config label replace Header Data
        /// Put Each label add form 
        /// </summary>
        private void SetHeaderValue()
        {
            try
            {
                // set Value in Header level
                DataRow[] drHeaderValue = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Value' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Header'");
                if (drHeaderValue.Length > 0)
                {
                    DataTable Temp = drHeaderValue.CopyToDataTable();
                    DataColumnCollection dtHeadercolumns = dtGetHeaderVal.Columns;
                    DataColumnCollection dtsplcolumns = dtGetSpecialVal.Columns;
                    for (int nCount = 0; nCount < Temp.Rows.Count; nCount++)
                    {
                        if (dtHeadercolumns.Contains(Temp.Rows[nCount][9].ToString()))
                        {
                            int nColumnCount = dtGetHeaderVal.Columns[Temp.Rows[nCount][9].ToString()].Ordinal;
                            SetFontStyle(Temp.Rows[nCount], dtGetHeaderVal, nColumnCount, 0, "Header", 0);
                        }
                        if (dtsplcolumns.Contains(Temp.Rows[nCount][9].ToString()))
                        {
                            int nColumnCount = dtGetSpecialVal.Columns[Temp.Rows[nCount][9].ToString()].Ordinal;
                            SetFontStyle(Temp.Rows[nCount], dtGetSpecialVal, nColumnCount, 0, "Header", 0);
                        }
                    }
                }
                DataRow[] drFormulaValue = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Formula' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Header'");
                if (drFormulaValue.Length > 0)
                {
                    foreach (DataRow IRow in drFormulaValue)
                    {
                        SetFontStyle(IRow, dtGetHeaderVal, 0, 0, "Formula", 0);
                    }
                }
            }
            catch (Exception)
            {
                //objmdi.ShowMessage("Unable to Print setHeaderValue", GKS_BL.ToolStripErrorMsg);
            }
        }

        /// <summary>
        /// Body label and Data Label replace Body value
        /// Item Per Page Page Handle
        /// </summary>
        /// <param name="g"></param>
        /// <param name="e"></param>
        private void SetBody()
        {
            try
            {
                // Set body label in Paper
                float pointY = 0f;
                if (dtGetConfigPage.Rows.Count > 0)
                {
                    DataRow[] drBody = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Label' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Body'");
                    if (drBody.Length > 0)
                    {
                        foreach (DataRow row in drBody)
                        {
                            SetFontStyle(row, null, 0, 0, "Label", 0);
                        }
                    }
                }
                //Body Loop
                DataRow[] drBodyValue = dtGetConfigPage.Select("(" + dtGetConfigPage.Columns[14].ColumnName + "= 'Value' OR "
                    + dtGetConfigPage.Columns[14].ColumnName + "='Formula' ) AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Body'");
                if (drBodyValue.Length > 0)
                {
                    DataTable Temp = drBodyValue.CopyToDataTable();
                    bool blCheck = true;
                    while (totalnumber < dtGetBodyVal.Rows.Count)
                    {
                        // 6 --- > Continoues Pager, 5 --- > Item per Page
                        if (Convert.ToInt32(Temp.Rows[0][6].ToString()) > 0 || itemperpage < Convert.ToInt32(Temp.Rows[0][5].ToString()))
                        {
                            //Preview time set Increase Y position only sales transaction
                            if (nTransType == 4)
                            {
                                if (!string.IsNullOrEmpty(Convert.ToString(dtGetBodyVal.Rows[totalnumber]["ProdSerial"])))
                                {
                                    bodyFontHeight += float.Parse(Temp.Rows[0][13].ToString());
                                    if (nFormHeight < bodyFontHeight)
                                    {
                                        nFormHeight = (int)bodyFontHeight;
                                    }
                                    blCheck = false;
                                }
                                if ((Convert.ToString(dtGetBodyVal.Rows[totalnumber]["SR"])) == "Sales Return")
                                {
                                    //if (nSRPrintIndex > 0 && nSRPrintIndex == totalnumber)
                                    //{
                                    bodyFontHeight += float.Parse(Temp.Rows[0][13].ToString());
                                    nSRPrintIndex = 0;
                                }
                            }
                            if (blCheck)
                            {
                                Font font = null;
                                DataColumnCollection dtBodycolumns = dtGetBodyVal.Columns;
                                for (int nCount = 0; nCount < Temp.Rows.Count; nCount++)
                                {
                                    if (Temp.Rows[nCount][14].ToString() == "Value")
                                    {
                                        if (dtBodycolumns.Contains(Temp.Rows[nCount][9].ToString()))
                                        {
                                            int nColumnCount = dtGetBodyVal.Columns[Temp.Rows[nCount][9].ToString()].Ordinal;
                                            /// Y position --- > 13
                                            pointY = float.Parse(Temp.Rows[nCount][13].ToString()) + bodyFontHeight;
                                            SetFontStyle(Temp.Rows[nCount], dtGetBodyVal, nColumnCount, totalnumber, "Body", pointY);
                                            font = new Font(Temp.Rows[nCount][15].ToString(), Convert.ToInt32(Temp.Rows[nCount][16].ToString()));
                                        }
                                    }
                                    else if (Temp.Rows[nCount][14].ToString() == "Formula")
                                    {
                                        pointY = float.Parse(Temp.Rows[nCount][13].ToString()) + bodyFontHeight;
                                        SetFontStyle(Temp.Rows[nCount], dtGetBodyVal, 0, totalnumber, "FormulaBody", pointY);
                                        font = new Font(Temp.Rows[nCount][15].ToString(), Convert.ToInt32(Temp.Rows[nCount][16].ToString()));
                                    }
                                }
                                if (font != null)
                                {
                                    bodyFontHeight += font.Height + Convert.ToInt32(Temp.Rows[0][27]);
                                }
                            }
                            itemperpage += 1;
                            totalnumber += 1;
                        }
                        else
                        {
                            bodyFontHeight = 0;
                            SetFooterLabel(0);
                            SetFooterValue(0);
                            itemperpage = 0;
                            return;
                        }
                    }

                }
                //
                // Continues pager.
                //
                SetFooterLabel(1, 0, pointY);
                SetFooterValue(1, 0, pointY);
            }
            catch (Exception)
            {
                //objmdi.ShowMessage("Unable to Print setBody", GKS_BL.ToolStripErrorMsg);
            }
        }

        /// <summary>
        /// Footer label 
        /// Handle Footer on Everypage and Amount in Words,Tax Type Wise Printing
        /// </summary>
        /// <param name="g"></param>
        /// <param name="e"></param>
        /// <param name="nFooterValue"></param>
        /// <param name="strFooterValue"></param>
        /// <param name="fPointParamY">Handle Cut Sheet or Continues Paper</param>
        private void SetFooterLabel(int nFooterValue, int? strFooterValue = null, float? fPointParamY = null)
        {
            try
            {
                DataRow[] drFooter = dtGetConfigPage.Select(
                                                            dtGetConfigPage.Columns[14].ColumnName + "= 'Label' OR "
                                                            + dtGetConfigPage.Columns[14].ColumnName + "= 'Image' AND "
                                                            + dtGetConfigPage.Columns[18].ColumnName + "= 'Footer'"
                                                           );
                if (drFooter.Length > 0)
                {
                    float fPointY = 0;
                    if (fPointParamY.HasValue)
                    {
                        fPointY = (float)fPointParamY;
                    }
                    foreach (DataRow row in drFooter)
                    {
                        // Type --> HEader or Body or Footer
                        if (row[18].ToString() == "Footer")
                        {
                            // 13 - -> Y position
                            decimal firstFooterpointY = Convert.ToDecimal(row[13].ToString());
                            YPositionDiff = (fPointY - (float)firstFooterpointY);
                            YPositionDiff += 20;
                            break;
                        }
                    }

                    foreach (DataRow row in drFooter)
                    {
                        // 6    --- > Continues Sheet
                        if (Convert.ToInt32(row[6].ToString()) == 0)
                        {
                            if (ValidateFooter(row) == true)
                            {
                                SetFontStyle(row, null, 0, 0, row[14].ToString(), 0);
                            }
                        }
                        if (Convert.ToInt32(row[6].ToString()) == 1)
                        {
                            if (row[14].ToString() == "Label" && row[18].ToString() == "Footer")
                            {
                                SetFontStyle(row, null, 0, 0, "Footer Label", YPositionDiff);
                            }
                            if (row[14].ToString() == "Image" && row[18].ToString() == "Footer")
                            {
                                SetFontStyle(row, null, 0, 0, "Image", YPositionDiff);
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                //objmdi.ShowMessage("setFooterLabel", GKS_BL.ToolStripErrorMsg);
                //GKS_BL.BL_ExceptionMsg("Print", "setFooterLabel", ex);
            }
        }

        /// <summary>
        /// Footer  data label replace footer value
        /// Handle Footer on Everypage and Amount in Words,Tax Type Wise Printing
        /// </summary>
        /// <param name="e"></param>
        /// <param name="e"></param>
        /// <param name="nFooterValue"></param>
        /// <param name="strFooterValue"></param>
        /// <param name="fPointParamY"></param>
        private void SetFooterValue(int nFooterValue, int? strFooterValue = null, float? fPointParamY = null)
        {
            DataRow[] drFooterValue = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Value' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Footer'");
            bool isContinous = false;
            if (drFooterValue.Length > 0)
            {
                DataTable Temp = drFooterValue.CopyToDataTable();
                DataColumnCollection dtHeadercolumns = dtGetHeaderVal.Columns;
                DataColumnCollection dtsplcolumns = dtGetSpecialVal.Columns;
                if (dtsplcolumns.Contains("Tax Percentage"))
                {
                    dtsplcolumns.Remove("Tax Percentage");
                }
                if (dtsplcolumns.Contains("Tax Amount"))
                {
                    dtsplcolumns.Remove("Tax Amount");
                }
                if (dtsplcolumns.Contains("Tax Value"))
                {
                    dtsplcolumns.Remove("Tax Value");
                }
                if (dtsplcolumns.Contains("GST Tax Amount"))
                {
                    dtsplcolumns.Remove("GST Tax Amount");
                }
                if (dtsplcolumns.Contains("CGST %"))
                {
                    dtsplcolumns.Remove("CGST %");
                }
                if (dtsplcolumns.Contains("CGST Amount"))
                {
                    dtsplcolumns.Remove("CGST Amount");
                }
                if (dtsplcolumns.Contains("SGST %"))
                {
                    dtsplcolumns.Remove("SGST %");
                }
                if (dtsplcolumns.Contains("SGST Amount"))
                {
                    dtsplcolumns.Remove("SGST Amount");
                }
                if (dtsplcolumns.Contains("UTGST %"))
                {
                    dtsplcolumns.Remove("UTGST %");
                }
                if (dtsplcolumns.Contains("UTGST Amount"))
                {
                    dtsplcolumns.Remove("UTGST Amount");
                }
                if (dtsplcolumns.Contains("IGST %"))
                {
                    dtsplcolumns.Remove("IGST %");
                }
                if (dtsplcolumns.Contains("IGST Amount"))
                {
                    dtsplcolumns.Remove("IGST Amount");
                }
                if (dtsplcolumns.Contains("GCESS %"))
                {
                    dtsplcolumns.Remove("GCESS %");
                }
                if (dtsplcolumns.Contains("GCESS Amount"))
                {
                    dtsplcolumns.Remove("GCESS Amount");
                }
                if (dtsplcolumns.Contains("ICESS %"))
                {
                    dtsplcolumns.Remove("ICESS %");
                }
                if (dtsplcolumns.Contains("ICESS Amount"))
                {
                    dtsplcolumns.Remove("ICESS Amount");
                }
                for (int nCount = 0; nCount < Temp.Rows.Count; nCount++)
                {
                    if (dtHeadercolumns.Contains(Temp.Rows[nCount][9].ToString()))
                    {
                        int nColumnCount = dtGetHeaderVal.Columns[Temp.Rows[nCount][9].ToString()].Ordinal;
                        isContinous = (Convert.ToInt32(Temp.Rows[nCount][6].ToString()) == 1);

                        if (Convert.ToInt32(Temp.Rows[nCount][6].ToString()) == 0)
                        {
                            if (ValidateFooterForTable(Temp, nCount) == true)
                            {
                                if (dtGetHeaderVal.Columns[nColumnCount].ColumnName == "Amt in Words")
                                {
                                    SetFontStyle(Temp.Rows[nCount], dtGetHeaderVal, nColumnCount, 0, "Amt in Words", 0);
                                }
                                else
                                {
                                    SetFontStyle(Temp.Rows[nCount], dtGetHeaderVal, nColumnCount, 0, "Footer Value", 0);
                                }
                            }
                        }
                        if (Convert.ToInt32(Temp.Rows[nCount][6].ToString()) == 1)
                        {
                            if (dtGetHeaderVal.Columns[nColumnCount].ColumnName == "Amt in Words")
                            {
                                SetFontStyle(Temp.Rows[nCount], dtGetHeaderVal, nColumnCount, 0, "Amt in Words", YPositionDiff);
                            }
                            else
                            {
                                SetFontStyle(Temp.Rows[nCount], dtGetHeaderVal, nColumnCount, 0, "Footer Value", YPositionDiff);
                            }
                        }
                    }
                    if (dtsplcolumns.Contains(Temp.Rows[nCount][9].ToString()))
                    {
                        int nColumnCount = dtGetSpecialVal.Columns[Temp.Rows[nCount][9].ToString()].Ordinal;
                        if (Convert.ToInt32(Temp.Rows[0][6].ToString()) == 0)
                        {
                            if (ValidateFooterForTable(Temp, nCount) == true)
                            {
                                SetFontStyle(Temp.Rows[nCount], dtGetSpecialVal, nColumnCount, 0, "Every Page Footer Value", 0);
                            }
                        }
                        if (Convert.ToInt32(Temp.Rows[0][6].ToString()) == 1)
                        {
                            SetFontStyle(Temp.Rows[nCount], dtGetSpecialVal, nColumnCount, 0, "Every Page Footer Value", YPositionDiff);
                        }
                    }
                }
            }
            DataRow[] drFormulaValue = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Formula' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Footer'");
            if (drFormulaValue.Length > 0)
            {
                foreach (DataRow IRow in drFormulaValue)
                {
                    if (ValidateFooter(IRow) == true)
                    {
                        SetFontStyle(IRow, dtGetHeaderVal, 0, 0, "Formula", Convert.ToInt32(IRow[6].ToString()) == 0 ? 0 : YPositionDiff);
                    }
                }
            }

            DataRow[] drGSTInfo = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Value' AND "
                + dtGetConfigPage.Columns[18].ColumnName + "= 'Footer' AND ("
                + dtGetConfigPage.Columns[9].ColumnName + "= 'GST Tax Amount' OR "
                + dtGetConfigPage.Columns[9].ColumnName + "= 'CGST %' OR " + dtGetConfigPage.Columns[9].ColumnName + "= 'SGST %' OR "
                + dtGetConfigPage.Columns[9].ColumnName + "= 'UTGST %' OR " + dtGetConfigPage.Columns[9].ColumnName + "= 'IGST %' OR "
                + dtGetConfigPage.Columns[9].ColumnName + "= 'GCESS %' OR " + dtGetConfigPage.Columns[9].ColumnName + "= 'ICESS %' OR "
                + dtGetConfigPage.Columns[9].ColumnName + "= 'CGST Amount' OR " + dtGetConfigPage.Columns[9].ColumnName + "= 'SGST Amount' OR "
                + dtGetConfigPage.Columns[9].ColumnName + "= 'GCESS Amount' OR " + dtGetConfigPage.Columns[9].ColumnName + "= 'ICESS Amount' OR "
                + dtGetConfigPage.Columns[9].ColumnName + "= 'UTGST Amount' OR " + dtGetConfigPage.Columns[9].ColumnName + "= 'IGST Amount')");
            if (drGSTInfo.Length > 0)
            {
                DataTable dt = drGSTInfo.CopyToDataTable();
                float GSTFontHeight = 0, pointY = 0f;
                DataTable dtGetGSTSplits = GKS_BL.BL_ExecuteParamSP("uspGetGSTforPrinting", nTransType, nTransId);
                DataColumnCollection dc = dtGetGSTSplits.Columns;
                if (dtGetGSTSplits.Rows.Count > 0)
                {
                    for (int nRow = 0; nRow < dtGetGSTSplits.Rows.Count; nRow++)
                    {
                        Font font = null;
                        for (int nColumn = 0; nColumn < drGSTInfo.Length; nColumn++)
                        {
                            font = new Font(drGSTInfo[nColumn][15].ToString(), Convert.ToInt32(drGSTInfo[nColumn][16].ToString()));
                            if ((dc.Contains("GST Tax Amount") && drGSTInfo[nColumn][9].ToString() == "GST Tax Amount")
                                || (dc.Contains("ICESS Amount") && drGSTInfo[nColumn][9].ToString() == "ICESS Amount")
                                || (dc.Contains("ICESS %") && drGSTInfo[nColumn][9].ToString() == "ICESS %")
                                || (dc.Contains("GCESS Amount") && drGSTInfo[nColumn][9].ToString() == "GCESS Amount")
                                || (dc.Contains("GCESS %") && drGSTInfo[nColumn][9].ToString() == "GCESS %")
                                || (dc.Contains("IGST Amount") && drGSTInfo[nColumn][9].ToString() == "IGST Amount")
                                || (dc.Contains("IGST %") && drGSTInfo[nColumn][9].ToString() == "IGST %")
                                || (dc.Contains("UTGST Amount") && drGSTInfo[nColumn][9].ToString() == "UTGST Amount")
                                || (dc.Contains("UTGST %") && drGSTInfo[nColumn][9].ToString() == "UTGST %")
                                || (dc.Contains("SGST Amount") && drGSTInfo[nColumn][9].ToString() == "SGST Amount")
                                || (dc.Contains("SGST %") && drGSTInfo[nColumn][9].ToString() == "SGST %")
                                || (dc.Contains("CGST Amount") && drGSTInfo[nColumn][9].ToString() == "CGST Amount")
                                || (dc.Contains("CGST %") && drGSTInfo[nColumn][9].ToString() == "CGST %"))
                            {
                                int nColumnCount = dtGetGSTSplits.Columns[drGSTInfo[nColumn][9].ToString()].Ordinal;
                                pointY = float.Parse(drGSTInfo[nColumn][13].ToString()) + GSTFontHeight;
                                if (ValidateFooter(drGSTInfo[nColumn]) == true)
                                {
                                    SetFontStyle(drGSTInfo[nColumn], dtGetGSTSplits, nColumnCount, nRow, "Footer Value", YPositionDiff + GSTFontHeight);
                                }
                            }
                        }
                        if (font != null)
                        {
                            GSTFontHeight += font.Height;
                        }
                    }
                }
            }
            DataRow[] drTaxWiseValue = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Value' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Footer' AND ("
            + dtGetConfigPage.Columns[9].ColumnName + "= 'Tax Value' OR  " + dtGetConfigPage.Columns[9].ColumnName + "= 'Tax Percentage' OR  " + dtGetConfigPage.Columns[9].ColumnName + "= 'Tax Amount')");
            if (drTaxWiseValue.Length > 0)
            {
                DataTable dtTax = new DataTable();
                float TaxWiseFontHeight = 0;
                DataTable dtValue = TaxWisePrint(dtGetBodyVal, drTaxWiseValue);
                if (nTransType == 4)
                {
                    if (dtValue.Columns.Contains("Doc Prefix"))
                    {
                        dtTax = dtValue.Select("[Doc Prefix]=2").CopyToDataTable();
                    }
                    else
                    {
                        dtTax = dtValue.Select().CopyToDataTable();
                    }
                }
                if (dtValue != null && dtValue.Rows.Count > 0)
                {
                    DataColumnCollection dtcolumns = dtValue.Columns;
                    DataTable dtCopy = dtValue.Clone();
                    float pointY = 0f;
                    DataTable dtDistinct = dtValue.DefaultView.ToTable(true, dtValue.Columns["Tax Percentage"].ColumnName);
                    for (int i = 0; i < dtDistinct.Rows.Count; i++)
                    {
                        DataRow drNew = dtCopy.NewRow();
                        for (int nConfig = 0; nConfig < drTaxWiseValue.Length; nConfig++)
                        {
                            if (dtcolumns.Contains("Tax Percentage") && drTaxWiseValue[nConfig][9].ToString() == "Tax Percentage")
                            {
                                drNew["Tax Percentage"] = dtDistinct.Rows[i]["Tax Percentage"].ToString();
                            }
                            if (dtcolumns.Contains("Tax Value") && drTaxWiseValue[nConfig][9].ToString() == "Tax Value")
                            {
                                decimal dTaxValue = (decimal)dtValue.Compute("SUM([Tax Value])", "[Tax Percentage] =" + dtDistinct.Rows[i]["Tax Percentage"].ToString());
                                drNew["Tax Value"] = dTaxValue;
                            }
                            if (dtcolumns.Contains("Tax Amount") && drTaxWiseValue[nConfig][9].ToString() == "Tax Amount")
                            {
                                decimal dTaxAmt = (decimal)dtValue.Compute("SUM([Tax Amount])", "[Tax Percentage] =" + dtDistinct.Rows[i]["Tax Percentage"].ToString());
                                drNew["Tax Amount"] = dTaxAmt;
                            }
                        }
                        dtCopy.Rows.Add(drNew);
                    }
                    if (dtCopy.Columns.Count > 0)
                    {
                        if (dtCopy.Columns.Count == 4)
                        {
                            dtCopy.Columns.Remove("Doc Prefix");
                        }
                    }
                    DataColumnCollection dtClonecolumns = dtCopy.Columns;
                    for (int i = 0; i < dtCopy.Rows.Count; i++)
                    {
                        Font font = null;
                        for (int nConfig = 0; nConfig < drTaxWiseValue.Length; nConfig++)
                        {
                            font = new Font(drTaxWiseValue[nConfig][15].ToString(), Convert.ToInt32(drTaxWiseValue[nConfig][16].ToString()));
                            if (dtcolumns.Contains("Tax Percentage") && drTaxWiseValue[nConfig][9].ToString() == "Tax Percentage")
                            {
                                int nColumnCount = dtCopy.Columns[drTaxWiseValue[nConfig][9].ToString()].Ordinal;
                                pointY = (float.Parse(drTaxWiseValue[nConfig][13].ToString()) + TaxWiseFontHeight) + ((isContinous) ? YPositionDiff : 0);
                                if (ValidateFooter(drTaxWiseValue[nConfig]) == true)
                                {
                                    SetFontStyle(drTaxWiseValue[nConfig], dtCopy, nColumnCount, i, "Body", pointY);
                                }
                            }
                            else if (dtClonecolumns.Contains("Tax Value") && drTaxWiseValue[nConfig][9].ToString() == "Tax Value")
                            {
                                int nColumnCount = dtCopy.Columns[drTaxWiseValue[nConfig][9].ToString()].Ordinal;
                                pointY = (float.Parse(drTaxWiseValue[nConfig][13].ToString()) + TaxWiseFontHeight) + ((isContinous) ? YPositionDiff : 0);
                                if (ValidateFooter(drTaxWiseValue[nConfig]) == true)
                                {
                                    SetFontStyle(drTaxWiseValue[nConfig], dtCopy, nColumnCount, i, "Body", pointY);
                                }
                            }
                            else if (dtcolumns.Contains("Tax Amount") && drTaxWiseValue[nConfig][9].ToString() == "Tax Amount")
                            {
                                int nColumnCount = dtCopy.Columns[drTaxWiseValue[nConfig][9].ToString()].Ordinal;
                                pointY = (float.Parse(drTaxWiseValue[nConfig][13].ToString()) + TaxWiseFontHeight) + ((isContinous) ? YPositionDiff : 0);
                                if (ValidateFooter(drTaxWiseValue[nConfig]) == true)
                                {
                                    SetFontStyle(drTaxWiseValue[nConfig], dtCopy, nColumnCount, i, "Body", pointY);
                                }
                            }
                        }
                        if (font != null)
                        {
                            TaxWiseFontHeight += font.Height;
                        }
                    }
                }
            }
        }

        /// <summary>
        /// Validate Footer on EVery page or Not 
        /// </summary>
        /// <param name="dr">Rowise Check From Footer Table</param>
        /// <returns>Print for Retrun true</returns>
        private bool ValidateFooter(DataRow dr)
        {
            bool bl = false;
            try
            {
                // 8 --- > Footer on EVery page
                if (Convert.ToInt32(dr[8].ToString()) == 1)
                {
                    bl = true;
                }
                else if (Convert.ToInt32(dr[8].ToString()) == 0)
                {
                    if (Convert.ToInt32(dr[19].ToString()) == 1 || totalnumber == dtGetBodyVal.Rows.Count)
                    {
                        bl = true;
                    }
                }
            }

            catch (Exception)
            {
                throw;
            }
            return bl;
        }

        /// <summary>
        /// Validate Footer on EVery page or Not in Table
        /// </summary>
        /// <param name="dt">Rowise Check From Footer Table</param>
        /// <param name="nRowCount">Fetched Row</param>
        /// <returns>Print for Retrun true</returns>
        private bool ValidateFooterForTable(DataTable dt, int nRowCount)
        {
            bool bl = false;
            try
            {
                if (Convert.ToInt32(dt.Rows[nRowCount][8].ToString()) == 1)
                {
                    bl = true;
                }
                else
                {
                    if (Convert.ToInt32(dt.Rows[nRowCount][19].ToString()) == 1 || totalnumber == dtGetBodyVal.Rows.Count)
                    {
                        bl = true;
                    }
                }
            }
            catch (Exception)
            {
                throw;
            }
            return bl;
        }

        /// <summary>
        /// Method Handle All Design Fonts and style for loop all things for header and footer
        /// </summary>
        /// <param name="row"></param>
        /// <param name="g"></param>
        /// <param name="RowValue"></param>
        /// <param name="ColumnCount"></param>
        /// <param name="RowCount"></param>
        /// <param name="Mode"></param>
        /// <param name="Ypoint"></param>
        private void SetFontStyle(DataRow row, DataTable RowValue, int ColumnCount, int RowCount, string Mode, float Ypoint)
        {
            try
            {
                //dynamic label used to add form should be Printable tables
                Label lbl = new Label();
                PictureBox picBox = new PictureBox();
                // 12 , 13 -- > X and Y position, 
                // 10 , 11   ---- > Width and Height
                // 22 - Bold , 23 - Italic  , 24 - Underline
                //  Right Align -- >  25
                Font fontControl = null;
                if (row[22].ToString() == "0" && row[23].ToString() == "0" && row[24].ToString() == "0")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Regular);
                }
                else if (row[22].ToString() == "1" && row[23].ToString() == "0" && row[24].ToString() == "0")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Bold);
                }
                else if (row[22].ToString() == "1" && row[23].ToString() == "1" && row[24].ToString() == "0")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Bold | FontStyle.Italic);
                }
                else if (row[22].ToString() == "1" && row[23].ToString() == "0" && row[24].ToString() == "1")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Bold | FontStyle.Underline);
                }
                else if (row[22].ToString() == "0" && row[23].ToString() == "0" && row[24].ToString() == "1")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Underline);
                }
                else if (row[22].ToString() == "0" && row[23].ToString() == "1" && row[24].ToString() == "1")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Italic | FontStyle.Underline);
                }
                else if (row[22].ToString() == "1" && row[23].ToString() == "1" && row[24].ToString() == "1")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Italic | FontStyle.Italic | FontStyle.Underline);
                }
                else if (row[22].ToString() == "0" && row[23].ToString() == "1" && row[24].ToString() == "0")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Italic);
                }
                //String Alignment
                StringFormat strFrmt = new StringFormat
                {
                    FormatFlags = StringFormatFlags.NoWrap,
                    Trimming = StringTrimming.None
                };
                strFrmt.LineAlignment = StringAlignment.Far;
                if (row[25].ToString() == "1")
                {
                    strFrmt.Alignment = StringAlignment.Far;
                }
                //Rectangle used for get width and height
                RectangleF drawRect = new RectangleF();
                if (Mode == "Body" || Mode == "FormulaBody")
                {
                    drawRect = new RectangleF(float.Parse(row[12].ToString()), Ypoint, float.Parse(row[10].ToString()), float.Parse(row[11].ToString()));
                }
                else if (Mode == "Footer Value" || Mode == "Footer Label" || Mode == "Amt in Words" || Mode == "Formula")
                {
                    float Yfinal = float.Parse(row[13].ToString()) + Ypoint;
                    drawRect = new RectangleF(float.Parse(row[12].ToString()), Yfinal, float.Parse(row[10].ToString()), float.Parse(row[11].ToString()));
                }
                else
                {
                    drawRect = new RectangleF(float.Parse(row[12].ToString()), float.Parse(row[13].ToString()), float.Parse(row[10].ToString()), float.Parse(row[11].ToString()));
                }
                if (string.IsNullOrEmpty(row[30].ToString()))
                {
                    lbl.Font = fontControl;
                    lbl.Location = new Point((int)drawRect.Location.X, (int)drawRect.Location.Y);
                    lbl.Width = (int)drawRect.Width;
                    lbl.Height = (int)drawRect.Height;
                }
                else
                {
                    picBox.Location = new Point((int)drawRect.Location.X, (int)drawRect.Location.Y);
                    picBox.Width = (int)drawRect.Width;
                    picBox.Height = (int)drawRect.Height;
                }
                if (Mode == "Header" || Mode == "Body" || Mode == "Footer Value" || Mode == "Every Page Footer Value")
                {
                    if (row[9].ToString() != "Page No.") // LAbel Name --- > 9 
                    {
                        if (RowValue.Rows[RowCount][ColumnCount].ToString().Contains("."))
                        {
                            //GKS_BL.BL_RoundOffDecimal
                            lbl.Text = GKS_BL.BL_RoundOffTwoDecimal(RowValue.Rows[RowCount][ColumnCount].ToString()).ToString();
                        }
                        else
                        {
                            lbl.Text = RowValue.Rows[RowCount][ColumnCount].ToString().Trim();
                        }
                    }
                    //else
                    //{
                    //    lbl.Text = PageNo.ToString();
                    //}
                }
                else if (Mode == "Label" || Mode == "Footer Label")
                {
                    lbl.Text = row[9].ToString();
                }
                else if (Mode == "Image")
                {
                    MemoryStream ms = new MemoryStream((byte[])row[30]);
                    picBox.Image = Image.FromStream(ms);
                    picBox.SizeMode = PictureBoxSizeMode.StretchImage;
                    picBox.Refresh();
                }
                else if (Mode == "Barcode")
                {
                    if (RowValue.Columns.Contains("Doc Id"))
                    {
                        //string strDocValue = (RowValue.Rows[0]["Doc Id"].ToString());
                        //BaseBarcode barcode = BarcodeFactory.GetBarcode(Symbology.Code128);
                        //barcode.Number = strDocValue;
                        //barcode.ChecksumAdd = true;
                        //Bitmap bitmap = barcode.Render();
                        //lbl.Image = bitmap;
                        //lbl.Text = null;
                    }
                    else
                    {
                        // objmdi.messages("Barcode Column Doc Id Missing", GKS_BL.ToolStripErrorMsg);
                    }
                }
                else if (Mode == "Amt in Words")
                {
                    int Value = RowValue.Columns.Count - 3;
                    //GKS_BL.BL_RoundOffDecimal
                    decimal NetAmt = GKS_BL.BL_RoundOffTwoDecimal(RowValue.Rows[0][Value].ToString());
                    lbl.Text = GKS_BL.BL_AmountInWords(NetAmt).Trim();
                }
                else if (Mode == "Formula" || Mode == "FormulaBody")
                {
                    string str = GKS_BL.BL_GetFormulaValue(RowValue, row[9].ToString(), RowCount).ToString();
                    lbl.Text = str.Trim();
                }
                lbl.Text = string.Format(lbl.Text, strFrmt).Trim();
                PrintForm.Controls.Add((string.IsNullOrEmpty(row[30].ToString()) ? (Control)lbl : (Control)picBox));
                if (nFormHeight < lbl.Location.Y)
                {
                    nFormHeight = lbl.Location.Y;
                }
            }
            catch (Exception ex)
            {
                //GKS_BL.BL_ExceptionMsg("Print", "SetFontStyle", ex);
            }
        }

        /// <summary>
        /// Tax Type Wise Tax Amount Showing add the Footer
        /// </summary>
        /// <param name="dtValue"></param>
        /// <param name="IRow"></param>
        /// <returns></returns>
        DataTable TaxWisePrint(DataTable dtValue, DataRow[] IRow)
        {
            try
            {
                string[] strValue = new string[IRow.Length];
                for (int i = 0; i < IRow.Length; i++)
                {
                    strValue[i] = IRow[i][9].ToString();
                }
                if (strValue != null && dtValue.Rows.Count > 0)
                {
                    DataColumnCollection dtColumns = dtValue.Columns;
                    if (dtColumns.Contains("Tax Percentage"))
                    {
                        return dtValue.DefaultView.ToTable(false, strValue);
                    }
                    return null;
                }
                return null;
            }
            catch (Exception)
            {
                throw;
            }

        }
    }
}