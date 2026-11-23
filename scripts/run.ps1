$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "env.json"
if (-Not (Test-Path $configPath)) {
    Write-Host "Error: scripts\env.json not found!" -ForegroundColor Red
    exit 1
}
$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

$rootDir = Split-Path $PSScriptRoot -Parent
$targetSrc = (Resolve-Path (Join-Path $rootDir $config.srcPath)).Path
$logFile = Join-Path $PSScriptRoot "1c_run.log"

if (Test-Path $logFile) { Remove-Item $logFile }

Write-Host "=== Step 1: Loading code to server (Background Designer) ===" -ForegroundColor Cyan

# Формируем базовые параметры подключения к серверу
$baseArgs = @(
    "/S", $config.ibServer
)

if ($config.ibUser -ne "") {
    $baseArgs += "/N"
    $baseArgs += "`"$($config.ibUser)`""
}

if ($config.ibPwd -ne "") {
    $baseArgs += "/P"
    $baseArgs += "`"$($config.ibPwd)`""
}

# Аргументы для фоновой загрузки и обновления БД
$designerArgs = @("DESIGNER") + $baseArgs + @(
    "/LoadConfigFromFiles", $targetSrc
)

if ($config.extensionName -and $config.extensionName -ne "") {
    $designerArgs += "-Extension"
    $designerArgs += $config.extensionName
}

$designerArgs += "/UpdateDBCfg"
if ($config.extensionName -and $config.extensionName -ne "") {
    $designerArgs += "-Extension"
    $designerArgs += $config.extensionName
}

$designerArgs += @(
    "/DisableStartupDialogs",
    "/DisableStartupMessages",
    "/Out", $logFile
)

# Запускаем фоновую загрузку и ждем завершения
$process = Start-Process -FilePath $config.v8path -ArgumentList $designerArgs -Wait -PassThru -NoNewWindow

if ($process.ExitCode -ne 0) {
    Write-Host "=== Load failed! Exit code: $($process.ExitCode) ===" -ForegroundColor Red
    if (Test-Path $logFile) {
        Write-Host "--- 1C Error Log ---" -ForegroundColor Yellow
        Get-Content $logFile -Encoding Default
    }
    exit $process.ExitCode
}

Write-Host "=== Code loaded successfully! Starting 1C:Enterprise... ===" -ForegroundColor Green

# Шаг 2: Запускаем пользовательский режим (1С:Предприятие) без ожидания закрытия окна
$enterpriseArgs = @("ENTERPRISE") + $baseArgs + @(
    "/DisableStartupDialogs",
    "/DisableStartupMessages"
)

Start-Process -FilePath $config.v8path -ArgumentList $enterpriseArgs
