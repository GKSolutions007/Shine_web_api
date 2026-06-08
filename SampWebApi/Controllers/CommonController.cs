using DocumentFormat.OpenXml.Drawing.Diagrams;
using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using System.Windows.Forms;

namespace SampWebApi.Controllers
{
    [CookieAuthorize]
    public class CommonController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [HttpGet]
        [Route("api/documentseries/docid")]
        public IHttpActionResult GetDocseriesid(string TransID, string BranchID, string DocDate)
        {
            try
            {
                var DocInfo = new List<object>();
                DataTable DDT = bl.BL_ExecuteParamSP("uspgetDocumentID", DocDate, BranchID, TransID);
                if (DDT.Rows.Count > 0)
                {
                    DocInfo.Add(new
                    {
                        MsgID = "0",
                        Message = "Document ID fetched",
                        DocValue = DDT.Rows[0]["DocValue"].ToString(),
                        Prefix = DDT.Rows[0]["Prefix"].ToString(),
                        DocID = DDT.Rows[0]["DocID"].ToString()
                    });
                    string val = JsonConvert.SerializeObject(DDT);
                    return Ok(DocInfo);
                }
                DocInfo.Add(new
                {
                    MsgID = "1",
                    Message = "Document ID not found"
                });
                return Ok(DocInfo);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CommonController", "documentseries/docid", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/mrpontax")]
        public IHttpActionResult ReturnGrossorMRPTaxAmt(int GrossorTax, int TaxID, int TaxTypeID, decimal Price, decimal MRP)
        {
            try
            {
                decimal dTaxAmt = 0;
                var TaxReturn = new List<object>();
                DataTable dtMTdetail = bl.BL_ExecuteParamSP("uspGetTaxCumulative", TaxID, TaxTypeID, 1);
                decimal dApponMRPCum = dtMTdetail.Select("AppOn = -1")
              .Select(r => Convert.ToDecimal(r["CumulativeTax"]))
              .DefaultIfEmpty(0)
              .Sum();
                decimal dApponPriceCum = dtMTdetail.Select("AppOn <> -1")
                  .Select(r => Convert.ToDecimal(r["CumulativeTax"]))
                  .DefaultIfEmpty(0)
                  .Sum();
                decimal dGrossAmt = 0;
                if (GrossorTax == 1)
                {
                    dGrossAmt = dApponMRPCum > 0 ? (MRP / (1 + (dApponMRPCum / 100))) : (Price / (1 + (dApponMRPCum / 100)));
                }
                for (int i = 0; i < dtMTdetail.Rows.Count; i++)
                {
                    int nAppon = bl.BL_nValidation(dtMTdetail.Rows[i]["AppOn"].ToString());
                    decimal dCumTax = bl.BL_dValidation(dtMTdetail.Rows[i]["CumulativeTax"].ToString());
                    if (nAppon == -1)
                    {
                        decimal dPrice = (MRP / (1 + (dApponMRPCum / 100)));
                        dTaxAmt += (dPrice * dCumTax) / 100;
                    }
                    else
                    {
                        //decimal dPrice = (Price / (1 + (dApponPriceCum / 100)));
                        dTaxAmt += (Price * dCumTax) / 100;
                    }
                }
                TaxReturn.Add(new
                {
                    MRP = MRP,
                    MRPTaxPern = dApponMRPCum,
                    MRPTaxAmt = dTaxAmt,
                    TaxonGross = dGrossAmt
                });
                return Ok(TaxReturn);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CommonController", "mrpontax", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/taxdetails")]
        public IHttpActionResult TaxCumulative(int TaxID, int TaxTypeID)
        {
            try
            {
                DataTable dtMTdetail = bl.BL_ExecuteParamSP("uspGetTaxCumulative", TaxID, TaxTypeID, 1);
                return Ok(dtMTdetail);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CommonController", "taxdetails", ex.Message);
            }
            return Ok();
        }
    }
}
