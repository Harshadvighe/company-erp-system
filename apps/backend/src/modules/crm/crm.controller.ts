import { Controller, Get, Post, Put, Patch, Body, Param, Query, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CrmService } from './crm.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@ApiTags('CRM')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/v1/crm')
export class CrmController {
  constructor(private readonly crmService: CrmService) {}

  // ─── DASHBOARD ────────────────────────────────────────────────────────────

  @Get('dashboard')
  @ApiOperation({ summary: 'CRM Dashboard — lead counts, conversion rate, follow-ups' })
  getDashboardStats() {
    return this.crmService.getDashboardStats();
  }

  @Get('follow-ups/pending')
  @ApiOperation({ summary: 'Get leads due for follow-up today and tomorrow' })
  getPendingFollowUps() {
    return this.crmService.getPendingFollowUps();
  }

  // ─── LEADS ────────────────────────────────────────────────────────────────

  @Get('leads')
  @ApiOperation({ summary: 'List leads with filter by status, priority, assignee' })
  getLeads(@Query() query: any) {
    return this.crmService.getLeads(query);
  }

  @Get('leads/:id')
  @ApiOperation({ summary: 'Get lead detail' })
  getLead(@Param('id') id: string) {
    return this.crmService.getLead(id);
  }

  @Post('leads')
  @ApiOperation({ summary: 'Create new lead' })
  createLead(@Body() dto: any, @Req() req: any) {
    return this.crmService.createLead(dto, req.user?.id, req.user?.email);
  }

  @Put('leads/:id')
  @ApiOperation({ summary: 'Update lead' })
  updateLead(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.crmService.updateLead(id, dto, req.user?.id, req.user?.email);
  }

  @Patch('leads/:id/status')
  @ApiOperation({ summary: 'Update lead pipeline status (NEW → CONTACTED → QUALIFIED → WON/LOST)' })
  updateLeadStatus(
    @Param('id') id: string,
    @Body() body: { status: string },
    @Req() req: any,
  ) {
    return this.crmService.updateLeadStatus(id, body.status, req.user?.id, req.user?.email);
  }

  // ─── ENQUIRIES ────────────────────────────────────────────────────────────

  @Get('enquiries')
  @ApiOperation({ summary: 'List enquiries with filters & pagination' })
  getEnquiries(@Query() query: any) {
    return this.crmService.getEnquiries(query);
  }

  @Get('enquiries/:id')
  @ApiOperation({ summary: 'Get enquiry detail' })
  getEnquiry(@Param('id') id: string) {
    return this.crmService.getEnquiry(id);
  }

  @Post('enquiries')
  @ApiOperation({ summary: 'Create new enquiry linked to customer' })
  createEnquiry(@Body() dto: any, @Req() req: any) {
    return this.crmService.createEnquiry(dto, req.user?.id, req.user?.email);
  }

  @Put('enquiries/:id')
  @ApiOperation({ summary: 'Update enquiry' })
  updateEnquiry(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.crmService.updateEnquiry(id, dto, req.user?.id, req.user?.email);
  }
}
