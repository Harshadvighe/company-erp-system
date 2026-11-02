import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    let dbUrl = process.env.DATABASE_URL || '';
    if (dbUrl) {
      // If connecting to Supabase pooler on port 5432 (session mode), automatically switch to port 6543 (transaction mode)
      // for application queries to prevent hitting the 15-connection limit (EMAXCONNSESSION)
      if (dbUrl.includes('.pooler.supabase.com:5432')) {
        dbUrl = dbUrl.replace('.pooler.supabase.com:5432', '.pooler.supabase.com:6543');
        if (!dbUrl.includes('pgbouncer=true')) {
          const sep = dbUrl.includes('?') ? '&' : '?';
          dbUrl = `${dbUrl}${sep}pgbouncer=true`;
        }
      }

      if (dbUrl.includes(':6543') && !dbUrl.includes('pgbouncer=true')) {
        const sep = dbUrl.includes('?') ? '&' : '?';
        dbUrl = `${dbUrl}${sep}pgbouncer=true`;
      }

      if (/connection_limit=\d+/.test(dbUrl)) {
        dbUrl = dbUrl.replace(/connection_limit=\d+/, 'connection_limit=5');
      } else {
        const sep = dbUrl.includes('?') ? '&' : '?';
        dbUrl = `${dbUrl}${sep}connection_limit=5`;
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
