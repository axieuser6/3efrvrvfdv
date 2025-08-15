import React, { useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import { useUserAccess } from '../hooks/useUserAccess';
import { useSubscription } from '../hooks/useSubscription';
import { supabase } from '../lib/supabase';
import { Link } from 'react-router-dom';
import { SubscriptionManagement } from '../components/SubscriptionManagement';
import { LaunchStudioButton } from '../components/LaunchStudioButton';
import { isSuperAdmin } from '../utils/adminAuth';
import { 
  Mail, 
  Calendar, 
  Shield, 
  Trash2, 
  AlertTriangle, 
  ArrowLeft, 
  Key, 
  Eye, 
  EyeOff,
  User,
  Crown,
  Zap,
  Settings
} from 'lucide-react';

export function UserManagementPage() {
  const { user, signOut } = useAuth();
  const { accessStatus, isPaidUser, isTrialing } = useUserAccess();
  const { subscription } = useSubscription();
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

  // Get user status for display
  const getUserStatus = () => {
    if (isAdmin) return { text: 'SUPER ADMIN', color: 'text-purple-600', bg: 'bg-purple-100' };
    if (isPaidUser) return { text: 'PREMIUM', color: 'text-green-600', bg: 'bg-green-100' };
    if (isTrialing) return { text: 'TRIAL', color: 'text-blue-600', bg: 'bg-blue-100' };
    return { text: 'STANDARD', color: 'text-gray-600', bg: 'bg-gray-100' };
  };

  const userStatus = getUserStatus();

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
      {/* Header */}
      <div className="bg-white border-b-2 border-black shadow-lg">
        <div className="max-w-6xl mx-auto px-6 py-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-white border-2 border-black flex items-center justify-center rounded-none shadow-md">
                <img
                  src="https://www.axiestudio.se/Axiestudiologo.jpg"
                  alt="Axie Studio"
                  className="w-8 h-8 object-contain"
                />
              </div>
              <div>
                <h1 className="text-2xl font-bold text-black uppercase tracking-wide">AXIE STUDIO</h1>
                <p className="text-gray-600 font-medium">Account Management</p>
              </div>
            </div>
            <Link
              to="/dashboard"
              className="flex items-center gap-2 bg-gray-600 text-white px-4 py-2 rounded-none font-bold hover:bg-gray-700 transition-all duration-200 uppercase tracking-wide text-sm shadow-md hover:shadow-lg"
            >
              <ArrowLeft className="w-4 h-4" />
              BACK TO DASHBOARD
            </Link>
          </div>
        </div>
      </div>

      <div className="max-w-6xl mx-auto px-6 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Left Column - Profile & Status */}
          <div className="lg:col-span-1 space-y-6">
            {/* User Profile Card */}
            <div className="bg-white border-2 border-black rounded-none shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] p-6">
              <div className="text-center mb-6">
                <div className="w-20 h-20 bg-gradient-to-br from-blue-500 to-purple-600 text-white flex items-center justify-center rounded-none mx-auto mb-4 shadow-lg">
                  <User className="w-10 h-10" />
                </div>
                <h2 className="text-xl font-bold text-black uppercase tracking-wide mb-2">
                  USER PROFILE
                </h2>
                <div className={`inline-flex items-center gap-2 px-3 py-1 rounded-none ${userStatus.bg} ${userStatus.color} font-bold text-sm uppercase tracking-wide`}>
                  {isAdmin && <Crown className="w-4 h-4" />}
                  {isPaidUser && !isAdmin && <Shield className="w-4 h-4" />}
                  {userStatus.text}
                </div>
              </div>

              <div className="space-y-4">
                <div className="flex items-center gap-3 p-3 bg-gray-50 border border-gray-200 rounded-none">
                  <Mail className="w-5 h-5 text-gray-600" />
                  <div className="flex-1">
                    <p className="text-xs text-gray-500 uppercase tracking-wide font-bold">EMAIL</p>
                    <p className="text-black font-medium">{user?.email}</p>
                  </div>
                </div>
                
                <div className="flex items-center gap-3 p-3 bg-gray-50 border border-gray-200 rounded-none">
                  <Calendar className="w-5 h-5 text-gray-600" />
                  <div className="flex-1">
                    <p className="text-xs text-gray-500 uppercase tracking-wide font-bold">MEMBER SINCE</p>
                    <p className="text-black font-medium">
                      {user?.created_at ? new Date(user.created_at).toLocaleDateString() : 'Unknown'}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-3 p-3 bg-gray-50 border border-gray-200 rounded-none">
                  <Shield className="w-5 h-5 text-gray-600" />
                  <div className="flex-1">
                    <p className="text-xs text-gray-500 uppercase tracking-wide font-bold">ACCESS LEVEL</p>
                    <p className="text-black font-medium capitalize">
                      {accessStatus?.access_level || 'Standard'}
                    </p>
                  </div>
                </div>
              </div>
            </div>

            {/* Security Settings Card */}
            <div className="bg-white border-2 border-black rounded-none shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] p-6">
              <div className="flex items-center gap-3 mb-6">
                <div className="w-8 h-8 bg-blue-600 text-white flex items-center justify-center rounded-none">
                  <Key className="w-5 h-5" />
                </div>
                <h3 className="text-lg font-bold text-black uppercase tracking-wide">
                  SECURITY
                </h3>
              </div>

              {passwordChangeMessage && (
                <div className={`p-4 border-2 rounded-none mb-4 ${
                  passwordChangeMessage.includes('successfully')
                    ? 'border-green-200 bg-green-50 text-green-800'
                    : 'border-red-200 bg-red-50 text-red-800'
                }`}>
                  <p className="text-sm font-medium">{passwordChangeMessage}</p>
                </div>
              )}

              {!showPasswordChange ? (
                <button
                  onClick={() => setShowPasswordChange(true)}
                  className="w-full flex items-center justify-center gap-2 bg-blue-600 text-white px-4 py-3 rounded-none font-bold hover:bg-blue-700 transition-colors uppercase tracking-wide"
                >
                  <Key className="w-4 h-4" />
                  CHANGE PASSWORD
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
                        className="w-full p-3 border-2 border-gray-300 rounded-none focus:outline-none focus:border-blue-600 transition-colors"
                        required
                      />
                      <button
                        type="button"
                        onClick={() => setShowCurrentPassword(!showCurrentPassword)}
                        className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-600 hover:text-black transition-colors"
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
                        className="w-full p-3 border-2 border-gray-300 rounded-none focus:outline-none focus:border-blue-600 transition-colors"
                        required
                        minLength={6}
                      />
                      <button
                        type="button"
                        onClick={() => setShowNewPassword(!showNewPassword)}
                        className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-600 hover:text-black transition-colors"
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
                        className="w-full p-3 border-2 border-gray-300 rounded-none focus:outline-none focus:border-blue-600 transition-colors"
                        required
                        minLength={6}
                      />
                      <button
                        type="button"
                        onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                        className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-600 hover:text-black transition-colors"
                      >
                        {showConfirmPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                      </button>
                    </div>
                  </div>

                  <div className="flex gap-3">
                    <button
                      type="submit"
                      disabled={isChangingPassword}
                      className="flex-1 bg-blue-600 text-white px-4 py-2 rounded-none font-bold hover:bg-blue-700 transition-colors uppercase tracking-wide disabled:opacity-50"
                    >
                      {isChangingPassword ? 'UPDATING...' : 'UPDATE'}
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
                      className="flex-1 bg-gray-600 text-white px-4 py-2 rounded-none font-bold hover:bg-gray-700 transition-colors uppercase tracking-wide"
                    >
                      CANCEL
                    </button>
                  </div>
                </form>
              )}
            </div>
          </div>

          {/* Right Column - Main Content */}
          <div className="lg:col-span-2 space-y-6">
            {/* AxieStudio Access Card */}
            <div className="bg-white border-2 border-black rounded-none shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] p-6">
              <div className="flex items-center gap-3 mb-6">
                <div className="w-8 h-8 bg-blue-600 text-white flex items-center justify-center rounded-none">
                  <Zap className="w-5 h-5" />
                </div>
                <h3 className="text-lg font-bold text-black uppercase tracking-wide">
                  AXIESTUDIO ACCESS
                </h3>
              </div>

              <div className="bg-gradient-to-r from-blue-50 to-purple-50 border-2 border-blue-200 rounded-none p-6">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-4">
                    <div className="w-12 h-12 bg-white border-2 border-black flex items-center justify-center rounded-none shadow-md">
                      <img
                        src="https://www.axiestudio.se/Axiestudiologo.jpg"
                        alt="Axie Studio"
                        className="w-8 h-8 object-contain"
                      />
                    </div>
                    <div>
                      <h4 className="text-lg font-bold text-blue-900 uppercase tracking-wide">AI WORKFLOW STUDIO</h4>
                      <p className="text-blue-700 text-sm">Access your AI workflow platform</p>
                      <p className="text-blue-600 text-xs mt-1">Uses your account credentials for automatic login</p>
                    </div>
                  </div>
                  <LaunchStudioButton
                    className="bg-blue-600 text-white px-6 py-3 font-bold uppercase tracking-wide hover:bg-blue-700 transition-colors border-2 border-blue-700 shadow-md hover:shadow-lg"
                    variant="primary"
                  />
                </div>
              </div>
            </div>

            {/* Subscription Management Card */}
            <div className="bg-white border-2 border-black rounded-none shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] p-6">
              <div className="flex items-center gap-3 mb-6">
                <div className="w-8 h-8 bg-green-600 text-white flex items-center justify-center rounded-none">
                  <Settings className="w-5 h-5" />
                </div>
                <h3 className="text-lg font-bold text-black uppercase tracking-wide">
                  SUBSCRIPTION MANAGEMENT
                </h3>
              </div>
              <SubscriptionManagement />
            </div>

            {/* Account Actions - Danger Zone */}
            <div className="bg-white border-2 border-red-500 rounded-none shadow-[8px_8px_0px_0px_rgba(239,68,68,1)] p-6">
              <div className="flex items-center gap-3 mb-6">
                <div className="w-8 h-8 bg-red-600 text-white flex items-center justify-center rounded-none">
                  <AlertTriangle className="w-5 h-5" />
                </div>
                <h3 className="text-lg font-bold text-red-800 uppercase tracking-wide">
                  DANGER ZONE
                </h3>
              </div>
              
              <div className="bg-red-50 border-2 border-red-200 rounded-none p-6">
                <div className="mb-6">
                  <h4 className="text-lg font-bold text-red-900 mb-3 uppercase tracking-wide">
                    🚨 PERMANENT ACCOUNT DELETION
                  </h4>
                  
                  <div className="space-y-4 text-sm">
                    <div className="bg-red-100 border border-red-300 rounded-none p-4">
                      <p className="font-bold text-red-900 mb-2">⚡ IMMEDIATE EFFECTS:</p>
                      <ul className="text-red-800 space-y-1">
                        <li>• ❌ Account deleted immediately (no grace period)</li>
                        <li>• ❌ All subscription access terminated instantly</li>
                        <li>• ❌ Any remaining subscription time forfeited</li>
                      </ul>
                    </div>

                    <div className="bg-red-200 border border-red-400 rounded-none p-4">
                      <p className="font-bold text-red-900 mb-2">🗑️ DATA CONSEQUENCES:</p>
                      <ul className="text-red-800 space-y-1">
                        <li>• ❌ All account data permanently deleted</li>
                        <li>• ⚠️ AxieStudio account DEACTIVATED (data preserved)</li>
                        <li>• 📧 Contact support to reactivate AxieStudio if you resubscribe</li>
                        <li>• 🚫 This action cannot be undone</li>
                      </ul>
                    </div>

                    <div className="bg-yellow-100 border border-yellow-400 rounded-none p-4">
                      <p className="font-bold text-yellow-900 mb-2">💡 ALTERNATIVES:</p>
                      <ul className="text-yellow-800 space-y-1">
                        <li>• 🔄 Cancel subscription instead (keeps account until period ends)</li>
                        <li>• ⏸️ Downgrade to Standard (pause subscription)</li>
                        <li>• 📞 Contact support for other options</li>
                      </ul>
                    </div>
                  </div>
                </div>
                
                {!showDeleteConfirm ? (
                  <button
                    onClick={() => setShowDeleteConfirm(true)}
                    className="w-full flex items-center justify-center gap-2 bg-red-600 text-white px-6 py-3 rounded-none font-bold hover:bg-red-700 transition-colors uppercase tracking-wide shadow-md hover:shadow-lg"
                  >
                    <Trash2 className="w-5 h-5" />
                    DELETE ACCOUNT PERMANENTLY
                  </button>
                ) : (
                  <div className="space-y-4">
                    <div className="bg-red-600 text-white p-4 rounded-none">
                      <p className="font-bold text-center">
                        ⚠️ ARE YOU ABSOLUTELY SURE?
                      </p>
                      <p className="text-sm text-center mt-2">
                        This action cannot be undone and will permanently delete your account.
                      </p>
                    </div>
                    <div className="flex gap-3">
                      <button
                        onClick={handleDeleteAccount}
                        disabled={isDeleting}
                        className="flex-1 bg-red-600 text-white px-4 py-3 rounded-none font-bold hover:bg-red-700 disabled:opacity-50 uppercase tracking-wide transition-colors"
                      >
                        {isDeleting ? 'DELETING...' : 'YES, DELETE PERMANENTLY'}
                      </button>
                      <button
                        onClick={() => setShowDeleteConfirm(false)}
                        className="flex-1 bg-gray-600 text-white px-4 py-3 rounded-none font-bold hover:bg-gray-700 transition-colors uppercase tracking-wide"
                      >
                        CANCEL
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