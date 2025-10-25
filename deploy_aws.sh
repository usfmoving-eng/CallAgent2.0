#!/bin/bash

# AWS Deployment Update Script
# Run this on your AWS EC2 instance after pushing code changes

echo "🚀 Updating Callagent on AWS..."

# Navigate to project directory
cd ~/Callagent || exit 1

echo "📥 Pulling latest code from GitHub..."
git pull origin main

echo "🛑 Stopping current containers..."
sudo docker-compose down

echo "🔨 Rebuilding Docker image (no cache)..."
sudo docker-compose build --no-cache

echo "▶️  Starting containers..."
sudo docker-compose up -d

echo "⏳ Waiting for container to start..."
sleep 5

echo "✅ Checking container status..."
sudo docker ps -a | grep callagent-app

echo "📋 Showing recent logs..."
sudo docker logs callagent-app --tail 50

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "📊 To monitor logs in real-time:"
echo "   sudo docker logs callagent-app -f"
echo ""
echo "🏥 Health check:"
echo "   curl http://18.222.171.238/health"
echo ""
