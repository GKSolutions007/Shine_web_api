using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SampWebApi.Models
{
    public class DeliveryModel
    {
        public string TransMode { get; set; }
        public string ID { get; set; }
        public string DocDate { get; set; }
        public string DocPrefix { get; set; }
        public string DocValue { get; set; }
        public string DocID { get; set; }
        public string RefNo { get; set; }
        public string BranchID { get; set; }
        public string SalesmanID { get; set; }
        public string VehicleID { get; set; }
        public string Status { get; set; }
        public string CurrentStatus { get; set; }

        public string Remarks { get; set; }
        public string Narration { get; set; }
        public string DocumentIDs { get; set; }
        public string FilterBranch { get; set; }
        public string UID { get; set; }        
    }
    public class DeliveryProductFilter
    {
        public string BranchID { get; set; }
        public string TransMode { get; set; }
        public string DocumentIDs { get; set; }
        public string DeliveryID { get; set; }
        public string BeatID { get; set; }
        public string SalesmanID { get; set; }
        public string CustomerID { get; set; }
        public string FromDate { get; set; }
        public string ToDate { get; set; }
        public string InclDoc { get; set; }
    }
}