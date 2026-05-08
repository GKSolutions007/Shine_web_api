using ClosedXML.Excel;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Spreadsheet;
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Web;
using System.Windows.Forms;
using static System.Windows.Forms.VisualStyles.VisualStyleElement.ListView;

namespace SampWebApi.Import_Utility
{
    using Excel = Microsoft.Office.Interop.Excel;
    public class clsExportData
    {
        public string strFilePath { get; set; }
        public string strFileName { get; set; }
        public string strSheetName { get; set; }
        private readonly string strExtension = ".xlsx";
        public const string strFolderName = "\\Export Data\\";
        public void AddingHelptoExcel(string strFileLocation, int HelpSheetIndex, DataSet dtHelpData)
        {
            Excel.Application excel;
            Excel.Workbook worKbooK;
            Excel.Worksheet worKsheeT;
            Excel.Range celLrangE;
            try
            {
                excel = new Excel.Application();
                if (excel != null)
                {
                    worKbooK = excel.Workbooks.Open(strFileLocation);
                    worKsheeT = excel.ActiveSheet as Excel.Worksheet;
                    var xlSheets = worKbooK.Sheets as Excel.Sheets;
                    worKsheeT = (Excel.Worksheet)xlSheets.Add(xlSheets[HelpSheetIndex], Type.Missing, Type.Missing, Type.Missing);
                    worKsheeT.Name = "Help";
                    worKsheeT = (Excel.Worksheet)worKbooK.Worksheets.get_Item(HelpSheetIndex);
                    celLrangE = worKsheeT.UsedRange;
                    int copyRowIndex = celLrangE.Rows.Count + 1;
                    int nExcelRow = 1, nExcelColumn = 1;

                    for (int i = 0; i < dtHelpData.Tables.Count; i++)
                    {
                        if (i != (dtHelpData.Tables.Count - 1))
                        {
                            ColorExcel(worKsheeT, nExcelRow, nExcelColumn, System.Drawing.Color.Yellow, System.Drawing.Color.Black);
                            worKsheeT.Cells[nExcelRow, nExcelColumn].Font.Size = 13;
                            worKsheeT.Cells[nExcelRow, nExcelColumn].Font.Bold = true;
                            worKsheeT.Cells[nExcelRow, nExcelColumn] = dtHelpData.Tables[i].TableName;
                            CellFormats(worKsheeT, nExcelRow, nExcelColumn, "@");
                            worKsheeT.Range[worKsheeT.Cells[nExcelRow, 1], worKsheeT.Cells[nExcelRow, dtHelpData.Tables[i].Columns.Count]].Merge();
                            copyRowIndex++;
                            nExcelRow++;
                        }
                        nExcelColumn = 1;
                        for (int nColumn = 0; nColumn < dtHelpData.Tables[i].Columns.Count; nColumn++)
                        {
                            ColorExcel(worKsheeT, nExcelRow, nExcelColumn, System.Drawing.Color.SteelBlue, System.Drawing.Color.White);
                            worKsheeT.Cells[nExcelRow, nExcelColumn] = dtHelpData.Tables[i].Columns[nColumn].ColumnName;
                            CellFormats(worKsheeT, nExcelRow, nExcelColumn, "@");
                            worKsheeT.Cells[nExcelRow, nExcelColumn].Font.Size = 13;
                            worKsheeT.Cells[nExcelRow, nExcelColumn].Font.Bold = true;
                            nExcelColumn++;
                        }
                        copyRowIndex++;
                        nExcelRow++;
                        nExcelColumn = 1;
                        for (int nRowData = 0; nRowData < dtHelpData.Tables[i].Rows.Count; nRowData++)
                        {
                            for (int nColumn = 0; nColumn < dtHelpData.Tables[i].Columns.Count; nColumn++)
                            {
                                worKsheeT.Cells[nExcelRow, nExcelColumn] = dtHelpData.Tables[i].Rows[nRowData][nColumn];
                                CellFormats(worKsheeT, nExcelRow, nExcelColumn, "@");
                                worKsheeT.Cells[nExcelRow, nExcelColumn].Font.Size = 12;
                                worKsheeT.Cells[nExcelRow, nExcelColumn].Font.Bold = false;
                                nExcelColumn++;
                            }
                            copyRowIndex++;
                            nExcelRow++;
                            nExcelColumn = 1;
                        }
                        copyRowIndex++;
                        nExcelRow++;
                        copyRowIndex++;
                        nExcelRow++;
                        nExcelColumn = 1;
                    }
                    excel.DisplayAlerts = false;
                    for (int i = excel.ActiveWorkbook.Worksheets.Count; i > 0; i--)
                    {
                        worKsheeT = excel.ActiveWorkbook.Worksheets[i];
                        if (worKsheeT.Name == "Dup Help")
                        {
                            worKsheeT.Delete();
                        }
                        else
                        {
                            //worKsheeT.Columns.AutoFit();
                        }

                        if (i == 1)
                        {
                            worKsheeT.Select();
                        }
                    }
                    excel.DisplayAlerts = true;
                    worKbooK.Close(true, Type.Missing, Type.Missing);
                    excel.Quit();
                }
            }
            catch (Exception ex)
            {
                throw ex;
            }
            finally
            {
                worKsheeT = null;
                celLrangE = null;
                worKbooK = null;
            }
        }
        private static void ColorExcel(Microsoft.Office.Interop.Excel.Worksheet worKsheeT, int nExcelRow, int nExcelColumn, System.Drawing.Color ColorName, System.Drawing.Color FontColor)
        {
            worKsheeT.Cells[nExcelRow, nExcelColumn].Interior.Color = System.Drawing.ColorTranslator.ToOle(ColorName);
            worKsheeT.Cells[nExcelRow, nExcelColumn].Font.Bold = true;
            worKsheeT.Cells[nExcelRow, nExcelColumn].Font.Size = 11;
            worKsheeT.Cells[nExcelRow, nExcelColumn].Font.Color = FontColor;
        }

        private static void CellFormats(Microsoft.Office.Interop.Excel.Worksheet worKsheeT, int nExcelRow, int nExcelColumn, string CellFormat)
        {
            Excel.Range a1 = worKsheeT.Cells[nExcelRow, nExcelColumn];
            Excel.Range a2 = worKsheeT.Cells[nExcelRow, nExcelColumn];
            Excel.Range formatRange = worKsheeT.get_Range(a1, a2);
            formatRange.NumberFormat = CellFormat;
            worKsheeT.get_Range(a1, a2).Cells.Borders.LineStyle = Microsoft.Office.Interop.Excel.XlLineStyle.xlContinuous;

        }


        public void OpenTransTemplate(List<string> strHeader, List<string> strDetail, List<string> strSerialInfo)
        {
            try
            {
                DataTable dtHeader = new DataTable();
                DataTable dtDetail = new DataTable();
                DataTable dtSerialInfo = new DataTable();
                foreach (string strHeaderName in strHeader)
                {
                    dtHeader.Columns.Add(strHeaderName, typeof(string));
                }
                foreach (string strHeaderName in strDetail)
                {
                    dtDetail.Columns.Add(strHeaderName, typeof(string));
                }
                foreach (string strHeaderName in strSerialInfo)
                {
                    dtSerialInfo.Columns.Add(strHeaderName, typeof(string));
                }

                //SAVE AS FILE
                if (!Directory.Exists(strFilePath))
                {
                    Directory.CreateDirectory(strFilePath);
                }
                using (XLWorkbook wb = new XLWorkbook())
                {
                    DataTable dtHelp = new DataTable();
                    dtHelp.Columns.Add("Help");
                    wb.Worksheets.Add(dtHeader, "Header");
                    wb.Worksheets.Add(dtDetail, "Detail");
                    wb.Worksheets.Add(dtSerialInfo, "SerialInfo");
                    wb.Worksheets.Add(dtHelp, "Dup Help");
                    wb.SaveAs(strFilePath + strFileName + strExtension);
                }
            }
            catch (IOException)
            {
                MessageBox.Show("File Already Opened Using Another Process", "Import", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
            catch (Exception)
            {
                throw;
            }
        }
        public void OpenTransTemplate(List<string> strHeader)
        {
            try
            {
                DataTable dtHeader = new DataTable();
                foreach (string strHeaderName in strHeader)
                {
                    dtHeader.Columns.Add(strHeaderName, typeof(string));
                }
                //SAVE AS FILE
                if (!Directory.Exists(strFilePath))
                {
                    Directory.CreateDirectory(strFilePath);
                }
                using (XLWorkbook wb = new XLWorkbook())
                {
                    wb.Worksheets.Add(dtHeader, "Header");
                    wb.SaveAs(strFilePath + strFileName + strExtension);
                }
            }

            catch (IOException)
            {
                MessageBox.Show("File Already Opened Using Another Process", "Import", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
            catch (Exception)
            {
                throw;
            }
        }
        public void OpenTransTemplate(List<string> strHeader, List<string> strDetail)//,DataSet dtHelp = null
        {
            try
            {
                DataTable dtHeader = new DataTable();
                DataTable dtDetail = new DataTable();
                foreach (string strHeaderName in strHeader)
                {
                    dtHeader.Columns.Add(strHeaderName, typeof(string));
                }
                foreach (string strHeaderName in strDetail)
                {
                    dtDetail.Columns.Add(strHeaderName, typeof(string));
                }
                //SAVE AS FILE
                if (!Directory.Exists(strFilePath))
                {
                    Directory.CreateDirectory(strFilePath);
                }
                DataTable dtHelp = new DataTable();
                dtHelp.Columns.Add("Help");
                using (XLWorkbook wb = new XLWorkbook())
                {
                    wb.Worksheets.Add(dtHeader, "Header");
                    wb.Worksheets.Add(dtDetail, "Detail");
                    wb.Worksheets.Add(dtHelp, "Dup Help");
                    wb.SaveAs(strFilePath + strFileName + strExtension);
                }
            }
            catch (IOException)
            {
                MessageBox.Show("File Already Opened Using Another Process", "Import", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
            catch (Exception)
            {
                throw;
            }
        }
        public void TransImport_ExportToExcel(DataTable dtHeader, DataTable dtDetail, DataTable dtSerialInfo, bool AddHelp = false)
        {
            try
            {
                //Exporting to Excel
                if (!Directory.Exists(strFilePath))
                {
                    Directory.CreateDirectory(strFilePath);
                }
                DataTable dtHelp = new DataTable();
                dtHelp.Columns.Add("Help");
                using (XLWorkbook wb = new XLWorkbook())
                {
                    wb.Worksheets.Add(dtHeader, "Header");
                    wb.Worksheets.Add(dtDetail, "Detail");
                    wb.Worksheets.Add(dtSerialInfo, "SerialInfo");
                    if (AddHelp)
                        wb.Worksheets.Add(dtHelp, "Dup Help");
                    wb.SaveAs(strFilePath + strFileName + strExtension);
                }
            }
            catch (IOException)
            {
                MessageBox.Show("File Already Opened Using Another Process", "Import", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
            catch (Exception)
            {
                throw;
            }
        }
        public void TransImport_ExportToExcel(DataTable dtHeader, DataTable dtDetail, bool AddHelp = false)
        {
            try
            {
                //Exporting to Excel
                if (!Directory.Exists(strFilePath))
                {
                    Directory.CreateDirectory(strFilePath);
                }
                DataTable dtHelp = new DataTable();
                dtHelp.Columns.Add("Help");
                using (XLWorkbook wb = new XLWorkbook())
                {
                    wb.Worksheets.Add(dtHeader, "Header");
                    wb.Worksheets.Add(dtDetail, "Detail");
                    if (AddHelp)
                        wb.Worksheets.Add(dtHelp, "Dup Help");
                    wb.SaveAs(strFilePath + strFileName + strExtension);
                }
            }
            catch (IOException)
            {
                MessageBox.Show("File Already Opened Using Another Process", "Import", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
            catch (Exception)
            {
                throw;
            }
        }
        public DataTable TransactionColumnValidation(List<string> lst, string sSheetName, ref bool blResult)
        {
            DataTable dtSheetdata = new DataTable();
            try
            {
                blResult = true;                
                List<string> lstdtColumn = new List<string>();
                string ffp = strFilePath + strFileName;
                SpreadsheetDocument docSelected = SpreadsheetDocument.Open(strFilePath + strFileName, false);
                IEnumerable<Sheet> AllSheet = docSelected.WorkbookPart.Workbook.Descendants<Sheet>();
                strSheetName = sSheetName;
                Sheet sCurrent = GetSelectedSheet(AllSheet);
                if (sCurrent != null)
                {
                    Worksheet worksheet = (docSelected.WorkbookPart.GetPartById(sCurrent.Id.Value) as WorksheetPart).Worksheet;
                    IEnumerable<Row> rows = worksheet.GetFirstChild<SheetData>().Descendants<Row>();
                    // Add Header Columns
                    foreach (Row row in rows)
                    {
                        if (row.RowIndex.Value == 1)
                        {
                            foreach (Cell cell in row.Descendants<Cell>())
                            {
                                lstdtColumn.Add(GetValue(docSelected, cell));
                            }
                        }
                        break;
                    }
                    // Verify Columns Count
                    if (lst.Count != lstdtColumn.Count)
                    {
                        blResult = false;
                    }
                    string ErrMsg = "";
                    // Verify Columns Names Are Same Or Not
                    foreach (string str in lst)
                    {
                        if (!lstdtColumn.Contains(str))
                        {
                            ErrMsg = str;
                            blResult = false;
                            break;
                        }
                    }
                    if (blResult)
                    {
                        dtSheetdata = GetTransactionDataRecords(docSelected, rows, sSheetName);
                        // Get the elapsed time as a TimeSpan value.
                    }
                    //docSelected.Close();
                }
            }
            catch (IOException)
            {

            }
            catch (Exception)
            {
                throw;
            }
            return dtSheetdata;
        }
        public DataTable GetTable(SpreadsheetDocument docSelected, IEnumerable<Row> rows)
        {
            DataTable dCheck = new DataTable();
            List<string> lstv = new List<string>();
            // Iterate Every Rows In Excel Sheet
            int TotalRowCount = rows.Count();

            decimal dRowFact = (decimal)TotalRowCount / 100;

            int TempRowCount = 0;

            foreach (Row row in rows)
            {
                if (row.RowIndex.Value == 1)
                {
                    foreach (Cell cell in row.Descendants<Cell>())
                    {
                        dCheck.Columns.Add(GetValue(docSelected, cell));
                        lstv.Add(Regex.Replace(cell.CellReference, @"[\d-]", string.Empty));
                    }
                }
                else
                {
                    dCheck.Rows.Add();
                    int nCount = 0, index = 0, TempCount;
                    foreach (Cell cell in row.Descendants<Cell>())
                    {
                        var vCellHeader = Regex.Replace(cell.CellReference, @"[\d-]", string.Empty);
                        var Temp = lstv[nCount];
                        if (lstv[nCount] != vCellHeader)
                        {
                            index = lstv.FindIndex(x => x.StartsWith(vCellHeader));
                            TempCount = nCount;
                            while (index > 0 && index > TempCount)
                            {
                                dCheck.Rows[dCheck.Rows.Count - 1][nCount] = null;
                                nCount++;
                                index--;
                            }
                        }
                        // Added By Sriram G
                        // Excel Cell Value Decimal Should be RoundOff 6 Digits
                        decimal dOutValue = 0.00M;
                        string strCellValue = GetValue(docSelected, cell);
                        //if (!string.IsNullOrEmpty(strCellValue))
                        //{
                        //    if (strCellValue.Contains('.'))
                        //    {
                        //        if (decimal.TryParse(strCellValue, out dOutValue))
                        //        {
                        //            strCellValue = Convert.ToString(Math.Round(Convert.ToDecimal(strCellValue), 6));
                        //        }
                        //    }
                        //}
                        dCheck.Rows[dCheck.Rows.Count - 1][nCount] = strCellValue;
                        nCount++;
                    }
                }

                TempRowCount++;
            }
            return dCheck;
        }
        public DataTable GetTransactionDataRecords(SpreadsheetDocument docSelected, IEnumerable<Row> rows, string HeaderorItems)
        {
            DataTable dCheck = new DataTable();
            List<string> lstv = new List<string>();
            // Iterate Every Rows In Excel Sheet
            int TotalRowCount = rows.Count();

            decimal dRowFact = (decimal)TotalRowCount / 100;

            int TempRowCount = 0;

            foreach (Row row in rows)
            {
                if (row.RowIndex.Value == 1)
                {
                    foreach (Cell cell in row.Descendants<Cell>())
                    {
                        dCheck.Columns.Add(GetValue(docSelected, cell));
                        lstv.Add(Regex.Replace(cell.CellReference, @"[\d-]", string.Empty));
                    }
                }
                else
                {
                    dCheck.Rows.Add();
                    int nCount = 0, index = 0, TempCount;
                    foreach (Cell cell in row.Descendants<Cell>())
                    {
                        var vCellHeader = Regex.Replace(cell.CellReference, @"[\d-]", string.Empty);
                        var Temp = lstv[nCount];
                        if (lstv[nCount] != vCellHeader)
                        {
                            index = lstv.FindIndex(x => x.StartsWith(vCellHeader));
                            TempCount = nCount;
                            while (index > 0 && index > TempCount)
                            {
                                dCheck.Rows[dCheck.Rows.Count - 1][nCount] = null;
                                nCount++;
                                index--;
                            }
                        }
                        // Added By Sriram G
                        // Excel Cell Value Decimal Should be RoundOff 6 Digits
                        decimal dOutValue = 0.00M;
                        string strCellValue = GetValue(docSelected, cell);                        
                        dCheck.Rows[dCheck.Rows.Count - 1][nCount] = strCellValue;
                        nCount++;
                    }
                }

                TempRowCount++;
            }
            //if (HeaderorItems == "Header")//Header data
            //{
            //    dtHeaderData = dCheck;
            //}
            //else//Items data
            //{
            //    dtItemsData = dCheck;
            //}
            return dCheck;
        }
        private string GetValue(SpreadsheetDocument doc, Cell cell)
        {
            try
            {
                if (cell.DataType != null && cell.DataType.Value == CellValues.SharedString)
                {
                    return doc.WorkbookPart.SharedStringTablePart.SharedStringTable.ChildElements[(int.Parse(cell.CellValue.InnerText))].InnerText;
                    return null;
                }
                else
                if (cell.StyleIndex != null)
                {
                    CellFormat cf = doc.WorkbookPart.WorkbookStylesPart.Stylesheet.CellFormats.ChildElements[int.Parse(cell.StyleIndex.InnerText)] as CellFormat;
                    if (cf.NumberFormatId == 14)
                    {
                        if (cell.CellValue == null)
                        {
                            return null;
                        }
                        return DateTime.FromOADate(double.Parse(cell.CellValue.InnerText)).ToString("dd/MM/yyyy");
                    }
                    return cell.InnerText;
                }
                else
                {
                    return cell.InnerText;
                }
            }
            catch (NullReferenceException)
            {
                return null;
            }
            catch
            {
                throw;
            }
        }
        private Sheet GetSelectedSheet(IEnumerable<Sheet> Sheets)
        {
            foreach (Sheet sName in Sheets)
            {
                if (sName.Name == strSheetName)
                {
                    return sName;
                }
            }
            return null;
        }
        #region Sales Header Columns
        public static List<string> AddSalesHeaderColumnForExport(bool WithError)
        {
            if (!WithError)
            {
                return new List<string>()
        {
            "DOC ID *",
            "DOC DATE *",
            "BRANCH NAME *",
            "BEAT NAME",
            "SALESMAN NAME",
            "PARTY NAME *",
            "PAYMENT MODE *",
            "CREDIT TERM *",
            "ADDITIONAL DISCOUNT %",
            "TRADE DISCOUNT %",
            "FRIEGHT",
            "OTHER CHARGE %",
            "WRITEOFF AMT",
            "NET AMOUNT *",
            "STATUS *",
            "REMARKS",
            "TRANSPORT MODE",
            "TRANSPORT TYPE",
            "VECHICLE NUMBER",
            "TRANSPORT ID",
            "TRANSPORT NAME",
            "DISTANCE",
            "IRN",
            "ACKNOWLEDGE NO",
            "ACKNOWLEDGE DATE",
            "ACKNOWLEDGE STATUS",
            "SIGNED QRCODE",
            "EWAY BILL NO"
        };
            }
            else
            {
                return new List<string>()
        {
            "DOC ID *",
            "DOC DATE *",
            "BRANCH NAME *",
            "BEAT NAME",
            "SALESMAN NAME",
            "PARTY NAME *",
            "PAYMENT MODE *",
            "CREDIT TERM *",
            "ADDITIONAL DISCOUNT %",
            "TRADE DISCOUNT %",
            "FRIEGHT",
            "OTHER CHARGE %",
            "WRITEOFF AMT",
            "NET AMOUNT *",
            "STATUS *",
            "REMARKS",
            "TRANSPORT MODE",
            "TRANSPORT TYPE",
            "VECHICLE NUMBER",
            "TRANSPORT ID",
            "TRANSPORT NAME",
            "DISTANCE",
            "IRN",
            "ACKNOWLEDGE NO",
            "ACKNOWLEDGE DATE",
            "ACKNOWLEDGE STATUS",
            "SIGNED QRCODE",
            "EWAY BILL NO",
            "ERROR"
        };
            }
        }
        #endregion
        public static List<string> AddSalesHeaderColumnForExport_old(bool WithError)
        {
            if (!WithError)
            {
                return new List<string>()
            {
                "DOC ID *",   "DOC PREFIX *",   "BRANCH NAME *",   "DOC DATE *", "PARTY NAME *",    "PAYMENT MODE *", "CREDIT TERM *",  "ADDITIONAL DISCOUNT %",  "TRADE DISCOUNT %",   "FRIEGHT",  "OTHER CHARGE %", "NET AMOUNT *",   "STATUS *",   "BEAT NAME",    "SALESMAN NAME",    "WRITEOFF AMT", "TRANSACTION TYPE", "RETURN TYPE",  "REMARKS",
                "TRANSPORT MODE","TRANSPORT TYPE","VECHICLE NUMBER","TRANSPORT ID","TRANSPORT NAME","DISTANCE","IRN","ACKNOWLEDGE NO","ACKNOWLEDGE DATE","ACKNOWLEDGE STATUS","SIGNED QRCODE","EWAY BILL NO"
            };
            }
            else
            {
                return new List<string>()
            {
                "DOC ID *",   "DOC PREFIX *",   "BRANCH NAME *",   "DOC DATE *", "PARTY NAME *",    "PAYMENT MODE *", "CREDIT TERM *",  "ADDITIONAL DISCOUNT %",  "TRADE DISCOUNT %",   "FRIEGHT",  "OTHER CHARGE %", "NET AMOUNT *",   "STATUS *",   "BEAT NAME",    "SALESMAN NAME",    "WRITEOFF AMT", "TRANSACTION TYPE", "RETURN TYPE",  "REMARKS",
                "TRANSPORT MODE","TRANSPORT TYPE","VECHICLE NUMBER","TRANSPORT ID","TRANSPORT NAME","DISTANCE","IRN","ACKNOWLEDGE NO","ACKNOWLEDGE DATE","ACKNOWLEDGE STATUS","SIGNED QRCODE","EWAY BILL NO","ERROR"
            };
            }
        }
        #region Sales Detail Columns
        public static List<string> AddSalesDetailColumnForExport(bool WithError)
        {
            if (!WithError)
            {
                return new List<string>()
        {
            "DOC ID *",
            "PRODUCT NAME *",
            "BATCH NUMBER",
            "PKD DATE",
            "EXPIRY DATE",
            "QTY *",
            "PRICE *",
            "MRP *",
            "PRODUCT DISCOUNT",
            "TAX NAME *",
            "REASON NAME"
        };
            }
            else
            {
                return new List<string>()
        {
            "DOC ID *",
            "PRODUCT NAME *",
            "BATCH NUMBER",
            "PKD DATE",
            "EXPIRY DATE",
            "QTY *",
            "PRICE *",
            "MRP *",
            "PRODUCT DISCOUNT",
            "TAX NAME *",
            "REASON NAME",
            "ERROR"
        };
            }
        }
        #endregion
        #region Sales Return Header Columns
        public static List<string> AddSalesReturnHeaderColumnForExport(bool WithError)
        {
            if (!WithError)
            {
                return new List<string>()
        {
            "DOC ID *",
            "DOC DATE *",
            "BRANCH NAME *",
            "BEAT NAME",
            "SALESMAN NAME",
            "PARTY NAME *",
            "ADDITIONAL DISCOUNT %",
            "TRADE DISCOUNT %",
            "FRIEGHT",
            "OTHER CHARGE %",
            "WRITEOFF AMT",
            "NET AMOUNT *",
            "STATUS *",
            "TRANSACTION TYPE",
            "RETURN TYPE",
            "REMARKS",
            "TRANSPORT MODE",
            "TRANSPORT TYPE",
            "VECHICLE NUMBER",
            "TRANSPORT ID",
            "TRANSPORT NAME",
            "DISTANCE",
            "IRN",
            "ACKNOWLEDGE NO",
            "ACKNOWLEDGE DATE",
            "ACKNOWLEDGE STATUS",
            "SIGNED QRCODE",
            "EWAY BILL NO"
        };
            }
            else
            {
                return new List<string>()
        {
            "DOC ID *",
            "DOC DATE *",
            "BRANCH NAME *",
            "BEAT NAME",
            "SALESMAN NAME",
            "PARTY NAME *",
            "ADDITIONAL DISCOUNT %",
            "TRADE DISCOUNT %",
            "FRIEGHT",
            "OTHER CHARGE %",
            "WRITEOFF AMT",
            "NET AMOUNT *",
            "STATUS *",
            "TRANSACTION TYPE",
            "RETURN TYPE",
            "REMARKS",
            "TRANSPORT MODE",
            "TRANSPORT TYPE",
            "VECHICLE NUMBER",
            "TRANSPORT ID",
            "TRANSPORT NAME",
            "DISTANCE",
            "IRN",
            "ACKNOWLEDGE NO",
            "ACKNOWLEDGE DATE",
            "ACKNOWLEDGE STATUS",
            "SIGNED QRCODE",
            "EWAY BILL NO",
            "ERROR"
        };
            }
        }
        #endregion
        #region Sales Return Detail Columns
        public static List<string> AddSalesReturnDetailColumnForExport(bool WithError)
        {
            if (!WithError)
            {
                return new List<string>()
        {
            "DOC ID *",
            "PRODUCT NAME *",
            "BATCH NUMBER",
            "PKD DATE",
            "EXPIRY DATE",
            "QTY *",
            "PRICE *",
            "MRP *",
            "PRODUCT DISCOUNT",
            "TAX NAME *",
            "REASON NAME"
        };
            }
            else
            {
                return new List<string>()
        {
            "DOC ID *",
            "PRODUCT NAME *",
            "BATCH NUMBER",
            "PKD DATE",
            "EXPIRY DATE",
            "QTY *",
            "PRICE *",
            "MRP *",
            "PRODUCT DISCOUNT",
            "TAX NAME *",
            "REASON NAME",
            "ERROR"
        };
            }
        }
        #endregion
        #region Bill Header Columns
        public static List<string> AddBillHeaderColumnForExport(bool WithError)
        {
            if (!WithError)
            {
                return new List<string>()
        {
            "DOC ID *",
            "DOC DATE *",
            "BRANCH NAME *",
            "PARTY NAME *",
            "PAYMENT MODE *",
            "CREDIT TERM *",
            "ADDITIONAL DISCOUNT %",
            "TRADE DISCOUNT %",
            "FRIEGHT",
            "OTHER CHARGE %",
            "WRITEOFF AMT",
            "NET AMOUNT *",
            "STATUS *",
            "REMARKS",
            "TRANSPORT MODE",
            "TRANSPORT TYPE",
            "VECHICLE NUMBER",
            "TRANSPORT ID",
            "TRANSPORT NAME",
            "DISTANCE",
            "IRN",
            "ACKNOWLEDGE NO",
            "ACKNOWLEDGE DATE",
            "ACKNOWLEDGE STATUS",
            "SIGNED QRCODE",
            "EWAY BILL NO"
        };
            }
            else
            {
                return new List<string>()
        {
            "DOC ID *",
            "DOC DATE *",
            "BRANCH NAME *",
            "PARTY NAME *",
            "PAYMENT MODE *",
            "CREDIT TERM *",
            "ADDITIONAL DISCOUNT %",
            "TRADE DISCOUNT %",
            "FRIEGHT",
            "OTHER CHARGE %",
            "WRITEOFF AMT",
            "NET AMOUNT *",
            "STATUS *",
            "REMARKS",
            "TRANSPORT MODE",
            "TRANSPORT TYPE",
            "VECHICLE NUMBER",
            "TRANSPORT ID",
            "TRANSPORT NAME",
            "DISTANCE",
            "IRN",
            "ACKNOWLEDGE NO",
            "ACKNOWLEDGE DATE",
            "ACKNOWLEDGE STATUS",
            "SIGNED QRCODE",
            "EWAY BILL NO",
            "ERROR"
        };
            }
        }
        #endregion
        #region Bill Detail Columns
        public static List<string> AddBillDetailColumnForExport(bool WithError)
        {
            if (!WithError)
            {
                return new List<string>()
        {
            "DOC ID *",
            "PRODUCT NAME *",
            "BATCH NUMBER",
            "PKD DATE",
            "EXPIRY DATE",
            "ACTUAL QTY",
            "DAMAGE QTY",
            "FREE QTY",
            "PURCHASE PRICE",
            "SALE PRICE",
            "ECP PRICE",
            "SPL PRICE",
            "MRP",
            "RETURN PRICE",
            "PRODUCT DISCOUNT",
            "TAX NAME *",
            "REASON NAME"
        };
            }
            else
            {
                return new List<string>()
        {
            "DOC ID *",
            "PRODUCT NAME *",
            "BATCH NUMBER",
            "PKD DATE",
            "EXPIRY DATE",
            "ACTUAL QTY",
            "DAMAGE QTY",
            "FREE QTY",
            "PURCHASE PRICE",
            "SALE PRICE",
            "ECP PRICE",
            "SPL PRICE",
            "MRP",
            "RETURN PRICE",
            "PRODUCT DISCOUNT",
            "TAX NAME *",
            "REASON NAME",
            "ERROR"
        };
            }
        }
        #endregion
        #region Purchse Return Header Columns
        public static List<string> AddPurchaseReturnHeaderColumnForExport(bool WithError)
        {
            if (!WithError)
            {
                return new List<string>()
        {
            "DOC ID *",
            "DOC DATE *",
            "BRANCH NAME *",
            "PARTY NAME *",
            "ADDITIONAL DISCOUNT %",
            "TRADE DISCOUNT %",
            "FRIEGHT",
            "OTHER CHARGE %",
            "WRITEOFF AMT",
            "NET AMOUNT *",
            "STATUS *",
            "RETURN TYPE",
            "REMARKS",
            "TRANSPORT MODE",
            "TRANSPORT TYPE",
            "VECHICLE NUMBER",
            "TRANSPORT ID",
            "TRANSPORT NAME",
            "DISTANCE",
            "IRN",
            "ACKNOWLEDGE NO",
            "ACKNOWLEDGE DATE",
            "ACKNOWLEDGE STATUS",
            "SIGNED QRCODE",
            "EWAY BILL NO"
        };
            }
            else
            {
                return new List<string>()
        {
            "DOC ID *",
            "DOC DATE *",
            "BRANCH NAME *",
            "PARTY NAME *",
            "ADDITIONAL DISCOUNT %",
            "TRADE DISCOUNT %",
            "FRIEGHT",
            "OTHER CHARGE %",
            "WRITEOFF AMT",
            "NET AMOUNT *",
            "STATUS *",
            "RETURN TYPE",
            "REMARKS",
            "TRANSPORT MODE",
            "TRANSPORT TYPE",
            "VECHICLE NUMBER",
            "TRANSPORT ID",
            "TRANSPORT NAME",
            "DISTANCE",
            "IRN",
            "ACKNOWLEDGE NO",
            "ACKNOWLEDGE DATE",
            "ACKNOWLEDGE STATUS",
            "SIGNED QRCODE",
            "EWAY BILL NO",
            "ERROR"
        };
            }
        }
        #endregion
        #region Purchse Return Detail Columns
        public static List<string> AddPurchaseReturnDetailColumnForExport(bool WithError)
        {
            if (!WithError)
            {
                return new List<string>()
        {
            "DOC ID *",
            "PRODUCT NAME *",
            "BATCH NUMBER",
            "PKD DATE",
            "EXPIRY DATE",
            "ACTUAL QTY",
            "DAMAGE QTY",
            "FREE QTY",
            "PURCHASE PRICE",           
            "MRP",
            "PRODUCT DISCOUNT",
            "TAX NAME *",
            "REASON NAME"
        };
            }
            else
            {
                return new List<string>()
        {
            "DOC ID *",
            "PRODUCT NAME *",
            "BATCH NUMBER",
            "PKD DATE",
            "EXPIRY DATE",
            "ACTUAL QTY",
            "DAMAGE QTY",
            "FREE QTY",
            "PURCHASE PRICE",
            "SALE PRICE",
            "ECP PRICE",
            "SPL PRICE",
            "MRP",
            "RETURN PRICE",
            "PRODUCT DISCOUNT",
            "TAX NAME *",
            "REASON NAME",
            "ERROR"
        };
            }
        }
        #endregion
        public static List<string> AddSalesDetailColumnForExport_old(bool WithError)
        {
            if (!WithError)
            {
                return new List<string>()
            {
                "DOC ID *",   "PRODUCT NAME *", "BATCH NUMBER", "PKD DATE", "EXPIRY DATE",  "ACTUAL QTY",   "DAMAGE QTY",   "FREE QTY", "UOM PURCHASE PRICE",   "UOM SALE PRICE",   "UOM ECP PRICE",    "UOM SPL PRICE",    "UOM MRP PRICE",    "RETURN PRICE", "TAX NAME *", "PRODUCT DISCOUNT", "REASON NAME"
            };
            }
            else
            {
                return new List<string>()
            {
                "DOC ID *",   "PRODUCT NAME *", "BATCH NUMBER", "PKD DATE", "EXPIRY DATE",  "ACTUAL QTY",   "DAMAGE QTY",   "FREE QTY", "UOM PURCHASE PRICE",   "UOM SALE PRICE",   "UOM ECP PRICE",    "UOM SPL PRICE",    "UOM MRP PRICE",    "RETURN PRICE", "TAX NAME *", "PRODUCT DISCOUNT", "REASON NAME","ERROR"
            };
            }
        }
        
    }
}