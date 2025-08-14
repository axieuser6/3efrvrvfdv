import React, { useState } from 'react';
import { useAuth } from '../hooks/useAuth';
import { supabase } from '../lib/supabase';
import { CreateAxieStudioButton } from '../components/CreateAxieStudioButton';
import { LaunchStudioOnlyButton } from '../components/LaunchStudioOnlyButton';
import { ArrowLeft, UserPlus, Trash2, TestTube, CheckCircle, XCircle, Loader2, Zap } from 'lucide-react';
import { Link } from 'react-router-dom';

interface TestResult {
  id: string;
  type: 'info' | 'success' | 'error';
  message: string;
  timestamp: Date;
}

export function AxieStudioTestPage() {
  const { user } = useAuth();
  const [testResults, setTestResults] = useState<TestResult[]>([]);
  const [isCreating, setIsCreating] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [testEmail, setTestEmail] = useState('test-user@example.com');
  const [testPassword, setTestPassword] = useState('TestPassword123!');

  const addTestResult = (type: TestResult['type'], message: string) => {
    const result: TestResult = {
      id: Date.now().toString(),
      type,
      message,
      timestamp: new Date()
    };
    setTestResults(prev => [result, ...prev]);
  };

  const clearResults = () => {
    setTestResults([]);
  };

  const testCreateAccount = async () => {
    if (!user) {
      addTestResult('error', 'No authenticated user found');
      return;
    }

    setIsCreating(true);
    addTestResult('info', `🔄 Testing account creation for: ${testEmail}`);

    try {
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session) {
        addTestResult('error', '❌ No active session found');
        return;
      }

      addTestResult('info', '🔐 Session found, calling AxieStudio API...');

      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/axie-studio-account`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({
          action: 'create',
          email: testEmail,
          password: testPassword
        }),
      });

      const result = await response.json();

      if (response.ok && result.success) {
        addTestResult('success', '✅ AxieStudio account created successfully!');
        addTestResult('info', `👤 User ID: ${result.user_id}`);
        addTestResult('info', `📧 Email: ${result.email}`);
        addTestResult('info', '🎉 Account creation test PASSED!');
      } else {
        addTestResult('error', `❌ Creation failed: ${result.error || 'Unknown error'}`);
      }

    } catch (error: any) {
      addTestResult('error', `❌ Error: ${error.message}`);
    } finally {
      setIsCreating(false);
    }
  };

  const testDeleteAccount = async () => {
    if (!user) {
      addTestResult('error', 'No authenticated user found');
      return;
    }

    setIsDeleting(true);
    addTestResult('info', `🗑️ Testing account deletion for: ${testEmail}`);

    try {
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session) {
        addTestResult('error', '❌ No active session found');
        return;
      }

      addTestResult('info', '🔐 Session found, calling deletion API...');

      const response = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/axie-studio-account`, {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${session.access_token}`,
        }
      });

      const result = await response.json();

      if (response.ok && result.success) {
        addTestResult('success', '✅ AxieStudio account deleted successfully!');
        addTestResult('info', '🎉 Account deletion test PASSED!');
      } else {
        addTestResult('error', `❌ Deletion failed: ${result.error || 'Unknown error'}`);
      }

    } catch (error: any) {
      addTestResult('error', `❌ Error: ${error.message}`);
    } finally {
      setIsDeleting(false);
    }
  };

  const testFullFlow = async () => {
    addTestResult('info', '🚀 Starting FULL FLOW test...');
    await testCreateAccount();
    
    // Wait 2 seconds between create and delete
    setTimeout(async () => {
      await testDeleteAccount();
      addTestResult('success', '🎉 FULL FLOW test completed!');
    }, 2000);
  };

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-6xl mx-auto space-y-8">
        {/* Header */}
        <div className="bg-white border-2 border-black rounded-none shadow-[8px_8px_0px_0px_rgba(0,0,0,1)] p-6">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-3">
              <TestTube className="w-8 h-8 text-black" />
              <h1 className="text-3xl font-bold text-black uppercase tracking-wide">
                AxieStudio Integration Test
              </h1>
            </div>
            <Link
              to="/test"
              className="flex items-center gap-2 bg-gray-600 text-white px-4 py-2 rounded-none font-bold hover:bg-gray-700 transition-colors uppercase tracking-wide text-sm"
            >
              <ArrowLeft className="w-4 h-4" />
              BACK TO TESTS
            </Link>
          </div>
          <p className="text-gray-600">
            Test AxieStudio account creation and deletion with proper authentication
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Test Controls */}
          <div className="bg-white border-2 border-black rounded-none shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] p-6">
            <h2 className="text-xl font-bold text-black mb-6 uppercase tracking-wide">
              Test Controls
            </h2>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-bold text-black uppercase tracking-wide mb-2">
                  Test Email
                </label>
                <input
                  type="email"
                  value={testEmail}
                  onChange={(e) => setTestEmail(e.target.value)}
                  className="w-full p-3 border-2 border-black rounded-none font-mono"
                  placeholder="test-user@example.com"
                />
              </div>
              
              <div>
                <label className="block text-sm font-bold text-black uppercase tracking-wide mb-2">
                  Test Password
                </label>
                <input
                  type="password"
                  value={testPassword}
                  onChange={(e) => setTestPassword(e.target.value)}
                  className="w-full p-3 border-2 border-black rounded-none font-mono"
                  placeholder="TestPassword123!"
                />
              </div>

              <div className="grid grid-cols-1 gap-3 pt-4">
                <button
                  onClick={testCreateAccount}
                  disabled={isCreating}
                  className="flex items-center justify-center gap-2 bg-green-600 text-white px-4 py-3 rounded-none font-bold hover:bg-green-700 disabled:opacity-50 uppercase tracking-wide"
                >
                  {isCreating ? <Loader2 className="w-4 h-4 animate-spin" /> : <UserPlus className="w-4 h-4" />}
                  {isCreating ? 'CREATING...' : 'TEST CREATE ACCOUNT'}
                </button>

                <button
                  onClick={testDeleteAccount}
                  disabled={isDeleting}
                  className="flex items-center justify-center gap-2 bg-red-600 text-white px-4 py-3 rounded-none font-bold hover:bg-red-700 disabled:opacity-50 uppercase tracking-wide"
                >
                  {isDeleting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Trash2 className="w-4 h-4" />}
                  {isDeleting ? 'DELETING...' : 'TEST DELETE ACCOUNT'}
                </button>

                <button
                  onClick={testFullFlow}
                  disabled={isCreating || isDeleting}
                  className="flex items-center justify-center gap-2 bg-blue-600 text-white px-4 py-3 rounded-none font-bold hover:bg-blue-700 disabled:opacity-50 uppercase tracking-wide"
                >
                  <TestTube className="w-4 h-4" />
                  TEST FULL FLOW
                </button>

                <button
                  onClick={clearResults}
                  className="flex items-center justify-center gap-2 bg-gray-600 text-white px-4 py-3 rounded-none font-bold hover:bg-gray-700 uppercase tracking-wide"
                >
                  CLEAR RESULTS
                </button>
              </div>

              <div className="mt-8 p-4 border-2 border-blue-600 bg-blue-50 rounded-none">
                <h3 className="text-lg font-bold text-blue-800 mb-4 uppercase tracking-wide">
                  🎯 Production Buttons Test
                </h3>
                <p className="text-blue-700 mb-4 text-sm">
                  Test the actual production buttons used in the dashboard:
                </p>
                <div className="space-y-3">
                  <CreateAxieStudioButton
                    className="w-full"
                    onAccountCreated={() => addTestResult('success', '✅ Account created via production button!')}
                  />
                  <LaunchStudioOnlyButton className="w-full" />
                </div>
              </div>
            </div>
          </div>

          {/* Test Results */}
          <div className="bg-white border-2 border-black rounded-none shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] p-6">
            <h2 className="text-xl font-bold text-black mb-6 uppercase tracking-wide">
              Test Results
            </h2>
            
            <div className="space-y-2 max-h-96 overflow-y-auto">
              {testResults.length === 0 ? (
                <p className="text-gray-500 italic">No test results yet...</p>
              ) : (
                testResults.map((result) => (
                  <div
                    key={result.id}
                    className={`p-3 border-2 rounded-none ${
                      result.type === 'success'
                        ? 'bg-green-50 border-green-600 text-green-800'
                        : result.type === 'error'
                        ? 'bg-red-50 border-red-600 text-red-800'
                        : 'bg-blue-50 border-blue-600 text-blue-800'
                    }`}
                  >
                    <div className="flex items-start gap-2">
                      {result.type === 'success' ? (
                        <CheckCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
                      ) : result.type === 'error' ? (
                        <XCircle className="w-4 h-4 mt-0.5 flex-shrink-0" />
                      ) : (
                        <TestTube className="w-4 h-4 mt-0.5 flex-shrink-0" />
                      )}
                      <div className="flex-1">
                        <p className="font-mono text-sm">{result.message}</p>
                        <p className="text-xs opacity-75 mt-1">
                          {result.timestamp.toLocaleTimeString()}
                        </p>
                      </div>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
