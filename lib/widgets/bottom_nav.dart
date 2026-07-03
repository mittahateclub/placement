import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../screens/home_shell.dart';

/// Floating dock bottom bar — the active item sits in a glossy ink pill
/// (porcelain in dark mode); icons swap to their filled variant when selected.
/// Supports a "no selection" state when a drawer-only page is open.
class AppBottomNav extends StatelessWidget {
  final List<AppPage> pages;
  final String selectedId;
  final void Function(String id) onSelect;

  const AppBottomNav({
    super.key,
    required this.pages,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: isLight
                  ? scheme.outline.withValues(alpha: 0.6)
                  : scheme.outline),
          boxShadow: [
            BoxShadow(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.6),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: pages.map((page) {
            final selected = page.id == selectedId;
            final labelColor = selected
                ? scheme.onSurface
                : scheme.onSurface.withValues(alpha: 0.42);
            return Expanded(
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(page.id);
                },
                borderRadius: BorderRadius.circular(22),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: const Cubic(0.16, 1, 0.3, 1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 5.5),
                      decoration: BoxDecoration(
                        gradient:
                            selected ? AppColors.glossy(brightness) : null,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: AnimatedScale(
                        scale: selected ? 1.0 : 0.92,
                        duration: const Duration(milliseconds: 260),
                        curve: const Cubic(0.16, 1, 0.3, 1),
                        child: Icon(
                          selected ? page.activeIcon ?? page.icon : page.icon,
                          size: 22,
                          color: selected
                              ? AppColors.onGlossy(brightness)
                              : scheme.onSurface.withValues(alpha: 0.42),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.1,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: labelColor,
                      ),
                      child: Text(
                        page.shortLabel ?? page.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
