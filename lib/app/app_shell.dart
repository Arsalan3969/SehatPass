import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../features/home/home_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/medicines/medicines_screen.dart';
import '../features/medicines/data/medicine_repository.dart';
import '../features/sehat_ai/sehat_ai_screen.dart';
import '../features/profile/profile_screen.dart';
import '../core/theme/app_colors.dart';
import '../services/notification_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// Global tab notifier to allow any screen to programmatically switch bottom tabs.
  static final ValueNotifier<int> tabNotifier = ValueNotifier<int>(0);

  static void switchTab(int index) {
    if (index >= 0 && index <= 4) {
      tabNotifier.value = index;
    }
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  StreamSubscription<String?>? _notificationTapSubscription;

  static const List<Widget> _screens = [
    HomeScreen(),
    ReportsScreen(),
    MedicinesScreen(),
    SehatAiScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = AppShell.tabNotifier.value;
    AppShell.tabNotifier.addListener(_onTabChange);
    _listenToNotificationTaps();
    _syncMedicineReminders();
  }

  void _listenToNotificationTaps() {
    _notificationTapSubscription =
        NotificationService.instance.onNotificationTap.listen((payload) {
      if (payload != null && payload.contains('medicine_reminder')) {
        AppShell.switchTab(2);
      }
    });
  }

  Future<void> _syncMedicineReminders() async {
    try {
      final medicines = await MedicineRepository.instance.getActiveMedicines();
      await NotificationService.instance.syncMedicineReminders(medicines);
    } catch (e) {
      debugPrint('AppShell: startup sync of medicine reminders notice: $e');
    }
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    AppShell.tabNotifier.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    if (mounted && _currentIndex != AppShell.tabNotifier.value) {
      setState(() {
        _currentIndex = AppShell.tabNotifier.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            AppShell.switchTab(index);
          },
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 68,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description_rounded),
              label: 'Reports',
            ),
            NavigationDestination(
              icon: Icon(Icons.medication_outlined),
              selectedIcon: Icon(Icons.medication_rounded),
              label: 'Medicines',
            ),
            NavigationDestination(
              icon: Icon(Icons.smart_toy_outlined),
              selectedIcon: Icon(Icons.smart_toy_rounded),
              label: 'Sehat AI',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
