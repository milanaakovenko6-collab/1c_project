$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "env.json"
if (-Not (Test-Path $configPath)) {
    Write-Host "Error: scripts\env.json not found!" -ForegroundColor Red
    exit 1
}
$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

$rootDir = Split-Path $PSScriptRoot -Parent
$targetSrc = Join-Path $rootDir $config.srcPath

Write-Host "=== Loading sources from Git to 1C server ===" -ForegroundColor Cyan
Write-Host "Server: $($config.ibServer)"

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

$argsList += "/LoadConfigFromFiles `"$targetSrc`""
$argsList += "/UpdateDBCfg"
$argsList += "/DisableStartupDialogs"
$argsList += "/DisableStartupMessages"

$process = Start-Process -FilePath $config.v8path -ArgumentList $argsList -Wait -PassThru -NoNewWindow

if ($process.ExitCode -eq 0) {
    Write-Host "=== Configuration loaded and updated on server! ===" -ForegroundColor Green
} else {
    Write-Host "=== Load failed! Exit code: $($process.ExitCode) ===" -ForegroundColor Red
    exit $process.ExitCode
}
