-- 🚀 SETUP ADMIN ACCOUNT WITH PRO SUBSCRIPTION + INFINITE TIME
-- Run this in Supabase SQL Editor

-- 1. VERIFY ADMIN ACCOUNT EXISTS
SELECT 
    'ADMIN ACCOUNT CHECK' as status,
    u.id,
    u.email,
    u.created_at,
    up.full_name
FROM auth.users u
LEFT JOIN user_profiles up ON u.id = up.id
WHERE u.email = 'stefanjohnmiranda5@gmail.com';

-- 2. CREATE/UPDATE USER PROFILE FOR ADMIN
INSERT INTO user_profiles (id, email, full_name, created_at, updated_at)
SELECT 
    u.id,
    u.email,
    'Stefan John Miranda (Admin)',
    u.created_at,
    now()
FROM auth.users u
WHERE u.email = 'stefanjohnmiranda5@gmail.com'
ON CONFLICT (id) DO UPDATE SET
    full_name = 'Stefan John Miranda (Admin)',
    updated_at = now();

-- 3. CREATE STRIPE CUSTOMER FOR ADMIN (if not exists)
INSERT INTO stripe_customers (user_id, customer_id, email, created_at, updated_at)
SELECT 
    u.id,
    'cus_admin_' || u.id,  -- Fake customer ID for admin
    u.email,
    now(),
    now()
FROM auth.users u
WHERE u.email = 'stefanjohnmiranda5@gmail.com'
ON CONFLICT (user_id) DO UPDATE SET
    updated_at = now();

-- 4. CREATE PRO SUBSCRIPTION FOR ADMIN WITH INFINITE TIME
INSERT INTO stripe_subscriptions (
    user_id,
    customer_id,
    subscription_id,
    status,
    price_id,
    current_period_start,
    current_period_end,
    cancel_at_period_end,
    created_at,
    updated_at
)
SELECT 
    u.id,
    'cus_admin_' || u.id,
    'sub_admin_pro_' || u.id,  -- Fake subscription ID for admin
    'active',
    'price_1Rv4rDBacFXEnBmNDMrhMqOH',  -- PRO price ID
    extract(epoch from now())::bigint,
    extract(epoch from (now() + interval '100 years'))::bigint,  -- Infinite time (100 years)
    false,
    now(),
    now()
FROM auth.users u
WHERE u.email = 'stefanjohnmiranda5@gmail.com'
ON CONFLICT (user_id) DO UPDATE SET
    status = 'active',
    price_id = 'price_1Rv4rDBacFXEnBmNDMrhMqOH',
    current_period_start = extract(epoch from now())::bigint,
    current_period_end = extract(epoch from (now() + interval '100 years'))::bigint,
    cancel_at_period_end = false,
    updated_at = now();

-- 5. CREATE/UPDATE USER ACCOUNT STATE FOR ADMIN
INSERT INTO user_account_state (
    user_id,
    account_status,
    has_access,
    access_level,
    trial_start_date,
    trial_end_date,
    trial_days_remaining,
    stripe_customer_id,
    stripe_subscription_id,
    subscription_status,
    current_period_end,
    axie_studio_status,
    created_at,
    updated_at
)
SELECT 
    u.id,
    'premium_active',
    true,
    'pro',
    u.created_at,
    u.created_at + interval '7 days',  -- Trial completed
    0,  -- No trial days remaining
    'cus_admin_' || u.id,
    'sub_admin_pro_' || u.id,
    'active',
    now() + interval '100 years',  -- Infinite subscription
    'active',
    now(),
    now()
FROM auth.users u
WHERE u.email = 'stefanjohnmiranda5@gmail.com'
ON CONFLICT (user_id) DO UPDATE SET
    account_status = 'premium_active',
    has_access = true,
    access_level = 'pro',
    trial_days_remaining = 0,
    stripe_customer_id = 'cus_admin_' || user_account_state.user_id,
    stripe_subscription_id = 'sub_admin_pro_' || user_account_state.user_id,
    subscription_status = 'active',
    current_period_end = now() + interval '100 years',
    axie_studio_status = 'active',
    updated_at = now();

-- 6. CREATE/UPDATE TRIAL RECORD FOR ADMIN (mark as converted to paid)
INSERT INTO user_trials (
    user_id,
    trial_start_date,
    trial_end_date,
    trial_status,
    created_at,
    updated_at
)
SELECT 
    u.id,
    u.created_at,
    u.created_at + interval '7 days',
    'converted_to_paid',
    now(),
    now()
FROM auth.users u
WHERE u.email = 'stefanjohnmiranda5@gmail.com'
ON CONFLICT (user_id) DO UPDATE SET
    trial_status = 'converted_to_paid',
    updated_at = now();

-- 7. VERIFY ADMIN SETUP IS COMPLETE
SELECT 
    'ADMIN SETUP VERIFICATION' as status,
    u.email,
    uas.account_status,
    uas.has_access,
    uas.access_level,
    uas.subscription_status,
    ss.status as stripe_status,
    ss.price_id,
    to_timestamp(ss.current_period_end) as subscription_expires,
    ut.trial_status
FROM auth.users u
LEFT JOIN user_account_state uas ON u.id = uas.user_id
LEFT JOIN stripe_subscriptions ss ON u.id = ss.user_id
LEFT JOIN user_trials ut ON u.id = ut.user_id
WHERE u.email = 'stefanjohnmiranda5@gmail.com';

-- 8. FINAL SUCCESS MESSAGE
SELECT '✅ ADMIN ACCOUNT SETUP COMPLETE!' as message,
       'stefanjohnmiranda5@gmail.com now has PRO subscription with infinite time' as details;
