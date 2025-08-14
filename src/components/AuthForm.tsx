import React, { useState } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { Eye, EyeOff, Mail, Lock, AlertCircle, CheckCircle } from 'lucide-react';

interface AuthFormProps {
  mode: 'login' | 'signup';
  onToggleMode: () => void;
}

export function AuthForm({ mode, onToggleMode }: AuthFormProps) {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<{ type: 'error' | 'success' | 'warning'; text: string } | null>(null);

  // Get redirect parameter from URL
  const redirectTo = searchParams.get('redirect') || '/dashboard';

  // Function to check if email has been used before
  const checkEmailHistory = async (email: string) => {
    try {
      const { data, error } = await supabase.rpc('check_email_trial_history', { p_email: email });

      if (error) {
        console.error('Error checking email history:', error);
        return false;
      }

      if (data && data.length > 0) {
        const history = data[0];
        if (history.has_used_trial) {
          return true;
        }
      }

      return false;
    } catch (error) {
      console.error('Error checking email history:', error);
      return false;
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setMessage(null);

    try {
      if (mode === 'signup') {
        // First check if this email has been used before
        const isReturning = await checkEmailHistory(email);

        const { error } = await supabase.auth.signUp({
          email,
          password,
          options: {
            emailRedirectTo: `${window.location.origin}${redirectTo}`,
          },
        });

        if (error) throw error;

        console.log('✅ Supabase account created successfully.');

        if (isReturning) {
          setMessage({
            type: 'warning',
            text: `Welcome back! Please check your email and click the confirmation link to reactivate your account. No free trial is available for returning users.`,
          });
        } else {
          setMessage({
            type: 'success',
            text: `Account created successfully! Please check your email and click the confirmation link to activate your account and start your 7-day free trial.`,
          });
        }
      } else {
        const { error } = await supabase.auth.signInWithPassword({
          email,
          password,
        });

        if (error) throw error;

        // Redirect to the specified page after successful login
        navigate(redirectTo);
      }
    } catch (error: any) {
      setMessage({
        type: 'error',
        text: error.message || 'An error occurred',
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-white flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-white border-2 border-black rounded-none shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] p-8">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-20 h-20 bg-white border-2 border-black rounded-none mb-4">
            <img
              src="https://www.axiestudio.se/Axiestudiologo.jpg"
              alt="Axie Studio"
              className="w-16 h-16 object-contain"
            />
          </div>
          <h1 className="text-3xl font-bold text-black mb-2">
            AXIE STUDIO
          </h1>
          <h2 className="text-xl font-bold text-black mb-2">
            {mode === 'login' ? 'SIGN IN' : 'SIGN UP'}
          </h2>
          <p className="text-gray-600">
            {mode === 'login'
              ? 'Access your AI workflow platform'
              : 'Join the AI workflow revolution'
            }
          </p>
        </div>

        {message && (
          <div className={`mb-6 p-4 border-2 border-black rounded-none flex items-center gap-3 ${
            message.type === 'error'
              ? 'bg-red-100 text-red-800'
              : message.type === 'warning'
              ? 'bg-yellow-100 text-yellow-800'
              : 'bg-green-100 text-green-800'
          }`}>
            {message.type === 'error' ? (
              <AlertCircle className="w-5 h-5 flex-shrink-0" />
            ) : message.type === 'warning' ? (
              <AlertCircle className="w-5 h-5 flex-shrink-0" />
            ) : (
              <CheckCircle className="w-5 h-5 flex-shrink-0" />
            )}
            <span className="text-sm font-medium">{message.text}</span>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label htmlFor="email" className="block text-sm font-bold text-black mb-2 uppercase tracking-wide">
              Email
            </label>
            <div className="relative">
              <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-600" />
              <input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                className="w-full pl-10 pr-4 py-3 border-2 border-black rounded-none focus:outline-none focus:ring-0 focus:border-gray-600 transition-colors bg-white"
                placeholder="your@email.com"
              />
            </div>
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-bold text-black mb-2 uppercase tracking-wide">
              Password
            </label>
            <div className="relative">
              <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-600" />
              <input
                id="password"
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                minLength={6}
                className="w-full pl-10 pr-12 py-3 border-2 border-black rounded-none focus:outline-none focus:ring-0 focus:border-gray-600 transition-colors bg-white"
                placeholder="••••••••"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-600 hover:text-black transition-colors"
              >
                {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
              </button>
            </div>
            {mode === 'signup' && (
              <p className="mt-1 text-xs text-gray-500 uppercase tracking-wide">
                Min 6 characters
              </p>
            )}
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-black text-white py-3 px-4 rounded-none font-bold uppercase tracking-wide hover:bg-gray-800 focus:outline-none focus:ring-0 disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 border-2 border-black hover:shadow-[4px_4px_0px_0px_rgba(0,0,0,0.3)]"
          >
            {loading ? (
              <div className="flex items-center justify-center gap-2">
                <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                {mode === 'login' ? 'SIGNING IN...' : 'CREATING...'}
              </div>
            ) : (
              mode === 'login' ? 'SIGN IN' : 'CREATE ACCOUNT'
            )}
          </button>
        </form>

        <div className="mt-8 text-center">
          <p className="text-gray-600">
            {mode === 'login' ? "Don't have an account?" : 'Already have an account?'}
          </p>
          <button
            onClick={onToggleMode}
            className="mt-2 text-black font-bold hover:underline transition-all uppercase tracking-wide"
          >
            {mode === 'login' ? 'SIGN UP' : 'SIGN IN'}
          </button>
        </div>
      </div>
    </div>
  );
}