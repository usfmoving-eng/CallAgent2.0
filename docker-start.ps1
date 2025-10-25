# Docker Quick Start Script for Windows PowerShell
# Run this script to build and start your Docker container

Write-Host "🐳 Starting USF Moving AI Agent with Docker..." -ForegroundColor Cyan
Write-Host ""

# Check if Docker is installed
Write-Host "Checking Docker installation..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version
    Write-Host "✅ Docker found: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker is not installed!" -ForegroundColor Red
    Write-Host "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

# Check if Docker is running
Write-Host ""
Write-Host "Checking if Docker is running..." -ForegroundColor Yellow
try {
    docker info > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Docker is not running!" -ForegroundColor Red
        Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "❌ Cannot connect to Docker!" -ForegroundColor Red
    exit 1
}

# Check if .env file exists
Write-Host ""
Write-Host "Checking for .env file..." -ForegroundColor Yellow
if (-Not (Test-Path ".env")) {
    Write-Host "⚠️  Warning: .env file not found!" -ForegroundColor Yellow
    Write-Host "Make sure to create .env with your API keys before continuing." -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y") {
        exit 0
    }
} else {
    Write-Host "✅ .env file found" -ForegroundColor Green
}

# Stop existing containers
Write-Host ""
Write-Host "Stopping any existing containers..." -ForegroundColor Yellow
docker-compose down 2>$null
Write-Host "✅ Cleaned up old containers" -ForegroundColor Green

# Build the Docker image
Write-Host ""
Write-Host "🔨 Building Docker image..." -ForegroundColor Cyan
docker-compose build
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Build successful" -ForegroundColor Green

# Start the container
Write-Host ""
Write-Host "🚀 Starting container..." -ForegroundColor Cyan
docker-compose up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to start container!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Container started" -ForegroundColor Green

# Wait a moment for container to be ready
Write-Host ""
Write-Host "⏳ Waiting for application to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Check container status
Write-Host ""
Write-Host "📊 Container Status:" -ForegroundColor Cyan
docker-compose ps

# Test health endpoint
Write-Host ""
Write-Host "🏥 Testing health endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost/health" -TimeoutSec 5
    Write-Host "✅ Application is healthy!" -ForegroundColor Green
    Write-Host "   Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Gray
} catch {
    Write-Host "⚠️  Health check failed (app may still be starting)" -ForegroundColor Yellow
}

# Show logs
Write-Host ""
Write-Host "📋 Recent logs:" -ForegroundColor Cyan
docker-compose logs --tail=20

# Final instructions
Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✅ Docker container is running!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 Application URL: http://localhost" -ForegroundColor Cyan
Write-Host "🏥 Health Check:    http://localhost/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Useful Commands:" -ForegroundColor Yellow
Write-Host "   View logs:       docker-compose logs -f" -ForegroundColor Gray
Write-Host "   Stop container:  docker-compose down" -ForegroundColor Gray
Write-Host "   Restart:         docker-compose restart" -ForegroundColor Gray
Write-Host "   Rebuild:         docker-compose up -d --build" -ForegroundColor Gray
Write-Host ""
Write-Host "🔗 For ngrok, run in another terminal:" -ForegroundColor Yellow
Write-Host "   ngrok http 80" -ForegroundColor Gray
Write-Host ""
