import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';
import { SequenceService } from '../../core/database/sequence.service';
import { FileStorageService } from '../../core/storage/file-storage.service';

@Injectable()
export class DocumentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly fileStorageService: FileStorageService,
    private readonly sequenceService: SequenceService,
  ) {}

  private isDocumentAdminOrManager(user: any): boolean {
    if (!user) return false;
    const role = String(user?.role || '').toUpperCase();
    const roles: string[] = Array.isArray(user?.roles) ? user.roles.map((r: any) => String(r).toUpperCase()) : [];
    const allRoles = [role, ...roles];
    return allRoles.some((r) =>
      ['ROLE_ADMIN', 'ADMIN', 'ROLE_SUPER_ADMIN', 'SUPER_ADMIN', 'ROLE_SALES_MGR', 'SALES_MANAGER'].includes(r),
    );
  }

  private async getStaffId(user: any): Promise<string | null> {
    if (user?.staffId) return user.staffId;
    if (user?.id) {
      const staff = await this.prisma.staff.findFirst({ where: { userId: user.id } });
      return staff ? staff.id : null;
    }
    return null;
  }

  async assertDocumentEntityAccess(entityType: string, entityId: string, user: any): Promise<void> {
    if (!user) {
      throw new ForbiddenException('User context missing or unauthenticated');
    }

    if (this.isDocumentAdminOrManager(user)) {
      return;
    }

    const staffId = await this.getStaffId(user);
    if (!staffId) {
      throw new ForbiddenException('Fail-closed: Unmapped employee does not have permission to access CRM documents');
    }

    if (!entityType || !entityId) {
      throw new ForbiddenException('Entity type and entity ID are required for document access validation');
    }

    const normalizedType = entityType.trim().toLowerCase();

    if (normalizedType === 'customer') {
      const customer = await this.prisma.customer.findUnique({ where: { id: entityId } });
      if (!customer) throw new NotFoundException(`Customer with ID "${entityId}" not found`);
      if (customer.assignedStaffId !== staffId) {
        throw new ForbiddenException('Access denied: You are not assigned to this customer');
      }
      return;
    }

    if (normalizedType === 'lead') {
      const lead = await this.prisma.lead.findUnique({ where: { id: entityId } });
      if (!lead) throw new NotFoundException(`Lead with ID "${entityId}" not found`);
      if (lead.assignedStaffId !== staffId) {
        throw new ForbiddenException('Access denied: You are not assigned to this lead');
      }
      return;
    }

    if (normalizedType === 'enquiry') {
      const enquiry = await this.prisma.enquiry.findUnique({ where: { id: entityId } });
      if (!enquiry) throw new NotFoundException(`Enquiry with ID "${entityId}" not found`);
      if (enquiry.assignedStaffId !== staffId) {
        throw new ForbiddenException('Access denied: You are not assigned to this enquiry');
      }
      return;
    }

    if (normalizedType === 'opportunity') {
      const opp = await this.prisma.opportunity.findUnique({
        where: { id: entityId },
        include: { customer: true, lead: true, enquiry: true },
      });
      if (!opp) throw new NotFoundException(`Opportunity with ID "${entityId}" not found`);
      const isOwner =
        opp.assignedStaffId === staffId ||
        opp.customer?.assignedStaffId === staffId ||
        opp.lead?.assignedStaffId === staffId ||
        opp.enquiry?.assignedStaffId === staffId;
      if (!isOwner) {
        throw new ForbiddenException('Access denied: You are not assigned to this opportunity');
      }
      return;
    }

    if (['crmactivity', 'activity', 'followup', 'follow-up'].includes(normalizedType)) {
      const act = await this.prisma.crmActivity.findUnique({
        where: { id: entityId },
        include: { customer: true, lead: true, opportunity: true },
      });
      if (!act) throw new NotFoundException(`CRM Activity with ID "${entityId}" not found`);
      const isOwner =
        act.staffId === staffId ||
        act.customer?.assignedStaffId === staffId ||
        act.lead?.assignedStaffId === staffId ||
        act.opportunity?.assignedStaffId === staffId;
      if (!isOwner) {
        throw new ForbiddenException('Access denied: You are not assigned to this CRM activity');
      }
      return;
    }

    if (normalizedType === 'quotation') {
      const quote = await this.prisma.quotation.findUnique({
        where: { id: entityId },
        include: { customer: true },
      });
      if (!quote) throw new NotFoundException(`Quotation with ID "${entityId}" not found`);
      const isOwner = quote.assignedStaffId === staffId || quote.customer?.assignedStaffId === staffId;
      if (!isOwner) {
        throw new ForbiddenException('Access denied: You are not assigned to this quotation');
      }
      return;
    }

    if (['sys', 'system', 'general'].includes(normalizedType)) {
      throw new ForbiddenException('Access denied: Only administrators can access system-level documents');
    }
  }

  async uploadDocument(
    file: Express.Multer.File,
    entityType: string,
    entityId: string,
    documentType: string,
    uploadedBy: string,
    user?: any,
  ) {
    await this.assertDocumentEntityAccess(entityType, entityId, user);

    const storageResult = await this.fileStorageService.uploadFile(file, entityType, entityId);

    const documentCode = await this.sequenceService.nextDocumentCode();

    return this.prisma.documentItem.create({
      data: {
        documentCode,
        name: storageResult.fileName,
        documentType: documentType || 'GENERAL',
        entityType,
        entityId,
        fileName: storageResult.fileName,
        fileSize: storageResult.fileSize,
        mimeType: storageResult.mimeType,
        storagePath: storageResult.storagePath,
        uploadedBy: uploadedBy || user?.fullName || 'System User',
      },
    });
  }

  async getDocumentsByEntity(entityType: string, entityId: string, user?: any) {
    await this.assertDocumentEntityAccess(entityType, entityId, user);
    return this.prisma.documentItem.findMany({
      where: { entityType, entityId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getAllDocuments(user?: any) {
    if (this.isDocumentAdminOrManager(user)) {
      return this.prisma.documentItem.findMany({
        orderBy: { createdAt: 'desc' },
        take: 50,
      });
    }

    const staffId = await this.getStaffId(user);
    if (!staffId) {
      return [];
    }

    const [customers, leads, enquiries, opportunities, activities, quotations] = await Promise.all([
      this.prisma.customer.findMany({ where: { assignedStaffId: staffId }, select: { id: true } }),
      this.prisma.lead.findMany({ where: { assignedStaffId: staffId }, select: { id: true } }),
      this.prisma.enquiry.findMany({ where: { assignedStaffId: staffId }, select: { id: true } }),
      this.prisma.opportunity.findMany({ where: { assignedStaffId: staffId }, select: { id: true } }),
      this.prisma.crmActivity.findMany({ where: { staffId }, select: { id: true } }),
      this.prisma.quotation.findMany({ where: { assignedStaffId: staffId }, select: { id: true } }),
    ]);

    const accessibleIds = [
      ...customers.map((c) => c.id),
      ...leads.map((l) => l.id),
      ...enquiries.map((e) => e.id),
      ...opportunities.map((o) => o.id),
      ...activities.map((a) => a.id),
      ...quotations.map((q) => q.id),
    ];

    return this.prisma.documentItem.findMany({
      where: {
        OR: [
          { entityId: { in: accessibleIds } },
          { uploadedBy: user?.fullName || '___' },
        ],
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async getFileBuffer(documentId: string, user?: any) {
    const doc = await this.prisma.documentItem.findUnique({ where: { id: documentId } });
    if (!doc) throw new NotFoundException('Document record not found');

    await this.assertDocumentEntityAccess(doc.entityType, doc.entityId, user);

    const buffer = await this.fileStorageService.downloadFile(doc.storagePath);
    return { buffer, doc };
  }

  async replaceDocument(documentId: string, file: Express.Multer.File, user?: any) {
    const doc = await this.prisma.documentItem.findUnique({ where: { id: documentId } });
    if (!doc) throw new NotFoundException('Document record not found');

    await this.assertDocumentEntityAccess(doc.entityType, doc.entityId, user);

    const storageResult = await this.fileStorageService.uploadFile(file, doc.entityType, doc.entityId);

    try {
      await this.fileStorageService.deleteFile(doc.storagePath);
    } catch (e) {
      // Ignore previous file removal failure
    }

    return this.prisma.documentItem.update({
      where: { id: documentId },
      data: {
        name: storageResult.fileName,
        fileName: storageResult.fileName,
        fileSize: storageResult.fileSize,
        mimeType: storageResult.mimeType,
        storagePath: storageResult.storagePath,
        uploadedBy: user?.fullName || doc.uploadedBy,
      },
    });
  }

  async deleteDocument(documentId: string, user?: any) {
    const doc = await this.prisma.documentItem.findUnique({ where: { id: documentId } });
    if (!doc) throw new NotFoundException('Document record not found');

    await this.assertDocumentEntityAccess(doc.entityType, doc.entityId, user);

    try {
      await this.fileStorageService.deleteFile(doc.storagePath);
    } catch (e) {
      // Ignore storage cleanup failure
    }

    return this.prisma.documentItem.delete({
      where: { id: documentId },
    });
  }

  async downloadFileByPath(storagePath: string): Promise<Buffer> {
    return this.fileStorageService.downloadFile(storagePath);
  }
}
