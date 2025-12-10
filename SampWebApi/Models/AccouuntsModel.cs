using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Web;
using System.Web.Util;

namespace SampWebApi.Models
{
    public class AccouuntsModel
    {
        public string TransMode { get; set; }
        public string ID { get; set; }
        public string DocID { get; set; }
        public string TransID { get; set; }
        public string DocDate { get; set; }
        public string RefNo { get; set; }
        public string PartyID { get; set; }
        public string FAID { get; set; }
        public string NoteValue { get; set; }
        public string Balance { get; set; }
        public string Remark { get; set; }
        public string Narration { get; set; }
        public string Status { get; set; }
        public string StatusID { get; set; }
        public string CurrentStatus { get; set; }
        public string FAType { get; set; }
        public string AdjYN { get; set; }
        public string UDFId { get; set; }
        public string UDFDocId { get; set; }
        public string UDFDocPrefix { get; set; }
        public string UDFDocValue { get; set; }
        public string CBy { get; set; }
        public string CDate { get; set; }
        public string SACHSN { get; set; }
        public string TaxID { get; set; }
        public string TaxPern { get; set; }
        public string GoodsAmt { get; set; }
        public string DiscPern { get; set; }
        public string DiscAmt { get; set; }
        public string GrossAmt { get; set; }
        public string TaxAmt { get; set; }
        public string NetAmt { get; set; }
        public string TDSAmt { get; set; }
        public string ContType { get; set; }
        public string ContMode { get; set; }
           
        public string VisaPern { get; set; }
        public string VisaAmt { get; set; }
        public string Salesman { get; set; }
        public string OCPType { get; set; }
        public string NEFTNo { get; set; }
        public string BankAccID { get; set; }
        public string ChequeNo { get; set; }
        public string ChequeDate { get; set; }
        public string IFSC { get; set; }
        public string BankID { get; set; }
        public string BankName { get; set; }
        public string Branch { get; set; }
        public List<JournalEntry> JVData { get; set; }
        public List<OtherCollPayPMDetails> OCPPMData { get; set; }

    }
    public class JournalEntry
    {
        public string AccID { get; set; }
        public string FAType { get; set; }
        public string AdjYN { get; set; }
        public string Credit { get; set; }
        public string Debit { get; set; }
        public string Remarks { get; set; }
        public string Serial { get; set; }
    }
    public class BRSData
    {
        public string JVID { get; set; }
        public string DocDate { get; set; }
        public string BRSDate { get; set; }
        public string DocValue { get; set; }
    }
    public class OtherCollPayPMDetails
    {
        public string ID { get; set; }
        public string Amount { get; set; }
        public string PaymentMode { get; set; }
        public string BankAccID { get; set; }
        public string ChequeNo { get; set; }
        public string ChequeID { get; set; }
        public string NeftID { get; set; }
        public string Date { get; set; }
        public string PayAt { get; set; }
        public string IfscCode { get; set; }
        public string BankName { get; set; }
        public string BranchName { get; set; }
        public string AmtRecd { get; set; }
        public string Status { get; set; }

    }
    public class chequedeposit
    {
        public string ID { get; set; }
        public string TransMode { get; set; }
        public string DocID { get; set; }
        public string Docprefix { get; set; }
        public string DocDate { get; set; }
        public string RefNo { get; set; }
        public string DepositAccID { get; set; }
        public string SalesmanID { get; set; }
        public string Status { get; set; }
        public string CurrentStatus { get; set; }
        public string UDFId { get; set; }
        public string UDFDocId { get; set; }
        public string UDFDocPrefix { get; set; }
        public string UDFDocValue { get; set; }
        public string CBy { get; set; }
        public string ChequeBRDate { set; get; }
        public string BankCharge { set; get; }
        public List<chequedepositdocuments> chequedepositsdocs { get; set; }
    }
    public class chequedepositdocuments {
        public string AccID { get; set; }
        public string AccName { get; set; }
        public string ChqorDDNo { get; set; }
        public string ChqDate { get; set; }
        public string BankName { get; set; }
        public string BranchName { get; set; }
        public string CollAmt { get; set; }
        public string PayMode { get; set; }
        public string Desc { get; set; }
        public string Status { get; set; }
        public string ColID { get; set; }
        public string DepID { get; set; }
        public string IFSCCode { get; set; }

    }
    public class EInvoiceEwayModel
    {
        public string TypeID { get; set; }
        public string DocID { get; set; }
        public string DocDate { get; set; }
        public string DocType { get; set; }


        public string VehicleNo { get; set; }
        public string Distance { get; set; }
        public string TransportType { get; set; }
        public string TransportMode { get; set; }

        public string TransactionID { get; set; }
        public string TransactionName { get; set; }
        public string DocRange { get; set; }

    }
}