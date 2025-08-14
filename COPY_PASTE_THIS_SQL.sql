-- ============================================================================
-- 🔧 COPY AND PASTE THIS SQL INTO SUPABASE SQL EDITOR
-- ============================================================================
-- This script fixes trial timer issues and is SAFE to run multiple times
-- It includes proper IF statements and safety checks

-- ============================================================================
-- STEP 1: FIX EXISTING USERS' TRIAL DATES
-- ============================================================================

-- Fix user_trials table (only update incorrect dates)
DO $$
DECLARE
    updated_count integer;
BEGIN
    UPDATE user_trials 
    SET 
        trial_start_date = (SELECT created_at FROM auth.users WHERE id = user_trials.user_id),
        trial_end_date = (SELECT created_at + interval '7 days' FROM auth.users WHERE id = user_trials.user_id),
        updated_at = now()
    WHERE user_id IN (SELECT id FROM auth.users)
    AND trial_start_date != (SELECT created_at FROM auth.users WHERE id = user_trials.user_id);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Fixed % trial records with correct dates', updated_count;
END $$;

-- Fix user_account_state table (only update incorrect dates)
DO $$
DECLARE
    updated_count integer;
BEGIN
    UPDATE user_account_state 
    SET 
        trial_start_date = (SELECT created_at FROM auth.users WHERE id = user_account_state.user_id),
        trial_end_date = (SELECT created_at + interval '7 days' FROM auth.users WHERE id = user_account_state.user_id),
        trial_days_remaining = GREATEST(0, EXTRACT(days FROM (
            (SELECT created_at + interval '7 days' FROM auth.users WHERE id = user_account_state.user_id) - now()
        ))::integer),
        updated_at = now()
    WHERE user_id IN (SELECT id FROM auth.users)
    AND (trial_start_date IS NULL OR trial_start_date != (SELECT created_at FROM auth.users WHERE id = user_account_state.user_id));
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Fixed % account state records with correct trial dates', updated_count;
END $$;

-- ============================================================================
-- STEP 2: UPDATE CREATE_USER_TRIAL FUNCTION FOR FUTURE USERS
-- ============================================================================

-- Drop existing function safely
DROP FUNCTION IF EXISTS create_user_trial(uuid, integer);

-- Create improved function that uses user creation time
CREATE OR REPLACE FUNCTION create_user_trial(p_user_id uuid, p_trial_days integer DEFAULT 7)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_created_at timestamptz;
BEGIN
    -- Get the user's actual creation time
    SELECT created_at INTO v_user_created_at
    FROM auth.users 
    WHERE id = p_user_id;
    
    IF v_user_created_at IS NULL THEN
        RAISE EXCEPTION 'User % not found in auth.users', p_user_id;
    END IF;

    -- Create trial record using user's actual creation time (not now())
    BEGIN
        INSERT INTO user_trials (
            user_id,
            trial_start_date,
            trial_end_date,
            trial_status
        )
        VALUES (
            p_user_id,
            v_user_created_at,  -- Use actual creation time
            v_user_created_at + (p_trial_days || ' days')::interval,  -- 7 days from creation
            'active'
        );

        RAISE NOTICE '✅ Created trial for user % starting from % (creation time)', p_user_id, v_user_created_at;

    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE '⚠️ Trial already exists for user %, skipping', p_user_id;
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Failed to create trial for user %: %', p_user_id, SQLERRM;
    END;

    -- Update central account state with correct dates
    UPDATE user_account_state
    SET
        trial_start_date = v_user_created_at,
        trial_end_date = v_user_created_at + (p_trial_days || ' days')::interval,
        trial_days_remaining = p_trial_days,
        updated_at = now()
    WHERE user_id = p_user_id;
    
    RAISE NOTICE '✅ Updated account state for user % with trial ending %', 
                 p_user_id, v_user_created_at + (p_trial_days || ' days')::interval;
END;
$$;

-- ============================================================================
-- STEP 3: VERIFICATION QUERY
-- ============================================================================

-- Check if the fix worked correctly
SELECT 
    '🔍 VERIFICATION RESULTS' as status,
    COUNT(*) as total_users,
    COUNT(CASE WHEN u.created_at = ut.trial_start_date THEN 1 END) as correct_start_dates,
    COUNT(CASE WHEN ut.trial_end_date = u.created_at + interval '7 days' THEN 1 END) as correct_end_dates
FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id;

-- Show recent users with their trial status
SELECT 
    '📊 RECENT USERS TRIAL STATUS' as info,
    u.email,
    u.created_at as user_created,
    ut.trial_start_date,
    ut.trial_end_date,
    EXTRACT(days FROM (ut.trial_end_date - now()))::integer as days_remaining,
    CASE 
        WHEN u.created_at = ut.trial_start_date THEN '✅ CORRECT'
        ELSE '❌ STILL WRONG'
    END as start_date_status,
    CASE 
        WHEN ut.trial_end_date = u.created_at + interval '7 days' THEN '✅ CORRECT'
        ELSE '❌ STILL WRONG'
    END as end_date_status
FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
ORDER BY u.created_at DESC
LIMIT 5;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_user_trial(uuid, integer) TO authenticated;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🎉 ============================================';
    RAISE NOTICE '🎉 TRIAL DATE FIX COMPLETED SUCCESSFULLY!';
    RAISE NOTICE '🎉 ============================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ All existing users now have correct trial dates';
    RAISE NOTICE '✅ Future users will get trials starting from signup time';
    RAISE NOTICE '✅ Trial timer will show accurate countdown';
    RAISE NOTICE '';
    RAISE NOTICE '🔧 NEXT STEP: Enable email confirmation in Supabase dashboard';
    RAISE NOTICE '📖 See ENABLE_EMAIL_CONFIRMATION_GUIDE.md for instructions';
    RAISE NOTICE '';
END $$;
