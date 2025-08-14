# 🔧 ENABLE EMAIL CONFIRMATION GUIDE

## 🚨 **CRITICAL ISSUE IDENTIFIED:**
Users can signup without email verification, which is a security risk and bypasses the intended flow.

## 📋 **STEPS TO FIX EMAIL CONFIRMATION:**

### **1. Enable Email Confirmation in Supabase Dashboard**

1. **Go to Supabase Dashboard:**
   - Visit: https://app.supabase.com/
   - Select your project: `axie-studio-user-management`

2. **Navigate to Authentication Settings:**
   - Click **"Authentication"** in the left sidebar
   - Click **"Settings"** tab
   - Scroll to **"User Signups"** section

3. **Enable Email Confirmation:**
   - Find **"Enable email confirmations"**
   - **Turn this ON** ✅
   - Set **"Confirm email change"** to **ON** ✅
   - Set **"Enable secure email change"** to **ON** ✅

4. **Configure Email Templates (Optional):**
   - Click **"Email Templates"** tab
   - Customize the **"Confirm signup"** template
   - Add your branding and messaging

### **2. Update Frontend to Handle Email Confirmation**

The current `AuthForm.tsx` already shows the correct message:
```typescript
setMessage({
  type: 'success',
  text: `Account created successfully! Please check your email and click the confirmation link to activate your account and start your 7-day free trial.`,
});
```

### **3. Configure Email Provider (If Needed)**

If you want custom emails instead of Supabase defaults:

1. **Go to Authentication > Settings**
2. **Scroll to "SMTP Settings"**
3. **Configure your email provider:**
   - **SMTP Host:** `smtp.your-provider.com`
   - **SMTP Port:** `587` (or `465` for SSL)
   - **SMTP User:** `your-email@domain.com`
   - **SMTP Pass:** `your-email-password`
   - **Sender Name:** `Axie Studio`
   - **Sender Email:** `noreply@axiestudio.se`

### **4. Test Email Confirmation Flow**

1. **Create a new test account**
2. **Check that signup requires email confirmation**
3. **Verify email is sent**
4. **Click confirmation link**
5. **Verify user can then login**

## 🔍 **CURRENT SETTINGS TO CHECK:**

### **Authentication > Settings > User Signups:**
- ✅ **Enable email confirmations** = ON
- ✅ **Confirm email change** = ON  
- ✅ **Enable secure email change** = ON
- ⚠️ **Allow new users to sign up** = ON (keep this)

### **Authentication > Settings > Security:**
- ✅ **Enable phone confirmations** = OFF (unless you want SMS)
- ✅ **Enable manual linking** = OFF (recommended)

## 🎯 **EXPECTED BEHAVIOR AFTER FIX:**

### **Before (BROKEN):**
1. User enters email/password
2. Account created immediately ❌
3. User can login right away ❌
4. No email verification required ❌

### **After (CORRECT):**
1. User enters email/password
2. Account created but **NOT CONFIRMED** ✅
3. Email sent with confirmation link ✅
4. User must click link to activate ✅
5. Only then can user login ✅

## 🚀 **ADDITIONAL SECURITY IMPROVEMENTS:**

### **Rate Limiting:**
- Set **"Rate limiting"** for signups
- Limit to **5 signups per hour per IP**

### **Password Requirements:**
- Minimum **8 characters**
- Require **uppercase, lowercase, number**

### **Redirect URLs:**
- Set **"Site URL"** to your production domain
- Add **"Redirect URLs"** for allowed domains

## 📝 **VERIFICATION CHECKLIST:**

- [ ] Email confirmation enabled in Supabase dashboard
- [ ] Test signup requires email verification
- [ ] Confirmation emails are being sent
- [ ] Users cannot login until email confirmed
- [ ] Trial starts only after email confirmation
- [ ] Frontend shows appropriate messages

## 🔧 **TROUBLESHOOTING:**

### **If emails aren't being sent:**
1. Check Supabase logs in Dashboard > Logs
2. Verify SMTP settings if using custom provider
3. Check spam folder
4. Test with different email providers

### **If confirmation links don't work:**
1. Check redirect URLs in auth settings
2. Verify site URL is correct
3. Check browser console for errors

## 🎯 **RESULT:**
After implementing these changes:
- ✅ **Security improved** - No unverified accounts
- ✅ **Trial abuse prevented** - Email required
- ✅ **Professional flow** - Standard email confirmation
- ✅ **Better UX** - Clear messaging about email verification
