const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

// Load .env.staging
const envPath = path.resolve(__dirname, '../.env.staging');
const envContent = fs.readFileSync(envPath, 'utf8');
const env = { ...process.env };
envContent.split(/\r?\n/).forEach((line) => {
  const t = line.trim();
  if (t && !t.startsWith('#')) {
    const eq = t.indexOf('=');
    if (eq !== -1) {
      const k = t.slice(0, eq).trim();
      let v = t.slice(eq + 1).trim();
      if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
      env[k] = v;
    }
  }
});

env.PATH = 'C:\\Program Files\\nodejs;' + (process.env.PATH || '');

try {
  console.log('Deploying migrations to staging PostgreSQL...');
  const out = execSync('npx prisma migrate deploy --schema=prisma/schema.staging.prisma', {
    cwd: path.resolve(__dirname, '..'),
    env,
    encoding: 'utf8',
  });
  console.log(out);
  console.log('Staging migrations applied successfully!');
} catch (e) {
  console.error('Error deploying migrations:', e.message);
  if (e.stdout) console.log('stdout:', e.stdout);
  if (e.stderr) console.error('stderr:', e.stderr);
  process.exit(1);
}
