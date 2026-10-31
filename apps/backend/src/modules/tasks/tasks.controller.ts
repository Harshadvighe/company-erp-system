import {
  Controller,
  Get,
  Post,
  Put,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { TasksService } from './tasks.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';

@ApiTags('Tasks')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('api/v1/tasks')
export class TasksController {
  constructor(private readonly tasksService: TasksService) {}

  @Get()
  @RequirePermissions('TASKS:VIEW')
  @ApiOperation({ summary: 'List all tasks with project, department, assignee & status filters' })
  findAll(@Query() query: any) {
    return this.tasksService.findAll(query);
  }

  @Get('my-tasks')
  @ApiOperation({ summary: 'List tasks assigned to logged-in user staff profile' })
  findMyTasks(@Req() req: any) {
    return this.tasksService.findMyTasks(req.user?.staffId);
  }

  @Get('my-led-teams')
  @ApiOperation({ summary: 'List teams led by the logged-in staff member' })
  findMyLedTeams(@Req() req: any) {
    return this.tasksService.findMyLedTeams(req.user?.staffId);
  }

  @Get('assignees')
  @ApiOperation({ summary: 'List active staff available for task assignment' })
  getAssignableStaff(@Req() req: any) {
    return this.tasksService.getAssignableStaff(req.user?.staffId);
  }

  @Get('stats/summary')
  @ApiOperation({ summary: 'Get task analytics: total, active, review, completed, overdue, and personal stats' })
  getTaskStats(@Req() req: any) {
    return this.tasksService.getTaskStats(req.user?.staffId);
  }

  @Get('form-options')
  @ApiOperation({ summary: 'Get task creation metadata options (staff, projects, milestones, departments, teams)' })
  getFormOptions(@Req() req: any) {
    return this.tasksService.getFormOptions(req.user?.staffId, req.user);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get full task details with comments, assignees & activity log' })
  findOne(@Param('id') id: string, @Req() req: any) {
    return this.tasksService.findOne(id, req.user?.staffId, req.user);
  }

  @Post()
  @ApiOperation({ summary: 'Create new task (auto-generates TSK code, records activity)' })
  create(@Body() dto: any, @Req() req: any) {
    return this.tasksService.create(
      dto,
      req.user?.staffId,
      req.user?.id,
      req.user?.email,
      req.user,
    );
  }

  @Put(':id')
  @RequirePermissions('TASKS:EDIT')
  @ApiOperation({ summary: 'Update task details, due date, estimated hours' })
  update(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.tasksService.update(id, dto, req.user?.staffId, req.user?.id, req.user?.email);
  }

  @Patch(':id/status')
  @ApiOperation({ summary: 'Transition task status along lifecycle (ACCEPTED, IN_PROGRESS, REVIEW, COMPLETED, RETURNED)' })
  updateStatus(
    @Param('id') id: string,
    @Body('status') status: string,
    @Body('notes') notes: string,
    @Req() req: any,
  ) {
    return this.tasksService.updateStatus(id, status, notes, req.user?.staffId, req.user);
  }

  @Patch(':id/progress')
  @ApiOperation({ summary: 'Update task completion percentage by the assignee' })
  updateProgress(
    @Param('id') id: string,
    @Body('progress') progress: number,
    @Req() req: any,
  ) {
    return this.tasksService.updateProgress(id, progress, req.user?.staffId, req.user);
  }

  @Post(':id/comments')
  @ApiOperation({ summary: 'Add progress comment or feedback to task' })
  addComment(@Param('id') id: string, @Body('comment') comment: string, @Req() req: any) {
    return this.tasksService.addComment(id, comment, req.user?.staffId, req.user);
  }

  @Post(':id/log-hours')
  @ApiOperation({ summary: 'Log hours worked on task with optional notes' })
  logHours(
    @Param('id') id: string,
    @Body('hours') hours: number,
    @Body('notes') notes: string,
    @Req() req: any,
  ) {
    return this.tasksService.logHours(id, hours, notes, req.user?.staffId, req.user);
  }

  @Delete(':id')
  @RequirePermissions('TASKS:DELETE')
  @ApiOperation({ summary: 'Delete task (Admins or Task Creators/Assigners)' })
  remove(@Param('id') id: string, @Req() req: any) {
    return this.tasksService.remove(id, req.user?.staffId, req.user);
  }
}
