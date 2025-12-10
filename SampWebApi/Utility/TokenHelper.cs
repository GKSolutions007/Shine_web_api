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
        public static string GenerateToken(string UserId)
        {
            var Issuer = JwtSettings.Issuer;
            var Audience = JwtSettings.Audience;
            var key = JwtSettings.GetKey();
            var AuthTokenExpiresInMins = double.Parse(JwtSettings.AuthTokenExpiresInMins);

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
                Expires = DateTime.UtcNow.AddMinutes(AuthTokenExpiresInMins),
                SameSite = SameSiteMode.Strict,
                Path = "/"
            };
            HttpContext.Current.Response.Cookies.Add(authCookie);

            return authToken;
        }
        public static string GenerateRefreshToken(string UserId)
        {
            var RefreshTokenExpiresInDays = double.Parse(JwtSettings.RefreshTokenExpiresInDays);
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
                ExpiresAt = DateTime.Now.AddDays(RefreshTokenExpiresInDays)
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

        public void RevokeRefreshToken(string token)
        {
            DataTable DDT = new DataTable();
            using (var conn = new SqlConnection(connectionString))
            {

                //SqlConnection sqlConnection = new SqlConnection(connectionString);
                conn.Open();
                SqlCommand sqlCommand = new SqlCommand("uspUpdateRefreshToken", conn);
                sqlCommand.CommandType = CommandType.StoredProcedure;
                SqlDataAdapter SDA = new SqlDataAdapter(sqlCommand);
                SDA.Fill(DDT);
                conn.Close();
            }
        }
    }
}