/// <reference types="https://esm.sh/@supabase/functions-js/src/edge-runtime.d.ts" />

/**
 * 🛍️ GET PRODUCT CONFIGURATION
 * 
 * Returns product configuration from Supabase Edge Secrets
 * This allows us to store sensitive product IDs securely
 */

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-client-info, apikey',
};

Deno.serve(async (req) => {
  console.log('🛍️ Get Product Config API called');

  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  // Only allow GET requests
  if (req.method !== 'GET') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  try {
    console.log('📋 Fetching product configuration from secrets...');

    // Get product configuration from environment secrets
    const productConfig = {
      limited_time: {
        product_id: Deno.env.get('STRIPE_LIMITED_TIME_PRODUCT_ID'),
        price_id: Deno.env.get('STRIPE_LIMITED_TIME_PRICE_ID'),
      },
      pro: {
        product_id: Deno.env.get('STRIPE_PRO_PRODUCT_ID'),
        price_id: Deno.env.get('STRIPE_PRO_PRICE_ID'),
      }
    };

    console.log('✅ Product configuration retrieved successfully');

    const response = {
      success: true,
      message: 'Product configuration retrieved',
      config: productConfig
    };

    return new Response(
      JSON.stringify(response),
      { 
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );

  } catch (error) {
    console.error('❌ Error fetching product config:', error);
    
    const errorResponse = {
      success: false,
      message: 'Error fetching product configuration',
      error: error instanceof Error ? error.message : 'Unknown error'
    };
    
    return new Response(
      JSON.stringify(errorResponse),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );
  }
});
