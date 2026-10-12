import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';

@Injectable()
export class DashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async getMetrics(roleCode?: string) {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const [
      customerCount,
      vendorCount,
      productCount,
      openEnquiries,
      activeLeads,
      panelSpecsCount,
      recentInteractions,
      recentAuditLogs,
      invoiceStats,
      purchaseStats,
      enquiryBreakdown,
      customerTypeBreakdown,
      pendingFollowUps,
      openOpportunities,
    ] = await Promise.all([
      this.prisma.customer.count(),
      this.prisma.vendor.count(),
      this.prisma.product.count(),
      this.prisma.enquiry.count({ where: { status: 'PENDING' } }),
      this.prisma.lead.count({ where: { status: { notIn: ['WON', 'LOST', 'DISQUALIFIED'] } } }),
      this.prisma.panelSpecification.count(),
      this.prisma.customerInteraction.findMany({
        take: 5,
        orderBy: { interactionDate: 'desc' },
        include: { customer: { select: { companyName: true, customerCode: true } } },
      }),
      this.prisma.auditLog.findMany({
        take: 5,
        orderBy: { timestamp: 'desc' },
      }),
      // Real revenue from invoices this month
      this.prisma.salesInvoice.aggregate({
        _sum: { grandTotal: true, paidAmount: true, balanceDue: true },
        where: { createdAt: { gte: monthStart } },
      }),
      // Real payables from purchase invoices
      this.prisma.purchaseInvoice.aggregate({
        _sum: { balanceAmount: true },
        where: { status: { in: ['UNPAID', 'PARTIALLY_PAID'] } },
      }),
      // Real enquiry status breakdown
      this.prisma.enquiry.groupBy({
        by: ['status'],
        _count: { id: true },
      }),
      // Real customer type breakdown
      this.prisma.customer.groupBy({
        by: ['customerType'],
        _count: { id: true },
      }),
      this.prisma.crmFollowUp.count({ where: { status: 'PENDING' } }),
      this.prisma.opportunity.count({ where: { stage: { notIn: ['CLOSED_WON', 'CLOSED_LOST'] } } }),
    ]);

    return {
      kpis: {
        customers: customerCount,
        vendors: vendorCount,
        products: productCount,
        openEnquiries,
        activeLeads,
        panelSpecs: panelSpecsCount,
        pendingFollowUps,
        openOpportunities,
        currentRevenue: invoiceStats._sum.grandTotal ?? 0,
        receivables: invoiceStats._sum.balanceDue ?? 0,
        collected: invoiceStats._sum.paidAmount ?? 0,
        payables: purchaseStats._sum.balanceAmount ?? 0,
      },
      charts: {
        enquiryStatusBreakdown: enquiryBreakdown.map((e) => ({
          status: e.status,
          count: e._count.id,
        })),
        customerTypeBreakdown: customerTypeBreakdown.map((c) => ({
          type: c.customerType,
          count: c._count.id,
        })),
      },
      recentInteractions,
      recentAuditLogs,
    };
  }
}
