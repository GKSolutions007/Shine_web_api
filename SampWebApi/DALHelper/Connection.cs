using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Web;

namespace SampWebApi.DALHelper
{
    public class Connection
    {
        public static string GetConnectionString()
        {
            string connectionString = ConfigurationManager.ConnectionStrings["Connections"].ConnectionString;
            return connectionString;
        }
    }
}