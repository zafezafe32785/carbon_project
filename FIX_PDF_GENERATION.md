# Fix PDF Generation on Linux Server

## Problem
PDF generation fails on Linux because `pywin32` and `docx2pdf` only work on Windows.

## Solution
Added LibreOffice as Method 3 for Word-to-PDF conversion, which works on Linux servers.

## Files Changed
1. `backend/report_generator.py` - Added LibreOffice conversion method
2. `backend/Dockerfile` - Added LibreOffice installation

## Deployment Steps

### Step 1: Upload Changed Files to Server

From Windows PowerShell:
```powershell
cd d:\carbon_project

# Upload backend changes
scp backend/report_generator.py nc-user@103.29.190.75:~/backend/
scp backend/Dockerfile nc-user@103.29.190.75:~/backend/
```

### Step 2: Rebuild Backend Container

SSH into server:
```bash
ssh nc-user@103.29.190.75
cd ~

# Stop all containers
docker-compose down

# Rebuild backend container (this will install LibreOffice)
docker-compose build backend

# Start all containers
docker-compose up -d

# Check if containers are running
docker-compose ps
```

### Step 3: Verify LibreOffice is Installed

```bash
# Check if LibreOffice is available in the container
docker-compose exec backend libreoffice --version

# Should output something like: LibreOffice 7.x.x.x
```

### Step 4: Test PDF Generation

1. Go to your web app: http://103.29.190.75
2. Generate a report
3. Download it
4. Open the PDF to verify it's properly formatted

### Step 5: Check Logs (If Issues)

```bash
# View backend logs to see conversion process
docker-compose logs -f backend

# Look for these messages:
# - "Attempting conversion with docx2pdf..." (will fail on Linux)
# - "Attempting conversion with win32com..." (will fail on Linux)
# - "Attempting conversion with LibreOffice..." (should succeed)
# - "✓ Successfully converted Word to PDF using LibreOffice"
```

## How It Works

The code now tries 3 methods in order:

1. **docx2pdf** (Windows only) - Tries first, fails on Linux
2. **win32com** (Windows + MS Word) - Tries second, fails on Linux
3. **LibreOffice** (Cross-platform) - **NEW!** Works on Linux ✅

LibreOffice is installed in the Docker container and can convert .docx files to PDF using command-line interface.

## Troubleshooting

### Error: "LibreOffice not found on system"
```bash
# Rebuild the backend container
docker-compose down
docker-compose build --no-cache backend
docker-compose up -d
```

### Error: "LibreOffice conversion timed out"
The timeout is set to 60 seconds. For large reports, you may need to increase it in `report_generator.py` line 1706.

### PDF is blank or corrupted
Check backend logs:
```bash
docker-compose logs backend | tail -50
```

### Container won't start after rebuild
```bash
# Check for errors
docker-compose logs backend

# Check disk space
df -h

# Force remove old images
docker system prune -a
```

## Notes

- LibreOffice installation adds ~200MB to the Docker image
- First conversion might be slower as LibreOffice initializes
- Supports Thai fonts (already configured in Word document generation)
- Works for PDF, Word, and Excel report formats
