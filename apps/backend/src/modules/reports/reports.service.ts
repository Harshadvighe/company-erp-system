import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../core/database/prisma.service';

@Injectable()
export class ReportsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * 1. Consolidated Executive Summary
   */
  async getExecutiveSummary() {
    const [
      customersCount,
      vendorsCount,
      products,
      invoices,
      salesOrders,
      purchaseOrders,
      panelSpecs,
      staffCount,
    ] = await Promise.all([
      this.prisma.customer.count({ where: { status: 'ACTIVE' } }),
      this.prisma.vendor.count({ where: { status: 'ACTIVE' } }),
      this.prisma.product.findMany({ select: { id: true, purchasePrice: true, currentStock: true, reorderLevel: true } }),
      this.prisma.salesInvoice.findMany({
        select: {
          id: true,
          grandTotal: true,
          status: true,
          taxAmount: true,
          createdAt: true,
        },
      }),
      this.prisma.salesOrder.findMany({
        select: {
          id: true,
          grandTotal: true,
          status: true,
          createdAt: true,
        },
      }),
      this.prisma.purchaseOrder.findMany({
        select: {
          id: true,
          totalAmount: true,
          status: true,
          createdAt: true,
        },
      }),
      this.prisma.panelSpecification.findMany({
        select: { id: true, status: true, panelType: true, finalPrice: true },
      }),
      this.prisma.staff.count({ where: { status: 'ACTIVE' } }),
    ]);

    // Financial Metrics
    let totalRevenue = 0;
    let pendingReceivables = 0;
    let collectedRevenue = 0;
    let totalGstCollected = 0;

    invoices.forEach((inv) => {
      const amt = Number(inv.grandTotal) || 0;
      const tax = Number(inv.taxAmount) || 0;
      totalRevenue += amt;
      totalGstCollected += tax;

      if (inv.status === 'PAID') {
        collectedRevenue += amt;
      } else if (inv.status === 'ISSUED' || inv.status === 'PARTIALLY_PAID') {
        pendingReceivables += amt;
      }
    });

    let totalProcurement = 0;
    let pendingPayables = 0;
    purchaseOrders.forEach((po) => {
      const amt = Number(po.totalAmount) || 0;
      totalProcurement += amt;
      if (po.status === 'APPROVED' || po.status === 'PARTIALLY_RECEIVED') {
        pendingPayables += amt;
      }
    });

    // Inventory Valuation
    let totalStockValuation = 0;
    let totalUnits = 0;
    let lowStockCount = 0;

    products.forEach((p) => {
      const qty = p.currentStock || 0;
      const cost = Number(p.purchasePrice) || 0;
      totalStockValuation += qty * cost;
      totalUnits += qty;
      if (qty <= p.reorderLevel) lowStockCount++;
    });

    // Panel Manufacturing Pipeline
    const panelStatusCounts: Record<string, number> = {};
    panelSpecs.forEach((ps) => {
      const st = ps.status || 'DRAFT';
      panelStatusCounts[st] = (panelStatusCounts[st] || 0) + 1;
    });

    return {
      financials: {
        totalRevenue,
        collectedRevenue,
        pendingReceivables,
        totalProcurement,
        pendingPayables,
        netCashFlowEstimate: collectedRevenue - totalProcurement,
        totalGstCollected,
      },
      operations: {
        totalCustomers: customersCount,
        totalVendors: vendorsCount,
        activeStaff: staffCount,
        totalStockValuation,
        totalStockUnits: totalUnits,
        lowStockCount,
        panelSpecsCount: panelSpecs.length,
        panelStatusCounts,
        salesOrdersCount: salesOrders.length,
        purchaseOrdersCount: purchaseOrders.length,
      },
    };
  }

  /**
   * 2. Commercial & Sales Performance Report
   */
  async getSalesReport() {
    const [orders, invoices, quotations, topCustomers] = await Promise.all([
      this.prisma.salesOrder.findMany({
        take: 50,
        orderBy: { createdAt: 'desc' },
        include: { customer: { select: { companyName: true, customerCode: true } } },
      }),
      this.prisma.salesInvoice.findMany({
        take: 50,
        orderBy: { createdAt: 'desc' },
        include: { customer: { select: { companyName: true, customerCode: true } } },
      }),
      this.prisma.quotation.findMany({
        select: { id: true, status: true, grandTotal: true, createdAt: true },
      }),
      this.prisma.customer.findMany({
        take: 5,
        orderBy: { createdAt: 'asc' },
        include: {
          quotations: { select: { grandTotal: true } },
          salesInvoices: { select: { grandTotal: true } },
        },
      }),
    ]);

    const totalQuotations = quotations.length;
    const wonQuotations = quotations.filter((q) => q.status === 'ACCEPTED').length;
    const conversionRate = totalQuotations > 0 ? (wonQuotations / totalQuotations) * 100 : 0;

    const customerSpendLeaderboard = topCustomers.map((c) => {
      const billed = c.salesInvoices.reduce((acc, curr) => acc + (Number(curr.grandTotal) || 0), 0);
      return {
        id: c.id,
        name: c.companyName,
        code: c.customerCode,
        billedAmount: billed,
      };
    });

    return {
      totalQuotations,
      wonQuotations,
      conversionRate: Math.round(conversionRate * 10) / 10,
      recentOrders: orders.slice(0, 10).map((o) => ({
        id: o.id,
        orderNumber: o.orderNumber,
        customerName: o.customer.companyName,
        totalAmount: o.grandTotal,
        status: o.status,
        date: o.orderDate,
      })),
      topCustomers: customerSpendLeaderboard,
      recentInvoices: invoices.slice(0, 10).map((i) => ({
        id: i.id,
        invoiceNumber: i.invoiceNumber,
        customerName: i.customer.companyName,
        totalAmount: i.grandTotal,
        status: i.status,
        date: i.invoiceDate,
      })),
    };
  }

  /**
   * 3. Inventory & Materials Valuation Report
   */
  async getInventoryReport() {
    const [warehouses, products, transactions] = await Promise.all([
      this.prisma.warehouse.findMany({
        include: {
          stockItems: {
            include: { product: true },
          },
        },
      }),
      this.prisma.product.findMany({
        where: { status: 'ACTIVE' },
        include: { unit: true, category: true },
      }),
      this.prisma.stockTransaction.findMany({
        take: 20,
        orderBy: { transactionDate: 'desc' },
        include: {
          product: { select: { sku: true, name: true } },
          warehouse: { select: { code: true, name: true } },
        },
      }),
    ]);

    const warehouseBreakdown = warehouses.map((wh) => {
      let valuation = 0;
      let units = 0;
      wh.stockItems.forEach((si) => {
        units += si.currentQuantity;
        valuation += si.currentQuantity * (Number(si.product?.purchasePrice) || 0);
      });
      return {
        id: wh.id,
        code: wh.code,
        name: wh.name,
        location: wh.location,
        units,
        valuation,
        skuCount: wh.stockItems.length,
      };
    });

    const lowStockAlerts = products
      .filter((p) => (p.currentStock || 0) <= p.reorderLevel)
      .map((p) => ({
        id: p.id,
        sku: p.sku,
        name: p.name,
        category: p.category?.name || 'General',
        currentStock: p.currentStock,
        reorderLevel: p.reorderLevel,
        unit: p.unit?.name || 'Nos',
        deficit: p.reorderLevel - (p.currentStock || 0),
      }));

    return {
      warehouseBreakdown,
      lowStockAlerts,
      recentMovements: transactions.map((t) => ({
        id: t.id,
        type: t.transactionType,
        quantity: t.quantity,
        sku: t.product?.sku,
        productName: t.product?.name,
        warehouseCode: t.warehouse?.code,
        date: t.transactionDate,
        notes: t.notes,
      })),
    };
  }

  /**
   * 4. Production & Quality Signoff Throughput Report
   */
  async getProductionReport() {
    const specs = await this.prisma.panelSpecification.findMany({
      include: {
        customer: { select: { companyName: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    const stageBreakdown: Record<string, number> = {
      DRAFT: 0,
      ESTIMATION: 0,
      ENGINEERING_APPROVED: 0,
      BOM_RELEASED: 0,
      FABRICATION: 0,
      WIRING: 0,
      TESTING_QC: 0,
      COMPLETED: 0,
      DISPATCHED: 0,
    };

    specs.forEach((s) => {
      const st = s.status || 'DRAFT';
      stageBreakdown[st] = (stageBreakdown[st] || 0) + 1;
    });

    return {
      totalPanels: specs.length,
      stageBreakdown,
      activePanels: specs.slice(0, 10).map((s) => ({
        id: s.id,
        panelCode: s.panelCode,
        customerName: s.customer?.companyName || 'Standard Panel Stock',
        panelType: s.panelType,
        voltage: s.voltage,
        status: s.status,
        finalPrice: s.finalPrice,
      })),
    };
  }
}
