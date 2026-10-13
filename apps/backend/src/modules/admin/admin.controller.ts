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
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('api/v1/admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  // ─── COMPANY ──────────────────────────────────────────────────────────────

  @Get('company')
  @RequirePermissions('ORGANIZATION:VIEW')
  @ApiOperation({ summary: 'Get company profile' })
  getCompanyProfile() {
    return this.adminService.getCompanyProfile();
  }

  @Put('company')
  @RequirePermissions('ORGANIZATION:EDIT')
  @ApiOperation({ summary: 'Create or update company profile' })
  updateCompanyProfile(@Body() dto: any) {
    return this.adminService.updateCompanyProfile(dto);
  }

  // ─── DEPARTMENTS ──────────────────────────────────────────────────────────

  @Get('departments')
  @RequirePermissions('ORGANIZATION:VIEW')
  @ApiOperation({ summary: 'List all departments' })
  getDepartments() {
    return this.adminService.getDepartments();
  }

  @Get('organization')
  @RequirePermissions('STAFF:VIEW')
  @ApiOperation({ summary: 'Get departments, department heads, teams and memberships' })
  getOrganizationStructure() {
    return this.adminService.getOrganizationStructure();
  }

  @Post('departments')
  @RequirePermissions('ORGANIZATION:CREATE')
  @ApiOperation({ summary: 'Create department' })
  createDepartment(@Body() dto: { name: string; code: string }) {
    return this.adminService.createDepartment(dto);
  }

  @Put('departments/:id')
  @RequirePermissions('ORGANIZATION:EDIT')
  @ApiOperation({ summary: 'Update department' })
  updateDepartment(@Param('id') id: string, @Body() dto: any) {
    return this.adminService.updateDepartment(id, dto);
  }

  @Put('departments/:id/head')
  @RequirePermissions('ORGANIZATION:EDIT')
  @ApiOperation({ summary: 'Assign or remove the department head' })
  updateDepartmentHead(@Param('id') id: string, @Body() dto: any) {
    if (!dto || !Object.prototype.hasOwnProperty.call(dto, 'staffId')) {
      throw new BadRequestException('staffId must be provided as a staff ID or null');
    }
    return this.adminService.updateDepartmentHead(id, dto.staffId);
  }

  @Delete('departments/:id')
  @RequirePermissions('ORGANIZATION:DELETE')
  @ApiOperation({ summary: 'Delete department (only if no users assigned)' })
  deleteDepartment(@Param('id') id: string) {
    return this.adminService.deleteDepartment(id);
  }

  @Get('teams')
  @RequirePermissions('STAFF:VIEW')
  @ApiOperation({ summary: 'List teams, optionally filtered by department' })
  getTeams(@Query('departmentId') departmentId?: string) {
    return this.adminService.getTeams(departmentId);
  }

  @Post('teams')
  @RequirePermissions('ORGANIZATION:CREATE')
  @ApiOperation({ summary: 'Create team with leader and members' })
  createTeam(@Body() dto: any) {
    return this.adminService.createTeam(dto);
  }

  @Put('teams/:id')
  @RequirePermissions('ORGANIZATION:EDIT')
  @ApiOperation({ summary: 'Update team, leader and members' })
  updateTeam(@Param('id') id: string, @Body() dto: any) {
    return this.adminService.updateTeam(id, dto);
  }

  @Delete('teams/:id')
  @RequirePermissions('ORGANIZATION:DELETE')
  @ApiOperation({ summary: 'Delete team' })
  deleteTeam(@Param('id') id: string) {
    return this.adminService.deleteTeam(id);
  }

  // ─── DESIGNATIONS ──────────────────────────────────────────────────────────

  @Get('designations')
  @RequirePermissions('ORGANIZATION:VIEW')
  @ApiOperation({ summary: 'List all designations' })
  getDesignations() {
    return this.adminService.getDesignations();
  }

  @Post('designations')
  @RequirePermissions('ORGANIZATION:CREATE')
  @ApiOperation({ summary: 'Create designation' })
  createDesignation(@Body() dto: { name: string; code: string; description?: string }) {
    return this.adminService.createDesignation(dto);
  }

  @Put('designations/:id')
  @RequirePermissions('ORGANIZATION:EDIT')
  @ApiOperation({ summary: 'Update designation' })
  updateDesignation(@Param('id') id: string, @Body() dto: any) {
    return this.adminService.updateDesignation(id, dto);
  }

  @Delete('designations/:id')
  @RequirePermissions('ORGANIZATION:DELETE')
  @ApiOperation({ summary: 'Delete designation (only if no staff assigned)' })
  deleteDesignation(@Param('id') id: string) {
    return this.adminService.deleteDesignation(id);
  }

  // ─── FINANCIAL YEARS ──────────────────────────────────────────────────────

  @Get('financial-years')
  @RequirePermissions('ORGANIZATION:VIEW')
  @ApiOperation({ summary: 'List all financial years' })
  getFinancialYears() {
    return this.adminService.getFinancialYears();
  }

  @Post('financial-years')
  @RequirePermissions('ORGANIZATION:CREATE')
  @ApiOperation({ summary: 'Create financial year' })
  createFinancialYear(@Body() dto: any) {
    return this.adminService.createFinancialYear(dto);
  }

  @Patch('financial-years/:id/set-current')
  @RequirePermissions('ORGANIZATION:EDIT')
  @ApiOperation({ summary: 'Set a financial year as current' })
  setCurrentFinancialYear(@Param('id') id: string) {
    return this.adminService.setCurrentFinancialYear(id);
  }

  // ─── TAX RATES ────────────────────────────────────────────────────────────

  @Get('tax-rates')
  @RequirePermissions('ORGANIZATION:VIEW')
  @ApiOperation({ summary: 'List all tax rates (GST slabs)' })
  getTaxRates() {
    return this.adminService.getTaxRates();
  }

  @Post('tax-rates')
  @RequirePermissions('ORGANIZATION:CREATE')
  @ApiOperation({ summary: 'Create tax rate' })
  createTaxRate(@Body() dto: any) {
    return this.adminService.createTaxRate(dto);
  }

  @Put('tax-rates/:id')
  @RequirePermissions('ORGANIZATION:EDIT')
  @ApiOperation({ summary: 'Update tax rate' })
  updateTaxRate(@Param('id') id: string, @Body() dto: any) {
    return this.adminService.updateTaxRate(id, dto);
  }

  // ─── PAYMENT MODES ────────────────────────────────────────────────────────

  @Get('payment-modes')
  @RequirePermissions('ORGANIZATION:VIEW')
  @ApiOperation({ summary: 'List all payment modes' })
  getPaymentModes() {
    return this.adminService.getPaymentModes();
  }

  @Post('payment-modes')
  @RequirePermissions('ORGANIZATION:CREATE')
  @ApiOperation({ summary: 'Create payment mode' })
  createPaymentMode(@Body() dto: any) {
    return this.adminService.createPaymentMode(dto);
  }

  // ─── USERS ────────────────────────────────────────────────────────────────

  @Get('users')
  @RequirePermissions('USERS:VIEW')
  @ApiOperation({ summary: 'List all users with roles' })
  getUsers(@Query() query: any) {
    return this.adminService.getUsers(query);
  }

  @Post('users')
  @RequirePermissions('USERS:CREATE')
  @ApiOperation({ summary: 'Create new user with role assignment' })
  createUser(@Body() dto: any, @Req() req: any) {
    return this.adminService.createUser(dto, req.user);
  }

  @Put('users/:id')
  @RequirePermissions('USERS:EDIT')
  @ApiOperation({ summary: 'Update user details and roles' })
  updateUser(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.adminService.updateUser(id, dto, req.user);
  }

  @Patch('users/:id/toggle-status')
  @RequirePermissions('USERS:EDIT')
  @ApiOperation({ summary: 'Toggle user active/inactive status' })
  toggleUserStatus(@Param('id') id: string, @Req() req: any) {
    return this.adminService.toggleUserStatus(id, req.user);
  }

  // ─── ROLES ────────────────────────────────────────────────────────────────

  @Get('roles')
  @RequirePermissions('ROLES:VIEW')
  @ApiOperation({ summary: 'List all roles with permissions' })
  getRoles() {
    return this.adminService.getRoles();
  }

  @Post('roles')
  @RequirePermissions('ROLES:CREATE')
  @ApiOperation({ summary: 'Create role with permission assignment' })
  createRole(@Body() dto: any, @Req() req: any) {
    return this.adminService.createRole(dto, req.user);
  }

  @Put('roles/:id/permissions')
  @RequirePermissions('ROLES:EDIT')
  @ApiOperation({ summary: 'Update permissions assigned to a role' })
  updateRolePermissions(@Param('id') id: string, @Body() body: { permissionIds: string[] }, @Req() req: any) {
    return this.adminService.updateRolePermissions(id, body.permissionIds, req.user);
  }

  // ─── PERMISSIONS ──────────────────────────────────────────────────────────

  @Get('permissions')
  @RequirePermissions('ROLES:VIEW')
  @ApiOperation({ summary: 'List all available permissions (module:action pairs)' })
  getPermissions() {
    return this.adminService.getPermissions();
  }

  // ─── EMPLOYEE REQUESTS & ONBOARDING PROVISIONING ──────────────────────────

  @Get('employee-requests')
  @RequirePermissions('STAFF:VIEW')
  @ApiOperation({ summary: 'List employee onboarding requests awaiting approval' })
  getEmployeeRequests(
    @Query('departmentId') departmentId?: string,
    @Query('status') status?: string,
    @Query('search') search?: string,
  ) {
    return this.adminService.getEmployeeRequests({ departmentId, status, search });
  }

  @Post('employee-requests/:id/approve')
  @RequirePermissions('STAFF:APPROVE')
  @ApiOperation({ summary: 'Approve employee onboarding, assign department/role, and create login credentials' })
  approveEmployeeRequest(
    @Param('id') id: string,
    @Body() dto: ApproveEmployeeRequestDto,
    @Req() req: any,
  ) {
    return this.adminService.approveEmployeeRequest(id, dto, req.user);
  }

  @Post('employee-requests/:id/reject')
  @RequirePermissions('STAFF:APPROVE')
  @ApiOperation({ summary: 'Reject employee onboarding request' })
  rejectEmployeeRequest(
    @Param('id') id: string,
    @Body('reason') reason: string,
    @Req() req: any,
  ) {
    return this.adminService.rejectEmployeeRequest(id, reason, req.user);
  }
}
