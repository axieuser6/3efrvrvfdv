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
        
        // Use environment variables directly instead of Edge Function
        const envConfig = {
          limited_time: {
            product_id: import.meta.env.VITE_STRIPE_LIMITED_TIME_PRODUCT_ID || 'prod_Ss7w3IYMyDloAF',
            price_id: import.meta.env.VITE_STRIPE_LIMITED_TIME_PRICE_ID || 'price_1RwNgiBacFXEnBmNu1PwJnYK',
          },
          pro: {
            product_id: import.meta.env.VITE_STRIPE_PRO_PRODUCT_ID || 'prod_SqmQgEphHNdPVG',
            price_id: import.meta.env.VITE_STRIPE_PRO_PRICE_ID || 'price_1Rv4rDBacFXEnBmNDMrhMqOH',
          }
        };
        
        console.log('✅ Using environment variables for product config:', envConfig);
        setConfig(envConfig);
      } catch (err) {
        console.warn('Using fallback product config due to error:', err);
        // Use fallback config even on error
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
        setConfig(fallbackConfig);
      } finally {
        setLoading(false);
      }
    }

    fetchProductConfig();
  }, []);

  return { config, loading, error };
}
