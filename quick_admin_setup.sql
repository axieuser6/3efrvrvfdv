-- 🚀 QUICK ADMIN SETUP - Copy and paste this into Supabase SQL Editor

-- Get admin user ID first
DO $$
DECLARE
    admin_user_id uuid;
BEGIN
    -- Get admin user ID
    SELECT id INTO admin_user_id 
    FROM auth.users 
    WHERE email = 'stefanjohnmiranda5@gmail.com';
    
    IF admin_user_id IS NULL THEN
        RAISE NOTICE '❌ Admin user not found with email stefanjohnmiranda5@gmail.com';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Found admin user: %', admin_user_id;
    
    -- 1. Update user profile
    INSERT INTO user_profiles (id, email, full_name, created_at, updated_at)
    VALUES (admin_user_id, 'stefanjohnmiranda5@gmail.com', 'Stefan John Miranda (Admin)', now(), now())
    ON CONFLICT (id) DO UPDATE SET
        full_name = 'Stefan John Miranda (Admin)',
        updated_at = now();
    
    -- 2. Create/update stripe customer
    INSERT INTO stripe_customers (user_id, customer_id, email, created_at, updated_at)
    VALUES (admin_user_id, 'cus_admin_' || admin_user_id, 'stefanjohnmiranda5@gmail.com', now(), now())
    ON CONFLICT (user_id) DO UPDATE SET
        customer_id = 'cus_admin_' || admin_user_id,
        updated_at = now();
    
    -- 3. Create/update PRO subscription with infinite time
    INSERT INTO stripe_subscriptions (
        user_id, customer_id, subscription_id, status, price_id,
        current_period_start, current_period_end, cancel_at_period_end,
        created_at, updated_at
    )
    VALUES (
        admin_user_id,
        'cus_admin_' || admin_user_id,
        'sub_admin_pro_' || admin_user_id,
        'active',
        'price_1Rv4rDBacFXEnBmNDMrhMqOH',  -- PRO price ID
        extract(epoch from now())::bigint,
        extract(epoch from (now() + interval '100 years'))::bigint,  -- Infinite
        false,
        now(),
        now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        status = 'active',
        price_id = 'price_1Rv4rDBacFXEnBmNDMrhMqOH',
        current_period_start = extract(epoch from now())::bigint,
        current_period_end = extract(epoch from (now() + interval '100 years'))::bigint,
        cancel_at_period_end = false,
        updated_at = now();
    
    -- 4. Update account state
    INSERT INTO user_account_state (
        user_id, account_status, has_access, access_level,
        stripe_customer_id, stripe_subscription_id, subscription_status,
        current_period_end, axie_studio_status, created_at, updated_at
    )
    VALUES (
        admin_user_id, 'premium_active', true, 'pro',
        'cus_admin_' || admin_user_id, 'sub_admin_pro_' || admin_user_id, 'active',
        now() + interval '100 years', 'active', now(), now()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        account_status = 'premium_active',
        has_access = true,
        access_level = 'pro',
        stripe_customer_id = 'cus_admin_' || user_account_state.user_id,
        stripe_subscription_id = 'sub_admin_pro_' || user_account_state.user_id,
        subscription_status = 'active',
        current_period_end = now() + interval '100 years',
        axie_studio_status = 'active',
        updated_at = now();
    
    -- 5. Update trial status
    INSERT INTO user_trials (user_id, trial_start_date, trial_end_date, trial_status, created_at, updated_at)
    SELECT admin_user_id, created_at, created_at + interval '7 days', 'converted_to_paid', now(), now()
    FROM auth.users WHERE id = admin_user_id
    ON CONFLICT (user_id) DO UPDATE SET
        trial_status = 'converted_to_paid',
        updated_at = now();
    
    RAISE NOTICE '🎉 ADMIN SETUP COMPLETE! stefanjohnmiranda5@gmail.com now has PRO subscription with infinite time';
    
END $$;
