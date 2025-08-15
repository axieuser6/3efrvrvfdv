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
  // SECURITY: Enhanced tracking
  is_cancelled_subscription?: boolean;
  has_stripe_subscription?: boolean;
  subscription_verification_time?: number;
  is_expired_trial_user?: boolean;
  can_create_axiestudio_account?: boolean;
}

export function useUserAccess() {
  const { user } = useAuth();
  const [accessStatus, setAccessStatus] = useState<UserAccessStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastFetch, setLastFetch] = useState<number>(0);

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
        const fetchTime = Date.now();
        setLastFetch(fetchTime);

        console.log('🔄 Fetching user access status for user:', user.id);

        // SECURITY FIX: Use single, authoritative data source
        // Always use the RPC function for consistent results
        const { data: accessData, error: accessError } = await supabase.rpc('get_user_access_level', {
          p_user_id: user.id
        });

        if (accessError) {
          console.error('❌ Access check failed:', accessError);
          throw accessError;
        }

        if (!accessData || accessData.length === 0) {
          console.log('⚠️ No access data found for user');
          setAccessStatus(null);
          return;
        }

        const userAccess = accessData[0];
        console.log('✅ User access data:', userAccess);

        // SECURITY: Get subscription data separately for verification
        const { data: subscriptionData } = await supabase
          .from('stripe_user_subscriptions')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();

        // SECURITY: Cross-verify subscription status
        const hasActiveStripeSubscription = subscriptionData?.subscription_status === 'active';
        const hasTrialingStripeSubscription = subscriptionData?.subscription_status === 'trialing';
        const isSubscriptionCancelled = subscriptionData?.cancel_at_period_end === true;

        // BULLETPROOF ACCESS DETERMINATION
        let finalHasAccess = false;
        let finalAccessType: 'paid_subscription' | 'stripe_trial' | 'free_trial' | 'no_access' = 'no_access';

        // Priority 1: Active paid subscription (highest priority)
        if (hasActiveStripeSubscription && !isSubscriptionCancelled) {
          finalHasAccess = true;
          finalAccessType = 'paid_subscription';
        }
        // Priority 2: Trialing subscription
        else if (hasTrialingStripeSubscription) {
          finalHasAccess = true;
          finalAccessType = 'stripe_trial';
        }
        // Priority 3: Active free trial (only if no subscription exists)
        else if (userAccess.trial_status === 'active' && 
                 userAccess.days_remaining > 0 && 
                 !subscriptionData?.subscription_id) {
          finalHasAccess = true;
          finalAccessType = 'free_trial';
        }
        // Priority 4: Cancelled subscription (has access until period ends)
        else if (hasActiveStripeSubscription && isSubscriptionCancelled) {
          finalHasAccess = true;
          finalAccessType = 'paid_subscription'; // Still paid until period ends
        }

        // SECURITY: Build bulletproof access status
        const bulletproofAccessStatus: UserAccessStatus = {
          user_id: user.id,
          trial_start_date: userAccess.trial_start_date || '',
          trial_end_date: userAccess.trial_end_date || '',
          trial_status: userAccess.trial_status || 'expired',
          deletion_scheduled_at: userAccess.deletion_scheduled_at || null,
          subscription_status: subscriptionData?.subscription_status || null,
          subscription_id: subscriptionData?.subscription_id || null,
          price_id: subscriptionData?.price_id || null,
          current_period_end: subscriptionData?.current_period_end || null,
          has_access: finalHasAccess,
          access_type: finalAccessType,
          seconds_remaining: userAccess.seconds_remaining || 0,
          days_remaining: userAccess.days_remaining || 0,
          // SECURITY: Add verification flags
          is_cancelled_subscription: isSubscriptionCancelled,
          has_stripe_subscription: !!subscriptionData?.subscription_id,
          subscription_verification_time: fetchTime
        };

        console.log('🔒 Bulletproof access status:', bulletproofAccessStatus);
        setAccessStatus(bulletproofAccessStatus);

      } catch (err) {
        console.error('Error fetching user access status:', err);
        setError(err instanceof Error ? err.message : 'Failed to fetch access status');
        setAccessStatus(null);
      } finally {
        setLoading(false);
      }
    };

    fetchAccessStatus();

    // SECURITY: More frequent polling for subscription changes
    const subscription = supabase
      .channel('user_access_updates')
      .on('postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_trials',
          filter: `user_id=eq.${user.id}`
        },
        () => {
          console.log('🔄 Real-time update: user_trials changed');
          fetchAccessStatus();
        }
      )
      .on('postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'stripe_subscriptions'
        },
        () => {
          console.log('🔄 Real-time update: stripe_subscriptions changed');
          fetchAccessStatus();
        }
      )
      .subscribe();

    // SECURITY: Poll every 5 seconds for critical subscription changes
    const pollInterval = setInterval(() => {
      // Only poll if data is older than 5 seconds
      if (Date.now() - lastFetch > 5000) {
        fetchAccessStatus();
      }
    }, 5000);

    return () => {
      subscription.unsubscribe();
      clearInterval(pollInterval);
    };
  }, [user, lastFetch]);

  const hasAccess = accessStatus?.has_access || false;
  const isPaidUser = accessStatus?.access_type === 'paid_subscription';
  const isTrialing = accessStatus?.access_type === 'stripe_trial';
  const isFreeTrialing = accessStatus?.access_type === 'free_trial';
  
  // SECURITY: Enhanced protection logic
  const isProtected = isPaidUser || 
                     isTrialing || 
                     (accessStatus?.subscription_status === 'active' && !accessStatus?.is_cancelled_subscription) ||
                     accessStatus?.trial_status === 'converted_to_paid';
  
  // SECURITY: Additional security flags
  const isExpiredTrialUser = accessStatus?.trial_status === 'expired' || 
                            accessStatus?.trial_status === 'scheduled_for_deletion';
  const canCreateAxieStudioAccount = hasAccess && 
                                    !isExpiredTrialUser && 
                                    (isPaidUser || isTrialing || isFreeTrialing);

  return {
    accessStatus,
    loading,
    error,
    hasAccess,
    isPaidUser,
    isTrialing,
    isFreeTrialing,
    isProtected,
    // SECURITY: New security flags
    isExpiredTrialUser,
    canCreateAxieStudioAccount,
    lastFetch,
    refetch: () => {
      if (user) {
        setLoading(true);
      }
    },
  };
}