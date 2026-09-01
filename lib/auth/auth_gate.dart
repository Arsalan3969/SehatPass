import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app/app_shell.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../features/auth/login_screen.dart';
import '../features/doctor/doctor_shell_screen.dart';
import '../services/auth_service.dart';
import '../features/auth/reset_password_screen.dart';
import '../shared/widgets/app_card.dart';

class AuthGate extends StatefulWidget {
  final Stream<AuthState>? authStateStream;
  final bool? initialRecoveryMode;

  const AuthGate({
    super.key,
    this.authStateStream,
    this.initialRecoveryMode,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Key _roleFutureKey = UniqueKey();
  bool _isRecoveryMode = false;

  @override
  void initState() {
    super.initState();
    _isRecoveryMode = widget.initialRecoveryMode ?? false;
  }

  void _retryRoleFetch() {
    setState(() {
      _roleFutureKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: widget.authStateStream ?? AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final event = snapshot.data!.event;
          if (event == AuthChangeEvent.passwordRecovery) {
            _isRecoveryMode = true;
          } else if (event == AuthChangeEvent.signedOut) {
            _isRecoveryMode = false;
          }
        }

        final session = snapshot.hasData
            ? snapshot.data!.session
            : AuthService.instance.currentSession;

        if (session == null || session.user.id.isEmpty) {
          _isRecoveryMode = false;
          return const LoginScreen();
        }

        if (_isRecoveryMode) {
          return ResetPasswordScreen(
            onContinueToLogin: () async {
              await AuthService.instance.signOut();
              if (mounted) {
                setState(() {
                  _isRecoveryMode = false;
                });
              }
            },
          );
        }

        final userId = session.user.id;

        return FutureBuilder<String?>(
          key: ValueKey('${userId}_$_roleFutureKey'),
          future: AuthService.instance.getUserProfileRole(userId),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen();
            }

            if (roleSnapshot.hasError || !roleSnapshot.hasData) {
              return _buildRoleErrorScreen(
                errorMessage: 'Unable to retrieve user profile from the database.',
              );
            }

            final role = roleSnapshot.data;

            if (role == 'patient') {
              return const AppShell();
            } else if (role == 'doctor') {
              return const DoctorShellScreen();
            } else {
              return _buildRoleErrorScreen(
                errorMessage:
                    'Invalid account role configured. Please contact support.',
              );
            }
          },
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_hospital_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading SehatPass...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleErrorScreen({required String errorMessage}) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.emergencySurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.emergencyBorder),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.emergency,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Account Resolution Error',
                      style: AppTextStyles.headingSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage,
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _retryRoleFetch,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'Retry Connection',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await AuthService.instance.signOut();
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.emergency,
                          side: const BorderSide(color: AppColors.emergencyBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
