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
      res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(raw) }));
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function get(path, token) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: 'localhost',
      port: 3000,
      path,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    }, (res) => {
      let raw = '';
      res.on('data', chunk => raw += chunk);
      res.on('end', () => resolve({ status: res.statusCode, body: JSON.parse(raw) }));
    });
    req.on('error', reject);
    req.end();
  });
}

async function test() {
  const login = await post('/api/v1/auth/login', { emailOrUsername: 'admin', password: 'Saark@2026' });
  const token = login.body.data?.tokens?.accessToken || login.body.accessToken;
  console.log('Login Status:', login.status, 'User:', login.body.data?.user?.fullName || login.body.user?.fullName);

  const health = await get('/api/v1/admin/system/health', token);
  const hData = health.body.data || health.body;
  console.log('System Health Status:', health.status);
  console.log('Database Engine:', hData.database?.engine, 'Latency:', hData.database?.latencyMs + 'ms');
  console.log('Security Standard:', hData.security?.standard);

  const policy = await get('/api/v1/admin/security/policy', token);
  const pData = policy.body.data || policy.body;
  console.log('Security Policy Status:', policy.status);
  console.log('Policy Face:', pData.faceRecognitionPolicy, 'MinPass:', pData.passwordMinLength);

  const audit = await get('/api/v1/admin/audit-logs', token);
  const aData = audit.body.data || audit.body;
  console.log('Audit Logs Status:', audit.status, 'Total Logs:', aData.total);
  if (aData.data && aData.data.length > 0) {
    console.log('Sample Log Action:', aData.data[0].action, 'Details:', aData.data[0].details);
  }

  const sessions = await get('/api/v1/admin/security/sessions', token);
  const sData = sessions.body.data || sessions.body;
  console.log('Active Sessions:', sData.length);
}

test().catch(console.error);
