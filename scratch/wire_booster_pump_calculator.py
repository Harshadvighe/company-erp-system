import os

# 1. Update sales_marketing_portal_page.dart
portal_path = 'apps/mobile/lib/features/crm/presentation/pages/sales_marketing_portal_page.dart'
with open(portal_path, 'r', encoding='utf-8') as f:
    portal_content = f.read()

portal_content = portal_content.replace('\r\n', '\n')

# 1.1 Body replacement
body_target = """                                           : _activeNavTab == 8
                                               ? FinancialReportsWorkspaceView(
                                                   onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                                 )
                                               : SingleChildScrollView("""

body_repl = """                                           : _activeNavTab == 8
                                               ? FinancialReportsWorkspaceView(
                                                   onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                                 )
                                               : _activeNavTab == 9
                                                   ? BoosterPumpCalculatorWorkspaceView(
                                                       onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                                     )
                                                   : SingleChildScrollView("""

if body_target in portal_content:
    portal_content = portal_content.replace(body_target, body_repl, 1)
    print("Updated portal_content body")
else:
    print("Warning: body_target not found in portal_content")

# 1.2 Category button click handler
click_target = """            if (item.title == 'Customer CRM & Leads') {
              setState(() => _activeNavTab = 1);
            } else if (item.title == 'Saark Product Sector' || item.title == 'Water Meter' || item.title == 'BMS') {
              setState(() => _activeNavTab = 2);
            } else {
              context.go(item.route);
            }"""

click_repl = """            if (item.title == 'Customer CRM & Leads') {
              setState(() => _activeNavTab = 1);
            } else if (item.title == 'Saark Product Sector' || item.title == 'Water Meter' || item.title == 'BMS') {
              setState(() => _activeNavTab = 2);
            } else if (item.title.contains('Booster Pump')) {
              setState(() => _activeNavTab = 9);
            } else {
              context.go(item.route);
            }"""

if click_target in portal_content:
    portal_content = portal_content.replace(click_target, click_repl, 1)
    print("Updated category click handler")
else:
    print("Warning: click_target not found")

# 1.3 Update category route
cat_target = """    _CategoryButtonData(
      title: 'Booster Pump Control Panel Desing,Materil & Price Calculator',
      route: '/production/new',
      description: 'Design booster pump specs, calculate BOM material cost & final price',
    ),"""

cat_repl = """    _CategoryButtonData(
      title: 'Booster Pump Control Panel Desing,Materil & Price Calculator',
      route: '/production/booster-pump-calculator',
      description: 'Design booster pump specs, calculate BOM material cost & final price',
    ),"""

if cat_target in portal_content:
    portal_content = portal_content.replace(cat_target, cat_repl, 1)
    print("Updated category route")

with open(portal_path, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(portal_content)

print("Finished updating portal_page")

# 2. Update app_router.dart
router_path = 'apps/mobile/lib/core/routing/app_router.dart'
with open(router_path, 'r', encoding='utf-8') as f:
    router_content = f.read()

router_content = router_content.replace('\r\n', '\n')

router_imp_target = "import 'package:saark_erp_mobile/features/production/presentation/pages/panel_spec_form_page.dart';"
router_imp_repl = "import 'package:saark_erp_mobile/features/production/presentation/pages/panel_spec_form_page.dart';\nimport 'package:saark_erp_mobile/features/production/presentation/pages/booster_pump_calculator_page.dart';"

if router_imp_target in router_content and 'booster_pump_calculator_page.dart' not in router_content:
    router_content = router_content.replace(router_imp_target, router_imp_repl, 1)
    print("Added router import")

router_route_target = """          GoRoute(
            path: '/production/new',
            name: 'panel-spec-form',
            builder: (context, state) => const PanelSpecFormPage(),
          ),"""

router_route_repl = """          GoRoute(
            path: '/production/new',
            name: 'panel-spec-form',
            builder: (context, state) => const PanelSpecFormPage(),
          ),
          GoRoute(
            path: '/production/booster-pump-calculator',
            name: 'booster-pump-calculator',
            builder: (context, state) => const BoosterPumpCalculatorPage(),
          ),"""

if router_route_target in router_content and '/production/booster-pump-calculator' not in router_content:
    router_content = router_content.replace(router_route_target, router_route_repl, 1)
    print("Added route to router")

with open(router_path, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(router_content)

print("Finished updating app_router.dart")
