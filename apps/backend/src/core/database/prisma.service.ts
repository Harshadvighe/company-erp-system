import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    let dbUrl = process.env.DATABASE_URL || '';
    if (dbUrl) {
      // Ensure connection limit is bounded to 3 to prevent exhaust on Supabase pool (15 max session connections)
      if (/connection_limit=\d+/.test(dbUrl)) {
        dbUrl = dbUrl.replace(/connection_limit=\d+/, 'connection_limit=3');
      } else {
        const sep = dbUrl.includes('?') ? '&' : '?';
        dbUrl = `${dbUrl}${sep}connection_limit=3`;
      }

      // If pooler port is 6543, ensure pgbouncer=true
      if (dbUrl.includes(':6543') && !dbUrl.includes('pgbouncer=true')) {
        const sep = dbUrl.includes('?') ? '&' : '?';
        dbUrl = `${dbUrl}${sep}pgbouncer=true`;
      }

      // Add pool timeout and connect timeout so queries don't hang indefinitely
      if (!dbUrl.includes('pool_timeout=')) {
        const sep = dbUrl.includes('?') ? '&' : '?';
        dbUrl = `${dbUrl}${sep}pool_timeout=15`;
      }
      if (!dbUrl.includes('connect_timeout=')) {
        const sep = dbUrl.includes('?') ? '&' : '?';
        dbUrl = `${dbUrl}${sep}connect_timeout=15`;
      }
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
    // Connect asynchronously in background to ensure instant server port binding
    this.$connect()
      .then(() => {
        this.logger.log('✅ Connected to database successfully');
      })
      .catch((err: any) => {
        this.logger.warn(`⚠️ Database connection notice: ${err?.message || err}. Queries will retry automatically.`);
      });
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}
