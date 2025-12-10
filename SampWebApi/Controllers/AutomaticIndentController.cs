using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Reflection;
using System.Web;
using System.Web.Http;
using System.Web.Http.Cors;
using System.Xml.Linq;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class AutomaticIndentController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        DataTable dtProd = new DataTable();
        [HttpGet]
        [Route("api/automaticindent/get")]
        public IHttpActionResult GetData(string Mode, string CodeName, string ID = null)
        {
            DataTable DDT = new DataTable();
            if (Mode == "1")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetAutoIndentData", Mode, 0);
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
                DDT = bl.BL_ExecuteParamSP("uspGetSetAutoIndentData", Mode, CodeName);
                List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                for (int i = 0; i < DDT.Rows.Count; i++)
                {
                    DataTable DDT1 = bl.BL_ExecuteParamSP("uspGetSetAutoIndentData", 3, DDT.Rows[i]["ID"].ToString());
                    List<ProductModel> listProd = new List<ProductModel>();
                    string AIcount = "", POcount = "";
                    for (int j = 0; j < DDT1.Rows.Count; j++)
                    {
                        AIcount = DDT1.Rows[j][10].ToString();
                        POcount = DDT1.Rows[j][11].ToString();
                        decimal dABS = bl.BL_dValidation(DDT1.Rows[j][4].ToString());
                        int dMOH = bl.BL_nValidation(DDT1.Rows[j][8].ToString());
                        int dMOQ = bl.BL_nValidation(DDT1.Rows[j][9].ToString());
                        decimal dMOHABS = dMOH - dABS;
                        if (dMOHABS > 0)
                        {
                            decimal MOHDivMOQ = dMOHABS / dMOQ;
                            int Floorval = Convert.ToInt32(Math.Floor(MOHDivMOQ));
                            int identqty = Floorval * dMOQ;
                            if (identqty > 0)
                            {
                                List<clsPurchaseUOM> listBranch = new List<clsPurchaseUOM>();
                                DataTable dtBranch = bl.BL_ExecuteParamSP("uspGetSetAutoIndentData", 11, DDT1.Rows[j][0].ToString());
                                for (int k = 0; k < dtBranch.Rows.Count; k++)
                                {
                                    listBranch.Add(new clsPurchaseUOM
                                    {
                                        Name = dtBranch.Rows[k][0].ToString(),
                                        ConvRate = dtBranch.Rows[k][1].ToString(),
                                    });
                                }
                                listProd.Add(new ProductModel
                                {
                                    ID = DDT1.Rows[j][0].ToString(),
                                    Code = DDT1.Rows[j][1].ToString(),
                                    Name = DDT1.Rows[j][2].ToString(),
                                    PurchasePrice = DDT1.Rows[j][3].ToString(),
                                    ABSQty = dABS.ToString(),
                                    BaseUomID = DDT1.Rows[j][5].ToString(),
                                    BaseUOMName = DDT1.Rows[j][6].ToString(),
                                    CustStkReq = DDT1.Rows[j][7].ToString(),
                                    MOH = dMOH.ToString(),
                                    MOQ = dMOQ.ToString(),
                                    IndentQty = identqty.ToString(),
                                    UOMList = listBranch
                                });
                            }
                        }
                    }
                    list.Add(new CustomerVendorModel
                    {
                        ID = DDT.Rows[i]["ID"].ToString(),
                        Code = DDT.Rows[i]["Code"].ToString(),
                        Name = DDT.Rows[i]["Name"].ToString(),
                        Billadd1 = DDT.Rows[i]["Billadd1"].ToString(),
                        Billadd2 = DDT.Rows[i]["Billadd2"].ToString(),
                        Billadd3 = DDT.Rows[i]["Billadd3"].ToString(),
                        Shipadd1 = DDT.Rows[i]["Shipadd1"].ToString(),
                        shipadd2 = DDT.Rows[i]["shipadd2"].ToString(),
                        Shipadd3 = DDT.Rows[i]["Shipadd3"].ToString(),
                        Pincode = DDT.Rows[i]["Pincode"].ToString(),
                        ContactPerson = DDT.Rows[i]["ContactPerson"].ToString(),
                        Ph1 = DDT.Rows[i]["Ph1"].ToString(),
                        Ph2 = DDT.Rows[i]["Ph2"].ToString(),
                        Mob1 = DDT.Rows[i]["Mob1"].ToString(),
                        Mob2 = DDT.Rows[i]["Mob2"].ToString(),
                        Email = DDT.Rows[i]["Email"].ToString(),
                        PANNumber = DDT.Rows[i]["PANNumber"].ToString(),
                        AadharNo = DDT.Rows[i]["AadharNo"].ToString(),
                        DLNo20 = DDT.Rows[i]["DLNo20"].ToString(),
                        DLNo21 = DDT.Rows[i]["DLNo21"].ToString(),
                        FSSAINo = DDT.Rows[i]["FSSAINo"].ToString(),
                        StateID = DDT.Rows[i]["StateID"].ToString(),
                        GSTIN = DDT.Rows[i]["GSTIN"].ToString(),
                        CreditTermID = DDT.Rows[i]["CreditTermID"].ToString(),
                        PaymentModeID = DDT.Rows[i]["PaymentModeID"].ToString(),
                        TaxTypeID = DDT.Rows[i]["TaxTypeID"].ToString(),
                        FAID = DDT.Rows[i]["FAID"].ToString(),
                        WeekCycle = DDT.Rows[i]["WeekCycle"].ToString(),
                        Active = DDT.Rows[i]["Active"].ToString(),
                        Ratings = DDT.Rows[i]["Rating"].ToString(),
                        AIopen = AIcount,
                        POopen = POcount,
                        lstProduct = listProd
                    });
                }
                return Ok(list);
            }
            if (Mode == "4" || Mode == "7")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetAutoIndentData", Mode, CodeName);
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
                        VendorID = DDT.Rows[i]["Party"].ToString(),
                        GrossAmt = DDT.Rows[i]["IndentValue"].ToString(),
                        Status = DDT.Rows[i]["Status"].ToString(),
                    });
                }
                return Ok(list);
            }

            if (Mode == "5" || Mode == "8")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetAutoIndentData", Mode, null, CodeName);
                List<PurchaseModel> list = new List<PurchaseModel>();
                string AIcount = "", POcount = "";
                if (DDT.Rows.Count > 0)
                {
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        DataTable DDTPROD = bl.BL_ExecuteParamSP("uspGetSetAutoIndentData", Mode == "5" ? 6 : 9, null, DDT.Rows[i]["ID"].ToString());
                        List<ProductModel> listProd = new List<ProductModel>();
                        for (int j = 0; j < DDTPROD.Rows.Count; j++)
                        {
                            AIcount = DDTPROD.Rows[j][11].ToString();
                            POcount = DDTPROD.Rows[j][12].ToString();
                            List<clsPurchaseUOM> listBranch = new List<clsPurchaseUOM>();
                            DataTable dtBranch = bl.BL_ExecuteParamSP("uspGetSetAutoIndentData", 11, DDTPROD.Rows[j][0].ToString());
                            for (int k = 0; k < dtBranch.Rows.Count; k++)
                            {
                                listBranch.Add(new clsPurchaseUOM
                                {
                                    Name = dtBranch.Rows[k][0].ToString(),
                                    ConvRate = dtBranch.Rows[k][1].ToString(),
                                });
                            }
                            listProd.Add(new ProductModel
                            {
                                ID = DDTPROD.Rows[j][0].ToString(),
                                BaseUomID = DDTPROD.Rows[j][1].ToString(),
                                Code = DDTPROD.Rows[j][2].ToString(),
                                Name = DDTPROD.Rows[j][3].ToString(),
                                BaseUOMName = DDTPROD.Rows[j][4].ToString(),
                                PurchasePrice = DDTPROD.Rows[j][5].ToString(),
                                ABSQty = DDTPROD.Rows[j][6].ToString(),
                                MOH = DDTPROD.Rows[j][7].ToString(),
                                MOQ = DDTPROD.Rows[j][8].ToString(),
                                IndentQty = DDTPROD.Rows[j][9].ToString(),
                                CustStkReq = DDTPROD.Rows[j][10].ToString(),
                                UOMList = listBranch
                            });
                        }

                        DataTable DDT1 = bl.BL_ExecuteParamSP("uspGetSetAutoIndentData", 21, DDT.Rows[i][6].ToString());
                        List<CustomerVendorModel> listParty = new List<CustomerVendorModel>();
                        for (int j = 0; j < DDT1.Rows.Count; j++)
                        {
                            listParty.Add(new CustomerVendorModel
                            {
                                ID = DDT1.Rows[j]["ID"].ToString(),
                                Code = DDT1.Rows[j]["Code"].ToString(),
                                Name = DDT1.Rows[j]["Name"].ToString(),
                                Billadd1 = DDT1.Rows[j]["Billadd1"].ToString(),
                                Billadd2 = DDT1.Rows[j]["Billadd2"].ToString(),
                                Billadd3 = DDT1.Rows[j]["Billadd3"].ToString(),
                                Shipadd1 = DDT1.Rows[j]["Shipadd1"].ToString(),
                                shipadd2 = DDT1.Rows[j]["shipadd2"].ToString(),
                                Shipadd3 = DDT1.Rows[j]["Shipadd3"].ToString(),
                                Pincode = DDT1.Rows[j]["Pincode"].ToString(),
                                ContactPerson = DDT1.Rows[j]["ContactPerson"].ToString(),
                                Ph1 = DDT1.Rows[j]["Ph1"].ToString(),
                                Ph2 = DDT1.Rows[j]["Ph2"].ToString(),
                                Mob1 = DDT1.Rows[j]["Mob1"].ToString(),
                                Mob2 = DDT1.Rows[j]["Mob2"].ToString(),
                                Email = DDT1.Rows[j]["Email"].ToString(),
                                PANNumber = DDT1.Rows[j]["PANNumber"].ToString(),
                                AadharNo = DDT1.Rows[j]["AadharNo"].ToString(),
                                DLNo20 = DDT1.Rows[j]["DLNo20"].ToString(),
                                DLNo21 = DDT1.Rows[j]["DLNo21"].ToString(),
                                FSSAINo = DDT1.Rows[j]["FSSAINo"].ToString(),
                                StateID = DDT1.Rows[j]["StateID"].ToString(),
                                GSTIN = DDT1.Rows[j]["GSTIN"].ToString(),
                                CreditTermID = DDT1.Rows[j]["CreditTermID"].ToString(),
                                PaymentModeID = DDT1.Rows[j]["PaymentModeID"].ToString(),
                                TaxTypeID = DDT1.Rows[j]["TaxTypeID"].ToString(),
                                FAID = DDT1.Rows[j]["FAID"].ToString(),
                                WeekCycle = DDT1.Rows[j]["WeekCycle"].ToString(),
                                Active = DDT1.Rows[j]["Active"].ToString(),
                                Ratings = DDT1.Rows[j]["Rating"].ToString(),
                                AIopen = AIcount,
                                POopen = POcount,
                            });
                        }
                        string asdf = "";
                        list.Add(new PurchaseModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            DocID = DDT.Rows[i]["DocID"].ToString(),
                            Date = Convert.ToDateTime(DDT.Rows[i]["Date"].ToString()).ToString("yyyy-MM-dd"),
                            RefNo = DDT.Rows[i]["RefNo"].ToString(),
                            BranchID = DDT.Rows[i]["BranchID"].ToString(),
                            VendorID = DDT.Rows[i]["VendorID"].ToString(),
                            Status = DDT.Rows[i]["Status"].ToString(),
                            UDFId = DDT.Rows[i]["UDFId"].ToString(),
                            UDFDocId = DDT.Rows[i]["UDFDocId"].ToString(),
                            UDFDocPrefix = DDT.Rows[i]["UDFDocPrefix"].ToString(),
                            UDFDocValue = DDT.Rows[i]["UDFDocValue"].ToString(),
                            Remarks = DDT.Rows[i]["Remarks"].ToString(),
                            Narration = DDT.Rows[i]["Narration"].ToString(),
                            TransportID = bl.BL_nValidation(DDT.Rows[i]["PoID"].ToString()) > 0 ? "1" : "0",
                            lstPartyInfo = listParty,
                            lstProduct = listProd
                        });
                    }
                }
                return Ok(list);
            }
            if (Mode == "10")
            {
                DDT = bl.BL_ExecuteParamSP("uspGetSetAutoIndentData", Mode, null, CodeName);
                return Ok("0");
            }

            return Ok();
        }
        //
        
        [HttpGet]
        [Route("api/automaticindent/getbranchqty")]
        public IHttpActionResult GetBranchqty(string ProdID)
        {
            string qry = "select MBO.Name Branch,dbo.fngetroundedvalue(SUM(ActualQty)) ActualQty,dbo.fngetroundedvalue(SUM(ActualFreeQty)) ActualFreeQty,dbo.fngetroundedvalue(SUM(ActualDmgQty)) ActualDmgQty,MP.Name ProductName,MP.Code ProductCode from tblProductInventory PV JOIN tblMasterBranchOffice MBO ON MBO.ID = PV.BranchID JOIN tblMasterProduct MP ON MP.ID = PV.ProdID WHERE PRODID = " + ProdID + " GROUP BY MBO.Name,MP.Name,MP.Code";
            DataTable dtQty = bl.BL_ExecuteSqlQuery(qry);
            List<ProductModel> listProd = new List<ProductModel>();
            for (int i = 0; i < dtQty.Rows.Count; i++)
            {
                listProd.Add(new ProductModel()
                {
                    Name = dtQty.Rows[i]["ProductName"].ToString(),
                    Code = dtQty.Rows[i]["ProductCode"].ToString(),
                    Branch = dtQty.Rows[i]["Branch"].ToString(),
                    ABSQty = dtQty.Rows[i]["ActualQty"].ToString(),
                    ABSFreeQty = dtQty.Rows[i]["ActualFreeQty"].ToString(),
                    ABSDmgQty = dtQty.Rows[i]["ActualDmgQty"].ToString(),
                });
            }
            return Ok(listProd);
        }

       [HttpGet]
        [Route("api/automaticindent/getfilterdata")]
        public IHttpActionResult GetFilterData(string TransID, string FType, string Branch, string Party, string FromDate, string ToDate, string Showall)
        {
            //if (Mode == "6" || Mode == "9")
            {
                string Mode = FType == "1" ? "4" : "7";
                DataTable DDT = bl.BL_ExecuteParamSP("uspGetSetAutoIndentData", Mode, FType, Branch, TransID, Party, FromDate, ToDate, Showall);
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
                        VendorID = DDT.Rows[i]["Party"].ToString(),
                        GrossAmt = DDT.Rows[i]["IndentValue"].ToString(),
                        Status = DDT.Rows[i]["Status"].ToString(),
                        CBy = DDT.Rows[i]["UserName"].ToString(),
                        CDate = DDT.Rows[i]["LastActionTime"].ToString(),
                        CurrentStatus = DDT.Rows[i]["StatusID"].ToString(),
                    });
                }
                return Ok(list);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/automaticindent/save")]
        public IHttpActionResult Save(PurchaseModel listTrans)
        {
            if (listTrans != null)
            {

                DataTable dtAI = new DataTable();
                dtAI.Columns.Add("ProdID", typeof(int));
                dtAI.Columns.Add("UomID", typeof(int));
                dtAI.Columns.Add("PurchasePrice", typeof(decimal));
                dtAI.Columns.Add("ABSQty", typeof(decimal));
                dtAI.Columns.Add("MOH", typeof(int));
                dtAI.Columns.Add("MOQ", typeof(int));
                dtAI.Columns.Add("IndentQty", typeof(int));
                dtAI.Columns.Add("Serial", typeof(int));
                DataTable dtProd = new DataTable();
                if (dtProd.Columns.Count == 0)
                {
                    dtProd.Columns.Add("ProdId", typeof(int));
                    dtProd.Columns.Add("UomId", typeof(int));
                    dtProd.Columns.Add("Qty", typeof(decimal));
                    dtProd.Columns.Add("PurchasePrice", typeof(decimal));
                    dtProd.Columns.Add("TaxID", typeof(int));
                    dtProd.Columns.Add("TaxPercentage", typeof(decimal));
                    dtProd.Columns.Add("GrossAmt", typeof(decimal), bl.dValidationExp("(Qty*PurchasePrice)")).DefaultValue = 0;
                    dtProd.Columns.Add("TaxAmt", typeof(decimal), bl.dValidationExp("((GrossAmt*TaxPercentage)/100)"));
                    dtProd.Columns.Add("NetAmt", typeof(decimal), bl.dValidationExp("(GrossAmt+TaxAmt)"));
                    dtProd.Columns.Add("InventoryId", typeof(int));
                    dtProd.Columns.Add("Serial", typeof(int));
                    dtProd.Columns.Add("UomCR", typeof(decimal));
                }
                DataTable dtProducts = ToDataTable(listTrans.lstProduct);
                List<SaveMessage> list = new List<SaveMessage>();
                if (listTrans.TransMode != "4")
                {
                    int nPOserial = 1; 
                    for (int i = 0; i < dtProducts.Rows.Count; i++)
                    {
                        int nProdID = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["ID"]));
                        if (nProdID > 0)
                        {
                            int Qty = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["IndentQty"]));
                            DataRow dtRow = dtAI.NewRow();
                            dtRow[0] = nProdID;
                            dtRow[1] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["BaseUomID"]));
                            dtRow[2] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["PurchasePrice"]));
                            dtRow[3] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["ABSQty"]));
                            dtRow[4] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["MOH"]));
                            dtRow[5] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["MOQ"]));
                            dtRow[6] = Qty;
                            dtRow[7] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["TrackSerial"]));
                            dtAI.Rows.Add(dtRow);
                            DataTable dtPROD = bl.BL_ExecuteParamSP("uspGetSetInventoryAdjustmentData", 6, nProdID);
                            int TaxID = bl.BL_nValidation(dtPROD.Rows[0]["PurchaseTaxID"].ToString());
                            decimal TaxPern = bl.BL_dValidation(dtPROD.Rows[0]["GST"].ToString());
                            decimal dBase = bl.BL_dValidation(dtPROD.Rows[0]["BaseCR"].ToString());
                            if (Qty > 0)
                            {
                                DataRow drPo = dtProd.NewRow();
                                drPo[0] = nProdID;
                                drPo[1] = bl.BL_nValidation(Convert.ToString(dtProducts.Rows[i]["BaseUomID"]));
                                drPo[2] = Qty;
                                drPo[3] = bl.BL_dValidation(Convert.ToString(dtProducts.Rows[i]["PurchasePrice"]));
                                drPo[4] = TaxID;
                                drPo[5] = TaxPern;
                                drPo[9] = bl.BL_dValidation(0);
                                drPo[10] = nPOserial;
                                drPo[11] = dBase;
                                dtProd.Rows.Add(drPo);
                                nPOserial++;
                            }
                        }
                    }
                    if (listTrans.IsDraft == "0")
                    {
                        string nMode = listTrans.TransMode == "3" ? "1" : listTrans.TransMode;
                        bl.bl_Transaction(1);
                        DataTable dtResult = bl.bl_ManageTrans("uspManageAutomaticIndent", nMode, bl.BL_nValidation(listTrans.ID), listTrans.VendorID, bl.BL_nValidation(listTrans.BranchID),
                            listTrans.Date, listTrans.RefNo, listTrans.UDFId, listTrans.TransportID, listTrans.CBy, bl.BL_nValidation(listTrans.CurrentStatus), bl.BL_dValidation(listTrans.NetAmt),
                            listTrans.Remarks, listTrans.Narration, bl.BL_nValidation(listTrans.DraftID), dtAI, dtProd);
                        if (dtResult.Columns.Count > 1)
                        {
                            bl.bl_Transaction(3);
                            string[] strErrorList = dtResult.Rows[0][0].ToString().Split('$');

                            list.Add(new SaveMessage()
                            {
                                ID = 0.ToString(),
                                MsgID = "1",
                                Message = dtResult.Rows[0][0].ToString()
                            });
                            return Ok(list);
                        }
                        else
                        {
                            bl.bl_Transaction(2);
                            int nBillScopeID = bl.BL_nValidation(dtResult.Rows[0][0]);
                            list.Add(new SaveMessage()
                            {
                                ID = nBillScopeID.ToString(),
                                MsgID = "0",
                                Message = "Saved Successfully"
                            });
                            return Ok(list);
                        }
                    }
                    else //  Draft
                    {
                        bl.bl_Transaction(1);
                        DataTable dtResult = bl.bl_ManageTrans("uspManageAutomaticIndentDraft", listTrans.TransMode, bl.BL_nValidation(listTrans.ID), listTrans.VendorID, bl.BL_nValidation(listTrans.BranchID),
                             listTrans.Date, listTrans.RefNo, listTrans.UDFId, 0, listTrans.CBy, bl.BL_nValidation(listTrans.CurrentStatus), bl.BL_dValidation(listTrans.NetAmt),
                             listTrans.Remarks, listTrans.Narration, bl.BL_nValidation(listTrans.DraftID), dtAI, listTrans.TransportID);
                        if (dtResult.Columns.Count > 1)
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
                        else
                        {
                            bl.bl_Transaction(2);
                            int nBillScopeID = bl.BL_nValidation(dtResult.Rows[0][0]);
                            list.Add(new SaveMessage()
                            {
                                ID = nBillScopeID.ToString(),
                                MsgID = "0",
                                Message = "Saved Successfully"
                            });
                            return Ok(list);
                        }
                    }
                }
                else// for cancel
                {
                    bl.bl_Transaction(1);
                    DataTable dtResult = bl.bl_ManageTrans("uspManageAutomaticIndentCancel", listTrans.ID, listTrans.CBy, listTrans.CurrentStatus, listTrans.Remarks, listTrans.Narration);
                    if (dtResult.Rows.Count > 0)
                    {
                        bl.bl_Transaction(3);
                        list.Add(new SaveMessage()
                        {
                            ID = 1.ToString(),
                            MsgID = "1",
                            Message = dtResult.Rows[0][0].ToString()
                        });
                        return Ok(list);
                    }
                    else
                    {
                        bl.bl_Transaction(2);
                        list.Add(new SaveMessage()
                        {
                            ID = 0.ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                        return Ok(list);
                    }
                }
                return Ok(0);
            }
            return Ok("No data found");
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
