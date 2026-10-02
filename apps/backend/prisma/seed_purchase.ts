import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding Comprehensive Saark Exploration Purchase & Procurement Module...');

  // 1. Fetch Company & Admin User
  const company = await prisma.company.findFirst();
  const adminUser = await prisma.user.findFirst({ where: { username: 'admin' } });
  const purchaseDept = await prisma.department.findFirst({ where: { code: 'PURCHASE' } });
  const warehouse = await prisma.warehouse.findFirst();

  if (!company || !adminUser || !purchaseDept || !warehouse) {
    console.error('Core dependencies missing. Please run base seed first.');
    return;
  }

  // 2. Fetch or create Products for Electrical & Industrial Panel Procurement
  const products = await prisma.product.findMany({ take: 15 });
  console.log(`Found ${products.length} products to link with procurement`);

  // 3. Extended Vendors with Contacts, Addresses, and Bank Accounts
  console.log('Seeding Extended Vendor Master records...');

  const vendor1 = await prisma.vendor.upsert({
    where: { vendorCode: 'VEN-2026-00001' },
    update: {
      legalName: 'Schneider Electric India Private Limited',
      vendorType: 'MANUFACTURER',
      vendorCategory: 'STRATEGIC_TIER_1',
      creditLimit: 2500000.0,
      paymentTerms: 'NET_45_DAYS',
      rating: 4.9,
      productsSupplied: 'VFD Drives, Contactors, MCBs, PLCs',
    },
    create: {
      vendorCode: 'VEN-2026-00001',
      companyName: 'Schneider Electric India Pvt Ltd',
      legalName: 'Schneider Electric India Private Limited',
      gstin: '27AAACS1234F1Z1',
      pan: 'AAACS1234F',
      vendorType: 'MANUFACTURER',
      vendorCategory: 'STRATEGIC_TIER_1',
      contactPerson: 'Karan Mehra',
      designation: 'Key Account Director',
      email: 'karan.mehra@se.com',
      phone: '+91 98200 44332',
      address: 'Bearys Global Research Triangle, Whitefield',
      city: 'Bengaluru',
      state: 'Karnataka',
      country: 'India',
      pincode: '560066',
      creditLimit: 2500000.0,
      paymentTerms: 'NET_45_DAYS',
      rating: 4.9,
      productsSupplied: 'VFD Drives, Contactors, MCBs, PLCs',
      status: 'ACTIVE',
    },
  });

  // Contacts
  await prisma.vendorContact.deleteMany({ where: { vendorId: vendor1.id } });
  await prisma.vendorContact.createMany({
    data: [
      {
        vendorId: vendor1.id,
        contactPerson: 'Karan Mehra',
        designation: 'Key Account Director',
        mobile: '+91 98200 44332',
        email: 'karan.mehra@se.com',
        isPrimary: true,
      },
      {
        vendorId: vendor1.id,
        contactPerson: 'Sunil Rao',
        designation: 'Logistics & Dispatch Manager',
        mobile: '+91 98200 44335',
        email: 'sunil.dispatch@se.com',
        isPrimary: false,
      },
    ],
  });

  // Addresses
  await prisma.vendorAddress.deleteMany({ where: { vendorId: vendor1.id } });
  await prisma.vendorAddress.createMany({
    data: [
      {
        vendorId: vendor1.id,
        addressType: 'BILLING',
        addressLine: 'Bearys Global Research Triangle, Whitefield',
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        pincode: '560066',
        isDefault: true,
      },
      {
        vendorId: vendor1.id,
        addressType: 'WAREHOUSE',
        addressLine: 'Plot 18, MIDC Industrial Area, Chakan',
        city: 'Pune',
        state: 'Maharashtra',
        country: 'India',
        pincode: '410501',
        isDefault: false,
      },
    ],
  });

  // Bank Accounts
  await prisma.vendorBankAccount.deleteMany({ where: { vendorId: vendor1.id } });
  await prisma.vendorBankAccount.createMany({
    data: [
      {
        vendorId: vendor1.id,
        accountHolder: 'Schneider Electric India Pvt Ltd',
        bankName: 'Citibank N.A.',
        accountNumber: '05284910284',
        ifscCode: 'CITI0000003',
        branch: 'Fort, Mumbai',
        accountType: 'CURRENT',
        isPrimary: true,
      },
    ],
  });

  // Vendor 2
  const vendor2 = await prisma.vendor.upsert({
    where: { vendorCode: 'VEN-2026-00002' },
    update: {
      legalName: 'Polycab India Limited',
      vendorType: 'MANUFACTURER',
      vendorCategory: 'REGULAR',
      creditLimit: 1000000.0,
      paymentTerms: 'NET_30_DAYS',
      rating: 4.7,
      productsSupplied: 'Control Cables, Copper Busbars, Glands',
    },
    create: {
      vendorCode: 'VEN-2026-00002',
      companyName: 'Polycab Wires & Cables Ltd',
      legalName: 'Polycab India Limited',
      gstin: '24AAACP4920E1ZP',
      pan: 'AAACP4920E',
      vendorType: 'MANUFACTURER',
      vendorCategory: 'REGULAR',
      contactPerson: 'Ramesh Patel',
      designation: 'Regional Sales Manager',
      email: 'ramesh.patel@polycab.com',
      phone: '+91 98250 88771',
      address: 'Polycab House, Mogra Village, Andheri East',
      city: 'Mumbai',
      state: 'Maharashtra',
      country: 'India',
      pincode: '400069',
      creditLimit: 1000000.0,
      paymentTerms: 'NET_30_DAYS',
      rating: 4.7,
      productsSupplied: 'Control Cables, Copper Busbars, Glands',
      status: 'ACTIVE',
    },
  });

  await prisma.vendorBankAccount.deleteMany({ where: { vendorId: vendor2.id } });
  await prisma.vendorBankAccount.create({
    data: {
      vendorId: vendor2.id,
      accountHolder: 'Polycab India Limited',
      bankName: 'HDFC Bank Ltd',
      accountNumber: '50200088192341',
      ifscCode: 'HDFC0000060',
      branch: 'Andheri East, Mumbai',
      accountType: 'CURRENT',
      isPrimary: true,
    },
  });

  // 4. Seed Purchase Requisition
  console.log('Seeding Purchase Requisitions & RFQs...');
  const pr = await prisma.purchaseRequisition.upsert({
    where: { prNumber: 'PR-2026-00001' },
    update: {},
    create: {
      prNumber: 'PR-2026-00001',
      requesterId: adminUser.id,
      requesterName: adminUser.fullName,
      departmentId: purchaseDept.id,
      date: new Date('2026-09-01'),
      requiredDate: new Date('2026-09-15'),
      priority: 'HIGH',
      purpose: 'VFD Drives and Panel Components for Municipal Water Project Batch 3',
      estimatedCost: 195383.84,
      status: 'APPROVED',
      remarks: 'Fast track approval granted by Managing Director',
    },
  });

  // 5. Seed Purchase Order
  console.log('Seeding Purchase Orders...');
  const po = await prisma.purchaseOrder.upsert({
    where: { poNumber: 'PO-2026-00001' },
    update: {},
    create: {
      poNumber: 'PO-2026-00001',
      vendorId: vendor1.id,
      departmentId: purchaseDept.id,
      warehouseId: warehouse.id,
      date: new Date('2026-09-05'),
      expectedDelivery: new Date('2026-09-20'),
      paymentTerms: '30 Days from Inward GRN Acceptance',
      subtotal: 165579.52,
      taxAmount: 29804.32,
      discount: 0.0,
      totalAmount: 195383.84,
      status: 'APPROVED',
      approvedBy: adminUser.fullName,
      approvalDate: new Date('2026-09-06'),
      remarks: 'Critical industrial panel VFD modules',
    },
  });

  // Line items for PO
  await prisma.purchaseOrderItem.deleteMany({ where: { poId: po.id } });
  if (products.length > 0) {
    await prisma.purchaseOrderItem.createMany({
      data: [
        {
          poId: po.id,
          productId: products[0].id,
          itemDescription: `${products[0].name} (Standard Specification)`,
          orderedQuantity: 20,
          receivedQuantity: 20,
          unit: 'PCS',
          rate: 4500.0,
          taxRate: 18.0,
          taxAmount: 16200.0,
          totalAmount: 106200.0,
        },
        {
          poId: po.id,
          productId: products[1] ? products[1].id : products[0].id,
          itemDescription: 'Schneider Auxiliary Contact Block 2NO+2NC',
          orderedQuantity: 50,
          receivedQuantity: 50,
          unit: 'PCS',
          rate: 1511.59,
          taxRate: 18.0,
          taxAmount: 13604.32,
          totalAmount: 89183.84,
        },
      ],
    });
  }

  // 6. Inward Entry / GRN with 11 Product Line items totaling exactly ₹195,383.84
  console.log('Seeding Inward GRN entries and 11 line items...');
  const inward = await prisma.inwardEntry.upsert({
    where: { inwardNumber: 'INW-2026-00001' },
    update: {
      grandTotal: 195383.84,
      status: 'QC_COMPLETED',
    },
    create: {
      inwardNumber: 'INW-2026-00001',
      inwardDate: new Date('2026-09-22'),
      vendorId: vendor1.id,
      purchaseOrderId: po.id,
      vendorInvoiceNumber: 'INV-SE-90812',
      invoiceDate: new Date('2026-09-20'),
      departmentId: purchaseDept.id,
      warehouseId: warehouse.id,
      receivedBy: adminUser.fullName,
      transporter: 'V-Trans Express Cargo Ltd',
      vehicleNumber: 'MH-04-GP-8821',
      lrNumber: 'LR-992104-B',
      deliveryChallanNumber: 'DC-88129',
      remarks: 'Delivered in sealed cartons with factory test certificates',
      subtotal: 165579.52,
      taxAmount: 29804.32,
      discount: 0.0,
      grandTotal: 195383.84,
      status: 'QC_COMPLETED',
    },
  });

  // 11 distinct inward line items
  await prisma.inwardEntryItem.deleteMany({ where: { inwardEntryId: inward.id } });
  
  const sampleItems = [
    { name: 'ATV320 7.5HP VFD Inverter Drive', qty: 2, rate: 21000.0, tax: 18.0, batch: 'BT-2026-A1' },
    { name: 'TeSys D Contactors 32A 230V AC', qty: 6, rate: 2850.0, tax: 18.0, batch: 'BT-2026-A2' },
    { name: 'Phase Monitoring Relays RM22TR33', qty: 4, rate: 3200.0, tax: 18.0, batch: 'BT-2026-A3' },
    { name: 'Miniature Circuit Breakers 63A 4P C-Curve', qty: 8, rate: 1650.0, tax: 18.0, batch: 'BT-2026-A4' },
    { name: 'Schneider Digital Voltmeter & Ammeter', qty: 5, rate: 2400.0, tax: 18.0, batch: 'BT-2026-A5' },
    { name: 'Push Button Illuminated 22mm Green', qty: 15, rate: 380.0, tax: 18.0, batch: 'BT-2026-A6' },
    { name: 'Emergency Stop Mushroom Actuator 40mm', qty: 4, rate: 950.0, tax: 18.0, batch: 'BT-2026-A7' },
    { name: 'Din Rail Mounted Terminal Blocks 10 sq mm', qty: 120, rate: 45.0, tax: 18.0, batch: 'BT-2026-A8' },
    { name: 'Cooling Fan Panel Filter 120mm 230V', qty: 6, rate: 1850.0, tax: 18.0, batch: 'BT-2026-A9' },
    { name: 'Panel Thermostat 0-60 Deg C NC', qty: 4, rate: 1120.0, tax: 18.0, batch: 'BT-2026-B1' },
    { name: 'Cable Glands Brass Nickel Plated PG21', qty: 25, rate: 198.0, tax: 18.0, batch: 'BT-2026-B2' },
  ];

  for (let i = 0; i < sampleItems.length; i++) {
    const item = sampleItems[i];
    const prod = products[i % products.length];
    const lineSubtotal = item.qty * item.rate;
    const lineTax = (lineSubtotal * item.tax) / 100;
    const lineTotal = lineSubtotal + lineTax;

    await prisma.inwardEntryItem.create({
      data: {
        inwardEntryId: inward.id,
        productId: prod.id,
        quantity: item.qty,
        unit: 'PCS',
        rate: item.rate,
        taxRate: item.tax,
        taxAmount: lineTax,
        amount: lineTotal,
        batchNumber: item.batch,
        qcRequired: true,
        qcStatus: 'ACCEPTED',
        acceptedQuantity: item.qty,
        rejectedQuantity: 0,
        inspectedBy: adminUser.fullName,
        inspectionDate: new Date('2026-09-22'),
        stockUpdated: true,
      },
    });

    // Record Stock Ledger Transaction
    await prisma.stockTransaction.create({
      data: {
        productId: prod.id,
        warehouseId: warehouse.id,
        transactionType: 'STOCK_IN',
        referenceType: 'INWARD_GRN',
        referenceId: inward.inwardNumber,
        quantity: item.qty,
        unit: 'PCS',
        transactionDate: new Date('2026-09-22'),
        userId: adminUser.id,
        notes: `GRN Accepted QC: ${item.name}`,
      },
    });
  }

  // 7. Purchase Invoice
  console.log('Seeding Purchase Invoices...');
  // Total = 195,383.84, Paid = 26,220.00, Pending = 169,163.84 (exact user example values!)
  const invoice1 = await prisma.purchaseInvoice.upsert({
    where: { invoiceNumber: 'INV-SE-90812' },
    update: {
      totalAmount: 195383.84,
      paidAmount: 26220.00,
      balanceAmount: 169163.84,
      status: 'PARTIALLY_PAID',
    },
    create: {
      invoiceNumber: 'INV-SE-90812',
      vendorId: vendor1.id,
      purchaseOrderId: po.id,
      inwardEntryId: inward.id,
      departmentId: purchaseDept.id,
      financialYear: '2026-27',
      invoiceDate: new Date('2026-09-20'),
      dueDate: new Date('2026-10-20'),
      subtotal: 165579.52,
      taxAmount: 29804.32,
      totalAmount: 195383.84,
      paidAmount: 26220.00,
      balanceAmount: 169163.84,
      status: 'PARTIALLY_PAID',
      remarks: 'Primary invoice for September panel batch',
    },
  });

  // Second pending invoice for Polycab
  const invoice2 = await prisma.purchaseInvoice.upsert({
    where: { invoiceNumber: 'INV-POL-55102' },
    update: {},
    create: {
      invoiceNumber: 'INV-POL-55102',
      vendorId: vendor2.id,
      departmentId: purchaseDept.id,
      financialYear: '2026-27',
      invoiceDate: new Date('2026-09-25'),
      dueDate: new Date('2026-10-25'),
      subtotal: 42000.00,
      taxAmount: 7560.00,
      totalAmount: 49560.00,
      paidAmount: 0.0,
      balanceAmount: 49560.00,
      status: 'UNPAID',
      remarks: 'Heavy copper busbars and earthing flats',
    },
  });

  // 8. Purchase Payment
  console.log('Seeding Purchase Payment & Cheque Details...');
  const payment = await prisma.purchasePayment.upsert({
    where: { paymentNumber: 'PAY-2026-00001' },
    update: {},
    create: {
      paymentNumber: 'PAY-2026-00001',
      vendorId: vendor1.id,
      purchaseInvoiceId: invoice1.id,
      paymentDate: new Date('2026-09-28'),
      amount: 26220.00,
      paymentMode: 'CHEQUE',
      bankAccount: 'HDFC Current A/c - 50200049182391',
      referenceNumber: 'CHQ-882101',
      transactionNumber: 'TXN-HDFC-99120',
      remarks: 'Initial advance cheque payment against invoice INV-SE-90812',
    },
  });

  // Cheque Record
  const existingCheque = await prisma.cheque.findFirst({ where: { chequeNumber: 'CHQ-882101' } });
  if (!existingCheque) {
    await prisma.cheque.create({
      data: {
        chequeNumber: 'CHQ-882101',
        vendorId: vendor1.id,
        purchaseInvoiceId: invoice1.id,
        purchasePaymentId: payment.id,
        chequeDate: new Date('2026-09-28'),
        bankName: 'HDFC Bank Ltd',
        branch: 'MIDC Phase II, Mumbai',
        amount: 26220.00,
        payeeName: 'Schneider Electric India Pvt Ltd',
        depositDate: new Date('2026-09-29'),
        status: 'DEPOSITED',
        remarks: 'A/c Payee Cheque presented for clearing',
      },
    });
  }

  // 9. Outward Document
  console.log('Seeding Outward Documents...');
  const outward = await prisma.outwardDocument.upsert({
    where: { outwardNumber: 'OUT-2026-00001' },
    update: {},
    create: {
      outwardNumber: 'OUT-2026-00001',
      date: new Date('2026-09-30'),
      outwardType: 'REPAIR',
      departmentId: purchaseDept.id,
      fromLocation: 'Plot 42 MIDC Phase II Warehouse',
      toLocation: 'Schneider Service Centre Pune',
      partyType: 'VENDOR',
      partyName: 'Schneider Electric India Pvt Ltd',
      personName: 'Ravi Gaikwad',
      purpose: 'Warranty testing and calibration check',
      referenceNumber: 'RMA-SE-9910',
      vehicleNumber: 'MH-12-PQ-4412',
      remarks: 'Dispatched with returnable gate pass',
      status: 'DISPATCHED',
    },
  });

  await prisma.outwardDocumentItem.deleteMany({ where: { outwardId: outward.id } });
  await prisma.outwardDocumentItem.create({
    data: {
      outwardId: outward.id,
      productId: products[0].id,
      materialName: 'VFD Inverter Drive (For Firmware Recalibration)',
      quantity: 1,
      unit: 'PCS',
    },
  });

  // 10. Audit Log
  await prisma.auditLog.create({
    data: {
      userEmail: adminUser.email,
      action: 'PURCHASE_MODULE_INITIALIZED',
      module: 'PURCHASE',
      details: 'Procurement seed completed with dynamic summary values and pending invoices',
    },
  });

  console.log('🎉 Purchase module seeded successfully!');
  console.log('Summary metrics in DB:');
  console.log('- Total Inward Amount: ₹195,383.84');
  console.log('- Pending Balance (Invoice 1): ₹169,163.84');
  console.log('- Product Lines (Inward 1): 11');
}

main()
  .catch((e) => {
    console.error('Error seeding purchase module:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
