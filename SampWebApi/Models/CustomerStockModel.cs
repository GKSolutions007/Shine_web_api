using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SampWebApi.Models
{
    public class CustomerStockModel
    {
    }
    public class CustomerStockRequestModel
    {
        public string ID { get; set; }
        public string Date { get; set; }
        public string ProdID { get; set; }
        public string CustID { get; set; }
        public string Qty { get; set; }
        public string Price { get; set; }
        public string UomID { get; set; }
        public string MobileNo { get; set; }
        public string Status { get; set; }
        public string ExpectedDate { get; set; }
        public string CBy { get; set; }
    }
}