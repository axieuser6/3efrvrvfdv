import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';

interface ProductConfig {
  limited_time: {
    product_id: string;
    price_id: string;
  };
  pro: {
    product_id: string;
    price_id: string;
  };
}

interface UseProductConfigReturn {
  config: ProductConfig | null;
  loading: boolean;
  error: string | null;
}

export function useProductConfig(): UseProductConfigReturn {
  const [config, setConfig] = useState<ProductConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchProductConfig() {
      try {
        console.log('🛍️ Fetching product configuration...');
        
        const { data, error: functionError } = await supabase.functions.invoke('get-product-config');
        
        if (functionError) {
          throw new Error(`Function error: ${functionError.message}`);
        }

        if (!data?.success) {
          throw new Error(data?.message || 'Failed to fetch product configuration');
        }

      // Fallback to hardcoded config if Edge Function fails
      const fallbackConfig = {
        limited_time: {
          product_id: 'prod_fallback_limited',
          price_id: 'price_fallback_limited',
        },
        pro: {
          product_id: 'prod_fallback_pro', 
          price_id: 'price_fallback_pro',
        }
      };
      
      try {
        const response = await fetch(`${supabaseUrl}/functions/v1/get-product-config`, {
          headers: {
            'Authorization': `Bearer ${supabaseAnonKey}`,
            'Content-Type': 'application/json',
          },
        });

        if (response.ok) {
          const data = await response.json();
          if (data.success && data.config) {
            setConfig(data.config);
            return;
          }
        }
      } catch (fetchError) {
        console.warn('Product config fetch failed, using fallback:', fetchError);
      }
      
      // Use fallback config
      setConfig(fallbackConfig);
        };
      console.warn('Using fallback product config due to error:', err);
      // Use fallback config even on error
      setConfig(fallbackConfig);
        setLoading(false);
      }
    }

    fetchProductConfig();
  }, []);

  return { config, loading, error };
}
