import { Module } from '@nestjs/common';
import { NpdService } from './npd.service';
import { NpdController, NpdV1Controller } from './npd.controller';
import { PrismaService } from '../../core/database/prisma.service';

@Module({
  controllers: [NpdController, NpdV1Controller],
  providers: [NpdService, PrismaService],
  exports: [NpdService],
})
export class NpdModule {}
