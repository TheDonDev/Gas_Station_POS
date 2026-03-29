# Set encoding to UTF8 for clean emoji display
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "🚀 Starting Gas Station POS Full Stack..." -ForegroundColor Cyan

# Prevent "cannot open for writing" error by closing any running instances of the app
Write-Host "🧹 Cleaning up previous instances..." -ForegroundColor Gray
Stop-Process -Name "gas_store_pos" -ErrorAction SilentlyContinue

# 1. Start the Node.js Backend in a new window so logs stay separated
Write-Host "📦 Launching Backend Server..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location backend; npm start"

# 2. Start the Flutter Frontend in the current window
Write-Host "📱 Launching Flutter Frontend..." -ForegroundColor Green
flutter run -d windows