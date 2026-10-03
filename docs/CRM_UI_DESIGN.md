# SAARK ERP — CRM & Sales System: UI/UX Design System & Wireframes

**Company:** SAARK EXPLORATION PRIVATE LIMITED  
**Document:** `docs/CRM_UI_DESIGN.md`  
**Architect:** Senior Full-Stack ERP & CRM Architect  
**Date:** October 2026  

---

## 1. Visual Design Language
* **Design Philosophy:** Clean, premium industrial enterprise UI. High information density without visual noise.
* **Palette:**
  * Primary Accent: **SAARK Electric Orange** (`#F97316` / `#FB923C`).
  * Dark Canvas: Deep Graphite (`#0F1216`).
  * Dark Surface: Slate Charcoal (`#1A1E24`).
  * Elevated Cards: Soft Charcoal (`#222730`).
  * Borders & Dividers: Subdued Slate (`#2E3642`).
  * Semantic Accents: Success Emerald (`#10B981`), Warning Amber (`#F59E0B`), Danger Coral (`#EF4444`), Info Sky (`#0EA5E9`).
* **Typography:** `Inter` / `Outfit`, geometric numbers with tabular alignment (`FontFeature.tabularFigures()`).

---

## 2. Key Screen Wireframes

### 2.1 CRM Executive Dashboard
```text
+------------------------------------------------------------------------------------------+
|  CRM SALES DASHBOARD                                 [ Filter: This Month v ] [ + New Lead ] |
+------------------------------------------------------------------------------------------+
| [ Total Leads: 48 ] [ Open Opps: 11 ] [ Pipeline: ₹48.5L ] [ Won: ₹18.2L ] [ Overdue: 2! ] |
+------------------------------------------------------------------------------------------+
| PIPELINE FUNNEL (₹48.5L)                     | TODAY'S FOLLOW-UP QUEUE (4)              |
| [==================] Qualification (₹12.0L)  | ! OVERDUE: AquaTech Recirculation (₹3.5L)|
| [===============]    Requirement   (₹9.5L)   |   Call Ramesh Deshmukh (+91 98220...)    |
| [===========]        Tech Eval     (₹14.0L)  |   [ Call Now ]  [ Reschedule ]           |
| [========]           Quote Sent    (₹21.0L)  |------------------------------------------|
| [====]               Negotiation   (₹8.0L)   | > 11:30 AM: Pune Municipal ST Plant      |
| [==========]         Won           (₹29.0L)  |   Site Visit with Sneha (QC Eng)         |
+------------------------------------------------------------------------------------------+
| PRODUCT DEMAND BREAKDOWN                     | RECENT INTERACTIONS                      |
| [o] Booster Pump Panels (42%)                | * 10:15 AM - Call logged: Kalyani Forge  |
| [o] VFD Automation Panels (28%)              | * 09:30 AM - Quote v2 sent: Godrej Agro  |
| [o] Dewatering & STP Panels (18%)            | * Yesterday - Site visit: Bhosari MIDC   |
+------------------------------------------------------------------------------------------+
```

### 2.2 Sales Pipeline (Kanban Board)
```text
+-------------------------------------------------------------------------------------------+
| PIPELINE KANBAN           [ Search Opportunities... ]  [ Filter by Owner v ]  [ + Deal ]  |
+---------------------+---------------------+---------------------+-------------------------+
| QUALIFICATION (5)   | TECH EVAL (4)       | QUOTATION SENT (6)  | NEGOTIATION (2)         |
| Total: ₹12.0 Lakhs  | Total: ₹14.0 Lakhs  | Total: ₹21.0 Lakhs  | Total: ₹8.0 Lakhs       |
+---------------------+---------------------+---------------------+-------------------------+
| [CARD 1]            | [CARD 4]            | [CARD 7]            | [CARD 10]               |
| Kalyani Technoforge | Thermax Water Div   | Godrej Agrovet Ltd  | Praj Industries Ltd     |
| 45kW Recirculation  | STP Control Panel   | 3-Pump Booster Skid | Dewatering Panel (55kW) |
| ₹3,50,000 | 10%     | ₹4,80,000 | 40%     | ₹6,20,000 | 60%     | ₹5,10,000 | 80%         |
| Owner: Amit Joshi   | Owner: Amit Joshi   | Owner: Rahul Patil  | Owner: Vikram Sharma    |
| Follow-up: Today    | Follow-up: 08 Oct   | Quote: Q-2026-0082  | Target: 15 Oct          |
+---------------------+---------------------+---------------------+-------------------------+
```

### 2.3 Customer 360 Workspace
```text
+-------------------------------------------------------------------------------------------+
| <- Back to Customers      KALYANI TECHNOFORGE LTD (CUS-2026-00042)        [ Edit ] [ : ] |
| Segment: VFD PANEL | Type: END_CUSTOMER | Owner: Amit Joshi | Rating: ★★★★☆ (85/100)    |
| GST: 27AAECK1234F1Z5 | Phone: +91 98220 11223 | City: Pune, Maharashtra                   |
+-------------------------------------------------------------------------------------------+
| [Overview] [Contacts (3)] [Timeline] [Opps (2)] [Enquiries (1)] [Site Visits] [Media (4)] |
+-------------------------------------------------------------------------------------------+
| CHRONOLOGICAL TIMELINE                                                                    |
|                                                                                           |
| (•) 03 Oct 2026, 11:15 AM — CALL LOGGED by Amit Joshi                                    |
|     Contact: Ramesh Deshmukh (Purchase Head) | Outcome: INTERESTED                        |
|     "Discussed delivery schedule for 45kW VFD panel. Client agreed to review quote v2."   |
|     Next Follow-up scheduled for: 06 Oct 2026, 10:00 AM                                   |
|                                                                                           |
| (•) 01 Oct 2026, 03:30 PM — SITE VISIT COMPLETED by Rohit Shinde (Prod Eng)              |
|     Location: Plant 2, Bhosari MIDC                                                       |
|     Readings: 418V Phase-to-Phase, 65A Running Load, Ambient 38°C                         |
|     Attached: [Photo 1 - MCC Panel] [Photo 2 - Pump Skid]                                |
|                                                                                           |
| (•) 28 Sep 2026, 02:00 PM — QUOTATION DISPATCHED                                          |
|     Quote Ref: Q-2026-0041 | Value: ₹3,50,000 | Version 1.0                              |
+-------------------------------------------------------------------------------------------+
```

---

## 3. Mobile Adaptive Experience
* **Bottom Navigation Bar:** Fast access to `Dashboard`, `Leads`, `Pipeline`, `Follow-ups`.
* **One-Tap Quick Actions Floating Button:**
  * `Log Call`: Populates active phone dialer and prompts for conversation outcome upon hangup.
  * `Site Visit`: Opens mobile camera to capture panel dimensions and site name.
  * `Quick Lead`: Minimalist 3-field lead capture form for exhibition and field use.
* **Dialer & WhatsApp Integration:**
  * Tapping a phone number launches the native phone dialer (`tel:+91...`).
  * Tapping the WhatsApp badge launches direct chat with prefilled template (`https://wa.me/...`).
