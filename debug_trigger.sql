-- Debug script to check what's causing the trigger to fail

-- Check if all required tables exist
SELECT 
    'user_profiles' as table_name,
    EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'user_profiles') as exists
UNION ALL
SELECT 
    'user_trials' as table_name,
    EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'user_trials') as exists
UNION ALL
SELECT 
    'user_account_state' as table_name,
    EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'user_account_state') as exists
UNION ALL
SELECT 
    'deleted_account_history' as table_name,
    EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'deleted_account_history') as exists;

-- Check if all required functions exist
SELECT 
    'create_complete_user_profile' as function_name,
    EXISTS(SELECT 1 FROM information_schema.routines WHERE routine_name = 'create_complete_user_profile') as exists
UNION ALL
SELECT 
    'create_user_trial' as function_name,
    EXISTS(SELECT 1 FROM information_schema.routines WHERE routine_name = 'create_user_trial') as exists
UNION ALL
SELECT 
    'handle_user_resignup' as function_name,
    EXISTS(SELECT 1 FROM information_schema.routines WHERE routine_name = 'handle_user_resignup') as exists;

-- Check if the trigger exists
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- Check if the enum types exist
SELECT 
    'user_account_status' as enum_name,
    EXISTS(SELECT 1 FROM pg_type WHERE typname = 'user_account_status') as exists
UNION ALL
SELECT 
    'trial_status' as enum_name,
    EXISTS(SELECT 1 FROM pg_type WHERE typname = 'trial_status') as exists;
