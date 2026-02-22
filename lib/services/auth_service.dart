import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/models.dart';

// ──────────────────────────────────────────────
// Auth service — thin wrapper around Supabase Auth
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

  // ── Email / password ──
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final res = await _auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
    return res;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithPassword(email: email, password: password);
  }

  // ── Google OAuth ──
  Future<AuthResponse> signInWithGoogle() async {
    /// On mobile we use the native Google Sign-In flow, then pass the
    /// id_token to Supabase for verification.
    const webClientId =
        ''; // TODO: set your Google OAuth web client ID here
    const iosClientId =
        ''; // TODO: set your iOS client ID here

    final googleSignIn = GoogleSignIn(
      clientId: iosClientId.isNotEmpty ? iosClientId : null,
      serverClientId: webClientId.isNotEmpty ? webClientId : null,
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
    await _client.from('profiles').update({
      if (fullName != null) 'full_name': fullName,
      if (homeCurrency != null) 'home_currency': homeCurrency,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', uid);
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

/// Whether the user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// User profile from `profiles` table.
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return AuthService.instance.getProfile();
});
