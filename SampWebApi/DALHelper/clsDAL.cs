using System;
using System.Collections.Generic;
using System.Collections.Concurrent;
using System.Data.SqlClient;
using System.Data;
using System.Linq;
using System.Web;
using System.Configuration;

namespace SampWebApi.DALHelper
{
    // THREAD-SAFETY NOTE:
    //   clsDAL holds per-instance connection/transaction fields (aSqlconnection,
    //   aSqlTransaction, and the Shinecode pair). It is therefore NOT thread-safe and
    //   must be used as one instance per request (the current pattern: one clsBusinessLayer
    //   -> one clsDAL per controller, and controllers are created per request by Web API).
    //   Do NOT register clsDAL/clsBusinessLayer as a singleton or share an instance across
    //   threads, or concurrent requests will corrupt each other's transaction state.
    public class clsDAL
    {
        SqlConnection aSqlconnection = new SqlConnection();
        SqlTransaction aSqlTransaction;
        SqlConnection aSqlconnectionShinecode = new SqlConnection();
        SqlTransaction aSqlTransactionShinecode;

        // Configurable query timeout (seconds). 0 = infinite. Read once from config at startup.
        private static readonly int _queryTimeoutSeconds = GetConfiguredTimeout();
        private static int GetConfiguredTimeout()
        {
            int val;
            string cfg = System.Configuration.ConfigurationManager.AppSettings["QueryTimeoutSeconds"];
            return int.TryParse(cfg, out val) && val >= 0 ? val : 120;
        }

        // ===== Stored-procedure parameter metadata cache (performance) =====
        // SqlCommandBuilder.DeriveParameters issues a catalog round-trip to SQL Server on
        // EVERY call to discover an SP's parameters. For a high-traffic app that doubles the
        // DB round-trips. We derive the parameters once per SP name and cache a clone, then
        // re-apply the cached definitions to each new command. Toggle off with
        // appSettings["CacheSpParameters"] = "false" if an SP signature changes at runtime.
        private static readonly ConcurrentDictionary<string, SqlParameter[]> _spParamCache
            = new ConcurrentDictionary<string, SqlParameter[]>(StringComparer.OrdinalIgnoreCase);

        private static readonly bool _cacheSpParams = GetCacheSpParamsSetting();
        private static bool GetCacheSpParamsSetting()
        {
            string cfg = System.Configuration.ConfigurationManager.AppSettings["CacheSpParameters"];
            // default ON
            return string.IsNullOrEmpty(cfg) || !cfg.Equals("false", StringComparison.OrdinalIgnoreCase);
        }

        // Cache key includes the target database so that same-named stored procedures on
        // different databases (main DB vs. Shinecode DB) never share a cached signature.
        private static string SpCacheKey(SqlCommand cmd)
        {
            return (cmd.Connection != null ? cmd.Connection.Database : "") + "::" + cmd.CommandText;
        }

        // SQL errors that mean the cached parameter list no longer matches the procedure
        // (e.g. it was ALTERed to add/remove/retype a parameter while the app was running):
        //   201  procedure expects a parameter that was not supplied
        //   206  operand type clash
        //   8144 too many arguments
        //   8145 '@x' is not a parameter for procedure
        internal static bool IsSpSignatureMismatch(SqlException ex)
        {
            return ex.Number == 201 || ex.Number == 206 || ex.Number == 8144 || ex.Number == 8145;
        }

        // Drops the cached parameter list so the next call derives it from the server again.
        // The failing call itself still throws (no automatic retry: the caller may be inside a
        // transaction), but the app recovers on the next call instead of needing a restart.
        internal static void InvalidateSpParameters(SqlCommand cmd)
        {
            SqlParameter[] removed;
            _spParamCache.TryRemove(SpCacheKey(cmd), out removed);
        }

        // Populates cmd.Parameters for the stored procedure, using the cache when enabled.
        // cmd.Connection must be open (the database name is part of the cache key).
        internal static void PrepareSpParameters(SqlCommand cmd)
        {
            if (!_cacheSpParams)
            {
                SqlCommandBuilder.DeriveParameters(cmd);
                return;
            }

            string dbKey = SpCacheKey(cmd);

            SqlParameter[] cached;
            if (!_spParamCache.TryGetValue(dbKey, out cached))
            {
                // First call for this SP: derive from the server, then cache clones.
                SqlCommandBuilder.DeriveParameters(cmd);
                cached = new SqlParameter[cmd.Parameters.Count];
                for (int i = 0; i < cmd.Parameters.Count; i++)
                    cached[i] = (SqlParameter)((ICloneable)cmd.Parameters[i]).Clone();
                _spParamCache[dbKey] = cached;
                return; // cmd.Parameters already populated by DeriveParameters
            }

            // Subsequent calls: rebuild parameters from cached definitions (no DB round-trip).
            cmd.Parameters.Clear();
            foreach (var p in cached)
                cmd.Parameters.Add((SqlParameter)((ICloneable)p).Clone());
        }
        public string Connectionstr()
        {
            return Utility.SecretConfig.ConnectionString("Connections");
        }
        public DataTable dl_ExecuteSqlQuery(string strquery)
        {
            DataTable dt_SqlQuery = new DataTable();
            try
            {
                using (aSqlconnection = new SqlConnection(Connectionstr()))
                using (SqlDataAdapter dacmd = new SqlDataAdapter(strquery, aSqlconnection))
                {
                    aSqlconnection.Open();
                    dacmd.Fill(dt_SqlQuery);
                }
            }
            catch (Exception)
            {
                throw; // preserve original stack trace
            }
            return dt_SqlQuery;
        }

        /// <summary>
        /// Parameterized ad-hoc query. Use this instead of string-concatenating values into
        /// dl_ExecuteSqlQuery. Example:
        ///   dl_ExecuteParamQuery("SELECT * FROM tblMasterTax WHERE TaxID = @p0", taxId)
        /// Parameters are referenced as @p0, @p1, ... in the query text, matching the order
        /// of the values supplied. This closes SQL-injection holes on the raw-query path.
        /// </summary>
        public DataTable dl_ExecuteParamQuery(string strquery, params object[] parameters)
        {
            DataTable dt = new DataTable();
            try
            {
                using (aSqlconnection = new SqlConnection(Connectionstr()))
                using (SqlCommand cmd = new SqlCommand(strquery, aSqlconnection))
                using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                {
                    cmd.CommandTimeout = _queryTimeoutSeconds;
                    for (int i = 0; i < parameters.Length; i++)
                        cmd.Parameters.AddWithValue("@p" + i, parameters[i] ?? DBNull.Value);
                    aSqlconnection.Open();
                    da.Fill(dt);
                }
            }
            catch (Exception)
            {
                throw;
            }
            return dt;
        }
        public DataTable dl_ExecuteParamSP(string strSPName, params object[] parameters)
        {
            DataTable dt_returnvalue = new DataTable();
            int Errindex = 0;
            try
            {
                using (aSqlconnection = new SqlConnection(Connectionstr()))
                {
                    aSqlconnection.Open();
                    SqlCommand cmd = new SqlCommand(strSPName, aSqlconnection);
                    cmd.CommandTimeout = _queryTimeoutSeconds;
                    cmd.CommandType = CommandType.StoredProcedure;
                    PrepareSpParameters(cmd);
                    for (int i = 0; i < parameters.Length; i++)
                    {
                        Errindex = i;
                        cmd.Parameters[i + 1].Value = parameters[i];
                    }
                    using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                    {
                        try { da.Fill(dt_returnvalue); }
                        catch (SqlException ex) when (IsSpSignatureMismatch(ex)) { InvalidateSpParameters(cmd); throw; }
                    }
                }
            }
            catch (Exception)
            {
                throw; // preserve original stack trace
            }
            return dt_returnvalue;
        }
        // Rolls back only if the transaction is still alive. When a procedure runs with
        // SET XACT_ABORT ON, SQL Server rolls the transaction back itself on error; the
        // SqlTransaction is then "zombied" (Connection == null) and Rollback() would throw
        // InvalidOperationException, hiding the real SqlException from the caller/log.
        private static void SafeRollback(SqlTransaction tx)
        {
            if (tx == null || tx.Connection == null) return;
            try { tx.Rollback(); }
            catch (InvalidOperationException) { /* already completed on the server */ }
        }
        public void dl_Transaction(int Action)
        {
            if (Action == 1)
            {
                aSqlconnection = new SqlConnection(Connectionstr());
                aSqlconnection.Open();
                aSqlTransaction = aSqlconnection.BeginTransaction();
            }
            else if (Action == 2)
            {
                aSqlTransaction.Commit();
                aSqlconnection.Close();
            }
            else if (Action == 3)
            {
                SafeRollback(aSqlTransaction);
                aSqlconnection.Close();
            }
        }
        public DataTable dl_ManageTrans(string strStoredProc, params object[] obj)
        {
            try
            {
                DataTable dt_returnvalue = new DataTable();

                SqlCommand cmd = new SqlCommand(strStoredProc, aSqlconnection, aSqlTransaction);
                cmd.CommandTimeout = _queryTimeoutSeconds;
                cmd.CommandType = CommandType.StoredProcedure;
                PrepareSpParameters(cmd);
                for (int i = 0; i < obj.Length; i++)
                {
                    if (cmd.Parameters[i + 1].SqlDbType != SqlDbType.Structured)
                    {
                        cmd.Parameters[i + 1].Value = obj[i];
                    }
                    else
                    {
                        string strTypeName = cmd.Parameters[i + 1].TypeName;
                        int nIndex = strTypeName.IndexOf(".");
                        cmd.Parameters[i + 1].TypeName = strTypeName.Substring(nIndex + 1);
                        cmd.Parameters[i + 1].Value = obj[i];
                    }
                }
                using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                {
                    try { da.Fill(dt_returnvalue); }
                    catch (SqlException ex) when (IsSpSignatureMismatch(ex)) { InvalidateSpParameters(cmd); throw; }
                }
                return dt_returnvalue;
            }
            catch (Exception)
            {
                SafeRollback(aSqlTransaction);
                throw; // preserve original stack trace
            }
        }
        public void dl_Transaction_SC(int Action)
        {
            if (Action == 1)
            {
                string connectionString = Utility.SecretConfig.ConnectionString("ShinecodeConnection");
                aSqlconnectionShinecode = new SqlConnection(connectionString);
                aSqlconnectionShinecode.Open();
                aSqlTransactionShinecode = aSqlconnectionShinecode.BeginTransaction();
            }
            else if (Action == 2)
            {
                aSqlTransactionShinecode.Commit();
                aSqlconnectionShinecode.Close();
            }
            else if (Action == 3)
            {
                SafeRollback(aSqlTransactionShinecode);
                aSqlconnectionShinecode.Close();
            }
        }
        public DataTable dl_ManageTrans_SC(string strStoredProc, params object[] obj)
        {
            try
            {
                DataTable dt_returnvalue = new DataTable();

                SqlCommand cmd = new SqlCommand(strStoredProc, aSqlconnectionShinecode, aSqlTransactionShinecode);
                cmd.CommandTimeout = _queryTimeoutSeconds;
                cmd.CommandType = CommandType.StoredProcedure;
                PrepareSpParameters(cmd);
                for (int i = 0; i < obj.Length; i++)
                {
                    if (cmd.Parameters[i + 1].SqlDbType != SqlDbType.Structured)
                    {
                        cmd.Parameters[i + 1].Value = obj[i];
                    }
                    else
                    {
                        string strTypeName = cmd.Parameters[i + 1].TypeName;
                        int nIndex = strTypeName.IndexOf(".");
                        cmd.Parameters[i + 1].TypeName = strTypeName.Substring(nIndex + 1);
                        cmd.Parameters[i + 1].Value = obj[i];
                    }
                }
                using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                {
                    try { da.Fill(dt_returnvalue); }
                    catch (SqlException ex) when (IsSpSignatureMismatch(ex)) { InvalidateSpParameters(cmd); throw; }
                }
                return dt_returnvalue;
            }
            catch (Exception)
            {
                // Roll back the Shinecode transaction (not the main DB transaction)
                SafeRollback(aSqlTransactionShinecode);
                throw; // preserve original stack trace
            }
        }
        public DataSet dl_ExecuteParamSPDataset(string strSPName, params object[] parameters)
        {
            DataSet dt_returnvalue = new DataSet();
            int Errindex = 0;
            try
            {
                using (aSqlconnection = new SqlConnection(Connectionstr()))
                {
                    aSqlconnection.Open();
                    SqlCommand cmd = new SqlCommand(strSPName, aSqlconnection);
                    cmd.CommandTimeout = _queryTimeoutSeconds;
                    cmd.CommandType = CommandType.StoredProcedure;
                    PrepareSpParameters(cmd);
                    for (int i = 0; i < parameters.Length; i++)
                    {
                        Errindex = i;
                        cmd.Parameters[i + 1].Value = parameters[i];
                    }
                    using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                    {
                        try { da.Fill(dt_returnvalue); }
                        catch (SqlException ex) when (IsSpSignatureMismatch(ex)) { InvalidateSpParameters(cmd); throw; }
                    }
                }
            }
            catch (Exception)
            {
                throw; // preserve original stack trace
            }
            return dt_returnvalue;
        }
    }
}