import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sehatpass/auth/auth_gate.dart';
import 'package:sehatpass/core/theme/app_theme.dart';
import 'package:sehatpass/features/auth/login_screen.dart';
import 'package:sehatpass/features/auth/signup_screen.dart';
import 'package:sehatpass/features/auth/forgot_password_screen.dart';
import 'package:sehatpass/features/auth/reset_password_screen.dart';
import 'package:sehatpass/services/auth_service.dart';

void main() {
  group('AuthService Tests', () {
    test('authCallbackUrl is configured to sehatpass://auth-callback', () {
      expect(AuthService.authCallbackUrl, 'sehatpass://auth-callback');
    });

    test('over_email_send_rate_limit returns user-friendly 60-second message', () {
      final msg = AuthService.getFriendlyAuthMessage('over_email_send_rate_limit');
      expect(
        msg,
        'For security purposes, you can only request a password reset email once every 60 seconds. Please wait before trying again.',
      );
    });

    test('over_request_rate_limit returns friendly rate-limit message', () {
      final msg = AuthService.getFriendlyAuthMessage('over_request_rate_limit');
      expect(
        msg,
        'Too many requests. Please wait a few moments before trying again.',
      );
    });
  });

  group('AuthGate Password Recovery Tests', () {
    testWidgets('AuthGate routes to ResetPasswordScreen on passwordRecovery event',
        (WidgetTester tester) async {
      final controller = StreamController<AuthState>();
      final mockUser = User(
        id: 'rec-user-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      final mockSession = Session(
        accessToken: 'mock-token',
        tokenType: 'bearer',
        user: mockUser,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AuthGate(
            authStateStream: controller.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially null session -> LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);

      // Emit passwordRecovery event
      controller.add(AuthState(AuthChangeEvent.passwordRecovery, mockSession));
      await tester.pumpAndSettle();

      // Should display ResetPasswordScreen, not AppShell or DoctorShellScreen
      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.text('Create New Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);

      await controller.close();
    });
  });

  group('ResetPasswordScreen Tests', () {
    testWidgets('Renders all ResetPasswordScreen elements properly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ResetPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create New Password'), findsOneWidget);
      expect(
        find.text(
            'Your identity has been verified. Enter your new password below.'),
        findsOneWidget,
      );
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));
    });

    testWidgets('Toggles password visibility on both fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ResetPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final iconButtons = find.byType(IconButton);
      expect(iconButtons, findsNWidgets(2));

      // Toggle first field
      await tester.tap(iconButtons.at(0));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      // Toggle second field
      await tester.tap(iconButtons.at(1));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_off_outlined), findsNWidgets(2));
    });

    testWidgets('Validates empty and short password inputs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ResetPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap update password without entering anything
      await tester.tap(find.widgetWithText(ElevatedButton, 'Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a new password'), findsOneWidget);

      // Enter short password
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('Validates password mismatch',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const ResetPasswordScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'newpassword123');
      await tester.enterText(textFields.at(1), 'mismatched123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('Handles successful password update and navigates back to login',
        (WidgetTester tester) async {
      String? submittedPassword;
      bool continueCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ResetPasswordScreen(
            onUpdatePassword: (password) async {
              submittedPassword = password;
            },
            onContinueToLogin: () {
              continueCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'ValidPass123!');
      await tester.enterText(textFields.at(1), 'ValidPass123!');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Update Password'));
      await tester.pumpAndSettle();

      expect(submittedPassword, 'ValidPass123!');
      expect(find.text('Password updated successfully'), findsOneWidget);
      expect(find.text('Continue to Login'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue to Login'));
      await tester.pumpAndSettle();

      expect(continueCalled, isTrue);
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

    testWidgets('Tapping Resend verification email triggers cooldown',
        (WidgetTester tester) async {
      String? resentEmail;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: LoginScreen(
            onResendVerification: (email) async {
              resentEmail = email;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter email in email field
      final emailField = find.widgetWithText(TextFormField, 'name@example.com');
      await tester.enterText(emailField, 'test@example.com');

      final resendBtn = find.text('Resend verification email');
      await tester.ensureVisible(resendBtn);
      await tester.tap(resendBtn);
      await tester.pumpAndSettle();

      expect(resentEmail, 'test@example.com');
      // Should now display cooldown
      expect(find.textContaining('Resend verification email ('), findsOneWidget);
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

    testWidgets('ForgotPasswordScreen activates 60s cooldown on success',
        (WidgetTester tester) async {
      String? sentEmail;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ForgotPasswordScreen(
            onResetPassword: (email) async {
              sentEmail = email;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emailField = find.byType(TextFormField);
      await tester.enterText(emailField, 'reset@example.com');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Send Reset Link'));
      await tester.pumpAndSettle();

      expect(sentEmail, 'reset@example.com');
      expect(find.text('Check Your Email'), findsOneWidget);
      expect(find.textContaining('Resend available in'), findsOneWidget);
    });

    testWidgets('ForgotPasswordScreen displays rate limit message and starts cooldown on rate limit error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ForgotPasswordScreen(
            onResetPassword: (email) async {
              throw 'For security purposes, you can only request a password reset email once every 60 seconds. Please wait before trying again.';
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emailField = find.byType(TextFormField);
      await tester.enterText(emailField, 'reset@example.com');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Send Reset Link'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('once every 60 seconds'),
        findsOneWidget,
      );
      // Button should now be on cooldown
      expect(find.textContaining('Resend in '), findsOneWidget);
    });
  });
}
