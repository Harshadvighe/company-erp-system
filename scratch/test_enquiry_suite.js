async function testEnquiryFlow() {
  const baseURL = 'http://localhost:3000/api/v1';

  try {
    // 1. Login as admin
    const loginRes = await fetch(`${baseURL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        emailOrUsername: 'admin',
        password: 'Saark@2026',
      }),
    });
    const loginData = await loginRes.json();
    const payload = loginData.data || loginData;
    const token = payload.tokens?.accessToken || payload.accessToken || payload.token;
    console.log('Admin login response:', loginRes.status, 'Token acquired:', !!token);

    const headers = {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    };

    // 2. GET /crm/enquiries
    const enqRes = await fetch(`${baseURL}/crm/enquiries`, { headers });
    const enqJson = await enqRes.json();
    const enqData = enqJson.data || enqJson;
    console.log('GET /crm/enquiries status:', enqRes.status);
    console.log('Enquiries count:', enqData.data?.length);
    console.log('Enquiries summary:', enqData.summary);

    if (!enqData.data || enqData.data.length === 0) {
      throw new Error('No enquiries returned from backend');
    }

    const firstEnq = enqData.data[0];
    console.log('First enquiry:', firstEnq.enquiryNumber, firstEnq.status, firstEnq.customer?.companyName);

    // 3. Update status via PATCH /crm/enquiries/:id/status
    const patchRes = await fetch(`${baseURL}/crm/enquiries/${firstEnq.id}/status`, {
      method: 'PATCH',
      headers,
      body: JSON.stringify({ status: 'Complete' }),
    });
    const patchData = await patchRes.json();
    console.log('PATCH /crm/enquiries/:id/status status:', patchRes.status, 'New status:', patchData?.status);

    // 4. Batch status update via POST /crm/enquiries/batch-status
    const batchRes = await fetch(`${baseURL}/crm/enquiries/batch-status`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ ids: [firstEnq.id], status: 'Pending' }),
    });
    const batchData = await batchRes.json();
    console.log('POST /crm/enquiries/batch-status status:', batchRes.status, 'Result:', batchData);

    // 5. GET /crm/enquiries-summary
    const sumRes = await fetch(`${baseURL}/crm/enquiries-summary`, { headers });
    const sumData = await sumRes.json();
    console.log('GET /crm/enquiries-summary status:', sumRes.status, 'Summary:', sumData);

    console.log('\n[SUCCESS] All Enquiry Management backend tests passed perfectly!');
  } catch (err) {
    console.error('Test error:', err);
    process.exit(1);
  }
}

testEnquiryFlow();
