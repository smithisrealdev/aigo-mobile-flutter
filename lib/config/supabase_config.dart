import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration and initialization.
class SupabaseConfig {
  SupabaseConfig._();

  // ── Supabase project (same as website) ──
  static const String supabaseUrl = 'https://dvzqgsukcmdhwwxsynwg.supabase.co';

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR2enFnc3VrY21kaHd3eHN5bndnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE0ODQxMjUsImV4cCI6MjA3NzA2MDEyNX0.V_XDg4NRezthUq_4YlTbHh0JOYQIOo33GJp2qJAN4hI';

  /// Edge‑function base (same project).
  static String get functionsBaseUrl => '$supabaseUrl/functions/v1';

  /// Call once in main() before runApp.
  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  /// Convenience accessor.
  static SupabaseClient get client => Supabase.instance.client;
}
