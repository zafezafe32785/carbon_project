# Environment Variables Setup Guide

This guide explains what each value in your `.env` file means and how to set it up.

---

## 📋 Current Setup (Local Development)

Your current [backend/.env](backend/.env) is configured for **local development** (running on your Windows machine). Here's what each value means:

### 1. **SECRET_KEY** (Already Set ✅)
```env
SECRET_KEY=your-super-secret-key-change-this-in-production-12345
```

**What is it?**
- A random string used by Flask to encrypt sessions and cookies
- Keeps your user sessions secure

**Current Status:** ✅ You already have one set!

**For Production:** Change it to a random string. Generate one with:
```bash
# On Windows PowerShell:
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})

# Or use this online generator:
# https://randomkeygen.com/
```

---

### 2. **MONGO_URI** (Already Set ✅)
```env
MONGO_URI=mongodb://localhost:27017/carbon_accounting
```

**What is it?**
- Connection string to your MongoDB database
- Currently pointing to `localhost` (your local machine)

**Current Status:** ✅ Works for local development!

**When to change:**
- **Docker Deployment:** Use `mongodb://admin:changeme123@mongodb:27017/carbon_accounting?authSource=admin`
- **NIPA Cloud:** Use the connection string provided by NIPA Cloud's MongoDB service

---

### 3. **MONGO_USERNAME & MONGO_PASSWORD** (New)
```env
MONGO_USERNAME=admin
MONGO_PASSWORD=changeme123
```

**What is it?**
- Username and password for MongoDB (used in Docker deployment)

**Current Status:** Set to defaults

**What to do:**
- **Local Development:** Not needed (your local MongoDB probably has no password)
- **Docker/NIPA Cloud:** Change `changeme123` to a strong password like `MySecure@Pass2024!`

---

### 4. **OPENAI_API_KEY** (Optional)
```env
OPENAI_API_KEY=your-openai-api-key-here
```

**What is it?**
- API key for OpenAI (if your app uses AI features for report generation)

**How to get it:**
1. Go to https://platform.openai.com/
2. Sign up / Log in
3. Go to "API Keys" section
4. Click "Create new secret key"
5. Copy the key (looks like: `sk-proj-xxxxxxxxxxxxx`)
6. Paste it here

**Current Status:**
- ⚠️ **If your app uses AI features:** You need to get this key
- ✅ **If you don't use AI features:** Leave it as is (it won't be used)

---

### 5. **Other Values**
```env
FLASK_ENV=development
UPLOAD_FOLDER=uploads
MAX_CONTENT_LENGTH=16777216
TESSERACT_CMD=/usr/bin/tesseract
```

**What they do:**
- `FLASK_ENV`: `development` for testing, `production` for deployment
- `UPLOAD_FOLDER`: Where uploaded files are stored
- `MAX_CONTENT_LENGTH`: Maximum file upload size (16MB)
- `TESSERACT_CMD`: Path to Tesseract OCR program (for PDF text extraction)

**Current Status:** ✅ All good! No changes needed.

---

## 🚀 Quick Setup for Different Scenarios

### Scenario 1: Local Development (Current Setup)
**What you have now is perfect!** Just make sure MongoDB is running locally:
```bash
# Check if MongoDB is running
# If not, start it or install it
```

### Scenario 2: Testing with Docker Compose
Update your `.env`:
```env
MONGO_URI=mongodb://admin:changeme123@mongodb:27017/carbon_accounting?authSource=admin
FLASK_ENV=production
```

Then run:
```bash
docker-compose up -d
```

### Scenario 3: Deploying to NIPA Cloud
1. Create a MongoDB instance in NIPA Cloud
2. NIPA Cloud will give you a connection string like:
   ```
   mongodb://user:pass@nipa-mongodb.cloud:27017/mydb
   ```
3. Update your `.env`:
   ```env
   MONGO_URI=<the-connection-string-from-nipa-cloud>
   SECRET_KEY=<generate-a-new-random-key>
   FLASK_ENV=production
   ```

---

## ⚠️ Security Warnings

### DO NOT:
- ❌ Commit `.env` file to Git (it's already in `.gitignore`)
- ❌ Share your `.env` file with anyone
- ❌ Use default passwords in production
- ❌ Put `.env` file in public folders

### DO:
- ✅ Keep `.env` file private
- ✅ Use strong passwords for production
- ✅ Change `SECRET_KEY` before deploying
- ✅ Keep a backup of your production `.env` file securely

---

## 🔍 How to Check if Your Current Setup Works

Run this test:
```bash
cd backend
python app.py
```

If you see:
- ✅ `* Running on http://127.0.0.1:5000` → Your setup works!
- ❌ `MongoClient could not connect` → MongoDB is not running or wrong connection string
- ❌ `OPENAI_API_KEY not found` → Add the OpenAI key (if you use AI features)

---

## 📝 Summary

**For now (local development):**
- ✅ Your current `.env` is fine!
- ✅ No changes needed
- ✅ Just make sure MongoDB is installed and running locally

**Before deploying to NIPA Cloud:**
- 📝 Get MongoDB connection string from NIPA Cloud
- 📝 Generate a new strong SECRET_KEY
- 📝 Change MONGO_PASSWORD to something secure
- 📝 Get OPENAI_API_KEY (if using AI features)

**Need help?**
- Check if MongoDB is running: Open MongoDB Compass or run `mongosh` in terminal
- Test your backend: `cd backend && python app.py`
- See deployment guide: Open [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

---

## 🎯 TL;DR (Too Long; Didn't Read)

**Your current setup is already configured for local development! You don't need to change anything right now.**

Only update these values when:
1. **Deploying to NIPA Cloud** → Get MongoDB connection from NIPA Cloud
2. **Using Docker** → Uncomment the Docker MongoDB URI line
3. **Using AI features** → Get OpenAI API key from platform.openai.com

That's it! 🎉
