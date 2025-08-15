-- 🔍 DEBUG TEAM CREATION ISSUE
-- Run this to see what's happening with your team data

-- 1. Check if you have any teams in the database
SELECT 
  'TEAMS CHECK' as check_type,
  t.id,
  t.name,
  t.admin_user_id,
  t.current_members,
  t.max_members,
  t.status,
  t.created_at,
  u.email as admin_email
FROM teams t
LEFT JOIN auth.users u ON t.admin_user_id = u.id
WHERE u.email = 'stefanjohnmiranda3@gmail.com'
ORDER BY t.created_at DESC;

-- 2. Check team members for your teams
SELECT 
  'TEAM MEMBERS CHECK' as check_type,
  tm.id,
  tm.team_id,
  tm.user_id,
  tm.role,
  tm.status,
  tm.display_name,
  up.email as member_email,
  tm.created_at
FROM team_members tm
LEFT JOIN user_profiles up ON tm.user_id = up.id
WHERE tm.team_id IN (
  SELECT t.id FROM teams t
  JOIN auth.users u ON t.admin_user_id = u.id
  WHERE u.email = 'stefanjohnmiranda3@gmail.com'
)
ORDER BY tm.created_at DESC;

-- 3. Check team subscriptions
SELECT 
  'TEAM SUBSCRIPTIONS CHECK' as check_type,
  ts.id,
  ts.team_id,
  ts.stripe_subscription_id,
  ts.stripe_customer_id,
  ts.status,
  ts.price_id,
  ts.created_at
FROM team_subscriptions ts
WHERE ts.team_id IN (
  SELECT t.id FROM teams t
  JOIN auth.users u ON t.admin_user_id = u.id
  WHERE u.email = 'stefanjohnmiranda3@gmail.com'
)
ORDER BY ts.created_at DESC;

-- 4. Check if there are any orphaned teams (teams without proper admin)
SELECT 
  'ORPHANED TEAMS CHECK' as check_type,
  t.id,
  t.name,
  t.admin_user_id,
  t.status,
  'No admin user found' as issue
FROM teams t
WHERE NOT EXISTS (
  SELECT 1 FROM auth.users u WHERE u.id = t.admin_user_id
);

-- 5. Check RLS policies on teams table
SELECT 
  'TEAMS RLS POLICIES' as check_type,
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'teams'
ORDER BY policyname;

-- 6. Test if you can access teams table directly
SELECT 
  'DIRECT TEAMS ACCESS TEST' as check_type,
  COUNT(*) as total_teams,
  COUNT(CASE WHEN admin_user_id = (SELECT id FROM auth.users WHERE email = 'stefanjohnmiranda3@gmail.com') THEN 1 END) as your_teams
FROM teams;

-- 7. Check if the bulletproof function was created successfully
SELECT 
  'FUNCTION CHECK' as check_type,
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines 
WHERE routine_name = 'create_team_member'
ORDER BY routine_name;

-- 8. Clean up any duplicate or broken teams (OPTIONAL - uncomment if needed)
-- DELETE FROM teams WHERE admin_user_id = (SELECT id FROM auth.users WHERE email = 'stefanjohnmiranda3@gmail.com') AND status != 'active';

SELECT 'Debug complete! Check the results above to see what''s happening with your team data.' as final_status;
