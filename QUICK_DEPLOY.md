# Quick Deploy Guide - Update Frontend Fix

## What Was Fixed?
Fixed the "**Unsupported operation: Platform_operatingSystem**" error when downloading reports from your web application.

## Deploy in 3 Simple Steps

### Step 1: Connect to Your Server

```bash
ssh nc-user@103.29.190.75
```

### Step 2: Navigate to Project & Update

```bash
# Navigate to your project directory (update path if different)
cd /home/nc-user/carbon_project

# OR if in different location:
# cd /opt/carbon_project
# cd ~/carbon_project

# Stop containers
docker-compose down

# If using Git, pull latest changes:
git pull origin main

# If NOT using Git, exit SSH and upload files manually (see below)
```

### Step 3: Restart Containers

```bash
# Start containers
docker-compose up -d

# Check status
docker-compose ps

# All services should show "Up" status
```

---

## Alternative: Manual File Upload (If Not Using Git)

If you need to upload the fixed files manually from Windows:

### 1. Using SCP Command (Windows PowerShell/CMD)

```powershell
# From Windows, navigate to your project
cd d:\carbon_project

# Upload frontend build files
scp -r frontend\build\web\* nc-user@103.29.190.75:/home/nc-user/carbon_project/frontend/build/web/
```

### 2. Then SSH and Restart

```bash
ssh nc-user@103.29.190.75
cd /home/nc-user/carbon_project
docker-compose restart nginx
```

### 3. Using the Provided Script

**Windows Users:**
```batch
# Edit deploy_to_server.bat first to set correct REMOTE_PATH
# Then double-click or run:
deploy_to_server.bat
```

**Linux/Mac Users:**
```bash
# Edit deploy_to_server.sh first to set correct REMOTE_PATH
chmod +x deploy_to_server.sh
./deploy_to_server.sh
```

---

## Verify Deployment

1. Open browser and go to: `http://103.29.190.75`
2. Login to your account
3. Go to Report Generation
4. Generate a report
5. Click Download - Should now work without error!

---

## Common Issues

### Cannot Connect to Server
```bash
# Make sure SSH key is configured or use password
ssh -v nc-user@103.29.190.75
```

### Don't Know Project Path
```bash
# After SSH, find it:
find / -name "docker-compose.yml" 2>/dev/null | grep carbon
# OR
ls -la ~
cd ~/carbon_project
```

### Containers Not Starting
```bash
# Check logs
docker-compose logs

# Check if ports are in use
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :5000
```

### Permission Denied
```bash
# Fix permissions
sudo chown -R nc-user:nc-user /home/nc-user/carbon_project
```

---

## Before You Start - Important!

⚠️ **UPDATE THE REMOTE PATH** in deployment scripts if your project is not in `/home/nc-user/carbon_project`

To find your project path:
```bash
ssh nc-user@103.29.190.75
pwd
ls -la
# Navigate until you find the folder with docker-compose.yml
```

---

## Need Help?

Check the detailed guide: [DEPLOY_UPDATE.md](DEPLOY_UPDATE.md)
