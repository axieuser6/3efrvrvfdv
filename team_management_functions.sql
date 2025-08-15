-- 🔧 TEAM MANAGEMENT FUNCTIONS
-- Run this in Supabase SQL Editor to create team management functions

-- 1. FUNCTION TO UPDATE TEAM MEMBER PASSWORD
CREATE OR REPLACE FUNCTION update_team_member_password(
  p_member_user_id uuid,
  p_new_password text,
  p_admin_user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_team_id uuid;
  v_is_admin boolean := false;
BEGIN
  -- Verify the admin is actually a team admin
  SELECT t.id INTO v_team_id
  FROM teams t
  WHERE t.admin_user_id = p_admin_user_id;
  
  IF v_team_id IS NULL THEN
    RAISE EXCEPTION 'User is not a team admin';
  END IF;
  
  -- Verify the member belongs to the admin's team
  IF NOT EXISTS (
    SELECT 1 FROM team_members tm 
    WHERE tm.user_id = p_member_user_id 
    AND tm.team_id = v_team_id 
    AND tm.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Member not found in your team';
  END IF;
  
  -- Update the password using Supabase Auth Admin API
  -- Note: This requires the function to have admin privileges
  PERFORM auth.update_user(
    p_member_user_id,
    json_build_object('password', p_new_password)
  );
  
  -- Log the password change
  INSERT INTO team_audit_log (
    team_id,
    admin_user_id,
    action,
    target_user_id,
    details,
    created_at
  ) VALUES (
    v_team_id,
    p_admin_user_id,
    'password_updated',
    p_member_user_id,
    'Password updated by team admin',
    now()
  );
  
  RETURN json_build_object(
    'success', true,
    'message', 'Password updated successfully'
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;

-- 2. FUNCTION TO DELETE TEAM MEMBER ACCOUNT COMPLETELY
CREATE OR REPLACE FUNCTION delete_team_member_account(
  p_member_user_id uuid,
  p_admin_user_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_team_id uuid;
  v_member_email text;
BEGIN
  -- Verify the admin is actually a team admin
  SELECT t.id INTO v_team_id
  FROM teams t
  WHERE t.admin_user_id = p_admin_user_id;
  
  IF v_team_id IS NULL THEN
    RAISE EXCEPTION 'User is not a team admin';
  END IF;
  
  -- Get member email for logging
  SELECT up.email INTO v_member_email
  FROM user_profiles up
  WHERE up.id = p_member_user_id;
  
  -- Verify the member belongs to the admin's team and is not an admin
  IF NOT EXISTS (
    SELECT 1 FROM team_members tm 
    WHERE tm.user_id = p_member_user_id 
    AND tm.team_id = v_team_id 
    AND tm.role = 'member'
    AND tm.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Member not found in your team or is an admin';
  END IF;
  
  -- Log the deletion before removing data
  INSERT INTO team_audit_log (
    team_id,
    admin_user_id,
    action,
    target_user_id,
    details,
    created_at
  ) VALUES (
    v_team_id,
    p_admin_user_id,
    'member_deleted',
    p_member_user_id,
    'Member account completely deleted: ' || COALESCE(v_member_email, 'unknown'),
    now()
  );
  
  -- Delete all user data (cascading deletes will handle related records)
  -- 1. Remove from team_members
  DELETE FROM team_members WHERE user_id = p_member_user_id;
  
  -- 2. Delete user profile
  DELETE FROM user_profiles WHERE id = p_member_user_id;
  
  -- 3. Delete user account state
  DELETE FROM user_account_state WHERE user_id = p_member_user_id;
  
  -- 4. Delete user trials
  DELETE FROM user_trials WHERE user_id = p_member_user_id;
  
  -- 5. Delete stripe customer data
  DELETE FROM stripe_customers WHERE user_id = p_member_user_id;
  
  -- 6. Delete from auth.users (this should be done last)
  DELETE FROM auth.users WHERE id = p_member_user_id;
  
  -- Update team member count
  UPDATE teams 
  SET 
    current_members = current_members - 1,
    updated_at = now()
  WHERE id = v_team_id;
  
  RETURN json_build_object(
    'success', true,
    'message', 'Member account deleted successfully'
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;

-- 3. CREATE TEAM AUDIT LOG TABLE (if not exists)
CREATE TABLE IF NOT EXISTS team_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid REFERENCES teams(id) ON DELETE CASCADE,
  admin_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  target_user_id uuid,
  details text,
  created_at timestamptz DEFAULT now()
);

-- 4. CREATE RLS POLICY FOR AUDIT LOG
ALTER TABLE team_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Team audit log access" ON team_audit_log
  FOR ALL USING (
    team_id IN (SELECT id FROM teams WHERE admin_user_id = auth.uid())
  );

-- 5. GRANT NECESSARY PERMISSIONS
GRANT EXECUTE ON FUNCTION update_team_member_password TO authenticated;
GRANT EXECUTE ON FUNCTION delete_team_member_account TO authenticated;

-- 6. VERIFICATION QUERIES
SELECT 'Team management functions created successfully!' as status;

-- Test that functions exist
SELECT 
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines 
WHERE routine_name IN ('update_team_member_password', 'delete_team_member_account')
ORDER BY routine_name;
