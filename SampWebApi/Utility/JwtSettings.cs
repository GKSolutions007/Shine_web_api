using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Text;
using System.Web;

namespace SampWebApi.Utility
{
    public static class JwtSettings
    {
        public static string Issuer = ConfigurationManager.AppSettings["ValidIssuer"] ?? "default_issuer";
        public static string Audience = ConfigurationManager.AppSettings["ValidAudience"] ?? "default_audience";
        public static string AuthTokenExpiresInMins = ConfigurationManager.AppSettings["AuthTokenExpiresInMins"] ?? "15";
        public static string RefreshTokenExpiresInDays = ConfigurationManager.AppSettings["RefreshTokenExpiresInDays"] ?? "1";
        public static string SecretKey = "yPqB3dmFXNfJg6X1W/JzNX4A2Sc6sZ7Q7+p2lYxPrCY=";

        public static byte[] GetKey() => Encoding.UTF8.GetBytes(SecretKey);
    }
}