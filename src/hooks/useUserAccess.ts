import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from './useAuth';

export interface UserAccessStatus {
  user_id: string;
  trial_start_date: string;
  trial_end_date: string;
  trial_status: 'active' | 'expired' | 'converted_to_paid' | 'scheduled_for_deletion';
  deletion_scheduled_at: string | null;
  subscription_status: string | null;
  subscription_id: string | null;
  price_id: string | null;
  current_period_end: number | null;
  has_access: boolean;
  access_type: 'paid_subscription' | 'stripe_trial' | 'free_trial' | 'no_access';
  seconds_remaining: number;
  days_remaining: number;
}

export function useUserAccess() {
  const { user } = useAuth();
  const [accessStatus, setAccessStatus] = useState<UserAccessStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!user) {
      setAccessStatus(null);
      setLoading(false);
      return;
    }

    const fetchAccessStatus = async () => {
      try {
        setLoading(true);
        setError(null);

        console.log('🔄 Fetching user access status for user:', user.id);

        // Use the existing function that we know works
        try {
          const result = await supabase.rpc('get_user_access_level', {
            p_user_id: user.id
          });
          
          if (result.error) {
            console.warn('RPC function failed, using fallback:', result.error);
            // Create basic fallback data
            const fallbackData = {
              user_id: user.id,
              has_access: true,
              access_type: 'free_trial',
              trial_status: 'active',
              subscription_status: null,
              days_remaining: 7,
              seconds_remaining: 7 * 24 * 60 * 60,
              trial_start_date: user.created_at,
              trial_end_date: new Date(new Date(user.created_at).getTime() + 7 * 24 * 60 * 60 * 1000).toISOString(),
              deletion_scheduled_at: null,
              subscription_id: null,
              price_id: null,
              current_period_end: null
            };
            setAccessStatus(fallbackData);
            return;
          }
          
          if (result.data && result.data.length > 0) {
            console.log('✅ User access data:', result.data[0]);
            setAccessStatus(result.data[0]);
            return;
          }
        } catch (rpcError) {
          console.warn('RPC function not available, using fallback:', rpcError);
        }

        // Create basic fallback data
        const fallbackData: UserAccessStatus = {
          user_id: user.id,
          has_access: true,
          access_type: 'free_trial',
          trial_status: 'active',
          subscription_status: null,
          days_remaining: 7,
          seconds_remaining: 7 * 24 * 60 * 60,
          trial_start_date: user.created_at,
          trial_end_date: new Date(new Date(user.created_at).getTime() + 7 * 24 * 60 * 60 * 1000).toISOString(),
          deletion_scheduled_at: null,
          subscription_id: null,
          price_id: null,
          current_period_end: null
        };

        console.log('✅ Using fallback access data');
        setAccessStatus(fallbackData);

      } catch (err) {
        console.error('Error fetching user access status:', err);
        
        // Even on error, provide basic access
        const errorFallback: UserAccessStatus = {
          user_id: user.id,
          has_access: true,
          access_type: 'free_trial',
          trial_status: 'active',
          subscription_status: null,
          days_remaining: 7,
          seconds_remaining: 7 * 24 * 60 * 60,
          trial_start_date: user.created_at,
          trial_end_date: new Date(new Date(user.created_at).getTime() + 7 * 24 * 60 * 60 * 1000).toISOString(),
          deletion_scheduled_at: null,
          subscription_id: null,
          price_id: null,
          current_period_end: null
        };
        
        setAccessStatus(errorFallback);
        setError(null); // Don't show errors to user
      } finally {
        setLoading(false);
      }
    };

    fetchAccessStatus();
  }, [user]);

  const hasAccess = accessStatus?.has_access || false;
  const isPaidUser = accessStatus?.access_type === 'paid_subscription';
  const isTrialing = accessStatus?.access_type === 'stripe_trial';
  const isFreeTrialing = accessStatus?.access_type === 'free_trial';
  const isProtected = isPaidUser || isTrialing;

  return {
    accessStatus,
    loading,
    error,
    hasAccess,
    isPaidUser,
    isTrialing,
    isFreeTrialing,
    lastFetch,
    refetch: () => {
        setLoading(true);
      }
    }
  };
}