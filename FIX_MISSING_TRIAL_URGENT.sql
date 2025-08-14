-- 🚨 URGENT FIX: CREATE MISSING TRIAL FOR digitalspace5554@gmail.com
-- This user has NO trial record, which is why the timer shows EXPIRED

-- 1. First, let's verify the user exists and get their creation time
SELECT 
    'USER INFO:' as status,
    id,
    email,
    created_at,
    created_at + interval '7 days' as should_expire_at
FROM auth.users 
WHERE email = 'digitalspace5554@gmail.com';

-- 2. Check if trial record exists (should be empty)
SELECT 
    'CURRENT TRIAL STATUS:' as status,
    COUNT(*) as trial_records_found
FROM user_trials 
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'digitalspace5554@gmail.com');

-- 3. CREATE THE MISSING TRIAL RECORD
-- This will create a 7-day trial starting from the user's actual creation time
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
    'active',
    now(),
    now()
FROM auth.users u
WHERE u.email = 'digitalspace5554@gmail.com'
AND NOT EXISTS (
    SELECT 1 FROM user_trials ut WHERE ut.user_id = u.id
);

-- 4. Also create user_account_state record if missing
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
        WHEN (u.created_at + interval '7 days') > now() THEN 'active'
        ELSE 'expired'
    END,
    now(),
    now()
FROM auth.users u
WHERE u.email = 'digitalspace5554@gmail.com'
AND NOT EXISTS (
    SELECT 1 FROM user_account_state uas WHERE uas.user_id = u.id
);

-- 5. Verify the fix worked
SELECT 
    'VERIFICATION - TRIAL CREATED:' as status,
    u.id,
    u.email,
    u.created_at as user_created,
    ut.trial_start_date,
    ut.trial_end_date,
    ut.trial_status,
    
    -- Calculate exact remaining time
    CASE 
        WHEN ut.trial_end_date > now() THEN 
            EXTRACT(days FROM (ut.trial_end_date - now()))::integer || ' days, ' ||
            EXTRACT(hours FROM (ut.trial_end_date - now()))::integer || ' hours, ' ||
            EXTRACT(minutes FROM (ut.trial_end_date - now()))::integer || ' minutes, ' ||
            EXTRACT(seconds FROM (ut.trial_end_date - now()))::integer || ' seconds'
        ELSE 'EXPIRED'
    END as exact_time_remaining,
    
    -- Verify correctness
    CASE 
        WHEN ut.trial_start_date = u.created_at AND 
             ut.trial_end_date = u.created_at + interval '7 days' THEN '✅ CORRECT'
        ELSE '❌ STILL WRONG'
    END as accuracy_status

FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
WHERE u.email = 'digitalspace5554@gmail.com';

-- 6. Also verify user_account_state
SELECT 
    'VERIFICATION - ACCOUNT STATE:' as status,
    u.email,
    uas.trial_start_date,
    uas.trial_end_date,
    uas.trial_days_remaining,
    uas.trial_status
FROM auth.users u
LEFT JOIN user_account_state uas ON u.id = uas.user_id
WHERE u.email = 'digitalspace5554@gmail.com';

-- 7. Calculate what the timer should show right now
SELECT 
    'TIMER SHOULD SHOW:' as status,
    u.email,
    u.created_at as account_created,
    u.created_at + interval '7 days' as trial_expires,
    
    -- Exact countdown format
    CASE 
        WHEN (u.created_at + interval '7 days') > now() THEN 
            EXTRACT(days FROM ((u.created_at + interval '7 days') - now()))::integer || 'd ' ||
            EXTRACT(hours FROM ((u.created_at + interval '7 days') - now()))::integer || 'h ' ||
            EXTRACT(minutes FROM ((u.created_at + interval '7 days') - now()))::integer || 'm ' ||
            EXTRACT(seconds FROM ((u.created_at + interval '7 days') - now()))::integer || 's'
        ELSE 'EXPIRED'
    END as timer_display,
    
    -- Time since account creation
    EXTRACT(days FROM (now() - u.created_at))::integer || ' days, ' ||
    EXTRACT(hours FROM (now() - u.created_at))::integer || ' hours ago' as account_age

FROM auth.users u
WHERE u.email = 'digitalspace5554@gmail.com';
