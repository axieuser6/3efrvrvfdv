import React, { useState } from 'react';
import { useTeam } from '../hooks/useTeam';
import { Users, Plus, Settings, Trash2, Key, Eye, EyeOff } from 'lucide-react';

export function TeamManagement() {
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
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    displayName: ''
  });
  const [newPassword, setNewPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [creating, setCreating] = useState(false);
  const [updatingPassword, setUpdatingPassword] = useState(false);

  if (loading) {
    return (
      <div className="bg-white border-2 border-black rounded-none shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] p-8">
        <div className="text-center">
          <div className="animate-spin w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full mx-auto mb-4"></div>
          <p className="text-gray-600">Loading team data...</p>
        </div>
      </div>
    );
  }

  if (!team && !isTeamMember) {
    return (
      <div className="bg-white border-2 border-black rounded-none shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] p-8">
        <div className="text-center">
          <Users className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <h3 className="text-xl font-bold text-gray-800 mb-2 uppercase tracking-wide">
            NO TEAM FOUND
          </h3>
          <p className="text-gray-600 mb-6">
            You are not part of any team. Subscribe to Team Pro to create and manage a team.
          </p>
        </div>
      </div>
    );
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
    if (!newPassword) return;

    try {
      setUpdatingPassword(true);
      await updateMemberPassword(memberId, newPassword);
      setNewPassword('');
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
    if (!confirm(`Are you sure you want to remove ${memberEmail} from the team?`)) return;

    try {
      await removeMember(memberId);
      alert('Team member removed successfully!');
    } catch (err) {
      console.error('Error removing member:', err);
      alert(err instanceof Error ? err.message : 'Failed to remove team member');
    }
  };

  return (
    <div className="bg-white border-2 border-black rounded-none shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] p-8">
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
              {team?.name} • {team?.current_members}/{team?.max_members} members
            </p>
          </div>
        </div>

        {isTeamAdmin && team && team.current_members < team.max_members && (
          <button
            onClick={() => setShowCreateForm(!showCreateForm)}
            className="flex items-center gap-2 bg-green-600 text-white px-4 py-2 rounded-none font-bold hover:bg-green-700 transition-colors uppercase tracking-wide"
          >
            <Plus className="w-4 h-4" />
            ADD MEMBER
          </button>
        )}
      </div>

      {error && (
        <div className="bg-red-50 border-2 border-red-200 rounded-none p-4 mb-6">
          <p className="text-red-800 font-bold">Error: {error}</p>
        </div>
      )}

      {/* Create Member Form */}
      {showCreateForm && isTeamAdmin && (
        <div className="bg-gray-50 border-2 border-gray-200 rounded-none p-6 mb-6">
          <h4 className="font-bold text-gray-800 uppercase tracking-wide mb-4">CREATE NEW TEAM MEMBER</h4>
          <form onSubmit={handleCreateMember} className="space-y-4">
            <div>
              <label className="block text-sm font-bold text-gray-700 mb-2 uppercase tracking-wide">
                EMAIL ADDRESS
              </label>
              <input
                type="email"
                value={formData.email}
                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                className="w-full px-3 py-2 border-2 border-gray-300 rounded-none focus:border-blue-600 focus:outline-none"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-bold text-gray-700 mb-2 uppercase tracking-wide">
                PASSWORD
              </label>
              <div className="relative">
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={formData.password}
                  onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                  className="w-full px-3 py-2 border-2 border-gray-300 rounded-none focus:border-blue-600 focus:outline-none pr-10"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-2 top-2 text-gray-500 hover:text-gray-700"
                >
                  {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                </button>
              </div>
            </div>
            <div>
              <label className="block text-sm font-bold text-gray-700 mb-2 uppercase tracking-wide">
                DISPLAY NAME (OPTIONAL)
              </label>
              <input
                type="text"
                value={formData.displayName}
                onChange={(e) => setFormData({ ...formData, displayName: e.target.value })}
                className="w-full px-3 py-2 border-2 border-gray-300 rounded-none focus:border-blue-600 focus:outline-none"
              />
            </div>
            <div className="flex gap-3">
              <button
                type="submit"
                disabled={creating}
                className="bg-green-600 text-white px-4 py-2 rounded-none font-bold hover:bg-green-700 disabled:bg-green-400 transition-colors uppercase tracking-wide"
              >
                {creating ? 'CREATING...' : 'CREATE MEMBER'}
              </button>
              <button
                type="button"
                onClick={() => setShowCreateForm(false)}
                className="bg-gray-600 text-white px-4 py-2 rounded-none font-bold hover:bg-gray-700 transition-colors uppercase tracking-wide"
              >
                CANCEL
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Team Members List */}
      <div className="space-y-4">
        <h4 className="font-bold text-gray-800 uppercase tracking-wide">TEAM MEMBERS</h4>
        
        {teamMembers.length === 0 ? (
          <div className="text-center py-8">
            <Users className="w-12 h-12 text-gray-400 mx-auto mb-4" />
            <p className="text-gray-600">No team members yet.</p>
          </div>
        ) : (
          <div className="space-y-3">
            {teamMembers.map((member) => (
              <div key={member.id} className="bg-gray-50 border-2 border-gray-200 rounded-none p-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="font-bold text-gray-800">
                      {member.display_name || member.full_name || member.email}
                    </p>
                    <p className="text-sm text-gray-600">{member.email}</p>
                    <p className="text-xs text-gray-500 uppercase tracking-wide">
                      {member.role} • {member.status}
                    </p>
                  </div>
                  
                  {isTeamAdmin && (
                    <div className="flex gap-2">
                      <button
                        onClick={() => setShowPasswordForm(member.id)}
                        className="bg-blue-600 text-white p-2 rounded-none hover:bg-blue-700 transition-colors"
                        title="Change Password"
                      >
                        <Key className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleRemoveMember(member.id, member.email || '')}
                        className="bg-red-600 text-white p-2 rounded-none hover:bg-red-700 transition-colors"
                        title="Remove Member"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  )}
                </div>

                {/* Password Update Form */}
                {showPasswordForm === member.id && (
                  <div className="mt-4 pt-4 border-t-2 border-gray-300">
                    <div className="flex gap-3">
                      <input
                        type="password"
                        value={newPassword}
                        onChange={(e) => setNewPassword(e.target.value)}
                        placeholder="New password"
                        className="flex-1 px-3 py-2 border-2 border-gray-300 rounded-none focus:border-blue-600 focus:outline-none"
                      />
                      <button
                        onClick={() => handleUpdatePassword(member.id)}
                        disabled={updatingPassword || !newPassword}
                        className="bg-blue-600 text-white px-4 py-2 rounded-none font-bold hover:bg-blue-700 disabled:bg-blue-400 transition-colors uppercase tracking-wide"
                      >
                        {updatingPassword ? 'UPDATING...' : 'UPDATE'}
                      </button>
                      <button
                        onClick={() => {
                          setShowPasswordForm(null);
                          setNewPassword('');
                        }}
                        className="bg-gray-600 text-white px-4 py-2 rounded-none font-bold hover:bg-gray-700 transition-colors uppercase tracking-wide"
                      >
                        CANCEL
                      </button>
                    </div>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
