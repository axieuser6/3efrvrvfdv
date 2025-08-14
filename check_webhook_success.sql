-- Check if the webhook successfully processed the payment
-- Run this in Supabase SQL Editor

-- Check for user14@mocksender.shop (the email from the webhook)
SELECT 
    'User Info' as type,
    u.email,
    u.id::text as value
FROM auth.users u 
WHERE u.email = 'user14@mocksender.shop'

UNION ALL

-- Check if customer was created
SELECT 
    'Customer Record' as type,
    'customer_id' as email,
    sc.customer_id as value
FROM stripe_customers sc
JOIN auth.users u ON sc.user_id = u.id
WHERE u.email = 'user14@mocksender.shop'

UNION ALL

-- Check subscription status
SELECT 
    'Subscription Status' as type,
    'status' as email,
    ss.status as value
FROM stripe_subscriptions ss
JOIN stripe_customers sc ON ss.customer_id = sc.customer_id
JOIN auth.users u ON sc.user_id = u.id
WHERE u.email = 'user14@mocksender.shop'

UNION ALL

-- Check trial status
SELECT 
    'Trial Status' as type,
    'status' as email,
    ut.trial_status as value
FROM user_trials ut
JOIN auth.users u ON ut.user_id = u.id
WHERE u.email = 'user14@mocksender.shop';

-- Also check what the frontend view shows
SELECT 
    'Frontend View' as info,
    user_id,
    customer_id,
    subscription_status,
    trial_status,
    trial_days_remaining::text
FROM stripe_user_subscriptions 
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'user14@mocksender.shop');
