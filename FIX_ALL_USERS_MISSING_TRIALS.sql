-- 🚨 COMPREHENSIVE FIX: CREATE MISSING TRIALS FOR ALL USERS
-- This will fix the timer issue for ALL users who are missing trial records

-- 1. First, let's see how many users are affected
SELECT 
    'USERS WITHOUT TRIALS:' as status,
    COUNT(*) as users_missing_trials
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_trials ut WHERE ut.user_id = u.id
);

-- 2. Show which users are missing trials
SELECT 
    'AFFECTED USERS:' as status,
    u.id,
    u.email,
    u.created_at,
    u.created_at + interval '7 days' as should_expire_at,
    CASE 
        WHEN (u.created_at + interval '7 days') > now() THEN 'ACTIVE TRIAL'
        ELSE 'EXPIRED TRIAL'
    END as trial_status_should_be
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_trials ut WHERE ut.user_id = u.id
)
ORDER BY u.created_at DESC;

-- 3. CREATE MISSING TRIAL RECORDS FOR ALL USERS
-- This creates trials based on each user's actual creation time
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
    u.created_at,  -- Start from actual user creation time
    u.created_at + interval '7 days',  -- End 7 days later
    CASE
        WHEN (u.created_at + interval '7 days') > now() THEN 'active'::trial_status
        ELSE 'expired'::trial_status
    END,
    now(),
    now()
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_trials ut WHERE ut.user_id = u.id
);

-- 4. CREATE MISSING USER_ACCOUNT_STATE RECORDS FOR ALL USERS
INSERT INTO user_account_state (
    user_id,
    trial_start_date,
    trial_end_date,
    trial_days_remaining,
    trial_status,
    created_at,
    updated_at
)
SELECT 
    u.id,
    u.created_at,
    u.created_at + interval '7 days',
    GREATEST(0, EXTRACT(days FROM ((u.created_at + interval '7 days') - now()))::integer),
    CASE
        WHEN (u.created_at + interval '7 days') > now() THEN 'active'::trial_status
        ELSE 'expired'::trial_status
    END,
    now(),
    now()
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_account_state uas WHERE uas.user_id = u.id
);

-- 5. ALSO FIX ANY EXISTING INCORRECT TRIAL DATES
-- Update trials that don't match user creation time
UPDATE user_trials 
SET 
    trial_start_date = (SELECT created_at FROM auth.users WHERE id = user_trials.user_id),
    trial_end_date = (SELECT created_at + interval '7 days' FROM auth.users WHERE id = user_trials.user_id),
    trial_status = CASE
        WHEN (SELECT created_at + interval '7 days' FROM auth.users WHERE id = user_trials.user_id) > now() THEN 'active'::trial_status
        ELSE 'expired'::trial_status
    END,
    updated_at = now()
WHERE trial_start_date != (SELECT created_at FROM auth.users WHERE id = user_trials.user_id)
   OR trial_end_date != (SELECT created_at + interval '7 days' FROM auth.users WHERE id = user_trials.user_id);

-- 6. UPDATE USER_ACCOUNT_STATE TO MATCH
UPDATE user_account_state 
SET 
    trial_start_date = (SELECT created_at FROM auth.users WHERE id = user_account_state.user_id),
    trial_end_date = (SELECT created_at + interval '7 days' FROM auth.users WHERE id = user_account_state.user_id),
    trial_days_remaining = GREATEST(0, EXTRACT(days FROM (((SELECT created_at FROM auth.users WHERE id = user_account_state.user_id) + interval '7 days') - now()))::integer),
    trial_status = CASE
        WHEN (SELECT created_at + interval '7 days' FROM auth.users WHERE id = user_account_state.user_id) > now() THEN 'active'::trial_status
        ELSE 'expired'::trial_status
    END,
    updated_at = now()
WHERE trial_start_date != (SELECT created_at FROM auth.users WHERE id = user_account_state.user_id)
   OR trial_end_date != (SELECT created_at + interval '7 days' FROM auth.users WHERE id = user_account_state.user_id);

-- 7. VERIFICATION: Show all users and their trial status after fix
SELECT 
    'VERIFICATION - ALL USERS FIXED:' as status,
    u.id,
    u.email,
    u.created_at as user_created,
    ut.trial_start_date,
    ut.trial_end_date,
    ut.trial_status,
    
    -- Calculate exact remaining time for each user
    CASE 
        WHEN ut.trial_end_date > now() THEN 
            EXTRACT(days FROM (ut.trial_end_date - now()))::integer || 'd ' ||
            EXTRACT(hours FROM (ut.trial_end_date - now()))::integer || 'h ' ||
            EXTRACT(minutes FROM (ut.trial_end_date - now()))::integer || 'm ' ||
            EXTRACT(seconds FROM (ut.trial_end_date - now()))::integer || 's'
        ELSE 'EXPIRED'
    END as timer_display,
    
    -- Verify correctness
    CASE 
        WHEN ut.trial_start_date = u.created_at AND 
             ut.trial_end_date = u.created_at + interval '7 days' THEN '✅ CORRECT'
        ELSE '❌ STILL WRONG'
    END as accuracy_status,
    
    -- Account age
    EXTRACT(days FROM (now() - u.created_at))::integer || ' days old' as account_age

FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
ORDER BY u.created_at DESC;

-- 8. SUMMARY STATISTICS
SELECT 
    'SUMMARY:' as status,
    COUNT(*) as total_users,
    COUNT(ut.user_id) as users_with_trials,
    COUNT(*) - COUNT(ut.user_id) as users_still_missing_trials,
    COUNT(CASE WHEN ut.trial_status = 'active' THEN 1 END) as active_trials,
    COUNT(CASE WHEN ut.trial_status = 'expired' THEN 1 END) as expired_trials
FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id;

-- 9. CHECK SPECIFIC USER (digitalspace5554@gmail.com)
SELECT 
    'STEFAN USER CHECK:' as status,
    u.email,
    u.created_at,
    ut.trial_start_date,
    ut.trial_end_date,
    ut.trial_status,
    CASE 
        WHEN ut.trial_end_date > now() THEN 
            EXTRACT(days FROM (ut.trial_end_date - now()))::integer || 'd ' ||
            EXTRACT(hours FROM (ut.trial_end_date - now()))::integer || 'h ' ||
            EXTRACT(minutes FROM (ut.trial_end_date - now()))::integer || 'm ' ||
            EXTRACT(seconds FROM (ut.trial_end_date - now()))::integer || 's'
        ELSE 'EXPIRED'
    END as stefan_timer_should_show
FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
WHERE u.email = 'digitalspace5554@gmail.com';
