import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from './useAuth';

export interface Team {
  id: string;
  name: string;
  admin_user_id: string;
  stripe_subscription_id: string | null;
  stripe_customer_id: string | null;
  max_members: number;
  current_members: number;
  status: 'active' | 'suspended' | 'cancelled';
  created_at: string;
  updated_at: string;
}

export interface TeamMember {
  id: string;
  team_id: string;
  user_id: string;
  role: 'admin' | 'member';
  status: 'active' | 'suspended';
  display_name: string | null;
  created_by: string;
  created_at: string;
  updated_at: string;
  // Joined user data
  email?: string;
  full_name?: string;
}

export interface TeamSubscription {
  id: string;
  team_id: string;
  stripe_subscription_id: string;
  stripe_customer_id: string;
  status: 'active' | 'cancelled' | 'past_due';
  current_period_start: number;
  current_period_end: number;
  cancel_at_period_end: boolean;
  price_id: string;
  created_at: string;
  updated_at: string;
}

export function useTeam() {
  const { user } = useAuth();
  const [team, setTeam] = useState<Team | null>(null);
  const [teamMembers, setTeamMembers] = useState<TeamMember[]>([]);
  const [teamSubscription, setTeamSubscription] = useState<TeamSubscription | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isTeamAdmin, setIsTeamAdmin] = useState(false);
  const [isTeamMember, setIsTeamMember] = useState(false);

  // Fetch team data
  const fetchTeamData = useCallback(async () => {
    if (!user) {
      setTeam(null);
      setTeamMembers([]);
      setTeamSubscription(null);
      setIsTeamAdmin(false);
      setIsTeamMember(false);
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      setError(null);

      console.log('🔄 Fetching team data for user:', user.id);

      // Check if user is team admin
      const { data: adminTeam, error: adminError } = await supabase
        .from('teams')
        .select('*')
        .eq('admin_user_id', user.id)
        .maybeSingle();

      if (adminError && adminError.code !== 'PGRST116') {
        throw adminError;
      }

      // Check if user is team member
      const { data: memberTeam, error: memberError } = await supabase
        .from('team_members')
        .select(`
          *,
          teams (*)
        `)
        .eq('user_id', user.id)
        .eq('status', 'active')
        .maybeSingle();

      if (memberError && memberError.code !== 'PGRST116') {
        throw memberError;
      }

      let currentTeam: Team | null = null;
      let isAdmin = false;
      let isMember = false;

      if (adminTeam) {
        currentTeam = adminTeam;
        isAdmin = true;
        console.log('✅ User is team admin');
      } else if (memberTeam?.teams) {
        currentTeam = memberTeam.teams as Team;
        isMember = true;
        console.log('✅ User is team member');
      }

      setTeam(currentTeam);
      setIsTeamAdmin(isAdmin);
      setIsTeamMember(isMember);

      // If user has a team, fetch members and subscription
      if (currentTeam) {
        // Fetch team members (without auth.users join - not allowed from client)
        const { data: members, error: membersError } = await supabase
          .from('team_members')
          .select(`
            *,
            user_profiles (email, full_name)
          `)
          .eq('team_id', currentTeam.id)
          .eq('status', 'active');

        if (membersError) {
          console.error('❌ Error fetching team members:', membersError);
        } else {
          const formattedMembers = members?.map(member => ({
            ...member,
            email: member.user_profiles?.email,
            full_name: member.user_profiles?.full_name
          })) || [];
          setTeamMembers(formattedMembers);
        }

        // Fetch team subscription (only if admin)
        if (isAdmin && currentTeam.stripe_subscription_id) {
          const { data: subscription, error: subError } = await supabase
            .from('team_subscriptions')
            .select('*')
            .eq('team_id', currentTeam.id)
            .maybeSingle();

          if (subError && subError.code !== 'PGRST116') {
            console.error('❌ Error fetching team subscription:', subError);
          } else {
            setTeamSubscription(subscription);
          }
        }
      }

    } catch (err) {
      console.error('❌ Error fetching team data:', err);
      setError(err instanceof Error ? err.message : 'Failed to fetch team data');
    } finally {
      setLoading(false);
    }
  }, [user]);

  // Create team
  const createTeam = async (teamName: string) => {
    if (!user) throw new Error('User not authenticated');

    try {
      const { data, error } = await supabase
        .from('teams')
        .insert({
          name: teamName,
          admin_user_id: user.id,
          max_members: 5,
          current_members: 1,
          status: 'active'
        })
        .select()
        .single();

      if (error) throw error;

      console.log('✅ Team created successfully:', data);
      await fetchTeamData();
      return data;
    } catch (err) {
      console.error('❌ Error creating team:', err);
      throw err;
    }
  };

  // Create team member
  const createTeamMember = async (email: string, password: string, displayName?: string) => {
    if (!user || !isTeamAdmin) {
      throw new Error('Only team admin can create members');
    }

    try {
      console.log('🔄 Creating team member:', { email, displayName });

      // Call the server-side function to create the team member
      const { data, error } = await supabase.rpc('create_team_member', {
        p_email: email,
        p_password: password,
        p_display_name: displayName || '',
        p_admin_user_id: user.id
      });

      if (error) {
        console.error('❌ Database error creating team member:', error);
        throw new Error(error.message || 'Database error saving new user');
      }

      if (!data?.success) {
        console.error('❌ Function returned error:', data?.error);
        throw new Error(data?.error || 'Failed to create team member');
      }

      console.log('✅ Team member created successfully:', data);

      // Refresh team data to show the new member
      await fetchTeamData();

      return {
        id: data.user_id,
        email: data.email,
        display_name: data.display_name
      };
    } catch (err) {
      console.error('❌ Error creating team member:', err);
      throw err;
    }
  };

  // Update team member password
  const updateMemberPassword = async (memberId: string, newPassword: string) => {
    if (!user || !isTeamAdmin) {
      throw new Error('Only team admin can update member passwords');
    }

    try {
      const member = teamMembers.find(m => m.id === memberId);
      if (!member) throw new Error('Team member not found');

      const { error } = await supabase.auth.admin.updateUserById(member.user_id, {
        password: newPassword
      });

      if (error) throw error;

      console.log('✅ Member password updated successfully');
      return true;
    } catch (err) {
      console.error('❌ Error updating member password:', err);
      throw err;
    }
  };

  // Remove team member (complete account deletion)
  const removeMember = async (memberId: string) => {
    if (!user || !isTeamAdmin) {
      throw new Error('Only team admin can remove members');
    }

    try {
      console.log('🗑️ Completely deleting team member account:', memberId);

      // Get the member's user_id before deletion
      const member = teamMembers.find(m => m.id === memberId);
      if (!member) throw new Error('Team member not found');

      // Call Supabase function to completely delete the user account
      const { error } = await supabase.rpc('delete_team_member_account', {
        p_member_user_id: member.user_id,
        p_admin_user_id: user.id
      });

      if (error) {
        console.error('❌ Account deletion failed:', error);
        throw new Error(error.message || 'Failed to delete member account');
      }

      console.log('✅ Team member account completely deleted');
      await fetchTeamData(); // Refresh team data
      return true;
    } catch (err) {
      console.error('❌ Error deleting team member account:', err);
      throw err;
    }
  };

  useEffect(() => {
    fetchTeamData();
  }, [fetchTeamData]);

  return {
    team,
    teamMembers,
    teamSubscription,
    loading,
    error,
    isTeamAdmin,
    isTeamMember,
    createTeam,
    createTeamMember,
    updateMemberPassword,
    removeMember,
    refetch: fetchTeamData
  };
}
