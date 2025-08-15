/*
  # Enhanced Deletion Tracking for Trial Abuse Prevention

  1. Updates
    - Enhanced record_account_deletion function to track trial usage
    - Better trial completion detection
    - Improved abuse prevention tracking

  2. Security
    - Tracks if user completed their 7-day trial
    - Prevents trial abuse through re-signup
    - Maintains deletion history permanently
*/

-- Update the record_account_deletion function to track trial usage better
CREATE OR REPLACE FUNCTION record_account_deletion(
    p_user_id uuid,
    p_email text,
    p_reason text DEFAULT 'immediate_deletion',
    p_trial_used boolean DEFAULT false,
    p_trial_completed boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_profile RECORD;
    v_trial_info RECORD;
    v_subscription_info RECORD;
BEGIN
    -- Get user profile information
    SELECT * INTO v_user_profile
    FROM user_profiles
    WHERE id = p_user_id;

    -- Get trial information
    SELECT * INTO v_trial_info
    FROM user_trials
    WHERE user_id = p_user_id;

    -- Get subscription information
    SELECT sc.customer_id, ss.status as subscription_status, ss.subscription_id
    INTO v_subscription_info
    FROM stripe_customers sc
    LEFT JOIN stripe_subscriptions ss ON sc.customer_id = ss.customer_id
    WHERE sc.user_id = p_user_id
    AND sc.deleted_at IS NULL
    AND (ss.deleted_at IS NULL OR ss.deleted_at IS NULL);

    -- Record the deletion in history
    INSERT INTO deleted_account_history (
        original_user_id,
        email,
        full_name,
        trial_used,
        trial_start_date,
        trial_end_date,
        trial_completed,
        ever_subscribed,
        last_subscription_status,
        subscription_cancelled_date,
        account_deleted_at,
        deletion_reason,
        can_get_new_trial,
        requires_immediate_subscription
    )
    VALUES (
        p_user_id,
        p_email,
        v_user_profile.full_name,
        COALESCE(p_trial_used, v_trial_info.user_id IS NOT NULL), -- True if trial existed
        v_trial_info.trial_start_date,
        v_trial_info.trial_end_date,
        COALESCE(p_trial_completed, 
            v_trial_info.trial_status IN ('expired', 'converted_to_paid') OR
            (v_trial_info.trial_end_date IS NOT NULL AND v_trial_info.trial_end_date <= now())
        ),
        v_subscription_info.customer_id IS NOT NULL, -- True if ever had subscription
        v_subscription_info.subscription_status,
        CASE 
            WHEN v_subscription_info.subscription_status = 'canceled' THEN now()
            ELSE NULL
        END,
        now(),
        p_reason,
        false, -- Never allow new trial for deleted accounts
        true   -- Always require subscription for returning users
    )
    ON CONFLICT (email) DO UPDATE SET
        -- Update with latest deletion info
        original_user_id = EXCLUDED.original_user_id,
        full_name = EXCLUDED.full_name,
        trial_used = EXCLUDED.trial_used OR deleted_account_history.trial_used, -- Keep true if ever used
        trial_completed = EXCLUDED.trial_completed OR deleted_account_history.trial_completed,
        ever_subscribed = EXCLUDED.ever_subscribed OR deleted_account_history.ever_subscribed,
        last_subscription_status = COALESCE(EXCLUDED.last_subscription_status, deleted_account_history.last_subscription_status),
        account_deleted_at = EXCLUDED.account_deleted_at,
        deletion_reason = EXCLUDED.deletion_reason,
        updated_at = now();

    RAISE NOTICE 'Recorded account deletion for % with trial_used=% trial_completed=%', 
                 p_email, 
                 COALESCE(p_trial_used, v_trial_info.user_id IS NOT NULL),
                 COALESCE(p_trial_completed, v_trial_info.trial_status IN ('expired', 'converted_to_paid'));
END;
$$;

-- Update the check_email_trial_history function to return trial completion status
CREATE OR REPLACE FUNCTION check_email_trial_history(p_email text)
RETURNS TABLE(
    has_used_trial boolean,
    trial_completed boolean,
    ever_subscribed boolean,
    requires_subscription boolean,
    deletion_reason text,
    deleted_at timestamptz,
    can_get_new_trial boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dah.trial_used as has_used_trial,
        dah.trial_completed,
        dah.ever_subscribed,
        dah.requires_immediate_subscription as requires_subscription,
        dah.deletion_reason,
        dah.account_deleted_at as deleted_at,
        dah.can_get_new_trial
    FROM deleted_account_history dah
    WHERE dah.email = p_email;
END;
$$;