import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/doctor/models/clinic_model.dart';
import 'package:sehatpass/features/doctor/models/doctor_onboarding_data.dart';
import 'package:sehatpass/features/doctor/models/doctor_profile_model.dart';
import 'package:sehatpass/features/doctor/onboarding/steps/doctor_profile_step.dart';
import 'package:sehatpass/features/doctor/onboarding/steps/list_clinic_step.dart';
import 'package:sehatpass/features/doctor/profile/doctor_profile_screen.dart';
import 'package:sehatpass/features/profile/widgets/profile_header.dart';
import 'package:sehatpass/services/image_upload_service.dart';

void main() {
  group('A. ImageUploadService Unit Tests', () {
    test('ImagePickerResultAction enum has expected values', () {
      expect(ImagePickerResultAction.values, contains(ImagePickerResultAction.camera));
      expect(ImagePickerResultAction.values, contains(ImagePickerResultAction.gallery));
      expect(ImagePickerResultAction.values, contains(ImagePickerResultAction.remove));
    });

    test('resolveImageUrl returns direct absolute HTTP/HTTPS URLs without storage call', () async {
      final service = ImageUploadService();
      const httpUrl = 'https://images.example.com/avatar123.jpg';
      final resolved = await service.resolveImageUrl(httpUrl);
      expect(resolved, equals(httpUrl));

      const emptyUrl = '';
      final resolvedEmpty = await service.resolveImageUrl(emptyUrl);
      expect(resolvedEmpty, isNull);

      final resolvedNull = await service.resolveImageUrl(null);
      expect(resolvedNull, isNull);
    });

    test('clearCache clears internal memory cache without error', () {
      expect(() => ImageUploadService.clearCache(), returnsNormally);
    });
  });

  group('B. ProfileHeader Widget Tests', () {
    testWidgets('renders avatar with camera icon and triggers onAvatarTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ProfileHeader(
              name: 'Ali Khan',
              email: 'ali@example.com',
              onAvatarTap: () => tapped = true,
              onEditProfile: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ali Khan'), findsOneWidget);
      expect(find.text('ali@example.com'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);

      // Tap avatar camera icon
      await tester.tap(find.byIcon(Icons.camera_alt_rounded));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('shows loading spinner when isUploadingAvatar is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ProfileHeader(
              name: 'Ali Khan',
              email: 'ali@example.com',
              isUploadingAvatar: true,
              onEditProfile: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('C. DoctorProfileStep Widget Tests', () {
    testWidgets('renders profile photo selector and form inputs', (tester) async {
      final initial = DoctorProfileModel(
        fullName: 'Dr. Sara Khan',
        specialization: 'Cardiologist',
        qualifications: 'MBBS, FCPS',
        experienceYears: '8 years',
        bio: 'Heart specialist.',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DoctorProfileStep(
              initialData: initial,
              onNext: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set Up Your Doctor Profile'), findsOneWidget);
      expect(find.text('Add Photo'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.text('Dr. Sara Khan'), findsOneWidget);
      expect(find.text('Cardiologist'), findsOneWidget);
    });
  });

  group('D. ListClinicStep Widget Tests', () {
    testWidgets('renders clinic photo upload container and form inputs', (tester) async {
      final initial = ClinicModel(
        name: 'Sara Heart Care',
        address: '123 Main Road',
        city: 'Lahore',
        phone: '03001234567',
        description: 'Comprehensive cardiology services.',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListClinicStep(
              initialData: initial,
              onNext: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('List Your Clinic'), findsOneWidget);
      expect(find.text('Upload Clinic Logo or Photo'), findsOneWidget);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
      expect(find.text('Sara Heart Care'), findsOneWidget);
    });
  });

  group('E. DoctorProfileScreen Avatar Tests', () {
    testWidgets('renders doctor bio card with interactive avatar camera badge', (tester) async {
      final data = DoctorOnboardingData(
        profile: DoctorProfileModel(
          doctorId: 'doc-123',
          fullName: 'Dr. Usman Tariq',
          specialization: 'Neurologist',
          qualifications: 'MBBS, MD',
          experienceYears: '10 years',
          bio: 'Specialist in neurology.',
          isPublished: true,
        ),
        clinic: ClinicModel(
          name: 'Neuro Clinic',
          address: '45 Gulberg',
          city: 'Lahore',
          phone: '03112223334',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: DoctorProfileScreen(
            data: data,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dr. Usman Tariq'), findsOneWidget);
      expect(find.text('Neurologist'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });
  });
}
