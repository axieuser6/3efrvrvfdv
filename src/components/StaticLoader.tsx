import React from 'react';

interface StaticLoaderProps {
  children: React.ReactNode;
  loading?: boolean;
  fallback?: React.ReactNode;
  className?: string;
}

/**
 * StaticLoader - Provides immediate rendering with optional background loading
 * This component makes the app feel "static" by showing content immediately
 * while optionally handling loading states in the background
 */
export function StaticLoader({ 
  children, 
  loading = false, 
  fallback = null, 
  className = '' 
}: StaticLoaderProps) {
  // 🚀 STATIC BEHAVIOR: Always show children immediately
  // Loading state is handled internally without affecting UI
  return (
    <div className={className}>
      {children}
      {/* Optional: Show subtle loading indicator in corner if needed */}
      {loading && (
        <div className="fixed bottom-4 right-4 z-50 opacity-50">
          <div className="bg-gray-800 text-white px-2 py-1 rounded text-xs">
            Syncing...
          </div>
        </div>
      )}
    </div>
  );
}

interface StaticButtonProps {
  children: React.ReactNode;
  onClick?: () => void | Promise<void>;
  disabled?: boolean;
  loading?: boolean;
  className?: string;
  variant?: 'primary' | 'secondary' | 'danger';
}

/**
 * StaticButton - Button that appears static but handles async operations
 */
export function StaticButton({ 
  children, 
  onClick, 
  disabled = false, 
  loading = false,
  className = '',
  variant = 'primary'
}: StaticButtonProps) {
  const [isProcessing, setIsProcessing] = React.useState(false);

  const handleClick = async () => {
    if (disabled || isProcessing || !onClick) return;

    try {
      setIsProcessing(true);
      await onClick();
    } catch (error) {
      console.error('Button action failed:', error);
    } finally {
      setIsProcessing(false);
    }
  };

  const baseClasses = "px-4 py-2 rounded font-medium transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2";
  
  const variantClasses = {
    primary: "bg-blue-600 hover:bg-blue-700 text-white focus:ring-blue-500",
    secondary: "bg-gray-600 hover:bg-gray-700 text-white focus:ring-gray-500",
    danger: "bg-red-600 hover:bg-red-700 text-white focus:ring-red-500"
  };

  const disabledClasses = "opacity-50 cursor-not-allowed";

  return (
    <button
      onClick={handleClick}
      disabled={disabled || isProcessing}
      className={`
        ${baseClasses} 
        ${variantClasses[variant]} 
        ${(disabled || isProcessing) ? disabledClasses : ''} 
        ${className}
      `}
    >
      {isProcessing ? (
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
          <span>Processing...</span>
        </div>
      ) : (
        children
      )}
    </button>
  );
}

interface StaticCardProps {
  children: React.ReactNode;
  title?: string;
  loading?: boolean;
  className?: string;
}

/**
 * StaticCard - Card component that appears static
 */
export function StaticCard({ 
  children, 
  title, 
  loading = false, 
  className = '' 
}: StaticCardProps) {
  return (
    <div className={`bg-white rounded-lg shadow-md border ${className}`}>
      {title && (
        <div className="px-6 py-4 border-b border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
        </div>
      )}
      <div className="px-6 py-4">
        {children}
      </div>
      {loading && (
        <div className="px-6 py-2 border-t border-gray-200 bg-gray-50">
          <div className="flex items-center gap-2 text-sm text-gray-600">
            <div className="w-3 h-3 border-2 border-gray-400 border-t-transparent rounded-full animate-spin"></div>
            <span>Updating...</span>
          </div>
        </div>
      )}
    </div>
  );
}

interface StaticStatusProps {
  status: 'success' | 'warning' | 'error' | 'info';
  message: string;
  details?: string;
  className?: string;
}

/**
 * StaticStatus - Status indicator that appears immediately
 */
export function StaticStatus({ 
  status, 
  message, 
  details, 
  className = '' 
}: StaticStatusProps) {
  const statusConfig = {
    success: {
      bgColor: 'bg-green-50',
      borderColor: 'border-green-200',
      textColor: 'text-green-800',
      icon: '✅'
    },
    warning: {
      bgColor: 'bg-yellow-50',
      borderColor: 'border-yellow-200',
      textColor: 'text-yellow-800',
      icon: '⚠️'
    },
    error: {
      bgColor: 'bg-red-50',
      borderColor: 'border-red-200',
      textColor: 'text-red-800',
      icon: '❌'
    },
    info: {
      bgColor: 'bg-blue-50',
      borderColor: 'border-blue-200',
      textColor: 'text-blue-800',
      icon: 'ℹ️'
    }
  };

  const config = statusConfig[status];

  return (
    <div className={`
      ${config.bgColor} 
      ${config.borderColor} 
      ${config.textColor} 
      border rounded-lg p-4 
      ${className}
    `}>
      <div className="flex items-start gap-3">
        <span className="text-lg">{config.icon}</span>
        <div className="flex-1">
          <p className="font-medium">{message}</p>
          {details && (
            <p className="text-sm mt-1 opacity-80">{details}</p>
          )}
        </div>
      </div>
    </div>
  );
}

/**
 * StaticSkeleton - Skeleton loader that appears static
 */
export function StaticSkeleton({ 
  lines = 3, 
  className = '' 
}: { 
  lines?: number; 
  className?: string; 
}) {
  return (
    <div className={`animate-pulse ${className}`}>
      {Array.from({ length: lines }).map((_, i) => (
        <div 
          key={i} 
          className={`
            bg-gray-200 rounded h-4 mb-2
            ${i === lines - 1 ? 'w-3/4' : 'w-full'}
          `}
        />
      ))}
    </div>
  );
}
