using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SampWebApi.Models
{
    public class PrintConfigModel
    {
        
        public string SaveType { get; set; }
        public string SaveMode { get; set; }
        public string UserID { get; set; }
        public string PrintID { get; set; }
        public string ConfigName { get; set; }
        public string TransactionID { get; set; }
        public string BoxW { get; set; }
        public string BoxH { get; set; }
        public string BoxX { get; set; }
        public string BoxY { get; set; }
        public string PrintMode { get; set; }
        public string DetailItemPerPage { get; set; }
        public string ContinuesPaper { get; set; }
        public string HeaderOnEP { get; set; }
        public string FooterOnEP { get; set; }
        public string PaperType { get; set; }
        public string PaperSizeType { get; set; }
        public string BodyLineSpace { get; set; }
        public string LineFeed { get; set; }
        public string IncludeCut { get; set; }
        public string WebPrint { get; set; }
        public string PaperTypeID { get; set; }
        public string Height { get; set; }
        public string Width { get; set; }
        public List<PrintCustomizeModel> PrintConfigDeatils { get; set; }
    }

    public class PrintCustomizeModel
    {
        public string PaperID { get; set; }
        public string ControlType { get; set; }
        public string X { get; set; }
        public string Y { get; set; }
        public string Width { get; set; }
        public string Height { get; set; }
        public string Rotation { get; set; }
        public string FontFamily { get; set; }
        public string FontSize { get; set; }
        public string FontWeight { get; set; }
        public string FontStyle { get; set; }
        public string TextValue { get; set; }
        public string ImageData { get; set; }
        public string QRBarcodeID { get; set; }
        public string QRText { get; set; }
        public string Alignment { get; set; }
        public string PlaceType { get; set; }
        public string SourceName { get; set; }
        public string IsFooter { get; set; }
        public string Bold { get; set; }
        public string Italic { get; set; }
        public string Underline { get; set; }
        public string Fontcolor { get; set; }
        public string Wraptext { get; set; }
    }

    public class BarcodeProfiles
    {
        public string ID { get; set; }
        public string ProfileName { get; set; }
        public string FileName { get; set; }
        public string Width { get; set; }
        public string Height { get; set; }
        public string NoofRows { get; set; }
        public string UID { get; set; }
    }
}