import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14.21.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('🔄 Starting reactivate-subscription function...')
    
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
    
    console.log('Environment check:', {
      hasSupabaseUrl: !!supabaseUrl,
      hasSupabaseAnonKey: !!supabaseAnonKey,
      hasSupabaseServiceKey: !!supabaseServiceKey,
      hasStripeKey: !!stripeKey
    })

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceKey || !stripeKey) {
      throw new Error('Missing required environment variables')
    }

    // Use anon key for auth verification
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })

    // Use service role key for database operations
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })

    const authHeader = req.headers.get('Authorization')
    console.log('Auth header present:', !!authHeader)
    
    if (!authHeader) {
      throw new Error('Authorization header missing')
    }

    const token = authHeader.replace('Bearer ', '')
    const { data, error: authError } = await supabaseClient.auth.getUser(token)
    
    if (authError) {
      console.error('Auth error:', authError)
      throw new Error(`Authentication failed: ${authError.message}`)
    }

    const user = data.user
    console.log('User found:', !!user, user?.email)

    if (!user?.email) {
      throw new Error('User not found or no email')
    }

    const requestBody = await req.json()
    console.log('Request body:', requestBody)
    
    const { subscription_id } = requestBody

    if (!subscription_id) {
      throw new Error('Subscription ID is required')
    }

    // Initialize Stripe
    const stripe = new Stripe(stripeKey, {
      apiVersion: '2023-10-16',
    })

    console.log(`🔄 Reactivating subscription ${subscription_id} for user ${user.email}`)

    // Get current subscription details
    const currentSubscription = await stripe.subscriptions.retrieve(subscription_id)
    console.log('Current subscription status:', currentSubscription.status)
    console.log('Current period end:', currentSubscription.current_period_end)
    console.log('Cancel at period end:', currentSubscription.cancel_at_period_end)

    if (!currentSubscription.cancel_at_period_end) {
      console.log('⚠️ Subscription is not marked for cancellation, but proceeding with reactivation')
      // Don't throw error, just proceed - user might have already reactivated via Stripe
    }

    // Calculate remaining time credit
    const now = Math.floor(Date.now() / 1000)
    const remainingSeconds = Math.max(0, currentSubscription.current_period_end - now)
    const remainingDays = Math.ceil(remainingSeconds / (24 * 60 * 60))
    
    console.log(`⏰ Remaining time: ${remainingDays} days (${remainingSeconds} seconds)`)

    // Reactivate the subscription (remove cancel_at_period_end)
    const reactivatedSubscription = await stripe.subscriptions.update(subscription_id, {
      cancel_at_period_end: false,
    })

    console.log(`✅ Subscription ${subscription_id} reactivated`)

    // If there's significant remaining time, extend the next billing period
    if (remainingDays > 0) {
      // Calculate new period end (current period end + remaining time)
      const newPeriodEnd = currentSubscription.current_period_end + remainingSeconds
      
      console.log(`🎁 Adding ${remainingDays} days credit to next billing period`)
      console.log(`New period will end: ${new Date(newPeriodEnd * 1000).toISOString()}`)
      
      // Update the subscription to extend the period
      await stripe.subscriptions.update(subscription_id, {
        proration_behavior: 'none', // Don't prorate
        trial_end: newPeriodEnd, // Extend current period
      })
    }

    // Update the subscription status in our database
    const { error: updateError } = await supabaseAdmin
      .from('stripe_subscriptions')
      .update({ 
        status: 'active',
        cancel_at_period_end: false
      })
      .eq('subscription_id', subscription_id)

    if (updateError) {
      console.error('❌ Error updating subscription in database:', updateError)
      throw updateError
    }

    // Update trial status back to converted_to_paid
    const { error: trialUpdateError } = await supabaseAdmin
      .from('user_trials')
      .update({ 
        deletion_scheduled_at: null,
        trial_status: 'converted_to_paid'
      })
      .eq('user_id', user.id)

    if (trialUpdateError) {
      console.error('❌ Error updating trial status:', trialUpdateError)
      // Don't throw here as the subscription is already reactivated
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Subscription reactivated successfully',
        credit_applied: remainingDays,
        subscription: {
          id: subscription_id,
          status: 'active',
          current_period_end: reactivatedSubscription.current_period_end
        }
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('❌ Error in reactivate-subscription function:', error)
    return new Response(
      JSON.stringify({
        error: error.message,
        success: false
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
