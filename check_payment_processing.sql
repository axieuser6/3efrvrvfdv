-- Check if the Stripe payment was processed correctly for stefan@mocksender.shop

-- 1. Find the user
SELECT 
    id,
    email,
    created_at
FROM auth.users 
WHERE email = 'stefan@mocksender.shop';

-- 2. Check subscription status
SELECT 
    customer_id,
    subscription_id,
    status,
    price_id,
    current_period_start,
    current_period_end,
    cancel_at_period_end,
    created_at,
    updated_at
FROM stripe_subscriptions 
WHERE customer_id IN (
    SELECT customer_id 
    FROM stripe_customers 
    WHERE email = 'stefan@mocksender.shop'
);

-- 3. Check customer record
SELECT 
    customer_id,
    email,
    user_id,
    created_at
FROM stripe_customers 
WHERE email = 'stefan@mocksender.shop';

-- 4. Check trial status (should be converted or protected)
SELECT 
    user_id,
    trial_status,
    trial_start_date,
    trial_end_date,
    deletion_scheduled_at
FROM user_trials 
WHERE user_id = (
    SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop'
);

-- 5. Check account state
SELECT 
    user_id,
    account_status,
    has_access,
    access_level,
    trial_days_remaining
FROM user_account_state 
WHERE user_id = (
    SELECT id FROM auth.users WHERE email = 'stefan@mocksender.shop'
);

-- 6. Check recent webhook events (if logged)
SELECT 
    event_type,
    processed_at,
    customer_id,
    subscription_id
FROM webhook_events 
WHERE customer_id IN (
    SELECT customer_id 
    FROM stripe_customers 
    WHERE email = 'stefan@mocksender.shop'
)
ORDER BY processed_at DESC
LIMIT 5;
