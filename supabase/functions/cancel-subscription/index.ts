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
    console.log('🔄 Starting cancel-subscription function...')

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

    console.log(`🔄 Canceling subscription ${subscription_id} for user ${user.email}`)

    // Cancel the subscription at period end
    const canceledSubscription = await stripe.subscriptions.update(subscription_id, {
      cancel_at_period_end: true,
    })

    console.log(`✅ Subscription ${subscription_id} will be canceled at period end:`, canceledSubscription.current_period_end)

    // Update the subscription status in our database
    const { error: updateError } = await supabaseAdmin
      .from('stripe_subscriptions')
      .update({
        status: 'canceled',
        cancel_at_period_end: true
      })
      .eq('subscription_id', subscription_id)

    if (updateError) {
      console.error('❌ Error updating subscription in database:', updateError)
      throw updateError
    }

    // Schedule account deletion for 24 hours AFTER the billing period ends (grace period)
    const subscriptionEndDate = new Date(canceledSubscription.current_period_end * 1000)
    const deletionDate = new Date(subscriptionEndDate.getTime() + (24 * 60 * 60 * 1000)) // Add 24 hours

    console.log(`📅 Subscription ends: ${subscriptionEndDate.toISOString()}`)
    console.log(`🗑️ Account deletion scheduled: ${deletionDate.toISOString()} (24h grace period)`)

    const { error: trialUpdateError } = await supabaseAdmin
      .from('user_trials')
      .update({
        deletion_scheduled_at: deletionDate.toISOString(),
        trial_status: 'canceled'
      })
      .eq('user_id', user.id)

    if (trialUpdateError) {
      console.error('❌ Error scheduling account deletion:', trialUpdateError)
      // Don't throw here as the subscription is already canceled
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Subscription canceled successfully',
        cancellation_effective_date: deletionDate.toISOString(),
        subscription: {
          id: subscription_id,
          status: 'canceled',
          current_period_end: canceledSubscription.current_period_end
        }
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('❌ Error in cancel-subscription function:', error)
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
