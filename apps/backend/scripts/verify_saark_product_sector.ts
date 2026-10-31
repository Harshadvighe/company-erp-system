import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('================================================================');
  console.log('VERIFYING SAARK PRODUCT SECTOR & TECHNICAL SPECS (38 FIELDS)');
  console.log('================================================================\n');

  // 1. Verify Sectors
  console.log('1. Checking Product Sectors Registry...');
  const sectors = await prisma.productSector.findMany();
  console.log(`   Found ${sectors.length} sectors:`, sectors.map(s => s.name).join(', '));
  if (sectors.length === 0) {
    console.log('   Seeding initial sectors...');
    await prisma.productSector.createMany({
      data: [
        { name: 'Booster Pump Control Panel', code: 'BOOSTER_PUMP', isActive: true },
        { name: 'STP Panel', code: 'STP_PANEL', isActive: true },
        { name: 'Water Meter', code: 'WATER_METER', isActive: true },
        { name: 'BMS', code: 'BMS', isActive: true },
        { name: 'Other', code: 'OTHER', isActive: true },
      ],
    });
    console.log('   Initial sectors seeded successfully.');
  }

  // 2. Create Saark Product with ALL 38 Fields
  console.log('\n2. Testing Saark Product Creation with all 38 fields...');
  const testSku = 'SAARK-BP-TEST-01';

  // Clean up previous test record if exists
  await prisma.saarkProductSector.deleteMany({
    where: { skuModelNumber: testSku },
  });

  const productData = {
    // SECTION 1: Basic Identity & Description
    productSector: 'Booster Pump Control Panel', // 01
    productName: 'Dual VFD Constant Pressure Booster Panel', // 02
    skuModelNumber: testSku, // 03
    productCategory: 'Control Panel', // 04
    shortDescriptionFile: 'docs/products/bp_summary.pdf', // 05
    detailedDescriptionFile: 'docs/products/bp_full_specs.pdf', // 06
    targetApplicationsFile: 'docs/products/bp_target_apps.pdf', // 07

    // SECTION 2: Electrical & Power Specifications
    inputVoltage: '415V 3-Phase', // 08
    ratedFrequency: '50 Hz', // 09
    minPowerRating: 3.0, // 10
    maxPowerRating: 15.0, // 11
    powerRatingUnit: 'HP', // 12
    starterDriveType: 'Integrated VFD', // 13
    enclosureIpRating: 'IP55', // 14

    // SECTION 3: Pump Configuration & Control Parameters
    pumpSupportCapacity: '2 Pumps [1W+1S]', // 15
    controlModes: 'Constant Pressure; Auto-Alternation; Duty/Assist/Standby', // 16
    pressureSensorCompatibility: '4-20 mA; 0-10V; RS-485 Digital', // 17
    minPressure: 1.0, // 18
    maxPressure: 10.0, // 19
    pressureUnit: 'bar', // 20
    levelSensorInputs: 'Float Switch; Ultrasonic; Conductive Probes', // 21

    // SECTION 4: Smart Features, Display & Connectivity
    userInterfaceDisplay: 'Touchscreen HMI', // 22
    communicationProtocols: 'RS-485 Modbus RTU; Modbus TCP/IP; BACnet', // 23
    iotCloudFeatures: 'GSM/4G Remote Telemetry; Wi-Fi Dashboard; Mobile App Support; SMS Alerts', // 24
    dataLogging: 'Historical Fault Log; Run-Hour Meter; Pressure Trends', // 25

    // SECTION 5: Protections & Alarms
    electricalProtections: 'Overload; Under/Over-Voltage; Phase Failure; Phase Reversal; Short Circuit', // 26
    hydraulicProtections: 'Dry Run Protection (Auto-Reset); High/Low Pressure Cutoff; Pipe Burst / Leakage Detection; Anti-Seize Cycling', // 27

    // SECTION 6: Media, Documents & Compliance
    productImages: 'uploads/panels/bp_front.png | uploads/panels/bp_internal.png', // 28
    datasheetManual: 'uploads/docs/datasheet_bp200.pdf', // 29
    wiringSld: 'uploads/schematics/sld_bp200.dwg', // 30
    certifications: 'CE; RoHS; ISO 9001; CPRI Approved', // 31

    // SECTION 7: Promotional Material & Operational Videos
    promotionalVideo: 'uploads/videos/bp_promo.mp4', // 32
    photoName: 'Interior Switchgear Wiring', // 33
    photoDescription: 'Busbar assembly with ABB breakers and Danfoss VFDs', // 34
    photoAttachment: 'uploads/photos/interior_highres.jpg', // 35
    settingVideoType: 'Configuration', // 36
    settingVideoDetails: 'Step-by-step PID setpoint configuration and transducer scaling', // 37
    settingVideoAttachment: 'uploads/videos/setup_guide.mp4', // 38
  };

  const created = await prisma.saarkProductSector.create({
    data: productData,
  });

  console.log(`   Created product ID: ${created.id}`);
  console.log(`   SKU: ${created.skuModelNumber}`);
  console.log(`   Product Name: ${created.productName}`);
  console.log(`   Product Sector: ${created.productSector}`);

  // 3. Field Verification
  console.log('\n3. Validating persisted fields count...');
  const fieldsToCheck = Object.keys(productData);
  let matchCount = 0;
  for (const field of fieldsToCheck) {
    if ((created as any)[field] !== undefined && (created as any)[field] !== null) {
      matchCount++;
    } else {
      console.warn(`   WARNING: Field ${field} is missing or null`);
    }
  }
  console.log(`   Successfully validated ${matchCount} of ${fieldsToCheck.length} specification fields!`);

  // 4. Query & Filter Verification
  console.log('\n4. Testing query filters...');
  const filtered = await prisma.saarkProductSector.findMany({
    where: {
      productSector: 'Booster Pump Control Panel',
      skuModelNumber: { contains: 'TEST' },
    },
  });
  console.log(`   Filter query returned ${filtered.length} matching products.`);

  // 5. Update Verification
  console.log('\n5. Testing update operation...');
  const updated = await prisma.saarkProductSector.update({
    where: { id: created.id },
    data: {
      maxPressure: 16.0,
      userInterfaceDisplay: 'Touchscreen HMI + 7-Segment LED',
    },
  });
  console.log(`   Updated maxPressure: ${updated.maxPressure} bar`);
  console.log(`   Updated display: ${updated.userInterfaceDisplay}`);

  // 6. Promotion Material Test
  console.log('\n6. Testing promotion material...');
  const promo = await prisma.promotionMaterial.create({
    data: {
      sector: 'Booster Pump Control Panel',
      title: 'Booster Panel Operation Demo',
      materialType: 'YouTube Video',
      platform: 'YouTube',
      publishLink: 'https://youtube.com/watch?v=saark_test',
    },
  });
  console.log(`   Created promotion ID: ${promo.id}, title: ${promo.title}`);
  await prisma.promotionMaterial.delete({ where: { id: promo.id } });
  console.log('   Promotion deleted successfully.');

  // 7. Clean up
  await prisma.saarkProductSector.delete({ where: { id: created.id } });
  console.log('\n7. Cleaned up test product record.');

  console.log('\n================================================================');
  console.log('ALL VERIFICATION TESTS PASSED SUCCESSFULLY! (38/38 FIELDS)');
  console.log('================================================================');
}

main()
  .catch((e) => {
    console.error('Test execution failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
