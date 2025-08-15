-- 🧪 TEST DYNAMIC TEAM ACCESS SYSTEM
-- Run this to test the team member access system

-- 1. Check current team admin subscription status
SELECT 
  'TEAM ADMIN STATUS' as test_type,
  u.email as admin_email,
  t.name as team_name,
  t.current_members,
  t.max_members,
  ts.status as subscription_status,
  ts.price_id,
  uas.account_status as admin_account_status,
  uas.access_level as admin_access_level
FROM auth.users u
JOIN teams t ON u.id = t.admin_user_id
LEFT JOIN team_subscriptions ts ON t.id = ts.team_id
LEFT JOIN user_account_state uas ON u.id = uas.user_id
WHERE u.email = 'stefanjohnmiranda3@gmail.com';

-- 2. Check team members and their access levels
SELECT 
  'TEAM MEMBERS STATUS' as test_type,
  up.email as member_email,
  tm.display_name,
  tm.role,
  tm.status as member_status,
  uas.account_status,
  uas.access_level,
  uas.axie_studio_status,
  uas.subscription_status,
  ut.trial_status
FROM team_members tm
JOIN user_profiles up ON tm.user_id = up.id
LEFT JOIN user_account_state uas ON tm.user_id = uas.user_id
LEFT JOIN user_trials ut ON tm.user_id = ut.user_id
WHERE tm.team_id IN (
  SELECT id FROM teams WHERE admin_user_id IN (
    SELECT id FROM auth.users WHERE email = 'stefanjohnmiranda3@gmail.com'
  )
)
ORDER BY tm.created_at;

-- 3. Test the sync function manually
SELECT sync_team_member_access();

-- 4. Check if sync worked - verify member access after sync
SELECT 
  'POST-SYNC MEMBER STATUS' as test_type,
  up.email as member_email,
  uas.account_status,
  uas.access_level,
  uas.axie_studio_status,
  CASE 
    WHEN uas.access_level = 'pro' AND uas.axie_studio_status = 'active' THEN '✅ PRO ACCESS'
    WHEN uas.access_level = 'trial' AND uas.axie_studio_status = 'inactive' THEN '⚠️ STANDARD ACCESS'
    ELSE '❌ UNKNOWN STATUS'
  END as access_summary
FROM team_members tm
JOIN user_profiles up ON tm.user_id = up.id
JOIN user_account_state uas ON tm.user_id = uas.user_id
WHERE tm.team_id IN (
  SELECT id FROM teams WHERE admin_user_id IN (
    SELECT id FROM auth.users WHERE email = 'stefanjohnmiranda3@gmail.com'
  )
)
AND tm.role = 'member'
ORDER BY tm.created_at;

-- 5. Simulate admin losing subscription (for testing)
-- UNCOMMENT TO TEST SUBSCRIPTION LOSS:
-- UPDATE team_subscriptions 
-- SET status = 'canceled' 
-- WHERE team_id IN (
--   SELECT id FROM teams WHERE admin_user_id IN (
--     SELECT id FROM auth.users WHERE email = 'stefanjohnmiranda3@gmail.com'
--   )
-- );

-- 6. Simulate admin regaining subscription (for testing)
-- UNCOMMENT TO TEST SUBSCRIPTION RESTORATION:
-- UPDATE team_subscriptions 
-- SET status = 'active' 
-- WHERE team_id IN (
--   SELECT id FROM teams WHERE admin_user_id IN (
--     SELECT id FROM auth.users WHERE email = 'stefanjohnmiranda3@gmail.com'
--   )
-- );

SELECT 'Dynamic team access test complete! Check the results above.' as final_status;
