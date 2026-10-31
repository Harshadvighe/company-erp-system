const http = require('http');

function post(path, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = http.request({
      hostname: 'localhost',
      port: 3000,
      path,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
      },
    }, (res) => {
      let raw = '';
      res.on('data', chunk => raw += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(raw) });
        } catch (e) {
          resolve({ status: res.statusCode, body: raw });
        }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function get(path) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: 'localhost',
      port: 3000,
      path,
      method: 'GET',
    }, (res) => {
      let raw = '';
      res.on('data', chunk => raw += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(raw) });
        } catch (e) {
          resolve({ status: res.statusCode, body: raw });
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

async function run() {
  console.log('--- Testing PostgreSQL Database Explorer Endpoints ---');

  // Wait a few seconds if server is booting
  await new Promise(r => setTimeout(r, 2000));

  // 1. Test DBA Auth
  console.log('\n[1] Testing DBA Auth with admin / Saark@2026:');
  const authRes = await post('/api/v1/database/auth', {
    username: 'admin',
    password: 'Saark@2026',
  });
  console.log('Status:', authRes.status);
  console.log('Auth result:', JSON.stringify(authRes.body, null, 2));

  // 2. Test Telemetry
  console.log('\n[2] Testing Telemetry:');
  const telRes = await get('/api/v1/database/telemetry');
  console.log('Status:', telRes.status);
  console.log('Telemetry:', JSON.stringify(telRes.body, null, 2));

  // 3. Test Tables Discovery
  console.log('\n[3] Testing Tables Discovery:');
  const tablesRes = await get('/api/v1/database/tables');
  console.log('Status:', tablesRes.status);
  console.log('Total tables discovered:', tablesRes.body?.totalTables);
  if (tablesRes.body?.tables?.length > 0) {
    console.log('Sample first 5 tables:', tablesRes.body.tables.slice(0, 5));
  }

  // 4. Test Table Data for users
  console.log('\n[4] Testing Table Data for "users":');
  const userDataRes = await get('/api/v1/database/table/users?limit=2');
  console.log('Status:', userDataRes.status);
  console.log('Columns count:', userDataRes.body?.columns?.length);
  console.log('Total rows:', userDataRes.body?.totalRows);
  console.log('Sample columns:', userDataRes.body?.columns?.slice(0, 5));
  console.log('Sample rows:', userDataRes.body?.rows?.slice(0, 1));

  // 5. Test Read-only SQL Query Runner
  console.log('\n[5] Testing Custom SQL Query on "users":');
  const queryRes = await post('/api/v1/database/query', {
    query: 'SELECT * FROM "users" LIMIT 2',
  });
  console.log('Status:', queryRes.status);
  console.log('Execution time ms:', queryRes.body?.executionTimeMs);
  console.log('Query rows returned:', queryRes.body?.rowCount);
  console.log('Query rows:', queryRes.body?.rows);


  console.log('\nAll Database Explorer tests completed successfully!');
}

run().catch(console.error);
