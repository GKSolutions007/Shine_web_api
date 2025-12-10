using BuinessLayer;
using SampWebApi.BuisnessLayer;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Drawing;
using System.Drawing.Printing;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Mail;
using System.Printing;
using System.Runtime.Remoting.Messaging;
using System.Text;
using System.Web;
using System.Windows.Forms;
using Shinewebprint;
using Spire.Pdf;
using SampWebApi.DALHelper;
using Zen.Barcode;
using System.Drawing.Imaging;
using clsEncryptDecrypt = BuinessLayer.clsEncryptDecrypt;
namespace SampWebApi.Printing
{
    public class PrintBase
    {
        private bool previewLoaded = false;
        int PreviousValue = 0;
        #region Public properties
        public clsBusinessLayer GKS_BL
        {
            get; set;
        }

        public int PrintConfigId { get; set; }
        public static int nLabelWidth = 10;
        public static int nLabelHeight = 10;
        public bool IsAskNoOfCopies = false;
        #endregion

        #region Private Fields
        private int nPageCount { get; set; }
        private int nTransType { get; set; }
        private string strPrinterName { get; set; }
        private int nConfigId { get; set; }
        public string GroupPDFoutputPath { get; set; }
        private int nTransId { get; set; }
        private Label[] lbl = new Label[8];
        private StringFormat genTypFormat = StringFormat.GenericTypographic;
        private Pen pen = new Pen(Color.Black, 0.25f);

        private StringFormat strFormat = new StringFormat();
        private int nItemCount = 0, nCopies, nKeys, nMaiYesNo, topMargin, totalNumber = 0, itemsPerPage = 0, pageNo,
            nSalesSerialWisePrint = 1, nSRPrintIndex = 0, nSRIndex = 0, totalNumberPrint = 0;
        private bool nSRPrint = false, nSR = false, IsPrint = false, totalNumberAssigned = false;
        private float YPositionDiff = 0, bodyFontHeight = 0;
        private string strHeaderSP, strBodySP, strFooterSP;
        private DataTable dtGetConfigPage, dtGetHeaderVal, dtGetSpecialVal, dtGetBodyVal;
        private PaperSize paperSize;
        private PaperSource PaperSource;
        private SolidBrush blackBrush = new SolidBrush(Color.Black);
        int nA = 0, nR = 0, nG = 0, nB = 0;
        private delegate void delegateMailTrigger(string pdfFilePath, string strFileName, string strFromId, string strPassword, string strToID, string strSMTPServer, string strSubject);
        private delegate void delegatePrintTrigger();
        string dtp;
        int nPrint;
        string strEmailIDs = "";
        decimal fHVal, fVVal;
        bool hasMorePagesToPrint = false;
        int nLineFeed = 0, nIncludeCut = 0;
        int nConfigNamep = 0, nprintID = 0, nTransNamep = 0, nnumofcopy = 0;
        bool IsTransPrint = false;
        PrintDialog PgSetUp = new PrintDialog();

        #endregion
        public void SetGlobalValues(int nTranType, int nTranId, int configId)
        {
            this.nTransType = nTranType;
            this.nTransId = nTranId;
            this.nConfigId = configId;

            LoadLineFeedandIncludeCut(configId);
        }
        public void SendEmail(int nTranType, int nTranId, string strMachineName, string strMailID, int ConfigID)
        {
            try
            {
                strEmailIDs = (!string.IsNullOrEmpty(strMailID) ? strMailID : string.Empty);
                SetGlobalValues(nTranType, nTranId, ConfigID);
                SendEmail();
            }
            catch (Exception ex)
            {
                throw;
            }
        }
        public string SaveAsPDF(int nTranType, int nTranId, string strMachineName, string strMailID, int ConfigID)
        {
            string RetunPath = "";
            try
            {
                SetGlobalValues(nTranType, nTranId, ConfigID);
                RetunPath = SaveFileinLocation();
            }
            catch (Exception ex)
            {
                throw ex;
            }
            return RetunPath;
        }
        public string GroupPDFPB(int nTranType, int nTranId, int ConfigID, bool IsFinished)
        {
            string RetunPath = "";
            try
            {
                SetGlobalValues(nTranType, nTranId, ConfigID);
                //RetunPath = SaveFileinLocation();
                DocWiseGeneratePDF(IsFinished);
            }
            catch (Exception ex)
            {
                throw ex;
            }
            return RetunPath;
        }
        public void PrintAndPreview(int nTranType, int nTranId, bool bIsEvent, bool bPreview, bool IsView, string strPrintCust = null)
        {
            try
            {
                bool IsPrint = true;
                DataTable dt = GKS_BL.BL_ExecuteParamSP("uspValidPrintStatus", nTranType, nTranId);
                if (dt.Rows.Count > 0)
                {
                    DataTable dtprint = GKS_BL.BL_ExecuteSqlQuery("SELECT [PwdID] FROM tblAppPasswordSettings WHERE PwdID=8 AND Active=1");
                }
                if (IsPrint)
                {
                    Configuration configFile = ConfigurationManager.OpenExeConfiguration(Application.ExecutablePath);
                    var settings = configFile.AppSettings.Settings;
                    nPrint = 2;// Convert.ToInt32(settings["Print"].Value);
                    string strMachineName = Environment.MachineName;
                    PrintAndEmail(nTranType, nTranId, bIsEvent, bPreview, IsView, strPrintCust);
                    //if ((!bPreview) && (nPrint == 2))// && (ValidatePrintYesNo(strMachineName, nTranType)
                    //{
                    //    if (MessageBox.Show("Do you want to Print", "Print", MessageBoxButtons.YesNo, MessageBoxIcon.Question, MessageBoxDefaultButton.Button1) == DialogResult.Yes)
                    //    {
                    //        PrintAndEmail(nTranType, nTranId, bIsEvent, bPreview, IsView, strPrintCust);
                    //    }
                    //    else
                    //    {
                    //        SendEmail(nTranType, nTranId, strMachineName, null, 0);
                    //    }
                    //}
                    //else
                    //{
                    //    PrintAndEmail(nTranType, nTranId, bIsEvent, bPreview, IsView, strPrintCust);
                    //}
                }
                //}
                //else
                //{
                //    DataTable dtprint = GKS_BL.BL_ExecuteSqlQuery("SELECT [PwdID] FROM tblAppPasswordSettings WHERE PwdID=8 AND Active=1");
                //    string dtp = dtprint.Rows[0][0].ToString();
                //    frmCancelDocPrint CDP = new frmCancelDocPrint(GKS_BL, Obj_MDI, dtp);
                //    CDP.MinimizeBox = false;
                //    CDP.StartPosition = FormStartPosition.CenterParent;
                //    if (CDP.ShowDialog() == DialogResult.OK) 
                //    {
                //        Configuration configFile = ConfigurationManager.OpenExeConfiguration(Application.ExecutablePath);
                //        var settings = configFile.AppSettings.Settings;
                //        nPrint = Convert.ToInt32(settings["Print"].Value);
                //        string strMachineName = Environment.MachineName;
                //        if ((!bPreview) && (nPrint == 2) && (ValidatePrintYesNo(strMachineName, nTranType)))
                //        {
                //            if (MessageBox.Show("Do you want to Print", "Print", MessageBoxButtons.YesNo, MessageBoxIcon.Question, MessageBoxDefaultButton.Button1) == DialogResult.Yes)
                //            {
                //                PrintAndEmail(nTranType, nTranId, bIsEvent, bPreview, strPrintCust);
                //            }
                //            else
                //            {
                //                SendEmail(nTranType, nTranId, strMachineName, null, 0);
                //            }
                //        }
                //        else
                //        {
                //            PrintAndEmail(nTranType, nTranId, bIsEvent, bPreview, strPrintCust);
                //        }
                //    }
                //}

            }
            catch (Exception ex)
            {
                //ErrorLogger.Instance.Log(ex);
            }
        }

        private void PrintAndEmail(int nTranType, int nTranId, bool bIsEvent, bool bPreview, bool IsView, string strPrintCust = null)
        {
            try
            {
                string strMachineName = Environment.MachineName;

                Print(nTranType, nTranId, bIsEvent, bPreview);
                //Email
                if (!bPreview)
                {
                    if (strPrintCust == null)
                    {
                        SendEmail(nTranType, nTranId, strMachineName, null, 0);
                    }
                }
            }
            catch (Exception ex)
            {
                //ErrorLogger.Instance.Log(ex);
            }
        }

        private void Print(int nTranType, int nTranId, bool bIsEvent, bool bPreview)
        {
            try
            {
                string strMachineName = Environment.MachineName;
                string strPrinter = null;
                int configId = PrintConfigId;
                DataTable dtMultpleProf = new DataTable();
                //Print Only Validation
                //if (!bPreview)
                //{
                //    if (!ValidatePrintYesNo(strMachineName, nTranType))
                //    {
                //        if (bIsEvent)
                //        {
                //            //Obj_MDI.ShowMessage(GKS_BL.BL_XMLMessage(387), GKS_BL.ToolStripErrorMsg);
                //        }
                //        return;
                //    }
                //}
                //After Continue Print Validation
                if (configId == 0)
                {
                    //configId = GetDefaultPrintConfiguration(strMachineName, nTranType);
                    dtMultpleProf = GKS_BL.BL_ExecuteParamSP("uspGetprintInfo", strMachineName, nTranType);// GetDefaultPrintConfigurationMultiple(strMachineName, nTranType);
                    if (dtMultpleProf.Rows.Count == 0)//(configId == 0)
                    {
                        //load popup for get configuration Name
                        //ShowPrintPopup(nTranType, 1, ref strPrinter, ref configId);
                        //ShowPrintPopupMultipleProfile(nTranType, 1, ref strPrinter, ref configId, ref dtMultpleProf);

                        if (dtMultpleProf.Rows.Count == 0)//configId == 0
                        {
                            return;
                        }
                    }
                }
                for (int i = 0; i < dtMultpleProf.Rows.Count; i++)
                {
                    configId = Convert.ToInt32(dtMultpleProf.Rows[i][0]);

                    //After Get Configuration and Printer Name
                    strPrinter = "CutePDF Writer";
                    if (!string.IsNullOrEmpty(strPrinter) && configId > 0)
                    {
                        SetGlobalValues(nTranType, nTranId, configId);
                        this.strPrinterName = strPrinter;

                        if (bPreview)
                        {
                            LoadPreview();
                        }
                        else
                        {
                            CommonPrint();
                        }

                    }
                }
            }
            catch (Exception ex)
            {
                //ErrorLogger.Instance.Log(ex);
            }
        }

        private void LoadLineFeedandIncludeCut(int configID)
        {
            this.nLineFeed = 0;// Convert.ToInt32(GKS_BL.BL_GetSingleValue("tblPrintConfig", "LineFeed", "PrintID='" + configID.ToString() + "'"));
            this.nIncludeCut = 0;// Convert.ToInt32(GKS_BL.BL_GetSingleValue("tblPrintConfig", "IncludeCut", "PrintID='" + configID.ToString() + "'"));
        }

        /// <summary>
        /// Load Preview
        /// </summary>
        private void LoadPreview()
        {
            //Header and Footer Procedure and Spl
            using (DataTable dtPrint = GKS_BL.BL_GetTransName(nTransType))//GKS_BL.BL_GetTransName(nTransType)
            {
                if (dtPrint.Rows.Count > 0)
                {
                    strHeaderSP = dtPrint.Rows[0][2].ToString();
                    strBodySP = dtPrint.Rows[0][3].ToString();
                    strFooterSP = dtPrint.Rows[0][4].ToString();
                    //load Transaction Data
                    GetRecordFromDB();
                    using (PrintDocument printDoc = new PrintDocument())
                    {
                        using (PrintPreviewDialog prnPreview = new PrintPreviewDialog())
                        {
                            //PgSetUp.AllowSomePages = true;
                            //PgSetUp.AllowSelection = true;
                            //PgSetUp.ShowDialog();

                            GetConfigDetail();
                            GetHeightContinuesSheet();
                            printDoc.PrintController = new StandardPrintController();
                            printDoc.PrintPage += new PrintPageEventHandler(PrintDoc_PrintPage);
                            printDoc.OriginAtMargins = false;
                            printDoc.DefaultPageSettings.PrinterSettings.PrinterName = strPrinterName;
                            printDoc.DefaultPageSettings.PaperSize = paperSize;
                            printDoc.BeginPrint += PrintDoc_BeginPrint;
                            //printDoc.DefaultPageSettings.PrinterSettings.FromPage = PgSetUp.PrinterSettings.FromPage;
                            //printDoc.DefaultPageSettings.PrinterSettings.ToPage = PgSetUp.PrinterSettings.ToPage;
                            prnPreview.Document = printDoc;
                            prnPreview.PrintPreviewControl.StartPageChanged += PrintPreviewControl_StartPageChanged;
                            prnPreview.WindowState = FormWindowState.Maximized;
                            prnPreview.PrintPreviewControl.Zoom = 100 / 100f;
                            prnPreview.ShowDialog();
                        }
                    }
                }
            }
        }

        void PrintPreviewControl_StartPageChanged(object sender, EventArgs e)
        {
            //PreviousValue = pageNo;
            pageNo = ((System.Windows.Forms.PrintPreviewControl)sender).StartPage + 1;

            previewLoaded = true;
            //totalNumber = nSR && PreviousValue == pageNo ? totalNumber - 1 : totalNumber;
            nSR = true;
        }

        private void PrintDoc_BeginPrint(object sender, PrintEventArgs e)
        {
            Reset();
        }

        /// <summary>
        /// Print Continues Sheet to Call clsprintConvertForm Class
        /// </summary>
        private void GetHeightContinuesSheet()
        {
            if (paperSize.Height == 1)
            {
                PrintConvert cls = new PrintConvert
                {
                    strHeaderSP = this.strHeaderSP,
                    strBodySP = this.strBodySP,
                    strFooterSP = this.strFooterSP,
                    nConfigId = this.nConfigId,
                    //objmdi = this.Obj_MDI,
                    GKS_BL = this.GKS_BL,
                    nTransId = this.nTransId,
                    dtGetConfigPage = this.dtGetConfigPage,
                    paperSize = this.paperSize,
                    nTransType = this.nTransType,
                    nSalesSerialWisePrint = this.nSalesSerialWisePrint
                };
                cls.LoadForm();
                paperSize.Height = Convert.ToInt32(cls.dfinalPrintingFormHeight);
            }
        }

        public void SetGlobalVariableforTransPrint(int nConfigId, string strPrinterName, int nTransType, int nCopies, int nTransDocID)
        {
            SetGlobalValues(nTransType, nTransDocID, nConfigId);
            this.nCopies = nCopies;
            this.strPrinterName = strPrinterName;
            this.nMaiYesNo = 0;
            this.IsTransPrint = true;
            CommonPrint();
        }

        private void CommonPrint()
        {
            try
            {
                //Header and Footer  and Spl Fields Procedure
                using (DataTable dtprint = GKS_BL.BL_GetTransName(nTransType))// GKS_BL.BL_GetTransName(nTransType)
                {
                    if (dtprint.Rows.Count > 0)
                    {
                        //Get All Available printer in local
                        PrinterSettings.StringCollection stringCollection = PrinterSettings.InstalledPrinters;
                        List<string> list = stringCollection.Cast<string>().ToList();
                        //Procedure header,Detail,Special Fields
                        strHeaderSP = dtprint.Rows[0][2].ToString();
                        strBodySP = dtprint.Rows[0][3].ToString();
                        strFooterSP = dtprint.Rows[0][4].ToString();
                        //load Transaction Data
                        //GetRecordFromDB();
                        //Get Printer Detail Based on Local Machine and Configuration ID 
                        nCopies = 1;
                        GetRecordFromDB();
                        //Get Config and Print Paper Size
                        GetConfigDetail();
                        //get and set Continues select time
                        GetHeightContinuesSheet();
                        //Print Trigger based on Number of copies if 0 Not Trigger mail
                        if (nCopies > 0)
                        {
                            //Check Config Printer available or not
                            if (list == null || !list.Contains(strPrinterName))
                            {
                                //Obj_MDI.ShowMessage("Cofiguartion Printer Not Available !!!", GKS_BL.ToolStripErrorMsg);
                            }
                            else
                            {
                                PrintTrigger();
                            }
                        }
                        //Detail Config Settings and Get Mail Id from the party from DB 
                        if (nMaiYesNo == 1)
                        {
                            //SendEmail();
                        }
                    }
                }
            }
            catch (Exception Ex)
            {
                //GKS_BL.BL_ExceptionMsg("ClsPrint", Ex.Message, Ex);
                //Obj_MDI.ShowMessage("Unable to Print", GKS_BL.ToolStripErrorMsg);
            }
        }
        public void TranprintConf(int nConfigId)
        {

            try
            {
                // get Configuration from table
                //dtGetConfigPage = GKS_BL.BL_GetPrintPreviewPage(nConfigId);
                if (dtGetConfigPage.Rows.Count > 0)
                {
                    if (Convert.ToInt32(dtGetConfigPage.Rows[0][6].ToString()) > 0)
                    {
                        paperSize = new PaperSize("Custom", Convert.ToInt32(dtGetConfigPage.Rows[0][0]), 1);
                    }
                    else
                    {
                        if (Convert.ToInt32(dtGetConfigPage.Rows[0][5].ToString()) > 0)
                        {
                            nItemCount = Convert.ToInt32(dtGetConfigPage.Rows[0][5].ToString());
                        }
                        paperSize = new PaperSize("Custom", Convert.ToInt32(dtGetConfigPage.Rows[0][0]), Convert.ToInt32(dtGetConfigPage.Rows[0][1]));
                    }
                    paperSize.RawKind = (int)PaperKind.Custom;
                }
            }
            catch (Exception ex)
            {
                //GKS_BL.BL_ExceptionMsg("Print", "getConfigDetails", ex);
                //GKS_BL.BL_LogFileWrite("PrintBase", "TranprintConf", ex.Message);
            }

        }

        public void TranPrintContinueSheet()
        {
            if (paperSize.Height == 1)
            {
                PrintConvert cls = new PrintConvert
                {
                    strHeaderSP = this.strHeaderSP,
                    strBodySP = this.strBodySP,
                    strFooterSP = this.strFooterSP,
                    nConfigId = this.nConfigId,
                    //objmdi = this.Obj_MDI,
                    GKS_BL = this.GKS_BL,
                    nTransId = this.nTransId,
                    dtGetConfigPage = this.dtGetConfigPage,
                    paperSize = this.paperSize,
                    nTransType = this.nTransType,
                    nSalesSerialWisePrint = this.nSalesSerialWisePrint
                };
                cls.LoadForm();
                paperSize.Height = Convert.ToInt32(cls.dfinalPrintingFormHeight);
            }


        }

        private void SendEmail()
        {
            try
            {
                DataTable dtPrint = GKS_BL.BL_GetTransName(nTransType);//GKS_BL.BL_GetTransName(nTransType)
                if (dtPrint.Rows.Count > 0)
                {
                    strHeaderSP = dtPrint.Rows[0][2].ToString();
                    strBodySP = dtPrint.Rows[0][3].ToString();
                    strFooterSP = dtPrint.Rows[0][4].ToString();
                }
                GetConfigDetail();
                GetHeightContinuesSheet();
                GetRecordFromDB();
                PrinterSettings.StringCollection strInsPrinters = PrinterSettings.InstalledPrinters;
                List<string> lstInsPrinters = strInsPrinters.Cast<string>().ToList();
                //Detail Config Settings and Get Mail Id from the party from DB 
                using (DataTable dtMailData = GKS_BL.BL_ExecuteParamSP("uspGetMailId", nTransType, nTransId))
                {
                    //Verify Mail Yes check Printer Config form then check Admin in application Config Check Allo Trigger or not
                    if (Convert.ToInt32(dtMailData.Rows[2][0]) == 1)
                    {
                        //Check Mail Id Is there or  not the party
                        bool hasMailID = false;
                        string strTOMailID = "";
                        if (string.IsNullOrEmpty(strEmailIDs) && !string.IsNullOrEmpty(dtMailData.Rows[6][0].ToString().Trim()))
                        {
                            hasMailID = true;
                            strTOMailID = Convert.ToString(dtMailData.Rows[6][0]).Trim();
                        }
                        else if (!string.IsNullOrEmpty(strEmailIDs))
                        {
                            hasMailID = true;
                            strTOMailID = strEmailIDs;
                        }
                        if (hasMailID)
                        {
                            //Validate print xps printer available or not
                            if (lstInsPrinters == null || !lstInsPrinters.Contains("Microsoft XPS Document Writer"))// !lstInsPrinters.Contains("") 
                            {
                                //Obj_MDI.ShowMessage("Mail Can't send !!! Not Available MXDW", GKS_BL.ToolStripErrorMsg);
                                return;
                            }
                            string pdfFilePath = ConfigurationManager.ConnectionStrings["PrintDoc"].ConnectionString + "\\Mail Transfer\\";

                            ///string pdfFilePath = @"D:\HOST\ResetPwd" + "\\Mail Transfer\\";

                            string strFileName = Convert.ToString(dtMailData.Rows[5][0]) + DateTime.Now.ToString("yyyyMMddHHmmssffff");

                            //Temporary Store in Physically
                            if (!Directory.Exists(pdfFilePath))
                            {
                                Directory.CreateDirectory(pdfFilePath);
                            }
                            // Store XPS file mail trigger
                            using (PrintDocument printDoc = new PrintDocument())
                            {
                                Reset();
                                printDoc.PrintPage += new PrintPageEventHandler(PrintDoc_PrintPage);
                                printDoc.DefaultPageSettings.PaperSize = paperSize;
                                printDoc.DefaultPageSettings.PrinterSettings.PrintToFile = true;
                                printDoc.DefaultPageSettings.PrinterSettings.PrintFileName = pdfFilePath + strFileName + ".xps";//.xps
                                printDoc.DefaultPageSettings.PrinterSettings.PrinterName = "Microsoft XPS Document Writer";// "Microsoft XPS Document Writer";
                                printDoc.PrintController = new StandardPrintController();
                                printDoc.PrintPage += (sender, e) => nPageCount++;
                                printDoc.Print();

                            }
                            //Mail Asynchronous method call using delegate

                            delegateMailTrigger delMailrigger = new delegateMailTrigger(MailTransfer);//(attachmentMail, spirePdfCreater, dtAdminData);
                            IAsyncResult iarMail = delMailrigger.BeginInvoke(pdfFilePath, strFileName, dtMailData.Rows[0][0].ToString(),
                               (dtMailData.Rows[1][0].ToString()), strTOMailID, dtMailData.Rows[3][0].ToString(),
                            dtMailData.Rows[4][0].ToString() + "_" + dtMailData.Rows[5][0].ToString() + "_" + dtMailData.Rows[7][0].ToString()//subject
                               , new AsyncCallback(IAsyncResultMailTrigger), "Unable to Print");
                            delMailrigger -= MailTransfer;

                            //Testing time using this
                            //mailtransfer(pdfFilePath, strFileName, dtMailData.Rows[0][0].ToString(), dtMailData.Rows[1][0].ToString(),
                            //dtMailData.Rows[6][0].ToString(), dtMailData.Rows[3][0].ToString(),
                            //dtMailData.Rows[4][0].ToString() + "_" + dtMailData.Rows[5][0].ToString() + "_" + dtMailData.Rows[7][0].ToString());//subject
                        }
                    }
                }
            }
            catch (Exception Ex)
            {
                //GKS_BL.BL_LogFileWrite("Mail Unable to Process that time", "SendEmail", Ex.Message);
                throw;
            }
        }
        private string SaveFileinLocation()
        {
            string FinalFileName = "";
            try
            {
                DataTable dtPrint = GKS_BL.BL_GetTransName(nTransType);//GKS_BL.BL_GetTransName(nTransType)
                if (dtPrint.Rows.Count > 0)
                {
                    strHeaderSP = dtPrint.Rows[0][2].ToString();
                    strBodySP = dtPrint.Rows[0][3].ToString();
                    strFooterSP = dtPrint.Rows[0][4].ToString();
                }
                GetConfigDetail();
                GetHeightContinuesSheet();
                GetRecordFromDB();
                PrinterSettings.StringCollection strInsPrinters = PrinterSettings.InstalledPrinters;
                List<string> lstInsPrinters = strInsPrinters.Cast<string>().ToList();
                //Detail Config Settings and Get Mail Id from the party from DB 
                using (DataTable dtMailData = GKS_BL.BL_ExecuteParamSP("uspGetMailId", nTransType, nTransId))
                {
                    //Validate print xps printer available or not
                    if (lstInsPrinters == null || !lstInsPrinters.Contains("Microsoft XPS Document Writer"))// !lstInsPrinters.Contains("") 
                    {
                        //Obj_MDI.ShowMessage("Mail Can't send !!! Not Available MXDW", GKS_BL.ToolStripErrorMsg);
                        return "no printer";
                    }
                    //string p = AppDomain.CurrentDomain.BaseDirectory + "\\PDF\\";
                    string pdfFilePath = System.Configuration.ConfigurationManager.AppSettings["SupportFilePath"] + "\\PDF\\";
                    pdfFilePath = AppDomain.CurrentDomain.BaseDirectory + "\\PDF\\";

                    string strFileName = Convert.ToString(dtMailData.Rows[5][0]) + "_" + DateTime.Now.ToString("yyyyMMddHHmmssffff");

                    //Temporary Store in Physically
                    if (!Directory.Exists(pdfFilePath))
                    {
                        Directory.CreateDirectory(pdfFilePath);
                    }
                    // Store XPS file mail trigger
                    using (PrintDocument printDoc = new PrintDocument())
                    {
                        Reset();
                        printDoc.PrintPage += new PrintPageEventHandler(PrintDoc_PrintPage);
                        printDoc.DefaultPageSettings.PaperSize = paperSize;
                        printDoc.DefaultPageSettings.PrinterSettings.PrintToFile = true;
                        printDoc.DefaultPageSettings.PrinterSettings.PrintFileName = pdfFilePath + strFileName + ".xps";//.xps
                        printDoc.DefaultPageSettings.PrinterSettings.PrinterName = "Microsoft XPS Document Writer";// "Microsoft XPS Document Writer";
                        printDoc.PrintController = new StandardPrintController();
                        printDoc.PrintPage += (sender, e) => nPageCount++;
                        printDoc.Print();
                    }


                    //old
                    //using (PdfDocument spirePdfCreater = new PdfDocument())
                    //{
                    //    spirePdfCreater.LoadFromXPS(pdfFilePath + strFileName + ".xps");//xps
                    //                                                                    //convert to pdf file.
                    //    spirePdfCreater.SaveToFile(pdfFilePath + strFileName + ".pdf");
                    //}
                    using (PdfSharp.Xps.XpsModel.XpsDocument pdfXpsDoc = PdfSharp.Xps.XpsModel.XpsDocument.Open(pdfFilePath + strFileName + ".xps"))
                    {
                        PdfSharp.Xps.XpsConverter.Convert(pdfXpsDoc, pdfFilePath + strFileName + ".pdf", 0);
                    }
                    //ClientScript.RegisterStartupScript(this.GetType(), "print", string.Format("PrintHTML(\"{0}\");", sb.ToString()), true);
                    //set file Extension
                    string xpsfilename = pdfFilePath + strFileName + ".xps";
                    strFileName = strFileName + ".pdf";
                    FinalFileName = pdfFilePath + strFileName;
                    if (System.IO.File.Exists(xpsfilename))
                    {
                        System.IO.File.Delete(xpsfilename);
                    }
                }
            }
            catch (Exception Ex)
            {
                //GKS_BL.BL_LogFileWrite("PrintBase", "SaveFileinLocation", Ex.Message);
                throw Ex;
                //GKS_BL.BL_ExceptionMsg("Mail Unable to Process that time", Ex.Message, Ex);
            }
            return FinalFileName;
        }
        private void DocWiseGeneratePDF(bool IsFinished)
        {
            try
            {
                DataTable dtPrint = GKS_BL.BL_GetTransName(nTransType);//GKS_BL.BL_GetTransName(nTransType)
                if (dtPrint.Rows.Count > 0)
                {
                    strHeaderSP = dtPrint.Rows[0][2].ToString();
                    strBodySP = dtPrint.Rows[0][3].ToString();
                    strFooterSP = dtPrint.Rows[0][4].ToString();
                }
                GetConfigDetail();
                GetHeightContinuesSheet();
                GetRecordFromDB();
                PrinterSettings.StringCollection strInsPrinters = PrinterSettings.InstalledPrinters;
                List<string> lstInsPrinters = strInsPrinters.Cast<string>().ToList();
                //Detail Config Settings and Get Mail Id from the party from DB 
                using (DataTable dtMailData = GKS_BL.BL_ExecuteParamSP("uspGetMailId", nTransType, nTransId))
                {
                    //Verify Mail Yes check Printer Config form then check Admin in application Config Check Allo Trigger or not
                    //Check Mail Id Is there or  not the party
                    bool hasMailID = true;
                    if (hasMailID)
                    {
                        //Validate print xps printer available or not
                        if (lstInsPrinters == null || !lstInsPrinters.Contains("Microsoft XPS Document Writer"))
                        {
                            //Obj_MDI.ShowMessage("Mail Can't send !!! Not Available MXDW", GKS_BL.ToolStripErrorMsg);
                            return;
                        }
                        string pdfFileTempPath = AppDomain.CurrentDomain.BaseDirectory + "\\TempGroupPDFPath\\";// Application.StartupPath
                        string pdfFilePath = AppDomain.CurrentDomain.BaseDirectory + "\\Group PDF\\";
                        string strFileName = Convert.ToString(dtMailData.Rows[5][0]) + "_" + DateTime.Now.ToString("yyyyMMddHHmmssffff");
                        //Temporary Store in Physically
                        if (!Directory.Exists(pdfFilePath))
                        {
                            Directory.CreateDirectory(pdfFilePath);
                        }
                        if (!Directory.Exists(pdfFileTempPath))
                        {
                            Directory.CreateDirectory(pdfFileTempPath);
                        }
                        // Store XPS file mail trigger
                        using (PrintDocument printDoc = new PrintDocument())
                        {
                            Reset();
                            printDoc.PrintPage += new PrintPageEventHandler(PrintDoc_PrintPage);
                            printDoc.DefaultPageSettings.PaperSize = paperSize;
                            printDoc.DefaultPageSettings.PrinterSettings.PrintToFile = true;
                            printDoc.DefaultPageSettings.PrinterSettings.PrintFileName = pdfFileTempPath + strFileName + ".xps";
                            printDoc.DefaultPageSettings.PrinterSettings.PrinterName = "Microsoft XPS Document Writer";
                            printDoc.PrintController = new StandardPrintController();
                            printDoc.PrintPage += (sender, e) => nPageCount++;
                            printDoc.Print();
                        }
                        ConvertXPStoPDF(pdfFileTempPath, pdfFilePath, strFileName, IsFinished);
                    }
                }
            }
            catch (Exception Ex)
            {
                //GKS_BL.BL_ExceptionMsg("Mail Unable to Process that time", Ex.Message, Ex);
            }
        }
        private void ConvertXPStoPDF(string pdfTempPath, string pdfMainPath, string strFileName, bool IsFinished)
        {
            try
            {
                //using (PdfDocument spirePdfCreater = new PdfDocument())
                //{
                //xps Create 10 page above do not send pdf only xps
                if (nPageCount > 10)
                {
                    //objmdi.ShowMessage("Sending Mail Failed for Attachment Contain Greater then 10 pages", GKS_BL.ToolStripErrorMsg);
                    //DeleteDirectory(pdfFilePath, strFileName);
                    //set file Extension
                    strFileName = strFileName + ".xps";
                }
                else
                {
                    using (PdfSharp.Xps.XpsModel.XpsDocument pdfXpsDoc = PdfSharp.Xps.XpsModel.XpsDocument.Open(pdfTempPath + strFileName + ".xps"))
                    {
                        PdfSharp.Xps.XpsConverter.Convert(pdfXpsDoc, pdfTempPath + strFileName + ".pdf", 0);
                    }
                }
                //}
            }
            catch (Exception ex)
            {

            }
            finally
            {
                if (IsFinished)
                {
                    string[] filePaths = Directory.GetFiles(pdfTempPath, "*.pdf", SearchOption.TopDirectoryOnly);
                    string opPth = MergePDF.MergeAllPDF(pdfMainPath, filePaths);
                    GroupPDFoutputPath = opPth;
                    DeleteDirectory(pdfTempPath, strFileName);
                    //ProcessStartInfo startInfo = new ProcessStartInfo(opPth);
                    //Process.Start(startInfo);
                }
            }
        }
        /// <summary>
        /// Preset Some Loop Condition Varaible
        /// </summary>
        private void Reset()
        {
            //default Values For Print
            //PreviousValue = nSR ? Convert.ToInt32(Math.Ceiling((dtGetBodyVal.Rows.Count + 1) / Convert.ToDecimal(dtGetConfigPage.Rows[0][5]))) :
            //    Convert.ToInt32(Math.Ceiling(dtGetBodyVal.Rows.Count / Convert.ToDecimal(dtGetConfigPage.Rows[0][5])));

            pageNo = !IsPrint ? (previewLoaded) ? pageNo : 1 : 1;
            totalNumber = !IsPrint ? (previewLoaded) ? ((itemsPerPage - 1) != -1) ? (Convert.ToInt32(dtGetConfigPage.Rows[0][5].ToString()) * (pageNo - 1)) : 0 : 0 : 0;
            //totalNumber = nSR && PreviousValue == pageNo ? totalNumber - 1 : totalNumber;
            //nSR =  nSR && PreviousValue == pageNo ? false : true;
            itemsPerPage = 0;// (!previewLoaded) ? 0 : itemsPerPage;
            bodyFontHeight = 0;
            //nSRPrint = false;
        }

        private static void DeleteDirectory(string pdfFilePath, string strFileName)
        {
            //Temporary Stored print files exe path,Delete after Printing 
            if (Directory.Exists(pdfFilePath))
            {
                Directory.Delete(pdfFilePath, true);
            }
        }

        /// <summary>
        ///Used Asyncronous parallal process for Mail Trigger 
        /// </summary>
        /// <param name="iAsync">call from Common Print method</param>
        private void IAsyncResultMailTrigger(IAsyncResult iAsync)
        {
            try
            {
                AsyncResult arMail = (AsyncResult)iAsync;
                delegateMailTrigger delMailTrigger = (delegateMailTrigger)arMail.AsyncDelegate;

                delMailTrigger.EndInvoke(iAsync);
                if (!iAsync.IsCompleted)
                {
                    //Obj_MDI.ShowMessage(Convert.ToString(iAsync.AsyncState), GKS_BL.ToolStripErrorMsg);
                }
            }
            catch (Exception ex)
            {
                //throw;
            }
        }

        private void PaperHW(string PaperType, int Height, int Width, ref int Lines, ref int Chars)
        {
            try
            {
                double dWidth = (Height) * 1;
                double dHeight = (Width) * 1;
                if (PaperType == "mm")
                {
                    dHeight = (Height) * 0.2645833333333;
                    dWidth = ((Width) * 0.2645833333333);
                }
                if (PaperType == "CM")
                {
                    dHeight = (Height) * 0.02645833333333;
                    dWidth = (Width) * 0.02645833333333;
                }
                if (PaperType == "Inches")
                {
                    dHeight = (Height) * 0.01041666666667;
                    dWidth = (Width) * 0.01041666666667;
                }
                if (PaperType == "Pixel")
                {
                    dHeight = (Height) * 1;
                    dWidth = (Width) * 1;
                }
                if (PaperType == "Chars")
                {
                    dHeight = (Height) / 22.677;
                    dWidth = (Width) / 8.69;
                }

                Lines = (int)Math.Round(Convert.ToDouble(dHeight));
                Chars = (int)Math.Round(Convert.ToDouble(dWidth));
            }
            catch (Exception ex)
            {
                //GKS_BL.BL_ExceptionMsg("PrintBase", "PaperHW", ex);
            }
        }

        private void EnableLineFeed(StreamWriter sw, bool isReverse = false)
        {
            int mode = (isReverse) ? 106 : 74;
            int mag1 = 2, mag2 = 72;
            int divi = nLineFeed / mag1;
            int mod = nLineFeed % mag1;
            int val = (mod == 0) ? 0 : mod * mag2;

            for (int i = 0; i < divi; i++)
            {
                sw.Write(((char)27).ToString());
                sw.Write(((char)mode).ToString());
                if (val == 0 && (i == divi - 1) && isReverse)
                    sw.WriteLine(((char)216).ToString());
                else
                    sw.Write(((char)216).ToString());
            }
            if (val != 0)
            {
                sw.Write(((char)27).ToString());
                sw.Write(((char)mode).ToString());
                if (isReverse)
                    sw.WriteLine(((char)val).ToString());
                else
                    sw.Write(((char)val).ToString());
            }
        }

        private PrintQueue AssignPrintingFiletoQueue(PrintServer printServer, string lPrinterName)
        {
            try
            {
                PrintQueue printQueue = new PrintQueue(printServer, lPrinterName);
                return printQueue;
            }
            catch
            {
                PrintQueue printQueue = new PrintQueue(printServer, lPrinterName, PrintSystemDesiredAccess.AdministratePrinter);
                return printQueue;
            }
        }

        /// <summary>
        /// Print Functionlaity Seperate from UI for Asyncronous
        /// </summary>
        /// <param name="spirePdfCreater"></param>
        /// <param name="pdfFilePath"></param>
        /// 

        private void PrintPageEventHandler(object sender, PrintPageEventArgs e)
        {

        }
        private void PrintTrigger()
        {
            while (nCopies > 0)
            {
                IsPrint = true;
                Reset();

                string tempFile;
                string appPath = ConfigurationManager.ConnectionStrings["PrintDoc"].ConnectionString + @"\PrintSpool\";//Application.StartupPath
                if (!Directory.Exists(appPath)) Directory.CreateDirectory(appPath);

                int printMode = Convert.ToInt32(dtGetConfigPage.Rows[0][4].ToString());
                if (printMode == 1)
                {
                    tempFile = appPath + Guid.NewGuid().ToString() + ".xps";
                    using (PrintDocument printDoc = new PrintDocument())
                    {
                        //PrintDialog PgSetUp = new PrintDialog();
                        //PgSetUp.AllowSomePages = true;
                        //PgSetUp.AllowSelection = true;
                        //PgSetUp.ShowDialog();
                        //printDoc.DefaultPageSettings.PrinterSettings.FromPage = PgSetUp.PrinterSettings.FromPage;
                        //printDoc.DefaultPageSettings.PrinterSettings.ToPage = PgSetUp.PrinterSettings.ToPage;
                        GetConfigDetail();
                        GetHeightContinuesSheet();
                        printDoc.PrintController = new StandardPrintController();
                        printDoc.PrintPage += new PrintPageEventHandler(PrintDoc_PrintPage);
                        printDoc.OriginAtMargins = false;
                        printDoc.DefaultPageSettings.PrinterSettings.PrinterName = strPrinterName;
                        printDoc.DefaultPageSettings.PaperSize = paperSize;
                        //PrintPageEventHandler printpp = new PrintPageEventHandler(PrintPageEventHandler);
                        //printDoc.DefaultPageSettings.PaperSource = 
                        //printDoc.PrinterSettings.PrintRange =  PrintRange.SomePages;
                        //printDoc.PrinterSettings.FromPage = 2;
                        //printDoc.PrinterSettings.ToPage = 3;
                        //printDoc.PrinterSettings.MinimumPage = 1;
                        //printDoc.PrinterSettings.MaximumPage = 100;
                        printDoc.Print();

                        //printDoc.PrintController = new StandardPrintController();
                        //printDoc.DefaultPageSettings.PaperSize = paperSize;
                        //printDoc.DefaultPageSettings.PrinterSettings.PrinterName = "Microsoft XPS Document Writer";
                        //printDoc.DefaultPageSettings.PrinterSettings.PrintFileName = tempFile;
                        //printDoc.DefaultPageSettings.PrinterSettings.PrintToFile = true;
                        //printDoc.OriginAtMargins = false;
                        //printDoc.PrintPage += new PrintPageEventHandler(PrintDoc_PrintPage);
                        //printDoc.PrintPage += (sender, e) => nPageCount++;
                        //printDoc.Print();

                        //PrintAtPrinter(strPrinterName, tempFile);
                        IsPrint = false;
                    }
                }
                else
                {
                    do
                    {
                        tempFile = appPath + Guid.NewGuid().ToString() + ".out";
                        using (var sw = new StreamWriter(File.Create(tempFile), Encoding.ASCII))
                        {
                            int totLines = 1, totChars = 1, totLineContinous = 1;
                            bool continousPaper = (dtGetConfigPage.Rows[0][6].ToString() == "1");
                            bool tranType = (nTransType == 4) && nSRPrint;
                            bool prodSerialExists = false;
                            if (nTransType == 4)
                            {
                                for (int i = 0; i < dtGetBodyVal.Rows.Count; i++)
                                {
                                    if (!string.IsNullOrEmpty(Convert.ToString(dtGetBodyVal.Rows[i]["ProdSerial"])))
                                    {
                                        prodSerialExists = true;
                                        break;
                                    }
                                }
                            }

                            ChangePaperSizeBasedOnUnit(dtGetConfigPage.Rows[0][21].ToString());
                            PaperHW(dtGetConfigPage.Rows[0][21].ToString(), (continousPaper || prodSerialExists || tranType) ? paperSize.Height + 23 : Convert.ToInt32(dtGetConfigPage.Rows[0][1].ToString()), Convert.ToInt32(dtGetConfigPage.Rows[0][0].ToString()), ref totLines, ref totChars);

                            if ((prodSerialExists || tranType) && continousPaper)
                            {
                                paperSize.Height = 1;
                                GetHeightContinuesSheet();
                                PaperHW(dtGetConfigPage.Rows[0][21].ToString(), (continousPaper || prodSerialExists || tranType) ? paperSize.Height + 23 : Convert.ToInt32(dtGetConfigPage.Rows[0][1].ToString()), Convert.ToInt32(dtGetConfigPage.Rows[0][0].ToString()), ref totLineContinous, ref totChars);
                            }

                            totLines = (totLines > totLineContinous) ? totLines : totLineContinous;

                            List<StringBuilder> lstString = new List<StringBuilder>(totLines);
                            for (int i = 0; i < totLines; i++)
                            {
                                lstString.Add(new StringBuilder("".PadLeft(totChars)));
                            }
                            SetHeaderLabel(null, printMode, lstString);
                            SetHeaderValue(null, printMode, lstString);
                            SetBody(null, null, printMode, lstString);

                            //Pre line feed
                            EnableLineFeed(sw, true);
                            //Content
                            int j = 1;
                            foreach (var str in lstString)
                            {
                                if (j == lstString.Count)
                                {
                                    sw.Write(str.ToString());
                                }
                                else
                                {
                                    sw.WriteLine(str.ToString());
                                }
                                j++;
                            }
                            //Post line feed
                            EnableLineFeed(sw);
                        }

                        //PrintAtPrinter(strPrinterName, tempFile, true);
                    } while (hasMorePagesToPrint);
                }
                nCopies--;
            }
        }

        /// <summary>
        /// 
        /// validation send mail or not 
        /// Validation Success to send mail
        /// </summary>
        /// <param name="strPath">Path Where to locate Attachment file</param>
        private void MailTransfer(string pdfFilePath, string strFileName, string strFromId, string strPassword, string strToID, string strsmtpServer, string strSubject)
        {
            try
            {
                //Check Internet Connectivity from Utilities Class
                if (CheckForInternetConnection())
                {
                    using (PdfDocument spirePdfCreater = new PdfDocument())
                    {
                        //xps Create 10 page above do not send pdf only xps
                        if (nPageCount > 10)
                        {
                            //objmdi.ShowMessage("Sending Mail Failed for Attachment Contain Greater then 10 pages", GKS_BL.ToolStripErrorMsg);
                            //DeleteDirectory(pdfFilePath, strFileName);
                            //set file Extension
                            strFileName = strFileName + ".xps";
                        }
                        else
                        {
                            //if (!Directory.Exists(pdfFilePath))
                            //{
                            //    Directory.CreateDirectory(pdfFilePath);
                            //}
                            //Load .xps file form your local executable path
                            spirePdfCreater.LoadFromXPS(pdfFilePath + strFileName + ".xps");//xps
                            //convert to pdf file.
                            spirePdfCreater.SaveToFile(pdfFilePath + strFileName + ".pdf");
                            //set file Extension
                            strFileName = strFileName + ".pdf";
                        }
                        //Mail Triggering
                        using (MailMessage mail = new MailMessage())
                        {
                            using (SmtpClient SmtpServer = new SmtpClient(strsmtpServer))//"smtp.gmail.com"
                            {
                                using (Attachment attachment = new Attachment(pdfFilePath + strFileName))
                                {
                                    mail.From = new MailAddress(strFromId);
                                    mail.To.Add(strToID);
                                    mail.Subject = strSubject;
                                    mail.Attachments.Add(attachment);
                                    SmtpServer.Port = 587;
                                    SmtpServer.Host = strsmtpServer;//"smtp.gmail.com"
                                    SmtpServer.UseDefaultCredentials = false;
                                    SmtpServer.Credentials = new System.Net.NetworkCredential(strFromId, clsEncryptDecrypt.Decrypt(strPassword));
                                    SmtpServer.EnableSsl = true;
                                    SmtpServer.DeliveryMethod = SmtpDeliveryMethod.Network;
                                    SmtpServer.Send(mail);

                                }
                            }
                            //Obj_MDI.ShowMessage("Mail Sent Successfully", GKS_BL.ToolStripInfoMsg);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                throw;
                //Obj_MDI.ShowMessage("Mail Unable to Process that time", GKS_BL.ToolStripErrorMsg);
            }
            finally
            {
                DeleteDirectory(pdfFilePath, strFileName);
            }
        }
        public static bool CheckForInternetConnection()
        {
            try
            {
                using (var client = new WebClient())
                {
                    using (var stream = client.OpenRead("http://www.google.com"))
                    {
                        return true;
                    }
                }
            }
            catch
            {
                return false;
            }
        }
        /// <summary>
        /// Prindocument raised that Event dynamically
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void PrintDoc_PrintPage(object sender, PrintPageEventArgs e)
        {
            try
            {
                //int Pg = 0;

                topMargin = (int)e.MarginBounds.Top;
                SetHeaderLabel(e.Graphics); // Draw Head Label
                SetHeaderValue(e.Graphics); // Draw Head value
                SetBody(e.Graphics, e);
            }
            catch (Exception ex)
            {
                //Obj_MDI.ShowMessage("Unable to Print", GKS_BL.ToolStripErrorMsg);
            }
        }

        private void ChangePaperSizeBasedOnUnit(string strMesuringUnit)
        {
            try
            {
                if (strMesuringUnit.Trim() == "mm")
                {
                    fVVal = fHVal = 3.7795275593333M;
                }
                else if (strMesuringUnit.Trim() == "CM")
                {
                    fVVal = fHVal = 37.795275593333M;
                }
                else if (strMesuringUnit.Trim() == "Inches")
                {
                    fVVal = fHVal = 96.0M;
                }
                else if (strMesuringUnit.Trim() == "Pixel")
                {
                    fVVal = fHVal = 1.0M;
                }
                else if (strMesuringUnit.Trim() == "Chars")
                {
                    fHVal = 8.69291338646659M;
                    fVVal = 22.6771653559998M;
                }
            }
            catch (Exception ex)
            {
                //GKS_BL.BL_ExceptionMsg("PrintBase", "ChangePaperSizeBasedOnUnit", ex);
            }
        }

        //Print Record get from DB
        private void GetRecordFromDB()
        {
            try
            {
                dtGetHeaderVal = GKS_BL.BL_ExecuteParamSP(strHeaderSP, nTransId);
                dtGetSpecialVal = GKS_BL.BL_ExecuteParamSP(strFooterSP);
                //Sales Transaction pass Two Parameters based on Serial wies print or Without serial
                if (nTransType == 4)
                {
                    //one mention for one column add additional for Product Serial
                    using (DataTable dtTemp = GKS_BL.BL_ExecuteParamSP(strBodySP, Convert.ToInt32(dtGetHeaderVal.Rows[0][0]), 1))
                    {
                        dtGetBodyVal = dtTemp.Clone();
                        //dtGetBodyVal = GKS_BL.BL_ExecuteParamSP(strBodySP, Convert.ToInt32(dtGetHeaderVal.Rows[0][0]), nSalesSerialWisePrint);
                        foreach (DataRow iRowBody in dtTemp.Rows)
                        {
                            dtGetBodyVal.ImportRow(iRowBody);
                            //Future set app config level print sales Invoice with Product Serial
                            if (nSalesSerialWisePrint == 2)//1
                            {
                                //get Serial from Detail based on row serial column and Inv Id
                                using (DataTable dtSerial = GKS_BL.BL_ExecuteParamSP("uspGetProductSerialForPrint",
                                    Convert.ToInt32(dtGetHeaderVal.Rows[0][0]),
                                    Convert.ToInt32(iRowBody["Serial"])))
                                {
                                    //product serial add to print datatable
                                    foreach (DataRow item in dtSerial.Rows)
                                    {
                                        DataRow dr = dtGetBodyVal.NewRow();
                                        dr["ProdSerial"] = item["ProdSerial"];
                                        dtGetBodyVal.Rows.Add(dr);
                                    }
                                }
                            }
                        }
                    }
                    //Print Sales Return Detail if Adjust for that sales document
                    using (DataTable dt = GKS_BL.BL_ExecuteParamSP("uspGetAdjustedSalesReturnInvoice", Convert.ToInt32(dtGetHeaderVal.Rows[0][0])))
                    {
                        if (dt.Rows.Count > 0)
                        {
                            nSRPrintIndex = dtGetBodyVal.Rows.Count;
                            nSR = true;
                            nSRPrint = true;
                        }
                        foreach (DataRow IRow in dt.Rows)
                        {
                            //Get Sales Return Detail
                            using (DataTable dtSaleReturn = GKS_BL.BL_ExecuteParamSP(strBodySP, Convert.ToInt32(IRow[0])))
                            {
                                //Sales return Moves to Sales Detail Table
                                dtGetBodyVal.Rows.Add();
                                dtGetBodyVal.Rows[dtGetBodyVal.Rows.Count - 1]["SR"] = (Convert.ToInt32(dtSaleReturn.Rows[0]["TransactionType"]) == 2 ? "Saleable Return - " : "Damage Return - ") + dtSaleReturn.Rows[0]["DocID"].ToString();
                                //dtGetBodyVal.Rows.Add();
                                //dtGetBodyVal.Rows[dtGetBodyVal.Rows.Count - 1]["SR"] = "DocID - " + dtSaleReturn.Rows[0]["DocID"].ToString();
                                foreach (DataRow item in dtSaleReturn.Rows)
                                {
                                    dtGetBodyVal.ImportRow(item);
                                }
                            }
                        }
                    }
                }
                //Other Transaction as Follows
                else
                {
                    dtGetBodyVal = GKS_BL.BL_ExecuteParamSP(strBodySP, nTransId);
                }
            }
            catch (Exception)
            {
                throw;
            }
        }

        /// <summary>
        ///set paper only header and labels
        /// </summary>
        /// <param name="g">Draw a string using graphics </param>
        private void SetHeaderLabel(System.Drawing.Graphics g, int printMode = 1, List<StringBuilder> sw = null)
        {
            try
            {
                if (dtGetConfigPage.Rows.Count > 0)
                {
                    //Header Label Printing
                    DataRow[] drHeader = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Label' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Header'");
                    if (drHeader.Length > 0)
                    {
                        foreach (DataRow row in drHeader)
                        {
                            if (row[14].ToString() == "Label" && row[18].ToString() == "Header")
                            {
                                SetFontStyle(row, g, null, 0, 0, "Label", 0, printMode, sw);
                            }
                        }
                    }
                    //Image Printing
                    drHeader = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Image' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Header'");
                    if (drHeader.Length > 0)
                    {
                        foreach (DataRow row in drHeader)
                        {
                            if (row[14].ToString() == "Image" && row[18].ToString() == "Header")
                            {
                                SetFontStyle(row, g, null, 0, 0, "Image", 0, printMode, sw);
                            }
                        }
                    }
                    //BarCode Printing
                    drHeader = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'gksBarCode' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Header'");
                    if (drHeader.Length > 0)
                    {
                        foreach (DataRow row in drHeader)
                        {
                            if (row[14].ToString() == "gksBarCode" && row[18].ToString() == "Header")
                            {
                                SetFontStyle(row, g, null, 0, 0, "gksBarCode", 0, printMode, sw);
                            }
                        }
                    }
                    //QRCode Printing
                    drHeader = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'gksQRCode' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Header'");
                    if (drHeader.Length > 0)
                    {
                        foreach (DataRow row in drHeader)
                        {
                            if (row[14].ToString() == "gksQRCode" && row[18].ToString() == "Header")
                            {
                                SetFontStyle(row, g, null, 0, 0, "gksQRCode", 0, printMode, sw);
                            }
                        }
                    }
                    //Barcode Printing
                    drHeader = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Barcode' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Barcode'");
                    if (drHeader.Length > 0 && dtGetHeaderVal.Rows.Count > 0)
                    {
                        foreach (DataRow row in drHeader)
                        {
                            SetFontStyle(row, g, dtGetHeaderVal, 0, 0, "Barcode", 0, printMode, sw);
                        }
                    }
                    //Box Printing
                    drHeader = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Box' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Header'");
                    if (drHeader.Length > 0 && dtGetHeaderVal.Rows.Count > 0)
                    {
                        foreach (DataRow row in drHeader)
                        {
                            SetFontStyle(row, g, dtGetHeaderVal, 0, 0, "Box", 0, printMode, sw);
                        }
                    }
                    //Copy Type
                    drHeader = dtGetConfigPage.Select(dtGetConfigPage.Columns[9].ColumnName + "= 'Copytype' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Header'");
                    if (drHeader.Length > 0 && dtGetHeaderVal.Rows.Count > 0)
                    {
                        foreach (DataRow row in drHeader)
                        {
                            SetFontStyle(row, g, dtGetHeaderVal, 0, 0, "Copytype", 0, printMode, sw);
                        }
                    }
                }
            }
            catch (Exception)
            {
                //Obj_MDI.ShowMessage("Unable to Print SetHeaderLabel", GKS_BL.ToolStripErrorMsg);
            }
        }

        /// <summary>
        /// Header Value Printing Based Config label replace Header Data
        /// </summary>
        /// <param name="g"></param>
        private void SetHeaderValue(System.Drawing.Graphics g, int printMode = 1, List<StringBuilder> sw = null)
        {
            try
            {
                DataRow[] drHeaderValue = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Value' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Header'");
                if (drHeaderValue.Length > 0)
                {
                    DataTable dtTemp = drHeaderValue.CopyToDataTable();
                    DataColumnCollection dtHeadercolumns = dtGetHeaderVal.Columns;
                    DataColumnCollection dtsplcolumns = dtGetSpecialVal.Columns;
                    for (int nCount = 0; nCount < dtTemp.Rows.Count; nCount++)
                    {
                        if (dtHeadercolumns.Contains(dtTemp.Rows[nCount][9].ToString()))
                        {
                            int nColumnCount = dtGetHeaderVal.Columns[dtTemp.Rows[nCount][9].ToString()].Ordinal;
                            SetFontStyle(dtTemp.Rows[nCount], g, dtGetHeaderVal, nColumnCount, 0, "Header", 0, printMode, sw);
                        }
                        if (dtsplcolumns.Contains(dtTemp.Rows[nCount][9].ToString()))
                        {
                            int nColumnCount = dtGetSpecialVal.Columns[dtTemp.Rows[nCount][9].ToString()].Ordinal;
                            SetFontStyle(dtTemp.Rows[nCount], g, dtGetSpecialVal, nColumnCount, 0, "Header", 0, printMode, sw);
                        }
                    }
                }
                DataRow[] drFormulaValue = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Formula' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Header'");
                if (drFormulaValue.Length > 0)
                {
                    foreach (DataRow IRow in drFormulaValue)
                    {
                        SetFontStyle(IRow, g, dtGetHeaderVal, 0, 0, "Formula", 0, printMode, sw);
                    }
                }
            }
            catch (Exception)
            {
                //Obj_MDI.ShowMessage("Unable to Print SetHeaderValue", GKS_BL.ToolStripErrorMsg);
            }
        }

        /// <summary>
        /// Body label and Data Label replace Body value
        /// Item Per Page Page Handle
        /// </summary>
        /// <param name="g"></param>
        /// <param name="e"></param>
        private void SetBody(System.Drawing.Graphics g, System.Drawing.Printing.PrintPageEventArgs e, int printMode = 1, List<StringBuilder> sw = null)
        {
            try
            {
                float pointY = 0f;
                if (dtGetConfigPage.Rows.Count > 0)
                {
                    DataRow[] drBody = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Label' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Body'");
                    if (drBody.Length > 0)
                    {
                        foreach (DataRow row in drBody)
                        {
                            SetFontStyle(row, g, null, 0, 0, "Label", 0, printMode, sw);
                        }
                    }
                }

                DataRow[] drBodyValue = dtGetConfigPage.Select("(" + dtGetConfigPage.Columns[14].ColumnName + "= 'Value' OR " + dtGetConfigPage.Columns[14].ColumnName + "='Formula' ) AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Body'");
                if (drBodyValue.Length > 0)
                {
                    DataTable dtTemp = drBodyValue.CopyToDataTable();
                    SizeF stringSize = new SizeF();
                    bool blCheck = true;
                    //if (nSRIndex > 0 && totalNumber <= nSRIndex && nSR)//|| nSR)//totalNumber == 0
                    //{
                    //    nSRPrintIndex = nSRIndex;
                    //    nSRIndex = 0;
                    //}
                    bool flag = true;
                    while (totalNumber < dtGetBodyVal.Rows.Count && flag)
                    {
                        if (Convert.ToInt32(dtTemp.Rows[0][6].ToString()) > 0 || itemsPerPage < Convert.ToInt32(dtTemp.Rows[0][5].ToString()))
                        {
                            blCheck = true;
                            // 6 --- > Continoues Page, 5 --- > Item per Page

                            // Sales Transaction Only
                            if (nTransType == 4)
                            {
                                if (!string.IsNullOrEmpty(Convert.ToString(dtGetBodyVal.Rows[totalNumber]["ProdSerial"])))
                                {
                                    pointY = float.Parse(dtTemp.Rows[0][13].ToString()) + bodyFontHeight;
                                    DrawCustomString(Convert.ToString(dtGetBodyVal.Rows[totalNumber]["ProdSerial"]),
                                        FontStyle.Italic, g, e, 35, float.Parse(dtTemp.Rows[0][13].ToString()), ref stringSize, printMode, sw, dtTemp.Rows[0], pointY);
                                    blCheck = false;
                                }
                                //if (nSRPrintIndex > 0 && nSRPrintIndex == totalNumber && nSR)
                                //{
                                //    //totalNumber -= 1;

                                //    pointY = float.Parse(dtTemp.Rows[0][13].ToString()) + bodyFontHeight;
                                //    DrawCustomString("Sales Return ", FontStyle.Bold, g, e, 10, float.Parse(dtTemp.Rows[0][13].ToString()), ref stringSize, printMode, sw, dtTemp.Rows[0], pointY);
                                //    blCheck = false; //nSR = false;
                                //}

                                //(Convert.ToString(dtGetBodyVal.Rows[totalNumber]["SR"]))
                                string str = (Convert.ToString(dtGetBodyVal.Rows[totalNumber]["SR"]));
                                if (str.Substring(0, Math.Min(str.Length, 15)) == "Saleable Return" || str.Substring(0, Math.Min(str.Length, 13)) == "Damage Return")
                                {
                                    pointY = float.Parse(dtTemp.Rows[0][13].ToString()) + bodyFontHeight;
                                    DrawCustomString(Convert.ToString(dtGetBodyVal.Rows[totalNumber]["SR"]),
                                        FontStyle.Bold, g, e, 35, float.Parse(dtTemp.Rows[0][13].ToString()), ref stringSize, printMode, sw, dtTemp.Rows[0], pointY);
                                    //totalNumber += 1;
                                    blCheck = false; nSR = false;
                                }
                            }
                            if (blCheck)
                            {
                                DataColumnCollection dtBodycolumns = dtGetBodyVal.Columns;
                                for (int nCount = 0; nCount < dtTemp.Rows.Count; nCount++)
                                {
                                    if (dtTemp.Rows[nCount][14].ToString() == "Value")
                                    {
                                        if (dtBodycolumns.Contains(dtTemp.Rows[nCount][9].ToString()))
                                        {
                                            int nColumnCount = dtGetBodyVal.Columns[dtTemp.Rows[nCount][9].ToString()].Ordinal;
                                            // Y position --- > 13
                                            pointY = float.Parse(dtTemp.Rows[nCount][13].ToString()) + bodyFontHeight;
                                            SetFontStyle(dtTemp.Rows[nCount], g, dtGetBodyVal, nColumnCount, totalNumber, "Body", pointY, printMode, sw);
                                            Font font = new Font(dtTemp.Rows[nCount][15].ToString(), Convert.ToInt32(dtTemp.Rows[nCount][16].ToString()));
                                            stringSize = (printMode == 1) ? e.Graphics.MeasureString(dtTemp.Rows[nCount][15].ToString().Trim(), font) : new SizeF();
                                        }
                                    }
                                    else if (dtTemp.Rows[nCount][14].ToString() == "Formula")
                                    {
                                        pointY = float.Parse(dtTemp.Rows[nCount][13].ToString()) + bodyFontHeight;
                                        SetFontStyle(dtTemp.Rows[nCount], g, dtGetBodyVal, 0, totalNumber, "FormulaBody", pointY, printMode, sw);
                                        Font font = new Font(dtTemp.Rows[nCount][15].ToString(), Convert.ToInt32(dtTemp.Rows[nCount][16].ToString()));
                                        stringSize = (printMode == 1) ? e.Graphics.MeasureString(dtTemp.Rows[nCount][15].ToString(), font) : new SizeF();
                                    }
                                }
                            }
                            bodyFontHeight += ((printMode == 1) ? Convert.ToInt32(dtTemp.Rows[0][27]) : 23) + stringSize.Height;
                            itemsPerPage += 1;
                            if (e != null) e.HasMorePages = false;
                            if (printMode == 0) hasMorePagesToPrint = false;
                            totalNumber += 1;

                            //if (nSRPrintIndex != totalNumber)// || nSR == false)
                            //{
                            //    totalNumber += 1;
                            //}

                            //else
                            //{
                            //    if (nSRPrint == true)
                            //    {
                            //        nSRIndex = nSRPrintIndex;
                            //        nSRPrintIndex = 0;
                            //    }
                            //    else
                            //    {
                            //        totalNumber += 1;
                            //    }
                            //}

                            if (previewLoaded && itemsPerPage == Convert.ToInt32(dtTemp.Rows[0][5].ToString()))
                            {
                                flag = false;
                                //previewLoaded = false;
                                //itemsPerPage = 0;
                            }
                        }
                        else
                        {
                            bodyFontHeight = 0;
                            SetFooterLabel((e != null) ? e.Graphics : null, e, 0, 0, pointY, printMode, sw);
                            SetFooterValue((e != null) ? e.Graphics : null, e, 0, 0, pointY, printMode, sw);
                            itemsPerPage = 0;// (!previewLoaded) ? 0 : itemsPerPage;
                            pageNo += 1;

                            if (e != null) e.HasMorePages = true;
                            if (printMode == 0) hasMorePagesToPrint = true;
                            return;
                        }
                    }

                }
                // Continues page.

                SetFooterLabel((e != null) ? e.Graphics : null, e, 1, 0, pointY, printMode, sw);
                SetFooterValue((e != null) ? e.Graphics : null, e, 1, 0, pointY, printMode, sw);
                if (g != null) g.Dispose();
            }
            catch (Exception ex)
            {
                //Obj_MDI.ShowMessage("Unable to Print setBody", GKS_BL.ToolStripErrorMsg);
                //Panthera.Utilities.ErrorLogger.Instance.Log(ex);
            }
        }

        private void DrawCustomString(string strCustom, FontStyle obj, System.Drawing.Graphics g, PrintPageEventArgs e, float x, float y, ref SizeF stringSize, int printMode = 1, List<StringBuilder> sw = null, DataRow row = null, float Ypoint = 0f)
        {
            try
            {
                int X, Y;
                int line = 1, character = 1, width = 1;
                bool rightAlign = false;
                string format = "";
                if (printMode == 0)
                {
                    X = Convert.ToInt32(x + 40);
                    float Yfinal = float.Parse(row[13].ToString()) + Ypoint;
                    Y = Convert.ToInt32(Ypoint);
                    character = (int)(X / fHVal) + 1;
                    line = (int)(Y / fVVal) + 1;
                    width = strCustom.Length;
                    rightAlign = (row[25].ToString() == "1");
                    format = "{0," + ((rightAlign) ? "" : "-") + width + "}";
                }

                if (printMode == 1)
                {
                    //Font set
                    Font fontControl = new Font("Microsoft Sans Serif", 10, obj);
                    RectangleF drawRect = new RectangleF(x, y + bodyFontHeight, 180, 22);
                    //String Alignment
                    StringFormat strFrmt = new StringFormat(StringFormatFlags.MeasureTrailingSpaces);
                    strFrmt.LineAlignment = StringAlignment.Far;
                    g.DrawString(strCustom, fontControl, blackBrush, drawRect, strFrmt);
                    stringSize = e.Graphics.MeasureString(strCustom.Trim(), fontControl);
                }
                else
                {
                    string toWrite = strCustom;
                    if (toWrite.Length > width)
                        toWrite = (rightAlign) ? toWrite.Substring(toWrite.Length - width, width) : toWrite.Substring(0, width);
                    toWrite = string.Format(format, toWrite);
                    sw[line - 1].Remove(character, width)
                                .Insert(character, toWrite);
                }
            }
            catch (Exception ex)
            {
                throw;
            }
        }

        /// <summary>
        /// Footer label 
        /// Handle Footer on Everypage and Amount in Words,Tax Type Wise Printing
        /// </summary>
        /// <param name="g"></param>
        /// <param name="e"></param>
        /// <param name="nFooterValue"></param>
        /// <param name="strFooterValue"></param>
        /// <param name="fPointParamY">Handle Cut Sheet or Continues Paper</param>
        private void SetFooterLabel(System.Drawing.Graphics g, System.Drawing.Printing.PrintPageEventArgs e, int nFooterValue, int? strFooterValue = null, float? fPointParamY = null, int printMode = 1, List<StringBuilder> sw = null)
        {
            try
            {
                DataRow[] drFooter = dtGetConfigPage.Select(
                                                            dtGetConfigPage.Columns[14].ColumnName + "= 'Label' OR "
                                                            + dtGetConfigPage.Columns[14].ColumnName + "= 'Image' OR "
                                                            + dtGetConfigPage.Columns[14].ColumnName + "= 'Box' OR "
                                                            + dtGetConfigPage.Columns[14].ColumnName + "= 'gksQRCode' OR "
                                                            + dtGetConfigPage.Columns[14].ColumnName + "= 'gksBarCode' AND "
                                                            + dtGetConfigPage.Columns[18].ColumnName + "= 'Footer'"
                                                           );
                if (drFooter.Length > 0)
                {
                    float fPointY = 0;
                    if (fPointParamY.HasValue)
                    {
                        fPointY = (float)fPointParamY;
                    }
                    foreach (DataRow row in drFooter)
                    {
                        // Type --> Header or Body or Footer
                        if (row[18].ToString() == "Footer")
                        {
                            // 13 - -> Y position
                            decimal firstFooterpointY = Convert.ToDecimal(row[13].ToString());
                            YPositionDiff = (fPointY - (float)firstFooterpointY);
                            YPositionDiff += (printMode == 1) ? 20 : 25;
                            break;
                        }

                    }
                    foreach (DataRow row in drFooter)
                    {
                        // 6    --- > Continues Sheet
                        if (Convert.ToInt32(row[6].ToString()) == 0)
                        {
                            if (ValidateFooter(row) == true)
                            {
                                SetFontStyle(row, g, null, 0, 0, row[14].ToString(), 0, printMode, sw);
                            }
                        }
                        if (Convert.ToInt32(row[6].ToString()) == 1)
                        {
                            if (row[14].ToString() == "Label" && row[18].ToString() == "Footer")
                            {
                                SetFontStyle(row, g, null, 0, 0, "Footer Label", YPositionDiff, printMode, sw);
                            }
                            if (row[14].ToString() == "Image" && row[18].ToString() == "Footer")
                            {
                                SetFontStyle(row, g, null, 0, 0, "Image", YPositionDiff, printMode, sw);
                            }
                            if (row[14].ToString() == "gksBarCode" && row[18].ToString() == "Footer")
                            {
                                SetFontStyle(row, g, null, 0, 0, "gksBarCode", YPositionDiff, printMode, sw);
                            }
                            if (row[14].ToString() == "gksQRCode" && row[18].ToString() == "Footer")
                            {
                                SetFontStyle(row, g, null, 0, 0, "gksQRCode", YPositionDiff, printMode, sw);
                            }
                            if (row[14].ToString() == "Box" && row[18].ToString() == "Footer")
                            {
                                SetFontStyle(row, g, null, 0, 0, "Box", YPositionDiff, printMode, sw);
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                //Obj_MDI.ShowMessage("setFooterLabel", GKS_BL.ToolStripErrorMsg);
                //GKS_BL.BL_ExceptionMsg("Print", "SetFooterLabel", ex);
            }
        }

        /// <summary>
        /// Footer  data label replace footer value
        /// Handle Footer on Everypage and Amount in Words,Tax Type Wise Printing
        /// </summary>
        /// <param name="g"></param>
        /// <param name="e"></param>
        /// <param name="nFooterValue"></param>
        /// <param name="strFooterValue"></param>
        /// <param name="fPointParamY"></param>
        private void SetFooterValue(System.Drawing.Graphics g, System.Drawing.Printing.PrintPageEventArgs e, int nFooterValue, int? strFooterValue = null, float? fPointParamY = null, int printMode = 1, List<StringBuilder> sw = null)
        {
            try
            {
                DataRow[] drFooterValue = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Value' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Footer'");
                bool isContinous = false;

                if (drFooterValue.Length > 0)
                {
                    DataTable dtTemp = drFooterValue.CopyToDataTable();
                    DataColumnCollection dtHeadercolumns = dtGetHeaderVal.Columns;
                    DataColumnCollection dtsplcolumns = dtGetSpecialVal.Columns;
                    if (dtsplcolumns.Contains("Tax Percentage"))
                    {
                        dtsplcolumns.Remove("Tax Percentage");
                    }
                    if (dtsplcolumns.Contains("Tax Amount"))
                    {
                        dtsplcolumns.Remove("Tax Amount");
                    }
                    if (dtsplcolumns.Contains("Tax Value"))
                    {
                        dtsplcolumns.Remove("Tax Value");
                    }
                    if (dtsplcolumns.Contains("Doc Prefix"))
                    {
                        dtsplcolumns.Remove("Doc Prefix");
                    }
                    if (dtsplcolumns.Contains("GST Tax Amount"))
                    {
                        dtsplcolumns.Remove("GST Tax Amount");
                    }
                    if (dtsplcolumns.Contains("CGST %"))
                    {
                        dtsplcolumns.Remove("CGST %");
                    }
                    if (dtsplcolumns.Contains("CGST Amount"))
                    {
                        dtsplcolumns.Remove("CGST Amount");
                    }
                    if (dtsplcolumns.Contains("SGST %"))
                    {
                        dtsplcolumns.Remove("SGST %");
                    }
                    if (dtsplcolumns.Contains("SGST Amount"))
                    {
                        dtsplcolumns.Remove("SGST Amount");
                    }
                    if (dtsplcolumns.Contains("UTGST %"))
                    {
                        dtsplcolumns.Remove("UTGST %");
                    }
                    if (dtsplcolumns.Contains("UTGST Amount"))
                    {
                        dtsplcolumns.Remove("UTGST Amount");
                    }
                    if (dtsplcolumns.Contains("IGST %"))
                    {
                        dtsplcolumns.Remove("IGST %");
                    }
                    if (dtsplcolumns.Contains("IGST Amount"))
                    {
                        dtsplcolumns.Remove("IGST Amount");
                    }
                    if (dtsplcolumns.Contains("GCESS %"))
                    {
                        dtsplcolumns.Remove("GCESS %");
                    }
                    if (dtsplcolumns.Contains("GCESS Amount"))
                    {
                        dtsplcolumns.Remove("GCESS Amount");
                    }
                    if (dtsplcolumns.Contains("ICESS %"))
                    {
                        dtsplcolumns.Remove("ICESS %");
                    }
                    if (dtsplcolumns.Contains("ICESS Amount"))
                    {
                        dtsplcolumns.Remove("ICESS Amount");
                    }
                    for (int nCount = 0; nCount < dtTemp.Rows.Count; nCount++)
                    {
                        if (dtHeadercolumns.Contains(dtTemp.Rows[nCount][9].ToString()))
                        {
                            int nColumnCount = dtGetHeaderVal.Columns[dtTemp.Rows[nCount][9].ToString()].Ordinal;
                            isContinous = (Convert.ToInt32(dtTemp.Rows[nCount][6].ToString()) == 1);

                            if (Convert.ToInt32(dtTemp.Rows[nCount][6].ToString()) == 0)
                            {
                                if (ValidateFooterForTable(dtTemp, nCount) == true)
                                {
                                    if (dtGetHeaderVal.Columns[nColumnCount].ColumnName == "Amt in Words")
                                    {
                                        SetFontStyle(dtTemp.Rows[nCount], g, dtGetHeaderVal, nColumnCount, 0, "Amt in Words", 0, printMode, sw);
                                    }
                                    else
                                    {
                                        SetFontStyle(dtTemp.Rows[nCount], g, dtGetHeaderVal, nColumnCount, 0, "Footer Value", 0, printMode, sw);
                                    }
                                }
                            }
                            if (Convert.ToInt32(dtTemp.Rows[nCount][6].ToString()) == 1)
                            {
                                if (dtGetHeaderVal.Columns[nColumnCount].ColumnName == "Amt in Words")
                                {
                                    SetFontStyle(dtTemp.Rows[nCount], g, dtGetHeaderVal, nColumnCount, 0, "Amt in Words", YPositionDiff, printMode, sw);
                                }
                                else
                                {
                                    SetFontStyle(dtTemp.Rows[nCount], g, dtGetHeaderVal, nColumnCount, 0, "Footer Value", YPositionDiff, printMode, sw);
                                }
                            }
                        }
                        if (dtsplcolumns.Contains(dtTemp.Rows[nCount][9].ToString()))
                        {
                            int nColumnCount = dtGetSpecialVal.Columns[dtTemp.Rows[nCount][9].ToString()].Ordinal;
                            if (Convert.ToInt32(dtTemp.Rows[0][6].ToString()) == 0)
                            {
                                if (ValidateFooterForTable(dtTemp, nCount) == true)
                                {
                                    SetFontStyle(dtTemp.Rows[nCount], g, dtGetSpecialVal, nColumnCount, 0, "Every Page Footer Value", 0, printMode, sw);
                                }
                            }
                            if (Convert.ToInt32(dtTemp.Rows[0][6].ToString()) == 1)
                            {
                                SetFontStyle(dtTemp.Rows[nCount], g, dtGetSpecialVal, nColumnCount, 0, "Every Page Footer Value", YPositionDiff, printMode, sw);
                            }
                        }
                    }
                }
                DataRow[] drFormulaValue = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Formula' AND " + dtGetConfigPage.Columns[18].ColumnName + "= 'Footer'");
                if (drFormulaValue.Length > 0)
                {
                    foreach (DataRow IRow in drFormulaValue)
                    {
                        if (ValidateFooter(IRow) == true)
                        {
                            SetFontStyle(IRow, g, dtGetHeaderVal, 0, 0, "Formula", Convert.ToInt32(IRow[6].ToString()) == 0 ? 0 : YPositionDiff, printMode, sw);
                        }
                    }
                }
                DataRow[] drGSTInfo = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Value' AND "
                    + dtGetConfigPage.Columns[18].ColumnName + "= 'Footer' AND ("
                    + dtGetConfigPage.Columns[9].ColumnName + "= 'GST Tax Amount' OR "
                    + dtGetConfigPage.Columns[9].ColumnName + "= 'CGST %' OR " + dtGetConfigPage.Columns[9].ColumnName + "= 'SGST %' OR "
                    + dtGetConfigPage.Columns[9].ColumnName + "= 'UTGST %' OR " + dtGetConfigPage.Columns[9].ColumnName + "= 'IGST %' OR "
                    + dtGetConfigPage.Columns[9].ColumnName + "= 'GCESS %' OR " + dtGetConfigPage.Columns[9].ColumnName + "= 'ICESS %' OR "
                    + dtGetConfigPage.Columns[9].ColumnName + "= 'CGST Amount' OR " + dtGetConfigPage.Columns[9].ColumnName + "= 'SGST Amount' OR "
                    + dtGetConfigPage.Columns[9].ColumnName + "= 'GCESS Amount' OR " + dtGetConfigPage.Columns[9].ColumnName + "= 'ICESS Amount' OR "
                    + dtGetConfigPage.Columns[9].ColumnName + "= 'UTGST Amount' OR " + dtGetConfigPage.Columns[9].ColumnName + "= 'IGST Amount')");
                if (drGSTInfo.Length > 0)
                {
                    //DataTable dtgstprint = GKS_BL.BL_ExecuteSqlQuery("select AppValue from tblAppConfig where AppId = 166");
                    int nHSNinGSTPrint = 0;// dtgstprint.Rows.Count > 0 ? Convert.ToInt32(dtgstprint.Rows[0][0].ToString()) : 0;
                    DataTable dt = drGSTInfo.CopyToDataTable();
                    float GSTFontHeight = 0, pointY = 0f;
                    //DataTable dtGetGSTSplits = GKS_BL.BL_ExecuteParamSP("uspGetGSTforPrinting", nTransType, nTransId);
                    DataTable dtGetGSTSplits = new DataTable();
                    if (nHSNinGSTPrint == 1)
                    {
                        dtGetGSTSplits = GKS_BL.BL_ExecuteParamSP("uspGetGSTforPrinting", nTransType, nTransId);
                    }
                    else
                    {
                        dtGetGSTSplits = GKS_BL.BL_ExecuteParamSP("uspGetGSTforPrintingWOHSN", nTransType, nTransId);
                    }
                    DataColumnCollection dc = dtGetGSTSplits.Columns;
                    SizeF stringSize = new SizeF();
                    if (dtGetGSTSplits.Rows.Count > 0)
                    {
                        for (int nRow = 0; nRow < dtGetGSTSplits.Rows.Count; nRow++)
                        {
                            for (int nColumn = 0; nColumn < drGSTInfo.Length; nColumn++)
                            {
                                Font font = new Font(drGSTInfo[nColumn][15].ToString(), Convert.ToInt32(drGSTInfo[nColumn][16].ToString()));
                                if ((dc.Contains("GST Tax Amount") && drGSTInfo[nColumn][9].ToString() == "GST Tax Amount")
                                    || (dc.Contains("ICESS Amount") && drGSTInfo[nColumn][9].ToString() == "ICESS Amount")
                                    || (dc.Contains("ICESS %") && drGSTInfo[nColumn][9].ToString() == "ICESS %")
                                    || (dc.Contains("GCESS Amount") && drGSTInfo[nColumn][9].ToString() == "GCESS Amount")
                                    || (dc.Contains("GCESS %") && drGSTInfo[nColumn][9].ToString() == "GCESS %")
                                    || (dc.Contains("IGST Amount") && drGSTInfo[nColumn][9].ToString() == "IGST Amount")
                                    || (dc.Contains("IGST %") && drGSTInfo[nColumn][9].ToString() == "IGST %")
                                    || (dc.Contains("UTGST Amount") && drGSTInfo[nColumn][9].ToString() == "UTGST Amount")
                                    || (dc.Contains("UTGST %") && drGSTInfo[nColumn][9].ToString() == "UTGST %")
                                    || (dc.Contains("SGST Amount") && drGSTInfo[nColumn][9].ToString() == "SGST Amount")
                                    || (dc.Contains("SGST %") && drGSTInfo[nColumn][9].ToString() == "SGST %")
                                    || (dc.Contains("CGST Amount") && drGSTInfo[nColumn][9].ToString() == "CGST Amount")
                                    || (dc.Contains("CGST %") && drGSTInfo[nColumn][9].ToString() == "CGST %"))
                                {
                                    int nColumnCount = dtGetGSTSplits.Columns[drGSTInfo[nColumn][9].ToString()].Ordinal;
                                    pointY = (float.Parse(drGSTInfo[nColumn][13].ToString()) + GSTFontHeight) + ((isContinous) ? YPositionDiff : 0);
                                    if (ValidateFooter(drGSTInfo[nColumn]) == true)
                                    {
                                        SetFontStyle(drGSTInfo[nColumn], g, dtGetGSTSplits, nColumnCount, nRow, "Body", pointY, printMode, sw);
                                        stringSize = (printMode == 1) ? e.Graphics.MeasureString(dtGetGSTSplits.Rows[nRow][nColumnCount].ToString().Trim(), font) : new SizeF();
                                    }
                                }
                            }
                            GSTFontHeight += (printMode == 1) ? stringSize.Height : stringSize.Height + 23;
                        }
                    }
                }
                DataRow[] drTaxWiseValue = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Value' AND "
                    + dtGetConfigPage.Columns[18].ColumnName + "= 'Footer' AND ("
                    + dtGetConfigPage.Columns[9].ColumnName + "= 'Tax Value' OR  "
                    + dtGetConfigPage.Columns[9].ColumnName + "= 'Tax Percentage' OR  "
                    + dtGetConfigPage.Columns[9].ColumnName + "= 'Tax Amount' OR "
                    + dtGetConfigPage.Columns[9].ColumnName + "= 'Doc Prefix')");
                if (drTaxWiseValue.Length > 0)
                {
                    DataTable dtTax = new DataTable();
                    SizeF stringSize = new SizeF();
                    float TaxWiseFontHeight = 0;
                    DataTable dtValue = TaxWisePrint(dtGetBodyVal, drTaxWiseValue);
                    if (nTransType == 4)
                    {
                        if (dtValue.Columns.Contains("Doc Prefix"))
                        {
                            dtTax = dtValue.Select("[Doc Prefix]=15").CopyToDataTable();
                        }
                        else
                        {
                            dtTax = dtValue.Select().CopyToDataTable();
                        }
                    }
                    if (dtValue != null && dtValue.Rows.Count > 0)
                    {
                        DataColumnCollection dtcolumns = dtValue.Columns;
                        DataTable dtCopy = dtValue.Clone();
                        DataTable dtDistinct = new DataTable();
                        float pointY = 0f;
                        if (nTransType == 4)
                        {
                            dtDistinct = dtTax.DefaultView.ToTable(true, dtTax.Columns["Tax Percentage"].ColumnName);
                        }
                        else
                        {
                            dtDistinct = dtValue.DefaultView.ToTable(true, dtValue.Columns["Tax Percentage"].ColumnName);
                        }
                        for (int i = 0; i < dtDistinct.Rows.Count; i++)
                        {
                            DataRow drNew = dtCopy.NewRow();

                            for (int nConfig = 0; nConfig < drTaxWiseValue.Length; nConfig++)
                            {
                                if (nTransType == 4)
                                {
                                    if (dtcolumns.Contains("Tax Percentage") && drTaxWiseValue[nConfig][9].ToString() == "Tax Percentage")
                                    {
                                        drNew["Tax Percentage"] = dtTax.Rows[i]["Tax Percentage"].ToString();
                                    }
                                    if (dtcolumns.Contains("Tax Value") && drTaxWiseValue[nConfig][9].ToString() == "Tax Value")
                                    {
                                        decimal dTaxValue = Convert.ToDecimal(dtTax.Compute("SUM([Tax Value])", "[Tax Percentage] =" + dtDistinct.Rows[i]["Tax Percentage"].ToString()));
                                        drNew["Tax Value"] = dTaxValue;
                                    }
                                    if (dtcolumns.Contains("Tax Amount") && drTaxWiseValue[nConfig][9].ToString() == "Tax Amount")
                                    {
                                        decimal dTaxAmt = Convert.ToDecimal(dtTax.Compute("SUM([Tax Amount])", "[Tax Percentage] =" + dtDistinct.Rows[i]["Tax Percentage"].ToString()));
                                        drNew["Tax Amount"] = dTaxAmt;
                                    }
                                }
                                else
                                {
                                    if (dtcolumns.Contains("Doc Prefix") && drTaxWiseValue[nConfig][9].ToString() == "Doc Prefix")
                                    {
                                        dtValue.Columns.Remove("Doc Prefix");
                                    }
                                    if (dtcolumns.Contains("Tax Percentage") && drTaxWiseValue[nConfig][9].ToString() == "Tax Percentage")
                                    {
                                        drNew["Tax Percentage"] = dtDistinct.Rows[i]["Tax Percentage"].ToString();
                                    }

                                    if (dtcolumns.Contains("Tax Value") && drTaxWiseValue[nConfig][9].ToString() == "Tax Value")
                                    {
                                        decimal dTaxValue = (decimal)dtValue.Compute("SUM([Tax Value])", "[Tax Percentage] =" + dtDistinct.Rows[i]["Tax Percentage"].ToString());
                                        drNew["Tax Value"] = dTaxValue;
                                    }
                                    if (dtcolumns.Contains("Tax Amount") && drTaxWiseValue[nConfig][9].ToString() == "Tax Amount")
                                    {
                                        decimal dTaxAmt = (decimal)dtValue.Compute("SUM([Tax Amount])", "[Tax Percentage] =" + dtDistinct.Rows[i]["Tax Percentage"].ToString());
                                        drNew["Tax Amount"] = dTaxAmt;
                                    }
                                }
                            }
                            dtCopy.Rows.Add(drNew);
                        }
                        if (dtCopy.Columns.Count > 0)
                        {
                            if (dtCopy.Columns.Count == 4)
                            {
                                dtCopy.Columns.Remove("Doc Prefix");
                            }
                        }
                        DataColumnCollection dtClonecolumns = dtCopy.Columns;
                        for (int i = 0; i < dtCopy.Rows.Count; i++)
                        {
                            for (int nConfig = 0; nConfig < drTaxWiseValue.Length; nConfig++)
                            {
                                Font font = new Font(drTaxWiseValue[nConfig][15].ToString(), Convert.ToInt32(drTaxWiseValue[nConfig][16].ToString()));
                                if (dtcolumns.Contains("Tax Percentage") && drTaxWiseValue[nConfig][9].ToString() == "Tax Percentage")
                                {
                                    int nColumnCount = dtCopy.Columns[drTaxWiseValue[nConfig][9].ToString()].Ordinal;
                                    pointY = (float.Parse(drTaxWiseValue[nConfig][13].ToString()) + TaxWiseFontHeight) + ((isContinous) ? YPositionDiff : 0);
                                    if (ValidateFooter(drTaxWiseValue[nConfig]) == true)
                                    {
                                        SetFontStyle(drTaxWiseValue[nConfig], g, dtCopy, nColumnCount, i, "Body", pointY, printMode, sw);
                                        stringSize = e.Graphics.MeasureString(dtCopy.Rows[i][nColumnCount].ToString().Trim(), font);
                                    }
                                }
                                if (dtClonecolumns.Contains("Tax Value") && drTaxWiseValue[nConfig][9].ToString() == "Tax Value")
                                {
                                    int nColumnCount = dtCopy.Columns[drTaxWiseValue[nConfig][9].ToString()].Ordinal;

                                    pointY = (float.Parse(drTaxWiseValue[nConfig][13].ToString()) + TaxWiseFontHeight) + ((isContinous) ? YPositionDiff : 0);
                                    if (ValidateFooter(drTaxWiseValue[nConfig]) == true)
                                    {
                                        SetFontStyle(drTaxWiseValue[nConfig], g, dtCopy, nColumnCount, i, "Body", pointY, printMode, sw);
                                        stringSize = e.Graphics.MeasureString(dtCopy.Rows[i][nColumnCount].ToString().Trim(), font);
                                    }
                                }
                                if (dtcolumns.Contains("Tax Amount") && drTaxWiseValue[nConfig][9].ToString() == "Tax Amount")
                                {
                                    int nColumnCount = dtCopy.Columns[drTaxWiseValue[nConfig][9].ToString()].Ordinal;

                                    pointY = (float.Parse(drTaxWiseValue[nConfig][13].ToString()) + TaxWiseFontHeight) + ((isContinous) ? YPositionDiff : 0);
                                    if (ValidateFooter(drTaxWiseValue[nConfig]) == true)
                                    {
                                        SetFontStyle(drTaxWiseValue[nConfig], g, dtCopy, nColumnCount, i, "Body", pointY, printMode, sw);
                                        stringSize = e.Graphics.MeasureString(dtCopy.Rows[i][nColumnCount].ToString().Trim(), font);
                                    }
                                }
                            }
                            TaxWiseFontHeight += stringSize.Height;
                        }
                    }
                }
                DataRow[] drGSTTaxWiseValue = dtGetConfigPage.Select(dtGetConfigPage.Columns[14].ColumnName + "= 'Value' AND "
                   + dtGetConfigPage.Columns[18].ColumnName + "= 'Footer' AND ("
                   + dtGetConfigPage.Columns[9].ColumnName + "= 'VGST Type' OR "
                    + dtGetConfigPage.Columns[9].ColumnName + "= 'VGST %' OR "
                    + dtGetConfigPage.Columns[9].ColumnName + "= 'VGST Amt' OR "
                    + dtGetConfigPage.Columns[9].ColumnName + "= 'VTaxableValue')");
                if (drGSTTaxWiseValue.Length > 0)
                {
                    DataTable dt = drGSTTaxWiseValue.CopyToDataTable();
                    float GSTFontHeight = 0, pointY = 0f;
                    DataTable dtGetGSTSplits = GKS_BL.BL_ExecuteParamSP("uspGetVGSTDataforPrinting", nTransType, nTransId);
                    DataColumnCollection dc = dtGetGSTSplits.Columns;
                    SizeF stringSize = new SizeF();
                    if (dtGetGSTSplits.Rows.Count > 0)
                    {
                        for (int nRow = 0; nRow < dtGetGSTSplits.Rows.Count; nRow++)
                        {
                            for (int nColumn = 0; nColumn < drGSTTaxWiseValue.Length; nColumn++)
                            {
                                Font font = new Font(drGSTTaxWiseValue[nColumn][15].ToString(), Convert.ToInt32(drGSTTaxWiseValue[nColumn][16].ToString()));
                                if ((dc.Contains("VGST Type") && drGSTTaxWiseValue[nColumn][9].ToString() == "VGST Type")
                                    || (dc.Contains("VGST %") && drGSTTaxWiseValue[nColumn][9].ToString() == "VGST %")
                                    || (dc.Contains("VGST Amt") && drGSTTaxWiseValue[nColumn][9].ToString() == "VGST Amt")
                                    || (dc.Contains("VTaxableValue") && drGSTTaxWiseValue[nColumn][9].ToString() == "VTaxableValue"))
                                {
                                    int nColumnCount = dtGetGSTSplits.Columns[drGSTTaxWiseValue[nColumn][9].ToString()].Ordinal;
                                    pointY = (float.Parse(drGSTTaxWiseValue[nColumn][13].ToString()) + GSTFontHeight) + ((isContinous) ? YPositionDiff : 0);
                                    if (ValidateFooter(drGSTTaxWiseValue[nColumn]) == true)
                                    {
                                        SetFontStyle(drGSTTaxWiseValue[nColumn], g, dtGetGSTSplits, nColumnCount, nRow, "Body", pointY, printMode, sw);
                                        stringSize = (printMode == 1) ? e.Graphics.MeasureString(dtGetGSTSplits.Rows[nRow][nColumnCount].ToString().Trim(), font) : new SizeF();
                                    }
                                }
                            }
                            GSTFontHeight += (printMode == 1) ? stringSize.Height : stringSize.Height + 23;
                        }
                    }
                }
            }
            catch (Exception ex)
            {

            }
        }

        /// <summary>
        /// Validate Footer on EVery page or Not 
        /// </summary>
        /// <param name="dr">Rowise Check From Footer Table</param>
        /// <returns>Print for Retrun true</returns>
        private bool ValidateFooter(DataRow dr)
        {
            bool bl = false;
            try
            {
                // 8 --- > Footer on EVery page
                if (Convert.ToInt32(dr[8].ToString()) == 1)
                {
                    bl = true;
                }
                else if (Convert.ToInt32(dr[8].ToString()) == 0)
                {
                    if (Convert.ToInt32(dr[19].ToString()) == 1 || totalNumber == dtGetBodyVal.Rows.Count)
                    {
                        bl = true;
                    }
                }
            }
            catch (Exception)
            {
                throw;
            }
            return bl;
        }

        /// <summary>
        /// Validate Footer on EVery page or Not in Table
        /// </summary>
        /// <param name="dt">Rowise Check From Footer Table</param>
        /// <param name="nRowCount">Fetched Row</param>
        /// <returns>Print for Retrun true</returns>
        private bool ValidateFooterForTable(DataTable dt, int nRowCount)
        {
            bool bl = false;
            try
            {
                if (Convert.ToInt32(dt.Rows[nRowCount][8].ToString()) == 1)
                {
                    bl = true;
                }
                else
                {
                    if (Convert.ToInt32(dt.Rows[nRowCount][19].ToString()) == 1 || totalNumber == dtGetBodyVal.Rows.Count)
                    {
                        bl = true;
                    }
                }
            }
            catch (Exception)
            {
                throw;
            }
            return bl;
        }

        /// <summary>
        /// Method Handle All Design Fonts and style for loop all things for header and footer
        /// </summary>
        /// <param name="row"></param>
        /// <param name="g"></param>
        /// <param name="RowValue"></param>
        /// <param name="ColumnCount"></param>
        /// <param name="RowCount"></param>
        /// <param name="Mode"></param>
        /// <param name="Ypoint"></param>
        private void SetFontStyle(DataRow row, System.Drawing.Graphics g, DataTable RowValue, int ColumnCount, int RowCount, string Mode, float Ypoint, int printMode = 1, List<StringBuilder> sw = null)
        {
            try
            {
                int X, Y;
                int line = 1, character = 1, width = 1;
                bool rightAlign = false;
                string format = "";
                if (printMode == 0)
                {
                    X = Convert.ToInt32(row[12].ToString());
                    float Yfinal = float.Parse(row[13].ToString()) + Ypoint;
                    Y = (Mode == "Body" || Mode == "FormulaBody") ? Convert.ToInt32(Ypoint)
                        : (Mode == "Footer Value" || Mode == "Footer Label" || Mode == "Amt in Words" || Mode == "Formula") ? Convert.ToInt32(Yfinal)
                        : Convert.ToInt32(row[13].ToString());
                    character = (int)(X / fHVal) + 1;
                    line = (int)(Y / fVVal) + 1;
                    width = (int)(Convert.ToInt32(row[10].ToString()) / fHVal);
                    rightAlign = (row[25].ToString() == "1");
                    format = "{0," + ((rightAlign) ? "" : "-") + width + "}";
                }

                // 12, 13 -- > X and Y position, 
                // 10, 11 -- > Width and Height
                // 22 - Bold, 23 - Italic, 24 - Underline
                // Right Align -- >  25
                Font fontControl = null;
                if (row[22].ToString() == "0" && row[23].ToString() == "0" && row[24].ToString() == "0")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Regular);
                }
                else if (row[22].ToString() == "1" && row[23].ToString() == "0" && row[24].ToString() == "0")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Bold);
                }
                else if (row[22].ToString() == "1" && row[23].ToString() == "1" && row[24].ToString() == "0")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Bold | FontStyle.Italic);
                }
                else if (row[22].ToString() == "1" && row[23].ToString() == "0" && row[24].ToString() == "1")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Bold | FontStyle.Underline);
                }
                else if (row[22].ToString() == "0" && row[23].ToString() == "0" && row[24].ToString() == "1")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Underline);
                }
                else if (row[22].ToString() == "0" && row[23].ToString() == "1" && row[24].ToString() == "1")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Italic | FontStyle.Underline);
                }
                else if (row[22].ToString() == "1" && row[23].ToString() == "1" && row[24].ToString() == "1")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Italic | FontStyle.Italic | FontStyle.Underline);
                }
                else if (row[22].ToString() == "0" && row[23].ToString() == "1" && row[24].ToString() == "0")
                {
                    fontControl = new Font(row[15].ToString(), Convert.ToInt16(row[16]), FontStyle.Italic);
                }
                string aabb = row[33].ToString();
                //String Alignment
                StringFormat strFrmt = new StringFormat
                {
                    FormatFlags = aabb == "0" ? StringFormatFlags.NoWrap : StringFormatFlags.FitBlackBox,
                    Trimming = StringTrimming.None
                };
                strFrmt.LineAlignment = StringAlignment.Far;
                if (row[25].ToString() == "1")
                {
                    strFrmt.Alignment = StringAlignment.Far;
                }

                RectangleF drawRect = new RectangleF();
                if (printMode == 1)
                {
                    if (Mode == "Body" || Mode == "FormulaBody")
                    {
                        drawRect = new RectangleF(float.Parse(row[12].ToString()), Ypoint, float.Parse(row[10].ToString()), float.Parse(row[11].ToString()));
                    }
                    else if (Mode == "Footer Value" || Mode == "Footer Label" || Mode == "Amt in Words" || Mode == "Formula")
                    {
                        float Yfinal = float.Parse(row[13].ToString()) + Ypoint;
                        drawRect = new RectangleF(float.Parse(row[12].ToString()), Yfinal, float.Parse(row[10].ToString()), float.Parse(row[11].ToString()));
                    }
                    else
                    {
                        drawRect = new RectangleF(
                            float.Parse(row[12].ToString()),
                            float.Parse(row[13].ToString()),
                            float.Parse(row[10].ToString()),
                            float.Parse(row[11].ToString()));
                    }
                }

                if (Mode == "Header" || Mode == "Body" || Mode == "Footer Value" || Mode == "Every Page Footer Value")
                {
                    if (row[9].ToString() != "Page No.") // Label Name -- > 9 
                    {
                        if (row[9].ToString() == "V_Line")
                        {
                            int X_Point = Convert.ToInt32(drawRect.X),
                                Starting_Y_Point = Convert.ToInt32(row[13].ToString()) + Convert.ToInt32(Ypoint),
                                Ending_Y_Point = Starting_Y_Point + Convert.ToInt32(drawRect.Height);

                            g.DrawLine(new Pen(Color.Black, 1), X_Point, Starting_Y_Point, X_Point, Ending_Y_Point);
                        }
                        else if (row[9].ToString() == "H_Line")
                        {
                            int Y_Point = Convert.ToInt32(row[13].ToString()) + Convert.ToInt32(Ypoint) + 10,
                                Starting_X_Point = Convert.ToInt32(row[12].ToString()),
                                Ending_X_Point = Starting_X_Point + Convert.ToInt32(drawRect.Width);

                            g.DrawLine(new Pen(Color.Black, 1), Starting_X_Point, Y_Point, Ending_X_Point, Y_Point);
                        }
                        else
                        {
                            if (RowValue.Columns[ColumnCount].DataType == typeof(decimal))
                            {
                                if (printMode == 1)
                                {//GKS_BL.BL_RoundOffDecimal
                                    g.DrawString(GKS_BL.BL_RoundOffTwoDecimal(RowValue.Rows[RowCount][ColumnCount].ToString()).ToString(), fontControl, blackBrush, drawRect, strFrmt);
                                }
                                else
                                {//GKS_BL.BL_RoundOffDecimal
                                    string toWrite = GKS_BL.BL_RoundOffTwoDecimal(RowValue.Rows[RowCount][ColumnCount].ToString()).ToString();
                                    if (toWrite.Length > width)
                                        toWrite = (rightAlign) ? toWrite.Substring(toWrite.Length - width, width) : toWrite.Substring(0, width);
                                    toWrite = string.Format(format, toWrite);
                                    sw[line - 1].Remove(character, width)
                                                .Insert(character, toWrite);
                                }
                            }
                            else
                            {
                                if (printMode == 1)
                                    g.DrawString(RowValue.Rows[RowCount][ColumnCount].ToString(), fontControl, blackBrush, drawRect, strFrmt);
                                else
                                {
                                    string toWrite = RowValue.Rows[RowCount][ColumnCount].ToString();
                                    if (toWrite.Length > width)
                                        toWrite = (rightAlign) ? toWrite.Substring(toWrite.Length - width, width) : toWrite.Substring(0, width);
                                    toWrite = string.Format(format, toWrite);
                                    sw[line - 1].Remove(character, width)
                                                .Insert(character, toWrite);
                                }
                            }
                        }
                    }
                    else
                    {

                        if (printMode == 1)
                        {
                            string[] strr = row[32].ToString().Split(',');
                            if (strr.Length > 2)
                            {
                                nA = GKS_BL.BL_nValidation(strr[0].ToString());
                                nR = GKS_BL.BL_nValidation(strr[1].ToString());
                                nG = GKS_BL.BL_nValidation(strr[2].ToString());
                                nB = GKS_BL.BL_nValidation(strr[3].ToString());
                            }
                            Color clr = Color.FromArgb(nR, nG, nB);
                            blackBrush = new SolidBrush(clr);
                            //g.DrawString(pageNo.ToString(), fontControl, blackBrush, drawRect, strFrmt);

                            if (dtGetBodyVal.Rows.Count > 0 && GKS_BL.BL_nValidation(dtGetConfigPage.Rows[0]["DetailItemPerPage"].ToString()) > 0)
                            {
                                decimal pg = 0.00m;
                                int TotalItemsCount = dtGetBodyVal.Rows.Count;
                                int dtItemsPP = Convert.ToInt32(dtGetConfigPage.Rows[0]["DetailItemPerPage"].ToString());
                                pg = (decimal)(TotalItemsCount) / (decimal)dtItemsPP;
                                int totalNumberPrint = Convert.ToInt32(Math.Ceiling(pg));
                                g.DrawString(pageNo.ToString() + "/" + totalNumberPrint, fontControl, blackBrush, drawRect, strFrmt);
                            }
                            else
                            {
                                g.DrawString(pageNo.ToString(), fontControl, blackBrush, drawRect, strFrmt);
                            }
                        }
                        else
                        {
                            string toWrite = pageNo.ToString();
                            if (toWrite.Length > width)
                                toWrite = (rightAlign) ? toWrite.Substring(toWrite.Length - width, width) : toWrite.Substring(0, width);
                            toWrite = string.Format(format, toWrite);
                            sw[line - 1].Remove(character, width)
                                        .Insert(character, toWrite);
                        }
                    }
                }
                else if (Mode == "Label" || Mode == "Footer Label")
                {
                    if (printMode == 1)
                        g.DrawString(row[9].ToString(), fontControl, blackBrush, drawRect, strFrmt);
                    else
                    {
                        string toWrite = row[9].ToString();
                        if (toWrite.Length > width)
                            toWrite = (rightAlign) ? toWrite.Substring(toWrite.Length - width, width) : toWrite.Substring(0, width);
                        toWrite = string.Format(format, toWrite);
                        sw[line - 1].Remove(character, width)
                                    .Insert(character, toWrite);
                    }
                }
                else if (Mode == "Box")
                {
                    Rectangle rt = new Rectangle(int.Parse(row[12].ToString()),
                            int.Parse(row[13].ToString()),
                            int.Parse(row[10].ToString()),
                            int.Parse(row[11].ToString()));
                    g.DrawRectangle(new Pen(Color.Black, 1), rt);
                }
                else if (Mode == "Copytype")
                {
                    string strCopyType = nCopies == 1 ? "Original" : nCopies == 2 ? "Duplicate" : nCopies == 2 ? "Triplicate" : "Original";
                    g.DrawString(strCopyType, fontControl, blackBrush, drawRect, strFrmt);
                }
                else if (Mode == "gksBarCode" || Mode == "gksQRCode")
                {
                    if (printMode == 1)
                    {
                        Image img = null;
                        string iic = row[9].ToString();
                        string nameofqr = "";
                        if (!string.IsNullOrEmpty(iic))
                        {
                            nameofqr = iic.Remove(3);
                        }
                        DataTable dtGetPrintDocID = GKS_BL.BL_ExecuteParamSP("uspGetDocIDforPrint", nTransId, nTransType);
                        string strDocID = (dtGetPrintDocID.Rows.Count > 0 ? dtGetPrintDocID.Rows[0][0].ToString() : "No Data");
                        string upitn = (dtGetPrintDocID.Rows[0][4].ToString()).Length > 80 ? (dtGetPrintDocID.Rows[0][4].ToString()).Remove(80) : dtGetPrintDocID.Rows[0][4].ToString();
                        string upiamt = dtGetPrintDocID.Rows[0][5].ToString();
                        string upiid = dtGetPrintDocID.Rows[0][6].ToString();
                        string upiname = dtGetPrintDocID.Rows[0][7].ToString();
                        string UPIURL = nameofqr == "UWA" ? string.Format("upi://pay?pa={0}&pn={1}&cu=INR&am={2}&tn={3}", upiid, upiname, upiamt, upitn) :
                            nameofqr == "UWO" ? string.Format("upi://pay?pa={0}&pn={1}&cu=INR&tn={2}", upiid, upiname, upitn) : "";
                        string UPIQRDATA = !string.IsNullOrEmpty(upiid) ? UPIURL : "";

                        strDocID = strDocID != "No Data" ? nameofqr == "SQR" ? dtGetPrintDocID.Rows[0][1].ToString() : nameofqr == "UWA" || nameofqr == "UWO" ? UPIQRDATA : dtGetPrintDocID.Rows[0][0].ToString() : "No Data";
                        bool hasPrint = true;
                        //strDocID = "upi://pay?pa=jjsolution2011@okicici&pn=Naresh Kanna&cu=INR&am="+ upiamt + "&tn=" + upitn;
                        if (Mode == "gksQRCode")
                        {
                            //strDocID = strDocID.Substring(0, 122);
                            string Content = (!string.IsNullOrEmpty(Convert.ToString(row[31])) ? Convert.ToString(row[31]) : strDocID);

                            //CodeQrBarcodeDraw qrCode = BarcodeDrawFactory.CodeQr;                                                        
                            //img = qrCode.Draw(Content, 100);

                            MessagingToolkit.QRCode.Codec.QRCodeEncoder encoder = new MessagingToolkit.QRCode.Codec.QRCodeEncoder();
                            encoder.QRCodeScale = 8;
                            //encoder.QRCodeEncodeMode = MessagingToolkit.QRCode.Codec.QRCodeEncoder.ENCODE_MODE.ALPHA_NUMERIC;
                            Bitmap bmp = new Bitmap(encoder.Encode(Content), new Size(250, 250));
                            img = bmp;
                        }
                        else
                        {
                            strDocID = strDocID != "No Data" ? nameofqr == "BRC" ? dtGetPrintDocID.Rows[0][0].ToString() : nameofqr == "BRA" ? dtGetPrintDocID.Rows[0][2].ToString() : dtGetPrintDocID.Rows[0][3].ToString() : "No Data";
                            if (!string.IsNullOrEmpty(strDocID) && strDocID != "0")
                            {
                                Code128BarcodeDraw barCode = BarcodeDrawFactory.Code128WithChecksum;
                                img = barCode.Draw(strDocID, 100);
                            }
                            else
                            {
                                hasPrint = false;
                            }
                        }
                        if (hasPrint)
                            g.DrawImage(img, drawRect.X, drawRect.Y, drawRect.Width, drawRect.Height);
                    }
                }
                else if (Mode == "Image")
                {
                    if (printMode == 1)
                    {
                        MemoryStream ms = new MemoryStream((byte[])row[30]);
                        Image img = Image.FromStream(ms);
                        //g.DrawImage(img, drawRect.X, drawRect.Y, drawRect.Width, drawRect.Height);
                        // Set opacity here (value between 0.0f and 1.0f)
                        float opacity = 1; // 50% opacity
                        ColorMatrix matrix = new ColorMatrix();
                        matrix.Matrix33 = opacity; // Set the alpha channel (opacity)

                        // Create ImageAttributes and set the ColorMatrix
                        ImageAttributes imgAttributes = new ImageAttributes();
                        imgAttributes.SetColorMatrix(matrix, ColorMatrixFlag.Default, ColorAdjustType.Bitmap);

                        // Draw the image with the applied opacity
                        Rectangle rt = new Rectangle(int.Parse(row[12].ToString()),
                           int.Parse(row[13].ToString()),
                           int.Parse(row[10].ToString()),
                           int.Parse(row[11].ToString()));
                        g.DrawImage(img, rt, 0, 0, img.Width, img.Height, GraphicsUnit.Pixel, imgAttributes);
                    }
                    else
                    {
                        string toWrite = row[30].ToString();
                        if (toWrite.Length > width)
                            toWrite = (rightAlign) ? toWrite.Substring(toWrite.Length - width, width) : toWrite.Substring(0, width);
                        toWrite = string.Format(format, toWrite);
                        sw[line - 1].Remove(character, width)
                                    .Insert(character, toWrite);
                    }
                }
                else if (Mode == "Barcode")
                {
                    if (RowValue.Columns.Contains("Doc Id"))
                    {
                        //string strDocValue = (RowValue.Rows[0]["Doc Id"].ToString());
                        //BaseBarcode barcode = BarcodeFactory.GetBarcode(Symbology.Code128);
                        //barcode.Number = strDocValue;
                        //barcode.ChecksumAdd = true;
                        //Bitmap bitmap = barcode.Render();
                        //g.DrawImage(bitmap, drawRect);
                    }
                    else
                    {
                        //Obj_MDI.ShowMessage("Barcode Column Doc Id Missing", GKS_BL.ToolStripErrorMsg);
                    }
                }
                else if (Mode == "Amt in Words")
                {
                    int Value = RowValue.Columns.Count - 3;
                    decimal NetAmt = GKS_BL.BL_RoundOffTwoDecimal(RowValue.Rows[0][Value].ToString()); //GKS_BL.BL_RoundOffDecimal(RowValue.Rows[0][Value].ToString());
                    string strWord = GKS_BL.BL_AmountInWords(NetAmt);
                    if (printMode == 1)
                        g.DrawString(strWord, fontControl, blackBrush, drawRect, strFrmt);
                    else
                    {
                        string toWrite = strWord;
                        if (toWrite.Length > width)
                            toWrite = (rightAlign) ? toWrite.Substring(toWrite.Length - width, width) : toWrite.Substring(0, width);
                        toWrite = string.Format(format, toWrite);
                        sw[line - 1].Remove(character, width)
                                    .Insert(character, toWrite);
                    }
                }
                else if (Mode == "Formula" || Mode == "FormulaBody")
                {
                    //BL_GetFormulaValue
                    string str = GKS_BL.BL_GetFormulaValue(RowValue, row[9].ToString(), RowCount).ToString();
                    if (printMode == 1)
                        g.DrawString(GKS_BL.BL_RoundOffTwoDecimal(str).ToString(), fontControl, blackBrush, drawRect, strFrmt);
                    else//GKS_BL.BL_RoundOffDecimal
                    {
                        string toWrite = Convert.ToDecimal(str).ToString();
                        if (toWrite.Length > width)
                            toWrite = (rightAlign) ? toWrite.Substring(toWrite.Length - width, width) : toWrite.Substring(0, width);
                        toWrite = string.Format(format, toWrite);
                        sw[line - 1].Remove(character, width)
                                    .Insert(character, toWrite);
                    }
                }
            }
            catch (Exception ex)
            {
                //GKS_BL.BL_ExceptionMsg("Print", "SetFontStyle", ex);
            }
        }

        /// <summary>
        /// Get and Set Config Details into varibales
        /// </summary>
        private void GetConfigDetail()
        {
            try
            {
                // get Configuration from table
                dtGetConfigPage = GKS_BL.BL_GetPrintPreviewPage(nConfigId);//BL_GetPrintPreviewPage
                if (dtGetConfigPage.Rows.Count > 0)
                {
                    if (Convert.ToInt32(dtGetConfigPage.Rows[0][6].ToString()) > 0)
                    {
                        paperSize = new PaperSize("Custom", Convert.ToInt32(dtGetConfigPage.Rows[0][0]), 1);
                    }
                    else
                    {
                        if (Convert.ToInt32(dtGetConfigPage.Rows[0][5].ToString()) > 0)
                        {
                            nItemCount = Convert.ToInt32(dtGetConfigPage.Rows[0][5].ToString());
                        }
                        paperSize = new PaperSize("Custom", Convert.ToInt32(dtGetConfigPage.Rows[0][0]), Convert.ToInt32(dtGetConfigPage.Rows[0][1]));
                    }
                    paperSize.RawKind = (int)PaperKind.Custom;
                }
            }
            catch (Exception ex)
            {
                //GKS_BL.BL_ExceptionMsg("Print", "getConfigDetails", ex);
            }
        }

        /// <summary>
        /// Tax Type Wise Tax Amount Showing add the Footer
        /// </summary>
        /// <param name="dtValue"></param>
        /// <param name="IRow"></param>
        /// <returns></returns>
        private DataTable TaxWisePrint(DataTable dtValue, DataRow[] IRow)
        {
            try
            {
                string[] strValue = new string[IRow.Length];
                for (int i = 0; i < IRow.Length; i++)
                {
                    strValue[i] = IRow[i][9].ToString();
                }
                if (strValue != null && dtValue.Rows.Count > 0)
                {
                    DataColumnCollection dtColumns = dtValue.Columns;
                    if (dtColumns.Contains("Tax Percentage"))
                    {
                        return dtValue.DefaultView.ToTable(false, strValue);
                    }
                    return null;
                }
                return null;
            }
            catch (Exception)
            {
                throw;
            }
        }

        /// <summary>
        /// Print Clear 
        /// </summary>
        /// <param name="Container">Container</param>
        public static void Clear(Control Container)
        {
            try
            {
                foreach (Control ctrl in Container.Controls)
                {
                    if (ctrl is Panel || ctrl is GroupBox || ctrl is TabControl)
                    {
                        Clear(ctrl);
                    }
                    else if (ctrl is TextBox)
                    {
                        ((TextBox)ctrl).Clear();
                        ((TextBox)ctrl).Tag = 0;
                    }
                    else if (ctrl is ListView)
                    {
                        ((ListView)ctrl).Items.Clear();
                    }
                    else if (ctrl is ComboBox)
                    {
                        ((ComboBox)ctrl).DroppedDown = false;
                        ((ComboBox)ctrl).DataSource = null;
                        ((ComboBox)ctrl).Text = string.Empty;
                    }
                    else if (ctrl is CheckBox)
                    {
                        ((CheckBox)ctrl).Checked = false;
                    }
                }
            }
            catch (Exception)
            {
                throw;
            }
        }

        /// <summary>
        /// Print Clear 
        /// </summary>
        /// <param name="Container">Container</param>
        public static void Delete(Control Container)
        {
            try
            {
                Container.Controls.Clear();
            }
            catch (Exception)
            {
                throw;
            }
        }
    }

}