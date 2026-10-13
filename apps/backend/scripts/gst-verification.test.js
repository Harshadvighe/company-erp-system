const assert = require('node:assert/strict');
const { after, beforeEach, test } = require('node:test');
const { GstVerificationService } = require('../src/modules/crm/gst-verification.service');

const GSTIN = '24ABKCS2033B1ZV';
const originalFetch = global.fetch;
const environmentKeys = [
  'GSTIN_API_KEY',
  'GST_VERIFICATION_TOKEN_SECRET',
];
const originalEnvironment = Object.fromEntries(
  environmentKeys.map((key) => [key, process.env[key]]),
);

beforeEach(() => {
  process.env.GSTIN_API_KEY = 'test-api-key';
  process.env.GST_VERIFICATION_TOKEN_SECRET = 'test-signing-secret-at-least-32-characters';
});

after(() => {
  global.fetch = originalFetch;
  for (const [key, value] of Object.entries(originalEnvironment)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
});

function jsonResponse(status, payload) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function taxpayerResponse() {
  return jsonResponse(200, {
    success: true,
    gstin: GSTIN,
    credits_remaining: 487,
    data: {
      gstin: GSTIN,
      legal_name: 'Example Legal Name',
      trade_name: 'Example Trade Name',
      status: 'Active',
      registration_date: '2017-07-01',
      state_code: '24',
      address: 'Unit 42, Main Road, Pune',
      city: 'Pune',
      address_details: {
        building_number: '42',
        building_name: 'Unit',
        floor: '2',
        street: 'Main Road',
        locality: 'Pune',
        district: 'Pune',
        city: 'Pune',
        state: 'Gujarat',
        landmark: null,
        pincode: '411001',
      },
      pincode: '411001',
    },
  });
}

test('uses GSTIN Portal GET lookup, normalizes fields, and signs verification proof', async (t) => {
  const requests = [];
  global.fetch = async (url, options) => {
    requests.push({ url: String(url), options });
    return taxpayerResponse();
  };
  t.after(() => {
    global.fetch = originalFetch;
  });

  const service = new GstVerificationService();
  const result = await service.verifyAndFetch(GSTIN, 'user-1');

  assert.equal(result.valid, true);
  assert.equal(result.legalName, 'Example Legal Name');
  assert.equal(result.tradeName, 'Example Trade Name');
  assert.equal(result.address, 'Unit 42, Main Road, Pune');
  assert.equal(result.state, 'Gujarat');
  assert.equal(result.stateCode, '24');
  assert.equal(result.city, 'Pune');
  assert.equal(result.district, 'Pune');
  assert.equal(result.pincode, '411001');
  assert.equal(result.companyStatus, 'Active');
  assert.equal(result.registrationDate, '2017-07-01');
  assert.equal(result.rawPayload, undefined);
  assert.equal(requests.length, 1);
  assert.equal(
    requests[0].url,
    `https://www.gstinapi.in/v1/gstin/${GSTIN}`,
  );
  assert.equal(requests[0].options.method, 'GET');
  assert.deepEqual(requests[0].options.headers, { 'x-api-key': 'test-api-key' });

  const metadata = service.getVerifiedMetadata(
    result.verificationToken,
    GSTIN,
    'user-1',
  );
  assert.equal(metadata.gstVerified, true);
  assert.equal(metadata.gstProviderRef, result.providerRef);
  assert.throws(() =>
    service.getVerifiedMetadata(result.verificationToken, GSTIN, 'user-2'),
  );
});

test('rejects invalid GSTINs before making provider requests', async (t) => {
  let requestCount = 0;
  global.fetch = async () => {
    requestCount++;
    return taxpayerResponse();
  };
  t.after(() => {
    global.fetch = originalFetch;
  });

  await assert.rejects(
    () => new GstVerificationService().verifyAndFetch('24ABKCS2033B1ZX'),
    (error) => error.status === 400,
  );
  assert.equal(requestCount, 0);
});

test('retries HTTP 429 responses at most three times', async (t) => {
  let requestCount = 0;
  global.fetch = async () => {
    requestCount++;
    return jsonResponse(429, { success: false, error: 'Rate limit exceeded' });
  };
  t.after(() => {
    global.fetch = originalFetch;
  });

  await assert.rejects(
    () => new GstVerificationService().verifyAndFetch(GSTIN),
    (error) => error.status === 429,
  );
  assert.equal(requestCount, 3);
});

test('retries HTTP 502 responses at most three times', async (t) => {
  let requestCount = 0;
  global.fetch = async () => {
    requestCount++;
    return jsonResponse(502, { success: false, error: 'Upstream unavailable' });
  };
  t.after(() => {
    global.fetch = originalFetch;
  });

  await assert.rejects(
    () => new GstVerificationService().verifyAndFetch(GSTIN),
    (error) => error.status === 502,
  );
  assert.equal(requestCount, 3);
});

test('maps permanent provider errors without retrying', async (t) => {
  const cases = [
    [400, 400],
    [401, 503],
    [402, 503],
    [403, 503],
    [404, 404],
  ];

  for (const [providerStatus, expectedStatus] of cases) {
    let requestCount = 0;
    global.fetch = async () => {
      requestCount++;
      return jsonResponse(providerStatus, {
        success: false,
        error: 'Provider error',
      });
    };

    await assert.rejects(
      () => new GstVerificationService().verifyAndFetch(GSTIN),
      (error) => error.status === expectedStatus,
    );
    assert.equal(requestCount, 1, `HTTP ${providerStatus} should not retry`);
  }
  t.after(() => {
    global.fetch = originalFetch;
  });
});

test('does not claim verification when provider credentials are absent', async (t) => {
  delete process.env.GSTIN_API_KEY;
  let requestCount = 0;
  global.fetch = async () => {
    requestCount++;
    return taxpayerResponse();
  };
  t.after(() => {
    global.fetch = originalFetch;
  });

  await assert.rejects(
    () => new GstVerificationService().verifyAndFetch(GSTIN),
    (error) => error.status === 503,
  );
  assert.equal(requestCount, 0);
});

test('auto-resolves State and District when provider returns null fields in address_details', async (t) => {
  const maharashtraGstin = '27AACCN7475P1ZN';
  global.fetch = async (url) => {
    const urlStr = String(url);
    if (urlStr.includes('gstinapi.in')) {
      return jsonResponse(200, {
        success: true,
        gstin: maharashtraGstin,
        data: {
          gstin: maharashtraGstin,
          legal_name: 'TEST MAHARASHTRA ENTERPRISES',
          trade_name: 'TEST ENTERPRISES',
          status: 'Active',
          state_code: '27',
          city: 'KARVE NAGAR',
          pincode: '411052',
          address: 'SHOP NO 1, MALHAR BUILDING, KARVE NAGAR',
          address_details: {
            building_number: '1',
            building_name: 'MALHAR BUILDING',
            floor: null,
            street: 'CANAL ROAD',
            locality: 'KARVE NAGAR',
            district: null,
            city: null,
            state: null,
            pincode: '411052',
          },
        },
      });
    }
    if (urlStr.includes('postalpincode.in')) {
      return jsonResponse(200, [
        {
          Status: 'Success',
          PostOffice: [
            {
              Name: 'Karvenagar',
              District: 'Pune',
              State: 'Maharashtra',
              Block: 'Pune City',
              Pincode: '411052',
            },
          ],
        },
      ]);
    }
    return jsonResponse(404, {});
  };
  t.after(() => {
    global.fetch = originalFetch;
  });

  const service = new GstVerificationService();
  const result = await service.verifyAndFetch(maharashtraGstin, 'user-1');

  assert.equal(result.valid, true);
  assert.equal(result.state, 'Maharashtra');
  assert.equal(result.stateCode, '27');
  assert.equal(result.district, 'Pune');
  assert.equal(result.city, 'KARVE NAGAR');
  assert.equal(result.pincode, '411052');
});

test('retries HTTP 503 provider response at most three times and returns user-friendly 503', async (t) => {
  let requestCount = 0;
  global.fetch = async () => {
    requestCount++;
    return jsonResponse(503, { success: false, error: 'Service Unavailable' });
  };
  t.after(() => {
    global.fetch = originalFetch;
  });

  await assert.rejects(
    () => new GstVerificationService().verifyAndFetch(GSTIN),
    (error) => {
      assert.equal(error.status, 503);
      assert.match(error.message, /manually/i);
      return true;
    },
  );
  assert.equal(requestCount, 3);
});

test('retries on network fetch timeout or AbortError and throws 503', async (t) => {
  let requestCount = 0;
  global.fetch = async () => {
    requestCount++;
    const err = new Error('The operation was aborted due to timeout');
    err.name = 'TimeoutError';
    throw err;
  };
  t.after(() => {
    global.fetch = originalFetch;
  });

  await assert.rejects(
    () => new GstVerificationService().verifyAndFetch(GSTIN),
    (error) => {
      assert.equal(error.status, 503);
      assert.match(error.message, /unavailable or timed out/i);
      return true;
    },
  );
  assert.equal(requestCount, 3);
});

test('throws 503 when GST_VERIFICATION_TOKEN_SECRET is missing or too short', async () => {
  delete process.env.GST_VERIFICATION_TOKEN_SECRET;
  await assert.rejects(
    () => new GstVerificationService().verifyAndFetch(GSTIN),
    (error) => {
      assert.equal(error.status, 503);
      assert.match(error.message, /manually/i);
      return true;
    },
  );

  process.env.GST_VERIFICATION_TOKEN_SECRET = 'too-short';
  await assert.rejects(
    () => new GstVerificationService().verifyAndFetch(GSTIN),
    (error) => {
      assert.equal(error.status, 503);
      assert.match(error.message, /manually/i);
      return true;
    },
  );
});
