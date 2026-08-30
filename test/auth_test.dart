import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/auth/login_screen.dart';
import 'package:sehatpass/features/auth/signup_screen.dart';
import 'package:sehatpass/features/auth/forgot_password_screen.dart';

import 'package:sehatpass/services/auth_service.dart';

void main() {
  group('AuthService Tests', () {
    test('authCallbackUrl is configured to sehatpass://auth-callback', () {
      expect(AuthService.authCallbackUrl, 'sehatpass://auth-callback');
    });
  });

  group('LoginScreen Tests', () {
    testWidgets('Renders all LoginScreen elements properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Branding and titles
      expect(find.text('Welcome to SehatPass'), findsOneWidget);
      expect(find.text('Sign in to access your healthcare portal'),
          findsOneWidget);

      // Form fields
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Resend verification email'), findsOneWidget);
      expect(find.text("Don't have an account? "), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('Tapping Resend verification email opens prompt dialog if email empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final resendBtn = find.text('Resend verification email');
      await tester.ensureVisible(resendBtn);
      await tester.tap(resendBtn);
      await tester.pumpAndSettle();

      expect(find.text('Resend Verification'), findsOneWidget);
      expect(find.text('Resend Link'), findsOneWidget);
    });

    testWidgets('LoginScreen validation shows errors on empty submit',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap login without typing anything
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('LoginScreen password visibility toggle works',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final toggleButton = find.byIcon(Icons.visibility_outlined);
      expect(toggleButton, findsOneWidget);

      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });

  group('SignUpScreen Tests', () {
    testWidgets('Renders all SignUpScreen elements and role cards',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const SignUpScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('I am joining as a'), findsOneWidget);
      expect(find.text('Patient'), findsOneWidget);
      expect(find.text('Doctor'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('SignUpScreen role selection toggles between Patient and Doctor',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const SignUpScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Doctor role card
      await tester.tap(find.text('Doctor'));
      await tester.pumpAndSettle();

      // Tap Patient role card
      await tester.tap(find.text('Patient'));
      await tester.pumpAndSettle();
    });

    testWidgets('SignUpScreen validates password match',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const SignUpScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      // Full Name
      await tester.enterText(textFields.at(0), 'Test User');
      // Email
      await tester.enterText(textFields.at(1), 'test@example.com');
      // Password
      await tester.enterText(textFields.at(2), 'password123');
      // Confirm Password (mismatched)
      await tester.enterText(textFields.at(3), 'mismatched123');

      final signUpBtn = find.widgetWithText(ElevatedButton, 'Sign Up');
      await tester.ensureVisible(signUpBtn);
      await tester.tap(signUpBtn);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen Tests', () {
    testWidgets('Renders ForgotPasswordScreen elements properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Send Reset Link'), findsOneWidget);
    });

    testWidgets('ForgotPasswordScreen validates email input',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ForgotPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Send Reset Link'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
    });
  });
}
