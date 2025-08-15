export interface StripeProduct {
  id: string;
  priceId: string;
  name: string;
  description: string;
  mode: 'payment' | 'subscription';
  price: number;
}

export const stripeProducts: StripeProduct[] = [
  {
    id: 'trial_product',
    priceId: 'trial_price',
    name: '7-Day Free Trial',
    description: 'Get started with full access to AI workflows',
    mode: 'subscription',
    price: 0.00,
  },
  {
    id: import.meta.env.VITE_STRIPE_PRO_PRODUCT_ID || 'YOUR_STRIPE_PRODUCT_ID',
    priceId: import.meta.env.VITE_STRIPE_PRO_PRICE_ID || 'YOUR_STRIPE_PRICE_ID',
    name: 'Go Pro',
    description: 'Advanced AI workflows with unlimited access',
    mode: 'subscription',
    price: 45.00,
  },
  {
    id: 'YOUR_TEST_PRODUCT_ID',
    priceId: 'YOUR_TEST_PRICE_ID',
    name: 'Test Product',
    description: 'Test payment for development',
    mode: 'subscription',
    price: 5.00,
  },
];

export const getProductById = (id: string): StripeProduct | undefined => {
  return stripeProducts.find(product => product.id === id);
};

export const getProductByPriceId = (priceId: string): StripeProduct | undefined => {
  return stripeProducts.find(product => product.priceId === priceId);
};