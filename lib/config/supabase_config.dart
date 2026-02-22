import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration and initialization.
class SupabaseConfig {
  SupabaseConfig._();

  // ── Supabase project (same as website) ──
  static const String supabaseUrl = 'https://pievxjynaqqiqicujjkl.supabase.co';

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBpZXZ4anluYXFxaXFpY3VqamtsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcxNDkyMTUsImV4cCI6MjA4MjcyNTIxNX0.f87o5sb7muSetwyObH-mT7-m5jPU5TJGie77NB26E38';

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
