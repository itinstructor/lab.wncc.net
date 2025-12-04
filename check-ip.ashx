<%@ WebHandler Language="C#" Class="BlacklistCheckHandler" %>

using System;
using System.Web;
using System.Threading.Tasks;
using LabWnccNet;

public class BlacklistCheckHandler : HttpTaskAsyncHandler
{
    public override async Task ProcessRequestAsync(HttpContext context)
    {
        context.Response.ContentType = "application/json";
        
        try
        {
            // Get IP from query string or use client IP
            string ipToCheck = context.Request.QueryString["ip"];
            if (string.IsNullOrEmpty(ipToCheck))
            {
                ipToCheck = GetClientIP(context.Request);
            }
            
            // Check if IP is blacklisted
            var result = await IPBlacklistChecker.IsBlacklistedAsync(ipToCheck);
            
            // Return JSON response
            context.Response.Write(string.Format(@"{{
    ""ip"": ""{0}"",
    ""isBlacklisted"": {1},
    ""source"": ""{2}"",
    ""confidence"": {3}
}}", 
                ipToCheck,
                result.IsBlacklisted.ToString().ToLower(),
                result.Source ?? "none",
                result.Confidence));
        }
        catch (Exception ex)
        {
            context.Response.StatusCode = 500;
            context.Response.Write(string.Format(@"{{
    ""error"": ""{0}""
}}", ex.Message.Replace("\"", "\\\"")));
        }
    }
    
    private string GetClientIP(HttpRequest request)
    {
        string ip = request.Headers["X-Forwarded-For"];
        if (!string.IsNullOrEmpty(ip))
        {
            ip = ip.Split(',')[0].Trim();
        }
        else
        {
            ip = request.UserHostAddress;
        }
        return ip;
    }
}
