const fs = require('fs');
const path = require('path');

const files = [
  path.resolve(__dirname, '../prisma/schema.staging.prisma'),
  path.resolve(__dirname, '../prisma/schema.postgresql.prisma')
];

files.forEach(fp => {
  let content = fs.readFileSync(fp, 'utf8');
  const eol = content.includes('\r\n') ? '\r\n' : '\n';
  const target1 = '  @@index([parentFollowUpId])' + eol + '}';
  const repl1 = '  @@index([parentFollowUpId])' + eol + '  @@index([reminderSentAt])' + eol + '  @@index([escalatedAt])' + eol + '}';
  if (!content.includes(target1)) throw new Error('Target 1 not found in ' + fp);
  content = content.replace(target1, repl1);

  const target2 = '  @@index([mediaClass])' + eol + '}' + eol + eol + 'model CrmSavedFilter {';
  const digestModel = [
    'model CrmDigestLog {',
    '  id            String   @id @default(uuid())',
    '  digestDate    String   // Format: "YYYY-MM-DD" in Asia/Kolkata timezone',
    '  staffId       String',
    '  userId        String',
    '  activityCount Int      @default(0)',
    '  dispatchedAt  DateTime @default(now())',
    '',
    '  @@unique([digestDate, staffId])',
    '  @@index([digestDate])',
    '  @@index([userId])',
    '  @@map("crm_digest_logs")',
    '}'
  ].join(eol);

  const repl2 = '  @@index([mediaClass])' + eol + '}' + eol + eol + digestModel + eol + eol + 'model CrmSavedFilter {';
  if (!content.includes(target2)) throw new Error('Target 2 not found in ' + fp);
  content = content.replace(target2, repl2);

  fs.writeFileSync(fp, content, 'utf8');
  console.log('Successfully updated ' + fp);
});
