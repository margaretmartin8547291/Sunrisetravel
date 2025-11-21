param(
  [int]$Port = 8000,
  [string]$Root = (Get-Location).Path
)

Add-Type -AssemblyName System.Net.HttpListener
Add-Type -AssemblyName System.IO

$prefix = "http://localhost:${Port}/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "Static server running at $prefix serving $Root"

function Get-ContentType($path) {
  switch ([System.IO.Path]::GetExtension($path).ToLower()) {
    ".html" { return "text/html; charset=utf-8" }
    ".css"  { return "text/css; charset=utf-8" }
    ".js"   { return "application/javascript; charset=utf-8" }
    ".png"  { return "image/png" }
    ".jpg"  { return "image/jpeg" }
    ".jpeg" { return "image/jpeg" }
    ".svg"  { return "image/svg+xml" }
    default  { return "application/octet-stream" }
  }
}

while ($listener.IsListening) {
  try {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response

    $localPath = $req.Url.LocalPath
    if ($localPath -eq "/") { $localPath = "/index.html" }

    # Prevent directory traversal
    $safePath = $localPath -replace "\\\\", "/" -replace "\.\.\/", "" -replace "\.\.\\", ""
    $fsPath = Join-Path $Root ($safePath.TrimStart('/'))

    if (Test-Path $fsPath -PathType Leaf) {
      $bytes = [System.IO.File]::ReadAllBytes($fsPath)
      $res.ContentType = Get-ContentType $fsPath
      $res.StatusCode = 200
      $res.ContentLength64 = $bytes.Length
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    }
    else {
      $msg = [Text.Encoding]::UTF8.GetBytes("404 Not Found")
      $res.StatusCode = 404
      $res.ContentType = "text/plain; charset=utf-8"
      $res.ContentLength64 = $msg.Length
      $res.OutputStream.Write($msg, 0, $msg.Length)
    }
    $res.OutputStream.Close()
  }
  catch {
    Write-Host "Error: $($_.Exception.Message)"
  }
}