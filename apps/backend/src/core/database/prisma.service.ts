import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    let dbUrl = process.env.DATABASE_URL || '';
    if (dbUrl && !dbUrl.includes('connection_limit=')) {
      const sep = dbUrl.includes('?') ? '&' : '?';
      dbUrl = `${dbUrl}${sep}connection_limit=3`;
    }

    super(dbUrl ? {
      datasources: {
        db: {
          url: dbUrl,
        },
      },
    } : undefined);
  }

  async onModuleInit() {
    try {
      await this.$connect();
      this.logger.log('✅ Connected to database successfully');
    } catch (err: any) {
      this.logger.warn(`⚠️ Database connection pool notice: ${err.message}. Queries will retry automatically.`);
    }
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
