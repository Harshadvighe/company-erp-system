const https = require('https');

async function testGstLookup(gstin) {
  console.log(`Checking live lookup options for GSTIN: ${gstin}`);

  const endpoints = [
    {
      name: 'MastersIndia API',
      url: `https://commonapi.mastersindia.co/commonapis/searchgstin?gstin=${gstin}`,
      headers: { 'client_id': '1000' }
    },
    {
      name: 'GSTIN Check Free',
      url: `https://sheet.gstincheck.co.in/check/free/${gstin}`,
    },
    {
      name: 'Razorpay / QuickGST or Public Directory',
      url: `https://api.razorpay.com/v1/payments/gstin/${gstin}`,
    },
    {
      name: 'ClearTax Search Page',
      url: `https://cleartax.in/s/gst-number-search/${gstin}`,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
      }
    },
    {
      name: 'KnowYourGST / GstHero Search',
      url: `https://app.gsthero.com/api/getGstDetails/${gstin}`,
    }
  ];

  for (const ep of endpoints) {
    try {
      console.log(`\nTrying ${ep.name}... (${ep.url})`);
      const res = await fetch(ep.url, {
        headers: ep.headers || {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
        }
      });
      console.log(`  Status: ${res.status}`);
      const text = await res.text();
      console.log(`  Body preview (${text.length} bytes):`, text.substring(0, 300));
      if (text.includes('legal') || text.includes('trade') || text.includes('lgnm') || text.includes('pradr') || text.includes('bno')) {
        console.log('  >>> FOUND DATA KEYWORDS IN RESPONSE! <<<');
      }
    } catch (err) {
      console.log(`  Error:`, err.message);
    }
  }
}

testGstLookup('27AACCN7475P1ZN');
