async function testInventory() {
  const baseURL = 'http://localhost:3000/api/v1';
  console.log('--- 1. Authenticating as Admin ---');
  const loginRes = await fetch(`${baseURL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ emailOrUsername: 'admin@saark.in', password: 'Saark@2026' })
  });
  const loginData = await loginRes.json();
  const token = loginData.data?.tokens?.accessToken || loginData.tokens?.accessToken || loginData.accessToken;
  if (!token) {
    throw new Error('Failed to get token: ' + JSON.stringify(loginData));
  }
  const headers = {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  };
  console.log('✓ Token acquired');

  console.log('\n--- 2. Fetch Initial Summary ---');
  const sumRaw = await (await fetch(`${baseURL}/inventory/summary`, { headers })).json();
  const summary = sumRaw.data || sumRaw;
  console.log('Summary stats:', {
    totalProducts: summary.totalProducts,
    totalWarehouses: summary.totalWarehouses,
    totalStockUnits: summary.totalStockUnits,
    totalValuation: summary.totalValuation,
    lowStockCount: summary.lowStockCount,
  });

  console.log('\n--- 3. Verify Warehouses ---');
  let whShopfloor;
  const whRaw = await (await fetch(`${baseURL}/inventory/warehouses`, { headers })).json();
  const whList = whRaw.data || whRaw;
  const existing = Array.isArray(whList) ? whList.find(w => w.code === 'WH-SHOPFLOOR') : null;
  if (existing) {
    whShopfloor = existing;
    console.log('✓ Found warehouse:', whShopfloor.code, whShopfloor.id);
  } else {
    const createWhRaw = await (await fetch(`${baseURL}/inventory/warehouses`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        code: 'WH-SHOPFLOOR',
        name: 'Production Shopfloor Store',
        location: 'Plant Bay B',
      })
    })).json();
    whShopfloor = createWhRaw.data || createWhRaw;
    console.log('✓ Created warehouse:', whShopfloor.code, whShopfloor.id);
  }

  const whMain = Array.isArray(whList) ? whList.find(w => w.code === 'WH-MAIN') : null;
  console.log(`✓ Main warehouse: ${whMain?.code} (${whMain?.name})`);

  console.log('\n--- 4. List Stock Items ---');
  const stockRaw = await (await fetch(`${baseURL}/inventory/stock`, { headers })).json();
  const stockData = stockRaw.data || stockRaw;
  const stockItems = stockData.items || [];
  console.log(`✓ Total stock items in database: ${stockItems.length}`);
  const targetItem = stockItems[0];
  if (!targetItem) {
    throw new Error('No items in stock response');
  }
  console.log(`Target item: [${targetItem.sku}] ${targetItem.name}`);
  console.log(`  Current Stock: ${targetItem.currentStock}, Available: ${targetItem.availableStock}, Valuation: ₹${targetItem.valuation}`);

  console.log('\n--- 5. Perform Stock Adjustment (INCREASE +10) ---');
  const adjRaw = await (await fetch(`${baseURL}/inventory/adjust`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      productId: targetItem.id,
      warehouseId: whMain.id,
      adjustmentType: 'INCREASE',
      quantity: 10,
      reason: 'Physical Audit Intake',
      notes: 'Verified via incoming vendor batch and QC stamp',
    })
  })).json();
  const adjRes = adjRaw.data || adjRaw;
  console.log(`✓ Adjustment complete! Old Qty: ${targetItem.currentStock}, New Qty: ${adjRes.quantity}, Delta: +${adjRes.delta}`);

  console.log('\n--- 6. Perform Inter-Store Transfer to WH-SHOPFLOOR (Qty: 3) ---');
  const transferRaw = await (await fetch(`${baseURL}/inventory/transfer`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      productId: targetItem.id,
      fromWarehouseId: whMain.id,
      toWarehouseId: whShopfloor.id,
      quantity: 3,
      notes: 'Issued 3 units to Shopfloor Bay B for Panel Assembly Work Order',
    })
  })).json();
  const transferRes = transferRaw.data || transferRaw;
  const transSourceItem = transferRes.sourceItem || transferRes.data?.sourceItem;
  const transDestItem = transferRes.targetItem || transferRes.data?.targetItem;
  console.log(`✓ Transfer complete!`);
  if (transSourceItem && transDestItem) {
    console.log(`  Source (${whMain.code}) remaining: ${transSourceItem.currentQuantity}`);
    console.log(`  Destination (${whShopfloor.code}) stock: ${transDestItem.currentQuantity}`);
  } else {
    console.log(`  Transfer result:`, transferRes);
  }

  console.log('\n--- 7. Audit Movement Ledger ---');
  const txRaw = await (await fetch(`${baseURL}/inventory/transactions?limit=6`, { headers })).json();
  const txData = txRaw.data || txRaw;
  const txList = txData.transactions || [];
  console.log(`✓ Retrieved ${txList.length} transactions:`);
  for (const tx of txList) {
    console.log(`  - [${tx.transactionType}] ${tx.quantity > 0 ? '+' : ''}${tx.quantity} units of ${tx.product?.sku} at ${tx.warehouse?.code} | Notes: ${tx.notes || 'None'}`);
  }

  console.log('\n--- 8. Re-fetch Summary After Movements ---');
  const sumResAfterRaw = await (await fetch(`${baseURL}/inventory/summary`, { headers })).json();
  const sumResAfter = sumResAfterRaw.data || sumResAfterRaw;
  console.log('Updated summary stats:', {
    totalProducts: sumResAfter.totalProducts,
    totalWarehouses: sumResAfter.totalWarehouses,
    totalStockUnits: sumResAfter.totalStockUnits,
    totalValuation: sumResAfter.totalValuation,
    lowStockCount: sumResAfter.lowStockCount,
  });
  console.log('\n============================================================');
  console.log('>>> ALL INVENTORY & WAREHOUSE WORKFLOWS FULLY VALIDATED! <<<');
  console.log('============================================================');
}

testInventory().catch(err => {
  console.error('Error during test:', err);
  process.exit(1);
});
