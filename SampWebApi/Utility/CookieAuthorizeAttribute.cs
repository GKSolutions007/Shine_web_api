using Microsoft.IdentityModel.Tokens;
using SampWebApi.BuisnessLayer;
using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Threading;
using System.Web;
using System.Web.Http;

namespace SampWebApi.Utility
{
    public class CookieAuthorizeAttribute : AuthorizeAttribute
    {
        private readonly RefreshTokenRepo _refreshTokenRepo = new RefreshTokenRepo();
        clsBusinessLayer bl = new clsBusinessLayer();

        protected override bool IsAuthorized(System.Web.Http.Controllers.HttpActionContext actionContext)
        {
            var cookie = HttpContext.Current.Request.Cookies["AuthToken"];
            if (cookie == null || string.IsNullOrEmpty(cookie.Value))
                return false;

            if (cookie != null)
            {
                var token = cookie.Value;
                var AuthTokenValidate = _refreshTokenRepo.GetAuthToken(token);
                // IsRevoked = true means the session has been ended (revoked/logged-out).
                // A valid active session has IsRevoked = false.
                if (AuthTokenValidate == null || AuthTokenValidate.AuthTokenExpiresAt <= DateTime.Now || !AuthTokenValidate.IsRevoked)
                {
                    //bl.BL_WriteErrorMsginLog("CookieAuthorize", "IsAuthorized", "Token invalid, expired, or revoked for token: " + token?.Substring(0, Math.Min(20, token.Length)));
                    return false;
                }
                var TrustDevice = HttpContext.Current.Request.Cookies["DeviceID"];
                if (TrustDevice != null)
                {
                    var devid = TrustDevice.Value;
                    bool isValid = _refreshTokenRepo.ValidateTrustDevice(devid);
                    if (!isValid)
                    {
                        return false;
                    }
                }
                var Issuer = JwtSettings.Issuer;
                var Audience = JwtSettings.Audience;
                var key = JwtSettings.GetKey();

                var tokenHandler = new JwtSecurityTokenHandler();
                var validationParameters = new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(key),
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidIssuer = Issuer,
                    ValidAudience = Audience,
                    ValidateLifetime = true
                };

                try
                {
                    var principal = tokenHandler.ValidateToken(token, validationParameters, out _);
                    HttpContext.Current.User = principal;
                    return true;
                }
                catch (Exception)
                {
                    return false;
                }
            }
            return false;
        }
    }
}