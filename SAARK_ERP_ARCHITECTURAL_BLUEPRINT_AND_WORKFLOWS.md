# SAARK EXPLORATION PVT. LTD. - ERP SYSTEM
## Comprehensive Enterprise Architectural Blueprint & System Workflows

---

> [!CAUTION]
> ### 🛡️ AUTHOR-RESTRICTED GOVERNANCE SHIELD & SECURITY POLICY
> **Primary Author & Architectural Gatekeeper:** `sonwanep968@gmail.com`  
> **Secondary Gatekeeper & Delivery Mail:** `pooja.saark@gmail.com`  
> **Governance Enforcement Level:** `CRITICAL (Zero-Trust Codebase & Architecture Lock)`  
>
> **Strict Security Rule:**  
> No user, developer, client, or automated agent is permitted to directly modify this architectural file, register new ERP modules, or alter core database registers without explicit cryptographic OTP authorization dispatched to `sonwanep968@gmail.com`.
> 
> * **Request Permission API:** `POST /api/v1/governance/request-access`  
> * **Verify OTP & Unlock Lease API:** `POST /api/v1/governance/verify-access`  
> * **Status & Security Audit:** `GET /api/v1/governance/status`  
> 
> Any attempt to bypass or tamper with this file without an authorized lease token (`ACCESS_GRANT_TOKEN`) triggers a security event logged in the PostgreSQL Audit Ledger.

---

## 1. High-Level System Architecture & Topology

The Saark Exploration ERP platform is architected as an industrial-grade, dual-tier enterprise application designed for high-availability manufacturing, CRM, biometrics, and multi-track product development.

```mermaid
flowchart TD
    subgraph ClientTier ["CLIENT TIER (Cross-Platform Flutter 3.47)"]
        WebClient["Flutter Web App (Chrome / Firefox / Edge)"]
        MobileClient["Flutter Mobile App (Android APK / Tablet)"]
        CameraFeed["WebRTC HTML5 Camera Viewport (Live Streaming)"]
        WebClient --> CameraFeed
        MobileClient --> CameraFeed
    end

    subgraph APITier ["ENTERPRISE GATEWAY (NestJS 10.x & TypeScript)"]
        ReverseProxy["Static Asset Server & API Gateway (Port 3000)"]
        AuthModule["Authentication & Strict 2FA Module"]
        GovernanceModule["Governance & Author Protection (sonwanep968@gmail.com)"]
        BiometricService["Face Recognition Service (128-d Vector Engine)"]
        NpdModule["Product Development Dual-Track Engine (24 Steps)"]
        CrmModule["Sales & Marketing CRM Module"]
        ProductionModule["Production & Panel Manufacturing Module"]
        HrModule["Human Resources & Staff Module"]
        AuditService["Enterprise Audit Logging Engine"]
        MailService["SMTP & Resend Mail Dispatcher"]

        ReverseProxy --> AuthModule
        ReverseProxy --> GovernanceModule
        ReverseProxy --> BiometricService
        ReverseProxy --> NpdModule
        ReverseProxy --> CrmModule
        ReverseProxy --> ProductionModule
        ReverseProxy --> HrModule
        AuthModule --> AuditService
        GovernanceModule --> MailService
        GovernanceModule --> AuditService
    end

    subgraph BiometricAIEngine ["BIOMETRIC EMBEDDING ENGINE"]
        PyEngine["Python OpenCV Face Engine (HOG + LBP / Spatial Gradients)"]
        BiometricService --> PyEngine
    end

    subgraph DataTier ["PERSISTENCE & STORAGE TIER"]
        PrismaORM["Prisma 5.22 Database Client"]
        SupabasePG[("Supabase Cloud PostgreSQL Database (Port 6543)")]
        LocalVault[("Encrypted Local Vault & Artifact Storage")]
        
        APITier --> PrismaORM
        PrismaORM --> SupabasePG
        APITier --> LocalVault
    end

    WebClient -->|HTTP / REST / WebSocket| ReverseProxy
    MobileClient -->|HTTP / REST| ReverseProxy
```

---

## 2. Core Operational Workflows & Flowcharts

### Workflow 1: Biometric Authentication, 1:N Face Auto-Login & Bypass Gatekeeper

This workflow governs how users authenticate: via instant 1:N camera scan (no password needed), credential login, or the authorized direct bypass for Rahul Yeole.

```mermaid
flowchart TD
    StartLogin([User Opens Login Screen]) --> CheckHour{Current Time >= 18:00 IST?}
    
    CheckHour -- Yes --> CheckAdminBypass{User is SuperAdmin?}
    CheckAdminBypass -- No --> BlockOfficeClosed[Display: Office Hours Closed at 6:00 PM]
    CheckAdminBypass -- Yes --> AllowLoginPath[Proceed with Administrative Access]
    
    CheckHour -- No --> ChooseMethod{Select Login Method}

    %% Instant Face Auto-Login
    ChooseMethod -- Instant Face Scan --> CaptureFace[WebRTC Snaps Live Frame from Camera]
    CaptureFace --> ExtractLiveVector[Extract 128-Dimensional Biometric Descriptor]
    ExtractLiveVector --> CheckLiveness{Liveness & Anti-Spoof Passed?}
    CheckLiveness -- No --> FailLiveness[Reject: Spoof or Glare Detected]
    CheckLiveness -- Yes --> ScanAllDB[Search All Active Employee Biometrics in PostgreSQL]
    ScanAllDB --> DecryptGCM[Decrypt AES-256-GCM Stored Embeddings]
    DecryptGCM --> CompareVectors[Compute Euclidean Distance & Cosine Similarity]
    CompareVectors --> MatchFound{Similarity >= 70% or Distance <= 0.55?}
    MatchFound -- Yes --> IssueToken[Issue JWT Session & Route to Assigned Module e.g. Sales & Marketing]
    MatchFound -- No --> FailFace[Reject: Face Not Recognized. Use Password Login]

    %% Username & Password
    ChooseMethod -- Username & Password --> EnterCreds[Enter Username/Email & Password]
    EnterCreds --> VerifyDBPassword{Bcrypt Password Valid?}
    VerifyDBPassword -- No --> InvalidCreds[Reject: Invalid Credentials]
    VerifyDBPassword -- Yes --> CheckRahulBypass{Is User Rahul Yeole or Saarkadmin?}
    
    %% Rahul Yeole Bypass
    CheckRahulBypass -- Yes --> RahulGrant[Camera Access Bypassed! Direct JWT Issued -> /sales-marketing]
    CheckRahulBypass -- No --> Check2FARequired{Face Biometric 2FA Enforced?}
    Check2FARequired -- No --> RegularGrant[Issue JWT Session & Route to Target Route]
    Check2FARequired -- Yes --> Face2FAChallenge[Prompt Live Camera Face Verification Modal]
    Face2FAChallenge --> Verify1to1[Verify Live Descriptor vs User's Stored Template]
    Verify1to1 -- Match --> IssueToken
    Verify1to1 -- Mismatch --> LockoutCheck{Attempts >= 3?}
    LockoutCheck -- Yes --> Lockout15m[Lock User Biometric Auth for 15 Minutes]
    LockoutCheck -- No --> Retry2FA[Increment Failed Attempts & Retry]
```

---

### Workflow 2: 30-Minute Presence Verification & Absence Auto-Logout

Every 30 minutes during an active user session, the system automatically checks for physical presence in front of the camera.

```mermaid
sequenceDiagram
    autonumber
    actor User as Employee (e.g. Sales & Marketing)
    participant Client as AppShell & SessionPresenceDialog
    participant Camera as LiveCameraStreamViewport (WebRTC)
    participant Backend as NestJS AuthController (/verify-presence)
    participant DB as Prisma / PostgreSQL Database

    Note over User,Client: User is actively working in Sales & Marketing (/sales-marketing)
    Client->>Client: 30-Minute Timer Elapses (Duration: 30 mins)
    
    alt User is Rahul Yeole or Camera-Bypassed
        Client->>Client: Detects Bypass Flag (saarkexploration30)
        Client->>Client: Silently resets 30-minute timer without opening camera
        Note over User: Continues working completely uninterrupted
    else Regular Employee
        Client->>User: Opens Non-Disruptive Presence Dialog Overlay
        Client->>Camera: Activates live camera stream & starts 45s countdown
        
        loop Every 1.8 seconds until verified or 45s timeout
            Camera->>Client: Snaps live biometric frame
            Client->>Backend: POST /api/v1/auth/verify-presence { face_data, currentRoute }
            Backend->>DB: Decrypt stored template & compare 128-d embeddings
            
            alt Face Matches Authenticated User
                Backend-->>Client: { verified: true, similarity: 89.4% }
                Client->>User: Displays "✅ Presence Verified! Resuming session..."
                Client->>Client: Closes Dialog & Resets 30-Minute Timer
                Note over User: User remains on EXACT screen (/sales-marketing) without page refresh
            else Face Not Detected / Mismatch / User Absent
                Backend-->>Client: { verified: false, message: "Looking for face..." }
            end
        end
        
        opt 45 Seconds Expire without Verified Face
            Client->>User: Displays "❌ Verification Failed. Logging out..."
            Client->>Backend: POST /api/v1/auth/logout
            Client->>Client: AppStorage.deleteAll() & route to /login
            Note over User: Session terminated due to unverified presence
        end
    end
```

---

### Workflow 3: Daily 6:00 PM (18:00 IST) Automatic Office Hours Logout

Enforces company security policy by automatically terminating all non-administrative operational sessions at 6:00 PM.

```mermaid
flowchart TD
    Loop["AppShell Clock Monitor Loop (Every 15 Seconds)"] --> ReadClock["Read DateTime.now() in Indian Standard Time (IST)"]
    ReadClock --> IsAfter6PM{"Current Hour >= 18 (6:00 PM)?"}
    
    IsAfter6PM -- No --> WaitNext["Sleep 15 seconds & re-check"]
    WaitNext --> Loop

    IsAfter6PM -- Yes --> CheckRole{"Is User SuperAdmin / Director?"}
    CheckRole -- Yes --> AllowAdmin["Exempt: Administrative maintenance session remains active"]
    
    CheckRole -- No --> TriggerAutoLogout["Trigger Immediate Auto-Logout Action"]
    TriggerAutoLogout --> ClearStorage["AppStorage.deleteAll() (Clear Tokens & Profile)"]
    ClearStorage --> NotifyUser["Display Alert: '⏰ Office Hours Closed (6:00 PM Auto-Logout Active)'"]
    NotifyUser --> RedirectLogin["Redirect Immediately to /login"]
    
    subgraph ServerSideCutoff ["Server-Side Enforcement (auth.service.ts)"]
        APICall["Incoming Login or Heartbeat Request"] --> ServerHourCheck{"isPastOfficeHours() == true?"}
        ServerHourCheck -- Yes --> RejectAPI["HTTP 401: Office hours ended at 6:00 PM. System closed."]
    end
```

---

### Workflow 4: Product Development & NPD 24-Step Dual-Track Engine

The Product Development (NPD) module coordinates dual engineering tracks: **Software/R&D (Steps 1–12)** and **Hardware/Firmware/QC (Steps 13–24)**, integrated with an immutable artifact vault and factory QC test rigs.

```mermaid
flowchart TD
    subgraph Track1 ["TRACK 1: R&D & SYSTEMS ARCHITECTURE (Steps 1-12)"]
        S1["1. PRD & Requirement Baselines"] --> S2["2. Market & Regulatory Standards (RoHS/CE)"]
        S2 --> S3["3. Concept Architecture"] --> S4["4. Schematic & Core Circuit Design"]
        S4 --> S5["5. BOM Definition & Lifecycle Scrub"] --> S6["6. Component Sourcing Validation"]
        S6 --> S7["7. Simulation & Thermal Analysis"] --> S8["8. Mechanical CAD & Enclosure Design"]
        S8 --> S9["9. Firmware Architecture Specification"] --> S10["10. Board Bring-Up Protocols"]
        S10 --> S11["11. Prototype Alpha Assembly"] --> S12["12. Design Verification Test (DVT)"]
    end

    subgraph Track2 ["TRACK 2: HARDWARE, RIG & FACTORY QC (Steps 13-24)"]
        S13["13. Prototype Beta Build"] --> S14["14. Automated Rig Firmware Ingestion"]
        S14 --> S15["15. Power & Signal Integrity Testing"] --> S16["16. Thermal Chamber Cycling"]
        S16 --> S17["17. EMI/EMC Pre-Compliance Validation"] --> S18["18. Factory QC Rig Calibration"]
        S18 --> S19["19. Tooling & Injection Mold Signoff"] --> S20["20. Pre-Production Pilot Run"]
        S20 --> S21["21. Production Acceptance FAT Protocol"] --> S22["22. Regulatory Compliance Certification"]
        S22 --> S23["23. Packaging & Serialized Labeling"] --> S24["24. Commercial Launch & Mass Production"]
    end

    subgraph VaultAndRegisters ["SSOT REGISTERS & ARTIFACT VAULT"]
        SSOTMap[("SSOT Register Map (Modbus / BLE / Flash Registers)")]
        BOMRoHS[("BOM Verification Engine (Conflict Minerals / RoHS)")]
        ArtifactVault[("Tamper-Proof Artifact Vault (Schematics, Gerbers, Binaries)")]
        FactoryRig[("Automated Factory QC Rig Telemetry Ingestion")]
    end

    Track1 --> S13
    S5 -.-> BOMRoHS
    S9 -.-> SSOTMap
    S12 -.-> ArtifactVault
    S14 -.-> FactoryRig
    S18 -.-> FactoryRig
    S21 -.-> ArtifactVault
```

---

### Workflow 5: Sales & Marketing (CRM) Lead-to-Cash Pipeline

End-to-end commercial operations pipeline ensuring zero duplicate customer entries, strict credit checks, and automated work order routing to production.

```mermaid
flowchart LR
    A["1. Inbound Lead / Enquiry"] --> B["2. Anti-Duplicate Detection Check"]
    B --> C["3. Account / Vendor Verification"]
    C --> D["4. Technical Quotation Drafting"]
    D --> E["5. Margin & Pricing Review"]
    E --> F["6. Customer PO Confirmation"]
    F --> G["7. Sales Order Generation"]
    G --> H["8. Work Order Dispatch to Production"]
    H --> I["9. Panel Manufacturing & FAT"]
    I --> J["10. Accounts Invoicing & Dispatch"]
```

---

## 3. Codebase Architecture & Directory Map

```text
d:\saark_ERP\company-erp-system\
├── 1_START_BACKEND_SERVER.bat               # Starts NestJS server on port 3000
├── 2_OPEN_WEB_ERP.bat                      # Opens ERP web client in browser
├── START_ERP_SYSTEM.bat                    # One-click dual server & client launcher
├── SAARK_ERP_LINKS_AND_ACCESS.txt          # Active URL, Wi-Fi & Credentials directory
├── SAARK_ERP_ARCHITECTURAL_BLUEPRINT_AND_WORKFLOWS.md # THIS MASTER GOVERNANCE FILE
│
├── apps/
│   ├── backend/                            # NestJS 10.x Enterprise Gateway
│   │   ├── prisma/
│   │   │   └── schema.prisma               # 35+ Enterprise PostgreSQL Models
│   │   ├── public/                         # Production Compiled Flutter Web SPA
│   │   │   ├── index.html
│   │   │   ├── main.dart.js                # Release JavaScript Bundle
│   │   │   └── flutter_bootstrap.js
│   │   ├── scripts/                        # Automated Verification Test Suites
│   │   │   └── test_face_login_and_presence_suite.js # Comprehensive Auth Test Suite
│   │   └── src/
│   │       ├── common/                     # Interceptors, Filters, Guards
│   │       ├── core/
│   │       │   ├── audit/                  # PostgreSQL Audit Logging Service
│   │       │   ├── biometrics/             # 128-d Vector Engine & Python OpenCV Runner
│   │       │   ├── database/               # Prisma Database Connection Service
│   │       │   └── notifications/          # SMTP & Resend Email Service
│   │       └── modules/
│   │           ├── auth/                   # Strict 2FA, 1:N Face Login, 6 PM Cutoff
│   │           ├── governance/             # Author Permission Gatekeeper (sonwanep968@gmail.com)
│   │           ├── crm/                    # Sales & Marketing, Quotations, Leads
│   │           ├── npd/                    # Product Development 24-Step Engine
│   │           ├── panel-manufacturing/    # Production, Booster Pump Calculations
│   │           ├── hr/                     # Staff Onboarding & Module Access Control
│   │           ├── inventory/              # Warehouse Stores & Asset Tracking
│   │           └── purchase/               # Procurement & Vendor Purchase Orders
│   │
│   └── mobile/                             # Cross-Platform Flutter Client
│       └── lib/
│           ├── core/
│           │   ├── auth/                   # AuthNotifier, Riverpod State, Storage
│           │   ├── biometrics/             # SessionPresenceDialog, Viewport, WebRTC
│           │   ├── routing/                # GoRouter with Module Protection Guards
│           │   └── widgets/                # AppShell, Responsive Nav, Presence Monitor
│           └── features/
│               ├── authentication/         # LoginPage with Face Auto-Login & Bypass
│               ├── crm/                    # Sales & Marketing Portal
│               ├── product_development/    # NPD 24-Step Board, Vault, SSOT Registers
│               ├── production/             # Manufacturing & QC Management
│               └── hr/                     # Human Resources Management Portal
```

---

## 4. Author Permission & Code Modification Security Protocol

### Designated Author: `sonwanep968@gmail.com`

Any user or developer attempting to make architectural changes, edit this documentation, or register new modules into the codebase must follow this sequence:

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer / Requester
    participant Gate as Governance Controller (/api/v1/governance)
    actor Author as Primary Author (sonwanep968@gmail.com)
    participant Core as Saark ERP Codebase

    Dev->>Gate: POST /request-access { requesterEmail, targetResource, changeSummary }
    Gate->>Gate: Generate Secure 6-Digit Cryptographic OTP (10m TTL)
    Gate->>Author: Dispatches Urgent Security Notification Email with OTP
    Gate-->>Dev: { success: true, message: "OTP sent to sonwanep968@gmail.com" }

    Note over Author: Author inspects requester identity, IP, and proposed changes
    
    alt Author approves and grants OTP to Developer
        Author-->>Dev: Author shares 6-digit OTP
        Dev->>Gate: POST /verify-access { requesterEmail, otp, targetResource }
        Gate->>Gate: Validates OTP against stored challenge
        Gate-->>Dev: { authorized: true, leaseToken: "LEASE-...", expiresAt: "2 hours" }
        Dev->>Core: Commit changes with valid leaseToken header
        Note over Core: Changes merged and recorded in PostgreSQL Audit Ledger
    else Author denies or does not share OTP
        Dev->>Gate: Attempts invalid OTP or times out
        Gate-->>Dev: HTTP 401 Unauthorized: Access Denied
        Note over Core: Codebase and Architectural Blueprint remain 100% LOCKED
    end
```

---

## 5. Summary of System Access Credentials

| Identity / Role | Username / Email | Password | Access Rights & Routing |
| :--- | :--- | :--- | :--- |
| **Managing Director** | `Saarkadmin` | `12345678` | Full unrestricted access to all 15 modules |
| **Author & Governance Gatekeeper** | `sonwanep968@gmail.com` | *OTP Challenge* | Sole authorized gatekeeper for architectural changes & new modules |
| **Sales & Marketing (Rahul Yeole)** | `saarkexploration30` | `Saark@2026` | Direct login bypass (no camera required) $\rightarrow$ `/sales-marketing` |
| **HR / Employee Test Account** | `pooja.saark` | `Saark@2026` | General Employee access (dual-factor face scan enabled) |

---
*Generated by Saark Exploration ERP Engineering Team • Document Version: 2.4.0 • Verified on November 18, 2026*
