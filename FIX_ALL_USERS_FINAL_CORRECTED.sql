-- 🚨 FINAL CORRECTED VERSION: CREATE MISSING TRIALS FOR ALL USERS
-- Fixed to handle foreign key constraints properly

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

-- 3. CREATE MISSING USER PROFILES FIRST (to satisfy foreign key constraints)
INSERT INTO user_profiles (
    user_id,
    email,
    created_at,
    updated_at
)
SELECT 
    u.id,
    u.email,
    u.created_at,
    now()
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_profiles up WHERE up.user_id = u.id
)
ON CONFLICT (user_id) DO NOTHING;

-- 4. CREATE MISSING TRIAL RECORDS FOR ALL USERS
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

-- 5. CREATE OR UPDATE USER_ACCOUNT_STATE RECORDS
-- Now that user_profiles exist, this should work
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
    GREATEST(0, EXTRACT(days FROM ((u.created_at + interval '7 days') - now()))::integer)
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM user_account_state uas WHERE uas.user_id = u.id
)
AND EXISTS (
    SELECT 1 FROM user_profiles up WHERE up.user_id = u.id
)
ON CONFLICT (user_id) DO UPDATE SET
    trial_start_date = EXCLUDED.trial_start_date,
    trial_end_date = EXCLUDED.trial_end_date,
    trial_days_remaining = EXCLUDED.trial_days_remaining,
    updated_at = now();

-- 6. FIX ANY EXISTING INCORRECT TRIAL DATES
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

-- 7. UPDATE USER_ACCOUNT_STATE TO MATCH (only for users with profiles)
UPDATE user_account_state 
SET 
    trial_start_date = (SELECT created_at FROM auth.users WHERE id = user_account_state.user_id),
    trial_end_date = (SELECT created_at + interval '7 days' FROM auth.users WHERE id = user_account_state.user_id),
    trial_days_remaining = GREATEST(0, EXTRACT(days FROM (((SELECT created_at FROM auth.users WHERE id = user_account_state.user_id) + interval '7 days') - now()))::integer),
    updated_at = now()
WHERE EXISTS (
    SELECT 1 FROM user_profiles up WHERE up.user_id = user_account_state.user_id
)
AND (
    trial_start_date != (SELECT created_at FROM auth.users WHERE id = user_account_state.user_id)
    OR trial_end_date != (SELECT created_at + interval '7 days' FROM auth.users WHERE id = user_account_state.user_id)
);

-- 8. VERIFICATION: Show all users and their trial status after fix
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
    
    -- Check if user_profile exists
    CASE 
        WHEN up.user_id IS NOT NULL THEN '✅ HAS PROFILE'
        ELSE '❌ MISSING PROFILE'
    END as profile_status,
    
    -- Account age
    EXTRACT(days FROM (now() - u.created_at))::integer || ' days old' as account_age

FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
LEFT JOIN user_profiles up ON u.id = up.user_id
ORDER BY u.created_at DESC;

-- 9. SUMMARY STATISTICS
SELECT 
    'SUMMARY:' as status,
    COUNT(*) as total_users,
    COUNT(ut.user_id) as users_with_trials,
    COUNT(up.user_id) as users_with_profiles,
    COUNT(uas.user_id) as users_with_account_state,
    COUNT(*) - COUNT(ut.user_id) as users_still_missing_trials,
    COUNT(CASE WHEN ut.trial_status = 'active' THEN 1 END) as active_trials,
    COUNT(CASE WHEN ut.trial_status = 'expired' THEN 1 END) as expired_trials
FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
LEFT JOIN user_profiles up ON u.id = up.user_id
LEFT JOIN user_account_state uas ON u.id = uas.user_id;

-- 10. CHECK SPECIFIC USER (digitalspace5554@gmail.com)
SELECT 
    'STEFAN USER CHECK:' as status,
    u.email,
    u.created_at,
    ut.trial_start_date,
    ut.trial_end_date,
    ut.trial_status,
    CASE 
        WHEN up.user_id IS NOT NULL THEN '✅ HAS PROFILE'
        ELSE '❌ MISSING PROFILE'
    END as profile_status,
    CASE 
        WHEN uas.user_id IS NOT NULL THEN '✅ HAS ACCOUNT STATE'
        ELSE '❌ MISSING ACCOUNT STATE'
    END as account_state_status,
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
LEFT JOIN user_profiles up ON u.id = up.user_id
LEFT JOIN user_account_state uas ON u.id = uas.user_id
WHERE u.email = 'digitalspace5554@gmail.com';
