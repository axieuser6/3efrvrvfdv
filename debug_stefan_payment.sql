-- Debug Stefan's payment processing
-- Run this in Supabase SQL Editor

-- 1. Find Stefan's user ID
SELECT
    id as user_id,
    email,
    created_at
FROM auth.users
WHERE email = 'stefan@mocksender.shop';

-- 2. Check if Stripe customer exists
SELECT
    user_id,
    customer_id,
    created_at
FROM stripe_customers
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop');

-- 3. Check subscription record
SELECT
    customer_id,
    subscription_id,
    status,
    price_id,
    current_period_start,
    current_period_end,
    created_at,
    updated_at
FROM stripe_subscriptions
WHERE customer_id = (
    SELECT customer_id
    FROM stripe_customers
    WHERE user_id = (SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop')
);

-- 4. Check trial status
SELECT
    user_id,
    trial_status,
    trial_start_date,
    trial_end_date,
    deletion_scheduled_at,
    created_at,
    updated_at
FROM user_trials
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop');

-- 5. Check what the view shows (this is what the frontend uses)
SELECT
    user_id,
    customer_id,
    subscription_id,
    subscription_status,
    price_id,
    current_period_start,
    current_period_end,
    trial_status,
    trial_days_remaining
FROM stripe_user_subscriptions
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop');
