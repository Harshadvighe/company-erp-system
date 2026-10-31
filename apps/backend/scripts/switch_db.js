const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const targetDb = (process.argv[2] || '').toLowerCase();

if (!['postgres', 'postgresql', 'sqlite'].includes(targetDb)) {
  console.log('Usage: node scripts/switch_db.js <postgres|sqlite>');
  process.exit(1);
}

const isPostgres = targetDb.startsWith('postgres');
const provider = isPostgres ? 'postgresql' : 'sqlite';

const schemaPath = path.join(__dirname, '../prisma/schema.prisma');
const envPath = path.join(__dirname, '../.env');

// 1. Update prisma/schema.prisma datasource provider
let schema = fs.readFileSync(schemaPath, 'utf8');
schema = schema.replace(
  /datasource db \{\s+provider = "(sqlite|postgresql)"\s+url\s+= env\("DATABASE_URL"\)\s+\}/,
  `datasource db {\n  provider = "${provider}"\n  url      = env("DATABASE_URL")\n}`
);
fs.writeFileSync(schemaPath, schema, 'utf8');
console.log(`✅ Updated prisma/schema.prisma datasource provider to: ${provider}`);

// 2. Update .env
if (fs.existsSync(envPath)) {
  let env = fs.readFileSync(envPath, 'utf8');

  env = env.replace(/DATABASE_PROVIDER=.*/g, `DATABASE_PROVIDER=${provider}`);

  if (isPostgres) {
    if (!env.includes('postgresql://') && !env.includes('postgres://')) {
      env = env.replace(
        /DATABASE_URL=.*/g,
        'DATABASE_URL="postgresql://saark:saark_secure_password@localhost:5432/saark_erp_db?schema=public"'
      );
    }
  } else {
    env = env.replace(
      /DATABASE_URL=.*/g,
      'DATABASE_URL="file:../../storage/saark_erp.db"'
    );
  }

  fs.writeFileSync(envPath, env, 'utf8');
  console.log(`✅ Updated .env DATABASE_PROVIDER to ${provider}`);
}

// 3. Regenerate Prisma Client
console.log(`🔄 Generating Prisma Client for ${provider}...`);
try {
  const envVars = { ...process.env };
  if (isPostgres && (!envVars.DATABASE_URL || !envVars.DATABASE_URL.startsWith('postgres'))) {
    envVars.DATABASE_URL = 'postgresql://saark:saark_secure_password@localhost:5432/saark_erp_db?schema=public';
  }
  execSync('npx.cmd prisma generate', {
    cwd: path.join(__dirname, '..'),
    env: envVars,
    stdio: 'inherit',
  });
  console.log(`\n🎉 Successfully switched ERP database engine to ${provider.toUpperCase()}!`);
} catch (e) {
  console.error(`Failed to generate Prisma Client:`, e.message);
  process.exit(1);
}
