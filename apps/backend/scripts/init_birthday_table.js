require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS birthday_wishes (
      id VARCHAR(64) PRIMARY KEY,
      employee_id VARCHAR(64) NOT NULL,
      sender_user_id VARCHAR(64) NOT NULL,
      sender_name VARCHAR(255) NOT NULL,
      sender_avatar VARCHAR(500),
      recipient_name VARCHAR(255) NOT NULL,
      recipient_email VARCHAR(255),
      message TEXT NOT NULL,
      wish_date DATE NOT NULL DEFAULT CURRENT_DATE,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    )
  `);

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS idx_birthday_wishes_employee ON birthday_wishes(employee_id)
  `);

  await prisma.$executeRawUnsafe(`
    CREATE INDEX IF NOT EXISTS idx_birthday_wishes_date ON birthday_wishes(wish_date)
  `);

  console.log('✅ birthday_wishes table created successfully in PostgreSQL.');
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
