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

        // Secret key is read from appSettings["JwtSecretKey"] so it can be rotated per environment
        // without redeploying code. Read through SecretConfig: plain text inside a protected
        // appSettings section (SecretsArePlainText=true), or legacy clsEncryptDecrypt ciphertext.
        private static string _secretKey = null;
        public static string SecretKey
        {
            get
            {
                if (_secretKey == null)
                {
                    string encrypted = ConfigurationManager.AppSettings["JwtSecretKey"];
                    if (string.IsNullOrEmpty(encrypted))
                    {
                        // Fail closed: never fall back to a key baked into source. A signing key
                        // committed to the repo lets anyone with the code forge valid tokens.
                        // The deployment environment MUST supply an AES-encrypted JwtSecretKey.
                        throw new ConfigurationErrorsException(
                            "appSettings[\"JwtSecretKey\"] is missing. Supply an AES-encrypted JWT signing key " +
                            "(encrypt with clsEncryptDecrypt.Encrypt) before the application can issue or validate tokens.");
                    }
                    _secretKey = SecretConfig.AppSecret("JwtSecretKey");
                }
                return _secretKey;
            }
        }

        public static byte[] GetKey() => Encoding.UTF8.GetBytes(SecretKey);
    }
}