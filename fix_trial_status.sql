-- Fix the trial status for the current user and improve the trigger

-- First, fix the current user's trial status
UPDATE user_trials 
SET 
    trial_status = 'active',
    trial_start_date = now(),
    trial_end_date = now() + interval '7 days',
    updated_at = now()
WHERE user_id = 'f81de212-068c-45f6-9439-14ba0de46b52';

-- Update the account state for the current user
UPDATE user_account_state 
SET 
    account_status = 'trial_active',
    has_access = true,
    access_level = 'trial',
    trial_start_date = now(),
    trial_end_date = now() + interval '7 days',
    trial_days_remaining = 7,
    updated_at = now()
WHERE user_id = 'f81de212-068c-45f6-9439-14ba0de46b52';

-- Improve the trigger to set correct initial status
CREATE OR REPLACE FUNCTION on_auth_user_created_simple()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Create user profile if it doesn't exist
    INSERT INTO user_profiles (id, email, created_at)
    VALUES (NEW.id, NEW.email, now())
    ON CONFLICT (id) DO NOTHING;

    -- Create trial record with ACTIVE status
    INSERT INTO user_trials (user_id, trial_start_date, trial_end_date, trial_status)
    VALUES (NEW.id, now(), now() + interval '7 days', 'active')
    ON CONFLICT (user_id) DO NOTHING;

    -- Create account state with TRIAL_ACTIVE status
    INSERT INTO user_account_state (
        user_id, 
        account_status, 
        has_access, 
        access_level, 
        trial_start_date, 
        trial_end_date, 
        trial_days_remaining
    )
    VALUES (
        NEW.id, 
        'trial_active', 
        true, 
        'trial', 
        now(), 
        now() + interval '7 days', 
        7
    )
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log the error but don't fail the signup
    RAISE NOTICE 'Error in user creation trigger: %', SQLERRM;
    RETURN NEW;
END;
$$;
