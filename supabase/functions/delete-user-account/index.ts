import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'npm:@supabase/supabase-js@2.49.1';

// Validate required environment variables
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY');

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
    // SECURITY: Verify the user is authenticated and can only delete their own account
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

    const { user_id } = await req.json();

    // SECURITY: Ensure user can only delete their own account
    if (user_id !== authenticatedUser.id) {
      return new Response(
        JSON.stringify({ error: 'You can only delete your own account' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: 'User ID is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // SECURITY: Prevent deletion of super admin account
    const SUPER_ADMIN_ID = 'b8782453-a343-4301-a947-67c5bb407d2b';
    if (user_id === SUPER_ADMIN_ID) {
      return new Response(
        JSON.stringify({ error: 'Super admin account cannot be deleted' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    console.log(`🗑️ Starting immediate deletion for user: ${user_id}`);

    // STEP 1: Record deletion history FIRST (critical for abuse prevention)
    let userEmail: string | null = null;
    try {
      console.log('🔄 Recording deletion history (FIRST - critical for abuse prevention)...');

      // Get user email first
      const { data: userData } = await supabase.auth.admin.getUserById(user_id);
      userEmail = userData?.user?.email || null;

      if (userEmail) {
        await supabase.rpc('record_account_deletion', {
          p_user_id: user_id,
          p_email: userEmail,
          p_reason: 'immediate_deletion'
        });
        console.log('✅ Deletion history recorded - abuse prevention secured');
      } else {
        throw new Error('Could not retrieve user email for deletion history');
      }
    } catch (error) {
      console.error('❌ CRITICAL: Failed to record deletion history:', error);
      return new Response(
        JSON.stringify({
          error: 'Failed to record deletion history - operation aborted for security',
          code: 'HISTORY_RECORD_FAILED'
        }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // STEP 2: Comprehensive Stripe cleanup
    try {
      console.log('🔄 Starting comprehensive Stripe cleanup...');

      // Get user's Stripe customer ID
      const { data: customerData } = await supabase
        .from('stripe_customers')
        .select('customer_id')
        .eq('user_id', user_id)
        .single();

      if (customerData?.customer_id) {
        console.log(`🔄 Processing Stripe customer: ${customerData.customer_id}`);

        // 1. Cancel all active subscriptions
        const { data: subscriptions } = await supabase
          .from('stripe_subscriptions')
          .select('subscription_id, status')
          .eq('customer_id', customerData.customer_id)
          .in('status', ['active', 'trialing', 'past_due']);

        if (subscriptions && subscriptions.length > 0) {
          for (const sub of subscriptions) {
            try {
              // Mark as cancelled in our database immediately
              await supabase
                .from('stripe_subscriptions')
                .update({
                  status: 'canceled',
                  cancel_at_period_end: true,
                  canceled_at: Math.floor(Date.now() / 1000),
                  deleted_at: new Date().toISOString(),
                  updated_at: new Date().toISOString()
                })
                .eq('subscription_id', sub.subscription_id);

              console.log(`✅ Cancelled subscription: ${sub.subscription_id}`);
            } catch (subError) {
              console.warn(`⚠️ Failed to cancel subscription ${sub.subscription_id}:`, subError);
            }
          }
          console.log(`✅ Processed ${subscriptions.length} Stripe subscriptions`);
        }

        // 2. Mark customer as deleted in our database
        await supabase
          .from('stripe_customers')
          .update({
            deleted_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
          })
          .eq('customer_id', customerData.customer_id);

        console.log('✅ Stripe customer marked as deleted');
      } else {
        console.log('ℹ️ No Stripe customer found for user');
      }
    } catch (error) {
      console.warn('⚠️ Stripe cleanup failed (non-critical):', error);
      // Don't fail the entire deletion for Stripe issues
    }

    // 2. Remove user access immediately
    try {
      console.log('🔄 Removing user access...');
      
      // Mark user for immediate deletion in user_account_state
      await supabase
        .from('user_account_state')
        .update({
          account_status: 'deleted',
          has_access: false,
          access_level: 'suspended',
          trial_days_remaining: 0,
          updated_at: new Date().toISOString()
        })
        .eq('user_id', user_id);

      // Mark trial as deleted
      await supabase
        .from('user_trials')
        .update({
          trial_status: 'deleted',
          deletion_scheduled_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
        .eq('user_id', user_id);

      console.log('✅ User access removed');
    } catch (error) {
      console.warn('⚠️ Access removal failed:', error);
    }

    // STEP 4: Delete user data from all tables in correct order
    try {
      console.log('🔄 Deleting user data...');

      // Delete in correct order to respect foreign key constraints
      const deletionSteps = [
        { table: 'stripe_subscriptions', column: 'customer_id', isCustomerId: true },
        { table: 'axie_studio_accounts', column: 'user_id', isCustomerId: false },
        { table: 'axie_studio_credentials', column: 'user_id', isCustomerId: false },
        { table: 'user_account_state', column: 'user_id', isCustomerId: false },
        { table: 'stripe_customers', column: 'user_id', isCustomerId: false },
        { table: 'user_trials', column: 'user_id', isCustomerId: false },
        { table: 'user_profiles', column: 'id', isCustomerId: false }
      ];

      for (const step of deletionSteps) {
        try {
          if (step.isCustomerId) {
            // For stripe_subscriptions, we need to delete by customer_id
            const { data: customerData } = await supabase
              .from('stripe_customers')
              .select('customer_id')
              .eq('user_id', user_id);

            if (customerData && customerData.length > 0) {
              for (const customer of customerData) {
                await supabase
                  .from(step.table)
                  .delete()
                  .eq(step.column, customer.customer_id);
              }
            }
          } else {
            await supabase
              .from(step.table)
              .delete()
              .eq(step.column, user_id);
          }
          console.log(`✅ Deleted data from ${step.table}`);
        } catch (error) {
          console.warn(`⚠️ Failed to delete from ${step.table}:`, error);
        }
      }
    } catch (error) {
      console.warn('⚠️ Data deletion failed:', error);
    }

    // 4. Delete the Supabase Auth user (this will cascade delete remaining data)
    try {
      console.log('🔄 Deleting Supabase Auth user...');
      
      const { error: deleteError } = await supabase.auth.admin.deleteUser(user_id);
      
      if (deleteError) {
        console.error('❌ Auth user deletion failed:', deleteError);
        throw deleteError;
      }
      
      console.log('✅ Supabase Auth user deleted');
    } catch (error) {
      console.error('❌ Auth deletion failed:', error);
      throw error;
    }

    console.log('✅ User deletion completed successfully');

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'User account deleted successfully' 
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );

  } catch (error) {
    console.error('❌ User deletion failed:', error);

    // SECURITY: Sanitize error response - don't leak sensitive information
    const sanitizedError = error instanceof Error
      ? (error.message.includes('auth') || error.message.includes('token')
         ? 'Authentication error occurred'
         : 'Internal server error occurred')
      : 'Unknown error occurred';

    return new Response(
      JSON.stringify({
        error: 'Failed to delete user account',
        code: 'DELETION_FAILED',
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
