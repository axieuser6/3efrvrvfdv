import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'npm:@supabase/supabase-js@2.49.1';

// Validate required environment variables
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY');
const AXIESTUDIO_APP_URL = Deno.env.get('AXIESTUDIO_APP_URL');

if (!AXIESTUDIO_APP_URL) {
  throw new Error('AXIESTUDIO_APP_URL environment variable is required');
}

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !SUPABASE_ANON_KEY) {
  throw new Error('Missing required environment variables: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY');
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

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
    // SECURITY: Verify the user is authenticated
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ error: 'Authorization header required' }),
        { 
          status: 401, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    const token = authHeader.replace('Bearer ', '');
    
    // Create a client with the user's token to verify authentication
    const userSupabase = createClient(
      SUPABASE_URL,
      SUPABASE_ANON_KEY,
      {
        global: {
          headers: {
            Authorization: authHeader,
          },
        },
      }
    );

    // Verify the user is authenticated
    const { data: { user: authenticatedUser }, error: authError } = await userSupabase.auth.getUser(token);
    
    if (authError || !authenticatedUser) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        { 
          status: 401, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    console.log(`🚀 Starting AxieStudio auto-login for user: ${authenticatedUser.email}`);

    // Step 1: Get user's AxieStudio credentials from our database
    const { data: userProfile } = await supabase
      .from('user_profiles')
      .select('email')
      .eq('id', authenticatedUser.id)
      .single();

    if (!userProfile) {
      return new Response(
        JSON.stringify({ error: 'User profile not found' }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    const userEmail = userProfile.email || authenticatedUser.email;

    // Step 2: Get user's AxieStudio credentials from our database
    console.log(`🔐 Getting AxieStudio credentials for: ${userEmail}`);

    const { data: credentialsData } = await supabase
      .from('axie_studio_credentials')
      .select('axie_studio_email, axie_studio_password')
      .eq('user_id', authenticatedUser.id)
      .single();

    if (!credentialsData) {
      console.log('⚠️ No AxieStudio credentials found, redirecting to login');
      const loginUrl = `${AXIESTUDIO_APP_URL}/login`;

      return new Response(
        JSON.stringify({
          success: true,
          redirect_url: loginUrl,
          message: 'No AxieStudio account found. Please create an account first.',
          auto_login_available: false
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Step 3: Login to AxieStudio with user's specific credentials
    console.log(`🔐 Logging into AxieStudio with user credentials: ${credentialsData.email}`);

    try {
      const loginResponse = await fetch(`${AXIESTUDIO_APP_URL}/api/v1/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          username: credentialsData.axie_studio_email,
          password: credentialsData.axie_studio_password
        })
      });

      if (loginResponse.ok) {
        const loginData = await loginResponse.json();
        console.log('✅ AxieStudio login successful for user:', credentialsData.axie_studio_email);

        // Step 4: Extract cookies from the response
        const setCookieHeaders = loginResponse.headers.get('set-cookie');

        // Step 5: Create authenticated redirect URL
        // Since we can't forward cookies across domains, we'll include the access token
        // in the URL so AxieStudio can authenticate the user
        const redirectUrl = new URL(`${AXIESTUDIO_APP_URL}/flows`);

        // Add access token to URL for authentication
        if (loginData.access_token) {
          redirectUrl.searchParams.set('access_token', loginData.access_token);
        }

        // Update last login time
        await supabase
          .from('axie_studio_credentials')
          .update({ last_login_at: new Date().toISOString() })
          .eq('user_id', authenticatedUser.id);

        return new Response(
          JSON.stringify({
            success: true,
            redirect_url: redirectUrl.toString(),
            message: 'Auto-login successful - redirecting with authentication token',
            user_email: credentialsData.axie_studio_email,
            access_token: loginData.access_token,
            token_type: loginData.token_type || 'bearer'
          }),
          {
            status: 200,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json'
            }
          }
        );
      } else {
        const errorText = await loginResponse.text();
        console.error('❌ AxieStudio login failed:', errorText);

        // Login failed, redirect to manual login
        const loginUrl = `${AXIESTUDIO_APP_URL}/login`;

        return new Response(
          JSON.stringify({
            success: true,
            redirect_url: loginUrl,
            message: 'AxieStudio login failed. Please login manually.',
            auto_login_available: false
          }),
          {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        );
      }
    } catch (axieError) {
      console.error('❌ AxieStudio connection failed:', axieError);

      // Fallback: redirect to login page
      const loginUrl = `${AXIESTUDIO_APP_URL}/login`;

      return new Response(
        JSON.stringify({
          success: true,
          redirect_url: loginUrl,
          message: 'Connection to AxieStudio failed. Please try again.',
          auto_login_available: false
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

  } catch (error) {
    console.error('❌ Auto-login function failed:', error);
    
    // SECURITY: Sanitize error response
    const sanitizedError = error instanceof Error 
      ? (error.message.includes('auth') || error.message.includes('token') 
         ? 'Authentication error occurred' 
         : 'Internal server error occurred')
      : 'Unknown error occurred';
    
    return new Response(
      JSON.stringify({ 
        error: 'Failed to process auto-login request',
        code: 'AUTO_LOGIN_FAILED',
        message: sanitizedError,
        timestamp: new Date().toISOString()
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );
  }
});
