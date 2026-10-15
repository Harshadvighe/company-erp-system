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
  console.log('Validating prisma/schema.staging.prisma...');
  const out1 = execSync('npx prisma validate --schema=prisma/schema.staging.prisma', {
    cwd: path.resolve(__dirname, '..'),
    env,
    encoding: 'utf8',
  });
  console.log(out1);

  console.log('Generating @prisma/client-staging...');
  const out2 = execSync('npx prisma generate --schema=prisma/schema.staging.prisma', {
    cwd: path.resolve(__dirname, '..'),
    env,
    encoding: 'utf8',
  });
  console.log(out2);

  console.log('Validating prisma/schema.prisma (SQLite)...');
  const out3 = execSync('npx prisma validate --schema=prisma/schema.prisma', {
    cwd: path.resolve(__dirname, '..'),
    env: process.env,
    encoding: 'utf8',
  });
  console.log(out3);

  console.log('Validating prisma/schema.postgresql.prisma...');
  const outPostgres = execSync('npx prisma validate --schema=prisma/schema.postgresql.prisma', {
    cwd: path.resolve(__dirname, '..'),
    env,
    encoding: 'utf8',
  });
  console.log(outPostgres);

  console.log('Generating default prisma-client-js...');
  const out4 = execSync('npx prisma generate --schema=prisma/schema.prisma', {
    cwd: path.resolve(__dirname, '..'),
    env: process.env,
    encoding: 'utf8',
  });
  console.log(out4);

  console.log('All schemas validated and clients generated successfully!');
} catch (e) {
  console.error('Error:', e.message);
  if (e.stdout) console.log('stdout:', e.stdout);
  if (e.stderr) console.error('stderr:', e.stderr);
  process.exit(1);
}
