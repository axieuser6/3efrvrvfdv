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

        // Try enterprise dashboard view first (best option)
        const { data: dashboardData, error: dashboardError } = await supabase
          .from('user_dashboard')
          .select('*')
          .maybeSingle();

        if (dashboardData && !dashboardError) {
          console.log('✅ Successfully fetched from enterprise user_dashboard:', dashboardData);
          // Convert enterprise format to expected format
          const enterpriseData = {
            user_id: dashboardData.user_id,
            trial_start_date: dashboardData.trial_start_date,
            trial_end_date: dashboardData.trial_end_date,
            trial_status: dashboardData.trial_status,
            deletion_scheduled_at: null,
            subscription_status: dashboardData.stripe_status,
            subscription_id: dashboardData.stripe_subscription_id,
            price_id: dashboardData.price_id,
            current_period_end: dashboardData.current_period_end,
            has_access: dashboardData.has_access,
            access_type: dashboardData.access_level === 'pro' ? 'paid_subscription' :
                        dashboardData.access_level === 'trial' ? 'free_trial' : 'no_access',
            seconds_remaining: dashboardData.trial_days_remaining * 24 * 60 * 60,
            days_remaining: dashboardData.trial_days_remaining
          };
          setAccessStatus(enterpriseData);
          return;
        }

        console.log('⚠️ Enterprise dashboard not available, trying user_access_status view:', dashboardError);

        // Try to use the user_access_status view (basic option)
        const { data: accessData, error: accessError } = await supabase
          .from('user_access_status')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();

        if (accessData && !accessError) {
          console.log('✅ Successfully fetched from user_access_status view:', accessData);
          setAccessStatus(accessData);
          return;
        }

        console.log('⚠️ user_access_status view failed, trying individual queries:', accessError);

        // Fallback: Query individual tables/views
        const { data: trialData, error: trialError } = await supabase
          .from('user_trial_info')
          .select('*')
          .maybeSingle();

        console.log('Trial data result:', { trialData, trialError });

        const { data: subscriptionData, error: subscriptionError } = await supabase
          .from('stripe_user_subscriptions')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();

        console.log('Subscription data result:', { subscriptionData, subscriptionError });

        // If subscription query fails (multiple rows), try querying the base tables directly
        if (subscriptionError && subscriptionError.code === 'PGRST116') {
          console.log('⚠️ Views failed, trying base tables...');

          // Use trial data from the view if available, otherwise query directly
          let userTrialData = trialData;
          if (!userTrialData && trialError) {
            const { data: directTrialData, error: userTrialError } = await supabase
              .from('user_trials')
              .select('*')
              .eq('user_id', user.id)
              .maybeSingle();
            userTrialData = directTrialData;
            console.log('User trials result:', { userTrialData, userTrialError });
          }

          // Query stripe data through customers table
          const { data: stripeData, error: stripeError } = await supabase
            .from('stripe_customers')
            .select(`
              customer_id,
              stripe_subscriptions (
                subscription_id,
                status,
                price_id,
                current_period_end
              )
            `)
            .eq('user_id', user.id)
            .is('deleted_at', null)
            .maybeSingle();

          console.log('Stripe data result:', { stripeData, stripeError });

          // Combine the data from base tables
          const subscription = stripeData?.stripe_subscriptions?.[0];

          // Determine access type - prioritize subscription status
          let access_type: 'paid_subscription' | 'stripe_trial' | 'free_trial' | 'no_access' = 'no_access';
          let has_access = false;

          if (subscription?.status === 'active') {
            access_type = 'paid_subscription';
            has_access = true;
          } else if (subscription?.status === 'trialing') {
            access_type = 'stripe_trial';
            has_access = true;
          } else if (userTrialData?.trial_status === 'active' && userTrialData && new Date(userTrialData.trial_end_date) > new Date()) {
            access_type = 'free_trial';
            has_access = true;
          }

          const combinedData = {
            user_id: user.id,
            trial_start_date: userTrialData?.trial_start_date || '',
            trial_end_date: userTrialData?.trial_end_date || '',
            trial_status: subscription?.status === 'active' ? 'converted_to_paid' : userTrialData?.trial_status || 'expired',
            deletion_scheduled_at: userTrialData?.deletion_scheduled_at || null,
            subscription_status: subscription?.status || null,
            subscription_id: subscription?.subscription_id || null,
            price_id: subscription?.price_id || null,
            current_period_end: subscription?.current_period_end || null,
            has_access,
            access_type,
            seconds_remaining: userTrialData && new Date(userTrialData.trial_end_date) > new Date()
              ? Math.floor((new Date(userTrialData.trial_end_date).getTime() - new Date().getTime()) / 1000)
              : 0,
            days_remaining: userTrialData && new Date(userTrialData.trial_end_date) > new Date()
              ? Math.ceil((new Date(userTrialData.trial_end_date).getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24))
              : 0
          };

          console.log('✅ Combined data from base tables:', combinedData);
          setAccessStatus(combinedData);
          return;
        }

        // Combine the data from views - prioritize subscription status
        let access_type: 'paid_subscription' | 'stripe_trial' | 'free_trial' | 'no_access' = 'no_access';
        let has_access = false;

        if (subscriptionData?.subscription_status === 'active') {
          access_type = 'paid_subscription';
          has_access = true;
        } else if (subscriptionData?.subscription_status === 'trialing') {
          access_type = 'stripe_trial';
          has_access = true;
        } else if (trialData?.trial_status === 'active' && trialData?.days_remaining > 0) {
          access_type = 'free_trial';
          has_access = true;
        }

        const combinedData = {
          user_id: user.id,
          trial_start_date: trialData?.trial_start_date || '',
          trial_end_date: trialData?.trial_end_date || '',
          trial_status: subscriptionData?.subscription_status === 'active' ? 'converted_to_paid' : trialData?.trial_status || 'expired',
          deletion_scheduled_at: trialData?.deletion_scheduled_at || null,
          subscription_status: subscriptionData?.subscription_status || null,
          subscription_id: subscriptionData?.subscription_id || null,
          price_id: subscriptionData?.price_id || null,
          current_period_end: subscriptionData?.current_period_end || null,
          has_access,
          access_type,
          seconds_remaining: trialData?.seconds_remaining || 0,
          days_remaining: trialData?.days_remaining || 0
        };

        console.log('✅ Combined data from views:', combinedData);
        setAccessStatus(combinedData);
      } catch (err) {
        console.error('Error fetching user access status:', err);
        setError(err instanceof Error ? err.message : 'Failed to fetch access status');
        setAccessStatus(null);
      } finally {
        setLoading(false);
      }
    };

    fetchAccessStatus();

    // Set up real-time subscription for access status updates
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

    return () => {
      subscription.unsubscribe();
    };
  }, [user]);

  const hasAccess = accessStatus?.has_access || false;
  const isPaidUser = accessStatus?.access_type === 'paid_subscription';
  const isTrialing = accessStatus?.access_type === 'stripe_trial';
  const isFreeTrialing = accessStatus?.access_type === 'free_trial';
  const isProtected = isPaidUser || isTrialing || accessStatus?.trial_status === 'converted_to_paid';

  return {
    accessStatus,
    loading,
    error,
    hasAccess,
    isPaidUser,
    isTrialing,
    isFreeTrialing,
    isProtected,
    refetch: () => {
      if (user) {
        setLoading(true);
      }
    },
  };
}