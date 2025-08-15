-- 🚀 Create axiestudio_accounts table with access token storage
-- This allows us to store and reuse access tokens from AxieStudio

-- Create the axiestudio_accounts table if it doesn't exist
CREATE TABLE IF NOT EXISTS axiestudio_accounts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    axiestudio_username TEXT,
    axiestudio_password TEXT,
    axiestudio_email TEXT,
    access_token TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_accessed TIMESTAMPTZ,

    -- Ensure one account per user
    UNIQUE(user_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_axiestudio_accounts_user_id
ON axiestudio_accounts(user_id);

CREATE INDEX IF NOT EXISTS idx_axiestudio_accounts_access_token
ON axiestudio_accounts(access_token)
WHERE access_token IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_axiestudio_accounts_last_accessed
ON axiestudio_accounts(last_accessed)
WHERE last_accessed IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_axiestudio_accounts_active
ON axiestudio_accounts(is_active)
WHERE is_active = true;

-- Add RLS (Row Level Security) policies
ALTER TABLE axiestudio_accounts ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own AxieStudio accounts
CREATE POLICY "Users can view own axiestudio accounts" ON axiestudio_accounts
    FOR SELECT USING (auth.uid() = user_id);

-- Policy: Users can insert their own AxieStudio accounts
CREATE POLICY "Users can insert own axiestudio accounts" ON axiestudio_accounts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own AxieStudio accounts
CREATE POLICY "Users can update own axiestudio accounts" ON axiestudio_accounts
    FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Users can delete their own AxieStudio accounts
CREATE POLICY "Users can delete own axiestudio accounts" ON axiestudio_accounts
    FOR DELETE USING (auth.uid() = user_id);

-- Add comments explaining the table and columns
COMMENT ON TABLE axiestudio_accounts IS 'Stores AxieStudio account information and access tokens for users';
COMMENT ON COLUMN axiestudio_accounts.user_id IS 'Reference to the user in auth.users';
COMMENT ON COLUMN axiestudio_accounts.axiestudio_username IS 'Username for AxieStudio account';
COMMENT ON COLUMN axiestudio_accounts.axiestudio_password IS 'Encrypted password for AxieStudio account';
COMMENT ON COLUMN axiestudio_accounts.axiestudio_email IS 'Email used for AxieStudio account';
COMMENT ON COLUMN axiestudio_accounts.access_token IS 'Stores AxieStudio access token for auto-login functionality';
COMMENT ON COLUMN axiestudio_accounts.is_active IS 'Whether this AxieStudio account is active';
COMMENT ON COLUMN axiestudio_accounts.last_accessed IS 'Timestamp when this AxieStudio account was last accessed via Launch Studio button';
COMMENT ON COLUMN axiestudio_accounts.updated_at IS 'Timestamp when this record was last updated';
