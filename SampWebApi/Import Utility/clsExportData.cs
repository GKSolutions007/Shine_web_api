using ClosedXML.Excel;
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.IO;
using System.Linq;
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
                            ColorExcel(worKsheeT, nExcelRow, nExcelColumn, Color.Yellow, Color.Black);
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
                            ColorExcel(worKsheeT, nExcelRow, nExcelColumn, System.Drawing.Color.SteelBlue, Color.White);
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
        private static void ColorExcel(Microsoft.Office.Interop.Excel.Worksheet worKsheeT, int nExcelRow, int nExcelColumn, Color ColorName, Color FontColor)
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
                using (XLWorkbook wb = new XLWorkbook())
                {
                    wb.Worksheets.Add(dtHeader, "Header");
                    wb.Worksheets.Add(dtDetail, "Detail");
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

        public static List<string> AddSalesHeaderColumnForExport(bool WithError)
        {
            if (!WithError)
            {
                return new List<string>()
            {
                "DOC ID",   "DOC PREFIX",   "BRANCH",   "DOC DATE", "PARTY NAME",   "TAX TYPE NAME",    "PAYMENT MODE", "CREDIT TERM",  "ADDITIONAL DISCOUNT",  "TRADE DISCOUNT",   "FRIEGHT",  "OTHER CHARGE", "NET AMOUNT",   "STATUS",   "BEAT NAME",    "SALESMAN NAME",    "WRITEOFF AMT", "TRANSACTION TYPE", "RETURN TYPE",  "REMARKS",  "TRANSMODE",    "VEHICLETYPE",  "VECHICLE NUMBER",  "TRANSPORTID",  "TRANSPORTNAME",    "IRN",  "ACKNO",    "ACKDATE",  "ACKSTATUS",    "SIGNEDQRCODE", "EWBNO"
            };
            }
            else
            {
                return new List<string>()
            {
                "DOC ID",   "DOC PREFIX",   "BRANCH",   "DOC DATE", "PARTY NAME",   "TAX TYPE NAME",    "PAYMENT MODE", "CREDIT TERM",  "ADDITIONAL DISCOUNT",  "TRADE DISCOUNT",   "FRIEGHT",  "OTHER CHARGE", "NET AMOUNT",   "STATUS",   "BEAT NAME",    "SALESMAN NAME",    "WRITEOFF AMT", "TRANSACTION TYPE", "RETURN TYPE",  "REMARKS",  "TRANSMODE",    "VEHICLETYPE",  "VECHICLE NUMBER",  "TRANSPORTID",  "TRANSPORTNAME",    "IRN",  "ACKNO",    "ACKDATE",  "ACKSTATUS",    "SIGNEDQRCODE", "EWBNO","ERROR"
            };
            }
        }

        public static List<string> AddSalesDetailColumnForExport(bool WithError)
        {
            if (!WithError)
            {
                return new List<string>()
            {
                "DOC ID",   "PRODUCT NAME", "BATCH NUMBER", "PKD DATE", "EXPIRY DATE",  "ACTUAL QTY",   "DAMAGE QTY",   "FREE QTY", "UOM PURCHASE PRICE",   "UOM SALE PRICE",   "UOM ECP PRICE",    "UOM SPL PRICE",    "UOM MRP PRICE",    "RETURN PRICE", "TAX NAME", "PRODUCT DISCOUNT", "REASON NAME"
            };
            }
            else
            {
                return new List<string>()
            {
                "DOC ID",   "PRODUCT NAME", "BATCH NUMBER", "PKD DATE", "EXPIRY DATE",  "ACTUAL QTY",   "DAMAGE QTY",   "FREE QTY", "UOM PURCHASE PRICE",   "UOM SALE PRICE",   "UOM ECP PRICE",    "UOM SPL PRICE",    "UOM MRP PRICE",    "RETURN PRICE", "TAX NAME", "PRODUCT DISCOUNT", "REASON NAME","ERROR"
            };
            }
        }
        public static List<string> AddSalesSerialInfoColumnForExport(bool WithError)
        {
            if (!WithError)
            {
                return new List<string>()
            {
                "DOC ID",
                "PRODUCT NAME",
                "SERIAL"
            };
            }
            else
            {
                return new List<string>()
            {
                "DOC ID",
                "PRODUCT NAME",
                "SERIAL","ERROR"
            };
            }
        }
    }
}