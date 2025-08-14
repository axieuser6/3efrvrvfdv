import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'npm:@supabase/supabase-js@2.49.1';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { user_id } = await req.json();

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: 'User ID is required' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    console.log(`🔄 Cancelling subscriptions immediately for user: ${user_id}`);

    // Get user's Stripe customer ID
    const { data: customerData } = await supabase
      .from('stripe_customers')
      .select('customer_id')
      .eq('user_id', user_id)
      .single();

    if (!customerData?.customer_id) {
      console.log('ℹ️ No Stripe customer found for user');
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'No subscriptions to cancel' 
        }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    // Get all active subscriptions for this customer
    const { data: subscriptions } = await supabase
      .from('stripe_subscriptions')
      .select('subscription_id, status')
      .eq('customer_id', customerData.customer_id)
      .in('status', ['active', 'trialing']);

    if (!subscriptions || subscriptions.length === 0) {
      console.log('ℹ️ No active subscriptions found');
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'No active subscriptions to cancel' 
        }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    // Cancel each subscription immediately
    const cancelResults = [];
    for (const subscription of subscriptions) {
      try {
        console.log(`🔄 Cancelling subscription: ${subscription.subscription_id}`);
        
        // Use the existing cancel-subscription function with immediate flag
        const { data, error } = await supabase.functions.invoke('cancel-subscription', {
          body: { 
            subscription_id: subscription.subscription_id,
            immediate: true 
          }
        });

        if (error) {
          console.error(`❌ Failed to cancel ${subscription.subscription_id}:`, error);
          cancelResults.push({
            subscription_id: subscription.subscription_id,
            success: false,
            error: error.message
          });
        } else {
          console.log(`✅ Cancelled subscription: ${subscription.subscription_id}`);
          cancelResults.push({
            subscription_id: subscription.subscription_id,
            success: true
          });
        }
      } catch (error) {
        console.error(`❌ Error cancelling ${subscription.subscription_id}:`, error);
        cancelResults.push({
          subscription_id: subscription.subscription_id,
          success: false,
          error: error.message
        });
      }
    }

    // Update user access status to remove access immediately
    try {
      await supabase
        .from('user_access_status')
        .upsert({
          user_id: user_id,
          access_type: 'none',
          trial_status: 'cancelled',
          subscription_status: 'cancelled',
          trial_ends_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        });
      console.log('✅ User access removed immediately');
    } catch (error) {
      console.warn('⚠️ Failed to update access status:', error);
    }

    const successCount = cancelResults.filter(r => r.success).length;
    const totalCount = cancelResults.length;

    console.log(`✅ Subscription cancellation completed: ${successCount}/${totalCount} successful`);

    return new Response(
      JSON.stringify({ 
        success: true,
        message: `Cancelled ${successCount}/${totalCount} subscriptions`,
        results: cancelResults
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );

  } catch (error) {
    console.error('❌ Subscription cancellation failed:', error);
    
    return new Response(
      JSON.stringify({ 
        error: 'Failed to cancel subscriptions',
        details: error.message 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );
  }
});
