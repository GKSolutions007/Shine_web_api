using Microsoft.IdentityModel.Tokens;
using SampWebApi.Utility;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Data;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Web;
using SampWebApi.Models;

namespace SampWebApi.BuisnessLayer
{
    public static class TokenHelper
    {
        /// <summary>
        /// Builds a signed JWT auth token value WITHOUT writing any cookie. Used by the refresh
        /// flow, which must decide (via the atomic DB rotation) whether it won before it is
        /// allowed to set cookies.
        /// </summary>
        public static string BuildAuthTokenValue(string UserId = null)
        {
            var Issuer = JwtSettings.Issuer;
            var Audience = JwtSettings.Audience;
            var key = JwtSettings.GetKey();
            var AuthTokenExpiresInMins = double.Parse(JwtSettings.AuthTokenExpiresInMins);

            var tokenHandler = new JwtSecurityTokenHandler();

            // IMPORTANT: a unique 'jti' MUST be in the issued token. The old code built a claims
            // list with a jti GUID but never attached it to the descriptor (Subject was
            // commented out), so the JWT carried only nbf/exp/iat/iss/aud. Any two tokens issued
            // in the SAME WHOLE SECOND were therefore byte-identical, which is exactly how two
            // tblRefreshTokens rows ended up with the same AuthToken (and AuthTokenHash). Adding
            // jti makes every issued token unique regardless of timing.
            var claims = new List<Claim>
            {
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };
            if (!string.IsNullOrEmpty(UserId))
            {
                claims.Add(new Claim(JwtRegisteredClaimNames.Sub, UserId));
            }

            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(claims),
                Expires = DateTime.UtcNow.AddMinutes(AuthTokenExpiresInMins),
                SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256Signature),
                Issuer = Issuer,
                Audience = Audience
            };
            var token = tokenHandler.CreateToken(tokenDescriptor);
            return tokenHandler.WriteToken(token);
        }

        /// <summary>
        /// Generates a cryptographically random 64-byte refresh token value WITHOUT writing any
        /// cookie or touching the database.
        /// </summary>
        public static string BuildRefreshTokenValue()
        {
            using (var rng = new RNGCryptoServiceProvider())
            {
                byte[] randomBytes = new byte[64];
                rng.GetBytes(randomBytes);
                return Convert.ToBase64String(randomBytes);
            }
        }

        /// <summary>
        /// Writes the AuthToken + DeviceID cookies for an already-generated auth token value.
        /// HttpOnly / Secure / SameSite=Strict are preserved exactly as before.
        /// </summary>
        public static void SetAuthCookies(string authToken, string DeviceID)
        {
            var RefreshTokenExpiresInDays = double.Parse(JwtSettings.RefreshTokenExpiresInDays);

            HttpCookie authCookie = new HttpCookie("AuthToken", authToken)
            {
                HttpOnly = true,
                Secure = true,
                Expires = DateTime.Now.AddDays(RefreshTokenExpiresInDays),
                SameSite = SameSiteMode.Strict,
                Path = "/"
            };
            HttpContext.Current.Response.Cookies.Add(authCookie);
            HttpCookie deviceCookie = new HttpCookie("DeviceID", DeviceID)
            {
                HttpOnly = true,
                Secure = true,
                Expires = DateTime.UtcNow.AddDays(RefreshTokenExpiresInDays),
                SameSite = SameSiteMode.Strict,
                Path = "/"
            };
            HttpContext.Current.Response.Cookies.Add(deviceCookie);
        }

        /// <summary>
        /// Writes the RefreshToken + DeviceID cookies for an already-generated refresh token
        /// value. HttpOnly / Secure / SameSite=Strict are preserved exactly as before.
        /// </summary>
        public static void SetRefreshCookies(string refreshToken, string DeviceID)
        {
            var RefreshTokenExpiresInDays = double.Parse(JwtSettings.RefreshTokenExpiresInDays);

            HttpCookie refreshCookie = new HttpCookie("RefreshToken", refreshToken)
            {
                HttpOnly = true,
                Secure = true,
                Expires = DateTime.UtcNow.AddDays(RefreshTokenExpiresInDays),
                SameSite = SameSiteMode.Strict,
                Path = "/"
            };
            HttpContext.Current.Response.Cookies.Add(refreshCookie);
            HttpCookie deviceCookie = new HttpCookie("DeviceID", DeviceID)
            {
                HttpOnly = true,
                Secure = true,
                Expires = DateTime.UtcNow.AddDays(RefreshTokenExpiresInDays),
                SameSite = SameSiteMode.Strict,
                Path = "/"
            };
            HttpContext.Current.Response.Cookies.Add(deviceCookie);
        }

        public static string GenerateToken(string UserId, string DeviceID = "abcd")
        {
            var Issuer = JwtSettings.Issuer;
            var Audience = JwtSettings.Audience;
            var key = JwtSettings.GetKey();
            var AuthTokenExpiresInMins = double.Parse(JwtSettings.AuthTokenExpiresInMins);
            var RefreshTokenExpiresInDays = double.Parse(JwtSettings.RefreshTokenExpiresInDays);

            var tokenHandler = new JwtSecurityTokenHandler();

            var claims = new List<Claim>
            {
                new Claim(ClaimTypes.Name, UserId),
                new Claim(JwtRegisteredClaimNames.Sub, UserId),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };

            var tokenDescriptor = new SecurityTokenDescriptor
            {
                // The claims (including the per-token jti GUID) MUST be attached here. Previously
                // this was commented out, so every token issued in the same whole second was
                // identical -> duplicate AuthToken rows. Attaching Subject makes each token unique.
                Subject = new ClaimsIdentity(claims),
                Expires = DateTime.UtcNow.AddMinutes(AuthTokenExpiresInMins),
                SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256Signature),
                Issuer = Issuer,
                Audience = Audience
            };
            var token = tokenHandler.CreateToken(tokenDescriptor);
            var authToken = tokenHandler.WriteToken(token);            

            HttpCookie authCookie = new HttpCookie("AuthToken", authToken)
            {
                HttpOnly = true,
                Secure = true,
                Expires = DateTime.Now.AddDays(RefreshTokenExpiresInDays),//DateTime.UtcNow.AddMinutes(AuthTokenExpiresInMins),
                SameSite = SameSiteMode.Strict,
                Path = "/"
            };
            HttpContext.Current.Response.Cookies.Add(authCookie);
            HttpCookie deviceCookie = new HttpCookie("DeviceID", DeviceID)
            {
                HttpOnly = true,
                Secure = true,
                Expires = DateTime.UtcNow.AddDays(RefreshTokenExpiresInDays),
                SameSite = SameSiteMode.Strict,
                Path = "/"
            };
            HttpContext.Current.Response.Cookies.Add(deviceCookie);
            return authToken;
        }
        public static string GenerateRefreshToken(string UserId,string AuthToken,string DeviceID = "abcd")
        {
            var RefreshTokenExpiresInDays = double.Parse(JwtSettings.RefreshTokenExpiresInDays);
            var AuthTokenExpiresInMins = double.Parse(JwtSettings.AuthTokenExpiresInMins);
            var AuthTokenCookie = AuthToken;// HttpContext.Current.Request.Cookies["AuthToken"];            
            var Sessionidcookie = HttpContext.Current.Request.Cookies["ASP.NET_SessionId"];
            var refreshToken = "";
            using (var rng = new RNGCryptoServiceProvider())
            {
                byte[] randomBytes = new byte[64];
                rng.GetBytes(randomBytes);
                refreshToken = Convert.ToBase64String(randomBytes);
                
            }

            var refreshTokenRepo = new RefreshTokenRepo();
            refreshTokenRepo.SaveRefreshToken(new RefreshToken
            {
                UserId = UserId,
                Token = refreshToken,
                ExpiresAt = DateTime.Now.AddDays(RefreshTokenExpiresInDays),
                // Guard against a missing ASP.NET_SessionId cookie (previously a NullReferenceException).
                Session_id = Sessionidcookie != null ? Sessionidcookie.Value : string.Empty,
                AuthToken = AuthTokenCookie,
                AuthTokenExpiresAt = DateTime.Now.AddMinutes(AuthTokenExpiresInMins),
            });

            HttpCookie refreshCookie = new HttpCookie("RefreshToken", refreshToken)
            {
                HttpOnly = true,
                Secure = true,
                Expires = DateTime.UtcNow.AddDays(RefreshTokenExpiresInDays),
                SameSite = SameSiteMode.Strict,
                Path = "/"
            };
            HttpContext.Current.Response.Cookies.Add(refreshCookie);
            HttpCookie deviceCookie = new HttpCookie("DeviceID", DeviceID)
            {
                HttpOnly = true,
                Secure = true,
                Expires = DateTime.UtcNow.AddDays(RefreshTokenExpiresInDays),
                SameSite = SameSiteMode.Strict,
                Path = "/"
            };
            HttpContext.Current.Response.Cookies.Add(deviceCookie);
            return refreshToken;
        }

    }

    public class RefreshTokenRepo
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        string connectionString = SampWebApi.Utility.SecretConfig.ConnectionString("Connections");

        //private readonly string _connectionString = ConfigurationManager.ConnectionStrings["DefaultConnection"].ConnectionString;

        public void SaveRefreshToken(RefreshToken refreshToken)
        {
            using (var conn = new SqlConnection(connectionString))
            {

                //SqlConnection sqlConnection = new SqlConnection(connectionString);
                conn.Open();
                SqlCommand sqlCommand = new SqlCommand("uspInsertRefreshToken", conn);
                sqlCommand.CommandType = CommandType.StoredProcedure;
                sqlCommand.Parameters.AddWithValue("@UserId", refreshToken.UserId);
                sqlCommand.Parameters.AddWithValue("@Token", refreshToken.Token);
                sqlCommand.Parameters.AddWithValue("@ExpiresAt", refreshToken.ExpiresAt);
                sqlCommand.Parameters.AddWithValue("@IsRevoked", refreshToken.IsRevoked);
                sqlCommand.Parameters.AddWithValue("@SessionID", refreshToken.Session_id);
                sqlCommand.Parameters.AddWithValue("@AuthToken", refreshToken.AuthToken);
                sqlCommand.Parameters.AddWithValue("@AuthTokenExpiresAt", refreshToken.AuthTokenExpiresAt);
                DataTable DDT = new DataTable();
                SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                SDA.Fill(DDT);
                conn.Close();
                //var query = "INSERT INTO RefreshTokens (UserId, Token, ExpiresAt, IsRevoked) VALUES (@UserId, @Token, @ExpiresAt, 0)";
                //conn.Execute(query, refreshToken);
            }
        }

        public RefreshToken GetRefreshToken(string token)
        {
            DataTable DDT = new DataTable();
            var refreshToken = new RefreshToken();
            using (var conn = new SqlConnection(connectionString))
            {

                //SqlConnection sqlConnection = new SqlConnection(connectionString);
                conn.Open();
                SqlCommand sqlCommand = new SqlCommand("uspGetRefreshToken", conn);
                sqlCommand.CommandType = CommandType.StoredProcedure;
                sqlCommand.Parameters.AddWithValue("@TokenType", 1);
                sqlCommand.Parameters.AddWithValue("@Token", token);
                SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);    
                SDA.Fill(DDT);
                conn.Close();
            }

            if (DDT.Rows.Count > 0)
            {
                refreshToken = new RefreshToken
                {
                    Id = (Guid)(DDT.Rows[0]["Id"]),
                    Token = DDT.Rows[0]["Token"].ToString(),
                    UserId = DDT.Rows[0]["UserId"].ToString(),
                    ExpiresAt = Convert.ToDateTime(DDT.Rows[0]["ExpiresAt"]),
                    CreatedAt = Convert.ToDateTime(DDT.Rows[0]["CreatedAt"]),
                    IsRevoked = Convert.ToBoolean(DDT.Rows[0]["IsRevoked"])
                };
            }

            return refreshToken;
        }
        public RefreshToken GetAuthToken(string token)
        {
            DataTable DDT = new DataTable();
            var refreshToken = new RefreshToken();
            using (var conn = new SqlConnection(connectionString))
            {

                //SqlConnection sqlConnection = new SqlConnection(connectionString);
                conn.Open();
                SqlCommand sqlCommand = new SqlCommand("uspGetRefreshToken", conn);
                sqlCommand.CommandType = CommandType.StoredProcedure;
                sqlCommand.Parameters.AddWithValue("@TokenType", 2);
                sqlCommand.Parameters.AddWithValue("@Token", token);
                SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                SDA.Fill(DDT);
                conn.Close();
            }

            if (DDT.Rows.Count > 0)
            {
                refreshToken = new RefreshToken
                {
                    Id = (Guid)(DDT.Rows[0]["Id"]),
                    AuthToken = DDT.Rows[0]["AuthToken"].ToString(),
                    UserId = DDT.Rows[0]["UserId"].ToString(),
                    AuthTokenExpiresAt = Convert.ToDateTime(DDT.Rows[0]["AuthTokenExpireAt"]),
                    CreatedAt = Convert.ToDateTime(DDT.Rows[0]["CreatedAt"]),
                    IsRevoked = Convert.ToBoolean(DDT.Rows[0]["IsRevoked"])
                };
            }

            return refreshToken;
        }
        public void RevokeRefreshToken(int TokenType,string token)
        {
            // Backward-compatible wrapper: keeps the old "fire and forget" contract used by
            // logout and other callers. The row-count returned by uspUpdateRefreshToken is
            // ignored here. Concurrency-sensitive callers (token refresh) must use
            // TryRevokeRefreshToken / RotateRefreshToken instead.
            TryRevokeRefreshToken(TokenType, token);
        }

        /// <summary>
        /// Revokes a still-active token row and reports whether THIS call was the one that
        /// changed it. Returns true only when an active row (IsRevoked = 1) was flipped to
        /// revoked by this invocation; false when the row was already revoked by a concurrent
        /// request. Used to detect the loser of a refresh race.
        /// </summary>
        public bool TryRevokeRefreshToken(int TokenType, string token)
        {
            DataTable DDT = new DataTable();
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                SqlCommand sqlCommand = new SqlCommand("uspUpdateRefreshToken", conn);
                sqlCommand.CommandType = CommandType.StoredProcedure;
                sqlCommand.Parameters.AddWithValue("@TokenType", TokenType);
                sqlCommand.Parameters.AddWithValue("@Token", token);
                SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                SDA.Fill(DDT);
                conn.Close();
            }

            if (DDT.Rows.Count > 0 && DDT.Columns.Contains("RowsAffected"))
            {
                return Convert.ToInt32(DDT.Rows[0]["RowsAffected"]) > 0;
            }
            // Older uspUpdateRefreshToken (pre-13) returns no result set. Fall back to the
            // previous behaviour: assume the revoke happened (the DB-side unique index and the
            // atomic RotateRefreshToken proc are the real guards when 13 is deployed).
            return true;
        }

        /// <summary>
        /// Atomically rotates a session: revokes the old (still-active) auth-token row and, only
        /// if this request won that claim, inserts one new active row with the supplied new
        /// tokens. Returns true for the single winning request; false for every concurrent
        /// request that arrived with the same expiring tokens. Nothing is inserted on the losing
        /// path, so no duplicate/conflicting rows are created and the winner's cookies survive.
        /// </summary>
        public bool RotateRefreshToken(Guid oldRowId, string userId, string newRefreshToken,
            DateTime newRefreshExpires, string sessionId, string newAuthToken, DateTime newAuthExpires)
        {
            DataTable DDT = new DataTable();
            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                SqlCommand sqlCommand = new SqlCommand("uspRotateRefreshToken", conn);
                sqlCommand.CommandType = CommandType.StoredProcedure;
                // Rotate by the exact primary key the controller already validated. The row Id is
                // a guaranteed-unique GUID, so this is immune to any AuthToken value collision.
                sqlCommand.Parameters.AddWithValue("@OldRowId", oldRowId);
                sqlCommand.Parameters.AddWithValue("@UserId", (object)userId ?? DBNull.Value);
                sqlCommand.Parameters.AddWithValue("@NewRefreshToken", newRefreshToken);
                sqlCommand.Parameters.AddWithValue("@NewRefreshExpires", newRefreshExpires);
                sqlCommand.Parameters.AddWithValue("@SessionID", (object)sessionId ?? string.Empty);
                sqlCommand.Parameters.AddWithValue("@NewAuthToken", newAuthToken);
                sqlCommand.Parameters.AddWithValue("@NewAuthExpires", newAuthExpires);
                SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                SDA.Fill(DDT);
                conn.Close();
            }

            return DDT.Rows.Count > 0 && DDT.Columns.Contains("Won")
                && Convert.ToBoolean(DDT.Rows[0]["Won"]);
        }
        public bool ValidateTrustDevice(string DeviceID)
        {
            DataTable DDT = new DataTable();
            using (var conn = new SqlConnection(connectionString))
            {

                //SqlConnection sqlConnection = new SqlConnection(connectionString);
                conn.Open();
                SqlCommand sqlCommand = new SqlCommand("uspValidateDevice", conn);
                sqlCommand.CommandType = CommandType.StoredProcedure;
                sqlCommand.Parameters.AddWithValue("@Mode", 5);
                sqlCommand.Parameters.AddWithValue("@DeviceID", DeviceID);
                SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                SDA.Fill(DDT);
                conn.Close();
            }
            //DataTable dtDevData = bl.BL_ExecuteParamSP("uspValidateDevice", 5, DeviceID);
            return DDT.Rows.Count > 0;
        }
    }
}