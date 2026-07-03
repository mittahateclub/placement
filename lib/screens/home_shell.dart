import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/bottom_nav.dart';
import 'student/applications_screen.dart';
import 'student/calendar_screen.dart';
import 'student/chat_screen.dart';
import 'student/college_space_screen.dart';
import 'student/notifications_screen.dart';
import 'student/my_resumes_screen.dart';
import 'student/profile_screen.dart';
import 'student/results_screen.dart';
import 'student/resume_builder_screen.dart';
import 'student/student_dashboard.dart';
import 'superadmin/create_uniadmin_screen.dart';
import 'superadmin/manage_students_screen.dart';
import 'superadmin/manage_uniadmins_screen.dart';
import 'superadmin/superadmin_dashboard.dart';
import 'superadmin/universities_screen.dart';
import 'uniadmin/admin_profile_screen.dart';
import 'uniadmin/create_account_screen.dart';
import 'uniadmin/events_screen.dart';
import 'uniadmin/inbox_screen.dart';
import 'uniadmin/student_database_screen.dart';
import 'uniadmin/tests_screen.dart';
import 'uniadmin/uniadmin_dashboard.dart';

class AppPage {
  final String id;
  final String label;
  final IconData icon;

  /// Filled icon variant shown when selected in the bottom bar.
  final IconData? activeIcon;

  /// Compact label for the bottom bar (falls back to [label]).
  final String? shortLabel;
  final String? group;
  final Widget Function(void Function(String id) navigate) build;

  const AppPage({
    required this.id,
    required this.label,
    required this.icon,
    required this.build,
    this.activeIcon,
    this.shortLabel,
    this.group,
  });
}

/// Root scaffold after login: bottom tabs for primary destinations,
/// drawer for everything else.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.tappedPayload.addListener(_onTappedPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncReminders();
      _onTappedPayload(); // consume a notification that cold-started the app
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.tappedPayload.removeListener(_onTappedPayload);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncReminders();
      _onTappedPayload();
    }
  }

  /// Recompute + reschedule a student's reminders (and surface newly posted
  /// items). Cheap and safe to call on every app open/resume.
  void _syncReminders() {
    if (!mounted) return;
    final auth = context.read<AuthService>();
    if (auth.isStudent) NotificationService.sync(auth);
  }

  /// A tapped notification asks to open a specific tab.
  void _onTappedPayload() {
    final target = NotificationService.tappedPayload.value;
    if (target == null) return;
    NotificationService.tappedPayload.value = null;
    if (mounted && target.isNotEmpty) _navigate(target);
  }

  List<AppPage> _pagesFor(AuthService auth) {
    if (auth.isSuperAdmin) {
      return [
        AppPage(
            id: 'dashboard',
            label: 'Dashboard',
            shortLabel: 'Home',
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            build: (nav) => SuperadminDashboard(onNavigate: nav)),
        AppPage(
            id: 'universities',
            label: 'Universities',
            shortLabel: 'Unis',
            icon: Icons.account_balance_outlined,
            activeIcon: Icons.account_balance_rounded,
            build: (_) => const UniversitiesScreen()),
        AppPage(
            id: 'manage-students',
            label: 'Manage Students',
            shortLabel: 'Students',
            icon: Icons.group_outlined,
            activeIcon: Icons.group_rounded,
            build: (_) => const ManageStudentsScreen()),
        AppPage(
            id: 'create-uniadmin',
            label: 'Create Admin',
            icon: Icons.person_add_outlined,
            build: (_) => const CreateUniadminScreen()),
        AppPage(
            id: 'manage-uniadmins',
            label: 'Manage Admins',
            shortLabel: 'Admins',
            icon: Icons.manage_accounts_outlined,
            activeIcon: Icons.manage_accounts_rounded,
            build: (_) => const ManageUniadminsScreen()),
      ];
    }
    if (auth.isUniAdmin) {
      return [
        AppPage(
            id: 'dashboard',
            label: 'Dashboard',
            shortLabel: 'Home',
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            group: 'Main',
            build: (nav) => UniadminDashboard(onNavigate: nav)),
        AppPage(
            id: 'events',
            label: 'Events',
            icon: Icons.event_outlined,
            activeIcon: Icons.event_rounded,
            group: 'Manage',
            build: (_) => const EventsScreen()),
        AppPage(
            id: 'tests',
            label: 'Tests',
            icon: Icons.quiz_outlined,
            activeIcon: Icons.quiz_rounded,
            group: 'Manage',
            build: (_) => const TestsScreen()),
        AppPage(
            id: 'inbox',
            label: 'Support Inbox',
            shortLabel: 'Inbox',
            icon: Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
            group: 'Manage',
            build: (_) => const InboxScreen()),
        AppPage(
            id: 'create-account',
            label: 'Register Student',
            icon: Icons.person_add_outlined,
            group: 'Admin',
            build: (_) => const CreateAccountScreen()),
        AppPage(
            id: 'students',
            label: 'Student Database',
            shortLabel: 'Students',
            icon: Icons.group_outlined,
            activeIcon: Icons.group_rounded,
            group: 'Admin',
            build: (_) => const StudentDatabaseScreen()),
        AppPage(
            id: 'profile',
            label: 'Profile',
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            group: 'Admin',
            build: (_) => const AdminProfileScreen()),
      ];
    }
    // Student
    return [
      AppPage(
          id: 'dashboard',
          label: 'Dashboard',
          shortLabel: 'Home',
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          group: 'Main',
          build: (nav) => StudentDashboard(onNavigate: nav)),
      AppPage(
          id: 'applications',
          label: 'Applications',
          shortLabel: 'Applied',
          icon: Icons.check_circle_outline_rounded,
          activeIcon: Icons.check_circle_rounded,
          group: 'Main',
          build: (_) => const ApplicationsScreen()),
      AppPage(
          id: 'college',
          label: 'College Space',
          shortLabel: 'College',
          icon: Icons.school_outlined,
          activeIcon: Icons.school_rounded,
          group: 'Main',
          build: (nav) => CollegeSpaceScreen(onNavigate: nav)),
      AppPage(
          id: 'resume-builder',
          label: 'AI Resume Builder',
          shortLabel: 'Resume',
          icon: Icons.description_outlined,
          activeIcon: Icons.description_rounded,
          group: 'Prepare',
          build: (nav) => ResumeBuilderScreen(onNavigate: nav)),
      AppPage(
          id: 'profile',
          label: 'Profile',
          icon: Icons.person_outline_rounded,
          activeIcon: Icons.person_rounded,
          group: 'Track',
          build: (_) => const ProfileScreen()),
      AppPage(
          id: 'calendar',
          label: 'Calendar',
          icon: Icons.calendar_today_outlined,
          group: 'Main',
          build: (nav) => CalendarScreen(onNavigate: nav)),
      AppPage(
          id: 'my-resumes',
          label: 'My Resumes',
          icon: Icons.folder_outlined,
          group: 'Prepare',
          build: (nav) => MyResumesScreen(onNavigate: nav)),
      AppPage(
          id: 'results',
          label: 'Results',
          icon: Icons.bar_chart_rounded,
          group: 'Track',
          build: (_) => const ResultsScreen()),
    ];
  }

  /// Primary destinations shown in the bottom bar, in tab order.
  /// Students: Home left, College Space center, Resume on the right.
  List<String> _bottomIdsFor(AuthService auth) {
    if (auth.isSuperAdmin) {
      return ['dashboard', 'universities', 'manage-students', 'manage-uniadmins'];
    }
    if (auth.isUniAdmin) {
      return ['dashboard', 'events', 'students', 'tests', 'profile'];
    }
    return ['dashboard', 'applications', 'college', 'resume-builder', 'profile'];
  }

  void _navigate(String id) {
    setState(() => _selectedId = id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final pages = _pagesFor(auth);
    final selected = pages.firstWhere(
      (p) => p.id == _selectedId,
      orElse: () => pages.first,
    );
    final bottomPages = _bottomIdsFor(auth)
        .map((id) => pages.firstWhere((p) => p.id == id))
        .toList();

    // Drawer lists pages grouped (groups may be non-contiguous in the tab
    // ordering above), preserving relative order within each group.
    final drawerPages = <AppPage>[
      ...pages.where((p) => p.group == null),
      for (final group in const ['Main', 'Prepare', 'Track', 'Manage', 'Admin'])
        ...pages.where((p) => p.group == group),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(selected.label),
        actions: [
          if (auth.isStudent)
            NotificationsAppBarButton(onNavigate: _navigate),
          if (auth.isStudent) const ChatAppBarButton(),
          if (auth.isUniAdmin)
            InboxAppBarButton(onOpen: () => _navigate('inbox')),
          const SizedBox(width: 4),
        ],
      ),
      drawer: AppDrawer(
        pages: drawerPages,
        selectedId: selected.id,
        onSelect: (id) {
          Navigator.pop(context); // close drawer
          _navigate(id);
        },
      ),
      drawerEdgeDragWidth: 64,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: const Cubic(0.16, 1, 0.3, 1),
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.015),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(selected.id),
            child: selected.build(_navigate),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        pages: bottomPages,
        selectedId: selected.id,
        onSelect: _navigate,
      ),
    );
  }
}
