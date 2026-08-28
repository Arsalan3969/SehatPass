import 'package:flutter/material.dart';
import 'app/app_shell.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const SehatPassApp());
}

class SehatPassApp extends StatelessWidget {
  const SehatPassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SehatPass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppShell(),
    );
  }
}
