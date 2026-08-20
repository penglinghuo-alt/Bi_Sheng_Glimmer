# 一键复制本机 Flutter SDK 的 canvaskit 到 web/canvaskit
# 用法: 双击运行 或 右键 -> 使用 PowerShell 运行
$ErrorActionPreference = "Stop"

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd) {
    $flutterRoot = Split-Path (Split-Path $flutterCmd.Source -Parent) -Parent
} else {
    $envPath = Get-ChildItem Env:FLUTTER_ROOT -ErrorAction SilentlyContinue
    if ($envPath) {
        $flutterRoot = $envPath.Value
    } else {
        Write-Host "未找到 flutter，请先安装 Flutter 或把它加入 PATH" -ForegroundColor Red
        Read-Host "按回车退出"
        exit 1
    }
}

$src = Join-Path $flutterRoot "bin\cache\flutter_web_sdk\canvaskit"
$dst = Join-Path $PSScriptRoot "canvaskit"

if (-not (Test-Path $src)) {
    Write-Host "未找到 SDK canvaskit: $src" -ForegroundColor Red
    Write-Host "请先运行一次 'flutter build web' 生成缓存后再执行本脚本" -ForegroundColor Yellow
    Read-Host "按回车退出"
    exit 1
}

if (Test-Path $dst) {
    Write-Host "web\canvaskit 已存在，正在覆盖更新..." -ForegroundColor Yellow
}

Copy-Item -Recurse $src $dst -Force
Write-Host "完成! canvaskit 已复制到 $dst" -ForegroundColor Green
Write-Host "现在重新运行 flutter run 或 flutter build web 即可，无需再访问 Google" -ForegroundColor Green
Read-Host "按回车退出"
