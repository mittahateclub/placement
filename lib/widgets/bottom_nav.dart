import 'package:flutter/material.dart';

import '../screens/home_shell.dart';

/// Traditional bottom navigation bar for the role's primary destinations.
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

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: pages.map((page) {
              final selected = page.id == selectedId;
              final color = selected
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.45);
              return Expanded(
                child: InkWell(
                  onTap: () => onSelect(page.id),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? scheme.primary.withValues(alpha: 0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          selected ? page.activeIcon ?? page.icon : page.icon,
                          size: 21,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        page.shortLabel ?? page.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.1,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
