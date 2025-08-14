
import { useAuth } from '../hooks/useAuth';
import { useUserAccess } from '../hooks/useUserAccess';
import { useSubscription } from '../hooks/useSubscription';
import { isSuperAdmin } from '../utils/adminAuth';
import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';



import { SubscriptionStatus } from '../components/SubscriptionStatus';
import { TrialStatus } from '../components/TrialStatus';
import { AccountDeletionCountdown } from '../components/AccountDeletionCountdown';
import { ReturningUserStatus } from '../components/ReturningUserStatus';
import { CreateAxieStudioButton } from '../components/CreateAxieStudioButton';
import { LaunchStudioOnlyButton } from '../components/LaunchStudioOnlyButton';

import { Link } from 'react-router-dom';
import { Settings, LogOut, ShoppingBag, Zap, Shield, AlertTriangle } from 'lucide-react';

export function DashboardPage() {
  const { user, signOut } = useAuth();
  const {
    accessStatus,
    hasAccess,
    isPaidUser,
    isTrialing,
    isFreeTrialing,
    isProtected
  } = useUserAccess();
  const { subscription } = useSubscription();

  // Returning user status
  const [returningUserStatus, setReturningUserStatus] = useState<{
    has_used_trial: boolean;
    ever_subscribed: boolean;
    deletion_reason: string;
  } | null>(null);

  useEffect(() => {
    const checkReturningUser = async () => {
      if (!user?.email) return;

      try {
        const { data } = await supabase.rpc('check_email_trial_history', {
          p_email: user.email
        });

        if (data && data.length > 0) {
          setReturningUserStatus(data[0]);
        }
      } catch (error) {
        console.error('Error checking returning user status:', error);
      }
    };

    checkReturningUser();
  }, [user?.email]);

  // Debug logging
  console.log('🔍 Dashboard Debug:', {
    accessStatus,
    hasAccess,
    isPaidUser,
    isTrialing,
    isFreeTrialing,
    isProtected,
    access_type: accessStatus?.access_type,
    subscription_status: accessStatus?.subscription_status,
    trial_status: accessStatus?.trial_status,
    subscription_id: accessStatus?.subscription_id,
    price_id: accessStatus?.price_id,
    subscriptionCancelled: subscription?.cancel_at_period_end
  });

  // Check if current user is super admin
  const isAdmin = isSuperAdmin(user?.id);









  return (
    <div className="min-h-screen bg-white">
      <header className="bg-white border-b-4 border-black">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-20">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-white border-2 border-black flex items-center justify-center rounded-none">
                <img
                  src="https://www.axiestudio.se/Axiestudiologo.jpg"
                  alt="Axie Studio"
                  className="w-10 h-10 object-contain"
                />
              </div>
              <div>
                <h1 className="text-xl font-bold text-black uppercase tracking-wide">AXIE STUDIO</h1>
                <p className="text-sm text-gray-600 uppercase tracking-wide">DASHBOARD</p>
              </div>
              {isProtected && (
                <div className="flex items-center gap-2 bg-green-100 text-green-800 px-3 py-1 border border-green-600 rounded-none">
                  <Shield className="w-4 h-4" />
                  <span className="text-xs font-bold uppercase tracking-wide">PROTECTED</span>
                </div>
              )}
            </div>
            <div className="flex items-center gap-6">
              <span className="text-sm text-gray-600 font-medium uppercase tracking-wide">
                {user?.email}
                {isAdmin && (
                  <span className="ml-2 bg-red-600 text-white px-2 py-1 text-xs rounded-none font-bold">
                    SUPER ADMIN
                  </span>
                )}
              </span>

              {isAdmin && (
                <Link
                  to="/admin"
                  className="flex items-center gap-2 bg-red-600 text-white px-3 py-2 rounded-none font-bold hover:bg-red-700 transition-colors uppercase tracking-wide text-xs"
                >
                  <Settings className="w-4 h-4" />
                  ADMIN PANEL
                </Link>
              )}

              <Link
                to="/account"
                className="flex items-center gap-2 bg-gray-600 text-white px-3 py-2 rounded-none font-bold hover:bg-gray-700 transition-colors uppercase tracking-wide text-xs"
              >
                <Settings className="w-4 h-4" />
                ACCOUNT
              </Link>

              <Link
                to="/products"
                className="flex items-center gap-2 bg-black text-white px-3 py-2 rounded-none font-bold hover:bg-gray-800 transition-colors uppercase tracking-wide text-xs"
              >
                <ShoppingBag className="w-4 h-4" />
                PRODUCTS
              </Link>

              <button
                onClick={async () => {
                  console.log('🔓 Logout button clicked');
                  try {
                    await signOut();
                  } catch (error) {
                    console.error('❌ Logout failed:', error);
                    // Force logout as fallback
                    localStorage.clear();
                    sessionStorage.clear();
                    window.location.href = '/login';
                  }
                }}
                className="flex items-center gap-2 text-black hover:text-gray-600 transition-colors font-medium uppercase tracking-wide"
              >
                <LogOut className="w-4 h-4" />
                SIGN OUT
              </button>
            </div>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="mb-12">
          <h2 className="text-4xl font-bold text-black mb-4 uppercase tracking-wide">
            {hasAccess ? 'AI WORKFLOWS READY' : 'WELCOME TO AXIE STUDIO'}
          </h2>
          <p className="text-gray-600 text-lg">
            {hasAccess 
              ? 'Your AI workflow platform is active and ready to use.'
              : 'Start your 7-day free trial to access advanced AI workflow capabilities.'
            }
          </p>
        </div>

        {/* Important Alerts */}
        <div className="mb-8 space-y-4">
          <AccountDeletionCountdown />
          {user?.email && <ReturningUserStatus userEmail={user.email} />}
        </div>



        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="lg:col-span-2 space-y-8">
            {/* Consolidated Status Overview */}
            <div className="bg-white border-2 border-black rounded-none shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] p-8">
              <h3 className="text-xl font-bold text-black mb-6 uppercase tracking-wide">
                ACCOUNT STATUS
              </h3>

              {/* Access Status */}
              <div className="mb-6">
                <div className={`p-4 border-2 rounded-none ${
                  hasAccess ? 'border-green-600 bg-green-50' : 'border-red-600 bg-red-50'
                }`}>
                  <div className="flex items-center justify-between">
                    <div>
                      <p className={`font-bold uppercase tracking-wide ${
                        hasAccess ? 'text-green-800' : 'text-red-800'
                      }`}>
                        {hasAccess ? '✅ ACTIVE ACCESS' : '❌ NO ACCESS'}
                      </p>
                      <p className={`text-sm ${hasAccess ? 'text-green-700' : 'text-red-700'}`}>
                        {accessStatus?.access_type.replace('_', ' ').toUpperCase() || 'UNKNOWN'}
                      </p>
                    </div>
                    <div className="text-right">
                      <p className={`text-sm font-medium ${isProtected ? 'text-green-700' : 'text-orange-700'}`}>
                        {isPaidUser ? 'PREMIUM' : isTrialing ? (subscription?.cancel_at_period_end ? 'CANCELLED' : 'TRIAL') : isProtected ? 'PROTECTED' : 'FREE TRIAL'}
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              {/* Trial/Subscription Status */}
              <div className="space-y-4">
                <TrialStatus />
                <SubscriptionStatus />
              </div>
            </div>

            {/* AXIE STUDIO ACCESS */}
            <div className="bg-white border-2 border-black rounded-none shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] p-8">
              <h3 className="text-xl font-bold text-black mb-6 uppercase tracking-wide">
                AXIE STUDIO
              </h3>

              {/* Studio Access */}
              {hasAccess ? (
                <div className="relative group">
                  <div className="relative flex items-center gap-6 p-6 border-2 border-green-600 rounded-none bg-green-50 hover:bg-green-100 transition-all duration-300 hover:shadow-[8px_8px_0px_0px_rgba(22,163,74,1)] hover:translate-x-[-4px] hover:translate-y-[-4px]">
                    <div className="w-12 h-12 bg-green-600 text-white flex items-center justify-center rounded-none">
                      <Zap className="w-6 h-6" />
                    </div>
                    <div className="flex-1">
                      <h4 className="text-lg font-bold text-green-800 uppercase tracking-wide mb-1">
                        ✅ STUDIO READY
                      </h4>
                      <p className="text-green-700 text-sm">
                        Your AI workflow platform is active and ready to use.
                      </p>
                    </div>
                    <div className="flex flex-col gap-2">
                      <CreateAxieStudioButton className="min-w-[160px] justify-center text-sm" />
                      <LaunchStudioOnlyButton className="min-w-[160px] justify-center text-sm" />
                    </div>
                  </div>
                </div>
              ) : (
                <div className="flex items-center gap-4 p-6 border-2 border-orange-600 rounded-none bg-orange-50">
                  <div className="w-12 h-12 bg-orange-600 text-white flex items-center justify-center rounded-none">
                    <AlertTriangle className="w-6 h-6" />
                  </div>
                  <div className="flex-1">
                    <h4 className="font-bold text-orange-800 uppercase tracking-wide">
                      {(accessStatus?.trial_status === 'expired' || accessStatus?.trial_status === 'scheduled_for_deletion')
                        ? '❌ TRIAL EXPIRED'
                        : '⏳ UPGRADE REQUIRED'
                      }
                    </h4>
                    <p className="text-sm text-orange-700">
                      {(accessStatus?.trial_status === 'expired' || accessStatus?.trial_status === 'scheduled_for_deletion')
                        ? 'Upgrade to Pro to restore access'
                        : 'Requires active subscription'
                      }
                    </p>
                  </div>
                  <Link
                    to="/products"
                    className="px-4 py-2 bg-orange-600 text-white font-bold uppercase tracking-wide rounded-none hover:bg-orange-700 transition-colors"
                  >
                    UPGRADE
                  </Link>
                </div>
              )}

              {/* Admin Testing (if admin) */}
              {isAdmin && (
                <div className="mt-6 pt-6 border-t-2 border-gray-200">
                  <Link
                    to="/test"
                    className="flex items-center gap-4 p-4 border-2 border-red-600 rounded-none hover:bg-red-50 transition-all hover:shadow-[4px_4px_0px_0px_rgba(220,38,38,1)] hover:translate-x-[-2px] hover:translate-y-[-2px]"
                  >
                    <div className="w-10 h-10 bg-red-600 text-white flex items-center justify-center rounded-none">
                      <Settings className="w-5 h-5" />
                    </div>
                    <div>
                      <h4 className="font-bold text-red-800 uppercase tracking-wide text-sm">ADMIN TESTING</h4>
                      <p className="text-xs text-red-600">Test system integrations</p>
                    </div>
                  </Link>
                </div>
              )}


            </div>
          </div>

          <div className="space-y-8">
            <div className="bg-white border-2 border-black rounded-none shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] p-8">
              <h3 className="text-xl font-bold text-black mb-6 uppercase tracking-wide">
                ACCOUNT INFO
              </h3>
              <div className="space-y-4">
                <div>
                  <label className="text-sm font-bold text-black uppercase tracking-wide">EMAIL</label>
                  <p className="text-gray-900 font-medium">{user?.email}</p>
                </div>
                <div>
                  <label className="text-sm font-bold text-black uppercase tracking-wide">MEMBER SINCE</label>
                  <p className="text-gray-900 font-medium">
                    {user?.created_at ? new Date(user.created_at).toLocaleDateString() : 'N/A'}
                  </p>
                </div>
                <div>
                  <label className="text-sm font-bold text-black uppercase tracking-wide">ACCOUNT STATUS</label>
                  <p className={`font-medium ${isProtected ? 'text-green-600' : 'text-orange-600'}`}>
                    {isPaidUser ? 'PREMIUM' : isTrialing ? (subscription?.cancel_at_period_end ? 'CANCELLED SUBSCRIPTION' : 'STRIPE TRIAL') : isProtected ? 'PROTECTED' : 'TRIAL'}
                  </p>
                </div>

                {/* Subscription Information */}
                {subscription && (
                  <div>
                    <label className="text-sm font-bold text-black uppercase tracking-wide">SUBSCRIPTION</label>
                    <p className="text-gray-900 font-medium">
                      {subscription.cancel_at_period_end ? (
                        <span className="text-orange-600">
                          Cancelled - Expires {subscription.current_period_end ? new Date(subscription.current_period_end * 1000).toLocaleDateString() : 'N/A'}
                        </span>
                      ) : (
                        <span className="text-green-600">
                          Active - Renews {subscription.current_period_end ? new Date(subscription.current_period_end * 1000).toLocaleDateString() : 'N/A'}
                        </span>
                      )}
                    </p>
                  </div>
                )}

                {/* Trial Information */}
                {accessStatus?.trial_end_date && !isPaidUser && (
                  <div>
                    <label className="text-sm font-bold text-black uppercase tracking-wide">TRIAL EXPIRES</label>
                    <p className="text-gray-900 font-medium">
                      {new Date(accessStatus.trial_end_date).toLocaleDateString()}
                    </p>
                  </div>
                )}

                {/* Returning User Status */}
                {returningUserStatus?.has_used_trial && (
                  <div>
                    <label className="text-sm font-bold text-black uppercase tracking-wide">USER TYPE</label>
                    <p className="text-blue-600 font-medium">
                      {returningUserStatus.ever_subscribed ? 'Returning Subscriber' : 'Returning User - Trial Used'}
                    </p>
                  </div>
                )}


                {subscription && (
                  <div>
                    <label className="text-sm font-bold text-black uppercase tracking-wide">SUBSCRIPTION</label>
                    <p className="text-gray-900 font-medium">
                      {subscription.cancel_at_period_end ? 'Cancelled - Expires ' : 'Active - Renews '}
                      {subscription.current_period_end ? new Date(subscription.current_period_end * 1000).toLocaleDateString() : 'N/A'}
                    </p>
                  </div>
                )}
                {accessStatus?.trial_end_date && !isPaidUser && (
                  <div>
                    <label className="text-sm font-bold text-black uppercase tracking-wide">TRIAL EXPIRES</label>
                    <p className="text-gray-900 font-medium">
                      {new Date(accessStatus.trial_end_date).toLocaleDateString()}
                    </p>
                  </div>
                )}
              </div>
            </div>

            {/* Quick Actions */}
            <div className="bg-white border-2 border-black rounded-none shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] p-8">
              <h3 className="text-xl font-bold text-black mb-6 uppercase tracking-wide">
                QUICK ACTIONS
              </h3>
              <div className="space-y-4">
                <Link
                  to="/products"
                  className="flex items-center gap-3 p-4 border-2 border-black rounded-none hover:bg-gray-50 transition-all hover:shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] hover:translate-x-[-2px] hover:translate-y-[-2px]"
                >
                  <div className="w-10 h-10 bg-black text-white flex items-center justify-center rounded-none">
                    <ShoppingBag className="w-5 h-5" />
                  </div>
                  <div>
                    <h4 className="font-bold text-black uppercase tracking-wide text-sm">VIEW PLANS</h4>
                    <p className="text-xs text-gray-600">Upgrade or change plan</p>
                  </div>
                </Link>

                <Link
                  to="/account"
                  className="flex items-center gap-3 p-4 border-2 border-black rounded-none hover:bg-gray-50 transition-all hover:shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] hover:translate-x-[-2px] hover:translate-y-[-2px]"
                >
                  <div className="w-10 h-10 bg-black text-white flex items-center justify-center rounded-none">
                    <Settings className="w-5 h-5" />
                  </div>
                  <div>
                    <h4 className="font-bold text-black uppercase tracking-wide text-sm">ACCOUNT SETTINGS</h4>
                    <p className="text-xs text-gray-600">Manage your account</p>
                  </div>
                </Link>
              </div>
            </div>


          </div>
        </div>
      </main>
    </div>
  );
}