using DocumentFormat.OpenXml.Drawing.Diagrams;
using DocumentFormat.OpenXml.Drawing.Spreadsheet;
using DocumentFormat.OpenXml.Vml;
using Ionic.Zip;
using SampWebApi.BuisnessLayer;
using SampWebApi.Models;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading;
using System.Web;
using System.Web.Http;
using System.Web.Http.Cors;

namespace SampWebApi.Controllers
{
    //[EnableCors(origins: "*", headers: "*", methods: "*")]
    public class UploadFilesController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        [System.Web.Http.HttpPost]
        [System.Web.Http.Route("api/myuploads")]
        public IHttpActionResult myuploadsFiles()
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
                    DataTable dtBakPath = bl.BL_ExecuteSqlQuery("select BackupPath from tblCompanyRegistration");
                    string path = dtBakPath.Rows[0]["BackupPath"].ToString();
                    string strFilePath = path + "\\myUploadFiles\\";
                    string UserID = HttpContext.Current.Request.Files.AllKeys[0].ToString();
                    for (int i = 1; i < HttpContext.Current.Request.Files.Count; i++)
                    {
                        string fileName = HttpContext.Current.Request.Files[i].FileName;
                        string fileContentType = HttpContext.Current.Request.Files[i].ContentType;
                        //strFilePath = AppDomain.CurrentDomain.BaseDirectory + "Upload Files\\";
                        if (!Directory.Exists(strFilePath))
                        {
                            Directory.CreateDirectory(strFilePath);
                        }
                        HttpContext.Current.Request.Files[1].SaveAs(strFilePath + fileName);
                    }
                    MTM.Add(new ImportResults()
                    {
                        ID = "0",
                        Msg = "File Uploaded Successfully.",
                    });
                    return Ok(MTM);
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

        [HttpGet]
        [Route("api/backupfile")]
        public IHttpActionResult backupfile()
        {
            List<SaveMessage> list = new List<SaveMessage>();
            try
            {
                string MgID = "1", Msg = "", bakfullpath = "", filename = "";
                DataTable dt = bl.BL_ExecuteParamSP("uspAutoBackUp", 1);
                if (dt.Rows.Count > 0)
                {
                    if (dt.Columns.Count != 3)
                    {
                        bakfullpath = dt.Rows[0][1].ToString();
                        filename = dt.Rows[0][0].ToString();
                        string tempsource = dt.Rows[0][1].ToString();
                        MgID = "0";
                        Msg = "Backup Successfully";
                        //tempsource = @"D:\Host\NewWebShineAPI\BACKUPFILES\BK_DEV001_APR2024_20250925112574553.bak";
                        if (File.Exists(tempsource))
                        {
                            string sourceFile = tempsource;
                            string Dest = tempsource.Replace(".bak", ".zip");
                            string zipPath = Dest;// @"D:\2025\shineweb_ui\shaineweb.ui\BAK\BK_GKBS01_APR2024_20250503153834267.zip";                            
                            using (Ionic.Zip.ZipFile zfp = new Ionic.Zip.ZipFile())
                            {
                                zfp.UseZip64WhenSaving = Zip64Option.AsNecessary; // ✅ Allow large files
                                FileInfo fi = new FileInfo(sourceFile);
                                zfp.AddFile(sourceFile);
                                DirectoryInfo dff = new DirectoryInfo(sourceFile);
                                zfp.Save(zipPath);

                                if (File.Exists(sourceFile))
                                {
                                    //bl.BL_WriteErrorMsginLog("Source File", "File Path", sourceFile);
                                    File.Delete(sourceFile);
                                }
                            }                            
                            

                        }
                        else
                        {
                            Msg = "Backup File does not exists for zip";
                        }
                    }
                    else
                    {
                        Msg = "Backup failed. " + dt.Rows[0][0].ToString();
                    }
                }
                list.Add(new SaveMessage()
                {
                    MsgID = MgID,
                    Message = Msg,
                    FileName = filename,
                    FilePath = bakfullpath
                });
                return Ok(list);
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Backup", "Backup", ex.Message);
            }
            list.Add(new SaveMessage()
            {
                MsgID = "1",
                Message = "Back up completed. But zip file failed"
            });
            return Ok(list);
        }
        [HttpGet]
        [Route("api/downloadbakfile")]
        public HttpResponseMessage DownloadFile(string FPath, string FName)
        {
            DataTable dt = new DataTable();
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
        [HttpGet]
        [Route("api/deletemyuploadfile")]
        public IHttpActionResult deletemyuploadfile(string FPath, string FName)
        {
            var fileList = new List<object>();

            try
            {
                string MsgID = "0";
                string Message = "";
                if (File.Exists(FPath))
                {
                    File.Delete(FPath);
                    MsgID = "1";
                    Message = "File Deleted successfully";
                }
                else
                {
                    MsgID = "2";
                    Message = "File Not Found";
                }
                fileList.Add(new
                {
                    MsgID = MsgID,
                    Message = Message
                });
            }
            catch (Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Delete File", "deletemyuploadfile", ex.Message);
            }
            return Ok(fileList);
        }        
        [HttpGet]
        [Route("api/listbackupfiles")]
        public IHttpActionResult listFiles(string FileType)
        {
            DataTable dtBakPath = bl.BL_ExecuteSqlQuery("select BackupPath from tblCompanyRegistration");
            string path = dtBakPath.Rows[0]["BackupPath"].ToString();
            var fileList = new List<object>();
            string StoreLocation = "";
            if(FileType == "1")
                StoreLocation = path + "\\BACKUPFILES\\";
            else if(FileType == "2")
                StoreLocation = path + "\\myUploadFiles\\";
            if (Directory.Exists(StoreLocation))
            {
                var files = new DirectoryInfo(StoreLocation)
                               .GetFiles()
                               .OrderByDescending(f => f.CreationTime);  // sort by created date (newest first)

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
                        fullPath = fullPath,
                        fileName = fileName,
                        extension = extension,
                        fileSize = fileSize,
                        CreateTime = CreateTime
                    });
                }
            }
            return Ok(fileList);
        }

        /*
         * api/olduploadfile/upload
         * receieve a zip file, unzip here and move to another place
         */
        [Route("api/olduploadfile/upload")]
        [HttpPost]
        public IHttpActionResult FileUpload()
        {
            try
            {
                string path = @"D:\Host\NewWebShineSupport\ZIP\";
                string TempPath = @"D:\Host\NewWebShineSupport\Temp\ZIP\";
                //gksapp.in location
                path = @"D:\Program Files (x86)\Host\New folder (2)\NewWebShine\";
                TempPath = @"D:\Program Files (x86)\Host\New folder (2)\uploadtemp\";
                //202 location
                //path = @"D:\Host\NewWebShine\";
                //TempPath = @"D:\Program Files (x86)\Host\New folder (2)\uploadtemp\";
                //from config
                string tid = HttpContext.Current.Request.Files.AllKeys[0].ToString();
                string PathKey = tid == "1" ? "APIPath" : tid == "2" ? "UIPath" : "SourcePath";
                path = ConfigurationManager.AppSettings[PathKey].ToString();
                TempPath = ConfigurationManager.AppSettings["temppath"].ToString();
                var file = HttpContext.Current.Request.Files.Count > 1 ? HttpContext.Current.Request.Files[0] : null;
                if (file != null && file.ContentLength > 1)
                {
                    string StoreLocation = path;
                    string TempStoreLocation = TempPath;
                    if (!Directory.Exists(TempStoreLocation))
                    {
                        Directory.CreateDirectory(TempStoreLocation);
                    }
                    var fileName = System.IO.Path.GetFileName(file.FileName);
                    var filefolder = fileName.Remove(fileName.Length - 4);
                    file.SaveAs(TempStoreLocation + fileName);
                    //if (Directory.Exists(StoreLocation))
                    //{
                    //    Directory.Delete(StoreLocation, true);
                    //    Directory.CreateDirectory(StoreLocation);
                    //}
                    System.IO.Compression.ZipFile.ExtractToDirectory(TempStoreLocation + fileName, TempStoreLocation, Encoding.UTF8);
                    string pt = TempStoreLocation + filefolder + @"\";
                    //String[] files = Directory.GetFiles(pt);
                    //String[] directories = Directory.GetDirectories(pt);
                    //DirectoryInfo DF = new DirectoryInfo(TempStoreLocation);//+filefolder

                    //if (!Directory.Exists(StoreLocation))
                    //{
                    //    //Directory.CreateDirectory(StoreLocation);
                    //}
                    moveDirectory(pt, StoreLocation);
                    //DF.MoveTo(StoreLocation);
                    //FileInfo[] Dfiles = DF.GetFiles();
                    if (Directory.Exists(TempStoreLocation))
                    {
                        Directory.Delete(TempStoreLocation, true);
                    }
                    return Ok("File uploaded");
                }
                else
                {
                    return InternalServerError();
                }
            }
            catch (Exception ex)
            {
                return InternalServerError(ex);
            }
        }
        private void moveDirectory(string fuente, string destino)
        {
            if (!System.IO.Directory.Exists(destino))
            {
                System.IO.Directory.CreateDirectory(destino);
            }
            String[] files = Directory.GetFiles(fuente);
            String[] directories = Directory.GetDirectories(fuente);
            foreach (string s in files)
            {
                FileInfo fs = new FileInfo(s);
                string ext = fs.Extension;
                string fnm = fs.Name;
                if (fnm == "Web.config")
                {
                    
                }
                else
                {
                    System.IO.File.Copy(s, System.IO.Path.Combine(destino, System.IO.Path.GetFileName(s)), true);
                }
            }
            foreach (string d in directories)
            {
                moveDirectory(System.IO.Path.Combine(fuente, System.IO.Path.GetFileName(d)), System.IO.Path.Combine(destino, System.IO.Path.GetFileName(d)));
            }

        }
    }
}
