-- Fix signup trigger to handle account state creation properly
-- This fixes the 500 error during user signup

-- Enhanced function to handle user re-signup with better error handling
CREATE OR REPLACE FUNCTION handle_user_resignup(
    p_user_id uuid,
    p_email text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_history record;
    v_result jsonb;
    v_account_state_exists boolean := false;
BEGIN
    -- Check if email has been used before
    SELECT * INTO v_history
    FROM deleted_account_history
    WHERE email = p_email;

    IF v_history IS NOT NULL THEN
        -- This is a returning user - no trial allowed
        UPDATE user_trials
        SET
            trial_status = 'expired',
            trial_end_date = now(), -- Expire immediately
            deletion_scheduled_at = NULL, -- Don't delete, they need to subscribe
            updated_at = now()
        WHERE user_id = p_user_id;

        -- Check if account state exists before updating
        SELECT EXISTS(SELECT 1 FROM user_account_state WHERE user_id = p_user_id) INTO v_account_state_exists;
        
        IF v_account_state_exists THEN
            -- Update account state to require subscription
            UPDATE user_account_state
            SET
                account_status = 'trial_expired',
                has_access = false,
                access_level = 'suspended',
                trial_days_remaining = 0,
                updated_at = now()
            WHERE user_id = p_user_id;
        ELSE
            -- Create account state if it doesn't exist
            INSERT INTO user_account_state (
                user_id,
                account_status,
                has_access,
                access_level,
                trial_days_remaining,
                trial_start_date,
                trial_end_date
            ) VALUES (
                p_user_id,
                'trial_expired',
                false,
                'suspended',
                0,
                now(),
                now()
            );
        END IF;

        v_result := jsonb_build_object(
            'is_returning_user', true,
            'requires_subscription', true,
            'trial_allowed', false,
            'message', 'Welcome back! Please subscribe to continue using our service.'
        );
    ELSE
        -- This is a new user - normal trial process
        v_result := jsonb_build_object(
            'is_returning_user', false,
            'requires_subscription', false,
            'trial_allowed', true,
            'message', 'Welcome! Your 7-day free trial has started.'
        );
    END IF;

    RETURN v_result;
END;
$$;

-- Enhanced trigger function with better error handling
CREATE OR REPLACE FUNCTION on_auth_user_created_enhanced()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_resignup_result jsonb;
    v_user_exists boolean := false;
BEGIN
    -- CRITICAL SAFETY CHECK: Verify the user actually exists in auth.users
    SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = NEW.id) INTO v_user_exists;

    IF NOT v_user_exists THEN
        RAISE EXCEPTION 'User % does not exist in auth.users table', NEW.id;
    END IF;

    -- Create complete user profile (enterprise) with error handling
    BEGIN
        PERFORM create_complete_user_profile(
            NEW.id,
            NEW.email,
            NEW.raw_user_meta_data->>'full_name'
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to create user profile for %: %', NEW.id, SQLERRM;
    END;

    -- Create trial record using the safe function
    BEGIN
        PERFORM create_user_trial(NEW.id, 7);
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to create trial for user %: %', NEW.id, SQLERRM;
    END;

    -- Handle potential re-signup with error handling
    BEGIN
        SELECT handle_user_resignup(NEW.id, NEW.email) INTO v_resignup_result;
    EXCEPTION WHEN OTHERS THEN
        -- Log the error but don't fail the entire process
        RAISE NOTICE 'Warning: Failed to handle resignup for user %: %', NEW.id, SQLERRM;
    END;

    RETURN NEW;
END;
$$;
