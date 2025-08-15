-- 🔄 DYNAMIC TEAM ACCESS SYSTEM
-- Team members get Pro access ONLY while team admin has active Team Pro subscription
-- When admin loses subscription, members automatically revert to Standard tier

-- 1. CREATE FUNCTION TO SYNC TEAM MEMBER ACCESS BASED ON ADMIN SUBSCRIPTION
CREATE OR REPLACE FUNCTION sync_team_member_access()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  team_record RECORD;
  member_record RECORD;
  admin_has_active_subscription boolean;
BEGIN
  -- Loop through all teams
  FOR team_record IN 
    SELECT t.id as team_id, t.admin_user_id, t.status as team_status
    FROM teams t
    WHERE t.status = 'active'
  LOOP
    -- Check if team admin has active Team Pro subscription
    SELECT EXISTS (
      SELECT 1 FROM team_subscriptions ts
      WHERE ts.team_id = team_record.team_id
      AND ts.status = 'active'
      AND ts.price_id IN ('price_1RwOhVBacFXEnBmNIeWQ1wQe', 'price_1RwP9cBacFXEnBmNsM3xVLL2')
    ) INTO admin_has_active_subscription;
    
    -- Update all team members based on admin subscription status
    FOR member_record IN
      SELECT tm.user_id, tm.role
      FROM team_members tm
      WHERE tm.team_id = team_record.team_id
      AND tm.status = 'active'
      AND tm.role = 'member' -- Don't affect admin
    LOOP
      IF admin_has_active_subscription THEN
        -- 🎯 ADMIN HAS SUBSCRIPTION: Grant Pro access to members
        UPDATE user_account_state
        SET
          account_status = 'subscription_active'::user_account_status,
          has_access = true,
          access_level = 'pro'::user_access_level,
          subscription_status = 'active',
          axie_studio_status = 'active', -- AxieStudio active
          current_period_end = now() + interval '1 month',
          updated_at = now()
        WHERE user_id = member_record.user_id;
        
        -- Update trial status to converted
        UPDATE user_trials 
        SET 
          trial_status = 'converted_to_paid',
          updated_at = now()
        WHERE user_id = member_record.user_id;
        
      ELSE
        -- 🚫 ADMIN LOST SUBSCRIPTION: Revert members to Standard tier
        UPDATE user_account_state
        SET
          account_status = 'trial_active'::user_account_status, -- Standard tier
          has_access = true, -- Still have access but limited
          access_level = 'trial'::user_access_level, -- Standard tier level
          subscription_status = 'inactive',
          axie_studio_status = 'inactive', -- AxieStudio inactive
          current_period_end = now() + interval '7 days', -- Standard trial period
          updated_at = now()
        WHERE user_id = member_record.user_id;
        
        -- Update trial status back to active
        UPDATE user_trials 
        SET 
          trial_status = 'active',
          trial_end_date = now() + interval '7 days',
          updated_at = now()
        WHERE user_id = member_record.user_id;
        
      END IF;
    END LOOP;
  END LOOP;
END;
$$;

-- 2. CREATE TRIGGER TO AUTO-SYNC WHEN TEAM SUBSCRIPTIONS CHANGE
CREATE OR REPLACE FUNCTION trigger_sync_team_access()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Sync team member access whenever team subscription changes
  PERFORM sync_team_member_access();
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS team_subscription_change_trigger ON team_subscriptions;

-- Create trigger on team_subscriptions table
CREATE TRIGGER team_subscription_change_trigger
  AFTER INSERT OR UPDATE OR DELETE ON team_subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION trigger_sync_team_access();

-- 3. UPDATE TEAM MEMBER CREATION FUNCTION TO CREATE STANDARD USERS
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
  
  -- Check if admin has active subscription (determines initial access level)
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
  
  -- Create user profile (handle potential duplicates)
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
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    updated_at = now();
  
  -- Create user account state (access level depends on admin subscription)
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
    CASE WHEN v_admin_has_subscription THEN 'subscription_active' ELSE 'trial_active' END,
    true,
    CASE WHEN v_admin_has_subscription THEN 'pro' ELSE 'trial' END,
    CASE WHEN v_admin_has_subscription THEN 'active' ELSE 'inactive' END,
    CASE WHEN v_admin_has_subscription THEN now() + interval '1 month' ELSE now() + interval '7 days' END,
    CASE WHEN v_admin_has_subscription THEN 'active' ELSE 'inactive' END, -- AxieStudio status
    now(),
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    account_status = EXCLUDED.account_status,
    has_access = EXCLUDED.has_access,
    access_level = EXCLUDED.access_level,
    subscription_status = EXCLUDED.subscription_status,
    current_period_end = EXCLUDED.current_period_end,
    axie_studio_status = EXCLUDED.axie_studio_status,
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
    trial_status = EXCLUDED.trial_status,
    trial_end_date = EXCLUDED.trial_end_date,
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
    'display_name', p_display_name,
    'initial_access_level', CASE WHEN v_admin_has_subscription THEN 'pro' ELSE 'standard' END,
    'axiestudio_status', CASE WHEN v_admin_has_subscription THEN 'active' ELSE 'inactive' END
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;

-- 4. GRANT PERMISSIONS
GRANT EXECUTE ON FUNCTION sync_team_member_access TO authenticated;
GRANT EXECUTE ON FUNCTION create_team_member TO authenticated;

-- 5. INITIAL SYNC (run once to set current state)
SELECT sync_team_member_access();

SELECT 'Dynamic team access system ready! Team members will automatically get Pro/Standard based on admin subscription status.' as status;
