import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'npm:@supabase/supabase-js@2.49.1';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

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

    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
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

    const { user_id } = await req.json();

    // SECURITY: Ensure user can only start trial for their own account
    if (user_id !== user.id) {
      return new Response(
        JSON.stringify({ error: 'You can only start trial for your own account' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    console.log(`🎁 Starting 7-day free trial for user: ${user.email}`);

    // Check if user already has an active trial
    const { data: existingTrial } = await supabase
      .from('user_trials')
      .select('trial_status, trial_end_date')
      .eq('user_id', user_id)
      .maybeSingle();

    if (existingTrial?.trial_status === 'active') {
      const trialEndDate = new Date(existingTrial.trial_end_date);
      if (trialEndDate > new Date()) {
        return new Response(
          JSON.stringify({ 
            error: 'You already have an active trial',
            trial_end_date: existingTrial.trial_end_date
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // Check if user has already used their trial
    const { data: trialHistory } = await supabase.rpc('check_email_trial_history', {
      p_email: user.email!
    });

    if (trialHistory && trialHistory.length > 0 && trialHistory[0].has_used_trial) {
      return new Response(
        JSON.stringify({ 
          error: 'You have already used your free trial. Please subscribe to continue.',
          requires_subscription: true
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Start the trial by updating user records
    const trialStartDate = new Date();
    const trialEndDate = new Date(trialStartDate.getTime() + (7 * 24 * 60 * 60 * 1000)); // 7 days

    // Update user_trials table
    const { error: trialError } = await supabase
      .from('user_trials')
      .upsert({
        user_id: user_id,
        trial_start_date: trialStartDate.toISOString(),
        trial_end_date: trialEndDate.toISOString(),
        trial_status: 'active',
        updated_at: new Date().toISOString()
      });

    if (trialError) {
      console.error('❌ Error updating trial:', trialError);
      throw new Error('Failed to activate trial');
    }

    // Update user_account_state table
    const { error: accountError } = await supabase
      .from('user_account_state')
      .upsert({
        user_id: user_id,
        account_status: 'trial_active',
        has_access: true,
        access_level: 'trial',
        trial_start_date: trialStartDate.toISOString(),
        trial_end_date: trialEndDate.toISOString(),
        trial_days_remaining: 7,
        updated_at: new Date().toISOString()
      });

    if (accountError) {
      console.error('❌ Error updating account state:', accountError);
      throw new Error('Failed to update account status');
    }

    console.log('✅ 7-day free trial activated successfully');

    return new Response(
      JSON.stringify({
        success: true,
        message: '7-day free trial activated successfully!',
        trial_start_date: trialStartDate.toISOString(),
        trial_end_date: trialEndDate.toISOString(),
        days_remaining: 7
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('❌ Start trial error:', error);
    return new Response(
      JSON.stringify({ 
        error: error.message || 'Failed to start trial',
        success: false
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});