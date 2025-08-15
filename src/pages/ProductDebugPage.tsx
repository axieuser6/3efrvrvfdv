import React from 'react';
import { createStripeProducts } from '../stripe-config';
import { useProductConfig } from '../hooks/useProductConfig';

export function ProductDebugPage() {
  const { config: productConfig, loading: configLoading, error } = useProductConfig();

  const products = createStripeProducts(productConfig);

  return (
    <div className="min-h-screen bg-white p-8">
      <h1 className="text-3xl font-bold mb-8">Product Configuration Debug</h1>
      
      <div className="space-y-8">
        <div className="bg-gray-100 p-6 rounded-lg">
          <h2 className="text-xl font-bold mb-4">Product Config Status</h2>
          <p><strong>Loading:</strong> {configLoading ? 'Yes' : 'No'}</p>
          <p><strong>Error:</strong> {error || 'None'}</p>
          <p><strong>Config:</strong></p>
          <pre className="bg-white p-4 rounded mt-2 text-sm overflow-auto">
            {JSON.stringify(productConfig, null, 2)}
          </pre>
        </div>

        <div className="bg-gray-100 p-6 rounded-lg">
          <h2 className="text-xl font-bold mb-4">Environment Variables</h2>
          <div className="space-y-2 text-sm">
            <p><strong>PRO_PRODUCT_ID:</strong> {import.meta.env.VITE_STRIPE_PRO_PRODUCT_ID}</p>
            <p><strong>PRO_PRICE_ID:</strong> {import.meta.env.VITE_STRIPE_PRO_PRICE_ID}</p>
            <p><strong>LIMITED_TIME_PRODUCT_ID:</strong> {import.meta.env.VITE_STRIPE_LIMITED_TIME_PRODUCT_ID}</p>
            <p><strong>LIMITED_TIME_PRICE_ID:</strong> {import.meta.env.VITE_STRIPE_LIMITED_TIME_PRICE_ID}</p>
          </div>
        </div>

        <div className="bg-gray-100 p-6 rounded-lg">
          <h2 className="text-xl font-bold mb-4">Generated Products ({products.length})</h2>
          <div className="space-y-4">
            {products.map((product, index) => (
              <div key={product.id} className="bg-white p-4 rounded border">
                <h3 className="font-bold text-lg">{index + 1}. {product.name}</h3>
                <div className="grid grid-cols-2 gap-4 mt-2 text-sm">
                  <div>
                    <p><strong>ID:</strong> {product.id}</p>
                    <p><strong>Price ID:</strong> {product.priceId}</p>
                  </div>
                  <div>
                    <p><strong>Price:</strong> ${product.price}</p>
                    <p><strong>Mode:</strong> {product.mode}</p>
                  </div>
                </div>
                <p className="mt-2 text-gray-600">{product.description}</p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
