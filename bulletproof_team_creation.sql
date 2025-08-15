-- 🛡️ BULLETPROOF TEAM MEMBER CREATION
-- This version avoids all UUID conflicts by using a different approach

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
  v_retry_count integer := 0;
  v_max_retries integer := 5;
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
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
    RAISE EXCEPTION 'User with email % already exists', p_email;
  END IF;
  
  -- Generate unique user ID with retry logic
  LOOP
    v_new_user_id := gen_random_uuid();
    v_retry_count := v_retry_count + 1;
    
    -- Check if this UUID is truly unique across all relevant tables
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = v_new_user_id) AND
       NOT EXISTS (SELECT 1 FROM user_profiles WHERE id = v_new_user_id) AND
       NOT EXISTS (SELECT 1 FROM user_account_state WHERE user_id = v_new_user_id) AND
       NOT EXISTS (SELECT 1 FROM user_trials WHERE user_id = v_new_user_id) THEN
      EXIT; -- UUID is unique, exit loop
    END IF;
    
    -- Safety check to prevent infinite loop
    IF v_retry_count > v_max_retries THEN
      RAISE EXCEPTION 'Could not generate unique user ID after % attempts', v_max_retries;
    END IF;
  END LOOP;
  
  -- Create user in auth.users table with error handling
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
      now(),
      now(),
      now(),
      '',
      '',
      '',
      ''
    );
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'Failed to create user account - UUID conflict in auth.users';
  END;
  
  -- Create user profile with error handling
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
    -- If profile exists, update it
    UPDATE user_profiles SET
      email = p_email,
      full_name = COALESCE(p_display_name, ''),
      updated_at = now()
    WHERE id = v_new_user_id;
  END;
  
  -- Create user account state by copying from admin pattern
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
    )
    SELECT 
      v_new_user_id,
      CASE 
        WHEN v_admin_has_subscription THEN uas.account_status 
        ELSE 'trial_active'
      END,
      true,
      CASE 
        WHEN v_admin_has_subscription THEN 'pro'
        ELSE 'trial'
      END,
      CASE 
        WHEN v_admin_has_subscription THEN 'active' 
        ELSE 'inactive' 
      END,
      CASE 
        WHEN v_admin_has_subscription THEN now() + interval '1 month' 
        ELSE now() + interval '7 days' 
      END,
      CASE 
        WHEN v_admin_has_subscription THEN 'active' 
        ELSE 'inactive' 
      END,
      now(),
      now()
    FROM user_account_state uas
    WHERE uas.user_id = p_admin_user_id;
  EXCEPTION WHEN unique_violation THEN
    -- Update existing account state
    UPDATE user_account_state SET
      account_status = CASE WHEN v_admin_has_subscription THEN 'subscription_active' ELSE 'trial_active' END,
      has_access = true,
      access_level = CASE WHEN v_admin_has_subscription THEN 'pro' ELSE 'trial' END,
      subscription_status = CASE WHEN v_admin_has_subscription THEN 'active' ELSE 'inactive' END,
      current_period_end = CASE WHEN v_admin_has_subscription THEN now() + interval '1 month' ELSE now() + interval '7 days' END,
      axie_studio_status = CASE WHEN v_admin_has_subscription THEN 'active' ELSE 'inactive' END,
      updated_at = now()
    WHERE user_id = v_new_user_id;
  END;
  
  -- Create user trial record
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
    'initial_access_level', CASE WHEN v_admin_has_subscription THEN 'pro' ELSE 'trial' END,
    'axiestudio_status', CASE WHEN v_admin_has_subscription THEN 'active' ELSE 'inactive' END,
    'retry_count', v_retry_count
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM,
    'detail', 'Error creating team member: ' || SQLERRM,
    'retry_count', v_retry_count
  );
END;
$$;

-- GRANT PERMISSIONS
GRANT EXECUTE ON FUNCTION create_team_member TO authenticated;

SELECT 'Bulletproof team member creation ready! This handles all UUID conflicts.' as status;
