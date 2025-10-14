# NIPA Cloud Deployment Guide

## Overview
This guide will help you deploy your Carbon Accounting Platform (Flask Backend + Flutter Frontend) to NIPA Cloud.

## Prerequisites
- NIPA Cloud account ([Sign up here](https://nipa.cloud/))
- Docker and Docker Compose installed locally (for testing)
- Git repository (optional but recommended)

## Architecture
- **Backend:** Flask API (Python 3.11)
- **Frontend:** Flutter Web
- **Database:** MongoDB
- **Reverse Proxy:** Nginx

---

## Step 1: Prepare Your Application

### Changes Made for Cloud Deployment:
1. ✅ Removed Windows-specific dependencies (`pywin32`, `docx2pdf`)
2. ✅ Changed `opencv-python` to `opencv-python-headless` (for Linux servers)
3. ✅ Added `gunicorn` for production WSGI server
4. ✅ Created Docker configuration files

### Files Created:
- `backend/Dockerfile` - Backend container configuration
- `docker-compose.yml` - Multi-container orchestration
- `nginx.conf` - Reverse proxy configuration
- `.env.example` - Environment variables template

---

## Step 2: Test Locally (Optional but Recommended)

### 2.1 Create Environment File
```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your configuration
# Change passwords and secret keys!
```

### 2.2 Build Flutter Web App
```bash
cd frontend
flutter build web
cd ..
```

### 2.3 Test with Docker Compose
```bash
# Build and start all services
docker-compose up -d

# Check logs
docker-compose logs -f

# Test the application
# Backend API: http://localhost:5000
# Frontend: http://localhost:80
```

### 2.4 Stop Services
```bash
docker-compose down
```

---

## Step 3: Deploy to NIPA Cloud

### Option A: Using NIPA Cloud Portal (Recommended)

#### 3.1 Access NIPA Cloud Console
1. Go to [https://portal.nipa.cloud/](https://portal.nipa.cloud/)
2. Login with your credentials
3. Navigate to "Container Registry" or "Kubernetes Service"

#### 3.2 Build and Push Docker Images

**a) Tag your images:**
```bash
# Build backend image
docker build -t nipa.registry.io/YOUR_USERNAME/carbon-backend:latest ./backend

# Tag your image (if needed)
docker tag carbon-backend:latest nipa.registry.io/YOUR_USERNAME/carbon-backend:latest
```

**b) Login to NIPA Container Registry:**
```bash
docker login nipa.registry.io
# Enter your NIPA Cloud credentials
```

**c) Push images:**
```bash
docker push nipa.registry.io/YOUR_USERNAME/carbon-backend:latest
```

#### 3.3 Deploy MongoDB
1. In NIPA Cloud Portal, go to "Database as a Service (DBaaS)"
2. Create a new MongoDB instance
3. Note the connection string provided

#### 3.4 Deploy Backend Service
1. Go to "Container Service" or "Kubernetes"
2. Click "Create New Service"
3. Configure:
   - **Image:** `nipa.registry.io/YOUR_USERNAME/carbon-backend:latest`
   - **Port:** 5000
   - **Environment Variables:**
     ```
     MONGO_URI=<your-mongodb-connection-string>
     SECRET_KEY=<your-secret-key>
     FLASK_ENV=production
     ```
   - **Volumes:**
     - `/app/uploads` (for file uploads)
     - `/app/reports` (for generated reports)
4. Click "Deploy"

#### 3.5 Deploy Frontend
1. Build Flutter web app:
   ```bash
   cd frontend
   flutter build web
   ```
2. Upload `build/web/` contents to:
   - **NIPA Object Storage (S3)**, OR
   - **Static web hosting service**, OR
   - **Deploy as Nginx container** with Flutter web files

#### 3.6 Configure Load Balancer
1. Go to "Load Balancer as a Service (LBaaS)"
2. Create new load balancer
3. Configure:
   - **Backend:** Point to your Flask backend service (port 5000)
   - **Frontend:** Point to your Nginx/static hosting
4. Get the public IP/domain

---

### Option B: Using Docker Compose on NIPA Cloud VM

#### 3.1 Create a Virtual Machine
1. Go to NIPA Cloud Portal → "Compute" → "Instances"
2. Create new instance:
   - **OS:** Ubuntu 22.04 LTS
   - **CPU/RAM:** At least 2 vCPU, 4GB RAM
   - **Storage:** At least 20GB
3. Note the public IP address

#### 3.2 Connect to VM
```bash
ssh ubuntu@YOUR_VM_IP
```

#### 3.3 Install Docker and Docker Compose
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo apt install docker-compose -y
```

#### 3.4 Deploy Your Application
```bash
# Clone your repository (or upload files)
git clone YOUR_REPO_URL
cd YOUR_PROJECT

# Create .env file
nano .env
# Add your configuration

# Build Flutter web
cd frontend
flutter build web  # If Flutter is installed, otherwise build locally and upload
cd ..

# Start services
docker-compose up -d

# Check status
docker-compose ps
docker-compose logs -f
```

#### 3.5 Configure Firewall
In NIPA Cloud Portal:
1. Go to "Security Groups"
2. Open ports:
   - **80** (HTTP)
   - **443** (HTTPS)
   - **22** (SSH)

---

## Step 4: Configure Domain (Optional)

### 4.1 Add DNS Records
Point your domain to NIPA Cloud IP:
```
A Record: @ → YOUR_NIPA_CLOUD_IP
A Record: www → YOUR_NIPA_CLOUD_IP
```

### 4.2 Configure SSL/TLS (HTTPS)
```bash
# SSH into your VM
ssh ubuntu@YOUR_VM_IP

# Install Certbot
sudo apt install certbot python3-certbot-nginx -y

# Get SSL certificate
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

---

## Step 5: Monitoring and Maintenance

### Check Application Logs
```bash
# Backend logs
docker-compose logs -f backend

# MongoDB logs
docker-compose logs -f mongodb

# All logs
docker-compose logs -f
```

### Update Application
```bash
# Pull latest changes
git pull

# Rebuild and restart
docker-compose down
docker-compose up -d --build
```

### Backup Database
```bash
# Create backup
docker exec carbon_mongodb mongodump --out /data/backup

# Copy backup from container
docker cp carbon_mongodb:/data/backup ./mongodb-backup-$(date +%Y%m%d)
```

---

## Important Notes

### Security Checklist:
- ✅ Change default passwords in `.env`
- ✅ Use strong SECRET_KEY
- ✅ Enable HTTPS/SSL
- ✅ Configure firewall rules
- ✅ Regular security updates
- ✅ Setup database backups

### Performance Tips:
- Use NIPA Cloud's Load Balancer for scaling
- Enable Auto Scaling for high traffic
- Use Object Storage (S3) for uploaded files
- Consider CDN for static assets

### Cost Optimization:
- Start with smaller instance and scale as needed
- Use NIPA Cloud's pay-as-you-go pricing
- Monitor resource usage regularly
- Stop unused instances

---

## Troubleshooting

### Container won't start
```bash
docker-compose logs backend
```

### Database connection issues
- Check `MONGO_URI` in `.env`
- Verify MongoDB container is running: `docker-compose ps`
- Test connection: `docker exec -it carbon_mongodb mongosh`

### File upload issues
- Check volume permissions: `docker exec -it carbon_backend ls -la /app/uploads`
- Increase `client_max_body_size` in nginx.conf

### Port already in use
```bash
# Check what's using the port
sudo lsof -i :5000
sudo lsof -i :80

# Stop the service or change ports in docker-compose.yml
```

---

## Support Resources

- **NIPA Cloud Documentation:** https://docs-epc.gitbook.io/ncs-documents/
- **NIPA Cloud GitHub:** https://github.com/nipa-cloud
- **NIPA Cloud Support:** support@nipa.cloud
- **Community Forum:** Check NIPA Cloud website for community links

---

## Quick Reference

### Useful Commands
```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Restart specific service
docker-compose restart backend

# View logs
docker-compose logs -f

# Execute command in container
docker exec -it carbon_backend bash

# Check disk space
df -h

# Check memory usage
free -h

# Check running containers
docker ps
```

### Environment Variables
| Variable | Description | Example |
|----------|-------------|---------|
| `MONGO_URI` | MongoDB connection string | `mongodb://admin:pass@mongodb:27017/carbon_accounting` |
| `SECRET_KEY` | Flask secret key for sessions | Random string (use `openssl rand -hex 32`) |
| `FLASK_ENV` | Flask environment | `production` |
| `OPENAI_API_KEY` | OpenAI API key (if using) | `sk-...` |

---

## Next Steps

1. ✅ Test application locally
2. ✅ Create NIPA Cloud account
3. ✅ Deploy to NIPA Cloud
4. ✅ Configure domain and SSL
5. ✅ Setup monitoring
6. ✅ Configure automated backups
7. ✅ Load test your application

Good luck with your deployment! 🚀
