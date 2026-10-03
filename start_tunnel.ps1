$ErrorActionPreference = "SilentlyContinue"
$Host.UI.RawUI.WindowTitle = "Saark ERP - 4G/5G Online Access"

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "         Starting Saark ERP Backend & Generating 4G/5G Direct Link    " -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1. Start Backend if not already running on port 3000
$port3000Active = Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue
if (-not $port3000Active) {
    Write-Host "[1/3] Starting Backend Server on Port 3000..." -ForegroundColor Green
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$scriptDir\1_START_BACKEND_SERVER.bat`"" -WindowStyle Minimized
    Start-Sleep -Seconds 4
} else {
    Write-Host "[1/3] Backend Server is already running on Port 3000." -ForegroundColor Green
}

# 2. Start Cloudflare Tunnel
Write-Host "[2/3] Connecting Cloudflare 4G/5G Tunnel..." -ForegroundColor Green
$logFile = "$scriptDir\tunnel_output.log"
if (Test-Path $logFile) { Remove-Item $logFile -Force }

$cloudflaredExe = "$scriptDir\cloudflared.exe"
$tunnelProc = Start-Process -FilePath $cloudflaredExe -ArgumentList "tunnel --url http://localhost:3000 --protocol http2" -RedirectStandardError $logFile -PassThru -NoNewWindow

# 3. Wait and extract the public trycloudflare URL
Write-Host "[3/3] Generating Direct 4G/5G Phone Link..." -ForegroundColor Green
$foundUrl = $null
$maxRetries = 30
$retryCount = 0

while (-not $foundUrl -and $retryCount -lt $maxRetries) {
    Start-Sleep -Seconds 1
    $retryCount++
    if (Test-Path $logFile) {
        try {
            $stream = [System.IO.FileStream]::new($logFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            $reader = [System.IO.StreamReader]::new($stream)
            $content = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
            
            if ($content -match "(https://[a-zA-Z0-9-]+\.trycloudflare\.com)") {
                $foundUrl = $matches[1]
                break
            }
        } catch {}
    }
}

Clear-Host
if ($foundUrl) {
    # 1. Save URL to text file
    $urlFile = "$scriptDir\phone_url.txt"
    Set-Content -Path $urlFile -Value $foundUrl -Force

    # 2. Copy URL to clipboard
    try { Set-Clipboard -Value $foundUrl } catch {}

    # 3. Generate QR Code HTML from template
    $templateFile = "$scriptDir\phone_access_template.html"
    $htmlFile = "$scriptDir\phone_access.html"
    if (Test-Path $templateFile) {
        $encodedUrl = [System.Uri]::EscapeDataString($foundUrl)
        $qrUrl = "https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=$encodedUrl"
        $html = (Get-Content $templateFile -Raw) -replace '__URL__', $foundUrl -replace '__QR__', $qrUrl
        Set-Content -Path $htmlFile -Value $html -Force
        Start-Process $htmlFile
    }

    # 4. Display clear banner in the console
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host "                    SAARK ERP - 4G/5G LINK READY!                     " -ForegroundColor Yellow
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  [PHONE 4G/5G URL]  " -ForegroundColor Cyan -NoNewline
    Write-Host "👉  $foundUrl" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [LOCAL WI-FI URL]  " -ForegroundColor Cyan -NoNewline
    Write-Host "👉  http://192.168.1.104:3000" -ForegroundColor White
    Write-Host ""
    Write-Host "  [LOCAL PC URL]     " -ForegroundColor Cyan -NoNewline
    Write-Host "👉  http://localhost:3000" -ForegroundColor White
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host "  * Scan the QR code that opened in your browser with your phone camera! *" -ForegroundColor Cyan
    Write-Host "  * URL has been copied to your clipboard & saved in 'phone_url.txt'    *" -ForegroundColor Magenta
    Write-Host "  * Keep this window OPEN while using the ERP.                          *" -ForegroundColor Gray
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Press Ctrl+C to stop the tunnel." -ForegroundColor DarkGray
    
    # Keep process active
    $tunnelProc.WaitForExit()
} else {
    Write-Host "Failed to extract Cloudflare tunnel URL automatically." -ForegroundColor Red
    Write-Host "Check tunnel_output.log for details." -ForegroundColor Yellow
    if (Test-Path $logFile) {
        Get-Content $logFile -Tail 20
    }
    Read-Host "Press Enter to exit..."
}
