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

interface AccessControlResult {
  has_access: boolean;
  access_type: 'paid_subscription' | 'stripe_trial' | 'free_trial' | 'no_access';
  can_create_axiestudio_account: boolean;
  subscription_status: string | null;
  trial_status: string | null;
  is_expired_trial_user: boolean;
  is_returning_user: boolean;
  requires_subscription: boolean;
  protection_level: 'protected' | 'trial' | 'expired' | 'none';
  verification_timestamp: string;
}

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

    console.log(`🔒 Enhanced access control check for user: ${user.email}`);

    // STEP 1: Get comprehensive user data
    const { data: accessData, error: accessError } = await supabase.rpc('get_user_access_level', {
      p_user_id: user.id
    });

    if (accessError) {
      console.error('❌ Access check failed:', accessError);
      return new Response(
        JSON.stringify({ error: 'Access verification failed' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const userAccess = accessData?.[0];

    // STEP 2: Get subscription data
    const { data: subscriptionData } = await supabase
      .from('stripe_user_subscriptions')
      .select('*')
      .eq('user_id', user.id)
      .maybeSingle();

    // STEP 3: Check if user is returning (has deletion history)
    const { data: deletionHistory } = await supabase.rpc('check_email_trial_history', {
      p_email: user.email!
    });

    const isReturningUser = deletionHistory && deletionHistory.length > 0 && deletionHistory[0].has_used_trial;

    // STEP 4: BULLETPROOF ACCESS DETERMINATION
    const hasActiveSubscription = subscriptionData?.subscription_status === 'active';
    const hasTrialingSubscription = subscriptionData?.subscription_status === 'trialing';
    const isSubscriptionCancelled = subscriptionData?.cancel_at_period_end === true;
    const hasActiveTrial = userAccess?.trial_status === 'active' && userAccess?.days_remaining > 0;
    const isExpiredTrialUser = userAccess?.trial_status === 'expired' || 
                              userAccess?.trial_status === 'scheduled_for_deletion';

    // SECURITY: Determine final access
    let finalHasAccess = false;
    let finalAccessType: AccessControlResult['access_type'] = 'no_access';
    let canCreateAxieStudioAccount = false;
    let protectionLevel: AccessControlResult['protection_level'] = 'none';

    // Priority 1: Active paid subscription (highest access)
    if (hasActiveSubscription && !isSubscriptionCancelled) {
      finalHasAccess = true;
      finalAccessType = 'paid_subscription';
      canCreateAxieStudioAccount = true;
      protectionLevel = 'protected';
    }
    // Priority 2: Cancelled subscription (access until period ends)
    else if (hasActiveSubscription && isSubscriptionCancelled) {
      finalHasAccess = true;
      finalAccessType = 'paid_subscription';
      canCreateAxieStudioAccount = true; // Still can create until period ends
      protectionLevel = 'protected';
    }
    // Priority 3: Trialing subscription
    else if (hasTrialingSubscription) {
      finalHasAccess = true;
      finalAccessType = 'stripe_trial';
      canCreateAxieStudioAccount = true;
      protectionLevel = 'trial';
    }
    // Priority 4: Active free trial (only for NEW users)
    else if (hasActiveTrial && !isReturningUser) {
      finalHasAccess = true;
      finalAccessType = 'free_trial';
      canCreateAxieStudioAccount = true;
      protectionLevel = 'trial';
    }
    // Priority 5: Returning users with expired trial (BLOCKED)
    else if (isReturningUser && isExpiredTrialUser) {
      finalHasAccess = false; // Basic app access only
      finalAccessType = 'no_access';
      canCreateAxieStudioAccount = false; // BLOCKED from AxieStudio
      protectionLevel = 'expired';
    }

    const result: AccessControlResult = {
      has_access: finalHasAccess,
      access_type: finalAccessType,
      can_create_axiestudio_account: canCreateAxieStudioAccount,
      subscription_status: subscriptionData?.subscription_status || null,
      trial_status: userAccess?.trial_status || null,
      is_expired_trial_user: isExpiredTrialUser,
      is_returning_user: isReturningUser,
      requires_subscription: isReturningUser && isExpiredTrialUser,
      protection_level: protectionLevel,
      verification_timestamp: new Date().toISOString()
    };

    console.log('🔒 Enhanced access control result:', result);

    return new Response(
      JSON.stringify({
        success: true,
        access_control: result,
        user_id: user.id,
        email: user.email
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error: any) {
    console.error('❌ Enhanced access control error:', error);
    return new Response(
      JSON.stringify({ error: 'Access control verification failed' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});