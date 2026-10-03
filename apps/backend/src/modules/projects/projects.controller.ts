import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { ProjectsService } from './projects.service';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { PermissionsGuard } from '../../common/guards/permissions.guard';
import { RequirePermissions } from '../../common/decorators/permissions.decorator';

@ApiTags('Projects')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('api/v1/projects')
export class ProjectsController {
  constructor(private readonly projectsService: ProjectsService) {}

  @Get()
  @RequirePermissions('PROJECTS:VIEW')
  @ApiOperation({ summary: 'List all projects with health, managers & progress' })
  findAll(@Query() query: any) {
    return this.projectsService.findAll(query);
  }

  @Get(':id')
  @RequirePermissions('PROJECTS:VIEW')
  @ApiOperation({ summary: 'Get full project detail (milestones, team, tasks, health)' })
  findOne(@Param('id') id: string) {
    return this.projectsService.findOne(id);
  }

  @Post()
  @RequirePermissions('PROJECTS:CREATE')
  @ApiOperation({ summary: 'Create new project with auto-generated project code' })
  create(@Body() dto: any, @Req() req: any) {
    return this.projectsService.create(dto, req.user?.id, req.user?.email);
  }

  @Put(':id')
  @RequirePermissions('PROJECTS:EDIT')
  @ApiOperation({ summary: 'Update project attributes and budget' })
  update(@Param('id') id: string, @Body() dto: any, @Req() req: any) {
    return this.projectsService.update(id, dto, req.user?.id, req.user?.email);
  }

  // ─── TEAM MEMBERS ─────────────────────────────────────────────────────────

  @Post(':id/members')
  @RequirePermissions('PROJECTS:EDIT')
  @ApiOperation({ summary: 'Allocate staff member to project team' })
  addMember(@Param('id') id: string, @Body() dto: any) {
    return this.projectsService.addMember(id, dto);
  }

  @Delete(':id/members/:staffId')
  @RequirePermissions('PROJECTS:EDIT')
  @ApiOperation({ summary: 'Remove staff member from project team' })
  removeMember(@Param('id') id: string, @Param('staffId') staffId: string) {
    return this.projectsService.removeMember(id, staffId);
  }

  // ─── MILESTONES ───────────────────────────────────────────────────────────

  @Post(':id/milestones')
  @RequirePermissions('PROJECTS:EDIT')
  @ApiOperation({ summary: 'Create project milestone' })
  createMilestone(@Param('id') id: string, @Body() dto: any) {
    return this.projectsService.createMilestone(id, dto);
  }

  @Put(':id/milestones/:milestoneId')
  @RequirePermissions('PROJECTS:EDIT')
  @ApiOperation({ summary: 'Update milestone progress & status' })
  updateMilestone(@Param('milestoneId') milestoneId: string, @Body() dto: any) {
    return this.projectsService.updateMilestone(milestoneId, dto);
  }
}
