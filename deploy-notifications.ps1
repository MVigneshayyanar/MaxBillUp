# Firebase Cloud Functions Deployment Script
# ✅ STATUS: SUCCESSFULLY DEPLOYED on December 21, 2025
# Functions are LIVE and operational!
#
# If you need to redeploy, run this script again.

Write-Host ""
Write-Host "✅ CLOUD FUNCTIONS ALREADY DEPLOYED!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Deployed Functions:" -ForegroundColor Yellow
Write-Host "  1. sendPushNotification (active)" -ForegroundColor Green
Write-Host "  2. sendKnowledgeNotification (active)" -ForegroundColor Green
Write-Host ""
Write-Host "To redeploy or update functions, continue..." -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to continue with deployment, or Ctrl+C to exit"

Write-Host ""
Write-Host "🚀 Firebase Cloud Functions Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Firebase CLI is installed
$firebaseInstalled = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebaseInstalled) {
    Write-Host "❌ Firebase CLI is not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install it first:" -ForegroundColor Yellow
    Write-Host "npm install -g firebase-tools" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "✅ Firebase CLI found" -ForegroundColor Green
Write-Host ""

# Navigate to project directory
Set-Location C:\MaxBillUp

Write-Host "📁 Current directory: C:\MaxBillUp" -ForegroundColor Cyan
Write-Host ""

# Step 1: Login
Write-Host "Step 1: Logging in to Firebase..." -ForegroundColor Yellow
Write-Host "Please use the account that has access to 'maxbillup' project" -ForegroundColor Gray
Write-Host ""
firebase login

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Login failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Login successful!" -ForegroundColor Green
Write-Host ""

# Step 2: Set project
Write-Host "Step 2: Setting Firebase project to 'maxbillup'..." -ForegroundColor Yellow
firebase use maxbillup

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Failed to set project!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Make sure you have access to the 'maxbillup' project" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "✅ Project set successfully!" -ForegroundColor Green
Write-Host ""

# Step 3: Deploy functions
Write-Host "Step 3: Deploying Cloud Functions..." -ForegroundColor Yellow
Write-Host "This may take 1-2 minutes..." -ForegroundColor Gray
Write-Host ""
firebase deploy --only functions

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎉 Notifications are now enabled!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run your Flutter app" -ForegroundColor White
Write-Host "2. Login as admin (maxmybillapp@gmail.com)" -ForegroundColor White
Write-Host "3. Go to Knowledge tab" -ForegroundColor White
Write-Host "4. Post new knowledge" -ForegroundColor White
Write-Host "5. Check if notification is sent! 🔔" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

