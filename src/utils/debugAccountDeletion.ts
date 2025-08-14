import { supabase } from '../lib/supabase';

export interface DeletionDebugInfo {
  userId: string;
  email: string;
  hasSupabaseAuth: boolean;
  hasUserProfile: boolean;
  hasUserTrial: boolean;
  hasAccountState: boolean;
  hasStripeCustomer: boolean;
  hasAxieCredentials: boolean;
  isProtected: boolean;
  protectionReason?: string;
  errors: string[];
}

/**
 * Debug account deletion issues
 */
export async function debugAccountDeletion(userId: string): Promise<DeletionDebugInfo> {
  const debug: DeletionDebugInfo = {
    userId,
    email: '',
    hasSupabaseAuth: false,
    hasUserProfile: false,
    hasUserTrial: false,
    hasAccountState: false,
    hasStripeCustomer: false,
    hasAxieCredentials: false,
    isProtected: false,
    errors: []
  };

  try {
    // Check Supabase Auth user
    const { data: authUser, error: authError } = await supabase.auth.admin.getUserById(userId);
    if (authError) {
      debug.errors.push(`Auth user check failed: ${authError.message}`);
    } else if (authUser?.user) {
      debug.hasSupabaseAuth = true;
      debug.email = authUser.user.email || '';
    }

    // Check user_profiles table
    const { data: profile, error: profileError } = await supabase
      .from('user_profiles')
      .select('id')
      .eq('id', userId)
      .maybeSingle();
    
    if (profileError) {
      debug.errors.push(`Profile check failed: ${profileError.message}`);
    } else if (profile) {
      debug.hasUserProfile = true;
    }

    // Check user_trials table
    const { data: trial, error: trialError } = await supabase
      .from('user_trials')
      .select('user_id, trial_status')
      .eq('user_id', userId)
      .maybeSingle();
    
    if (trialError) {
      debug.errors.push(`Trial check failed: ${trialError.message}`);
    } else if (trial) {
      debug.hasUserTrial = true;
    }

    // Check user_account_state table
    const { data: accountState, error: accountError } = await supabase
      .from('user_account_state')
      .select('user_id, account_status')
      .eq('user_id', userId)
      .maybeSingle();
    
    if (accountError) {
      debug.errors.push(`Account state check failed: ${accountError.message}`);
    } else if (accountState) {
      debug.hasAccountState = true;
    }

    // Check stripe_customers table
    const { data: customer, error: customerError } = await supabase
      .from('stripe_customers')
      .select('customer_id')
      .eq('user_id', userId)
      .maybeSingle();
    
    if (customerError) {
      debug.errors.push(`Stripe customer check failed: ${customerError.message}`);
    } else if (customer) {
      debug.hasStripeCustomer = true;
    }

    // Check axie_studio_credentials table
    const { data: credentials, error: credError } = await supabase
      .from('axie_studio_credentials')
      .select('user_id')
      .eq('user_id', userId)
      .maybeSingle();
    
    if (credError) {
      debug.errors.push(`Axie credentials check failed: ${credError.message}`);
    } else if (credentials) {
      debug.hasAxieCredentials = true;
    }

    // Check if user is protected from deletion
    try {
      const { data: protection, error: protectionError } = await supabase.rpc('verify_user_protection', {
        p_user_id: userId
      });

      if (protectionError) {
        debug.errors.push(`Protection check failed: ${protectionError.message}`);
      } else if (protection && protection.length > 0) {
        debug.isProtected = protection[0].is_protected || false;
        debug.protectionReason = protection[0].protection_reason;
      }
    } catch (error) {
      debug.errors.push(`Protection function failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }

  } catch (error) {
    debug.errors.push(`Debug process failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }

  return debug;
}

/**
 * Generate a readable debug report
 */
export function generateDebugReport(debug: DeletionDebugInfo): string {
  let report = `🔍 ACCOUNT DELETION DEBUG REPORT\n`;
  report += `User ID: ${debug.userId}\n`;
  report += `Email: ${debug.email}\n\n`;

  report += `📊 DATA PRESENCE:\n`;
  report += `  ${debug.hasSupabaseAuth ? '✅' : '❌'} Supabase Auth User\n`;
  report += `  ${debug.hasUserProfile ? '✅' : '❌'} User Profile\n`;
  report += `  ${debug.hasUserTrial ? '✅' : '❌'} User Trial\n`;
  report += `  ${debug.hasAccountState ? '✅' : '❌'} Account State\n`;
  report += `  ${debug.hasStripeCustomer ? '✅' : '❌'} Stripe Customer\n`;
  report += `  ${debug.hasAxieCredentials ? '✅' : '❌'} Axie Credentials\n\n`;

  report += `🛡️ PROTECTION STATUS:\n`;
  report += `  Protected: ${debug.isProtected ? '✅ YES' : '❌ NO'}\n`;
  if (debug.protectionReason) {
    report += `  Reason: ${debug.protectionReason}\n`;
  }

  if (debug.errors.length > 0) {
    report += `\n🚨 ERRORS:\n`;
    debug.errors.forEach(error => {
      report += `  • ${error}\n`;
    });
  }

  return report;
}