import {
  Controller, Get, Post, Put, Patch, Delete,
  Body, Param, Query, UseGuards, Req, BadRequestException,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';
import { ApproveEmployeeRequestDto } from './dto/approve-employee-request.dto';

@ApiTags('Administration')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('api/v1/admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  // ─── COMPANY ──────────────────────────────────────────────────────────────

  @Get('company')
  @ApiOperation({ summary: 'Get company profile' })
  getCompanyProfile() {
    return this.adminService.getCompanyProfile();
  }

  @Put('company')
  @ApiOperation({ summary: 'Create or update company profile' })
  updateCompanyProfile(@Body() dto: any) {
    return this.adminService.updateCompanyProfile(dto);
  }

  // ─── DEPARTMENTS ──────────────────────────────────────────────────────────

  @Get('departments')
  @ApiOperation({ summary: 'List all departments' })
  getDepartments() {
    return this.adminService.getDepartments();
  }

  @Get('organization')
  @UseGuards(PermissionsGuard)
  @RequirePermissions('STAFF:VIEW')
  @ApiOperation({ summary: 'Get departments, department heads, teams and memberships' })
  getOrganizationStructure() {
    return this.adminService.getOrganizationStructure();
  }

  @Post('departments')
  @ApiOperation({ summary: 'Create department' })
  createDepartment(@Body() dto: { name: string; code: string }) {
    return this.adminService.createDepartment(dto);
  }

  @Put('departments/:id')
  @ApiOperation({ summary: 'Update department' })
  updateDepartment(@Param('id') id: string, @Body() dto: any) {
    return this.adminService.updateDepartment(id, dto);
  }

  @Put('departments/:id/head')
  @UseGuards(PermissionsGuard)
  @RequirePermissions('ORGANIZATION:EDIT')
  @ApiOperation({ summary: 'Assign or remove the department head' })
  updateDepartmentHead(@Param('id') id: string, @Body() dto: any) {
    if (!dto || !Object.prototype.hasOwnProperty.call(dto, 'staffId')) {
      throw new BadRequestException('staffId must be provided as a staff ID or null');
    }
    return this.adminService.updateDepartmentHead(id, dto.staffId);
  }

  @Delete('departments/:id')
  @ApiOperation({ summary: 'Delete department (only if no users assigned)' })
  deleteDepartment(@Param('id') id: string) {
    return this.adminService.deleteDepartment(id);
  }

  @Get('teams')
  @UseGuards(PermissionsGuard)
  @RequirePermissions('STAFF:VIEW')
  @ApiOperation({ summary: 'List teams, optionally filtered by department' })
  getTeams(@Query('departmentId') departmentId?: string) {
    return this.adminService.getTeams(departmentId);
  }

  @Post('teams')
  @UseGuards(PermissionsGuard)
  @RequirePermissions('ORGANIZATION:CREATE')
  @ApiOperation({ summary: 'Create team with leader and members' })
  createTeam(@Body() dto: any) {
    return this.adminService.createTeam(dto);
  }

  @Put('teams/:id')
  @UseGuards(PermissionsGuard)
  @RequirePermissions('ORGANIZATION:EDIT')
  @ApiOperation({ summary: 'Update team, leader and members' })
  updateTeam(@Param('id') id: string, @Body() dto: any) {
    return this.adminService.updateTeam(id, dto);
  }

  @Delete('teams/:id')
  @UseGuards(PermissionsGuard)
  @RequirePermissions('ORGANIZATION:DELETE')
  @ApiOperation({ summary: 'Delete team' })
  deleteTeam(@Param('id') id: string) {
    return this.adminService.deleteTeam(id);
  }

  // ─── DESIGNATIONS ──────────────────────────────────────────────────────────

  @Get('designations')
  @ApiOperation({ summary: 'List all designations' })
  getDesignations() {
    return this.adminService.getDesignations();
  }

  @Post('designations')
  @ApiOperation({ summary: 'Create designation' })
  createDesignation(@Body() dto: { name: string; code: string; description?: string }) {
    return this.adminService.createDesignation(dto);
  }

  @Put('designations/:id')
  @ApiOperation({ summary: 'Update designation' })
  updateDesignation(@Param('id') id: string, @Body() dto: any) {
    return this.adminService.updateDesignation(id, dto);
  }

  @Delete('designations/:id')
  @ApiOperation({ summary: 'Delete designation (only if no staff assigned)' })
  deleteDesignation(@Param('id') id: string) {
    return this.adminService.deleteDesignation(id);
  }

  // ─── FINANCIAL YEARS ──────────────────────────────────────────────────────

  @Get('financial-years')
  @ApiOperation({ summary: 'List all financial years' })
  getFinancialYears() {
    return this.adminService.getFinancialYears();
  }

  @Post('financial-years')
  @ApiOperation({ summary: 'Create financial year' })
  createFinancialYear(@Body() dto: any) {
    return this.adminService.createFinancialYear(dto);
  }

  @Patch('financial-years/:id/set-current')
  @ApiOperation({ summary: 'Set a financial year as current' })
  setCurrentFinancialYear(@Param('id') id: string) {
    return this.adminService.setCurrentFinancialYear(id);
  }

  // ─── TAX RATES ────────────────────────────────────────────────────────────

  @Get('tax-rates')
  @ApiOperation({ summary: 'List all tax rates (GST slabs)' })
  getTaxRates() {
    return this.adminService.getTaxRates();
  }

  @Post('tax-rates')
  @ApiOperation({ summary: 'Create tax rate' })
  createTaxRate(@Body() dto: any) {
    return this.adminService.createTaxRate(dto);
  }

  @Put('tax-rates/:id')
  @ApiOperation({ summary: 'Update tax rate' })
  updateTaxRate(@Param('id') id: string, @Body() dto: any) {
    return this.adminService.updateTaxRate(id, dto);
  }

  // ─── PAYMENT MODES ────────────────────────────────────────────────────────

  @Get('payment-modes')
  @ApiOperation({ summary: 'List all payment modes' })
  getPaymentModes() {
    return this.adminService.getPaymentModes();
  }

  @Post('payment-modes')
  @ApiOperation({ summary: 'Create payment mode' })
  createPaymentMode(@Body() dto: any) {
    return this.adminService.createPaymentMode(dto);
  }

  // ─── USERS ────────────────────────────────────────────────────────────────

  @Get('users')
  @ApiOperation({ summary: 'List all users with roles' })
  getUsers(@Query() query: any) {
    return this.adminService.getUsers(query);
  }

  @Post('users')
  @ApiOperation({ summary: 'Create new user with role assignment' })
  createUser(@Body() dto: any) {
    return this.adminService.createUser(dto);
  }

  @Put('users/:id')
  @ApiOperation({ summary: 'Update user details and roles' })
  updateUser(@Param('id') id: string, @Body() dto: any) {
    return this.adminService.updateUser(id, dto);
  }

  @Patch('users/:id/toggle-status')
  @ApiOperation({ summary: 'Toggle user active/inactive status' })
  toggleUserStatus(@Param('id') id: string) {
    return this.adminService.toggleUserStatus(id);
  }

  // ─── ROLES ────────────────────────────────────────────────────────────────

  @Get('roles')
  @ApiOperation({ summary: 'List all roles with permissions' })
  getRoles() {
    return this.adminService.getRoles();
  }

  @Post('roles')
  @ApiOperation({ summary: 'Create role with permission assignment' })
  createRole(@Body() dto: any) {
    return this.adminService.createRole(dto);
  }

  @Put('roles/:id/permissions')
  @ApiOperation({ summary: 'Update permissions assigned to a role' })
  updateRolePermissions(@Param('id') id: string, @Body() body: { permissionIds: string[] }) {
    return this.adminService.updateRolePermissions(id, body.permissionIds);
  }

  // ─── PERMISSIONS ──────────────────────────────────────────────────────────

  @Get('permissions')
  @ApiOperation({ summary: 'List all available permissions (module:action pairs)' })
  getPermissions() {
    return this.adminService.getPermissions();
  }

  // ─── EMPLOYEE REQUESTS & ONBOARDING PROVISIONING ──────────────────────────

  @Get('employee-requests')
  @ApiOperation({ summary: 'List employee onboarding requests awaiting approval' })
  getEmployeeRequests(
    @Query('departmentId') departmentId?: string,
    @Query('status') status?: string,
    @Query('search') search?: string,
  ) {
    return this.adminService.getEmployeeRequests({ departmentId, status, search });
  }

  @Post('employee-requests/:id/approve')
  @ApiOperation({ summary: 'Approve employee onboarding, assign department/role, and create login credentials' })
  approveEmployeeRequest(
    @Param('id') id: string,
    @Body() dto: ApproveEmployeeRequestDto,
    @Req() req: any,
  ) {
    return this.adminService.approveEmployeeRequest(id, dto, req.user);
  }

  @Post('employee-requests/:id/reject')
  @ApiOperation({ summary: 'Reject employee onboarding request' })
  rejectEmployeeRequest(
    @Param('id') id: string,
    @Body('reason') reason: string,
    @Req() req: any,
  ) {
    return this.adminService.rejectEmployeeRequest(id, reason, req.user);
  }


  @Put('employee-requests/:id')
  @ApiOperation({ summary: 'Update employee details and linked user account from Administration' })
  updateEmployeeRequest(
    @Param('id') id: string,
    @Body() dto: any,
    @Req() req: any,
  ) {
    return this.adminService.updateEmployeeRequest(id, dto, req.user);
  }

  // ─── SETTINGS & SYSTEM CONFIGURATION ────────────────────────────────────────

  @Get('settings')
  @ApiOperation({ summary: 'Get admin system settings and email preferences' })
  getSettings() {
    return this.adminService.getSettings();
  }

  @Put('settings')
  @ApiOperation({ summary: 'Update admin system settings and email preferences' })
  updateSettings(@Body() dto: any) {
    return this.adminService.updateSettings(dto);
  }

  @Get('mail-logs')
  @ApiOperation({ summary: 'List recent email notifications dispatched by system' })
  getMailLogs() {
    return this.adminService.getMailLogs();
  }

  @Post('send-test-email')
  @ApiOperation({ summary: 'Send a test email to verify SMTP configuration' })
  sendTestEmail(@Body() body: { to: string }) {
    return this.adminService.sendTestEmail(body.to);
  }

  @Post('employee-requests/:id/resend-email')
  @ApiOperation({ summary: 'Resend welcome onboarding credentials email to employee' })
  resendWelcomeEmail(@Param('id') id: string, @Body() body?: { password?: string }) {
    return this.adminService.resendWelcomeEmail(id, body?.password);
  }

  // ─── AUDIT TRAIL & COMPLIANCE ACCESS LOGS ──────────────────────────────────

  @Get('audit-logs')
  @ApiOperation({ summary: 'List tamper-evident audit logs with module and action filters' })
  getAuditLogs(
    @Query('module') module?: string,
    @Query('action') action?: string,
    @Query('search') search?: string,
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
  ) {
    return this.adminService.getAuditLogs({ module, action, search, limit, offset });
  }

  // ─── INDUSTRIAL SECURITY & GOVERNANCE POLICIES ─────────────────────────────

  @Get('security/policy')
  @ApiOperation({ summary: 'Get plant cybersecurity & governance configuration (IEC 62443 / ISO 27001)' })
  getSecurityPolicy() {
    return this.adminService.getSecurityPolicy();
  }

  @Put('security/policy')
  @ApiOperation({ summary: 'Update plant cybersecurity & governance configuration' })
  updateSecurityPolicy(@Body() dto: any, @Req() req: any) {
    return this.adminService.updateSecurityPolicy(dto, req.user);
  }

  @Get('security/sessions')
  @ApiOperation({ summary: 'Get active enterprise user sessions across plant and HQ' })
  getActiveSessions() {
    return this.adminService.getActiveSessions();
  }

  @Get('security/session-history')
  @ApiOperation({ summary: 'Get user login and logout history records with timestamps and durations' })
  getSessionHistory(
    @Query('search') search?: string,
    @Query('status') status?: string,
    @Query('userId') userId?: string,
    @Query('limit') limit?: number,
    @Query('offset') offset?: number,
    @Query('startDate') startDate?: string,
    @Query('endDate') endDate?: string,
  ) {
    return this.adminService.getSessionHistory({ search, status, userId, limit, offset, startDate, endDate });
  }

  @Delete('security/sessions/:id')
  @ApiOperation({ summary: 'Terminate or revoke an active session' })
  revokeSession(@Param('id') id: string, @Req() req: any) {
    return this.adminService.revokeSession(id, req.user);
  }

  @Post('security/sessions/:id/terminate')
  @ApiOperation({ summary: 'Terminate or revoke an active session (POST alternative)' })
  terminateSession(@Param('id') id: string, @Req() req: any) {
    return this.adminService.revokeSession(id, req.user);
  }

  // ─── SYSTEM HEALTH & DIAGNOSTICS ──────────────────────────────────────────

  @Get('system/health')
  @ApiOperation({ summary: 'Industrial telemetry: PostgreSQL latency, pool health, memory, uptime' })
  getSystemHealth() {
    return this.adminService.getSystemHealth();
  }

  @Post('system/backup')
  @ApiOperation({ summary: 'Trigger manual database snapshot and disaster recovery backup' })
  triggerSystemBackup(@Req() req: any) {
    return this.adminService.triggerSystemBackup(req.user);
  }

  // ─── USER SECURITY MANAGEMENT ─────────────────────────────────────────────

  @Patch('users/:id/unlock')
  @ApiOperation({ summary: 'Unlock a locked user account and reset failed attempt counters' })
  unlockUser(@Param('id') id: string, @Req() req: any) {
    return this.adminService.unlockUser(id, req.user);
  }

  @Patch('users/:id/reset-password')
  @ApiOperation({ summary: 'Administrator reset user password' })
  resetPassword(@Param('id') id: string, @Req() req: any, @Body('password') password?: string) {
    return this.adminService.resetPassword(id, password, req.user);
  }

  @Patch('users/:id/toggle-face')
  @ApiOperation({ summary: 'Toggle biometric face authentication requirement for user' })
  toggleFaceVerification(@Param('id') id: string, @Req() req: any, @Body('enabled') enabled?: boolean) {
    return this.adminService.toggleFaceVerification(id, enabled, req.user);
  }

  // ─── POSTGRESQL LIVE DATABASE EXPLORER ────────────────────────────────────

  @Post('database/auth')
  @ApiOperation({ summary: 'Authenticate DBA credentials to access PostgreSQL Database Explorer' })
  authenticateDatabaseAccess(@Body() dto: { username?: string; password?: string }) {
    return this.adminService.verifyDatabaseAccess(dto);
  }

  @Get('database/telemetry')
  @ApiOperation({ summary: 'Get live PostgreSQL connection telemetry' })
  getDatabaseTelemetry() {
    return this.adminService.getDatabaseTelemetry();
  }

  @Get('database/tables')
  @ApiOperation({ summary: 'List all public PostgreSQL tables with row counts and schema information' })
  getDatabaseTables() {
    return this.adminService.getDatabaseTables();
  }

  @Get('database/table/:tableName')
  @ApiOperation({ summary: 'Fetch table columns and paginated records' })
  getDatabaseTableData(
    @Param('tableName') tableName: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('search') search?: string,
  ) {
    return this.adminService.getDatabaseTableData(tableName, {
      page: page ? parseInt(page, 10) : 1,
      limit: limit ? parseInt(limit, 10) : 25,
      search,
    });
  }

  @Post('database/query')
  @ApiOperation({ summary: 'Execute safe read-only SQL query on PostgreSQL database' })
  executeDatabaseQuery(@Body() dto: { query: string; limit?: number }) {
    if (!dto?.query) throw new BadRequestException('SQL query is required');
    return this.adminService.executeReadOnlyQuery(dto.query, dto.limit);
  }
}


