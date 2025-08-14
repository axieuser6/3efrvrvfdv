# ⚡ EDGE FUNCTIONS REFERENCE - COMPLETE FUNCTIONS GUIDE

## 📋 **OVERVIEW**
This document provides detailed information about all 11 Supabase Edge Functions in the Axie Studio User Management system. Each function handles specific business logic for user management, payments, and AxieStudio integration.

---

## 🗂️ **FUNCTIONS OVERVIEW**

| Function | Purpose | Trigger | Dependencies |
|----------|---------|---------|--------------|
| `axie-studio-account` | Create/delete AxieStudio accounts | User signup/deletion | AxieStudio API |
| `axie-studio-login` | Auto-login to AxieStudio | User clicks "Launch Studio" | Stored credentials |
| `cancel-subscription` | Cancel Stripe subscription | User cancels subscription | Stripe API |
| `cancel-subscription-immediate` | Immediate cancellation | Admin/emergency cancel | Stripe API |
| `create-portal-session` | Stripe customer portal | User manages subscription | Stripe API |
| `delete-user-account` | Complete account deletion | User deletes account | Multiple APIs |
| `reactivate-subscription` | Reactivate cancelled subscription | User resubscribes | Stripe API |
| `stripe-checkout` | Create checkout sessions | User purchases subscription | Stripe API |
| `stripe-webhook` | Handle Stripe events | Stripe sends webhooks | Stripe webhooks |
| `stripe-webhook-public` | Public webhook endpoint | Stripe webhook delivery | Stripe webhooks |
| `trial-cleanup` | Automated trial cleanup | Scheduled/cron job | Database cleanup |

---

## 🏗️ **DEPLOYMENT COMMANDS**

### **Deploy All Functions:**
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

### **Deploy Single Function:**
```bash
supabase functions deploy function-name
```

### **View Function Logs:**
```bash
supabase functions logs function-name
```

---

## 🔧 **FUNCTION DETAILS**

### **1. axie-studio-account**
**Purpose:** Creates and deletes AxieStudio user accounts

**Endpoints:**
- `POST /functions/v1/axie-studio-account`

**Request Body:**
```json
{
  "action": "create" | "delete",
  "email": "user@example.com",
  "password": "secure-password"
}
```

**Environment Variables:**
- `AXIESTUDIO_APP_URL` - AxieStudio application URL
- `AXIESTUDIO_USERNAME` - Admin username for API access
- `AXIESTUDIO_PASSWORD` - Admin password for API access

**Process Flow:**
1. Login to AxieStudio with admin credentials
2. Create API key for user management
3. Create/delete user account in AxieStudio
4. Store credentials in `axie_studio_credentials` table

---

### **2. axie-studio-login**
**Purpose:** Provides auto-login functionality to AxieStudio

**Endpoints:**
- `POST /functions/v1/axie-studio-login`

**Headers:**
```
Authorization: Bearer <supabase-jwt-token>
```

**Response:**
```json
{
  "success": true,
  "access_token": "AXIESTUDIO_JWT_TOKEN",
  "login_url": "https://YOUR_AXIESTUDIO_DOMAIN.com/login?token=..."
}
```

**Process Flow:**
1. Verify Supabase user authentication
2. Retrieve stored AxieStudio credentials
3. Login to AxieStudio API
4. Return access token for frontend

---

### **3. stripe-checkout**
**Purpose:** Creates Stripe checkout sessions for subscriptions

**Endpoints:**
- `POST /functions/v1/stripe-checkout`

**Request Body:**
```json
{
  "price_id": "price_YOUR_PRICE_ID",
  "mode": "subscription",
  "success_url": "https://YOUR_DOMAIN.com/success",
  "cancel_url": "https://YOUR_DOMAIN.com/cancel"
}
```

**Environment Variables:**
- `STRIPE_SECRET_KEY` - Stripe secret key

**Process Flow:**
1. Verify user authentication
2. Create or retrieve Stripe customer
3. Create checkout session
4. Return checkout URL

---

### **4. stripe-webhook & stripe-webhook-public**
**Purpose:** Handle Stripe webhook events for subscription changes

**Endpoints:**
- `POST /functions/v1/stripe-webhook`
- `POST /functions/v1/stripe-webhook-public`

**Webhook Events Handled:**
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_succeeded`
- `invoice.payment_failed`

**Environment Variables:**
- `STRIPE_WEBHOOK_SECRET` - Webhook endpoint secret

**Process Flow:**
1. Verify webhook signature
2. Parse Stripe event
3. Update database based on event type
4. Update user access and trial status

---

### **5. delete-user-account**
**Purpose:** Complete account deletion with trial abuse prevention

**Endpoints:**
- `POST /functions/v1/delete-user-account`

**Headers:**
```
Authorization: Bearer <supabase-jwt-token>
```

**Process Flow:**
1. Verify user authentication
2. Call `delete_user_immediately()` SQL function
3. Delete AxieStudio account
4. Cancel Stripe subscriptions
5. Delete Supabase auth user
6. Clean up all user data

---

### **6. trial-cleanup**
**Purpose:** Automated cleanup of expired trials

**Endpoints:**
- `POST /functions/v1/trial-cleanup`

**Trigger:** Scheduled cron job or manual execution

**Process Flow:**
1. Protect paying customers (safety check)
2. Find expired trial users
3. Delete AxieStudio accounts
4. Remove user access
5. Schedule account deletion

---

### **7. cancel-subscription & cancel-subscription-immediate**
**Purpose:** Cancel Stripe subscriptions with different timing

**Endpoints:**
- `POST /functions/v1/cancel-subscription`
- `POST /functions/v1/cancel-subscription-immediate`

**Request Body:**
```json
{
  "subscription_id": "sub_YOUR_SUBSCRIPTION_ID"
}
```

**Difference:**
- `cancel-subscription`: Cancels at period end
- `cancel-subscription-immediate`: Cancels immediately

---

### **8. reactivate-subscription**
**Purpose:** Reactivate cancelled subscriptions

**Endpoints:**
- `POST /functions/v1/reactivate-subscription`

**Request Body:**
```json
{
  "subscription_id": "sub_YOUR_SUBSCRIPTION_ID"
}
```

**Process Flow:**
1. Verify user owns subscription
2. Reactivate in Stripe
3. Update database status
4. Restore user access

---

### **9. create-portal-session**
**Purpose:** Create Stripe customer portal sessions

**Endpoints:**
- `POST /functions/v1/create-portal-session`

**Request Body:**
```json
{
  "return_url": "https://YOUR_DOMAIN.com/account"
}
```

**Response:**
```json
{
  "url": "https://billing.stripe.com/session/YOUR_SESSION_ID"
}
```

---

## 🔐 **SECURITY CONSIDERATIONS**

### **Authentication:**
- All functions require valid Supabase JWT tokens
- Service role key used for admin operations
- Row-level security enforced on database operations

### **CORS Configuration:**
```typescript
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};
```

### **Environment Variables Security:**
- All sensitive data stored as Supabase secrets
- No hardcoded credentials in function code
- API keys rotated regularly

---

## 🧪 **TESTING FUNCTIONS**

### **Test Individual Function:**
```bash
# Test with curl
curl -X POST \
  https://YOUR_PROJECT_ID.supabase.co/functions/v1/FUNCTION_NAME \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

### **Test from Frontend:**
```typescript
const { data: { session } } = await supabase.auth.getSession();

const response = await fetch(
  `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/function-name`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${session.access_token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ test: 'data' })
  }
);
```

---

## 🚨 **TROUBLESHOOTING**

### **Common Issues:**

**1. Function Not Found (404)**
- Check function is deployed: `supabase functions list`
- Verify function name spelling
- Check project linking: `supabase status`

**2. Environment Variables Missing**
- List secrets: `supabase secrets list`
- Set missing secrets: `supabase secrets set KEY=value`
- Redeploy function after setting secrets

**3. Authentication Errors (401)**
- Verify JWT token is valid
- Check token expiration
- Ensure user has required permissions

**4. CORS Errors**
- Check CORS headers in function
- Verify OPTIONS method handling
- Check browser network tab for preflight requests

### **Debug Commands:**
```bash
# View function logs
supabase functions logs function-name --follow

# List all functions
supabase functions list

# Check function status
supabase status

# View secrets (names only)
supabase secrets list
```

---

## ✅ **VERIFICATION CHECKLIST**

After deploying all functions:

- [ ] All 11 functions deployed successfully
- [ ] All environment variables set
- [ ] Functions appear in Supabase dashboard
- [ ] Test endpoints return expected responses
- [ ] Authentication working correctly
- [ ] CORS headers configured properly
- [ ] Error handling working
- [ ] Logging enabled for debugging

---

**🎉 All Edge Functions are now deployed and ready for production use!**
