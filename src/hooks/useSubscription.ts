import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from './useAuth';
import { getProductByPriceId } from '../stripe-config';

export interface UserSubscription {
  customer_id: string;
  subscription_id: string | null;
  subscription_status: 'not_started' | 'incomplete' | 'incomplete_expired' | 'trialing' | 'active' | 'past_due' | 'canceled' | 'unpaid' | 'paused';
  price_id: string | null;
  current_period_start: number | null;
  current_period_end: number | null;
  cancel_at_period_end: boolean;
  payment_method_brand: string | null;
  payment_method_last4: string | null;
  product_name?: string;
}

export function useSubscription() {
  const { user } = useAuth();
  const [subscription, setSubscription] = useState<UserSubscription | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!user) {
      setSubscription(null);
      setLoading(false);
      return;
    }

    const fetchSubscription = async () => {
      try {
        setLoading(true);
        setError(null);

        console.log('🔄 Fetching subscription for user:', user.id);

        // Try the view first
        const { data, error: fetchError } = await supabase
          .from('stripe_user_subscriptions')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();

        if (data && !fetchError) {
          console.log('✅ Successfully fetched from stripe_user_subscriptions view:', data);

          // Add product name if we have a price_id
          const product = data.price_id ? getProductByPriceId(data.price_id) : null;
          setSubscription({
            ...data,
            product_name: product?.name,
          });

          // Sync subscription status to ensure trial protection
          if (data.subscription_status === 'active' || data.subscription_status === 'trialing') {
            try {
              await supabase.rpc('sync_subscription_status');
              await supabase.rpc('protect_paying_customers');
            } catch (error) {
              console.error('Failed to sync subscription status:', error);
            }
          }
          return;
        }

        console.log('⚠️ stripe_user_subscriptions view failed, trying base tables:', fetchError);

        // Fallback: Query base tables directly with manual join
        const { data: customerData, error: customerError } = await supabase
          .from('stripe_customers')
          .select('customer_id')
          .eq('user_id', user.id)
          .is('deleted_at', null)
          .maybeSingle();

        if (customerError) {
          throw customerError;
        }

        if (customerData) {
          // Now query subscription separately to avoid relationship issues
          // Order by updated_at desc to get the most recent subscription
          const { data: subscriptionData, error: subscriptionError } = await supabase
            .from('stripe_subscriptions')
            .select('*')
            .eq('customer_id', customerData.customer_id)
            .is('deleted_at', null)
            .order('updated_at', { ascending: false })
            .limit(1)
            .maybeSingle();

          if (subscriptionError) {
            console.warn('Subscription query failed:', subscriptionError);
          }

          const enrichedData: UserSubscription = {
            customer_id: customerData.customer_id,
            subscription_id: subscriptionData?.subscription_id || null,
            subscription_status: subscriptionData?.status || 'not_started',
            price_id: subscriptionData?.price_id || null,
            current_period_start: subscriptionData?.current_period_start || null,
            current_period_end: subscriptionData?.current_period_end || null,
            cancel_at_period_end: subscriptionData?.cancel_at_period_end || false,
            payment_method_brand: subscriptionData?.payment_method_brand || null,
            payment_method_last4: subscriptionData?.payment_method_last4 || null,
          };

          // Add product name if we have a price_id
          const product = enrichedData.price_id ? getProductByPriceId(enrichedData.price_id) : null;
          setSubscription({
            ...enrichedData,
            product_name: product?.name,
          });

          console.log('✅ Successfully fetched from base tables:', enrichedData);
          console.log('🔍 Full subscription object:', subscriptionData);
          console.log('🔍 Cancel at period end:', subscriptionData?.cancel_at_period_end);
          console.log('🔍 Current period end:', subscriptionData?.current_period_end);
          console.log('🔍 Is subscription cancelled?:', subscriptionData?.cancel_at_period_end === true);

          // Sync subscription status to ensure trial protection
          if (enrichedData.subscription_status === 'active' || enrichedData.subscription_status === 'trialing') {
            try {
              await supabase.rpc('sync_subscription_status');
              await supabase.rpc('protect_paying_customers');
            } catch (error) {
              console.error('Failed to sync subscription status:', error);
            }
          }
        } else {
          console.log('ℹ️ No customer found for user');
          setSubscription(null);
          console.log('ℹ️ No subscription found for user');
          setSubscription(null);
        }
      } catch (err) {
        console.error('Error fetching subscription:', err);
        setError(err instanceof Error ? err.message : 'Failed to fetch subscription');
        setSubscription(null);
      } finally {
        setLoading(false);
      }
    };

    fetchSubscription();

    // Poll for subscription changes every 10 seconds (faster detection)
    const interval = setInterval(fetchSubscription, 10000);

    return () => clearInterval(interval);
  }, [user]);

  const hasActiveSubscription = subscription?.subscription_status === 'active';
  const isTrialing = subscription?.subscription_status === 'trialing';
  const isPastDue = subscription?.subscription_status === 'past_due';
  // A subscription is considered cancelled if it has cancel_at_period_end=true OR status is 'canceled'
  const isCanceled = subscription?.cancel_at_period_end === true || subscription?.subscription_status === 'canceled';

  return {
    subscription,
    loading,
    error,
    hasActiveSubscription,
    isTrialing,
    isPastDue,
    isCanceled,
    refetch: () => {
      if (user) {
        // Trigger a re-fetch by updating the effect dependency
        setLoading(true);
      }
    },
  };
}