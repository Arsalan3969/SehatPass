import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/doctor_onboarding_data.dart';
import '../data/doctor_repository.dart';
import 'widgets/onboarding_progress_bar.dart';
import 'steps/doctor_profile_step.dart';
import 'steps/list_clinic_step.dart';
import 'steps/add_services_step.dart';
import 'steps/set_availability_step.dart';
import 'steps/preview_clinic_step.dart';
import 'publish_success_screen.dart';

class DoctorOnboardingScreen extends StatefulWidget {
  const DoctorOnboardingScreen({super.key});

  @override
  State<DoctorOnboardingScreen> createState() => _DoctorOnboardingScreenState();
}

class _DoctorOnboardingScreenState extends State<DoctorOnboardingScreen> {
  int _currentStep = 1;
  final int _totalSteps = 5;
  bool _isLoading = true;
  bool _isPublishing = false;
  DoctorOnboardingData _data = DoctorOnboardingData();

  @override
  void initState() {
    super.initState();
    _loadExistingState();
  }

  Future<void> _loadExistingState() async {
    try {
      final existing =
          await DoctorRepository.instance.loadExistingOnboardingData();
      if (mounted) {
        setState(() {
          _data = existing;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('DoctorOnboardingScreen: Error loading initial data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      _confirmExit();
    }
  }

  void _goToStep(int step) {
    if (step >= 1 && step <= _totalSteps) {
      setState(() => _currentStep = step);
    }
  }

  void _confirmExit() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: const Text('Exit Setup?', style: AppTextStyles.headingSmall),
        content: const Text(
          'Your onboarding progress will not be saved if you leave now.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Continue Setup'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.emergency,
            ),
            child: const Text(
              'Exit',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showPublishConfirmation() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Publish Clinic?',
              style: AppTextStyles.headingSmall,
            ),
          ],
        ),
        content: const Text(
          'Once published, patients will be able to find your clinic and view your available services.',
          style: AppTextStyles.bodyMedium,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handlePublish();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Publish',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handlePublish() async {
    setState(() => _isPublishing = true);

    try {
      final publishedData =
          await DoctorRepository.instance.publishDoctorProfile(data: _data);

      if (!mounted) return;
      setState(() {
        _isPublishing = false;
        _data = publishedData;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PublishSuccessScreen(data: publishedData),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPublishing = false);
      _showErrorDialog(e.toString());
    }
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppColors.emergency, size: 24),
            SizedBox(width: 10),
            Text('Publish Failed', style: AppTextStyles.headingSmall),
          ],
        ),
        content: Text(
          message,
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child:
                const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return DoctorProfileStep(
          initialData: _data.profile,
          onNext: (updated) {
            _data.profile = updated;
            _nextStep();
          },
        );
      case 2:
        return ListClinicStep(
          initialData: _data.clinic,
          onNext: (updated) {
            _data.clinic = updated;
            _nextStep();
          },
        );
      case 3:
        return AddServicesStep(
          initialServices: _data.services,
          onNext: (updated) {
            _data.services = updated;
            _nextStep();
          },
        );
      case 4:
        return SetAvailabilityStep(
          initialData: _data.availability,
          onNext: (updated) {
            _data.availability = updated;
            _nextStep();
          },
        );
      case 5:
        return PreviewClinicStep(
          data: _data,
          onEdit: () => _goToStep(1),
          onPublish: _showPublishConfirmation,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_isPublishing) {
          _prevStep();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
            onPressed: _isPublishing ? null : _prevStep,
          ),
          title: Text(
            'Doctor Onboarding',
            style: AppTextStyles.headingMedium.copyWith(fontSize: 17),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.textSecondary),
              tooltip: 'Exit Setup',
              onPressed: _isPublishing ? null : _confirmExit,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: OnboardingProgressBar(
              currentStep: _currentStep,
              totalSteps: _totalSteps,
            ),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              else
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_currentStep),
                    child: _buildCurrentStep(),
                  ),
                ),
              if (_isPublishing)
                Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 22),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x20000000),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Publishing Clinic...',
                            style: AppTextStyles.labelLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

