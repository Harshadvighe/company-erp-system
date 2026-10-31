const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('Creating user_sessions table in PostgreSQL if not exists...');
  
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS "user_sessions" (
      "id" TEXT NOT NULL,
      "userId" TEXT NOT NULL,
      "username" TEXT NOT NULL,
      "fullName" TEXT NOT NULL,
      "email" TEXT NOT NULL,
      "department" TEXT,
      "role" TEXT,
      "ipAddress" TEXT,
      "clientType" TEXT,
      "loginTime" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "logoutTime" TIMESTAMP(3),
      "lastHeartbeat" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "durationSeconds" INTEGER,
      "status" TEXT NOT NULL DEFAULT 'ACTIVE',
      "loginMethod" TEXT NOT NULL DEFAULT 'CREDENTIALS_AND_BIOMETRIC_2FA',
      "faceVerified" BOOLEAN NOT NULL DEFAULT false,
      "logoutReason" TEXT,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

      CONSTRAINT "user_sessions_pkey" PRIMARY KEY ("id"),
      CONSTRAINT "user_sessions_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE
    );
  `);

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "user_sessions_userId_idx" ON "user_sessions"("userId");
  `);
  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "user_sessions_status_idx" ON "user_sessions"("status");
  `);
  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS "user_sessions_loginTime_idx" ON "user_sessions"("loginTime");
  `);

  console.log('✔ Table "user_sessions" created or already exists with indexes!');
  
  // Verify table existence
  const check = await prisma.$queryRaw`
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'user_sessions'
    ORDER BY ordinal_position;
  `;
  console.log('Columns in user_sessions:', check);

  await prisma.$disconnect();
}

main().catch(err => {
  console.error('Error creating table:', err);
  process.exit(1);
});
