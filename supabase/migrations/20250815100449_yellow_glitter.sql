@@ .. @@
-- Create stripe_user_subscriptions view
CREATE VIEW stripe_user_subscriptions AS
SELECT
+    c.user_id,
    c.customer_id,
    s.subscription_id,
    s.status as subscription_status,
    s.price_id,
    s.current_period_end,
    s.created_at as subscription_created_at,
    s.updated_at as subscription_updated_at
FROM stripe_customers c
LEFT JOIN stripe_subscriptions s ON c.customer_id = s.customer_id
WHERE c.deleted_at IS NULL 
AND (s.deleted_at IS NULL OR s.deleted_at IS NULL);