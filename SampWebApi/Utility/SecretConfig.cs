using System;
using System.Configuration;
using SampWebApi.DALHelper;

namespace SampWebApi.Utility
{
    /// <summary>
    /// Single place that reads secrets (connection strings, JWT key, SMTP passkey) from Web.config.
    ///
    /// Two storage modes, chosen by appSettings["SecretsArePlainText"]:
    ///  - "true"  : the values are plain text and the connectionStrings / appSettings sections are
    ///              encrypted on disk by ASP.NET protected configuration (aspnet_regiis -pef,
    ///              machine-bound DPAPI). ConfigurationManager decrypts them transparently.
    ///              Set up with Deploy\Protect-WebConfig.ps1.
    ///  - missing / anything else : legacy mode, values are clsEncryptDecrypt ciphertext. That AES key
    ///              is hard-coded in source, so this mode only obscures the values; it is kept so
    ///              existing deployments keep working until they are migrated.
    /// </summary>
    public static class SecretConfig
    {
        private static readonly bool _plainText = string.Equals(
            ConfigurationManager.AppSettings["SecretsArePlainText"], "true", StringComparison.OrdinalIgnoreCase);

        /// <summary>True when secrets are stored in plain text inside protected config sections.</summary>
        public static bool UsesProtectedConfiguration { get { return _plainText; } }

        /// <summary>Connection string by name, decrypted if stored in the legacy format.</summary>
        public static string ConnectionString(string name)
        {
            ConnectionStringSettings cs = ConfigurationManager.ConnectionStrings[name];
            if (cs == null || string.IsNullOrEmpty(cs.ConnectionString))
                throw new ConfigurationErrorsException("connectionStrings[\"" + name + "\"] is missing.");
            return Unprotect(cs.ConnectionString);
        }

        /// <summary>Secret appSettings value (e.g. JwtSecretKey, passkey); null/empty is returned as-is.</summary>
        public static string AppSecret(string key)
        {
            string value = ConfigurationManager.AppSettings[key];
            return string.IsNullOrEmpty(value) ? value : Unprotect(value);
        }

        private static string Unprotect(string value)
        {
            return _plainText ? value : clsEncryptDecrypt.Decrypt(value);
        }
    }
}
