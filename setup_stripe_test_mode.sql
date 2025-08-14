-- Commands to switch to Stripe test mode for safe testing
-- Run these in your terminal to use test keys instead of live keys

-- Test Secret Key (starts with sk_test_)
-- supabase secrets set STRIPE_SECRET_KEY=sk_test_your_test_key_here

-- Test Webhook Secret (you'll get this from Stripe Dashboard → Webhooks → Test mode)
-- supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_test_your_webhook_secret_here

-- Then update your .env file with test publishable key:
-- VITE_STRIPE_PUBLISHABLE_KEY=pk_test_your_test_publishable_key_here

-- Test Product/Price IDs (create these in Stripe Dashboard → Test mode)
-- VITE_STRIPE_PRO_PRICE_ID=price_test_your_test_price_id_here
