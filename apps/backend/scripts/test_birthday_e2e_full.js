const { PrismaClient } = require('@prisma/client');
const jwt = require('jsonwebtoken');

const prisma = new PrismaClient();
const BASE_URL = 'http://localhost:3000';

async function runBirthdayTestSuite() {
  console.log('================================================================');
  console.log('🎂 STARTING COMPREHENSIVE BIRTHDAY CELEBRATIONS E2E TEST SUITE');
  console.log('================================================================\n');

  let passedTests = 0;
  let totalTests = 0;

  function assert(condition, testName, detail = '') {
    totalTests++;
    if (condition) {
      passedTests++;
      console.log(`  ✅ [PASS] ${testName} ${detail ? `(${detail})` : ''}`);
    } else {
      console.error(`  ❌ [FAIL] ${testName} ${detail ? `(${detail})` : ''}`);
    }
  }

  try {
    // -------------------------------------------------------------
    // TEST 1: Check Database Setup & Atharav Employee Record
    // -------------------------------------------------------------
    console.log('1. Checking Database Setup for Birthday Feature:');
    const birthdayWishesTable = await prisma.$queryRaw`
      SELECT table_name FROM information_schema.tables WHERE table_name = 'birthday_wishes'
    `;
    assert(birthdayWishesTable.length > 0, 'birthday_wishes table exists in PostgreSQL');

    const atharavUser = await prisma.user.findFirst({
      where: { username: { contains: 'athrav', mode: 'insensitive' } },
      include: { employee: true }
    });
    assert(atharavUser !== null, 'Atharav user exists', `Username: ${atharavUser?.username}`);
    assert(atharavUser?.employee !== null, 'Atharav employee profile linked', `Emp ID: ${atharavUser?.employee?.employeeId}`);
    
    const dob = atharavUser?.employee?.dateOfBirth;
    console.log(`   Atharav DOB: ${dob ? dob.toISOString().split('T')[0] : 'None'}`);
    assert(dob && dob.getMonth() === 10 && dob.getDate() === 20, 'DOB is November 20');

    // -------------------------------------------------------------
    // TEST 2: Static Flutter Web Delivery Check
    // -------------------------------------------------------------
    console.log('\n2. Testing Flutter Web Frontend Serving via NestJS:');
    const webRes = await fetch(`${BASE_URL}/`);
    const webHtml = await webRes.text();
    assert(webRes.status === 200, 'Web server serves Flutter app at /');
    assert(webHtml.includes('flutter_bootstrap.js') || webHtml.includes('flutter'), 'HTML contains Flutter bootstrap bundle');

    // -------------------------------------------------------------
    // TEST 3: Authenticate as Saarkadmin & Call Today Birthdays Endpoint
    // -------------------------------------------------------------
    console.log('\n3. Testing Admin Login & Birthday Detection:');
    const loginRes = await fetch(`${BASE_URL}/api/v1/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'Saarkadmin', password: '12345678' })
    });
    const loginData = await loginRes.json();
    assert(loginRes.status === 200 || loginRes.status === 201, 'Saarkadmin logged in successfully');
    
    const adminToken = loginData?.data?.tokens?.accessToken || loginData?.tokens?.accessToken || loginData?.data?.accessToken || loginData?.accessToken;
    assert(!!adminToken, 'Received JWT Access Token for Saarkadmin', adminToken ? 'Token present' : 'Token missing');

    const bdayRes = await fetch(`${BASE_URL}/api/v1/hr/birthdays/today`, {
      headers: { Authorization: `Bearer ${adminToken}` }
    });
    const bdayRaw = await bdayRes.json();
    console.log('   bdayRaw response:', JSON.stringify(bdayRaw, null, 2));
    assert(bdayRes.status === 200, 'GET /api/v1/hr/birthdays/today returns 200 OK');
    
    const bdayData = bdayRaw?.data || bdayRaw;
    assert(bdayData.hasCelebrantsToday === true, 'hasCelebrantsToday is true');
    assert(bdayData.isMyBirthday === false, 'isMyBirthday is false for Saarkadmin');
    const celebrantsList = bdayData.celebrants || bdayData.todayCelebrants || [];
    assert(Array.isArray(celebrantsList) && celebrantsList.length > 0, 'celebrants array has entries');
    
    const celebrant = celebrantsList.find(c => c.id === atharavUser?.employee?.id || c.employeeCode === 'EMP-2026-003');
    assert(!!celebrant, 'Atharav Darwatakar is detected as today\'s celebrant', `Name: ${celebrant?.fullName}, Age: ${celebrant?.age}`);
    assert(Array.isArray(bdayData.upcoming || bdayData.upcomingBirthdays), 'upcoming list is populated', `Upcoming count: ${(bdayData.upcoming || bdayData.upcomingBirthdays)?.length}`);

    // -------------------------------------------------------------
    // TEST 4: Dispatch Birthday Wish to Atharav
    // -------------------------------------------------------------
    console.log('\n4. Testing Wish Dispatch & Notification Flow:');
    const wishMessage = `Wishing you a wonderful 21st Birthday, Atharav! May you achieve great success and happiness at Saark Exploration! - E2E Verified at ${new Date().toLocaleTimeString('en-IN')}`;
    
    const targetEmpId = celebrant.id || celebrant.employeeId;
    const wishRes = await fetch(`${BASE_URL}/api/v1/hr/birthdays/wish`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`
      },
      body: JSON.stringify({
        employeeId: targetEmpId,
        message: wishMessage
      })
    });
    const wishData = await wishRes.json();
    assert(wishRes.status === 200 || wishRes.status === 201, 'POST /api/v1/hr/birthdays/wish returns 200/201');
    assert(wishData?.message?.includes('delivered') || wishData?.data?.includes('delivered'), 'Confirmation message returned', wishData?.message || wishData?.data);

    // Verify in PostgreSQL table
    const storedWishes = await prisma.$queryRaw`
      SELECT * FROM birthday_wishes WHERE employee_id = ${targetEmpId} ORDER BY created_at DESC LIMIT 5
    `;
    assert(storedWishes.length > 0, 'Wish successfully recorded in birthday_wishes table');
    const latestWish = storedWishes[0];
    assert(latestWish.sender_name === 'Saarkadmin' || latestWish.sender_name.includes('Admin'), 'Sender name recorded as Saarkadmin', `Recorded: ${latestWish.sender_name}`);
    console.log(`   Latest recorded wish ID: ${latestWish.id}`);

    // Verify Notification generated for Atharav
    const notifications = await prisma.notification.findMany({
      where: { userId: atharavUser.id },
      orderBy: { createdAt: 'desc' },
      take: 5
    });
    const birthdayNotification = notifications.find(n => n.title.includes('Birthday Wish') || n.title.includes('Birthday'));
    assert(!!birthdayNotification, 'In-app Notification created for Atharav', `Title: "${birthdayNotification?.title}"`);

    // -------------------------------------------------------------
    // TEST 5: Verify Celebrant Login Experience (Atharav)
    // -------------------------------------------------------------
    console.log('\n5. Testing Celebrant View when Atharav Logs In:');
    const jwtSecret = process.env.JWT_SECRET || 'saark-super-secret-jwt-key-2026';
    const atharavToken = jwt.sign(
      { sub: atharavUser.id, username: atharavUser.username, role: atharavUser.role, email: atharavUser.email },
      jwtSecret,
      { expiresIn: '1h' }
    );

    const atharavBdayRes = await fetch(`${BASE_URL}/api/v1/hr/birthdays/today`, {
      headers: { Authorization: `Bearer ${atharavToken}` }
    });
    const atharavBdayRaw = await atharavBdayRes.json();
    const atharavData = atharavBdayRaw?.data || atharavBdayRaw;
    assert(atharavData.isMyBirthday === true, 'isMyBirthday is TRUE when Atharav logs in');
    assert(atharavData.hasCelebrantsToday === true, 'hasCelebrantsToday is true for Atharav');
    const atharavWishes = atharavData.myCelebration?.wishes || atharavData.celebrants?.[0]?.wishes || [];
    assert(Array.isArray(atharavWishes) && atharavWishes.length > 0, 'Atharav sees the feed of wishes received', `Total wishes received: ${atharavWishes.length}`);

    // -------------------------------------------------------------
    // TEST 6: Test HR Broadcast Birthday Wish
    // -------------------------------------------------------------
    console.log('\n6. Testing HR Official Birthday Broadcast:');
    const broadcastRes = await fetch(`${BASE_URL}/api/v1/hr/birthdays/broadcast`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${adminToken}`
      },
      body: JSON.stringify({
        employeeId: targetEmpId,
        message: 'Happy Birthday from Saark Exploration Management! Wishing you prosperity, growth, and good health!'
      })
    });
    assert(broadcastRes.status === 200 || broadcastRes.status === 201, 'POST /api/v1/hr/birthdays/broadcast returns 200/201');

    console.log('\n================================================================');
    console.log(`🎯 TEST RESULTS SUMMARY: ${passedTests} / ${totalTests} TESTS PASSED (${Math.round((passedTests / totalTests) * 100)}%)`);
    console.log('================================================================\n');

    if (passedTests === totalTests) {
      console.log('🎉 ALL BIRTHDAY NOTIFICATION & CELEBRATION TESTS PASSED PERFECTLY!');
      process.exit(0);
    } else {
      console.error('⚠️ SOME TESTS FAILED. Please review the output above.');
      process.exit(1);
    }
  } catch (err) {
    console.error('❌ Error during E2E test execution:', err);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

runBirthdayTestSuite();
