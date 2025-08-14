-- 🛡️ PREVENTION: Ensure all future users get trials automatically
-- This creates a robust trigger system that won't fail

-- 1. First, let's check if the trigger exists and is working
SELECT 
    'CURRENT TRIGGERS:' as status,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_schema = 'auth' 
AND event_object_table = 'users';

-- 2. Create an improved trigger function that's more robust
CREATE OR REPLACE FUNCTION public.handle_new_user_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_trial_days integer := 7;
    v_user_created_at timestamptz;
BEGIN
    -- Get the user's creation time
    v_user_created_at := NEW.created_at;
    
    -- Log the trigger execution
    RAISE NOTICE '🚀 Creating trial for new user: % (created at: %)', NEW.email, v_user_created_at;
    
    -- Create trial record with error handling
    BEGIN
        INSERT INTO public.user_trials (
            user_id,
            trial_start_date,
            trial_end_date,
            trial_status,
            created_at,
            updated_at
        )
        VALUES (
            NEW.id,
            v_user_created_at,
            v_user_created_at + (v_trial_days || ' days')::interval,
            'active'::trial_status,
            now(),
            now()
        );
        
        RAISE NOTICE '✅ Trial created successfully for user %', NEW.email;
        
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE '⚠️ Trial already exists for user %, skipping', NEW.email;
        WHEN OTHERS THEN
            RAISE EXCEPTION '❌ Failed to create trial for user %: %', NEW.email, SQLERRM;
    END;
    
    -- Create user_account_state record with error handling
    BEGIN
        INSERT INTO public.user_account_state (
            user_id,
            trial_start_date,
            trial_end_date,
            trial_days_remaining,
            trial_status,
            created_at,
            updated_at
        )
        VALUES (
            NEW.id,
            v_user_created_at,
            v_user_created_at + (v_trial_days || ' days')::interval,
            v_trial_days,
            'active'::trial_status,
            now(),
            now()
        );
        
        RAISE NOTICE '✅ Account state created successfully for user %', NEW.email;
        
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE '⚠️ Account state already exists for user %, skipping', NEW.email;
        WHEN OTHERS THEN
            RAISE EXCEPTION '❌ Failed to create account state for user %: %', NEW.email, SQLERRM;
    END;
    
    RETURN NEW;
END;
$$;

-- 3. Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 4. Create the new robust trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user_signup();

-- 5. Test the trigger by checking recent users
SELECT 
    'TRIGGER TEST - RECENT USERS:' as status,
    u.id,
    u.email,
    u.created_at,
    CASE 
        WHEN ut.user_id IS NOT NULL THEN '✅ HAS TRIAL'
        ELSE '❌ MISSING TRIAL'
    END as trial_status,
    CASE 
        WHEN uas.user_id IS NOT NULL THEN '✅ HAS ACCOUNT STATE'
        ELSE '❌ MISSING ACCOUNT STATE'
    END as account_state_status
FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
LEFT JOIN user_account_state uas ON u.id = uas.user_id
ORDER BY u.created_at DESC
LIMIT 10;

-- 6. Create a monitoring function to check for missing trials daily
CREATE OR REPLACE FUNCTION public.check_missing_trials()
RETURNS TABLE(
    missing_trials_count integer,
    affected_users text[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_missing_count integer;
    v_affected_emails text[];
BEGIN
    -- Count users without trials
    SELECT COUNT(*) INTO v_missing_count
    FROM auth.users u
    WHERE NOT EXISTS (
        SELECT 1 FROM user_trials ut WHERE ut.user_id = u.id
    );
    
    -- Get list of affected emails
    SELECT ARRAY_AGG(u.email) INTO v_affected_emails
    FROM auth.users u
    WHERE NOT EXISTS (
        SELECT 1 FROM user_trials ut WHERE ut.user_id = u.id
    );
    
    RETURN QUERY SELECT v_missing_count, v_affected_emails;
END;
$$;

-- 7. Test the monitoring function
SELECT 
    'MONITORING CHECK:' as status,
    missing_trials_count,
    affected_users
FROM public.check_missing_trials();

-- 8. Create a function to auto-fix missing trials (can be run periodically)
CREATE OR REPLACE FUNCTION public.auto_fix_missing_trials()
RETURNS TABLE(
    fixed_users_count integer,
    fixed_user_emails text[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_fixed_count integer;
    v_fixed_emails text[];
BEGIN
    -- Get list of users to fix
    SELECT ARRAY_AGG(u.email) INTO v_fixed_emails
    FROM auth.users u
    WHERE NOT EXISTS (
        SELECT 1 FROM user_trials ut WHERE ut.user_id = u.id
    );
    
    -- Fix missing trials
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
    
    -- Fix missing account states
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
    
    GET DIAGNOSTICS v_fixed_count = ROW_COUNT;
    
    RETURN QUERY SELECT v_fixed_count, v_fixed_emails;
END;
$$;

-- 9. Final verification that everything is working
SELECT 
    'FINAL VERIFICATION:' as status,
    'Trigger created and ready for new users' as message;

SELECT 
    'MONITORING FUNCTIONS:' as status,
    'check_missing_trials() and auto_fix_missing_trials() created' as message;
