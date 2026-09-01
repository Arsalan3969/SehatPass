import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import 'data/emergency_repository.dart';
import 'emergency_info_preview_screen.dart';
import 'manage_emergency_info_screen.dart';
import 'models/emergency_info_model.dart';

class EmergencyQrScreen extends StatefulWidget {
  final EmergencyRepository? repository;

  const EmergencyQrScreen({super.key, this.repository});

  @override
  State<EmergencyQrScreen> createState() => _EmergencyQrScreenState();
}

class _EmergencyQrScreenState extends State<EmergencyQrScreen> {
  EmergencyRepository get _repo =>
      widget.repository ?? EmergencyRepository.instance;

  EmergencyInfoData _data = const EmergencyInfoData();
  bool _isLoading = true;
  bool _isRegenerating = false;
  bool _isTogglingStatus = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final info = await _repo.getEmergencyInfo();
      if (!mounted) return;
      setState(() {
        _data = info;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is String
            ? e
            : 'Unable to load emergency information. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _onToggleActiveStatus(bool active) async {
    if (_isTogglingStatus) return;
    setState(() => _isTogglingStatus = true);

    try {
      await _repo.setEmergencyAccessActive(active);
      if (!mounted) return;
      setState(() {
        _data = _data.copyWith(isActive: active);
        _isTogglingStatus = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active
                ? 'Emergency QR access is now ACTIVE.'
                : 'Emergency QR access has been DISABLED.',
          ),
          backgroundColor: active ? AppColors.primary : AppColors.textSecondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTogglingStatus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is String ? e : 'Unable to update status.'),
          backgroundColor: AppColors.emergency,
        ),
      );
    }
  }

  Future<void> _onRegenerateToken() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: AppColors.emergency,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Reset Emergency QR',
              style: AppTextStyles.headingSmall,
            ),
          ],
        ),
        content: const Text(
          'Regenerating your QR token will immediately invalidate any existing printed or shared QR codes. Do you want to proceed?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Reset QR'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isRegenerating = true);
    try {
      final newToken = await _repo.regenerateEmergencyToken();
      if (!mounted) return;
      setState(() {
        _data = _data.copyWith(identifier: newToken);
        _isRegenerating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'New Emergency QR generated. Previous code invalidated.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRegenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is String ? e : 'Unable to reset QR code.'),
          backgroundColor: AppColors.emergency,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onCopyPublicUrl() {
    final url = _repo.buildEmergencyAccessUrl(_data.identifier);
    if (url.isEmpty) return;

    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.content_copy_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Public Emergency URL copied! Test it in any browser.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _onManageInfo() async {
    final result = await Navigator.push<EmergencyInfoData>(
      context,
      MaterialPageRoute(
        builder: (_) => ManageEmergencyInfoScreen(
          repository: _repo,
          initialData: _data,
        ),
      ),
    );

    if (result != null) {
      setState(() => _data = result);
    } else {
      _loadData();
    }
  }

  Future<void> _onPreviewEmergencyInfo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmergencyInfoPreviewScreen(
          repository: _repo,
          initialData: _data,
        ),
      ),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Emergency QR'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            tooltip: 'Regenerate QR Token',
            onPressed:
                _isRegenerating || _isLoading ? null : _onRegenerateToken,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
            tooltip: 'Manage Information',
            onPressed: _isLoading ? null : _onManageInfo,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: _isLoading
                ? _buildLoadingView()
                : _errorMessage != null
                    ? _buildErrorView()
                    : _buildContentView(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Center(
          child: CircularProgressIndicator(color: AppColors.emergency),
        ),
        const SizedBox(height: 16),
        Text(
          'Loading your secure Emergency QR...',
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.emergency),
            const SizedBox(height: 14),
            Text(
              'Unable to Load Emergency Data',
              style: AppTextStyles.headingSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Something went wrong.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentView() {
    final isTokenValid = _data.identifier.isNotEmpty;
    final publicEmergencyUrl = _repo.buildEmergencyAccessUrl(_data.identifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Emergency Header Banner ──────────────────────────────
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.emergencySurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.emergencyBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: AppColors.emergency,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Emergency QR Access',
                          style: AppTextStyles.headingSmall.copyWith(
                            color: AppColors.emergency,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('🚨', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Responders scanning this QR get instant access to your emergency medical summary via secure HTTPS without needing to login.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: const Color(0xFF991B1B),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Incomplete Info Warning (if needed) ──────────────────
        if (!_data.isComplete) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Emergency information is incomplete',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Add your blood group, allergies, and emergency contact for responder safety.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB45309),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _onManageInfo,
                        child: const Text(
                          'Complete Information →',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // ── QR Code Card ─────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // QR Widget - Encodes only the secure HTTPS emergency URL
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _data.isActive
                        ? AppColors.border
                        : AppColors.emergencyBorder,
                    width: _data.isActive ? 1 : 2,
                  ),
                ),
                child: isTokenValid
                    ? Opacity(
                        opacity: _data.isActive ? 1.0 : 0.4,
                        child: QrImageView(
                          data: publicEmergencyUrl,
                          version: QrVersions.auto,
                          size: 210.0,
                          backgroundColor: Colors.white,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: _data.isActive
                                ? Colors.black
                                : AppColors.textTertiary,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: _data.isActive
                                ? Colors.black
                                : AppColors.textTertiary,
                          ),
                        ),
                      )
                    : const SizedBox(
                        height: 210,
                        width: 210,
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.emergency),
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Patient Name
              Text(
                _data.fullName.isNotEmpty ? _data.fullName : 'Patient Profile',
                style: AppTextStyles.headingSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),

              // Status Chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _data.isActive
                      ? AppColors.primarySurface
                      : AppColors.emergencySurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _data.isActive
                        ? const Color(0xFFA7D9C0)
                        : AppColors.emergencyBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _data.isActive
                            ? AppColors.primary
                            : AppColors.emergency,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _data.isActive
                          ? 'Emergency Access: ACTIVE'
                          : 'Emergency Access: DISABLED',
                      style: AppTextStyles.caption.copyWith(
                        color: _data.isActive
                            ? AppColors.primary
                            : AppColors.emergency,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Token: ${_data.identifier.isNotEmpty ? _data.identifier : "Generating..."}',
                  style: AppTextStyles.caption.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Active Toggle & Security Controls Card ───────────────
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Allow Emergency Scans',
                          style: AppTextStyles.labelLarge.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'When disabled, scanned QR will show access disabled.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _data.isActive,
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: Colors.white,
                    onChanged: _isTogglingStatus
                        ? null
                        : (val) => _onToggleActiveStatus(val),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppColors.border),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _onCopyPublicUrl,
                      icon: const Icon(Icons.link_rounded, size: 16),
                      label: const Text('Copy Web Link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isRegenerating ? null : _onRegenerateToken,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset Token'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.emergency,
                        side: const BorderSide(color: AppColors.emergencyBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Privacy Guarantee Note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.security_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Privacy Protected: This QR code encodes only a secure HTTPS token. Your patient UUID, email, and unshared medical data are never encoded in the QR or publicly exposed.',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Secondary Action: Preview Emergency Information ──────
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _onPreviewEmergencyInfo,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('Preview Responder View'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Manage Emergency Information Tile ────────────────────
        AppCard(
          onTap: _onManageInfo,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage Emergency Information',
                      style: AppTextStyles.labelLarge.copyWith(
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Edit emergency contact & sharing preferences',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}
