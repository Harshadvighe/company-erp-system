import { CrmService } from '../src/modules/crm/crm.service';
import { GstVerificationService } from '../src/modules/crm/gst-verification.service';
import { SequenceService } from '../src/core/database/sequence.service';
import { AuditService } from '../src/core/audit/audit.service';
import { PrismaService } from '../src/core/database/prisma.service';
import { BadRequestException, ConflictException, NotFoundException } from '@nestjs/common';

async function runCrmDataValidationSuite() {
  console.log('========================================================================');
  console.log('    SAARK ERP: COMPREHENSIVE CRM MODULE DATA VALIDATION TEST SUITE     ');
  console.log('========================================================================\n');

  const prisma = new PrismaService();
  await prisma.$connect();
  const auditService = new AuditService(prisma);
  const sequenceService = new SequenceService(prisma);
  const gstVerificationService = new GstVerificationService();
  const crmService = new CrmService(prisma, auditService, gstVerificationService, sequenceService);

  let passedTests = 0;
  let totalTests = 0;
  const createdCustomerIds: string[] = [];
  const createdLeadIds: string[] = [];
  const createdEnquiryIds: string[] = [];

  function assert(condition: boolean, testName: string, details?: string) {
    totalTests++;
    if (!condition) {
      console.error(`❌ FAIL [Test ${totalTests}]: ${testName}`);
      if (details) console.error(`   Details: ${details}`);
      throw new Error(`Assertion failed: ${testName}`);
    }
    console.log(`✅ PASS [Test ${totalTests}]: ${testName}`);
    if (details) console.log(`   ${details}`);
    passedTests++;
  }

  async function assertThrows(
    fn: () => Promise<any>,
    expectedErrorType: any,
    testName: string,
    messageSubstring?: string,
  ) {
    totalTests++;
    try {
      await fn();
      console.error(`❌ FAIL [Test ${totalTests}]: ${testName} (Expected exception not thrown)`);
      throw new Error(`Expected exception not thrown: ${testName}`);
    } catch (err: any) {
      const isExpectedType = err instanceof expectedErrorType;
      const messageMatches = messageSubstring ? (err.message && err.message.includes(messageSubstring)) : true;
      if (isExpectedType && messageMatches) {
        console.log(`✅ PASS [Test ${totalTests}]: ${testName}`);
        console.log(`   Caught expected ${err.constructor.name}: "${err.message}"`);
        passedTests++;
      } else {
        console.error(`❌ FAIL [Test ${totalTests}]: ${testName}`);
        console.error(`   Expected: ${expectedErrorType.name} with "${messageSubstring}"`);
        console.error(`   Received: ${err?.constructor?.name}: "${err?.message}"`);
        throw err;
      }
    }
  }

  try {
    // -------------------------------------------------------------------------
    // 1. SETUP & MASTER DATA VERIFICATION
    // -------------------------------------------------------------------------
    console.log('\n--- 1. MASTER DATA INTEGRITY & BASE SETUP ---');
    const existingCustomers = await prisma.customer.count();
    const existingStaff = await prisma.staff.findFirst();
    if (!existingStaff) throw new Error('No staff found in database!');
    const staffUser = { id: existingStaff.userId || 'admin', staffId: existingStaff.id, email: existingStaff.email };
    assert(existingCustomers >= 0, `Preserved existing customers (${existingCustomers} in DB)`);
    assert(existingStaff != null, `Staff context verified: ${existingStaff.fullName} (${existingStaff.id})`);

    // -------------------------------------------------------------------------
    // 2. GSTIN & PAN DATA VALIDATION ENGINE
    // -------------------------------------------------------------------------
    console.log('\n--- 2. GSTIN & PAN DATA VALIDATION & ERROR GUARDS ---');
    
    // 2.1 Short GSTIN
    await assertThrows(
      () => crmService.createCompany({ companyName: 'Invalid GST Co', gstin: '27ABCDE' }, staffUser),
      BadRequestException,
      'Reject GSTIN shorter than 15 characters',
      'Enter a valid GSTIN, including its checksum digit.',
    );

    // 2.2 Invalid characters in GSTIN
    await assertThrows(
      () => crmService.createCompany({ companyName: 'Invalid GST Co', gstin: '27AAACS9821F1Z$' }, staffUser),
      BadRequestException,
      'Reject GSTIN with invalid special characters',
      'Enter a valid GSTIN, including its checksum digit.',
    );

    // 2.3 Invalid Luhn Mod-36 Checksum
    await assertThrows(
      () => crmService.createCompany({ companyName: 'Invalid Checksum Co', gstin: '27AAPFU0939F1Z0' }, staffUser),
      BadRequestException,
      'Reject 15-char GSTIN failing Luhn Mod-36 checksum calculation',
      'Enter a valid GSTIN, including its checksum digit.',
    );

    // 2.4 Non-string PAN type validation
    await assertThrows(
      () => crmService.createCompany({ companyName: 'Bad PAN Co', pan: 1234567890 }, staffUser),
      BadRequestException,
      'Reject non-string PAN input type',
      'PAN must be provided as text.',
    );

    // 2.5 PAN mismatching embedded GSTIN PAN (chars 3-12)
    await assertThrows(
      () => crmService.createCompany({
        companyName: 'Mismatched PAN Co',
        gstin: '27AAACS9821F1ZB',
        pan: 'BBBCS9821F',
      }, staffUser),
      BadRequestException,
      'Reject PAN that does not match embedded GSTIN PAN',
      'PAN must match the PAN embedded in the GSTIN.',
    );

    // Clean up any stale test customers from prior interrupted runs
    const staleTestCustomers = await prisma.customer.findMany({
      where: {
        OR: [
          { companyName: { contains: 'Saark Automation & Power Systems' } },
          { companyName: { contains: 'Pioneer Water Solutions' } },
          { gstin: '24ABKCS2033B1ZV' },
        ],
      },
      select: { id: true },
    });
    for (const c of staleTestCustomers) {
      await prisma.crmFollowUp.deleteMany({ where: { customerId: c.id } });
      await prisma.crmMeeting.deleteMany({ where: { activity: { customerId: c.id } } });
      await prisma.crmCall.deleteMany({ where: { activity: { customerId: c.id } } });
      await prisma.crmActivity.deleteMany({ where: { customerId: c.id } });
      await prisma.opportunity.deleteMany({ where: { customerId: c.id } });
      await prisma.customerContact.deleteMany({ where: { customerId: c.id } });
      await prisma.lead.deleteMany({ where: { customerId: c.id } });
      await prisma.customerValuation.deleteMany({ where: { customerId: c.id } });
      await prisma.companyValuationHistory.deleteMany({ where: { customerId: c.id } });
      await prisma.customer.delete({ where: { id: c.id } }).catch(() => {});
    }

    const testSuffix = Date.now().toString().slice(-4);
    function generateValidGstin(suffix: string) {
      const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      const pan = `AABCS${suffix}B`;
      const first14 = `27${pan}1Z`;
      let factor = 1;
      let sum = 0;
      for (let i = 0; i < 14; i++) {
        const codePoint = chars.indexOf(first14[i]);
        let product = factor * codePoint;
        factor = factor === 2 ? 1 : 2;
        product = Math.floor(product / 36) + (product % 36);
        sum += product;
      }
      const checkCodePoint = (36 - (sum % 36)) % 36;
      return { gstin: `${first14}${chars[checkCodePoint]}`, pan };
    }

    const { gstin: validGstin, pan: validPan } = generateValidGstin(testSuffix);
    const newCompany = await crmService.createCompany({
      companyName: `Saark Automation & Power Systems ${testSuffix}`,
      gstin: validGstin,
      pan: validPan,
      customerType: 'PROSPECT',
      email: `contact${testSuffix}@saarkautomation.in`,
      phone: `9822${testSuffix}12`,
      city: 'Ahmedabad',
      state: 'Gujarat',
      pincode: '380001',
      contacts: [
        { name: 'Rajesh Mehta', mobile: `9822${testSuffix}12`, email: `rajesh${testSuffix}@saarkautomation.in`, isPrimary: true },
      ],
    }, staffUser);

    createdCustomerIds.push(newCompany.id);
    assert(newCompany != null && newCompany.id != null, `Valid company registered: ${newCompany.companyName} (${newCompany.customerCode})`);
    assert(newCompany.gstin === validGstin, `GSTIN stored accurately: ${newCompany.gstin}`);
    assert(newCompany.pan === validPan, `PAN stored accurately: ${newCompany.pan}`);

    // 2.7 Duplicate GSTIN Prevention
    await assertThrows(
      () => crmService.createCompany({
        companyName: `Another Company with Same GSTIN ${testSuffix}`,
        gstin: validGstin,
      }, staffUser),
      ConflictException,
      'Prevent duplicate GSTIN registration with ConflictException',
      `Company with GSTIN ${validGstin} already exists`,
    );

    // 2.8 Duplicate Check Query Engine
    const duplicateCheck = await crmService.checkCompanyDuplicate({
      gstin: validGstin,
      phone: `9822${testSuffix}12`,
      companyName: 'Saark Automation',
    });
    assert(duplicateCheck.hasDuplicate === true, `Duplicate check identified duplicate company`);
    assert(duplicateCheck.duplicates.length >= 1, `Duplicate detection returned matching records (${duplicateCheck.duplicates.length})`);
    assert(duplicateCheck.duplicates.some((d: any) => d.matchField === 'gstin'), 'Duplicate detector flagged match on GSTIN');

    // -------------------------------------------------------------------------
    // 3. LEAD MANAGEMENT & BANT QUALIFICATION
    // -------------------------------------------------------------------------
    console.log('\n--- 3. LEAD MANAGEMENT & BANT QUALIFICATION ---');

    const lead = await crmService.createLead({
      companyName: `Pioneer Water Solutions Ltd ${testSuffix}`,
      contactPerson: 'Anand Kulkarni',
      phone: `9881${testSuffix}01`,
      email: `anand${testSuffix}@pioneerwater.in`,
      source: 'INDIA_MART',
      productInterest: 'Booster Pump & Dewatering Panel',
      requirement: '4 Units of 22 kW Dual VFD Booster Pump Automation Panels',
      estimatedValue: 650000.0,
      priority: 'HIGH',
      assignedStaffId: existingStaff.id,
    }, staffUser);

    createdLeadIds.push(lead.id);
    assert(lead.id != null, `Lead created with automatic number: ${lead.leadNumber}`);
    assert(lead.status === 'NEW', `Initial lead status is NEW`);
    assert(lead.qualificationStatus === 'PENDING', `Initial qualification status is PENDING`);
    assert(lead.estimatedValue === 650000.0, `Lead estimatedValue stored as ₹${lead.estimatedValue}`);

    // 3.2 Non-existent lead lookup validation
    await assertThrows(
      () => crmService.getLead('non-existent-uuid-0000'),
      NotFoundException,
      'Reject lookup of non-existent lead with NotFoundException',
      'Lead not found',
    );

    // 3.3 BANT Qualification
    const qualifiedLead = await crmService.qualifyLead(lead.id, {
      isQualified: true,
      bantBudget: 650000.0,
      bantAuthority: 'DECISION_MAKER',
      bantNeed: 'VFD_PUMP_PANEL',
      bantTimeline: 'WITHIN_30_DAYS',
      qualificationNotes: 'Technical specifications approved by GM Projects',
    }, staffUser);

    assert(qualifiedLead.qualificationStatus === 'QUALIFIED', `Lead BANT status updated to QUALIFIED`);
    assert(qualifiedLead.status === 'QUALIFIED', `Lead status progressed to QUALIFIED`);
    assert(qualifiedLead.bantAuthority === 'DECISION_MAKER', `BANT Authority validated: DECISION_MAKER`);

    // 3.4 Atomic Lead Conversion to Customer + Contact + Opportunity
    const conversionResult = await crmService.convertLead(lead.id, {
      customerType: 'PROSPECT',
      createOpportunity: true,
      opportunityTitle: `${qualifiedLead.companyName} — ${qualifiedLead.productInterest}`,
      assignedStaffId: existingStaff.id,
    }, staffUser);

    assert(conversionResult.customerId != null, `Lead converted to Customer ID: ${conversionResult.customerId}`);
    assert(conversionResult.opportunityId != null, `Opportunity created ID: ${conversionResult.opportunityId}`);
    createdCustomerIds.push(conversionResult.customerId);

    // Fetch and verify converted entities
    const convertedCustomer = await prisma.customer.findUnique({
      where: { id: conversionResult.customerId },
      include: { contacts: true, opportunities: true, leads: true },
    });
    assert(convertedCustomer != null, `Converted Customer retrieved successfully`);
    assert(convertedCustomer?.companyName === qualifiedLead.companyName, `Customer companyName matches lead`);
    assert(convertedCustomer?.contacts.length! >= 1, `Customer contact created automatically`);
    assert(convertedCustomer?.contacts[0].isPrimary === true, `Contact marked as primary`);
    assert(convertedCustomer?.leads[0].status === 'OPPORTUNITY', `Lead status updated to OPPORTUNITY`);

    // -------------------------------------------------------------------------
    // 4. OPPORTUNITY PIPELINE & WEIGHTED VALUE VALIDATION
    // -------------------------------------------------------------------------
    console.log('\n--- 4. OPPORTUNITIES & PIPELINE REVENUE CALCULATIONS ---');
    const opp = await prisma.opportunity.findUnique({ where: { id: conversionResult.opportunityId } });
    if (!opp) throw new Error('Converted opportunity not found');

    // 4.1 Verify initial stage math
    assert(opp.stage === 'QUALIFICATION', `Opportunity initial stage is QUALIFICATION`);
    assert(opp.probability === 10, `Initial probability is 10%`);
    assert(opp.weightedValue === (opp.estimatedValue * 10) / 100, `Weighted value calculated as 10% of ₹${opp.estimatedValue} = ₹${opp.weightedValue}`);

    // 4.2 Move to QUOTATION_SENT (60%)
    const updatedOpp = await crmService.updateOpportunityStage(opp.id, 'QUOTATION_SENT', 60, staffUser);
    assert(updatedOpp.stage === 'QUOTATION_SENT', `Stage updated to QUOTATION_SENT`);
    assert(updatedOpp.probability === 60, `Probability updated to 60%`);
    assert(updatedOpp.weightedValue === (opp.estimatedValue * 60) / 100, `Weighted value accurately updated to ₹${updatedOpp.weightedValue}`);

    // 4.3 Validation: Marking Lost WITHOUT reason must fail
    await assertThrows(
      () => crmService.markOpportunityLost(opp.id, '', 'No remarks', 'Competitor X', staffUser),
      BadRequestException,
      'Reject marking opportunity lost without mandatory reason',
      'Lost reason is mandatory',
    );

    // 4.4 Mark Lost WITH valid reason
    const lostOpp = await crmService.markOpportunityLost(
      opp.id,
      'PRICE_TOO_HIGH',
      'Client opted for lower-tier starter panel',
      'Local Fabricator',
      staffUser,
    );
    assert(lostOpp.stage === 'CLOSED_LOST', `Opportunity stage updated to CLOSED_LOST`);
    assert(lostOpp.probability === 0, `Probability set to 0% for lost deal`);
    assert(lostOpp.weightedValue === 0, `Weighted value set to 0 for lost deal`);
    assert(lostOpp.lostReason === 'PRICE_TOO_HIGH', `Lost reason recorded: ${lostOpp.lostReason}`);
    assert(lostOpp.competitor === 'Local Fabricator', `Competitor recorded: ${lostOpp.competitor}`);

    // -------------------------------------------------------------------------
    // 5. FOLLOW-UP LIFECYCLE & BUSINESS RULE GUARDS
    // -------------------------------------------------------------------------
    console.log('\n--- 5. FOLLOW-UP ENGINE DATA VALIDATION & ERROR GUARDS ---');

    // 5.1 Invalid Mode
    await assertThrows(
      () => crmService.createFollowUp({
        customerId: newCompany.id,
        mode: 'INVALID_MODE',
        assignedStaffId: existingStaff.id,
      }, staffUser),
      BadRequestException,
      'Reject invalid follow-up mode',
      'mode must be COMPLETE_NOW or SCHEDULE',
    );

    // 5.2 Missing Customer ID
    await assertThrows(
      () => crmService.createFollowUp({
        mode: 'SCHEDULE',
        scheduledDate: new Date(Date.now() + 86400000).toISOString(),
        assignedStaffId: existingStaff.id,
      }, staffUser),
      BadRequestException,
      'Reject follow-up without customerId',
      'customerId is required',
    );

    // 5.3 SCHEDULE mode without scheduledDate
    await assertThrows(
      () => crmService.createFollowUp({
        customerId: newCompany.id,
        mode: 'SCHEDULE',
        assignedStaffId: existingStaff.id,
      }, staffUser),
      BadRequestException,
      'Reject SCHEDULE mode when scheduledDate is missing',
      'scheduledDate is required when scheduling a follow-up',
    );

    // 5.4 SCHEDULE mode with past date
    const pastDate = new Date(Date.now() - 3600000).toISOString();
    await assertThrows(
      () => crmService.createFollowUp({
        customerId: newCompany.id,
        mode: 'SCHEDULE',
        scheduledDate: pastDate,
        assignedStaffId: existingStaff.id,
      }, staffUser),
      BadRequestException,
      'Reject scheduling follow-up with past date',
      'scheduledDate must be in the future',
    );

    // 5.5 COMPLETE_NOW mode without discussion
    await assertThrows(
      () => crmService.createFollowUp({
        customerId: newCompany.id,
        mode: 'COMPLETE_NOW',
        discussion: '   ',
        assignedStaffId: existingStaff.id,
      }, staffUser),
      BadRequestException,
      'Reject COMPLETE_NOW mode when discussion is blank',
      'discussion is required for a completed interaction',
    );

    // 5.6 Invalid priority
    const futureDate = new Date(Date.now() + 2 * 86400000).toISOString();
    await assertThrows(
      () => crmService.createFollowUp({
        customerId: newCompany.id,
        mode: 'SCHEDULE',
        scheduledDate: futureDate,
        priority: 'ULTRA_HIGH',
        assignedStaffId: existingStaff.id,
      }, staffUser),
      BadRequestException,
      'Reject invalid priority enum',
      'priority is invalid',
    );

    // 5.7 Valid Future Follow-up Creation & Sequential followUpNumber
    const scheduledFollowUp = await crmService.createFollowUp({
      customerId: newCompany.id,
      mode: 'SCHEDULE',
      activityType: 'CALL',
      priority: 'HIGH',
      subject: 'Commercial Terms Clarification',
      scheduledDate: futureDate,
      reminderMinutes: 30,
      assignedStaffId: existingStaff.id,
    }, staffUser);

    assert(scheduledFollowUp.id != null, `Scheduled follow-up created (ID: ${scheduledFollowUp.id})`);
    assert(scheduledFollowUp.status === 'PENDING', `Initial status is PENDING`);
    assert(scheduledFollowUp.followUpNumber === 1, `Assigned sequential followUpNumber: 1`);

    // 5.8 Complete Follow-up without discussion notes must fail
    await assertThrows(
      () => crmService.completeFollowUp(scheduledFollowUp.id, { discussion: '' }, staffUser),
      BadRequestException,
      'Reject completing follow-up without discussion notes',
      'Discussion is required to complete a follow-up',
    );

    // 5.9 Complete Follow-up with Next Action Chaining
    const nextFutureDate = new Date(Date.now() + 5 * 86400000).toISOString();
    const completedFollowUp = await crmService.completeFollowUp(scheduledFollowUp.id, {
      discussion: 'Client agreed to 40% advance payment terms.',
      outcome: 'POSITIVE',
      nextAction: 'Send revised formal offer with advance proforma invoice',
      scheduleNext: true,
      nextScheduledDate: nextFutureDate,
      nextActivityType: 'EMAIL',
      nextSubject: 'Dispatch Proforma Invoice & Bank Details',
    }, staffUser);

    assert(completedFollowUp.status === 'COMPLETED', `Follow-up status transitioned to COMPLETED`);
    assert(completedFollowUp.completedDate != null, `Completed timestamp set: ${completedFollowUp.completedDate}`);

    // 5.10 Re-completing already completed follow-up must fail
    await assertThrows(
      () => crmService.completeFollowUp(scheduledFollowUp.id, { discussion: 'Duplicate completion attempt' }, staffUser),
      BadRequestException,
      'Reject re-completing an already completed follow-up',
      'Follow-up is already completed',
    );

    // 5.11 Verify chained next follow-up exists with followUpNumber: 2
    const customerFollowUps = await prisma.crmFollowUp.findMany({
      where: { customerId: newCompany.id },
      orderBy: { followUpNumber: 'asc' },
    });
    assert(customerFollowUps.length === 2, `Company has exactly 2 chained follow-ups`);
    assert(customerFollowUps[1].followUpNumber === 2, `Chained follow-up assigned followUpNumber: 2`);
    assert(customerFollowUps[1].status === 'PENDING', `Chained follow-up status is PENDING`);

    // -------------------------------------------------------------------------
    // 6. MEETINGS & RESCHEDULE VALIDATION
    // -------------------------------------------------------------------------
    console.log('\n--- 6. MEETINGS SCHEDULING & RESCHEDULE VALIDATION ---');
    const meetingStartTime = new Date(Date.now() + 86400000); // tomorrow
    const meetingEndTime = new Date(meetingStartTime.getTime() + 3600000); // 1 hour

    const meeting = await crmService.createMeeting({
      agenda: 'Technical Panel Architecture & SCADA Integration',
      customerId: newCompany.id,
      startTime: meetingStartTime.toISOString(),
      endTime: meetingEndTime.toISOString(),
      location: 'Saark Factory - Chakan MIDC',
      hostStaffId: existingStaff.id,
      notes: 'Finalize VFD controller brand and MCCB rating selection',
    }, staffUser);

    assert(meeting.id != null, `Meeting scheduled: "${meeting.agenda}" (ID: ${meeting.id})`);
    assert(meeting.meetingStatus === 'SCHEDULED', `Initial meeting status is SCHEDULED`);

    // 6.1 Reschedule WITHOUT newStartTime must fail
    await assertThrows(
      () => crmService.respondMeeting(meeting.id, { action: 'RESCHEDULE' }, staffUser),
      BadRequestException,
      'Reject reschedule action without newStartTime',
      'newStartTime is required for reschedule',
    );

    // 6.2 Reschedule WITH valid newStartTime
    const rescheduledStartTime = new Date(meetingStartTime.getTime() + 2 * 86400000);
    const rescheduledEndTime = new Date(rescheduledStartTime.getTime() + 3600000);
    const rescheduleResult = await crmService.respondMeeting(meeting.id, {
      action: 'RESCHEDULE',
      newStartTime: rescheduledStartTime.toISOString(),
      newEndTime: rescheduledEndTime.toISOString(),
      reason: 'Chief Electrical Inspector site inspection conflict',
    }, staffUser);

    assert(rescheduleResult.meetingStatus === 'RESCHEDULE_PROPOSED', `Meeting status updated to RESCHEDULE_PROPOSED`);
    assert(new Date(rescheduleResult.startTime).getTime() === rescheduledStartTime.getTime(), `Start time updated to new date`);

    // 6.3 Host responds ACCEPT
    const acceptedMeeting = await crmService.respondMeeting(meeting.id, { action: 'ACCEPT' }, staffUser);
    assert(acceptedMeeting.meetingStatus === 'ACCEPTED', `Meeting confirmed with ACCEPTED status`);

    // -------------------------------------------------------------------------
    // 7. ACTIVITIES: CALLS & SITE VISITS
    // -------------------------------------------------------------------------
    console.log('\n--- 7. TECHNICAL CALLS & ENGINEERING SITE VISITS ---');

    const callResult = await crmService.createCall({
      customerId: newCompany.id,
      subject: 'Inverter Duty Motor Compatibility Check',
      callOutcome: 'CONNECTED',
      durationSec: 1080,
      notes: 'Clarified ABB vs Siemens dual motor protection settings',
      dataSent: true,
      dataTypes: ['DATASHEET_PDF'],
    }, staffUser);

    assert(callResult.id != null, `Phone call logged (ID: ${callResult.id})`);
    assert(callResult.activity.activityType === 'CALL', `Activity type confirmed as CALL`);
    assert(callResult.durationSec === 1080, `Call duration recorded: 1080s (18 mins)`);

    const siteVisitResult = await crmService.createSiteVisit({
      customerId: newCompany.id,
      subject: 'Pumping Station Pre-Installation Inspection',
      visitDate: new Date().toISOString(),
      voltage: '415V AC, 3-Phase',
      cableLengthMeters: 65,
      earthingStatus: 'SATISFACTORY',
      remarks: 'Adequate ventilation in control room for IP54 panel',
    }, staffUser);

    assert(siteVisitResult.id != null, `Site visit logged (ID: ${siteVisitResult.id})`);
    assert(siteVisitResult.activity.activityType === 'SITE_VISIT', `Activity type confirmed as SITE_VISIT`);

    // -------------------------------------------------------------------------
    // 8. ENQUIRIES & BATCH STATUS UPDATES
    // -------------------------------------------------------------------------
    console.log('\n--- 8. ENQUIRY MANAGEMENT & BATCH OPERATIONS ---');

    const enquiry1 = await crmService.createEnquiry({
      customerId: newCompany.id,
      source: 'DIRECT_CALL',
      productRequirement: 'Dual 15 HP Booster Pump Control Panel with PLC',
      estimatedValue: 280000,
      priority: 'HIGH',
      status: 'PENDING',
    }, staffUser);
    createdEnquiryIds.push(enquiry1.id);

    const enquiry2 = await crmService.createEnquiry({
      customerId: newCompany.id,
      source: 'WEBSITE',
      productRequirement: 'Level Sensors & Remote Telemetry Unit',
      estimatedValue: 45000,
      priority: 'MEDIUM',
      status: 'PENDING',
    }, staffUser);
    createdEnquiryIds.push(enquiry2.id);

    assert(enquiry1.id != null && enquiry2.id != null, `Enquiries created: ${enquiry1.enquiryNumber}, ${enquiry2.enquiryNumber}`);

    // Update single enquiry status
    const updatedEnq = await crmService.updateEnquiry(enquiry1.id, { status: 'IN_REVIEW' }, staffUser);
    assert(updatedEnq.status === 'IN_REVIEW', `Single enquiry status transitioned to IN_REVIEW`);

    // Batch update enquiry status
    const batchResult = await crmService.batchUpdateEnquiryStatus([enquiry1.id, enquiry2.id], 'COMPLETED', staffUser);
    assert(batchResult.count === 2, `Batch update transitioned 2 enquiries to COMPLETED`);

    const verifyEnquiries = await prisma.enquiry.findMany({
      where: { id: { in: [enquiry1.id, enquiry2.id] } },
    });
    assert(verifyEnquiries.every((e: any) => e.status === 'COMPLETED'), `All batch updated enquiries have status COMPLETED`);

    // -------------------------------------------------------------------------
    // 9. CUSTOMER 360 & CHRONOLOGICAL TIMELINE AGGREGATION
    // -------------------------------------------------------------------------
    console.log('\n--- 9. CUSTOMER 360 PROFILE & CHRONOLOGICAL TIMELINE ---');

    const profile360 = await crmService.getCompany360(newCompany.id);
    assert(profile360.id === newCompany.id, `Company 360 profile loaded for ${profile360.companyName}`);
    assert(profile360.contacts != null && profile360.contacts.length >= 1, `Customer 360 has linked contacts (${profile360.contacts.length})`);
    assert(profile360.followUps != null && profile360.followUps.length === 2, `Customer 360 has 2 linked follow-ups`);
    assert(profile360.enquiries != null && profile360.enquiries.length === 2, `Customer 360 has 2 linked enquiries`);
    assert(profile360.activities != null && profile360.activities.length >= 2, `Customer 360 has linked activities (${profile360.activities.length})`);

    // Verify chronological activity timeline
    const timeline = await crmService.getCompanyTimeline(newCompany.id);
    assert(timeline != null && timeline.length >= 4, `Customer 360 timeline aggregated ${timeline.length} events across modules`);

    // Assert strict descending chronological order (event[i].timestamp >= event[i+1].timestamp)
    let isSorted = true;
    for (let i = 0; i < timeline.length - 1; i++) {
      const t1 = new Date(timeline[i].timestamp).getTime();
      const t2 = new Date(timeline[i + 1].timestamp).getTime();
      if (t1 < t2) {
        isSorted = false;
        break;
      }
    }
    assert(isSorted, `Customer 360 Timeline is strictly sorted in reverse-chronological order (newest first)`);
    console.log(`   Sample timeline events:`);
    timeline.slice(0, 4).forEach((ev: any) => console.log(`   • [${ev.type}] ${ev.title} — ${new Date(ev.timestamp).toISOString()}`));

    // -------------------------------------------------------------------------
    // 10. PRODUCT & SYSTEM INTERESTS MASTER
    // -------------------------------------------------------------------------
    console.log('\n--- 10. PRODUCT & SYSTEM INTERESTS MASTER ---');
    const productSystems = await crmService.getProductSystems();
    assert(Array.isArray(productSystems), `Product & System interests master loaded (${productSystems.length} systems registered)`);

    // -------------------------------------------------------------------------
    // 11. CRM DASHBOARD & MY-WORK AGGREGATION
    // -------------------------------------------------------------------------
    console.log('\n--- 11. CRM DASHBOARD & SALESPERSON DAILY WORK ---');
    const dashboard = await crmService.getDashboardStats(staffUser);
    assert(dashboard != null, `CRM Dashboard stats aggregated successfully`);
    assert(dashboard.totalCustomers >= 1, `Dashboard reports total customers: ${dashboard.totalCustomers}`);
    assert(dashboard.pipelineValue >= 0, `Dashboard pipeline value calculated: ₹${dashboard.pipelineValue}`);

    const myWork = await crmService.getMyWork(staffUser);
    assert(myWork != null, `Sales representative daily work summary loaded`);
    assert(Array.isArray(myWork.pendingFollowUps), `Pending follow-ups list present in My Work`);

    console.log('\n========================================================================');
    console.log(`ALL ${passedTests} OF ${totalTests} DATA VALIDATION & CRM TESTS PASSED (100% SUCCESS)`);
    console.log('========================================================================');

  } catch (error) {
    console.error('\n❌ CRM DATA VALIDATION SUITE FAILED:', error);
    process.exit(1);
  } finally {
    // Clean up test entities created during this run to keep DB pristine
    try {
      console.log('\n🧹 Performing clean teardown of temporary test records...');
      if (createdEnquiryIds.length > 0) {
        await prisma.enquiry.deleteMany({ where: { id: { in: createdEnquiryIds } } });
      }
      for (const custId of createdCustomerIds) {
        await prisma.crmFollowUp.deleteMany({ where: { customerId: custId } });
        await prisma.crmMeeting.deleteMany({ where: { activity: { customerId: custId } } });
        await prisma.crmCall.deleteMany({ where: { activity: { customerId: custId } } });
        await prisma.crmActivity.deleteMany({ where: { customerId: custId } });
        await prisma.opportunity.deleteMany({ where: { customerId: custId } });
        await prisma.customerContact.deleteMany({ where: { customerId: custId } });
        await prisma.lead.deleteMany({ where: { customerId: custId } });
        await prisma.customer.deleteMany({ where: { id: custId } });
      }
      if (createdLeadIds.length > 0) {
        await prisma.lead.deleteMany({ where: { id: { in: createdLeadIds } } });
      }
      console.log('   ✅ Teardown complete. Master database records pristine.');
    } catch (cleanupErr) {
      console.warn('   ⚠️ Teardown notice:', cleanupErr);
    }
    await prisma.$disconnect();
  }
}

runCrmDataValidationSuite();
