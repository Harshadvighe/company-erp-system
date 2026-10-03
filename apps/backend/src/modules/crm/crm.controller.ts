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

  @Patch('follow-ups/:id/complete')
  @RequirePermissions('CRM:EDIT')
  @ApiOperation({ summary: 'Mark follow-up as completed' })
  completeFollowUp(@Param('id') id: string, @Body() body: { notes?: string }, @Req() req: any) {
    return this.crmService.completeFollowUp(id, body.notes, req.user);
  }

  // ─── ANALYTICS ────────────────────────────────────────────────────────────
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
}
