using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Net.Mail;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using DALHelper;

namespace BuinessLayer
{
    public class clsBusinessLayer
    {
        clsDAL ObjDL = new clsDAL();
        public DataTable BL_ExecuteParamSP(string strProcedure, params object[] objParams)
        {
            return ObjDL.dl_ExecuteParamSP(strProcedure, objParams);
        }
        public DataTable BL_ExecuteSqlQuery(string strquery)
        {
            return ObjDL.dl_ExecuteSqlQuery(strquery);
        }
        public string BL_AppConfigValuebyID(int AppID)
        {
            string AppValue = "";
            DataTable dtApps = ObjDL.dl_ExecuteSqlQuery("SELECT * FROM tblAppConfig WHERE AppId = " + AppID);
            if (dtApps.Rows.Count > 0)
            {
                AppValue = dtApps.Rows[0][2].ToString();
            }
            return AppValue;
        }
        public void bl_Transaction(int action)
        {
            ObjDL.dl_Transaction(action);
        }
        public DataTable bl_ManageTrans(string strStoredProc, params object[] obj)
        {
            return ObjDL.dl_ManageTrans(strStoredProc, obj);
        }
        public bool SendEmail(string Subject, string Body, string ToMailID)
        {
            bool MailSend = false;
            try
            {
                string HostName = "", EMail = "", Pwd = "";
                //DataTable dtNames = BL_ExecuteParamSP("uspApplicationConfigValue");
                //if (dtNames.Rows.Count > 0)
                //{
                //    HostName = dtNames.Rows[0]["HostName"].ToString();
                //    EMail = dtNames.Rows[0]["EMailID"].ToString();
                //    Pwd = dtNames.Rows[0]["Password"].ToString();
                //}
                HostName = "smtp.gmail.com";
                EMail = "gksolutions.work007@gmail.com";
                Pwd = "ujrx zkfl kpfo dehr";
                if (!string.IsNullOrEmpty(HostName) && !string.IsNullOrEmpty(EMail) && !string.IsNullOrEmpty(Pwd))
                {
                    //
                    MailMessage message = new MailMessage();
                    SmtpClient smtp = new SmtpClient();
                    //message.From = new MailAddress("gks.helpdesk@gmail.com");//gks.helpdesk@gmail.com
                    message.From = new MailAddress(EMail);//gks.helpdesk@gmail.com//"vipassana.pveasllp@gmail.com"
                    message.To.Add(new MailAddress(ToMailID));
                    message.Subject = Subject;
                    message.IsBodyHtml = true; //to make message body as html  
                    message.Body = Body;
                    smtp.Port = 587;
                    smtp.Host = HostName;// "smtp.gmail.com"; //for gmail host  
                    smtp.EnableSsl = true;
                    smtp.UseDefaultCredentials = false;
                    //smtp.Credentials = new NetworkCredential("gks.helpdesk@gmail.com", "mkolocmylhzuuvdk");
                    //smtp.Credentials = new NetworkCredential("vipassana.pveasllp@gmail.com", "eyilfwmebqgydnjg");//pveasllp@2021
                    smtp.Credentials = new NetworkCredential(EMail, Pwd);
                    smtp.DeliveryMethod = SmtpDeliveryMethod.Network;

                    smtp.Send(message);
                    MailSend = true;
                }
                else
                {
                    MailSend = false;
                    //BL_WriteErrorMsginLog("BL", "Mail Send", "E-Mail config details are empty in App Config. You should give the details there.");
                }
            }
            catch (Exception ex)
            {
                MailSend = false;
                //BL_WriteErrorMsginLog("BL", "Mail Send - Exception", ex.Message);
                throw ex;
            }
            finally
            {

            }
            return MailSend;
        }
    }
}
