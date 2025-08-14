-- 🔍 CHECK TIMER ACCURACY FOR CURRENT USER
-- Run this in Supabase SQL Editor to verify timer accuracy

-- 1. Check the specific user's trial data
SELECT 
    u.id,
    u.email,
    u.created_at as user_created_at,
    ut.trial_start_date,
    ut.trial_end_date,
    ut.trial_status,
    
    -- Calculate what the trial_end_date SHOULD be (7 days from user creation)
    u.created_at + interval '7 days' as correct_trial_end_date,
    
    -- Check if trial dates are correct
    CASE 
        WHEN ut.trial_start_date = u.created_at THEN '✅ CORRECT'
        ELSE '❌ WRONG - trial_start_date should equal user.created_at'
    END as trial_start_status,
    
    CASE 
        WHEN ut.trial_end_date = u.created_at + interval '7 days' THEN '✅ CORRECT'
        ELSE '❌ WRONG - trial_end_date should be 7 days from user.created_at'
    END as trial_end_status,
    
    -- Calculate remaining time based on CORRECT dates
    CASE 
        WHEN (u.created_at + interval '7 days') > now() THEN 
            EXTRACT(epoch FROM ((u.created_at + interval '7 days') - now()))::integer
        ELSE 0
    END as correct_seconds_remaining,
    
    -- Calculate remaining time based on DATABASE dates
    CASE 
        WHEN ut.trial_end_date > now() THEN 
            EXTRACT(epoch FROM (ut.trial_end_date - now()))::integer
        ELSE 0
    END as database_seconds_remaining,
    
    -- Show the difference
    CASE 
        WHEN ut.trial_end_date > now() AND (u.created_at + interval '7 days') > now() THEN 
            EXTRACT(epoch FROM (ut.trial_end_date - (u.created_at + interval '7 days')))::integer
        ELSE 0
    END as seconds_difference

FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
WHERE u.email = 'digitalspace5554@gmail.com'  -- Stefan's current user
ORDER BY u.created_at DESC;

-- 2. Check all recent users for pattern analysis
SELECT 
    u.id,
    u.email,
    u.created_at as user_created,
    ut.trial_start_date,
    ut.trial_end_date,
    
    -- Time calculations
    CASE 
        WHEN ut.trial_end_date > now() THEN 
            EXTRACT(days FROM (ut.trial_end_date - now()))::integer || 'd ' ||
            EXTRACT(hours FROM (ut.trial_end_date - now()))::integer || 'h ' ||
            EXTRACT(minutes FROM (ut.trial_end_date - now()))::integer || 'm'
        ELSE 'EXPIRED'
    END as time_remaining_display,
    
    -- Verify correctness
    CASE 
        WHEN ut.trial_start_date = u.created_at AND 
             ut.trial_end_date = u.created_at + interval '7 days' THEN '✅ CORRECT'
        ELSE '❌ INCORRECT DATES'
    END as accuracy_status

FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
ORDER BY u.created_at DESC
LIMIT 10;

-- 3. Fix any incorrect trial dates for the current user
-- (Run this if the above queries show incorrect dates)

-- First, let's see what needs to be fixed:
SELECT 
    'BEFORE FIX:' as status,
    u.id,
    u.email,
    u.created_at,
    ut.trial_start_date,
    ut.trial_end_date,
    ut.trial_start_date = u.created_at as start_correct,
    ut.trial_end_date = u.created_at + interval '7 days' as end_correct
FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
WHERE u.email = 'digitalspace5554@gmail.com';

-- Fix the trial dates if they're wrong:
UPDATE user_trials 
SET 
    trial_start_date = (SELECT created_at FROM auth.users WHERE email = 'digitalspace5554@gmail.com'),
    trial_end_date = (SELECT created_at + interval '7 days' FROM auth.users WHERE email = 'digitalspace5554@gmail.com'),
    updated_at = now()
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'digitalspace5554@gmail.com');

-- Verify the fix:
SELECT 
    'AFTER FIX:' as status,
    u.id,
    u.email,
    u.created_at,
    ut.trial_start_date,
    ut.trial_end_date,
    ut.trial_start_date = u.created_at as start_correct,
    ut.trial_end_date = u.created_at + interval '7 days' as end_correct,
    
    -- Show exact remaining time
    CASE 
        WHEN ut.trial_end_date > now() THEN 
            EXTRACT(days FROM (ut.trial_end_date - now()))::integer || ' days, ' ||
            EXTRACT(hours FROM (ut.trial_end_date - now()))::integer || ' hours, ' ||
            EXTRACT(minutes FROM (ut.trial_end_date - now()))::integer || ' minutes, ' ||
            EXTRACT(seconds FROM (ut.trial_end_date - now()))::integer || ' seconds'
        ELSE 'EXPIRED'
    END as exact_time_remaining

FROM auth.users u
LEFT JOIN user_trials ut ON u.id = ut.user_id
WHERE u.email = 'digitalspace5554@gmail.com';
