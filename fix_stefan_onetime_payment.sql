-- Fix Stefan's one-time payment manually
-- Run this in Supabase SQL Editor

DO $$
DECLARE
    stefan_user_id UUID;
    stefan_customer_id TEXT := 'cus_QgXXXXXXXXXX'; -- Replace with actual customer ID from Stripe
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
    INSERT INTO stripe_customers (user_id, customer_id, created_at, updated_at)
    VALUES (stefan_user_id, stefan_customer_id, NOW(), NOW())
    ON CONFLICT (user_id) DO UPDATE SET
        customer_id = EXCLUDED.customer_id,
        updated_at = NOW();
    
    RAISE NOTICE 'Created/updated Stripe customer record for customer_id: %', stefan_customer_id;
    
    -- Create subscription record for one-time payment
    INSERT INTO stripe_subscriptions (
        customer_id, 
        status,
        created_at,
        updated_at
    )
    VALUES (
        stefan_customer_id,
        'one_time_payment', -- Special status for one-time payments
        NOW(),
        NOW()
    )
    ON CONFLICT (customer_id) DO UPDATE SET
        status = EXCLUDED.status,
        updated_at = NOW();
    
    RAISE NOTICE 'Created subscription record with one_time_payment status';
    
    -- Convert trial to paid (even for one-time payment)
    UPDATE user_trials 
    SET 
        trial_status = 'converted',
        deletion_scheduled_at = NULL,
        updated_at = NOW()
    WHERE user_id = stefan_user_id;
    
    RAISE NOTICE 'Converted trial to paid status';
    
    -- Create order record for the SEK 10.00 payment
    INSERT INTO stripe_orders (
        checkout_session_id,
        payment_intent_id,
        customer_id,
        amount_subtotal,
        amount_total,
        currency,
        payment_status,
        status,
        created_at,
        updated_at
    )
    VALUES (
        'cs_live_a1QBqRUJjWYaksxBrs8OxFFDwTzPE0ZOScmXbpCISaagkttDYf06s58XYG', -- From webhook data
        'pi_3Rvk4DBacFXEnBmN1Zz7qTbQ', -- From webhook data
        stefan_customer_id,
        1000, -- SEK 10.00 in cents
        1000,
        'sek',
        'paid',
        'completed',
        NOW(),
        NOW()
    )
    ON CONFLICT (checkout_session_id) DO NOTHING;
    
    RAISE NOTICE 'Created order record for SEK 10.00 payment';
    
    -- Run protection functions
    PERFORM sync_subscription_status();
    PERFORM protect_paying_customers();
    
    RAISE NOTICE 'Ran sync and protection functions';
    RAISE NOTICE 'Stefan one-time payment fix completed!';
    
END $$;

-- Verify the fix
SELECT 
    'User Info' as type,
    u.email,
    u.id::text as value
FROM auth.users u 
WHERE u.email = 'stefan@mocksender.shop'

UNION ALL

SELECT 
    'Customer' as type,
    'customer_id' as email,
    sc.customer_id as value
FROM stripe_customers sc
WHERE sc.user_id = (SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop')

UNION ALL

SELECT 
    'Subscription' as type,
    'status' as email,
    ss.status as value
FROM stripe_subscriptions ss
WHERE ss.customer_id = (
    SELECT customer_id FROM stripe_customers 
    WHERE user_id = (SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop')
)

UNION ALL

SELECT 
    'Trial' as type,
    'status' as email,
    ut.trial_status as value
FROM user_trials ut
WHERE ut.user_id = (SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop')

UNION ALL

SELECT 
    'Order' as type,
    'amount' as email,
    so.amount_total::text as value
FROM stripe_orders so
WHERE so.customer_id = (
    SELECT customer_id FROM stripe_customers 
    WHERE user_id = (SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop')
);

-- Check what the frontend will see
SELECT 
    user_id,
    customer_id,
    subscription_id,
    subscription_status,
    trial_status,
    trial_days_remaining
FROM stripe_user_subscriptions 
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop');
