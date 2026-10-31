const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('Testing PostgreSQL table metadata queries...');

  const tables = await prisma.$queryRaw`
    SELECT 
      t.table_name,
      COALESCE(s.n_live_tup, 0) AS row_count
    FROM information_schema.tables t
    LEFT JOIN (
      SELECT relname, sum(n_live_tup) as n_live_tup 
      FROM pg_stat_user_tables 
      WHERE schemaname = 'public' 
      GROUP BY relname
    ) s ON s.relname = t.table_name
    WHERE t.table_schema = 'public'
    ORDER BY t.table_name ASC;
  `;

  console.log(`✔ Found ${tables.length} tables in PostgreSQL:`);
  console.log(tables.slice(0, 10));

  // Test inspecting a table: user_sessions
  const columns = await prisma.$queryRaw`
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_name = 'user_sessions' AND table_schema = 'public'
    ORDER BY ordinal_position ASC;
  `;
  console.log(`✔ Columns in user_sessions (${columns.length}):`, columns.slice(0, 5));

  const rows = await prisma.$queryRawUnsafe(`
    SELECT * FROM "user_sessions" ORDER BY "loginTime" DESC LIMIT 3;
  `);
  console.log(`✔ Sample rows from user_sessions (${rows.length}):`, rows);

  await prisma.$disconnect();
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
