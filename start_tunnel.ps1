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
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$scriptDir\start_backend.bat`"" -WindowStyle Minimized
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

    # 3. Create interactive HTML page with QR code for smartphone camera scanning
    $htmlFile = "$scriptDir\phone_access.html"
    $encodedUrl = [System.Uri]::EscapeDataString($foundUrl)
    $qrUrl = "https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=$encodedUrl"
    
    $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Saark ERP - Smartphone 4G/5G Access</title>
  <style>
    * { box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background: #0b1329;
      color: #f8fafc;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 20px;
      text-align: center;
    }
    .card {
      background: #1e293b;
      padding: 35px;
      border-radius: 20px;
      box-shadow: 0 20px 40px rgba(0,0,0,0.6);
      max-width: 520px;
      width: 100%;
      border: 1px solid #334155;
    }
    h1 {
      color: #38bdf8;
      margin-top: 0;
      font-size: 24px;
      font-weight: 700;
    }
    p {
      color: #cbd5e1;
      font-size: 15px;
      margin: 10px 0 20px 0;
    }
    .qr-box {
      margin: 15px 0 25px 0;
      background: #ffffff;
      padding: 16px;
      border-radius: 16px;
      display: inline-block;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    }
    .qr-box img {
      display: block;
      width: 220px;
      height: 220px;
    }
    .url-title {
      font-size: 13px;
      text-transform: uppercase;
      letter-spacing: 1px;
      color: #94a3b8;
      font-weight: 600;
      margin-bottom: 6px;
    }
    .url-box {
      word-break: break-all;
      font-size: 16px;
      background: #0f172a;
      padding: 14px 16px;
      border-radius: 10px;
      color: #4ade80;
      font-weight: 600;
      margin-bottom: 20px;
      border: 1px solid #1e293b;
      user-select: all;
    }
    .btn-row {
      display: flex;
      gap: 12px;
      justify-content: center;
      flex-wrap: wrap;
    }
    .btn {
      background: #0284c7;
      color: white;
      border: none;
      padding: 12px 24px;
      border-radius: 10px;
      cursor: pointer;
      font-size: 15px;
      font-weight: 600;
      text-decoration: none;
      transition: background 0.2s;
    }
    .btn:hover {
      background: #0369a1;
    }
    .btn-copy {
      background: #334155;
    }
    .btn-copy:hover {
      background: #475569;
    }
    .badge {
      display: inline-block;
      background: #16a34a;
      color: #ffffff;
      font-size: 12px;
      font-weight: 700;
      padding: 4px 12px;
      border-radius: 20px;
      margin-bottom: 12px;
      letter-spacing: 0.5px;
    }
    .hint {
      color: #64748b;
      font-size: 13px;
      margin-top: 25px;
      line-height: 1.5;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">● ONLINE &amp; ACTIVE</div>
    <h1>Saark ERP - 4G/5G Access</h1>
    <p>Scan this QR code with your <b>iPhone or Android Camera</b>:</p>
    
    <div class="qr-box">
      <img src="$qrUrl" alt="Scan QR Code" />
    </div>

    <div class="url-title">Direct Smartphone URL:</div>
    <div class="url-box" id="erpUrl">$foundUrl</div>

    <div class="btn-row">
      <a href="$foundUrl" target="_blank" class="btn">Open ERP Website</a>
      <button class="btn btn-copy" onclick="navigator.clipboard.writeText('$foundUrl'); alert('Copied to clipboard!');">Copy Link</button>
    </div>

    <div class="hint">
      Works on any device (iOS / Android / Laptop) over 4G, 5G, or Wi-Fi.<br>
      Please keep the tunnel window open on your PC while using the system.
    </div>
  </div>
</body>
</html>
"@
    Set-Content -Path $htmlFile -Value $htmlContent -Force

    # Automatically launch the QR code & URL page in browser
    Start-Process $htmlFile

    # Display clear banner in the console
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host "                    SAARK ERP - 4G/5G LINK READY!                     " -ForegroundColor Yellow
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  📱 DIRECT 4G / 5G SMARTPHONE URL:" -ForegroundColor Cyan
    Write-Host "  👉  $foundUrl" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  📶 LOCAL WI-FI URL:" -ForegroundColor Cyan
    Write-Host "  👉  http://192.168.1.104:3000" -ForegroundColor White
    Write-Host ""
    Write-Host "  💻 LOCAL PC URL:" -ForegroundColor Cyan
    Write-Host "  👉  http://localhost:3000" -ForegroundColor White
    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host "  * An access screen with QR Code has been opened in your browser!    *" -ForegroundColor Cyan
    Write-Host "  * URL has been copied to your clipboard & saved in 'phone_url.txt' *" -ForegroundColor Magenta
    Write-Host "  * Keep this window OPEN while using the ERP on your phone.         *" -ForegroundColor Gray
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
