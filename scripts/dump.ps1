$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "env.json"
if (-Not (Test-Path $configPath)) {
    Write-Host "Error: scripts\env.json not found!" -ForegroundColor Red
    exit 1
}
$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

$rootDir = Split-Path $PSScriptRoot -Parent
$targetSrc = Join-Path $rootDir $config.srcPath
$logFile = Join-Path $PSScriptRoot "1c_dump.log"

if (Test-Path $logFile) { Remove-Item $logFile }

Write-Host "=== Starting 1C extension dump to Git ===" -ForegroundColor Cyan
Write-Host "Server: $($config.ibServer)"
Write-Host "Extension: $($config.extensionName)"
Write-Host "Target directory: $targetSrc"

$argsList = @(
    "DESIGNER",
    "/S `"$($config.ibServer)`""
)

if ($config.ibUser -ne "") {
    $argsList += "/N `"$($config.ibUser)`""
}

if ($config.ibPwd -ne "") {
    $argsList += "/P `"$($config.ibPwd)`""
}

$dumpCmd = "/DumpConfigToFiles `"$targetSrc`" -update"
if ($config.extensionName -and $config.extensionName -ne "") {
    $dumpCmd += " -Extension `"$($config.extensionName)`""
}
$argsList += $dumpCmd

$argsList += "/DisableStartupDialogs"
$argsList += "/DisableStartupMessages"
$argsList += "/Out `"$logFile`""

$process = Start-Process -FilePath $config.v8path -ArgumentList $argsList -Wait -PassThru -NoNewWindow

if ($process.ExitCode -eq 0) {
    Write-Host "=== Extension dump completed successfully! Ready to commit. ===" -ForegroundColor Green
} else {
    Write-Host "=== Dump failed! Exit code: $($process.ExitCode) ===" -ForegroundColor Red
    if (Test-Path $logFile) {
        Write-Host "--- 1C Error Log ---" -ForegroundColor Yellow
        Get-Content $logFile -Encoding Default
    }
    exit $process.ExitCode
}
