#!/bin/bash

# KidsDen Backend Deployment Script for EC2
# This script sets up and deploys the KidsDen backend services on an EC2 instance

set -e

echo "🚀 KidsDen Backend Deployment Script"
echo "==================================="

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Docker on Amazon Linux 2
install_docker() {
    echo "📦 Installing Docker..."
    sudo yum update -y
    sudo yum install -y docker git
    sudo service docker start
    sudo usermod -a -G docker $USER
    sudo chkconfig docker on
    echo "✅ Docker installed successfully"
}

# Function to install Docker Compose
install_docker_compose() {
    echo "📦 Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed successfully"
}

# Check and install dependencies
echo "🔍 Checking dependencies..."

if ! command_exists docker; then
    install_docker
    echo "⚠️  Please log out and back in, then run this script again to refresh Docker permissions"
    exit 0
else
    echo "✅ Docker is already installed"
fi

if ! command_exists docker-compose; then
    install_docker_compose
else
    echo "✅ Docker Compose is already installed"
fi

if ! command_exists git; then
    echo "📦 Installing Git..."
    sudo yum install -y git
    echo "✅ Git installed successfully"
else
    echo "✅ Git is already installed"
fi

# Environment setup
echo ""
echo "🔧 Environment Configuration"
echo "==========================="

# Check if environment variables are set
if [ -z "$JWT_SECRET" ]; then
    echo "⚠️  JWT_SECRET not set. Using default (change in production!)"
    export JWT_SECRET="change-this-super-secure-jwt-secret-in-production"
fi

if [ -z "$RAZORPAY_KEY_ID" ]; then
    echo "⚠️  RAZORPAY_KEY_ID not set. Payment functionality will not work."
    export RAZORPAY_KEY_ID="your_razorpay_key_id"
fi

if [ -z "$RAZORPAY_KEY_SECRET" ]; then
    echo "⚠️  RAZORPAY_KEY_SECRET not set. Payment functionality will not work."
    export RAZORPAY_KEY_SECRET="your_razorpay_key_secret"
fi

# Set production environment
export NODE_ENV="production"
export ENVIRONMENT="ec2"

echo "Environment variables configured:"
echo "  NODE_ENV: $NODE_ENV"
echo "  ENVIRONMENT: $ENVIRONMENT"
echo "  JWT_SECRET: ${JWT_SECRET:0:10}... (truncated)"

# Application deployment
echo ""
echo "🚢 Deploying Application"
echo "======================"

# Create application directory
APP_DIR="/home/$(whoami)/kidsden-backend"

if [ -d "$APP_DIR" ]; then
    echo "📂 Updating existing deployment..."
    cd "$APP_DIR"
    git pull origin main || {
        echo "❌ Git pull failed. Please check repository access."
        exit 1
    }
else
    echo "📂 Cloning repository..."
    git clone https://github.com/deanurag/kidsden-backend.git "$APP_DIR" || {
        echo "❌ Git clone failed. Please check repository URL and access."
        echo "💡 If repository is private, set up SSH keys or use HTTPS with token"
        exit 1
    }
    cd "$APP_DIR"
fi

# Create logs directory
mkdir -p logs

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose down 2>/dev/null || true

# Remove old images to ensure fresh deployment
echo "🧹 Cleaning up old images..."
docker system prune -f

# Check available memory
MEMORY_GB=$(free -g | awk 'NR==2{printf "%.0f", $2}')
echo "💾 Available memory: ${MEMORY_GB}GB"

# Choose appropriate compose file based on available resources
if [ "$MEMORY_GB" -lt 2 ]; then
    echo "⚠️  Limited memory detected. Using minimal configuration (without Kafka)..."
    COMPOSE_FILE="docker-compose.ec2-minimal.yml"
else
    echo "✅ Sufficient memory available. Using full configuration..."
    COMPOSE_FILE="docker-compose.yml"
fi

# Build and start services
echo "🏗️  Building application..."
docker-compose -f "$COMPOSE_FILE" build app

echo "🚀 Starting services..."
docker-compose -f "$COMPOSE_FILE" up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Health check
echo ""
echo "🔍 Health Check"
echo "============="

check_service() {
    local service_name=$1
    local url=$2
    local max_attempts=10
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$url" >/dev/null 2>&1; then
            echo "✅ $service_name is healthy"
            return 0
        fi
        
        echo "⏳ Attempt $attempt/$max_attempts: $service_name not ready..."
        sleep 3
        attempt=$((attempt + 1))
    done
    
    echo "❌ $service_name health check failed"
    return 1
}

# Check services
check_service "Backend API" "http://localhost:3000/health"
check_service "Chat Backend" "http://localhost:8000/health"

# Display status
echo ""
echo "📊 Deployment Status"
echo "=================="
docker-compose -f "$COMPOSE_FILE" ps

echo ""
echo "📋 Service Information"
echo "===================="
echo "🌐 Backend API:      http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
echo "💬 Chat Backend:     http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000"
echo "🔍 Health Check API: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000/health"
echo "🔍 Health Check Chat:http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000/health"

echo ""
echo "📝 Next Steps"
echo "============"
echo "1. Configure your security groups to allow traffic on ports 3000 and 8000"
echo "2. Set up SSL/TLS certificates for production (recommended)"
echo "3. Configure DNS to point to your EC2 public IP"
echo "4. Set proper environment variables for production:"
echo "   export JWT_SECRET=\"your-actual-jwt-secret\""
echo "   export RAZORPAY_KEY_ID=\"your-actual-key\""
echo "   export RAZORPAY_KEY_SECRET=\"your-actual-secret\""
echo "5. Monitor logs: docker-compose logs -f app"

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📚 Useful Commands:"
echo "  View logs:           docker-compose -f $COMPOSE_FILE logs -f app"
echo "  Check status:        docker-compose -f $COMPOSE_FILE ps"
echo "  Restart services:    docker-compose -f $COMPOSE_FILE restart app"
echo "  Update deployment:   git pull && docker-compose -f $COMPOSE_FILE build app && docker-compose -f $COMPOSE_FILE up -d"
echo "  Stop services:       docker-compose -f $COMPOSE_FILE down"
echo ""
echo "🔧 Troubleshooting:"
echo "  Check app logs:      docker logs kidsden-app"
echo "  Enter container:     docker exec -it kidsden-app sh"
echo "  Check processes:     docker exec -it kidsden-app supervisorctl status"