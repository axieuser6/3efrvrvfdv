import React, { useState } from 'react';
import { useTeam } from '../hooks/useTeam';
import { useUserAccess } from '../hooks/useUserAccess';
import { useSubscription } from '../hooks/useSubscription';
import { Users, Plus, Key, Trash2, Eye, EyeOff, Crown, Settings, AlertTriangle } from 'lucide-react';

export function TeamDashboardSection() {
  const { accessStatus } = useUserAccess();
  const { subscription } = useSubscription();
  const { 
    team, 
    teamMembers, 
    loading, 
    error, 
    isTeamAdmin, 
    isTeamMember,
    createTeamMember, 
    updateMemberPassword, 
    removeMember 
  } = useTeam();

  const [showCreateForm, setShowCreateForm] = useState(false);
  const [showPasswordForm, setShowPasswordForm] = useState<string | null>(null);
  const [showPasswords, setShowPasswords] = useState<{[key: string]: boolean}>({});
  const [creating, setCreating] = useState(false);
  const [updatingPassword, setUpdatingPassword] = useState(false);

  const [formData, setFormData] = useState({
    email: '',
    password: '',
    displayName: ''
  });

  const [passwordData, setPasswordData] = useState({
    newPassword: ''
  });

  // Only show for Team Pro subscribers or team members
  const hasTeamSubscription = accessStatus?.is_team_subscription ||
                              subscription?.price_id === 'price_1RwP9cBacFXEnBmNsM3xVLL2' ||
                              subscription?.price_id === 'price_1RwOhVBacFXEnBmNIeWQ1wQe';
  const shouldShow = hasTeamSubscription || isTeamMember;

  console.log('🔍 Team Dashboard Debug:', {
    hasTeamSubscription,
    isTeamMember,
    shouldShow,
    subscriptionPriceId: subscription?.price_id,
    accessStatus: accessStatus?.is_team_subscription
  });

  if (!shouldShow || loading) {
    return null;
  }

  const handleCreateMember = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.email || !formData.password) return;

    try {
      setCreating(true);
      await createTeamMember(formData.email, formData.password, formData.displayName);
      setFormData({ email: '', password: '', displayName: '' });
      setShowCreateForm(false);
    } catch (err) {
      console.error('Error creating team member:', err);
      alert(err instanceof Error ? err.message : 'Failed to create team member');
    } finally {
      setCreating(false);
    }
  };

  const handleUpdatePassword = async (memberId: string) => {
    if (!passwordData.newPassword) return;

    try {
      setUpdatingPassword(true);
      await updateMemberPassword(memberId, passwordData.newPassword);
      setPasswordData({ newPassword: '' });
      setShowPasswordForm(null);
      alert('Password updated successfully!');
    } catch (err) {
      console.error('Error updating password:', err);
      alert(err instanceof Error ? err.message : 'Failed to update password');
    } finally {
      setUpdatingPassword(false);
    }
  };

  const handleRemoveMember = async (memberId: string, memberEmail: string) => {
    if (!confirm(`Are you sure you want to permanently delete the account for ${memberEmail}? This action cannot be undone and will remove all their data.`)) {
      return;
    }

    try {
      await removeMember(memberId);
      alert('Team member account deleted successfully');
    } catch (err) {
      console.error('Error removing member:', err);
      alert(err instanceof Error ? err.message : 'Failed to remove team member');
    }
  };

  const togglePasswordVisibility = (memberId: string) => {
    setShowPasswords(prev => ({
      ...prev,
      [memberId]: !prev[memberId]
    }));
  };

  const generatePassword = () => {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
    let password = '';
    for (let i = 0; i < 12; i++) {
      password += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    setFormData(prev => ({ ...prev, password }));
  };

  return (
    <div className="bg-white border-2 border-black rounded-none shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] p-8 mb-8">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-blue-600 text-white flex items-center justify-center rounded-none">
            <Users className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-xl font-bold text-black uppercase tracking-wide">
              TEAM MANAGEMENT
            </h3>
            <p className="text-gray-600 text-sm">
              {isTeamAdmin ? 'Manage your team members and accounts' : `Member of ${team?.name}`}
            </p>
          </div>
        </div>

        {isTeamAdmin && (
          <div className="flex items-center gap-2">
            <span className="flex items-center gap-1 text-blue-600 text-sm font-bold">
              <Crown className="w-4 h-4" />
              ADMIN
            </span>
          </div>
        )}
      </div>

      {error && (
        <div className="bg-red-50 border-2 border-red-200 rounded-none p-4 mb-6">
          <p className="text-red-800 font-bold">Error: {error}</p>
        </div>
      )}

      {/* Team Status */}
      {team && (
        <div className="bg-gray-50 border-2 border-gray-200 rounded-none p-4 mb-6">
          <div className="grid md:grid-cols-3 gap-4 text-sm">
            <div>
              <p className="font-bold text-gray-800 uppercase tracking-wide">TEAM NAME:</p>
              <p className="text-gray-600">{team.name}</p>
            </div>
            <div>
              <p className="font-bold text-gray-800 uppercase tracking-wide">MEMBERS:</p>
              <p className="text-gray-600">{team.current_members}/{team.max_members}</p>
            </div>
            <div>
              <p className="font-bold text-gray-800 uppercase tracking-wide">STATUS:</p>
              <p className="text-green-600 font-bold">{team.status.toUpperCase()}</p>
            </div>
          </div>
        </div>
      )}

      {/* Add Member Form (Admin Only) */}
      {isTeamAdmin && team && team.current_members < team.max_members && (
        <div className="mb-6">
          {!showCreateForm ? (
            <button
              onClick={() => setShowCreateForm(true)}
              className="flex items-center gap-2 bg-green-600 text-white px-6 py-3 rounded-none font-bold hover:bg-green-700 transition-colors uppercase tracking-wide"
            >
              <Plus className="w-4 h-4" />
              ADD TEAM MEMBER
            </button>
          ) : (
            <div className="bg-green-50 border-2 border-green-200 rounded-none p-6">
              <h4 className="text-lg font-bold text-green-900 mb-4 uppercase tracking-wide">
                CREATE NEW TEAM MEMBER
              </h4>
              <form onSubmit={handleCreateMember} className="space-y-4">
                <div className="grid md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-bold text-green-900 mb-2 uppercase tracking-wide">
                      EMAIL ADDRESS *
                    </label>
                    <input
                      type="email"
                      value={formData.email}
                      onChange={(e) => setFormData(prev => ({ ...prev, email: e.target.value }))}
                      placeholder="member@company.com"
                      className="w-full px-3 py-2 border-2 border-green-300 rounded-none focus:border-green-600 focus:outline-none"
                      required
                    />
                  </div>
                  <div>
                    <label className="block text-sm font-bold text-green-900 mb-2 uppercase tracking-wide">
                      DISPLAY NAME
                    </label>
                    <input
                      type="text"
                      value={formData.displayName}
                      onChange={(e) => setFormData(prev => ({ ...prev, displayName: e.target.value }))}
                      placeholder="John Doe"
                      className="w-full px-3 py-2 border-2 border-green-300 rounded-none focus:border-green-600 focus:outline-none"
                    />
                  </div>
                </div>
                <div>
                  <label className="block text-sm font-bold text-green-900 mb-2 uppercase tracking-wide">
                    PASSWORD *
                  </label>
                  <div className="flex gap-2">
                    <input
                      type="text"
                      value={formData.password}
                      onChange={(e) => setFormData(prev => ({ ...prev, password: e.target.value }))}
                      placeholder="Enter secure password"
                      className="flex-1 px-3 py-2 border-2 border-green-300 rounded-none focus:border-green-600 focus:outline-none"
                      required
                    />
                    <button
                      type="button"
                      onClick={generatePassword}
                      className="bg-green-600 text-white px-4 py-2 rounded-none font-bold hover:bg-green-700 transition-colors uppercase tracking-wide text-sm"
                    >
                      GENERATE
                    </button>
                  </div>
                </div>
                <div className="flex gap-3">
                  <button
                    type="submit"
                    disabled={creating || !formData.email || !formData.password}
                    className="bg-green-600 text-white px-6 py-2 rounded-none font-bold hover:bg-green-700 disabled:bg-green-400 transition-colors uppercase tracking-wide"
                  >
                    {creating ? 'CREATING...' : 'CREATE MEMBER'}
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      setShowCreateForm(false);
                      setFormData({ email: '', password: '', displayName: '' });
                    }}
                    className="bg-gray-600 text-white px-6 py-2 rounded-none font-bold hover:bg-gray-700 transition-colors uppercase tracking-wide"
                  >
                    CANCEL
                  </button>
                </div>
              </form>
            </div>
          )}
        </div>
      )}

      {/* Team Members List */}
      <div>
        <h4 className="text-lg font-bold text-black mb-4 uppercase tracking-wide">
          TEAM MEMBERS ({teamMembers.length})
        </h4>
        
        {teamMembers.length === 0 ? (
          <div className="text-center py-8">
            <Users className="w-12 h-12 text-gray-400 mx-auto mb-4" />
            <p className="text-gray-600">No team members yet.</p>
            {isTeamAdmin && (
              <p className="text-gray-500 text-sm mt-2">Create your first team member to get started.</p>
            )}
          </div>
        ) : (
          <div className="space-y-3">
            {teamMembers.map((member) => (
              <div key={member.id} className="bg-gray-50 border-2 border-gray-200 rounded-none p-4">
                <div className="flex items-center justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-3 mb-2">
                      <p className="font-bold text-gray-800">
                        {member.display_name || member.full_name || member.email}
                      </p>
                      {member.role === 'admin' && (
                        <span className="flex items-center gap-1 text-blue-600 text-xs font-bold">
                          <Crown className="w-3 h-3" />
                          ADMIN
                        </span>
                      )}
                    </div>
                    <p className="text-sm text-gray-600">{member.email}</p>
                    <p className="text-xs text-gray-500 uppercase tracking-wide">
                      {member.role} • {member.status}
                    </p>
                  </div>

                  {/* Admin Controls */}
                  {isTeamAdmin && member.role !== 'admin' && (
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => setShowPasswordForm(showPasswordForm === member.id ? null : member.id)}
                        className="flex items-center gap-1 bg-blue-600 text-white px-3 py-1 rounded-none font-bold hover:bg-blue-700 transition-colors uppercase tracking-wide text-xs"
                      >
                        <Key className="w-3 h-3" />
                        PASSWORD
                      </button>
                      <button
                        onClick={() => handleRemoveMember(member.id, member.email || 'Unknown')}
                        className="flex items-center gap-1 bg-red-600 text-white px-3 py-1 rounded-none font-bold hover:bg-red-700 transition-colors uppercase tracking-wide text-xs"
                      >
                        <Trash2 className="w-3 h-3" />
                        DELETE
                      </button>
                    </div>
                  )}
                </div>

                {/* Password Update Form */}
                {showPasswordForm === member.id && (
                  <div className="mt-4 pt-4 border-t-2 border-gray-300">
                    <div className="bg-blue-50 border-2 border-blue-200 rounded-none p-4">
                      <h5 className="font-bold text-blue-900 mb-3 uppercase tracking-wide">
                        UPDATE PASSWORD FOR {member.email}
                      </h5>
                      <div className="flex gap-2">
                        <input
                          type="text"
                          value={passwordData.newPassword}
                          onChange={(e) => setPasswordData({ newPassword: e.target.value })}
                          placeholder="Enter new password"
                          className="flex-1 px-3 py-2 border-2 border-blue-300 rounded-none focus:border-blue-600 focus:outline-none"
                        />
                        <button
                          onClick={() => handleUpdatePassword(member.id)}
                          disabled={updatingPassword || !passwordData.newPassword}
                          className="bg-blue-600 text-white px-4 py-2 rounded-none font-bold hover:bg-blue-700 disabled:bg-blue-400 transition-colors uppercase tracking-wide text-sm"
                        >
                          {updatingPassword ? 'UPDATING...' : 'UPDATE'}
                        </button>
                        <button
                          onClick={() => {
                            setShowPasswordForm(null);
                            setPasswordData({ newPassword: '' });
                          }}
                          className="bg-gray-600 text-white px-4 py-2 rounded-none font-bold hover:bg-gray-700 transition-colors uppercase tracking-wide text-sm"
                        >
                          CANCEL
                        </button>
                      </div>
                      <div className="mt-2">
                        <p className="text-xs text-blue-700">
                          <AlertTriangle className="w-3 h-3 inline mr-1" />
                          The member will need to use this new password to log in.
                        </p>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Team Features Info */}
      <div className="mt-6 pt-6 border-t-2 border-gray-200">
        <h4 className="text-lg font-bold text-black mb-4 uppercase tracking-wide">
          TEAM BENEFITS
        </h4>
        <div className="grid md:grid-cols-2 gap-6 text-sm">
          <div>
            <h5 className="font-bold text-gray-800 mb-2 uppercase tracking-wide">
              FOR TEAM ADMINS:
            </h5>
            <ul className="text-gray-600 space-y-1">
              <li>• Create up to 5 team member accounts</li>
              <li>• Manage member passwords and access</li>
              <li>• Delete member accounts completely</li>
              <li>• Centralized billing and subscription management</li>
              <li>• Full administrative control</li>
            </ul>
          </div>
          <div>
            <h5 className="font-bold text-gray-800 mb-2 uppercase tracking-wide">
              FOR TEAM MEMBERS:
            </h5>
            <ul className="text-gray-600 space-y-1">
              <li>• Full Pro feature access</li>
              <li>• AxieStudio account included</li>
              <li>• No individual billing required</li>
              <li>• Team collaboration tools</li>
              <li>• Shared team dashboard</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}
