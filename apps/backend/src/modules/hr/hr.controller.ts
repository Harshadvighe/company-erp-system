import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';
import { HrService } from './hr.service';
import { CreateEmployeeDto } from './dto/create-employee.dto';
import { CreateLeaveDto, UpdateLeaveStatusDto } from './dto/create-leave.dto';
import { ClockInDto, ClockOutDto } from './dto/clock-in.dto';
import { AllocateWorkstationDto, LogOvertimeDto, ReportSafetyIncidentDto } from './dto/industrial.dto';

@ApiTags('Human Resources (HR) & Industrial Workforce')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('api/v1/hr')
export class HrController {
  constructor(private readonly hrService: HrService) {}

  // -------------------------------------------------------------
  // DASHBOARD
  // -------------------------------------------------------------
  @Get('dashboard')
  @RequirePermissions('HR:VIEW', 'STAFF:VIEW')
  @ApiOperation({ summary: 'Get HR Executive & Industrial Shopfloor Metrics' })
  async getDashboard() {
    return this.hrService.getDashboardMetrics();
  }

  // -------------------------------------------------------------
  // DEPARTMENTS (FOR HR FORM & DROPDOWNS)
  // -------------------------------------------------------------
  @Get('departments')
  @RequirePermissions('HR:VIEW', 'ORGANIZATION:VIEW', 'STAFF:VIEW')
  @ApiOperation({ summary: 'List departments for HR onboarding & filters' })
  async getDepartments() {
    return this.hrService.getDepartments();
  }

  // -------------------------------------------------------------
  // SHIFTS (FACTORIES ACT)
  // -------------------------------------------------------------
  @Get('shifts')
  @RequirePermissions('HR:VIEW')
  @ApiOperation({ summary: 'List manufacturing plant shift rosters and allowances' })
  async getShifts() {
    return this.hrService.getShifts();
  }

  // -------------------------------------------------------------
  // WORKSTATIONS & ASSEMBLY BAYS
  // -------------------------------------------------------------
  @Get('workstations')
  @RequirePermissions('HR:VIEW')
  @ApiOperation({ summary: 'Get shopfloor bay technician allocations' })
  async getWorkstations(@Query('date') date?: string) {
    return this.hrService.getWorkstationAllocations(date);
  }

  @Post('workstations/allocate')
  @RequirePermissions('HR:CREATE', 'HR:EDIT')
  @ApiOperation({ summary: 'Allocate technician to manufacturing bay / panel job' })
  async allocateWorkstation(@Body() dto: AllocateWorkstationDto) {
    return this.hrService.allocateWorkstation(dto);
  }

  // -------------------------------------------------------------
  // OVERTIME (FACTORIES ACT SEC 59)
  // -------------------------------------------------------------
  @Post('overtime/log')
  @RequirePermissions('HR:CREATE', 'HR:EDIT')
  @ApiOperation({ summary: 'Log overtime hours for a shift' })
  async logOvertime(@Body() dto: LogOvertimeDto) {
    return this.hrService.logOvertime(dto);
  }

  @Patch('overtime/:id/approve')
  @RequirePermissions('HR:APPROVE')
  @ApiOperation({ summary: 'Approve or reject overtime by shopfloor supervisor' })
  async approveOvertime(
    @Param('id') id: string,
    @Body('approved') approved: boolean,
  ) {
    return this.hrService.approveOvertime(id, approved ?? true);
  }

  // -------------------------------------------------------------
  // SAFETY & EHS
  // -------------------------------------------------------------
  @Get('safety')
  @RequirePermissions('HR:VIEW')
  @ApiOperation({ summary: 'Get EHS incident and plant safety log' })
  async getSafetyIncidents() {
    return this.hrService.getSafetyIncidents();
  }

  @Post('safety')
  @RequirePermissions('HR:CREATE')
  @ApiOperation({ summary: 'Report shopfloor safety incident or near-miss' })
  async reportSafetyIncident(
    @Body() dto: ReportSafetyIncidentDto,
    @Req() req: any,
  ) {
    const reporter = req.user?.fullName || req.user?.email || 'Plant Safety Officer';
    return this.hrService.reportSafetyIncident(dto, reporter);
  }

  // -------------------------------------------------------------
  // FACTORIES ACT MUSTER ROLL
  // -------------------------------------------------------------
  @Get('muster-roll')
  @RequirePermissions('HR:VIEW', 'REPORTS:VIEW')
  @ApiOperation({ summary: 'Generate Factories Act Form 25 Muster Roll report' })
  async getMusterRoll(
    @Query('month') month?: string,
    @Query('year') year?: number,
  ) {
    return this.hrService.getMusterRoll(month, year);
  }

  // -------------------------------------------------------------
  // EMPLOYEES
  // -------------------------------------------------------------
  @Get('employees')
  @RequirePermissions('HR:VIEW', 'STAFF:VIEW')
  @ApiOperation({ summary: 'List all employees with industrial filters' })
  async getEmployees(
    @Query('search') search?: string,
    @Query('departmentId') departmentId?: string,
    @Query('status') status?: string,
    @Query('workerCategory') workerCategory?: string,
  ) {
    return this.hrService.getEmployees(search, departmentId, status, workerCategory);
  }

  @Get('employees/:id')
  @RequirePermissions('HR:VIEW', 'STAFF:VIEW')
  @ApiOperation({ summary: 'Get employee profile with full 360-degree details' })
  async getEmployeeById(@Param('id') id: string) {
    return this.hrService.getEmployeeById(id);
  }

  @Post('employees')
  @RequirePermissions('HR:CREATE', 'STAFF:CREATE')
  @ApiOperation({ summary: 'Onboard a new employee or technician' })
  async createEmployee(@Body() dto: CreateEmployeeDto) {
    return this.hrService.createEmployee(dto);
  }

  @Put('employees/:id')
  @RequirePermissions('HR:EDIT', 'STAFF:EDIT')
  @ApiOperation({ summary: 'Update employee details' })
  async updateEmployee(
    @Param('id') id: string,
    @Body() dto: Partial<CreateEmployeeDto>,
  ) {
    return this.hrService.updateEmployee(id, dto);
  }

  // -------------------------------------------------------------
  // ATTENDANCE
  // -------------------------------------------------------------
  @Get('attendance')
  @RequirePermissions('HR:VIEW')
  @ApiOperation({ summary: 'Get daily attendance sheet' })
  async getAttendance(@Query('date') date?: string) {
    return this.hrService.getAttendance(date);
  }

  @Post('attendance/clock-in')
  @RequirePermissions('HR:EDIT', 'MY_WORK:VIEW')
  @ApiOperation({ summary: 'Record employee shift clock-in' })
  async clockIn(@Body() dto: ClockInDto) {
    return this.hrService.clockIn(dto);
  }

  @Post('attendance/clock-out')
  @RequirePermissions('HR:EDIT', 'MY_WORK:VIEW')
  @ApiOperation({ summary: 'Record employee shift clock-out with overtime detection' })
  async clockOut(@Body() dto: ClockOutDto) {
    return this.hrService.clockOut(dto);
  }

  // -------------------------------------------------------------
  // LEAVE MANAGEMENT
  // -------------------------------------------------------------
  @Get('leaves')
  @RequirePermissions('HR:VIEW')
  @ApiOperation({ summary: 'List all leave requests' })
  async getLeaves(@Query('status') status?: string) {
    return this.hrService.getLeaveRequests(status);
  }

  @Post('leaves')
  @RequirePermissions('HR:CREATE', 'MY_WORK:VIEW')
  @ApiOperation({ summary: 'Apply for a new leave request' })
  async createLeave(@Body() dto: CreateLeaveDto) {
    return this.hrService.createLeaveRequest(dto);
  }

  @Patch('leaves/:id/status')
  @RequirePermissions('HR:APPROVE')
  @ApiOperation({ summary: 'Approve or Reject a leave request' })
  async updateLeaveStatus(
    @Param('id') id: string,
    @Body() dto: UpdateLeaveStatusDto,
    @Req() req: any,
  ) {
    const approver = req.user?.email || 'HR Administrator';
    return this.hrService.updateLeaveStatus(id, dto, approver);
  }

  // -------------------------------------------------------------
  // PAYROLL
  // -------------------------------------------------------------
  @Get('payroll')
  @RequirePermissions('HR:VIEW')
  @ApiOperation({ summary: 'List employee payroll salary slips with overtime' })
  async getPayroll(
    @Query('month') month?: string,
    @Query('year') year?: number,
  ) {
    return this.hrService.getPayrollRecords(month, year);
  }
}
