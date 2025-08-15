-- 🚀 SETUP BOTH USERS WITH THEIR SUBSCRIPTIONS
-- Run this in Supabase SQL Editor

DO $$
DECLARE
    team_admin_user_id uuid;
    pro_user_id uuid;
    created_team_id uuid;
    existing_customer_id text;
BEGIN
    RAISE NOTICE '🚀 STARTING DUAL USER SUBSCRIPTION SETUP...';

    -- Clean up any existing conflicting data first
    RAISE NOTICE '🧹 Cleaning up existing data...';

    -- Get user IDs first
    SELECT id INTO team_admin_user_id FROM auth.users WHERE email = 'stefanjohnmiranda3@gmail.com';
    SELECT id INTO pro_user_id FROM auth.users WHERE email = 'stefanjohnmiranda4@gmail.com';

    -- Clean up existing data for these specific users
    IF team_admin_user_id IS NOT NULL THEN
        -- Clean up team admin's existing data
        DELETE FROM team_subscriptions WHERE team_id IN (SELECT id FROM teams WHERE admin_user_id = team_admin_user_id);
        DELETE FROM teams WHERE admin_user_id = team_admin_user_id;
        DELETE FROM stripe_subscriptions WHERE customer_id IN (SELECT customer_id FROM stripe_customers WHERE user_id = team_admin_user_id);
        DELETE FROM stripe_customers WHERE user_id = team_admin_user_id;
    END IF;

    IF pro_user_id IS NOT NULL THEN
        -- Clean up pro user's existing data
        DELETE FROM stripe_subscriptions WHERE customer_id IN (SELECT customer_id FROM stripe_customers WHERE user_id = pro_user_id);
        DELETE FROM stripe_customers WHERE user_id = pro_user_id;
    END IF;

    -- Also clean up any orphaned records with the target customer IDs
    DELETE FROM team_subscriptions WHERE stripe_customer_id IN ('cus_Ss9R5F4PfWUm5Z', 'cus_Ss9T9VfuTDDdsw');
    DELETE FROM stripe_subscriptions WHERE customer_id IN ('cus_Ss9R5F4PfWUm5Z', 'cus_Ss9T9VfuTDDdsw');

    -- ========================================
    -- 👑 SETUP TEAM ADMIN: stefanjohnmiranda3@gmail.com
    -- ========================================

    IF team_admin_user_id IS NULL THEN
        RAISE NOTICE '❌ Team admin user not found: stefanjohnmiranda3@gmail.com';
    ELSE
        RAISE NOTICE '✅ Found team admin: stefanjohnmiranda3@gmail.com (ID: %)', team_admin_user_id;
        
        -- 1. Create/update stripe customer for team admin
        INSERT INTO stripe_customers (user_id, customer_id, created_at, updated_at)
        VALUES (team_admin_user_id, 'cus_Ss9R5F4PfWUm5Z', now(), now())
        ON CONFLICT (user_id) DO UPDATE SET
            customer_id = 'cus_Ss9R5F4PfWUm5Z',
            updated_at = now();
        
        -- 2. Create/update Team Pro subscription
        INSERT INTO stripe_subscriptions (
            customer_id, subscription_id, status, price_id,
            current_period_start, current_period_end, cancel_at_period_end,
            created_at, updated_at
        )
        VALUES (
            'cus_Ss9R5F4PfWUm5Z',
            'sub_team_' || team_admin_user_id,
            'active',
            'price_1RwP9cBacFXEnBmNsM3xVLL2', -- Team Pro price
            extract(epoch from now())::bigint,
            extract(epoch from (now() + interval '1 month'))::bigint,
            false,
            now(),
            now()
        )
        ON CONFLICT (customer_id) DO UPDATE SET
            subscription_id = 'sub_team_' || team_admin_user_id,
            status = 'active',
            price_id = 'price_1RwP9cBacFXEnBmNsM3xVLL2',
            current_period_start = extract(epoch from now())::bigint,
            current_period_end = extract(epoch from (now() + interval '1 month'))::bigint,
            cancel_at_period_end = false,
            updated_at = now();
        
        -- 3. Update team admin account state
        INSERT INTO user_account_state (
            user_id, account_status, has_access, access_level,
            stripe_customer_id, stripe_subscription_id, subscription_status,
            current_period_end, axie_studio_status, created_at, updated_at
        )
        VALUES (
            team_admin_user_id, 'subscription_active', true, 'enterprise',
            'cus_Ss9R5F4PfWUm5Z', 'sub_team_' || team_admin_user_id, 'active',
            now() + interval '1 month', 'active', now(), now()
        )
        ON CONFLICT (user_id) DO UPDATE SET
            account_status = 'subscription_active',
            has_access = true,
            access_level = 'enterprise',
            stripe_customer_id = 'cus_Ss9R5F4PfWUm5Z',
            stripe_subscription_id = 'sub_team_' || team_admin_user_id,
            subscription_status = 'active',
            current_period_end = now() + interval '1 month',
            axie_studio_status = 'active',
            updated_at = now();
        
        -- 4. Create team for admin
        INSERT INTO teams (name, admin_user_id, stripe_subscription_id, stripe_customer_id, max_members, current_members, status, created_at, updated_at)
        VALUES ('Stefan Team', team_admin_user_id, 'sub_team_' || team_admin_user_id, 'cus_Ss9R5F4PfWUm5Z', 5, 1, 'active', now(), now())
        ON CONFLICT (admin_user_id) DO UPDATE SET
            stripe_subscription_id = 'sub_team_' || teams.admin_user_id,
            stripe_customer_id = 'cus_Ss9R5F4PfWUm5Z',
            status = 'active',
            updated_at = now()
        RETURNING id INTO created_team_id;
        
        -- 5. Create team subscription record
        INSERT INTO team_subscriptions (
            team_id, stripe_subscription_id, stripe_customer_id, status,
            current_period_start, current_period_end, cancel_at_period_end,
            price_id, created_at, updated_at
        )
        VALUES (
            created_team_id,
            'sub_team_' || team_admin_user_id, 'cus_Ss9R5F4PfWUm5Z', 'active',
            extract(epoch from now())::bigint,
            extract(epoch from (now() + interval '1 month'))::bigint,
            false, 'price_1RwP9cBacFXEnBmNsM3xVLL2', now(), now()
        )
        ON CONFLICT (team_id) DO UPDATE SET
            stripe_subscription_id = 'sub_team_' || team_admin_user_id,
            stripe_customer_id = 'cus_Ss9R5F4PfWUm5Z',
            status = 'active',
            price_id = 'price_1RwP9cBacFXEnBmNsM3xVLL2',
            updated_at = now();
        
        RAISE NOTICE '✅ Team admin setup complete!';
    END IF;
    
    -- ========================================
    -- 💎 SETUP PRO USER: stefanjohnmiranda4@gmail.com
    -- ========================================

    IF pro_user_id IS NULL THEN
        RAISE NOTICE '❌ Pro user not found: stefanjohnmiranda4@gmail.com';
    ELSE
        RAISE NOTICE '✅ Found pro user: stefanjohnmiranda4@gmail.com (ID: %)', pro_user_id;
        
        -- 1. Create/update stripe customer for pro user
        INSERT INTO stripe_customers (user_id, customer_id, created_at, updated_at)
        VALUES (pro_user_id, 'cus_Ss9T9VfuTDDdsw', now(), now())
        ON CONFLICT (user_id) DO UPDATE SET
            customer_id = 'cus_Ss9T9VfuTDDdsw',
            updated_at = now();
        
        -- 2. Create/update Pro subscription
        INSERT INTO stripe_subscriptions (
            customer_id, subscription_id, status, price_id,
            current_period_start, current_period_end, cancel_at_period_end,
            created_at, updated_at
        )
        VALUES (
            'cus_Ss9T9VfuTDDdsw',
            'sub_pro_' || pro_user_id,
            'active',
            'price_1Rv4rDBacFXEnBmNDMrhMqOH', -- Go Pro price
            extract(epoch from now())::bigint,
            extract(epoch from (now() + interval '1 month'))::bigint,
            false,
            now(),
            now()
        )
        ON CONFLICT (customer_id) DO UPDATE SET
            subscription_id = 'sub_pro_' || pro_user_id,
            status = 'active',
            price_id = 'price_1Rv4rDBacFXEnBmNDMrhMqOH',
            current_period_start = extract(epoch from now())::bigint,
            current_period_end = extract(epoch from (now() + interval '1 month'))::bigint,
            cancel_at_period_end = false,
            updated_at = now();
        
        -- 3. Update pro user account state
        INSERT INTO user_account_state (
            user_id, account_status, has_access, access_level,
            stripe_customer_id, stripe_subscription_id, subscription_status,
            current_period_end, axie_studio_status, created_at, updated_at
        )
        VALUES (
            pro_user_id, 'subscription_active', true, 'pro',
            'cus_Ss9T9VfuTDDdsw', 'sub_pro_' || pro_user_id, 'active',
            now() + interval '1 month', 'active', now(), now()
        )
        ON CONFLICT (user_id) DO UPDATE SET
            account_status = 'subscription_active',
            has_access = true,
            access_level = 'pro',
            stripe_customer_id = 'cus_Ss9T9VfuTDDdsw',
            stripe_subscription_id = 'sub_pro_' || pro_user_id,
            subscription_status = 'active',
            current_period_end = now() + interval '1 month',
            axie_studio_status = 'active',
            updated_at = now();
        
        RAISE NOTICE '✅ Pro user setup complete!';
    END IF;
    
    -- Update trial status for both users
    INSERT INTO user_trials (user_id, trial_start_date, trial_end_date, trial_status, created_at, updated_at)
    SELECT u.id, u.created_at, u.created_at + interval '7 days', 'converted_to_paid', now(), now()
    FROM auth.users u
    WHERE u.email IN ('stefanjohnmiranda3@gmail.com', 'stefanjohnmiranda4@gmail.com')
    ON CONFLICT (user_id) DO UPDATE SET
        trial_status = 'converted_to_paid',
        updated_at = now();
    
    RAISE NOTICE '🎉 DUAL USER SETUP COMPLETE!';
    
END $$;

-- ========================================
-- 📊 VERIFICATION QUERIES
-- ========================================

-- Verify Team Admin Setup
SELECT
    '👑 TEAM ADMIN VERIFICATION' as status,
    u.email,
    uas.account_status,
    uas.has_access,
    uas.access_level,
    ss.status as subscription_status,
    ss.price_id,
    t.name as team_name,
    t.current_members,
    t.max_members,
    ts.status as team_subscription_status
FROM auth.users u
LEFT JOIN user_account_state uas ON u.id = uas.user_id
LEFT JOIN stripe_customers sc ON u.id = sc.user_id
LEFT JOIN stripe_subscriptions ss ON sc.customer_id = ss.customer_id
LEFT JOIN teams t ON u.id = t.admin_user_id
LEFT JOIN team_subscriptions ts ON t.id = ts.team_id
WHERE u.email = 'stefanjohnmiranda3@gmail.com';

-- Verify Pro User Setup
SELECT
    '💎 PRO USER VERIFICATION' as status,
    u.email,
    uas.account_status,
    uas.has_access,
    uas.access_level,
    ss.status as subscription_status,
    ss.price_id,
    ut.trial_status
FROM auth.users u
LEFT JOIN user_account_state uas ON u.id = uas.user_id
LEFT JOIN stripe_customers sc ON u.id = sc.user_id
LEFT JOIN stripe_subscriptions ss ON sc.customer_id = ss.customer_id
LEFT JOIN user_trials ut ON u.id = ut.user_id
WHERE u.email = 'stefanjohnmiranda4@gmail.com';

SELECT '✅ SETUP COMPLETE! Both users are ready for testing!' as final_status;
