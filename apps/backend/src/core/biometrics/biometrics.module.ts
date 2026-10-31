import { Module, Global } from '@nestjs/common';
import { FaceRecognitionService } from './face-recognition.service';
import { PrismaService } from '../database/prisma.service';

@Global()
@Module({
  providers: [FaceRecognitionService, PrismaService],
  exports: [FaceRecognitionService],
})
export class BiometricsModule {}
