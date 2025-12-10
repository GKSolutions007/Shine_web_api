using DocumentFormat.OpenXml.Drawing;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Spreadsheet;
using DocumentFormat.OpenXml.VariantTypes;
using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Http;
using System.Web.Http.ModelBinding.Binders;
using System.Windows.Forms;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class EInvoiceEwayController : ApiController
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
        [HttpGet]
        [Route("api/einvoiceeway/get")]
        public IHttpActionResult GetData(string TypeID, string Range, string FromDate, string ToDate)
        {
            string DocValue = "";
            if (!string.IsNullOrEmpty(Range))
            {
                DataTable dtRanges = bl.BL_StringSplitCommaHyphen(Range);

                for (int i = 0; i < dtRanges.Rows.Count; i++)
                {
                    DocValue += "'" + dtRanges.Rows[i][0].ToString() + "',";
                }
            }
            DataTable DDT = new DataTable();
            if (TypeID == "2")// E-Invoice
            {
                DDT = bl.BL_ExecuteParamSP("uspExportIRNData", 1, FromDate, ToDate, DocValue);
                string jsonparty = JsonConvert.SerializeObject(DDT);
                DDT = bl.BL_ExecuteParamSP("uspExportIRNData", 2, FromDate, ToDate, DocValue);
                string jsonpartyinfo = JsonConvert.SerializeObject(DDT);
                var EInvWayData = new
                {
                    Documents = jsonparty,
                    ProductInfo = jsonpartyinfo,
                };
                return Ok(EInvWayData);
            }
            else
            {
                DataTable dtResult = bl.BL_ExecuteParamSP("uspGetJsonDataforEWaybill", 2, 0, FromDate, ToDate, DocValue);
                if (dtResult.Rows.Count > 0)
                {
                    DDT = bl.BL_ExecuteParamSP("uspGetJsonDataforEWaybill", 5, 0, FromDate, ToDate, DocValue);
                    string jsonparty = JsonConvert.SerializeObject(DDT);
                    DDT = bl.BL_ExecuteParamSP("uspGetJsonDataforEWaybill", 6, 0, FromDate, ToDate, DocValue);
                    string jsonpartyinfo = JsonConvert.SerializeObject(DDT);
                    var EInvWayData = new
                    {
                        Documents = jsonparty,
                        ProductInfo = jsonpartyinfo,
                    };
                    return Ok(EInvWayData);
                }
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/einvoiceeway/getjson")]
        public IHttpActionResult GetJSONData(List<EInvoiceEwayModel> selectedData)
        {
            if(selectedData != null)
            {
                string txt = "";
                string TypeID = selectedData[0].TypeID;
                if(TypeID == "2")//E-Invoice
                {
                    txt = "[";
                    foreach (EInvoiceEwayModel items in selectedData)
                    {
                        string jsondata = "{" + '"' + "Version" + '"' + ":" + '"' + "1.1" + '"' + ',';
                        DataSet dtforJSON = new DataSet();
                        DataTable dt1 = bl.BL_ExecuteParamSP("uspGetDataforEInvoiceJSON", 1, items.DocID.ToString(), Convert.ToDateTime(items.DocDate.ToString()), items.DocType.ToString());
                        dt1.TableName = "TranDtls";
                        dtforJSON.Tables.Add(dt1);
                        DataTable dt2 = bl.BL_ExecuteParamSP("uspGetDataforEInvoiceJSON", 2, items.DocID.ToString(), Convert.ToDateTime(items.DocDate.ToString()), items.DocType.ToString());
                        dt2.TableName = "DocDtls";
                        dtforJSON.Tables.Add(dt2);
                        DataTable dt3 = bl.BL_ExecuteParamSP("uspGetDataforEInvoiceJSON", 3, items.DocID.ToString(), Convert.ToDateTime(items.DocDate.ToString()), items.DocType.ToString());
                        dt3.TableName = "SellerDtls";
                        dtforJSON.Tables.Add(dt3);
                        DataTable dt4 = bl.BL_ExecuteParamSP("uspGetDataforEInvoiceJSON", 4, items.DocID.ToString(), Convert.ToDateTime(items.DocDate.ToString()), items.DocType.ToString());
                        dt4.TableName = "BuyerDtls";
                        dtforJSON.Tables.Add(dt4);
                        DataTable dt5 = bl.BL_ExecuteParamSP("uspGetDataforEInvoiceJSON", 5, items.DocID.ToString(), Convert.ToDateTime(items.DocDate.ToString()), items.DocType.ToString());
                        dt5.TableName = "ValDtls";
                        dtforJSON.Tables.Add(dt5);
                        DataTable dt7 = bl.BL_ExecuteParamSP("uspGetDataforEInvoiceJSON", 7, items.DocID.ToString(), Convert.ToDateTime(items.DocDate.ToString()), items.DocType.ToString());
                        dt7.TableName = "EwbDtls";
                        dtforJSON.Tables.Add(dt7);
                        DataTable dt8 = bl.BL_ExecuteParamSP("uspGetDataforEInvoiceJSON", 8, items.DocID.ToString(), Convert.ToDateTime(items.DocDate.ToString()), items.DocType.ToString());
                        dt8.TableName = "ExpDtls";
                        dtforJSON.Tables.Add(dt8);
                        DataTable dt6 = bl.BL_ExecuteParamSP("uspGetDataforEInvoiceJSON", 6, items.DocID.ToString(), Convert.ToDateTime(items.DocDate.ToString()), items.DocType.ToString());
                        dt6.TableName = "ItemList";
                        dtforJSON.Tables.Add(dt6);
                        jsondata += '"' + "DispDtls" + '"' + ": null,";
                        jsondata += '"' + "ShipDtls" + '"' + ": null,";
                        //"Version": "1.1",
                        for (int i = 0; i < dtforJSON.Tables.Count; i++)
                        {
                            if (i == 5) // eway detail
                            {
                                if (string.IsNullOrEmpty(dtforJSON.Tables[i].Rows[0][2].ToString()))
                                {
                                    jsondata += '"' + "EwbDtls" + '"' + ": null,";
                                }
                                else
                                {
                                    string objdata = DataTableToJSONWithJSONNet(dtforJSON.Tables[i]);
                                    //jsondata += objdata;
                                    string d = '"' + dtforJSON.Tables[i].TableName + '"' + ":" + (dtforJSON.Tables[i].Rows.Count > 1 || i == 7 ? objdata : objdata.Remove(0, 1));
                                    d = (dtforJSON.Tables[i].Rows.Count > 1 || i == 7 ? d : d.Remove(d.Length - 1, 1) + ",");
                                    jsondata += d;
                                }
                            }
                            else
                            {
                                string objdata = DataTableToJSONWithJSONNet(dtforJSON.Tables[i]);
                                //jsondata += objdata;
                                string d = '"' + dtforJSON.Tables[i].TableName + '"' + ":" + (dtforJSON.Tables[i].Rows.Count > 1 || i == 7 ? objdata : objdata.Remove(0, 1));
                                d = (dtforJSON.Tables[i].Rows.Count > 1 || i == 7 ? d : d.Remove(d.Length - 1, 1) + ",");
                                jsondata += d;
                            }
                        }
                        txt += jsondata + "},";
                    }
                }
                else//E-Way
                {
                    DataTable dtverinfo = bl.BL_ExecuteParamSP("uspGetJsonDataforEWaybill", 1, 0);
                    txt = "{" + '"' + dtverinfo.Rows[0][0].ToString() + '"' + ":" + '"' + dtverinfo.Rows[0][1].ToString() + '"' + ',' + '"' + "billLists" + '"' + ':' + '[';
                    foreach (EInvoiceEwayModel items in selectedData)
                    {
                        string jsondata = "";
                        DataSet dtforJSON = new DataSet();
                        DataTable dt1 = bl.BL_ExecuteParamSP("uspGetJsonDataforEWaybill", 3, items.DocID.ToString());
                        dt1.TableName = "billLists";
                        dtforJSON.Tables.Add(dt1);
                        DataTable dt2 = bl.BL_ExecuteParamSP("uspGetJsonDataforEWaybill", 4, items.DocID.ToString());
                        dt2.TableName = "itemList";
                        //dt2.Columns.Remove("docNo");
                        dtforJSON.Tables.Add(dt2);
                        for (int j = 0; j < dtforJSON.Tables.Count; j++)
                        {
                            string objdata = DataTableToJSONWithJSONNet(dtforJSON.Tables[j]);
                            //jsondata += objdata;
                            string d = j == 1 ? '"' + dtforJSON.Tables[j].TableName + '"' + ":" + (dtforJSON.Tables[j].Rows.Count > 1 || j == 1 ? objdata : objdata.Remove(0, 1)) : objdata.Remove(0, 1);
                            d = (dtforJSON.Tables[j].Rows.Count > 1 || j == 1 ? d : d.Remove(d.Length - 8) + ",");
                            jsondata += d;
                            if (objdata != null)
                            {
                                //MessageBox.Show("data getting");
                            }
                        }
                        txt += jsondata + "},";
                    }
                }
                string fintxt = txt.Remove(txt.Length - 1, 1) + (TypeID == "2" ? "]" : "]}") ;
                txt = fintxt;// txt.Remove(txt.Length - 1, 1)+ "]";
                string FPt = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"];
                string JsonDirectory = FPt + (TypeID == "2" ? "\\json\\eInvoice\\" : "\\json\\eWay\\");
                if (!Directory.Exists(JsonDirectory))
                {
                    Directory.CreateDirectory(JsonDirectory);
                }
                string fileName = (TypeID == "2" ? "eInvoice_Json_" : "eWay_JSON_") + DateTime.Now.ToString("yyyMMddhhmmss") + ".json";
                string path = JsonDirectory + fileName;
                File.WriteAllText(path, txt);
                List<ImportResults> MTM = new List<ImportResults>();
                var sDocument = path;
                MTM.Add(new ImportResults()
                {
                    ID = "0",
                    Msg = "Json File Generated.",
                    FileName = fileName,
                    FilePath = path,
                });                
                return Ok(MTM);
            }
            return Ok();            
        }
        public string DataTableToJSONWithJSONNet(DataTable table)
        {
            string JSONString = string.Empty;

            JSONString = JsonConvert.SerializeObject(table, Formatting.Indented);

            return JSONString;
        }
        [System.Web.Http.HttpGet]
        [System.Web.Http.Route("api/downloadjsondata")]
        public HttpResponseMessage downloadjsondata(string FPath, string FName)
        {
            DataTable dt = new DataTable();
            //OpenTemplate(ImpDataTemp());
            //var sDocument = FPath;
            //byte[] fileBytes = System.IO.File.ReadAllBytes(sDocument);
            //string fileName = FName;
            var sDocument = FPath;
            byte[] fileBytes = System.IO.File.ReadAllBytes(sDocument);
            string fileName = FName;
            //return File(fileBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
            if (!File.Exists(FPath))
                return new HttpResponseMessage(HttpStatusCode.NotFound);

            var result = new HttpResponseMessage(HttpStatusCode.OK);
            var stream = new FileStream(FPath, FileMode.Open, FileAccess.Read);
            result.Content = new StreamContent(stream);
            result.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json");
            result.Content.Headers.ContentDisposition = new ContentDispositionHeaderValue("attachment")
            {
                FileName = fileName
            };
            return result;
            //return File(fileBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
        }
        [System.Web.Http.HttpPost]
        [System.Web.Http.Route("api/einvoiceeway/uploadjsonfile")]
        public IHttpActionResult LoadSelectFiledata()
        {
            string Msg = "";
            string dt = "";
            List<ImportResults> MTM = new List<ImportResults>();
            try
            {
                var file = HttpContext.Current.Request.Files.Count > 1 ? HttpContext.Current.Request.Files[0] : null;
                //var data = Request.Files[0].InputStream.Read;                                                       
                if (HttpContext.Current.Request.Files.Count > 0)
                {
                    string TransID = HttpContext.Current.Request.Files.AllKeys[0].ToString();
                    string TransName = HttpContext.Current.Request.Files.AllKeys[1].ToString();
                    string fileName = HttpContext.Current.Request.Files[2].FileName;
                    string fileContentType = HttpContext.Current.Request.Files[2].ContentType;
                    string FPt = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"];
                    strFilePath = FPt + "Upload json files\\";
                    strFileName = TransName + "_Upload_" + fileName;
                    if (!Directory.Exists(strFilePath))
                    {
                        Directory.CreateDirectory(strFilePath);
                    }
                    HttpContext.Current.Request.Files[2].SaveAs(strFilePath + strFileName);
                    bool blResult = true;
                    int EwayMode = 1;
                    List<string> lst = null;
                    if (TransID == "1")//E-Way
                    {
                        EwayMode = 1;
                        lst = AddEWBImport();
                    }
                    if (TransID == "2")//E-Invoice
                    {
                        lst = AddIRNExport();
                    }
                    bool ErrorColAlreadyExisist = false;
                    ColumnValidation(lst, ref blResult);
                    if (!blResult)
                    {
                        if (TransID == "1")//E-Way
                        {
                            EwayMode = 2;
                            lst = AddEWBImportfromReport();
                        }
                        if (TransID == "2")//E-Invoice
                        {
                            lst = AddEWBImportfromReport();
                        }
                        ColumnValidation(lst, ref blResult);
                        ErrorColAlreadyExisist = true;
                    }
                    if (blResult)
                    {
                        if (TransID == "1")//E-Way
                        {
                            
                            if (dtData.Rows.Count > 0)
                            {
                                if (EwayMode == 2)
                                {
                                    DataRow[] drAct = dtData.Select("status = 'Active'", null);
                                    dtResult = drAct.CopyToDataTable();
                                }
                                else
                                {
                                    dtResult = dtData;
                                }
                                string DocNocols = "", DocDateCols = "";
                                for (int i = 0; i < dtResult.Rows.Count; i++)
                                {
                                    if (dtResult.Columns.Contains("Doc.No"))
                                    {
                                        DocNocols = "Doc.No";
                                        DocDateCols = "Doc.Date";
                                    }
                                    else
                                    {
                                        DocNocols = "Doc No";
                                        DocDateCols = "Doc Date";
                                    }
                                    DataTable dtE = bl.BL_ExecuteParamSP("uspUpdateEWBImport", dtResult.Rows[i][DocNocols].ToString(),
                                               bl.BL_ChangeDateFormat(dtResult.Rows[i][DocDateCols].ToString(), 1),
                                               dtResult.Rows[i]["EWB No"].ToString(),null);
                                }
                                Msg = "0";// saved
                            }
                            else
                            {
                                Msg = "1";// no data
                            }
                        }
                        else if (TransID == "2")//E-Invoice
                        {
                            if (dtData.Rows.Count > 0)
                            {
                                dtResult = dtData;
                                string EwayColumn = "", SignQRColumn = "", DocType = "", eWayno = "" ;
                                for (int i = 0; i < dtResult.Rows.Count; i++)
                                {
                                    if (dtResult.Columns.Contains("EWB No./ If Any Errors While Creating EWB."))
                                    {
                                        EwayColumn = "EWB No./ If Any Errors While Creating EWB.";
                                        SignQRColumn = "Signed QR Code";
                                        DocType = "Doc Typ";
                                    }
                                    else
                                    {
                                        EwayColumn = "Eway Bill No.";
                                        SignQRColumn = "SignedQrCOde";
                                        DocType = "Doc Type";
                                    }
                                    if (!string.IsNullOrEmpty(Convert.ToString(dtResult.Rows[i][EwayColumn].ToString())))
                                    {
                                        string splitbyspace = Convert.ToString(dtResult.Rows[i][EwayColumn].ToString());
                                        string[] spt = splitbyspace.Split(' ');
                                        eWayno = spt[0].ToString();
                                    }                                  

                                    DataTable dtE = bl.BL_ExecuteParamSP("uspUpdateIRNImport", dtResult.Rows[i]["Doc No"].ToString(),
                                               bl.BL_ChangeDateFormat(dtResult.Rows[i]["Doc Date"].ToString(), 1),
                                               dtResult.Rows[i]["IRN"].ToString(), dtResult.Rows[i]["Ack No"].ToString(),
                                               !string.IsNullOrEmpty(Convert.ToString(dtResult.Rows[i]["Ack Date"].ToString())) ?
                                               Convert.ToDateTime(dtResult.Rows[i]["Ack Date"].ToString()) :
                                               Convert.ToDateTime(dtResult.Rows[i]["Doc Date"].ToString()), 
                                               dtResult.Rows[i]["Status"].ToString(),
                                               dtResult.Rows[i][SignQRColumn].ToString(),
                                                eWayno,
                                                dtResult.Rows[i][DocType].ToString());
                                }
                                Msg = "0";// saved
                            }
                            else
                            {
                                Msg = "1";// no data
                            }
                        }
                    }
                    else
                    {
                        Msg = "2";// column names mismatching
                    }
                }
            }
            catch
            {

            }           
            return Ok(Msg);
        }

        [HttpPost]
        [Route("api/einvoiceeway/updateewayinfo")]
        public IHttpActionResult UpdateEwayData(List<EInvoiceEwayModel> selectedData)
        {
            if(selectedData != null)
            {
                string DocValue = "";
                if (!string.IsNullOrEmpty(selectedData[0].DocRange))
                {
                    DataTable dtRanges = bl.BL_StringSplitCommaHyphen(selectedData[0].DocRange);

                    for (int i = 0; i < dtRanges.Rows.Count; i++)
                    {
                        DocValue += "'" + dtRanges.Rows[i][0].ToString() + "',";
                    }
                    string Doc = DocValue.Remove(DocValue.Length - 1);
                    bl.BL_ExecuteParamSP("uspUpdateEwayInTrans", 2, Doc, selectedData[0].VehicleNo, selectedData[0].Distance,
                                                    selectedData[0].TransportMode, selectedData[0].TransportType, selectedData[0].TransactionID,
                                                     selectedData[0].TransactionName);
                }
            }
            return Ok();
        }    

        public void ColumnValidation(List<string> lst, ref bool blResult)
        {
            try
            {
                blResult = true;
                List<string> lstdtColumn = new List<string>();
                string ffp = strFilePath + strFileName;
                SpreadsheetDocument docSelected = SpreadsheetDocument.Open(strFilePath + strFileName, false);
                IEnumerable<Sheet> AllSheet = docSelected.WorkbookPart.Workbook.Descendants<Sheet>();
                strSheetName = AllSheet.FirstOrDefault()?.Name;
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
                        GetTable(docSelected, rows);
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
        }
        public void GetTable(SpreadsheetDocument docSelected, IEnumerable<Row> rows)
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
            dtData = dCheck;
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
        
        public static List<string> AddEWBImport()
        {
            return new List<string>()
                    {
                        "SlNo",
                        "Supply Type",
                        "Doc No",
                        "Doc Date",
                        "Other Party Gstin",
                        "Supply State",
                        "Vehicle No",
                        "No of Items",
                        "EWB No",
                        "EWD Date",
                        "Valid Till Date",
                        "Errors",
                        "Alerts",
                    };
        }
        public static List<string> AddEWBImportfromReport()
        {
            return new List<string>()
                    {
                       "EWB No",
                        "EWB Date",
                        "Supply Type",
                        "Doc.No",
                        "Doc.Date",
                        "Doc.Type",
                        "Other Party GSTIN",
                        "Transporter Details",
                        "From GSTIN Info",
                        "TO GSTIN Info",
                        "status",
                        "No of Items",
                        "Main HSN Code",
                        "Main HSN Desc",
                        "Assessable Value",
                        "SGST Value",
                        "CGST Value",
                        "IGST Value",
                        "CESS Value",
                        "CESS Non.Advol Value",
                        "Other Value",
                        "Total Invoice Value",
                        "Valid Till Date",
                        "Mode of Generation",
                        "Cancelled By",
                        "Cancelled Date",
                        "IRN"
                    };
        }
        public static List<string> AddIRNExport()
        {
            return new List<string>()
                    {
                        "Sl. No",
                        "IRN",
                        "Ack No",
                        "Ack Date",
                        "Doc No",
                        "Doc Typ",
                        "Doc Date",
                        "Inv Value.",
                        "Recipient GSTIN",
                        "Status",
                        "Signed QR Code",
                        "EWB No./ If Any Errors While Creating EWB."
                    };
        }

        public static List<string> AddIRNExportfromReport()
        {
            return new List<string>()
                    {
                        "Sl. No",
                        "Ack No",
                        "Ack Date",
                        "Doc No",
                        "Doc Date",
                        "Doc Type",
                        "Inv Value.",
                        "Recipient GSTIN",
                        "Status",
                        "IRN",
                        "SignedQrCOde",
                        "Eway Bill No."
                    };
        }
    }
}
