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
        private readonly RefreshTokenRepo _refreshTokenRepo = new RefreshTokenRepo();

        [HttpPost]
        [Route("refresh")]
        public IHttpActionResult RefreshToken()
        {
            var refreshTokenCookie = HttpContext.Current.Request.Cookies["RefreshToken"];
            if (refreshTokenCookie == null)
            {
                return Unauthorized();
            }
            var cookie = HttpContext.Current.Request.Cookies["AuthToken"];

            var token = cookie.Value;
            var AuthTokenValidate = _refreshTokenRepo.GetAuthToken(token);
            if (AuthTokenValidate.AuthToken == null)// || AuthTokenValidate.AuthTokenExpiresAt <= DateTime.Now || AuthTokenValidate.IsRevoked
            {
                return BadRequest("Invalid Auth token.");
            }
            var refreshToken = _refreshTokenRepo.GetRefreshToken(refreshTokenCookie.Value);
            if (refreshToken == null || refreshToken.ExpiresAt <= DateTime.Now)// || refreshToken.IsRevoked
            {
                return BadRequest("Invalid or expired refresh token.");
            }
            _refreshTokenRepo.RevokeRefreshToken(2, token);
            // Validate and generate new access token
            var newAccessToken = TokenHelper.GenerateToken(refreshToken.UserId);
            var newRefreshToken= TokenHelper.GenerateRefreshToken(refreshToken.UserId, newAccessToken);

            if (newAccessToken == null)
            {
                return Unauthorized();
            }

            return Ok();//new { access_token = newAccessToken }
        }
    }
}
