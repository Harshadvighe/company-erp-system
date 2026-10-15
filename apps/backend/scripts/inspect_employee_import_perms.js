const path = require('path');
const fs = require('fs');

const stagingEnvPath = path.resolve(__dirname, '../.env.staging');
const envContent = fs.readFileSync(stagingEnvPath, 'utf8');
envContent.split(/\r?\n/).forEach(line => {
  const t = line.trim();
  if (t && !t.startsWith('#')) {
    const eq = t.indexOf('=');
    if (eq !== -1) {
      const k = t.slice(0, eq).trim();
      let v = t.slice(eq + 1).trim();
      if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
        v = v.slice(1, -1);
      }
      process.env[k] = v;
    }
  }
});

const { PrismaClient } = require(path.resolve(__dirname, '../node_modules/@prisma/client-staging'));
const prisma = new PrismaClient();

async function check() {
  const p = await prisma.permission.findFirst();
  console.log('Sample Permission:', p);

  const u = await prisma.user.findFirst({
    where: { email: 'harshadvighe545@gmail.com' },
    include: {
      userRoles: { include: { role: true } },
      userPermissions: { include: { permission: true } }
    }
  });
  console.log('User:', u?.email, 'Role:', u?.userRoles.map(ur => ur.role.name));
  console.log('User direct permissions:', u?.userPermissions.map(up => up.permission));

  const overrides = await prisma.userPermissionOverride.findMany({
    where: { userId: u?.id }
  });
  console.log('User overrides:', overrides);
}

check().catch(console.error).finally(() => prisma.$disconnect());
