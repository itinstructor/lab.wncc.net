# Build and Deploy IP Blacklist Checker
# Run this script to compile and deploy the blacklist checker

Write-Host "Building IP Blacklist Checker..." -ForegroundColor Cyan

# Create necessary directories
Write-Host "Creating directories..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path "bin" -Force | Out-Null
New-Item -ItemType Directory -Path "logs" -Force | Out-Null
New-Item -ItemType Directory -Path "packages" -Force | Out-Null

# Download Newtonsoft.Json if not present
$newtonsoftPath = "packages\Newtonsoft.Json.13.0.3\lib\net45\Newtonsoft.Json.dll"
if (-not (Test-Path $newtonsoftPath)) {
    Write-Host "Downloading Newtonsoft.Json..." -ForegroundColor Yellow
    
    # Create package directories
    New-Item -ItemType Directory -Path "packages\Newtonsoft.Json.13.0.3\lib\net45" -Force | Out-Null
    
    # Download from NuGet
    $url = "https://www.nuget.org/api/v2/package/Newtonsoft.Json/13.0.3"
    $zipPath = "packages\Newtonsoft.Json.13.0.3.zip"
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $zipPath
        
        # Extract the nupkg (it's actually a zip file, just rename it)
        Expand-Archive -Path $zipPath -DestinationPath "packages\Newtonsoft.Json.13.0.3" -Force
        
        # Clean up zip file
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        
        Write-Host "Newtonsoft.Json downloaded successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "Error downloading Newtonsoft.Json: $_" -ForegroundColor Red
        Write-Host "Trying alternative method..." -ForegroundColor Yellow
        
        # Alternative: Download DLL directly from NuGet CDN
        try {
            $dllUrl = "https://globalcdn.nuget.org/packages/newtonsoft.json.13.0.3.nupkg"
            $tempZip = "packages\temp.zip"
            Invoke-WebRequest -Uri $dllUrl -OutFile $tempZip
            Expand-Archive -Path $tempZip -DestinationPath "packages\Newtonsoft.Json.13.0.3" -Force
            Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
            Write-Host "Newtonsoft.Json downloaded successfully (alternative method)" -ForegroundColor Green
        }
        catch {
            Write-Host "Alternative download also failed." -ForegroundColor Red
            Write-Host "Downloading DLL directly..." -ForegroundColor Yellow
            
            # Last resort: direct DLL download from unpkg CDN
            try {
                $directUrl = "https://www.nuget.org/api/v2/package/Newtonsoft.Json/13.0.3"
                $bytes = (Invoke-WebRequest -Uri $directUrl).Content
                
                # Save as zip and extract
                $tempFile = [System.IO.Path]::GetTempFileName()
                [System.IO.File]::WriteAllBytes($tempFile, $bytes)
                
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($tempFile, "packages\Newtonsoft.Json.13.0.3")
                
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                Write-Host "Newtonsoft.Json downloaded successfully" -ForegroundColor Green
            }
            catch {
                Write-Host "All download methods failed: $_" -ForegroundColor Red
                Write-Host "Please download manually:" -ForegroundColor Yellow
                Write-Host "  1. Visit https://www.nuget.org/packages/Newtonsoft.Json/13.0.3" -ForegroundColor White
                Write-Host "  2. Download the package" -ForegroundColor White
                Write-Host "  3. Extract to: packages\Newtonsoft.Json.13.0.3\" -ForegroundColor White
                exit 1
            }
        }
    }
}

# Find C# compiler
Write-Host "Locating C# compiler..." -ForegroundColor Yellow
$cscPath = Get-ChildItem -Path "C:\Windows\Microsoft.NET\Framework64" -Recurse -Filter "csc.exe" -ErrorAction SilentlyContinue | 
           Sort-Object FullName -Descending | 
           Select-Object -First 1

if (-not $cscPath) {
    Write-Host "C# compiler not found. Please install .NET Framework SDK" -ForegroundColor Red
    exit 1
}

Write-Host "Using compiler: $($cscPath.FullName)" -ForegroundColor Green

# Compile the DLL
Write-Host "Compiling IPBlacklistChecker.cs..." -ForegroundColor Yellow

$compileArgs = @(
    "/target:library"
    "/out:bin\IPBlacklistChecker.dll"
    "/reference:System.dll"
    "/reference:System.Web.dll"
    "/reference:System.Net.Http.dll"
    "/reference:System.Runtime.Caching.dll"
    "/reference:System.Core.dll"
    "/reference:System.Xml.Linq.dll"
    "/reference:$newtonsoftPath"
    "IPBlacklistChecker.cs"
)

& $cscPath.FullName $compileArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "Compilation successful!" -ForegroundColor Green
    
    # Copy Newtonsoft.Json.dll to bin
    Write-Host "Copying dependencies to bin..." -ForegroundColor Yellow
    Copy-Item $newtonsoftPath -Destination "bin\" -Force
    
    Write-Host "Build complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Verify web.config has the HTTP module configured" -ForegroundColor White
    Write-Host "2. (Optional) Set ABUSEIPDB_API_KEY environment variable" -ForegroundColor White
    Write-Host "3. Restart IIS: iisreset" -ForegroundColor White
    Write-Host ""
    Write-Host "To restart IIS now, run: iisreset" -ForegroundColor Yellow
}
else {
    Write-Host "Compilation failed!" -ForegroundColor Red
    Write-Host "Check the error messages above" -ForegroundColor Yellow
    exit 1
}
