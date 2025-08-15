-- 🚀 SIMPLE TEAM SYSTEM DATABASE SCHEMA
-- Run this in Supabase SQL Editor

-- 1. TEAMS TABLE
CREATE TABLE IF NOT EXISTS teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  admin_user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  stripe_subscription_id text, -- Team subscription ID
  stripe_customer_id text,     -- Team customer ID
  max_members integer DEFAULT 5,
  current_members integer DEFAULT 1, -- Admin counts as 1
  status text DEFAULT 'active', -- 'active', 'suspended', 'cancelled'
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),

  CONSTRAINT teams_admin_unique UNIQUE(admin_user_id)
);

-- 2. TEAM MEMBERS TABLE
CREATE TABLE IF NOT EXISTS team_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid REFERENCES teams(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  role text DEFAULT 'member', -- 'admin' or 'member'
  status text DEFAULT 'active', -- 'active', 'suspended'
  display_name text,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),

  CONSTRAINT team_members_unique UNIQUE(team_id, user_id)
);

-- 3. TEAM SUBSCRIPTION TRACKING
CREATE TABLE IF NOT EXISTS team_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid REFERENCES teams(id) ON DELETE CASCADE,
  stripe_subscription_id text NOT NULL,
  stripe_customer_id text NOT NULL,
  status text NOT NULL, -- 'active', 'cancelled', 'past_due'
  current_period_start bigint,
  current_period_end bigint,
  cancel_at_period_end boolean DEFAULT false,
  price_id text, -- Team Pro price ID
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),

  CONSTRAINT team_subscriptions_unique UNIQUE(team_id)
);

-- 4. INDEXES FOR PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_teams_admin ON teams(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_team_members_team ON team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user ON team_members(user_id);
CREATE INDEX IF NOT EXISTS idx_team_subscriptions_team ON team_subscriptions(team_id);

-- 5. ROW LEVEL SECURITY (RLS)
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_subscriptions ENABLE ROW LEVEL SECURITY;

-- 6. RLS POLICIES

-- Teams: Admin can see their team, members can see their team
CREATE POLICY "Teams access policy" ON teams
  FOR ALL USING (
    admin_user_id = auth.uid() OR
    id IN (SELECT team_id FROM team_members WHERE user_id = auth.uid())
  );

-- Team Members: Team admin and members can see team members
CREATE POLICY "Team members access policy" ON team_members
  FOR ALL USING (
    team_id IN (
      SELECT id FROM teams WHERE admin_user_id = auth.uid()
      UNION
      SELECT team_id FROM team_members WHERE user_id = auth.uid()
    )
  );

-- Team Subscriptions: Only team admin can see subscription details
CREATE POLICY "Team subscriptions access policy" ON team_subscriptions
  FOR ALL USING (
    team_id IN (SELECT id FROM teams WHERE admin_user_id = auth.uid())
  );

-- 7. FUNCTIONS

-- Function to check if user is team admin
CREATE OR REPLACE FUNCTION is_team_admin(user_id uuid, team_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM teams
    WHERE id = team_id AND admin_user_id = user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get team member count
CREATE OR REPLACE FUNCTION get_team_member_count(team_id uuid)
RETURNS integer AS $$
BEGIN
  RETURN (
    SELECT COUNT(*) FROM team_members
    WHERE team_members.team_id = get_team_member_count.team_id
    AND status = 'active'
  ) + 1; -- +1 for admin
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update team member count
CREATE OR REPLACE FUNCTION update_team_member_count()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE teams
    SET current_members = get_team_member_count(NEW.team_id),
        updated_at = now()
    WHERE id = NEW.team_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE teams
    SET current_members = get_team_member_count(OLD.team_id),
        updated_at = now()
    WHERE id = OLD.team_id;
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE teams
    SET current_members = get_team_member_count(NEW.team_id),
        updated_at = now()
    WHERE id = NEW.team_id;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. TRIGGERS
CREATE TRIGGER team_member_count_trigger
  AFTER INSERT OR UPDATE OR DELETE ON team_members
  FOR EACH ROW EXECUTE FUNCTION update_team_member_count();

-- 9. SAMPLE DATA (Optional - for testing)
-- This will be populated when team admins create teams

SELECT '✅ TEAM SYSTEM SCHEMA CREATED SUCCESSFULLY!' as status;

-- 1. TEAMS TABLE
CREATE TABLE IF NOT EXISTS teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  admin_user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  stripe_subscription_id text, -- Team subscription ID
  stripe_customer_id text,     -- Team customer ID
  max_members integer DEFAULT 5,
  current_members integer DEFAULT 1, -- Admin counts as 1
  status text DEFAULT 'active', -- 'active', 'suspended', 'cancelled'
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  CONSTRAINT teams_admin_unique UNIQUE(admin_user_id)
);

-- 2. TEAM MEMBERS TABLE
CREATE TABLE IF NOT EXISTS team_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid REFERENCES teams(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  role text DEFAULT 'member', -- 'admin' or 'member'
  status text DEFAULT 'active', -- 'active', 'suspended'
  display_name text,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  CONSTRAINT team_members_unique UNIQUE(team_id, user_id)
);

-- 3. TEAM SUBSCRIPTION TRACKING
CREATE TABLE IF NOT EXISTS team_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id uuid REFERENCES teams(id) ON DELETE CASCADE,
  stripe_subscription_id text NOT NULL,
  stripe_customer_id text NOT NULL,
  status text NOT NULL, -- 'active', 'cancelled', 'past_due'
  current_period_start bigint,
  current_period_end bigint,
  cancel_at_period_end boolean DEFAULT false,
  price_id text, -- Team Pro price ID
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  CONSTRAINT team_subscriptions_unique UNIQUE(team_id)
);

-- 4. INDEXES FOR PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_teams_admin ON teams(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_team_members_team ON team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user ON team_members(user_id);
CREATE INDEX IF NOT EXISTS idx_team_subscriptions_team ON team_subscriptions(team_id);

-- 5. ROW LEVEL SECURITY (RLS)
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_subscriptions ENABLE ROW LEVEL SECURITY;

-- 6. RLS POLICIES

-- Teams: Admin can see their team, members can see their team
CREATE POLICY "Teams access policy" ON teams
  FOR ALL USING (
    admin_user_id = auth.uid() OR 
    id IN (SELECT team_id FROM team_members WHERE user_id = auth.uid())
  );

-- Team Members: Team admin and members can see team members
CREATE POLICY "Team members access policy" ON team_members
  FOR ALL USING (
    team_id IN (
      SELECT id FROM teams WHERE admin_user_id = auth.uid()
      UNION
      SELECT team_id FROM team_members WHERE user_id = auth.uid()
    )
  );

-- Team Subscriptions: Only team admin can see subscription details
CREATE POLICY "Team subscriptions access policy" ON team_subscriptions
  FOR ALL USING (
    team_id IN (SELECT id FROM teams WHERE admin_user_id = auth.uid())
  );

-- 7. FUNCTIONS

-- Function to check if user is team admin
CREATE OR REPLACE FUNCTION is_team_admin(user_id uuid, team_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM teams 
    WHERE id = team_id AND admin_user_id = user_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get team member count
CREATE OR REPLACE FUNCTION get_team_member_count(team_id uuid)
RETURNS integer AS $$
BEGIN
  RETURN (
    SELECT COUNT(*) FROM team_members 
    WHERE team_members.team_id = get_team_member_count.team_id 
    AND status = 'active'
  ) + 1; -- +1 for admin
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update team member count
CREATE OR REPLACE FUNCTION update_team_member_count()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE teams 
    SET current_members = get_team_member_count(NEW.team_id),
        updated_at = now()
    WHERE id = NEW.team_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE teams 
    SET current_members = get_team_member_count(OLD.team_id),
        updated_at = now()
    WHERE id = OLD.team_id;
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE teams 
    SET current_members = get_team_member_count(NEW.team_id),
        updated_at = now()
    WHERE id = NEW.team_id;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. TRIGGERS
CREATE TRIGGER team_member_count_trigger
  AFTER INSERT OR UPDATE OR DELETE ON team_members
  FOR EACH ROW EXECUTE FUNCTION update_team_member_count();

-- 9. SAMPLE DATA (Optional - for testing)
-- This will be populated when team admins create teams

SELECT '✅ TEAM SYSTEM SCHEMA CREATED SUCCESSFULLY!' as status;
