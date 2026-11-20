$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "env.json"
if (-Not (Test-Path $configPath)) {
    Write-Host "Error: scripts\env.json not found!" -ForegroundColor Red
    exit 1
}
$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

$rootDir = Split-Path $PSScriptRoot -Parent
$targetSrc = (Resolve-Path (Join-Path $rootDir $config.srcPath)).Path
$logFile = Join-Path $PSScriptRoot "1c_dump.log"

if (Test-Path $logFile) { Remove-Item $logFile }

Write-Host "=== Starting 1C extension dump to Git ===" -ForegroundColor Cyan

# Формируем аргументы строго отдельными элементами массива
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

$argsList += "/DumpConfigToFiles"
$argsList += $targetSrc
$argsList += "-update"

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
    Write-Host "=== Extension dump completed successfully! Ready to commit. ===" -ForegroundColor Green
} else {
    Write-Host "=== Dump failed! Exit code: $($process.ExitCode) ===" -ForegroundColor Red
    if (Test-Path $logFile) {
        Write-Host "--- 1C Error Log ---" -ForegroundColor Yellow
        Get-Content $logFile -Encoding Default
    } else {
        Write-Host "Log file was not created. Check server name, user/password or close open Configurator." -ForegroundColor Yellow
    }
    exit $process.ExitCode
}
