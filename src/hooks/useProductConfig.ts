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

        console.log('✅ Product configuration loaded:', data.config);
        setConfig(data.config);
        setError(null);
      } catch (err) {
        console.error('❌ Error fetching product config:', err);
        setError(err instanceof Error ? err.message : 'Unknown error');
        
        // Fallback to environment variables if function fails
        console.log('🔄 Falling back to environment variables...');
        const fallbackConfig: ProductConfig = {
          limited_time: {
            product_id: import.meta.env.VITE_STRIPE_LIMITED_TIME_PRODUCT_ID || 'prod_Ss7w3IYMyDloAF',
            price_id: import.meta.env.VITE_STRIPE_LIMITED_TIME_PRICE_ID || 'price_1RwNgiBacFXEnBmNu1PwJnYK',
          },
          pro: {
            product_id: import.meta.env.VITE_STRIPE_PRO_PRODUCT_ID || 'prod_SqmQgEphHNdPVG',
            price_id: import.meta.env.VITE_STRIPE_PRO_PRICE_ID || 'price_1Rv4rDBacFXEnBmNDMrhMqOH',
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
