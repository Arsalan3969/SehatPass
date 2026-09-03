import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app/app_shell.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/doctor/data/doctor_repository.dart';
import '../features/doctor/doctor_shell_screen.dart';
import '../features/doctor/onboarding/doctor_onboarding_screen.dart';
import '../services/auth_service.dart';
import '../shared/widgets/app_card.dart';

/// Resolved routing destinations for authenticated users.
enum AuthTarget {
  patient,
  doctorOnboarding,
  doctorShell,
}

class AuthGate extends StatefulWidget {
  final Stream<AuthState>? authStateStream;
  final bool? initialRecoveryMode;
  final AuthService? authService;
  final DoctorRepository? doctorRepository;
  final Future<String?> Function(String userId)? roleResolver;
  final Future<bool> Function(String doctorId)? doctorPublishedResolver;

  const AuthGate({
    super.key,
    this.authStateStream,
    this.initialRecoveryMode,
    this.authService,
    this.doctorRepository,
    this.roleResolver,
    this.doctorPublishedResolver,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Key _resolutionFutureKey = UniqueKey();
  bool _isRecoveryMode = false;

  @override
  void initState() {
    super.initState();
    _isRecoveryMode = widget.initialRecoveryMode ?? false;
  }

  void _retryResolution() {
    setState(() {
      _resolutionFutureKey = UniqueKey();
    });
  }

  Future<AuthTarget> _resolveDestination(String userId) async {
    // 1. Authoritatively resolve user role from public.profiles
    final String? role;
    if (widget.roleResolver != null) {
      role = await widget.roleResolver!(userId);
    } else {
      final auth = widget.authService ?? AuthService.instance;
      role = await auth.getUserProfileRole(userId);
    }

    if (role == null) {
      throw 'Unable to retrieve user profile from the database.';
    }

    if (role == 'patient') {
      return AuthTarget.patient;
    } else if (role == 'doctor') {
      // 2. Query public.doctor_profiles via DoctorRepository
      final bool isPublished;
      if (widget.doctorPublishedResolver != null) {
        isPublished = await widget.doctorPublishedResolver!(userId);
      } else {
        final docRepo = widget.doctorRepository ?? DoctorRepository.instance;
        isPublished = await docRepo.isDoctorProfilePublished(doctorId: userId);
      }

      if (isPublished) {
        return AuthTarget.doctorShell;
      } else {
        return AuthTarget.doctorOnboarding;
      }
    } else {
      throw 'Invalid account role configured. Please contact support.';
    }
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

        return FutureBuilder<AuthTarget>(
          key: ValueKey('${userId}_$_resolutionFutureKey'),
          future: _resolveDestination(userId),
          builder: (context, targetSnapshot) {
            if (targetSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen();
            }

            if (targetSnapshot.hasError || !targetSnapshot.hasData) {
              final errorMsg = targetSnapshot.hasError
                  ? targetSnapshot.error.toString().replaceFirst('Exception: ', '')
                  : 'Unable to retrieve user profile from the database.';
              return _buildRoleErrorScreen(
                errorMessage: errorMsg,
              );
            }

            final target = targetSnapshot.data!;

            switch (target) {
              case AuthTarget.patient:
                return const AppShell();
              case AuthTarget.doctorOnboarding:
                return const DoctorOnboardingScreen();
              case AuthTarget.doctorShell:
                return const DoctorShellScreen();
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
                        onPressed: _retryResolution,
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
