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
                //Subject = identity,
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
                Session_id = Sessionidcookie.Value,
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
        string connectionString = clsEncryptDecrypt.Decrypt(ConfigurationManager.ConnectionStrings["Connections"].ConnectionString);

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
            DataTable DDT = new DataTable();
            using (var conn = new SqlConnection(connectionString))
            {

                //SqlConnection sqlConnection = new SqlConnection(connectionString);
                conn.Open();
                SqlCommand sqlCommand = new SqlCommand("uspUpdateRefreshToken", conn);
                sqlCommand.CommandType = CommandType.StoredProcedure;
                sqlCommand.Parameters.AddWithValue("@TokenType", TokenType);
                sqlCommand.Parameters.AddWithValue("@Token", token);
                SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                SDA.Fill(DDT);
                conn.Close();
            }
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