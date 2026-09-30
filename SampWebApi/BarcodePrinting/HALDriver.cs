using Microsoft.VisualBasic;
using Org.BouncyCastle.Utilities;
using Panthera.Drucken;
using System;
using System.Collections.Generic;
using System.Data;
using System.IO;
using System.Linq;
using System.Web;
using Strings = Microsoft.VisualBasic.Strings;

namespace SampWebApi.BarcodePrinting
{
    public class HALDriver
    {
        private const int PRINT_BAR_TITLE = 1;
        private const string BARFORMAT = "FMT(1,@W,@H,0,0,1)";
        private const string ALLCLEAR = "ACL()";
        private const string BARPRINT = "PRT(1,1,1)";
        private long mnBarCodeDevice;
        public string Apppath = "";
        public string PrinterName = "";
        public bool SendtoPrinter = false;
        private string GetStr(object X)
        {
            string functionReturnValue = null;
            if (IsNull(X))
                functionReturnValue = string.Empty;
            else
                functionReturnValue = Convert.ToString(X);
            return functionReturnValue;
        }

        private void PrintError(string szErrDesc, string szErrNumber = "10000")
        {
            AppendToLog("(" + szErrNumber + "): " + szErrDesc);
        }

        private void AppendToLog(string szMessage)
        {
            try
            {
                string mydocpath = AppSpecificSettings.ErrorLogFilePath;
                using (StreamWriter writer = new StreamWriter(mydocpath, true))
                {
                    writer.WriteLine(szMessage);
                }
            }
            catch (Exception)
            {
                throw;
            }
        }

        private bool IsNull(object X)
        {
            bool functionReturnValue = false;
            if ((X == null))
            {
                functionReturnValue = true;
            }
            else
            {
                functionReturnValue = false;
            }
            return functionReturnValue;
        }

        private object EncodeBarcode2(string szCode)
        {
            if (Microsoft.VisualBasic.Information.IsNumeric(szCode))
            {
                szCode = "C" + szCode;
            }
            else
            {
                szCode = "B" + szCode;
            }
            return szCode;
        }

        private object EncodeBarcode(string szCode)
        {
            dynamic nLen = null;
            if (!Microsoft.VisualBasic.Information.IsNumeric(szCode))
            {
                szCode = ">6" + szCode;
            }
            else
            {
                nLen = szCode.Length;
                if (nLen == 0)
                    throw new InvalidDataException("szCode to be supplied");

                if (nLen == 1)
                {
                    szCode = ">6" + szCode;
                }
                else
                {
                    if (nLen & 1)
                    {
                        szCode = ">5"
                            + Microsoft.VisualBasic.Strings.Left(szCode, nLen - 1) + ">6"
                            + Microsoft.VisualBasic.Strings.Right(szCode, 1);
                    }
                    else
                    {
                        szCode = ">5" + szCode;
                    }
                }
            }
            return szCode;
        }

        private void CopyFileBinary(string src, string dest)
        {
            try
            {
                dynamic fno = null;
                dynamic fno2 = null;
                ValueType szContents = null;

                fno = FileSystem.FreeFile();
                FileSystem.FileOpen(fno, src, OpenMode.Binary);

                fno2 = FileSystem.FreeFile();
                FileSystem.FileOpen(fno2, dest, OpenMode.Binary);

                szContents = Strings.Space(FileSystem.LOF(fno));

                FileSystem.FileGet(fno, ref szContents);
                FileSystem.FilePut(fno2, szContents);
                FileSystem.FileClose(fno2);
                FileSystem.FileClose(fno);
            }
            catch (Exception)
            {
                throw;
            }
        }

        private void DeleteTECLabels(ref string szPrint)
        {
            try
            {
                szPrint = Strings.Replace(szPrint, "$BARCODE", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$CODE", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$MRP", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$SALEPRICE", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$ECP", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$PTS", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$PTR", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$SPLPRICE", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$TAXINCLSALEPRICE", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$TAXINCLECP", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$REASON", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$TITLE", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$LABEL1", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$LABEL2", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$LABEL3", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$BATCH", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$EXPIRY", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$NAME", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$PKD", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$DOCDATE", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$DAYSEXPIRY", "", 1, 1, CompareMethod.Binary);
                szPrint = Strings.Replace(szPrint, "$REMARK", "", 1, 1, CompareMethod.Binary);
            }
            catch (Exception)
            {
                throw;
            }
        }

        private void DumpToFile(string szOutputFile, string szOutput)
        {
            int fno = 0;
            fno = Microsoft.VisualBasic.FileSystem.FreeFile();
            if (FileSystem.Dir(szOutputFile) != Constants.vbNullString)
                FileSystem.Kill(szOutputFile);
            FileSystem.FileOpen(fno, szOutputFile, OpenMode.Binary);
            FileSystem.FilePut(fno, szOutput);
            FileSystem.FileClose(fno);
        }

        private void DumpToFile4Append(string szOutputFile, string szOutput)
        {
            try
            {
                using (StreamWriter writer = new StreamWriter(szOutputFile, true))
                {
                    writer.Write(szOutput);
                }
            }
            catch (Exception)
            {
                throw;
            }
        }

        private void COMWrite(string strCommand)
        {
            Panthera.Drucken.SerialPorts.PortManager comm = new Panthera.Drucken.SerialPorts.PortManager();

            comm.Parity = AppSpecificSettings.Parity;
            comm.StopBits = AppSpecificSettings.StopBits;
            comm.DataBits = AppSpecificSettings.DataBits;
            comm.BaudRate = AppSpecificSettings.BaudRate;
            comm.PortName = AppSpecificSettings.PortName;
            comm.HandshakeType = AppSpecificSettings.Handshake;
            comm.OpenPort();

            comm.WriteData(strCommand);

            comm.ClosePort();
        }

        private void COM_Write(string strCommand, int PortNo = 1, string settings = "9600,n,8,1")
        {
            COMWrite(strCommand);
        }

        private void SendBarOutput(dynamic nUseParallel, string szPrint, dynamic PortNo, string BaudRate, 
            bool oneShot)
        {
            try
            {
                if (nUseParallel == 1)
                {
                    //DumpToFile(AppSpecificSettings.AppPath + "\\BarCode.txt", szPrint);
                    //CopyFileBinary(AppSpecificSettings.AppPath + "\\BarCode.txt", "LPT" + PortNo);
                    DumpToFile(Apppath + "\\BarCode.txt", szPrint);
                    CopyFileBinary(Apppath + "\\BarCode.txt", "LPT" + PortNo);
                }
                else if (nUseParallel == 2)
                {
                    string szFileName = null;
                    //szFileName = AppSpecificSettings.AppPath + AppSpecificSettings.TempFile;
                    szFileName = Apppath + "GKBSBarcodeSpool.out";// AppSpecificSettings.TempFile;
                    if (oneShot)
                    {
                        DumpToFile4Append(szFileName, szPrint);
                    }
                    else
                    {
                        DumpToFile(szFileName, szPrint);
                        if (SendtoPrinter)
                        {
                            RawPrinterHelper A = new RawPrinterHelper();
                            //RawPrinterHelper.SendFileToPrinter(AppSpecificSettings.PrinterName, szFileName, AppSpecificSettings.IncludeCut);
                            RawPrinterHelper.SendFileToPrinter(PrinterName, szFileName, AppSpecificSettings.IncludeCut);
                        }
                    }
                }
                else
                {
                    COM_Write(szPrint, PortNo, BaudRate);
                }
            }
            catch (Exception)
            {
                throw;
            }
        }

        private string ScoopFile(string szFile)
        {
            string functionReturnValue = null;
            string myStream = "";
            int fno = 0;
            string szLine = null;

            fno = FileSystem.FreeFile();
            FileSystem.FileOpen(fno, szFile, OpenMode.Input);
            while (FileSystem.EOF(fno) == false)
            {
                szLine = FileSystem.LineInput(fno);
                myStream = myStream + szLine + Constants.vbCrLf;
            }
            FileSystem.FileClose(fno);

            functionReturnValue = myStream;
            myStream = Constants.vbNullString;
            return functionReturnValue;
        }

        private void PrintBarCodeLabels(dynamic labelWidth, dynamic labelHeight, dynamic labelsPerRow, params object[] vItems)
        {
            //deprecated
        }

        private void Print2TEC(dynamic labelWidth, dynamic labelHeight, long labelsPerRow, dynamic PortNo, dynamic BaudRate, DataTable dtPrint, ref object[,] vItems)
        {
            try
            {
                dynamic nUseParallel = null;
                dynamic SKUCount = null;
                dynamic i = null;
                dynamic j = null;
                dynamic nQtyCount = null;
                long nLabelCount = 0;
                dynamic szBarCodeFormat = null;
                bool bAdHoc = false;
                string szPrint = null;
                dynamic szBarTitle = null;
                dynamic szlabel1 = null;
                dynamic szlabel2 = null;
                dynamic szlabel3 = null;
                dynamic szEncodedBarCode = null;
                dynamic szBarLabelFormat = null;
                bool bPharmaOnly = false;

                nUseParallel = 2;// Microsoft.VisualBasic.Conversion.Val(AppSpecificSettings.UseParallel);

                szBarTitle = "";// dtPrint.Rows[0][8].ToString();
                szlabel1 = "";// dtPrint.Rows[0][14].ToString();
                szlabel2 = "";// dtPrint.Rows[0][15].ToString();
                szlabel3 = "";// dtPrint.Rows[0][16].ToString();
                szBarLabelFormat = dtPrint.Rows[0]["FileName"].ToString();
                //szBarTitle = Strings.UCase(AppSpecificSettings.BarTitle); // Title
                //szlabel1 = Strings.UCase(AppSpecificSettings.Label1); //Label 1
                //szlabel2 = Strings.UCase(AppSpecificSettings.Label2); // Label 2
                //szlabel3 = Strings.UCase(AppSpecificSettings.Label3); // Label 3
                //szBarLabelFormat = Strings.LCase(AppSpecificSettings.BarLabelFormat);

                szBarCodeFormat = ScoopFile(Apppath + "\\" + szBarLabelFormat);// dtPrint.Rows[0][9].ToString() + "\\" + dtPrint.Rows[0][10].ToString(); 
                szPrint = szBarCodeFormat;
                SKUCount = Information.UBound(vItems, 2);
                if (Information.UBound(vItems, 1) == 6)
                    bAdHoc = true;
                if (Information.UBound(vItems, 1) > 8)
                    bPharmaOnly = true;

                string szOutputFile = Apppath+ "GKBSBarcodeSpool.out";// AppSpecificSettings.AppPath + AppSpecificSettings.TempFile;
                bool oneShot = true;// AppSpecificSettings.OneShotPrinting;
                if (oneShot)
                {
                    if (FileSystem.Dir(szOutputFile) != Constants.vbNullString)
                        FileSystem.Kill(szOutputFile);
                }

                for (i = 0; i <= SKUCount; i++)
                {
                    nQtyCount = vItems[2, i];
                    for (j = 1; j <= nQtyCount; j++)
                    {
                        if (mnBarCodeDevice == 2)
                        {
                            szEncodedBarCode = EncodeBarcode(Convert.ToString(vItems[0, i]));
                        }
                        else if (mnBarCodeDevice == 3)
                        {
                            szEncodedBarCode = EncodeBarcode2(Convert.ToString(vItems[0, i]));
                        }
                        else
                        {
                            szEncodedBarCode = Convert.ToString(vItems[0, i]);
                        }
                        szPrint = Strings.Replace(szPrint, "$BARCODE", szEncodedBarCode, 1, 1, CompareMethod.Binary);
                        szPrint = Strings.Replace(szPrint, "$CODE", GetStr(vItems[0, i]), 1, 1, CompareMethod.Binary);
                        szPrint = Strings.Replace(szPrint, "$SALEPRICE", GetStr(vItems[1, i]), 1, 1, CompareMethod.Binary);
                        szPrint = Strings.Replace(szPrint, "$ECP", GetStr(vItems[1, i]), 1, 1, CompareMethod.Binary);
                        szPrint = Strings.Replace(szPrint, "$NAME", GetStr(vItems[3, i]), 1, 1, CompareMethod.Binary);
                        szPrint = Strings.Replace(szPrint, "$PKD", GetStr(vItems[4, i]), 1, 1, CompareMethod.Binary);
                        szPrint = Strings.Replace(szPrint, "$BATCH", GetStr(vItems[5, i]), 1, 1, CompareMethod.Binary);
                        szPrint = Strings.Replace(szPrint, "$EXPIRY", GetStr(vItems[6, i]), 1, 1, CompareMethod.Binary);
                        szPrint = Strings.Replace(szPrint, "$REASON", GetStr(vItems[12, i]), 1, 1, CompareMethod.Binary);
                        szPrint = Strings.Replace(szPrint, "$DOCDATE", GetStr(vItems[13, i]), 1, 1, CompareMethod.Binary);// doc date
                        szPrint = Strings.Replace(szPrint, "$DAYSEXPIRY", GetStr(vItems[14, i]), 1, 1, CompareMethod.Binary);// Expiry Days
                        szPrint = Strings.Replace(szPrint, "$REMARK", GetStr(vItems[15, i]), 1, 1, CompareMethod.Binary);// Expiry Days
                        szPrint = Strings.Replace(szPrint, "$TITLE", szBarTitle, 1, 1, CompareMethod.Binary);
                        szPrint = Strings.Replace(szPrint, "$LABEL1", szlabel1, 1, 1, CompareMethod.Binary);
                        szPrint = Strings.Replace(szPrint, "$LABEL2", szlabel2, 1, 1, CompareMethod.Binary);
                        szPrint = Strings.Replace(szPrint, "$LABEL3", szlabel3, 1, 1, CompareMethod.Binary);
                        if (!bAdHoc)
                        {
                            szPrint = Strings.Replace(szPrint, "$MRP", GetStr(vItems[7, i]), 1, 1, CompareMethod.Binary);
                            szPrint = Strings.Replace(szPrint, "$PTS", GetStr(vItems[8, i]), 1, 1, CompareMethod.Binary);
                            szPrint = Strings.Replace(szPrint, "$TAXINCLSALEPRICE", GetStr(vItems[8, i]), 1, 1, CompareMethod.Binary);
                            if (bPharmaOnly)
                            {
                                szPrint = Strings.Replace(szPrint, "$PTR", GetStr(vItems[9, i]), 1, 1, CompareMethod.Binary);
                                szPrint = Strings.Replace(szPrint, "$SPLPRICE", GetStr(vItems[10, i]), 1, 1, CompareMethod.Binary);
                                szPrint = Strings.Replace(szPrint, "$TAXINCLECP", GetStr(vItems[11, i]), 1, 1, CompareMethod.Binary);
                            }
                        }
                        nLabelCount = nLabelCount + 1;
                        if (nLabelCount == labelsPerRow)
                        {
                            SendBarOutput(nUseParallel, szPrint, PortNo, BaudRate, oneShot);
                            szPrint = szBarCodeFormat;
                            nLabelCount = 0;
                        }
                    }
                }
                if (nLabelCount > 0)
                {
                    for (int k = 0; k < labelsPerRow - nLabelCount; k++)
                    {
                        DeleteTECLabels(ref szPrint);
                    }
                    SendBarOutput(nUseParallel, szPrint, PortNo, BaudRate, oneShot);
                }

                if (oneShot && SendtoPrinter)
                {
                    RawPrinterHelper A = new RawPrinterHelper();
                    //RawPrinterHelper.SendFileToPrinter(AppSpecificSettings.PrinterName, szOutputFile, AppSpecificSettings.IncludeCut);
                    RawPrinterHelper.SendFileToPrinter(PrinterName, szOutputFile, AppSpecificSettings.IncludeCut);
                }

            }
            catch (Exception)
            {
                throw;
            }
        }

        public void PrintBarCodeLabels2(ref object[,] vItems, DataTable dtPrint)
        {
            try
            {
                dynamic nLabelWidth = null;
                dynamic nLabelHeight = null;
                long nLabelsPerRow = 0;
                dynamic szSettings = null;
                dynamic nPort = null;
                dynamic BaudRate = null;
                dynamic szBarCodeCommand = Constants.vbNullString;
                dynamic szBarcodeDensity = null;
                dynamic SKUCount = null;
                dynamic LabelY1 = null;
                dynamic LabelY2 = null;
                dynamic LabelY3 = null;
                dynamic LabelX = null;
                dynamic szLabels = null;
                object[] vLabel = null;
                dynamic szBarFormat = null;
                dynamic i = null;
                dynamic nQtyCount = null;
                dynamic j = null;
                dynamic nFont = null;
                dynamic nSymbology = null;
                dynamic nBarCodeHeight = null;
                dynamic szBarPrefix = null;
                object[] vBarCodeStyle = null;
                dynamic szBarCodeStyle = null;
                dynamic DataX = null;
                dynamic nTotBarCodes = null;
                dynamic nUseParallel = null;
                dynamic szBarSuffix = null;
                dynamic nBarCodeDevice = null;
                dynamic LabelY4 = null;
                dynamic LabelY5 = null;
                dynamic nPrintBatchNumber = null;
                dynamic LabelY6 = null;
                dynamic szBarTitle = null;
                dynamic szPKD = null;
                dynamic szlabel1 = null;
                dynamic szLabel2 = null;
                dynamic szLabel3 = null;
                Apppath = AppDomain.CurrentDomain.BaseDirectory + "barcodefile\\";// dtPrint.Rows[0][9].ToString();
                PrinterName = "Citizen CL-E321";// dtPrint.Rows[0][3].ToString();
                nBarCodeDevice = 4;// Microsoft.VisualBasic.Conversion.Val(AppSpecificSettings.BarCodeDevice);
                szBarFormat = dtPrint.Rows[0]["FileName"].ToString();
                nLabelsPerRow = Convert.ToInt32(dtPrint.Rows[0]["NoofRows"]);
                nLabelWidth = Convert.ToInt32(dtPrint.Rows[0]["NoofRows"]) * Convert.ToInt32(dtPrint.Rows[0]["Width"]);
                nLabelHeight = dtPrint.Rows[0]["Height"].ToString();
                //old
                //szBarFormat = Strings.LCase(AppSpecificSettings.BarLabelFormat);//File name
                //nLabelsPerRow = Convert.ToInt32(AppSpecificSettings.BarCodeLabelPerRows);// no of rows
                //nLabelWidth = Microsoft.VisualBasic.Conversion.Val(AppSpecificSettings.BarCodeLabelWidth) * nLabelsPerRow; // width * no of rows
                //nLabelHeight = Microsoft.VisualBasic.Conversion.Val(AppSpecificSettings.BarCodeLabelHeight); // Height

                szSettings = "9600,n,8,1";// AppSpecificSettings.BarCodeSettings;
                nPort = 1;// Microsoft.VisualBasic.Conversion.Val(AppSpecificSettings.BarCodePort);
                BaudRate = 9600;// Microsoft.VisualBasic.Conversion.Val(AppSpecificSettings.BaudRate);

                if (nBarCodeDevice >= 2 | szBarFormat == "godex*")
                {
                    if (szBarFormat == "godex*")
                    {
                        nBarCodeDevice = 4;
                    }
                    mnBarCodeDevice = (long)nBarCodeDevice;
                    Print2TEC(nLabelWidth, nLabelHeight, nLabelsPerRow, nPort, szSettings, dtPrint, ref vItems);
                    return;
                }

                szBarcodeDensity = "BDN(" + AppSpecificSettings.BarcodeDensity + ")";
                szBarCodeStyle = AppSpecificSettings.BarCodeStyle;
                nUseParallel = Microsoft.VisualBasic.Conversion.Val(AppSpecificSettings.UseParallel);
                szBarTitle = dtPrint.Rows[0][10].ToString();
                szlabel1 = dtPrint.Rows[0][14].ToString();
                szLabel2 = dtPrint.Rows[0][15].ToString();
                szLabel3 = dtPrint.Rows[0][16].ToString();
                //old
                //szBarTitle = Strings.UCase(AppSpecificSettings.BarTitle);
                //szlabel1 = Strings.UCase(AppSpecificSettings.Label1);
                //szLabel2 = Strings.UCase(AppSpecificSettings.Label2);
                //szLabel3 = Strings.UCase(AppSpecificSettings.Label3);

                vBarCodeStyle = Strings.Split(szBarCodeStyle, ",");
                nFont = Microsoft.VisualBasic.Conversion.Val(vBarCodeStyle[0]);
                nSymbology = Microsoft.VisualBasic.Conversion.Val(vBarCodeStyle[1]);
                nBarCodeHeight = Microsoft.VisualBasic.Conversion.Val(vBarCodeStyle[2]);
                szBarPrefix = vBarCodeStyle[3];
                szBarSuffix = vBarCodeStyle[4];
                nPrintBatchNumber = Microsoft.VisualBasic.Conversion.Val(vBarCodeStyle[5]);
                szLabels = AppSpecificSettings.BarY;
                vLabel = Strings.Split(szLabels, ",");
                if (PRINT_BAR_TITLE == 1)
                {
                    LabelY1 = Microsoft.VisualBasic.Conversion.Val(vLabel[0]) + 4;
                    LabelY2 = Microsoft.VisualBasic.Conversion.Val(vLabel[1]) + 4;
                    LabelY3 = Microsoft.VisualBasic.Conversion.Val(vLabel[2]) + 4;
                    LabelY4 = Microsoft.VisualBasic.Conversion.Val(vLabel[3]) + 4;
                    LabelY5 = Microsoft.VisualBasic.Conversion.Val(vLabel[4]) + 4;
                    LabelY6 = Microsoft.VisualBasic.Conversion.Val(vLabel[5]) + 4;
                }
                else
                {
                    //LabelY1 = Microsoft.VisualBasic.Conversion.Val(vLabel[0]);
                    //LabelY2 = Microsoft.VisualBasic.Conversion.Val(vLabel[1]);
                    //LabelY3 = Microsoft.VisualBasic.Conversion.Val(vLabel[2]);
                    //LabelY4 = Microsoft.VisualBasic.Conversion.Val(vLabel[3]);
                    //LabelY5 = Microsoft.VisualBasic.Conversion.Val(vLabel[4]);
                    //LabelY6 = Microsoft.VisualBasic.Conversion.Val(vLabel[5]);
                }
                LabelX = Microsoft.VisualBasic.Conversion.Val(AppSpecificSettings.BarX);
                szBarFormat = Strings.Replace(BARFORMAT, "@W", nLabelWidth);
                szBarFormat = Strings.Replace(szBarFormat, "@H", nLabelHeight);
                SKUCount = Information.UBound(vItems, 2);

                string szOutputFile = AppSpecificSettings.AppPath + AppSpecificSettings.TempFile;
                bool oneShot = AppSpecificSettings.OneShotPrinting;
                if (oneShot)
                {
                    if (FileSystem.Dir(szOutputFile) != Constants.vbNullString)
                        FileSystem.Kill(szOutputFile);
                }
                for (i = 0; i <= SKUCount; i++)
                {
                    nQtyCount = vItems[2, i];
                    for (j = 1; j <= nQtyCount; j++)
                    {
                        if (szBarCodeCommand == Constants.vbNullString)
                        {
                            szBarCodeCommand = szBarFormat + Constants.vbCrLf;
                            szBarCodeCommand = szBarCodeCommand + ALLCLEAR + Constants.vbCrLf;
                        }
                        DataX = LabelX + ((nLabelWidth / nLabelsPerRow) * (nTotBarCodes));
                        if (PRINT_BAR_TITLE == 1)
                        {
                            szBarCodeCommand = szBarCodeCommand + "CFL(1," + DataX + "," + 1 + "," + nFont + ",1,1)" + Constants.vbCrLf;
                            szBarCodeCommand = szBarCodeCommand + "DAT(1," + szBarTitle + ")" + Constants.vbCrLf;
                        }
                        szBarCodeCommand = szBarCodeCommand + "CFL(1," + DataX + "," + LabelY1 + "," + nFont + ",1,1)" + Constants.vbCrLf;
                        szBarCodeCommand = szBarCodeCommand + "DAT(1," + vItems[3, i] + ")" + Constants.vbCrLf;
                        szBarCodeCommand = szBarCodeCommand + szBarcodeDensity + Constants.vbCrLf;
                        szBarCodeCommand = szBarCodeCommand + "BFL(2," + DataX + "," + LabelY2 + ",0," + nSymbology + "," + nBarCodeHeight + ")" + Constants.vbCrLf;
                        szBarCodeCommand = szBarCodeCommand + "DAT(2," + szBarPrefix + vItems[0, i] + szBarSuffix + ")" + Constants.vbCrLf;
                        szBarCodeCommand = szBarCodeCommand + "CFL(3," + DataX + "," + LabelY3 + "," + nFont + ",1,1)" + Constants.vbCrLf;
                        szBarCodeCommand = szBarCodeCommand + "DAT(3," + vItems[0, i] + ")" + Constants.vbCrLf;

                        szBarCodeCommand = szBarCodeCommand + "CFL(4," + DataX + "," + LabelY4 + "," + nFont + ",1,1)" + Constants.vbCrLf;
                        szBarCodeCommand = szBarCodeCommand + "DAT(4," + vItems[9, i] + ")" + Constants.vbCrLf;

                        szPKD = GetStr(vItems[4, i]);
                        if (Strings.Len(szPKD) == 7)
                        {
                            szPKD = Strings.Left(szPKD, 3) + Microsoft.VisualBasic.Strings.Right(szPKD, 2);
                        }
                        szBarCodeCommand = szBarCodeCommand + "CFL(5," + DataX + 16 + "," + LabelY4 + "," + nFont + ",1,1)" + Constants.vbCrLf;
                        szBarCodeCommand = szBarCodeCommand + "DAT(5," + szPKD + ")" + Constants.vbCrLf;

                        if (nPrintBatchNumber == 1)
                        {
                            szBarCodeCommand = szBarCodeCommand + "CFL(6," + DataX + "," + LabelY5 + "," + nFont + ",1,1)" + Constants.vbCrLf;
                            szBarCodeCommand = szBarCodeCommand + "DAT(6," + GetStr(vItems[6, i]) + ")" + Constants.vbCrLf;

                            szBarCodeCommand = szBarCodeCommand + "CFL(7," + DataX + 16 + "," + LabelY5 + "," + nFont + ",1,1)" + Constants.vbCrLf;
                            szBarCodeCommand = szBarCodeCommand + "DAT(7," + vItems[5, i] + ")" + Constants.vbCrLf;
                        }
                        nTotBarCodes = nTotBarCodes + 1;
                        if (nTotBarCodes == nLabelsPerRow)
                        {
                            szBarCodeCommand = szBarCodeCommand + BARPRINT + Constants.vbCrLf;
                            SendBarOutput(nUseParallel, szBarCodeCommand, nPort, BaudRate, oneShot);
                            nTotBarCodes = 0;
                            szBarCodeCommand = Constants.vbNullString;
                        }
                    }
                }
                if (nTotBarCodes > 0)
                {
                    szBarCodeCommand = szBarCodeCommand + BARPRINT + Constants.vbCrLf;
                    SendBarOutput(nUseParallel, szBarCodeCommand, nPort, BaudRate, oneShot);
                }

                if (oneShot && SendtoPrinter)
                {
                    RawPrinterHelper A = new RawPrinterHelper();
                    RawPrinterHelper.SendFileToPrinter(AppSpecificSettings.PrinterName, szOutputFile, AppSpecificSettings.IncludeCut);
                }
            }
            catch (Exception)
            {
                throw;
            }
        }
    }
}