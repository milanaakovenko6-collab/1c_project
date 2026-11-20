$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "env.json"
if (-Not (Test-Path $configPath)) {
    Write-Host "Ошибка: Не найден файл настроек scripts\env.json!" -ForegroundColor Red
    exit 1
}
$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

$rootDir = Split-Path $PSScriptRoot -Parent
$targetSrc = Join-Path $rootDir $config.srcPath

Write-Host "=== Начинаем выгрузку серверной базы 1С в файлы ===" -ForegroundColor Cyan
Write-Host "Сервер и база: $($config.ibServer)"
Write-Host "Папка выгрузки: $targetSrc"

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

# Выгружаем только изменившиеся объекты
$argsList += "/DumpConfigToFiles `"$targetSrc`" -update"
$argsList += "/DisableStartupDialogs"
$argsList += "/DisableStartupMessages"

$process = Start-Process -FilePath $config.v8path -ArgumentList $argsList -Wait -PassThru -NoNewWindow

if ($process.ExitCode -eq 0) {
    Write-Host "=== Выгрузка успешно завершена! Можно делать коммит в Git. ===" -ForegroundColor Green
} else {
    Write-Host "=== Ошибка при выгрузке! Код возврата: $($process.ExitCode) ===" -ForegroundColor Red
    exit $process.ExitCode
}
