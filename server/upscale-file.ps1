param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

$ServerUrl = "http://127.0.0.1:7869"

if (-not (Test-Path $FilePath)) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("File not found: $FilePath", "Upscale Error", "OK", "Error")
    exit 1
}

try {
    $health = Invoke-RestMethod -Uri "$ServerUrl/health" -TimeoutSec 3 -ErrorAction Stop
} catch {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Upscale server is not running.",
        "Upscale Error", "OK", "Warning"
    )
    exit 1
}

try {
    $form = @{ file = Get-Item -LiteralPath $FilePath }
    $response = Invoke-RestMethod -Uri "$ServerUrl/upscale" -Method Post -Form $form -TimeoutSec 300 -ErrorAction Stop
} catch {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Upscale failed: $($_.Exception.Message)",
        "Upscale Error", "OK", "Error"
    )
    exit 1
}

$resultUrl = "$ServerUrl/result/$($response.id)"
Start-Process $resultUrl