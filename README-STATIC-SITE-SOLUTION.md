# IP Blacklist Checker - Updated Implementation

## Important Note

Your site (`lab.wncc.net`) is a **static HTML site**, not an ASP.NET application. HTTP Modules cannot run on static sites because they require the ASP.NET runtime to process every request.

## Solution: ASHX Handler

Instead of an HTTP Module, the IP blacklist checker is implemented as an **ASHX handler** that you can call via HTTP requests.

## Files Created

✅ `IPBlacklistChecker.dll` - Compiled blacklist checker library  
✅ `check-ip.ashx` - HTTP Handler to check IPs  
✅ `web.config` - Updated configuration  
✅ All documentation files  

## How to Use

### Option 1: Check IP via URL

Visit the handler directly in a browser or via API:

```
http://lab.wncc.net/check-ip.ashx
```

This will check your current IP address.

To check a specific IP:

```
http://lab.wncc.net/check-ip.ashx?ip=8.8.8.8
```

**Response Example:**
```json
{
    "ip": "8.8.8.8",
    "isBlacklisted": false,
    "source": "none",
    "confidence": 0
}
```

### Option 2: JavaScript Integration

Add this to your HTML pages to check visitors:

```html
<script>
// Check visitor IP on page load
fetch('/check-ip.ashx')
    .then(response => response.json())
    .then(data => {
        if (data.isBlacklisted) {
            console.warn('IP flagged:', data);
            // Optionally redirect or show warning
            // window.location = '/blocked.html';
        } else {
            console.log('IP clean:', data.ip);
        }
    })
    .catch(err => console.error('Blacklist check failed:', err));
</script>
```

### Option 3: PowerShell/API Integration

```powershell
# Check an IP
$result = Invoke-RestMethod -Uri "http://lab.wncc.net/check-ip.ashx?ip=8.8.8.8"
Write-Host "IP: $($result.ip)"
Write-Host "Blacklisted: $($result.isBlacklisted)"
Write-Host "Source: $($result.source)"
Write-Host "Confidence: $($result.confidence)%"
```

### Option 4: Server-Side Blocking (IIS URL Rewrite)

For automatic blocking, you'd need to:
1. Use IIS URL Rewrite module
2. Create a rewrite rule that calls the ASHX handler
3. Block based on the response

However, this is complex. A better approach for static sites is to use Cloudflare or a similar CDN with built-in threat intelligence.

## Testing

```powershell
# Test with your IP
Invoke-RestMethod "http://lab.wncc.net/check-ip.ashx"

# Test with a specific IP
Invoke-RestMethod "http://lab.wncc.net/check-ip.ashx?ip=8.8.8.8"

# Test with known bad IP (for testing only - use carefully)
Invoke-RestMethod "http://lab.wncc.net/check-ip.ashx?ip=185.220.101.1"
```

## Admin Interface

The `blacklist-admin.html` page can be updated to use the ASHX handler instead of direct API calls.

## Limitations

⚠️ **Cannot automatically block requests** - Since this is a static site, the ASHX handler can only **check** IPs, not block them before content is served.

For automatic blocking on a static site, consider:
- **Cloudflare** (free tier includes threat intelligence)
- **Azure Front Door** (with WAF)
- **AWS CloudFront** (with AWS WAF)
- Converting to full ASP.NET application

## Alternative: Full ASP.NET Site

If you want automatic blocking with the HTTP Module, you need to:

1. Convert the site to an ASP.NET application
2. Add a Global.asax or Startup.cs
3. Enable the HTTP Module in web.config

This requires more significant changes to your site structure.

## What Works Now

✅ Check any IP via `/check-ip.ashx`  
✅ API integration via HTTP requests  
✅ JavaScript client-side checks  
✅ PowerShell/automation integration  
✅ 24-hour caching (reduces API calls)  
✅ Logging to `logs/blacklist_checker.log`  

## Recommended Approach

For a static HTML site like yours, the **best security approach** is:

1. **Use Cloudflare** (or similar CDN)
   - Free tier includes threat intelligence
   - Automatic DDoS protection
   - Bot management
   - No code changes needed

2. **Keep this ASHX handler** for manual checks and monitoring

3. **Use JavaScript integration** to warn/redirect suspicious visitors

4. **Monitor logs** regularly with `logs/blacklist_checker.log`

## Status

🟢 **Site is working** - No errors  
🟢 **ASHX handler deployed** - Ready to use  
🟡 **Automatic blocking** - Not available for static sites  
🟢 **Manual checking** - Fully functional  

Visit: http://lab.wncc.net/check-ip.ashx to test!
