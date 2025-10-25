# Docker Setup Guide for USF Moving AI Agent

## 🐳 Docker Files Created

1. **Dockerfile** - Container image definition
2. **docker-compose.yml** - Service orchestration
3. **.dockerignore** - Files to exclude from image

---

## 🚀 Quick Start

### **Step 1: Install Docker Desktop (Windows)**

1. Download Docker Desktop from: https://www.docker.com/products/docker-desktop
2. Run the installer
3. Restart your computer
4. Open Docker Desktop and wait for it to start

### **Step 2: Verify Docker Installation**

Open PowerShell and run:
```powershell
docker --version
docker-compose --version
```

Should show versions like:
```
Docker version 24.0.x
Docker Compose version v2.x.x
```

---

## 🏗️ Build and Run with Docker

### **Option 1: Using Docker Compose (Recommended)**

```powershell
# Navigate to project directory
cd "C:\Users\FINE LAPTOP\Desktop\Call"

# Build and start the container
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the container
docker-compose down
```

### **Option 2: Using Docker Commands**

```powershell
# Build the image
docker build -t callagent .

# Run the container
docker run -d `
  --name callagent-app `
  -p 80:5000 `
  --env-file .env `
  callagent

# View logs
docker logs -f callagent-app

# Stop the container
docker stop callagent-app
docker rm callagent-app
```

---

## 📋 Common Docker Commands

### **Container Management**

```powershell
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Restart services
docker-compose restart

# View running containers
docker ps

# View all containers (including stopped)
docker ps -a

# Remove all stopped containers
docker container prune
```

### **Logs and Debugging**

```powershell
# View logs (follow mode)
docker-compose logs -f

# View logs for last 100 lines
docker-compose logs --tail=100

# Execute command in running container
docker exec -it callagent-app bash

# Check container health
docker inspect callagent-app | grep -A 10 Health
```

### **Image Management**

```powershell
# List images
docker images

# Remove image
docker rmi callagent

# Rebuild without cache
docker-compose build --no-cache

# Remove unused images
docker image prune
```

---

## 🔧 Configuration

### **Environment Variables**

All environment variables are loaded from your `.env` file. Make sure it contains:

```bash
# Twilio
TWILIO_ACCOUNT_SID=your_sid
TWILIO_AUTH_TOKEN=your_token
TWILIO_PHONE_NUMBER=your_number

# OpenAI
OPENAI_API_KEY=your_key

# Google
GOOGLE_MAPS_API_KEY=your_key
GOOGLE_SHEETS_CREDS={"your":"json"}
BOOKING_SHEET_ID=your_sheet_id

# Email
EMAIL_ADDRESS=your_email
EMAIL_PASSWORD=your_password
MANAGER_EMAIL=manager_email
```

### **Port Configuration**

- **Container Port:** 5000 (internal)
- **Host Port:** 80 (external)
- Access at: `http://localhost` or `http://your-ip`

To change the external port, edit `docker-compose.yml`:
```yaml
ports:
  - "8080:5000"  # Use port 8080 instead
```

---

## 🧪 Testing Your Docker Setup

### **1. Health Check**

```powershell
curl http://localhost/health
```

Should return:
```json
{"status":"healthy","service":"USF Moving AI Agent"}
```

### **2. View Container Status**

```powershell
docker-compose ps
```

Should show:
```
NAME               STATUS          PORTS
callagent-app      Up (healthy)    0.0.0.0:80->5000/tcp
```

### **3. Test with ngrok**

```powershell
# In a separate terminal, start ngrok
ngrok http 80

# Use the ngrok URL for Twilio webhooks
# Example: https://xxxx.ngrok-free.app/voice/inbound
```

---

## 🔄 Updating Your Application

### **After Code Changes**

```powershell
# Stop current container
docker-compose down

# Rebuild image
docker-compose build

# Start with new image
docker-compose up -d

# Or do all in one command:
docker-compose up -d --build
```

### **Quick Restart (No Code Changes)**

```powershell
docker-compose restart
```

---

## 🐛 Troubleshooting

### **Container Won't Start**

```powershell
# Check logs
docker-compose logs

# Check for port conflicts
netstat -ano | findstr :80

# Remove old containers
docker-compose down
docker container prune
```

### **Can't Connect to Container**

```powershell
# Verify container is running
docker ps

# Check port mapping
docker port callagent-app

# Test from inside container
docker exec -it callagent-app curl http://localhost:5000/health
```

### **Environment Variables Not Working**

```powershell
# Check if .env file exists
ls .env

# View environment variables in container
docker exec callagent-app printenv | grep TWILIO
```

### **Out of Disk Space**

```powershell
# Clean up Docker
docker system prune -a

# Remove unused volumes
docker volume prune
```

---

## 📊 Docker vs Local Development

| Aspect | Local (python app.py) | Docker |
|--------|----------------------|--------|
| Setup | Simple, quick | One-time setup |
| Isolation | Uses local Python | Isolated environment |
| Portability | OS-dependent | Works anywhere |
| Production | Not recommended | Production-ready |
| Debugging | Easy with debugger | Requires docker exec |
| Updates | Instant | Requires rebuild |

---

## 🚀 Production Deployment

### **For AWS EC2**

```bash
# SSH into EC2
ssh ubuntu@your-server-ip

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Clone your repo
git clone https://github.com/usfmoving-eng/Callagent.git
cd Callagent

# Create .env file
nano .env
# Paste your environment variables

# Start with Docker Compose
docker-compose up -d

# Check logs
docker-compose logs -f
```

### **For Render/Heroku**

These platforms auto-detect Dockerfile and build automatically. No docker-compose needed.

---

## 📝 Docker Architecture

```
┌─────────────────────────────────────┐
│         Docker Host (Windows)        │
│                                      │
│  ┌────────────────────────────────┐ │
│  │  callagent-app Container       │ │
│  │                                │ │
│  │  ┌──────────────────────────┐ │ │
│  │  │  Python 3.10             │ │ │
│  │  │  Flask App               │ │ │
│  │  │  Gunicorn                │ │ │
│  │  │  Port 5000 (internal)    │ │ │
│  │  └──────────────────────────┘ │ │
│  │                                │ │
│  │  Volumes:                      │ │
│  │  - ./logs → /app/logs          │ │
│  └────────────────────────────────┘ │
│             ↓ Port 80                │
│  ┌────────────────────────────────┐ │
│  │  Docker Network Bridge         │ │
│  └────────────────────────────────┘ │
└─────────────────────────────────────┘
              ↓
         Internet/Twilio
```

---

## ✅ Next Steps

1. **Install Docker Desktop**
2. **Create `.env` file** (if not exists)
3. **Run:** `docker-compose up -d`
4. **Test:** `curl http://localhost/health`
5. **Deploy to AWS** using same Docker setup

---

## 💡 Tips

- Use `docker-compose` for development
- Use `docker build` for CI/CD pipelines
- Keep `.env` file secure (never commit to git)
- Monitor container health with `docker ps`
- Use `docker-compose logs -f` to debug issues
- Rebuild after code changes: `docker-compose up -d --build`

---

**Your application is now containerized and production-ready!** 🎉
