using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using System.Web;
using System.Runtime.Caching;
using Newtonsoft.Json.Linq;
using System.IO;

namespace LabWnccNet
{
    /// <summary>
    /// IP Blacklist Check Result
    /// </summary>
    public class BlacklistResult
    {
        public bool IsBlacklisted { get; set; }
        public string Source { get; set; }
        public int Confidence { get; set; }
        
        public BlacklistResult()
        {
            IsBlacklisted = false;
            Source = null;
            Confidence = 0;
        }
        
        public BlacklistResult(bool isBlacklisted, string source, int confidence)
        {
            IsBlacklisted = isBlacklisted;
            Source = source;
            Confidence = confidence;
        }
    }

    /// <summary>
    /// IP Blacklist Checker - checks IPs against threat intelligence feeds
    /// </summary>
    public class IPBlacklistChecker
    {
        private static readonly MemoryCache _cache = MemoryCache.Default;
        private static readonly TimeSpan _cacheDuration = TimeSpan.FromHours(24);
        private static readonly HttpClient _httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
        private static readonly object _logLock = new object();
        private static readonly string _logPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "logs", "blacklist_checker.log");

        static IPBlacklistChecker()
        {
            // Ensure logs directory exists
            Directory.CreateDirectory(Path.GetDirectoryName(_logPath));
            Log("INFO", "IPBlacklistChecker initialized");
        }

        /// <summary>
        /// Check if an IP address is blacklisted
        /// </summary>
        public static async Task<BlacklistResult> IsBlacklistedAsync(string ipAddress)
        {
            // Check cache first
            string cacheKey = "blacklist_" + ipAddress;
            if (_cache.Contains(cacheKey))
            {
                Log("DEBUG", "IP " + ipAddress + " found in cache");
                return (BlacklistResult)_cache.Get(cacheKey);
            }

            Log("INFO", "Checking IP " + ipAddress + " against blacklists...");

            // Check against multiple sources
            var result = await CheckAllSources(ipAddress);

            // Cache the result
            _cache.Set(cacheKey, result, DateTimeOffset.Now.Add(_cacheDuration));

            if (result.IsBlacklisted)
            {
                Log("WARNING", string.Format("IP {0} BLACKLISTED by {1} (confidence: {2}%)", ipAddress, result.Source, result.Confidence));
            }
            else
            {
                Log("INFO", "IP " + ipAddress + " is NOT blacklisted");
            }

            return result;
        }

        private static async Task<BlacklistResult> CheckAllSources(string ipAddress)
        {
            // Check blocklist.de (free, no API key) with 3 second timeout
            try
            {
                var cts = new CancellationTokenSource();
                cts.CancelAfter(3000); // 3 second timeout
                var result = await CheckBlocklistDe(ipAddress, cts.Token);
                if (result.IsBlacklisted)
                    return result;
            }
            catch (TaskCanceledException)
            {
                Log("WARNING", "blocklist.de check timed out for " + ipAddress);
            }
            catch (Exception ex)
            {
                Log("ERROR", "Error checking blocklist.de for " + ipAddress + ": " + ex.Message);
            }

            // Check AbuseIPDB (requires API key) with 3 second timeout
            try
            {
                var apiKey = Environment.GetEnvironmentVariable("ABUSEIPDB_API_KEY");
                if (!string.IsNullOrEmpty(apiKey))
                {
                    var cts = new CancellationTokenSource();
                    cts.CancelAfter(3000); // 3 second timeout
                    var result = await CheckAbuseIPDB(ipAddress, apiKey, cts.Token);
                    if (result.IsBlacklisted)
                        return result;
                }
            }
            catch (TaskCanceledException)
            {
                Log("WARNING", "AbuseIPDB check timed out for " + ipAddress);
            }
            catch (Exception ex)
            {
                Log("ERROR", "Error checking AbuseIPDB for " + ipAddress + ": " + ex.Message);
            }

            return new BlacklistResult();
        }

        private static async Task<BlacklistResult> CheckBlocklistDe(string ipAddress, CancellationToken cancellationToken)
        {
            string url = "https://api.blocklist.de/api.php?ip=" + ipAddress;
            Log("DEBUG", "Checking blocklist.de for " + ipAddress);

            var response = await _httpClient.GetAsync(url, cancellationToken);
            if (response.IsSuccessStatusCode)
            {
                var text = await response.Content.ReadAsStringAsync();
                if (text.ToLower().Contains("attacks:") && !text.ToLower().Contains("attacks: 0"))
                {
                    Log("INFO", "blocklist.de: " + ipAddress + " found with attacks");
                    return new BlacklistResult(true, "blocklist.de", 80);
                }
            }
            else
            {
                Log("WARNING", "blocklist.de API error: " + response.StatusCode);
            }

            return new BlacklistResult();
        }

        private static async Task<BlacklistResult> CheckAbuseIPDB(string ipAddress, string apiKey, CancellationToken cancellationToken)
        {
            string url = "https://api.abuseipdb.com/api/v2/check?ipAddress=" + ipAddress + "&maxAgeInDays=90";
            Log("DEBUG", "Checking AbuseIPDB for " + ipAddress);

            var request = new HttpRequestMessage(HttpMethod.Get, url);
            request.Headers.Add("Accept", "application/json");
            request.Headers.Add("Key", apiKey);

            var response = await _httpClient.SendAsync(request, cancellationToken);
            if (response.IsSuccessStatusCode)
            {
                var json = await response.Content.ReadAsStringAsync();
                var data = JObject.Parse(json);
                
                var dataToken = data["data"];
                if (dataToken != null)
                {
                    var scoreToken = dataToken["abuseConfidenceScore"];
                    var abuseScore = scoreToken != null ? scoreToken.Value<int>() : 0;
                    
                    Log("INFO", string.Format("AbuseIPDB: {0} has abuse score {1}%", ipAddress, abuseScore));

                    // Block if abuse score > 75%
                    if (abuseScore > 75)
                    {
                        return new BlacklistResult(true, "AbuseIPDB", abuseScore);
                    }
                }
            }
            else
            {
                Log("WARNING", "AbuseIPDB API error: " + response.StatusCode);
            }

            return new BlacklistResult();
        }

        public static void ClearCache()
        {
            var cacheKeys = _cache.Where(kvp => kvp.Key.StartsWith("blacklist_")).Select(kvp => kvp.Key).ToList();
            foreach (var key in cacheKeys)
            {
                _cache.Remove(key);
            }
            Log("INFO", string.Format("Cache cleared ({0} entries removed)", cacheKeys.Count));
        }

        private static void Log(string level, string message)
        {
            try
            {
                lock (_logLock)
                {
                    string logEntry = string.Format("{0:yyyy-MM-dd HH:mm:ss} {1} [IPBlacklistChecker] {2}", DateTime.Now, level, message);
                    File.AppendAllText(_logPath, logEntry + Environment.NewLine);

                    // Also write to Debug output
                    System.Diagnostics.Debug.WriteLine(logEntry);
                }
            }
            catch
            {
                // Silently fail if logging fails
            }
        }
    }

    /// <summary>
    /// HTTP Module to block blacklisted IPs
    /// </summary>
    public class IPBlacklistModule : IHttpModule
    {
        public void Init(HttpApplication context)
        {
            context.BeginRequest += OnBeginRequest;
        }

        private void OnBeginRequest(object sender, EventArgs e)
        {
            var app = (HttpApplication)sender;
            var context = app.Context;

            // Get client IP address
            string ipAddress = GetClientIPAddress(context.Request);

            // Skip checking for localhost and private IPs
            if (ipAddress == "127.0.0.1" || ipAddress == "::1" || 
                ipAddress.StartsWith("192.168.") || ipAddress.StartsWith("10.") ||
                ipAddress.StartsWith("172.16.") || ipAddress.StartsWith("172.17.") ||
                ipAddress.StartsWith("172.18.") || ipAddress.StartsWith("172.19.") ||
                ipAddress.StartsWith("172.20.") || ipAddress.StartsWith("172.21.") ||
                ipAddress.StartsWith("172.22.") || ipAddress.StartsWith("172.23.") ||
                ipAddress.StartsWith("172.24.") || ipAddress.StartsWith("172.25.") ||
                ipAddress.StartsWith("172.26.") || ipAddress.StartsWith("172.27.") ||
                ipAddress.StartsWith("172.28.") || ipAddress.StartsWith("172.29.") ||
                ipAddress.StartsWith("172.30.") || ipAddress.StartsWith("172.31."))
            {
                return;
            }

            // Check if IP is blacklisted (synchronous wait - not ideal but works)
            var task = IPBlacklistChecker.IsBlacklistedAsync(ipAddress);
            task.Wait();
            var result = task.Result;

            if (result.IsBlacklisted)
            {
                // Block the request
                context.Response.StatusCode = 403;
                context.Response.StatusDescription = "Forbidden";
                context.Response.ContentType = "text/html";
                context.Response.Write(string.Format(@"
<!DOCTYPE html>
<html>
<head>
    <title>Access Denied</title>
    <style>
        body {{ font-family: Arial, sans-serif; text-align: center; padding: 50px; }}
        h1 {{ color: #d32f2f; }}
        p {{ color: #666; }}
    </style>
</head>
<body>
    <h1>Access Denied</h1>
    <p>Your IP address has been flagged by our security system.</p>
    <p>If you believe this is an error, please contact the administrator.</p>
    <hr>
    <small>Blocked by {0} (Confidence: {1}%)</small>
</body>
</html>", result.Source, result.Confidence));
                context.Response.End();
            }
        }

        private string GetClientIPAddress(HttpRequest request)
        {
            // Check for proxy headers first
            string ip = request.Headers["X-Forwarded-For"];
            if (!string.IsNullOrEmpty(ip))
            {
                // X-Forwarded-For can contain multiple IPs, take the first one
                ip = ip.Split(',')[0].Trim();
            }
            else
            {
                ip = request.UserHostAddress;
            }

            return ip;
        }

        public void Dispose()
        {
            // Cleanup if needed
        }
    }
}
