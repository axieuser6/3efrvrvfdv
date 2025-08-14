-- Fix the current user's trial status and create missing records

-- Fix user: c938f27e-ff8e-43cf-9648-d0ab2c5edc46
DO $$
DECLARE
    current_user_id uuid := 'c938f27e-ff8e-43cf-9648-d0ab2c5edc46';
    user_email text;
BEGIN
    -- Get user email
    SELECT email INTO user_email FROM auth.users WHERE id = current_user_id;
    
    -- Create user profile if missing
    INSERT INTO user_profiles (id, email, created_at)
    VALUES (current_user_id, user_email, now())
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        updated_at = now();
    
    -- Fix trial record
    INSERT INTO user_trials (user_id, trial_start_date, trial_end_date, trial_status, created_at, updated_at)
    VALUES (current_user_id, now(), now() + interval '7 days', 'active', now(), now())
    ON CONFLICT (user_id) DO UPDATE SET
        trial_start_date = now(),
        trial_end_date = now() + interval '7 days',
        trial_status = 'active',
        updated_at = now();
    
    -- Fix account state
    INSERT INTO user_account_state (
        user_id, 
        account_status, 
        has_access, 
        access_level, 
        trial_start_date, 
        trial_end_date, 
        trial_days_remaining,
        created_at,
        updated_at
    )
    VALUES (
        current_user_id, 
        'trial_active', 
        true, 
        'trial', 
        now(), 
        now() + interval '7 days', 
        7,
        now(),
        now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        account_status = 'trial_active',
        has_access = true,
        access_level = 'trial',
        trial_start_date = now(),
        trial_end_date = now() + interval '7 days',
        trial_days_remaining = 7,
        updated_at = now();
        
    RAISE NOTICE 'Fixed user % with email %', current_user_id, user_email;
END $$;

-- Fix the views to handle multiple rows properly
DROP VIEW IF EXISTS user_access_status CASCADE;

CREATE VIEW user_access_status AS
SELECT DISTINCT ON (ut.user_id)
    ut.user_id,
    ut.trial_start_date,
    ut.trial_end_date,
    ut.trial_status,
    ut.deletion_scheduled_at,
    s.status as subscription_status,
    s.subscription_id,
    s.price_id,
    s.current_period_end,
    CASE 
        WHEN s.status IN ('active', 'trialing') THEN true
        WHEN ut.trial_status = 'active' AND ut.trial_end_date > now() THEN true
        ELSE false
    END as has_access,
    CASE 
        WHEN s.status = 'active' THEN 'paid_subscription'
        WHEN s.status = 'trialing' THEN 'stripe_trial'
        WHEN ut.trial_status = 'active' AND ut.trial_end_date > now() THEN 'free_trial'
        ELSE 'no_access'
    END as access_type,
    CASE 
        WHEN ut.trial_end_date > now() THEN EXTRACT(epoch FROM (ut.trial_end_date - now()))::bigint
        ELSE 0
    END as seconds_remaining,
    CASE 
        WHEN ut.trial_end_date > now() THEN EXTRACT(days FROM (ut.trial_end_date - now()))::integer
        ELSE 0
    END as days_remaining
FROM user_trials ut
LEFT JOIN stripe_customers c ON ut.user_id = c.user_id AND c.deleted_at IS NULL
LEFT JOIN stripe_subscriptions s ON c.customer_id = s.customer_id AND s.deleted_at IS NULL
ORDER BY ut.user_id, s.created_at DESC NULLS LAST;
