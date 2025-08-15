-- 🔧 SIMPLE TEAM MEMBER CREATION - NO ENUM ISSUES
-- Let's use a much simpler approach that copies from existing working data

-- 1. First, let's see what values are actually used in your database
SELECT DISTINCT 
  'EXISTING VALUES CHECK' as check_type,
  account_status,
  access_level
FROM user_account_state 
WHERE user_id IN (
  SELECT id FROM auth.users WHERE email = 'stefanjohnmiranda3@gmail.com'
)
LIMIT 5;

-- 2. Create a simple function that copies the pattern from existing users
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
  v_admin_account_status text;
  v_admin_access_level text;
BEGIN
  -- Verify the admin is actually a team admin
  SELECT t.id, t.current_members, t.max_members 
  INTO v_team_id, v_team_current_members, v_team_max_members
  FROM teams t
  WHERE t.admin_user_id = p_admin_user_id AND t.status = 'active';
  
  IF v_team_id IS NULL THEN
    RAISE EXCEPTION 'User is not a team admin or team is not active';
  END IF;
  
  -- Get admin's current account status and access level to copy the pattern
  SELECT uas.account_status::text, uas.access_level::text
  INTO v_admin_account_status, v_admin_access_level
  FROM user_account_state uas
  WHERE uas.user_id = p_admin_user_id;
  
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
  
  -- Generate new user ID and ensure it's unique
  v_new_user_id := gen_random_uuid();

  -- Ensure the UUID doesn't already exist anywhere
  WHILE EXISTS (SELECT 1 FROM auth.users WHERE id = v_new_user_id) OR
        EXISTS (SELECT 1 FROM user_profiles WHERE id = v_new_user_id) LOOP
    v_new_user_id := gen_random_uuid();
  END LOOP;

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
    now(),
    now(),
    now(),
    '',
    '',
    '',
    ''
  );
  
  -- Create user profile with conflict handling
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
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    updated_at = now();
  
  -- Create user account state by copying from admin but adjusting for team member
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
  WHERE uas.user_id = p_admin_user_id
  ON CONFLICT (user_id) DO UPDATE SET
    account_status = EXCLUDED.account_status,
    has_access = EXCLUDED.has_access,
    access_level = EXCLUDED.access_level,
    subscription_status = EXCLUDED.subscription_status,
    current_period_end = EXCLUDED.current_period_end,
    axie_studio_status = EXCLUDED.axie_studio_status,
    updated_at = now();
  
  -- Create user trial record by copying pattern from admin
  INSERT INTO user_trials (
    user_id,
    trial_start_date,
    trial_end_date,
    trial_status,
    created_at,
    updated_at
  )
  SELECT 
    v_new_user_id,
    now(),
    now() + interval '7 days',
    CASE 
      WHEN v_admin_has_subscription THEN 'converted_to_paid' 
      ELSE 'active' 
    END,
    now(),
    now()
  FROM user_trials ut
  WHERE ut.user_id = p_admin_user_id
  LIMIT 1
  ON CONFLICT (user_id) DO UPDATE SET
    trial_status = EXCLUDED.trial_status,
    trial_end_date = EXCLUDED.trial_end_date,
    updated_at = now();
  
  -- If admin doesn't have trial record, create a basic one
  IF NOT FOUND THEN
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
    )
    ON CONFLICT (user_id) DO UPDATE SET
      trial_status = EXCLUDED.trial_status,
      trial_end_date = EXCLUDED.trial_end_date,
      updated_at = now();
  END IF;
  
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

-- 3. GRANT PERMISSIONS
GRANT EXECUTE ON FUNCTION create_team_member TO authenticated;

SELECT 'Simple team member creation ready! This copies the pattern from existing admin user.' as status;
