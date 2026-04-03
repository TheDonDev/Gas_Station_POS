# Set encoding to UTF8 for clean emoji display
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

Write-Host "🚀 Starting Gas Station POS Full Stack..." -ForegroundColor Cyan

# Prevent "cannot open for writing" error by closing any running instances of the app
Write-Host "🧹 Cleaning up previous instances..." -ForegroundColor Gray
# Use taskkill to aggressively release file handles
taskkill /F /IM gas_store_pos.exe /T 2>$null

# Small delay to allow Windows to release file locks
Start-Sleep -Seconds 1

# 0. Check Local MongoDB Status (Optional if using Atlas)
Write-Host "🍃 Checking Local MongoDB Status..." -ForegroundColor Gray
$mongoService = Get-Service -Name "MongoDB" -ErrorAction SilentlyContinue
if ($mongoService) {
    if ($mongoService.Status -ne 'Running') {
        Write-Host "Starting local MongoDB Service..." -ForegroundColor Yellow
        Start-Service -Name "MongoDB"
    }
} else {
    Write-Host "ℹ️ Local MongoDB service not found. This is normal if you are using MongoDB Atlas." -ForegroundColor Blue
}

# Kill any orphaned Node.js processes to ensure the latest server.js runs
Write-Host "🛑 Stopping existing Node servers..." -ForegroundColor Gray
Get-Process "node" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*node.exe*" } | Stop-Process -Force

# 1. Start the Node.js Backend in a new window so logs stay separated
Write-Host "📦 Launching Backend Server..." -ForegroundColor Yellow
Start-Process powershell -WorkingDirectory "$PSScriptRoot\backend" -ArgumentList "-NoExit", "-Command", "npm start"

# 2. Start the Flutter Frontend in the current window
Write-Host "📱 Launching Flutter Frontend..." -ForegroundColor Green
flutter run -d windows