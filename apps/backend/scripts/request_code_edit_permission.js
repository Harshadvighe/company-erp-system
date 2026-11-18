const BASE_URL = process.env.API_BASE_URL || 'http://127.0.0.1:3000/api/v1';

async function requestCodeEditPermission() {
  const payload = {
    requesterName: 'Saark ERP Admin / Developer',
    requesterEmail: 'pooja.saark@gmail.com',
    targetResource: 'SAARK_ERP_ARCHITECTURAL_BLUEPRINT_AND_WORKFLOWS.md',
    changeSummary: 'Requesting author authorization to edit architecture blueprint and code modules',
  };

  console.log('Dispatching permission request to author: sonwanep968@gmail.com...');
  const res = await fetch(`${BASE_URL}/governance/request-access`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });

  const json = await res.json();
  console.log('HTTP Status:', res.status);
  console.log('Response:', JSON.stringify(json, null, 2));
}

requestCodeEditPermission().catch(console.error);
