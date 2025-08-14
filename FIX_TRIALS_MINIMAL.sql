-- 🚨 MINIMAL FIX: Only fix user_trials table (skip problematic tables)
-- This focuses on the core issue: missing trial records

-- 1. Check how many users are missing trials
SELECT 
    'USERS WITHOUT TRIALS:' as status,
    COUNT(*) as users_missing_trials
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_trials ut WHERE ut.user_id = u.id
);

-- 2. Show affected users
SELECT 
    'AFFECTED USERS:' as status,
    u.id,
    u.email,
    u.created_at,
    u.created_at + interval '7 days' as should_expire_at,
    CASE 
        WHEN (u.created_at + interval '7 days') > now() THEN 'SHOULD BE ACTIVE'
        ELSE 'SHOULD BE EXPIRED'
    END as correct_status
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_trials ut WHERE ut.user_id = u.id
)
ORDER BY u.created_at DESC;

-- 3. CREATE MISSING TRIAL RECORDS (CORE FIX)
INSERT INTO user_trials (
    user_id,
    trial_start_date,
    trial_end_date,
    trial_status
)
SELECT 
    u.id,
    u.created_at,  -- Start from actual user creation time
    u.created_at + interval '7 days',  -- End 7 days later
    CASE 
        WHEN (u.created_at + interval '7 days') > now() THEN 'active'::trial_status
        ELSE 'expired'::trial_status
    END
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_trials ut WHERE ut.user_id = u.id
)
ON CONFLICT (user_id) DO NOTHING;

-- 4. FIX EXISTING INCORRECT TRIAL DATES
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

-- 5. VERIFICATION: Show all users and their trial status
SELECT 
    'VERIFICATION - TRIALS FIXED:' as status,
    u.id,
    u.email,
    u.created_at as user_created,
    ut.trial_start_date,
    ut.trial_end_date,
    ut.trial_status,
    
    -- Calculate exact remaining time
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
    END as accuracy_status

FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
ORDER BY u.created_at DESC;

-- 6. SUMMARY
SELECT 
    'SUMMARY:' as status,
    COUNT(*) as total_users,
    COUNT(ut.user_id) as users_with_trials,
    COUNT(*) - COUNT(ut.user_id) as users_still_missing_trials,
    COUNT(CASE WHEN ut.trial_status = 'active' THEN 1 END) as active_trials,
    COUNT(CASE WHEN ut.trial_status = 'expired' THEN 1 END) as expired_trials
FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id;

-- 7. CHECK STEFAN'S USER SPECIFICALLY
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
    END as stefan_timer_should_show,
    
    -- Account age for reference
    EXTRACT(days FROM (now() - u.created_at))::integer || ' days, ' ||
    EXTRACT(hours FROM (now() - u.created_at))::integer || ' hours old' as account_age
    
FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
WHERE u.email = 'digitalspace5554@gmail.com';
