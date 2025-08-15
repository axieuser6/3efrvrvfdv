-- 🔧 FIX TEAM MEMBER CREATION
-- Run this in Supabase SQL Editor to create a robust user creation function

-- 1. CREATE TEAM MEMBER CREATION FUNCTION
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
  v_team_subscription_status text;
BEGIN
  -- Verify the admin is actually a team admin AND has active subscription
  SELECT t.id, t.current_members, t.max_members
  INTO v_team_id, v_team_current_members, v_team_max_members
  FROM teams t
  WHERE t.admin_user_id = p_admin_user_id AND t.status = 'active';

  IF v_team_id IS NULL THEN
    RAISE EXCEPTION 'User is not a team admin or team is not active';
  END IF;

  -- 🔒 CRITICAL: Check if team admin has active Team Pro subscription
  SELECT ts.status INTO v_team_subscription_status
  FROM team_subscriptions ts
  WHERE ts.team_id = v_team_id
  AND ts.status = 'active'
  AND ts.price_id IN ('price_1RwOhVBacFXEnBmNIeWQ1wQe', 'price_1RwP9cBacFXEnBmNsM3xVLL2');

  IF v_team_subscription_status IS NULL THEN
    RAISE EXCEPTION 'Team admin does not have an active Team Pro subscription. Cannot create team members without active subscription.';
  END IF;

  -- Also verify admin has active user account state
  IF NOT EXISTS (
    SELECT 1 FROM user_account_state uas
    WHERE uas.user_id = p_admin_user_id
    AND uas.account_status = 'subscription_active'
    AND uas.has_access = true
  ) THEN
    RAISE EXCEPTION 'Team admin account is not active. Cannot create team members.';
  END IF;

  v_admin_has_subscription := true;
  
  -- Check team member limit
  IF v_team_current_members >= v_team_max_members THEN
    RAISE EXCEPTION 'Team is full. Maximum % members allowed.', v_team_max_members;
  END IF;
  
  -- Check if email already exists
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = p_email) THEN
    RAISE EXCEPTION 'User with email % already exists', p_email;
  END IF;
  
  -- Generate new user ID
  v_new_user_id := gen_random_uuid();
  
  -- Create user in auth.users table
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
  
  -- Create user profile
  INSERT INTO user_profiles (
    id,
    email,
    full_name,
    created_at,
    updated_at
  ) VALUES (
    v_new_user_id,
    p_email,
    p_display_name,
    now(),
    now()
  );
  
  -- Create user account state (team member gets Pro access)
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
    'subscription_active',
    true,
    'pro', -- Team members get Pro access
    'active',
    now() + interval '1 year', -- Long period for team members
    'active',
    now(),
    now()
  );
  
  -- Create user trial record (marked as converted)
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
    'converted_to_paid', -- Team members are considered converted
    now(),
    now()
  );
  
  -- Add to team members
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
    p_display_name,
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
    'display_name', p_display_name
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;

-- 2. GRANT PERMISSIONS
GRANT EXECUTE ON FUNCTION create_team_member TO authenticated;

-- 3. TEST THE FUNCTION (optional - remove if you don't want to test)
-- SELECT create_team_member(
--   'test@example.com',
--   'testpassword123',
--   'Test User',
--   (SELECT id FROM auth.users WHERE email = 'stefanjohnmiranda3@gmail.com')
-- );

SELECT 'Team member creation function ready!' as status;
