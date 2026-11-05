using SampWebApi.BuisnessLayer;
using SampWebApi.Utility;
using System;
using System.Collections.Concurrent;
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

        // In-process single-flight guard. Collapses a burst of concurrent refresh calls that
        // arrive at THIS instance with the same refresh token into one DB rotation; the rest
        // wait and then observe the already-rotated state. This is a fast first line only --
        // correctness across multiple API instances/app pools is guaranteed by the atomic
        // uspRotateRefreshToken proc + the filtered unique index, not by this lock.
        private static readonly ConcurrentDictionary<string, SemaphoreSlim> _refreshLocks =
            new ConcurrentDictionary<string, SemaphoreSlim>();

        private static SemaphoreSlim GetRefreshLock(string key)
        {
            return _refreshLocks.GetOrAdd(key ?? string.Empty, _ => new SemaphoreSlim(1, 1));
        }

        [HttpPost]
        [Route("refresh")]
        public IHttpActionResult RefreshToken()
        {
            string lockKey = null;
            SemaphoreSlim gate = null;
            bool gateTaken = false;
            try
            {
                var preRefreshCookie = HttpContext.Current.Request.Cookies["RefreshToken"];
                lockKey = preRefreshCookie != null ? preRefreshCookie.Value : null;
                gate = GetRefreshLock(lockKey);
                // Bounded wait so a stuck request can never block the whole session forever.
                gateTaken = gate.Wait(TimeSpan.FromSeconds(10));
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
                        bl.BL_WriteErrorMsginLog("Token", "refresh", "Unauthorized request from unknown device.","Info");
                        return BadRequest("Unauthorized request from unknown device.");
                    }
                }
                else
                {
                    bl.BL_WriteErrorMsginLog("Token", "refresh", "Unauthorized request from unknown device.", "Info");
                    return BadRequest("Unauthorized request from unknown device.");
                }
                var cookie = HttpContext.Current.Request.Cookies["AuthToken"];
                if (cookie == null || string.IsNullOrEmpty(cookie.Value))
                {
                    bl.BL_WriteErrorMsginLog("Token", "refresh", "Auth token cookie is missing.", "Info");
                    return BadRequest("Auth token cookie is missing.");
                }

                var token = cookie.Value;
                var AuthTokenValidate = _refreshTokenRepo.GetAuthToken(token);
                if (AuthTokenValidate == null || AuthTokenValidate.AuthToken == null)
                {
                    bl.BL_WriteErrorMsginLog("Token", "refresh", "Invalid Auth token.", "Info");
                    return BadRequest("Invalid Auth token.");
                }
                // NOTE: tblRefreshTokens.IsRevoked is inverted: 1 (true) = ACTIVE, 0 (false) = revoked.
                // uspInsertRefreshToken always writes 1; uspUpdateRefreshToken (logout / rotation) writes 0.
                if (!AuthTokenValidate.IsRevoked)
                {
                    string Tokeninfo = "Authtoken : " + AuthTokenValidate.AuthToken + "\n, AuthtokenExpiryAt : " + AuthTokenValidate.AuthTokenExpiresAt;
                    bl.BL_WriteErrorMsginLog("Token", "refresh", "Unauthorized request from closed session. Token Info : " + Tokeninfo, "Info");
                    return BadRequest("Unauthorized request from closed session.");
                }
                var refreshToken = _refreshTokenRepo.GetRefreshToken(refreshTokenCookie.Value);
                // GetRefreshToken returns an empty object (not null) when no row matches.
                if (refreshToken == null || string.IsNullOrEmpty(refreshToken.Token))
                {
                    bl.BL_WriteErrorMsginLog("Token", "refresh", "Invalid refresh token.", "Info");
                    return BadRequest("Invalid refresh token.");
                }
                // Reject already-rotated or logged-out refresh tokens (prevents replay).
                if (!refreshToken.IsRevoked || refreshToken.ExpiresAt <= DateTime.Now)
                {
                    bl.BL_WriteErrorMsginLog("Token", "refresh", "Invalid or expired refresh token.", "Info"); 
                    return BadRequest("Invalid or expired refresh token.");
                }
                // The refresh token must belong to the same session row as the auth token cookie.
                if (refreshToken.Id != AuthTokenValidate.Id)
                {
                    bl.BL_WriteErrorMsginLog("Token", "refresh", "Refresh token does not match the current session.", "Info");
                    return BadRequest("Refresh token does not match the current session.");
                }
                // --- Atomic rotation ---
                // Pre-generate the new token values WITHOUT writing any cookie, then ask the DB
                // to atomically (a) revoke the old active row only if it is still active and
                // (b) insert exactly one new active row, but only for the single request that
                // wins that claim. Concurrent requests carrying the same expired tokens get
                // won == false and MUST NOT write cookies: doing so would overwrite the winner's
                // fresh cookies with stale values and log the user out.
                var sessionCookie = HttpContext.Current.Request.Cookies["ASP.NET_SessionId"];
                var sessionId = sessionCookie != null ? sessionCookie.Value : string.Empty;

                var newAccessToken = TokenHelper.BuildAuthTokenValue(refreshToken.UserId);
                var newRefreshToken = TokenHelper.BuildRefreshTokenValue();
                var refreshExpires = DateTime.Now.AddDays(double.Parse(JwtSettings.RefreshTokenExpiresInDays));
                var authExpires = DateTime.Now.AddMinutes(double.Parse(JwtSettings.AuthTokenExpiresInMins));

                // Rotate by the primary key of the row we just validated (AuthTokenValidate.Id),
                // which equals refreshToken.Id (checked above). The row Id is a unique GUID, so
                // this cannot be confused by any duplicate/colliding AuthToken values.
                bool won = _refreshTokenRepo.RotateRefreshToken(
                    AuthTokenValidate.Id, refreshToken.UserId, newRefreshToken, refreshExpires,
                    sessionId, newAccessToken, authExpires);

                if (!won)
                {
                    // Another concurrent request already rotated this session. Tell the client to
                    // retry once; by then the winner's response has set the new cookies, so the
                    // retried original request authenticates normally. 409 (not 401) so the
                    // refresh retry loop is not mistaken for a logout.
                    bl.BL_WriteErrorMsginLog("Token", "refresh",
                        "Concurrent refresh detected; this request did not win rotation. Client should retry.", "Info");
                    return Conflict();
                }

                // Winner only: publish the new cookies.
                TokenHelper.SetAuthCookies(newAccessToken, TrustDevice.Value);
                TokenHelper.SetRefreshCookies(newRefreshToken, TrustDevice.Value);
            }
            catch(Exception ex)
            {
                bl.BL_WriteErrorMsginLog("Token", "refresh", ex.Message);
                // Do not report success when rotation failed; the client will send the user to login.
                return Unauthorized();
            }
            finally
            {
                if (gate != null && gateTaken)
                {
                    gate.Release();
                }
                // Refresh tokens are single-use: once rotated, this key is never seen again.
                // Evict the semaphore so the dictionary does not grow without bound. Only remove
                // when no other request still holds/awaits the gate (CurrentCount == 1).
                if (gate != null && lockKey != null && gate.CurrentCount == 1)
                {
                    SemaphoreSlim removed;
                    _refreshLocks.TryRemove(lockKey, out removed);
                }
            }
            return Ok();
        }
    }
}
