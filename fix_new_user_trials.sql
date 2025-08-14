-- Fix trial records for users who don't have them yet
-- This ensures all users get proper 7-day trials

-- Function to ensure user has a trial record
CREATE OR REPLACE FUNCTION ensure_user_trial(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Check if user already has a trial
    IF NOT EXISTS (SELECT 1 FROM user_trials WHERE user_id = p_user_id) THEN
        -- Create trial record
        INSERT INTO user_trials (
            user_id,
            trial_start_date,
            trial_end_date,
            trial_status
        )
        VALUES (
            p_user_id,
            now(),
            now() + interval '7 days',
            'active'
        );
        
        RAISE NOTICE 'Created trial record for user %', p_user_id;
    ELSE
        RAISE NOTICE 'Trial record already exists for user %', p_user_id;
    END IF;
    
    -- Also ensure user_account_state exists
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
        p_user_id,
        'trial_active',
        true,
        'trial',
        now(),
        now() + interval '7 days',
        7
    )
    ON CONFLICT (user_id) DO UPDATE SET
        trial_start_date = EXCLUDED.trial_start_date,
        trial_end_date = EXCLUDED.trial_end_date,
        trial_days_remaining = EXCLUDED.trial_days_remaining,
        updated_at = now();
        
    RAISE NOTICE 'Updated account state for user %', p_user_id;
END;
$$;

-- Fix all existing users who might not have trial records
DO $$
DECLARE
    user_record RECORD;
BEGIN
    FOR user_record IN 
        SELECT id, email 
        FROM auth.users 
        WHERE id NOT IN (SELECT user_id FROM user_trials)
    LOOP
        BEGIN
            PERFORM ensure_user_trial(user_record.id);
            RAISE NOTICE 'Fixed trial for user: %', user_record.email;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Failed to fix trial for user %: %', user_record.email, SQLERRM;
        END;
    END LOOP;
END $$;
