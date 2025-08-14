-- ============================================================================
-- TEST SCRIPT FOR DATABASE FOREIGN KEY FIX
-- ============================================================================
-- Run these commands to test that the foreign key constraint fix is working
-- ============================================================================

-- 1. Check overall database health
SELECT 'DATABASE HEALTH CHECK' as test_name;
SELECT check_database_health();

-- 2. Look for any existing foreign key issues
SELECT 'FOREIGN KEY DIAGNOSTICS' as test_name;
SELECT diagnose_foreign_key_issues();

-- 3. Clean up any orphaned records (if any exist)
SELECT 'CLEANUP ORPHANED RECORDS' as test_name;
SELECT cleanup_orphaned_records();

-- 4. Test the new safe trial creation function
SELECT 'TESTING SAFE TRIAL CREATION' as test_name;

-- This should fail gracefully with a clear error message
-- (since this UUID doesn't exist in auth.users)
DO $$
BEGIN
    PERFORM create_user_trial('00000000-0000-0000-0000-000000000000'::uuid, 7);
    RAISE NOTICE 'ERROR: Trial creation should have failed!';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'SUCCESS: Trial creation failed safely with message: %', SQLERRM;
END $$;

-- 5. Test the enhanced user profile creation function
SELECT 'TESTING SAFE PROFILE CREATION' as test_name;

-- This should also fail gracefully with a clear error message
DO $$
BEGIN
    PERFORM create_complete_user_profile(
        '00000000-0000-0000-0000-000000000000'::uuid,
        'test@example.com',
        'Test User'
    );
    RAISE NOTICE 'ERROR: Profile creation should have failed!';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'SUCCESS: Profile creation failed safely with message: %', SQLERRM;
END $$;

-- 6. Verify existing users (if any)
SELECT 'VERIFYING EXISTING USERS' as test_name;

-- Check all existing users in the system
SELECT 
    au.id,
    au.email,
    verify_user_creation_process(au.id) as verification_result
FROM auth.users au
LIMIT 5;

-- 7. Check for any users with incomplete setup
SELECT 'CHECKING FOR INCOMPLETE USER SETUPS' as test_name;

SELECT 
    au.id,
    au.email,
    CASE 
        WHEN up.id IS NULL THEN 'Missing user_profile'
        WHEN ut.user_id IS NULL THEN 'Missing user_trial'
        WHEN uas.user_id IS NULL THEN 'Missing account_state'
        ELSE 'Complete'
    END as status
FROM auth.users au
LEFT JOIN user_profiles up ON au.id = up.id
LEFT JOIN user_trials ut ON au.id = ut.user_id
LEFT JOIN user_account_state uas ON au.id = uas.user_id
WHERE up.id IS NULL OR ut.user_id IS NULL OR uas.user_id IS NULL;

-- 8. Test system metrics
SELECT 'SYSTEM METRICS' as test_name;
SELECT get_system_metrics();

-- ============================================================================
-- EXPECTED RESULTS:
-- ============================================================================
-- 1. Database health should show "excellent" or "good"
-- 2. Foreign key diagnostics should show no issues (has_issues: false)
-- 3. Cleanup should show 0 records cleaned (if database is healthy)
-- 4. Safe trial creation should fail with clear error message
-- 5. Safe profile creation should fail with clear error message
-- 6. Existing users should show complete verification results
-- 7. No incomplete user setups should be found
-- 8. System metrics should show current counts
-- ============================================================================

SELECT 'TEST COMPLETE - Check results above' as final_message;
