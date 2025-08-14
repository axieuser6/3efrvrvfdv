/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL: string
  readonly VITE_SUPABASE_ANON_KEY: string
  readonly VITE_AXIESTUDIO_APP_URL: string
  readonly VITE_STRIPE_PUBLISHABLE_KEY: string
  readonly VITE_STRIPE_PRO_PRICE_ID: string
  readonly VITE_STRIPE_PRO_PRODUCT_ID: string
  readonly VITE_STRIPE_TEST_PRICE_ID: string
  readonly VITE_STRIPE_TEST_PRODUCT_ID: string
  readonly VITE_API_BASE_URL: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
