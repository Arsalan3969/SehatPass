import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Available actions from the image picker bottom sheet.
enum ImagePickerResultAction {
  camera,
  gallery,
  remove,
}

/// Centralized service for selecting, compressing, and uploading profile & clinic images.
class ImageUploadService {
  final ImagePicker _picker;
  final SupabaseClient? _clientOverride;

  ImageUploadService({
    ImagePicker? picker,
    SupabaseClient? client,
  })  : _picker = picker ?? ImagePicker(),
        _clientOverride = client;

  static final ImageUploadService instance = ImageUploadService();

  SupabaseClient get _client {
    final override = _clientOverride;
    if (override != null) return override;
    return Supabase.instance.client;
  }

  /// In-memory cache for resolved signed URLs to prevent repeated network calls on widget rebuilds.
  static final Map<String, String> _urlCache = {};

  /// Displays a styled bottom sheet prompting the user to select Camera, Gallery, or Remove.
  Future<ImagePickerResultAction?> showImagePickerSheet(
    BuildContext context, {
    bool hasExistingImage = false,
  }) async {
    return showModalBottomSheet<ImagePickerResultAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select Image',
                    style: AppTextStyles.headingSmall.copyWith(fontSize: 16),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Take Photo',
                  style: AppTextStyles.labelLarge,
                ),
                onTap: () => Navigator.pop(ctx, ImagePickerResultAction.camera),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: AppTextStyles.labelLarge,
                ),
                onTap: () => Navigator.pop(ctx, ImagePickerResultAction.gallery),
              ),
              if (hasExistingImage) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.emergencySurface,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.emergency,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Remove Photo',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.emergency,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, ImagePickerResultAction.remove),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Picks and compresses an image from the given source.
  /// Returns `null` if the user cancels the picker.
  Future<XFile?> pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return file;
    } on PlatformException catch (e) {
      debugPrint('ImageUploadService: PlatformException picking image: $e');
      if (e.code == 'camera_access_denied' ||
          e.message?.toLowerCase().contains('permission') == true) {
        throw 'Camera/Photo access was denied. Please grant permission in Settings.';
      }
      throw 'Unable to access camera or photo library.';
    } catch (e) {
      debugPrint('ImageUploadService: Error picking image: $e');
      throw 'Failed to pick image. Please try again.';
    }
  }

  /// Uploads binary image bytes to the `profile-images` bucket under `<user_id>/<prefix>_<timestamp>.jpg`.
  /// Returns the relative storage path (e.g. `userId/avatar_12345.jpg`).
  Future<String> uploadImage({
    required Uint8List imageBytes,
    required String fileNamePrefix,
    String? userIdOverride,
  }) async {
    final uid = userIdOverride ?? _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw 'Authentication required to upload images.';
    }

    final sanitizedPrefix = fileNamePrefix.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final storagePath = '$uid/${sanitizedPrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      await _client.storage.from('profile-images').uploadBinary(
            storagePath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return storagePath;
    } catch (e) {
      debugPrint('ImageUploadService: Error uploading image: $e');
      throw 'Unable to upload image. Please check your network connection and try again.';
    }
  }

  /// Resolves a storage path or URL into a viewable signed URL.
  /// If [pathOrUrl] is null or empty, returns null.
  /// If it is already an http(s) URL, returns it directly.
  Future<String?> resolveImageUrl(
    String? pathOrUrl, {
    int expiresInSeconds = 604800, // 7 days
  }) async {
    if (pathOrUrl == null || pathOrUrl.trim().isEmpty) return null;
    final trimmed = pathOrUrl.trim();

    // Already an absolute HTTP URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // Check memory cache
    if (_urlCache.containsKey(trimmed)) {
      return _urlCache[trimmed];
    }

    try {
      final signedUrl = await _client.storage
          .from('profile-images')
          .createSignedUrl(trimmed, expiresInSeconds);

      _urlCache[trimmed] = signedUrl;
      return signedUrl;
    } catch (e) {
      debugPrint('ImageUploadService: Error generating signed URL for $trimmed: $e');
      // Fallback: try public URL
      try {
        final publicUrl = _client.storage.from('profile-images').getPublicUrl(trimmed);
        if (publicUrl.isNotEmpty) {
          _urlCache[trimmed] = publicUrl;
          return publicUrl;
        }
      } catch (_) {}
      return null;
    }
  }

  /// Retrieves a cached signed URL synchronously if previously resolved.
  static String? getCachedUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.trim().isEmpty) return null;
    final trimmed = pathOrUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return _urlCache[trimmed];
  }

  /// Clears the signed URL cache (e.g. upon logout or image replacement).
  static void clearCache() {
    _urlCache.clear();
  }
}
