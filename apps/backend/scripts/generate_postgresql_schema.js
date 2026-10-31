const fs = require('fs');
const path = require('path');

const schemaPath = path.join(__dirname, '../prisma/schema.prisma');
const pgSchemaPath = path.join(__dirname, '../prisma/schema.postgresql.prisma');

let content = fs.readFileSync(schemaPath, 'utf8');

// Replace datasource provider
content = content.replace(
  /datasource db \{\s+provider = "sqlite"\s+url\s+= env\("DATABASE_URL"\)\s+\}/,
  `datasource db {\n  provider = "postgresql"\n  url      = env("DATABASE_URL")\n}`
);

fs.writeFileSync(pgSchemaPath, content, 'utf8');
console.log('Successfully generated prisma/schema.postgresql.prisma for PostgreSQL');
