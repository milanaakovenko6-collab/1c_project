$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "env.json"
if (-Not (Test-Path $configPath)) {
    Write-Host "Error: scripts\env.json not found!" -ForegroundColor Red
    exit 1
}
$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

$rootDir = Split-Path $PSScriptRoot -Parent
$targetSrc = (Resolve-Path (Join-Path $rootDir $config.srcPath)).Path
$logFile = Join-Path $PSScriptRoot "1c_load.log"

if (Test-Path $logFile) { Remove-Item $logFile }

Write-Host "=== Loading extension sources from Git to 1C server ===" -ForegroundColor Cyan

$argsList = @(
    "DESIGNER",
    "/S", $config.ibServer
)

if ($config.ibUser -ne "") {
    $argsList += "/N"
    $argsList += "`"$($config.ibUser)`""
}

if ($config.ibPwd -ne "") {
    $argsList += "/P"
    $argsList += $config.ibPwd
}

$argsList += "/LoadConfigFromFiles"
$argsList += $targetSrc

if ($config.extensionName -and $config.extensionName -ne "") {
    $argsList += "-Extension"
    $argsList += $config.extensionName
}

$argsList += "/UpdateDBCfg"
if ($config.extensionName -and $config.extensionName -ne "") {
    $argsList += "-Extension"
    $argsList += $config.extensionName
}

$argsList += "/DisableStartupDialogs"
$argsList += "/DisableStartupMessages"
$argsList += "/Out"
$argsList += $logFile

Write-Host "Command: $($config.v8path) $($argsList -join ' ')" -ForegroundColor DarkGray

$process = Start-Process -FilePath $config.v8path -ArgumentList $argsList -Wait -PassThru -NoNewWindow

if ($process.ExitCode -eq 0) {
    Write-Host "=== Extension loaded and updated on server! ===" -ForegroundColor Green
} else {
    Write-Host "=== Load failed! Exit code: $($process.ExitCode) ===" -ForegroundColor Red
    if (Test-Path $logFile) {
        Write-Host "--- 1C Error Log ---" -ForegroundColor Yellow
        Get-Content $logFile -Encoding Default
    } else {
        Write-Host "Log file was not created. Check parameters." -ForegroundColor Yellow
    }
    exit $process.ExitCode
}
