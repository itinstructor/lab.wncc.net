# Test IP Blacklist Checker
# This script tests the blacklist checker functionality

Write-Host "IP Blacklist Checker - Test Script" -ForegroundColor Cyan
Write-Host ""

# Test IPs
$testIPs = @{
    "8.8.8.8" = "Google DNS (should NOT be blacklisted)"
    "1.1.1.1" = "Cloudflare DNS (should NOT be blacklisted)"
    "127.0.0.1" = "Localhost (whitelisted, won't be checked)"
}

Write-Host "Testing blacklist APIs directly..." -ForegroundColor Yellow
Write-Host ""

foreach ($ip in $testIPs.Keys) {
    Write-Host "Testing IP: $ip - $($testIPs[$ip])" -ForegroundColor Cyan
    
    # Test StopForumSpam
    try {
        $url = "https://api.stopforumspam.org/api?ip=$ip&json"
        $response = Invoke-RestMethod -Uri $url -TimeoutSec 5
        $appears = $response.ip.appears
        
        if ($appears -gt 0) {
            Write-Host "  StopForumSpam: BLACKLISTED (appears $appears times)" -ForegroundColor Red
        } else {
            Write-Host "  StopForumSpam: Clean" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  StopForumSpam: Error - $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Test blocklist.de
    try {
        $url = "https://api.blocklist.de/api.php?ip=$ip"
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 5
        $text = $response.Content.ToLower()
        
        if ($text -match "attacks:\s*(\d+)" -and $matches[1] -ne "0") {
            Write-Host "  blocklist.de: BLACKLISTED (attacks: $($matches[1]))" -ForegroundColor Red
        } else {
            Write-Host "  blocklist.de: Clean" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  blocklist.de: Error - $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

# Check if web.config is configured
Write-Host "Checking web.config configuration..." -ForegroundColor Yellow
$webConfig = Get-Content "web.config" -Raw

if ($webConfig -match "IPBlacklistModule") {
    Write-Host "  web.config: Module configured ✓" -ForegroundColor Green
} else {
    Write-Host "  web.config: Module NOT configured ✗" -ForegroundColor Red
}

# Check if DLL exists
if (Test-Path "bin\IPBlacklistChecker.dll") {
    Write-Host "  DLL: Compiled and present ✓" -ForegroundColor Green
    $dll = Get-Item "bin\IPBlacklistChecker.dll"
    Write-Host "    File size: $($dll.Length) bytes" -ForegroundColor Gray
    Write-Host "    Modified: $($dll.LastWriteTime)" -ForegroundColor Gray
} else {
    Write-Host "  DLL: NOT found ✗" -ForegroundColor Red
    Write-Host "    Run build-blacklist.ps1 to compile" -ForegroundColor Yellow
}

# Check dependencies
if (Test-Path "bin\Newtonsoft.Json.dll") {
    Write-Host "  Newtonsoft.Json: Present ✓" -ForegroundColor Green
} else {
    Write-Host "  Newtonsoft.Json: NOT found ✗" -ForegroundColor Red
}

# Check logs directory
if (Test-Path "logs") {
    Write-Host "  Logs directory: Present ✓" -ForegroundColor Green
    
    if (Test-Path "logs\blacklist_checker.log") {
        $logFile = Get-Item "logs\blacklist_checker.log"
        Write-Host "    Log file size: $($logFile.Length) bytes" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Last 5 log entries:" -ForegroundColor Cyan
        Get-Content "logs\blacklist_checker.log" -Tail 5 | ForEach-Object {
            Write-Host "    $_" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  Logs directory: NOT found ✗" -ForegroundColor Red
}

Write-Host ""
Write-Host "To test the live site:" -ForegroundColor Cyan
Write-Host "  1. Ensure IIS is running" -ForegroundColor White
Write-Host "  2. Visit http://lab.wncc.net" -ForegroundColor White
Write-Host "  3. Check logs\blacklist_checker.log for entries" -ForegroundColor White
Write-Host ""
Write-Host "To manually test a request:" -ForegroundColor Cyan
Write-Host '  Invoke-WebRequest -Uri "http://lab.wncc.net"' -ForegroundColor White
