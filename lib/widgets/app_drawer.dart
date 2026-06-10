import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_config.dart';
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
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
          child: Text(
            page.group!.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
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
      width: 296,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                    backgroundImage: auth.userPhotoUrl != null
                        ? NetworkImage(auth.userPhotoUrl!)
                        : null,
                    child: auth.userPhotoUrl == null
                        ? Text(
                            displayName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w800,
                                fontSize: 18),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Pill(
                                label: _roleLabel(auth),
                                color: AppColors.accent),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (auth.universityName != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_outlined,
                        size: 13,
                        color: scheme.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        auth.universityName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(),

            // ── Nav items ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                children: navItems,
              ),
            ),

            const Divider(),
            // ── Footer ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
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
                    icon: Icons.key_outlined,
                    label: 'AI Settings',
                    onTap: () => showGroqKeySheet(context),
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
            : scheme.onSurface.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                if (trailing != null)
                  SizedBox(height: 24, child: FittedBox(child: trailing)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet to paste/update the Groq API key that powers AI features.
Future<void> showGroqKeySheet(BuildContext context) async {
  final controller = TextEditingController(text: AppConfig.groqApiKey);
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_outlined,
                  size: 18, color: AppColors.accent),
              SizedBox(width: 8),
              Text('AI Settings',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The AI Resume Builder uses Groq (Llama 3.3 70B). Paste a Groq API '
            'key — it is stored only on this device. Get a free key at '
            'console.groq.com.',
            style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(sheetContext)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Groq API Key'),
          TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'gsk_...'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              await AppConfig.setGroqApiKey(controller.text);
              if (sheetContext.mounted) {
                Navigator.pop(sheetContext);
                showAppSnack(sheetContext, 'AI settings saved');
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    ),
  );
}
