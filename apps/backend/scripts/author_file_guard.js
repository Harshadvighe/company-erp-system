/**
 * ============================================================================
 * SAARK EXPLORATION PVT. LTD. - ERP SYSTEM
 * AUTHOR GOVERNANCE VAULT & FILE INTEGRITY SHIELD
 * ============================================================================
 * 
 * Enforces zero-trust file-level encryption, OS read-only locking, and git pre-commit
 * barriers for sonwanep968@gmail.com.
 * 
 * Commands:
 *   node author_file_guard.js lock
 *   node author_file_guard.js request-otp [requesterEmail]
 *   node author_file_guard.js unlock <OTP> [requesterEmail]
 *   node author_file_guard.js status
 *   node author_file_guard.js check-commit
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');

const REPO_ROOT = path.resolve(__dirname, '../../..');
const TARGET_FILE = path.join(REPO_ROOT, 'SAARK_ERP_ARCHITECTURAL_BLUEPRINT_AND_WORKFLOWS.md');
const VAULT_FILE = path.join(REPO_ROOT, '.author_vault_blueprint.enc');
const LEASE_FILE = path.join(REPO_ROOT, '.author_lease.json');
const BASE_URL = process.env.API_BASE_URL || 'http://127.0.0.1:3000/api/v1';

const AUTHOR_EMAIL = 'sonwanep968@gmail.com';
const MASTER_SECRET = 'saark_governance_master_vault_key_2026_sonwanep968';

// Derive 256-bit encryption key
function getVaultKey() {
  return crypto.scryptSync(MASTER_SECRET, AUTHOR_EMAIL, 32);
}

function encryptContent(plainText) {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-gcm', getVaultKey(), iv);
  let encrypted = cipher.update(plainText, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const authTag = cipher.getAuthTag().toString('hex');
  return JSON.stringify({
    iv: iv.toString('hex'),
    authTag,
    encrypted,
    timestamp: new Date().toISOString(),
    author: AUTHOR_EMAIL,
  });
}

function decryptContent(cipherJsonStr) {
  const envelope = JSON.parse(cipherJsonStr);
  const decipher = crypto.createDecipheriv(
    'aes-256-gcm',
    getVaultKey(),
    Buffer.from(envelope.iv, 'hex'),
  );
  decipher.setAuthTag(Buffer.from(envelope.authTag, 'hex'));
  let decrypted = decipher.update(envelope.encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}

function getLockedBanner() {
  return `# 🔒 SAARK EXPLORATION PVT. LTD. - ARCHITECTURAL BLUEPRINT
## 🛡️ FILE ACCESS LOCKED BY PRIMARY AUTHOR: sonwanep968@gmail.com

> [!CAUTION]
> ### ⛔ ACCESS RESTRICTED - PRIMARY AUTHOR AUTHORIZATION REQUIRED
> This architecture document and its internal engineering workflows are **ENCRYPTED & WRITE-LOCKED**.
> Direct file viewing or editing is strictly prohibited by company governance policy.
>
> **Sole Authorized Gatekeeper:** \`${AUTHOR_EMAIL}\`  
> **Secondary Gatekeeper & Delivery Mail:** \`pooja.saark@gmail.com\`  
> **Governance Enforcement:** \`ACTIVE (Zero-Trust Codebase & Architecture Lock)\`
>
> ---
>
> ### 🔓 How to Decrypt and Unlock This File:
> 1. Double-click or run the interactive batch file:  
>    \`UNLOCK_ARCHITECTURE_VIA_MAIL.bat\`
> 2. An urgent 6-digit authorization OTP will be dispatched to \`${AUTHOR_EMAIL}\`.
> 3. Enter the received OTP in the terminal prompt.
> 4. Upon verification, the governance engine will decrypt this file and grant an authorized 2-hour edit lease.
>
> *Any attempt to modify or commit this file without an active author lease is blocked by operating system read-only attributes and Git pre-commit hooks.*
`;
}

function isFileLocked() {
  if (!fs.existsSync(TARGET_FILE)) return true;
  const content = fs.readFileSync(TARGET_FILE, 'utf8');
  return content.includes('FILE ACCESS LOCKED BY PRIMARY AUTHOR');
}

// ─── LOCK ACTION ─────────────────────────────────────────────────────────────
function lockFile() {
  console.log('\n================================================================');
  console.log('       SAARK ERP: LOCKING ARCHITECTURAL BLUEPRINT FILE');
  console.log('================================================================\n');

  if (!fs.existsSync(TARGET_FILE)) {
    console.error(`Target file does not exist: ${TARGET_FILE}`);
    process.exit(1);
  }

  const currentContent = fs.readFileSync(TARGET_FILE, 'utf8');

  // If already locked, nothing to encrypt
  if (isFileLocked()) {
    console.log('ℹ️  File is already in LOCKED state.');
  } else {
    // Encrypt plain text into vault
    console.log('1. Encrypting architectural blueprint with AES-256-GCM...');
    const cipherJson = encryptContent(currentContent);
    fs.writeFileSync(VAULT_FILE, cipherJson, 'utf8');
    console.log(`   Encrypted vault stored at: ${VAULT_FILE}`);

    // Remove read-only temporarily if present to write banner
    try {
      execSync(`attrib -R "${TARGET_FILE}"`, { stdio: 'ignore' });
    } catch (_) {}

    // Overwrite blueprint with locked banner
    console.log('2. Overwriting file with locked governance security shield...');
    fs.writeFileSync(TARGET_FILE, getLockedBanner(), 'utf8');
  }

  // Remove active lease file
  if (fs.existsSync(LEASE_FILE)) {
    fs.unlinkSync(LEASE_FILE);
    console.log('3. Revoked local author lease token.');
  }

  // Apply OS Read-Only Attribute
  try {
    execSync(`attrib +R "${TARGET_FILE}"`, { stdio: 'ignore' });
    console.log('4. Applied Windows Read-Only attribute (attrib +R).');
  } catch (err) {
    console.warn(`   Notice: Could not set attrib +R: ${err.message}`);
  }

  console.log('\n================================================================');
  console.log(' 🔒 SUCCESS: Blueprint is now ENCRYPTED, READ-ONLY, and LOCKED!');
  console.log(`    Only accessible via OTP sent to ${AUTHOR_EMAIL}`);
  console.log('================================================================\n');
}

// ─── REQUEST OTP ACTION ──────────────────────────────────────────────────────
async function requestOtp(requesterEmail = 'pooja.saark@gmail.com') {
  console.log('\n================================================================');
  console.log(` REQUESTING AUTHOR OTP DISPATCH -> ${AUTHOR_EMAIL}`);
  console.log('================================================================\n');

  const payload = {
    requesterName: 'Saark ERP Engineer',
    requesterEmail: requesterEmail.trim(),
    targetResource: 'SAARK_ERP_ARCHITECTURAL_BLUEPRINT_AND_WORKFLOWS.md',
    changeSummary: 'Interactive request to decrypt and edit architectural blueprint',
  };

  try {
    const res = await fetch(`${BASE_URL}/governance/request-access`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    const json = await res.json();
    if (res.ok) {
      console.log('✅ OTP challenge initiated successfully!');
      console.log(`   Author Email : ${AUTHOR_EMAIL}`);
      console.log('   Delivery Copy: pooja.saark@gmail.com (Resend Cloud API)');
      console.log('   Validity     : 10 minutes (TTL)\n');
      console.log('Please check your email inbox for the 6-digit OTP.\n');
    } else {
      console.error('❌ Failed to request OTP:', JSON.stringify(json, null, 2));
      process.exit(1);
    }
  } catch (err) {
    console.error(`❌ Connection error to backend at ${BASE_URL}:`, err.message);
    process.exit(1);
  }
}

// ─── UNLOCK ACTION ───────────────────────────────────────────────────────────
async function unlockFile(otp, requesterEmail = 'pooja.saark@gmail.com') {
  if (!otp) {
    console.error('Usage: node author_file_guard.js unlock <6-DIGIT-OTP>');
    process.exit(1);
  }

  console.log('\n================================================================');
  console.log(` VERIFYING OTP FOR AUTHOR -> ${AUTHOR_EMAIL}`);
  console.log('================================================================\n');

  if (!fs.existsSync(VAULT_FILE)) {
    console.error(`❌ Encrypted vault file not found: ${VAULT_FILE}`);
    process.exit(1);
  }

  const payload = {
    requesterEmail: requesterEmail.trim(),
    targetResource: 'SAARK_ERP_ARCHITECTURAL_BLUEPRINT_AND_WORKFLOWS.md',
    otp: otp.trim(),
  };

  try {
    const res = await fetch(`${BASE_URL}/governance/verify-access`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    const json = await res.json();
    if (!res.ok) {
      console.error('❌ Verification Failed:', json.message || json.error || json);
      process.exit(1);
    }

    const data = json.data || json;
    console.log('1. OTP validated by governance engine.');
    console.log(`   Lease Token : ${data.leaseToken}`);
    console.log(`   Expires At  : ${data.expiresAt}`);

    // Save active lease file
    fs.writeFileSync(
      LEASE_FILE,
      JSON.stringify(
        {
          leaseToken: data.leaseToken,
          expiresAt: data.expiresAt,
          author: AUTHOR_EMAIL,
          requesterEmail,
          unlockedAt: new Date().toISOString(),
        },
        null,
        2,
      ),
      'utf8',
    );
    console.log('2. Stored temporary authorization lease locally (.author_lease.json).');

    // Remove OS Read-Only attribute
    try {
      execSync(`attrib -R "${TARGET_FILE}"`, { stdio: 'ignore' });
      console.log('3. Removed Windows Read-Only attribute (attrib -R).');
    } catch (_) {}

    // Decrypt content from vault
    console.log('4. Decrypting master architectural blueprint from AES-256-GCM vault...');
    const cipherJson = fs.readFileSync(VAULT_FILE, 'utf8');
    const plainText = decryptContent(cipherJson);

    fs.writeFileSync(TARGET_FILE, plainText, 'utf8');
    console.log('5. Restored plain text architectural blueprint.');

    console.log('\n================================================================');
    console.log(' 🔓 SUCCESS: FILE IS NOW UNLOCKED AND EDITABLE FOR 2 HOURS!');
    console.log('    You can now open and edit the document in your IDE.');
    console.log('    When finished, run: LOCK_ARCHITECTURE.bat to re-secure.');
    console.log('================================================================\n');
  } catch (err) {
    console.error(`❌ Verification Error: ${err.message}`);
    process.exit(1);
  }
}

// ─── STATUS ACTION ───────────────────────────────────────────────────────────
function getStatus() {
  console.log('\n================================================================');
  console.log('       SAARK ERP: AUTHOR GOVERNANCE & FILE STATUS');
  console.log('================================================================\n');

  const locked = isFileLocked();
  console.log(`Protected Target: ${TARGET_FILE}`);
  console.log(`Primary Author  : ${AUTHOR_EMAIL}`);
  console.log(`File State      : ${locked ? '🔒 LOCKED (Encrypted & Read-Only)' : '🔓 UNLOCKED (Decrypted & Editable)'}`);

  if (fs.existsSync(LEASE_FILE)) {
    try {
      const lease = JSON.parse(fs.readFileSync(LEASE_FILE, 'utf8'));
      const isExpired = new Date() > new Date(lease.expiresAt);
      console.log(`Active Lease    : ${lease.leaseToken}`);
      console.log(`Lease Status    : ${isExpired ? 'EXPIRED' : 'VALID & ACTIVE'}`);
      console.log(`Expires At      : ${lease.expiresAt}`);
    } catch (_) {}
  } else {
    console.log('Active Lease    : None (No authorization lease present)');
  }
  console.log('\n================================================================\n');
}

// ─── GIT PRE-COMMIT HOOK CHECK ───────────────────────────────────────────────
function checkGitCommit() {
  try {
    const stagedFiles = execSync('git diff --cached --name-only', { encoding: 'utf8' })
      .split('\n')
      .map((f) => f.trim())
      .filter(Boolean);

    const isProtectedStaged = stagedFiles.some(
      (f) =>
        f.includes('SAARK_ERP_ARCHITECTURAL_BLUEPRINT_AND_WORKFLOWS.md') ||
        f.startsWith('apps/backend/src/modules/governance'),
    );

    if (!isProtectedStaged) {
      // No protected files in commit - allow
      process.exit(0);
    }

    console.log('\n[Governance Shield] Checking author authorization for staged files...');

    // If the blueprint file is in secure LOCKED state, allow committing the locked vault
    if (isFileLocked() && !fs.existsSync(LEASE_FILE)) {
      console.log('🔒 Protected blueprint is in secure LOCKED state. Author integrity confirmed.\n');
      process.exit(0);
    }

    if (!fs.existsSync(LEASE_FILE)) {
      console.error(`
====================================================================
 ⛔ [GOVERNANCE PRE-COMMIT BLOCKED] - AUTHOR PERMISSION REQUIRED
 Cannot commit modifications to protected architectural files!
 Staged files include protected assets requiring OTP approval from:
 ${AUTHOR_EMAIL}

 To unlock and authorize this commit:
 1. Run: UNLOCK_ARCHITECTURE_VIA_MAIL.bat
 2. Verify the 6-digit OTP sent to ${AUTHOR_EMAIL}
====================================================================
`);
      process.exit(1);
    }

    const lease = JSON.parse(fs.readFileSync(LEASE_FILE, 'utf8'));
    if (new Date() > new Date(lease.expiresAt)) {
      console.error(`
====================================================================
 ⛔ [GOVERNANCE PRE-COMMIT BLOCKED] - LEASE EXPIRED
 Your authorization lease has EXPIRED.
 Please request a fresh OTP by running: UNLOCK_ARCHITECTURE_VIA_MAIL.bat
====================================================================
`);
      process.exit(1);
    }

    console.log(`✅ Valid Author Lease verified (${lease.leaseToken}). Proceeding with commit.\n`);
    process.exit(0);
  } catch (err) {
    console.error(`Pre-commit check error: ${err.message}`);
    process.exit(1);
  }
}

// ─── CLI ROUTER ──────────────────────────────────────────────────────────────
const command = (process.argv[2] || '').toLowerCase();
const arg3 = process.argv[3];
const arg4 = process.argv[4];

switch (command) {
  case 'lock':
    lockFile();
    break;
  case 'request-otp':
    requestOtp(arg3);
    break;
  case 'unlock':
    unlockFile(arg3, arg4);
    break;
  case 'status':
    getStatus();
    break;
  case 'check-commit':
    checkGitCommit();
    break;
  default:
    console.log(`
Usage: node author_file_guard.js <command> [args]

Commands:
  lock                     Encrypts file, applies attrib +R, clears active leases
  request-otp [email]      Dispatches 6-digit OTP to sonwanep968@gmail.com
  unlock <otp> [email]     Verifies OTP, restores decrypted file, and unlocks for 2 hours
  status                   Displays current file lock and lease token status
  check-commit             Validates git staged files against active author lease
`);
    break;
}
