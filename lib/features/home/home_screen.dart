import 'package:flutter/material.dart';
import 'widgets/home_greeting_bar.dart';
import 'widgets/health_overview_card.dart';
import 'widgets/quick_actions_grid.dart';
import 'widgets/emergency_card.dart';
import 'widgets/today_schedule_section.dart';
import 'widgets/recent_reports_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SizedBox(height: 20),
              HomeGreetingBar(),
              SizedBox(height: 20),
              HealthOverviewCard(),
              SizedBox(height: 24),
              QuickActionsGrid(),
              SizedBox(height: 20),
              EmergencyCard(),
              SizedBox(height: 24),
              TodayScheduleSection(),
              SizedBox(height: 24),
              RecentReportsSection(),
              SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
