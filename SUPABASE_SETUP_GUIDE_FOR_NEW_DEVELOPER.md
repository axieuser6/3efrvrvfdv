# 🚀 SUPABASE SETUP GUIDE FOR NEW DEVELOPER

## 📋 **OVERVIEW**
This guide provides step-by-step instructions for setting up the complete Supabase backend for the Axie Studio User Management system. Follow these steps in exact order.

## 🎯 **WHAT YOU'LL BUILD**
- **User Management System** with 7-day trials
- **Stripe Payment Integration** with subscriptions
- **AxieStudio Account Creation** and auto-login
- **Email Confirmation** and security
- **Account Deletion** with trial abuse prevention

---

## 📁 **PROJECT STRUCTURE**

```
supabase/
├── functions/                    # Edge Functions (TypeScript)
│   ├── axie-studio-account/      # Create/delete AxieStudio accounts
│   ├── axie-studio-login/        # Auto-login to AxieStudio
│   ├── cancel-subscription/      # Cancel Stripe subscriptions
│   ├── cancel-subscription-immediate/ # Immediate cancellation
│   ├── create-portal-session/    # Stripe customer portal
│   ├── delete-user-account/      # Complete account deletion
│   ├── reactivate-subscription/  # Reactivate cancelled subs
│   ├── stripe-checkout/          # Create Stripe checkout sessions
│   ├── stripe-webhook/           # Handle Stripe webhooks
│   ├── stripe-webhook-public/    # Public webhook endpoint
│   └── trial-cleanup/            # Automated trial cleanup
└── migrations/                   # SQL Database Schema
    ├── 20250813160527_shy_bird.sql           # Main database schema
    ├── 20250813172500_fix_signup_trigger.sql # Signup trigger fixes
    ├── 20250813230000_axie_studio_credentials.sql # Credentials table
    └── 20241213_add_immediate_deletion_functions.sql # Deletion functions
```

---

## 🗄️ **STEP 1: CREATE SUPABASE PROJECT**

### **1.1 Create Project**
1. Go to [Supabase Dashboard](https://app.supabase.com/)
2. Click **"New Project"**
3. Choose your organization
4. **Project Name:** `axie-studio-user-management`
5. **Database Password:** Generate strong password (save it!)
6. **Region:** Choose closest to your users
7. Click **"Create new project"**

### **1.2 Get Project Credentials**
1. Go to **Settings** > **API**
2. Copy these values:
   - **Project URL:** `https://YOUR_PROJECT_ID.supabase.co`
   - **Anon Public Key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (copy full key)
   - **Service Role Key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (copy full key)

---

## 🗃️ **STEP 2: APPLY SQL MIGRATIONS (IN ORDER)**

### **2.1 Main Database Schema**
**File:** `supabase/migrations/20250813160527_shy_bird.sql`

1. Go to **SQL Editor** in Supabase Dashboard
2. Copy the **entire content** of `20250813160527_shy_bird.sql`
3. Paste into SQL Editor
4. Click **"RUN"** ▶️

**What this creates:**
- ✅ Core tables: `user_profiles`, `user_trials`, `user_account_state`
- ✅ Stripe tables: `stripe_customers`, `stripe_subscriptions`
- ✅ Business logic functions: trial management, user protection
- ✅ Views: `user_dashboard`, `user_trial_info`, `user_access_status`
- ✅ Triggers: automatic user creation, trial setup
- ✅ RLS policies: row-level security

### **2.2 Signup Trigger Fixes**
**File:** `supabase/migrations/20250813172500_fix_signup_trigger.sql`

1. Copy content of `20250813172500_fix_signup_trigger.sql`
2. Paste into SQL Editor
3. Click **"RUN"** ▶️

**What this fixes:**
- ✅ Improved user creation trigger
- ✅ Better error handling for signups
- ✅ Trial creation reliability

### **2.3 AxieStudio Credentials Table**
**File:** `supabase/migrations/20250813230000_axie_studio_credentials.sql`

1. Copy content of `20250813230000_axie_studio_credentials.sql`
2. Paste into SQL Editor
3. Click **"RUN"** ▶️

**What this creates:**
- ✅ `axie_studio_credentials` table for auto-login
- ✅ Secure password storage
- ✅ RLS policies for credential access

### **2.4 Account Deletion Functions**
**File:** `supabase/migrations/20241213_add_immediate_deletion_functions.sql`

1. Copy content of `20241213_add_immediate_deletion_functions.sql`
2. Paste into SQL Editor
3. Click **"RUN"** ▶️

**What this creates:**
- ✅ `delete_user_immediately()` function
- ✅ `cleanup_deleted_user_data()` function
- ✅ Safe account deletion with trial abuse prevention

### **2.5 Trial Timer Fix (IMPORTANT)**
**File:** `COPY_PASTE_THIS_SQL.sql`

1. Copy content of `COPY_PASTE_THIS_SQL.sql`
2. Paste into SQL Editor
3. Click **"RUN"** ▶️

**What this fixes:**
- ✅ Trial dates use user creation time (not current time)
- ✅ Accurate trial countdown timers
- ✅ Fixes existing users with wrong dates

---

## 🔧 **STEP 3: CONFIGURE AUTHENTICATION**

### **3.1 Enable Email Confirmation**
1. Go to **Authentication** > **Settings**
2. In **"User Signups"** section:
   - ✅ **"Enable email confirmations"** = ON
   - ✅ **"Confirm email change"** = ON
   - ✅ **"Enable secure email change"** = ON
   - ✅ **"Allow new users to sign up"** = ON

### **3.2 Configure Email Templates (Optional)**
1. Go to **Authentication** > **Email Templates**
2. Customize **"Confirm signup"** template
3. Add your branding and messaging

### **3.3 Set Redirect URLs**
1. Go to **Authentication** > **URL Configuration**
2. **Site URL:** `https://YOUR_DOMAIN.com`
3. **Redirect URLs:** Add your production and development URLs:
   - `https://YOUR_DOMAIN.com`
   - `http://localhost:3000` (for development)

---

## ⚡ **STEP 4: DEPLOY EDGE FUNCTIONS**

### **4.1 Install Supabase CLI**
```bash
npm install -g supabase
```

### **4.2 Login and Link Project**
```bash
# Login to Supabase
supabase login

# Link your project (get project-ref from dashboard URL)
supabase link --project-ref YOUR_PROJECT_REF
```

### **4.3 Deploy All Functions**
```bash
# Deploy each function individually
supabase functions deploy axie-studio-account
supabase functions deploy axie-studio-login
supabase functions deploy cancel-subscription
supabase functions deploy cancel-subscription-immediate
supabase functions deploy create-portal-session
supabase functions deploy delete-user-account
supabase functions deploy reactivate-subscription
supabase functions deploy stripe-checkout
supabase functions deploy stripe-webhook
supabase functions deploy stripe-webhook-public
supabase functions deploy trial-cleanup
```

---

## 🔐 **STEP 5: SET ENVIRONMENT VARIABLES**

### **5.1 Supabase Function Secrets**
```bash
# Stripe Configuration
supabase secrets set STRIPE_SECRET_KEY=sk_test_YOUR_STRIPE_SECRET_KEY
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_YOUR_WEBHOOK_SECRET
supabase secrets set VITE_STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_STRIPE_PUBLISHABLE_KEY

# AxieStudio Configuration
supabase secrets set AXIESTUDIO_APP_URL=https://YOUR_AXIESTUDIO_DOMAIN.com
supabase secrets set AXIESTUDIO_USERNAME=YOUR_ADMIN_EMAIL@domain.com
supabase secrets set AXIESTUDIO_PASSWORD=YOUR_SECURE_PASSWORD
supabase secrets set AXIESTUDIO_API_KEY=sk-YOUR_AXIESTUDIO_API_KEY

# Supabase Configuration (for functions)
supabase secrets set SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
```

### **5.2 Frontend Environment Variables**
Create `.env` file in your project root:
```env
# Supabase Configuration
VITE_SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
VITE_SUPABASE_ANON_KEY=YOUR_ANON_KEY

# Stripe Configuration
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_STRIPE_PUBLISHABLE_KEY
VITE_STRIPE_PRO_PRICE_ID=price_YOUR_PRO_PRICE_ID
VITE_STRIPE_ENTERPRISE_PRICE_ID=price_YOUR_ENTERPRISE_PRICE_ID

# AxieStudio Configuration
VITE_AXIESTUDIO_APP_URL=https://YOUR_AXIESTUDIO_DOMAIN.com

# Admin Configuration (get from Supabase Auth > Users)
VITE_ADMIN_USER_ID=YOUR_ADMIN_USER_UUID
```

---

## 🧪 **STEP 6: VERIFICATION & TESTING**

### **6.1 Database Verification**
Run this query in SQL Editor:
```sql
-- Check all tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Check all functions exist
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
ORDER BY routine_name;
```

### **6.2 Function Testing**
1. Go to **Functions** in Supabase Dashboard
2. Check all functions are deployed and active
3. Test each function with sample data

### **6.3 Authentication Testing**
1. Test user signup (should require email confirmation)
2. Test email confirmation flow
3. Test login after confirmation
4. Verify trial creation and countdown

---

## 📊 **STEP 7: STRIPE INTEGRATION**

### **7.1 Create Stripe Products**
1. Go to [Stripe Dashboard](https://dashboard.stripe.com/)
2. Create products with recurring pricing
3. Copy price IDs to environment variables

### **7.2 Configure Webhooks**
1. In Stripe Dashboard, go to **Webhooks**
2. Add endpoint: `https://YOUR_PROJECT_ID.supabase.co/functions/v1/stripe-webhook-public`
3. Select events: `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`
4. Copy webhook secret to environment variables

---

## ✅ **STEP 8: FINAL CHECKLIST**

- [ ] Supabase project created
- [ ] All 4 SQL migrations applied successfully
- [ ] Email confirmation enabled
- [ ] All 11 Edge Functions deployed
- [ ] Environment variables set
- [ ] Stripe products and webhooks configured
- [ ] Database verification queries pass
- [ ] Authentication flow tested
- [ ] Trial system working
- [ ] Payment integration tested

---

## 🚨 **TROUBLESHOOTING**

### **Common Issues:**
1. **Migration fails:** Check for syntax errors, run migrations in order
2. **Functions won't deploy:** Verify CLI is logged in and linked
3. **Environment variables missing:** Double-check all secrets are set
4. **Email confirmation not working:** Verify auth settings in dashboard
5. **Stripe webhooks failing:** Check endpoint URL and selected events

### **Getting Help:**
- Check Supabase logs in Dashboard > Logs
- Review function logs for specific errors
- Verify environment variables are set correctly
- Test individual components before integration

---

**🎉 Congratulations! Your Supabase backend is now fully configured and ready for production use!**

---

## 📚 **ADDITIONAL DOCUMENTATION**

- **📄 SQL_COMMANDS_REFERENCE.md** - Detailed SQL setup with verification
- **⚡ EDGE_FUNCTIONS_REFERENCE.md** - Complete functions documentation
- **🔧 ENVIRONMENT_VARIABLES.md** - All required environment variables
- **🧪 TESTING_GUIDE.md** - Step-by-step testing procedures
