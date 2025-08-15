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

        // BULLETPROOF: Use fixed view with user_id column
        const { data, error: fetchError } = await supabase
          .from('stripe_user_subscriptions')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();

        if (data && !fetchError) {
          console.log('✅ Successfully fetched from fixed stripe_user_subscriptions view:', data);

          // Add product name if we have a price_id
          const product = data.price_id ? getProductByPriceId(data.price_id) : null;
          setSubscription({
            ...data,
            product_name: product?.name,
          });

          // BULLETPROOF: Sync subscription status for protection
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

        console.log('⚠️ Fixed view failed, trying base tables fallback:', fetchError);

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
          // Query most recent active subscription
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

          console.log('✅ Fallback: Successfully fetched from base tables:', enrichedData);

          // BULLETPROOF: Ensure protection for paying customers
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

    // BULLETPROOF: More frequent polling for subscription changes
    const interval = setInterval(fetchSubscription, 5000);

    return () => clearInterval(interval);
  }, [user]);

  const hasActiveSubscription = subscription?.subscription_status === 'active';
  const isTrialing = subscription?.subscription_status === 'trialing';
  const isPastDue = subscription?.subscription_status === 'past_due';
  // BULLETPROOF: Enhanced cancellation detection
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