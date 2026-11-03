using System;
using System.Net;
using System.Net.Http;
using System.Web.Http.Filters;
using SampWebApi.BuisnessLayer;

namespace SampWebApi.Utility
{
    /// <summary>
    /// Global Web API exception filter.
    ///
    /// Context: most controllers currently catch their own exceptions and return Ok()
    /// (HTTP 200 with an empty body), which makes failures indistinguishable from success
    /// at the HTTP level. This filter is a safety net: for any exception that is NOT caught
    /// by a controller (i.e. propagates out of the action), it logs the error and returns a
    /// proper HTTP 500 with a structured JSON body instead of the default HTML error.
    ///
    /// It does not change existing controllers that swallow exceptions — those keep working
    /// as before. New/refactored controllers should let exceptions propagate (or rethrow)
    /// so this filter can produce a correct status code and envelope.
    /// </summary>
    public class GlobalExceptionFilter : ExceptionFilterAttribute
    {
        public override void OnException(HttpActionExecutedContext context)
        {
            try
            {
                var bl = new clsBusinessLayer();
                string controller = context.ActionContext?.ControllerContext?.ControllerDescriptor?.ControllerName ?? "Unknown";
                string action = context.ActionContext?.ActionDescriptor?.ActionName ?? "Unknown";
                bl.BL_WriteErrorMsginLog(controller, action, context.Exception?.ToString() ?? "null exception");
            }
            catch
            {
                // Never let logging failures override the response we are about to send.
            }

            var body = new
            {
                success = false,
                msgID = "1",
                message = "An unexpected error occurred. Please try again or contact support."
            };

            context.Response = context.Request.CreateResponse(HttpStatusCode.InternalServerError, body);
        }
    }
}
