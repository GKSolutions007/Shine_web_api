using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Web;
using NPOI.HSSF.UserModel;
using NPOI.SS.UserModel;
using NPOI.XSSF.UserModel;
using SampWebApi.BuisnessLayer;
namespace SampWebApi.Printing
{
    public class clsExcelOpenreadwrite
    {
        public string strSheetName { get; set; }
        public string strExtension = ".xlsx";
        public string strFileName = "";
        public string strFilePath
        {
            get; set;
        }
        public DataTable dtData { get; set; }
        public DataTable dtResult { get; set; }
        clsBusinessLayer bl = new clsBusinessLayer();

        public void ColumnValidation(List<string> lst, ref bool blResult)
        {
            try
            {
                blResult = true;

                string filePath = Path.Combine(strFilePath, strFileName);
                string extension = Path.GetExtension(filePath);

                // --- Step 1: detect fake ".xls" files that are really HTML (common with
                // ASP.NET GridView "export to Excel" buttons) ---
                if (IsHtmlDisguisedAsExcel(filePath))
                {
                    DataTable dtHtml = ReadHtmlTableAsDataTable(filePath);
                    ValidateAndAssign(lst, dtHtml, ref blResult);
                    return;
                }

                // --- Step 2: genuine binary/zip Excel files ---
                IWorkbook workbook;

                using (FileStream fs = new FileStream(
                    filePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                {
                    if (extension.Equals(".xls", StringComparison.OrdinalIgnoreCase))
                    {
                        workbook = new HSSFWorkbook(fs);
                    }
                    else if (extension.Equals(".xlsx", StringComparison.OrdinalIgnoreCase))
                    {
                        workbook = new XSSFWorkbook(fs);
                    }
                    else
                    {
                        throw new Exception("Only .xls and .xlsx files are supported.");
                    }
                }

                ISheet sheet = workbook.GetSheetAt(0);
                if (sheet == null) { blResult = false; return; }

                strSheetName = sheet.SheetName;

                IRow headerRow = sheet.GetRow(0);
                if (headerRow == null) { blResult = false; return; }

                List<string> lstdtColumn = new List<string>();
                for (int i = 0; i < headerRow.LastCellNum; i++)
                {
                    ICell cell = headerRow.GetCell(i, MissingCellPolicy.CREATE_NULL_AS_BLANK);
                    string value = GetValue(workbook, cell);
                    lstdtColumn.Add(value);
                }

                if (lst.Count != lstdtColumn.Count) blResult = false;

                foreach (string str in lst)
                {
                    if (!lstdtColumn.Contains(str)) { blResult = false; break; }
                }

                if (blResult) GetTable(workbook, sheet);
            }
            catch (IOException) { throw; }
            catch (Exception) { throw; }
        }

        /// <summary>
        /// Checks whether a file claiming to be .xls/.xlsx is actually an HTML table
        /// (e.g. exported from an ASP.NET GridView with Response.ContentType = "application/vnd.ms-excel").
        /// </summary>
        private bool IsHtmlDisguisedAsExcel(string filePath)
        {
            // A real .xls (OLE2/CFBF) file starts with the magic bytes D0 CF 11 E0 A1 B1 1A E1.
            // A real .xlsx (ZIP) file starts with "PK".
            // Anything else — especially text starting with "<" — is not a genuine Excel binary.
            byte[] header = new byte[8];
            using (FileStream fs = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            {
                int read = fs.Read(header, 0, header.Length);
                if (read < 4) return false;
            }

            byte[] ole2Signature = { 0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1 };
            bool isOle2 = true;
            for (int i = 0; i < 8 && i < header.Length; i++)
            {
                if (header[i] != ole2Signature[i]) { isOle2 = false; break; }
            }

            bool isZip = header.Length >= 2 && header[0] == (byte)'P' && header[1] == (byte)'K';

            return !isOle2 && !isZip;
        }

        /// <summary>
        /// Parses an HTML table (GridView export) into a DataTable using HtmlAgilityPack.
        /// Install via NuGet: Install-Package HtmlAgilityPack
        /// </summary>
        private DataTable ReadHtmlTableAsDataTable(string filePath)
        {
            var doc = new HtmlAgilityPack.HtmlDocument();
            doc.Load(filePath);

            var table = doc.DocumentNode.SelectSingleNode("//table");
            if (table == null)
                throw new Exception("File could not be parsed as a valid Excel or HTML table file.");

            var dt = new DataTable();

            var rows = table.SelectNodes(".//tr");
            if (rows == null || rows.Count == 0)
                throw new Exception("No rows found in the uploaded file.");

            // Header row (th, or first tr's td if no th present)
            var headerCells = rows[0].SelectNodes(".//th");
            if (headerCells == null)
                headerCells = rows[0].SelectNodes(".//td");

            foreach (var cell in headerCells)
            {
                string colName = System.Net.WebUtility.HtmlDecode(cell.InnerText.Trim());
                // Avoid duplicate column name errors
                string uniqueName = colName;
                int suffix = 1;
                while (dt.Columns.Contains(uniqueName))
                    uniqueName = colName + "_" + suffix++;
                dt.Columns.Add(uniqueName);
            }

            strSheetName = "Sheet1"; // no real sheet name in HTML export

            // Data rows
            for (int r = 1; r < rows.Count; r++)
            {
                var cells = rows[r].SelectNodes(".//td");
                if (cells == null) continue;

                DataRow dr = dt.NewRow();
                for (int c = 0; c < cells.Count && c < dt.Columns.Count; c++)
                {
                    string val = System.Net.WebUtility.HtmlDecode(cells[c].InnerText.Trim());
                    dr[c] = val.Replace("&nbsp;", "").Trim();
                }
                dt.Rows.Add(dr);
            }

            return dt;
        }

        /// <summary>
        /// Shared column validation logic against a DataTable (used by the HTML path).
        /// </summary>
        private void ValidateAndAssign(List<string> lst, DataTable dt, ref bool blResult)
        {
            if (dt == null || dt.Columns.Count == 0) { blResult = false; return; }

            List<string> lstdtColumn = dt.Columns.Cast<DataColumn>()
                                                  .Select(c => c.ColumnName)
                                                  .ToList();

            if (lst.Count != lstdtColumn.Count) blResult = false;

            foreach (string str in lst)
            {
                if (!lstdtColumn.Contains(str)) { blResult = false; break; }
            }

            if (blResult)
            {
                dtResult = dt; // assign directly instead of NPOI's GetTable(...)
                dtData = dt;
            }
        }
        public void ColumnValidation_OLDER(List<string> lst, ref bool blResult)
        {
            try
            {
                blResult = true;

                string filePath = Path.Combine(strFilePath, strFileName);

                IWorkbook workbook;

                using (FileStream fs = new FileStream(
                    filePath,
                    FileMode.Open,
                    FileAccess.Read,
                    FileShare.ReadWrite))
                {
                    string extension = Path.GetExtension(filePath);
                    // Reset stream after header check
                    fs.Position = 0;
                    if (extension.Equals(".xls", StringComparison.OrdinalIgnoreCase))
                    {
                        workbook = new HSSFWorkbook(fs);
                        //workbook = WorkbookFactory.Create(fs);
                    }
                    else if (extension.Equals(".xlsx", StringComparison.OrdinalIgnoreCase))
                    {
                        workbook = new XSSFWorkbook(fs);
                    }
                    else
                    {
                        throw new Exception("Only .xls and .xlsx files are supported.");
                    }
                }

                ISheet sheet = workbook.GetSheetAt(0);

                if (sheet == null)
                {
                    blResult = false;
                    return;
                }

                strSheetName = sheet.SheetName;

                // Get header row
                IRow headerRow = sheet.GetRow(0);

                if (headerRow == null)
                {
                    blResult = false;
                    return;
                }

                List<string> lstdtColumn = new List<string>();

                for (int i = 0; i < headerRow.LastCellNum; i++)
                {
                    ICell cell = headerRow.GetCell(
                        i,
                        MissingCellPolicy.CREATE_NULL_AS_BLANK);

                    string value = GetValue(workbook, cell);

                    lstdtColumn.Add(value);
                }

                // Verify Columns Count
                if (lst.Count != lstdtColumn.Count)
                {
                    blResult = false;
                }

                // Verify Column Names
                foreach (string str in lst)
                {
                    if (!lstdtColumn.Contains(str))
                    {
                        blResult = false;
                        break;
                    }
                }

                // Read table data
                if (blResult)
                {
                    GetTable(workbook, sheet);
                }
            }
            catch (IOException)
            {
                throw;
            }
            catch (Exception)
            {
                throw;
            }
        }
        private string GetValue(IWorkbook workbook, ICell cell)
        {
            try
            {
                if (cell == null)
                    return null;

                if (cell.CellType == CellType.Blank)
                    return null;

                if (cell.CellType == CellType.String)
                {
                    return cell.StringCellValue;
                }

                if (cell.CellType == CellType.Numeric)
                {
                    if (DateUtil.IsCellDateFormatted(cell))
                    {
                        return Convert.ToDateTime(cell.DateCellValue).ToString("dd/MM/yyyy");
                    }

                    return cell.NumericCellValue.ToString();
                }

                if (cell.CellType == CellType.Boolean)
                {
                    return cell.BooleanCellValue.ToString();
                }

                if (cell.CellType == CellType.Formula)
                {
                    switch (cell.CachedFormulaResultType)
                    {
                        case CellType.String:
                            return cell.StringCellValue;

                        case CellType.Numeric:

                            if (DateUtil.IsCellDateFormatted(cell))
                            {
                                return Convert.ToDateTime(cell.DateCellValue).ToString("dd/MM/yyyy");
                            }

                            return cell.NumericCellValue.ToString();

                        case CellType.Boolean:
                            return cell.BooleanCellValue.ToString();

                        default:
                            return cell.ToString();
                    }
                }

                return cell.ToString();
            }
            catch
            {
                throw;
            }
        }
        public void GetTable(IWorkbook workbook, ISheet sheet)
        {
            DataTable dCheck = new DataTable();

            if (sheet == null)
            {
                dtData = dCheck;
                return;
            }

            IRow headerRow = sheet.GetRow(0);

            if (headerRow == null)
            {
                dtData = dCheck;
                return;
            }

            int columnCount = headerRow.LastCellNum;

            if (columnCount <= 0)
            {
                dtData = dCheck;
                return;
            }

            // -----------------------------------
            // Add Header Columns
            // -----------------------------------

            for (int i = 0; i < columnCount; i++)
            {
                ICell cell = headerRow.GetCell(
                    i,
                    MissingCellPolicy.CREATE_NULL_AS_BLANK);

                string columnName = GetValue(workbook, cell);

                if (string.IsNullOrWhiteSpace(columnName))
                {
                    columnName = "Column" + (i + 1);
                }

                // Avoid duplicate DataTable column names
                string originalName = columnName;
                int duplicateCount = 1;

                while (dCheck.Columns.Contains(columnName))
                {
                    columnName = originalName + "_" + duplicateCount;
                    duplicateCount++;
                }

                dCheck.Columns.Add(columnName);
            }

            // -----------------------------------
            // Read Data Rows
            // -----------------------------------

            for (int rowIndex = 1; rowIndex <= sheet.LastRowNum; rowIndex++)
            {
                IRow row = sheet.GetRow(rowIndex);

                if (row == null)
                    continue;

                DataRow dataRow = dCheck.NewRow();

                for (int colIndex = 0; colIndex < columnCount; colIndex++)
                {
                    ICell cell = row.GetCell(
                        colIndex,
                        MissingCellPolicy.CREATE_NULL_AS_BLANK);

                    dataRow[colIndex] = GetValue(workbook, cell) ?? "";
                }

                dCheck.Rows.Add(dataRow);
            }

            dtData = dCheck;
        }
    }
}