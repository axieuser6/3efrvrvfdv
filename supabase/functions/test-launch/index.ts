/// <reference types="https://esm.sh/@supabase/functions-js/src/edge-runtime.d.ts" />

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-client-info, apikey',
};

Deno.serve(async (req) => {
  console.log('🧪 Test Launch API called');

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
    console.log('📥 Parsing request body...');
    const body = await req.json();
    console.log('📋 Request data:', body);

    // Get AxieStudio URL
    const axiestudioUrl = Deno.env.get('AXIESTUDIO_APP_URL') || 'https://flow.axiestudio.se';
    console.log('🔍 AxieStudio URL:', axiestudioUrl);

    // Simple redirect to login page
    const loginUrl = `${axiestudioUrl}/login`;

    const response = {
      success: true,
      message: 'Redirecting to AxieStudio login page',
      redirect_url: loginUrl,
      fallback_url: loginUrl
    };

    console.log('✅ Redirecting user to:', loginUrl);

    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );

  } catch (error) {
    console.error('❌ Test function error:', error);
    
    const errorResponse = {
      success: false,
      message: 'Test function error',
      error: error instanceof Error ? error.message : 'Unknown error',
      fallback_url: 'https://flow.axiestudio.se/login'
    };

    console.log('📤 Sending error response:', errorResponse);
    
    return new Response(
      JSON.stringify(errorResponse),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );
  }
});
