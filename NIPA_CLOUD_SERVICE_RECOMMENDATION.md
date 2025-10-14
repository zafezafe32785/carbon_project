# NIPA Cloud Service Recommendation for Your Application

## 🎯 Your Application Stack
- **Backend:** Flask (Python) API
- **Frontend:** Flutter Web
- **Database:** MongoDB
- **Files:** PDF reports, image uploads

---

## 📋 NIPA Cloud Services Available

Based on NIPA Cloud documentation, here are the available services:

### Compute Services:
- ✅ **Compute Instance** (Virtual Machines)
- ✅ **Kubernetes Cluster** (Container orchestration)

### Database Services:
- ⚠️ **SQL Database** (MySQL only - NOT MongoDB)

### Storage Services:
- ✅ **Block Storage** (NVMe - for VM storage)
- ✅ **Object Storage (S3)** (for files/uploads)

### Networking Services:
- ✅ **Load Balancer**
- ✅ **External IP**
- ✅ **Security Group** (firewall)
- ✅ **SSL Certificate**

---

## 🏆 RECOMMENDED SOLUTION: Compute Instance (VM) with Docker

### Why This Option?
- ✅ **Easiest to set up** - Most straightforward deployment
- ✅ **Full control** - Install any software you need (including MongoDB)
- ✅ **Cost-effective** - Pay only for what you use
- ✅ **Best for your stack** - NIPA doesn't offer MongoDB as a service

### What You'll Use:
| Service | Purpose | Cost |
|---------|---------|------|
| **Compute Instance** | Run your Flask + MongoDB + Frontend | ~฿500-2,000/month |
| **Block Storage** | Store database and files | ~฿100-500/month |
| **External IP** | Public internet access | ~฿100/month |
| **Security Group** | Firewall protection | Free |

**Total Estimated Cost:** ~฿700-2,600/month (depends on instance size)

---

## 📦 Deployment Architecture

```
┌─────────────────────────────────────────┐
│     NIPA Cloud Compute Instance         │
│                                         │
│  ┌─────────────┐  ┌──────────────┐    │
│  │   Nginx     │  │   Flask API   │    │
│  │ (Frontend)  │──│   (Backend)   │    │
│  └─────────────┘  └──────────────┘    │
│                          │              │
│                   ┌──────────────┐     │
│                   │   MongoDB    │     │
│                   └──────────────┘     │
│                                         │
└─────────────────────────────────────────┘
         │
         └─── External IP (Public Access)
```

---

## 🚀 Step-by-Step: What Services to Choose on NIPA Cloud

### Step 1: Create Compute Instance

**Go to:** NIPA Cloud Portal → Compute → Compute Instance → Create

**Recommended Configuration:**

#### For Small/Testing (Budget-friendly):
- **Instance Type:** General Purpose
- **CPU:** 2 vCPU
- **RAM:** 4 GB
- **OS:** Ubuntu 22.04 LTS
- **Storage:** 40 GB (Block Storage)
- **Cost:** ~฿700-1,000/month

#### For Production (Recommended):
- **Instance Type:** General Purpose
- **CPU:** 4 vCPU
- **RAM:** 8 GB
- **OS:** Ubuntu 22.04 LTS
- **Storage:** 80 GB (Block Storage)
- **Cost:** ~฿1,500-2,500/month

#### For High Traffic:
- **Instance Type:** Compute Optimized
- **CPU:** 8 vCPU
- **RAM:** 16 GB
- **OS:** Ubuntu 22.04 LTS
- **Storage:** 120 GB (Block Storage)
- **Cost:** ~฿3,000-5,000/month

---

### Step 2: Setup External IP

**Go to:** NIPA Cloud Portal → Network → External IP → Create

**What to do:**
1. Click "Allocate External IP"
2. Associate with your Compute Instance
3. Note the IP address (you'll use this to access your app)

**Cost:** ~฿100/month

---

### Step 3: Configure Security Group (Firewall)

**Go to:** NIPA Cloud Portal → Network → Security Group → Create

**Required Rules:**

| Type | Protocol | Port | Source | Purpose |
|------|----------|------|--------|---------|
| Inbound | TCP | 22 | Your IP | SSH access |
| Inbound | TCP | 80 | 0.0.0.0/0 | HTTP (web) |
| Inbound | TCP | 443 | 0.0.0.0/0 | HTTPS (secure web) |
| Outbound | All | All | 0.0.0.0/0 | Internet access |

---

### Step 4: (Optional) Setup Object Storage for Uploads

**Go to:** NIPA Cloud Portal → Storage → Object Storage

**Why?**
- Store PDF reports and uploads separately
- Better performance
- Easier backups

**Cost:** ~฿50-200/month (depends on usage)

---

### Step 5: (Optional) Setup Load Balancer

**Only needed if:**
- You expect high traffic (1000+ users)
- You want auto-scaling
- You need 99.9% uptime

**Cost:** ~฿500-1,000/month

---

## 💰 Pricing Estimate

### Minimum Setup (For Testing):
```
Compute Instance (2 vCPU, 4GB)    ฿700
External IP                        ฿100
Block Storage (40GB)               ฿80
─────────────────────────────────
TOTAL                             ~฿880/month
```

### Recommended Setup (Production):
```
Compute Instance (4 vCPU, 8GB)    ฿1,800
External IP                        ฿100
Block Storage (80GB)               ฿160
Object Storage (50GB)              ฿100
─────────────────────────────────
TOTAL                             ~฿2,160/month
```

**Note:** Check the [NIPA Cloud Pricing Calculator](https://nipa.cloud/pricing/calculator) for exact prices.

---

## 🎯 Quick Start Checklist

To deploy on NIPA Cloud, follow these steps in order:

- [ ] **1. Create NIPA Cloud Account**
  - Go to: https://portal.nipa.cloud/
  - Sign up with email
  - Verify your account

- [ ] **2. Add Payment Method**
  - Add credit card or top up credits
  - NIPA uses pay-as-you-go billing

- [ ] **3. Create Compute Instance**
  - Choose: Ubuntu 22.04 LTS
  - Size: 2-4 vCPU, 4-8 GB RAM
  - Storage: 40-80 GB

- [ ] **4. Create External IP**
  - Allocate new IP
  - Associate with your instance

- [ ] **5. Configure Security Group**
  - Open ports: 22, 80, 443
  - Apply to your instance

- [ ] **6. Connect to Instance**
  - SSH: `ssh ubuntu@YOUR_EXTERNAL_IP`
  - Or use NIPA Cloud web console

- [ ] **7. Install Docker on Instance**
  - Follow deployment guide
  - Upload your code
  - Run `docker-compose up -d`

- [ ] **8. Configure Domain (Optional)**
  - Point your domain to External IP
  - Setup SSL certificate

---

## 🔄 Alternative Options (If You Need Them)

### Option A: Kubernetes Cluster
**When to use:**
- You need auto-scaling
- You expect very high traffic
- You want container orchestration

**Cost:** Higher (~฿3,000+/month)
**Complexity:** Advanced setup required

### Option B: Multiple Compute Instances + Load Balancer
**When to use:**
- You need high availability
- You want to separate services (DB on one, API on another)

**Cost:** Medium-High (~฿2,500+/month)
**Complexity:** Moderate

---

## ⚠️ Important Notes

### MongoDB Limitation:
NIPA Cloud only offers **MySQL** database service, NOT MongoDB. You have two options:

1. **Install MongoDB yourself on Compute Instance** (Recommended ✅)
   - Full control
   - No extra cost
   - Included in your docker-compose setup

2. **Use external MongoDB service:**
   - MongoDB Atlas (https://www.mongodb.com/cloud/atlas)
   - Costs extra (~$9-57 USD/month)
   - Better for production

---

## 🎉 Summary: What You Should Do

### **Start with this simple setup:**

1. **Create:** Compute Instance (2 vCPU, 4 GB RAM, Ubuntu 22.04)
2. **Create:** External IP and associate it
3. **Configure:** Security Group (ports 22, 80, 443)
4. **Deploy:** Use docker-compose (from deployment guide)

**This gives you:**
- ✅ Flask API running
- ✅ MongoDB running
- ✅ Flutter frontend hosted
- ✅ Public access via External IP

**Total Cost:** ~฿700-1,000/month

### **When you're ready to scale:**
- Add Object Storage for files
- Add Load Balancer for traffic distribution
- Upgrade Compute Instance size

---

## 📚 Next Steps

1. Read: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Full deployment instructions
2. Visit: https://portal.nipa.cloud/ - Create your account
3. Check: https://nipa.cloud/pricing/calculator - Calculate exact costs
4. Follow: "Option B: Using Docker Compose on NIPA Cloud VM" section in deployment guide

---

## 🆘 Need Help?

- **NIPA Cloud Docs:** https://docs-epc.gitbook.io/ncs-documents/
- **NIPA Cloud Support:** support@nipa.cloud
- **Pricing Calculator:** https://nipa.cloud/pricing/calculator

Good luck! 🚀
