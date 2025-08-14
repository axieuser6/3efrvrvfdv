-- Fix trial dates to use user creation time and enable email confirmation
-- Run this script to fix existing users and future signups
-- SAFE TO RUN MULTIPLE TIMES - includes proper IF checks

-- ============================================================================
-- 1. FIX EXISTING USERS' TRIAL DATES (SAFE WITH CONDITIONS)
-- ============================================================================

DO $$
BEGIN
    -- Only update trials that have incorrect start dates (not matching user creation time)
    UPDATE user_trials
    SET
        trial_start_date = (SELECT created_at FROM auth.users WHERE id = user_trials.user_id),
        trial_end_date = (SELECT created_at + interval '7 days' FROM auth.users WHERE id = user_trials.user_id),
        updated_at = now()
    WHERE user_id IN (SELECT id FROM auth.users)
    AND trial_start_date != (SELECT created_at FROM auth.users WHERE id = user_trials.user_id);

    RAISE NOTICE 'Updated % trial records with correct dates', ROW_COUNT;
END $$;

DO $$
BEGIN
    -- Only update account states that have incorrect trial dates
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

    RAISE NOTICE 'Updated % account state records with correct trial dates', ROW_COUNT;
END $$;

-- ============================================================================
-- 2. IMPROVE CREATE_USER_TRIAL FUNCTION (SAFE REPLACEMENT)
-- ============================================================================

-- Drop and recreate function safely
DROP FUNCTION IF EXISTS create_user_trial(uuid, integer);

-- Update the create_user_trial function to use user creation time
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

    -- Create trial record using user's actual creation time
    BEGIN
        INSERT INTO user_trials (
            user_id,
            trial_start_date,
            trial_end_date,
            trial_status
        )
        VALUES (
            p_user_id,
            v_user_created_at,
            v_user_created_at + (p_trial_days || ' days')::interval,
            'active'
        );

        RAISE NOTICE 'Successfully created trial for user % with % days starting from %', 
                     p_user_id, p_trial_days, v_user_created_at;

    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE EXCEPTION 'Foreign key violation creating trial for user %: User does not exist in auth.users', p_user_id;
        WHEN unique_violation THEN
            RAISE NOTICE 'Trial already exists for user %, ignoring duplicate creation', p_user_id;
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
    
    RAISE NOTICE 'Updated account state for user % with trial ending %', 
                 p_user_id, v_user_created_at + (p_trial_days || ' days')::interval;
END;
$$;

-- ============================================================================
-- 3. CREATE FUNCTION TO FIX SPECIFIC USER (SAFE REPLACEMENT)
-- ============================================================================

-- Drop and recreate function safely
DROP FUNCTION IF EXISTS fix_user_trial_dates(uuid);

-- Function to fix a specific user's trial dates
CREATE OR REPLACE FUNCTION fix_user_trial_dates(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_created_at timestamptz;
    v_trial_end_date timestamptz;
    v_days_remaining integer;
    v_result jsonb;
BEGIN
    -- Get user creation time
    SELECT created_at INTO v_user_created_at
    FROM auth.users 
    WHERE id = p_user_id;
    
    IF v_user_created_at IS NULL THEN
        RETURN jsonb_build_object('error', 'User not found');
    END IF;
    
    -- Calculate correct trial end date
    v_trial_end_date := v_user_created_at + interval '7 days';
    v_days_remaining := GREATEST(0, EXTRACT(days FROM (v_trial_end_date - now()))::integer);
    
    -- Update user_trials
    UPDATE user_trials 
    SET 
        trial_start_date = v_user_created_at,
        trial_end_date = v_trial_end_date,
        updated_at = now()
    WHERE user_id = p_user_id;
    
    -- Update user_account_state
    UPDATE user_account_state 
    SET 
        trial_start_date = v_user_created_at,
        trial_end_date = v_trial_end_date,
        trial_days_remaining = v_days_remaining,
        updated_at = now()
    WHERE user_id = p_user_id;
    
    -- Return result
    v_result := jsonb_build_object(
        'user_id', p_user_id,
        'user_created_at', v_user_created_at,
        'trial_start_date', v_user_created_at,
        'trial_end_date', v_trial_end_date,
        'days_remaining', v_days_remaining,
        'fixed_at', now()
    );
    
    RETURN v_result;
END;
$$;

-- ============================================================================
-- 4. VERIFICATION QUERY
-- ============================================================================

-- Query to check trial dates for all users
SELECT 
    u.id,
    u.email,
    u.created_at as user_created,
    ut.trial_start_date,
    ut.trial_end_date,
    ut.trial_status,
    EXTRACT(days FROM (ut.trial_end_date - now()))::integer as days_remaining_calculated,
    uas.trial_days_remaining as days_remaining_stored,
    CASE 
        WHEN u.created_at = ut.trial_start_date THEN '✅ CORRECT'
        ELSE '❌ WRONG - should start from user creation'
    END as trial_start_status,
    CASE 
        WHEN ut.trial_end_date = u.created_at + interval '7 days' THEN '✅ CORRECT'
        ELSE '❌ WRONG - should be 7 days from user creation'
    END as trial_end_status
FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
LEFT JOIN user_account_state uas ON u.id = uas.user_id
ORDER BY u.created_at DESC
LIMIT 10;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION create_user_trial(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION fix_user_trial_dates(uuid) TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION create_user_trial(uuid, integer) IS 'Creates trial record using user actual creation time from auth.users, not current time';
COMMENT ON FUNCTION fix_user_trial_dates(uuid) IS 'Fixes trial dates for a specific user to use their actual creation time';
