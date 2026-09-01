import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();
  factory AuthService() => instance;

  bool get _isSupabaseInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient get _client => Supabase.instance.client;

  /// Stream of Supabase authentication state changes.
  Stream<AuthState> get authStateChanges {
    if (!_isSupabaseInitialized) return const Stream.empty();
    return _client.auth.onAuthStateChange;
  }

  /// Current authenticated Supabase User, if any.
  User? get currentUser {
    if (!_isSupabaseInitialized) return null;
    return _client.auth.currentUser;
  }

  /// Current active Supabase Session, if any.
  Session? get currentSession {
    if (!_isSupabaseInitialized) return null;
    return _client.auth.currentSession;
  }

  /// Standard Mobile Deep Link Callback URI for SehatPass
  static const String authCallbackUrl = 'sehatpass://auth-callback';

  /// Whether a user is currently authenticated.
  bool get isAuthenticated => currentUser != null;

  /// Sign up a new user with email, password, full name, and role ('patient' | 'doctor').
  /// Metadata is passed so the database trigger can initialize the profile record.
  /// [emailRedirectTo] defaults to [authCallbackUrl] for native mobile email confirmation.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? emailRedirectTo,
  }) async {
    assert(role == 'patient' || role == 'doctor',
        'Role must be either patient or doctor');
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: emailRedirectTo ?? authCallbackUrl,
        data: {
          'full_name': fullName.trim(),
          'role': role,
        },
      );
      return response;
    } on AuthException catch (e) {
      throw _getFriendlyAuthMessage(e.message);
    } catch (e) {
      throw _getGenericErrorMessage(e);
    }
  }

  /// Sign in an existing user with email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw _getFriendlyAuthMessage(e.message);
    } catch (e) {
      throw _getGenericErrorMessage(e);
    }
  }

  /// Sign out the current user and end the Supabase session.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw _getFriendlyAuthMessage(e.message);
    } catch (e) {
      throw _getGenericErrorMessage(e);
    }
  }

  /// Send password reset link to user's email with mobile deep link redirect.
  Future<void> resetPassword({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: redirectTo ?? authCallbackUrl,
      );
    } on AuthException catch (e) {
      throw _getFriendlyAuthMessage(e.message);
    } catch (e) {
      throw _getGenericErrorMessage(e);
    }
  }

  /// Resend confirmation email to user's email address.
  Future<void> resendVerificationEmail({
    required String email,
    String? emailRedirectTo,
  }) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: emailRedirectTo ?? authCallbackUrl,
      );
    } on AuthException catch (e) {
      throw _getFriendlyAuthMessage(e.message);
    } catch (e) {
      throw _getGenericErrorMessage(e);
    }
  }

  /// Update password for the current recovery session or authenticated user.
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return response;
    } on AuthException catch (e) {
      throw _getFriendlyAuthMessage(e.message);
    } catch (e) {
      throw _getGenericErrorMessage(e);
    }
  }

  /// Authoritative role resolution from public.profiles table.
  /// Strict validation: returns 'patient', 'doctor', or null if not found/invalid.
  Future<String?> getUserProfileRole(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      final role = data['role']?.toString().toLowerCase().trim();
      if (role == 'patient' || role == 'doctor') {
        return role;
      }
      return null;
    } catch (e) {
      // Return null on failure so AuthGate can display a recovery state
      return null;
    }
  }

  /// Authoritative profile retrieval from public.profiles table.
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return data;
    } catch (e) {
      return null;
    }
  }

  /// Translates raw Supabase AuthException messages into friendly user feedback.
  static String _getFriendlyAuthMessage(String rawMessage) {
    final lower = rawMessage.toLowerCase();
    if (lower.contains('over_email_send_rate_limit') ||
        lower.contains('email_rate_limit') ||
        lower.contains('email rate limit') ||
        lower.contains('once every')) {
      return 'For security purposes, you can only request a password reset email once every 60 seconds. Please wait before trying again.';
    }
    if (lower.contains('over_request_rate_limit') ||
        lower.contains('too many requests') ||
        lower.contains('rate limit')) {
      return 'Too many requests. Please wait a few moments before trying again.';
    }
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials') ||
        lower.contains('wrong password')) {
      return 'Invalid email or password. Please try again.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('email already exists') ||
        lower.contains('already exists')) {
      return 'An account with this email already exists. Please login instead.';
    }
    if (lower.contains('password should be at least') ||
        lower.contains('weak password')) {
      return 'Password is too weak. Please use at least 6 characters.';
    }
    if (lower.contains('email not confirmed') ||
        lower.contains('unconfirmed')) {
      return 'Please verify your email address to log in.';
    }
    if (lower.contains('network') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection')) {
      return 'Network connection error. Please check your internet and try again.';
    }
    return rawMessage;
  }

  /// Public utility to parse friendly auth error messages.
  static String getFriendlyAuthMessage(String rawMessage) =>
      _getFriendlyAuthMessage(rawMessage);

  /// Translates generic system errors into user-friendly feedback.
  static String _getGenericErrorMessage(dynamic error) {
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('socketexception') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('clientexception')) {
      return 'Unable to connect to the server. Please check your internet connection.';
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
