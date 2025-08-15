# ✅ Stripe Integration Setup Checklist

## 🎯 **Quick Setup Guide**

Your Stripe integration is already built! Just follow these steps to configure it:

### **□ Step 1: Create Stripe Account**
- [ ] Sign up at [stripe.com](https://stripe.com)
- [ ] Complete business verification
- [ ] Access Stripe Dashboard

### **□ Step 2: Create Products**
- [ ] Go to **Products** in Stripe Dashboard
- [ ] Create "Axie Studio Pro" product
- [ ] Set pricing (e.g., $45/month)
- [ ] Copy the **Price ID** (starts with `price_`)

### **□ Step 3: Get API Keys**
- [ ] Go to **Developers** > **API Keys**
- [ ] Copy **Publishable Key** (`pk_test_...`)
- [ ] Copy **Secret Key** (`sk_test_...`)

### **□ Step 4: Configure Webhooks**
- [ ] Go to **Developers** > **Webhooks**
- [ ] Add endpoint: `https://YOUR_PROJECT_ID.supabase.co/functions/v1/stripe-webhook-public`
- [ ] Select events: `checkout.session.completed`, `customer.subscription.*`
- [ ] Copy **Webhook Secret** (`whsec_...`)

### **□ Step 5: Update Environment Variables**

#### **Frontend (.env):**
```env
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_YOUR_KEY_HERE
VITE_STRIPE_PRO_PRICE_ID=price_YOUR_PRICE_ID_HERE
```

#### **Supabase Functions:**
```bash
supabase secrets set STRIPE_SECRET_KEY=sk_test_YOUR_SECRET_KEY
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_YOUR_WEBHOOK_SECRET
```

### **□ Step 6: Update Product Config**
- [ ] Edit `src/stripe-config.ts` with your actual product details
- [ ] Replace placeholder price IDs with real ones

### **□ Step 7: Test Integration**
- [ ] Go to `/products` page
- [ ] Click "GET GO PRO" button
- [ ] Complete test checkout
- [ ] Verify webhook processes payment
- [ ] Check subscription in dashboard

## 🧪 **Test Cards**

Use these for testing:
- **Success**: `4242424242424242`
- **Decline**: `4000000000000002`
- **3D Secure**: `4000002500003155`

## ✅ **Success Indicators**

When working correctly:
- ✅ Products page shows your pricing
- ✅ Checkout opens Stripe payment form
- ✅ Successful payments redirect to success page
- ✅ Dashboard shows subscription status
- ✅ Customer portal allows subscription management

## 🚀 **Your Stripe Features**

Your app includes:
- **7-day free trials** with automatic billing
- **Subscription management** (cancel/reactivate)
- **Customer portal** for self-service
- **Real-time webhook processing**
- **Trial abuse prevention**
- **Multiple payment modes**

**Ready to accept payments! 💳**