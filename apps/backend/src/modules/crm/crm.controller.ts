import { Controller, Get, Post, Put, Patch, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CrmService } from './crm.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';

@ApiTags('CRM')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('api/v1/crm')
export class CrmController {
  constructor(private readonly crmService: CrmService) {}

  // ─── DASHBOARD ────────────────────────────────────────────────────────────
  @Get('dashboard')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'CRM Dashboard — pipeline value, conversion rate, follow-ups' })
  getDashboardStats(@Req() req: any) {
    return this.crmService.getDashboardStats(req.user);
  }

  // ─── GLOBAL SEARCH ────────────────────────────────────────────────────────
  @Get('search')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'Global CRM search across companies, leads, enquiries, opportunities, quotations' })
  globalSearch(@Query('q') query: string, @Req() req: any) {
    return this.crmService.globalSearch(query, req.user);
  }

  // ─── LEADS ────────────────────────────────────────────────────────────────
  @Get('leads')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'List leads with filters, search, and pagination' })
  getLeads(@Query() query: any, @Req() req: any) {
    return this.crmService.getLeads(query, req.user);
  }

  @Get('leads/:id')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'Get lead detail' })
  getLead(@Param('id') id: string) {
    return this.crmService.getLead(id);
  }

  @Post('leads')
  @RequirePermissions('CRM:CREATE')
  @ApiOperation({ summary: 'Create new lead' })
  createLead(@Body() dto: any, @Req() req: any) {
    return this.crmService.createLead(dto, req.user);
  }

  @Put('leads/:id')
  @RequirePermissions('CRM:EDIT')
  @ApiOperation({ summary: 'Update lead' })
  updateLead(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.crmService.updateLead(id, dto, req.user);
  }

  @Post('leads/:id/qualify')
  @RequirePermissions('CRM:EDIT')
  @ApiOperation({ summary: 'BANT Qualification for Lead' })
  qualifyLead(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.crmService.qualifyLead(id, dto, req.user);
  }

  @Post('leads/:id/convert')
  @RequirePermissions('CRM:EDIT')
  @ApiOperation({ summary: 'Atomically convert lead to Customer + Opportunity' })
  convertLead(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.crmService.convertLead(id, dto, req.user);
  }

  @Patch('leads/:id/status')
  @RequirePermissions('CRM:EDIT')
  @ApiOperation({ summary: 'Update lead status' })
  updateLeadStatus(@Param('id') id: string, @Body() body: { status: string }, @Req() req: any) {
    return this.crmService.updateLead(id, { status: body.status }, req.user);
  }

  // ─── OPPORTUNITIES & PIPELINE ─────────────────────────────────────────────
  @Get('opportunities')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'List opportunities' })
  getOpportunities(@Query() query: any, @Req() req: any) {
    return this.crmService.getOpportunities(query, req.user);
  }

  @Get('pipeline')
  @Get('opportunities/pipeline')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'Get opportunities grouped by Kanban stage' })
  getPipeline(@Req() req: any) {
    return this.crmService.getPipeline(req.user);
  }

  @Post('opportunities')
  @RequirePermissions('CRM:CREATE')
  @ApiOperation({ summary: 'Create new opportunity' })
  createOpportunity(@Body() dto: any, @Req() req: any) {
    return this.crmService.createOpportunity(dto, req.user);
  }

  @Patch('opportunities/:id/stage')
  @RequirePermissions('CRM:EDIT')
  @ApiOperation({ summary: 'Update opportunity stage' })
  updateOpportunityStage(
    @Param('id') id: string,
    @Body() body: { stage: string; probability?: number },
    @Req() req: any,
  ) {
    return this.crmService.updateOpportunityStage(id, body.stage, body.probability, req.user);
  }

  @Post('opportunities/:id/lost')
  @RequirePermissions('CRM:EDIT')
  @ApiOperation({ summary: 'Mark opportunity as lost with reason' })
  markOpportunityLost(@Param('id') id: string, @Body() body: any, @Req() req: any) {
    return this.crmService.markOpportunityLost(id, body.lostReason, body.lostRemarks, body.competitor, req.user);
  }

  // ─── ACTIVITIES: CALLS, MEETINGS & SITE VISITS ────────────────────────────
  @Post('activities/call')
  @RequirePermissions('CRM:CREATE')
  @ApiOperation({ summary: 'Log phone call conversation and outcome' })
  logCall(@Body() dto: any, @Req() req: any) {
    return this.crmService.logCall(dto, req.user);
  }

  @Post('activities/meeting')
  @RequirePermissions('CRM:CREATE')
  @ApiOperation({ summary: 'Schedule client meeting' })
  scheduleMeeting(@Body() dto: any, @Req() req: any) {
    return this.crmService.scheduleMeeting(dto, req.user);
  }

  @Post('activities/site-visit')
  @RequirePermissions('CRM:CREATE')
  @ApiOperation({ summary: 'Log engineering site visit with measurements and photos' })
  logSiteVisit(@Body() dto: any, @Req() req: any) {
    return this.crmService.logSiteVisit(dto, req.user);
  }

  // ─── FOLLOW-UPS ───────────────────────────────────────────────────────────
  @Get('follow-ups')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'List follow-ups with overdue detection' })
  getFollowUps(@Query() query: any, @Req() req: any) {
    return this.crmService.getFollowUps(query, req.user);
  }

  @Get('follow-ups/companies')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'List companies with follow-up summary and history' })
  getFollowUpCompanies(@Query() query: any, @Req() req: any) {
    return this.crmService.getFollowUpCompanies(query, req.user);
  }

  @Post('follow-ups')
  @RequirePermissions('CRM:CREATE')
  @ApiOperation({ summary: 'Create a completed interaction or scheduled follow-up' })
  createFollowUp(@Body() dto: any, @Req() req: any) {
    return this.crmService.createFollowUp(dto, req.user);
  }

  @Patch('follow-ups/:id/complete')
  @RequirePermissions('CRM:EDIT')
  @ApiOperation({ summary: 'Complete a follow-up and optionally schedule its next action' })
  completeFollowUp(@Param('id') id: string, @Body() body: any, @Req() req: any) {
    return this.crmService.completeFollowUp(id, body, req.user);
  }

  // ─── ANALYTICS ────────────────────────────────────────────────────────────
  @Get('analytics')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'Get CRM overall analytics overview' })
  getAnalyticsOverview(@Req() req: any) {
    return this.crmService.getAnalyticsOverview(req.user);
  }

  @Get('analytics/:type')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'Get CRM analytics: pipeline, lead-sources, product-demand' })
  getAnalytics(@Param('type') type: string, @Req() req: any) {
    return this.crmService.getAnalytics(type, req.user);
  }

  // ─── ENQUIRIES ────────────────────────────────────────────────────────────
  @Get('enquiries')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'List enquiries with filters & pagination' })
  getEnquiries(@Query() query: any, @Req() req: any) {
    return this.crmService.getEnquiries(query, req.user);
  }

  @Get('enquiries/:id')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'Get enquiry detail' })
  getEnquiry(@Param('id') id: string) {
    return this.crmService.getEnquiry(id);
  }

  @Post('enquiries')
  @RequirePermissions('CRM:CREATE')
  @ApiOperation({ summary: 'Create new enquiry linked to customer' })
  createEnquiry(@Body() dto: any, @Req() req: any) {
    return this.crmService.createEnquiry(dto, req.user);
  }

  @Put('enquiries/:id')
  @RequirePermissions('CRM:EDIT')
  @ApiOperation({ summary: 'Update enquiry' })
  updateEnquiry(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.crmService.updateEnquiry(id, dto, req.user);
  }

  // ─── PRODUCT & SYSTEM INTERESTS ───────────────────────────────────────────
  @Get('product-systems')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'List standard Product & System interests master' })
  getProductSystems() {
    return this.crmService.getProductSystems();
  }

  // ─── UNIFIED COMPANIES & CUSTOMER 360 ─────────────────────────────────────
  @Get('companies')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'List companies / customers in CRM with search, filters & valuation scores' })
  getCompanies(@Query() query: any, @Req() req: any) {
    return this.crmService.getCompanies(query, req.user);
  }

  @Post('companies/duplicate-check')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'Duplicate check across GSTIN, Phone, Email, and Name' })
  checkCompanyDuplicate(@Body() dto: { gstin?: string; phone?: string; email?: string; companyName?: string; domain?: string }) {
    return this.crmService.checkCompanyDuplicate(dto);
  }

  @Post('companies/gst-verify')
  @RequirePermissions('CRM:CREATE', 'CRM:EDIT')
  @ApiOperation({ summary: 'Verify GSTIN using GSTIN Portal and fetch registered details' })
  verifyGst(@Body('gstin') gstin: string, @Req() req: any) {
    return this.crmService.verifyGst(gstin, req.user, req.ip);
  }

  @Get('companies/:id/360')
  @Get('companies/:id')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'Aggregated Company 360 profile with all 16 relations' })
  getCompany360(@Param('id') id: string) {
    return this.crmService.getCompany360(id);
  }

  @Get('companies/:id/timeline')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'Unified chronological activity timeline for company' })
  getCompanyTimeline(@Param('id') id: string) {
    return this.crmService.getCompanyTimeline(id);
  }

  @Post('companies')
  @RequirePermissions('CRM:CREATE')
  @ApiOperation({ summary: 'Create new company / customer master record in CRM' })
  createCompany(@Body() dto: any, @Req() req: any) {
    return this.crmService.createCompany(dto, req.user);
  }

  @Put('companies/:id')
  @RequirePermissions('CRM:EDIT')
  @ApiOperation({ summary: 'Update company master record' })
  updateCompany(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.crmService.updateCompany(id, dto, req.user);
  }

  @Put('companies/:id/product-interests')
  @RequirePermissions('CRM:EDIT')
  @ApiOperation({ summary: 'Update company product & system interests' })
  updateCompanyProductInterests(
    @Param('id') id: string,
    @Body('productSystemIds') productSystemIds: string[],
  ) {
    return this.crmService.updateCompanyProductInterests(id, productSystemIds || []);
  }

  @Post('companies/:id/valuation')
  @RequirePermissions('CRM:EDIT')
  @ApiOperation({ summary: 'Update company manual rating or valuation parameters' })
  updateCompanyValuation(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.crmService.updateCompanyValuation(id, dto, req.user);
  }

  // ─── MEETINGS WORKFLOW ───────────────────────────────────────────────────
  @Get('meetings')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'List scheduled meetings with host and customer data' })
  getMeetings(@Query() query: any, @Req() req: any) {
    return this.crmService.getMeetings(query, req.user);
  }

  @Post('meetings')
  @RequirePermissions('CRM:CREATE')
  @ApiOperation({ summary: 'Schedule new meeting with host assignment' })
  createMeeting(@Body() dto: any, @Req() req: any) {
    return this.crmService.createMeeting(dto, req.user);
  }

  @Patch('meetings/:id/respond')
  @Patch('activities/meeting/:id/respond')
  @RequirePermissions('CRM:EDIT')
  @ApiOperation({ summary: 'Host response to meeting: Accept, Reschedule, or Decline' })
  respondMeeting(
    @Param('id') id: string,
    @Body() dto: { action: 'ACCEPT' | 'RESCHEDULE' | 'DECLINE'; newStartTime?: string; newEndTime?: string; reason?: string },
    @Req() req: any,
  ) {
    return this.crmService.respondMeeting(id, dto, req.user);
  }

  // ─── CALLS & RECORDINGS ───────────────────────────────────────────────────
  @Get('calls')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'List phone calls with outcomes and audio recording links' })
  getCalls(@Query() query: any, @Req() req: any) {
    return this.crmService.getCalls(query, req.user);
  }

  @Post('calls')
  @RequirePermissions('CRM:CREATE')
  @ApiOperation({ summary: 'Log phone call activity with data sent attachments' })
  createCall(@Body() dto: any, @Req() req: any) {
    return this.crmService.createCall(dto, req.user);
  }

  @Post('calls/:id/recordings')
  @RequirePermissions('CRM:CREATE')
  @ApiOperation({ summary: 'Upload or link audio recording for phone call' })
  uploadCallRecording(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.crmService.uploadCallRecording(id, dto, req.user);
  }

  // ─── SITE VISITS ──────────────────────────────────────────────────────────
  @Get('site-visits')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'List engineering site visits with technical measurements' })
  getSiteVisits(@Query() query: any, @Req() req: any) {
    return this.crmService.getSiteVisits(query, req.user);
  }

  @Post('site-visits')
  @RequirePermissions('CRM:CREATE')
  @ApiOperation({ summary: 'Record engineering site inspection with voltage & panel specs' })
  createSiteVisit(@Body() dto: any, @Req() req: any) {
    return this.crmService.createSiteVisit(dto, req.user);
  }

  // ─── MY WORK ─────────────────────────────────────────────────────────────
  @Get('my-work')
  @RequirePermissions('CRM:VIEW')
  @ApiOperation({ summary: 'User daily work summary: pending follow-ups, today meetings, active deals' })
  getMyWork(@Req() req: any) {
    return this.crmService.getMyWork(req.user);
  }
}
