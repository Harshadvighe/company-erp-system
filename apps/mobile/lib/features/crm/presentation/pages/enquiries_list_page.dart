import 'package:flutter/material.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/sales_marketing_portal_page.dart';

/// Enquiry Management Page that displays the full Saark ERP desktop workspace
/// with Enquiry Management active as requested.
class EnquiriesListPage extends StatelessWidget {
  const EnquiriesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SalesMarketingPortalPage(initialTab: 1, initialSubModule: 1);
  }
}
