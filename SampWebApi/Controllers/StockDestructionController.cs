using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Linq.Expressions;
using System.Net;
using System.Net.Http;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Web.Http;
using System.Web.Http.Cors;


namespace SampWebApi.Controllers
{
    public class StockDestructionController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [Route("api/stockdestruction/get")]
        public IHttpActionResult GetConvertionData(string Mode, string CodeName, string ID = null, string BranchID = "0", string Date = "", string ConvType = "0")
        {
            try
            {
                DataTable DDT = new DataTable();
                if (Mode == "1")
                {
                    DDT = bl.BL_ExecuteParamSP("uspGetSetStockDestructionData", Mode, 0);
                    List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new CustomerVendorModel
                        {
                            FType = DDT.Rows[i][0].ToString(),
                            Form = DDT.Rows[i][1].ToString(),
                            ID = DDT.Rows[i][2].ToString(),
                            Code = DDT.Rows[i][3].ToString(),
                            Name = DDT.Rows[i][4].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "2")
                {
                    DDT = bl.BL_ExecuteParamSP("uspGetSetStockDestructionData", Mode, CodeName, null, null, BranchID, Convert.ToDateTime(Date));
                    List<ProductModel> list = new List<ProductModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new ProductModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Code = DDT.Rows[i]["Code"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                            EAN = DDT.Rows[i]["EAN"].ToString(),
                            HSNCode = DDT.Rows[i]["HSNCode"].ToString(),
                            PurchasePrice = DDT.Rows[i]["PurchasePrice"].ToString(),
                            ABSQty = DDT.Rows[i]["DMGQty"].ToString(),
                        });
                    }
                    return Ok(list);
                }


                if (Mode == "3")
                {
                    DDT = bl.BL_ExecuteParamSP("uspGetSetStockDestructionData", Mode, CodeName);
                    List<PRBatch> list = new List<PRBatch>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        DataTable dtUOM = bl.BL_ExecuteParamSP("uspGetSetStockDestructionData", 5, "", DDT.Rows[i][0].ToString());
                        List<clsPurchaseUOM> ulist = new List<clsPurchaseUOM>();
                        for (int j = 0; j < dtUOM.Rows.Count; j++)
                        {
                            ulist.Add(new clsPurchaseUOM
                            {
                                ID = dtUOM.Rows[j][0].ToString(),
                                Name = dtUOM.Rows[j][1].ToString(),
                                ConvRate = dtUOM.Rows[j][2].ToString()
                            });
                        }
                        List<PurchaseBatchInfo> ulistBatch = new List<PurchaseBatchInfo>();
                        string qtype = ConvType == "1" || ConvType == "2" || ConvType == "7" ? "Sale" : ConvType == "3" || ConvType == "4" ? "Free" : "Damage";
                        DataTable dtBatch = bl.BL_ExecuteParamSP("uspGetProdInventoryDetailForICV", DDT.Rows[i][0].ToString(), qtype, Date, 0, 0);
                        for (int j = 0; j < dtBatch.Rows.Count; j++)
                        {
                            ulistBatch.Add(new PurchaseBatchInfo
                            {
                                QtyType = dtBatch.Rows[j]["TYPE"].ToString(),
                                InventoryID = dtBatch.Rows[j]["InventoryId"].ToString(),
                                ProdID = DDT.Rows[i][0].ToString(),
                                BatchNo = dtBatch.Rows[j]["BatchNumber"].ToString(),
                                PKDDate = dtBatch.Rows[j]["PKDDate"].ToString(),
                                ExpiryDate = dtBatch.Rows[j]["ExpiryDate"].ToString(),
                                ActQty = dtBatch.Rows[j]["Qty"].ToString(),
                                MRP = dtBatch.Rows[j]["MRP"].ToString(),
                                PurchasePrice = dtBatch.Rows[j]["PurchasePrice"].ToString(),
                                OrgMRP = dtBatch.Rows[j]["MRP"].ToString(),
                                DocDate = dtBatch.Rows[j]["InventoryDate"].ToString()
                                //
                            });
                        }
                        list.Add(new PRBatch
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Code = DDT.Rows[i]["Code"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                            HSNCode = DDT.Rows[i]["HSNCode"].ToString(),
                            ProductDiscPerc = DDT.Rows[i]["ProductDiscPerc"].ToString(),
                            BaseUomID = DDT.Rows[i]["BaseUomID"].ToString(),
                            BaseCR = DDT.Rows[i]["BaseCR"].ToString(),
                            PurchaseUomID = DDT.Rows[i]["PurchaseUomID"].ToString(),
                            PurchaseCR = DDT.Rows[i]["PurchaseCR"].ToString(),
                            PurchaseTaxID = DDT.Rows[i]["PurchaseTaxID"].ToString(),
                            TaxName = DDT.Rows[i]["TaxName"].ToString(),
                            GSTPern = DDT.Rows[i]["GST"].ToString(),
                            PurchasePrice = DDT.Rows[i]["PurchasePrice"].ToString(),
                            SalesPrice = DDT.Rows[i]["SalesPrice"].ToString(),
                            ECP = DDT.Rows[i]["ECP"].ToString(),
                            SPLPrice = DDT.Rows[i]["SPLPrice"].ToString(),
                            MRP = DDT.Rows[i]["MRP"].ToString(),
                            ReturnPrice = DDT.Rows[i]["ReturnPrice"].ToString(),
                            BatchNo = DDT.Rows[i]["TrackBatch"].ToString(),
                            PKD = DDT.Rows[i]["TrackPDK"].ToString(),
                            UOMList = ulist,
                            PRBatchInfo = ulistBatch,
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "8")
                {
                    DDT = bl.BL_ExecuteParamSP("uspGetSetStockDestructionData", Mode, null, CodeName);
                    List<PurchaseModel> list = new List<PurchaseModel>();
                    if (DDT.Rows.Count > 0)
                    {

                        for (int i = 0; i < DDT.Rows.Count; i++)
                        {
                            List<PurchaseBatchInfo> listBatch = new List<PurchaseBatchInfo>();
                            DataTable DDT3 = bl.BL_ExecuteParamSP("uspGetSetStockDestructionData", 9, CodeName);

                            for (int l = 0; l < DDT3.Rows.Count; l++)
                            {
                                listBatch.Add(new PurchaseBatchInfo
                                {

                                    ProdID = DDT3.Rows[l]["ProdID"].ToString(),
                                    UomID = DDT3.Rows[l]["UomID"].ToString(),
                                    TaxPern = DDT3.Rows[l]["TaxPern"].ToString(),
                                    ReasonID = DDT3.Rows[l]["ReasonID"].ToString(),
                                    Reason = DDT3.Rows[l]["Reason"].ToString(),
                                    Code = DDT3.Rows[l]["Code"].ToString(),
                                    Name = DDT3.Rows[l]["Name"].ToString(),
                                    ActQty = DDT3.Rows[l]["OrgQty"].ToString(),
                                    UOMName = DDT3.Rows[l]["UOMName"].ToString(),
                                    PurchasePrice = DDT3.Rows[l]["GrossAmt"].ToString()
                                });
                            }

                            list.Add(new PurchaseModel
                            {
                                ID = DDT.Rows[i]["InventoryID"].ToString(),
                                DocID = DDT.Rows[i]["DocID"].ToString(),
                                Date = Convert.ToDateTime(DDT.Rows[i]["InventoryDate"].ToString()).ToString("yyyy-MM-dd"),
                                RefNo = DDT.Rows[i]["RefNo"].ToString(),
                                BranchID = DDT.Rows[i]["BranchID"].ToString(),
                                GrossAmt = DDT.Rows[i]["TotalAmt"].ToString(),
                                Status = DDT.Rows[i]["Status"].ToString(),
                                Remarks = DDT.Rows[i]["Remarks"].ToString(),
                                Narration = DDT.Rows[i]["Narration"].ToString(),
                                ConvertionType = DDT.Rows[i]["ConvertionTypeId"].ToString(),
                                lstBatchInfo = listBatch,
                                DocPrefix = DDT.Rows[i]["Prefix"].ToString()
                            });
                        }
                    }
                    return Ok(list);
                }
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Inventory", "stockdestruction/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/stockdestruction/save")]
        public IHttpActionResult stockdestructionSave(PurchaseModel listTrans)
        {
            try
            {
                if (listTrans != null)
                {
                    DataTable dtBatch = ToDataTable(listTrans.lstBatchInfo);
                    DataTable dtProducts = ToDataTable(listTrans.lstProdInfo);
                    List<SaveMessage> list = new List<SaveMessage>();
                    bl.bl_Transaction(1);
                    try
                    {
                        int nMode = listTrans.TransMode == "2" ? 3 : 6;
                        DataTable dtResult = bl.bl_ManageTrans("uspManageInventoryAdjustmentHeader", listTrans.BranchID, listTrans.Date, bl.BL_dValidation(listTrans.GrossAmt), listTrans.CBy, bl.BL_nValidation(listTrans.TransID),
                            bl.BL_nValidation(listTrans.UDFId), listTrans.Remarks, listTrans.Narration, listTrans.RefNo,1,0); 
                        if (dtResult.Columns.Count == 1)
                        {
                            int nPRID = bl.BL_nValidation(dtResult.Rows[0][0].ToString());
                            for (int i = 0; i < dtProducts.Rows.Count; i++)
                            {
                                int nProdID = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["ProdID"]));
                                if (nProdID > 0)
                                {
                                    //TrackInventory,TrackBatch,TrackSerial,TrackPDK
                                    DataTable dtPROD = bl.bl_ManageTrans("uspGetSetInventoryAdjustmentData", 6, nProdID);
                                    int InvYN = Convert.ToBoolean(dtPROD.Rows[0]["TrackInventory"].ToString()) ? 1 : 0;
                                    int batYN = Convert.ToBoolean(dtPROD.Rows[0]["TrackBatch"].ToString()) ? 1 : 0;
                                    int serYN = Convert.ToBoolean(dtPROD.Rows[0]["TrackSerial"].ToString()) ? 1 : 0;
                                    int pkdYN = Convert.ToBoolean(dtPROD.Rows[0]["TrackPDK"].ToString()) ? 1 : 0;
                                    int TaxID = bl.BL_nValidation(dtPROD.Rows[0]["PurchaseTaxID"].ToString());
                                    decimal TaxPern = bl.BL_dValidation(dtPROD.Rows[0]["GST"].ToString());
                                    DataRow[] dr = dtBatch.Select("ProdID = '" + nProdID + "'", null);
                                    foreach (DataRow iRow in dr)
                                    {
                                        //DataTable getConvFact = bl.BL_ExecuteSqlQuery("select dbo.fnGetConvertionFact(" + bl.BL_nValidation(dgvProd.Rows[DetailCount].Cells[UomGrpID.Name].Value) + "," + bl.BL_nValidation(dgvProd.Rows[DetailCount].Cells[UomID.Name].Value) + ")");
                                        decimal dUomTax = 0;// bl.GetUOMTaxValue(bl.BL_nValidation(iRow["TaxID"]), bl.BL_nValidation(txtTaxType.Tag),
                                                            //(bl.BL_dValidation(iRow["Qty"]) + bl.BL_dValidation(iRow["DmgQty"])) * (getConvFact.Rows.Count > 0 ? bl.BL_dValidation(getConvFact.Rows[0][0].ToString()) : 0.00M));// bl.BL_dValidation(dgvProd.Rows[DetailCount].Cells[SelectedUomCF.Name].Value));

                                        decimal dQty = bl.BL_dValidation(iRow["Qty"].ToString());
                                        //if (dQty > 0)
                                        {
                                            decimal dGrs = dQty * bl.BL_dValidation(iRow["PurchasePrice"].ToString());

                                            string pkd = !string.IsNullOrEmpty(iRow["ExpiryDate"].ToString()) ? iRow["ExpiryDate"].ToString() : null;
                                            string exp = !string.IsNullOrEmpty(iRow["ExpiryDate"].ToString()) ? iRow["ExpiryDate"].ToString() : null;
                                            string batch = !string.IsNullOrEmpty(iRow["BatchNo"].ToString()) ? iRow["BatchNo"].ToString() : null;
                                            int InventID = bl.BL_nValidation(iRow["InventoryID"].ToString());
                                            DataTable dtResultDetail = new DataTable();
                                            if (InventID > 0)
                                            {
                                                dtResultDetail = bl.bl_ManageTrans("uspInventoryConvertionDetailSave", bl.BL_nValidation(listTrans.BranchID), nPRID, listTrans.Date, nProdID, listTrans.ConvertionType,
                                                   dQty, InventID, dGrs, bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["ReasonID"])),
                                                   listTrans.CBy);
                                            }

                                            if (dtResultDetail.Rows.Count > 0)
                                            {
                                                string Error = dtResultDetail.Rows[0][0].ToString();
                                                bl.bl_Transaction(3);
                                                list.Add(new SaveMessage()
                                                {
                                                    ID = 0.ToString(),
                                                    MsgID = "1",
                                                    Message = Error
                                                });
                                                return Ok(list);
                                            }
                                        }
                                    }
                                }
                            }
                            bl.bl_Transaction(2);
                            bl.BL_UpdateclosingDateforPosting(22, nPRID, Convert.ToDateTime(listTrans.Date));
                            int nBillScopeID = bl.BL_nValidation(dtResult.Rows[0][0]);
                            list.Add(new SaveMessage()
                            {
                                ID = nBillScopeID.ToString(),
                                MsgID = "0",
                                Message = "Saved Successfully"
                            });
                            return Ok(list);
                        }
                        else
                        {
                            bl.bl_Transaction(3);
                            list.Add(new SaveMessage()
                            {
                                ID = 0.ToString(),
                                MsgID = "1",
                                Message = dtResult.Rows[0][0].ToString()
                            });
                            return Ok(list);
                        }
                    }
                    catch (Exception ex)
                    {
                        bl.bl_Transaction(3);
                    }
                    return Ok(0);
                }
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Inventory", "stockdestruction/save", ex.Message);
            }
            return Ok("No data found");
        }

        [HttpGet]
        [Route("api/stockdestruction/getfilterdata")]
        public IHttpActionResult stockdestructionFilterData(string Mode, string TransID, string Branch, string FromDate, string ToDate, string Showall)
        {
            try
            {
                //if (Mode == "6" || Mode == "9")
                {
                    DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetStockDestructionData", Mode, null, Branch, TransID, null, FromDate, ToDate, Showall);
                    List<PurchaseModel> list = new List<PurchaseModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new PurchaseModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            DocID = DDT.Rows[i]["DocID"].ToString(),
                            Date = DDT.Rows[i]["DocDate"].ToString(),
                            RefNo = DDT.Rows[i]["RefNo"].ToString(),
                            BranchID = DDT.Rows[i]["Branch"].ToString(),
                            GrossAmt = DDT.Rows[i]["GrossAmt"].ToString(),
                            Status = DDT.Rows[i]["Status"].ToString(),
                            CBy = DDT.Rows[i]["UserName"].ToString(),
                            CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                            CurrentStatus = DDT.Rows[i]["StatusID"].ToString(),
                            ConvertionType = DDT.Rows[i]["ConvertionType"].ToString(),
                            Remarks = DDT.Rows[i]["Remarks"].ToString(),
                            Narration = DDT.Rows[i]["Narration"].ToString()
                        });
                    }
                    return Ok(list);
                }
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Inventory", "stockdestruction/getfilterdata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/inventoryadjustment/producthistory")]
        public IHttpActionResult inventoryAdjItemHistory(string ProdID, string BranchID)
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspInventoryAdjustmentProdHistory", ProdID, BranchID);
                string jsonhistorydata = JsonConvert.SerializeObject(DDT);
                return Ok(jsonhistorydata);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Inventory", "inventoryadjustment/producthistory", ex.Message);
            }
            return Ok();
        }
        public DataTable ToDataTable<T>(List<T> items)
        {
            DataTable dataTable = new DataTable(typeof(T).Name);
            //Get all the properties
            PropertyInfo[] Props = typeof(T).GetProperties(BindingFlags.Public | BindingFlags.Instance);
            foreach (PropertyInfo prop in Props)
            {
                //Setting column names as Property names
                dataTable.Columns.Add(prop.Name);
            }
            foreach (T item in items)
            {
                var values = new object[Props.Length];
                for (int i = 0; i < Props.Length; i++)
                {
                    //inserting property values to datatable rows
                    values[i] = Props[i].GetValue(item, null);
                }
                dataTable.Rows.Add(values);
            }
            //put a breakpoint here and check datatable
            return dataTable;
        }
    }
}
