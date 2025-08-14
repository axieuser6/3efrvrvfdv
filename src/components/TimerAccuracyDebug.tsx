import React, { useState, useEffect } from 'react';
import { useAuth } from '../hooks/useAuth';
import { useTrialStatus } from '../hooks/useTrialStatus';
import { AlertTriangle, CheckCircle, Clock, User } from 'lucide-react';

export function TimerAccuracyDebug() {
  const { user } = useAuth();
  const { trialInfo } = useTrialStatus();
  const [realTimeRemaining, setRealTimeRemaining] = useState<string>('');
  const [databaseTimeRemaining, setDatabaseTimeRemaining] = useState<string>('');
  const [isAccurate, setIsAccurate] = useState<boolean>(true);

  useEffect(() => {
    if (!user || !trialInfo) return;

    const updateComparison = () => {
      const now = new Date();
      
      // Calculate from user's actual creation time (REAL)
      const userCreatedAt = new Date(user.created_at);
      const realTrialEndDate = new Date(userCreatedAt.getTime() + (7 * 24 * 60 * 60 * 1000));
      const realDifference = realTrialEndDate.getTime() - now.getTime();
      
      // Calculate from database trial_end_date (DATABASE)
      const databaseTrialEndDate = new Date(trialInfo.trial_end_date);
      const databaseDifference = databaseTrialEndDate.getTime() - now.getTime();
      
      // Format real time remaining
      if (realDifference > 0) {
        const days = Math.floor(realDifference / (1000 * 60 * 60 * 24));
        const hours = Math.floor((realDifference % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        const minutes = Math.floor((realDifference % (1000 * 60 * 60)) / (1000 * 60));
        const seconds = Math.floor((realDifference % (1000 * 60)) / 1000);
        setRealTimeRemaining(`${days}d ${hours}h ${minutes}m ${seconds}s`);
      } else {
        setRealTimeRemaining('EXPIRED');
      }
      
      // Format database time remaining
      if (databaseDifference > 0) {
        const days = Math.floor(databaseDifference / (1000 * 60 * 60 * 24));
        const hours = Math.floor((databaseDifference % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        const minutes = Math.floor((databaseDifference % (1000 * 60 * 60)) / (1000 * 60));
        const seconds = Math.floor((databaseDifference % (1000 * 60)) / 1000);
        setDatabaseTimeRemaining(`${days}d ${hours}h ${minutes}m ${seconds}s`);
      } else {
        setDatabaseTimeRemaining('EXPIRED');
      }
      
      // Check if they match (within 60 seconds tolerance)
      const differenceInSeconds = Math.abs(realDifference - databaseDifference) / 1000;
      setIsAccurate(differenceInSeconds < 60);
    };

    updateComparison();
    const interval = setInterval(updateComparison, 1000);

    return () => clearInterval(interval);
  }, [user, trialInfo]);

  if (!user || !trialInfo) {
    return null;
  }

  const userCreatedAt = new Date(user.created_at);
  const databaseTrialEndDate = new Date(trialInfo.trial_end_date);
  const realTrialEndDate = new Date(userCreatedAt.getTime() + (7 * 24 * 60 * 60 * 1000));

  return (
    <div className="bg-gray-50 border-2 border-gray-300 rounded-none p-4 mb-6">
      <div className="flex items-center gap-3 mb-4">
        <Clock className="w-5 h-5 text-gray-600" />
        <h3 className="font-bold uppercase tracking-wide text-gray-800">
          Timer Accuracy Debug
        </h3>
        {isAccurate ? (
          <CheckCircle className="w-5 h-5 text-green-600" />
        ) : (
          <AlertTriangle className="w-5 h-5 text-red-600" />
        )}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
        {/* Real Time (Based on User Creation) */}
        <div className="bg-green-50 border-2 border-green-600 rounded-none p-3">
          <h4 className="font-bold text-green-800 mb-2 uppercase tracking-wide text-sm">
            ✅ REAL TIME (User Creation Based)
          </h4>
          <div className="text-2xl font-bold text-green-800 mb-2">
            {realTimeRemaining}
          </div>
          <div className="text-xs text-green-700">
            <div>User Created: {userCreatedAt.toLocaleString()}</div>
            <div>Trial Ends: {realTrialEndDate.toLocaleString()}</div>
          </div>
        </div>

        {/* Database Time */}
        <div className={`${isAccurate ? 'bg-blue-50 border-blue-600' : 'bg-red-50 border-red-600'} border-2 rounded-none p-3`}>
          <h4 className={`font-bold mb-2 uppercase tracking-wide text-sm ${isAccurate ? 'text-blue-800' : 'text-red-800'}`}>
            {isAccurate ? '✅' : '❌'} DATABASE TIME
          </h4>
          <div className={`text-2xl font-bold mb-2 ${isAccurate ? 'text-blue-800' : 'text-red-800'}`}>
            {databaseTimeRemaining}
          </div>
          <div className={`text-xs ${isAccurate ? 'text-blue-700' : 'text-red-700'}`}>
            <div>Trial Start: {new Date(trialInfo.trial_start_date).toLocaleString()}</div>
            <div>Trial Ends: {databaseTrialEndDate.toLocaleString()}</div>
          </div>
        </div>
      </div>

      {/* Status */}
      <div className={`border-2 rounded-none p-3 ${
        isAccurate 
          ? 'bg-green-50 border-green-600' 
          : 'bg-red-50 border-red-600'
      }`}>
        <div className="flex items-center gap-2">
          {isAccurate ? (
            <CheckCircle className="w-4 h-4 text-green-600" />
          ) : (
            <AlertTriangle className="w-4 h-4 text-red-600" />
          )}
          <span className={`font-bold text-sm uppercase tracking-wide ${
            isAccurate ? 'text-green-800' : 'text-red-800'
          }`}>
            {isAccurate ? 'TIMER IS ACCURATE' : 'TIMER MISMATCH DETECTED'}
          </span>
        </div>
        
        {!isAccurate && (
          <div className="mt-2 text-sm text-red-700">
            <p>⚠️ The database trial dates don't match the user's actual creation time.</p>
            <p>🔧 Run the SQL fix query to correct the trial dates.</p>
          </div>
        )}
      </div>

      {/* User Info */}
      <div className="mt-4 text-xs text-gray-600">
        <div className="flex items-center gap-2">
          <User className="w-3 h-3" />
          <span>User ID: {user.id}</span>
        </div>
        <div>Email: {user.email}</div>
      </div>
    </div>
  );
}
