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

        protected override bool IsAuthorized(System.Web.Http.Controllers.HttpActionContext actionContext)
        {
            var cookie = HttpContext.Current.Request.Cookies["AuthToken"];
            if (cookie != null)
            {
                var token = cookie.Value;
                var AuthTokenValidate = _refreshTokenRepo.GetAuthToken(token);
                if (AuthTokenValidate == null || AuthTokenValidate.AuthTokenExpiresAt <= DateTime.Now || !AuthTokenValidate.IsRevoked)
                {
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
                //var key = Encoding.UTF8.GetBytes("yPqB3dmFXNfJg6X1W/JzNX4A2Sc6sZ7Q7+p2lYxPrCY=");

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