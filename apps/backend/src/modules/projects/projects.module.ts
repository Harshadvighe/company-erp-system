import { Module } from '@nestjs/common';
import { ProjectsController } from './projects.controller';
import { ProjectsService } from './projects.service';
import { SequenceService } from '../../core/database/sequence.service';
import { AuditService } from '../../core/audit/audit.service';

@Module({
  controllers: [ProjectsController],
  providers: [ProjectsService, AuditService, SequenceService],
  exports: [ProjectsService],
})
export class ProjectsModule {}
