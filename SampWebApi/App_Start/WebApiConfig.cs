using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Net.Http; // Added for DelegatingHandler, HttpRequestMessage, HttpResponseMessage
using System.Net.Http.Headers;
using System.Web;
using System.Web.Http;
using System.Web.Http.Controllers;
using System.Web.Http.Cors;
using System.Web.Http.Filters;

namespace SampWebApi
{
    public static class WebApiConfig
    {
        public static void Register(HttpConfiguration config)
        {
            string allowedOrigins = ConfigurationManager.AppSettings["AllowedOrigins"];
            // Guard: never pass null/empty to the CORS attribute. A null origin combined with
            // SupportsCredentials=true is a misconfiguration. If the setting is missing we fail
            // closed by disallowing cross-origin requests rather than silently allowing all.
            if (string.IsNullOrWhiteSpace(allowedOrigins))
            {
                allowedOrigins = "null"; // effectively disallows CORS until configured
            }
            // EnableCorsAttribute accepts a comma-separated list, so multiple environment origins
            // can be configured in appSettings["AllowedOrigins"] (e.g. "https://a,https://b").
            var cors = new EnableCorsAttribute(allowedOrigins, headers: "*", methods: "*")
            {
                SupportsCredentials = true //  Allows cookies to be sent
            };
            config.EnableCors(cors);

            // Add a global message handler to append embedding headers for PDF responses
            config.MessageHandlers.Add(new PdfEmbeddingHeaderHandler(allowedOrigins));

            config.Formatters.JsonFormatter.SupportedMediaTypes.Add(new MediaTypeHeaderValue("application/json"));
            // Web API routes
            config.MapHttpAttributeRoutes();

            config.Routes.MapHttpRoute(
                name: "DefaultApi",
                routeTemplate: "api/{controller}/{id}",
                defaults: new { id = RouteParameter.Optional }
            );
            config.Filters.Add(new SessionEnabledAttribute());
            // Safety net: return a proper HTTP 500 + JSON body for any UNCAUGHT exception,
            // instead of the default HTML error page. Controllers that catch their own
            // exceptions are unaffected.
            config.Filters.Add(new SampWebApi.Utility.GlobalExceptionFilter());
            //var cors = new EnableCorsAttribute("*", "*", "*");
        }
    }
    public class SessionEnabledAttribute : ActionFilterAttribute
    {
        public override void OnActionExecuting(HttpActionContext actionContext)
        {
            var session = HttpContext.Current.Session;
            base.OnActionExecuting(actionContext);
        }
    }

    // Adds frame/CORS headers for PDF responses to allow embedding from allowed origin
    public class PdfEmbeddingHeaderHandler : System.Net.Http.DelegatingHandler
    {
        private readonly string _allowedOrigin;
        public PdfEmbeddingHeaderHandler(string allowedOrigin)
        {
            _allowedOrigin = allowedOrigin;
        }
        protected override System.Threading.Tasks.Task<System.Net.Http.HttpResponseMessage> SendAsync(System.Net.Http.HttpRequestMessage request, System.Threading.CancellationToken cancellationToken)
        {
            return base.SendAsync(request, cancellationToken).ContinueWith(task =>
            {
                var response = task.Result;
                try
                {
                    if (response != null && response.Content != null)
                    {
                        var mediaType = response.Content.Headers.ContentType?.MediaType;
                        if (string.Equals(mediaType, "application/pdf", StringComparison.OrdinalIgnoreCase))
                        {
                            // Do NOT set Access-Control-Allow-Origin here to avoid duplicates with Web API CORS
                            if (!response.Headers.Contains("Vary"))
                                response.Headers.Add("Vary", "Origin");
                            // Prefer CSP over X-Frame-Options for modern control
                            if (!response.Headers.Contains("Content-Security-Policy"))
                                response.Headers.Add("Content-Security-Policy", $"frame-ancestors {_allowedOrigin}");
                            // Ensure inline display if filename is present downstream
                            if (response.Content.Headers.ContentDisposition == null)
                                response.Content.Headers.ContentDisposition = new ContentDispositionHeaderValue("inline");
                        }
                    }
                }
                catch { }
                return response;
            }, cancellationToken);
        }
    }

}
