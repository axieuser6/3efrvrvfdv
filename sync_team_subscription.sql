-- 🚀 SYNC TEAM SUBSCRIPTION FOR stefanjohnmiranda3@gmail.com
-- Run this in Supabase SQL Editor to manually sync the Team Pro subscription

DO $$
DECLARE
    team_admin_user_id uuid;
    team_id uuid;
BEGIN
    -- Get the user ID for stefanjohnmiranda3@gmail.com
    SELECT id INTO team_admin_user_id 
    FROM auth.users 
    WHERE email = 'stefanjohnmiranda3@gmail.com';
    
    IF team_admin_user_id IS NULL THEN
        RAISE NOTICE '❌ User not found: stefanjohnmiranda3@gmail.com';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Found user: % with ID: %', 'stefanjohnmiranda3@gmail.com', team_admin_user_id;
    
    -- 1. Create/update stripe customer record
    INSERT INTO stripe_customers (user_id, customer_id, email, created_at, updated_at)
    VALUES (team_admin_user_id, 'cus_Ss9R5F4PfWUm5Z', 'stefanjohnmiranda3@gmail.com', now(), now())
    ON CONFLICT (user_id) DO UPDATE SET
        customer_id = 'cus_Ss9R5F4PfWUm5Z',
        email = 'stefanjohnmiranda3@gmail.com',
        updated_at = now();
    
    -- 2. Create/update stripe subscription record
    INSERT INTO stripe_subscriptions (
        user_id, customer_id, subscription_id, status, price_id,
        current_period_start, current_period_end, cancel_at_period_end,
        created_at, updated_at
    )
    VALUES (
        team_admin_user_id,
        'cus_Ss9R5F4PfWUm5Z',
        'sub_team_' || team_admin_user_id, -- Generate subscription ID
        'active',
        'price_1RwP9cBacFXEnBmNsM3xVLL2', -- ACTUAL subscribed price ID
        extract(epoch from now())::bigint,
        extract(epoch from (now() + interval '1 month'))::bigint,
        false,
        now(),
        now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        customer_id = 'cus_Ss9R5F4PfWUm5Z',
        status = 'active',
        price_id = 'price_1RwP9cBacFXEnBmNsM3xVLL2',
        current_period_start = extract(epoch from now())::bigint,
        current_period_end = extract(epoch from (now() + interval '1 month'))::bigint,
        cancel_at_period_end = false,
        updated_at = now();
    
    -- 3. Update user account state
    INSERT INTO user_account_state (
        user_id, account_status, has_access, access_level,
        stripe_customer_id, stripe_subscription_id, subscription_status,
        current_period_end, axie_studio_status, created_at, updated_at
    )
    VALUES (
        team_admin_user_id, 'premium_active', true, 'team_pro',
        'cus_Ss9R5F4PfWUm5Z', 'sub_team_' || team_admin_user_id, 'active',
        now() + interval '1 month', 'active', now(), now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        account_status = 'premium_active',
        has_access = true,
        access_level = 'team_pro',
        stripe_customer_id = 'cus_Ss9R5F4PfWUm5Z',
        stripe_subscription_id = 'sub_team_' || user_account_state.user_id,
        subscription_status = 'active',
        current_period_end = now() + interval '1 month',
        axie_studio_status = 'active',
        updated_at = now();
    
    -- 4. Update trial status
    INSERT INTO user_trials (user_id, trial_start_date, trial_end_date, trial_status, created_at, updated_at)
    SELECT team_admin_user_id, created_at, created_at + interval '7 days', 'converted_to_paid', now(), now()
    FROM auth.users WHERE id = team_admin_user_id
    ON CONFLICT (user_id) DO UPDATE SET
        trial_status = 'converted_to_paid',
        updated_at = now();
    
    -- 5. Check if team already exists, if not create one
    SELECT id INTO team_id FROM teams WHERE admin_user_id = team_admin_user_id;
    
    IF team_id IS NULL THEN
        -- Create team for the admin
        INSERT INTO teams (name, admin_user_id, stripe_subscription_id, stripe_customer_id, max_members, current_members, status, created_at, updated_at)
        VALUES ('Stefan Team', team_admin_user_id, 'sub_team_' || team_admin_user_id, 'cus_Ss9R5F4PfWUm5Z', 5, 1, 'active', now(), now())
        RETURNING id INTO team_id;
        
        RAISE NOTICE '✅ Created team with ID: %', team_id;
    ELSE
        -- Update existing team
        UPDATE teams SET
            stripe_subscription_id = 'sub_team_' || team_admin_user_id,
            stripe_customer_id = 'cus_Ss9R5F4PfWUm5Z',
            status = 'active',
            updated_at = now()
        WHERE id = team_id;
        
        RAISE NOTICE '✅ Updated existing team with ID: %', team_id;
    END IF;
    
    -- 6. Create team subscription record
    INSERT INTO team_subscriptions (
        team_id, stripe_subscription_id, stripe_customer_id, status,
        current_period_start, current_period_end, cancel_at_period_end,
        price_id, created_at, updated_at
    )
    VALUES (
        team_id, 'sub_team_' || team_admin_user_id, 'cus_Ss9R5F4PfWUm5Z', 'active',
        extract(epoch from now())::bigint,
        extract(epoch from (now() + interval '1 month'))::bigint,
        false, 'price_1RwP9cBacFXEnBmNsM3xVLL2', now(), now()
    )
    ON CONFLICT (team_id) DO UPDATE SET
        stripe_subscription_id = 'sub_team_' || team_admin_user_id,
        stripe_customer_id = 'cus_Ss9R5F4PfWUm5Z',
        status = 'active',
        current_period_start = extract(epoch from now())::bigint,
        current_period_end = extract(epoch from (now() + interval '1 month'))::bigint,
        cancel_at_period_end = false,
        price_id = 'price_1RwP9cBacFXEnBmNsM3xVLL2',
        updated_at = now();
    
    RAISE NOTICE '🎉 TEAM SUBSCRIPTION SYNC COMPLETE!';
    RAISE NOTICE 'stefanjohnmiranda3@gmail.com now has Team Pro subscription with team management capabilities';
    
END $$;

-- Verify the setup
SELECT 
    'VERIFICATION' as status,
    u.email,
    uas.account_status,
    uas.has_access,
    uas.access_level,
    ss.status as subscription_status,
    ss.price_id,
    t.name as team_name,
    t.current_members,
    t.max_members
FROM auth.users u
LEFT JOIN user_account_state uas ON u.id = uas.user_id
LEFT JOIN stripe_subscriptions ss ON u.id = ss.user_id
LEFT JOIN teams t ON u.id = t.admin_user_id
WHERE u.email = 'stefanjohnmiranda3@gmail.com';
