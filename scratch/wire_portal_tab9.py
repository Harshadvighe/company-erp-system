portal_path = 'apps/mobile/lib/features/crm/presentation/pages/sales_marketing_portal_page.dart'
with open(portal_path, 'r', encoding='utf-8') as f:
    portal_content = f.read()

portal_content = portal_content.replace('\r\n', '\n')

old_frag = """: _activeNavTab == 8
                                               ? FinancialReportsWorkspaceView(
                                                   onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                                 )
                                               : SingleChildScrollView("""

new_frag = """: _activeNavTab == 8
                                               ? FinancialReportsWorkspaceView(
                                                   onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                                 )
                                               : _activeNavTab == 9
                                                   ? BoosterPumpCalculatorWorkspaceView(
                                                       onBackToDashboard: () => setState(() => _activeNavTab = 0),
                                                     )
                                                   : SingleChildScrollView("""

assert old_frag in portal_content, "old_frag not found!"
portal_content = portal_content.replace(old_frag, new_frag, 1)

with open(portal_path, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(portal_content)

print("SUCCESSFULLY WIRED BODY TAB 9")
