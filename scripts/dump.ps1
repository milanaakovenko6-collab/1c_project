$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "env.json"
if (-Not (Test-Path $configPath)) {
    Write-Host "Error: scripts\env.json not found! Copy env.example.json to env.json." -ForegroundColor Red
    exit 1
}
$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

$rootDir = Split-Path $PSScriptRoot -Parent
$targetSrc = Join-Path $rootDir $config.srcPath

Write-Host "=== Starting 1C configuration dump to Git ===" -ForegroundColor Cyan
Write-Host "Server: $($config.ibServer)"
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

$argsList += "/DumpConfigToFiles `"$targetSrc`" -update"
$argsList += "/DisableStartupDialogs"
$argsList += "/DisableStartupMessages"

$process = Start-Process -FilePath $config.v8path -ArgumentList $argsList -Wait -PassThru -NoNewWindow

if ($process.ExitCode -eq 0) {
    Write-Host "=== Dump completed successfully! Ready to commit. ===" -ForegroundColor Green
} else {
    Write-Host "=== Dump failed! Exit code: $($process.ExitCode) ===" -ForegroundColor Red
    exit $process.ExitCode
}
