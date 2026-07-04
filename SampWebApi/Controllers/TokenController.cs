using SampWebApi.BuisnessLayer;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
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

                var token = cookie.Value;
                var AuthTokenValidate = _refreshTokenRepo.GetAuthToken(token);
                if (AuthTokenValidate.AuthToken == null)// || AuthTokenValidate.AuthTokenExpiresAt <= DateTime.Now || AuthTokenValidate.IsRevoked
                {
                    return BadRequest("Invalid Auth token.");
                }
                else if (!AuthTokenValidate.IsRevoked)
                {
                    return BadRequest("Unauthorized request from closed session.");
                }
                var refreshToken = _refreshTokenRepo.GetRefreshToken(refreshTokenCookie.Value);
                if (refreshToken == null || refreshToken.ExpiresAt <= DateTime.Now)// || refreshToken.IsRevoked
                {
                    return BadRequest("Invalid or expired refresh token.");
                }
                _refreshTokenRepo.RevokeRefreshToken(2, token);
                // Validate and generate new access token
                var newAccessToken = TokenHelper.GenerateToken(refreshToken.UserId, TrustDevice.Value);
                var newRefreshToken = TokenHelper.GenerateRefreshToken(refreshToken.UserId, newAccessToken, TrustDevice.Value);

                if (newAccessToken == null)
                {
                    return Unauthorized();
                }
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Token", "refresh", ex.Message);
            }
            return Ok();//new { access_token = newAccessToken }
        }
    }
}
