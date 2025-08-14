// Test the fixed webhook
// Run this in browser console

async function testFixedWebhook() {
  try {
    console.log('🔄 Testing fixed webhook endpoint...');
    
    // Test with a mock Stefan payment event
    const mockEvent = {
      id: 'evt_test_stefan',
      object: 'event',
      type: 'checkout.session.completed',
      data: {
        object: {
          id: 'cs_test_stefan',
          object: 'checkout.session',
          customer: null, // This was the issue - no customer ID
          customer_details: {
            email: 'stefan@mocksender.shop',
            name: 'Stefan Miranda'
          },
          mode: 'payment', // One-time payment, not subscription
          payment_status: 'paid',
          amount_total: 1000,
          amount_subtotal: 1000,
          currency: 'sek',
          payment_intent: 'pi_test_stefan'
        }
      }
    };
    
    const response = await fetch('https://othsnnoncnerjogvwjgc.supabase.co/functions/v1/stripe-webhook', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'stripe-signature': 'test_signature_will_fail_but_thats_ok'
      },
      body: JSON.stringify(mockEvent)
    });
    
    console.log('Response status:', response.status);
    const result = await response.text();
    console.log('Response:', result);
    
    if (response.status === 400 && result.includes('signature verification failed')) {
      console.log('✅ Webhook endpoint is working! (signature verification expected to fail in test)');
      console.log('✅ No more 401 auth errors!');
    } else if (response.status === 401) {
      console.log('❌ Still getting 401 auth errors');
    } else {
      console.log('🤔 Unexpected response:', response.status, result);
    }
    
  } catch (error) {
    console.error('❌ Webhook test failed:', error);
  }
}

testFixedWebhook();
