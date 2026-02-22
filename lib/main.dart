import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'config/supabase_config.dart';
import 'services/offline_service.dart';
import 'services/connectivity_service.dart';
import 'services/notification_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Add Firebase.initializeApp() here once google-services.json /
  // GoogleService-Info.plist are configured:
  // try {
  //   await Firebase.initializeApp(
  //     options: DefaultFirebaseOptions.currentPlatform,
  //   );
  // } catch (e) {
  //   debugPrint('Firebase init failed: $e');
  // }

  await SupabaseConfig.init();

  // Hive (offline cache)
  await Hive.initFlutter();
  await OfflineService.instance.init();

  // Connectivity monitoring + auto-sync
  ConnectivityService.instance.init();

  // Push notifications (graceful — no-op without Firebase config)
  await NotificationService.instance.init();

  runApp(const ProviderScope(child: AigoApp()));
}
