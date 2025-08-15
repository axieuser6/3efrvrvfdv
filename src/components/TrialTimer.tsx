import React, { useState, useEffect } from 'react';
import { Clock, AlertCircle } from 'lucide-react';

interface TrialTimerProps {
  trialEndDate: string | null;
  subscriptionStatus: string | null;
  currentPlan: string | null;
}

export function TrialTimer({ trialEndDate, subscriptionStatus, currentPlan }: TrialTimerProps) {
  const [timeLeft, setTimeLeft] = useState<{
    days: number;
    hours: number;
    minutes: number;
    seconds: number;
    expired: boolean;
  }>({ days: 0, hours: 0, minutes: 0, seconds: 0, expired: false });

  useEffect(() => {
    if (!trialEndDate) {
      // If no trial end date, set as expired
      setTimeLeft({ days: 0, hours: 0, minutes: 0, seconds: 0, expired: true });
      return;
    }

    const updateTimer = () => {
      const now = new Date().getTime();
      const endTime = new Date(trialEndDate).getTime();
      const difference = endTime - now;

      if (difference <= 0) {
        setTimeLeft({ days: 0, hours: 0, minutes: 0, seconds: 0, expired: true });
        return;
      }

      const days = Math.floor(difference / (1000 * 60 * 60 * 24));
      const hours = Math.floor((difference % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
      const minutes = Math.floor((difference % (1000 * 60 * 60)) / (1000 * 60));
      const seconds = Math.floor((difference % (1000 * 60)) / 1000);

      setTimeLeft({ days, hours, minutes, seconds, expired: false });
    };

    updateTimer();
    const interval = setInterval(updateTimer, 1000);

    return () => clearInterval(interval);
  }, [trialEndDate]);

  // Determine current status
  const getStatusInfo = () => {
    // PRIORITY 1: Active subscription (including resubscribed users)
    if (subscriptionStatus === 'active' && currentPlan !== 'Standard') {
      return {
        status: `${currentPlan?.toUpperCase()} ACTIVE`,
        color: 'bg-green-600',
        textColor: 'text-green-800',
        bgColor: 'bg-green-50',
        icon: <Clock className="w-4 h-4" />
      };
    }

    // PRIORITY 2: Trial period (only if actually trialing and has trial data)
    if (subscriptionStatus === 'trialing' || (trialEndDate && !timeLeft.expired)) {
      return {
        status: 'TRIAL PERIOD',
        color: 'bg-blue-600',
        textColor: 'text-blue-800',
        bgColor: 'bg-blue-50',
        icon: <Clock className="w-4 h-4" />
      };
    }

    // PRIORITY 3: Expired or cancelled (but not if they have active subscription)
    if ((timeLeft.expired || subscriptionStatus === 'canceled' || subscriptionStatus === 'incomplete_expired') && subscriptionStatus !== 'active') {
      return {
        status: 'TRIAL EXPIRED',
        color: 'bg-red-600',
        textColor: 'text-red-800',
        bgColor: 'bg-red-50',
        icon: <AlertCircle className="w-4 h-4" />
      };
    }

    return {
      status: 'STANDARD TIER',
      color: 'bg-gray-600',
      textColor: 'text-gray-800',
      bgColor: 'bg-gray-50',
      icon: <Clock className="w-4 h-4" />
    };
  };

  const statusInfo = getStatusInfo();

  return (
    <div className={`${statusInfo.bgColor} border-2 border-black rounded-none p-6 mb-8`}>
      <div className="flex items-center gap-3 mb-4">
        <div className={`${statusInfo.color} text-white p-2 rounded-none`}>
          {statusInfo.icon}
        </div>
        <div>
          <h3 className={`font-bold text-lg ${statusInfo.textColor} uppercase tracking-wide`}>
            {statusInfo.status}
          </h3>
          <p className="text-sm text-gray-600">
            {subscriptionStatus === 'active' && currentPlan !== 'Standard'
              ? `Your ${currentPlan} subscription is active`
              : subscriptionStatus === 'trialing' || (trialEndDate && !timeLeft.expired)
              ? 'Your trial period is active'
              : timeLeft.expired || !trialEndDate
              ? 'Your trial has ended - upgrade to continue'
              : 'Your account is on the Standard tier'
            }
          </p>
        </div>
      </div>

      {/* Show timer only during trial */}
      {(subscriptionStatus === 'trialing' || (trialEndDate && !timeLeft.expired)) && (
        <div className="grid grid-cols-4 gap-4 text-center">
          <div className="bg-white border-2 border-black rounded-none p-3">
            <div className="text-2xl font-bold text-black">{timeLeft.days}</div>
            <div className="text-xs text-gray-600 uppercase tracking-wide">Days</div>
          </div>
          <div className="bg-white border-2 border-black rounded-none p-3">
            <div className="text-2xl font-bold text-black">{timeLeft.hours}</div>
            <div className="text-xs text-gray-600 uppercase tracking-wide">Hours</div>
          </div>
          <div className="bg-white border-2 border-black rounded-none p-3">
            <div className="text-2xl font-bold text-black">{timeLeft.minutes}</div>
            <div className="text-xs text-gray-600 uppercase tracking-wide">Minutes</div>
          </div>
          <div className="bg-white border-2 border-black rounded-none p-3">
            <div className="text-2xl font-bold text-black">{timeLeft.seconds}</div>
            <div className="text-xs text-gray-600 uppercase tracking-wide">Seconds</div>
          </div>
        </div>
      )}

      {/* Show subscription info for active subscriptions */}
      {subscriptionStatus === 'active' && currentPlan !== 'Standard' && (
        <div className="bg-white border-2 border-black rounded-none p-4 text-center">
          <div className="text-lg font-bold text-green-600">✓ SUBSCRIPTION ACTIVE</div>
          <div className="text-sm text-gray-600 mt-1">
            Enjoying full access to AxieStudio
          </div>
        </div>
      )}

      {/* Show upgrade message for expired/standard */}
      {(timeLeft.expired || !trialEndDate || subscriptionStatus === 'canceled' || currentPlan === 'Standard') && (
        <div className="bg-white border-2 border-black rounded-none p-4 text-center">
          <div className="text-lg font-bold text-gray-600">📦 DATA PRESERVED</div>
          <div className="text-sm text-gray-600 mt-1">
            Your account and data are safe. Upgrade anytime to reactivate AxieStudio access.
          </div>
        </div>
      )}
    </div>
  );
}
