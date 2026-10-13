import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

function buildDatasourceConfig() {
  const dbUrl = process.env.DATABASE_URL;
  if (!dbUrl) return undefined;

  if (dbUrl.startsWith('postgresql://') || dbUrl.startsWith('postgres://')) {
    try {
      const url = new URL(dbUrl);
      let modified = false;

      // Conservative connection limit to prevent exhausting Supabase pool (limit: 15)
      if (!url.searchParams.has('connection_limit')) {
        url.searchParams.set('connection_limit', '5');
        modified = true;
      }

      // If connecting to Supabase transaction pooler port 6543, ensure pgbouncer=true
      if (url.port === '6543' && !url.searchParams.has('pgbouncer')) {
        url.searchParams.set('pgbouncer', 'true');
        modified = true;
      }

      if (modified) {
        return {
          datasources: {
            db: {
              url: url.toString(),
            },
          },
        };
      }
    } catch {
      // Fallback to default Prisma env lookup
    }
  }

  return undefined;
}

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    const config = buildDatasourceConfig();
    super(config);
  }

  async onModuleInit() {
    this.logger.log('Connecting to database...');
    await this.$connect();
    this.logger.log('Database connected successfully.');
  }

  async onModuleDestroy() {
    this.logger.log('Disconnecting from database...');
    await this.$disconnect();
    this.logger.log('Database disconnected.');
  }
}
