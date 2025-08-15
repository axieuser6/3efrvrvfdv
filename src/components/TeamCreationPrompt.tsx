import React, { useState } from 'react';
import { useTeam } from '../hooks/useTeam';
import { useUserAccess } from '../hooks/useUserAccess';
import { Users, Plus } from 'lucide-react';

export function TeamCreationPrompt() {
  const { accessStatus } = useUserAccess();
  const { team, createTeam, loading } = useTeam();
  const [showCreateForm, setShowCreateForm] = useState(false);
  const [teamName, setTeamName] = useState('');
  const [creating, setCreating] = useState(false);

  // Only show if user has team subscription but no team
  const hasTeamSubscription = accessStatus?.is_team_subscription;
  const shouldShowPrompt = hasTeamSubscription && !team && !loading;

  if (!shouldShowPrompt) {
    return null;
  }

  const handleCreateTeam = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!teamName.trim()) return;

    try {
      setCreating(true);
      await createTeam(teamName.trim());
      setTeamName('');
      setShowCreateForm(false);
    } catch (err) {
      console.error('Error creating team:', err);
      alert(err instanceof Error ? err.message : 'Failed to create team');
    } finally {
      setCreating(false);
    }
  };

  return (
    <div className="bg-blue-50 border-2 border-blue-200 rounded-none p-6 mb-6">
      <div className="flex items-center gap-4 mb-4">
        <div className="w-12 h-12 bg-blue-600 text-white flex items-center justify-center rounded-none">
          <Users className="w-6 h-6" />
        </div>
        <div>
          <h3 className="text-xl font-bold text-blue-900 uppercase tracking-wide">
            TEAM SUBSCRIPTION ACTIVE
          </h3>
          <p className="text-blue-700 text-sm">
            You have a Team Pro subscription! Create your team to start managing members.
          </p>
        </div>
      </div>

      {!showCreateForm ? (
        <button
          onClick={() => setShowCreateForm(true)}
          className="flex items-center gap-2 bg-blue-600 text-white px-6 py-3 rounded-none font-bold hover:bg-blue-700 transition-colors uppercase tracking-wide"
        >
          <Plus className="w-5 h-5" />
          CREATE YOUR TEAM
        </button>
      ) : (
        <form onSubmit={handleCreateTeam} className="space-y-4">
          <div>
            <label className="block text-sm font-bold text-blue-900 mb-2 uppercase tracking-wide">
              TEAM NAME
            </label>
            <input
              type="text"
              value={teamName}
              onChange={(e) => setTeamName(e.target.value)}
              placeholder="Enter your team name"
              className="w-full px-3 py-2 border-2 border-blue-300 rounded-none focus:border-blue-600 focus:outline-none"
              required
              maxLength={50}
            />
          </div>
          <div className="flex gap-3">
            <button
              type="submit"
              disabled={creating || !teamName.trim()}
              className="bg-blue-600 text-white px-6 py-2 rounded-none font-bold hover:bg-blue-700 disabled:bg-blue-400 transition-colors uppercase tracking-wide"
            >
              {creating ? 'CREATING...' : 'CREATE TEAM'}
            </button>
            <button
              type="button"
              onClick={() => {
                setShowCreateForm(false);
                setTeamName('');
              }}
              className="bg-gray-600 text-white px-6 py-2 rounded-none font-bold hover:bg-gray-700 transition-colors uppercase tracking-wide"
            >
              CANCEL
            </button>
          </div>
        </form>
      )}
    </div>
  );
}
