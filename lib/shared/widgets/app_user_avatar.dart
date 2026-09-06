import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/image_upload_service.dart';

/// Centralized, high-performance Avatar widget that automatically handles
/// private Supabase Storage paths, signed URL resolution, in-memory caching,
/// loading states, and graceful fallback to initials or icons.
class AppUserAvatar extends StatelessWidget {
  final String? imageUrlOrPath;
  final String? name;
  final double size;
  final double? borderRadius;
  final bool isCircle;
  final IconData fallbackIcon;
  final Color? backgroundColor;
  final Color? textColor;
  final BoxBorder? border;

  const AppUserAvatar({
    super.key,
    this.imageUrlOrPath,
    this.name,
    this.size = 48,
    this.borderRadius,
    this.isCircle = true,
    this.fallbackIcon = Icons.person_rounded,
    this.backgroundColor,
    this.textColor,
    this.border,
  });

  String _getInitial() {
    if (name == null || name!.trim().isEmpty) return '';
    final trimmed = name!.trim();
    // Remove "Dr." or "Dr " prefix for cleaner initial if desired, or use first char
    if (trimmed.toLowerCase().startsWith('dr. ') && trimmed.length > 4) {
      return trimmed[4].toUpperCase();
    }
    if (trimmed.toLowerCase().startsWith('dr ') && trimmed.length > 3) {
      return trimmed[3].toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = isCircle ? size / 2 : (borderRadius ?? 12.0);
    final bgColor = backgroundColor ?? AppColors.primarySurface;
    final fgColor = textColor ?? AppColors.primary;
    final initial = _getInitial();

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(effectiveRadius),
          border: border,
        ),
        child: Center(
          child: initial.isNotEmpty
              ? Text(
                  initial,
                  style: TextStyle(
                    color: fgColor,
                    fontWeight: FontWeight.w700,
                    fontSize: size * 0.4,
                  ),
                )
              : Icon(
                  fallbackIcon,
                  size: size * 0.5,
                  color: fgColor,
                ),
        ),
      );
    }

    final rawPath = imageUrlOrPath?.trim();
    if (rawPath == null || rawPath.isEmpty) {
      return fallback();
    }

    // Check synchronous cache first
    final cached = ImageUploadService.getCachedUrl(rawPath);
    if (cached != null) {
      return _buildImage(cached, effectiveRadius, fallback);
    }

    // Resolve asynchronously
    return FutureBuilder<String?>(
      future: ImageUploadService.instance.resolveImageUrl(rawPath),
      builder: (context, snapshot) {
        final resolvedUrl = snapshot.data;
        if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
          return _buildImage(resolvedUrl, effectiveRadius, fallback);
        }
        return fallback();
      },
    );
  }

  Widget _buildImage(String url, double radius, Widget Function() fallbackBuilder) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primarySurface,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(radius),
        border: border,
      ),
      child: ClipRRect(
        borderRadius: isCircle
            ? BorderRadius.circular(size / 2)
            : BorderRadius.circular(radius),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallbackBuilder(),
        ),
      ),
    );
  }
}
