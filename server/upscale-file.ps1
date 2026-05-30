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
    $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $boundary = [System.Guid]::NewGuid().ToString()
    $LF = "`r`n"

    $bodyLines = @(
        "--$boundary",
        "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"",
        "Content-Type: application/octet-stream",
        "",
        ""
    )
    $headerBytes = [System.Text.Encoding]::UTF8.GetBytes(($bodyLines -join $LF))
    $footerBytes = [System.Text.Encoding]::UTF8.GetBytes("${LF}--${boundary}--${LF}")

    $body = New-Object byte[] ($headerBytes.Length + $fileBytes.Length + $footerBytes.Length)
    [Buffer]::BlockCopy($headerBytes, 0, $body, 0, $headerBytes.Length)
    [Buffer]::BlockCopy($fileBytes, 0, $body, $headerBytes.Length, $fileBytes.Length)
    [Buffer]::BlockCopy($footerBytes, 0, $body, $headerBytes.Length + $fileBytes.Length, $footerBytes.Length)

    $contentType = "multipart/form-data; boundary=$boundary"
    $response = Invoke-RestMethod -Uri "$ServerUrl/upscale" -Method Post -Body $body -ContentType $contentType -TimeoutSec 300 -ErrorAction Stop
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