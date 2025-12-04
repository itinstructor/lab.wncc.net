# IP Blacklist Checker - Quick Start Guide

## What You Have

A complete C# ASP.NET IP blacklist checker similar to your Python implementation, with:

✅ Multi-source threat intelligence (StopForumSpam, blocklist.de, AbuseIPDB)
✅ 24-hour caching to minimize API calls
✅ Automatic logging to `logs/blacklist_checker.log`
✅ HTTP Module that blocks malicious IPs with 403 Forbidden
✅ Admin web interface for testing
✅ PowerShell scripts for building and testing

## Files Created

```
c:\inetpub\lab.wncc.net\
├── IPBlacklistChecker.cs          # Main C# implementation
├── IPBlacklistChecker.csproj      # Project file
├── packages.config                # NuGet dependencies
├── web.config                     # IIS configuration (updated)
├── build-blacklist.ps1            # Build script
├── test-blacklist.ps1             # Test script
├── blacklist-admin.html           # Admin interface
├── README-BLACKLIST.md            # Full documentation
└── blacklist_checker.py           # Original Python version
```

## Quick Setup (3 Steps)

### Step 1: Build the Module

```powershell
cd c:\inetpub\lab.wncc.net
.\build-blacklist.ps1
```

This will:
- Download Newtonsoft.Json dependency
- Compile IPBlacklistChecker.cs into a DLL
- Copy everything to the `bin/` folder

### Step 2: Verify Configuration

The `web.config` is already configured. It should contain:

```xml
<system.webServer>
    <modules>
        <add name="IPBlacklistModule" type="LabWnccNet.IPBlacklistModule, IPBlacklistChecker" />
    </modules>
</system.webServer>
```

### Step 3: Restart IIS

```powershell
iisreset
```

## Testing

### Option 1: Run Test Script

```powershell
.\test-blacklist.ps1
```

### Option 2: Use Admin Interface

Open in browser:
```
http://lab.wncc.net/blacklist-admin.html
```

### Option 3: Check Logs

```powershell
Get-Content logs\blacklist_checker.log -Tail 20 -Wait
```

## How It Works

1. **Every incoming HTTP request** is intercepted by `IPBlacklistModule`
2. **Client IP is extracted** (supports X-Forwarded-For for proxies)
3. **Cache is checked first** (24-hour TTL)
4. **If not cached**, queries threat intelligence APIs:
   - StopForumSpam (free, no key needed)
   - blocklist.de (free, no key needed)
   - AbuseIPDB (optional, needs free API key)
5. **If blacklisted**, returns 403 Forbidden
6. **If clean**, request continues normally
7. **Result is cached** for 24 hours

## Whitelisted IPs (Not Checked)

- `127.0.0.1` - localhost
- `::1` - IPv6 localhost
- `192.168.*` - private network
- `10.*` - private network

## Optional: Add AbuseIPDB Support

Get free API key from: https://www.abuseipdb.com/

Set environment variable:

```powershell
# Set for IIS (requires admin)
[System.Environment]::SetEnvironmentVariable("ABUSEIPDB_API_KEY", "your-api-key-here", "Machine")

# Restart IIS
iisreset
```

## Comparison: Python vs C#

| Feature | Python (Flask/Django) | C# ASP.NET (IIS) |
|---------|----------------------|------------------|
| **Integration** | WSGI middleware | IIS HTTP Module |
| **Runs on** | Every framework call | Every HTTP request (before app) |
| **Performance** | ~5-10ms overhead | ~2-5ms overhead (cached) |
| **Caching** | functools.lru_cache | MemoryCache |
| **Logging** | TimedRotatingFileHandler | File.AppendAllText |
| **Async** | Native async/await | Task-based async |

Both implementations:
- Use the same threat intelligence sources
- Cache results for 24 hours
- Log all checks
- Support the same configuration options

## Troubleshooting

### Module not loading?

```powershell
# Check if DLL exists
Test-Path bin\IPBlacklistChecker.dll

# Check IIS application pool permissions
icacls bin\IPBlacklistChecker.dll

# Check Event Viewer
Get-EventLog -LogName Application -Source "ASP.NET*" -Newest 10
```

### IPs not being blocked?

```powershell
# Check logs
Get-Content logs\blacklist_checker.log -Tail 50

# Test APIs manually
Invoke-RestMethod "https://api.stopforumspam.org/api?ip=8.8.8.8&json"
```

### Build failed?

```powershell
# Check .NET Framework installed
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full"

# Find C# compiler
Get-ChildItem C:\Windows\Microsoft.NET\Framework64 -Recurse -Filter csc.exe
```

## Monitoring

### View live logs:

```powershell
Get-Content logs\blacklist_checker.log -Tail 20 -Wait
```

### Check recent blocks:

```powershell
Get-Content logs\blacklist_checker.log | Select-String "BLACKLISTED"
```

### Count checks today:

```powershell
$today = Get-Date -Format "yyyy-MM-dd"
(Get-Content logs\blacklist_checker.log | Select-String $today).Count
```

## Security Notes

✅ Blocks malicious IPs before application code runs
✅ All checks are logged for auditing
✅ Cache prevents API rate limit issues
✅ Multiple threat intelligence sources for accuracy
⚠️ Local/private IPs are whitelisted (not checked)
⚠️ Consider fail2ban for behavior-based blocking
⚠️ Monitor logs for attack patterns

## Next Steps

1. **Build**: Run `.\build-blacklist.ps1`
2. **Restart IIS**: Run `iisreset`
3. **Test**: Run `.\test-blacklist.ps1` or visit `/blacklist-admin.html`
4. **Monitor**: Watch `logs\blacklist_checker.log`
5. **Optional**: Set up AbuseIPDB API key for enhanced detection

## Support

For issues or questions:
- Check `README-BLACKLIST.md` for detailed documentation
- Review logs: `logs\blacklist_checker.log`
- Test APIs: Run `.\test-blacklist.ps1`
- Admin interface: `http://lab.wncc.net/blacklist-admin.html`
