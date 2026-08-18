using DocumentFormat.OpenXml.Drawing.Diagrams;
using Newtonsoft.Json;
using SampWebApi.BuisnessLayer;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Cryptography.X509Certificates;
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
        [HttpGet]
        [Route("api/validatedocument")]
        public IHttpActionResult ValidateDocument(int ActionType,int TransID, int ID,int Status)
        {
            try
            {
                bl.bl_Transaction(1);
                DataTable dtMTdetail = bl.bl_ManageTrans("uspValidateEditCanceldocument", ActionType, TransID, ID, Status);
                var fileList = new List<object>();
                if (dtMTdetail.Rows.Count > 0)
                {
                    bl.bl_Transaction(2);
                    fileList.Add(new
                    {                        
                        MsgID = 1,
                        Message = dtMTdetail.Rows[0][0].ToString(),                        
                    });
                }
                else
                {
                    bl.bl_Transaction(3);
                    fileList.Add(new
                    {
                        MsgID = 0,
                        Message = "Valid document",
                    });
                }
                return Ok(fileList);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CommonController", "Edit/Cancel Validate Document", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/validatedraftdocument")]
        public IHttpActionResult ValidateDraftDocument(int ActionType, int TransID, int ID, int Status,int UserID = 0)
        {
            try
            {
                bl.bl_Transaction(1);
                DataTable dtMTdetail = bl.bl_ManageTrans("uspValidateDraftData", ActionType, TransID, ID, Status, UserID);
                var fileList = new List<object>();
                if (dtMTdetail.Rows.Count == 0)
                {
                    bl.bl_Transaction(2);
                    fileList.Add(new
                    {
                        MsgID = ActionType == 1 ? "1" : "0",
                        Message = ActionType == 1 ? "Valid document" : "Cancelled Successfully",
                    });
                }
                else
                {
                    bl.bl_Transaction(3);
                    fileList.Add(new
                    {                        
                        MsgID = 2,
                        Message = dtMTdetail.Rows[0][0].ToString(),
                    });
                }
                return Ok(fileList);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CommonController", "Validate Draft Document", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/validateinvoicetransferdocument")]
        public IHttpActionResult validateinvoicetransferdocument(int TransID,int ID,  string Shinecode, int Status)
        {
            try
            {
                bl.bl_Transaction_SC(1);
                DataTable dtMTdetail = bl.bl_ManageTrans_SC("uspgetMasterdata", 4, TransID, ID, Shinecode, Status);
                var fileList = new List<object>();
                if (dtMTdetail.Rows.Count == 0)
                {
                    DataTable dtSCcheck = bl.bl_ManageTrans_SC("uspgetMasterdata", 5, TransID, ID, Shinecode);
                    bl.bl_Transaction_SC(2);
                    fileList.Add(new
                    {
                        MsgID = "0",
                        Message = "Cancelled Successfully",
                    });
                }
                else
                {
                    bl.bl_Transaction_SC(3);
                    fileList.Add(new
                    {
                        MsgID = 2,
                        Message = dtMTdetail.Rows[0][0].ToString(),
                    });
                }
                return Ok(fileList);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CommonController", "validate invoicetransfer", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/logfiles")]
        public IHttpActionResult logfiles()
        {
            try
            {
                string strFol = AppDomain.CurrentDomain.BaseDirectory + "\\Log File Errors\\";
                var files = new DirectoryInfo(strFol)
                                   .GetFiles()
                                   .OrderByDescending(f => f.CreationTime);
                var fileList = new List<object>();
                foreach (FileInfo fi in files)
                {
                    string fullPath = fi.FullName;          // Full path
                    string fileName = fi.Name;              // File name with extension
                    string extension = fi.Extension;        // Extension (.txt, .xls etc.)
                    string CreateTime = fi.CreationTime.ToString("dd/MMM/yyyy hh:mm:ss tt");
                    long sizeInBytes = fi.Length;

                    string fileSize;
                    if (sizeInBytes < 1024 * 1024) // less than 1 MB
                        fileSize = $"{(sizeInBytes / 1024.0):N2} KB";
                    else
                        fileSize = $"{(sizeInBytes / 1024.0 / 1024.0):N2} MB";

                    fileList.Add(new
                    {
                        //fullPath = fullPath,
                        fileName = fileName,
                        extension = extension,
                        fileSize = fileSize,
                        CreateTime = CreateTime
                    });
                }
                return Ok(fileList);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Common", "logfiles", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/logfiledata")]
        public IHttpActionResult logfiledata(string FileName)
        {
            try
            {
                string strFol = AppDomain.CurrentDomain.BaseDirectory + "\\Log File Errors\\"+ FileName;
                FileInfo logFileInfo = new FileInfo(strFol);
                string JsonData = ""; var filedata = new List<object>();
                if (logFileInfo.Exists)
                {
                    string objReader = File.ReadAllText(strFol);
                    if (!string.IsNullOrEmpty(objReader))
                    {
                        JsonData += "[" + objReader.Remove(objReader.Length - 3,1) + "]";
                        filedata.Add(new
                        {
                            ResponseID = 1,
                            ResponseMessage = "File Data fetched",
                            FileData = JsonData
                        });
                    }
                    else
                    {
                        filedata.Add(new
                        {
                            ResponseID = 2,
                            ResponseMessage = "No Data Found",
                        });
                    }
                }
                else//file not exists
                {
                    filedata.Add(new
                    {
                        ResponseID = 3,
                        ResponseMessage = "File Not Found",
                    });
                }
                return Ok(filedata);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Common", "logfiledata", ex.Message);
            }
            return Ok();
        }
        [HttpGet]
        [Route("api/masterlist")]
        public IHttpActionResult MasterFielddata(string FormName, string SubField,string Value)
        {
            try
            {
                DataTable dtMSTdetail = bl.BL_ExecuteParamSP("uspgetMasterlists", FormName, SubField, Value);
                return Ok(dtMSTdetail);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("CommonController", "masterlist", ex.Message);
            }
            return Ok();
        }
    }
}
