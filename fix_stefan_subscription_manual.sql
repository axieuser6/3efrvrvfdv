-- Manual fix for Stefan's subscription status
-- Run this in Supabase SQL Editor

DO $$
DECLARE
    stefan_user_id UUID;
    stefan_customer_id TEXT := 'cus_REPLACE_WITH_ACTUAL_ID'; -- Get from Stripe Dashboard
BEGIN
    -- Get Stefan's user ID
    SELECT id INTO stefan_user_id 
    FROM auth.users 
    WHERE email = 'stefan@mocksender.shop';
    
    IF stefan_user_id IS NULL THEN
        RAISE EXCEPTION 'User stefan@mocksender.shop not found';
    END IF;
    
    RAISE NOTICE 'Found Stefan user ID: %', stefan_user_id;
    
    -- Create/update Stripe customer record
    INSERT INTO stripe_customers (user_id, customer_id, created_at, updated_at)
    VALUES (stefan_user_id, stefan_customer_id, NOW(), NOW())
    ON CONFLICT (user_id) DO UPDATE SET
        customer_id = EXCLUDED.customer_id,
        updated_at = NOW();
    
    RAISE NOTICE 'Created/updated customer record';
    
    -- Create subscription record for one-time payment (this is key!)
    INSERT INTO stripe_subscriptions (
        customer_id, 
        status,
        created_at,
        updated_at
    )
    VALUES (
        stefan_customer_id,
        'active', -- Change from 'one_time_payment' to 'active'
        NOW(),
        NOW()
    )
    ON CONFLICT (customer_id) DO UPDATE SET
        status = 'active', -- Make sure it's active
        updated_at = NOW();
    
    RAISE NOTICE 'Created/updated subscription with active status';
    
    -- Convert trial to paid
    UPDATE user_trials 
    SET 
        trial_status = 'converted',
        deletion_scheduled_at = NULL,
        updated_at = NOW()
    WHERE user_id = stefan_user_id;
    
    RAISE NOTICE 'Converted trial to paid status';
    
    -- Run protection functions
    PERFORM sync_subscription_status();
    PERFORM protect_paying_customers();
    
    RAISE NOTICE 'Stefan subscription fix completed!';
    
END $$;

-- Verify the fix
SELECT 
    'Final Status Check' as info,
    user_id,
    customer_id,
    subscription_status,
    trial_status,
    trial_days_remaining::text
FROM stripe_user_subscriptions 
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop');
