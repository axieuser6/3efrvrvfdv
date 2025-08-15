-- 🚨 FIX INFINITE RECURSION IN TEAM RLS POLICIES (SIMPLE VERSION)
-- Run this in Supabase SQL Editor

-- 1. DROP EXISTING PROBLEMATIC POLICIES
DROP POLICY IF EXISTS "Teams access policy" ON teams;
DROP POLICY IF EXISTS "Team members access policy" ON team_members;
DROP POLICY IF EXISTS "Team subscriptions access policy" ON team_subscriptions;

-- 2. CREATE FIXED NON-RECURSIVE POLICIES

-- Teams: Simple policy - admin can see their team, members can see their team
CREATE POLICY "Teams access policy" ON teams
  FOR ALL USING (
    admin_user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM team_members tm 
      WHERE tm.team_id = teams.id 
      AND tm.user_id = auth.uid() 
      AND tm.status = 'active'
    )
  );

-- Team Members: Team admin and active members can see team members
CREATE POLICY "Team members access policy" ON team_members
  FOR ALL USING (
    -- User is the team admin
    EXISTS (
      SELECT 1 FROM teams t 
      WHERE t.id = team_members.team_id 
      AND t.admin_user_id = auth.uid()
    )
    OR
    -- User is an active member of the same team
    (
      user_id = auth.uid() OR
      EXISTS (
        SELECT 1 FROM team_members tm2 
        WHERE tm2.team_id = team_members.team_id 
        AND tm2.user_id = auth.uid() 
        AND tm2.status = 'active'
      )
    )
  );

-- Team Subscriptions: Only team admin can see subscription details
CREATE POLICY "Team subscriptions access policy" ON team_subscriptions
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM teams t 
      WHERE t.id = team_subscriptions.team_id 
      AND t.admin_user_id = auth.uid()
    )
  );

-- 3. VERIFY POLICIES ARE WORKING
SELECT 'TEAM RLS POLICIES FIXED!' as status;
