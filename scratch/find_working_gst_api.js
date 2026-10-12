async function testApis() {
  const gstin = '27AACCN7475P1ZN';
  const urls = [
    {
      name: 'MastersIndia Public Search',
      url: `https://app.mastersindia.co/api/v1/public/gstin/${gstin}`,
    },
    {
      name: 'ClearTax Web Search API',
      url: `https://cleartax.in/api/v1/gstin/verify?gstin=${gstin}`,
    },
    {
      name: 'ClearTax Internal API',
      url: `https://cleartax.in/s/gst-number-search/${gstin}/`,
    },
    {
      name: 'IndiaFilings GST Search',
      url: `https://www.indiafilings.com/api/gstin-search/${gstin}`,
    },
    {
      name: 'Vakilsearch GST Search',
      url: `https://vakilsearch.com/api/v1/gstin/${gstin}`,
    },
    {
      name: 'GSTHero Public',
      url: `https://portal.gsthero.com/api/v1/searchTaxpayer?gstin=${gstin}`,
    },
    {
      name: 'Quicko GST Search',
      url: `https://api.quicko.com/gst/${gstin}`,
    }
  ];

  for (const item of urls) {
    try {
      console.log(`Testing ${item.name}...`);
      const res = await fetch(item.url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*'
        }
      });
      console.log(`  -> Status: ${res.status}`);
      const text = await res.text();
      console.log(`  -> Response (${text.length} chars): ${text.substring(0, 200)}\n`);
    } catch (e) {
      console.log(`  -> Error: ${e.message}\n`);
    }
  }
}

testApis();
