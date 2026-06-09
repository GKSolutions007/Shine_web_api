using Microsoft.Ajax.Utilities;
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
using System.Web.Http;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class PartyProductAnalticReportController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/partyanalticalreport/getparty")]
        public IHttpActionResult GetData(int PartyType)
        {
            try
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspPartyReportData", 1, PartyType);
                string jsonparty = JsonConvert.SerializeObject(DDT);
                return Ok(jsonparty);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("PartyProductAnalyticalReport", "partyanalticalreport/getparty", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/partyanalticalreport/getdocuments")]
        public IHttpActionResult GetDocData(string PartyType, string AccountID)
        {
            try
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspPartyReportData", 3, AccountID);
                string jsonparty = JsonConvert.SerializeObject(DDT);
                DDT = bl.BL_ExecuteParamSP("uspPartyReportData", 2, AccountID, PartyType);
                string jsonpartyinfo = JsonConvert.SerializeObject(DDT);
                var PartyData = new
                {
                    Documents = jsonparty,
                    PartyInfo = jsonpartyinfo,
                };
                return Ok(PartyData);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("PartyProductAnalyticalReport", "partyanalticalreport/getdocuments", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/productanalticalreport/getproduct")]
        public IHttpActionResult GetproductData()
        {
            try
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspProductReportData", 1);
                string jsonparty = JsonConvert.SerializeObject(DDT);
                return Ok(jsonparty);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("PartyProductAnalyticalReport", "productanalticalreport/getproduct", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/productanalticalreport/getdocuments")]
        public IHttpActionResult GetProdDocData( string ProductID)
        {
            try
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspProductReportData", 3, ProductID);
                string jsonparty = JsonConvert.SerializeObject(DDT);
                DDT = bl.BL_ExecuteParamSP("uspProductReportData", 2, ProductID);
                string jsonpartyinfo = JsonConvert.SerializeObject(DDT);
                var ProductData = new
                {
                    Documents = jsonparty,
                    ProductInfo = jsonpartyinfo,
                };
                return Ok(ProductData);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("PartyProductAnalyticalReport", "productanalticalreport/getdocuments", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/invoiceanalticalreport/getinvoices")]
        public IHttpActionResult GetinvoiceData()
        {
            try
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspInvoiceTrackReportData", 1);
                string jsonparty = JsonConvert.SerializeObject(DDT);
                return Ok(jsonparty);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("PartyProductAnalyticalReport", "invoiceanalticalreport/getinvoices", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/invoiceanalticalreport/getdocuments")]
        public IHttpActionResult GetInvDocData(string DocValue)
        {
            try
            {
                DataTable DDT = new DataTable();
                DDT = bl.BL_ExecuteParamSP("uspInvoiceTrackReportData", 3, DocValue);
                string jsonAssignInv = JsonConvert.SerializeObject(DDT);
                DDT = bl.BL_ExecuteParamSP("uspInvoiceTrackReportData", 2, DocValue);
                string jsonpartyinfo = JsonConvert.SerializeObject(DDT);
                DDT = bl.BL_ExecuteParamSP("uspGetSetAssignInvoices", 6, DDT.Rows[0][0].ToString(), 15);
                string invjson = JsonConvert.SerializeObject(DDT);
                var InvoiceData = new
                {
                    AssignInvData = jsonAssignInv,
                    InvoiceInfo = jsonpartyinfo,
                    InvoiceCollection = invjson
                };
                return Ok(InvoiceData);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("PartyProductAnalyticalReport", "invoiceanalticalreport/getdocuments", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/customeros/initiatedata")]
        public IHttpActionResult COSinitiatedata()
        {
            try
            {
                DataSet DDT = bl.BL_ExecuteParamSPDataset("uspMobileCustomerOS", 1);
                string invjson = JsonConvert.SerializeObject(DDT);
                return Ok(invjson);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("PartyProductAnalyticalReport", "customeros/initiatedata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/customeros/generatedata")]
        public IHttpActionResult COSgeneratedata(int Mode, string BeatID, string SalesmanID, string Party, string Period, string CustomerType, string Rating)
        {
            try
            {
                if (Mode == 2)
                {
                    DataTable dtResult = bl.BL_ExecuteParamSP("uspMobileCustomerOS", Mode, BeatID, SalesmanID, Party, Period, CustomerType, Rating);
                    string invjson = JsonConvert.SerializeObject(dtResult);
                    return Ok(invjson);
                }
                else if (Mode == 3)
                {
                    DataSet DDT = bl.BL_ExecuteParamSPDataset("uspMobileCustomerOS", Mode, BeatID);
                    string invjson = JsonConvert.SerializeObject(DDT);
                    return Ok(invjson);
                }
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("PartyProductAnalyticalReport", "customeros/generatedata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/monthwisesalesanaltic/filterdata")]
        public IHttpActionResult mwsfilterdata(string Mode,string FilterID)
        {
            try
            {
                DataSet DDT = bl.BL_ExecuteParamSPDataset("uspMonthwisesalesAnalticsReport", Mode, FilterID);
                return Ok(DDT);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("PartyProductAnalyticalReport", "monthwisesalesanaltic/filterdata", ex.Message);
            }
            return Ok();
        }
        [HttpPost]
        [Route("api/monthwisesalesanaltic/generatedata")]
        public IHttpActionResult mwsgeneratedata(MSWAfilters reportfilter)
        {
            try
            {
                DataSet DDT = bl.BL_ExecuteParamSPDataset("uspMonthwisesalesAnalticsReport", 3, reportfilter.TransactionType,
                    reportfilter.PartyFilterTypeID, reportfilter.SelectPartyfilterIDs, reportfilter.ProductFilterTypeID,
                    reportfilter.SelectProductfilterIDs, reportfilter.ValueTypeID, reportfilter.FromDate, reportfilter.ToDate);
                return Ok(DDT);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("PartyProductAnalyticalReport", "monthwisesalesanaltic/generatedata", ex.Message);
            }
            return Ok();
        }
    }
    public class MSWAfilters{
        public int TransactionType { get; set; }
        public string PartyFilterTypeID { get; set; }
        public string SelectPartyfilterIDs { get; set; }
        public string ProductFilterTypeID { get; set; }
        public string SelectProductfilterIDs { get; set; }
        public string ValueTypeID { get; set; }
        public string FromDate { get; set; }
        public string ToDate { get; set; }
    }
}
