import { Module } from '@nestjs/common';
import { ProjectsController } from './projects.controller';
import { ProjectsService } from './projects.service';
import { PrismaService } from '../../core/database/prisma.service';
import { AuditService } from '../../core/audit/audit.service';

@Module({
  controllers: [ProjectsController],
  providers: [ProjectsService, PrismaService, AuditService],
  exports: [ProjectsService],
})
export class ProjectsModule {}
