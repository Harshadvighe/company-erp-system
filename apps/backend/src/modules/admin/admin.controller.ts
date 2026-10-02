import {
  Controller, Get, Post, Put, Patch, Delete,
  Body, Param, Query, UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

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

  @Delete('departments/:id')
  @ApiOperation({ summary: 'Delete department (only if no users assigned)' })
  deleteDepartment(@Param('id') id: string) {
    return this.adminService.deleteDepartment(id);
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
}
