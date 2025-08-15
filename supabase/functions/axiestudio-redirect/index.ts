/// <reference types="https://esm.sh/@supabase/functions-js/src/edge-runtime.d.ts" />

/**
 * 🚀 AXIESTUDIO REDIRECT FUNCTION
 * 
 * Simple function that redirects users to the AxieStudio login page.
 * No complex logic, no database operations, just a clean redirect.
 */

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-client-info, apikey',
};

Deno.serve(async (req) => {
  console.log('🚀 AxieStudio Redirect API called');

  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  // Only allow POST requests
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  try {
    console.log('📥 Processing redirect request...');
    
    // Get AxieStudio URL from environment
    const axiestudioUrl = Deno.env.get('AXIESTUDIO_APP_URL') || 'https://flow.axiestudio.se';
    const loginUrl = `${axiestudioUrl}/login`;
    
    console.log('🔗 Redirecting to AxieStudio login:', loginUrl);

    // Simple successful response with redirect URL
    const response = {
      success: true,
      message: 'Redirecting to AxieStudio login page',
      redirect_url: loginUrl,
      fallback_url: loginUrl
    };

    return new Response(
      JSON.stringify(response),
      { 
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );

  } catch (error) {
    console.error('❌ Redirect function error:', error);
    
    // Fallback response
    const errorResponse = {
      success: false,
      message: 'Error occurred, falling back to manual redirect',
      fallback_url: 'https://flow.axiestudio.se/login',
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
