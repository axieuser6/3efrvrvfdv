# 🚀 Complete Stripe Integration Guide

## 📋 **Current Status**
Your app already has Stripe integration implemented! You just need to configure it with your actual Stripe credentials.

## 🔧 **What's Already Implemented**

### ✅ **Frontend Integration**
- Stripe checkout sessions
- Product cards with pricing
- Subscription status display
- Customer portal access
- Payment success/cancel handling

### ✅ **Backend Integration**
- `stripe-checkout` function - Creates checkout sessions
- `stripe-webhook` function - Handles payment events
- `stripe-webhook-public` function - Public webhook endpoint
- `cancel-subscription` function - Cancels subscriptions
- `create-portal-session` function - Customer portal access
- `reactivate-subscription` function - Reactivates cancelled subs

### ✅ **Database Integration**
- `stripe_customers` table - Customer records
- `stripe_subscriptions` table - Subscription data
- `stripe_orders` table - Order tracking
- Views for easy data access
- Automated webhook processing

## 🎯 **Setup Steps**

### **Step 1: Create Stripe Account**
1. Go to [stripe.com](https://stripe.com) and create an account
2. Complete business verification if needed
3. Navigate to the Stripe Dashboard

### **Step 2: Create Products**
1. Go to **Products** in Stripe Dashboard
2. Click **"Add Product"**
3. Create your subscription products:

**Example Pro Product:**
- Name: "Axie Studio Pro"
- Description: "Advanced AI workflow platform"
- Pricing: $45/month (or your preferred price)
- Billing: Recurring monthly
- Currency: USD (or your preferred currency)

4. **Copy the Price ID** (starts with `price_`) - you'll need this!

### **Step 3: Get API Keys**
1. Go to **Developers** > **API Keys**
2. Copy these keys:
   - **Publishable Key** (starts with `pk_test_` or `pk_live_`)
   - **Secret Key** (starts with `sk_test_` or `sk_live_`)

### **Step 4: Set Up Webhooks**
1. Go to **Developers** > **Webhooks**
2. Click **"Add endpoint"**
3. **Endpoint URL**: `https://YOUR_PROJECT_ID.supabase.co/functions/v1/stripe-webhook-public`
4. **Events to send**:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
5. Click **"Add endpoint"**
6. **Copy the Webhook Secret** (starts with `whsec_`)

### **Step 5: Configure Environment Variables**

#### **Frontend (.env file):**
```env
# Replace these with your actual Stripe values
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_ACTUAL_PUBLISHABLE_KEY
VITE_STRIPE_PRO_PRICE_ID=price_YOUR_ACTUAL_PRICE_ID
VITE_STRIPE_PRO_PRODUCT_ID=prod_YOUR_ACTUAL_PRODUCT_ID
```

#### **Supabase Functions (via CLI):**
```bash
# Set Stripe secrets for your functions
supabase secrets set STRIPE_SECRET_KEY=sk_test_YOUR_ACTUAL_SECRET_KEY
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_YOUR_ACTUAL_WEBHOOK_SECRET
```

### **Step 6: Update Product Configuration**
Update your `src/stripe-config.ts` with your actual product details:

```typescript
export const stripeProducts: StripeProduct[] = [
  {
    id: 'trial_product',
    priceId: 'trial_price',
    name: '7-Day Free Trial',
    description: 'Get started with full access to AI workflows',
    mode: 'subscription',
    price: 0.00,
  },
  {
    id: 'YOUR_ACTUAL_PRODUCT_ID', // Replace with your Stripe product ID
    priceId: 'YOUR_ACTUAL_PRICE_ID', // Replace with your Stripe price ID
    name: 'Axie Studio Pro',
    description: 'Advanced AI workflows with unlimited access',
    mode: 'subscription',
    price: 45.00, // Your actual price
  },
];
```

## 🧪 **Testing Your Integration**

### **Test Mode (Recommended First)**
1. Use **test keys** (start with `pk_test_` and `sk_test_`)
2. Use Stripe's test card numbers:
   - Success: `4242424242424242`
   - Decline: `4000000000000002`

### **Test the Flow**
1. Go to `/products` in your app
2. Click "GET GO PRO" button
3. Complete checkout with test card
4. Verify webhook processes payment
5. Check subscription appears in dashboard

### **Verify Webhooks**
1. Go to Stripe Dashboard > Webhooks
2. Check your endpoint shows "Success" status
3. View webhook logs for any errors

## 🔍 **Troubleshooting**

### **Common Issues:**

**1. "No such price"**
- Check your `VITE_STRIPE_PRO_PRICE_ID` matches Stripe
- Ensure you're using the Price ID, not Product ID

**2. "Webhook signature verification failed"**
- Check your `STRIPE_WEBHOOK_SECRET` is correct
- Ensure webhook endpoint URL is correct

**3. "Customer not found"**
- Check user signup flow creates customer records
- Verify database tables exist

**4. "Function not found"**
- Deploy functions: `supabase functions deploy`
- Check function logs: `supabase functions logs stripe-checkout`

## 🎉 **Success Indicators**

When everything is working:
- ✅ Products page shows your actual pricing
- ✅ Checkout redirects to Stripe payment page
- ✅ Successful payments redirect to success page
- ✅ Subscription status updates in dashboard
- ✅ Webhooks show "Success" in Stripe dashboard
- ✅ Customer portal allows subscription management

## 🚀 **Going Live**

### **Switch to Live Mode:**
1. Replace test keys with live keys (`pk_live_`, `sk_live_`)
2. Create live webhook endpoint
3. Test with real payment methods
4. Monitor for any issues

### **Production Checklist:**
- [ ] Live Stripe keys configured
- [ ] Webhook endpoint verified in live mode
- [ ] Products created in live mode
- [ ] Test transactions completed successfully
- [ ] Customer portal working
- [ ] Subscription management functional

## 💡 **Your Stripe Integration Features**

Your app includes these advanced Stripe features:
- **7-day free trials** with automatic conversion
- **Subscription management** with cancel/reactivate
- **Customer portal** for self-service
- **Webhook automation** for real-time updates
- **Trial abuse prevention** with account tracking
- **Multiple payment modes** (subscription and one-time)

**Your Stripe integration is enterprise-ready! Just add your credentials and you're live!** 🎯