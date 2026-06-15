import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/format.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common.dart';

/// In-app notification center: upcoming tests, events and deadlines on
/// standard reminder windows, plus a switch to enable OS reminders.
class NotificationsScreen extends StatefulWidget {
  /// Switches the underlying tab when an alert is tapped.
  final void Function(String id)? onNavigate;
  const NotificationsScreen({super.key, this.onNavigate});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _granted = true;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    // Refresh in the background, then clear the unread badge.
    NotificationService.sync(auth).then((_) => NotificationService.markAllSeen());
    NotificationService.permissionGranted().then((g) {
      if (mounted) setState(() => _granted = g);
    });
  }

  Future<void> _refresh() async {
    await NotificationService.sync(context.read<AuthService>());
    await NotificationService.markAllSeen();
  }

  Future<void> _toggle(bool value) async {
    final auth = context.read<AuthService>();
    await NotificationService.setEnabled(value, auth);
    if (value) {
      final granted = await NotificationService.requestPermission();
      if (mounted) setState(() => _granted = granted);
    }
    if (mounted) setState(() {});
  }

  Future<void> _sendTest() async {
    final status = await NotificationService.sendTestNotification();
    final granted = await NotificationService.permissionGranted();
    if (!mounted) return;
    setState(() => _granted = granted);
    showAppSnack(context, status, error: !granted);
  }

  void _open(AppAlert a) {
    if (a.navTarget != null && widget.onNavigate != null) {
      Navigator.pop(context);
      widget.onNavigate!(a.navTarget!);
    } else {
      showAppSnack(context,
          'This assessment is taken on the UniShip web portal.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ValueListenableBuilder<List<AppAlert>>(
            valueListenable: NotificationService.alerts,
            builder: (context, all, _) {
              final now = DateTime.now();
              final visible = all
                  .where((a) => a.relevantUntil.isAfter(now))
                  .toList();
              final today = <AppAlert>[];
              final week = <AppAlert>[];
              final later = <AppAlert>[];
              for (final a in visible) {
                if (a.when.isBefore(now) || sameDay(a.when, now)) {
                  today.add(a);
                } else if (a.when
                    .isBefore(now.add(const Duration(days: 7)))) {
                  week.add(a);
                } else {
                  later.add(a);
                }
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ReminderToggle(
                    enabled: NotificationService.enabled,
                    granted: _granted,
                    onChanged: _toggle,
                    onTest: _sendTest,
                    onFixPermission: () async {
                      final g =
                          await NotificationService.requestPermission();
                      if (mounted) setState(() => _granted = g);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    const EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'You are all caught up',
                      subtitle:
                          'Reminders for upcoming tests, events and deadlines will show up here.',
                    ),
                  if (today.isNotEmpty) ...[
                    const FieldLabel('Today'),
                    ...today.map((a) => _AlertCard(alert: a, onTap: _open)),
                    const SizedBox(height: 8),
                  ],
                  if (week.isNotEmpty) ...[
                    const FieldLabel('This week'),
                    ...week.map((a) => _AlertCard(alert: a, onTap: _open)),
                    const SizedBox(height: 8),
                  ],
                  if (later.isNotEmpty) ...[
                    const FieldLabel('Later'),
                    ...later.map((a) => _AlertCard(alert: a, onTap: _open)),
                  ],
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReminderToggle extends StatelessWidget {
  final bool enabled;
  final bool granted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onFixPermission;
  final VoidCallback onTest;

  const _ReminderToggle({
    required this.enabled,
    required this.granted,
    required this.onChanged,
    required this.onFixPermission,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reminders',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text(
                      'Get a heads-up before tests, events and deadlines.',
                      style: TextStyle(fontSize: 11.5, height: 1.3),
                    ),
                  ],
                ),
              ),
              Switch(value: enabled, onChanged: onChanged),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onTest,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.notifications_active_outlined, size: 15),
              label: const Text('Send a test notification'),
            ),
          ),
          if (enabled && !granted) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: AppColors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notifications are turned off for UniShip on this device.',
                      style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                  TextButton(
                    onPressed: onFixPermission,
                    style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    child: const Text('Allow'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AppAlert alert;
  final void Function(AppAlert) onTap;
  const _AlertCard({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SurfaceCard(
        padding: const EdgeInsets.all(12),
        onTap: () => onTap(alert),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: alert.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(alert.icon, size: 19, color: alert.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${alert.subtitle} · ${alert.leadLabel} ${_until(alert.when)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _UrgencyChip(when: alert.when, color: alert.color),
          ],
        ),
      ),
    );
  }
}

class _UrgencyChip extends StatelessWidget {
  final DateTime when;
  final Color color;
  const _UrgencyChip({required this.when, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = _shortUntil(when);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

/// "Starts in 2h" — full relative phrasing for the row subtitle.
String _until(DateTime when) {
  final now = DateTime.now();
  final d = when.difference(now);
  if (d.isNegative) return 'now';
  if (d.inMinutes < 60) return 'in ${d.inMinutes}m';
  if (d.inHours < 24) return 'in ${d.inHours}h';
  if (sameDay(when, now.add(const Duration(days: 1)))) {
    return 'tomorrow at ${formatTime(when)}';
  }
  if (d.inDays < 7) return 'in ${d.inDays} days';
  return 'on ${formatDayDate(when)}';
}

/// Compact form for the urgency chip.
String _shortUntil(DateTime when) {
  final now = DateTime.now();
  final d = when.difference(now);
  if (d.isNegative) return 'NOW';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  return '${d.inDays}d';
}

/// Top-bar bell for students — boxless icon with a live unread badge,
/// mirroring [ChatAppBarButton].
class NotificationsAppBarButton extends StatelessWidget {
  final void Function(String id) onNavigate;
  const NotificationsAppBarButton({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.unseenCount,
      builder: (context, unseen, _) {
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationsScreen(onNavigate: onNavigate),
                ),
              ),
              icon: const Icon(Icons.notifications_none_rounded, size: 22),
            ),
            if (unseen > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 15),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.surface, width: 1.5),
                  ),
                  child: Text(
                    unseen > 9 ? '9+' : '$unseen',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
