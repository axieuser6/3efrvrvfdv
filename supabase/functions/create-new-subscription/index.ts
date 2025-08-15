import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import Stripe from 'npm:stripe@17.7.0';
import { createClient } from 'npm:@supabase/supabase-js@2.49.1';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

const stripeSecret = Deno.env.get('STRIPE_SECRET_KEY')!;

if (!stripeSecret) {
  throw new Error('Missing STRIPE_SECRET_KEY environment variable');
}

const stripe = new Stripe(stripeSecret, {
  appInfo: {
    name: 'Axie Studio Production',
    version: '1.0.0',
  },
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

Deno.serve(async (req) => {
  try {
    if (req.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // SECURITY: Verify authentication
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ error: 'Authorization required' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid authentication' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const { price_id } = await req.json();

    if (!price_id) {
      return new Response(
        JSON.stringify({ error: 'Price ID required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`🔄 Creating NEW subscription for user: ${user.email}`);

    // SECURITY CHECK: Verify user can resubscribe
    const { data: accessData, error: accessError } = await supabase.rpc('get_user_access_level', {
      p_user_id: user.id
    });

    if (accessError) {
      console.error('❌ Error checking user access:', accessError);
      return new Response(
        JSON.stringify({ error: 'Unable to verify account status' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get or create Stripe customer
    let { data: customerData } = await supabase
      .from('stripe_customers')
      .select('customer_id')
      .eq('user_id', user.id)
      .is('deleted_at', null)
      .maybeSingle();

    let customerId: string;

    if (!customerData) {
      // Create new Stripe customer
      const newCustomer = await stripe.customers.create({
        email: user.email!,
        metadata: {
          userId: user.id,
          resubscribe: 'true'
        },
      });

      // Store in database
      const { error: customerError } = await supabase.from('stripe_customers').insert({
        user_id: user.id,
        customer_id: newCustomer.id,
      });

      if (customerError) {
        console.error('❌ Failed to store customer:', customerError);
        return new Response(
          JSON.stringify({ error: 'Failed to create customer record' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      customerId = newCustomer.id;
      console.log(`✅ Created new customer: ${customerId}`);
    } else {
      customerId = customerData.customer_id;
      console.log(`✅ Using existing customer: ${customerId}`);
    }

    // CRITICAL: Create NEW checkout session for NEW subscription
    const checkoutSession = await stripe.checkout.sessions.create({
      customer: customerId,
      payment_method_types: ['card'],
      line_items: [
        {
          price: price_id,
          quantity: 1,
        },
      ],
      mode: 'subscription', // NEW subscription, not reactivation
      success_url: `${Deno.env.get('FRONTEND_URL') || 'http://localhost:5173'}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${Deno.env.get('FRONTEND_URL') || 'http://localhost:5173'}/account`,
      metadata: {
        user_id: user.id,
        resubscribe: 'true',
        previous_cancellation: 'true'
      }
    });

    console.log(`✅ Created NEW subscription checkout: ${checkoutSession.id}`);

    return new Response(
      JSON.stringify({
        success: true,
        checkout_url: checkoutSession.url,
        session_id: checkoutSession.id,
        message: 'New subscription checkout created'
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('❌ Create subscription error:', error);
    return new Response(
      JSON.stringify({ error: error.message || 'Failed to create subscription' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});