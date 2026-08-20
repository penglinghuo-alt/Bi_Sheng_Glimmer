# Copy canvaskit from local Flutter SDK to web/canvaskit
# Usage: right-click -> Run with PowerShell
$ErrorActionPreference = "Stop"

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd) {
    $flutterRoot = Split-Path (Split-Path $flutterCmd.Source -Parent) -Parent
} else {
    $envPath = Get-ChildItem Env:FLUTTER_ROOT -ErrorAction SilentlyContinue
    if ($envPath) {
        $flutterRoot = $envPath.Value
    } else {
        Write-Host "Flutter not found. Please install Flutter or add it to PATH." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

$src = Join-Path $flutterRoot "bin\cache\flutter_web_sdk\canvaskit"
$dst = Join-Path $PSScriptRoot "canvaskit"

if (-not (Test-Path $src)) {
    Write-Host "SDK canvaskit not found: $src" -ForegroundColor Red
    Write-Host "Run 'flutter build web' once first to generate the cache." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

if (Test-Path $dst) {
    Write-Host "web\canvaskit already exists, updating..." -ForegroundColor Yellow
}

Copy-Item -Recurse $src $dst -Force
Write-Host "Done! canvaskit copied to $dst" -ForegroundColor Green
Write-Host "Now re-run 'flutter run' or 'flutter build web'. No Google access needed." -ForegroundColor Green
Read-Host "Press Enter to exit"
