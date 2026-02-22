import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/models.dart';

// ──────────────────────────────────────────────
// Auth service — matches AuthContext.tsx
// ──────────────────────────────────────────────

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => SupabaseConfig.client;
  GoTrueClient get _auth => _client.auth;

  // ── State stream ──
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;
  Session? get currentSession => _auth.currentSession;
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentSession != null;

  /// Get current access token, refreshing if needed.
  Future<String?> getAccessToken() async {
    final session = _auth.currentSession;
    if (session == null) return null;

    // Check if token is about to expire (within 60s)
    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final expiresDate =
          DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      if (expiresDate.difference(DateTime.now()).inSeconds < 60) {
        final refreshed = await _auth.refreshSession();
        return refreshed.session?.accessToken;
      }
    }
    return session.accessToken;
  }

  // ── Email / password (matches AuthContext.tsx) ──

  /// signUp passes full_name in data metadata, matching website.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return _auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  /// signIn with email/password, matching website.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithPassword(email: email, password: password);
  }

  // ── Google OAuth ──
  Future<AuthResponse> signInWithGoogle() async {
    const webClientId = '566607202117-rocpiig2v082i0fctl6ih9lkjt6vi6gg.apps.googleusercontent.com';
    const iosClientId = '566607202117-4s2hl6tg58li95mb4j90csldh2cc86do.apps.googleusercontent.com';

    final isIOS = Platform.isIOS;

    final googleSignIn = GoogleSignIn(
      // On iOS: set serverClientId to webClientId so id_token has web audience
      // On Android: serverClientId for id_token audience
      clientId: isIOS ? iosClientId : null,
      serverClientId: webClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw AuthException('Google sign-in was cancelled.');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw AuthException('Failed to get Google ID token.');
    }

    return _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  // ── Profile ──
  Future<UserProfile?> getProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final data =
        await _client.from('profiles').select().eq('id', uid).maybeSingle();
    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<void> updateProfile({String? fullName, String? homeCurrency}) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _client
        .from('profiles')
        .update({
          if (fullName != null) 'full_name': fullName,
          if (homeCurrency != null) 'home_currency': homeCurrency,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', uid);
  }

  // ── Sign out ──
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

// ──────────────────────────────────────────────
// Riverpod providers
// ──────────────────────────────────────────────

/// Exposes the raw Supabase auth state stream.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return AuthService.instance.onAuthStateChange;
});

/// Current user (null when logged out).
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(data: (state) => state.session?.user);
});

/// Current session.
final currentSessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(data: (state) => state.session);
});

/// Whether the user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// Auth loading state.
final authLoadingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.isLoading;
});

/// User profile from `profiles` table.
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return AuthService.instance.getProfile();
});
