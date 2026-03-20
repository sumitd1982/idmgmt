require('dotenv').config();
const axios = require('axios');

async function testMsg91() {
  const MSG91_KEY = process.env.MSG91_AUTH_KEY;
  const MSG91_TEMPLATE = process.env.MSG91_TEMPLATE_ID;
  const phone = '+91 8826756777';

  console.log('--- Testing MSG91 OTP API ---');
  console.log(`Phone Input: ${phone}`);
  
  if (!MSG91_KEY || !MSG91_TEMPLATE) {
    console.error('❌ ERROR: Missing MSG91_AUTH_KEY or MSG91_TEMPLATE_ID in your .env file!');
    console.log('Current Auth Key:', MSG91_KEY ? '**(Set)**' : '**(Missing)**');
    console.log('Current Template:', MSG91_TEMPLATE ? '**(Set)**' : '**(Missing)**');
    return;
  }

  // Formatting identical to auth.js
  const mobile = phone.replace(/\D/g, ''); 
  console.log(`Formatted Mobile: ${mobile}`);
  console.log(`Template ID: ${MSG91_TEMPLATE}`);

  try {
    console.log('\n⏳ Sending request to MSG91...');
    const resp = await axios.get('https://api.msg91.com/api/v5/otp', {
      params: { 
        template_id: MSG91_TEMPLATE, 
        mobile: mobile, 
        authkey: MSG91_KEY 
      },
      timeout: 8000
    });

    console.log('\n✅ MSG91 HTTP Response:');
    console.log(resp.data);
    
    if (resp.data?.type === 'success') {
      console.log('\n🎉 SUCCESS: MSG91 says the OTP was sent successfully!');
    } else {
      console.log('\n⚠️ WARNING: MSG91 returned a non-success response.');
    }

  } catch (err) {
    console.error('\n❌ ERROR: Request to MSG91 failed!');
    if (err.response) {
      console.error('HTTP Status:', err.response.status);
      console.error('Response Data:', err.response.data);
    } else {
      console.error(err.message);
    }
  }
}

testMsg91();
