# 🚀 Secure Cloud Run with Identity-Aware Proxy (IAP)

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform)](https://www.terraform.io/)
[![Google Cloud](https://img.shields.io/badge/Google%20Cloud-Platform-4285F4?logo=google-cloud)](https://cloud.google.com/)
[![IAP](https://img.shields.io/badge/Security-IAP%20Protected-green)](https://cloud.google.com/iap)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> Production-ready, identity-aware Cloud Run deployment with Google IAP for zero-trust access control. No VPN required.

## 📋 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Configuration](#-configuration)
- [IAP Setup](#-iap-setup)
- [Access Control](#-access-control)
- [Security](#-security)
- [Deployment](#-deployment)
- [Monitoring](#-monitoring)
- [Troubleshooting](#-troubleshooting)
- [Cost Estimation](#-cost-estimation)
- [Production Checklist](#-production-checklist)
- [Contributing](#-contributing)

## 🎯 Overview

This infrastructure deploys a secure, serverless application on Google Cloud Run protected by **Identity-Aware Proxy (IAP)**, providing:

- **Zero-trust security**: Authenticate users before reaching your application
- **No VPN required**: Access control via Google Workspace/Cloud Identity
- **HTTPS-only access**: Managed SSL certificates with automatic renewal
- **Serverless auto-scaling**: 2-5 instances based on demand
- **Enterprise-ready**: Production-grade security and compliance

### Use Cases

- Internal corporate applications
- Admin dashboards
- Employee-only services
- Partner portals
- Development/staging environments
- Compliance-sensitive applications (SOC2, PCI-DSS)

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        User Access Flow                          │
└─────────────────────────────────────────────────────────────────┘

    User (Authenticated Google Account)
            │
            ▼
    ┌───────────────┐
    │   DNS Record  │ ──── yourdomain.com
    │  (A Record)   │      Points to Global IP
    └───────┬───────┘
            │
            ▼
    ┌───────────────────┐
    │  Global Load      │ ──── HTTPS (443)
    │  Balancer         │      SSL Termination
    └───────┬───────────┘
            │
            ▼
    ┌───────────────────────────────────────┐
    │   Identity-Aware Proxy (IAP)          │
    │   ✓ Google OAuth 2.0                  │
    │   ✓ User Authentication               │
    │   ✓ Access Control Lists              │
    │   ✓ Audit Logging                     │
    └───────┬───────────────────────────────┘
            │
            ▼ (Only authenticated users pass)
    ┌───────────────────┐
    │  Backend Service  │
    │  (HTTPS)          │
    └───────┬───────────┘
            │
            ▼
    ┌───────────────────┐
    │  Cloud Run NEG    │ ──── Serverless Network Endpoint Group
    └───────┬───────────┘
            │
            ▼
    ┌───────────────────────────────┐
    │   Cloud Run Service           │
    │   • Auto-scaling (2-5 inst)   │
    │   • Internal ingress only     │
    │   • Port 8080                 │
    │   • Artifact Registry image   │
    └───────────────────────────────┘
```

## ✨ Features

### 🔐 Security First

- **IAP Authentication**: Google OAuth 2.0 integration
- **Zero-trust access**: No direct public internet access to Cloud Run
- **Managed SSL/TLS**: Automatic certificate provisioning and renewal
- **Internal ingress**: Cloud Run only accessible via load balancer
- **Audit logging**: Complete audit trail of all access attempts
- **Least-privilege IAM**: Dedicated service accounts with minimal permissions

### 🚀 Cloud-Native Benefits

- **Serverless architecture**: No server management
- **Auto-scaling**: 2-5 instances based on traffic
- **Global load balancing**: Low-latency worldwide
- **Zero-downtime deploys**: Blue/green deployment support
- **Pay-per-use**: Only charged for active request time

### 🛠 Developer Experience

- **Automated builds**: Cloud Build integration with Artifact Registry
- **Infrastructure as Code**: Complete Terraform configuration
- **Simple deployment**: One-command infrastructure deployment
- **Version control**: Container image versioning in Artifact Registry

## 📦 Prerequisites

### Required Software

```bash
# Core tools (with minimum versions)
terraform >= 1.5.0
gcloud >= 400.0.0
git >= 2.30.0

# Optional (recommended)
docker >= 20.10.0        # For local testing
terraform-docs >= 0.16.0 # For documentation
tflint >= 0.47.0        # For linting
```

### Google Cloud Requirements

1. **GCP Project** with billing enabled
2. **Custom domain** with DNS access (required for IAP)
3. **Google Workspace or Cloud Identity** (for user authentication)
4. **Project permissions**:
   - `roles/owner` or
   - `roles/editor` + `roles/iam.serviceAccountAdmin`

### Domain Setup

You **must** have a custom domain for IAP to work. Free domains are not supported.

**Supported domain providers:**
- Google Domains
- Cloudflare
- Namecheap
- GoDaddy
- Route53 (AWS)
- Any DNS provider supporting A records

## 🚀 Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/your-org/secure-cloudrun-iap.git
cd secure-cloudrun-iap/infrastructure
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# Required variables
project_id   = "your-gcp-project-id"
location     = "us-central1"
domain_name  = "app.yourdomain.com"  # MUST be a real domain you own

# IAP access control - Google account emails
allowed_iap_members = [
  "user:alice@yourdomain.com",
  "user:bob@yourdomain.com",
  "group:developers@yourdomain.com"
]
```

### 3. Authenticate with GCP

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project your-gcp-project-id
```

### 4. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy (takes ~10-15 minutes)
terraform apply
```

### 5. Configure DNS

After deployment, Terraform outputs the load balancer IP:

```bash
# Get the IP address
terraform output lb_ip_address

# Output: 34.120.45.67
```

**Add DNS A Record:**

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | app | 34.120.45.67 | 300 |

**DNS Propagation**: Wait 5-60 minutes for DNS to propagate globally.

### 6. Configure OAuth Consent Screen

**CRITICAL STEP - IAP will not work without this!**

1. Go to [OAuth Consent Screen](https://console.cloud.google.com/apis/credentials/consent)
2. Select **Internal** (for Google Workspace) or **External**
3. Fill in required fields:
   - **App name**: Your application name
   - **User support email**: Your email
   - **Developer contact**: Your email
4. Click **Save and Continue**
5. Add scopes (default is fine)
6. Add test users if using External
7. Click **Publish App** (for Internal apps)

### 7. Verify Access

```bash
# Check Cloud Run service
gcloud run services describe nodeapp \
  --region=us-central1 \
  --format='value(status.url)'

# Access your application
open https://app.yourdomain.com
```

**Expected flow:**
1. Browser redirects to Google OAuth
2. User logs in with Google account
3. IAP checks if user is in allowed list
4. If authorized, redirects to Cloud Run application
5. If denied, shows "You don't have access" error

## ⚙️ Configuration

### Terraform Variables

#### Required Variables

```hcl
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "location" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "domain_name" {
  description = "Custom domain for IAP (must be real domain you own)"
  type        = string
  # Example: "app.example.com" or "internal.company.com"
}

variable "allowed_iap_members" {
  description = "List of users/groups allowed through IAP"
  type        = list(string)
  # Format: "user:email@domain.com" or "group:team@domain.com"
}
```

#### Optional Variables

```hcl
variable "cloud_run_min_instances" {
  description = "Minimum Cloud Run instances (warm pool)"
  type        = number
  default     = 2
}

variable "cloud_run_max_instances" {
  description = "Maximum Cloud Run instances"
  type        = number
  default     = 5
}

variable "cloud_run_concurrency" {
  description = "Max concurrent requests per instance"
  type        = number
  default     = 80
}

variable "cloud_run_timeout" {
  description = "Request timeout in seconds"
  type        = number
  default     = 300
}
```

### Cloud Run Configuration

Customize deployment in `main.tf`:

```hcl
module "cloud_run_service" {
  source = "./modules/cloud-run"
  
  # Resource limits
  cpu    = "1000m"      # 1 vCPU
  memory = "512Mi"      # 512 MB RAM
  
  # Auto-scaling
  min_instance_count = 2   # Always-on instances
  max_instance_count = 10  # Max scale for traffic spikes
  
  # Container configuration
  containers = [{
    image = "us-central1-docker.pkg.dev/project/repo/app:v1.0.0"
    port  = 8080
    
    # Environment variables
    env = [
      { name = "NODE_ENV", value = "production" },
      { name = "LOG_LEVEL", value = "info" }
    ]
    
    # Health checks
    startup_probe = {
      http_get = {
        path = "/health"
        port = 8080
      }
      initial_delay_seconds = 10
      period_seconds        = 3
      failure_threshold     = 3
    }
  }]
}
```

## 🔐 IAP Setup

### Understanding IAP

**IAP (Identity-Aware Proxy)** provides application-level access control by:
1. Intercepting all HTTP(S) requests
2. Redirecting unauthenticated users to Google OAuth
3. Validating user identity against allowed list
4. Forwarding authenticated requests with identity headers
5. Logging all access attempts

### OAuth Brand Configuration

**Option 1: Via Terraform (Automated)**

Uncomment in `main.tf`:

```hcl
resource "google_iap_brand" "project_brand" {
  support_email     = "support@yourdomain.com"
  application_title = "Internal Application"
  project           = var.project_id
}

resource "google_iap_client" "iap_client" {
  display_name = "iap-oauth-client"
  brand        = google_iap_brand.project_brand.name
}
```

**Option 2: Via Console (Manual)**

1. Navigate to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth client ID**
3. Select **Web application**
4. Add authorized redirect URI:
   ```
   https://iap.googleapis.com/v1/oauth/clientIds/[CLIENT_ID]:handleRedirect
   ```
5. Save client ID and secret

### Access Control Lists (ACLs)

IAP supports granular access control:

```hcl
# Individual users
allowed_iap_members = [
  "user:alice@company.com",
  "user:bob@company.com"
]

# Google Groups (recommended for teams)
allowed_iap_members = [
  "group:engineering@company.com",
  "group:product@company.com"
]

# Service accounts (for automation)
allowed_iap_members = [
  "serviceAccount:ci-cd@project.iam.gserviceaccount.com"
]

# Domains (all users in domain)
allowed_iap_members = [
  "domain:company.com"
]

# Combined approach (recommended)
allowed_iap_members = [
  "group:employees@company.com",           # All employees
  "user:external-consultant@gmail.com",    # External user
  "serviceAccount:monitoring@project.iam.gserviceaccount.com"  # Automation
]
```

### IAP Headers

IAP adds identity headers to requests:

```javascript
// In your application code
app.get('/api/user', (req, res) => {
  const email = req.headers['x-goog-authenticated-user-email'];
  const userId = req.headers['x-goog-authenticated-user-id'];
  
  // email format: "accounts.google.com:user@domain.com"
  const userEmail = email.split(':')[1];
  
  res.json({ email: userEmail, userId });
});
```

**Available headers:**
- `X-Goog-Authenticated-User-Email`: User's email
- `X-Goog-Authenticated-User-ID`: Unique user ID
- `X-Goog-IAP-JWT-Assertion`: JWT token for verification

### JWT Token Verification (Recommended)

For production, verify IAP JWT tokens:

```javascript
const { OAuth2Client } = require('google-auth-library');

async function verifyIAPToken(req, res, next) {
  const iapJWT = req.headers['x-goog-iap-jwt-assertion'];
  
  if (!iapJWT) {
    return res.status(401).send('No IAP JWT found');
  }
  
  try {
    const oAuth2Client = new OAuth2Client();
    const audience = `/projects/PROJECT_NUMBER/global/backendServices/BACKEND_SERVICE_ID`;
    
    const ticket = await oAuth2Client.verifyIdToken({
      idToken: iapJWT,
      audience: audience
    });
    
    const payload = ticket.getPayload();
    req.user = {
      email: payload.email,
      userId: payload.sub
    };
    
    next();
  } catch (err) {
    return res.status(401).send('Invalid IAP JWT');
  }
}

app.use(verifyIAPToken);
```

## 🔒 Security

### Security Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Security Layers                       │
└─────────────────────────────────────────────────────────┘

Layer 1: DNS & SSL/TLS
  ├─ Google-managed SSL certificates
  ├─ Automatic certificate renewal
  └─ TLS 1.2+ enforced

Layer 2: Identity-Aware Proxy
  ├─ Google OAuth 2.0 authentication
  ├─ Access Control Lists (ACLs)
  ├─ Audit logging (Cloud Audit Logs)
  └─ JWT token-based verification

Layer 3: Load Balancer
  ├─ HTTPS-only (no HTTP allowed)
  ├─ Backend service health checks
  └─ DDoS protection (Google's infrastructure)

Layer 4: Cloud Run
  ├─ Internal ingress only (no public access)
  ├─ Service account isolation
  ├─ Container scanning (Artifact Registry)
  └─ Least-privilege IAM roles

Layer 5: VPC
  ├─ Private subnet (10.1.0.0/24)
  ├─ Firewall rules (SSH + HTTP only)
  └─ Network isolation
```

### Threat Model

| Threat | Mitigation |
|--------|-----------|
| **Unauthorized access** | IAP OAuth + ACLs |
| **Man-in-the-middle** | TLS 1.2+ encryption |
| **DDoS attacks** | Google Cloud Armor (optional add-on) |
| **Container vulnerabilities** | Artifact Registry scanning |
| **Compromised credentials** | Service account rotation |
| **Data exfiltration** | VPC firewall rules |
| **Insider threats** | Audit logging + IAP ACLs |

### Security Best Practices

#### 1. Enable Cloud Armor (Optional but Recommended)

```hcl
resource "google_compute_security_policy" "iap_policy" {
  name = "iap-security-policy"

  # Rate limiting
  rule {
    action   = "rate_based_ban"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      ban_duration_sec = 600
    }
  }

  # Default allow
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}

# Attach to backend service
resource "google_compute_backend_service" "iap_backend_service" {
  # ... existing config ...
  security_policy = google_compute_security_policy.iap_policy.id
}
```

#### 2. Enable Binary Authorization

```bash
# Require signed container images
gcloud container binauthz policy import policy.yaml
```

#### 3. Regular Security Audits

```bash
# Review IAP access logs
gcloud logging read "protoPayload.serviceName=iap.googleapis.com" \
  --limit 50 \
  --format json

# Check for unauthorized access attempts
gcloud logging read 'protoPayload.authenticationInfo.principalEmail!=""
  AND protoPayload.status.code!=0' \
  --limit 100
```

#### 4. Rotate Service Account Keys

```bash
# List service accounts
gcloud iam service-accounts list

# Rotate keys quarterly
gcloud iam service-accounts keys create new-key.json \
  --iam-account=SERVICE_ACCOUNT_EMAIL
```

### Compliance

This architecture supports:

- **SOC 2 Type II**: Audit logging, access controls
- **PCI-DSS**: Encrypted transmission, access logging
- **HIPAA**: IAP access controls, audit trails (with BAA)
- **ISO 27001**: Security controls, monitoring
- **GDPR**: Data access controls, audit logs

## 🚀 Deployment

### Manual Deployment

```bash
# 1. Deploy infrastructure
terraform init
terraform apply

# 2. Get load balancer IP
LB_IP=$(terraform output -raw lb_ip_address)
echo "Configure DNS A record for $LB_IP"

# 3. Wait for DNS propagation
while ! host app.yourdomain.com; do sleep 10; done

# 4. Wait for SSL certificate provisioning (5-20 minutes)
gcloud compute ssl-certificates describe ssl-cert --global \
  --format="get(managed.status)"

# 5. Test access
curl -I https://app.yourdomain.com
# Should redirect to Google OAuth
```

### Automated CI/CD

#### GitHub Actions

`.github/workflows/deploy.yml`:

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - 'infrastructure/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1
      
      - name: Build and push container
        run: |
          cd src
          gcloud builds submit \
            --tag=us-central1-docker.pkg.dev/$PROJECT_ID/nodeapp/nodeapp:$GITHUB_SHA
      
      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy nodeapp \
            --image=us-central1-docker.pkg.dev/$PROJECT_ID/nodeapp/nodeapp:$GITHUB_SHA \
            --region=us-central1 \
            --platform=managed
```

### Blue/Green Deployment

```bash
# Deploy new revision without traffic
gcloud run deploy nodeapp \
  --image=us-central1-docker.pkg.dev/project/repo/app:v2.0.0 \
  --region=us-central1 \
  --no-traffic \
  --tag=canary

# Test canary revision
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://canary---nodeapp-xyz.a.run.app

# Gradually shift traffic
gcloud run services update-traffic nodeapp \
  --region=us-central1 \
  --to-revisions=canary=10,LATEST=90

# Monitor metrics, then shift 100%
gcloud run services update-traffic nodeapp \
  --region=us-central1 \
  --to-latest
```

### Rollback

```bash
# List revisions
gcloud run revisions list --service=nodeapp --region=us-central1

# Rollback to previous revision
gcloud run services update-traffic nodeapp \
  --region=us-central1 \
  --to-revisions=nodeapp-00005-abc=100
```

## 📊 Monitoring

### Cloud Monitoring Dashboards

```bash
# Create custom dashboard
gcloud monitoring dashboards create --config-from-file=dashboard.json
```

`dashboard.json`:
```json
{
  "displayName": "IAP-Protected Cloud Run",
  "dashboardFilters": [],
  "gridLayout": {
    "widgets": [
      {
        "title": "Cloud Run Request Count",
        "xyChart": {
          "dataSets": [{
            "timeSeriesQuery": {
              "timeSeriesFilter": {
                "filter": "resource.type=\"cloud_run_revision\" metric.type=\"run.googleapis.com/request_count\"",
                "aggregation": {
                  "alignmentPeriod": "60s",
                  "perSeriesAligner": "ALIGN_RATE"
                }
              }
            }
          }]
        }
      },
      {
        "title": "IAP Authentication Failures",
        "xyChart": {
          "dataSets": [{
            "timeSeriesQuery": {
              "timeSeriesFilter": {
                "filter": "resource.type=\"global\" protoPayload.serviceName=\"iap.googleapis.com\" protoPayload.status.code!=0"
              }
            }
          }]
        }
      }
    ]
  }
}
```

### Log-Based Metrics

```bash
# Create metric for IAP denials
gcloud logging metrics create iap_access_denied \
  --description="IAP access denied count" \
  --log-filter='protoPayload.serviceName="iap.googleapis.com"
    AND protoPayload.status.code=7'
```

### Alerts

```bash
# Create alert for high error rate
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="IAP Access Denied Alert" \
  --condition-display-name="IAP denials > 10/min" \
  --condition-threshold-value=10 \
  --condition-threshold-duration=300s \
  --condition-filter='metric.type="logging.googleapis.com/user/iap_access_denied"'
```

### Audit Logging

```bash
# View IAP access logs
gcloud logging read "protoPayload.serviceName=iap.googleapis.com" \
  --limit 100 \
  --format="table(timestamp, protoPayload.authenticationInfo.principalEmail, protoPayload.status.code)"

# Export logs to BigQuery (for long-term analysis)
gcloud logging sinks create iap-audit-logs \
  bigquery.googleapis.com/projects/PROJECT_ID/datasets/audit_logs \
  --log-filter='protoPayload.serviceName="iap.googleapis.com"'
```

### Key Metrics to Monitor

| Metric | Threshold | Action |
|--------|-----------|--------|
| Request latency (P95) | > 2s | Increase instances |
| Error rate | > 1% | Check logs |
| IAP denials | > 50/hr | Review ACLs |
| SSL cert expiry | < 7 days | Check auto-renewal |
| Active instances | = max | Increase max limit |
| CPU utilization | > 80% | Optimize code or increase CPU |

## 🔧 Troubleshooting

### Common Issues

#### 1. "You don't have access" Error

**Symptoms**: User sees IAP access denied page

**Causes**:
- User not in `allowed_iap_members` list
- OAuth consent screen not configured
- Wrong Google account used

**Solutions**:

```bash
# Check current IAP members
gcloud iap web backend-services get-iam-policy BACKEND_SERVICE_NAME \
  --global \
  --format=json

# Add user to allowed list
# Update terraform.tfvars:
allowed_iap_members = [
  "user:newuser@domain.com"
]

# Apply changes
terraform apply
```

#### 2. SSL Certificate Stuck in "PROVISIONING"

**Symptoms**: Certificate shows `PROVISIONING` status for >30 minutes

**Causes**:
- DNS A record not pointing to load balancer IP
- DNS propagation delay
- Domain validation failure

**Solutions**:

```bash
# Check certificate status
gcloud compute ssl-certificates describe ssl-cert --global

# Verify DNS resolution
nslookup app.yourdomain.com
dig app.yourdomain.com

# Check domain ownership
gcloud compute ssl-certificates list --global \
  --format="table(name, managed.domains, managed.status, managed.domainStatus)"

# If stuck, delete and recreate
terraform destroy -target=google_compute_managed_ssl_certificate.ssl_cert
terraform apply
```

#### 3. Cloud Run Service Not Receiving Traffic

**Symptoms**: Load balancer shows healthy but application unreachable

**Causes**:
- IAP service account missing `run.invoker` role
- Cloud Run ingress set incorrectly
- Backend service misconfigured

**Solutions**:

```bash
# Check Cloud Run IAM
gcloud run services get-iam-policy nodeapp --region=us-central1

# Verify IAP service account has access
gcloud run services add-iam-policy-binding nodeapp \
  --region=us-central1 \
  --member="serviceAccount:service-PROJECT_NUMBER@gcp-sa-iap.iam.gserviceaccount.com" \
  --role="roles/run.invoker"

# Check backend service health
gcloud compute backend-services get-health iap-backend-service --global
```

#### 4. OAuth Consent Screen Not Showing

**Symptoms**: Direct browser to load balancer shows blank page

**Causes**:
- OAuth brand not created
- OAuth client not configured
- IAP not enabled on backend service

**Solutions**:

```bash
# Check if IAP is enabled
gcloud compute backend-services describe iap-backend-service \
  --global \
  --format="get(iap)"

# Enable IAP manually
gcloud compute backend-services update iap-backend-service \
  --global \
  --iap=enabled

# Verify OAuth credentials exist
gcloud iap oauth-brands list
gcloud iap oauth-clients list BRAND_NAME
```

#### 5. High Latency or Timeouts

**Symptoms**: Requests taking >5 seconds or timing out

**Causes**:
- Cold starts (min instances = 0)
- Application initialization time
- Database connection pooling issues

**Solutions**:

```hcl
# Increase minimum instances
module "cloud_run_service" {
  min_instance_count = 3  # Keep warm pool
  
  # Add startup probe
  containers = [{
    startup_probe = {
      initial_delay_seconds = 0
      timeout_seconds       = 1
      period_seconds        = 3
      failure_threshold     = 3
      http_get = {
        path = "/health"
        port = 8080
      }
    }
  }]
}
```

### Debug Mode

```bash
# Enable verbose logging
export TF_LOG=DEBUG
terraform apply

# Check Cloud Run logs
gcloud run services logs read nodeapp \
  --region=us-central1 \
  --limit=100

# Stream live logs
gcloud run services logs tail nodeapp --region=us-central1

# Check load balancer logs
gcloud logging read "resource.type=http_load_balancer" \
  --limit=50 \
  --format=json
```

### Getting Help

1. **Check Cloud Console**: [IAP Dashboard](https://console.cloud.google.com/security/iap)
2. **Review Audit Logs**: [Logs Explorer](https://console.cloud.google.com/logs)
3. **GCP Support**: File a support ticket
4. **Community**: [Stack Overflow - google-cloud-iap](https://stackoverflow.com/questions/tagged/google-cloud-iap)

## 💰 Cost Estimation

### Monthly Cost Breakdown (us-central1)

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| **Cloud Run** | 2-5 instances, 512MB, 1vCPU | $25-75 |
| **Load Balancer** | Global HTTPS LB | $18 |
| **IAP** | Free for HTTP(S) load balancers | $0 |
| **SSL Certificate** | Google-managed | $0 |
| **Cloud Storage** | Artifact Registry | $5-10 |
| **Networking** | Egress (first 1GB free) | $10-30 |
| **VPC** | Single VPC | $0 |
| **Logging** | 50GB/month | $0 (first 50GB free) |
| **Monitoring** | Basic metrics | $0 |
| **Total** | | **$58-133/month** |

### Cost Optimization

#### 1. Reduce Minimum Instances (Dev/Staging)

```hcl
# Development environment
min_instance_count = 0  # Accept cold starts
# Savings: ~$25/month per environment
```

#### 2. Use Committed Use Discounts

```bash
# 1-year commitment: 25% discount
# 3-year commitment: 52% discount
# Savings: ~$15-30/month
```

#### 3. Optimize Container Size

```dockerfile
# Use multi-stage builds
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine
COPY --from=builder /app/node_modules ./node_modules
COPY . .
# Smaller images = faster cold starts = lower costs
```

#### 4. Enable Request Logging Sampling

```hcl
# Sample 10% of requests instead of 100%
# Savings: ~$5-10/month on logging costs
```

### Cost Monitoring

```bash
# Set up budget alerts
gcloud billing budgets create \
  --billing-account=BILLING_ACCOUNT_ID \
  --display-name="IAP Cloud Run Budget" \
  --budget-amount=150USD \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=90 \
  --threshold-rule=percent=100

# View cost breakdown
gcloud billing accounts list
gcloud beta billing projects describe PROJECT_ID
```

## ✅ Production Checklist

### Pre-Deployment

#### Infrastructure
- [ ] Custom domain configured and DNS verified
- [ ] SSL certificate provisioned and active
- [ ] OAuth consent screen configured
- [ ] IAP OAuth client created
- [ ] Terraform state stored in remote backend (GCS)
- [ ] State locking enabled
- [ ] VPC and firewall rules configured

#### Security
- [ ] IAP enabled on backend service
- [ ] Access control lists (ACLs) defined and tested
- [ ] Service account permissions minimized
- [ ] Cloud Armor policies configured (optional)
- [ ] Audit logging enabled
- [ ] Binary Authorization enabled (optional)
- [ ] Secret Manager for sensitive data
- [ ] Network ingress restricted to internal only

#### Application
- [ ] Container image scanned for vulnerabilities
- [ ] Health check endpoint implemented (`/health`)
- [ ] Logging configured (structured JSON)
- [ ] Error handling implemented
- [ ] Graceful shutdown handling
- [ ] Environment variables externalized
- [ ] Database connection pooling configured

#### Monitoring
- [ ] Cloud Monitoring dashboard created
- [ ] Alert policies configured
- [ ] Notification channels set up (email, Slack, PagerDuty)
- [ ] Log-based metrics defined
- [ ] Uptime checks configured
- [ ] SLO/SLI defined and monitored

### Post-Deployment

#### Validation
- [ ] DNS resolution verified
- [ ] SSL certificate active and valid
- [ ] IAP authentication flow tested
- [ ] Authorized users can access application
- [ ] Unauthorized users are blocked
- [ ] Load balancer health checks passing
- [ ] Cloud Run instances healthy
- [ ] Application functionality verified
- [ ] Performance benchmarks met

#### Operations
- [ ] Runbook created for common issues
- [ ] Disaster recovery plan documented
- [ ] Backup and restore procedures tested
- [ ] Incident response plan defined
- [ ] On-call rotation established
- [ ] Documentation updated
- [ ] Team training completed

#### Compliance
- [ ] Security audit completed
- [ ] Compliance requirements met (SOC2, PCI-DSS, HIPAA)
- [ ] Access logs reviewed
- [ ] Data retention policies configured
- [ ] Privacy policy updated
- [ ] Terms of service updated

### 30-Day Review

- [ ] Cost analysis and optimization
- [ ] Performance metrics review
- [ ] Security posture assessment
- [ ] User feedback collected
- [ ] Capacity planning updated
- [ ] SLO/SLA review
- [ ] Lessons learned documented

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

### Development Workflow

1. Fork the repository
2. Create a feature branch
   ```bash
   git checkout -b feature/iap-improvements
   ```
3. Make your changes
4. Run validations
   ```bash
   terraform fmt -recursive
   terraform validate
   tflint
   ```
5. Commit with conventional commits
   ```bash
   git commit -m "feat: add Cloud Armor integration"
   ```
6. Push and create Pull Request

### Commit Convention

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `security:` Security improvements
- `perf:` Performance improvements
- `refactor:` Code refactoring
- `test:` Adding tests
- `chore:` Maintenance tasks

### Code Review

- All changes require PR approval
- Must pass CI/CD checks
- Security team review for IAP/IAM changes
- Performance testing for infrastructure changes

## 📚 Additional Resources

### Documentation
- [IAP Documentation](https://cloud.google.com/iap/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [OAuth 2.0 Guide](https://cloud.google.com/iap/docs/authentication-howto)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

### Tutorials
- [IAP for Cloud Run Tutorial](https://cloud.google.com/iap/docs/enabling-cloud-run)
- [Securing Cloud Run with IAP](https://cloud.google.com/architecture/serverless-vpc-access-securing-cloud-run)
- [Custom Domain Setup](https://cloud.google.com/run/docs/mapping-custom-domains)

### Best Practices
- [Cloud Run Best Practices](https://cloud.google.com/run/docs/best-practices)
- [IAP Security Best Practices](https://cloud.google.com/iap/docs/concepts-best-practices)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

### Support
- **Documentation**: [Project Wiki](https://github.com/your-org/secure-cloudrun-iap/wiki)
- **Issues**: [GitHub Issues](https://github.com/your-org/secure-cloudrun-iap/issues)
- **Email**: devops@yourcompany.com
- **Slack**: #infrastructure channel

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🎓 FAQ

### General

**Q: Do I need a custom domain for IAP?**
A: Yes, IAP requires a custom domain. You cannot use the default `*.run.app` domain.

**Q: Can I use a free domain (e.g., .tk, .ml)?**
A: No, Google managed SSL certificates do not support free top-level domains.

**Q: Is IAP free?**
A: Yes, IAP is free for HTTP(S) load balancers. You only pay for the load balancer and backend resources.

### Authentication

**Q: Can external users (non-Google Workspace) access my app?**
A: Yes, but you must configure the OAuth consent screen as "External" and add users individually or publish the app.

**Q: How do I authenticate service-to-service calls?**
A: Use service accounts with `serviceAccount:` prefix in `allowed_iap_members` and pass identity tokens.

**Q: Can I use custom authentication instead of Google OAuth?**
A: No, IAP only supports Google OAuth. For custom auth, remove IAP and implement in your application.

### Troubleshooting

**Q: Why is my SSL certificate stuck in PROVISIONING?**
A: Check that your DNS A record points to the load balancer IP and that domain ownership is verified.

**Q: Why do I see "You don't have access"?**
A: Ensure your Google account email is in the `allowed_iap_members` list and OAuth consent screen is configured.

**Q: Can I test locally without IAP?**
A: Yes, run Cloud Run locally with Docker and disable IAP checks in development mode.

### Performance

**Q: What causes high latency?**
A: Cold starts (increase min instances), application initialization time, or database connection issues.

**Q: How do I reduce costs?**
A: Reduce min instances (accept cold starts), use smaller container images, optimize database queries.

**Q: Can I use HTTP/2?**
A: Yes, load balancers automatically support HTTP/2. Ensure your application supports it.

---

**Built with ❤️ by the Platform Team**

**Last Updated**: January 2026
