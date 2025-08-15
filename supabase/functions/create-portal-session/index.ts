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
    console.log('🔄 Starting create-portal-session function...')

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

    // Get customer ID from our database
    const { data: customerData, error: customerError } = await supabaseAdmin
      .from('stripe_customers')
      .select('customer_id')
      .eq('user_id', user.id)
      .single()

    if (customerError || !customerData?.customer_id) {
      throw new Error('Customer not found')
    }

    // Initialize Stripe
    const stripe = new Stripe(stripeKey, {
      apiVersion: '2023-10-16',
    })

    console.log(`🔄 Creating portal session for customer ${customerData.customer_id}`)

    try {
      // First, try to create a portal configuration if none exists
      const configurations = await stripe.billingPortal.configurations.list({ limit: 1 });

      let configId = null;
      if (configurations.data.length === 0) {
        console.log('🔧 Creating default portal configuration...');
        const config = await stripe.billingPortal.configurations.create({
          business_profile: {
            headline: 'Axie Studio - Manage Your Subscription'
          },
          features: {
            subscription_cancel: {
              enabled: true,
              mode: 'at_period_end'
            },
            subscription_update: {
              enabled: true,
              default_allowed_updates: ['price']
            },
            payment_method_update: {
              enabled: true
            },
            invoice_history: {
              enabled: true
            }
          }
        });
        configId = config.id;
        console.log('✅ Created portal configuration:', configId);
      } else {
        configId = configurations.data[0].id;
        console.log('✅ Using existing portal configuration:', configId);
      }

      // Create portal session
      const session = await stripe.billingPortal.sessions.create({
        customer: customerData.customer_id,
        return_url: 'https://authr.axiestudio.se/dashboard',
        configuration: configId
      });

      console.log(`✅ Portal session created: ${session.url}`);

      return new Response(
        JSON.stringify({
          success: true,
          portal_url: session.url
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      );

    } catch (configError) {
      console.log('⚠️ Portal configuration failed, trying without config:', configError.message);

      // Fallback: create session without configuration
      const session = await stripe.billingPortal.sessions.create({
        customer: customerData.customer_id,
        return_url: 'https://authr.axiestudio.se/dashboard'
      });

      console.log(`✅ Fallback portal session created: ${session.url}`);

      return new Response(
        JSON.stringify({
          success: true,
          portal_url: session.url
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      );
    }

  } catch (error) {
    console.error('❌ Error creating portal session:', error)
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
