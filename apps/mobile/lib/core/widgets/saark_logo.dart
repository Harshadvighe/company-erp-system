import 'package:flutter/material.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/widgets/saark_logo_data.dart';

/// The crisp official SE brand emblem with zero-failure fallback.
class SaarkEmblemImage extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;

  const SaarkEmblemImage({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/saark_emblem.png',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => Image.network(
        '/assets/saark_emblem.png',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => Image.memory(
          kSaarkEmblemBytes,
          width: width,
          height: height,
          fit: fit,
        ),
      ),
    );
  }
}

/// The tightly cropped full official logo (SE + Saark Exploration + Tagline).
class SaarkFullLogoImage extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;

  const SaarkFullLogoImage({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/saark_full.png',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => Image.network(
        '/assets/saark_full.png',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => Image.memory(
          kSaarkFullLogoBytes,
          width: width,
          height: height,
          fit: fit,
        ),
      ),
    );
  }
}

/// Backward compatibility alias
class SaarkLogoImage extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;

  const SaarkLogoImage({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return SaarkEmblemImage(width: width, height: height, fit: fit);
  }
}

/// Industrial crisp badge showing the official SE emblem
class SaarkLogoBadge extends StatelessWidget {
  final double size;
  final bool showBackground;
  final VoidCallback? onTap;

  const SaarkLogoBadge({
    super.key,
    this.size = 32,
    this.showBackground = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final emblem = SaarkEmblemImage(
      width: size * 1.25,
      height: size * 0.68,
      fit: BoxFit.contain,
    );

    if (!showBackground) {
      return SizedBox(
        width: size * 1.25,
        height: size,
        child: Center(child: emblem),
      );
    }

    Widget badge = Container(
      width: size * 1.25,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
          color: const Color(0xFFF15A24).withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF15A24).withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: size * 0.12, vertical: size * 0.1),
      alignment: Alignment.center,
      child: emblem,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size * 0.22),
        child: badge,
      );
    }

    return badge;
  }
}

/// Full brand header containing the official logo badge + 'SAARK ERP' with stylized typography.
class SaarkBrandHeader extends StatefulWidget {
  final double badgeSize;
  final double fontSize;
  final bool isCompact;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  const SaarkBrandHeader({
    super.key,
    this.badgeSize = 32,
    this.fontSize = 14,
    this.isCompact = false,
    this.onTap,
    this.onDoubleTap,
  });

  @override
  State<SaarkBrandHeader> createState() => _SaarkBrandHeaderState();
}

class _SaarkBrandHeaderState extends State<SaarkBrandHeader> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Widget content = MouseRegion(
      cursor: (widget.onTap != null || widget.onDoubleTap != null)
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: _isHovered && (widget.onTap != null || widget.onDoubleTap != null)
              ? const Color(0xFFF15A24).withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SaarkLogoBadge(
              size: widget.badgeSize,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SAARK ERP',
                        style: TextStyle(
                          color: _isHovered ? const Color(0xFFFF7A45) : AppTheme.primary,
                          fontSize: widget.fontSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF15A24).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFF15A24).withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          'INDUSTRIAL',
                          style: TextStyle(
                            color: Color(0xFFFF9E77),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!widget.isCompact)
                    const Text(
                      'Saark Exploration Pvt. Ltd.',
                      style: TextStyle(
                        color: AppTypography.darkTextSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.onTap != null || widget.onDoubleTap != null) {
      return InkWell(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }

    return content;
  }
}

/// Full brand card displaying the entire official logo (emblem + company name + tagline)
class SaarkFullLogoCard extends StatelessWidget {
  final double width;
  final double? height;
  final EdgeInsetsGeometry padding;

  const SaarkFullLogoCard({
    super.key,
    this.width = 240,
    this.height,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF15A24).withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF15A24).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: const SaarkFullLogoImage(
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
