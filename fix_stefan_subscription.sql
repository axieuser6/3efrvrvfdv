-- Fix Stefan's subscription manually
-- Replace the placeholder values with actual Stripe data

-- STEP 1: Update these values with Stefan's actual Stripe data
-- Get these from Stripe Dashboard → Customers → Stefan Miranda
DO $$
DECLARE
    stefan_user_id UUID;
    stefan_customer_id TEXT := 'REPLACE_WITH_ACTUAL_CUSTOMER_ID'; -- e.g., 'cus_QgXXXXXXXXXX'
    stefan_subscription_id TEXT := 'REPLACE_WITH_ACTUAL_SUBSCRIPTION_ID'; -- e.g., 'sub_XXXXXXXXXX' (if exists)
    stefan_price_id TEXT := 'REPLACE_WITH_ACTUAL_PRICE_ID'; -- Your SEK monthly price ID
    has_subscription BOOLEAN := false; -- Set to true if Stefan has a subscription in Stripe
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
    
    RAISE NOTICE 'Created/updated Stripe customer record for customer_id: %', stefan_customer_id;
    
    -- Only create subscription if Stefan actually has one in Stripe
    IF has_subscription THEN
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
            stefan_price_id,
            EXTRACT(EPOCH FROM NOW())::INTEGER,
            EXTRACT(EPOCH FROM (NOW() + INTERVAL '1 month'))::INTEGER,
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
        
        RAISE NOTICE 'Created/updated subscription record for subscription_id: %', stefan_subscription_id;
        
        -- Convert trial to paid subscription
        UPDATE user_trials 
        SET 
            trial_status = 'converted',
            deletion_scheduled_at = NULL,
            updated_at = NOW()
        WHERE user_id = stefan_user_id;
        
        RAISE NOTICE 'Converted trial to paid subscription';
        
    ELSE
        -- If no subscription exists, just create a basic subscription record
        INSERT INTO stripe_subscriptions (
            customer_id, 
            status,
            created_at,
            updated_at
        )
        VALUES (
            stefan_customer_id,
            'not_started',
            NOW(),
            NOW()
        )
        ON CONFLICT (customer_id) DO UPDATE SET
            status = EXCLUDED.status,
            updated_at = NOW();
        
        RAISE NOTICE 'Created basic subscription record (no active subscription)';
    END IF;
    
    -- Run protection functions
    PERFORM sync_subscription_status();
    PERFORM protect_paying_customers();
    
    RAISE NOTICE 'Ran sync and protection functions';
    
    -- Show final status
    RAISE NOTICE 'Stefan subscription fix completed!';
    
END $$;

-- STEP 2: Verify the fix worked
SELECT 
    'Stefan User Info' as info_type,
    u.email,
    u.id as user_id
FROM auth.users u 
WHERE u.email = 'stefan@mocksender.shop'

UNION ALL

SELECT 
    'Stripe Customer' as info_type,
    sc.customer_id,
    sc.user_id::text
FROM stripe_customers sc
WHERE sc.user_id = (SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop')

UNION ALL

SELECT 
    'Subscription Status' as info_type,
    ss.status,
    ss.subscription_id
FROM stripe_subscriptions ss
WHERE ss.customer_id = (
    SELECT customer_id FROM stripe_customers 
    WHERE user_id = (SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop')
)

UNION ALL

SELECT 
    'Trial Status' as info_type,
    ut.trial_status,
    ut.trial_end_date::text
FROM user_trials ut
WHERE ut.user_id = (SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop');

-- STEP 3: Check what the frontend will see
SELECT 
    user_id,
    customer_id,
    subscription_id,
    subscription_status,
    trial_status,
    trial_days_remaining
FROM stripe_user_subscriptions 
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop');
