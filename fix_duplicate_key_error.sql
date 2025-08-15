-- 🔧 FIX DUPLICATE KEY ERROR - ROBUST TEAM MEMBER CREATION
-- This version handles all potential duplicate key conflicts

-- 1. DROP AND RECREATE THE FUNCTION WITH BETTER ERROR HANDLING
DROP FUNCTION IF EXISTS create_team_member(text, text, text, uuid);

CREATE OR REPLACE FUNCTION create_team_member(
  p_email text,
  p_password text,
  p_display_name text,
  p_admin_user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_team_id uuid;
  v_new_user_id uuid;
  v_team_current_members integer;
  v_team_max_members integer;
  v_admin_has_subscription boolean := false;
  v_existing_user_id uuid;
BEGIN
  -- Verify the admin is actually a team admin
  SELECT t.id, t.current_members, t.max_members 
  INTO v_team_id, v_team_current_members, v_team_max_members
  FROM teams t
  WHERE t.admin_user_id = p_admin_user_id AND t.status = 'active';
  
  IF v_team_id IS NULL THEN
    RAISE EXCEPTION 'User is not a team admin or team is not active';
  END IF;
  
  -- Check if admin has active subscription
  SELECT EXISTS (
    SELECT 1 FROM team_subscriptions ts
    WHERE ts.team_id = v_team_id
    AND ts.status = 'active'
    AND ts.price_id IN ('price_1RwOhVBacFXEnBmNIeWQ1wQe', 'price_1RwP9cBacFXEnBmNsM3xVLL2')
  ) INTO v_admin_has_subscription;
  
  -- Check team member limit
  IF v_team_current_members >= v_team_max_members THEN
    RAISE EXCEPTION 'Team is full. Maximum % members allowed.', v_team_max_members;
  END IF;
  
  -- Check if email already exists
  SELECT id INTO v_existing_user_id FROM auth.users WHERE email = p_email;
  IF v_existing_user_id IS NOT NULL THEN
    RAISE EXCEPTION 'User with email % already exists', p_email;
  END IF;
  
  -- Generate new user ID
  v_new_user_id := gen_random_uuid();
  
  -- Ensure the UUID doesn't already exist (very unlikely but possible)
  WHILE EXISTS (SELECT 1 FROM auth.users WHERE id = v_new_user_id) LOOP
    v_new_user_id := gen_random_uuid();
  END LOOP;
  
  -- Create user in auth.users table with minimal required fields
  BEGIN
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      created_at,
      updated_at,
      confirmation_token,
      email_change,
      email_change_token_new,
      recovery_token
    ) VALUES (
      v_new_user_id,
      '00000000-0000-0000-0000-000000000000',
      p_email,
      crypt(p_password, gen_salt('bf')),
      now(), -- Auto-confirm email
      now(),
      now(),
      '',
      '',
      '',
      ''
    );
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Failed to create user account - ID conflict';
  END;
  
  -- Create user profile with conflict handling
  BEGIN
    INSERT INTO user_profiles (
      id,
      email,
      full_name,
      created_at,
      updated_at
    ) VALUES (
      v_new_user_id,
      p_email,
      COALESCE(p_display_name, ''),
      now(),
      now()
    );
  EXCEPTION WHEN unique_violation THEN
    -- Update existing profile if it exists
    UPDATE user_profiles SET
      email = p_email,
      full_name = COALESCE(p_display_name, ''),
      updated_at = now()
    WHERE id = v_new_user_id;
  END;
  
  -- Create user account state with conflict handling
  BEGIN
    INSERT INTO user_account_state (
      user_id,
      account_status,
      has_access,
      access_level,
      subscription_status,
      current_period_end,
      axie_studio_status,
      created_at,
      updated_at
    ) VALUES (
      v_new_user_id,
      CASE WHEN v_admin_has_subscription THEN 'subscription_active'::user_account_status ELSE 'trial_active'::user_account_status END,
      true,
      CASE WHEN v_admin_has_subscription THEN 'pro'::user_access_level ELSE 'trial'::user_access_level END,
      CASE WHEN v_admin_has_subscription THEN 'active' ELSE 'inactive' END,
      CASE WHEN v_admin_has_subscription THEN now() + interval '1 month' ELSE now() + interval '7 days' END,
      CASE WHEN v_admin_has_subscription THEN 'active' ELSE 'inactive' END,
      now(),
      now()
    );
  EXCEPTION WHEN unique_violation THEN
    -- Update existing account state
    UPDATE user_account_state SET
      account_status = CASE WHEN v_admin_has_subscription THEN 'subscription_active'::user_account_status ELSE 'trial_active'::user_account_status END,
      has_access = true,
      access_level = CASE WHEN v_admin_has_subscription THEN 'pro'::user_access_level ELSE 'trial'::user_access_level END,
      subscription_status = CASE WHEN v_admin_has_subscription THEN 'active' ELSE 'inactive' END,
      current_period_end = CASE WHEN v_admin_has_subscription THEN now() + interval '1 month' ELSE now() + interval '7 days' END,
      axie_studio_status = CASE WHEN v_admin_has_subscription THEN 'active' ELSE 'inactive' END,
      updated_at = now()
    WHERE user_id = v_new_user_id;
  END;
  
  -- Create user trial record with conflict handling
  BEGIN
    INSERT INTO user_trials (
      user_id,
      trial_start_date,
      trial_end_date,
      trial_status,
      created_at,
      updated_at
    ) VALUES (
      v_new_user_id,
      now(),
      now() + interval '7 days',
      CASE WHEN v_admin_has_subscription THEN 'converted_to_paid' ELSE 'active' END,
      now(),
      now()
    );
  EXCEPTION WHEN unique_violation THEN
    -- Update existing trial
    UPDATE user_trials SET
      trial_status = CASE WHEN v_admin_has_subscription THEN 'converted_to_paid' ELSE 'active' END,
      trial_end_date = now() + interval '7 days',
      updated_at = now()
    WHERE user_id = v_new_user_id;
  END;
  
  -- Add to team members (this should not conflict as it's a new relationship)
  INSERT INTO team_members (
    team_id,
    user_id,
    role,
    status,
    display_name,
    created_by,
    created_at,
    updated_at
  ) VALUES (
    v_team_id,
    v_new_user_id,
    'member',
    'active',
    COALESCE(p_display_name, ''),
    p_admin_user_id,
    now(),
    now()
  );
  
  -- Update team member count
  UPDATE teams 
  SET 
    current_members = current_members + 1,
    updated_at = now()
  WHERE id = v_team_id;
  
  RETURN json_build_object(
    'success', true,
    'message', 'Team member created successfully',
    'user_id', v_new_user_id,
    'email', p_email,
    'display_name', COALESCE(p_display_name, ''),
    'initial_access_level', CASE WHEN v_admin_has_subscription THEN 'pro' ELSE 'standard' END,
    'axiestudio_status', CASE WHEN v_admin_has_subscription THEN 'active' ELSE 'inactive' END
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM,
    'detail', 'Error creating team member: ' || SQLERRM
  );
END;
$$;

-- 2. GRANT PERMISSIONS
GRANT EXECUTE ON FUNCTION create_team_member TO authenticated;

-- 3. TEST QUERY (optional)
SELECT 'Robust team member creation function ready! Duplicate key errors should be resolved.' as status;
