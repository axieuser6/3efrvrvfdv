-- Create table for storing AxieStudio credentials
CREATE TABLE IF NOT EXISTS axie_studio_credentials (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    axie_studio_user_id TEXT,
    axie_studio_email TEXT NOT NULL,
    axie_studio_password TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE axie_studio_credentials ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can only access their own credentials" ON axie_studio_credentials
    FOR ALL USING (auth.uid() = user_id);

-- Create function to store AxieStudio credentials
CREATE OR REPLACE FUNCTION store_axie_studio_credentials(
    p_user_id UUID,
    p_axie_studio_user_id TEXT,
    p_axie_studio_email TEXT,
    p_axie_studio_password TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO axie_studio_credentials (
        user_id,
        axie_studio_user_id,
        axie_studio_email,
        axie_studio_password
    ) VALUES (
        p_user_id,
        p_axie_studio_user_id,
        p_axie_studio_email,
        p_axie_studio_password
    )
    ON CONFLICT (user_id) 
    DO UPDATE SET
        axie_studio_user_id = EXCLUDED.axie_studio_user_id,
        axie_studio_email = EXCLUDED.axie_studio_email,
        axie_studio_password = EXCLUDED.axie_studio_password,
        updated_at = NOW();
END;
$$;

-- Create function to get AxieStudio credentials
CREATE OR REPLACE FUNCTION get_axie_studio_credentials(p_user_id UUID)
RETURNS TABLE(
    axie_studio_user_id TEXT,
    axie_studio_email TEXT,
    axie_studio_password TEXT,
    last_login_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        asc.axie_studio_user_id,
        asc.axie_studio_email,
        asc.axie_studio_password,
        asc.last_login_at
    FROM axie_studio_credentials asc
    WHERE asc.user_id = p_user_id;
END;
$$;

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_axie_studio_credentials_updated_at 
    BEFORE UPDATE ON axie_studio_credentials 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO service_role;
GRANT ALL ON axie_studio_credentials TO service_role;
GRANT EXECUTE ON FUNCTION store_axie_studio_credentials TO service_role;
GRANT EXECUTE ON FUNCTION get_axie_studio_credentials TO service_role;
