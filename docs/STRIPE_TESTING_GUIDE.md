# 🧪 Stripe Testing Guide

## 🎯 **Testing Your Stripe Integration**

### **Test Environment Setup**
1. Use **test mode** in Stripe Dashboard
2. Use **test API keys** (start with `pk_test_` and `sk_test_`)
3. Use **test webhook endpoint**

### **Test Cards**
```
# Success Cards
4242424242424242  # Visa
4000056655665556  # Visa (debit)
5555555555554444  # Mastercard

# Decline Cards
4000000000000002  # Generic decline
4000000000009995  # Insufficient funds
4000000000009987  # Lost card

# 3D Secure Cards
4000002500003155  # Requires authentication
4000002760003184  # Requires authentication
```

### **Test Scenarios**

#### **1. Successful Subscription**
1. Go to `/products`
2. Click "GET GO PRO"
3. Use `4242424242424242`
4. Complete checkout
5. **Expected**: Redirect to success page, subscription active

#### **2. Failed Payment**
1. Go to `/products`
2. Click "GET GO PRO"
3. Use `4000000000000002`
4. **Expected**: Payment declined, user stays on checkout

#### **3. Subscription Cancellation**
1. Have active subscription
2. Go to customer portal
3. Cancel subscription
4. **Expected**: Subscription marked as cancelled, access continues until period end

#### **4. Webhook Testing**
1. Complete a test payment
2. Check Stripe Dashboard > Webhooks
3. **Expected**: Webhook shows "Success" status
4. Check Supabase logs for processing

### **Verification Steps**

#### **Database Checks**
```sql
-- Check customer was created
SELECT * FROM stripe_customers WHERE user_id = 'YOUR_USER_ID';

-- Check subscription was created
SELECT * FROM stripe_subscriptions WHERE customer_id = 'YOUR_CUSTOMER_ID';

-- Check user access was updated
SELECT * FROM user_access_status WHERE user_id = 'YOUR_USER_ID';
```

#### **Frontend Checks**
- [ ] Dashboard shows subscription status
- [ ] Trial countdown updates correctly
- [ ] Customer portal link works
- [ ] Subscription management functions work

## 🚨 **Common Issues**

### **"No such price"**
- **Cause**: Wrong price ID in environment variables
- **Fix**: Copy correct price ID from Stripe Dashboard

### **"Webhook signature verification failed"**
- **Cause**: Wrong webhook secret
- **Fix**: Copy correct webhook secret from Stripe

### **"Customer not found"**
- **Cause**: Database not synced with Stripe
- **Fix**: Check webhook processing, verify database tables

### **"Function not found"**
- **Cause**: Functions not deployed
- **Fix**: Run `supabase functions deploy`

## ✅ **Success Checklist**

- [ ] Test payment completes successfully
- [ ] Webhook shows "Success" in Stripe Dashboard
- [ ] Customer record created in database
- [ ] Subscription record created in database
- [ ] User access updated correctly
- [ ] Dashboard shows subscription status
- [ ] Customer portal accessible
- [ ] Cancellation flow works

## 🎉 **Ready for Production**

When all tests pass:
1. Switch to **live mode** in Stripe
2. Update environment variables with **live keys**
3. Create **live webhook endpoint**
4. Test with real payment method
5. Monitor for any issues

**Your Stripe integration is production-ready! 🚀**