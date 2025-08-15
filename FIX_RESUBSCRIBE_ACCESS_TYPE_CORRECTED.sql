-- ============================================================================
-- 🔧 FIX RESUBSCRIBE ACCESS TYPE ISSUE - CORRECTED VERSION
-- ============================================================================
-- This script fixes the issue where resubscribed users show as "stripe_trial" 
-- instead of "paid_subscription" when they have a trialing subscription
-- but their trial_status is "converted_to_paid"
-- ============================================================================

-- STEP 1: Drop existing function first (to avoid signature conflict)
DROP FUNCTION IF EXISTS get_user_access_level(uuid);

-- STEP 2: Update the user_access_status view
DROP VIEW IF EXISTS user_access_status CASCADE;

CREATE VIEW user_access_status WITH (security_invoker = true) AS
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
        WHEN s.status = 'trialing' AND ut.trial_status = 'converted_to_paid' THEN 'paid_subscription'
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
WHERE ut.user_id IS NOT NULL;

-- STEP 3: Create the enhanced get_user_access_level function
CREATE OR REPLACE FUNCTION get_user_access_level(p_user_id uuid)
RETURNS TABLE(
    has_access boolean,
    access_type text,
    subscription_status text,
    trial_status text,
    days_remaining integer,
    trial_start_date timestamptz,
    trial_end_date timestamptz,
    deletion_scheduled_at timestamptz,
    seconds_remaining bigint,
    is_expired_trial_user boolean,
    is_returning_user boolean,
    requires_subscription boolean,
    can_create_axiestudio_account boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        CASE
            WHEN s.status IN ('active', 'trialing') THEN true
            WHEN ut.trial_status = 'active' AND ut.trial_end_date > now() THEN true
            ELSE false
        END as has_access,
        CASE
            WHEN s.status = 'active' THEN 'paid_subscription'
            WHEN s.status = 'trialing' AND ut.trial_status = 'converted_to_paid' THEN 'paid_subscription'
            WHEN s.status = 'trialing' THEN 'stripe_trial'
            WHEN ut.trial_status = 'active' AND ut.trial_end_date > now() THEN 'free_trial'
            ELSE 'no_access'
        END as access_type,
        COALESCE(s.status::text, 'none') as subscription_status,
        ut.trial_status::text,
        CASE
            WHEN ut.trial_end_date > now() THEN EXTRACT(days FROM (ut.trial_end_date - now()))::integer
            ELSE 0
        END as days_remaining,
        ut.trial_start_date,
        ut.trial_end_date,
        ut.deletion_scheduled_at,
        CASE
            WHEN ut.trial_end_date > now() THEN EXTRACT(epoch FROM (ut.trial_end_date - now()))::bigint
            ELSE 0
        END as seconds_remaining,
        -- Enhanced security flags
        (ut.trial_status IN ('expired', 'scheduled_for_deletion'))::boolean as is_expired_trial_user,
        false::boolean as is_returning_user, -- Will be enhanced later
        false::boolean as requires_subscription, -- Will be enhanced later
        CASE
            WHEN s.status IN ('active', 'trialing') THEN true
            WHEN ut.trial_status = 'active' AND ut.trial_end_date > now() THEN true
            ELSE false
        END as can_create_axiestudio_account
    FROM user_trials ut
    LEFT JOIN stripe_customers c ON ut.user_id = c.user_id AND c.deleted_at IS NULL
    LEFT JOIN stripe_subscriptions s ON c.customer_id = s.customer_id AND s.deleted_at IS NULL
    WHERE ut.user_id = p_user_id;
END;
$$;

-- STEP 4: Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ ============================================';
    RAISE NOTICE '✅ RESUBSCRIBE ACCESS TYPE FIX APPLIED!';
    RAISE NOTICE '✅ ============================================';
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Fixed: Resubscribed users with trialing subscriptions';
    RAISE NOTICE '🔧 Fixed: trial_status = converted_to_paid + subscription_status = trialing';
    RAISE NOTICE '🔧 Result: Now shows as paid_subscription instead of stripe_trial';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 WHAT THIS FIXES:';
    RAISE NOTICE '   - Subscribe → Cancel → Resubscribe flow';
    RAISE NOTICE '   - Users now get paid_subscription status immediately';
    RAISE NOTICE '   - No more confusion with stripe_trial for paying users';
    RAISE NOTICE '';
    RAISE NOTICE '🚀 NEXT STEPS:';
    RAISE NOTICE '   1. Refresh your browser dashboard';
    RAISE NOTICE '   2. Check your access status - should show paid_subscription';
    RAISE NOTICE '   3. Test the resubscribe flow - should work perfectly now!';
    RAISE NOTICE '';
END $$;
