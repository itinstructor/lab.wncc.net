# ASP.NET IP Blacklist Checker

This is a C# ASP.NET implementation of the IP blacklist checker, similar to the Python version.

## Features

- **Multiple threat intelligence sources:**
  - StopForumSpam (free, no API key required)
  - blocklist.de (free, no API key required)
  - AbuseIPDB (requires free API key)

- **In-memory caching:** Results cached for 24 hours to reduce API calls
- **Automatic logging:** All checks logged to `logs/blacklist_checker.log`
- **HTTP Module:** Automatically blocks blacklisted IPs at the request level

## Setup Instructions

### 1. Compile the C# Code

```powershell
# Install NuGet packages
nuget restore packages.config

# Compile the DLL
csc /target:library /out:bin\IPBlacklistChecker.dll /reference:System.dll /reference:System.Web.dll /reference:System.Net.Http.dll /reference:System.Runtime.Caching.dll /reference:packages\Newtonsoft.Json.13.0.3\lib\net45\Newtonsoft.Json.dll IPBlacklistChecker.cs

# Or use MSBuild
msbuild IPBlacklistChecker.csproj /p:Configuration=Release
```

### 2. Create bin Directory

```powershell
# Create bin directory if it doesn't exist
New-Item -ItemType Directory -Path "bin" -Force

# Copy Newtonsoft.Json.dll to bin
Copy-Item "packages\Newtonsoft.Json.13.0.3\lib\net45\Newtonsoft.Json.dll" -Destination "bin\" -Force
```

### 3. Configure AbuseIPDB (Optional)

To use AbuseIPDB, get a free API key from https://www.abuseipdb.com/

Set as environment variable:
```powershell
# Set for current session
$env:ABUSEIPDB_API_KEY = "your-api-key-here"

# Set permanently (requires admin)
[System.Environment]::SetEnvironmentVariable("ABUSEIPDB_API_KEY", "your-api-key-here", "Machine")

# Or in IIS Application Pool environment variables
```

### 4. Restart IIS

```powershell
iisreset
```

## How It Works

1. **HTTP Module intercepts all requests** before they reach your content
2. **Extracts client IP** from request (checks X-Forwarded-For for proxy scenarios)
3. **Checks cache** first (24-hour TTL)
4. **Queries threat intelligence APIs** in sequence:
   - StopForumSpam
   - blocklist.de
   - AbuseIPDB (if API key configured)
5. **Blocks with 403** if IP is blacklisted, or allows request to continue

## Configuration

The module is configured in `web.config`:

```xml
<system.webServer>
    <modules>
        <add name="IPBlacklistModule" type="LabWnccNet.IPBlacklistModule, IPBlacklistChecker" />
    </modules>
</system.webServer>
```

## Whitelisting Local IPs

The following IPs are automatically whitelisted (not checked):
- `127.0.0.1` (localhost)
- `::1` (IPv6 localhost)
- `192.168.*` (private network)
- `10.*` (private network)

To whitelist additional IPs, modify the `OnBeginRequest` method in `IPBlacklistChecker.cs`.

## Logging

Logs are written to `logs/blacklist_checker.log` with the following format:
```
2025-12-03 14:23:45 INFO [IPBlacklistChecker] Checking IP 203.0.113.45 against blacklists...
2025-12-03 14:23:46 WARNING [IPBlacklistChecker] IP 203.0.113.45 BLACKLISTED by StopForumSpam (confidence: 90%)
```

## Testing

Test the blacklist checker:

```powershell
# Test from PowerShell
Invoke-WebRequest -Uri "http://lab.wncc.net"

# Check logs
Get-Content "logs\blacklist_checker.log" -Tail 20

# Clear cache (requires modifying code to expose ClearCache via endpoint)
```

## API Rate Limits

- **StopForumSpam:** No rate limit for IP checks
- **blocklist.de:** No documented rate limit
- **AbuseIPDB:** 1,000 requests/day on free tier

Caching reduces API calls significantly.

## Comparison with Python Version

| Feature | Python | C# ASP.NET |
|---------|--------|------------|
| Language | Python 3.x | C# .NET Framework 4.8 |
| Caching | functools.lru_cache + dict | MemoryCache |
| Logging | TimedRotatingFileHandler | File.AppendAllText |
| Integration | Flask/Django middleware | IIS HTTP Module |
| Async | Native async/await | Task-based async |
| Dependencies | requests | HttpClient + Newtonsoft.Json |

## Troubleshooting

**Module not loading:**
- Verify `IPBlacklistChecker.dll` is in `bin/` folder
- Verify `Newtonsoft.Json.dll` is in `bin/` folder
- Check IIS application pool identity has read permissions
- Check Event Viewer for ASP.NET errors

**IPs not being blocked:**
- Check `logs/blacklist_checker.log` for errors
- Verify APIs are reachable (firewall/proxy)
- Test API endpoints manually

**Performance issues:**
- Increase cache duration (currently 24 hours)
- Reduce number of sources checked
- Implement async properly (current implementation uses async void)

## Security Notes

- Cache prevents repeated API calls for the same IP
- Blocked IPs receive 403 response before any application code runs
- All checks are logged for audit purposes
- Consider using fail2ban or similar for automatic blacklisting based on behavior

## Future Enhancements

- Add whitelist functionality
- Implement confidence threshold configuration
- Add admin API endpoint to manage cache
- Support for IPv6
- Integration with custom blacklist files
- Email alerts for blocked IPs
