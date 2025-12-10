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
        public IHttpActionResult GetData()
        {
            DataTable DDT = new DataTable();
            DDT = bl.BL_ExecuteParamSP("uspPartyReportData", 1);
            string jsonparty = JsonConvert.SerializeObject(DDT);
            return Ok(jsonparty);
        }
        [HttpGet]
        [Route("api/partyanalticalreport/getdocuments")]
        public IHttpActionResult GetDocData(string PartyType, string AccountID)
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
        [HttpGet]
        [Route("api/productanalticalreport/getproduct")]
        public IHttpActionResult GetproductData()
        {
            DataTable DDT = new DataTable();
            DDT = bl.BL_ExecuteParamSP("uspProductReportData", 1);
            string jsonparty = JsonConvert.SerializeObject(DDT);
            return Ok(jsonparty);
        }
        [HttpGet]
        [Route("api/productanalticalreport/getdocuments")]
        public IHttpActionResult GetProdDocData( string ProductID)
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
        [HttpGet]
        [Route("api/invoiceanalticalreport/getinvoices")]
        public IHttpActionResult GetinvoiceData()
        {
            DataTable DDT = new DataTable();
            DDT = bl.BL_ExecuteParamSP("uspInvoiceTrackReportData", 1);
            string jsonparty = JsonConvert.SerializeObject(DDT);
            return Ok(jsonparty);
        }
        [HttpGet]
        [Route("api/invoiceanalticalreport/getdocuments")]
        public IHttpActionResult GetInvDocData(string DocValue)
        {
            DataTable DDT = new DataTable();
            DDT = bl.BL_ExecuteParamSP("uspInvoiceTrackReportData", 3, DocValue);
            string jsonAssignInv = JsonConvert.SerializeObject(DDT);
            DDT = bl.BL_ExecuteParamSP("uspInvoiceTrackReportData", 2, DocValue);
            string jsonpartyinfo = JsonConvert.SerializeObject(DDT);
            DDT = bl.BL_ExecuteParamSP("uspGetSetAssignInvoices", 6, DDT.Rows[0][0].ToString());
            string invjson = JsonConvert.SerializeObject(DDT);
            var InvoiceData = new
            {
                AssignInvData = jsonAssignInv,
                InvoiceInfo = jsonpartyinfo,
                InvoiceCollection = invjson
            };
            return Ok(InvoiceData);
        }
    }
}
