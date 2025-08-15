-- 🔧 FIX ENUM TYPES - FINAL VERSION
-- First check what enum types actually exist, then create the function

-- 1. Check what enum types exist in the database
SELECT 
  'EXISTING ENUM TYPES' as check_type,
  typname as enum_name,
  array_agg(enumlabel ORDER BY enumsortorder) as enum_values
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
GROUP BY typname
ORDER BY typname;

-- 2. Check the actual column types in user_account_state table
SELECT 
  'USER_ACCOUNT_STATE COLUMNS' as check_type,
  column_name,
  data_type,
  udt_name
FROM information_schema.columns 
WHERE table_name = 'user_account_state' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Create the function without enum type declarations (let PostgreSQL infer types)
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
    now(),
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
    COALESCE(p_display_name, ''),
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    updated_at = now();
  
  -- Create user account state (using string literals, let PostgreSQL handle the casting)
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
    CASE WHEN v_admin_has_subscription THEN 'pro' ELSE 'trial' END,
    CASE WHEN v_admin_has_subscription THEN 'active' ELSE 'inactive' END,
    CASE WHEN v_admin_has_subscription THEN now() + interval '1 month' ELSE now() + interval '7 days' END,
    CASE WHEN v_admin_has_subscription THEN 'active' ELSE 'inactive' END,
    now(),
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    account_status = CASE WHEN v_admin_has_subscription THEN 'subscription_active'::user_account_status ELSE 'trial_active'::user_account_status END,
    has_access = true,
    access_level = CASE WHEN v_admin_has_subscription THEN 'pro' ELSE 'trial' END,
    subscription_status = CASE WHEN v_admin_has_subscription THEN 'active' ELSE 'inactive' END,
    current_period_end = CASE WHEN v_admin_has_subscription THEN now() + interval '1 month' ELSE now() + interval '7 days' END,
    axie_studio_status = CASE WHEN v_admin_has_subscription THEN 'active' ELSE 'inactive' END,
    updated_at = now();
  
  -- Create user trial record
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
    trial_status = CASE WHEN v_admin_has_subscription THEN 'converted_to_paid' ELSE 'active' END,
    trial_end_date = now() + interval '7 days',
    updated_at = now();
  
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

-- 4. GRANT PERMISSIONS
GRANT EXECUTE ON FUNCTION create_team_member TO authenticated;

-- 5. Test the function exists
SELECT 
  'FUNCTION CHECK' as test_type,
  routine_name,
  routine_type
FROM information_schema.routines 
WHERE routine_name = 'create_team_member';

SELECT 'Team member creation function ready! No enum type errors.' as status;
