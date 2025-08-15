/// <reference types="https://esm.sh/@supabase/functions-js/src/edge-runtime.d.ts" />

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

/**
 * 🔄 UPDATE AXIESTUDIO STATUS
 * 
 * Updates AxieStudio account active status based on user's subscription/trial status
 * Called when subscription status changes or trials expire
 */

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-client-info, apikey',
};

// Initialize Supabase client
const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

async function updateAxieStudioAccountStatus(userId: string, shouldBeActive: boolean): Promise<void> {
  console.log(`🔄 Updating AxieStudio status for user ${userId} to active: ${shouldBeActive}`);

  // Get user email and AxieStudio account info
  const { data: userProfile } = await supabase
    .from('user_profiles')
    .select('email')
    .eq('id', userId)
    .single();

  if (!userProfile?.email) {
    throw new Error(`User profile not found for ${userId}`);
  }

  const { data: axieAccount } = await supabase
    .from('axiestudio_accounts')
    .select('*')
    .eq('user_id', userId)
    .single();

  if (!axieAccount) {
    console.log(`⚠️ No AxieStudio account found for user ${userId}`);
    return;
  }

  // Get AxieStudio credentials
  const AXIESTUDIO_APP_URL = Deno.env.get('AXIESTUDIO_APP_URL');
  const AXIESTUDIO_USERNAME = Deno.env.get('AXIESTUDIO_USERNAME');
  const AXIESTUDIO_PASSWORD = Deno.env.get('AXIESTUDIO_PASSWORD');

  if (!AXIESTUDIO_APP_URL || !AXIESTUDIO_USERNAME || !AXIESTUDIO_PASSWORD) {
    throw new Error('Missing AxieStudio configuration');
  }

  // Login to AxieStudio to get admin token
  const loginResponse = await fetch(`${AXIESTUDIO_APP_URL}/api/v1/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      username: AXIESTUDIO_USERNAME,
      password: AXIESTUDIO_PASSWORD
    })
  });

  if (!loginResponse.ok) {
    throw new Error(`AxieStudio login failed: ${loginResponse.status}`);
  }

  const { access_token } = await loginResponse.json();

  // Create API key
  const apiKeyResponse = await fetch(`${AXIESTUDIO_APP_URL}/api/v1/api_key/`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${access_token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ name: 'Status Update API Key' })
  });

  if (!apiKeyResponse.ok) {
    throw new Error(`API key creation failed: ${apiKeyResponse.status}`);
  }

  const { api_key } = await apiKeyResponse.json();

  // Update user status in AxieStudio
  const updateResponse = await fetch(`${AXIESTUDIO_APP_URL}/api/v1/users/${axieAccount.axiestudio_user_id}`, {
    method: 'PATCH',
    headers: {
      'x-api-key': api_key,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      is_active: shouldBeActive
    })
  });

  if (!updateResponse.ok) {
    throw new Error(`Failed to update AxieStudio user status: ${updateResponse.status}`);
  }

  // Update our database record
  await supabase
    .from('axiestudio_accounts')
    .update({ 
      is_active: shouldBeActive,
      updated_at: new Date().toISOString()
    })
    .eq('user_id', userId);

  console.log(`✅ AxieStudio account status updated successfully for ${userProfile.email}`);
}

Deno.serve(async (req) => {
  console.log('🔄 Update AxieStudio Status API called');

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
    const body = await req.json();
    const { user_id, should_be_active } = body;

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: 'user_id is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    await updateAxieStudioAccountStatus(user_id, should_be_active ?? false);

    const response = {
      success: true,
      message: 'AxieStudio account status updated successfully',
      user_id,
      active_status: should_be_active ?? false
    };

    return new Response(
      JSON.stringify(response),
      { 
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );

  } catch (error) {
    console.error('❌ Error updating AxieStudio status:', error);
    
    const errorResponse = {
      success: false,
      message: 'Error updating AxieStudio account status',
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
