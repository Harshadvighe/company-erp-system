import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/features/production/presentation/widgets/booster_pump_calculator_workspace_view.dart';

class BoosterPumpCalculatorPage extends StatelessWidget {
  const BoosterPumpCalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141518),
      body: SafeArea(
        child: BoosterPumpCalculatorWorkspaceView(
          onBackToDashboard: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/crm/portal');
            }
          },
        ),
      ),
    );
  }
}
