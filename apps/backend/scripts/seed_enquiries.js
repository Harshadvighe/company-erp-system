const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function seed() {
  try {
    let c1 = await prisma.customer.findFirst({ where: { companyName: 'Win Win Distribution Pvt Ltd' } });
    if (!c1) {
      c1 = await prisma.customer.create({
        data: {
          customerCode: 'CUS-WW-001',
          companyName: 'Win Win Distribution Pvt Ltd',
          contactPerson: 'R.HYMAVATHI',
          phone: '9849993375',
          email: 'sales@winwindist.com',
          address: 'MIDC Chakan',
          city: 'Pune',
          state: 'Maharashtra',
          district: 'Pune',
          pincode: '410501',
        },
      });
      console.log('Created c1:', c1.id);
    } else {
      await prisma.customer.update({
        where: { id: c1.id },
        data: { contactPerson: 'R.HYMAVATHI', phone: '9849993375' },
      });
    }

    let c2 = await prisma.customer.findFirst({ where: { companyName: 'new Win Win Distribution Pvt Ltd' } });
    if (!c2) {
      c2 = await prisma.customer.create({
        data: {
          customerCode: 'CUS-WW-035',
          companyName: 'new Win Win Distribution Pvt Ltd',
          contactPerson: 'R.HYMAVATHI',
          phone: '9849993375',
          email: 'sales@newwinwindist.com',
          address: 'MIDC Chakan',
          city: 'Pune',
          state: 'Maharashtra',
          district: 'Pune',
          pincode: '410501',
        },
      });
      console.log('Created c2:', c2.id);
    } else {
      await prisma.customer.update({
        where: { id: c2.id },
        data: { contactPerson: 'R.HYMAVATHI', phone: '9849993375' },
      });
    }

    let enq1 = await prisma.enquiry.findFirst({ where: { customerId: c1.id } });
    if (!enq1) {
      const count = await prisma.enquiry.count();
      enq1 = await prisma.enquiry.create({
        data: {
          enquiryNumber: `ENQ-2026-${String(count + 1).padStart(5, '0')}`,
          customerId: c1.id,
          productInterest: 'Booster Pump Control Panel',
          status: 'Complete',
          remarks: '00 hrs 00 mins',
        },
      });
      console.log('Created enq1:', enq1.id);
    } else {
      await prisma.enquiry.update({
        where: { id: enq1.id },
        data: { status: 'Complete', remarks: '00 hrs 00 mins' },
      });
    }

    let enq2 = await prisma.enquiry.findFirst({ where: { customerId: c2.id } });
    if (!enq2) {
      const count = await prisma.enquiry.count();
      enq2 = await prisma.enquiry.create({
        data: {
          enquiryNumber: `ENQ-2026-${String(count + 1).padStart(5, '0')}`,
          customerId: c2.id,
          productInterest: 'Booster Pump Dual Skid',
          status: 'Pending',
          remarks: '00 hrs 00 mins',
        },
      });
      console.log('Created enq2:', enq2.id);
    } else {
      await prisma.enquiry.update({
        where: { id: enq2.id },
        data: { status: 'Pending', remarks: '00 hrs 00 mins' },
      });
    }

    const all = await prisma.enquiry.findMany({ include: { customer: true } });
    console.log('Total enquiries now in database:', all.length);
    for (const e of all) {
      console.log(`- #${e.enquiryNumber} | ${e.customer?.companyName} | ${e.customer?.contactPerson} | ${e.customer?.phone} | ${e.status}`);
    }
  } catch (err) {
    console.error('Seed error:', err);
  } finally {
    await prisma.$disconnect();
  }
}

seed();
