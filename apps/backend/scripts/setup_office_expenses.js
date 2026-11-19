const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('Ensuring office_expenses table exists in PostgreSQL...');
  
  await prisma.$executeRawUnsafe(`
    CREATE TABLE IF NOT EXISTS office_expenses (
      id VARCHAR(64) PRIMARY KEY,
      voucher_number VARCHAR(64) UNIQUE NOT NULL,
      title VARCHAR(255) NOT NULL,
      category VARCHAR(64) NOT NULL,
      amount DOUBLE PRECISION NOT NULL,
      expense_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      description TEXT,
      receipt_url TEXT,
      status VARCHAR(32) DEFAULT 'SUBMITTED',
      
      staff_id VARCHAR(64),
      staff_name VARCHAR(255),
      staff_email VARCHAR(255),
      department VARCHAR(128),
      
      reviewed_by VARCHAR(255),
      reviewed_at TIMESTAMP WITH TIME ZONE,
      review_notes TEXT,
      
      approved_by VARCHAR(255),
      approved_at TIMESTAMP WITH TIME ZONE,
      approval_notes TEXT,
      
      payment_mode VARCHAR(64),
      ledger_account VARCHAR(128) DEFAULT 'OFFICE_EXPENSE_LEDGER',
      ledger_ref VARCHAR(128),
      paid_at TIMESTAMP WITH TIME ZONE,
      
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
  `);

  console.log('✅ office_expenses table verified / created successfully!');

  // Check if sample data exists
  const count = await prisma.$queryRawUnsafe(`SELECT COUNT(*)::int as cnt FROM office_expenses;`);
  console.log('Current expense vouchers count:', count[0].cnt);

  if (count[0].cnt === 0) {
    console.log('Seeding initial verified expense vouchers for Saark Exploration...');
    await prisma.$executeRawUnsafe(`
      INSERT INTO office_expenses (
        id, voucher_number, title, category, amount, description, status,
        staff_name, staff_email, department, reviewed_by, reviewed_at, review_notes,
        approved_by, approved_at, approval_notes, payment_mode, ledger_account, ledger_ref, paid_at
      ) VALUES 
      (
        'exp-001', 'EXP-2026-00001', 'Site Visit Travel (Pune MIDC to Chakan Plant)', 'TRAVEL', 1450.00,
        'Fuel & Toll reimbursement for panel commissioning visit at customer site.', 'PAID',
        'Rahul Yeole', 'saarkexploration30@gmail.com', 'Sales & Marketing',
        'HR Admin', NOW() - INTERVAL '3 days', 'Valid site visit log attached.',
        'Saarkadmin', NOW() - INTERVAL '2 days', 'Approved for immediate reimbursement.',
        'PETTY_CASH', 'OFFICE_EXPENSE_LEDGER', 'JV-2026-0089', NOW() - INTERVAL '2 days'
      ),
      (
        'exp-002', 'EXP-2026-00002', 'Shop Floor Industrial Cable Ties & Ferrules', 'TOOLS', 2850.00,
        'Emergency purchase of nylon cable ties and ferrule markers for Bay 3 panel wiring.', 'APPROVED',
        'Amit Deshmukh', 'amit.deshmukh@saark.in', 'Engineering & Assembly',
        'HR Admin', NOW() - INTERVAL '1 day', 'Verified tax invoice from MIDC electricals.',
        'Saarkadmin', NOW() - INTERVAL '12 hours', 'Approved. Accounts to release cash.',
        'PETTY_CASH', 'OFFICE_EXPENSE_LEDGER', 'JV-2026-0094', NULL
      ),
      (
        'exp-003', 'EXP-2026-00003', 'Client Inspection Pantry & Refreshments', 'TEA_PANTRY', 680.00,
        'Tea, coffee and snacks during client FAT inspection visit for 15HP booster panel.', 'REVIEWED',
        'Pooja Saark', 'pooja.saark@gmail.com', 'Human Resources',
        'HR Admin', NOW() - INTERVAL '2 hours', 'Bill verified against visitor entry log.',
        NULL, NULL, NULL,
        NULL, 'OFFICE_EXPENSE_LEDGER', NULL, NULL
      ),
      (
        'exp-004', 'EXP-2026-00004', 'Urgent Courier of Switchgear Sample to Client', 'COURIER', 420.00,
        'DTDC Express dispatch of relay sample and CAD drawing hardcopy to Mumbai.', 'SUBMITTED',
        'Rahul Yeole', 'saarkexploration30@gmail.com', 'Sales & Marketing',
        NULL, NULL, NULL,
        NULL, NULL, NULL,
        NULL, 'OFFICE_EXPENSE_LEDGER', NULL, NULL
      );
    `);
    console.log('✅ Seeded 4 initial expense vouchers across all 4 lifecycle stages!');
  }

  await prisma.$disconnect();
}

main().catch(err => {
  console.error('Fatal:', err);
  process.exit(1);
});
