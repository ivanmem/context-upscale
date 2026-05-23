[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = 'https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth'
$outFile = Join-Path $PSScriptRoot 'weights' '4x-UltraSharp.pth'
if (-not (Test-Path (Split-Path $outFile))) { New-Item -ItemType Directory -Path (Split-Path $outFile) -Force | Out-Null }
Write-Host "      Downloading 4x-UltraSharp.pth (~64 MB)..."
Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing
