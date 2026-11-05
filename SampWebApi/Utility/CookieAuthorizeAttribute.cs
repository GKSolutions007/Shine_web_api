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
        protected override bool IsAuthorized(System.Web.Http.Controllers.HttpActionContext actionContext)
        {
            string userId;
            return ApiAuth.TryAuthenticate(out userId);
        }
    }

    /// <summary>
    /// Cookie/JWT session check shared by [CookieAuthorize] and by actions that are public for some
    /// requests but need to know whether the caller is signed in (for example api/signup/save).
    /// </summary>
    public static class ApiAuth
    {
        private const string UserIdItemKey = "ApiAuth.UserId";

        /// <summary>
        /// True when the request carries a valid, active session. userId is the signed-in user's ID,
        /// taken from the server-side token record (the JWT itself carries no user claims).
        /// </summary>
        public static bool TryAuthenticate(out string userId)
        {
            userId = null;
            var context = HttpContext.Current;
            if (context == null) return false;
            if (context.Items.Contains(UserIdItemKey))
            {
                userId = context.Items[UserIdItemKey] as string;
                return true;
            }

            var cookie = context.Request.Cookies["AuthToken"];
            if (cookie == null || string.IsNullOrEmpty(cookie.Value))
                return false;

            var repo = new RefreshTokenRepo();
            var token = cookie.Value;
            var AuthTokenValidate = repo.GetAuthToken(token);
            // IsRevoked = true means the session has been ended (revoked/logged-out).
            // A valid active session has IsRevoked = false.
            if (AuthTokenValidate == null || AuthTokenValidate.AuthTokenExpiresAt <= DateTime.Now || !AuthTokenValidate.IsRevoked)
            {
                return false;
            }
            var TrustDevice = context.Request.Cookies["DeviceID"];
            if (TrustDevice != null)
            {
                if (!repo.ValidateTrustDevice(TrustDevice.Value))
                    return false;
            }

            var tokenHandler = new JwtSecurityTokenHandler();
            var validationParameters = new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(JwtSettings.GetKey()),
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidIssuer = JwtSettings.Issuer,
                ValidAudience = JwtSettings.Audience,
                ValidateLifetime = true
            };

            try
            {
                var principal = tokenHandler.ValidateToken(token, validationParameters, out _);
                context.User = principal;
                userId = AuthTokenValidate.UserId ?? string.Empty;
                context.Items[UserIdItemKey] = userId;
                return true;
            }
            catch (Exception)
            {
                return false;
            }
        }
    }
}
