using Microsoft.IdentityModel.Tokens;
using Microsoft.Owin.Security.OAuth;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using System.Web;

namespace SampWebApi.Utility
{
    public class CookieOAuthProvider : OAuthAuthorizationServerProvider
    {
        public override async Task ValidateClientAuthentication(OAuthValidateClientAuthenticationContext context)
        {
            context.Validated(); // Always validate the client
        }

        public override async Task GrantResourceOwnerCredentials(OAuthGrantResourceOwnerCredentialsContext context)
        {
            context.OwinContext.Response.Headers.Add("Access-Control-Allow-Origin", new[] { "*" });
            string APIurl = ConfigurationManager.AppSettings["ValidIssuer"].ToString();
            string url = ConfigurationManager.AppSettings["ValidAudience"].ToString();
            // Dummy User Validation (Replace with DB authentication)
            if (context.UserName == "admin" && context.Password == "123")
            {
                var identity = new ClaimsIdentity(context.Options.AuthenticationType);
                identity.AddClaim(new Claim(ClaimTypes.Name, context.UserName));
                identity.AddClaim(new Claim("role", "admin"));

                var tokenHandler = new JwtSecurityTokenHandler();
                var key = Encoding.UTF8.GetBytes("yPqB3dmFXNfJg6X1W/JzNX4A2Sc6sZ7Q7+p2lYxPrCY=");

                var tokenDescriptor = new SecurityTokenDescriptor
                {
                    Subject = identity,
                    Expires = DateTime.UtcNow.AddMinutes(30),
                    SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256Signature),
                    Issuer = APIurl,//"https://localhost:44396/",
                    Audience = url,// "https://localhost:44326/"
                };

                var token = tokenHandler.CreateToken(tokenDescriptor);
                var tokenString = tokenHandler.WriteToken(token);

                // Set JWT as an HTTP-Only Cookie
                var cookie = new HttpCookie("AuthToken", tokenString)
                {
                    HttpOnly = true,  //  Secure - JavaScript cannot access
                    Secure = true,    //  Use HTTPS only (set true in production)
                    Expires = DateTime.UtcNow.AddMinutes(30),
                    SameSite = SameSiteMode.Strict //  Prevents CSRF attacks
                };

                HttpContext.Current.Response.Cookies.Add(cookie);
                context.Validated(identity);
            }
            else
            {
                context.SetError("invalid_grant", "Invalid username or password");
            }
        }
    }
}