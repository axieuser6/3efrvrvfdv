# 🗄️ SQL COMMANDS REFERENCE - COMPLETE DATABASE SETUP

## 📋 **OVERVIEW**
This document contains all SQL commands needed to set up the Axie Studio User Management database. Execute these commands **IN EXACT ORDER** in the Supabase SQL Editor.

---

## 🚨 **CRITICAL: EXECUTION ORDER**

**⚠️ IMPORTANT:** Run these SQL files in this exact order to avoid dependency errors:

1. **STEP 1:** `20250813160527_shy_bird.sql` - Main schema
2. **STEP 2:** `20250813172500_fix_signup_trigger.sql` - Trigger fixes  
3. **STEP 3:** `20250813230000_axie_studio_credentials.sql` - Credentials table
4. **STEP 4:** `20241213_add_immediate_deletion_functions.sql` - Deletion functions
5. **STEP 5:** `COPY_PASTE_THIS_SQL.sql` - Trial timer fix

---

## 📊 **STEP 1: MAIN DATABASE SCHEMA**
**File:** `supabase/migrations/20250813160527_shy_bird.sql`

### **What This Creates:**
- ✅ **Core Tables:** User profiles, trials, account state
- ✅ **Stripe Tables:** Customers, subscriptions, payments
- ✅ **Business Logic:** Trial management, user protection
- ✅ **Views:** Dashboard data, trial info, access status
- ✅ **Triggers:** Auto user creation, trial setup
- ✅ **Security:** Row-level security policies

### **How to Execute:**
1. Open **Supabase Dashboard** > **SQL Editor**
2. Copy **entire content** of `20250813160527_shy_bird.sql`
3. Paste into SQL Editor
4. Click **"RUN"** ▶️
5. Verify: Should see **"Success. No rows returned"**

### **Key Tables Created:**
```sql
-- Core user management
user_profiles              -- User profile data
user_trials               -- Trial tracking
user_account_state        -- Account status and access

-- Stripe integration  
stripe_customers          -- Stripe customer records
stripe_subscriptions      -- Subscription data

-- Views for easy data access
user_dashboard           -- Complete user dashboard data
user_trial_info         -- Trial status and countdown
user_access_status      -- Access permissions
```

---

## 🔧 **STEP 2: SIGNUP TRIGGER FIXES**
**File:** `supabase/migrations/20250813172500_fix_signup_trigger.sql`

### **What This Fixes:**
- ✅ **Improved Trigger:** Better user creation handling
- ✅ **Error Handling:** Prevents signup failures
- ✅ **Trial Reliability:** Ensures trial creation works

### **How to Execute:**
1. Copy content of `20250813172500_fix_signup_trigger.sql`
2. Paste into SQL Editor
3. Click **"RUN"** ▶️
4. Verify: Should see **"Success. No rows returned"**

### **Key Functions Updated:**
```sql
-- Updated trigger function
handle_new_user()         -- Improved user creation logic
```

---

## 🔐 **STEP 3: AXIESTUDIO CREDENTIALS**
**File:** `supabase/migrations/20250813230000_axie_studio_credentials.sql`

### **What This Creates:**
- ✅ **Credentials Table:** Secure AxieStudio login storage
- ✅ **Auto-Login Support:** Enables seamless AxieStudio access
- ✅ **Security Policies:** RLS for credential protection

### **How to Execute:**
1. Copy content of `20250813230000_axie_studio_credentials.sql`
2. Paste into SQL Editor
3. Click **"RUN"** ▶️
4. Verify: Should see **"Success. No rows returned"**

### **Key Tables Created:**
```sql
axie_studio_credentials   -- Stores AxieStudio login data
```

---

## 🗑️ **STEP 4: ACCOUNT DELETION FUNCTIONS**
**File:** `supabase/migrations/20241213_add_immediate_deletion_functions.sql`

### **What This Creates:**
- ✅ **Immediate Deletion:** Instant account removal
- ✅ **Data Cleanup:** Complete user data removal
- ✅ **Trial Protection:** Prevents trial abuse
- ✅ **Security Policies:** Safe deletion permissions

### **How to Execute:**
1. Copy content of `20241213_add_immediate_deletion_functions.sql`
2. Paste into SQL Editor
3. Click **"RUN"** ▶️
4. Verify: Should see **"Success. No rows returned"**

### **Key Functions Created:**
```sql
delete_user_immediately(UUID)     -- Instant account deletion
cleanup_deleted_user_data(UUID)   -- Complete data cleanup
```

---

## ⏰ **STEP 5: TRIAL TIMER FIX (CRITICAL)**
**File:** `COPY_PASTE_THIS_SQL.sql`

### **What This Fixes:**
- ✅ **Trial Dates:** Uses user creation time (not current time)
- ✅ **Accurate Timers:** Fixes countdown display
- ✅ **Existing Users:** Updates users with wrong dates

### **How to Execute:**
1. Copy content of `COPY_PASTE_THIS_SQL.sql`
2. Paste into SQL Editor
3. Click **"RUN"** ▶️
4. Verify: Should see **"Success. No rows returned"**

### **Critical Fix Applied:**
```sql
-- Updates the signup trigger to use user creation time
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Use NEW.created_at instead of NOW() for trial dates
  INSERT INTO user_trials (
    user_id,
    trial_start_date,
    trial_end_date,
    trial_status
  ) VALUES (
    NEW.id,
    NEW.created_at,                    -- ✅ FIXED: Use signup time
    NEW.created_at + INTERVAL '7 days', -- ✅ FIXED: 7 days from signup
    'active'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 🧪 **VERIFICATION COMMANDS**

### **Check All Tables Exist:**
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

**Expected Tables:**
- `axie_studio_credentials`
- `stripe_customers`
- `stripe_subscriptions`
- `user_account_state`
- `user_profiles`
- `user_trials`

### **Check All Functions Exist:**
```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
ORDER BY routine_name;
```

**Expected Functions:**
- `cleanup_deleted_user_data`
- `delete_user_immediately`
- `handle_new_user`
- `protect_paying_customers`
- `store_axie_studio_credentials`

### **Check All Views Exist:**
```sql
SELECT table_name 
FROM information_schema.views 
WHERE table_schema = 'public' 
ORDER BY table_name;
```

**Expected Views:**
- `user_access_status`
- `user_dashboard`
- `user_trial_info`

### **Test Trial Timer Fix:**
```sql
-- Check trial dates for recent users
SELECT 
  email,
  user_created,
  trial_start_date,
  trial_end_date,
  CASE 
    WHEN trial_start_date = user_created THEN '✅ CORRECT'
    ELSE '❌ STILL WRONG'
  END as start_date_status,
  CASE 
    WHEN trial_end_date = user_created + INTERVAL '7 days' THEN '✅ CORRECT'
    ELSE '❌ STILL WRONG'
  END as end_date_status
FROM user_trial_info
WHERE user_created > NOW() - INTERVAL '30 days'
ORDER BY user_created DESC;
```

---

## 🚨 **TROUBLESHOOTING**

### **Common Errors:**

**1. "relation does not exist"**
- **Cause:** Running migrations out of order
- **Fix:** Run migrations in exact order listed above

**2. "function already exists"**
- **Cause:** Re-running same migration
- **Fix:** Safe to ignore, or use `DROP FUNCTION IF EXISTS` first

**3. "permission denied"**
- **Cause:** RLS policies blocking access
- **Fix:** Verify you're running as service role

**4. "syntax error"**
- **Cause:** Copy/paste formatting issues
- **Fix:** Copy entire file content, don't select partial text

### **Verification Queries:**

**Check Migration Status:**
```sql
-- Count records in each table
SELECT 
  'user_profiles' as table_name, COUNT(*) as records FROM user_profiles
UNION ALL
SELECT 
  'user_trials' as table_name, COUNT(*) as records FROM user_trials
UNION ALL
SELECT 
  'user_account_state' as table_name, COUNT(*) as records FROM user_account_state;
```

**Check Function Permissions:**
```sql
-- Verify function permissions
SELECT 
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines 
WHERE routine_schema = 'public'
ORDER BY routine_name;
```

---

## ✅ **SUCCESS INDICATORS**

After running all SQL commands, you should have:

- [ ] **6 Tables** created successfully
- [ ] **5+ Functions** created successfully  
- [ ] **3 Views** created successfully
- [ ] **RLS Policies** enabled on all tables
- [ ] **Triggers** active for user creation
- [ ] **Trial Timer** using correct dates
- [ ] **No SQL errors** in any migration

---

## 🎯 **NEXT STEPS**

After completing all SQL setup:

1. **Deploy Edge Functions** (see main setup guide)
2. **Configure Authentication** settings
3. **Set Environment Variables** for functions
4. **Test User Signup** flow
5. **Verify Trial Timer** accuracy
6. **Test Payment Integration**

---

**🎉 Database setup complete! Your SQL foundation is ready for the Axie Studio User Management system.**
