-- Add immediate user deletion functions
-- This migration adds functions to handle immediate account deletion

-- Drop existing functions if they exist to avoid conflicts
DROP FUNCTION IF EXISTS delete_user_immediately(UUID);
DROP FUNCTION IF EXISTS cleanup_deleted_user_data(UUID);

-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can delete their own account immediately" ON user_account_state;

-- Function to delete user immediately (removes access and marks for deletion)
CREATE OR REPLACE FUNCTION delete_user_immediately(target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Log the deletion attempt
  RAISE NOTICE 'Starting immediate deletion for user: %', target_user_id;
  
  -- 1. Remove user access immediately by updating account state
  UPDATE user_account_state
  SET
    account_status = 'deleted',
    has_access = false,
    access_level = 'suspended',
    trial_days_remaining = 0,
    updated_at = NOW()
  WHERE user_id = target_user_id;
  
  -- 2. Mark trial as deleted
  UPDATE user_trials
  SET
    trial_status = 'deleted',
    deletion_scheduled_at = NOW(),
    updated_at = NOW()
  WHERE user_id = target_user_id;
  
  -- 3. Update any stripe subscriptions to cancelled status
  UPDATE stripe_subscriptions 
  SET 
    status = 'canceled',
    cancel_at_period_end = true,
    canceled_at = EXTRACT(EPOCH FROM NOW())::bigint
  WHERE customer_id IN (
    SELECT customer_id 
    FROM stripe_customers 
    WHERE user_id = target_user_id
  );
  
  RAISE NOTICE 'User % access removed immediately', target_user_id;
  
  RETURN TRUE;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error in delete_user_immediately for user %: %', target_user_id, SQLERRM;
    RETURN FALSE;
END;
$$;

-- Function to clean up user data (called after auth deletion)
CREATE OR REPLACE FUNCTION cleanup_deleted_user_data(target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Log the cleanup attempt
  RAISE NOTICE 'Starting data cleanup for user: %', target_user_id;
  
  -- Delete user data in correct order to respect foreign key constraints

  -- 1. Delete stripe subscriptions (by customer_id)
  DELETE FROM stripe_subscriptions
  WHERE customer_id IN (
    SELECT customer_id
    FROM stripe_customers
    WHERE user_id = target_user_id
  );

  -- 2. Delete axie studio accounts
  DELETE FROM axie_studio_accounts
  WHERE user_id = target_user_id;

  -- 3. Delete axie studio credentials
  DELETE FROM axie_studio_credentials
  WHERE user_id = target_user_id;

  -- 4. Delete user account state
  DELETE FROM user_account_state
  WHERE user_id = target_user_id;

  -- 5. Delete stripe customers
  DELETE FROM stripe_customers
  WHERE user_id = target_user_id;

  -- 6. Delete user trials
  DELETE FROM user_trials
  WHERE user_id = target_user_id;

  -- 7. Delete user profiles (CASCADE will handle auth.users)
  DELETE FROM user_profiles
  WHERE id = target_user_id;
  
  RAISE NOTICE 'Data cleanup completed for user: %', target_user_id;
  
  RETURN TRUE;
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error in cleanup_deleted_user_data for user %: %', target_user_id, SQLERRM;
    RETURN FALSE;
END;
$$;

-- Grant execute permissions to authenticated users (they can only delete their own account)
GRANT EXECUTE ON FUNCTION delete_user_immediately(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_deleted_user_data(UUID) TO authenticated;

-- Add RLS policies to ensure users can only delete their own accounts
CREATE POLICY "Users can delete their own account immediately" ON user_account_state
  FOR UPDATE USING (auth.uid() = user_id);

-- Add comment for documentation
COMMENT ON FUNCTION delete_user_immediately(UUID) IS 'Immediately removes user access and marks account for deletion. Used for instant account deletion regardless of subscription status.';
COMMENT ON FUNCTION cleanup_deleted_user_data(UUID) IS 'Cleans up user data after auth user deletion. Should be called after Supabase auth user is deleted.';
