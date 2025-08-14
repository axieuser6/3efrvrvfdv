# 🔐 ENVIRONMENT VARIABLES REFERENCE

## 📋 **OVERVIEW**
This document lists all environment variables required for the Axie Studio User Management system. Variables are organized by component and include examples and setup instructions.

---

## 🗂️ **VARIABLE CATEGORIES**

| Category | Count | Purpose |
|----------|-------|---------|
| **Supabase** | 3 | Database and authentication |
| **Stripe** | 4 | Payment processing |
| **AxieStudio** | 4 | External app integration |
| **Admin** | 1 | Administrative access |
| **Frontend** | 8 | Client-side configuration |

---

## 🏗️ **SUPABASE FUNCTION SECRETS**

### **Set All Secrets at Once:**
```bash
# Supabase Configuration
supabase secrets set SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY

# Stripe Configuration
supabase secrets set STRIPE_SECRET_KEY=sk_test_YOUR_STRIPE_SECRET_KEY
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_YOUR_WEBHOOK_SECRET
supabase secrets set VITE_STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_STRIPE_PUBLISHABLE_KEY
supabase secrets set VITE_STRIPE_PRO_PRICE_ID=price_YOUR_PRO_PRICE_ID
supabase secrets set VITE_STRIPE_ENTERPRISE_PRICE_ID=price_YOUR_ENTERPRISE_PRICE_ID

# AxieStudio Configuration
supabase secrets set AXIESTUDIO_APP_URL=https://YOUR_AXIESTUDIO_DOMAIN.com
supabase secrets set AXIESTUDIO_USERNAME=YOUR_ADMIN_EMAIL@domain.com
supabase secrets set AXIESTUDIO_PASSWORD=YOUR_SECURE_PASSWORD
supabase secrets set AXIESTUDIO_API_KEY=sk-YOUR_AXIESTUDIO_API_KEY
```

---

## 🗄️ **SUPABASE CONFIGURATION**

### **SUPABASE_URL**
- **Purpose:** Supabase project URL for API access
- **Format:** `https://your-project-id.supabase.co`
- **Where to find:** Supabase Dashboard > Settings > API
- **Used by:** All Edge Functions
- **Example:** `https://abcdefghijklmnop.supabase.co`

### **SUPABASE_SERVICE_ROLE_KEY**
- **Purpose:** Service role key for admin operations
- **Format:** JWT token starting with `eyJhbGciOiJIUzI1NiIs...`
- **Where to find:** Supabase Dashboard > Settings > API
- **Used by:** All Edge Functions
- **Security:** ⚠️ **NEVER expose in frontend code**

### **SUPABASE_ANON_KEY**
- **Purpose:** Anonymous key for client-side operations
- **Format:** JWT token starting with `eyJhbGciOiJIUzI1NiIs...`
- **Where to find:** Supabase Dashboard > Settings > API
- **Used by:** Frontend application
- **Security:** ✅ Safe to expose in frontend

---

## 💳 **STRIPE CONFIGURATION**

### **STRIPE_SECRET_KEY**
- **Purpose:** Stripe secret key for server-side operations
- **Format:** `sk_test_` or `sk_live_` followed by key
- **Where to find:** Stripe Dashboard > Developers > API Keys
- **Used by:** `stripe-checkout`, `stripe-webhook`, payment functions
- **Security:** ⚠️ **NEVER expose in frontend code**
- **Example:** `sk_test_51234567890abcdef...`

### **STRIPE_WEBHOOK_SECRET**
- **Purpose:** Webhook endpoint secret for signature verification
- **Format:** `whsec_` followed by secret
- **Where to find:** Stripe Dashboard > Webhooks > Endpoint > Signing Secret
- **Used by:** `stripe-webhook`, `stripe-webhook-public`
- **Security:** ⚠️ **Keep secret for webhook security**
- **Example:** `whsec_1234567890abcdef...`

### **VITE_STRIPE_PUBLISHABLE_KEY**
- **Purpose:** Stripe publishable key for client-side operations
- **Format:** `pk_test_` or `pk_live_` followed by key
- **Where to find:** Stripe Dashboard > Developers > API Keys
- **Used by:** Frontend Stripe integration
- **Security:** ✅ Safe to expose in frontend
- **Example:** `pk_test_51234567890abcdef...`

### **Stripe Price IDs:**
```bash
# Pro subscription price
VITE_STRIPE_PRO_PRICE_ID=price_1234567890abcdef

# Enterprise subscription price  
VITE_STRIPE_ENTERPRISE_PRICE_ID=price_0987654321fedcba

# Optional: Testing price ($1)
VITE_STRIPE_TEST_PRICE_ID=price_test123456789
```

---

## 🎮 **AXIESTUDIO CONFIGURATION**

### **AXIESTUDIO_APP_URL**
- **Purpose:** Base URL for AxieStudio application
- **Format:** `https://your-domain.com` (no trailing slash)
- **Used by:** `axie-studio-account`, `axie-studio-login`, `trial-cleanup`
- **Example:** `https://studio.yourdomain.com`

### **AXIESTUDIO_USERNAME**
- **Purpose:** Admin username for AxieStudio API access
- **Format:** Email address of admin user
- **Used by:** Account creation and management functions
- **Security:** ⚠️ **Use dedicated admin account**
- **Example:** `admin@yourdomain.com`

### **AXIESTUDIO_PASSWORD**
- **Purpose:** Admin password for AxieStudio API access
- **Format:** Secure password string
- **Used by:** Account creation and management functions
- **Security:** ⚠️ **Use strong, unique password**
- **Example:** `SecureAdminPassword123!`

### **AXIESTUDIO_API_KEY**
- **Purpose:** API key for AxieStudio operations
- **Format:** `sk-` followed by key string
- **Used by:** Direct API operations
- **Security:** ⚠️ **Keep secret, rotate regularly**
- **Example:** `sk-your-axiestudio-api-key-here`

---

## 👤 **ADMIN CONFIGURATION**

### **VITE_ADMIN_USER_ID**
- **Purpose:** UUID of admin user for special permissions
- **Format:** UUID string
- **Where to find:** Supabase Dashboard > Authentication > Users
- **Used by:** Admin page access control
- **Example:** `b8782453-a343-4301-a947-67c5bb407d2b`

---

## 🌐 **FRONTEND ENVIRONMENT VARIABLES**

### **Create `.env` file:**
```env
# Supabase Configuration
VITE_SUPABASE_URL=https://your-project-id.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Stripe Configuration
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_51234567890abcdef...
VITE_STRIPE_PRO_PRICE_ID=price_1234567890abcdef
VITE_STRIPE_ENTERPRISE_PRICE_ID=price_0987654321fedcba

# AxieStudio Configuration
VITE_AXIESTUDIO_APP_URL=https://studio.yourdomain.com

# Admin Configuration
VITE_ADMIN_USER_ID=b8782453-a343-4301-a947-67c5bb407d2b
```

---

## 🔧 **SETUP COMMANDS**

### **1. Set Supabase Secrets:**
```bash
# Login and link project first
supabase login
supabase link --project-ref your-project-ref

# Set all secrets
supabase secrets set SUPABASE_URL=https://your-project-id.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
supabase secrets set STRIPE_SECRET_KEY=sk_test_your-stripe-secret
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_your-webhook-secret
supabase secrets set AXIESTUDIO_APP_URL=https://your-axiestudio-domain.com
supabase secrets set AXIESTUDIO_USERNAME=admin@yourdomain.com
supabase secrets set AXIESTUDIO_PASSWORD=your-secure-password
supabase secrets set AXIESTUDIO_API_KEY=sk-your-axiestudio-api-key
```

### **2. Verify Secrets:**
```bash
# List all secrets (names only, values hidden)
supabase secrets list
```

### **3. Update Secrets:**
```bash
# Update individual secret
supabase secrets set SECRET_NAME=new-value

# Delete secret
supabase secrets unset SECRET_NAME
```

---

## 🧪 **TESTING CONFIGURATION**

### **Development vs Production:**

**Development (.env.local):**
```env
VITE_SUPABASE_URL=https://dev-project-id.supabase.co
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_...
VITE_STRIPE_PRO_PRICE_ID=price_test_...
VITE_AXIESTUDIO_APP_URL=https://dev-studio.yourdomain.com
```

**Production (.env.production):**
```env
VITE_SUPABASE_URL=https://prod-project-id.supabase.co
VITE_STRIPE_PUBLISHABLE_KEY=pk_live_...
VITE_STRIPE_PRO_PRICE_ID=price_live_...
VITE_AXIESTUDIO_APP_URL=https://studio.yourdomain.com
```

---

## 🚨 **SECURITY BEST PRACTICES**

### **✅ DO:**
- Use different keys for development and production
- Rotate API keys regularly
- Use strong, unique passwords
- Store secrets in Supabase secrets (not in code)
- Use environment-specific configurations

### **❌ DON'T:**
- Commit secrets to version control
- Share secret keys in chat/email
- Use production keys in development
- Hardcode credentials in source code
- Use weak or default passwords

### **🔐 Secret Management:**
```bash
# Good: Using Supabase secrets
supabase secrets set STRIPE_SECRET_KEY=sk_test_...

# Bad: Hardcoding in function
const stripeKey = "sk_test_hardcoded_key"; // ❌ NEVER DO THIS
```

---

## ✅ **VERIFICATION CHECKLIST**

### **Supabase Secrets:**
- [ ] `SUPABASE_URL` set correctly
- [ ] `SUPABASE_SERVICE_ROLE_KEY` set correctly
- [ ] All Stripe keys configured
- [ ] All AxieStudio credentials configured

### **Frontend Environment:**
- [ ] `.env` file created
- [ ] All `VITE_` variables set
- [ ] No secret keys in frontend env
- [ ] Environment-specific configurations

### **Testing:**
- [ ] Development environment working
- [ ] Production environment configured
- [ ] All functions can access required secrets
- [ ] No hardcoded credentials in code

---

## 🔍 **TROUBLESHOOTING**

### **Common Issues:**

**1. "Environment variable not found"**
```bash
# Check if secret is set
supabase secrets list

# Set missing secret
supabase secrets set MISSING_VAR=value
```

**2. "Invalid API key"**
- Verify key format and source
- Check if using test vs live keys correctly
- Ensure key has required permissions

**3. "CORS errors in development"**
- Check frontend environment variables
- Verify Supabase URL is correct
- Ensure anon key is properly set

**4. "Function deployment fails"**
- Verify all required secrets are set
- Check secret names match function code
- Redeploy after setting secrets

---

**🎉 All environment variables are now properly configured and secure!**
