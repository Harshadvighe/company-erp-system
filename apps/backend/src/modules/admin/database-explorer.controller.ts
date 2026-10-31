import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Param,
  Query,
  Req,
  BadRequestException,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { AdminService } from './admin.service';

@ApiTags('PostgreSQL Database Explorer')
@Controller('api/v1/database')
export class DatabaseExplorerController {
  constructor(private readonly adminService: AdminService) {}

  @Post('auth')
  @ApiOperation({ summary: 'Authenticate DBA credentials to unlock PostgreSQL Database Explorer' })
  async authenticateDba(
    @Body() dto: { username?: string; password?: string },
    @Req() req: any,
  ) {
    const clientIp = req.headers['x-forwarded-for'] || req.socket?.remoteAddress || '127.0.0.1';
    return this.adminService.verifyDatabaseAccess(dto, clientIp);
  }

  @Get('telemetry')
  @ApiOperation({ summary: 'Get live PostgreSQL connection telemetry and server metrics' })
  async getTelemetry() {
    return this.adminService.getDatabaseTelemetry();
  }

  @Get('tables')
  @ApiOperation({ summary: 'List all PostgreSQL tables categorized with live row counts and column schemas' })
  async getTables() {
    return this.adminService.getDatabaseTables();
  }

  @Get('table/:tableName')
  @ApiOperation({ summary: 'Get table column schemas, row count, sorting, and paginated records' })
  async getTableData(
    @Param('tableName') tableName: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('search') search?: string,
    @Query('sortBy') sortBy?: string,
    @Query('sortOrder') sortOrder?: 'ASC' | 'DESC',
    @Query('maskSensitive') maskSensitive?: string,
  ) {
    return this.adminService.getDatabaseTableData(tableName, {
      page: page ? parseInt(page, 10) : 1,
      limit: limit ? parseInt(limit, 10) : 25,
      search,
      sortBy,
      sortOrder,
      maskSensitive: maskSensitive === 'false' ? false : true,
    });
  }

  @Post('query')
  @ApiOperation({ summary: 'Execute safe read-only SQL SELECT queries against PostgreSQL database' })
  async runQuery(@Body() dto: { query: string; limit?: number }, @Req() req: any) {
    if (!dto || !dto.query) {
      throw new BadRequestException('SQL query is required');
    }
    return this.adminService.executeReadOnlyQuery(dto.query, dto.limit, req.user);
  }

  @Post('table/:tableName/entry')
  @ApiOperation({ summary: 'Insert a new database record entry into the specified table' })
  async insertRecord(
    @Param('tableName') tableName: string,
    @Body() dto: Record<string, any>,
    @Req() req: any,
  ) {
    return this.adminService.insertDatabaseTableRecord(tableName, dto, req.user);
  }

  @Put('table/:tableName/entry')
  @ApiOperation({ summary: 'Update an existing database record in the specified table' })
  async updateRecord(
    @Param('tableName') tableName: string,
    @Body() dto: { primaryKeyCol: string; primaryKeyValue: any; data: Record<string, any> },
    @Req() req: any,
  ) {
    if (!dto || !dto.primaryKeyCol || dto.primaryKeyValue === undefined || !dto.data) {
      throw new BadRequestException('primaryKeyCol, primaryKeyValue, and data are required');
    }
    return this.adminService.updateDatabaseTableRecord(
      tableName,
      dto.primaryKeyCol,
      dto.primaryKeyValue,
      dto.data,
      req.user,
    );
  }

  @Delete('table/:tableName/entry')
  @ApiOperation({ summary: 'Delete a database record from the specified table' })
  async deleteRecord(
    @Param('tableName') tableName: string,
    @Body() dto: { primaryKeyCol: string; primaryKeyValue: any },
    @Query('primaryKeyCol') queryPkCol?: string,
    @Query('primaryKeyValue') queryPkVal?: string,
    @Req() req?: any,
  ) {
    const pkCol = dto?.primaryKeyCol || queryPkCol;
    const pkVal = dto?.primaryKeyValue !== undefined ? dto.primaryKeyValue : queryPkVal;
    if (!pkCol || pkVal === undefined) {
      throw new BadRequestException('primaryKeyCol and primaryKeyValue are required');
    }
    return this.adminService.deleteDatabaseTableRecord(tableName, pkCol, pkVal, req?.user);
  }

  @Post('table/:tableName/bulk-insert')
  @ApiOperation({ summary: 'Bulk insert records into specified table (CSV/JSON upload)' })
  async bulkInsert(
    @Param('tableName') tableName: string,
    @Body() dto: { records: Record<string, any>[] },
    @Req() req: any,
  ) {
    if (!dto || !Array.isArray(dto.records)) {
      throw new BadRequestException('records array is required');
    }
    return this.adminService.bulkInsertDatabaseTableRecords(tableName, dto.records, req.user);
  }

  @Post('change-password')
  @ApiOperation({ summary: 'Change master database login credentials' })
  async changePassword(
    @Body() dto: { username: string; currentPassword: string; newPassword: string },
    @Req() req: any,
  ) {
    return this.adminService.changeDbaPassword(dto, req.user);
  }

  @Post('backup')
  @ApiOperation({ summary: 'Trigger verified system database snapshot backup' })
  async triggerBackup(@Req() req: any) {
    return this.adminService.triggerSystemBackup(req.user);
  }
}

