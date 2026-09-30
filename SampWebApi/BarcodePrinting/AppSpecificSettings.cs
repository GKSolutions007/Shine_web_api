using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Web;

namespace SampWebApi.BarcodePrinting
{
    public class AppSpecificSettings
    {
        public static string ErrorLogFilePath
        {
            get { return ConfigurationManager.AppSettings["ErrorLogFilePath"]; }
        }

        public static string AppPath
        {
            get { return ConfigurationManager.AppSettings["AppPath"]; }
        }

        public static string BarCodeLabelWidth
        {
            get { return ConfigurationManager.AppSettings["BarCodeLabelWidth"]; }
        }

        public static string BarCodeLabelHeight
        {
            get { return ConfigurationManager.AppSettings["BarCodeLabelHeight"]; }
        }

        public static string BarCodeLabelPerRows
        {
            get { return ConfigurationManager.AppSettings["BarCodeLabelPerRows"]; }
        }

        public static string BarCodeSettings
        {
            get { return ConfigurationManager.AppSettings["BarCodeSettings"]; }
        }

        public static string BarCodePort
        {
            get { return ConfigurationManager.AppSettings["BarCodePort"]; }
        }

        public static string BaudRate
        {
            get { return ConfigurationManager.AppSettings["BaudRate"]; }
        }

        public static string UseParallel
        {
            get { return ConfigurationManager.AppSettings["UseParallel"]; }
        }

        public static string BarTitle
        {
            get { return ConfigurationManager.AppSettings["BarTitle"]; }
        }

        public static string Label1
        {
            get { return ConfigurationManager.AppSettings["Label1"]; }
        }

        public static string Label2
        {
            get { return ConfigurationManager.AppSettings["Label2"]; }
        }

        public static string Label3
        {
            get { return ConfigurationManager.AppSettings["Label3"]; }
        }

        public static string BarLabelFormat
        {
            get { return ConfigurationManager.AppSettings["BarLabelFormat"]; }
        }

        public static string BarCodeDevice
        {
            get { return ConfigurationManager.AppSettings["BarCodeDevice"]; }
        }

        public static string BarcodeDensity
        {
            get { return ConfigurationManager.AppSettings["BarcodeDensity"]; }
        }

        public static string BarCodeStyle
        {
            get { return ConfigurationManager.AppSettings["BarCodeStyle"]; }
        }

        public static string BarY
        {
            get { return ConfigurationManager.AppSettings["BarY"]; }
        }

        public static string BarX
        {
            get { return ConfigurationManager.AppSettings["BarX"]; }
        }

        public static string PortName
        {
            get { return ConfigurationManager.AppSettings["PortName"]; }
        }

        public static string Parity
        {
            get { return ConfigurationManager.AppSettings["Parity"]; }
        }

        public static string StopBits
        {
            get { return ConfigurationManager.AppSettings["StopBits"]; }
        }

        public static string DataBits
        {
            get { return ConfigurationManager.AppSettings["DataBits"]; }
        }

        public static string TransMode
        {
            get { return ConfigurationManager.AppSettings["TransMode"]; }
        }

        public static string Handshake
        {
            get { return ConfigurationManager.AppSettings["Handshake"]; }
        }

        public static string TempFile
        {
            get { return ConfigurationManager.AppSettings["TempFile"]; }
        }

        public static bool DosPrinting
        {
            get { return (ConfigurationManager.AppSettings["DosPrinting"] == "true"); }
        }

        public static string PrinterName
        {
            get { return ConfigurationManager.AppSettings["PrinterName"]; }
        }

        public static bool IncludeCut
        {
            get { return (ConfigurationManager.AppSettings["IncludeCut"] == "true"); }
        }

        public static bool OneShotPrinting
        {
            get { return (ConfigurationManager.AppSettings["OneShotPrinting"] == "true"); }
        }
    }
}