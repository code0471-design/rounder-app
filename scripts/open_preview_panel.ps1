# Cursor / VS Code 오른쪽 Simple Browser 에 미리보기 열기
param(
  [int]$Port = 8888,
  [string]$HostName = "127.0.0.1"
)

$Url = "http://${HostName}:${Port}/"
Write-Host "Opening preview panel when server is ready..." -ForegroundColor Gray

for ($i = 0; $i -lt 120; $i++) {
  try {
    $client = New-Object System.Net.Sockets.TcpClient
    $connect = $client.BeginConnect($HostName, $Port, $null, $null)
    $ready = $connect.AsyncWaitHandle.WaitOne(500)
    if ($ready -and $client.Connected) {
      $client.Close()
      Start-Sleep -Milliseconds 600
      $encoded = [Uri]::EscapeDataString($Url)
      Start-Process "vscode://vscode.simple-browser/show?url=$encoded"
      Write-Host "Preview panel opened: $Url" -ForegroundColor Green
      return
    }
    $client.Close()
  } catch {}
  Start-Sleep -Seconds 1
}

Write-Host "[WARN] Server not ready. In Cursor press Ctrl+Shift+P -> Simple Browser: Show -> $Url" -ForegroundColor Yellow
