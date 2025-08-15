-- 🔧 SIMPLE TEAM MANAGEMENT FUNCTIONS (CLIENT-SAFE)
-- Run this in Supabase SQL Editor

-- 1. SIMPLE FUNCTION TO UPDATE TEAM MEMBER PASSWORD (using Edge Function approach)
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
    AND tm.role = 'member'
  ) THEN
    RAISE EXCEPTION 'Member not found in your team';
  END IF;
  
  -- Store password update request (to be processed by Edge Function)
  INSERT INTO password_update_requests (
    team_id,
    admin_user_id,
    target_user_id,
    new_password_hash,
    status,
    created_at
  ) VALUES (
    v_team_id,
    p_admin_user_id,
    p_member_user_id,
    crypt(p_new_password, gen_salt('bf')), -- Hash the password
    'pending',
    now()
  );
  
  RETURN json_build_object(
    'success', true,
    'message', 'Password update request created'
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;

-- 2. SIMPLE FUNCTION TO DELETE TEAM MEMBER (mark for deletion)
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
  
  -- Get member email
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
  
  -- Remove from team_members (soft delete approach)
  UPDATE team_members 
  SET 
    status = 'deleted',
    updated_at = now()
  WHERE user_id = p_member_user_id AND team_id = v_team_id;
  
  -- Mark user account for deletion
  UPDATE user_account_state 
  SET 
    account_status = 'account_deleted',
    has_access = false,
    access_level = 'suspended',
    updated_at = now()
  WHERE user_id = p_member_user_id;
  
  -- Mark trial as deleted
  UPDATE user_trials 
  SET 
    trial_status = 'deleted',
    updated_at = now()
  WHERE user_id = p_member_user_id;
  
  -- Update team member count
  UPDATE teams 
  SET 
    current_members = current_members - 1,
    updated_at = now()
  WHERE id = v_team_id;
  
  -- Create deletion request for Edge Function to process
  INSERT INTO account_deletion_requests (
    team_id,
    admin_user_id,
    target_user_id,
    target_email,
    status,
    created_at
  ) VALUES (
    v_team_id,
    p_admin_user_id,
    p_member_user_id,
    v_member_email,
    'pending',
    now()
  );
  
  RETURN json_build_object(
    'success', true,
    'message', 'Member account marked for deletion'
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;

-- 3. CREATE SUPPORTING TABLES
CREATE TABLE IF NOT EXISTS password_update_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid REFERENCES teams(id) ON DELETE CASCADE,
  admin_user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  target_user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  new_password_hash text NOT NULL,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz
);

CREATE TABLE IF NOT EXISTS account_deletion_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid REFERENCES teams(id) ON DELETE CASCADE,
  admin_user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  target_user_id uuid,
  target_email text,
  status text DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
  created_at timestamptz DEFAULT now(),
  processed_at timestamptz
);

-- 4. CREATE RLS POLICIES
ALTER TABLE password_update_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE account_deletion_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Password requests access" ON password_update_requests
  FOR ALL USING (
    admin_user_id = auth.uid() OR
    team_id IN (SELECT id FROM teams WHERE admin_user_id = auth.uid())
  );

CREATE POLICY "Deletion requests access" ON account_deletion_requests
  FOR ALL USING (
    admin_user_id = auth.uid() OR
    team_id IN (SELECT id FROM teams WHERE admin_user_id = auth.uid())
  );

-- 5. GRANT PERMISSIONS
GRANT EXECUTE ON FUNCTION update_team_member_password TO authenticated;
GRANT EXECUTE ON FUNCTION delete_team_member_account TO authenticated;

SELECT 'Simple team management functions created successfully!' as status;
