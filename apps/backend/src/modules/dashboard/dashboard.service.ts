import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';

@Injectable()
export class DashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async getMetrics(roleCode?: string) {
    const [
      customerCount,
      vendorCount,
      productCount,
      openEnquiries,
      activeLeads,
      panelSpecsCount,
      recentInteractions,
      recentAuditLogs,
    ] = await Promise.all([
      this.prisma.customer.count(),
      this.prisma.vendor.count(),
      this.prisma.product.count(),
      this.prisma.enquiry.count({ where: { status: 'PENDING' } }),
      this.prisma.lead.count({ where: { status: { notIn: ['WON', 'LOST'] } } }),
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
    ]);

    // Financial Overview summary
    const revenueStats = {
      monthlyTarget: 5000000.0,
      currentRevenue: 3850000.0,
      receivables: 1240000.0,
      payables: 650000.0,
    };

    return {
      kpis: {
        customers: customerCount,
        vendors: vendorCount,
        products: productCount,
        openEnquiries,
        activeLeads,
        panelSpecs: panelSpecsCount,
        monthlyTarget: revenueStats.monthlyTarget,
        currentRevenue: revenueStats.currentRevenue,
        receivables: revenueStats.receivables,
        payables: revenueStats.payables,
      },
      charts: {
        enquiryStatusBreakdown: [
          { status: 'PENDING', count: openEnquiries },
          { status: 'QUOTED', count: 3 },
          { status: 'CLOSED_WON', count: 8 },
        ],
        customerTypeBreakdown: [
          { type: 'End Customer', count: 5 },
          { type: 'Distributor', count: 3 },
          { type: 'OEM', count: 2 },
        ],
      },
      recentInteractions,
      recentAuditLogs,
    };
  }
}
