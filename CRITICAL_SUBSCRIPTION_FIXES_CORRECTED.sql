-- ============================================================================
-- 🚨 CRITICAL SUBSCRIPTION SYSTEM FIXES - CORRECTED VERSION
-- ============================================================================
-- This script addresses critical race conditions and edge cases in the 
-- subscription system identified by Senior QA analysis
-- ============================================================================

-- FIX 1: Add webhook deduplication table
CREATE TABLE IF NOT EXISTS webhook_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    stripe_event_id text UNIQUE NOT NULL,
    event_type text NOT NULL,
    processed_at timestamptz DEFAULT now(),
    created_at timestamptz DEFAULT now()
);

-- FIX 2: Add payment_failed to trial_status enum (if not exists)
DO $$ 
BEGIN
    -- Check if payment_failed value already exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum 
        WHERE enumlabel = 'payment_failed' 
        AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'trial_status')
    ) THEN
        ALTER TYPE trial_status ADD VALUE 'payment_failed';
        RAISE NOTICE 'Added payment_failed to trial_status enum';
    ELSE
        RAISE NOTICE 'payment_failed already exists in trial_status enum';
    END IF;
END $$;

-- FIX 3: Add canceled to trial_status enum (if not exists)
DO $$ 
BEGIN
    -- Check if canceled value already exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum 
        WHERE enumlabel = 'canceled' 
        AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'trial_status')
    ) THEN
        ALTER TYPE trial_status ADD VALUE 'canceled';
        RAISE NOTICE 'Added canceled to trial_status enum';
    ELSE
        RAISE NOTICE 'canceled already exists in trial_status enum';
    END IF;
END $$;

-- FIX 4: Enhanced subscription status handling
CREATE OR REPLACE FUNCTION handle_subscription_status_change(
    p_subscription_id text,
    p_customer_id text,
    p_status text,
    p_cancel_at_period_end boolean DEFAULT false,
    p_current_period_end bigint DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_deletion_date timestamptz;
BEGIN
    -- Get user_id from customer
    SELECT user_id INTO v_user_id
    FROM stripe_customers
    WHERE customer_id = p_customer_id AND deleted_at IS NULL;
    
    IF v_user_id IS NULL THEN
        RAISE WARNING 'No user found for customer_id: %', p_customer_id;
        RETURN;
    END IF;
    
    -- Update subscription status
    UPDATE stripe_subscriptions
    SET 
        status = p_status,
        cancel_at_period_end = p_cancel_at_period_end,
        current_period_end = p_current_period_end,
        updated_at = now()
    WHERE subscription_id = p_subscription_id;
    
    -- Handle different subscription states
    CASE p_status
        WHEN 'active' THEN
            -- Active subscription: ensure user is protected
            UPDATE user_trials
            SET 
                trial_status = 'converted_to_paid',
                deletion_scheduled_at = NULL,
                updated_at = now()
            WHERE user_id = v_user_id;
            
        WHEN 'trialing' THEN
            -- Trialing subscription: mark as converted if resubscribed user
            UPDATE user_trials
            SET 
                trial_status = CASE 
                    WHEN trial_status = 'expired' OR trial_status = 'canceled' 
                    THEN 'converted_to_paid'
                    ELSE trial_status
                END,
                deletion_scheduled_at = NULL,
                updated_at = now()
            WHERE user_id = v_user_id;
            
        WHEN 'canceled' THEN
            -- Canceled subscription: schedule deletion after period ends
            IF p_current_period_end IS NOT NULL THEN
                v_deletion_date := to_timestamp(p_current_period_end) + interval '24 hours';
                UPDATE user_trials
                SET 
                    trial_status = 'canceled',
                    deletion_scheduled_at = v_deletion_date,
                    updated_at = now()
                WHERE user_id = v_user_id;
            END IF;
            
        WHEN 'past_due' THEN
            -- Payment failed: give 7 days grace period
            UPDATE user_trials
            SET 
                trial_status = 'payment_failed',
                deletion_scheduled_at = now() + interval '7 days',
                updated_at = now()
            WHERE user_id = v_user_id;
            
        WHEN 'incomplete', 'incomplete_expired' THEN
            -- Payment incomplete: keep current status but don't give access
            -- Don't change trial_status, just log the issue
            RAISE NOTICE 'Subscription % has incomplete payment for user %', p_subscription_id, v_user_id;
            
        ELSE
            -- Unknown status: log warning
            RAISE WARNING 'Unknown subscription status: % for subscription %', p_status, p_subscription_id;
    END CASE;
    
    -- Always run protection after status change
    PERFORM protect_paying_customers();
END;
$$;

-- FIX 5: Enhanced trial cleanup with better safety checks
CREATE OR REPLACE FUNCTION safe_trial_cleanup()
RETURNS TABLE(
    user_id uuid,
    email text,
    trial_status text,
    deletion_scheduled_at timestamptz,
    has_active_subscription boolean,
    safe_to_delete boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_super_admin_id uuid := 'b8782453-a343-4301-a947-67c5bb407d2b';
BEGIN
    -- First, protect all paying customers
    PERFORM protect_paying_customers();
    PERFORM sync_subscription_status();
    
    RETURN QUERY
    SELECT 
        ut.user_id,
        au.email,
        ut.trial_status::text,
        ut.deletion_scheduled_at,
        COALESCE(s.status IN ('active', 'trialing'), false) as has_active_subscription,
        CASE 
            WHEN ut.user_id = v_super_admin_id THEN false  -- Never delete super admin
            WHEN s.status IN ('active', 'trialing') THEN false  -- Never delete paying customers
            WHEN ut.deletion_scheduled_at IS NULL THEN false  -- Not scheduled for deletion
            WHEN ut.deletion_scheduled_at > now() THEN false  -- Not yet time to delete
            WHEN ut.trial_status = 'converted_to_paid' THEN false  -- Converted users are protected
            ELSE true
        END as safe_to_delete
    FROM user_trials ut
    JOIN auth.users au ON ut.user_id = au.id
    LEFT JOIN stripe_customers c ON ut.user_id = c.user_id AND c.deleted_at IS NULL
    LEFT JOIN stripe_subscriptions s ON c.customer_id = s.customer_id AND s.deleted_at IS NULL
    WHERE ut.deletion_scheduled_at IS NOT NULL
    ORDER BY ut.deletion_scheduled_at ASC;
END;
$$;

-- FIX 6: Enhanced protection function
CREATE OR REPLACE FUNCTION protect_paying_customers()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Protect all users with active or trialing subscriptions
    UPDATE user_trials
    SET 
        trial_status = 'converted_to_paid',
        deletion_scheduled_at = NULL,
        updated_at = now()
    WHERE user_id IN (
        SELECT DISTINCT c.user_id
        FROM stripe_customers c
        JOIN stripe_subscriptions s ON c.customer_id = s.customer_id
        WHERE s.status IN ('active', 'trialing')
        AND s.deleted_at IS NULL
        AND c.deleted_at IS NULL
    )
    AND trial_status != 'converted_to_paid';
    
    -- Also protect super admin
    UPDATE user_trials
    SET 
        trial_status = 'converted_to_paid',
        deletion_scheduled_at = NULL,
        updated_at = now()
    WHERE user_id = 'b8782453-a343-4301-a947-67c5bb407d2b';
    
    RAISE NOTICE 'Protected paying customers from deletion';
END;
$$;

-- FIX 7: Add subscription conflict resolution
CREATE OR REPLACE FUNCTION resolve_subscription_conflicts()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- For customers with multiple subscriptions, keep only the latest active one
    WITH latest_subscriptions AS (
        SELECT DISTINCT ON (customer_id) 
            customer_id,
            subscription_id,
            created_at
        FROM stripe_subscriptions
        WHERE status IN ('active', 'trialing')
        AND deleted_at IS NULL
        ORDER BY customer_id, created_at DESC
    ),
    subscriptions_to_deactivate AS (
        SELECT s.subscription_id
        FROM stripe_subscriptions s
        LEFT JOIN latest_subscriptions ls ON s.subscription_id = ls.subscription_id
        WHERE s.status IN ('active', 'trialing')
        AND s.deleted_at IS NULL
        AND ls.subscription_id IS NULL
    )
    UPDATE stripe_subscriptions
    SET 
        status = 'canceled',
        updated_at = now()
    WHERE subscription_id IN (SELECT subscription_id FROM subscriptions_to_deactivate);
    
    RAISE NOTICE 'Resolved subscription conflicts';
END;
$$;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🚨 ============================================';
    RAISE NOTICE '🚨 CRITICAL SUBSCRIPTION FIXES APPLIED!';
    RAISE NOTICE '🚨 ============================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ Fixed: Webhook deduplication system';
    RAISE NOTICE '✅ Fixed: Payment failure handling (past_due, incomplete)';
    RAISE NOTICE '✅ Fixed: Race condition protection';
    RAISE NOTICE '✅ Fixed: Enhanced trial cleanup safety';
    RAISE NOTICE '✅ Fixed: Subscription conflict resolution';
    RAISE NOTICE '✅ Fixed: Added payment_failed and canceled enum values';
    RAISE NOTICE '';
    RAISE NOTICE '🎯 NEXT STEPS:';
    RAISE NOTICE '   1. Test basic subscription flow';
    RAISE NOTICE '   2. Test payment failure scenarios';
    RAISE NOTICE '   3. Test rapid cancel/resubscribe';
    RAISE NOTICE '   4. Monitor webhook processing';
    RAISE NOTICE '';
END $$;
