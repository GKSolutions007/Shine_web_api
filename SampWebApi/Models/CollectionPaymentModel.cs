using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace SampWebApi.Models
{
    public class CollectionPaymentModel
    {
        public string ID { get; set; }
        public string Mode { get; set; }
        public string TransID { get; set; }
        public string TransMode { get; set; }
        public string TransName { get; set; }
        public string IsDraft { get; set; }
        public string DraftID { get; set; }
        public string DocDate { get; set; }
        public string DocId { get; set; }
        public string DocPrefix { get; set; }
        public string DocValue { get; set; }
        public string BranchID { get; set; }
        public string CustomerID { get; set; }
        public string PartyName { get; set; }
        public string BeatID { get; set; }
        public string SalesmanID { get; set; }
        public string RefNo { get; set; }
        public string PaymentModeID { get; set; }
        public string PaymentTermID { get; set; }
        public string AdvanceAmount { get; set; }
        public string CollAmt { get; set; }
        public string Balance { get; set; }
        public string Status { get; set; }
        public string StatusID { get; set; }
        public string CBy { get; set; }
        public string CDate { get; set; }
        public string UDFId { get; set; }
        public string UDFDocId { get; set; }
        public string UDFDocPrefix { get; set; }
        public string UDFDocValue { get; set; }
        public string UserID { get; set; }
        public string Remarks { get; set; }
        public string Narration { get; set; }
        public string CurrentStatus { get; set; }
        public string VisaPern { get; set; }
        public string VisaAmt { get; set; }
        public string NEFTNo { get; set; }
        public string BankAccID { get; set; }
        public string BankAccNo { get; set; }
        public string ChequeID { get; set; }
        public string ChequeNo { get; set; }
        public string ChequeDate { get; set; }
        public string IFSC { get; set; }
        public string BankID { get; set; }
        public string BankName { get; set; }
        public string Branch { get; set; }
        public List<CollPayDetails> lstCollPayDtl { get; set; }
        public List<CustomerVendorModel> lstvPartyDtl { get; set; }
    }
    public class CollPayDetails
    {
        public string TypeID { get; set; }
        public string DocID { get; set; }
        public string Tran_Date { get; set; }
        public string DocRef { get; set; }
        public string TransName { get; set; }
        public string NetAmt { get; set; }
        public string Balance { get; set; }
        public string ID { get; set; }
        public string FAID { get; set; }
        public string DocPrefix { get; set; }
        public string DocValue { get; set; }
        public string UDFDocId { get; set; }
        public string CollAmt { get; set; }
        public string AdjAmt { get; set; }
        public string DiscPern { get; set; }
        public string DiscAmt { get; set; }
        public string FullAdjYN { get; set; }
        public string TotalAdjAmt { get; set; }
        public string WriteOffAmt { get; set; }
    }
}