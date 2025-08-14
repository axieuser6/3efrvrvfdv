-- Manual sync for Stefan's subscription
-- Run this in Supabase SQL Editor to fix Stefan's account

-- First, let's check Stefan's user ID
DO $$
DECLARE
    stefan_user_id UUID;
    stefan_customer_id TEXT := 'cus_QgXXXXXXXXXXXX'; -- Replace with actual Stripe customer ID
    stefan_subscription_id TEXT := 'sub_XXXXXXXXXX'; -- Replace with actual subscription ID
    stefan_price_id TEXT; -- We'll need the actual price ID from Stripe
BEGIN
    -- Get Stefan's user ID
    SELECT id INTO stefan_user_id 
    FROM auth.users 
    WHERE email = 'stefan@mocksender.shop';
    
    IF stefan_user_id IS NULL THEN
        RAISE EXCEPTION 'User stefan@mocksender.shop not found';
    END IF;
    
    RAISE NOTICE 'Found Stefan user ID: %', stefan_user_id;
    
    -- Create Stripe customer record
    INSERT INTO stripe_customers (user_id, customer_id, email, created_at, updated_at)
    VALUES (stefan_user_id, stefan_customer_id, 'stefan@mocksender.shop', NOW(), NOW())
    ON CONFLICT (user_id) DO UPDATE SET
        customer_id = EXCLUDED.customer_id,
        email = EXCLUDED.email,
        updated_at = NOW();
    
    RAISE NOTICE 'Created/updated Stripe customer record';
    
    -- Create subscription record (you'll need to update with actual values)
    INSERT INTO stripe_subscriptions (
        customer_id, 
        subscription_id, 
        status, 
        price_id,
        current_period_start,
        current_period_end,
        cancel_at_period_end,
        created_at,
        updated_at
    )
    VALUES (
        stefan_customer_id,
        stefan_subscription_id,
        'active',
        stefan_price_id, -- Update this with actual price ID
        EXTRACT(EPOCH FROM NOW())::INTEGER, -- Current time as Unix timestamp
        EXTRACT(EPOCH FROM (NOW() + INTERVAL '1 month'))::INTEGER, -- One month from now
        false,
        NOW(),
        NOW()
    )
    ON CONFLICT (customer_id) DO UPDATE SET
        subscription_id = EXCLUDED.subscription_id,
        status = EXCLUDED.status,
        price_id = EXCLUDED.price_id,
        current_period_start = EXCLUDED.current_period_start,
        current_period_end = EXCLUDED.current_period_end,
        updated_at = NOW();
    
    RAISE NOTICE 'Created/updated subscription record';
    
    -- Update trial status to converted
    UPDATE user_trials 
    SET 
        trial_status = 'converted',
        deletion_scheduled_at = NULL,
        updated_at = NOW()
    WHERE user_id = stefan_user_id;
    
    RAISE NOTICE 'Updated trial status to converted';
    
    -- Run protection functions
    PERFORM sync_subscription_status();
    PERFORM protect_paying_customers();
    
    RAISE NOTICE 'Ran protection functions';
    
END $$;
