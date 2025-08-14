-- Check if the automatic trial trigger is working properly

-- 1. Check if the trigger exists
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- 2. Check if the trigger function exists
SELECT 
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'on_auth_user_created_enhanced';

-- 3. Check if create_user_trial function exists
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_name = 'create_user_trial';

-- 4. Check recent users and their trial status
SELECT 
    u.id,
    u.email,
    u.created_at as user_created,
    ut.trial_start_date,
    ut.trial_end_date,
    ut.trial_status,
    CASE 
        WHEN ut.trial_end_date > now() THEN EXTRACT(days FROM (ut.trial_end_date - now()))::integer
        ELSE 0
    END as days_remaining
FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
ORDER BY u.created_at DESC
LIMIT 10;

-- 5. Check if any users are missing trial records
SELECT 
    COUNT(*) as users_without_trials
FROM auth.users u
WHERE u.id NOT IN (SELECT user_id FROM user_trials WHERE user_id IS NOT NULL);

-- 6. Test the create_user_trial function manually (for debugging)
-- This will show us if the function works when called directly
SELECT 'Testing create_user_trial function...' as test_status;
