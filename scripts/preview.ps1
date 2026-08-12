# ROUNDER — 로컬 미리보기 (빠른 debug 빌드 + 자동 새로고침)
# 사용법: powershell -ExecutionPolicy Bypass -File scripts/preview.ps1
#
# http://127.0.0.1:8888/
# lib/ · assets/ 저장 → 자동 재빌드 → 브라우저 자동 새로고침

$ErrorActionPreference = "Continue"
$Port = 8888
$HostName = "127.0.0.1"
$Flutter = Join-Path $env:LOCALAPPDATA "cursor-flutter\flutter\bin\flutter.bat"
$AppDir = Split-Path $PSScriptRoot -Parent
$WebDir = Join-Path $AppDir "build\web"
$BuildLock = Join-Path $env:TEMP "rounder_web_build.lock"
$StampFile = Join-Path $env:TEMP "rounder_build_stamp.txt"
$OpenPanel = Join-Path $PSScriptRoot "open_preview_panel.ps1"
$PreviewUrl = "http://${HostName}:${Port}/"
$global:PreviewDirty = $false

$LiveReloadScript = @'
<script id="rounder-livereload">(function(){var v=0;setInterval(function(){fetch("/__livereload__",{cache:"no-store"}).then(function(r){return r.text()}).then(function(t){var n=+t;if(v&&n!==v)location.reload();v=n}).catch(function(){});},700);})();</script>
'@

function Stop-PortProcess {
  param([int]$TargetPort)
  Get-NetTCPConnection -LocalPort $TargetPort -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique |
    ForEach-Object {
      if ($_ -gt 4) { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
    }
}

function Set-BuildStamp {
  $ms = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  Set-Content -Path $StampFile -Value $ms -NoNewline -Encoding ascii
}

function Invoke-WebBuild {
  if (Test-Path $BuildLock) { return $false }
  New-Item -ItemType File -Path $BuildLock -Force | Out-Null
  try {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Building..." -ForegroundColor Cyan
    Set-Location $AppDir
    & $Flutter build web --debug --dart-define=FORCE_OFFLINE_MOCK=true 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
      Set-BuildStamp
      Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Build OK — browser will refresh" -ForegroundColor Green
      return $true
    }
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Build FAILED (check errors above)" -ForegroundColor Red
    return $false
  } finally {
    Remove-Item $BuildLock -Force -ErrorAction SilentlyContinue
  }
}

function Start-PreviewServer {
  param([string]$Root, [int]$ListenPort, [string]$BindHost, [string]$StampPath, [string]$InjectScript)

  $listener = New-Object System.Net.HttpListener
  $listener.Prefixes.Add("http://${BindHost}:${ListenPort}/")
  $listener.Start()

  while ($listener.IsListening) {
    $ctx = $null
    try { $ctx = $listener.GetContext() } catch { break }
    if (-not $ctx) { continue }

    $path = $ctx.Request.Url.LocalPath
    try {
      if ($path -eq "/__livereload__") {
        $stamp = if (Test-Path $StampPath) { (Get-Content $StampPath -Raw).Trim() } else { "0" }
        $bytes = [Text.Encoding]::UTF8.GetBytes($stamp)
        $ctx.Response.ContentType = "text/plain; charset=utf-8"
        $ctx.Response.Headers.Add("Cache-Control", "no-store")
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        continue
      }

      $rel = $path.TrimStart("/") -replace "/", "\"
      if ([string]::IsNullOrWhiteSpace($rel)) { $rel = "index.html" }
      $file = Join-Path $Root $rel
      if (-not (Test-Path $file -PathType Leaf)) { $file = Join-Path $Root "index.html" }
      if (-not (Test-Path $file -PathType Leaf)) {
        $ctx.Response.StatusCode = 404
        continue
      }

      $bytes = [IO.File]::ReadAllBytes($file)
      $ext = [IO.Path]::GetExtension($file).ToLowerInvariant()
      $isHtml = ($ext -eq ".html") -or ($file -like "*\index.html")

      if ($isHtml) {
        $html = [Text.Encoding]::UTF8.GetString($bytes)
        if ($html -notmatch 'id="rounder-livereload"') {
          if ($html -match '</body>') {
            $html = $html -replace '</body>', ($InjectScript + '</body>')
          } else {
            $html += $InjectScript
          }
        }
        $bytes = [Text.Encoding]::UTF8.GetBytes($html)
        $ctx.Response.ContentType = "text/html; charset=utf-8"
      } elseif ($ext -eq ".js") {
        $ctx.Response.ContentType = "application/javascript; charset=utf-8"
      } elseif ($ext -eq ".json") {
        $ctx.Response.ContentType = "application/json; charset=utf-8"
      } elseif ($ext -eq ".wasm") {
        $ctx.Response.ContentType = "application/wasm"
      }

      $ctx.Response.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    } catch {
      $ctx.Response.StatusCode = 500
    } finally {
      $ctx.Response.Close()
    }
  }
}

if (-not (Test-Path $Flutter)) {
  Write-Host "[ERROR] Flutter not found: $Flutter" -ForegroundColor Red
  exit 1
}

Stop-PortProcess -TargetPort $Port
Start-Sleep -Milliseconds 800
Set-BuildStamp

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " ROUNDER Preview (auto refresh)" -ForegroundColor Cyan
Write-Host " URL: $PreviewUrl" -ForegroundColor Green
Write-Host " Save lib/ or assets/ -> auto rebuild -> auto refresh" -ForegroundColor Gray
Write-Host " Opens in Cursor right panel automatically" -ForegroundColor Green
Write-Host " Ctrl+C to stop" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

Invoke-WebBuild | Out-Null

Start-Job -ArgumentList $OpenPanel, $Port -ScriptBlock {
  param($Script, $ListenPort)
  & powershell -ExecutionPolicy Bypass -File $Script -Port $ListenPort
} | Out-Null

$serverJob = Start-Job -ArgumentList $WebDir, $Port, $HostName, $StampFile, $LiveReloadScript -ScriptBlock {
  param($Root, $ListenPort, $BindHost, $StampPath, $InjectScript)
  function Start-PreviewServer {
    param([string]$Root, [int]$ListenPort, [string]$BindHost, [string]$StampPath, [string]$InjectScript)
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://${BindHost}:${ListenPort}/")
    $listener.Start()
    while ($listener.IsListening) {
      $ctx = $null
      try { $ctx = $listener.GetContext() } catch { break }
      if (-not $ctx) { continue }
      $path = $ctx.Request.Url.LocalPath
      try {
        if ($path -eq "/__livereload__") {
          $stamp = if (Test-Path $StampPath) { (Get-Content $StampPath -Raw).Trim() } else { "0" }
          $bytes = [Text.Encoding]::UTF8.GetBytes($stamp)
          $ctx.Response.ContentType = "text/plain; charset=utf-8"
          $ctx.Response.Headers.Add("Cache-Control", "no-store")
          $ctx.Response.ContentLength64 = $bytes.Length
          $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
          continue
        }
        $rel = $path.TrimStart("/") -replace "/", "\"
        if ([string]::IsNullOrWhiteSpace($rel)) { $rel = "index.html" }
        $file = Join-Path $Root $rel
        if (-not (Test-Path $file -PathType Leaf)) { $file = Join-Path $Root "index.html" }
        if (-not (Test-Path $file -PathType Leaf)) {
          $ctx.Response.StatusCode = 404
          continue
        }
        $bytes = [IO.File]::ReadAllBytes($file)
        $ext = [IO.Path]::GetExtension($file).ToLowerInvariant()
        $isHtml = ($ext -eq ".html") -or ($file -like "*\index.html")
        if ($isHtml) {
          $html = [Text.Encoding]::UTF8.GetString($bytes)
          if ($html -notmatch 'id="rounder-livereload"') {
            if ($html -match '</body>') {
              $html = $html -replace '</body>', ($InjectScript + '</body>')
            } else {
              $html += $InjectScript
            }
          }
          $bytes = [Text.Encoding]::UTF8.GetBytes($html)
          $ctx.Response.ContentType = "text/html; charset=utf-8"
        } elseif ($ext -eq ".js") {
          $ctx.Response.ContentType = "application/javascript; charset=utf-8"
        } elseif ($ext -eq ".json") {
          $ctx.Response.ContentType = "application/json; charset=utf-8"
        }
        $ctx.Response.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
      } catch {
        $ctx.Response.StatusCode = 500
      } finally {
        $ctx.Response.Close()
      }
    }
  }
  Start-PreviewServer -Root $Root -ListenPort $ListenPort -BindHost $BindHost -StampPath $StampPath -InjectScript $InjectScript
}

$watchTargets = @(
  (Join-Path $AppDir "lib"),
  (Join-Path $AppDir "assets")
) | Where-Object { Test-Path $_ }

foreach ($target in $watchTargets) {
  $w = New-Object IO.FileSystemWatcher $target, "*.*"
  $w.IncludeSubdirectories = $true
  $w.EnableRaisingEvents = $true
  $action = { $global:PreviewDirty = $true }
  Register-ObjectEvent $w Changed -Action $action | Out-Null
  Register-ObjectEvent $w Created -Action $action | Out-Null
  Register-ObjectEvent $w Deleted -Action $action | Out-Null
  Register-ObjectEvent $w Renamed -Action $action | Out-Null
}

$pubspec = Join-Path $AppDir "pubspec.yaml"
if (Test-Path $pubspec) {
  $pw = New-Object IO.FileSystemWatcher (Split-Path $pubspec -Parent), (Split-Path $pubspec -Leaf)
  $pw.EnableRaisingEvents = $true
  Register-ObjectEvent $pw Changed -Action { $global:PreviewDirty = $true } | Out-Null
}

$lastBuild = [datetime]::MinValue
$pendingSince = $null

try {
  while ($true) {
    Start-Sleep -Milliseconds 400

    if ($global:PreviewDirty) {
      if (-not $pendingSince) { $pendingSince = [datetime]::Now }
      if (([datetime]::Now - $pendingSince).TotalMilliseconds -lt 900) { continue }

      $global:PreviewDirty = $false
      $pendingSince = $null

      if (([datetime]::Now - $lastBuild).TotalSeconds -lt 2) { continue }
      if (Invoke-WebBuild) { $lastBuild = [datetime]::Now }
    }

    if ($serverJob.State -in @("Failed", "Completed", "Stopped")) {
      Write-Host "[WARN] Server stopped — restarting..." -ForegroundColor Yellow
      Stop-PortProcess -TargetPort $Port
      Start-Sleep -Milliseconds 500
      $serverJob = Start-Job -ArgumentList $WebDir, $Port, $HostName, $StampFile, $LiveReloadScript -ScriptBlock {
        param($Root, $ListenPort, $BindHost, $StampPath, $InjectScript)
        function Start-PreviewServer {
          param([string]$Root, [int]$ListenPort, [string]$BindHost, [string]$StampPath, [string]$InjectScript)
          $listener = New-Object System.Net.HttpListener
          $listener.Prefixes.Add("http://${BindHost}:${ListenPort}/")
          $listener.Start()
          while ($listener.IsListening) {
            $ctx = $null
            try { $ctx = $listener.GetContext() } catch { break }
            if (-not $ctx) { continue }
            $path = $ctx.Request.Url.LocalPath
            try {
              if ($path -eq "/__livereload__") {
                $stamp = if (Test-Path $StampPath) { (Get-Content $StampPath -Raw).Trim() } else { "0" }
                $bytes = [Text.Encoding]::UTF8.GetBytes($stamp)
                $ctx.Response.ContentType = "text/plain; charset=utf-8"
                $ctx.Response.Headers.Add("Cache-Control", "no-store")
                $ctx.Response.ContentLength64 = $bytes.Length
                $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                continue
              }
              $rel = $path.TrimStart("/") -replace "/", "\"
              if ([string]::IsNullOrWhiteSpace($rel)) { $rel = "index.html" }
              $file = Join-Path $Root $rel
              if (-not (Test-Path $file -PathType Leaf)) { $file = Join-Path $Root "index.html" }
              if (-not (Test-Path $file -PathType Leaf)) {
                $ctx.Response.StatusCode = 404
                continue
              }
              $bytes = [IO.File]::ReadAllBytes($file)
              $ext = [IO.Path]::GetExtension($file).ToLowerInvariant()
              $isHtml = ($ext -eq ".html") -or ($file -like "*\index.html")
              if ($isHtml) {
                $html = [Text.Encoding]::UTF8.GetString($bytes)
                if ($html -notmatch 'id="rounder-livereload"') {
                  if ($html -match '</body>') {
                    $html = $html -replace '</body>', ($InjectScript + '</body>')
                  } else {
                    $html += $InjectScript
                  }
                }
                $bytes = [Text.Encoding]::UTF8.GetBytes($html)
                $ctx.Response.ContentType = "text/html; charset=utf-8"
              } elseif ($ext -eq ".js") {
                $ctx.Response.ContentType = "application/javascript; charset=utf-8"
              }
              $ctx.Response.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
              $ctx.Response.ContentLength64 = $bytes.Length
              $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            } catch {
              $ctx.Response.StatusCode = 500
            } finally {
              $ctx.Response.Close()
            }
          }
        }
        Start-PreviewServer -Root $Root -ListenPort $ListenPort -BindHost $BindHost -StampPath $StampPath -InjectScript $InjectScript
      }
    }
  }
} finally {
  Stop-Job $serverJob -ErrorAction SilentlyContinue
  Remove-Job $serverJob -Force -ErrorAction SilentlyContinue
}
