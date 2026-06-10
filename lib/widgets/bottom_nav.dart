import 'package:flutter/material.dart';

import '../screens/home_shell.dart';

/// Floating rounded bottom bar with an animated pill indicator.
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
    final isLight = Theme.of(context).brightness == Brightness.light;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(26),
          border: isLight
              ? null
              : Border.all(color: scheme.outline.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.10 : 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: pages.map((page) {
            final selected = page.id == selectedId;
            final color = selected
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.42);
            return Expanded(
              child: InkWell(
                onTap: () => onSelect(page.id),
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primary.withValues(alpha: 0.13)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        selected ? page.activeIcon ?? page.icon : page.icon,
                        size: 22,
                        color: color,
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
                        color: color,
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
