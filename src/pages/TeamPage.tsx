import React from 'react';
import { useAuth } from '../hooks/useAuth';
import { useTeam } from '../hooks/useTeam';
import { TeamManagement } from '../components/TeamManagement';
import { Link } from 'react-router-dom';
import { Users, Crown, ArrowLeft, Settings } from 'lucide-react';

export function TeamPage() {
  const { user } = useAuth();
  const { team, loading, isTeamAdmin, isTeamMember } = useTeam();

  if (!user) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-800 mb-4">Authentication Required</h1>
          <p className="text-gray-600 mb-6">Please log in to access team management.</p>
          <Link
            to="/login"
            className="bg-blue-600 text-white px-6 py-3 rounded-none font-bold hover:bg-blue-700 transition-colors uppercase tracking-wide"
          >
            LOG IN
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white border-b-2 border-black">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-4">
              <Link
                to="/dashboard"
                className="flex items-center gap-2 text-gray-600 hover:text-gray-800 transition-colors"
              >
                <ArrowLeft className="w-5 h-5" />
                <span className="font-medium uppercase tracking-wide">BACK TO DASHBOARD</span>
              </Link>
            </div>
            
            <div className="flex items-center gap-4">
              <span className="text-sm text-gray-600 font-medium uppercase tracking-wide">
                {user.email}
              </span>
              {isTeamAdmin && (
                <span className="bg-blue-600 text-white px-2 py-1 text-xs rounded-none font-bold uppercase tracking-wide">
                  TEAM ADMIN
                </span>
              )}
              {isTeamMember && !isTeamAdmin && (
                <span className="bg-green-600 text-white px-2 py-1 text-xs rounded-none font-bold uppercase tracking-wide">
                  TEAM MEMBER
                </span>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="mb-8">
          <div className="flex items-center gap-4 mb-4">
            <div className="w-12 h-12 bg-blue-600 text-white flex items-center justify-center rounded-none">
              <Users className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-3xl font-bold text-black uppercase tracking-wide">
                TEAM DASHBOARD
              </h1>
              <p className="text-gray-600">
                Manage your team members and settings
              </p>
            </div>
          </div>

          {/* Team Status */}
          {team && (
            <div className="bg-white border-2 border-black rounded-none shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] p-6 mb-8">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-xl font-bold text-black uppercase tracking-wide mb-2">
                    {team.name}
                  </h2>
                  <div className="flex items-center gap-6 text-sm">
                    <span className="text-gray-600">
                      <strong>Members:</strong> {team.current_members}/{team.max_members}
                    </span>
                    <span className="text-gray-600">
                      <strong>Status:</strong> {team.status.toUpperCase()}
                    </span>
                    {isTeamAdmin && (
                      <span className="flex items-center gap-1 text-blue-600">
                        <Crown className="w-4 h-4" />
                        <strong>ADMIN</strong>
                      </span>
                    )}
                  </div>
                </div>
                
                {isTeamAdmin && (
                  <div className="flex gap-3">
                    <Link
                      to="/account"
                      className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-none font-bold hover:bg-blue-700 transition-colors uppercase tracking-wide"
                    >
                      <Settings className="w-4 h-4" />
                      BILLING
                    </Link>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* No Team Message */}
          {!loading && !team && !isTeamMember && (
            <div className="bg-white border-2 border-black rounded-none shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] p-8 mb-8">
              <div className="text-center">
                <Users className="w-16 h-16 text-gray-400 mx-auto mb-4" />
                <h2 className="text-2xl font-bold text-gray-800 mb-4 uppercase tracking-wide">
                  NO TEAM FOUND
                </h2>
                <p className="text-gray-600 mb-6">
                  You are not part of any team. Subscribe to Team Pro to create and manage a team with up to 5 members.
                </p>
                <div className="flex gap-4 justify-center">
                  <Link
                    to="/products"
                    className="bg-blue-600 text-white px-6 py-3 rounded-none font-bold hover:bg-blue-700 transition-colors uppercase tracking-wide"
                  >
                    VIEW TEAM PLANS
                  </Link>
                  <Link
                    to="/dashboard"
                    className="bg-gray-600 text-white px-6 py-3 rounded-none font-bold hover:bg-gray-700 transition-colors uppercase tracking-wide"
                  >
                    BACK TO DASHBOARD
                  </Link>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Team Management Component */}
        {(team || isTeamMember) && <TeamManagement />}

        {/* Team Features Info */}
        {(team || isTeamMember) && (
          <div className="mt-8 bg-white border-2 border-black rounded-none shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] p-6">
            <h3 className="text-lg font-bold text-black uppercase tracking-wide mb-4">
              TEAM FEATURES
            </h3>
            <div className="grid md:grid-cols-2 gap-6">
              <div>
                <h4 className="font-bold text-gray-800 mb-2 uppercase tracking-wide">
                  FOR TEAM ADMINS:
                </h4>
                <ul className="text-sm text-gray-600 space-y-1">
                  <li>• Create up to 5 team member accounts</li>
                  <li>• Manage member passwords and access</li>
                  <li>• Centralized billing and subscription management</li>
                  <li>• Team usage analytics and reporting</li>
                  <li>• Full administrative control</li>
                </ul>
              </div>
              <div>
                <h4 className="font-bold text-gray-800 mb-2 uppercase tracking-wide">
                  FOR TEAM MEMBERS:
                </h4>
                <ul className="text-sm text-gray-600 space-y-1">
                  <li>• Full access to all Pro features</li>
                  <li>• Individual AxieStudio accounts</li>
                  <li>• Personal workflow management</li>
                  <li>• Team collaboration tools</li>
                  <li>• Priority support included</li>
                </ul>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
