using DocumentFormat.OpenXml.Office2010.PowerPoint;
using DocumentFormat.OpenXml.Spreadsheet;
using DocumentFormat.OpenXml.Vml;
using DocumentFormat.OpenXml.Wordprocessing;
using MessagingToolkit.QRCode.Crypt;
using Newtonsoft.Json;
using Org.BouncyCastle.Asn1.X509;
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
using System.Reflection;
using System.Text.Json.Nodes;
using System.Threading.Tasks;
using System.Web;
using System.Web.Hosting;
using System.Web.Http;
using System.Web.Http.Cors;
using System.Xml.Linq;
using static System.Windows.Forms.VisualStyles.VisualStyleElement;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class CustomerVendorProductController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/customermaster/get")]
        public IHttpActionResult GetData(string Mode, string Name)
        {
            try
            {
                DataTable DDT = new DataTable();
                if (Mode == "4")
                {
                    DDT = bl.BL_ExecuteParamSP("uspManageCustomerMaster", Mode, 0);
                    List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new CustomerVendorModel
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            Code = DDT.Rows[i][1].ToString(),
                            Name = DDT.Rows[i][2].ToString(),
                            CustomerType = DDT.Rows[i][3].ToString(),
                            Mob1 = DDT.Rows[i][4].ToString(),
                            GSTIN = DDT.Rows[i][5].ToString(),
                            Ratings = DDT.Rows[i][6].ToString(),
                            Active = DDT.Rows[i][7].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "444")
                {
                    DDT = bl.BL_ExecuteParamSP("uspManageCustomerMaster", 4, 0);
                    return Ok(DDT);
                }
                if (Mode == "5")
                {
                    DDT = bl.BL_ExecuteParamSP("uspManageCustomerMaster", Mode, Name);
                    List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        List<MapBeatSalesman> listBSM = new List<MapBeatSalesman>();
                        DataTable dtBSM = bl.BL_ExecuteParamSP("uspManageCustomerMaster", 7, DDT.Rows[i]["ID"].ToString());
                        for (int j = 0; j < dtBSM.Rows.Count; j++)
                        {
                            listBSM.Add(new MapBeatSalesman
                            {
                                BeatName = dtBSM.Rows[j][1].ToString(),
                                SalesmanName = dtBSM.Rows[j][2].ToString()
                            });
                        }
                        List<clsCustomerRemarks> listREM = new List<clsCustomerRemarks>();
                        DataTable dtREM = bl.BL_ExecuteParamSP("uspManageCustomerMaster", 9, DDT.Rows[i]["ID"].ToString());
                        for (int j = 0; j < dtREM.Rows.Count; j++)
                        {
                            listREM.Add(new clsCustomerRemarks
                            {
                                Remarks = dtREM.Rows[j][1].ToString()
                            });
                        }
                        list.Add(new CustomerVendorModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Code = DDT.Rows[i]["Code"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                            Shinecode = DDT.Rows[i]["Shinecode"].ToString(),
                            Billadd1 = DDT.Rows[i]["Billadd1"].ToString(),
                            Billadd2 = DDT.Rows[i]["Billadd2"].ToString(),
                            Billadd3 = DDT.Rows[i]["Billadd3"].ToString(),
                            Shipadd1 = DDT.Rows[i]["Shipadd1"].ToString(),
                            Shipadd2 = DDT.Rows[i]["shipadd2"].ToString(),
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
                            OSValue = DDT.Rows[i]["OSVAL"].ToString(),
                            OverDueValue = DDT.Rows[i]["OSCOUNT"].ToString(),//
                            OverDueInvCount = DDT.Rows[i]["OverDueInvCount"].ToString(),//
                            CreditLimitValue = DDT.Rows[i]["CreditLimitValue"].ToString(),
                            CreditLimitCount = DDT.Rows[i]["CreditLimitCount"].ToString(),
                            CreditlimitOS = DDT.Rows[i]["CreditlimitOS"].ToString(),
                            PriceTypeID = DDT.Rows[i]["PriceTypeID"].ToString(),
                            OwnerName = DDT.Rows[i]["OwnerName"].ToString(),
                            DiscountPern = DDT.Rows[i]["DiscountPern"].ToString(),
                            TrackPoint = DDT.Rows[i]["TrackPoint"].ToString(),
                            ClosingTrackPoint = DDT.Rows[i]["ClosingTrackPoint"].ToString(),
                            TCSTax = DDT.Rows[i]["TCSTax"].ToString(),
                            Latitude = DDT.Rows[i]["Latitude"].ToString(),
                            Longtitude = DDT.Rows[i]["Longtitude"].ToString(),
                            Distance = DDT.Rows[i]["Distance"].ToString(),
                            Remark = DDT.Rows[i]["Remark"].ToString(),
                            Active = DDT.Rows[i]["Active"].ToString(),
                            CustomerType = DDT.Rows[i]["CustomerType"].ToString(),
                            Ratings = DDT.Rows[i]["Rating"].ToString(),
                            
                            BSM = listBSM,
                            lstCustRemark = listREM
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "6")
                {
                    DDT = bl.BL_ExecuteParamSP("uspManageCustomerMaster", Mode, Name);
                    List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new CustomerVendorModel
                        {
                            FType = DDT.Rows[i][0].ToString(),
                            Form = DDT.Rows[i][1].ToString(),
                            ID = DDT.Rows[i][2].ToString(),
                            Name = DDT.Rows[i][3].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CustomerVendorProduct", "customermaster/get", ex.Message);
            }
            return Ok();
        }

        [HttpPost]
        [Route("api/customermaster/save")]
        public IHttpActionResult SaveBankAccont(CustomerVendorModel lstMaster)
        {
            List<SaveMessage> list = new List<SaveMessage>();
            try
            {
                if (lstMaster != null)
                {
                    string ID = !string.IsNullOrEmpty(lstMaster.ID) ? lstMaster.ID : "0";
                    DataTable DDT = bl.BL_ExecuteParamSP("uspManageCustomerMaster", lstMaster.Mode, ID, lstMaster.Code, lstMaster.Name, lstMaster.Billadd1,
                        lstMaster.Billadd2, lstMaster.Billadd3, lstMaster.Shipadd1, lstMaster.Shipadd2, lstMaster.Shipadd3, bl.CheckString(lstMaster.Pincode), lstMaster.ContactPerson,
                        lstMaster.Ph1, lstMaster.Ph2, lstMaster.Mob1, lstMaster.Mob2, lstMaster.Email, lstMaster.PANNumber, lstMaster.AadharNo, lstMaster.DLNo20, lstMaster.DLNo21,
                        lstMaster.FSSAINo, lstMaster.StateID, lstMaster.GSTIN.ToUpper(), lstMaster.CreditTermID, lstMaster.PaymentModeID, lstMaster.TaxTypeID,
                        lstMaster.FAID, bl.CheckString(lstMaster.OverDueValue), bl.CheckString(lstMaster.OverDueInvCount), bl.CheckString(lstMaster.CreditLimitValue), bl.CheckString(lstMaster.CreditLimitCount),
                        bl.CheckString(lstMaster.CreditlimitOS), lstMaster.PriceTypeID,
                        lstMaster.OwnerName, bl.CheckString(lstMaster.DiscountPern), bl.CheckString(lstMaster.TrackPoint), bl.CheckString(lstMaster.ClosingTrackPoint), lstMaster.TCSTax, lstMaster.Latitude, lstMaster.Longtitude,
                        bl.CheckString(lstMaster.Distance),
                        lstMaster.Remark, lstMaster.Active, lstMaster.UserID, lstMaster.CustomerType, lstMaster.Ratings, lstMaster.Shinecode);
                    if (DDT.Columns.Count == 1)
                    {
                        int IsoldDelete = 0, IdentID = Convert.ToInt32(DDT.Rows[0][0].ToString());
                        foreach (MapBeatSalesman item in lstMaster.BSM)
                        {
                            bl.BL_ExecuteParamSP("uspManageCustomerMaster", 3, IdentID, item.BeatName, item.SalesmanName, IsoldDelete);
                            IsoldDelete = 1;
                        }
                        IsoldDelete = 0;
                        foreach (clsCustomerRemarks item in lstMaster.lstCustRemark)
                        {
                            bl.BL_ExecuteParamSP("uspManageCustomerMaster", 8, IdentID, item.Remarks, IsoldDelete);
                            IsoldDelete = 1;
                        }
                        //Success message
                        list.Add(new SaveMessage()
                        {
                            ID = IdentID.ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        //Error message
                        list.Add(new SaveMessage()
                        {
                            ID = "0",
                            MsgID = "1",
                            Message = DDT.Rows[0][0].ToString()
                        });
                    }
                    return Ok(list);
                }
            }
            catch (Exception ex)
            {
                list.Add(new SaveMessage()
                {
                    ID = "1",
                    MsgID = "1",
                    Message = ex.Message
                });
            }
            return Ok(list);
        }

        [HttpGet]
        [Route("api/vendormaster/get")]
        public IHttpActionResult GetVendorData(string Mode, string Name)
        {
            try
            {
                DataTable DDT = new DataTable();
                if (Mode == "3")
                {
                    DDT = bl.BL_ExecuteParamSP("uspManageVendorMaster", Mode, 0);
                    List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new CustomerVendorModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Code = DDT.Rows[i]["Code"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                            Shinecode = DDT.Rows[i]["Shinecode"].ToString(),
                            ContactPerson = DDT.Rows[i]["ContactPerson"].ToString(),
                            Mob1 = DDT.Rows[i]["Mob1"].ToString(),
                            Mob2 = DDT.Rows[i]["Mob2"].ToString(),
                            Ph1 = DDT.Rows[i]["Ph1"].ToString(),
                            Ph2 = DDT.Rows[i]["Ph2"].ToString(),
                            GSTIN = DDT.Rows[i]["GSTIN"].ToString(),
                            Ratings = DDT.Rows[i]["Ratings"].ToString(),
                            Active = DDT.Rows[i]["Active"].ToString(),
                            Email = DDT.Rows[i]["Email"].ToString(),
                            Billadd1 = DDT.Rows[i]["Billadd1"].ToString(),
                            Billadd2 = DDT.Rows[i]["Billadd2"].ToString(),
                            Billadd3 = DDT.Rows[i]["Billadd3"].ToString(),
                            Shipadd1 = DDT.Rows[i]["Shipadd1"].ToString(),
                            Shipadd2 = DDT.Rows[i]["Shipadd2"].ToString(),
                            Shipadd3 = DDT.Rows[i]["Shipadd3"].ToString(),
                            Pincode = DDT.Rows[i]["Pincode"].ToString(),
                            PANNumber = DDT.Rows[i]["PANNumber"].ToString(),
                            AadharNo = DDT.Rows[i]["AadharNo"].ToString(),
                            DLNo20 = DDT.Rows[i]["DLNo20"].ToString(),
                            DLNo21 = DDT.Rows[i]["DLNo21"].ToString(),
                            FSSAINo = DDT.Rows[i]["FSSAINo"].ToString(),
                            StateName = DDT.Rows[i]["StateName"].ToString(),
                            TaxTypeName = DDT.Rows[i]["TaxTypeName"].ToString(),
                            PaymentMode = DDT.Rows[i]["PaymentMode"].ToString(),
                            WeekCycle = DDT.Rows[i]["WeekCycle"].ToString(),
                            CreditTerm = DDT.Rows[i]["CreditTerm"].ToString(),

                        });
                    }
                    return Ok(list);
                }
                if (Mode == "4")
                {
                    DDT = bl.BL_ExecuteParamSP("uspManageVendorMaster", Mode, Name);
                    List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new CustomerVendorModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Code = DDT.Rows[i]["Code"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                            Shinecode = DDT.Rows[i]["Shinecode"].ToString(),
                            Billadd1 = DDT.Rows[i]["Billadd1"].ToString(),
                            Billadd2 = DDT.Rows[i]["Billadd2"].ToString(),
                            Billadd3 = DDT.Rows[i]["Billadd3"].ToString(),
                            Shipadd1 = DDT.Rows[i]["Shipadd1"].ToString(),
                            Shipadd2 = DDT.Rows[i]["shipadd2"].ToString(),
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
                            OSValue = DDT.Rows[i]["OSVAL"].ToString(),
                            OverDueValue = DDT.Rows[i]["OSCOUNT"].ToString()
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "5")
                {
                    DDT = bl.BL_ExecuteParamSP("uspManageVendorMaster", Mode, 0);
                    List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new CustomerVendorModel
                        {
                            FType = DDT.Rows[i][0].ToString(),
                            Form = DDT.Rows[i][1].ToString(),
                            ID = DDT.Rows[i][2].ToString(),
                            Name = DDT.Rows[i][3].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CustomerVendorProduct", "vendormaster/get", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/vendormaster/getalldata")]
        public IHttpActionResult GetAllVendorData(string Mode, string Name)
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspManageVendorMaster", Mode, 0);
                return Ok(DDT);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CustomerVendorProduct", "vendormaster/getalldata", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/vendormaster/save")]
        public IHttpActionResult SaveVendor(CustomerVendorModel lstMaster)
        {
            List<SaveMessage> list = new List<SaveMessage>();
            try
            {
                if (lstMaster != null)
                {
                    string ID = !string.IsNullOrEmpty(lstMaster.ID) ? lstMaster.ID : "0";
                    DataTable DDT = bl.BL_ExecuteParamSP("uspManageVendorMaster", lstMaster.Mode, ID, lstMaster.Code, lstMaster.Name, lstMaster.Billadd1,
                        lstMaster.Billadd2, lstMaster.Billadd3, lstMaster.Shipadd1, lstMaster.Shipadd2, lstMaster.Shipadd3, bl.CheckString(lstMaster.Pincode), lstMaster.ContactPerson,
                        lstMaster.Ph1, lstMaster.Ph2, lstMaster.Mob1, lstMaster.Mob2, lstMaster.Email, lstMaster.PANNumber, lstMaster.AadharNo, lstMaster.DLNo20, lstMaster.DLNo21,
                        lstMaster.FSSAINo, lstMaster.StateID, lstMaster.GSTIN.ToUpper(), lstMaster.CreditTermID, lstMaster.PaymentModeID, lstMaster.TaxTypeID,
                        lstMaster.FAID, lstMaster.WeekCycle, lstMaster.Active, lstMaster.UserID, lstMaster.Ratings, lstMaster.Shinecode);
                    if (DDT.Columns.Count == 1)
                    {
                        int IdentID = Convert.ToInt32(DDT.Rows[0][0].ToString());
                        //Success message
                        list.Add(new SaveMessage()
                        {
                            ID = IdentID.ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        //Error message
                        list.Add(new SaveMessage()
                        {
                            ID = "0",
                            MsgID = "1",
                            Message = DDT.Rows[0][0].ToString()
                        });
                    }
                    return Ok(list);
                }
            }
            catch (Exception ex)
            {
                list.Add(new SaveMessage()
                {
                    ID = "1",
                    MsgID = "1",
                    Message = ex.Message
                });
            }
            return Ok(list);
        }


        [HttpGet]
        [Route("api/productmaster/get")]
        public IHttpActionResult GetProductData(string Mode, string Name)
        {
            try
            {
                DataTable DDT = new DataTable();
                if (Mode == "3")
                {
                    DDT = bl.BL_ExecuteParamSP("uspManageProductMaster", Mode, 0);
                    List<ProductModel> list = new List<ProductModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new ProductModel
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            Code = DDT.Rows[i][1].ToString(),
                            Name = DDT.Rows[i][2].ToString(),
                            EAN = DDT.Rows[i][3].ToString(),
                            MfrID = DDT.Rows[i][4].ToString(),
                            BrandID = DDT.Rows[i][5].ToString(),
                            CategoryID = DDT.Rows[i][6].ToString(),
                            Active = DDT.Rows[i][7].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "4")
                {
                    DataSet dtProdData = bl.BL_ExecuteParamSPDataset("uspManageProductMaster", Mode, Name);
                    DDT = dtProdData.Tables[0];
                    DataTable dtProductLocation = dtProdData.Tables[1];
                    DataTable dtProductStock = dtProdData.Tables[2];
                    DataTable dtProdImage = dtProdData.Tables[3];
                    //bl.BL_ExecuteParamSP("uspManageProductMaster", Mode, Name);
                    List<ProductModel> list = new List<ProductModel>();
                    List<clsProdLocMapping> listProcLocMap = new List<clsProdLocMapping>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        string PBPrice = "0", PRPrice = "0", InvPrice = "0", SRPrice = "0";
                        DataTable dtPrices = bl.BL_ExecuteParamSP("uspGetProductTransactionPrice", 1, DDT.Rows[i]["ID"].ToString());
                        if (dtPrices.Rows.Count > 0)
                        {
                            PBPrice = dtPrices.Rows[0][1].ToString();
                            PRPrice = dtPrices.Rows[0][2].ToString();
                            InvPrice = dtPrices.Rows[0][3].ToString();
                            SRPrice = dtPrices.Rows[0][4].ToString();
                        }
                        if (dtProductLocation.Rows.Count > 0)
                        {
                            for (int k = 0; k < dtProductLocation.Rows.Count; k++)
                            {
                                listProcLocMap.Add(new clsProdLocMapping
                                {
                                    ProductID = dtProductLocation.Rows[k][0].ToString(),
                                    BranchID = dtProductLocation.Rows[k][1].ToString(),
                                    LocationID = dtProductLocation.Rows[k][2].ToString(),
                                });
                            }
                        }
                        string ItemStock = "0.00";
                        if (dtProductStock.Rows.Count > 0)
                        {
                            ItemStock = dtProductStock.Rows[0][1].ToString();
                        }
                        List<CompressedImage> listproductimages = new List<CompressedImage>();
                        for (int k = 0; k < dtProdImage.Rows.Count; k++)
                        {
                            string imgdata = null;
                            if (!string.IsNullOrEmpty(dtProdImage.Rows[k][5].ToString()))
                            {
                                byte[] photoBytes = (byte[])dtProdImage.Rows[k][5];
                                imgdata = Convert.ToBase64String(photoBytes);
                            }
                            listproductimages.Add(new CompressedImage
                            {
                                FileName = dtProdImage.Rows[k][3].ToString(),
                                FileSize = dtProdImage.Rows[k][4].ToString(),
                                CompressImageData = imgdata,
                            });
                        }
                        list.Add(new ProductModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Code = DDT.Rows[i]["Code"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                            EAN = DDT.Rows[i]["EAN"].ToString(),
                            Shinecode = DDT.Rows[i]["Shinecode"].ToString(),
                            MfrID = DDT.Rows[i]["MfrName"].ToString(),
                            BrandID = DDT.Rows[i]["BrandName"].ToString(),
                            CategoryID = DDT.Rows[i]["CategoryName"].ToString(),
                            HSNCode = DDT.Rows[i]["HSNCode"].ToString(),
                            ProductDiscPerc = DDT.Rows[i]["ProductDiscPerc"].ToString(),
                            BaseUomID = DDT.Rows[i]["BaseUomID"].ToString(),
                            BaseCR = DDT.Rows[i]["BaseCR"].ToString(),
                            PurchaseUomID = DDT.Rows[i]["PurchaseUomID"].ToString(),
                            PurchaseCR = DDT.Rows[i]["PurchaseCR"].ToString(),
                            SalesUomID = DDT.Rows[i]["SalesUomID"].ToString(),
                            SalesCR = DDT.Rows[i]["SalesCR"].ToString(),
                            ReportingUomID = DDT.Rows[i]["ReportingUomID"].ToString(),
                            ReportingCR = DDT.Rows[i]["ReportingCR"].ToString(),
                            ReportingQty = DDT.Rows[i]["ReportingQty"].ToString(),
                            PurchaseTaxID = DDT.Rows[i]["PurchaseTaxID"].ToString(),
                            SalesTaxID = DDT.Rows[i]["SalesTaxID"].ToString(),
                            PurchasePrice = DDT.Rows[i]["PurchasePrice"].ToString(),
                            SalesPrice = DDT.Rows[i]["SalesPrice"].ToString(),
                            ECP = DDT.Rows[i]["ECP"].ToString(),
                            SPLPrice = DDT.Rows[i]["SPLPrice"].ToString(),
                            MRP = DDT.Rows[i]["MRP"].ToString(),
                            ReturnPrice = DDT.Rows[i]["ReturnPrice"].ToString(),

                            SaleonMRP = DDT.Rows[i]["SaleonMRP"].ToString(),
                            SaleonpPern = DDT.Rows[i]["SaleonpPern"].ToString(),
                            ECPonMRP = DDT.Rows[i]["ECPonMRP"].ToString(),
                            ECPonpPern = DDT.Rows[i]["ECPonpPern"].ToString(),
                            SPLonMRP = DDT.Rows[i]["SPLonMRP"].ToString(),
                            SPLonpPern = DDT.Rows[i]["SPLonpPern"].ToString(),

                            TrackInventory = DDT.Rows[i]["TrackInventory"].ToString(),
                            TrackBatch = DDT.Rows[i]["TrackBatch"].ToString(),
                            TrackSerial = DDT.Rows[i]["TrackSerial"].ToString(),
                            TrackPDK = DDT.Rows[i]["TrackPDK"].ToString(),
                            DateFormat = DDT.Rows[i]["DateFormat"].ToString(),
                            BarcodeUomID = DDT.Rows[i]["BarcodeUomID"].ToString(),
                            BarcodePriceID = DDT.Rows[i]["BarcodePriceID"].ToString(),
                            VendorID = DDT.Rows[i]["VendorName"].ToString(),
                            LocationID = DDT.Rows[i]["Location"].ToString(),
                            MOH = DDT.Rows[i]["MOH"].ToString(),
                            MOQ = DDT.Rows[i]["MOQ"].ToString(),
                            Remarks = DDT.Rows[i]["Remarks"].ToString(),
                            Active = DDT.Rows[i]["Active"].ToString(),
                            Weborder = DDT.Rows[i]["Weborder"].ToString(),
                            BarcodePrint = DDT.Rows[i]["BarcodeEnable"].ToString(),
                            ProdInvCount = DDT.Rows[i]["ProdInvCount"].ToString(),
                            ProdBatCount = DDT.Rows[i]["ProdBatCount"].ToString(),
                            ProdPkdCount = DDT.Rows[i]["ProdPkdCount"].ToString(),
                            ProdLifeTime = DDT.Rows[i]["LifeTime"].ToString(),
                            PurchaseBillPrice = PBPrice,
                            PurchaseReturnPrice = PRPrice,
                            InvoicePrice = InvPrice,
                            SalesReturnPrice = SRPrice,
                            lstProdLocMapping = listProcLocMap,
                            ProductImages = listproductimages,
                            ABSQty = ItemStock
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "5")
                {
                    DDT = bl.BL_ExecuteParamSP("uspManageProductMaster", Mode, 0);
                    List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new CustomerVendorModel
                        {
                            FType = DDT.Rows[i][0].ToString(),
                            Form = DDT.Rows[i][1].ToString(),
                            ID = DDT.Rows[i][2].ToString(),
                            Name = DDT.Rows[i][3].ToString(),
                            TaxTypeID = DDT.Rows[i][4].ToString(),
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CustomerVendorProduct", "productmaster/get", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/productmaster/getalldata")]
        public IHttpActionResult GetAllProductData(string Mode, string Name)
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspManageProductMaster", Mode, 0);
                return Ok(DDT);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CustomerVendorProduct", "productmaster/getalldata", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/productmaster/save_OLD")]
        public IHttpActionResult SaveProduct_OLD(ProductModel lstMaster)
        {
            List<SaveMessage> list = new List<SaveMessage>();
            try
            {
                if (lstMaster != null)
                {
                    string ID = !string.IsNullOrEmpty(lstMaster.ID) ? lstMaster.ID : "0";
                    DataTable DDT = bl.BL_ExecuteParamSP("uspManageProductMaster", lstMaster.Mode, ID, lstMaster.Code, lstMaster.Name, lstMaster.EAN, lstMaster.MfrID, lstMaster.BrandID, lstMaster.CategoryID,
                        bl.CheckString(lstMaster.HSNCode), bl.CheckString(lstMaster.ProductDiscPerc), lstMaster.BaseUomID, lstMaster.BaseCR, lstMaster.PurchaseUomID,
                        lstMaster.PurchaseCR, lstMaster.SalesUomID, lstMaster.SalesCR, lstMaster.ReportingUomID, lstMaster.ReportingCR,
                            bl.CheckString(lstMaster.ReportingQty), lstMaster.PurchaseTaxID,
                            lstMaster.SalesTaxID, bl.CheckString(lstMaster.PurchasePrice), bl.CheckString(lstMaster.SalesPrice), bl.CheckString(lstMaster.ECP),
                            bl.CheckString(lstMaster.SPLPrice), bl.CheckString(lstMaster.MRP), bl.CheckString(lstMaster.ReturnPrice), lstMaster.TrackInventory, lstMaster.TrackBatch,
                            lstMaster.TrackSerial, lstMaster.TrackPDK, lstMaster.DateFormat, lstMaster.BarcodeUomID, lstMaster.BarcodePriceID, lstMaster.VendorID,
                            bl.CheckString(lstMaster.MOH), bl.CheckString(lstMaster.MOQ), lstMaster.Remarks, lstMaster.Active, lstMaster.CBy, lstMaster.LocationID
                            , lstMaster.BarcodePrint, lstMaster.Weborder, lstMaster.SaleonMRP, lstMaster.SaleonpPern, lstMaster.ECPonMRP, lstMaster.ECPonpPern,
                            lstMaster.SPLonMRP, lstMaster.SPLonpPern, lstMaster.ProdLifeTime, lstMaster.Shinecode);
                    if (DDT.Columns.Count == 1)
                    {
                        int IdentID = Convert.ToInt32(DDT.Rows[0][0].ToString());
                        bl.BL_ExecuteParamSP("uspManageProductTransactionPrice", IdentID,
                                        bl.BL_dValidation(lstMaster.PurchaseBillPrice),
                                        bl.BL_dValidation(lstMaster.PurchaseReturnPrice),
                                        bl.BL_dValidation(lstMaster.InvoicePrice),
                                        bl.BL_dValidation(lstMaster.SalesReturnPrice),
                                        bl.BL_nValidation(lstMaster.CBy));
                        int Deleted = 0;
                        foreach (clsProdLocMapping lst in lstMaster.lstProdLocMapping)
                        {
                            bl.BL_ExecuteParamSP("uspUpdateProductLocationMapping", IdentID, lst.BranchID, lst.LocationID, Deleted);
                            Deleted = 1;
                        }
                        //Success message
                        list.Add(new SaveMessage()
                        {
                            ID = IdentID.ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        //Error message
                        list.Add(new SaveMessage()
                        {
                            ID = "0",
                            MsgID = "1",
                            Message = DDT.Rows[0][0].ToString()
                        });
                    }
                    return Ok(list);
                }
            }
            catch (Exception ex)
            {
                list.Add(new SaveMessage()
                {
                    ID = "1",
                    MsgID = "1",
                    Message = ex.Message
                });
            }
            return Ok(list);
        }
        [HttpPost]
        [Route("api/productmaster/save")]
        public async Task<IHttpActionResult> SaveProduct()
        {
            List<SaveMessage> list = new List<SaveMessage>();
            try
            {
                if (!Request.Content.IsMimeMultipartContent())
                {
                    list.Add(new SaveMessage() { ID = "1", MsgID = "1", Message = "Expected multipart/form-data request." });
                    return Ok(list);
                }
                var provider = new MultipartMemoryStreamProvider();
                await Request.Content.ReadAsMultipartAsync(provider);

                ProductModel lstMaster = null;
                List<string> savedImageNames = new List<string>();

                // Folder to store uploaded product images — adjust to your structure
                string uploadFolder = HostingEnvironment.MapPath("~/Uploads/ProductImages/");
                if (!Directory.Exists(uploadFolder))
                    Directory.CreateDirectory(uploadFolder);
                List<byte[]> compressimagedata = new List<byte[]>();
                var compimgdata = new List<object>();
                foreach (var content in provider.Contents)
                {
                    var fieldName = content.Headers.ContentDisposition.Name?.Trim('"');
                    var fileName = content.Headers.ContentDisposition.FileName?.Trim('"');
                    //content.Headers
                    if (!string.IsNullOrEmpty(fileName))
                    {
                        // Read the multipart part into a stream
                        byte[] rawBytes = await content.ReadAsByteArrayAsync();
                        using (var fileStream = new MemoryStream(rawBytes))
                        {                           
                            // Compress
                            byte[] compressedBytes = bl.CompressImage(fileStream);

                            if (compressedBytes != null && compressedBytes.Length > 0)
                            {
                                compimgdata.Add(new
                                {
                                    FileName = fileName,
                                    FileSize = (compressedBytes.Length / 1024) + " kb",
                                    compressimagedata = compressedBytes
                                });
                                compressimagedata.Add(compressedBytes);
                                // CompressImage always encodes to JPEG, so force the extension to match
                                //string safeName = Guid.NewGuid().ToString("N") + ".jpg";
                                //string fullPath = Path.Combine(uploadFolder, safeName);
                                //File.WriteAllBytes(fullPath, compressedBytes);
                                //savedImageNames.Add(safeName);
                            }
                        }
                    }
                    else if (fieldName == "data")
                    {
                        // This part is the JSON payload
                        string json = await content.ReadAsStringAsync();
                        lstMaster = JsonConvert.DeserializeObject<ProductModel>(json);
                    }
                }

                if (lstMaster != null)
                {
                    string ID = !string.IsNullOrEmpty(lstMaster.ID) ? lstMaster.ID : "0";
                    DataTable DDT = bl.BL_ExecuteParamSP("uspManageProductMaster", lstMaster.Mode, ID, lstMaster.Code, lstMaster.Name, lstMaster.EAN, lstMaster.MfrID, lstMaster.BrandID, lstMaster.CategoryID,
                        bl.CheckString(lstMaster.HSNCode), bl.CheckString(lstMaster.ProductDiscPerc), lstMaster.BaseUomID, lstMaster.BaseCR, lstMaster.PurchaseUomID,
                        lstMaster.PurchaseCR, lstMaster.SalesUomID, lstMaster.SalesCR, lstMaster.ReportingUomID, lstMaster.ReportingCR,
                        bl.CheckString(lstMaster.ReportingQty), lstMaster.PurchaseTaxID,
                        lstMaster.SalesTaxID, bl.CheckString(lstMaster.PurchasePrice), bl.CheckString(lstMaster.SalesPrice), bl.CheckString(lstMaster.ECP),
                        bl.CheckString(lstMaster.SPLPrice), bl.CheckString(lstMaster.MRP), bl.CheckString(lstMaster.ReturnPrice), lstMaster.TrackInventory, lstMaster.TrackBatch,
                        lstMaster.TrackSerial, lstMaster.TrackPDK, lstMaster.DateFormat, lstMaster.BarcodeUomID, lstMaster.BarcodePriceID, lstMaster.VendorID,
                        bl.CheckString(lstMaster.MOH), bl.CheckString(lstMaster.MOQ), lstMaster.Remarks, lstMaster.Active, lstMaster.CBy, lstMaster.LocationID,
                        lstMaster.BarcodePrint, lstMaster.Weborder, lstMaster.SaleonMRP, lstMaster.SaleonpPern, lstMaster.ECPonMRP, lstMaster.ECPonpPern,
                        lstMaster.SPLonMRP, lstMaster.SPLonpPern, lstMaster.ProdLifeTime, lstMaster.Shinecode);

                    if (DDT.Columns.Count == 1)
                    {
                        int IdentID = Convert.ToInt32(DDT.Rows[0][0].ToString());

                        bl.BL_ExecuteParamSP("uspManageProductTransactionPrice", IdentID,
                                        bl.BL_dValidation(lstMaster.PurchaseBillPrice),
                                        bl.BL_dValidation(lstMaster.PurchaseReturnPrice),
                                        bl.BL_dValidation(lstMaster.InvoicePrice),
                                        bl.BL_dValidation(lstMaster.SalesReturnPrice),
                                        bl.BL_nValidation(lstMaster.CBy));

                        int Deleted = 0;
                        foreach (clsProdLocMapping lst in lstMaster.lstProdLocMapping)
                        {
                            bl.BL_ExecuteParamSP("uspUpdateProductLocationMapping", IdentID, lst.BranchID, lst.LocationID, Deleted);
                            Deleted = 1;
                        }
                        string[] removeitemimages = lstMaster.RemoveProducts.Split(',');
                        foreach (string rmvfilename in removeitemimages)
                        {
                            if (!string.IsNullOrEmpty(rmvfilename))
                                bl.BL_ExecuteParamSP("uspSaveImagedata", 2, 1, "Product", IdentID, null, rmvfilename, null);
                        }
                        // Save image file names against the product — adjust SP/table to your schema
                        foreach (object imgdata in compimgdata)
                        {
                            var type = imgdata.GetType();
                            string fileName = type.GetProperty("FileName")?.GetValue(imgdata)?.ToString();
                            string fileSize = type.GetProperty("FileSize")?.GetValue(imgdata)?.ToString();
                            byte[] imageData = (byte[])type.GetProperty("compressimagedata")?.GetValue(imgdata);

                            //bl.BL_ExecuteParamSP("uspAddProductImage", IdentID, imgName);
                            bl.BL_ExecuteParamSP("uspSaveImagedata", 1,1, "Product", IdentID, imageData, fileName, fileSize);
                        }

                        list.Add(new SaveMessage()
                        {
                            ID = IdentID.ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        list.Add(new SaveMessage()
                        {
                            ID = "0",
                            MsgID = "1",
                            Message = DDT.Rows[0][0].ToString()
                        });
                    }
                }
                else
                {
                    list.Add(new SaveMessage() { ID = "1", MsgID = "1", Message = "Invalid product data received." });
                }

                return Ok(list);
            }
            catch (Exception ex)
            {
                list.Add(new SaveMessage()
                {
                    ID = "1",
                    MsgID = "1",
                    Message = ex.Message
                });
            }
            return Ok(list);
        }
       
        [HttpGet]
        [Route("api/productpricechange/get")]
        public IHttpActionResult GetProductPRICEData(string Mode, string BranchID, string ProdID)
        {
            try
            {
                if (Mode == "1")
                {
                    DataTable DDT = bl.BL_ExecuteParamSP("uspManageProductPricechangedata", Mode);
                    List<CustomerVendorModel> list = new List<CustomerVendorModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new CustomerVendorModel
                        {
                            FType = DDT.Rows[i][0].ToString(),
                            Form = DDT.Rows[i][1].ToString(),
                            ID = DDT.Rows[i][2].ToString(),
                            Code = DDT.Rows[i][4].ToString(),
                            Name = DDT.Rows[i][3].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "2")
                {
                    DataTable DDT = bl.BL_ExecuteParamSP("uspManageProductPricechangedata", Mode, BranchID);
                    List<SingleMasterModel> list = new List<SingleMasterModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        list.Add(new SingleMasterModel
                        {
                            ID = DDT.Rows[i][0].ToString(),
                            Name = DDT.Rows[i][2].ToString(),
                            Value = DDT.Rows[i][1].ToString(),
                        });
                    }
                    return Ok(list);
                }
                if (Mode == "3")
                {
                    DataTable DDT = bl.BL_ExecuteParamSP("uspManageProductPricechangedata", Mode, BranchID, ProdID);
                    List<ProductModel> list = new List<ProductModel>();
                    for (int i = 0; i < DDT.Rows.Count; i++)
                    {
                        List<ProdPricechangedata> listProdPrice = new List<ProdPricechangedata>();
                        DataTable dtBatch = bl.BL_ExecuteParamSP("uspManageProductPricechangedata", 4, BranchID, ProdID);
                        for (int j = 0; j < dtBatch.Rows.Count; j++)
                        {
                            string pkd = !string.IsNullOrEmpty(dtBatch.Rows[j]["PKDDate"].ToString()) ? Convert.ToDateTime(dtBatch.Rows[j]["PKDDate"].ToString()).ToString("yyyy-MM-dd") : null;
                            string exp = !string.IsNullOrEmpty(dtBatch.Rows[j]["ExpiryDate"].ToString()) ? Convert.ToDateTime(dtBatch.Rows[j]["ExpiryDate"].ToString()).ToString("yyyy-MM-dd") : null;
                            listProdPrice.Add(new ProdPricechangedata
                            {
                                InventoryID = dtBatch.Rows[j]["InventoryId"].ToString(),
                                TransDate = dtBatch.Rows[j]["PVDate"].ToString(),
                                ECP = dtBatch.Rows[j]["ECP"].ToString(),
                                MRP = dtBatch.Rows[j]["MRPONPrice"].ToString(),
                                MRPExcl = dtBatch.Rows[j]["MRP"].ToString(),
                                PKD = pkd,
                                Expiry = exp,
                                BatchNo = dtBatch.Rows[j]["BatchNumber"].ToString(),
                                PurchasePrice = dtBatch.Rows[j]["PurchasePrice"].ToString(),
                                ReturnPrice = dtBatch.Rows[j]["ReturnPrice"].ToString(),
                                SPLPrice = dtBatch.Rows[j]["SPLPrice"].ToString(),
                                SalePrice = dtBatch.Rows[j]["SalesPrice"].ToString(),
                                ActualQty = dtBatch.Rows[j]["ActualQty"].ToString(),
                            });
                        }
                        string SalePerc = Convert.ToBoolean(DDT.Rows[i]["SaleonMRP"].ToString()) ? Convert.ToString(bl.BL_dValidation(DDT.Rows[i]["SaleonpPern"].ToString()) * -1) :
                            Convert.ToString(bl.BL_dValidation(DDT.Rows[i]["SaleonpPern"].ToString()));
                        string ECPPerc = Convert.ToBoolean(DDT.Rows[i]["ECPonMRP"].ToString()) ? Convert.ToString(bl.BL_dValidation(DDT.Rows[i]["ECPonpPern"].ToString()) * -1) :
                            Convert.ToString(bl.BL_dValidation(DDT.Rows[i]["ECPonpPern"].ToString()));
                        string SPLPerc = Convert.ToBoolean(DDT.Rows[i]["SPLonMRP"].ToString()) ? Convert.ToString(bl.BL_dValidation(DDT.Rows[i]["SPLonpPern"].ToString()) * -1) :
                            Convert.ToString(bl.BL_dValidation(DDT.Rows[i]["SPLonpPern"].ToString()));
                        list.Add(new ProductModel
                        {
                            ID = DDT.Rows[i]["ID"].ToString(),
                            Code = DDT.Rows[i]["Code"].ToString(),
                            Name = DDT.Rows[i]["Name"].ToString(),
                            BaseUomID = DDT.Rows[i]["BaseUomID"].ToString(),
                            BaseCR = DDT.Rows[i]["BaseCR"].ToString(),
                            BaseUOMName = DDT.Rows[i]["BaseUOMName"].ToString(),
                            SalesTaxID = DDT.Rows[i]["TaxID"].ToString(),
                            PurchaseTaxID = DDT.Rows[i]["PurchaseTaxID"].ToString(),
                            GSTPern = DDT.Rows[i]["GST"].ToString(),
                            TaxName = DDT.Rows[i]["TaxName"].ToString(),
                            TrackInventory = DDT.Rows[i]["TrackInventory"].ToString(),
                            TrackBatch = DDT.Rows[i]["TrackBatch"].ToString(),
                            TrackSerial = DDT.Rows[i]["TrackSerial"].ToString(),
                            TrackPDK = DDT.Rows[i]["TrackPDK"].ToString(),
                            DateFormat = DDT.Rows[i]["DateFormat"].ToString(),
                            LocationID = DDT.Rows[i]["LocationName"].ToString(),
                            SaleonpPern = SalePerc,
                            ECPonpPern = ECPPerc,
                            SPLonpPern = SPLPerc,
                            lstProdPrice = listProdPrice
                        });
                    }
                    return Ok(list);
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CustomerVendorProduct", "productpricechange/get", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/productpricechange/save")]
        public IHttpActionResult SaveProductprice(ProductModel lstMaster)
        {
            List<SaveMessage> list = new List<SaveMessage>();
            try
            {
                if (lstMaster != null)
                {
                    string ID = !string.IsNullOrEmpty(lstMaster.ID) ? lstMaster.ID : "0";
                    DataTable DDT = new DataTable();
                    foreach (ProdPricechangedata items in lstMaster.lstProdPrice)
                    {
                        string exp = !string.IsNullOrEmpty(items.Expiry) ? Convert.ToDateTime(items.Expiry).ToString("yyyy-MM-dd") : null;
                        string pkd = !string.IsNullOrEmpty(items.PKD) ? Convert.ToDateTime(items.PKD).ToString("yyyy-MM-dd") : null;
                        DDT = bl.BL_ExecuteParamSP("uspManageProductPricechangedata", 5, lstMaster.BranchID, ID, items.InventoryID, lstMaster.TrackInventory,
                            lstMaster.GSTPern, items.BatchNo, pkd, exp, items.PurchasePrice, items.SalePrice, items.ECP, items.SPLPrice,
                            items.MRP, items.ReturnPrice, lstMaster.CBy);
                    }

                    if (DDT.Columns.Count == 1)
                    {
                        int IdentID = Convert.ToInt32(DDT.Rows[0][0].ToString());
                        //Success message
                        list.Add(new SaveMessage()
                        {
                            ID = IdentID.ToString(),
                            MsgID = "0",
                            Message = "Saved Successfully"
                        });
                    }
                    else
                    {
                        //Error message
                        list.Add(new SaveMessage()
                        {
                            ID = "0",
                            MsgID = "1",
                            //Message = DDT.Rows[0][0].ToString()
                        });
                    }
                    return Ok(list);
                }
            }
            catch (Exception ex)
            {
                list.Add(new SaveMessage()
                {
                    ID = "1",
                    MsgID = "1",
                    Message = ex.Message
                });
            }
            return Ok(list);
        }
        [HttpGet]
        [Route("api/customermaster/validatestatutory")]
        public IHttpActionResult validatestatutory(string FormName, string FieldName, string Value,string ID = "0")
        {
            try
            {
                DataTable DDT = bl.BL_ExecuteParamSP("uspVerifyStatutory", FormName, FieldName, Value, ID);
                string jsonparty = JsonConvert.SerializeObject(DDT);
                return Ok(jsonparty);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CustomerVendorProduct", "customermaster/validatestatutory", ex.Message);
            }
            return Ok();
        }
    }
}
