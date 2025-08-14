-- Add table to store AxieStudio credentials for auto-login
CREATE TABLE IF NOT EXISTS axie_studio_credentials (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    axie_studio_user_id text,
    axie_studio_email text NOT NULL,
    axie_studio_password_encrypted text NOT NULL, -- We'll encrypt this
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    last_login_at timestamptz
);

-- Add RLS policies
ALTER TABLE axie_studio_credentials ENABLE ROW LEVEL SECURITY;

-- Users can only see their own credentials
CREATE POLICY "Users can view own axie credentials" ON axie_studio_credentials
    FOR SELECT USING (auth.uid() = user_id);

-- Users can update their own credentials
CREATE POLICY "Users can update own axie credentials" ON axie_studio_credentials
    FOR UPDATE USING (auth.uid() = user_id);

-- Service role can manage all credentials
CREATE POLICY "Service role can manage axie credentials" ON axie_studio_credentials
    FOR ALL USING (auth.role() = 'service_role');

-- Function to store AxieStudio credentials (called when account is created)
CREATE OR REPLACE FUNCTION store_axie_studio_credentials(
    p_user_id uuid,
    p_axie_studio_user_id text,
    p_axie_studio_email text,
    p_axie_studio_password text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Simple encryption (in production, use proper encryption)
    -- For now, we'll use base64 encoding (NOT secure for production!)
    INSERT INTO axie_studio_credentials (
        user_id,
        axie_studio_user_id,
        axie_studio_email,
        axie_studio_password_encrypted
    )
    VALUES (
        p_user_id,
        p_axie_studio_user_id,
        p_axie_studio_email,
        encode(p_axie_studio_password::bytea, 'base64')
    )
    ON CONFLICT (user_id) DO UPDATE SET
        axie_studio_user_id = EXCLUDED.axie_studio_user_id,
        axie_studio_email = EXCLUDED.axie_studio_email,
        axie_studio_password_encrypted = EXCLUDED.axie_studio_password_encrypted,
        updated_at = now();
END;
$$;

-- Function to get AxieStudio credentials for auto-login
CREATE OR REPLACE FUNCTION get_axie_studio_credentials(p_user_id uuid)
RETURNS TABLE(
    axie_studio_email text,
    axie_studio_password text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        creds.axie_studio_email,
        convert_from(decode(creds.axie_studio_password_encrypted, 'base64'), 'UTF8') as axie_studio_password
    FROM axie_studio_credentials creds
    WHERE creds.user_id = p_user_id;
END;
$$;
