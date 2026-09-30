import 'package:flutter/material.dart';
import 'package:washbinapp/core/theme/app_theme.dart';
import 'package:washbinapp/features/bookings/screens/bookings_screen.dart';
import 'package:washbinapp/features/catalogue/screens/home_screen.dart';
import 'package:washbinapp/features/catalogue/screens/service_list_screen.dart';
import 'package:washbinapp/features/profile/screens/profile_screen.dart';

/// The signed-in app: browse, book, and look at what you have booked.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// The Bookings tab is kept alive by the IndexedStack below, so it is told
  /// to reload when the customer opens it — otherwise a booking made moments
  /// earlier would be missing from a list built before it existed.
  final _bookingsKey = GlobalKey<BookingsScreenState>();

  static const _bookingsTab = 2;

  void _select(int index) {
    setState(() => _index = index);

    if (index == _bookingsTab) {
      _bookingsKey.currentState?.refresh();
    }
  }

  static const _tabs = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined, color: Color(0xFF6F737A)),
      selectedIcon: Icon(Icons.home_rounded, color: AppTheme.ink),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.home_repair_service_outlined, color: Color(0xFF6F737A)),
      selectedIcon: Icon(
        Icons.home_repair_service_rounded,
        color: AppTheme.ink,
      ),
      label: 'Services',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined, color: Color(0xFF6F737A)),
      selectedIcon: Icon(Icons.receipt_long_rounded, color: AppTheme.ink),
      label: 'Bookings',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded, color: Color(0xFF6F737A)),
      selectedIcon: Icon(Icons.person_rounded, color: AppTheme.ink),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        // IndexedStack rather than a swap, so a tab keeps its scroll position
        // and any in-flight request when the customer moves away and back.
        child: IndexedStack(
          index: _index,
          children: [
            const HomeScreen(),
            const ServiceListScreen(),
            BookingsScreen(key: _bookingsKey),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.washbinYellow.withValues(alpha: 0.24),
        surfaceTintColor: Colors.white,
        shadowColor: AppTheme.black.withValues(alpha: 0.16),
        elevation: 12,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppTheme.ink : const Color(0xFF6F737A),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0,
          );
        }),
        destinations: _tabs,
      ),
    );
  }
}
