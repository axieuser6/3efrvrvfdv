-- Create the missing views that the frontend expects

-- Drop existing views first to avoid column conflicts
DROP VIEW IF EXISTS user_trial_info CASCADE;
DROP VIEW IF EXISTS stripe_user_subscriptions CASCADE;
DROP VIEW IF EXISTS user_access_status CASCADE;
DROP VIEW IF EXISTS user_dashboard CASCADE;

-- Create user_trial_info view
CREATE VIEW user_trial_info AS
SELECT
    ut.user_id,
    ut.trial_start_date,
    ut.trial_end_date,
    ut.trial_status,
    ut.deletion_scheduled_at,
    CASE 
        WHEN ut.trial_end_date > now() THEN EXTRACT(days FROM (ut.trial_end_date - now()))::integer
        ELSE 0
    END as days_remaining,
    CASE 
        WHEN ut.trial_end_date > now() THEN EXTRACT(epoch FROM (ut.trial_end_date - now()))::bigint
        ELSE 0
    END as seconds_remaining
FROM user_trials ut;

-- Create stripe_user_subscriptions view
CREATE VIEW stripe_user_subscriptions AS
SELECT
    c.user_id,
    c.customer_id,
    s.subscription_id,
    s.status as subscription_status,
    s.price_id,
    s.current_period_end,
    s.created_at as subscription_created_at,
    s.updated_at as subscription_updated_at
FROM stripe_customers c
LEFT JOIN stripe_subscriptions s ON c.customer_id = s.customer_id
WHERE c.deleted_at IS NULL 
AND (s.deleted_at IS NULL OR s.deleted_at IS NULL);

-- Create user_access_status view (if it doesn't exist)
CREATE VIEW user_access_status AS
SELECT
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
LEFT JOIN stripe_subscriptions s ON c.customer_id = s.customer_id AND s.deleted_at IS NULL;

-- Create user_dashboard view (enterprise)
CREATE VIEW user_dashboard AS
SELECT
    up.id as user_id,
    up.email,
    up.full_name,
    up.company,
    up.created_at as user_created_at,
    up.last_login_at,

    -- Account state
    uas.account_status,
    uas.has_access,
    uas.access_level,
    uas.trial_days_remaining,
    uas.last_activity_at,

    -- Trial info
    ut.trial_start_date,
    ut.trial_end_date,
    ut.trial_status,

    -- Stripe info
    sc.customer_id as stripe_customer_id,
    ss.subscription_id as stripe_subscription_id,
    ss.status as stripe_status,
    ss.current_period_end,
    ss.price_id,

    -- Axie Studio info
    asa.axie_studio_user_id,
    asa.axie_studio_email,
    asa.account_status as axie_studio_status,
    asa.last_sync_at as axie_last_sync

FROM user_profiles up
LEFT JOIN user_account_state uas ON up.id = uas.user_id
LEFT JOIN user_trials ut ON up.id = ut.user_id
LEFT JOIN stripe_customers sc ON up.id = sc.user_id AND sc.deleted_at IS NULL
LEFT JOIN stripe_subscriptions ss ON sc.customer_id = ss.customer_id AND ss.deleted_at IS NULL
LEFT JOIN axie_studio_accounts asa ON up.id = asa.user_id;
