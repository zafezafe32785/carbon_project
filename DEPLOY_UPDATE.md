# Deploy Frontend Update to NIPA Cloud

## Server Information
- **Server IP**: 103.29.190.75
- **User**: nc-user

## Quick Update Steps

### Option 1: Update and Restart (Recommended)

```bash
# 1. SSH into your server
ssh nc-user@103.29.190.75

# 2. Navigate to your project directory
cd /path/to/carbon_project  # Update this with your actual path

# 3. Stop all containers
docker-compose down

# 4. Pull latest code (if using Git)
git pull origin main

# 5. Rebuild and start containers
docker-compose up -d --build

# 6. Verify containers are running
docker-compose ps

# 7. Check logs if needed
docker-compose logs -f nginx
```

### Option 2: Update Only Frontend (Faster)

If you only need to update the frontend without rebuilding everything:

```bash
# 1. SSH into your server
ssh nc-user@103.29.190.75

# 2. Navigate to your project directory
cd /path/to/carbon_project

# 3. Stop only nginx container
docker-compose stop nginx

# 4. Update frontend files (if using Git)
git pull origin main

# 5. Rebuild Flutter web (if needed on server)
cd frontend
flutter build web --release
cd ..

# 6. Restart nginx container
docker-compose start nginx

# 7. Check nginx status
docker-compose ps nginx
```

### Option 3: Manual File Transfer (If not using Git)

If you're uploading files manually from Windows:

```bash
# From your Windows machine (PowerShell or Command Prompt)
# Navigate to your project directory
cd d:\carbon_project

# Use SCP to copy the updated frontend build to server
scp -r frontend/build/web/* nc-user@103.29.190.75:/path/to/carbon_project/frontend/build/web/

# Then SSH and restart nginx
ssh nc-user@103.29.190.75
cd /path/to/carbon_project
docker-compose restart nginx
```

## Detailed Step-by-Step Guide

### Step 1: Connect to Server

```bash
ssh nc-user@103.29.190.75
```

### Step 2: Locate Your Project

Your project should be in a directory on the server. Common locations:
- `/home/nc-user/carbon_project`
- `/opt/carbon_project`
- `~/carbon_project`

```bash
# Find your project
cd /home/nc-user/carbon_project  # Adjust path as needed
```

### Step 3: Backup Current Deployment (Recommended)

```bash
# Create a backup of current frontend
cp -r frontend/build/web frontend/build/web.backup.$(date +%Y%m%d_%H%M%S)
```

### Step 4: Stop Docker Containers

```bash
# Stop all containers gracefully
docker-compose down

# This will:
# - Stop: nginx, backend, mongodb
# - Preserve: volumes (database data, uploads, reports)
```

### Step 5: Update Files

**Option A: Using Git (Recommended)**
```bash
# Pull latest changes
git pull origin main

# Or if you need to force update
git fetch origin
git reset --hard origin/main
```

**Option B: Manual Upload from Windows**

From your Windows machine, upload the new build:

```powershell
# Using SCP (from Windows PowerShell)
cd d:\carbon_project
scp -r frontend\build\web\* nc-user@103.29.190.75:/home/nc-user/carbon_project/frontend/build/web/

# Or using WinSCP GUI tool
# Connect to: 103.29.190.75
# Upload: d:\carbon_project\frontend\build\web\
# To: /home/nc-user/carbon_project/frontend/build/web/
```

### Step 6: Start Docker Containers

```bash
# Start all containers in detached mode
docker-compose up -d

# Or rebuild and start (if Dockerfile changed)
docker-compose up -d --build
```

### Step 7: Verify Deployment

```bash
# Check if all containers are running
docker-compose ps

# Expected output:
# NAME              STATUS    PORTS
# carbon_nginx      Up        0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
# carbon_backend    Up        0.0.0.0:5000->5000/tcp
# carbon_mongodb    Up        0.0.0.0:27017->27017/tcp

# Check nginx logs
docker-compose logs nginx

# Check backend logs
docker-compose logs backend

# Follow logs in real-time (Ctrl+C to exit)
docker-compose logs -f
```

### Step 8: Test the Application

```bash
# From server, test if app is responding
curl http://localhost

# From your browser, visit:
http://103.29.190.75
```

## Common Issues and Troubleshooting

### Issue 1: Containers Won't Start

```bash
# Check for port conflicts
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :5000

# Check Docker logs
docker-compose logs

# Restart Docker service (if needed)
sudo systemctl restart docker
```

### Issue 2: Frontend Not Updating

```bash
# Clear browser cache or use incognito mode
# Force rebuild nginx container
docker-compose stop nginx
docker-compose rm -f nginx
docker-compose up -d nginx
```

### Issue 3: Permission Issues

```bash
# Fix permissions
sudo chown -R nc-user:nc-user /home/nc-user/carbon_project
chmod -R 755 /home/nc-user/carbon_project/frontend/build/web
```

### Issue 4: MongoDB Connection Issues

```bash
# Check MongoDB is running
docker-compose ps mongodb

# Restart MongoDB if needed
docker-compose restart mongodb

# Check backend can connect
docker-compose logs backend | grep -i mongo
```

## Quick Commands Reference

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Restart a specific service
docker-compose restart nginx
docker-compose restart backend

# View logs
docker-compose logs -f nginx          # Follow nginx logs
docker-compose logs -f backend        # Follow backend logs
docker-compose logs --tail=100 nginx  # Last 100 lines

# Rebuild and restart
docker-compose up -d --build

# Remove all containers and volumes (DANGER: Deletes data!)
docker-compose down -v  # Don't use unless you want to reset everything

# Check container status
docker-compose ps

# Execute command in container
docker-compose exec backend bash      # Access backend shell
docker-compose exec nginx sh          # Access nginx shell

# View container resource usage
docker stats
```

## Environment Variables

Make sure your `.env` file on the server contains:

```bash
MONGO_USERNAME=admin
MONGO_PASSWORD=your_secure_password
SECRET_KEY=your_secret_key
```

## Post-Deployment Checklist

- [ ] All containers are running (`docker-compose ps`)
- [ ] Website loads at http://103.29.190.75
- [ ] Login functionality works
- [ ] Report download feature works (the fix we just implemented)
- [ ] API calls are successful
- [ ] No errors in logs (`docker-compose logs`)

## Automatic Updates (Optional)

To set up automatic deployment, you can create a simple script:

```bash
# Create update script
nano /home/nc-user/update_frontend.sh

# Add this content:
#!/bin/bash
cd /home/nc-user/carbon_project
git pull origin main
docker-compose restart nginx
echo "Frontend updated at $(date)"

# Make it executable
chmod +x /home/nc-user/update_frontend.sh

# Run it
./update_frontend.sh
```

## Notes

1. The current build in `d:\carbon_project\frontend\build\web` already contains the fix for the download issue
2. You need to transfer these files to your server
3. The nginx container will serve these static files automatically
4. No backend restart is needed for frontend changes

## Support

If you encounter issues:
1. Check logs: `docker-compose logs`
2. Verify files exist: `ls -la frontend/build/web`
3. Check nginx config: `docker-compose exec nginx cat /etc/nginx/nginx.conf`
4. Test backend: `curl http://localhost:5000/api/health` (if you have a health endpoint)
