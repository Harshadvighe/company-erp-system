import {
  BadGatewayException,
  BadRequestException,
  HttpException,
  HttpStatus,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'crypto';

export interface GstVerificationResult {
  valid: boolean;
  gstin: string;
  legalName: string;
  tradeName: string | null;
  pan: string;
  state: string | null;
  stateCode: string;
  city: string | null;
  district: string | null;
  pincode: string | null;
  address: string | null;
  companyType: string;
  companyStatus: string;
  registrationDate: string | null;
  providerRef: string;
  isLiveLookup: true;
  verificationToken: string;
}

interface GstVerificationToken {
  gstin: string;
  userId: string | null;
  providerRef: string;
  verifiedAt: string;
  expiresAt: number;
}

type JsonRecord = Record<string, unknown>;

const GSTIN_PATTERN = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/;
const GSTIN_CHARACTERS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const VERIFICATION_TOKEN_TTL_MS = 15 * 60 * 1000;
const PROVIDER_REF = 'GSTINAPI_LIVE_LOOKUP';
const PROVIDER_BASE_URL = 'https://www.gstinapi.in';
const MAX_LOOKUP_ATTEMPTS = 3;
const RETRY_DELAY_MS = 500;

const ENTITY_TYPES: Record<string, string> = {
  C: 'PVT_LTD',
  P: 'PROPRIETORSHIP',
  F: 'PARTNERSHIP',
  H: 'HUF',
  A: 'AOP',
  T: 'TRUST',
  B: 'BOI',
  L: 'LOCAL_AUTHORITY',
  J: 'ARTIFICIAL_JURIDICAL',
  G: 'GOVT',
};

export const GST_STATE_CODE_MAP: Record<string, string> = {
  '01': 'Jammu and Kashmir',
  '02': 'Himachal Pradesh',
  '03': 'Punjab',
  '04': 'Chandigarh',
  '05': 'Uttarakhand',
  '06': 'Haryana',
  '07': 'Delhi',
  '08': 'Rajasthan',
  '09': 'Uttar Pradesh',
  '10': 'Bihar',
  '11': 'Sikkim',
  '12': 'Arunachal Pradesh',
  '13': 'Nagaland',
  '14': 'Manipur',
  '15': 'Mizoram',
  '16': 'Tripura',
  '17': 'Meghalaya',
  '18': 'Assam',
  '19': 'West Bengal',
  '20': 'Jharkhand',
  '21': 'Odisha',
  '22': 'Chhattisgarh',
  '23': 'Madhya Pradesh',
  '24': 'Gujarat',
  '25': 'Daman and Diu',
  '26': 'Dadra and Nagar Haveli and Daman and Diu',
  '27': 'Maharashtra',
  '28': 'Andhra Pradesh',
  '29': 'Karnataka',
  '30': 'Goa',
  '31': 'Lakshadweep',
  '32': 'Kerala',
  '33': 'Tamil Nadu',
  '34': 'Puducherry',
  '35': 'Andaman and Nicobar Islands',
  '36': 'Telangana',
  '37': 'Andhra Pradesh',
  '38': 'Ladakh',
  '97': 'Other Territory',
  '99': 'Centre Jurisdiction',
};

const PINCODE_PREFIX_DISTRICTS: Record<string, { district: string; state?: string; city?: string }> = {
  '411': { district: 'Pune', state: 'Maharashtra', city: 'Pune' },
  '412': { district: 'Pune', state: 'Maharashtra', city: 'Pune Rural' },
  '413': { district: 'Solapur', state: 'Maharashtra', city: 'Solapur' },
  '414': { district: 'Ahmednagar', state: 'Maharashtra', city: 'Ahmednagar' },
  '415': { district: 'Satara', state: 'Maharashtra', city: 'Satara' },
  '416': { district: 'Kolhapur', state: 'Maharashtra', city: 'Kolhapur' },
  '400': { district: 'Mumbai', state: 'Maharashtra', city: 'Mumbai' },
  '401': { district: 'Thane', state: 'Maharashtra', city: 'Thane' },
  '421': { district: 'Thane', state: 'Maharashtra', city: 'Kalyan' },
  '422': { district: 'Nashik', state: 'Maharashtra', city: 'Nashik' },
  '424': { district: 'Dhule', state: 'Maharashtra', city: 'Dhule' },
  '425': { district: 'Jalgaon', state: 'Maharashtra', city: 'Jalgaon' },
  '431': { district: 'Chhatrapati Sambhaji Nagar', state: 'Maharashtra', city: 'Chhatrapati Sambhaji Nagar' },
  '440': { district: 'Nagpur', state: 'Maharashtra', city: 'Nagpur' },
  '444': { district: 'Amravati', state: 'Maharashtra', city: 'Amravati' },
  '380': { district: 'Ahmedabad', state: 'Gujarat', city: 'Ahmedabad' },
  '390': { district: 'Vadodara', state: 'Gujarat', city: 'Vadodara' },
  '395': { district: 'Surat', state: 'Gujarat', city: 'Surat' },
  '360': { district: 'Rajkot', state: 'Gujarat', city: 'Rajkot' },
  '560': { district: 'Bengaluru', state: 'Karnataka', city: 'Bengaluru' },
  '500': { district: 'Hyderabad', state: 'Telangana', city: 'Hyderabad' },
  '600': { district: 'Chennai', state: 'Tamil Nadu', city: 'Chennai' },
  '110': { district: 'Delhi', state: 'Delhi', city: 'New Delhi' },
  '122': { district: 'Gurugram', state: 'Haryana', city: 'Gurugram' },
  '201': { district: 'Gautam Buddha Nagar', state: 'Uttar Pradesh', city: 'Noida' },
  '700': { district: 'Kolkata', state: 'West Bengal', city: 'Kolkata' },
  '302': { district: 'Jaipur', state: 'Rajasthan', city: 'Jaipur' },
};

function asRecord(value: unknown): JsonRecord | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as JsonRecord)
    : null;
}

function text(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function extractPincode(value: string | null | undefined): string | null {
  if (!value) return null;
  const match = value.match(/\b([1-9][0-9]{5})\b/);
  return match ? match[1] : null;
}

@Injectable()
export class GstVerificationService {
  private readonly logger = new Logger(GstVerificationService.name);

  validateFormat(gstin: string): boolean {
    return typeof gstin === 'string' && GSTIN_PATTERN.test(gstin.trim().toUpperCase());
  }

  validateChecksum(gstin: string): boolean {
    const cleanGstin = gstin.trim().toUpperCase();
    if (!this.validateFormat(cleanGstin)) return false;

    let factor = 1;
    let sum = 0;
    for (let index = 0; index < 14; index++) {
      const codePoint = GSTIN_CHARACTERS.indexOf(cleanGstin[index]);
      let product = factor * codePoint;
      factor = factor === 2 ? 1 : 2;
      product = Math.floor(product / 36) + (product % 36);
      sum += product;
    }

    const checkCodePoint = (36 - (sum % 36)) % 36;
    return GSTIN_CHARACTERS[checkCodePoint] === cleanGstin[14];
  }

  async verifyAndFetch(gstin: string, userId?: string): Promise<GstVerificationResult> {
    const cleanGstin = typeof gstin === 'string' ? gstin.trim().toUpperCase() : '';
    if (!this.validateFormat(cleanGstin) || !this.validateChecksum(cleanGstin)) {
      throw new BadRequestException('Enter a valid 15-character GSTIN, including its checksum digit.');
    }

    this.getVerificationSigningSecret();
    if (!process.env.GSTIN_API_KEY?.trim()) {
      this.logger.warn('GSTIN_API_KEY is not configured on the backend.');
      throw new ServiceUnavailableException(
        'GST verification service is not configured. You can enter company details manually.',
      );
    }

    const verifiedAt = new Date();
    const providerPayload = await this.lookupTaxpayer(cleanGstin);
    const returnedGstin = text(providerPayload.gstin)?.toUpperCase();
    const data = asRecord(providerPayload.data);
    const legalName = text(data?.legal_name);
    if (
      providerPayload.success !== true ||
      returnedGstin !== cleanGstin ||
      !data ||
      !legalName
    ) {
      throw new BadGatewayException(
        'GSTIN Portal returned an invalid or mismatched taxpayer response.',
      );
    }

    const addressData = asRecord(data?.address_details);
    const address = text(data?.address) || (addressData
      ? [
          text(addressData.building_number),
          text(addressData.building_name),
          text(addressData.floor),
          text(addressData.street),
          text(addressData.locality),
        ]
          .filter((part): part is string => part !== null)
          .join(', ') || null
      : null);

    const stateCode = text(data?.state_code) || cleanGstin.substring(0, 2);
    let state = text(addressData?.state) || text(data?.state) || GST_STATE_CODE_MAP[stateCode] || null;
    let city = text(data?.city) || text(addressData?.city) || text(addressData?.locality);
    let district = text(addressData?.district) || text(data?.district);
    let pincode = text(data?.pincode) || text(addressData?.pincode) || extractPincode(address) || extractPincode(text(data?.address));

    // Resolve district and state from Postal Pincode Directory if missing
    if ((!district || !state || !city) && pincode && /^\d{6}$/.test(pincode)) {
      const postal = await this.resolvePostalInfo(pincode);
      if (postal) {
        if (!district && postal.district) district = postal.district;
        if (!state && postal.state) state = postal.state;
        if (!city && postal.city) city = postal.city;
      }
    }

    // Local prefix fallback for district
    if (!district && pincode && /^\d{6}$/.test(pincode)) {
      const prefix = pincode.substring(0, 3);
      const mapped = PINCODE_PREFIX_DISTRICTS[prefix];
      if (mapped) {
        district = mapped.district;
        if (!state) state = mapped.state || null;
      }
    }

    return {
      valid: true,
      gstin: cleanGstin,
      legalName,
      tradeName: text(data?.trade_name),
      pan: cleanGstin.substring(2, 12),
      state,
      stateCode,
      city,
      district,
      pincode,
      address,
      companyType: ENTITY_TYPES[cleanGstin.charAt(5)] || 'OTHER',
      companyStatus: text(data?.status) || 'UNKNOWN',
      registrationDate: text(data?.registration_date),
      providerRef: PROVIDER_REF,
      isLiveLookup: true,
      verificationToken: this.createVerificationToken(
        cleanGstin,
        userId,
        verifiedAt,
      ),
    };
  }

  private async resolvePostalInfo(
    pincode: string,
  ): Promise<{ district: string | null; state: string | null; city: string | null } | null> {
    try {
      const res = await fetch(`https://api.postalpincode.in/pincode/${pincode}`, {
        signal: AbortSignal.timeout(2500),
      });
      if (!res.ok) return null;
      const json: any = await res.json();
      if (
        Array.isArray(json) &&
        json[0]?.Status === 'Success' &&
        Array.isArray(json[0]?.PostOffice) &&
        json[0].PostOffice.length > 0
      ) {
        const po = json[0].PostOffice[0];
        return {
          district: text(po.District),
          state: text(po.State),
          city: text(po.Block) && po.Block !== 'NA' ? text(po.Block) : text(po.Name),
        };
      }
    } catch {
      // Graceful ignore
    }
    return null;
  }

  getVerifiedMetadata(
    token: string | undefined,
    gstin: string | null,
    userId?: string,
  ): { gstVerified: true; gstVerifiedAt: Date; gstProviderRef: string } | null {
    if (token === undefined || token === null || token === '') return null;
    if (typeof token !== 'string') {
      throw new BadRequestException('GST verification proof is invalid. Verify the GSTIN again.');
    }
    if (!gstin) {
      throw new BadRequestException('A GSTIN is required when submitting GST verification.');
    }

    const [encodedPayload, encodedSignature, extra] = token.split('.');
    if (!encodedPayload || !encodedSignature || extra !== undefined) {
      throw new BadRequestException('GST verification has expired or is invalid. Verify the GSTIN again.');
    }

    const expectedSignature = createHmac(
      'sha256',
      this.getVerificationSigningSecret(),
    )
      .update(encodedPayload)
      .digest();
    let suppliedSignature: Buffer;
    let payload: JsonRecord;
    try {
      suppliedSignature = Buffer.from(encodedSignature, 'base64url');
      const parsedPayload = asRecord(
        JSON.parse(Buffer.from(encodedPayload, 'base64url').toString('utf8')),
      );
      if (!parsedPayload) {
        throw new Error('GST verification payload must be an object.');
      }
      payload = parsedPayload;
    } catch {
      throw new BadRequestException('GST verification has expired or is invalid. Verify the GSTIN again.');
    }

    if (
      suppliedSignature.length !== expectedSignature.length ||
      !timingSafeEqual(suppliedSignature, expectedSignature) ||
      typeof payload.gstin !== 'string' ||
      payload.gstin !== gstin.trim().toUpperCase() ||
      !(typeof payload.userId === 'string' || payload.userId === null) ||
      payload.userId !== (userId || null) ||
      payload.providerRef !== PROVIDER_REF ||
      typeof payload.expiresAt !== 'number' ||
      !Number.isFinite(payload.expiresAt) ||
      payload.expiresAt <= Date.now() ||
      typeof payload.verifiedAt !== 'string' ||
      !Number.isFinite(Date.parse(payload.verifiedAt))
    ) {
      throw new BadRequestException('GST verification has expired or is invalid. Verify the GSTIN again.');
    }

    return {
      gstVerified: true,
      gstVerifiedAt: new Date(payload.verifiedAt),
      gstProviderRef: payload.providerRef,
    };
  }

  private createVerificationToken(
    gstin: string,
    userId: string | undefined,
    verifiedAt: Date,
  ): string {
    const payload: GstVerificationToken = {
      gstin,
      userId: userId || null,
      providerRef: PROVIDER_REF,
      verifiedAt: verifiedAt.toISOString(),
      expiresAt: Date.now() + VERIFICATION_TOKEN_TTL_MS,
    };
    const encodedPayload = Buffer.from(JSON.stringify(payload)).toString('base64url');
    const signature = createHmac(
      'sha256',
      this.getVerificationSigningSecret(),
    )
      .update(encodedPayload)
      .digest('base64url');
    return `${encodedPayload}.${signature}`;
  }

  private getVerificationSigningSecret(): string {
    const secret = process.env.GST_VERIFICATION_TOKEN_SECRET?.trim();
    if (!secret || Buffer.byteLength(secret) < 32) {
      this.logger.warn('GST_VERIFICATION_TOKEN_SECRET is not configured or too short (<32 bytes) on the backend.');
      throw new ServiceUnavailableException(
        'GST verification service is not configured. You can enter company details manually.',
      );
    }
    return secret;
  }

  private async lookupTaxpayer(gstin: string): Promise<JsonRecord> {
    const apiKey = process.env.GSTIN_API_KEY!.trim();
    const url = `${PROVIDER_BASE_URL}/v1/gstin/${encodeURIComponent(gstin)}`;

    for (let attempt = 1; attempt <= MAX_LOOKUP_ATTEMPTS; attempt++) {
      let response: Response;
      try {
        response = await this.fetchProvider(url, {
          method: 'GET',
          headers: { 'x-api-key': apiKey },
        });
      } catch (err: any) {
        if (attempt < MAX_LOOKUP_ATTEMPTS) {
          await this.delay(RETRY_DELAY_MS * 2 ** (attempt - 1));
          continue;
        }
        throw new ServiceUnavailableException(
          'GSTIN Portal is unavailable or timed out. Please try again later or enter company details manually.',
        );
      }

      const payload = await this.readProviderJson(response);
      this.logLookupUsage(payload);

      if (
        response.status === 429 ||
        response.status === 502 ||
        response.status === 503 ||
        response.status === 504
      ) {
        if (attempt < MAX_LOOKUP_ATTEMPTS) {
          await this.delay(RETRY_DELAY_MS * 2 ** (attempt - 1));
          continue;
        }
      }

      this.throwProviderError(response.status, payload);
      if (payload.success !== true) {
        throw new BadGatewayException(
          'GSTIN Portal returned an unsuccessful response for the taxpayer lookup. You can enter details manually.',
        );
      }

      return payload;
    }

    throw new BadGatewayException(
      'GSTIN Portal did not complete the taxpayer lookup. You can enter details manually.',
    );
  }

  private async fetchProvider(
    url: string,
    options: RequestInit,
  ): Promise<Response> {
    try {
      return await fetch(url, {
        ...options,
        signal: AbortSignal.timeout(10_000),
      });
    } catch {
      throw new ServiceUnavailableException(
        'GSTIN Portal is unavailable or timed out. Please try again later or enter company details manually.',
      );
    }
  }

  private async readProviderJson(response: Response): Promise<JsonRecord> {
    let payload: unknown;
    try {
      payload = await response.json();
    } catch {
      if (!response.ok) {
        return {};
      }
      throw new BadGatewayException('GSTIN Portal returned an invalid JSON response.');
    }

    const json = asRecord(payload);
    if (!json) {
      if (!response.ok) return {};
      throw new BadGatewayException('GSTIN Portal returned an invalid response.');
    }
    return json;
  }

  private throwProviderError(status: number, payload: JsonRecord): void {
    switch (status) {
      case 200:
        return;
      case 400:
        throw new BadRequestException(
          'GSTIN Portal rejected the GSTIN format. Check the number and try again.',
        );
      case 401:
        throw new ServiceUnavailableException(
          'GSTIN Portal rejected the API key. Check GSTIN_API_KEY in the backend environment.',
        );
      case 402:
        throw new ServiceUnavailableException(
          'GSTIN Portal credits are exhausted. Add credits to the provider account.',
        );
      case 403:
        throw new ServiceUnavailableException(
          'The GSTIN Portal account is deactivated. Contact the provider.',
        );
      case 404:
        throw new NotFoundException(
          'This GSTIN is not registered in the GST database.',
        );
      case 429:
        throw new HttpException(
          'GSTIN Portal rate limit reached. Please retry shortly.',
          HttpStatus.TOO_MANY_REQUESTS,
        );
      case 502:
        throw new BadGatewayException(
          'The GST provider is temporarily unavailable. Please try again later or enter details manually.',
        );
      case 503:
      case 504:
        throw new ServiceUnavailableException(
          'GSTIN Portal is temporarily unavailable. Please try again later or enter company details manually.',
        );
      default:
        if (!payload.success && text(payload.error)) {
          throw new BadGatewayException(
            'GSTIN Portal could not complete the lookup. Please try again later or enter details manually.',
          );
        }
        if (status >= 500) {
          throw new ServiceUnavailableException(
            'GSTIN Portal is temporarily unavailable. Please try again later or enter company details manually.',
          );
        }
        throw new BadGatewayException(
          'GSTIN Portal returned an unexpected response.',
        );
    }
  }

  private logLookupUsage(payload: JsonRecord): void {
    const creditsRemaining = payload.credits_remaining;
    if (
      typeof creditsRemaining === 'number' ||
      (typeof creditsRemaining === 'string' && creditsRemaining.trim())
    ) {
      this.logger.log(`GSTIN Portal credits remaining: ${creditsRemaining}`);
    }
  }

  private delay(milliseconds: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, milliseconds));
  }
}
