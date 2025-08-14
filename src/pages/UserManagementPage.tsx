import { useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import { useEnterpriseUser } from '../hooks/useEnterpriseUser';
import { supabase } from '../lib/supabase';
import { Link } from 'react-router-dom';
import { SubscriptionManagement } from '../components/SubscriptionManagement';
import { LaunchStudioButton } from '../components/LaunchStudioButton';
import { debugAccountDeletion, generateDebugReport } from '../utils/debugAccountDeletion';
import { isSuperAdmin } from '../utils/adminAuth';
import { Mail, Calendar, Shield, Trash2, AlertTriangle, CheckCircle, ArrowLeft, Key, Eye, EyeOff } from 'lucide-react';

export function UserManagementPage() {
  const { user, signOut } = useAuth();
  const { enterpriseState, isEnterpriseEnabled } = useEnterpriseUser();
  const [isDeleting, setIsDeleting] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);

  // Check if current user is super admin
  const isAdmin = isSuperAdmin(user?.id);

  // Password change state
  const [showPasswordChange, setShowPasswordChange] = useState(false);
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showCurrentPassword, setShowCurrentPassword] = useState(false);
  const [showNewPassword, setShowNewPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [isChangingPassword, setIsChangingPassword] = useState(false);
  const [passwordChangeMessage, setPasswordChangeMessage] = useState('');

  // Debug account deletion
  const debugDeletion = async () => {
    if (!user) return;
    
    console.log('🔍 Running account deletion debug...');
    const debugInfo = await debugAccountDeletion(user.id);
    const report = generateDebugReport(debugInfo);
    
    console.log(report);
    alert(`Debug Report:\n\n${report}`);
  };

  const handlePasswordChange = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!user) return;

    // Validation
    if (newPassword !== confirmPassword) {
      setPasswordChangeMessage('New passwords do not match');
      return;
    }

    if (newPassword.length < 6) {
      setPasswordChangeMessage('Password must be at least 6 characters long');
      return;
    }

    setIsChangingPassword(true);
    setPasswordChangeMessage('');

    try {
      // Update password using Supabase Auth
      const { error } = await supabase.auth.updateUser({
        password: newPassword
      });

      if (error) throw error;

      setPasswordChangeMessage('Password updated successfully!');
      setCurrentPassword('');
      setNewPassword('');
      setConfirmPassword('');
      setShowPasswordChange(false);

      // Auto-hide success message after 3 seconds
      setTimeout(() => setPasswordChangeMessage(''), 3000);

    } catch (error: any) {
      console.error('Password change error:', error);
      setPasswordChangeMessage(error.message || 'Failed to update password');
    } finally {
      setIsChangingPassword(false);
    }
  };

  const handleDeleteAccount = async () => {
    if (!user) return;

    console.log('🗑️ Starting account deletion process for user:', user.id);

    setIsDeleting(true);
    try {
      // Step 1: Get current session for API calls
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session) {
        throw new Error('No active session found');
      }

      console.log('✅ Session found, proceeding with deletion...');

      // Step 2: Call the delete-user-account function (this handles everything)
      console.log('🔄 Calling delete-user-account function...');
      
      const deleteResponse = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/delete-user-account`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({
          user_id: user.id
        }),
      });

      const deleteResult = await deleteResponse.json();
      
      console.log('📡 Delete function response:', {
        status: deleteResponse.status,
        ok: deleteResponse.ok,
        result: deleteResult
      });

      if (!deleteResponse.ok) {
        throw new Error(deleteResult.error || deleteResult.details || 'Failed to delete account');
      }

      if (!deleteResult.success) {
        throw new Error(deleteResult.error || 'Account deletion failed');
      }

      console.log('✅ Account deletion completed successfully:', deleteResult);

      // Step 3: Sign out immediately
      console.log('🔄 Signing out user...');
      await signOut();
      
      console.log('✅ User signed out successfully');
    } catch (error) {
      console.error('❌ Failed to delete account:', error);
      
      // Show specific error message
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
      alert(`❌ Account deletion failed: ${errorMessage}\n\nPlease try again or contact support if the issue persists.`);
    } finally {
      setIsDeleting(false);
      setShowDeleteConfirm(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-6xl mx-auto space-y-8">
        {/* Header */}
        <div className="bg-white border-2 border-black rounded-none shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] p-6">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 bg-white border-2 border-black flex items-center justify-center rounded-none">
                <img
                  src="https://www.axiestudio.se/Axiestudiologo.jpg"
                  alt="Axie Studio"
                  className="w-8 h-8 object-contain"
                />
              </div>
              <div>
                <h1 className="text-2xl font-bold text-black uppercase tracking-wide">
                  AXIE STUDIO
                </h1>
                <p className="text-lg font-bold text-black uppercase tracking-wide">
                  Account Management
                </p>
              </div>
            </div>
            <Link
              to="/dashboard"
              className="flex items-center gap-2 bg-gray-600 text-white px-4 py-2 rounded-none font-bold hover:bg-gray-700 transition-colors uppercase tracking-wide text-sm"
            >
              <ArrowLeft className="w-4 h-4" />
              BACK TO DASHBOARD
            </Link>
          </div>
          <p className="text-gray-600">
            Manage your account settings and subscription details.
          </p>
        </div>

        {/* Account Information */}
        <div className="bg-white border-2 border-black rounded-none shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] p-6">
          <h2 className="text-xl font-bold text-black mb-6 uppercase tracking-wide">
            Account Information
          </h2>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-4">
              <div className="flex items-center gap-3 p-4 border-2 border-gray-200 rounded-none">
                <Mail className="w-5 h-5 text-gray-600" />
                <div>
                  <p className="text-sm text-gray-600 uppercase tracking-wide">Email</p>
                  <p className="font-bold text-black">{user?.email}</p>
                </div>
              </div>
              
              <div className="flex items-center gap-3 p-4 border-2 border-gray-200 rounded-none">
                <Calendar className="w-5 h-5 text-gray-600" />
                <div>
                  <p className="text-sm text-gray-600 uppercase tracking-wide">Member Since</p>
                  <p className="font-bold text-black">
                    {user?.created_at ? new Date(user.created_at).toLocaleDateString() : 'Unknown'}
                  </p>
                </div>
              </div>
            </div>

            <div className="space-y-4">
              {isEnterpriseEnabled && enterpriseState && (
                <>
                  <div className="flex items-center gap-3 p-4 border-2 border-gray-200 rounded-none">
                    <Shield className="w-5 h-5 text-gray-600" />
                    <div>
                      <p className="text-sm text-gray-600 uppercase tracking-wide">Access Level</p>
                      <p className="font-bold text-black capitalize">{enterpriseState.access_level}</p>
                    </div>
                  </div>
                  
                  <div className="flex items-center gap-3 p-4 border-2 border-gray-200 rounded-none">
                    <CheckCircle className="w-5 h-5 text-gray-600" />
                    <div>
                      <p className="text-sm text-gray-600 uppercase tracking-wide">Account Status</p>
                      <p className="font-bold text-black capitalize">{enterpriseState.account_status}</p>
                    </div>
                  </div>
                </>
              )}
            </div>
          </div>
        </div>

        {/* Main Content Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Left Column - Main Actions */}
          <div className="lg:col-span-2 space-y-8">
            {/* AxieStudio Access */}
            <div className="bg-white border-2 border-black rounded-none shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] p-6">
              <h2 className="text-xl font-bold text-black mb-6 uppercase tracking-wide">
                AxieStudio Access
              </h2>

              <div className="bg-blue-50 border-2 border-blue-200 rounded-none p-6">
                <div className="flex items-center gap-4 mb-4">
                  <div className="w-12 h-12 bg-white border-2 border-black flex items-center justify-center rounded-none">
                    <img
                      src="https://www.axiestudio.se/Axiestudiologo.jpg"
                      alt="Axie Studio"
                      className="w-8 h-8 object-contain"
                    />
                  </div>
                  <div>
                    <h3 className="text-lg font-bold text-blue-900 uppercase tracking-wide">AI WORKFLOW STUDIO</h3>
                    <p className="text-blue-700 text-sm">Access your AI workflow platform</p>
                  </div>
                </div>

                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-blue-800 font-medium mb-1">Ready to launch</p>
                    <p className="text-blue-600 text-sm">Uses your account credentials for automatic login</p>
                  </div>
                  <LaunchStudioButton
                    className="bg-blue-600 text-white px-6 py-3 font-bold uppercase tracking-wide hover:bg-blue-700 transition-colors border-2 border-blue-700"
                    variant="primary"
                  />
                </div>
              </div>
            </div>

            {/* Subscription Management */}
            <div className="bg-white border-2 border-black rounded-none shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] p-6">
              <h2 className="text-xl font-bold text-black mb-6 uppercase tracking-wide">
                Subscription Management
              </h2>
              <SubscriptionManagement />
            </div>
          </div>

          {/* Right Column - Settings & Actions */}
          <div className="space-y-8">
            {/* Security Settings */}
            <div className="bg-white border-2 border-black rounded-none shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] p-6">
              <h2 className="text-xl font-bold text-black mb-6 uppercase tracking-wide">
                Security Settings
              </h2>

              {passwordChangeMessage && (
                <div className={`p-4 border-2 rounded-none mb-6 ${
                  passwordChangeMessage.includes('successfully')
                    ? 'border-green-200 bg-green-50 text-green-800'
                    : 'border-red-200 bg-red-50 text-red-800'
                }`}>
                  {passwordChangeMessage}
                </div>
              )}

              {!showPasswordChange ? (
                <button
                  onClick={() => setShowPasswordChange(true)}
                  className="flex items-center gap-2 bg-gray-600 text-white px-4 py-2 rounded-none font-bold hover:bg-gray-700 transition-colors uppercase tracking-wide text-sm"
                >
                  <Key className="w-4 h-4" />
                  Change Password
                </button>
              ) : (
                <form onSubmit={handlePasswordChange} className="space-y-4">
                  <div>
                    <label className="block text-sm font-bold text-black uppercase tracking-wide mb-2">
                      Current Password
                    </label>
                    <div className="relative">
                      <input
                        type={showCurrentPassword ? 'text' : 'password'}
                        value={currentPassword}
                        onChange={(e) => setCurrentPassword(e.target.value)}
                        className="w-full p-3 border-2 border-gray-300 rounded-none focus:border-black focus:outline-none"
                        required
                      />
                      <button
                        type="button"
                        onClick={() => setShowCurrentPassword(!showCurrentPassword)}
                        className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-500 hover:text-gray-700"
                      >
                        {showCurrentPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                      </button>
                    </div>
                  </div>

                  <div>
                    <label className="block text-sm font-bold text-black uppercase tracking-wide mb-2">
                      New Password
                    </label>
                    <div className="relative">
                      <input
                        type={showNewPassword ? 'text' : 'password'}
                        value={newPassword}
                        onChange={(e) => setNewPassword(e.target.value)}
                        className="w-full p-3 border-2 border-gray-300 rounded-none focus:border-black focus:outline-none"
                        required
                        minLength={6}
                      />
                      <button
                        type="button"
                        onClick={() => setShowNewPassword(!showNewPassword)}
                        className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-500 hover:text-gray-700"
                      >
                        {showNewPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                      </button>
                    </div>
                  </div>

                  <div>
                    <label className="block text-sm font-bold text-black uppercase tracking-wide mb-2">
                      Confirm New Password
                    </label>
                    <div className="relative">
                      <input
                        type={showConfirmPassword ? 'text' : 'password'}
                        value={confirmPassword}
                        onChange={(e) => setConfirmPassword(e.target.value)}
                        className="w-full p-3 border-2 border-gray-300 rounded-none focus:border-black focus:outline-none"
                        required
                        minLength={6}
                      />
                      <button
                        type="button"
                        onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                        className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-500 hover:text-gray-700"
                      >
                        {showConfirmPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                      </button>
                    </div>
                  </div>

                  <div className="flex gap-4">
                    <button
                      type="submit"
                      disabled={isChangingPassword}
                      className="bg-black text-white px-4 py-2 font-bold uppercase tracking-wide hover:bg-gray-800 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {isChangingPassword ? 'Updating...' : 'Update Password'}
                    </button>
                    <button
                      type="button"
                      onClick={() => setShowPasswordChange(false)}
                      className="bg-gray-300 text-black px-4 py-2 font-bold uppercase tracking-wide hover:bg-gray-400 transition-colors"
                    >
                      Cancel
                    </button>
                  </div>
                </form>
              )}
            </div>

            {/* Subscription Information */}
            {isEnterpriseEnabled && enterpriseState && (
              <div className="bg-white border-2 border-black rounded-none shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] p-6">
                <h2 className="text-xl font-bold text-black mb-6 uppercase tracking-wide">
                  Subscription Details
                </h2>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  {enterpriseState.stripe_customer_id && (
                    <div className="p-4 border-2 border-gray-200 rounded-none">
                      <p className="text-sm text-gray-600 uppercase tracking-wide mb-2">Stripe Customer ID</p>
                      <p className="font-mono text-sm text-black">{enterpriseState.stripe_customer_id}</p>
                    </div>
                  )}

                  {enterpriseState.stripe_status && (
                    <div className="p-4 border-2 border-gray-200 rounded-none">
                      <p className="text-sm text-gray-600 uppercase tracking-wide mb-2">Subscription Status</p>
                      <p className="font-bold text-black capitalize">{enterpriseState.stripe_status}</p>
                    </div>
                  )}

                  {enterpriseState.trial_days_remaining > 0 && (
                    <div className="p-4 border-2 border-orange-200 bg-orange-50 rounded-none">
                      <p className="text-sm text-orange-600 uppercase tracking-wide mb-2">Trial Days Remaining</p>
                      <p className="font-bold text-orange-800">{enterpriseState.trial_days_remaining} days</p>
                    </div>
                  )}

                  {enterpriseState.axie_studio_user_id && (
                    <div className="p-4 border-2 border-gray-200 rounded-none">
                      <p className="text-sm text-gray-600 uppercase tracking-wide mb-2">AxieStudio Account</p>
                      <p className="font-mono text-sm text-black">{enterpriseState.axie_studio_user_id}</p>
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Account Actions */}
            <div className="bg-white border-2 border-black rounded-none shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] p-6">
              <h2 className="text-xl font-bold text-black mb-6 uppercase tracking-wide">
                Account Actions
              </h2>

              <div className="space-y-4">
                <div className="p-4 border-2 border-red-200 bg-red-50 rounded-none">
                  <div className="flex items-center gap-3 mb-4">
                    <AlertTriangle className="w-6 h-6 text-red-600" />
                    <h3 className="text-lg font-bold text-red-800 uppercase tracking-wide">
                      Danger Zone
                    </h3>
                  </div>

                  <p className="text-red-700 mb-4">
                    Permanently delete your account and all associated data. This action cannot be undone.
                  </p>

                  {!showDeleteConfirm ? (
                    <div className="space-y-3">
                      <button
                        onClick={() => setShowDeleteConfirm(true)}
                        className="flex items-center gap-2 bg-red-600 text-white px-4 py-2 font-bold uppercase tracking-wide hover:bg-red-700 transition-colors"
                      >
                        <Trash2 className="w-4 h-4" />
                        Delete Account
                      </button>
                      {isAdmin && (
                        <button
                          onClick={() => debugAccountDeletion(user?.id || '')}
                          className="flex items-center gap-2 bg-yellow-600 text-white px-4 py-2 font-bold uppercase tracking-wide hover:bg-yellow-700 transition-colors ml-4"
                        >
                          Debug Deletion
                        </button>
                      )}
                    </div>
                  ) : (
                    <div className="space-y-4">
                      <p className="font-bold text-red-800">
                        Are you absolutely sure? This action cannot be undone.
                      </p>
                      <div className="flex gap-4">
                        <button
                          onClick={handleDeleteAccount}
                          disabled={isDeleting}
                          className="bg-red-600 text-white px-4 py-2 font-bold uppercase tracking-wide hover:bg-red-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {isDeleting ? 'Deleting...' : 'Yes, Delete Account'}
                        </button>
                        <button
                          onClick={() => setShowDeleteConfirm(false)}
                          className="bg-gray-300 text-black px-4 py-2 font-bold uppercase tracking-wide hover:bg-gray-400 transition-colors"
                        >
                          Cancel
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
            {/* Security Settings */}
            <div className="bg-white border-2 border-black rounded-none shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] p-6">
          <h2 className="text-xl font-bold text-black mb-6 uppercase tracking-wide">
            Security Settings
          </h2>

          {passwordChangeMessage && (
            <div className={`p-4 border-2 rounded-none mb-6 ${
              passwordChangeMessage.includes('successfully')
                ? 'border-green-200 bg-green-50 text-green-800'
                : 'border-red-200 bg-red-50 text-red-800'
            }`}>
              {passwordChangeMessage}
            </div>
          )}

          {!showPasswordChange ? (
            <button
              onClick={() => setShowPasswordChange(true)}
              className="flex items-center gap-2 bg-black text-white px-4 py-2 rounded-none font-bold hover:bg-gray-800 transition-colors uppercase tracking-wide"
            >
              <Key className="w-4 h-4" />
              Change Password
            </button>
          ) : (
            <form onSubmit={handlePasswordChange} className="space-y-4">
              <div>
                <label className="block text-sm font-bold text-black uppercase tracking-wide mb-2">
                  Current Password
                </label>
                <div className="relative">
                  <input
                    type={showCurrentPassword ? 'text' : 'password'}
                    value={currentPassword}
                    onChange={(e) => setCurrentPassword(e.target.value)}
                    className="w-full p-3 border-2 border-black rounded-none focus:outline-none focus:ring-2 focus:ring-black"
                    required
                  />
                  <button
                    type="button"
                    onClick={() => setShowCurrentPassword(!showCurrentPassword)}
                    className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-600 hover:text-black"
                  >
                    {showCurrentPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-sm font-bold text-black uppercase tracking-wide mb-2">
                  New Password
                </label>
                <div className="relative">
                  <input
                    type={showNewPassword ? 'text' : 'password'}
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    className="w-full p-3 border-2 border-black rounded-none focus:outline-none focus:ring-2 focus:ring-black"
                    required
                    minLength={6}
                  />
                  <button
                    type="button"
                    onClick={() => setShowNewPassword(!showNewPassword)}
                    className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-600 hover:text-black"
                  >
                    {showNewPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-sm font-bold text-black uppercase tracking-wide mb-2">
                  Confirm New Password
                </label>
                <div className="relative">
                  <input
                    type={showConfirmPassword ? 'text' : 'password'}
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    className="w-full p-3 border-2 border-black rounded-none focus:outline-none focus:ring-2 focus:ring-black"
                    required
                    minLength={6}
                  />
                  <button
                    type="button"
                    onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                    className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-600 hover:text-black"
                  >
                    {showConfirmPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              <div className="flex gap-4">
                <button
                  type="submit"
                  disabled={isChangingPassword}
                  className="flex items-center gap-2 bg-black text-white px-4 py-2 rounded-none font-bold hover:bg-gray-800 transition-colors uppercase tracking-wide disabled:opacity-50"
                >
                  <Key className="w-4 h-4" />
                  {isChangingPassword ? 'Updating...' : 'Update Password'}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setShowPasswordChange(false);
                    setCurrentPassword('');
                    setNewPassword('');
                    setConfirmPassword('');
                    setPasswordChangeMessage('');
                  }}
                  className="bg-gray-600 text-white px-4 py-2 rounded-none font-bold hover:bg-gray-700 transition-colors uppercase tracking-wide"
                >
                  Cancel
                </button>
              </div>
            </form>
          )}
        </div>

        {/* Subscription Information */}
        {isEnterpriseEnabled && enterpriseState && (
          <div className="bg-white border-2 border-black rounded-none shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] p-6">
            <h2 className="text-xl font-bold text-black mb-6 uppercase tracking-wide">
              Subscription Details
            </h2>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {enterpriseState.stripe_customer_id && (
                <div className="p-4 border-2 border-gray-200 rounded-none">
                  <p className="text-sm text-gray-600 uppercase tracking-wide mb-2">Stripe Customer ID</p>
                  <p className="font-mono text-sm text-black">{enterpriseState.stripe_customer_id}</p>
                </div>
              )}
              
              {enterpriseState.stripe_status && (
                <div className="p-4 border-2 border-gray-200 rounded-none">
                  <p className="text-sm text-gray-600 uppercase tracking-wide mb-2">Subscription Status</p>
                  <p className="font-bold text-black capitalize">{enterpriseState.stripe_status}</p>
                </div>
              )}
              
              {enterpriseState.trial_days_remaining > 0 && (
                <div className="p-4 border-2 border-orange-200 bg-orange-50 rounded-none">
                  <p className="text-sm text-orange-600 uppercase tracking-wide mb-2">Trial Days Remaining</p>
                  <p className="font-bold text-orange-800">{enterpriseState.trial_days_remaining} days</p>
                </div>
              )}
              
              {enterpriseState.axie_studio_user_id && (
                <div className="p-4 border-2 border-gray-200 rounded-none">
                  <p className="text-sm text-gray-600 uppercase tracking-wide mb-2">AxieStudio Account</p>
                  <p className="font-mono text-sm text-black">{enterpriseState.axie_studio_user_id}</p>
                </div>
              )}
            </div>
          </div>
        )}

            {/* Account Actions */}
            <div className="bg-white border-2 border-black rounded-none shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] p-6">
          <h2 className="text-xl font-bold text-black mb-6 uppercase tracking-wide">
            Account Actions
          </h2>
          
          <div className="space-y-4">
            <div className="p-4 border-2 border-red-200 bg-red-50 rounded-none">
              <div className="flex items-center gap-3 mb-4">
                <AlertTriangle className="w-6 h-6 text-red-600" />
                <h3 className="text-lg font-bold text-red-800 uppercase tracking-wide">
                  Danger Zone
                </h3>
              </div>
              
              <p className="text-red-700 mb-4">
                <strong>IMMEDIATE DELETION:</strong> This will instantly remove your account and all access,
                regardless of any active subscription or trial time remaining. All data will be permanently deleted
                and your AxieStudio account will be removed. This action cannot be undone.
              </p>
              
              {!showDeleteConfirm ? (
                <div className="space-y-3">
                  <button
                    onClick={() => setShowDeleteConfirm(true)}
                    className="flex items-center gap-2 bg-red-600 text-white px-4 py-2 rounded-none font-bold hover:bg-red-700 uppercase tracking-wide"
                  >
                    <Trash2 className="w-4 h-4" />
                    DELETE ACCOUNT IMMEDIATELY
                  </button>

                  {isAdmin && (
                    <button
                      onClick={debugDeletion}
                      className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-none font-bold hover:bg-blue-700 uppercase tracking-wide text-sm"
                    >
                      🔍 DEBUG DELETION ISSUES
                    </button>
                  )}
                </div>
              ) : (
                <div className="space-y-4">
                  <p className="font-bold text-red-800">
                    Are you absolutely sure? This action cannot be undone.
                  </p>
                  <div className="flex gap-4">
                    <button
                      onClick={handleDeleteAccount}
                      disabled={isDeleting}
                      className="flex items-center gap-2 bg-red-600 text-white px-4 py-2 rounded-none font-bold hover:bg-red-700 disabled:opacity-50 uppercase tracking-wide"
                    >
                      <Trash2 className="w-4 h-4" />
                      {isDeleting ? 'DELETING...' : 'YES, DELETE IMMEDIATELY'}
                    </button>
                    <button
                      onClick={() => setShowDeleteConfirm(false)}
                      className="bg-gray-600 text-white px-4 py-2 rounded-none font-bold hover:bg-gray-700"
                    >
                      Cancel
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
          </div>
        </div>
      </div>
    </div>
  );
}
