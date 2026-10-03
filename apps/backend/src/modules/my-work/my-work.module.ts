import { Module } from '@nestjs/common';
import { MyWorkController } from './my-work.controller';
import { MyWorkService } from './my-work.service';
import { PrismaService } from '../../core/database/prisma.service';

@Module({
  controllers: [MyWorkController],
  providers: [MyWorkService, PrismaService],
  exports: [MyWorkService],
})
export class MyWorkModule {}
