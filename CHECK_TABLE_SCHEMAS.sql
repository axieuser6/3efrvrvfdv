-- 🔍 CHECK TABLE SCHEMAS TO FIX THE COLUMN ISSUES

-- 1. Check user_trials table structure
SELECT 
    'USER_TRIALS COLUMNS:' as table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'user_trials' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Check user_account_state table structure
SELECT 
    'USER_ACCOUNT_STATE COLUMNS:' as table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'user_account_state' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Check if trial_status enum exists
SELECT 
    'TRIAL_STATUS ENUM VALUES:' as enum_name,
    enumlabel as enum_value
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
WHERE t.typname = 'trial_status'
ORDER BY e.enumsortorder;

-- 4. Show sample data from both tables
SELECT 
    'SAMPLE USER_TRIALS DATA:' as table_name,
    *
FROM user_trials
LIMIT 3;

SELECT 
    'SAMPLE USER_ACCOUNT_STATE DATA:' as table_name,
    *
FROM user_account_state
LIMIT 3;
