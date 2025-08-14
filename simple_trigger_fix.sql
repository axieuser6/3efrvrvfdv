-- Simplified trigger that creates basic user records without complex logic
-- This should work even if some functions are missing

-- First, let's create a very simple trigger function
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

    -- Create trial record if it doesn't exist
    INSERT INTO user_trials (user_id, trial_start_date, trial_end_date, trial_status)
    VALUES (NEW.id, now(), now() + interval '7 days', 'active')
    ON CONFLICT (user_id) DO NOTHING;

    -- Create account state if it doesn't exist
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

-- Drop the existing trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create the new simple trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION on_auth_user_created_simple();
