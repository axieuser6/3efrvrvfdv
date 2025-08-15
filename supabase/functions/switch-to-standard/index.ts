import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Get user from auth header
    const authHeader = req.headers.get('Authorization')!
    const token = authHeader.replace('Bearer ', '')
    const { data, error } = await supabaseAdmin.auth.getUser(token)

    if (error || !data?.user) {
      throw new Error('Unauthorized')
    }

    const user = data.user
    console.log('🔄 Switching user to Standard tier:', user.email)

    const requestBody = await req.json()
    const { user_action } = requestBody

    console.log('📋 Switch action:', user_action)

    // Update user's trial status to 'standard' (paused state)
    const { error: trialUpdateError } = await supabaseAdmin
      .from('user_trials')
      .update({
        trial_status: 'standard', // Standard tier = paused account
        updated_at: new Date().toISOString()
      })
      .eq('user_id', user.id)

    if (trialUpdateError) {
      console.error('❌ Error updating trial status:', trialUpdateError)
      throw new Error('Failed to update account status')
    }

    // Update user account state to reflect Standard tier
    const { error: accountStateError } = await supabaseAdmin
      .from('user_account_state')
      .upsert({
        user_id: user.id,
        account_status: 'standard',
        has_access: false, // Standard tier has no access to premium features
        access_level: 'standard',
        subscription_status: 'standard'
      })
      .eq('user_id', user.id)

    if (accountStateError) {
      console.error('❌ Error updating account state:', accountStateError)
      // Don't throw here as trial update succeeded
    }

    // Deactivate AxieStudio account for Standard tier users
    try {
      const { data: axieResponse, error: axieError } = await supabaseAdmin.functions.invoke('axie-studio-account', {
        body: {
          action: 'deactivate',
          user_id: user.id,
          reason: 'switched_to_standard_tier'
        }
      })

      if (axieError) {
        console.warn('⚠️ Could not deactivate AxieStudio account:', axieError)
      } else {
        console.log('✅ AxieStudio account deactivated for Standard tier')
      }
    } catch (axieError) {
      console.warn('⚠️ AxieStudio deactivation failed:', axieError)
      // Don't throw - this is not critical for the main operation
    }

    console.log('✅ Successfully switched user to Standard tier')

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Successfully switched to Standard tier',
        new_status: 'standard',
        access_level: 'standard',
        has_access: false
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('❌ Error in switch-to-standard function:', error)
    
    return new Response(
      JSON.stringify({
        error: error.message || 'Internal server error',
        success: false
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})