-- 🔍 VERIFY TEAM MANAGEMENT SETUP
-- Run this to check if everything is working

-- 1. Check if functions exist
SELECT 
  'FUNCTIONS CHECK' as test_type,
  routine_name,
  routine_type,
  security_type
FROM information_schema.routines 
WHERE routine_name IN ('update_team_member_password', 'delete_team_member_account')
ORDER BY routine_name;

-- 2. Check if support tables exist
SELECT 
  'TABLES CHECK' as test_type,
  table_name,
  table_type
FROM information_schema.tables 
WHERE table_name IN ('password_update_requests', 'account_deletion_requests', 'teams', 'team_members', 'team_subscriptions')
AND table_schema = 'public'
ORDER BY table_name;

-- 3. Check team admin user setup
SELECT 
  'TEAM ADMIN CHECK' as test_type,
  u.email,
  uas.account_status,
  uas.access_level,
  ss.status as subscription_status,
  ss.price_id,
  t.name as team_name,
  t.current_members,
  t.max_members,
  t.status as team_status
FROM auth.users u
LEFT JOIN user_account_state uas ON u.id = uas.user_id
LEFT JOIN stripe_customers sc ON u.id = sc.user_id
LEFT JOIN stripe_subscriptions ss ON sc.customer_id = ss.customer_id
LEFT JOIN teams t ON u.id = t.admin_user_id
WHERE u.email = 'stefanjohnmiranda3@gmail.com';

-- 4. Check team members (if any)
SELECT 
  'TEAM MEMBERS CHECK' as test_type,
  tm.id,
  tm.user_id,
  tm.role,
  tm.status,
  tm.display_name,
  up.email,
  up.full_name
FROM team_members tm
LEFT JOIN user_profiles up ON tm.user_id = up.id
WHERE tm.team_id IN (
  SELECT id FROM teams WHERE admin_user_id IN (
    SELECT id FROM auth.users WHERE email = 'stefanjohnmiranda3@gmail.com'
  )
)
ORDER BY tm.created_at;

-- 5. Check RLS policies
SELECT 
  'RLS POLICIES CHECK' as test_type,
  schemaname,
  tablename,
  policyname,
  permissive,
  cmd
FROM pg_policies 
WHERE tablename IN ('teams', 'team_members', 'team_subscriptions', 'password_update_requests', 'account_deletion_requests')
ORDER BY tablename, policyname;

-- 6. Test team admin permissions (this should work if logged in as team admin)
SELECT 
  'PERMISSIONS TEST' as test_type,
  'Can access teams table' as test_description,
  COUNT(*) as team_count
FROM teams;

SELECT 
  'PERMISSIONS TEST' as test_type,
  'Can access team_members table' as test_description,
  COUNT(*) as member_count
FROM team_members;

-- 7. Final status
SELECT 
  'SETUP STATUS' as test_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'update_team_member_password') 
    AND EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'delete_team_member_account')
    AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'password_update_requests')
    AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'account_deletion_requests')
    THEN '✅ ALL FUNCTIONS AND TABLES READY'
    ELSE '❌ MISSING COMPONENTS'
  END as status;
