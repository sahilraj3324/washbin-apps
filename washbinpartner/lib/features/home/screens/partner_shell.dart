import 'package:flutter/material.dart';
import 'package:washbinpartner/app/app_services_scope.dart';
import 'package:washbinpartner/core/theme/app_theme.dart';
import 'package:washbinpartner/features/bookings/screens/bookings_screen.dart';
import 'package:washbinpartner/features/home/screens/home_screen.dart';
import 'package:washbinpartner/features/jobs/screens/jobs_screen.dart';
import 'package:washbinpartner/features/notifications/screens/notifications_screen.dart';
import 'package:washbinpartner/features/profile/screens/profile_screen.dart';

/// The approved partner's app: the four places the product needs, wired up
/// now so later phases fill a tab rather than restructure navigation.
///
/// Only Home and Profile do anything in Phase 1. Jobs and Bookings are here
/// because moving a tab later moves every partner's muscle memory with it.
class PartnerShell extends StatefulWidget {
  const PartnerShell({super.key});

  @override
  State<PartnerShell> createState() => _PartnerShellState();
}

class _PartnerShellState extends State<PartnerShell> {
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AppServicesScope.of(context).push.onOpenJob = (_) {
      if (mounted) {
        setState(() => _index = 1);
      }
    };
    AppServicesScope.of(context).push.onForeground = (payload) {
      if (!mounted) {
        return;
      }
      final title = payload.title ?? 'Washbin update';
      final body = payload.body ?? 'Open Jobs for the latest status.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$title\n$body')));
    };
  }

  static const _tabs = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.work_outline_rounded),
      selectedIcon: Icon(Icons.work_rounded),
      label: 'Jobs',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long_rounded),
      label: 'Bookings',
    ),
    NavigationDestination(
      icon: Icon(Icons.notifications_outlined),
      selectedIcon: Icon(Icons.notifications_rounded),
      label: 'Alerts',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        // IndexedStack rather than a swap, so a tab keeps its scroll position
        // and any in-flight request when the partner moves away and back.
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(
              onOpenJobs: () => setState(() => _index = 1),
              onOpenProfile: () => setState(() => _index = 4),
            ),
            const JobsScreen(),
            const BookingsScreen(),
            NotificationsScreen(onOpenJob: () => setState(() => _index = 1)),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: _tabs,
      ),
    );
  }
}
