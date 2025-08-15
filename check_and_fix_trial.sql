-- Check and fix trial data for resubscribed user
-- Run this in Supabase SQL Editor

-- 1. Check current user's trial status
SELECT 
    'CURRENT USER TRIAL STATUS' as check_type,
    u.id as user_id,
    u.email,
    u.created_at as user_created_at,
    ut.trial_start_date,
    ut.trial_end_date,
    ut.trial_status,
    CASE 
        WHEN ut.trial_end_date > now() THEN 'ACTIVE'
        ELSE 'EXPIRED'
    END as calculated_status,
    EXTRACT(days FROM (ut.trial_end_date - now()))::integer as days_remaining
FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
WHERE u.email = 'digitalspace5554@gmail.com';

-- 2. Check if user has subscription
SELECT 
    'SUBSCRIPTION STATUS' as check_type,
    s.*
FROM stripe_subscriptions s
JOIN auth.users u ON s.user_id = u.id
WHERE u.email = 'digitalspace5554@gmail.com';

-- 3. Fix missing trial if needed (for resubscribed users, mark as converted)
INSERT INTO user_trials (
    user_id,
    trial_start_date,
    trial_end_date,
    trial_status
)
SELECT
    u.id,
    u.created_at,
    u.created_at + interval '7 days',
    CASE
        WHEN EXISTS(SELECT 1 FROM stripe_subscriptions s WHERE s.user_id = u.id AND s.status = 'active')
        THEN 'converted_to_paid'::trial_status
        WHEN (u.created_at + interval '7 days') > now() THEN 'active'::trial_status
        ELSE 'expired'::trial_status
    END
FROM auth.users u
WHERE u.email = 'digitalspace5554@gmail.com'
AND NOT EXISTS (
    SELECT 1 FROM user_trials ut WHERE ut.user_id = u.id
);

-- 4. Check user_account_state
SELECT 
    'ACCOUNT STATE' as check_type,
    uas.*
FROM user_account_state uas
JOIN auth.users u ON uas.user_id = u.id
WHERE u.email = 'digitalspace5554@gmail.com';

-- 5. Fix missing account state if needed
INSERT INTO user_account_state (
    user_id,
    trial_start_date,
    trial_end_date,
    trial_days_remaining
)
SELECT 
    u.id,
    u.created_at,
    u.created_at + interval '7 days',
    CASE 
        WHEN (u.created_at + interval '7 days') > now() THEN 
            EXTRACT(days FROM ((u.created_at + interval '7 days') - now()))::integer
        ELSE 0
    END
FROM auth.users u
WHERE u.email = 'digitalspace5554@gmail.com'
AND NOT EXISTS (
    SELECT 1 FROM user_account_state uas WHERE uas.user_id = u.id
);

-- 6. Final verification
SELECT 
    'FINAL STATUS' as check_type,
    u.email,
    ut.trial_end_date,
    ut.trial_status,
    uas.trial_days_remaining,
    s.subscription_status
FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
LEFT JOIN user_account_state uas ON u.id = uas.user_id
LEFT JOIN stripe_subscriptions s ON u.id = s.user_id
WHERE u.email = 'digitalspace5554@gmail.com';
