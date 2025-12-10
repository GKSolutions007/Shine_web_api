using ClosedXML.Excel;
using DocumentFormat.OpenXml.Office2010.ExcelAc;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Spreadsheet;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
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
using System.Web.Http.Cors;
using System.Web.Mvc;
using System.Web.Routing;
using WebGrease.Activities;

namespace SampWebApi.Controllers
{
    public class ImportexportController : ApiController
    {
        clsBusinessLayer objBL = new clsBusinessLayer();
        public string strSheetName { get; set; }
        public int BranchID { get; set; }
        public int VendorID { get; set; }
        public int CustomerID { get; set; }
        public int PriceTypeID { get; set; }
        public int TaxTypeID { get; set; }
        public int ProductID { get; set; }
        public int BeatID { get; set; }
        public int SalesmanID { get; set; }
        public int TaxID { get; set; }
        public int UOMID { get; set; }
        public decimal TaxPern { get; set; }
        public string strExtension = ".xlsx";
        public string strFileName = "";
        public string strFilePath
        {
            get; set;
        }
        public DataTable dtData { get; set; }
        public DataTable dtHeaderData { get; set; }
        public DataTable dtItemsData { get; set; }
        [System.Web.Http.HttpPost]
        [System.Web.Http.Route("api/uploadimportfile")]
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
                    string UserID = HttpContext.Current.Request.Files.AllKeys[2].ToString();
                    //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Upload Files\\";
                    string FPt = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"];
                    strFilePath = FPt + "Upload Files\\";
                    strFileName = TransName + "_Upload_" + fileName;
                    if (!Directory.Exists(strFilePath))
                    {
                        Directory.CreateDirectory(strFilePath);
                    }
                    HttpContext.Current.Request.Files[3].SaveAs(strFilePath + strFileName);
                    bool blResult = true;
                    List<string> lst = null;
                    #region Validate Columns
                    if (TransID == "3")//PO
                    {
                        lst = POImpDataTemp();
                    }
                    if (TransID == "1")//Customer
                    {
                        lst = CustomerMasterTemp();
                    }
                    if (TransID == "2")//Product
                    {
                        lst = ProductMasterTemp();
                    }
                    if (TransID == "4")//Price Change
                    {
                        lst = PrichangeTemp();
                    }
                    if (TransID == "5")//order taken
                    {
                        lst = OrderTakenTemp();
                    }
                    if (TransID == "6") // trans price
                    {
                        lst = TransactonPricesTemp();
                    }
                    if (TransID == "7") // beat saleman map
                    {
                        lst = BeatSalesmanMappingTemp();
                    }
                    if (TransID == "8") // customer remark
                    {
                        lst = CustomerRemarksTemp();
                    }
                    if (TransID == "10") // Product Open import
                    {
                        lst = ProductOpenImportTemp();
                    }
                    bool ErrorColAlreadyExisist = false;
                    ColumnValidation(lst, ref blResult);
                    if (!blResult)
                    {
                        if (TransID == "3")//PO
                        {
                            lst = POImpDataTempWithErrCol();
                        }
                        if (TransID == "1")//Customer
                        {
                            lst = CustomerMasterTempWithErrCol();
                        }
                        if (TransID == "2")//Product
                        {
                            lst = ProductMasterTempWithErrCol();
                        }
                        if (TransID == "4")//Price Change
                        {
                            lst = PrichangeTempWithErrCol();
                        }
                        if (TransID == "5")//order taken
                        {
                            lst = OrderTakenTempWithErrCol();
                        }
                        if (TransID == "6") // trans price
                        {
                            lst = TransactonPricesTempWithErrCol();
                        }
                        if (TransID == "7") // beat saleman map
                        {
                            lst = BeatSalesmanMappingTempWithErrCol();
                        }
                        if (TransID == "8") // customer remark
                        {
                            lst = CustomerRemarksTempWithErrCol();
                        }
                        if (TransID == "10") // Product Open import
                        {
                            lst = ProductOpenImportTempWithErrCol();
                        }
                        ColumnValidation(lst, ref blResult);
                        ErrorColAlreadyExisist = true;
                    }
                    #endregion
                    if (blResult)
                    {
                        DataTable dtCorrectValues = new DataTable();
                        DataTable dtWrongValues = new DataTable();
                        foreach (string str in lst)
                        {
                            dtCorrectValues.Columns.Add(str);
                            dtWrongValues.Columns.Add(str);
                        }

                        if (!ErrorColAlreadyExisist)
                        {
                            dtCorrectValues.Columns.Add("Error");
                            dtWrongValues.Columns.Add("Error");
                        }
                        #region Purchase Order
                        if (TransID == "3")
                        {
                            dtCorrectValues.Columns.Add("TaxPern");
                            dtCorrectValues.Columns.Add("UOM");
                            if (dtData.Rows.Count > 0)
                            {
                                int nIndex = 1;
                                bool NoErrors = true;
                                foreach (DataRow item in dtData.Rows)
                                {
                                    string RowError = POImpValiation(item);
                                    if (string.IsNullOrEmpty(RowError))
                                    {
                                        DataRow drW = dtWrongValues.NewRow();
                                        drW["Doc ID"] = item.ItemArray[0];
                                        drW["Doc Date"] = item.ItemArray[1];
                                        drW["Branch Name"] = item.ItemArray[2];
                                        drW["Vendor Name"] = item.ItemArray[3];
                                        drW["Item Name"] = item.ItemArray[4];
                                        drW["Price"] = item.ItemArray[5];
                                        drW["Qty"] = item.ItemArray[6];
                                        drW["Tax"] = item.ItemArray[7];
                                        drW["Error"] = RowError;
                                        dtWrongValues.Rows.Add(drW);
                                        //Correct values only
                                        DataRow drC = dtCorrectValues.NewRow();
                                        drC["Doc ID"] = item.ItemArray[0];
                                        drC["Doc Date"] = item.ItemArray[1];
                                        drC["Branch Name"] = BranchID;
                                        drC["Vendor Name"] = VendorID;
                                        drC["Item Name"] = ProductID;
                                        drC["Price"] = item.ItemArray[5];
                                        drC["Qty"] = item.ItemArray[6];
                                        drC["Tax"] = TaxID;
                                        drC["TaxPern"] = TaxPern;
                                        drC["UOM"] = UOMID;
                                        drC["Error"] = nIndex;
                                        dtCorrectValues.Rows.Add(drC);
                                        nIndex++;
                                    }
                                    else
                                    {
                                        NoErrors = false;
                                        DataRow drW = dtWrongValues.NewRow();
                                        drW["Doc ID"] = item.ItemArray[0];
                                        drW["Doc Date"] = item.ItemArray[1];
                                        drW["Branch Name"] = item.ItemArray[2];
                                        drW["Vendor Name"] = item.ItemArray[3];
                                        drW["Item Name"] = item.ItemArray[4];
                                        drW["Price"] = item.ItemArray[5];
                                        drW["Qty"] = item.ItemArray[6];
                                        drW["Tax"] = item.ItemArray[7];
                                        drW["Error"] = RowError;
                                        dtWrongValues.Rows.Add(drW);
                                    }
                                }

                                if (NoErrors)//dtWrongValues.Rows.Count == 0
                                {
                                    DataTable dtProd = new DataTable();
                                    if (dtProd.Columns.Count == 0)
                                    {
                                        dtProd.Columns.Add("ProdId", typeof(int));
                                        dtProd.Columns.Add("UomId", typeof(int));
                                        dtProd.Columns.Add("Qty", typeof(decimal));
                                        dtProd.Columns.Add("PurchasePrice", typeof(decimal));
                                        dtProd.Columns.Add("TaxID", typeof(int));
                                        dtProd.Columns.Add("TaxPercentage", typeof(decimal));
                                        dtProd.Columns.Add("GrossAmt", typeof(decimal), "(Qty*PurchasePrice)");
                                        dtProd.Columns.Add("TaxAmt", typeof(decimal), "(GrossAmt*TaxPercentage)/100");
                                        dtProd.Columns.Add("NetAmt", typeof(decimal), "GrossAmt+TaxAmt");
                                        dtProd.Columns.Add("InventoryId", typeof(int)).DefaultValue = 0;
                                        dtProd.Columns.Add("Serial", typeof(int));
                                        dtProd.Columns.Add("UOMCR", typeof(decimal)).DefaultValue = 1;
                                    }
                                    DataTable dtDistinct = new DataTable();
                                    dtDistinct = dtCorrectValues.DefaultView.ToTable(true, dtCorrectValues.Columns["Doc ID"].ColumnName);
                                    string sortExpression = string.Format("{0}", "Doc ID");
                                    dtDistinct.DefaultView.Sort = sortExpression + " ASC";
                                    dtDistinct = dtDistinct.DefaultView.ToTable();
                                    for (int i = 0; i < dtDistinct.Rows.Count; i++)
                                    {
                                        dtProd.Rows.Clear();
                                        DataRow[] DRR = dtCorrectValues.Select("[Doc ID] = '" + dtDistinct.Rows[i][0].ToString() + "'");
                                        if (DRR.Length > 0)
                                        {
                                            for (int j = 0; j < DRR.Length; j++)
                                            {
                                                DataRow dtRow = dtProd.NewRow();
                                                dtRow[0] = objBL.BL_nValidation(Convert.ToString(DRR[j]["Item Name"]));
                                                dtRow[1] = objBL.BL_nValidation(Convert.ToString(DRR[j]["UOM"]));
                                                dtRow[2] = objBL.BL_dValidation(Convert.ToString(DRR[j]["Qty"]));
                                                dtRow[3] = objBL.BL_dValidation(Convert.ToString(DRR[j]["Price"]));
                                                dtRow[4] = objBL.BL_nValidation(Convert.ToString(DRR[j]["Tax"]));
                                                dtRow[5] = objBL.BL_dValidation(Convert.ToString(DRR[j]["TaxPern"]));
                                                dtRow[10] = (j + 1);
                                                dtProd.Rows.Add(dtRow);
                                            }
                                        }
                                        object gross = dtProd.Compute("sum(GrossAmt)", null);
                                        object Tax = dtProd.Compute("sum(TaxAmt)", null);
                                        object Net = dtProd.Compute("sum(NetAmt)", null);
                                        decimal roundnet = Math.Floor(objBL.BL_dValidation(Net));
                                        decimal Roundoff = roundnet - objBL.BL_dValidation(Net);
                                        dt = "Excel Sheet Date :" + DRR[0]["Doc Date"].ToString();
                                        DateTime date = DateTime.ParseExact(DRR[0]["Doc Date"].ToString(), "dd/MM/yyyy", System.Globalization.CultureInfo.InvariantCulture);
                                        string formattedDate = date.ToString("yyyy-MM-dd");
                                        dt = Convert.ToDateTime(formattedDate).ToString();//"yyyy-MM-dd"
                                        objBL.bl_Transaction(1);
                                        DataTable dtResult = objBL.bl_ManageTrans("uspManagePurchaseOrder", dtProd, 1, 0, objBL.BL_nValidation(DRR[0]["Branch Name"]),
                                1, dt, DRR[0]["Vendor Name"], DRR[0]["Doc ID"], 1, objBL.BL_dValidation(Roundoff), objBL.BL_dValidation(gross), objBL.BL_dValidation(Tax),
                                objBL.BL_dValidation(roundnet), 0, null, "Import Data", objBL.BL_nValidation(UserID), 0, 1);
                                        if (dtResult.Rows.Count == 3)
                                        {
                                            objBL.bl_Transaction(3);
                                        }
                                        objBL.bl_Transaction(2);
                                    }
                                    //int UID = Convert.ToInt32(2;

                                    if (NoErrors)//dtWrongValues.Rows.Count == 0
                                    {
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "0",
                                            Msg = "Data Saved Successfully.",
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                }
                                if (!NoErrors)
                                {
                                    //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Error Files\\";
                                    strFilePath = FPt + "Error Files\\";
                                    strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                    strSheetName = "Data";
                                    ExportToExcel(dtWrongValues);
                                    MTM.Add(new ImportResults()
                                    {
                                        ID = "1",
                                        Msg = "Data Not Saved. Error occured in some documents. See error list in downloads.",
                                        FileName = strFileName + strExtension,
                                        FilePath = strFilePath + strFileName + strExtension,
                                        Total = Convert.ToString(dtData.Rows.Count),
                                        Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                        UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                    });
                                }
                                return Ok(MTM);
                            }
                            else
                            {
                                Msg = "0";// no records found;
                            }
                        }
                        #endregion
                        #region Customer
                        else if (TransID == "1")
                        {
                            if (dtData.Rows.Count > 0)
                            {
                                bool NoErrors = true;
                                foreach (DataRow item in dtData.Rows)
                                {
                                    DataTable dtValidate = dtData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = CustomerImpValiation(dtValidate);
                                    if (string.IsNullOrEmpty(RowError))
                                    {
                                        //fill all the data
                                        dtWrongValues.Rows.Add(item.ItemArray);
                                        int rid = dtWrongValues.Rows.Count;
                                        dtWrongValues.Rows[rid - 1]["Error"] = RowError;
                                        //fill valid data only
                                        dtCorrectValues.Rows.Add(item.ItemArray);
                                    }
                                    else
                                    {
                                        NoErrors = false;
                                        //fill all the data
                                        dtWrongValues.Rows.Add(item.ItemArray);
                                        int rid = dtWrongValues.Rows.Count;
                                        dtWrongValues.Rows[rid - 1]["Error"] = RowError;
                                    }
                                }
                                if (NoErrors)//dtWrongValues.Rows.Count == 0// no error, create new records
                                {
                                    bool NoErrorwhenInsert = true;
                                    for (int i = 0; i < dtCorrectValues.Rows.Count; i++)
                                    {
                                        DataTable DDT = objBL.BL_ExecuteParamSP("uspManageCustomerMasterImport",
                                            dtCorrectValues.Rows[i]["Code *"].ToString(),
                                            dtCorrectValues.Rows[i]["Name *"].ToString(),
                                            dtCorrectValues.Rows[i]["Billing Address 1"].ToString(),
                                            dtCorrectValues.Rows[i]["Billing Address 2"].ToString(),
                                            dtCorrectValues.Rows[i]["Billing Address 3"].ToString(),
                                            dtCorrectValues.Rows[i]["Shipping Address 1"].ToString(),
                                            dtCorrectValues.Rows[i]["Shipping Address 2"].ToString(),
                                            dtCorrectValues.Rows[i]["Shipping Address 3"].ToString(),
                                            dtCorrectValues.Rows[i]["Pincode *"].ToString(),
                                            dtCorrectValues.Rows[i]["Contact Person"].ToString(),
                                            dtCorrectValues.Rows[i]["Phone No 1"].ToString(),
                                            dtCorrectValues.Rows[i]["Phone No 2"].ToString(),
                                            dtCorrectValues.Rows[i]["Mobile No 1"].ToString(),
                                            dtCorrectValues.Rows[i]["Mobile No 2"].ToString(),
                                            dtCorrectValues.Rows[i]["Email ID"].ToString(),
                                            dtCorrectValues.Rows[i]["PAN Number"].ToString(),
                                            dtCorrectValues.Rows[i]["Aadhar No"].ToString(),
                                            dtCorrectValues.Rows[i]["DL No 20"].ToString(),
                                            dtCorrectValues.Rows[i]["DL No 21"].ToString(),
                                            dtCorrectValues.Rows[i]["FSSAI No"].ToString(),
                                            dtCorrectValues.Rows[i]["State Name"].ToString(),
                                            dtCorrectValues.Rows[i]["GSTIN"].ToString(),
                                            dtCorrectValues.Rows[i]["Credit Term"].ToString(),
                                            dtCorrectValues.Rows[i]["Payment Mode"].ToString(),
                                            dtCorrectValues.Rows[i]["Tax Type *"].ToString(),
                                            objBL.BL_dValidation(dtCorrectValues.Rows[i]["Over Due Value"].ToString()),
                                            objBL.BL_nValidation(dtCorrectValues.Rows[i]["Over Due Inv Count"].ToString()),
                                            objBL.BL_dValidation(dtCorrectValues.Rows[i]["Credit Limit Value"].ToString()),
                                            objBL.BL_nValidation(dtCorrectValues.Rows[i]["Credit Limit Count"].ToString()),
                                            objBL.BL_dValidation(dtCorrectValues.Rows[i]["Over Due Value"].ToString()),
                                            dtCorrectValues.Rows[i]["Price Type *"].ToString(),
                                            dtCorrectValues.Rows[i]["Owner Name"].ToString(),
                                            objBL.BL_dValidation(dtCorrectValues.Rows[i]["Discount %"].ToString()),
                                            dtCorrectValues.Rows[i]["Track Point"].ToString() == "Y" ? "1" : "0", 0,
                                            dtCorrectValues.Rows[i]["TCS Tax"].ToString() == "Y" ? "1" : "0", null, null,
                                            dtCorrectValues.Rows[i]["Distance"].ToString(),
                                            dtCorrectValues.Rows[i]["Remark"].ToString(),
                                            dtCorrectValues.Rows[i]["Active"].ToString() == "Y" ? "1" : "0",
                                            objBL.BL_nValidation(UserID),
                                            dtCorrectValues.Rows[i]["Customer Type"].ToString(),
                                            dtCorrectValues.Rows[i]["Rating"].ToString());
                                        if (DDT.Columns.Count == 3)
                                        {
                                            NoErrorwhenInsert = false;
                                            dtWrongValues.Rows.Add(dtCorrectValues.Rows[i].ItemArray);
                                            int rid = dtWrongValues.Rows.Count;
                                            dtWrongValues.Rows[rid - 1]["Error"] = DDT.Rows[0][0].ToString();
                                        }
                                    }
                                    if (!NoErrorwhenInsert)
                                    {
                                        strFilePath = FPt + "Error Files\\";
                                        strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                        strSheetName = "Data";
                                        ExportToExcel(dtWrongValues);
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "1",
                                            Msg = "Data Saved with errors. Error occured in some documents. See error list in downloads.",
                                            FileName = strFileName + strExtension,
                                            FilePath = strFilePath + strFileName + strExtension,
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                    else
                                    {
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "0",
                                            Msg = "Data Saved Successfully.",
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                }
                                else
                                {
                                    //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Error Files\\";
                                    strFilePath = FPt + "Error Files\\";
                                    strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                    strSheetName = "Data";
                                    ExportToExcel(dtWrongValues);
                                    MTM.Add(new ImportResults()
                                    {
                                        ID = "1",
                                        Msg = "Data Not Saved. Error occured in some documents. See error list in downloads.",
                                        FileName = strFileName + strExtension,
                                        FilePath = strFilePath + strFileName + strExtension,
                                        Total = Convert.ToString(dtData.Rows.Count),
                                        Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                        UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                    });
                                }
                                return Ok(MTM);
                            }
                            else
                            {
                                Msg = "0";// no records found;
                            }
                        }
                        #endregion
                        #region Product
                        else if (TransID == "2")
                        {
                            if (dtData.Rows.Count > 0)
                            {
                                bool NoErrors = true;
                                foreach (DataRow item in dtData.Rows)
                                {
                                    DataTable dtValidate = dtData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = ProductImpValiation(dtValidate);
                                    if (string.IsNullOrEmpty(RowError))
                                    {
                                        dtWrongValues.Rows.Add(item.ItemArray);
                                        int rid = dtWrongValues.Rows.Count;
                                        dtWrongValues.Rows[rid - 1]["Error"] = RowError;
                                        //correct values only
                                        dtCorrectValues.Rows.Add(item.ItemArray);
                                    }
                                    else
                                    {
                                        NoErrors = false;
                                        dtWrongValues.Rows.Add(item.ItemArray);
                                        int rid = dtWrongValues.Rows.Count;
                                        dtWrongValues.Rows[rid - 1]["Error"] = RowError;
                                    }
                                }
                                if (NoErrors)//dtWrongValues.Rows.Count == 0 // no error, create/update records
                                {
                                    DataTable dtErrors = dtWrongValues.Clone();
                                    dtErrors.TableName = "Error Data";
                                    bool NoErrorwhenInsert = true;
                                    for (int i = 0; i < dtCorrectValues.Rows.Count; i++)
                                    {
                                        DataTable DDT = objBL.BL_ExecuteParamSP("uspManageProductMasterImport",
                                            dtCorrectValues.Rows[i]["Code *"].ToString(), dtCorrectValues.Rows[i]["Name *"].ToString(),
                                            dtCorrectValues.Rows[i]["EAN *"].ToString(), dtCorrectValues.Rows[i]["Mfr Name *"].ToString(),
                                            dtCorrectValues.Rows[i]["Brand Name *"].ToString(), dtCorrectValues.Rows[i]["Category Name *"].ToString(),
                                            dtCorrectValues.Rows[i]["HSN Code"].ToString(),
                                            objBL.BL_dValidation(dtCorrectValues.Rows[i]["Discount %"].ToString()),
                                            dtCorrectValues.Rows[i]["Base Uom *"].ToString(),
                                            objBL.BL_dValidation(dtCorrectValues.Rows[i]["Base CR *"].ToString()),
                                            dtCorrectValues.Rows[i]["Purchase Uom *"].ToString(),
                                            objBL.BL_dValidation(dtCorrectValues.Rows[i]["Purchase CR *"].ToString()),
                                            dtCorrectValues.Rows[i]["Sales Uom *"].ToString(),
                                            objBL.BL_dValidation(dtCorrectValues.Rows[i]["Sales CR *"].ToString()),
                                            dtCorrectValues.Rows[i]["Reporting Uom *"].ToString(),
                                            objBL.BL_dValidation(dtCorrectValues.Rows[i]["Reporting CR *"].ToString()),
                                             objBL.BL_dValidation(dtCorrectValues.Rows[i]["Reporting CR *"].ToString()),
                                             dtCorrectValues.Rows[i]["Purchase Tax *"].ToString(),
                                            dtCorrectValues.Rows[i]["Sales Tax *"].ToString(),
                                            objBL.BL_dValidation(dtCorrectValues.Rows[i]["Purchase Price *"].ToString()),
                                            dtCorrectValues.Rows[i]["Sale on MRP"].ToString(),
                                            objBL.BL_dValidation(dtCorrectValues.Rows[i]["Sales Margin %"].ToString()),
                                             objBL.BL_dValidation(dtCorrectValues.Rows[i]["Sales Price *"].ToString()),
                                             dtCorrectValues.Rows[i]["ECP on MRP"].ToString(),
                                             objBL.BL_dValidation(dtCorrectValues.Rows[i]["ECP Margin %"].ToString()),
                                             objBL.BL_dValidation(dtCorrectValues.Rows[i]["ECP *"].ToString()),
                                            dtCorrectValues.Rows[i]["SPL on MRP"].ToString(),
                                            objBL.BL_dValidation(dtCorrectValues.Rows[i]["SPL Margin %"].ToString()),
                                             objBL.BL_dValidation(dtCorrectValues.Rows[i]["SPL Price *"].ToString()),
                                             objBL.BL_dValidation(dtCorrectValues.Rows[i]["MRP *"].ToString()),
                                             objBL.BL_dValidation(dtCorrectValues.Rows[i]["Return Price"].ToString()),
                                             dtCorrectValues.Rows[i]["Track Inventory"].ToString(),
                                            dtCorrectValues.Rows[i]["Track Batch"].ToString(),
                                            dtCorrectValues.Rows[i]["Track Serial"].ToString(),
                                            dtCorrectValues.Rows[i]["Track PKD"].ToString(),
                                            dtCorrectValues.Rows[i]["Date Format"].ToString(),
                                            dtCorrectValues.Rows[i]["Barcode Print"].ToString(),
                                            dtCorrectValues.Rows[i]["Barcode Uom"].ToString(),
                                            dtCorrectValues.Rows[i]["Barcode Price"].ToString(),
                                            dtCorrectValues.Rows[i]["Vendor Name"].ToString(),
                                            objBL.BL_nValidation(dtCorrectValues.Rows[i]["MOH"].ToString()),
                                            objBL.BL_nValidation(dtCorrectValues.Rows[i]["MOQ"].ToString()),
                                            dtCorrectValues.Rows[i]["Remarks"].ToString(), dtCorrectValues.Rows[i]["Location Name"].ToString(),
                                        objBL.BL_nValidation(dtCorrectValues.Rows[i]["Weborder"].ToString()), dtCorrectValues.Rows[i]["Active"].ToString(),
                                        objBL.BL_nValidation(UserID), dtCorrectValues.Rows[i]["Life Time"].ToString());
                                        if (DDT.Columns.Count == 3)
                                        {
                                            NoErrorwhenInsert = false;
                                            dtWrongValues.Rows.Add(dtCorrectValues.Rows[i].ItemArray);
                                            int rid = dtWrongValues.Rows.Count;
                                            dtWrongValues.Rows[rid - 1]["Error"] = DDT.Rows[0][0].ToString();
                                        }
                                    }
                                    if (!NoErrorwhenInsert)
                                    {
                                        strFilePath = FPt + "Error Files\\";
                                        strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                        strSheetName = "Data";
                                        ExportToExcel(dtWrongValues);
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "1",
                                            Msg = "Data Saved with errors. Error occured in some documents. See error list in downloads.",
                                            FileName = strFileName + strExtension,
                                            FilePath = strFilePath + strFileName + strExtension,
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                    else
                                    {
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "0",
                                            Msg = "Data Saved Successfully.",
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                }
                                else
                                {
                                    //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Error Files\\";
                                    strFilePath = FPt + "Error Files\\";
                                    strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                    strSheetName = "Data";
                                    ExportToExcel(dtWrongValues);
                                    MTM.Add(new ImportResults()
                                    {
                                        ID = "1",
                                        Msg = "Data Not Saved. Error occured in some documents. See error list in downloads.",
                                        FileName = strFileName + strExtension,
                                        FilePath = strFilePath + strFileName + strExtension,
                                        Total = Convert.ToString(dtData.Rows.Count),
                                        Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                        UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                    });
                                }
                                return Ok(MTM);
                            }
                            else
                            {
                                Msg = "0";
                            }
                        }
                        #endregion
                        #region Price Change
                        else if (TransID == "4")
                        {
                            if (dtData.Rows.Count > 0)
                            {
                                bool NoErrors = true;
                                foreach (DataRow item in dtData.Rows)
                                {
                                    DataTable dtValidate = dtData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = PriceChangeImpValiation(dtValidate);
                                    if (string.IsNullOrEmpty(RowError))
                                    {
                                        dtWrongValues.Rows.Add(item.ItemArray);
                                        int rid = dtWrongValues.Rows.Count;
                                        dtWrongValues.Rows[rid - 1]["Error"] = RowError;
                                        dtCorrectValues.Rows.Add(item.ItemArray);
                                    }
                                    else
                                    {
                                        NoErrors = false;
                                        dtWrongValues.Rows.Add(item.ItemArray);
                                        int rid = dtWrongValues.Rows.Count;
                                        dtWrongValues.Rows[rid - 1]["Error"] = RowError;
                                    }
                                }
                                if (NoErrors)//dtWrongValues.Rows.Count == 0 // no error, create/update records
                                {
                                    DataTable dtErrors = dtWrongValues.Clone();
                                    dtErrors.TableName = "Error Data";
                                    bool NoErrorwhenInsert = true;
                                    for (int i = 0; i < dtCorrectValues.Rows.Count; i++)
                                    {
                                        string exp = !string.IsNullOrEmpty(dtCorrectValues.Rows[i]["Expiry"].ToString()) ? Convert.ToDateTime(dtCorrectValues.Rows[i]["Expiry"].ToString()).ToString("yyyy-MM-dd") : null;
                                        string pkd = !string.IsNullOrEmpty(dtCorrectValues.Rows[i]["PKD"].ToString()) ? Convert.ToDateTime(dtCorrectValues.Rows[i]["PKD"].ToString()).ToString("yyyy-MM-dd") : null;

                                        DataTable DDT = objBL.BL_ExecuteParamSP("uspManageProductPricechangedata", 6, 0, 0, dtCorrectValues.Rows[i]["ID"].ToString(), 0,
                                        0, dtCorrectValues.Rows[i]["Batch No"].ToString(), pkd, exp, null, objBL.BL_dValidation(dtCorrectValues.Rows[i]["Sales Price"].ToString()),
                                        objBL.BL_dValidation(dtCorrectValues.Rows[i]["ECP"].ToString()), objBL.BL_dValidation(dtCorrectValues.Rows[i]["SPL Price"].ToString()),
                                        objBL.BL_dValidation(dtCorrectValues.Rows[i]["MRP Incl"].ToString()), objBL.BL_dValidation(dtCorrectValues.Rows[i]["Return Price"].ToString()),
                                        objBL.BL_nValidation(UserID));//2
                                        if (DDT.Columns.Count == 3)
                                        {
                                            NoErrorwhenInsert = false;
                                            dtWrongValues.Rows.Add(dtCorrectValues.Rows[i].ItemArray);
                                            int rid = dtWrongValues.Rows.Count;
                                            dtWrongValues.Rows[rid - 1]["Error"] = DDT.Rows[0][0].ToString();
                                        }
                                    }
                                    if (!NoErrorwhenInsert)
                                    {
                                        strFilePath = FPt + "Error Files\\";
                                        strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                        strSheetName = "Data";
                                        ExportToExcel(dtWrongValues);
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "1",
                                            Msg = "Data Saved with errors. Error occured in some documents. See error list in downloads.",
                                            FileName = strFileName + strExtension,
                                            FilePath = strFilePath + strFileName + strExtension,
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                    else
                                    {
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "0",
                                            Msg = "Data Saved Successfully.",
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                }
                                else
                                {
                                    //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Error Files\\";
                                    strFilePath = FPt + "Error Files\\";
                                    strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                    strSheetName = "Data";
                                    ExportToExcel(dtWrongValues);
                                    MTM.Add(new ImportResults()
                                    {
                                        ID = "1",
                                        Msg = "Data Not Saved. Error occured in some documents. See error list in downloads.",
                                        FileName = strFileName + strExtension,
                                        FilePath = strFilePath + strFileName + strExtension,
                                        Total = Convert.ToString(dtData.Rows.Count),
                                        Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                        UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                    });
                                }
                                return Ok(MTM);
                            }
                            else
                            {
                                Msg = "0";
                            }
                        }
                        #endregion
                        #region Order Taken
                        else if (TransID == "5")
                        {
                            if (dtData.Rows.Count > 0)
                            {
                                int nIndex = 1;
                                bool NoErrors = true;
                                foreach (DataRow item in dtData.Rows)
                                {
                                    DataTable dtValidate = dtData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = OrderTakenImpValiation(dtValidate);
                                    if (string.IsNullOrEmpty(RowError))
                                    {
                                        DataRow drC = dtWrongValues.NewRow();
                                        drC["Order ID"] = item.ItemArray[0];
                                        drC["Doc Date"] = item.ItemArray[1];
                                        drC["Branch Name"] = item.ItemArray[2];
                                        drC["Beat Name"] = item.ItemArray[3];
                                        drC["Salesman Name"] = item.ItemArray[4];
                                        drC["Customer Name"] = item.ItemArray[5];
                                        drC["Additional Discount %"] = item.ItemArray[6];
                                        drC["Trade Discount %"] = item.ItemArray[7];
                                        drC["Remarks"] = item.ItemArray[8];
                                        drC["Product Name"] = ProductID;
                                        drC["Price"] = item.ItemArray[10];
                                        drC["Quantity"] = item.ItemArray[11];
                                        drC["Discount %"] = item.ItemArray[12];
                                        drC["Error"] = RowError;
                                        dtWrongValues.Rows.Add(drC);
                                        //correct values only                                        
                                        drC = dtCorrectValues.NewRow();
                                        drC["Order ID"] = item.ItemArray[0];
                                        drC["Doc Date"] = item.ItemArray[1];
                                        drC["Branch Name"] = BranchID;
                                        drC["Beat Name"] = BeatID;
                                        drC["Salesman Name"] = SalesmanID;
                                        drC["Customer Name"] = CustomerID;
                                        drC["Additional Discount %"] = objBL.BL_dValidation(item.ItemArray[6]);
                                        drC["Trade Discount %"] = objBL.BL_dValidation(item.ItemArray[7]);
                                        drC["Remarks"] = item.ItemArray[8];
                                        drC["Product Name"] = ProductID;
                                        drC["Price"] = objBL.BL_dValidation(item.ItemArray[10]);
                                        drC["Quantity"] = objBL.BL_dValidation(item.ItemArray[11]);
                                        drC["Discount %"] = objBL.BL_dValidation(item.ItemArray[12]); ;
                                        drC["Error"] = nIndex;
                                        dtCorrectValues.Rows.Add(drC);
                                        nIndex++;
                                    }
                                    else
                                    {
                                        //dtWrongValues.Rows.Add(item.ItemArray);
                                        //int rid = dtWrongValues.Rows.Count;
                                        //dtWrongValues.Rows[rid - 1]["Error"] = RowError;
                                        NoErrors = false;
                                        DataRow drC = dtWrongValues.NewRow();
                                        drC["Order ID"] = item.ItemArray[0];
                                        drC["Doc Date"] = item.ItemArray[1];
                                        drC["Branch Name"] = item.ItemArray[2];
                                        drC["Beat Name"] = item.ItemArray[3];
                                        drC["Salesman Name"] = item.ItemArray[4];
                                        drC["Customer Name"] = item.ItemArray[5];
                                        drC["Additional Discount %"] = item.ItemArray[6];
                                        drC["Trade Discount %"] = item.ItemArray[7];
                                        drC["Remarks"] = item.ItemArray[8];
                                        drC["Product Name"] = item.ItemArray[9];
                                        drC["Price"] = item.ItemArray[10];
                                        drC["Quantity"] = item.ItemArray[11];
                                        drC["Discount %"] = item.ItemArray[12];
                                        drC["Error"] = RowError;
                                        dtWrongValues.Rows.Add(drC);

                                    }
                                }
                                if (NoErrors)//dtWrongValues.Rows.Count == 0 // no error, create records
                                {
                                    DataTable dtProd = new DataTable();
                                    if (dtProd.Columns.Count == 0)
                                    {
                                        dtProd.Columns.Add("ProdId", typeof(int));
                                        dtProd.Columns.Add("UomId", typeof(int));
                                        dtProd.Columns.Add("Qty", typeof(decimal));
                                        dtProd.Columns.Add("Price", typeof(decimal));
                                        dtProd.Columns.Add("OrgPrice", typeof(decimal));
                                        dtProd.Columns.Add("Amount", typeof(decimal), "(Qty*Price)");
                                        dtProd.Columns.Add("DiscPern", typeof(decimal));
                                        dtProd.Columns.Add("DiscAmt", typeof(decimal), "(DiscPern*Amount)/100");
                                        dtProd.Columns.Add("ConversionRate", typeof(decimal));
                                        dtProd.Columns.Add("Serial", typeof(int));
                                    }
                                    DataTable dtDistinct = new DataTable();
                                    dtDistinct = dtCorrectValues.DefaultView.ToTable(true, dtCorrectValues.Columns["Order ID"].ColumnName);
                                    string sortExpression = string.Format("{0}", "Order ID");
                                    dtDistinct.DefaultView.Sort = sortExpression + " ASC";
                                    dtDistinct = dtDistinct.DefaultView.ToTable();
                                    for (int i = 0; i < dtDistinct.Rows.Count; i++)
                                    {
                                        dtProd.Rows.Clear();
                                        DataRow[] DRR = dtCorrectValues.Select("[Order ID] = '" + dtDistinct.Rows[i][0].ToString() + "'");
                                        if (DRR.Length > 0)
                                        {
                                            for (int j = 0; j < DRR.Length; j++)
                                            {
                                                DataRow dtRow = dtProd.NewRow();
                                                dtRow[0] = Convert.ToString(DRR[j]["Product Name"]);
                                                dtRow[1] = 0;
                                                dtRow[2] = objBL.BL_dValidation(Convert.ToString(DRR[j]["Quantity"]));
                                                dtRow[3] = objBL.BL_dValidation(Convert.ToString(DRR[j]["Price"]));
                                                dtRow[4] = objBL.BL_nValidation(Convert.ToString(DRR[j]["Price"]));//Discount %
                                                dtRow[6] = objBL.BL_dValidation(Convert.ToString(DRR[j]["Discount %"]));
                                                dtRow[8] = 1;
                                                dtRow[9] = (j + 1);
                                                dtProd.Rows.Add(dtRow);
                                            }
                                        }
                                        //save
                                        DateTime date = DateTime.ParseExact(DRR[0]["Doc Date"].ToString(), "dd/MM/yyyy", System.Globalization.CultureInfo.InvariantCulture);
                                        string formattedDate = date.ToString("yyyy-MM-dd");
                                        dt = Convert.ToDateTime(formattedDate).ToString();//"yyyy-MM-dd"
                                        objBL.bl_Transaction(1);
                                        DataTable dtResult = objBL.bl_ManageTrans("uspManageOrderTakenImport", dtProd, 1, 0, dt, objBL.BL_nValidation(DRR[0]["Branch Name"]),
                                            DRR[0]["Customer Name"], DRR[0]["Beat Name"], DRR[0]["Salesman Name"], DRR[0]["Order ID"], objBL.BL_dValidation(DRR[0]["Additional Discount %"]),
                                            objBL.BL_dValidation(DRR[0]["Trade Discount %"]), 1, 0, DRR[0]["Remarks"], objBL.BL_nValidation(UserID), 1, 1);
                                        if (dtResult.Rows.Count == 3)//
                                        {
                                            objBL.bl_Transaction(3);
                                        }
                                        objBL.bl_Transaction(2);
                                    }
                                    if (NoErrors)
                                    {
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "0",
                                            Msg = "Data Saved Successfully.",
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                }
                                else
                                {
                                    //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Error Files\\";
                                    strFilePath = FPt + "Error Files\\";
                                    strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                    strSheetName = "Data";
                                    ExportToExcel(dtWrongValues);
                                    MTM.Add(new ImportResults()
                                    {
                                        ID = "1",
                                        Msg = "Data Not Saved. Error occured in some documents. See error list in downloads.",
                                        FileName = strFileName + strExtension,
                                        FilePath = strFilePath + strFileName + strExtension,
                                        Total = Convert.ToString(dtData.Rows.Count),
                                        Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                        UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                    });
                                }
                                return Ok(MTM);
                            }
                            else
                            {
                                Msg = "0";
                            }
                        }
                        #endregion
                        #region Transaction Price
                        else if (TransID == "6")
                        {
                            if (dtData.Rows.Count > 0)
                            {
                                int nIndex = 1;
                                bool NoErrors = true;
                                foreach (DataRow item in dtData.Rows)
                                {
                                    DataTable dtValidate = dtData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = TransactionPriceImpValiation(dtValidate);
                                    if (string.IsNullOrEmpty(RowError))
                                    {
                                        DataRow drC = dtWrongValues.NewRow();
                                        drC["Product Code"] = item.ItemArray[0];
                                        drC["Product Name"] = item.ItemArray[1];
                                        drC["Purchase Bill Price"] = item.ItemArray[2];
                                        drC["Purchase Return Price"] = item.ItemArray[3];
                                        drC["Invoice Price"] = item.ItemArray[4];
                                        drC["Sales Return Price"] = item.ItemArray[5];
                                        drC["Error"] = RowError;
                                        dtWrongValues.Rows.Add(drC);
                                        //Correct values only
                                        drC = dtCorrectValues.NewRow();
                                        drC["Product Code"] = ProductID;
                                        drC["Product Name"] = ProductID;
                                        drC["Purchase Bill Price"] = item.ItemArray[2];
                                        drC["Purchase Return Price"] = item.ItemArray[3];
                                        drC["Invoice Price"] = item.ItemArray[4];
                                        drC["Sales Return Price"] = item.ItemArray[5];
                                        drC["Error"] = nIndex;
                                        dtCorrectValues.Rows.Add(drC);
                                        nIndex++;
                                    }
                                    else
                                    {
                                        NoErrors = false;
                                        DataRow drC = dtWrongValues.NewRow();
                                        drC["Product Code"] = item.ItemArray[0];
                                        drC["Product Name"] = item.ItemArray[1];
                                        drC["Purchase Bill Price"] = item.ItemArray[2];
                                        drC["Purchase Return Price"] = item.ItemArray[3];
                                        drC["Invoice Price"] = item.ItemArray[4];
                                        drC["Sales Return Price"] = item.ItemArray[5];
                                        drC["Error"] = RowError;
                                        dtWrongValues.Rows.Add(drC);
                                    }
                                }
                                if (NoErrors)//dtWrongValues.Rows.Count == 0// no error, create/update records
                                {
                                    DataTable dtErrors = dtWrongValues.Clone();
                                    dtErrors.TableName = "Error Data";
                                    bool NoErrorwhenInsert = true;
                                    for (int i = 0; i < dtCorrectValues.Rows.Count; i++)
                                    {

                                        DataTable DDT = objBL.BL_ExecuteParamSP("uspManageProductTransactionPrice", dtCorrectValues.Rows[i]["Product Name"].ToString(),
                                        objBL.BL_dValidation(dtCorrectValues.Rows[i]["Purchase Bill Price"].ToString()),
                                        objBL.BL_dValidation(dtCorrectValues.Rows[i]["Purchase Return Price"].ToString()),
                                        objBL.BL_dValidation(dtCorrectValues.Rows[i]["Invoice Price"].ToString()),
                                        objBL.BL_dValidation(dtCorrectValues.Rows[i]["Sales Return Price"].ToString()),
                                        objBL.BL_nValidation(UserID));
                                        if (DDT.Columns.Count == 3)
                                        {
                                            NoErrorwhenInsert = false;
                                            dtWrongValues.Rows.Add(dtCorrectValues.Rows[i].ItemArray);
                                            int rid = dtWrongValues.Rows.Count;
                                            dtWrongValues.Rows[rid - 1]["Error"] = DDT.Rows[0][0].ToString();
                                        }
                                    }
                                    if (!NoErrorwhenInsert)
                                    {
                                        strFilePath = FPt + "Error Files\\";
                                        strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                        strSheetName = "Data";
                                        ExportToExcel(dtWrongValues);
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "1",
                                            Msg = "Data Saved with errors. Error occured in some documents. See error list in downloads.",
                                            FileName = strFileName + strExtension,
                                            FilePath = strFilePath + strFileName + strExtension,
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                    else
                                    {
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "0",
                                            Msg = "Data Saved Successfully.",
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                }
                                else
                                {
                                    //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Error Files\\";
                                    strFilePath = FPt + "Error Files\\";
                                    strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                    strSheetName = "Data";
                                    ExportToExcel(dtWrongValues);
                                    MTM.Add(new ImportResults()
                                    {
                                        ID = "1",
                                        Msg = "Data Not Saved. Error occured in some documents. See error list in downloads.",
                                        FileName = strFileName + strExtension,
                                        FilePath = strFilePath + strFileName + strExtension,
                                        Total = Convert.ToString(dtData.Rows.Count),
                                        Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                        UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                    });
                                }
                                return Ok(MTM);
                            }
                            else
                            {
                                Msg = "0";
                            }
                        }
                        #endregion
                        #region Beat & Salesman Mapping
                        else if (TransID == "7")
                        {
                            if (dtData.Rows.Count > 0)
                            {
                                int nIndex = 1;
                                bool NoErrors = true;
                                foreach (DataRow item in dtData.Rows)
                                {
                                    DataTable dtValidate = dtData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = BeatSalesmanImpValiation(dtValidate);
                                    if (string.IsNullOrEmpty(RowError))
                                    {
                                        DataRow drC = dtWrongValues.NewRow();
                                        drC["Code"] = item.ItemArray[0];
                                        drC["Name"] = item.ItemArray[1];
                                        drC["Beat Name"] = item.ItemArray[2];
                                        drC["Salesman Name"] = item.ItemArray[3];
                                        drC["Error"] = RowError;
                                        dtWrongValues.Rows.Add(drC);

                                        //dtCorrectValues.Rows.Add(item.ItemArray);
                                        drC = dtCorrectValues.NewRow();
                                        drC["Code"] = CustomerID;
                                        drC["Name"] = CustomerID;
                                        drC["Beat Name"] = BeatID;
                                        drC["Salesman Name"] = SalesmanID;
                                        drC["Error"] = nIndex;
                                        dtCorrectValues.Rows.Add(drC);
                                        nIndex++;
                                    }
                                    else
                                    {
                                        NoErrors = false;
                                        DataRow drC = dtWrongValues.NewRow();
                                        drC["Code"] = item.ItemArray[0];
                                        drC["Name"] = item.ItemArray[1];
                                        drC["Beat Name"] = item.ItemArray[2];
                                        drC["Salesman Name"] = item.ItemArray[3];
                                        drC["Error"] = RowError;
                                        dtWrongValues.Rows.Add(drC);
                                    }
                                }
                                if (NoErrors)// dtWrongValues.Rows.Count == 0 // no error, create/update records
                                {
                                    DataTable dtErrors = dtWrongValues.Clone();
                                    dtErrors.TableName = "Error Data";
                                    bool NoErrorwhenInsert = true;
                                    int tempcust = 0, CurrentCust = 0, IsDelete = 0;
                                    for (int i = 0; i < dtCorrectValues.Rows.Count; i++)
                                    {
                                        CurrentCust = objBL.BL_nValidation(dtCorrectValues.Rows[i]["Code"].ToString());
                                        if (tempcust != CurrentCust)
                                        {
                                            IsDelete = 1;
                                        }
                                        DataTable DDT = objBL.BL_ExecuteParamSP("uspImportBeatsalesmanMapping", IsDelete,
                                             CurrentCust,
                                             objBL.BL_nValidation(dtCorrectValues.Rows[i]["Beat Name"].ToString()),
                                             objBL.BL_nValidation(dtCorrectValues.Rows[i]["Salesman Name"].ToString()));
                                        tempcust = CurrentCust;
                                        IsDelete = 0;
                                    }
                                    if (!NoErrorwhenInsert)
                                    {
                                        strFilePath = FPt + "Error Files\\";
                                        strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                        strSheetName = "Data";
                                        ExportToExcel(dtWrongValues);
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "1",
                                            Msg = "Data Saved with errors. Error occured in some documents. See error list in downloads.",
                                            FileName = strFileName + strExtension,
                                            FilePath = strFilePath + strFileName + strExtension,
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                    else
                                    {
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "0",
                                            Msg = "Data Saved Successfully.",
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                }
                                else
                                {
                                    //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Error Files\\";
                                    strFilePath = FPt + "Error Files\\";
                                    strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                    strSheetName = "Data";
                                    ExportToExcel(dtWrongValues);
                                    MTM.Add(new ImportResults()
                                    {
                                        ID = "1",
                                        Msg = "Data Not Saved. Error occured in some documents. See error list in downloads.",
                                        FileName = strFileName + strExtension,
                                        FilePath = strFilePath + strFileName + strExtension,
                                        Total = Convert.ToString(dtData.Rows.Count),
                                        Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                        UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                    });
                                }
                                return Ok(MTM);
                            }
                            else
                            {
                                Msg = "0";
                            }
                        }
                        #endregion
                        #region Customer Remarks
                        else if (TransID == "8")
                        {
                            if (dtData.Rows.Count > 0)
                            {
                                int nIndex = 1;
                                bool NoErrors = true;
                                foreach (DataRow item in dtData.Rows)
                                {
                                    DataTable dtValidate = dtData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = CusstomerRemarksImpValiation(dtValidate);
                                    if (string.IsNullOrEmpty(RowError))
                                    {
                                        DataRow drC = dtWrongValues.NewRow();
                                        drC["Code"] = item.ItemArray[0];
                                        drC["Name"] = item.ItemArray[1];
                                        drC["Remarks"] = item.ItemArray[2];
                                        drC["Error"] = RowError;
                                        dtWrongValues.Rows.Add(drC);
                                        //Correct values only
                                        drC = dtCorrectValues.NewRow();
                                        drC["Code"] = CustomerID;
                                        drC["Name"] = CustomerID;
                                        drC["Remarks"] = item.ItemArray[2];
                                        drC["Error"] = nIndex;
                                        dtCorrectValues.Rows.Add(drC);
                                        nIndex++;
                                    }
                                    else
                                    {
                                        NoErrors = false;
                                        DataRow drC = dtWrongValues.NewRow();
                                        drC["Code"] = item.ItemArray[0];
                                        drC["Name"] = item.ItemArray[1];
                                        drC["Remarks"] = item.ItemArray[2];
                                        drC["Error"] = RowError;
                                        dtWrongValues.Rows.Add(drC);
                                    }
                                }
                                if (NoErrors)//dtWrongValues.Rows.Count == 0 // no error, create/update records
                                {
                                    DataTable dtErrors = dtWrongValues.Clone();
                                    dtErrors.TableName = "Error Data";
                                    bool NoErrorwhenInsert = true;
                                    int tempcust = 0, CurrentCust = 0, IsDelete = 0;
                                    for (int i = 0; i < dtCorrectValues.Rows.Count; i++)
                                    {
                                        CurrentCust = objBL.BL_nValidation(dtCorrectValues.Rows[i]["Code"].ToString());
                                        if (tempcust != CurrentCust)
                                        {
                                            IsDelete = 1;
                                        }
                                        DataTable DDT = objBL.BL_ExecuteParamSP("uspImportCustomerRemarks", IsDelete,
                                             CurrentCust,
                                             dtCorrectValues.Rows[i]["Remarks"].ToString());
                                        tempcust = CurrentCust;
                                        IsDelete = 0;
                                    }
                                    if (!NoErrorwhenInsert)
                                    {
                                        strFilePath = FPt + "Error Files\\";
                                        strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                        strSheetName = "Data";
                                        ExportToExcel(dtWrongValues);
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "1",
                                            Msg = "Data Saved with errors. Error occured in some documents. See error list in downloads.",
                                            FileName = strFileName + strExtension,
                                            FilePath = strFilePath + strFileName + strExtension,
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                    else
                                    {
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "0",
                                            Msg = "Data Saved Successfully.",
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                }
                                else
                                {
                                    //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Error Files\\";
                                    strFilePath = FPt + "Error Files\\";
                                    strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                    strSheetName = "Data";
                                    ExportToExcel(dtWrongValues);
                                    MTM.Add(new ImportResults()
                                    {
                                        ID = "1",
                                        Msg = "Data Not Saved. Error occured in some documents. See error list in downloads.",
                                        FileName = strFileName + strExtension,
                                        FilePath = strFilePath + strFileName + strExtension,
                                        Total = Convert.ToString(dtData.Rows.Count),
                                        Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                        UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                    });
                                }
                                return Ok(MTM);
                            }
                            else
                            {
                                Msg = "0";
                            }
                        }
                        #endregion
                        #region Product Opening Import
                        else if (TransID == "10")
                        {
                            if (dtData.Rows.Count > 0)
                            {
                                bool NoErrors = true;
                                foreach (DataRow item in dtData.Rows)
                                {
                                    DataTable dtValidate = dtData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = ProductOpeningImpValidation(dtValidate);
                                    if (string.IsNullOrEmpty(RowError))
                                    {
                                        dtWrongValues.Rows.Add(item.ItemArray);
                                        int rid = dtWrongValues.Rows.Count;
                                        dtWrongValues.Rows[rid - 1]["Error"] = RowError;
                                        //correct values only
                                        dtCorrectValues.Rows.Add(item.ItemArray);
                                        int correctrid = dtCorrectValues.Rows.Count;
                                        dtCorrectValues.Rows[correctrid - 1]["Code *"] = ProductID;
                                        dtCorrectValues.Rows[correctrid - 1]["Branch Name *"] = BranchID;
                                    }
                                    else
                                    {
                                        NoErrors = false;
                                        dtWrongValues.Rows.Add(item.ItemArray);
                                        int rid = dtWrongValues.Rows.Count;
                                        dtWrongValues.Rows[rid - 1]["Error"] = RowError;
                                    }
                                }
                                if (NoErrors)//dtWrongValues.Rows.Count == 0 // no error, create/update records
                                {
                                    DataTable dtErrors = dtWrongValues.Clone();
                                    dtErrors.TableName = "Error Data";
                                    bool NoErrorwhenInsert = true;
                                    DataTable dtProductOpenImport = new DataTable("tvpProductOpeningImport");

                                    dtProductOpenImport.Columns.Add("Date", typeof(DateTime));                // date
                                    dtProductOpenImport.Columns.Add("ProdId", typeof(int));                  // int
                                    dtProductOpenImport.Columns.Add("BranchID", typeof(int));                // int
                                    dtProductOpenImport.Columns.Add("BatchNo", typeof(string));              // nvarchar(255)
                                    dtProductOpenImport.Columns.Add("PKD", typeof(DateTime));                // date
                                    dtProductOpenImport.Columns.Add("Expiry", typeof(DateTime));             // date
                                    dtProductOpenImport.Columns.Add("Qty", typeof(decimal));                 // decimal(25,4)
                                    dtProductOpenImport.Columns.Add("FreeQty", typeof(decimal));             // decimal(25,4)
                                    dtProductOpenImport.Columns.Add("DamageQty", typeof(decimal));           // decimal(25,4)
                                    dtProductOpenImport.Columns.Add("PurchasePrice", typeof(decimal));       // decimal(25,4)
                                    dtProductOpenImport.Columns.Add("SalePrice", typeof(decimal));           // decimal(25,4)
                                    dtProductOpenImport.Columns.Add("ECPPrice", typeof(decimal));            // decimal(25,4)
                                    dtProductOpenImport.Columns.Add("SPLPrice", typeof(decimal));            // decimal(25,4)
                                    dtProductOpenImport.Columns.Add("MRP", typeof(decimal));                 // decimal(25,4)
                                    dtProductOpenImport.Columns.Add("ReturnPrice", typeof(decimal));         // decimal(25,4)
                                    dtProductOpenImport.Columns.Add("Serial", typeof(int));                  // int
                                    for (int i = 0; i < dtCorrectValues.Rows.Count; i++)
                                    {
                                        DataRow drr = dtProductOpenImport.NewRow();
                                        drr["Date"] = DateTime.Today;
                                        drr["ProdId"] = dtCorrectValues.Rows[i]["Code *"];
                                        drr["BranchID"] = dtCorrectValues.Rows[i]["Branch Name *"];
                                        drr["BatchNo"] = dtCorrectValues.Rows[i]["Batch No"];
                                        //drr["PKD"] = dtCorrectValues.Rows[i]["PKD"];
                                        //drr["Expiry"] = dtCorrectValues.Rows[i]["Expiry"];
                                        // PKD
                                        if (dtCorrectValues.Rows[i]["PKD"] == DBNull.Value ||
                                            string.IsNullOrWhiteSpace(dtCorrectValues.Rows[i]["PKD"].ToString()))
                                        {
                                            drr["PKD"] = DBNull.Value;
                                        }
                                        else
                                        {
                                            drr["PKD"] = Convert.ToDateTime(dtCorrectValues.Rows[i]["PKD"]);
                                        }

                                        // Expiry
                                        if (dtCorrectValues.Rows[i]["Expiry"] == DBNull.Value ||
                                            string.IsNullOrWhiteSpace(dtCorrectValues.Rows[i]["Expiry"].ToString()))
                                        {
                                            drr["Expiry"] = DBNull.Value;
                                        }
                                        else
                                        {
                                            drr["Expiry"] = Convert.ToDateTime(dtCorrectValues.Rows[i]["Expiry"]);
                                        }
                                        drr["Qty"] = dtCorrectValues.Rows[i]["Qty *"];
                                        drr["FreeQty"] = dtCorrectValues.Rows[i]["Free Qty *"];
                                        drr["DamageQty"] = dtCorrectValues.Rows[i]["Damage Qty *"];
                                        drr["PurchasePrice"] = dtCorrectValues.Rows[i]["Purchase Price *"];
                                        drr["SalePrice"] = dtCorrectValues.Rows[i]["Sale Price *"];
                                        drr["ECPPrice"] = dtCorrectValues.Rows[i]["ECP *"];
                                        drr["SPLPrice"] = dtCorrectValues.Rows[i]["Special Price *"];
                                        drr["MRP"] = dtCorrectValues.Rows[i]["MRP *"];
                                        drr["ReturnPrice"] = dtCorrectValues.Rows[i]["Return Price *"];
                                        drr["Serial"] = (i + 1);
                                        dtProductOpenImport.Rows.Add(drr);
                                    }
                                    string Error = "";
                                    objBL.bl_Transaction(1);
                                    DataTable dtResult = objBL.bl_ManageTrans("uspManageProductOpeingImport", UserID, dtProductOpenImport);
                                    if(dtResult.Rows.Count > 0)
                                    {
                                        NoErrorwhenInsert = false;
                                        Error = dtResult.Rows[0][0].ToString();
                                        objBL.bl_Transaction(3);
                                    }
                                    else
                                    {
                                        objBL.bl_Transaction(2);
                                    }
                                    if (!NoErrorwhenInsert)
                                    {
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "2",
                                            Msg = Error,
                                            FileName = strFileName + strExtension,
                                            FilePath = strFilePath + strFileName + strExtension,
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                    else
                                    {
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "0",
                                            Msg = "Data Saved Successfully.",
                                            Total = Convert.ToString(dtData.Rows.Count),
                                            Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                        });
                                    }
                                }
                                else
                                {
                                    //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Error Files\\";
                                    strFilePath = FPt + "Error Files\\";
                                    strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                    strSheetName = "Data";
                                    ExportToExcel(dtWrongValues);
                                    MTM.Add(new ImportResults()
                                    {
                                        ID = "1",
                                        Msg = "Data Not Saved. Error occured in some documents. See error list in downloads.",
                                        FileName = strFileName + strExtension,
                                        FilePath = strFilePath + strFileName + strExtension,
                                        Total = Convert.ToString(dtData.Rows.Count),
                                        Saved = Convert.ToString(dtCorrectValues.Rows.Count),
                                        UnSaved = Convert.ToString(dtWrongValues.Rows.Count),
                                    });
                                }
                                return Ok(MTM);
                            }
                            else
                            {
                                Msg = "0";
                            }
                        }
                        #endregion
                    }
                    else
                    {
                        Msg = "2";// column names mismatching
                    }
                }
                else
                {
                    Msg = "1";// file not choosing
                }
            }
            catch (Exception ex)
            {
                objBL.BL_WriteErrorMsginLog("Import/Export", "Save", ex.Message);
                MTM.Add(new ImportResults()
                {
                    ID = "2",
                    Msg = ex.Message,
                });
                return Ok(MTM);
            }
            return Ok(Msg);
        }

        [System.Web.Http.HttpPost]
        [System.Web.Http.Route("api/uploadtransactionimportfile")]
        public IHttpActionResult TransactionFiledata()
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
                    string UserID = HttpContext.Current.Request.Files.AllKeys[2].ToString();
                    //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Upload Files\\";
                    string FPt = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"];
                    strFilePath = FPt + "Upload Files\\";
                    strFileName = TransName + "_Upload_" + fileName;
                    if (!Directory.Exists(strFilePath))
                    {
                        Directory.CreateDirectory(strFilePath);
                    }
                    HttpContext.Current.Request.Files[3].SaveAs(strFilePath + strFileName);
                    bool blHeaderResult = true ,blItemsResult = true;
                    List<string> lstHeader = null;
                    List<string> lstItems = null;
                    #region Header Validation
                    if (TransID == "9")//Quotation Header
                    {
                        lstHeader = QuotationHeaderTemp();
                    }
                    bool HeaderErrorColAlreadyExists = false;
                    TransactionColumnValidation(lstHeader, "Header", ref blHeaderResult);
                    if (!blHeaderResult)
                    {
                        if (TransID == "9")//Quotation Header
                        {
                            lstHeader = QuotationHeaderTempWithErrCol();
                        }
                        TransactionColumnValidation(lstHeader, "Header", ref blHeaderResult);
                        HeaderErrorColAlreadyExists = true;
                    }
                    #endregion
                    #region Items Validation
                    if (TransID == "9")//Quotation Items
                    {
                        lstItems = QuotationItemsTemp();
                    }
                    bool ItemsErrorColAlreadyExists = false;
                    TransactionColumnValidation(lstItems, "Items", ref blHeaderResult);
                    if (!blHeaderResult)
                    {
                        if (TransID == "9")//Quotation Items
                        {
                            lstItems = QuotationItemsTempWithErrCol();
                        }
                        TransactionColumnValidation(lstItems, "Items", ref blHeaderResult);
                        ItemsErrorColAlreadyExists = true;
                    }
                    #endregion
                    if (blHeaderResult && blItemsResult)
                    {                        
                        DataTable dtHeaderCorrectValues = new DataTable();
                        DataTable dtHeaderWrongValues = new DataTable();
                        foreach (string str in lstHeader)
                        {
                            dtHeaderCorrectValues.Columns.Add(str);                            
                            dtHeaderWrongValues.Columns.Add(str);
                        }
                        if(TransID == "9")//additional columns for quotation header
                        {
                            dtHeaderCorrectValues.Columns.Add("PriceTypeID");
                            dtHeaderCorrectValues.Columns.Add("TaxTypeID");
                        }
                        if (!HeaderErrorColAlreadyExists)
                        {
                            dtHeaderCorrectValues.Columns.Add("Error");
                            dtHeaderWrongValues.Columns.Add("Error");
                        }
                        DataTable dtItemsCorrectValues = new DataTable();
                        DataTable dtItemsWrongValues = new DataTable();
                        foreach (string str in lstItems)
                        {
                            dtItemsCorrectValues.Columns.Add(str);
                            dtItemsWrongValues.Columns.Add(str);
                        }
                        if (TransID == "9")//additional columns for quotation Items
                        {
                            dtItemsCorrectValues.Columns.Add("TaxPern");
                        }
                        if (!ItemsErrorColAlreadyExists)
                        {
                            dtItemsCorrectValues.Columns.Add("Error");
                            dtItemsWrongValues.Columns.Add("Error");
                        }
                        #region Quotation
                        if (TransID == "9")
                        {
                            if (dtHeaderData.Rows.Count > 0 && dtItemsData.Rows.Count > 0)
                            {
                                int nIndex = 1;
                                bool NoErrorsinHeader = true, NoErrorsinItems = true;
                                #region Header data validation
                                foreach (DataRow item in dtHeaderData.Rows)
                                {
                                    DataTable dtValidate = dtHeaderData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = QuotatinHeaderValiation(dtValidate);
                                    if (string.IsNullOrEmpty(RowError))
                                    {                                       
                                        DataRow drW = dtHeaderWrongValues.NewRow();
                                        drW["Branch Name *"] = item.ItemArray[0];
                                        drW["Ref No *"] = item.ItemArray[1];
                                        drW["Date *"] = item.ItemArray[2];
                                        drW["Party Name *"] = item.ItemArray[3];
                                        drW["Trade Discount %"] = item.ItemArray[4];
                                        drW["Trade Discount Amount"] = item.ItemArray[5];
                                        drW["Additional Discount %"] = item.ItemArray[6];
                                        drW["Additional Discount Amount"] = item.ItemArray[7];
                                        drW["Freight"] = item.ItemArray[8];
                                        drW["Other Charge Amount"] = item.ItemArray[9];
                                        drW["Remarks"] = item.ItemArray[10];
                                        drW["Narration"] = item.ItemArray[11];
                                        drW["Net Amount *"] = item.ItemArray[12];
                                        drW["Error"] = RowError;
                                        dtHeaderWrongValues.Rows.Add(drW);
                                        //Correct values only
                                        DataRow drC = dtHeaderCorrectValues.NewRow();
                                        drC["Branch Name *"] = BranchID;
                                        drC["Ref No *"] = item.ItemArray[1];
                                        drC["Date *"] = item.ItemArray[2];
                                        drC["Party Name *"] = CustomerID;
                                        drC["PriceTypeID"] = PriceTypeID;
                                        drC["TaxTypeID"] = TaxTypeID;
                                        drC["Trade Discount %"] = item.ItemArray[4];
                                        drC["Trade Discount Amount"] = item.ItemArray[5];
                                        drC["Additional Discount %"] = item.ItemArray[6];
                                        drC["Additional Discount Amount"] = item.ItemArray[7];
                                        drC["Freight"] = item.ItemArray[8];
                                        drC["Other Charge Amount"] = item.ItemArray[9];
                                        drC["Remarks"] = item.ItemArray[10];
                                        drC["Narration"] = item.ItemArray[11];
                                        drC["Net Amount *"] = item.ItemArray[12];
                                        drC["Error"] = nIndex;
                                        dtHeaderCorrectValues.Rows.Add(drC);
                                        nIndex++;
                                    }
                                    else
                                    {
                                        NoErrorsinHeader = false;
                                        DataRow drW = dtHeaderWrongValues.NewRow();
                                        drW["Branch Name *"] = item.ItemArray[0];
                                        drW["Ref No *"] = item.ItemArray[1];
                                        drW["Date *"] = item.ItemArray[2];
                                        drW["Party Name *"] = item.ItemArray[3];
                                        drW["Trade Discount %"] = item.ItemArray[4];
                                        drW["Trade Discount Amount"] = item.ItemArray[5];
                                        drW["Additional Discount %"] = item.ItemArray[6];
                                        drW["Additional Discount Amount"] = item.ItemArray[7];
                                        drW["Freight"] = item.ItemArray[8];
                                        drW["Other Charge Amount"] = item.ItemArray[9];
                                        drW["Remarks"] = item.ItemArray[10];
                                        drW["Narration"] = item.ItemArray[11];
                                        drW["Net Amount *"] = item.ItemArray[12];
                                        drW["Error"] = RowError;
                                        dtHeaderWrongValues.Rows.Add(drW);
                                    }
                                }
                                #endregion
                                #region Items data validation
                                foreach (DataRow item in dtItemsData.Rows)
                                {
                                    DataTable dtValidate = dtItemsData.Clone();
                                    dtValidate.TableName = "Validation";
                                    dtValidate.Rows.Add(item.ItemArray);
                                    string RowError = QuotatinItemsValiation(dtValidate);
                                    if (string.IsNullOrEmpty(RowError))
                                    {
                                        DataRow drW = dtItemsWrongValues.NewRow();
                                        drW["Ref No *"] = item.ItemArray[0];
                                        drW["Product Code *"] = item.ItemArray[1];
                                        drW["Product Name *"] = item.ItemArray[2];
                                        drW["MRP *"] = item.ItemArray[3];
                                        drW["UOM Price *"] = item.ItemArray[4];
                                        drW["Uom Qty *"] = item.ItemArray[5];
                                        drW["UOM Name *"] = item.ItemArray[6];
                                        drW["Product Discount %"] = item.ItemArray[7];
                                        drW["Product Discount Amount"] = item.ItemArray[8];
                                        drW["Trade Discount %"] = item.ItemArray[9];
                                        drW["Trade Discount Amount"] = item.ItemArray[10];
                                        drW["Additional Discount %"] = item.ItemArray[11];
                                        drW["Additional Discount Amount"] = item.ItemArray[12];
                                        drW["Tax Name *"] = item.ItemArray[13];
                                        drW["Reason"] = item.ItemArray[14];
                                        drW["Error"] = RowError;
                                        dtItemsWrongValues.Rows.Add(drW);
                                        //Correct values only
                                        DataRow drC = dtItemsCorrectValues.NewRow();
                                        drC["Ref No *"] = item.ItemArray[0];
                                        drC["Product Code *"] = ProductID;
                                        drC["Product Name *"] = ProductID;
                                        drC["MRP *"] = item.ItemArray[3];
                                        drC["UOM Price *"] = item.ItemArray[4];
                                        drC["Uom Qty *"] = item.ItemArray[5];
                                        drC["UOM Name *"] = UOMID;
                                        drC["Product Discount %"] = item.ItemArray[7];
                                        drC["Product Discount Amount"] = item.ItemArray[8];
                                        drC["Trade Discount %"] = item.ItemArray[9];
                                        drC["Trade Discount Amount"] = item.ItemArray[10];
                                        drC["Additional Discount %"] = item.ItemArray[11];
                                        drC["Additional Discount Amount"] = item.ItemArray[12];
                                        drC["Tax Name *"] = TaxID;
                                        drC["TaxPern"] = TaxPern;
                                        drC["Reason"] = item.ItemArray[14];
                                        drC["Error"] = nIndex;
                                        dtItemsCorrectValues.Rows.Add(drC);
                                        nIndex++;
                                    }
                                    else
                                    {
                                        NoErrorsinItems = false;
                                        DataRow drW = dtItemsWrongValues.NewRow();
                                        drW["Ref No *"] = item.ItemArray[0];
                                        drW["Product Code *"] = item.ItemArray[1];
                                        drW["Product Name *"] = item.ItemArray[2];
                                        drW["MRP *"] = item.ItemArray[3];
                                        drW["UOM Price *"] = item.ItemArray[4];
                                        drW["Uom Qty *"] = item.ItemArray[5];
                                        drW["UOM Name *"] = item.ItemArray[6];
                                        drW["Product Discount %"] = item.ItemArray[7];
                                        drW["Product Discount Amount"] = item.ItemArray[8];
                                        drW["Trade Discount %"] = item.ItemArray[9];
                                        drW["Trade Discount Amount"] = item.ItemArray[10];
                                        drW["Additional Discount %"] = item.ItemArray[11];
                                        drW["Additional Discount Amount"] = item.ItemArray[12];
                                        drW["Tax Name *"] = item.ItemArray[13];
                                        drW["Reason"] = item.ItemArray[14];
                                        drW["Error"] = RowError;
                                        dtItemsWrongValues.Rows.Add(drW);
                                    }
                                }
                                #endregion
                                if (NoErrorsinHeader && NoErrorsinItems)//dtWrongValues.Rows.Count == 0
                                {
                                    #region Datatable initialize
                                    DataTable dtProd = new DataTable();
                                    DataTable dtGSTInfo = new DataTable();
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
                                        dtProd.Columns.Add("SecondarySchemeID", typeof(int));
                                    
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
                                    for (int i = 0; i < dtHeaderCorrectValues.Rows.Count; i++)
                                    {
                                        string DocID = dtHeaderCorrectValues.Rows[i]["Ref No *"].ToString();
                                        dtProd.Rows.Clear();
                                        DataRow[] DRR = dtItemsCorrectValues.Select("[Ref No *] = '" + DocID + "'");
                                        if (DRR.Length > 0)
                                        {
                                            for (int j = 0; j < DRR.Length; j++)
                                            {
                                                decimal ProdDiscPern =
                                                    objBL.BL_dValidation(Convert.ToString(DRR[j]["Product Discount %"])), 
                                                    ProdDiscAmt = objBL.BL_dValidation(Convert.ToString(DRR[j]["Product Discount Amount"])), 
                                                    TradeDiscPern = objBL.BL_dValidation(Convert.ToString(DRR[j]["Trade Discount %"])), 
                                                    TradeDiscAmt = objBL.BL_dValidation(Convert.ToString(DRR[j]["Trade Discount Amount"])), 
                                                    AddnlDiscPern = objBL.BL_dValidation(Convert.ToString(DRR[j]["Additional Discount %"])), 
                                                    AddnlDiscAmt = objBL.BL_dValidation(Convert.ToString(DRR[j]["Additional Discount Amount"]));
                                                decimal dQty = objBL.BL_dValidation(Convert.ToString(DRR[j]["Uom Qty *"]));
                                                decimal dPrice = objBL.BL_dValidation(Convert.ToString(DRR[j]["UOM Price *"]));
                                                decimal dTaxPern = objBL.BL_dValidation(Convert.ToString(DRR[j]["TaxPern"]));
                                                decimal dGoodsAmt = (dQty * dPrice);

                                                decimal dGrossAmt = dGoodsAmt - (ProdDiscAmt + TradeDiscAmt + AddnlDiscAmt);
                                                decimal dTaxAmt = (dGrossAmt * dTaxPern) / 100;
                                                decimal dNetAmt = dGrossAmt + dTaxAmt;
                                                DataRow dtRow = dtProd.NewRow();
                                                dtRow["ProdId"] = objBL.BL_nValidation(Convert.ToString(DRR[j]["Product Code *"]));
                                                dtRow["InventoryYesNo"] = 0;
                                                dtRow["BatchYesNo"] = 0;
                                                dtRow["PKDYesNo"] = 0;
                                                dtRow["SerialYesNo"] = 0;
                                                dtRow["BaseUomPrice"] = objBL.BL_dValidation(Convert.ToString(DRR[j]["UOM Price *"]));
                                                dtRow["UomId"] = objBL.BL_nValidation(Convert.ToString(DRR[j]["UOM Name *"]));
                                                dtRow["UomQty"] = dQty;
                                                dtRow["UomPrice"] = dPrice;
                                                dtRow["GoodsAmt"] = dGoodsAmt;
                                                dtRow["UserDisc"] = 0;
                                                dtRow["UserDiscAmt"] = 0;
                                                dtRow["ProdDisc"] = ProdDiscPern;
                                                dtRow["ProdDiscAmt"] = ProdDiscAmt;
                                                dtRow["TradeDisc"] = TradeDiscAmt;
                                                dtRow["TradeDiscPern"] = TradeDiscPern;
                                                dtRow["AddnlDisc"] = AddnlDiscAmt;
                                                dtRow["AddnlDiscPern"] = AddnlDiscPern;
                                                dtRow["GrossAmt"] = dGrossAmt;
                                                dtRow["TaxId"] = objBL.BL_nValidation(Convert.ToString(DRR[j]["Tax Name *"]));
                                                dtRow["TaxPercentage"] = objBL.BL_dValidation(Convert.ToString(DRR[j]["TaxPern"]));
                                                dtRow["TaxAmt"] = dTaxAmt;
                                                dtRow["NetAmt"] = dNetAmt;
                                                dtRow["ReasonId"] = 0;
                                                dtRow["Serial"] = (j + 1);
                                                dtRow["BatchNumber"] = null;
                                                dtRow["PkgDate"] = null;
                                                dtRow["ExpiryDate"] = null;
                                                dtRow["InventoryPrice"] = 0;
                                                dtRow["MRP"] = objBL.BL_dValidation(Convert.ToString(DRR[j]["MRP *"]));
                                                dtRow["UomCR"] = 0;
                                                dtRow["InvQtyType"] = 1;
                                                dtRow["TempBatchInvId"] = 0;
                                                dtRow["SecondarySchemeID"] = 0;
                                                dtProd.Rows.Add(dtRow);
                                            }
                                            //decimal ProdDiscAmt = 0, TradeDiscAmt = 0, AddnlDiscAmt = 0;
                                            object dProdDiscAmt = dtProd.Compute("sum(ProdDiscAmt)", null);
                                            object dTradeDiscAmt = (dtProd.Compute("sum(TradeDisc)", null));
                                            object dAddnlDiscAmt = (dtProd.Compute("sum(AddnlDisc)", null));

                                            object gross = objBL.BL_dValidation(dtProd.Compute("sum(GrossAmt)", null));
                                            object Tax = objBL.BL_dValidation(dtProd.Compute("sum(TaxAmt)", null));
                                            object Net = objBL.BL_dValidation(dtProd.Compute("sum(NetAmt)", null));
                                            decimal HeaderNetAmount = objBL.BL_dValidation(dtHeaderCorrectValues.Rows[i]["Net Amount *"].ToString());
                                            decimal Roundoff = HeaderNetAmount - objBL.BL_dValidation(Net);
                                            if(Roundoff > 1)
                                            {
                                                dtHeaderWrongValues.Rows[i]["Error"] = "Net Amount Mistmatch between Header and Items";
                                                NoErrorsinHeader = false;
                                                continue;
                                            }
                                            decimal OtherChargeAmt = objBL.BL_dValidation(dtHeaderCorrectValues.Rows[i]["Other Charge Amount"].ToString());
                                            decimal OtherChargePern = (OtherChargeAmt / (objBL.BL_dValidation(gross) + objBL.BL_dValidation(Tax))) * 100;
                                            objBL.bl_Transaction(1);
                                            DataTable dtResult = objBL.bl_ManageTrans("uspManageQuatation", dtProd, 1, 0,
                                    dtHeaderCorrectValues.Rows[i]["Date *"].ToString(), 14, dtHeaderCorrectValues.Rows[i]["Branch Name *"].ToString(),
                                    dtHeaderCorrectValues.Rows[i]["Party Name *"].ToString(), DocID,
                                    dtHeaderCorrectValues.Rows[i]["PriceTypeID"].ToString(),
                                    dtHeaderCorrectValues.Rows[i]["TaxTypeID"].ToString(), 
                                    objBL.BL_dValidation(dtHeaderCorrectValues.Rows[i]["Trade Discount %"].ToString()), 
                                    objBL.BL_dValidation(dTradeDiscAmt),
                                    objBL.BL_dValidation(dtHeaderCorrectValues.Rows[i]["Additional Discount %"].ToString()), 
                                    objBL.BL_dValidation(dAddnlDiscAmt), 
                                    objBL.BL_dValidation(OtherChargePern),
                                    objBL.BL_dValidation(OtherChargeAmt), 
                                    objBL.BL_dValidation(dtHeaderCorrectValues.Rows[i]["Freight"].ToString()),
                                    objBL.BL_dValidation(dProdDiscAmt),
                                    objBL.BL_dValidation(dProdDiscAmt) + objBL.BL_dValidation(dTradeDiscAmt) + objBL.BL_dValidation(dAddnlDiscAmt),
                                    objBL.BL_dValidation(gross), 
                                    objBL.BL_dValidation(Tax),
                                    objBL.BL_dValidation(HeaderNetAmount), 
                                    objBL.BL_dValidation(Roundoff), 
                                    1,
                                    0, objBL.BL_nValidation(UserID), dtHeaderCorrectValues.Rows[i]["Remarks"].ToString(),
                                    dtHeaderCorrectValues.Rows[i]["Narration"].ToString(), 0,
                                    1);
                                            if (dtResult.Columns.Count > 1)
                                            {
                                                objBL.bl_Transaction(3);                                               
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
                                                        nTaxTypeID = objBL.BL_nValidation(dtHeaderCorrectValues.Rows[i]["TaxTypeID"].ToString());
                                                        dQtnGrossAmount = objBL.BL_dValidation(dtProd.Rows[nCount]["GrossAmt"]);

                                                        //DataTable getConvFact = objBL.BL_ExecuteSqlQuery("select dbo.fnGetConvertionFact(" + objBL.BL_nValidation(dtProd.Rows[nCount]["UomGrpID"]) + "," + objBL.BL_nValidation(dtProd.Rows[nCount]["UomId"]) + ")");

                                                        dQtys = (objBL.BL_dValidation(dtProd.Rows[nCount]["UomQty"])) * 1;// objBL.BL_dValidation(dtResult.Rows[0][0]);

                                                        DataTable dtTaxCompInfo = objBL.bl_ManageTrans("uspGetTaxCompInfo", nTaxID, nTaxTypeID);
                                                        if (dtTaxCompInfo.Rows.Count > 0)
                                                        {
                                                            bool ValidtoCalc = false;

                                                            for (int nTaxComp = 0; nTaxComp < dtTaxCompInfo.Rows.Count; nTaxComp++)
                                                            {
                                                                ValidtoCalc = true;
                                                                //nTaxTypeID == 1 && objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 1 ||
                                                                //       nTaxTypeID == 2 && objBL.BL_nValidation(dtTaxCompInfo.Rows[nTaxComp][1]) == 2 ? false : true;
                                                                DataRow dr = dtGSTInfo.NewRow();
                                                                dr["TransID"] = 14;
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
                                            }
                                        }
                                    }
                                    if (NoErrorsinHeader && NoErrorsinItems)//dtWrongValues.Rows.Count == 0
                                    {
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "0",
                                            Msg = "Data Saved Successfully.",
                                            Total = Convert.ToString(dtHeaderWrongValues.Rows.Count),
                                            Saved = Convert.ToString(dtHeaderCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtHeaderWrongValues.Rows.Count),
                                        });
                                    }
                                    else
                                    {
                                        strFilePath = FPt + "Error Files\\";
                                        strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                        //strSheetName = "Data";
                                        ExportToExcelTwoSheet(dtHeaderWrongValues, "Header", dtItemsWrongValues, "Items");
                                        MTM.Add(new ImportResults()
                                        {
                                            ID = "1",
                                            Msg = "Valid Data Saved. But, Error occured in some documents. See error list in downloads.",
                                            FileName = strFileName + strExtension,
                                            FilePath = strFilePath + strFileName + strExtension,
                                            Total = Convert.ToString(dtHeaderWrongValues.Rows.Count),
                                            Saved = Convert.ToString(dtHeaderCorrectValues.Rows.Count),
                                            UnSaved = Convert.ToString(dtHeaderWrongValues.Rows.Count),
                                        });
                                    }
                                }
                                //if (!NoErrors)
                                else
                                {
                                    //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Error Files\\";
                                    strFilePath = FPt + "Error Files\\";
                                    strFileName = TransName + "_Error_" + DateTime.Now.ToString("yyyyMMddHHmmss");
                                    //strSheetName = "Data";
                                    ExportToExcelTwoSheet(dtHeaderWrongValues, "Header", dtItemsWrongValues, "Items");
                                    MTM.Add(new ImportResults()
                                    {
                                        ID = "1",
                                        Msg = "Data Not Saved. Error occured in some documents. See error list in downloads.",
                                        FileName = strFileName + strExtension,
                                        FilePath = strFilePath + strFileName + strExtension,
                                        Total = Convert.ToString(dtHeaderWrongValues.Rows.Count),
                                        Saved = Convert.ToString(dtHeaderCorrectValues.Rows.Count),
                                        UnSaved = Convert.ToString(dtHeaderWrongValues.Rows.Count),
                                    });
                                }
                                return Ok(MTM);
                            }
                            else
                            {
                                if (dtHeaderData.Rows.Count == 0 && dtItemsData.Rows.Count == 0)
                                {
                                    Msg = "0.1";// no records found in both sheet;
                                }
                                else if(dtHeaderData.Rows.Count == 0)
                                {
                                    Msg = "0.2";// no records found in Header sheet;
                                }
                                else if (dtItemsData.Rows.Count == 0)
                                {
                                    Msg = "0.3";// no records found in Items sheet;
                                }
                            }
                        }
                        #endregion
                    }
                    else
                    {
                        if (!blHeaderResult && !blItemsResult)
                        {
                            Msg = "21";// Header and Items column names mismatching
                        }
                        else if (!blHeaderResult)
                        {
                            Msg = "22";// Header column names mismatching
                        }
                        else if (!blItemsResult)
                        {
                            Msg = "23";// Items column names mismatching
                        }
                    }
                }
                else
                {
                    Msg = "1";// file not choosing
                }
            }
            catch (Exception ex)
            {
                MTM.Add(new ImportResults()
                {
                    ID = "2",
                    Msg = ex.Message + " Date : " + dt,
                });
                return Ok(MTM);
            }
            return Ok(Msg);
        }
        public string ProductOpeningImpValidation(DataTable dtCheck)
        {
            string RowError = "";
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Branch Name *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Branch Name *"].ToString()))
                {
                    RowError += "* Branch Name : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 7, 3, dtCheck.Rows[0]["Branch Name *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* Branch Name not found in Database\n";
                    }
                    else
                    {
                        BranchID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "* Branch Name : Branch Name should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Code *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Code *"].ToString()))
                {
                    RowError += "* Code : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 12, 3, dtCheck.Rows[0]["Code *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        //RowError += "* * Code not found in Database\n";
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
                RowError += "* Code : Code should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Name *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Name *"].ToString()))
                {
                    RowError += "* Product Name : Invalid Characters\n";
                }
                else
                {
                    if (ProductID == 0)
                    {
                        DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 5, 3, dtCheck.Rows[0]["Name *"].ToString());
                        if (dt.Rows.Count == 0)
                        {
                            RowError += "* Product Code/Name not found in Database\n";
                        }
                        else
                        {
                            ProductID = Convert.ToInt32(dt.Rows[0][0].ToString());
                        }
                    }
                }
            }

            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Batch No"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Batch No"].ToString()))
                {
                    RowError += "* Batch No : Invalid Characters\n";
                }                
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PKD"].ToString()))
            {
                if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["PKD"].ToString()))
                {
                    RowError += "* PKD : Invalid Format(DD/MM/YYYY) Only\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Expiry"].ToString()))
            {
                if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["Expiry"].ToString()))
                {
                    RowError += "* Expiry : Invalid Format(DD/MM/YYYY) Only\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Qty *"].ToString()))
            {
                RowError += "* Qty : Qty should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Qty *"].ToString()))
                {
                    RowError += "* Qty : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Free Qty *"].ToString()))
            {
                RowError += "* Free Qty : Free Qty should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Free Qty *"].ToString()))
                {
                    RowError += "* Free Qty : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Damage Qty *"].ToString()))
            {
                RowError += "* Damage Qty : Damage Qty should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Damage Qty *"].ToString()))
                {
                    RowError += "* Damage Qty : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Purchase Price *"].ToString()))
            {
                RowError += "* Purchase Price : Purchase Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Purchase Price *"].ToString()))
                {
                    RowError += "* Purchase Price : Invalid character\n";
                }
            }

            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Sale Price *"].ToString()))
            {
                RowError += "* Sales Price : Sales Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Sale Price *"].ToString()))
                {
                    RowError += "* Sales Price : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["ECP *"].ToString()))
            {
                RowError += "* ECP : ECP Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["ECP *"].ToString()))
                {
                    RowError += "* ECP : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Special Price *"].ToString()))
            {
                RowError += "* Special Price : SPL Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Special Price *"].ToString()))
                {
                    RowError += "* Special Price : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["MRP *"].ToString()))
            {
                RowError += "* MRP : MRP should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["MRP *"].ToString()))
                {
                    RowError += "* MRP : Invalid character\n";
                }
            }

            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Return Price *"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Return Price *"].ToString()))
                {
                    RowError += "* Return Price : Invalid character\n";
                }
            }
            else
            {
                RowError += "* Return Price : Return Price should not be empty\n";
            }
            return RowError;
        }
        public string CustomerImpValiation(DataTable dtCheck)
        {
            string RowError = "";

            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Code *"].ToString()))
            {
                RowError += "Code : Code should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Code *"].ToString()))
                {
                    RowError += "Code : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Name *"].ToString()))
            {
                RowError += "Name : Name should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Name *"].ToString()))
                {
                    RowError += "Name : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Customer Type"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Customer Type"].ToString()))
                {
                    RowError += "Customer Type : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Price Type *"].ToString()))
            {
                RowError += "Price Type should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Price Type *"].ToString()))
                {
                    RowError += "Price Type : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Owner Name"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Owner Name"].ToString()))
                {
                    RowError += "Owner Name : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Contact Person"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Contact Person"].ToString()))
                {
                    RowError += "Contact Person : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Email ID"].ToString()))
            {
                if (!objBL.BL_Email(dtCheck.Rows[0]["Email ID"].ToString()))
                {
                    RowError += "Email ID : Invalid Email Format\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Phone No 1"].ToString()))
            {
                if (!objBL.BL_MobileNumberValidate(dtCheck.Rows[0]["Phone No 1"].ToString()))
                {
                    RowError += "Phone No 1 : Invalid Phone No Format\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Phone No 2"].ToString()))
            {
                if (!objBL.BL_MobileNumberValidate(dtCheck.Rows[0]["Phone No 2"].ToString()))
                {
                    RowError += "Phone No 2 : Invalid Phone No Format\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Mobile No 1"].ToString()))
            {
                if (!objBL.BL_MobileNumberValidate(dtCheck.Rows[0]["Mobile No 1"].ToString()))
                {
                    RowError += "Mobile No 1 : Invalid Mobile No Format\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Mobile No 2"].ToString()))
            {
                if (!objBL.BL_MobileNumberValidate(dtCheck.Rows[0]["Mobile No 2"].ToString()))
                {
                    RowError += "Mobile No 2 : Invalid Mobile No Format\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Billing Address 1"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Billing Address 1"].ToString()))
                {
                    RowError += "Billing Address 1 : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Billing Address 2"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Billing Address 2"].ToString()))
                {
                    RowError += "Billing Address 2 : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Billing Address 3"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Billing Address 3"].ToString()))
                {
                    RowError += "Billing Address 3 : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Shipping Address 1"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Shipping Address 1"].ToString()))
                {
                    RowError += "Shipping Address 1 : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Shipping Address 2"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Shipping Address 2"].ToString()))
                {
                    RowError += "Shipping Address 2 : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Shipping Address 3"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Shipping Address 3"].ToString()))
                {
                    RowError += "Shipping Address 3 : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Pincode *"].ToString()))
            {
                RowError += "Pincode should not be empty\n";
            }
            else
            {
                if (!objBL.BL_PinNumberValidate(dtCheck.Rows[0]["Pincode *"].ToString()))
                {
                    RowError += "Pincode : Invalid character(Numbers only)\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Distance"].ToString()))
            {
                if (!objBL.BL_Numeric(dtCheck.Rows[0]["Distance"].ToString()))
                {
                    RowError += "Distance : Invalid character(Numbers only)\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Credit Limit Value"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Credit Limit Value"].ToString()))
                {
                    RowError += "Credit Limit Value : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Credit Limit Count"].ToString()))
            {
                if (!objBL.BL_Numeric(dtCheck.Rows[0]["Credit Limit Count"].ToString()))
                {
                    RowError += "Credit Limit Count : Invalid character(Numbers only)\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Over Due Value"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Over Due Value"].ToString()))
                {
                    RowError += "Over Due Value : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Over Due Inv Count"].ToString()))
            {
                if (!objBL.BL_Numeric(dtCheck.Rows[0]["Over Due Inv Count"].ToString()))
                {
                    RowError += "Over Due Inv Count : Invalid character(Numbers only)\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PAN Number"].ToString()))
            {
                if (!objBL.BL_PANValidation(dtCheck.Rows[0]["PAN Number"].ToString()))
                {
                    RowError += "PAN Number : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Aadhar No"].ToString()))
            {
                if (!objBL.BL_AadhaarValidate(dtCheck.Rows[0]["Aadhar No"].ToString()))
                {
                    RowError += "Aadhar No : Invalid character(Numbers only)\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["FSSAI No"].ToString()))
            {
                if (!objBL.BL_FSSAIValidate(dtCheck.Rows[0]["FSSAI No"].ToString()))
                {
                    RowError += "FSSAI No : Invalid character(Numbers only)\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["State Name"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["State Name"].ToString()))
                {
                    RowError += "State Name : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["GSTIN"].ToString()))
            {
                if (!objBL.BL_isValidGSTIN(dtCheck.Rows[0]["GSTIN"].ToString()))
                {
                    RowError += "GSTIN : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Tax Type *"].ToString()))
            {
                RowError += "Tax Type should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumeric(dtCheck.Rows[0]["Tax Type *"].ToString()))
                {
                    RowError += "Tax Type : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Payment Mode"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Payment Mode"].ToString()))
                {
                    RowError += "Payment Mode : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Credit Term"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Credit Term"].ToString()))
                {
                    RowError += "Credit Term : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Discount %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Discount %"].ToString()))
                {
                    RowError += "Discount % : Invalid character\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Discount %"].ToString()) > 100)
                    {
                        RowError += "Discount % : % should be less than 100\n";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Remark"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Remark"].ToString()))
                {
                    RowError += "Remark : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Rating"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Rating"].ToString()))
                {
                    RowError += "Rating : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["TCS Tax"].ToString()))
            {
                RowError += "TCS Tax should not be empty\n\n";
            }
            else
            {
                if (dtCheck.Rows[0]["TCS Tax"].ToString().ToUpper() != "Y" && dtCheck.Rows[0]["TCS Tax"].ToString().ToUpper() != "N")
                {
                    RowError += "TCS Tax : Value should be Y or N\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Track Point"].ToString()))
            {
                RowError += "Track Point should not be empty\n\n";
            }
            else
            {
                if (dtCheck.Rows[0]["Track Point"].ToString().ToUpper() != "Y" && dtCheck.Rows[0]["Track Point"].ToString().ToUpper() != "N")
                {
                    RowError += "Track Point : Value should be Y or N\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Active"].ToString()))
            {
                RowError += "Active should not be empty\n\n";
            }
            else
            {
                if (dtCheck.Rows[0]["Active"].ToString().ToUpper() != "Y" && dtCheck.Rows[0]["Active"].ToString().ToUpper() != "N")
                {
                    RowError += "Active : Value should be Y or N\n";
                }
            }
            //Code *	Name *	Customer Type	Price Type *	Owner Name	Contact Person	Email ID	Phone No 1	
            //Phone No 2	Mobile No 1	Mobile No 2	Billing Address 1	Billing Address 2	Billing Address 3	
            //Shipping Address 1	Shipping Address 2	Shipping Address 3	Pincode *	Distance	Credit Limit Value	
            //Credit Limit Count	Over Due Value	Over Due Inv Count	PAN Number	Aadhar No	FSSAI No	DL No 20	
            //DL No 21	State Name	GSTIN	Tax Type *	Payment Mode	Credit Term	Discount %	Remark	Rating	
            //TCS Tax	Track Point	Active

            return RowError;
        }
        public string ProductImpValiation(DataTable dtCheck)
        {
            string RowError = "";
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Code *"].ToString()))
            {
                RowError += "Code : Code should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Code *"].ToString()))
                {
                    RowError += "Code : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Name *"].ToString()))
            {
                RowError += "Name : Name should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Name *"].ToString()))
                {
                    RowError += "Name : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["EAN *"].ToString()))
            {
                RowError += "EAN : EAN should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["EAN *"].ToString()))
                {
                    RowError += "EAN : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Mfr Name *"].ToString()))
            {
                RowError += "Mfr Name : Mfr Name should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Mfr Name *"].ToString()))
                {
                    RowError += "Mfr Name : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Brand Name *"].ToString()))
            {
                RowError += "Brand Name : Brand Name should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Brand Name *"].ToString()))
                {
                    RowError += "Brand Name : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Category Name *"].ToString()))
            {
                RowError += "Category Name : Category Name should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Category Name *"].ToString()))
                {
                    RowError += "Category Name : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["HSN Code"].ToString()))
            {
                if (!objBL.BL_HSNSACValidation(dtCheck.Rows[0]["HSN Code"].ToString()))
                {
                    RowError += "HSN Code : Invalid Format(Upto 8 Numeric Only)\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Discount %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Discount %"].ToString()))
                {
                    RowError += "Discount % : Invalid Format(Numbers Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Discount %"].ToString()) > 100)
                    {
                        RowError += "Discount % : % should be lessthan 100\n";
                    }
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Base Uom *"].ToString()))
            {
                RowError += "Base Uom : Base Uom should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Base Uom *"].ToString()))
                {
                    RowError += "Base Uom : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Base CR *"].ToString()))
            {
                RowError += "Base CR : Base CR should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Base CR *"].ToString()))
                {
                    RowError += "Base CR : Invalid character\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Base CR *"].ToString()) != 1)
                    {
                        RowError += "Base CR : Base CR must be 1\n";
                    }
                }
            }

            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Purchase Uom *"].ToString()))
            {
                RowError += "Purchase Uom : Purchase Uom should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Purchase Uom *"].ToString()))
                {
                    RowError += "Purchase Uom : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Purchase CR *"].ToString()))
            {
                RowError += "Purchase CR : Purchase CR should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Purchase CR *"].ToString()))
                {
                    RowError += "Purchase CR : Invalid character\n";
                }
            }

            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Sales Uom *"].ToString()))
            {
                RowError += "Sales Uom : Sales Uom should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Sales Uom *"].ToString()))
                {
                    RowError += "Sales Uom : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Sales CR *"].ToString()))
            {
                RowError += "Sales CR : Sales CR should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Sales CR *"].ToString()))
                {
                    RowError += "Sales CR : Invalid character\n";
                }
            }

            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Reporting Uom *"].ToString()))
            {
                RowError += "Reporting Uom : Reporting Uom should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Reporting Uom *"].ToString()))
                {
                    RowError += "Reporting Uom : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Reporting CR *"].ToString()))
            {
                RowError += "Reporting CR : Reporting CR should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Reporting CR *"].ToString()))
                {
                    RowError += "Reporting CR : Invalid character\n";
                }
            }
            //if (string.IsNullOrEmpty(dtCheck.Rows[0]["Reporting Qty *"].ToString()))
            //{
            //    RowError += "Reporting Qty : Reporting Uom should not be empty\n";
            //}
            //else
            //{
            //    if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Reporting Qty *"].ToString()))
            //    {
            //        RowError += "Reporting Qty : Invalid character\n";
            //    }
            //}

            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Purchase Tax *"].ToString()))
            {
                RowError += "Purchase Tax : Purchase Tax should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Purchase Tax *"].ToString()))
                {
                    RowError += "Purchase Tax : Invalid character\n";
                }
            }

            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Sales Tax *"].ToString()))
            {
                RowError += "Sales Tax : Sales Tax should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Sales Tax *"].ToString()))
                {
                    RowError += "Sales Tax : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Sale on MRP"].ToString()))
            {
                RowError += "Sale on MRP : Sale on MRP should not be empty\n\n";
            }
            else
            {
                if (dtCheck.Rows[0]["Sale on MRP"].ToString().ToUpper() != "Y" && dtCheck.Rows[0]["Sale on MRP"].ToString().ToUpper() != "N")
                {
                    RowError += "Sale on MRP : Value should be Y or N\n";
                }
            }

            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Sales Margin %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Sales Margin %"].ToString()))
                {
                    RowError += "Sales Margin % : Invalid character\n";
                }
            }

            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Sales Price *"].ToString()))
            {
                RowError += "Sales Price : Sales Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Sales Price *"].ToString()))
                {
                    RowError += "Sales Price : Invalid character\n";
                }
            }
            //ecp
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["ECP on MRP"].ToString()))
            {
                RowError += "ECP on MRP : ECP on MRP should not be empty\n\n";
            }
            else
            {
                if (dtCheck.Rows[0]["ECP on MRP"].ToString().ToUpper() != "Y" && dtCheck.Rows[0]["ECP on MRP"].ToString().ToUpper() != "N")
                {
                    RowError += "ECP on MRP : Value should be Y or N\n";
                }
            }

            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["ECP Margin %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["ECP Margin %"].ToString()))
                {
                    RowError += "ECP Margin % : Invalid character\n";
                }
            }

            if (string.IsNullOrEmpty(dtCheck.Rows[0]["ECP *"].ToString()))
            {
                RowError += "ECP : ECP Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["ECP *"].ToString()))
                {
                    RowError += "ECP : Invalid character\n";
                }
            }
            //spl
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["SPL on MRP"].ToString()))
            {
                RowError += "SPL on MRP : SPL on MRP should not be empty\n\n";
            }
            else
            {
                if (dtCheck.Rows[0]["SPL on MRP"].ToString().ToUpper() != "Y" && dtCheck.Rows[0]["SPL on MRP"].ToString().ToUpper() != "N")
                {
                    RowError += "SPL on MRP : Value should be Y or N\n";
                }
            }

            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["SPL Margin %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["SPL Margin %"].ToString()))
                {
                    RowError += "SPL Margin % : Invalid character\n";
                }
            }

            if (string.IsNullOrEmpty(dtCheck.Rows[0]["SPL Price *"].ToString()))
            {
                RowError += "SPL Price : SPL Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["SPL Price *"].ToString()))
                {
                    RowError += "SPL Price : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["MRP *"].ToString()))
            {
                RowError += "MRP : MRP should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["MRP *"].ToString()))
                {
                    RowError += "MRP : Invalid character\n";
                }
            }

            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Return Price"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Return Price"].ToString()))
                {
                    RowError += "Return Price : Invalid character\n";
                }
            }
            //
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Track Inventory"].ToString()))
            {
                RowError += "Track Inventory : Track Inventory should not be empty\n\n";
            }
            else
            {
                if (dtCheck.Rows[0]["Track Inventory"].ToString().ToUpper() != "Y" && dtCheck.Rows[0]["Track Inventory"].ToString().ToUpper() != "N")
                {
                    RowError += "Track Inventory : Value should be Y or N\n";
                }
            }
            //
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Track Batch"].ToString()))
            {
                RowError += "Track Batch : Track Batch should not be empty\n\n";
            }
            else
            {
                if (dtCheck.Rows[0]["Track Batch"].ToString().ToUpper() != "Y" && dtCheck.Rows[0]["Track Batch"].ToString().ToUpper() != "N")
                {
                    RowError += "Track Batch : Value should be Y or N\n";
                }
            }
            //PKD
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Track PKD"].ToString()))
            {
                RowError += "Track PKD : Track PKD should not be empty\n\n";
            }
            else
            {
                if (dtCheck.Rows[0]["Track PKD"].ToString().ToUpper() != "Y" && dtCheck.Rows[0]["Track PKD"].ToString().ToUpper() != "N")
                {
                    RowError += "Track PKD : Value should be Y or N\n";
                }
            }
            //SERI
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Track Serial"].ToString()))
            {
                RowError += "Track Serial : Track Serial should not be empty\n\n";
            }
            else
            {
                if (dtCheck.Rows[0]["Track Serial"].ToString().ToUpper() != "Y" && dtCheck.Rows[0]["Track Serial"].ToString().ToUpper() != "N")
                {
                    RowError += "Track Serial : Value should be Y or N\n";
                }
            }
            //DF
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Date Format"].ToString()))
            {
                RowError += "Date Format : Date Format should not be empty\n\n";
            }
            else
            {
                if (dtCheck.Rows[0]["Date Format"].ToString().ToUpper() != "DMY" && dtCheck.Rows[0]["Date Format"].ToString().ToUpper() != "YM")
                {
                    RowError += "Date Format : Value should be DMY or YM\n";
                }
            }
            bool barcodechk = false;
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Barcode Print"].ToString()))
            {
                if (dtCheck.Rows[0]["Barcode Print"].ToString().ToUpper() != "Y" && dtCheck.Rows[0]["Barcode Print"].ToString().ToUpper() != "N")
                {
                    RowError += "Barcode Print : Value should be Y or N\n";
                }
                else
                {
                    barcodechk = dtCheck.Rows[0]["Barcode Print"].ToString().ToUpper() == "Y";
                }
            }
            if (barcodechk)
            {
                if (string.IsNullOrEmpty(dtCheck.Rows[0]["Barcode Uom"].ToString()))
                {
                    RowError += "Barcode Uom : Barcode Uom should not be empty\n\n";
                }
                else
                {
                    if (!objBL.BL_AlphaNumeric(dtCheck.Rows[0]["Barcode Uom"].ToString()))
                    {
                        RowError += "Barcode Uom : Invalid character\n";
                    }
                }
            }
            if (barcodechk)
            {
                if (string.IsNullOrEmpty(dtCheck.Rows[0]["Barcode Price"].ToString()))
                {
                    RowError += "Barcode Price : Barcode Price should not be empty\n\n";
                }
                else
                {
                    if (!objBL.BL_AlphaNumeric(dtCheck.Rows[0]["Barcode Price"].ToString()))
                    {
                        RowError += "Barcode Price : Invalid character\n";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Vendor Name"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Vendor Name"].ToString()))
                {
                    RowError += "Vendor Name : Invalid character\n";
                }
            }

            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["MOH"].ToString()))
            {
                if (!objBL.BL_Numeric(dtCheck.Rows[0]["MOH"].ToString()))
                {
                    RowError += "MOH : Invalid character(Numbers Only)\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["MOQ"].ToString()))
            {
                if (!objBL.BL_Numeric(dtCheck.Rows[0]["MOQ"].ToString()))
                {
                    RowError += "MOQ : Invalid character(Numbers Only)\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Remarks"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Remarks"].ToString()))
                {
                    RowError += "Remarks : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Location Name"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Location Name"].ToString()))
                {
                    RowError += "Location Name : Invalid character\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Life Time"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Life Time"].ToString()))
                {
                    RowError += "Life Time : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Active"].ToString()))
            {
                RowError += "Active : Active should not be empty\n\n";
            }
            else
            {
                if (dtCheck.Rows[0]["Active"].ToString().ToUpper() != "Y" && dtCheck.Rows[0]["Active"].ToString().ToUpper() != "N")
                {
                    RowError += "Active : Value should be Y or N\n";
                }
            }
            //D
            //"Code *","Name *","EAN *","Mfr Name *","Brand Name *","Category Name *","HSN Code","Discount %","Base Uom *","Base CR *","Purchase Uom *",
            //"Purchase CR *","Sales Uom *","Sales CR *","Reporting Uom *","Reporting CR *","Reporting Qty *","Purchase Tax *","Sales Tax *","Purchase Price *",
            //"Sale on MRP","Sales Margin %","Sales Price *","ECP on MRP","ECP Margin %","ECP *","SPL on MRP","SPL Margin %","SPL Price *","MRP *","Return Price",
            //"Track Inventory","Track Batch","Track Serial","Track PKD","Date Format","Barcode Print","Barcode Uom","Barcode Price","Vendor Name",
            //"MOH","MOQ","Remarks","Location Name","Weborder","Active"
            return RowError;
        }
        public string OrderTakenImpValiation(DataTable dtCheck)
        {
            string RowError = "";
            BranchID = 0; BeatID = 0; SalesmanID = 0; CustomerID = 0; ProductID = 0;
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Order ID"].ToString()))
            {
                RowError += "Order ID : Order ID should not be empty\n";
            }
            else
            {
                if (!objBL.BL_AlphaNumeric(dtCheck.Rows[0]["Order ID"].ToString()))
                {
                    RowError += "Order ID : Invalid character(Alpha Numeric Only)\n";
                }
            }

            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Doc Date"].ToString()))
            {
                if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["Doc Date"].ToString()))
                {
                    RowError += "Doc Date : Invalid Format(DD/MM/YYYY) Only\n";
                }
            }
            else
            {
                RowError += "Doc Date : Doc Date should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Branch Name"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Branch Name"].ToString()))
                {
                    RowError += "Branch Name : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 7, 3, dtCheck.Rows[0]["Branch Name"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* Branch Name not found in Database\n";
                    }
                    else
                    {
                        BranchID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "Customer Name : Customer Name should not be empty\n";
            }

            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Beat Name"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Beat Name"].ToString()))
                {
                    RowError += "Beat Name : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 9, 3, dtCheck.Rows[0]["Beat Name"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* Beat Name not found in Database\n";
                    }
                    else
                    {
                        BeatID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Salesman Name"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Salesman Name"].ToString()))
                {
                    RowError += "Salesman Name : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 10, 3, dtCheck.Rows[0]["Salesman Name"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* Salesman Name not found in Database\n";
                    }
                    else
                    {
                        SalesmanID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Customer Name"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Customer Name"].ToString()))
                {
                    RowError += "Customer Name : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 8, 3, dtCheck.Rows[0]["Customer Name"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* Customer Name not found in Database\n";
                    }
                    else
                    {
                        CustomerID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "Customer Name : Customer Name should not be empty\n";
            }

            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Additional Discount %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Additional Discount %"].ToString()))
                {
                    RowError += "Additional Discount % : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Additional Discount %"].ToString()) > 100)
                    {
                        RowError += "Additional Discount % : Discount % should be less than 100 only\n";
                    }
                    //if (objBL.BL_dValidation(dtCheck.Rows[0]["Trade Discount %"].ToString()) < 0)
                    //{
                    //    RowError += "Trade Discount % : Discount % should be greater than or equal to 0 only\n";
                    //}
                }
            }
            //T DETERGENT CAKE
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Trade Discount %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Trade Discount %"].ToString()))
                {
                    RowError += "Trade Discount % : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Trade Discount %"].ToString()) > 100)
                    {
                        RowError += "Trade Discount % : Discount % should be less than 100 only\n";
                    }
                    //if (objBL.BL_dValidation(dtCheck.Rows[0]["Trade Discount %"].ToString()) < 0)
                    //{
                    //    RowError += "Trade Discount % : Discount % should be greater than or equal to 0 only\n";
                    //}
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Remarks"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Remarks"].ToString()))
                {
                    RowError += "Remarks : Invalid Characters\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Product Name"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Product Name"].ToString()))
                {
                    RowError += "Product Name : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 5, 3, dtCheck.Rows[0]["Product Name"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* Product Name not found in Database\n";
                    }
                    else
                    {
                        ProductID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "Product Name : Product Name should not be empty\n";
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Price"].ToString()))
            {
                RowError += "Price : Price Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Price"].ToString()))
                {
                    RowError += "Price : Invalid character\n";
                }
            }

            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Quantity"].ToString()))
            {
                RowError += "Quantity : Quantity should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Quantity"].ToString()))
                {
                    RowError += "Quantity : Invalid character\n";
                }
                if (objBL.BL_dValidation(dtCheck.Rows[0]["Quantity"].ToString()) <= 0)
                {
                    RowError += "Quantity : Quantity should be greater than 0 only\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Discount %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Discount %"].ToString()))
                {
                    RowError += "Discount % : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Discount %"].ToString()) > 100)
                    {
                        RowError += "Discount % : Discount % should be less than 100 only\n";
                    }
                    //if (objBL.BL_dValidation(dtCheck.Rows[0]["Trade Discount %"].ToString()) < 0)
                    //{
                    //    RowError += "Trade Discount % : Discount % should be greater than or equal to 0 only\n";
                    //}
                }
            }
            return RowError;
        }
        public string PriceChangeImpValiation(DataTable dtCheck)
        {
            string RowError = "";
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["ID"].ToString()))
            {
                RowError += "ID : ID should not be empty\n";
            }
            else
            {
                if (!objBL.BL_Numeric(dtCheck.Rows[0]["ID"].ToString()))
                {
                    RowError += "ID : Invalid character(Numbers Only)\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Batch No"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Batch No"].ToString()))
                {
                    RowError += "Batch No : Invalid Format(Alpha Numeric Only)\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["PKD"].ToString()))
            {
                if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["PKD"].ToString()))
                {
                    RowError += "PKD : Invalid Format (DD/MM/YYYY) Only\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Expiry"].ToString()))
            {
                if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["Expiry"].ToString()))
                {
                    RowError += "Expiry : Invalid Format (DD/MM/YYYY) Only\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Sales Price"].ToString()))
            {
                RowError += "Sales Price : Sales Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Sales Price"].ToString()))
                {
                    RowError += "Sales Price : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["ECP"].ToString()))
            {
                RowError += "ECP : ECP Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["ECP"].ToString()))
                {
                    RowError += "ECP : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["SPL Price"].ToString()))
            {
                RowError += "SPL Price : SPL Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["SPL Price"].ToString()))
                {
                    RowError += "SPL Price : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["MRP Incl"].ToString()))
            {
                RowError += "MRP Incl : MRP Incl should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["MRP Incl"].ToString()))
                {
                    RowError += "MRP Incl : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Return Price"].ToString()))
            {
                RowError += "Return Price : Return Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Return Price"].ToString()))
                {
                    RowError += "Return Price : Invalid character\n";
                }
            }
            return RowError;
        }

        public string TransactionPriceImpValiation(DataTable dtCheck)
        {
            string RowError = "";
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Product Code"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Product Code"].ToString()))
                {
                    RowError += "Code : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 12, 3, dtCheck.Rows[0]["Product Code"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        //RowError += "* Code not found in Database\n";
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
                RowError += "Code : Code should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Product Name"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Product Name"].ToString()))
                {
                    RowError += "Product Name : Invalid Characters\n";
                }
                else
                {
                    if (ProductID == 0)
                    {
                        DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 5, 3, dtCheck.Rows[0]["Product Name"].ToString());
                        if (dt.Rows.Count == 0)
                        {
                            RowError += "* Product Name not found in Database\n";
                        }
                        else
                        {
                            ProductID = Convert.ToInt32(dt.Rows[0][0].ToString());
                        }
                    }
                }
            }

            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Purchase Bill Price"].ToString()))
            {
                RowError += "Purchase Bill Price : Purchase Bill Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Purchase Bill Price"].ToString()))
                {
                    RowError += "Purchase Bill Price : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Purchase Return Price"].ToString()))
            {
                RowError += "Purchase Return Price : Purchase Return Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Purchase Return Price"].ToString()))
                {
                    RowError += "Purchase Return Price : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Invoice Price"].ToString()))
            {
                RowError += "Invoice Price : Invoice Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Invoice Price"].ToString()))
                {
                    RowError += "Invoice Price : Invalid character\n";
                }
            }
            if (string.IsNullOrEmpty(dtCheck.Rows[0]["Sales Return Price"].ToString()))
            {
                RowError += "Sales Return Price : Sales Return Price should not be empty\n";
            }
            else
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Sales Return Price"].ToString()))
                {
                    RowError += "Sales Return Price : Invalid character\n";
                }
            }
            return RowError;
        }

        public string BeatSalesmanImpValiation(DataTable dtCheck)
        {
            string RowError = "";
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Code"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Code"].ToString()))
                {
                    RowError += "Code : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 11, 3, dtCheck.Rows[0]["Code"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        //RowError += "* Code not found in Database\n";
                        CustomerID = 0;
                    }
                    else
                    {
                        CustomerID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "Code : Code should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Name"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Name"].ToString()))
                {
                    RowError += "Name : Invalid Characters\n";
                }
                else
                {
                    if (CustomerID == 0)
                    {
                        DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 8, 3, dtCheck.Rows[0]["Name"].ToString());
                        if (dt.Rows.Count == 0)
                        {
                            RowError += "* Code and Name not found in Database\n";
                            CustomerID = 0;
                        }
                        else
                        {
                            CustomerID = Convert.ToInt32(dt.Rows[0][0].ToString());
                        }
                    }
                }
            }
            else
            {
                RowError += "Name : Name should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Beat Name"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Beat Name"].ToString()))
                {
                    RowError += "Beat Name : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 9, 3, dtCheck.Rows[0]["Beat Name"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* Beat Name not found in Database\n";
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
                RowError += "Beat Name : Beat Name should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Salesman Name"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Salesman Name"].ToString()))
                {
                    RowError += "Salesman Name : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 10, 3, dtCheck.Rows[0]["Salesman Name"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* Salesman Name not found in Database\n";
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
                RowError += "Salesman Name : Salesman Name should not be empty\n";
            }
            return RowError;
        }

        public string CusstomerRemarksImpValiation(DataTable dtCheck)
        {
            string RowError = "";
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Code"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Code"].ToString()))
                {
                    RowError += "Code : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 11, 3, dtCheck.Rows[0]["Code"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        //RowError += "* Code not found in Database\n";
                        CustomerID = 0;
                    }
                    else
                    {
                        CustomerID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "Code : Code should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Name"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Name"].ToString()))
                {
                    RowError += "Name : Invalid Characters\n";
                }
                else
                {
                    if (CustomerID == 0)
                    {
                        DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 8, 3, dtCheck.Rows[0]["Name"].ToString());
                        if (dt.Rows.Count == 0)
                        {
                            RowError += "*Code and Name not found in Database\n";
                            CustomerID = 0;
                        }
                        else
                        {
                            CustomerID = Convert.ToInt32(dt.Rows[0][0].ToString());
                        }
                    }
                }
            }
            else
            {
                RowError += "Name : Name should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Remarks"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Remarks"].ToString()))
                {
                    RowError += "Remarks : Invalid Characters\n";
                }
            }
            else
            {
                RowError += "Remarks : Remarks should not be empty\n";
            }
            return RowError;
        }
        public string POImpValiation(DataRow dr)
        {
            bool IsValid = true;
            string RowError = "";
            if (string.IsNullOrEmpty(dr.ItemArray[0].ToString()))
            {
                IsValid = false;
                RowError += "* Doc ID should not be empty\n";
            }
            if (string.IsNullOrEmpty(dr.ItemArray[1].ToString()))
            {
                IsValid = false;
                RowError += "* Doc Date should not be empty\n";
            }
            if (string.IsNullOrEmpty(dr.ItemArray[2].ToString()))
            {
                IsValid = false;
                RowError += "* Branch Name Should not be Empty\n";
            }
            else
            {
                DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 7, 3, dr.ItemArray[2].ToString());
                if (dt.Rows.Count == 0)
                {
                    IsValid = false;
                    RowError += "* Enter valid Branch Name\n";
                }
                else
                {
                    BranchID = Convert.ToInt32(dt.Rows[0][0].ToString());
                }
            }
            if (string.IsNullOrEmpty(dr.ItemArray[3].ToString()))
            {
                IsValid = false;
                RowError += "* Vendor Name Should not be Empty\n";
            }
            else
            {
                DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 4, 3, dr.ItemArray[3].ToString());
                if (dt.Rows.Count == 0)
                {
                    IsValid = false;
                    RowError += "* Enter valid Vendor Name\n";
                }
                else
                {
                    VendorID = Convert.ToInt32(dt.Rows[0][0].ToString());
                }
            }
            if (string.IsNullOrEmpty(dr.ItemArray[4].ToString()))
            {
                IsValid = false;
                RowError += "* Product Name Should not be Empty\n";
            }
            else
            {
                DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 5, 3, dr.ItemArray[4].ToString());
                if (dt.Rows.Count == 0)
                {
                    IsValid = false;
                    RowError += "* Enter valid Product Name\n";
                }
                else
                {
                    ProductID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    UOMID = Convert.ToInt32(dt.Rows[0][9].ToString());//base uom
                }
            }
            if (string.IsNullOrEmpty(dr.ItemArray[5].ToString()))
            {
                IsValid = false;
                RowError += "* Price should not be empty\n";
            }
            else
            {
                if (!objBL.NumberValidate(dr.ItemArray[5].ToString()))
                {
                    IsValid = false;
                    RowError += "* Invalid Format. Numeric only allowed\n";
                }
            }
            if (string.IsNullOrEmpty(dr.ItemArray[6].ToString()))
            {
                IsValid = false;
                RowError += "* Qty should not be empty\n";
            }
            else
            {
                if (!objBL.NumberValidate(dr.ItemArray[6].ToString()))
                {
                    IsValid = false;
                    RowError += "* Invalid Format. Numeric only allowed\n";
                }
            }
            if (string.IsNullOrEmpty(dr.ItemArray[7].ToString()))
            {
                IsValid = false;
                RowError += "* Tax Should not be Empty\n";
            }
            else
            {
                DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 6, 3, dr.ItemArray[7].ToString());
                if (dt.Rows.Count == 0)
                {
                    IsValid = false;
                    RowError += "* Enter valid Tax\n";
                }
                else
                {
                    TaxID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    TaxPern = Convert.ToDecimal(dt.Rows[0][2].ToString());//base uom
                }
            }
            return RowError;
        }

        public string QuotatinHeaderValiation(DataTable dtCheck)
        {
            string RowError = "";
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Branch Name *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Branch Name *"].ToString()))
                {
                    RowError += "Branch Name * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 7, 3, dtCheck.Rows[0]["Branch Name *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        //RowError += "* Code not found in Database\n";
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
                RowError += "Branch Name * : Branch Name should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Party Name *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Party Name *"].ToString()))
                {
                    RowError += "Party Name * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 8, 3, dtCheck.Rows[0]["Party Name *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
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
                RowError += "Party Name * : Party Name should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Ref No *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Ref No *"].ToString()))
                {
                    RowError += "Ref No * : Invalid Characters\n";
                }
            }
            else
            {
                RowError += "Ref No * : Ref No should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Date *"].ToString()))
            {
                if (!objBL.BL_DateformatDMY(dtCheck.Rows[0]["Date *"].ToString()))
                {
                    RowError += "Date * : Invalid Date Format(Format : dd/MM/yyyy)\n";
                }
            }
            else
            {
                RowError += "Date * : Date should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Additional Discount %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Additional Discount %"].ToString()))
                {
                    RowError += "Additional Discount % : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Additional Discount %"].ToString()) > 100)
                    {
                        RowError += "Additional Discount % : Discount % should be less than 100 only\n";
                    }
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Additional Discount %"].ToString()) < 0)
                    {
                        RowError += "Additional Discount % : Discount % should be greater than or equal to 0 only\n";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Additional Discount Amount"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Additional Discount Amount"].ToString()))
                {
                    RowError += "Additional Discount Amount : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Additional Discount Amount"].ToString()) < 0)
                    {
                        RowError += "Additional Discount Amount : Discount Amount should be greater than or equal to 0 only\n";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Trade Discount %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Trade Discount %"].ToString()))
                {
                    RowError += "Trade Discount % : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Trade Discount %"].ToString()) > 100)
                    {
                        RowError += "Trade Discount % : Discount % should be less than 100 only\n";
                    }
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Trade Discount %"].ToString()) < 0)
                    {
                        RowError += "Trade Discount % : Discount % should be greater than or equal to 0 only\n";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Trade Discount Amount"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Trade Discount Amount"].ToString()))
                {
                    RowError += "Trade Discount Amount : Invalid character(Numeric Only)\n";
                }
                else
                {                    
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Trade Discount Amount"].ToString()) < 0)
                    {
                        RowError += "Trade Discount Amount : Discount Amount should be greater than or equal to 0 only\n";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Freight"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Freight"].ToString()))
                {
                    RowError += "Freight : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Freight"].ToString()) < 0)
                    {
                        RowError += "Freight : Freight should be greater than or equal to 0 only\n";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Other Charge Amount"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Other Charge Amount"].ToString()))
                {
                    RowError += "Other Charge Amount : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Other Charge Amount"].ToString()) < 0)
                    {
                        RowError += "Other Charge Amount : Other Charge Amount should be greater than or equal to 0 only\n";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Remarks"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Remarks"].ToString()))
                {
                    RowError += "Remarks : Invalid Characters\n";
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Narration"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Narration"].ToString()))
                {
                    RowError += "Narration : Invalid Characters\n";
                }
            }
            return RowError;
        }
        public string QuotatinItemsValiation(DataTable dtCheck)
        {
            string RowError = "";
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Ref No *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Ref No *"].ToString()))
                {
                    RowError += "Ref No * : Invalid Characters\n";
                }
            }
            else
            {
                RowError += "Ref No * : Ref No should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Product Code *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Product Code *"].ToString()))
                {
                    RowError += "Product Code * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 12, 3, dtCheck.Rows[0]["Product Code *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        //RowError += "* Code not found in Database\n";
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
                RowError += "Product Code * : Product Code should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Product Name *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Product Name *"].ToString()))
                {
                    RowError += "Product Name * : Invalid Characters\n";
                }
                else
                {
                    if (ProductID == 0)
                    {
                        DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 5, 3, dtCheck.Rows[0]["Product Name *"].ToString());
                        if (dt.Rows.Count == 0)
                        {
                            RowError += "* Product Code and Product Name not found in Database\n";
                            ProductID = 0;
                        }
                        else
                        {
                            ProductID = Convert.ToInt32(dt.Rows[0][0].ToString());
                        }
                    }
                }
            }
            else
            {
                RowError += "Product Name * : Product Name should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["MRP *"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["MRP *"].ToString()))
                {
                    RowError += "MRP * : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["MRP *"].ToString()) < 0)
                    {
                        RowError += "MRP *: MRP should be greater than or equal to 0 only\n";
                    }
                }
            }
            else
            {
                RowError += "MRP * : MRP should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["UOM Price *"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["UOM Price *"].ToString()))
                {
                    RowError += "UOM Price * : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["UOM Price *"].ToString()) < 0)
                    {
                        RowError += "UOM Price *: UOM Price should be greater than or equal to 0 only\n";
                    }
                }
            }
            else
            {
                RowError += "UOM Price * : UOM Price should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["UOM Qty *"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["UOM Qty *"].ToString()))
                {
                    RowError += "UOM Qty * : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["UOM Qty *"].ToString()) < 0)
                    {
                        RowError += "UOM Qty *: UOM Qty should be greater than or equal to 0 only\n";
                    }
                }
            }
            else
            {
                RowError += "UOM Qty * : UOM Qty should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["UOM Name *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["UOM Name *"].ToString()))
                {
                    RowError += "UOM Name * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 13, 3, dtCheck.Rows[0]["UOM Name *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* UOM Name not found in Database\n";
                        UOMID = 0;
                    }
                    else
                    {
                        UOMID = Convert.ToInt32(dt.Rows[0][0].ToString());
                    }
                }
            }
            else
            {
                RowError += "UOM Name * : UOM Name should not be empty\n";
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Product Discount %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Product Discount %"].ToString()))
                {
                    RowError += "Product Discount % : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Product Discount %"].ToString()) > 100)
                    {
                        RowError += "Product Discount % : Discount % should be less than 100 only\n";
                    }
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Product Discount %"].ToString()) < 0)
                    {
                        RowError += "Product Discount % : Discount % should be greater than or equal to 0 only\n";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Product Discount Amount"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Product Discount Amount"].ToString()))
                {
                    RowError += "Product Discount Amount : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Product Discount Amount"].ToString()) < 0)
                    {
                        RowError += "Product Discount Amount : Discount Amount should be greater than or equal to 0 only\n";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Additional Discount %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Additional Discount %"].ToString()))
                {
                    RowError += "Additional Discount % : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Additional Discount %"].ToString()) > 100)
                    {
                        RowError += "Additional Discount % : Discount % should be less than 100 only\n";
                    }
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Additional Discount %"].ToString()) < 0)
                    {
                        RowError += "Additional Discount % : Discount % should be greater than or equal to 0 only\n";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Additional Discount Amount"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Additional Discount Amount"].ToString()))
                {
                    RowError += "Additional Discount Amount : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Additional Discount Amount"].ToString()) < 0)
                    {
                        RowError += "Additional Discount Amount : Discount Amount should be greater than or equal to 0 only\n";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Trade Discount %"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Trade Discount %"].ToString()))
                {
                    RowError += "Trade Discount % : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Trade Discount %"].ToString()) > 100)
                    {
                        RowError += "Trade Discount % : Discount % should be less than 100 only\n";
                    }
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Trade Discount %"].ToString()) < 0)
                    {
                        RowError += "Trade Discount % : Discount % should be greater than or equal to 0 only\n";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Trade Discount Amount"].ToString()))
            {
                if (!objBL.BL_NumericWithDecimal(dtCheck.Rows[0]["Trade Discount Amount"].ToString()))
                {
                    RowError += "Trade Discount Amount : Invalid character(Numeric Only)\n";
                }
                else
                {
                    if (objBL.BL_dValidation(dtCheck.Rows[0]["Trade Discount Amount"].ToString()) < 0)
                    {
                        RowError += "Trade Discount Amount : Discount Amount should be greater than or equal to 0 only\n";
                    }
                }
            }
            if (!string.IsNullOrEmpty(dtCheck.Rows[0]["Tax Name *"].ToString()))
            {
                if (!objBL.BL_AlphaNumericSpl(dtCheck.Rows[0]["Tax Name *"].ToString()))
                {
                    RowError += "Tax Name * : Invalid Characters\n";
                }
                else
                {
                    DataTable dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 6, 3, dtCheck.Rows[0]["Tax Name *"].ToString());
                    if (dt.Rows.Count == 0)
                    {
                        RowError += "* Tax Name not found in Database\n";
                        TaxID = 0;
                    }
                    else
                    {
                        TaxID = Convert.ToInt32(dt.Rows[0][0].ToString());
                        TaxPern = Convert.ToDecimal(dt.Rows[0][2].ToString());//base uom
                    }
                }
            }
            else
            {
                RowError += "Tax Name * : Tax Name should not be empty\n";
            }
            return RowError;
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
                strSheetName = "Data";
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
        public void TransactionColumnValidation(List<string> lst,string sSheetName, ref bool blResult)
        {
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
                        GetTransactionDataRecords(docSelected, rows, sSheetName);
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
        public void GetTransactionDataRecords(SpreadsheetDocument docSelected, IEnumerable<Row> rows,string HeaderorItems)
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
            if(HeaderorItems == "Header")//Header data
            {
                dtHeaderData = dCheck;
            }
            else//Items data
            {
                dtItemsData = dCheck;
            }
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
        [System.Web.Http.HttpGet]
        [System.Web.Http.Route("api/generatetemplate")]
        public HttpResponseMessage GenerateTemplate(int TransID, string TransName)
        {
            DataTable dt = new DataTable();
            List<string> strTemp = null;
            if (TransID == 1)
            {
                strTemp = CustomerMasterTemp();
            }
            else if (TransID == 2) // product
            {
                strTemp = ProductMasterTemp();
            }
            else if (TransID == 3) // purchase order
            {
                strTemp = POImpDataTemp();
            }
            else if (TransID == 5) // order taken
            {
                strTemp = OrderTakenTemp();
            }
            else if (TransID == 6) // trans price
            {
                strTemp = TransactonPricesTemp();
            }
            else if (TransID == 7) // beat saleman map
            {
                strTemp = BeatSalesmanMappingTemp();
            }
            else if (TransID == 8) // customer remark
            {
                strTemp = CustomerRemarksTemp();
            }
            else if (TransID == 10) // Product Open import
            {
                strTemp = ProductOpenImportTemp();
            }
            OpenTemplate(strTemp, 1, TransID, TransName);
            var sDocument = strFilePath + strFileName + strExtension;
            byte[] fileBytes = System.IO.File.ReadAllBytes(sDocument);
            string fileName = strFileName + strExtension;
            //return File(fileBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
            if (!File.Exists(strFilePath + strFileName + strExtension))
                return new HttpResponseMessage(HttpStatusCode.NotFound);

            var result = new HttpResponseMessage(HttpStatusCode.OK);
            var stream = new FileStream(strFilePath + strFileName + strExtension, FileMode.Open, FileAccess.Read);
            result.Content = new StreamContent(stream);
            result.Content.Headers.ContentType = new MediaTypeHeaderValue("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
            result.Content.Headers.ContentDisposition = new ContentDispositionHeaderValue("attachment")
            {
                FileName = fileName
            };
            return result;
        }
        [System.Web.Http.HttpGet]
        [System.Web.Http.Route("api/exporttemplate")]
        public HttpResponseMessage ExportData(int TransID, string TransName, string FromDate = null, string ToDate = null)
        {
            List<string> strTemp = null;
            if (TransID == 1)
            {
                strTemp = CustomerMasterTemp();
            }
            else if (TransID == 2) // product
            {
                strTemp = ProductMasterTemp();
            }
            else if (TransID == 3) // purchase order
            {
                strTemp = POImpDataTemp();
            }
            else if (TransID == 5) // order taken
            {
                strTemp = OrderTakenTemp();
            }
            else if (TransID == 6) // trans price
            {
                strTemp = TransactonPricesTemp();
            }
            else if (TransID == 7) // beat saleman map
            {
                strTemp = BeatSalesmanMappingTemp();
            }
            else if (TransID == 8) // customer remark
            {
                strTemp = CustomerRemarksTemp();
            }
            else if (TransID == 10) // Product Open import
            {
                strTemp = ProductOpenImportTemp();
            }
            DataTable dt = new DataTable();
            OpenTemplate(strTemp, 2, TransID, TransName, FromDate, ToDate);
            var sDocument = strFilePath + strFileName + strExtension;
            byte[] fileBytes = System.IO.File.ReadAllBytes(sDocument);
            string fileName = strFileName + strExtension;
            //return File(fileBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
            if (!File.Exists(strFilePath + strFileName + strExtension))
                return new HttpResponseMessage(HttpStatusCode.NotFound);

            var result = new HttpResponseMessage(HttpStatusCode.OK);
            var stream = new FileStream(strFilePath + strFileName + strExtension, FileMode.Open, FileAccess.Read);
            result.Content = new StreamContent(stream);
            result.Content.Headers.ContentType = new MediaTypeHeaderValue("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
            result.Content.Headers.ContentDisposition = new ContentDispositionHeaderValue("attachment")
            {
                FileName = fileName
            };
            return result;
            //return File(fileBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
        }
        [System.Web.Http.HttpGet]
        [System.Web.Http.Route("api/downloaderrordata")]
        public HttpResponseMessage DownloadErrorData(string FPath, string FName)
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
            result.Content.Headers.ContentType = new MediaTypeHeaderValue("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
            result.Content.Headers.ContentDisposition = new ContentDispositionHeaderValue("attachment")
            {
                FileName = fileName
            };
            return result;
            //return File(fileBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
        }
        public void OpenTemplate(List<string> str, int Type, int TransID, string TransName, string FromDate = null, string ToDate = null)
        {
            DataTable dt = new DataTable();
            DataTable dtDefaultData = new DataTable();
            DataTable dtExampleData = new DataTable();
            string FPt = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"];
            //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "\\Export Data\\";
            strFilePath = FPt + "\\Export Data\\";
            strFileName = TransName + (Type == 1 ? "_Import_" : "_Export_") + DateTime.Now.ToString("yyyyMMddHHmmss");
            if (Type == 1)
            {
                if (TransID == 9) {
                    dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 1, TransID, null, DateTime.Now.AddYears(-21), DateTime.Now.AddYears(-20));
                    dtDefaultData = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 2, TransID, DateTime.Now.AddYears(-21), DateTime.Now.AddYears(-20));
                }
                else
                {
                    foreach (string strHeaderName in str)
                    {
                        dt.Columns.Add(strHeaderName, typeof(string));
                    }
                    dtDefaultData = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 2, TransID, null, FromDate, ToDate);
                    dtExampleData = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 3, TransID, null, FromDate, ToDate);
                }
            }
            else if (Type == 2)
            {
                dt = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 1, TransID, null, FromDate, ToDate);
                dtDefaultData = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 2, TransID, null, FromDate, ToDate);
                dtExampleData = objBL.BL_ExecuteParamSP("uspgetsetImportExport", 3, TransID, null, FromDate, ToDate);
            }
            strSheetName = "Data";
            if (TransID == 9)
            {
                ExportToExcelTwoSheet(dt, "Header", dtDefaultData, "Items");
            }
            else
            {
                ExportToExcelThreeSheet(dt, "Data", dtDefaultData, "Default Data", dtExampleData, "Example");
            }
        }
        public void ExportToExcel(DataTable DtData)
        {
            try
            {
                //Exporting to Excel
                if (!Directory.Exists(strFilePath))
                {
                    Directory.CreateDirectory(strFilePath);
                }
                using (XLWorkbook wb = new XLWorkbook())
                {
                    Int32 len = strSheetName.Length;
                    wb.Worksheets.Add(DtData, strSheetName.Substring(0, len).Trim());
                    wb.SaveAs(strFilePath + strFileName + strExtension);
                }
            }
            catch (IOException ex)
            {
                objBL.BL_WriteErrorMsginLog("Import/Emport", "ExportToExcel", ex.Message);
            }
            catch (Exception ex)
            {
                objBL.BL_WriteErrorMsginLog("Import/Emport", "ExportToExcel", ex.Message);
                throw;
            }
        }
        public void ExportToExcelTwoSheet(DataTable DtDataSheet1, string Sheet1Name, DataTable DtDataSheet2, string Sheet2Name)
        {
            try
            {
                //Exporting to Excel
                if (!Directory.Exists(strFilePath))
                {
                    Directory.CreateDirectory(strFilePath);
                }
                using (XLWorkbook wb = new XLWorkbook())
                {
                    Int32 len = Sheet1Name.Length;
                    wb.Worksheets.Add(DtDataSheet1, Sheet1Name.Substring(0, len).Trim());
                    len = Sheet2Name.Length;
                    wb.Worksheets.Add(DtDataSheet2, Sheet2Name.Substring(0, len).Trim());
                    wb.SaveAs(strFilePath + strFileName + strExtension);
                }
            }
            catch (IOException ex)
            {
                objBL.BL_WriteErrorMsginLog("Import Export", "ExportToExcelTwoSheet", ex.Message);
            }
            catch (Exception ex)
            {
                objBL.BL_WriteErrorMsginLog("Import Export", "ExportToExcelTwoSheet 1", ex.Message);
                throw;
            }
        }
        public void ExportToExcelThreeSheet(DataTable DtDataSheet1, string Sheet1Name, DataTable DtDataSheet2, string Sheet2Name, DataTable DtDataSheet3, string Sheet3Name)
        {
            try
            {
                //Exporting to Excel
                if (!Directory.Exists(strFilePath))
                {
                    Directory.CreateDirectory(strFilePath);
                }
                using (XLWorkbook wb = new XLWorkbook())
                {
                    Int32 len = Sheet1Name.Length;
                    wb.Worksheets.Add(DtDataSheet1, Sheet1Name.Trim());//.Substring(0, len)
                    len = Sheet2Name.Length;
                    wb.Worksheets.Add(DtDataSheet2, Sheet2Name.Trim());//.Substring(0, len)
                    len = Sheet3Name.Length;
                    wb.Worksheets.Add(DtDataSheet3, Sheet3Name.Trim());//.Substring(0, len)
                    wb.SaveAs(strFilePath + strFileName + strExtension);
                }
            }
            catch (IOException ex)
            {
                objBL.BL_WriteErrorMsginLog("Import Export", "ExportToExcelThreeSheet", ex.Message);
            }
            catch (Exception ex)
            {
                objBL.BL_WriteErrorMsginLog("Import Export", "ExportToExcelThreeSheet 1", ex.Message);
                throw;
            }
        }
        public static List<string> QuotationHeaderTemp()
        {
            return new List<string>()
            {
                "Branch Name *","Ref No *","Date *","Party Name *","Trade Discount %","Trade Discount Amount","Additional Discount %",
                "Additional Discount Amount","Freight","Other Charge Amount","Remarks","Narration","Net Amount *"
            };
        }
        public static List<string> QuotationHeaderTempWithErrCol()
        {
            return new List<string>()
            {
                "Branch Name *","Ref No *","Date *","Party Name *","Trade Discount %","Trade Discount Amount","Additional Discount %",
                "Additional Discount Amount","Freight","Other Charge Amount","Remarks","Narration","Net Amount *","Error"
            };
        }
        public static List<string> QuotationItemsTemp()
        {
            return new List<string>()
            {
                "Ref No *","Product Code *","Product Name *","MRP *","UOM Price *","Uom Qty *","UOM Name *","Product Discount %","Product Discount Amount",
                "Trade Discount %","Trade Discount Amount","Additional Discount %","Additional Discount Amount","Tax Name *","Reason"
            };
        }
        public static List<string> QuotationItemsTempWithErrCol()
        {
            return new List<string>()
            {
                "Ref No *","Product Code *","Product Name *","MRP *","UOM Price *","Uom Qty *","UOM Name *","Product Discount %","Product Discount Amount",
                "Trade Discount %","Trade Discount Amount","Additional Discount %","Additional Discount Amount","Tax Name *","Reason"
            };
        }
        public static List<string> POImpDataTemp()
        {
            return new List<string>()
            {
                "Doc ID","Doc Date","Branch Name","Vendor Name","Item Name","Price","Qty","Tax"
            };
        }
        public static List<string> POImpDataTempWithErrCol()
        {
            return new List<string>()
            {
                "Doc ID","Doc Date","Branch Name","Vendor Name","Item Name","Price","Qty","Tax","Error"
            };
        }
        public static List<string> CustomerMasterTemp()
        {
            return new List<string>()
            {
                "Code *","Name *","Customer Type","Price Type *","Owner Name","Contact Person","Email ID",
                "Phone No 1","Phone No 2","Mobile No 1","Mobile No 2","Billing Address 1","Billing Address 2",
                "Billing Address 3","Shipping Address 1","Shipping Address 2","Shipping Address 3","Pincode *","Distance",
                "Credit Limit Value","Credit Limit Count","Over Due Value","Over Due Inv Count","PAN Number","Aadhar No",
                "FSSAI No","DL No 20","DL No 21","State Name","GSTIN","Tax Type *","Payment Mode","Credit Term","Discount %",
                "Remark","Rating","TCS Tax","Track Point","Active"
                };
        }
        public static List<string> CustomerMasterTempWithErrCol()
        {
            return new List<string>()
            {
                "Code *","Name *","Customer Type","Price Type *","Owner Name","Contact Person","Email ID",
                "Phone No 1","Phone No 2","Mobile No 1","Mobile No 2","Billing Address 1","Billing Address 2",
                "Billing Address 3","Shipping Address 1","Shipping Address 2","Shipping Address 3","Pincode *","Distance",
                "Credit Limit Value","Credit Limit Count","Over Due Value","Over Due Inv Count","PAN Number","Aadhar No",
                "FSSAI No","DL No 20","DL No 21","State Name","GSTIN","Tax Type *","Payment Mode","Credit Term","Discount %",
                "Remark","Rating","TCS Tax","Track Point","Active","Error"
                };
        }
        public static List<string> ProductMasterTemp()
        {
            return new List<string>()
            {
                "Code *","Name *","EAN *","Mfr Name *","Brand Name *","Category Name *","HSN Code","Discount %","Base Uom *","Base CR *","Purchase Uom *",
                "Purchase CR *","Sales Uom *","Sales CR *","Reporting Uom *","Reporting CR *","Purchase Tax *","Sales Tax *","Purchase Price *",
                "Sale on MRP","Sales Margin %","Sales Price *","ECP on MRP","ECP Margin %","ECP *","SPL on MRP","SPL Margin %","SPL Price *","MRP *","Return Price",
                "Track Inventory","Track Batch","Track Serial","Track PKD","Date Format","Barcode Print","Barcode Uom","Barcode Price","Vendor Name",
                "MOH","MOQ","Remarks","Location Name","Weborder","Life Time","Active"
            };
        }
        public static List<string> ProductMasterTempWithErrCol()
        {
            return new List<string>()
            {
                "Code *","Name *","EAN *","Mfr Name *","Brand Name *","Category Name *","HSN Code","Discount %","Base Uom *","Base CR *","Purchase Uom *",
                "Purchase CR *","Sales Uom *","Sales CR *","Reporting Uom *","Reporting CR *","Purchase Tax *","Sales Tax *","Purchase Price *",
                "Sale on MRP","Sales Margin %","Sales Price *","ECP on MRP","ECP Margin %","ECP *","SPL on MRP","SPL Margin %","SPL Price *","MRP *","Return Price",
                "Track Inventory","Track Batch","Track Serial","Track PKD","Date Format","Barcode Print","Barcode Uom","Barcode Price","Vendor Name",
                "MOH","MOQ","Remarks","Location Name","Weborder","Life Time","Active","Error"
            };
        }
        public static List<string> PrichangeTemp()
        {
            return new List<string>() {
              "ID", "Code", "Name", "Branch",   "Manufacturer", "Brand",    "Category", "Batch No", "PKD",  "Expiry",   "Sales Price",  "ECP",  "SPL Price",    "Return Price", "MRP Incl"
            };
        }
        public static List<string> PrichangeTempWithErrCol()
        {
            return new List<string>() {
              "ID","Code","Name","Branch","Manufacturer","Brand","Category","Batch No","PKD","Expiry","Sales Price","ECP","SPL Price",
                "Return Price", "MRP Incl","Error"
            };
        }
        public static List<string> OrderTakenTemp()
        {
            return new List<string>() {
                "Order ID", "Doc Date","Branch Name","Beat Name","Salesman Name","Customer Name","Additional Discount %","Trade Discount %","Remarks","Product Name", "Price","Quantity","Discount %"
            };
        }
        public static List<string> OrderTakenTempWithErrCol()
        {
            return new List<string>() {
                "Order ID", "Doc Date","Branch Name","Beat Name","Salesman Name","Customer Name","Additional Discount %","Trade Discount %","Remarks","Product Name",
                "Price","Quantity","Discount %","Error"
            };
        }
        public static List<string> TransactonPricesTemp()
        {
            return new List<string>() {
                 "Product Code","Product Name", "Purchase Bill Price","Purchase Return Price","Invoice Price","Sales Return Price"
            };
        }
        public static List<string> TransactonPricesTempWithErrCol()
        {
            return new List<string>() {
                 "Product Code","Product Name", "Purchase Bill Price","Purchase Return Price","Invoice Price","Sales Return Price","Error"
            };
        }
        public static List<string> BeatSalesmanMappingTemp()
        {
            return new List<string>() {
              "Code", "Name", "Beat Name","Salesman Name"
            };
        }
        public static List<string> BeatSalesmanMappingTempWithErrCol()
        {
            return new List<string>() {
              "Code", "Name", "Beat Name","Salesman Name","Error"
            };
        }
        public static List<string> CustomerRemarksTemp()
        {
            return new List<string>() {
              "Code", "Name", "Remarks"
            };
        }
        public static List<string> CustomerRemarksTempWithErrCol()
        {
            return new List<string>() {
              "Code", "Name", "Remarks","Error"
            };
        }
        public static List<string> ProductOpenImportTemp()
        {            
            return new List<string>() {
              "Branch Name *","Code *", "Name *",  "Batch No","PKD","Expiry","Qty *","Free Qty *","Damage Qty *","Purchase Price *","Sale Price *","ECP *","MRP *","Special Price *","Return Price *"
            };
        }
        public static List<string> ProductOpenImportTempWithErrCol()
        {
            return new List<string>() {
              "Branch Name *","Code *", "Name *", "Batch No","PKD","Expiry","Qty *","Free Qty *","Damage Qty *","Purchase Price *","Sale Price *","ECP *","MRP *","Special Price *","Return Price *","Error"
            };
        }
    }
}
