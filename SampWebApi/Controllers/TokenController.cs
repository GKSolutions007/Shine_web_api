using SampWebApi.BuisnessLayer;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Web;
using System.Web.Http;

namespace SampWebApi.Controllers
{
    [RoutePrefix("api/token")]
    public class TokenController : ApiController
    {
        clsBusinessLayer bl = new clsBusinessLayer();
        private readonly RefreshTokenRepo _refreshTokenRepo = new RefreshTokenRepo();

        [HttpPost]
        [Route("refresh")]
        public IHttpActionResult RefreshToken()
        {
            try
            {
                var refreshTokenCookie = HttpContext.Current.Request.Cookies["RefreshToken"];
                if (refreshTokenCookie == null)
                {
                    return Unauthorized();
                }
                var TrustDevice = HttpContext.Current.Request.Cookies["DeviceID"];
                if (TrustDevice != null)
                {
                    var devid = TrustDevice.Value;
                    bool isValid = _refreshTokenRepo.ValidateTrustDevice(devid);
                    if (!isValid)
                    {
                        return BadRequest("Unauthorized request from unknown device.");
                    }
                }
                else
                {
                    return BadRequest("Unauthorized request from unknown device.");
                }
                var cookie = HttpContext.Current.Request.Cookies["AuthToken"];
                if (cookie == null || string.IsNullOrEmpty(cookie.Value))
                {
                    return BadRequest("Auth token cookie is missing.");
                }

                var token = cookie.Value;
                var AuthTokenValidate = _refreshTokenRepo.GetAuthToken(token);
                if (AuthTokenValidate == null || AuthTokenValidate.AuthToken == null)
                {
                    return BadRequest("Invalid Auth token.");
                }
                // NOTE: tblRefreshTokens.IsRevoked is inverted: 1 (true) = ACTIVE, 0 (false) = revoked.
                // uspInsertRefreshToken always writes 1; uspUpdateRefreshToken (logout / rotation) writes 0.
                if (!AuthTokenValidate.IsRevoked)
                {
                    return BadRequest("Unauthorized request from closed session.");
                }
                var refreshToken = _refreshTokenRepo.GetRefreshToken(refreshTokenCookie.Value);
                // GetRefreshToken returns an empty object (not null) when no row matches.
                if (refreshToken == null || string.IsNullOrEmpty(refreshToken.Token))
                {
                    return BadRequest("Invalid refresh token.");
                }
                // Reject already-rotated or logged-out refresh tokens (prevents replay).
                if (!refreshToken.IsRevoked || refreshToken.ExpiresAt <= DateTime.Now)
                {
                    return BadRequest("Invalid or expired refresh token.");
                }
                // The refresh token must belong to the same session row as the auth token cookie.
                if (refreshToken.Id != AuthTokenValidate.Id)
                {
                    return BadRequest("Refresh token does not match the current session.");
                }
                // Rotate: deactivate the old row, then issue a new access + refresh token pair.
                _refreshTokenRepo.RevokeRefreshToken(2, token);
                var newAccessToken = TokenHelper.GenerateToken(refreshToken.UserId, TrustDevice.Value);
                if (newAccessToken == null)
                {
                    return Unauthorized();
                }
                TokenHelper.GenerateRefreshToken(refreshToken.UserId, newAccessToken, TrustDevice.Value);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Token", "refresh", ex.Message);
                // Do not report success when rotation failed; the client will send the user to login.
                return Unauthorized();
            }
            return Ok();
        }
    }
}
