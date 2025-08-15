/*
  # Fix stripe_user_subscriptions view to include user_id

  1. View Updates
    - Drop and recreate `stripe_user_subscriptions` view
    - Add missing `user_id` column from stripe_customers table
    - Maintain all existing columns for backward compatibility

  2. Security
    - Preserve existing RLS policies
    - Ensure proper user data isolation
*/

-- Drop the existing view
DROP VIEW IF EXISTS stripe_user_subscriptions;

-- Recreate the view with user_id included
CREATE VIEW stripe_user_subscriptions 
WITH (security_invoker = true) AS
SELECT 
  sc.user_id,
  sc.customer_id,
  ss.subscription_id,
  ss.status as subscription_status,
  ss.price_id,
  ss.current_period_start,
  ss.current_period_end,
  ss.cancel_at_period_end,
  ss.payment_method_brand,
  ss.payment_method_last4
FROM stripe_customers sc
LEFT JOIN stripe_subscriptions ss ON sc.customer_id = ss.customer_id
WHERE sc.deleted_at IS NULL 
  AND (ss.deleted_at IS NULL OR ss.deleted_at IS NULL);