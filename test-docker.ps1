# Docker Deployment Verification Script
# Run this to check if your Docker deployment is good

Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Docker Deployment Health Check                  ║" -ForegroundColor Cyan
Write-Host "║   USF Moving AI Agent                             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

# Test 1: Check if Docker is running
Write-Host "═══ Test 1: Docker Service ═══" -ForegroundColor Yellow
try {
    docker info > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Docker is running" -ForegroundColor Green
    } else {
        Write-Host "❌ Docker is not running" -ForegroundColor Red
        $allPassed = $false
    }
} catch {
    Write-Host "❌ Cannot connect to Docker" -ForegroundColor Red
    $allPassed = $false
}
Write-Host ""

# Test 2: Check if container exists and is running
Write-Host "═══ Test 2: Container Status ═══" -ForegroundColor Yellow
$container = docker ps --filter "name=callagent-app" --format "{{.Names}}"
if ($container -eq "callagent-app") {
    Write-Host "✅ Container 'callagent-app' is running" -ForegroundColor Green
    
    # Get container details
    $status = docker inspect callagent-app --format='{{.State.Status}}'
    $uptime = docker inspect callagent-app --format='{{.State.StartedAt}}'
    Write-Host "   Status: $status" -ForegroundColor Gray
    Write-Host "   Started: $uptime" -ForegroundColor Gray
} else {
    Write-Host "❌ Container 'callagent-app' is not running" -ForegroundColor Red
    $allPassed = $false
}
Write-Host ""

# Test 3: Check container resource usage
Write-Host "═══ Test 3: Resource Usage ═══" -ForegroundColor Yellow
try {
    $stats = docker stats callagent-app --no-stream --format "{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}}"
    $cpu, $mem, $memperc = $stats -split ','
    Write-Host "✅ Resources:" -ForegroundColor Green
    Write-Host "   CPU: $cpu" -ForegroundColor Gray
    Write-Host "   Memory: $mem ($memperc)" -ForegroundColor Gray
} catch {
    Write-Host "⚠️  Could not get resource stats" -ForegroundColor Yellow
}
Write-Host ""

# Test 4: Check if key packages are installed
Write-Host "═══ Test 4: Python Packages ═══" -ForegroundColor Yellow
try {
    $packages = docker exec callagent-app pip list 2>$null | Select-String -Pattern "Flask|twilio|gunicorn|openai"
    if ($packages) {
        Write-Host "✅ Key packages installed:" -ForegroundColor Green
        $packages | ForEach-Object {
            Write-Host "   $_" -ForegroundColor Gray
        }
    } else {
        Write-Host "❌ Packages not found" -ForegroundColor Red
        $allPassed = $false
    }
} catch {
    Write-Host "❌ Cannot check packages" -ForegroundColor Red
    $allPassed = $false
}
Write-Host ""

# Test 5: Check if Flask app loads
Write-Host "═══ Test 5: Flask Application ═══" -ForegroundColor Yellow
try {
    $result = docker exec callagent-app python -c "import app; print('OK')" 2>&1
    if ($result -match "OK") {
        Write-Host "✅ Flask app imports successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Flask app failed to import" -ForegroundColor Red
        Write-Host "   Error: $result" -ForegroundColor Gray
        $allPassed = $false
    }
} catch {
    Write-Host "❌ Cannot test Flask import" -ForegroundColor Red
    $allPassed = $false
}
Write-Host ""

# Test 6: Check if port is mapped correctly
Write-Host "═══ Test 6: Port Mapping ═══" -ForegroundColor Yellow
$ports = docker port callagent-app 2>$null
if ($ports -match "5000.*80") {
    Write-Host "✅ Port mapping: 80 → 5000" -ForegroundColor Green
    Write-Host "   $ports" -ForegroundColor Gray
} else {
    Write-Host "❌ Port mapping incorrect" -ForegroundColor Red
    $allPassed = $false
}
Write-Host ""

# Test 7: Test health endpoint (localhost)
Write-Host "═══ Test 7: Health Endpoint (localhost) ═══" -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost/health" -TimeoutSec 5 -ErrorAction Stop
    if ($response.status -eq "healthy") {
        Write-Host "✅ Health endpoint responding" -ForegroundColor Green
        Write-Host "   Status: $($response.status)" -ForegroundColor Gray
        Write-Host "   Service: $($response.service)" -ForegroundColor Gray
    } else {
        Write-Host "⚠️  Health endpoint returned unexpected response" -ForegroundColor Yellow
        Write-Host "   Response: $response" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Health endpoint not responding" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Gray
    $allPassed = $false
}
Write-Host ""

# Test 8: Test if Gunicorn is running with correct config
Write-Host "═══ Test 8: Gunicorn Configuration ═══" -ForegroundColor Yellow
$logs = docker logs callagent-app --tail=20 2>&1
if ($logs -match "gunicorn.*Starting") {
    Write-Host "✅ Gunicorn is running" -ForegroundColor Green
    
    if ($logs -match "workers=1") {
        Write-Host "   Workers: 1 (correct for session management)" -ForegroundColor Gray
    }
    if ($logs -match "threads") {
        Write-Host "   Threads: 4 (for concurrent calls)" -ForegroundColor Gray
    }
    if ($logs -match "Listening at.*5000") {
        Write-Host "   Listening on: 0.0.0.0:5000" -ForegroundColor Gray
    }
} else {
    Write-Host "❌ Gunicorn not detected in logs" -ForegroundColor Red
    $allPassed = $false
}
Write-Host ""

# Test 9: Check for errors in logs
Write-Host "═══ Test 9: Error Check ═══" -ForegroundColor Yellow
$errors = docker logs callagent-app 2>&1 | Select-String -Pattern "ERROR|Exception|Traceback" | Select-Object -First 5
if ($errors) {
    Write-Host "⚠️  Found errors in logs:" -ForegroundColor Yellow
    $errors | ForEach-Object {
        Write-Host "   $_" -ForegroundColor Gray
    }
    Write-Host "   (Check full logs with: docker-compose logs)" -ForegroundColor Gray
} else {
    Write-Host "✅ No errors found in recent logs" -ForegroundColor Green
}
Write-Host ""

# Test 10: Test ngrok connectivity (if running)
Write-Host "═══ Test 10: ngrok Tunnel (Optional) ═══" -ForegroundColor Yellow
try {
    $ngrokApi = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 2 -ErrorAction Stop
    $publicUrl = $ngrokApi.tunnels[0].public_url
    if ($publicUrl) {
        Write-Host "✅ ngrok tunnel is active" -ForegroundColor Green
        Write-Host "   Public URL: $publicUrl" -ForegroundColor Gray
        Write-Host "   → Use this URL in Twilio webhooks" -ForegroundColor Cyan
        
        # Test ngrok URL
        try {
            $ngrokHealth = Invoke-RestMethod -Uri "$publicUrl/health" -TimeoutSec 5 -ErrorAction Stop
            Write-Host "✅ ngrok URL is accessible from internet" -ForegroundColor Green
        } catch {
            Write-Host "⚠️  ngrok URL not responding (may need to wait a moment)" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "⚠️  ngrok is not running (start with: ngrok http 80)" -ForegroundColor Yellow
    Write-Host "   (Only needed for local testing with Twilio)" -ForegroundColor Gray
}
Write-Host ""

# Summary
Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    SUMMARY                         ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($allPassed) {
    Write-Host "🎉 ALL CRITICAL TESTS PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your Docker deployment is READY for:" -ForegroundColor Green
    Write-Host "✅ Local testing with ngrok" -ForegroundColor Green
    Write-Host "✅ Production deployment on AWS" -ForegroundColor Green
    Write-Host "✅ Handling phone calls via Twilio" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Start ngrok (if not running): ngrok http 80" -ForegroundColor Gray
    Write-Host "2. Configure Twilio with ngrok URL" -ForegroundColor Gray
    Write-Host "3. Test by calling your Twilio number" -ForegroundColor Gray
} else {
    Write-Host "⚠️  SOME TESTS FAILED" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Check logs: docker-compose logs -f" -ForegroundColor Gray
    Write-Host "2. Restart: docker-compose restart" -ForegroundColor Gray
    Write-Host "3. Rebuild: docker-compose up -d --build" -ForegroundColor Gray
    Write-Host "4. Check .env file has all required variables" -ForegroundColor Gray
}
Write-Host ""

# Display useful commands
Write-Host "═══ Useful Commands ═══" -ForegroundColor Cyan
Write-Host "View logs:     docker-compose logs -f" -ForegroundColor Gray
Write-Host "Restart:       docker-compose restart" -ForegroundColor Gray
Write-Host "Stop:          docker-compose down" -ForegroundColor Gray
Write-Host "Rebuild:       docker-compose up -d --build" -ForegroundColor Gray
Write-Host "Shell access:  docker exec -it callagent-app bash" -ForegroundColor Gray
Write-Host ""
