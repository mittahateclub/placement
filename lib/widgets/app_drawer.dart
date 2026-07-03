import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/theme_controller.dart';
import '../screens/home_shell.dart';
import '../services/auth_service.dart';
import 'common.dart';

/// Role-aware navigation drawer (the app's "drag menu").
class AppDrawer extends StatelessWidget {
  final List<AppPage> pages;
  final String selectedId;
  final void Function(String id) onSelect;

  const AppDrawer({
    super.key,
    required this.pages,
    required this.selectedId,
    required this.onSelect,
  });

  String _roleLabel(AuthService auth) => auth.isSuperAdmin
      ? 'Super Admin'
      : auth.isUniAdmin
          ? 'Uni Admin'
          : 'Student';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final theme = context.watch<ThemeController>();
    final scheme = Theme.of(context).colorScheme;

    final displayName = auth.userName ??
        auth.user?.email?.split('@').first ??
        'Account';

    final navItems = <Widget>[];
    String? lastGroup;
    for (final page in pages) {
      if (page.group != null && page.group != lastGroup) {
        lastGroup = page.group;
        navItems.add(Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
          child: Text(
            page.group!.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: scheme.onSurface.withValues(alpha: 0.32),
            ),
          ),
        ));
      }
      navItems.add(_DrawerTile(
        icon: page.icon,
        label: page.label,
        selected: page.id == selectedId,
        onTap: () => onSelect(page.id),
      ));
    }

    return Drawer(
      width: 300,
      child: SafeArea(
        child: Column(
          children: [
            // ── Brand strip ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Image.asset(
                    theme.isDark
                        ? 'assets/logo_dark.png'
                        : 'assets/logo.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'UniShip',
                    style: AppTheme.display(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // ── User card ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.10)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        gradient:
                            AppColors.glossy(Theme.of(context).brightness),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: scheme.surfaceContainer,
                        backgroundImage: auth.userPhotoUrl != null
                            ? NetworkImage(auth.userPhotoUrl!)
                            : null,
                        child: auth.userPhotoUrl == null
                            ? Text(
                                displayName.substring(0, 1).toUpperCase(),
                                style: AppTheme.display(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.display(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Pill(
                                  label: _roleLabel(auth),
                                  color: AppColors.accent),
                            ],
                          ),
                          if (auth.universityName != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.account_balance_outlined,
                                    size: 12,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.4)),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    auth.universityName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.5)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Nav items ──
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: navItems,
              ),
            ),

            Divider(color: scheme.outline.withValues(alpha: 0.6)),
            // ── Footer ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  _DrawerTile(
                    icon: theme.isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    label: theme.isDark ? 'Light Mode' : 'Dark Mode',
                    onTap: theme.toggle,
                    trailing: Switch(
                      value: theme.isDark,
                      onChanged: (_) => theme.toggle(),
                    ),
                  ),
                  _DrawerTile(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    danger: true,
                    onTap: () async {
                      Navigator.pop(context);
                      await auth.signOut();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool danger;
  final VoidCallback onTap;
  final Widget? trailing;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.danger = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger
        ? AppColors.danger
        : selected
            ? scheme.primary
            : scheme.onSurface.withValues(alpha: 0.62);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.08)
                  : null,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 11.5),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: danger
                            ? AppColors.danger
                            : selected
                                ? scheme.primary
                                : scheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  if (selected && trailing == null)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (trailing != null)
                    SizedBox(height: 24, child: FittedBox(child: trailing)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
