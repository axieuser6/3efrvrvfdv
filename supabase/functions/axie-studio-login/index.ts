import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Max-Age': '86400',
}

const AXIESTUDIO_APP_URL = Deno.env.get('AXIESTUDIO_APP_URL')

if (!AXIESTUDIO_APP_URL) {
  throw new Error('AXIESTUDIO_APP_URL environment variable is required')
}

async function getAxieStudioApiKey(): Promise<string> {
  // First try to use the direct API key from environment
  const directApiKey = Deno.env.get('AXIESTUDIO_API_KEY')
  if (directApiKey) {
    console.log('Using direct API key from environment')
    return directApiKey
  }

  // Fallback: Create new API key using login credentials
  console.log('Creating new API key using login credentials...')

  const username = Deno.env.get('AXIESTUDIO_USERNAME')
  const password = Deno.env.get('AXIESTUDIO_PASSWORD')

  if (!username || !password) {
    throw new Error('AXIESTUDIO credentials not found in environment variables')
  }

  // Step 1: Login to get JWT token
  const loginBody = new URLSearchParams({
    username: username,
    password: password
  })

  const loginResponse = await fetch(`${AXIESTUDIO_APP_URL}/api/v1/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: loginBody
  })

  if (!loginResponse.ok) {
    throw new Error(`Login failed: ${loginResponse.status}`)
  }

  const loginData = await loginResponse.json()
  const accessToken = loginData.access_token

  if (!accessToken) {
    throw new Error('No access token received from login')
  }

  // Step 2: Create API key using JWT token
  const apiKeyResponse = await fetch(`${AXIESTUDIO_APP_URL}/api/v1/api_key/`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      name: `Auto-Login API Key ${new Date().toISOString()}`
    })
  })

  if (!apiKeyResponse.ok) {
    throw new Error(`API key creation failed: ${apiKeyResponse.status}`)
  }

  const apiKeyData = await apiKeyResponse.json()

  if (!apiKeyData.api_key) {
    throw new Error('No API key received from creation endpoint')
  }

  console.log('Successfully created new API key')
  return apiKeyData.api_key
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get the authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('No authorization header')
    }

    // Verify the user
    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    
    if (authError || !user) {
      throw new Error('Invalid token')
    }

    console.log(`🔐 Auto-login request for user: ${user.email}`)

    // Use the user's email as AxieStudio email (since we create accounts with same email)
    const axie_studio_email = user.email

    if (!axie_studio_email) {
      throw new Error('User email not found')
    }

    console.log(`📧 Using user email for AxieStudio login: ${axie_studio_email}`)

    // Try to get stored credentials first, if not available, use admin credentials to get user info
    let axie_studio_password: string | null = null

    try {
      const { data: credentials, error: credError } = await supabase
        .rpc('get_axie_studio_credentials', { p_user_id: user.id })

      if (!credError && credentials && credentials.length > 0) {
        axie_studio_password = credentials[0].axie_studio_password
        console.log('✅ Found stored credentials')
      }
    } catch (error) {
      console.log('ℹ️ No stored credentials found, will try direct login')
    }

    // If no stored password, use a predictable pattern based on user ID
    if (!axie_studio_password) {
      console.log('🔍 No stored password, using generated pattern...')

      // Generate password using user ID (same pattern as account creation)
      axie_studio_password = `AxieStudio${user.id.slice(0, 8)}!`
      console.log('✅ Using generated password pattern')
    }

    // Ensure we have a password before attempting login
    if (!axie_studio_password) {
      throw new Error('No AxieStudio password available for login')
    }

    // Login to AxieStudio to get session token
    const loginResponse = await fetch(`${AXIESTUDIO_APP_URL}/api/v1/login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        username: axie_studio_email,
        password: axie_studio_password
      })
    })

    if (!loginResponse.ok) {
      throw new Error(`AxieStudio login failed: ${loginResponse.status}`)
    }

    const loginData = await loginResponse.json()
    const accessToken = loginData.access_token

    console.log(`✅ AxieStudio login successful`)

    // Update last login time
    await supabase
      .from('axie_studio_credentials')
      .update({ last_login_at: new Date().toISOString() })
      .eq('user_id', user.id)

    // Return the auto-login URL with token
    const autoLoginUrl = `${AXIESTUDIO_APP_URL}/auto-login?token=${accessToken}`

    return new Response(
      JSON.stringify({
        success: true,
        auto_login_url: autoLoginUrl,
        flows_url: `${autoLoginUrl}&redirect=/flows`,
        message: 'Auto-login URL generated successfully'
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )

  } catch (error: any) {
    console.error('❌ Auto-login error:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      { 
        status: 400, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
