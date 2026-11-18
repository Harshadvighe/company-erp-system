const BASE_URL = process.env.API_BASE_URL || 'http://127.0.0.1:3000/api/v1';

async function verifyCodeEditPermission(otp) {
  if (!otp) {
    console.error('Usage: node verify_code_edit_permission.js <6-DIGIT-OTP>');
    process.exit(1);
  }

  const payload = {
    requesterEmail: 'pooja.saark@gmail.com',
    targetResource: 'SAARK_ERP_ARCHITECTURAL_BLUEPRINT_AND_WORKFLOWS.md',
    otp: otp.trim(),
  };

  console.log(`Verifying authorization OTP "${otp}" with Governance Gatekeeper...`);
  const res = await fetch(`${BASE_URL}/governance/verify-access`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  const json = await res.json();
  console.log('HTTP Status:', res.status);
  console.log('Result:', JSON.stringify(json, null, 2));

  if (res.ok) {
    console.log('\n================================================================');
    console.log(' ✅ PERMISSION VERIFIED & UNLOCKED BY AUTHOR (sonwanep968@gmail.com)!');
    console.log('================================================================');
  } else {
    console.log('\n❌ VERIFICATION FAILED: Invalid or expired OTP.');
  }
}

const inputOtp = process.argv[2];
verifyCodeEditPermission(inputOtp).catch(console.error);
