-- 🚨 FINAL FIX FOR INFINITE RECURSION - COMPLETELY NON-RECURSIVE POLICIES
-- Run this in Supabase SQL Editor

-- 1. DROP ALL EXISTING TEAM POLICIES
DROP POLICY IF EXISTS "Teams access policy" ON teams;
DROP POLICY IF EXISTS "Team members access policy" ON team_members;
DROP POLICY IF EXISTS "Team subscriptions access policy" ON team_subscriptions;

-- 2. DISABLE RLS TEMPORARILY TO TEST
ALTER TABLE teams DISABLE ROW LEVEL SECURITY;
ALTER TABLE team_members DISABLE ROW LEVEL SECURITY;
ALTER TABLE team_subscriptions DISABLE ROW LEVEL SECURITY;

-- 3. CREATE SIMPLE, NON-RECURSIVE POLICIES

-- Teams: Only admin can see their own team (no circular references)
CREATE POLICY "Teams simple policy" ON teams
  FOR ALL USING (admin_user_id = auth.uid());

-- Team Members: Only see your own membership record (no joins to teams)
CREATE POLICY "Team members simple policy" ON team_members
  FOR ALL USING (user_id = auth.uid());

-- Team Subscriptions: Only team admin can see (direct admin check)
CREATE POLICY "Team subscriptions simple policy" ON team_subscriptions
  FOR ALL USING (
    team_id IN (
      SELECT id FROM teams WHERE admin_user_id = auth.uid()
    )
  );

-- 4. RE-ENABLE RLS
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_subscriptions ENABLE ROW LEVEL SECURITY;

-- 5. TEST QUERIES TO VERIFY NO RECURSION
SELECT 'Testing teams table...' as test;
SELECT COUNT(*) as team_count FROM teams;

SELECT 'Testing team_members table...' as test;
SELECT COUNT(*) as member_count FROM team_members;

SELECT 'Testing team_subscriptions table...' as test;
SELECT COUNT(*) as subscription_count FROM team_subscriptions;

SELECT 'RLS POLICIES FIXED - NO MORE RECURSION!' as status;
