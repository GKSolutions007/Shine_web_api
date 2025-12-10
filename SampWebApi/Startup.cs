using Microsoft.IdentityModel.Tokens;
using Microsoft.Owin;
using Microsoft.Owin.Security.Jwt;
using Microsoft.Owin.Security.OAuth;
using Microsoft.Owin.Cors;
using Owin;
using SampWebApi.Utility;
using System;
using System.Configuration;
using System.Diagnostics;
using System.Text;
using System.Web.Cors;
using System.Threading.Tasks;
using DocumentFormat.OpenXml.Bibliography;

[assembly: OwinStartup(typeof(SampWebApi.Startup))]

namespace SampWebApi
{

    public class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            Debug.WriteLine("OWIN Startup is running..."); // Add this line
                                                           //                                               //ConfigureOAuth(app);
                                                           //                                               // In Program.cs or Startup.cs
                                                           //builder.Services.AddCors(options =>
                                                           //{
                                                           //    options.AddPolicy("AllowLocalhost", policy =>
                                                           //    {
                                                           //        policy.WithOrigins("https://localhost:44326")
                                                           //              .AllowAnyHeader()
                                                           //              .AllowAnyMethod();
                                                           //    });
                                                           //});
                                                           // For development - allow all origins (uncomment for development)
                                                           //app.UseCors(CorsOptions.AllowAll);
                                                           //ConfigureOAuth(app);

            // For production - use specific origins (uncomment and customize for production)
            
            //app.UseCors(new CorsOptions
            //{
            //    PolicyProvider = new CorsPolicyProvider
            //    {
            //        PolicyResolver = request =>
            //        {
            //            var policy = new CorsPolicy
            //            {
            //                AllowAnyOrigin = false,
            //                AllowAnyMethod = true,
            //                AllowAnyHeader = true,
            //                SupportsCredentials = true
            //            };
            //            //policy.Origins.Add("https://localhost:44326");
            //            // Add allowed origins
            //            policy.Origins.Add("https://localhost:44326");

            //            // For development, you might want to add additional origins
            //            // corsPolicy.Origins.Add("https://yourotherdomain.com");

            //            var corsOptions1 = new CorsOptions
            //            {
            //                PolicyProvider = new CorsPolicyProvider
            //                {
            //                    PolicyResolver = context => Task.FromResult(policy)
            //                }
            //            };
            //            // Add other allowed origins as needed
            //            // policy.Origins.Add("https://yourotherdomain.com");
            //            return Task.FromResult(policy);
            //        }
            //    }
            //});


            // Add any additional OWIN middleware here
            // Example: Configure authentication if needed
            // ConfigureOAuth(app);
            //app.UseAuthorization();

            //app.MapControllers();

            //app.Run();


            //// Later in the pipeline
            //app.UseCors("AllowLocalhost");
            //string[] a1 = { "https://localhost:44326" };
            //string[] a2 = { "GET, POST, PUT, DELETE" };
            //string[] a3 = { "Content-Type, Authorization" };
            //app.Use(async (context, next) =>
            //{
            //    context.Response.Headers.Add("Access-Control-Allow-Origin", a1);
            //    context.Response.Headers.Add("Access-Control-Allow-Methods", a2);
            //    context.Response.Headers.Add("Access-Control-Allow-Headers", a3);

            //    if (context.Request.Method == "OPTIONS")
            //    {
            //        context.Response.StatusCode = 200;
            //        return;
            //    }

            //    await next();
            //});

            //var builder = WebApplication.CreateBuilder(args);

            //// Add services to the container
            //builder.Services.AddControllers();

            //// Add CORS services
            //builder.Services.AddCors(options =>
            //{
            //    options.AddPolicy("AllowSpecificOrigin", policy =>
            //    {
            //        policy.WithOrigins("https://localhost:44326") // Your frontend origin
            //              .AllowAnyHeader()
            //              .AllowAnyMethod()
            //              .AllowCredentials();
            //    });
            //});

            //// If you want to allow all origins in development
            //builder.Services.AddCors(options =>
            //{
            //    options.AddPolicy("AllowAll", policy =>
            //    {
            //        policy.AllowAnyOrigin()
            //              .AllowAnyHeader()
            //              .AllowAnyMethod();
            //    });
            //});

            //var app = builder.Build();

            //// Configure the HTTP request pipeline
            //if (app.Environment.IsDevelopment())
            //{
            //    app.UseDeveloperExceptionPage();
            //    app.UseCors("AllowAll"); // Use this for development
            //}
            //else
            //{
            //    app.UseCors("AllowSpecificOrigin"); // Use this for production
            //}

            //// Enable static file serving
            //app.UseStaticFiles();

            //app.UseRouting();
            //app.UseAuthorization();

            //app.MapControllers();

            //app.Run();
        }

        public void ConfigureOAuth(IAppBuilder app)
        {
            var key = Encoding.UTF8.GetBytes("yPqB3dmFXNfJg6X1W/JzNX4A2Sc6sZ7Q7+p2lYxPrCY="); // Use a secure key
            string APIurl = ConfigurationManager.AppSettings["ValidIssuer"].ToString();
            string url = ConfigurationManager.AppSettings["ValidAudience"].ToString();

            app.UseOAuthAuthorizationServer(new OAuthAuthorizationServerOptions
            {
                AllowInsecureHttp = true, //   Set false in production
                TokenEndpointPath = new PathString("/token"),
                AccessTokenExpireTimeSpan = TimeSpan.FromMinutes(1),
                Provider = new CookieOAuthProvider(), // Custom provider for cookies                
            });

            app.UseJwtBearerAuthentication(new JwtBearerAuthenticationOptions
            {
                TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidateIssuerSigningKey = true,
                    ValidIssuer = APIurl,//"https://localhost:44396/",//APIurl,//
                    ValidAudience = url,//"https://localhost:44326/",//url,//
                    IssuerSigningKey = new SymmetricSecurityKey(key),
                    ValidateLifetime = true
                }
            });
        }
    }
}
