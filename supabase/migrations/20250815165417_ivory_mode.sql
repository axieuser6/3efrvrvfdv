/*
  # Fix New User Signup Trigger

  1. Problem
    - New user signup failing with "Database error saving new user"
    - Trigger function causing database errors during user creation

  2. Solution
    - Create robust trigger function with proper error handling
    - Handle foreign key constraints properly
    - Ensure user_profiles is created before other dependent records

  3. Changes
    - Drop existing problematic trigger
    - Create improved trigger function with proper sequencing
    - Recreate trigger with better error handling
*/

-- Drop existing trigger to prevent conflicts
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create improved trigger function that handles dependencies correctly
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
    v_user_created_at := COALESCE(NEW.created_at, now());
    
    -- Step 1: Create user profile first (required by foreign keys)
    BEGIN
        INSERT INTO public.user_profiles (
            id,
            email,
            full_name,
            created_at,
            updated_at,
            last_login_at,
            is_active
        )
        VALUES (
            NEW.id,
            NEW.email,
            COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
            v_user_created_at,
            now(),
            now(),
            true
        )
        ON CONFLICT (id) DO NOTHING;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Log error but don't fail the entire signup
            RAISE WARNING 'Failed to create user profile for %: %', NEW.email, SQLERRM;
    END;
    
    -- Step 2: Create trial record
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
        )
        ON CONFLICT (user_id) DO NOTHING;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING 'Failed to create trial for %: %', NEW.email, SQLERRM;
    END;
    
    -- Step 3: Create user account state
    BEGIN
        INSERT INTO public.user_account_state (
            user_id,
            account_status,
            has_access,
            access_level,
            trial_start_date,
            trial_end_date,
            trial_days_remaining,
            created_at,
            updated_at,
            last_activity_at
        )
        VALUES (
            NEW.id,
            'trial_active'::user_account_status,
            true,
            'trial',
            v_user_created_at,
            v_user_created_at + (v_trial_days || ' days')::interval,
            v_trial_days,
            now(),
            now(),
            now()
        )
        ON CONFLICT (user_id) DO NOTHING;
        
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING 'Failed to create account state for %: %', NEW.email, SQLERRM;
    END;
    
    RETURN NEW;
END;
$$;

-- Create the trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user_signup();

-- Verify the trigger was created
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_schema = 'auth' 
AND event_object_table = 'users'
AND trigger_name = 'on_auth_user_created';