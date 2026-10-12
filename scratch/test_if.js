async function testIndiaFilings() {
  const gstin = '27AACCN7475P1ZN';
  const url = 'https://www.indiafilings.com/api/gstin-search/' + gstin;
  try {
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://www.indiafilings.com/gst-search',
        'Origin': 'https://www.indiafilings.com',
        'sec-ch-ua': '"Google Chrome";v="123", "Not:A-Brand";v="8", "Chromium";v="123"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Windows"',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-origin'
      }
    });
    console.log('Status:', res.status);
    const data = await res.text();
    console.log('Response:', data);
  } catch(e) {
    console.log('Error:', e.message);
  }
}
testIndiaFilings();
