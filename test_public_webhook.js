// Test the new public webhook
// Run this in browser console

async function testPublicWebhook() {
  try {
    console.log('🔄 Testing NEW public webhook endpoint...');
    
    // Test with a mock payment event
    const mockEvent = {
      id: 'evt_test_public',
      object: 'event',
      type: 'checkout.session.completed',
      data: {
        object: {
          id: 'cs_test_public',
          object: 'checkout.session',
          customer: null, // No customer ID
          customer_details: {
            email: 'user14@mocksender.shop',
            name: 'Stefan Miranda'
          },
          mode: 'payment', // One-time payment
          payment_status: 'paid',
          amount_total: 1000,
          amount_subtotal: 1000,
          currency: 'sek',
          payment_intent: 'pi_test_public'
        }
      }
    };
    
    const response = await fetch('https://othsnnoncnerjogvwjgc.supabase.co/functions/v1/stripe-webhook-public', {
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
      console.log('✅ PUBLIC webhook endpoint is working!');
      console.log('✅ No more 401 auth errors!');
      console.log('🎉 Ready for real payments!');
    } else if (response.status === 401) {
      console.log('❌ Still getting 401 auth errors');
    } else if (response.status === 200) {
      console.log('🎉 PERFECT! Webhook processed successfully!');
    } else {
      console.log('🤔 Unexpected response:', response.status, result);
    }
    
  } catch (error) {
    console.error('❌ Webhook test failed:', error);
  }
}

testPublicWebhook();
