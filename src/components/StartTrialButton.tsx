import React, { useState } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../hooks/useAuth';
import { Play, Loader2, Gift } from 'lucide-react';

interface StartTrialButtonProps {
  onTrialStarted?: () => void;
  className?: string;
}

export function StartTrialButton({ onTrialStarted, className = '' }: StartTrialButtonProps) {
  const { user } = useAuth();
  const [isStarting, setIsStarting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleStartTrial = async () => {
    if (!user) {
      setError('Please log in to start your trial');
      return;
    }

    setIsStarting(true);
    setError(null);

    try {
      console.log('🚀 Starting 7-day free trial for user:', user.id);

      // Call the start-trial function
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        throw new Error('No active session found');
      }

      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/start-trial`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({
          user_id: user.id
        }),
      });

      const result = await response.json();

      if (!response.ok || !result.success) {
        throw new Error(result.error || 'Failed to start trial');
      }

      console.log('✅ Trial started successfully:', result);

      // Notify parent component
      if (onTrialStarted) {
        onTrialStarted();
      }

      // Refresh the page to update all components
      window.location.reload();

    } catch (error: any) {
      console.error('❌ Failed to start trial:', error);
      setError(error.message || 'Failed to start trial');
    } finally {
      setIsStarting(false);
    }
  };

  return (
    <div className={className}>
      {error && (
        <div className="bg-red-50 border-2 border-red-200 rounded-none p-4 mb-4">
          <p className="text-red-800 font-medium text-sm">{error}</p>
        </div>
      )}
      
      <button
        onClick={handleStartTrial}
        disabled={isStarting}
        className="w-full bg-gradient-to-r from-green-500 to-blue-500 text-white py-4 px-8 rounded-none font-bold hover:from-green-600 hover:to-blue-600 transition-all duration-300 uppercase tracking-wide border-2 border-green-600 shadow-[4px_4px_0px_0px_rgba(34,197,94,1)] hover:shadow-[6px_6px_0px_0px_rgba(34,197,94,1)] hover:translate-x-[-2px] hover:translate-y-[-2px] disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-3"
      >
        {isStarting ? (
          <>
            <Loader2 className="w-5 h-5 animate-spin" />
            STARTING TRIAL...
          </>
        ) : (
          <>
            <Gift className="w-5 h-5" />
            START 7-DAY FREE TRIAL
            <Play className="w-4 h-4" />
          </>
        )}
      </button>
      
      <div className="mt-3 text-center">
        <p className="text-sm text-gray-600">
          ✨ Get instant access to all premium AI workflow features
        </p>
        <p className="text-xs text-gray-500 mt-1">
          No credit card required • Cancel anytime
        </p>
      </div>
    </div>
  );
}