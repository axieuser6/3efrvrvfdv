import React, { useState } from 'react';
import { Zap, ExternalLink, Loader2 } from 'lucide-react';
import { supabase } from '../lib/supabase';

interface LaunchStudioOnlyButtonProps {
  className?: string;
}

export function LaunchStudioOnlyButton({ className = '' }: LaunchStudioOnlyButtonProps) {
  const [isLaunching, setIsLaunching] = useState(false);

  const handleLaunchStudio = async () => {
    setIsLaunching(true);
    console.log('🚀 Starting AxieStudio auto-login...');

    try {
      // Get current user session
      const { data: { session }, error: sessionError } = await supabase.auth.getSession();

      if (sessionError || !session) {
        console.error('❌ No active session found');
        // Fallback to manual login
        const loginUrl = `${import.meta.env.VITE_AXIESTUDIO_APP_URL}/login`;
        window.open(loginUrl, '_blank');
        return;
      }

      // Call our auto-login Supabase function
      const { data, error } = await supabase.functions.invoke('axiestudio-auto-login', {
        headers: {
          Authorization: `Bearer ${session.access_token}`,
        },
      });

      if (error) {
        console.error('❌ Auto-login failed:', error);
        // Fallback to manual login
        const loginUrl = `${import.meta.env.VITE_AXIESTUDIO_APP_URL}/login`;
        window.open(loginUrl, '_blank');
        return;
      }

      if (data?.success && data?.redirect_url) {
        console.log('✅ Auto-login successful, redirecting to:', data.redirect_url);
        window.open(data.redirect_url, '_blank');
      } else {
        console.warn('⚠️ Unexpected response, falling back to manual login');
        const loginUrl = `${import.meta.env.VITE_AXIESTUDIO_APP_URL}/login`;
        window.open(loginUrl, '_blank');
      }
    } catch (error) {
      console.error('❌ Launch failed:', error);
      // Fallback to manual login
      const loginUrl = `${import.meta.env.VITE_AXIESTUDIO_APP_URL}/login`;
      window.open(loginUrl, '_blank');
    } finally {
      setIsLaunching(false);
    }
  };

  return (
    <button
      onClick={handleLaunchStudio}
      disabled={isLaunching}
      className={`inline-flex items-center gap-3 px-8 py-4 rounded-none font-bold transition-all duration-300 uppercase tracking-wide border-3 hover:shadow-[6px_6px_0px_0px_rgba(0,0,0,1)] hover:translate-x-[-3px] hover:translate-y-[-3px] bg-black border-black text-white hover:bg-gray-800 hover:border-gray-800 disabled:opacity-50 disabled:cursor-not-allowed ${className}`}
    >
      {isLaunching ? (
        <>
          <Loader2 className="w-5 h-5 animate-spin" />
          LAUNCHING...
          <ExternalLink className="w-4 h-4" />
        </>
      ) : (
        <>
          <Zap className="w-5 h-5" />
          LAUNCH STUDIO
          <ExternalLink className="w-4 h-4" />
        </>
      )}
    </button>
  );
}
