path = 'apps/mobile/lib/features/crm/presentation/pages/sales_marketing_portal_page.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('\r\n', '\n')

# 1. Import
target_imp = "import 'package:saark_erp_mobile/features/crm/presentation/widgets/other_documents_workspace_view.dart';"
repl_imp = "import 'package:saark_erp_mobile/features/crm/presentation/widgets/other_documents_workspace_view.dart';\nimport 'package:saark_erp_mobile/features/crm/presentation/widgets/financial_reports_workspace_view.dart';"
if target_imp in content and repl_imp not in content:
    content = content.replace(target_imp, repl_imp, 1)

# 2. Body
target_body = """                                      : _activeNavTab == 7
                                          ? OtherDocumentsWorkspaceView(
                                              onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                            )
                                          : SingleChildScrollView("""

repl_body = """                                      : _activeNavTab == 7
                                          ? OtherDocumentsWorkspaceView(
                                              onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                            )
                                          : _activeNavTab == 8
                                              ? FinancialReportsWorkspaceView(
                                                  onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                                )
                                              : SingleChildScrollView("""

assert target_body in content, 'target_body not found'
content = content.replace(target_body, repl_body, 1)

# 3. Tab item
target_tab = "_NavTabItem(title: 'Report', icon: Icons.bar_chart_rounded, route: '/reports'),"
repl_tab = "_NavTabItem(title: 'Report', icon: Icons.bar_chart_rounded, route: '', isActive: _activeNavTab == 8),"
assert target_tab in content, 'target_tab not found'
content = content.replace(target_tab, repl_tab, 1)

# 4. Click
target_click = """        } else if (index == 7) {
          setState(() => _activeNavTab = 7);
        } else if (item.route.isNotEmpty) {"""

repl_click = """        } else if (index == 7) {
          setState(() => _activeNavTab = 7);
        } else if (index == 8) {
          setState(() => _activeNavTab = 8);
        } else if (item.route.isNotEmpty) {"""

assert target_click in content, 'target_click not found'
content = content.replace(target_click, repl_click, 1)

with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(content)

print('SUCCESS')
