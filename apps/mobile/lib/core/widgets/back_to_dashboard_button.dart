import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';

/// Standardized "Back to Dashboard" button used across all modules in Saark ERP.
/// Ensures consistent branding, styling, icon, label, and navigation behavior across the entire app.
class BackToDashboardButton extends StatelessWidget {
  final String label;
  final String route;
  final bool compact;
  final VoidCallback? onCustomTap;

  const BackToDashboardButton({
    super.key,
    this.label = 'Back to Dashboard',
    this.route = '/dashboard',
    this.compact = false,
    this.onCustomTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCustomTap ?? () => context.go(route),
        borderRadius: BorderRadius.circular(6),
        hoverColor: AppTheme.primaryHover,
        splashColor: Colors.white24,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.sm : AppSpacing.md,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 15,
              ),
              AppSpacing.gapW6,
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? AppTypography.scaleLabelSmall : AppTypography.scaleLabelMedium,
                  fontWeight: AppTypography.semiBold,
                  letterSpacing: 0.3,
                  height: AppTypography.leadingLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
