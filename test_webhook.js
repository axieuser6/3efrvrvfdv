// Test webhook manually
// Run this in browser console on your admin page

async function testWebhookManually() {
  try {
    console.log('🔄 Testing webhook endpoint...');
    
    const response = await fetch('https://othsnnoncnerjogvwjgc.supabase.co/functions/v1/stripe-webhook', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'stripe-signature': 'test_signature'
      },
      body: JSON.stringify({
        id: 'evt_test',
        object: 'event',
        type: 'checkout.session.completed',
        data: {
          object: {
            id: 'cs_test',
            customer: 'cus_test',
            mode: 'subscription',
            payment_status: 'paid'
          }
        }
      })
    });
    
    console.log('Response status:', response.status);
    const result = await response.text();
    console.log('Response:', result);
    
    if (response.status === 400 && result.includes('signature verification failed')) {
      console.log('✅ Webhook endpoint is working (signature verification expected to fail)');
    } else {
      console.log('❌ Unexpected response from webhook');
    }
    
  } catch (error) {
    console.error('❌ Webhook test failed:', error);
  }
}

testWebhookManually();
