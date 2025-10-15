#!/bin/bash

# =============================================================================
# Carbon Project - Deploy Frontend to NIPA Cloud
# =============================================================================

# Configuration
SERVER="103.29.190.75"
USER="nc-user"
REMOTE_PATH="/home/nc-user/carbon_project"  # UPDATE THIS PATH!

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}Carbon Project - Deploy Frontend${NC}"
echo -e "${BLUE}=================================${NC}"
echo ""

# Check if frontend build exists
if [ ! -d "frontend/build/web" ]; then
    echo -e "${RED}Error: frontend/build/web directory not found!${NC}"
    echo -e "${YELLOW}Please run 'flutter build web' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Frontend build found${NC}"
echo ""

# Upload frontend files
echo -e "${BLUE}Step 1: Uploading frontend files to server...${NC}"
scp -r frontend/build/web/* ${USER}@${SERVER}:${REMOTE_PATH}/frontend/build/web/

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Files uploaded successfully${NC}"
else
    echo -e "${RED}✗ Upload failed${NC}"
    exit 1
fi
echo ""

# Restart nginx container on server
echo -e "${BLUE}Step 2: Restarting nginx container...${NC}"
ssh ${USER}@${SERVER} "cd ${REMOTE_PATH} && docker-compose restart nginx"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Nginx restarted successfully${NC}"
else
    echo -e "${RED}✗ Restart failed${NC}"
    exit 1
fi
echo ""

# Check container status
echo -e "${BLUE}Step 3: Checking container status...${NC}"
ssh ${USER}@${SERVER} "cd ${REMOTE_PATH} && docker-compose ps"
echo ""

echo -e "${GREEN}=================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}=================================${NC}"
echo ""
echo -e "Visit: ${BLUE}http://${SERVER}${NC}"
echo ""
