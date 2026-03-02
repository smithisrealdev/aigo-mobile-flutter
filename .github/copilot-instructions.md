# AiGo Mobile - Copilot Instructions

## ⚠️ CRITICAL: Before Starting Any Task

**All AI agents MUST:**
1. **Read system instructions completely** before taking any action
2. **Read and understand your available skills/tools** before responding
3. **Follow this document's conventions** for all code changes
4. **Do not assume** - gather context from the codebase first

---

## Architecture Overview

AiGo is a Flutter travel planning app with **Supabase backend** and **offline-first architecture**. It mirrors a companion website codebase—many services explicitly reference website patterns (e.g., `// matches useTripChat.tsx`).

### Core Stack
- **State Management**: Riverpod (providers, `ConsumerWidget`, `ConsumerStatefulWidget`)
- **Backend**: Supabase (auth, database, edge functions) via `supabase_flutter`
- **Routing**: GoRouter with shell routes for bottom navigation
- **Offline**: Hive-based caching with pending sync queue

### Key Architectural Patterns

**Service Singleton + Riverpod Provider Pattern**:
Services use singleton instances with companion Riverpod providers:
```dart
// Service singleton
class TripService {
  TripService._();
  static final TripService instance = TripService._();
}

// Companion provider in same file
final tripServiceProvider = Provider((_) => TripService.instance);
```

**Offline-First Data Flow** (`lib/services/offline_service.dart`):
1. Attempt Supabase query → cache result on success
2. On failure, return cached data from Hive
3. Offline mutations queue to `PendingChange` and sync when online via `ConnectivityService`

## Directory Structure

| Path | Purpose |
|------|---------|
| `lib/config/` | Supabase configuration (`supabase_config.dart`) |
| `lib/models/` | Data classes with `fromJson`/`toInsertJson` (mirrors Supabase tables) |
| `lib/services/` | Business logic singletons (38 services covering auth, trips, chat, etc.) |
| `lib/providers/` | Re-exports service providers via `app_providers.dart` |
| `lib/router/` | GoRouter config with auth guards (`app_router.dart`) |
| `lib/screens/` | Screen widgets (one per route) |
| `lib/widgets/` | Reusable components |
| `lib/theme/` | `AppTheme`, `AppColors`, `ThemeProvider` |

## Critical Conventions

### Models
- Use `fromJson` factory constructor and `toInsertJson()` method (not `toJson`)
- Fields match Supabase snake_case column names in JSON methods
- Example: `userId` property ↔ `'user_id'` in JSON

### Providers
- Service providers live in their service files, re-exported via `lib/providers/app_providers.dart`
- Use `ref.watch()` for reactive data, `ref.read()` for one-time access
- Screens extend `ConsumerStatefulWidget` or `ConsumerWidget`

### Supabase Access
- Always use `SupabaseConfig.client` (not direct `Supabase.instance.client`)
- Edge functions: `${SupabaseConfig.functionsBaseUrl}/function-name`
- Auth token: `AuthService.instance.getAccessToken()` (handles refresh)

### Routing
- Routes defined in `lib/router/app_router.dart`
- Pass data via `state.extra` (typed appropriately)
- Main tabs use `ShellRoute` with `ScaffoldWithNav`
- Auth guard redirects unauthenticated users to `/login`

### Theming
- Use `AppColors` constants (e.g., `AppColors.brandBlue`, `AppColors.textPrimary`)
- Typography: DM Sans via `GoogleFonts.dmSans()`
- Both light/dark themes defined in `AppTheme`

## Common Development Tasks

### Adding a New Screen
1. Create `lib/screens/new_screen.dart` extending `ConsumerStatefulWidget`
2. Add route in `lib/router/app_router.dart`
3. Import services via `import '../providers/app_providers.dart'`

### Adding a New Service
1. Create singleton in `lib/services/` with `_()` private constructor
2. Add Riverpod provider(s) at bottom of file
3. Export provider in `lib/providers/app_providers.dart`
4. For offline support, integrate with `OfflineService` cache methods

### Streaming API Calls (Chat/Itinerary)
Services use Dio with response streaming for AI features:
```dart
final response = await dio.post(url,
  options: Options(responseType: ResponseType.stream),
  data: payload,
);
// Process stream chunks...
```

## Build & Run

```bash
flutter pub get                    # Install dependencies
flutter run                        # Run on connected device
flutter build apk --release        # Android release
flutter build ios --release        # iOS release (requires Xcode)
```

### Code Generation (Hive adapters)
```bash
dart run build_runner build --delete-conflicting-outputs
```

## External Dependencies Notes

- **Firebase**: Commented out in `main.dart` until `google-services.json`/`GoogleService-Info.plist` configured
- **Google Maps**: Requires API key in `ios/Runner/AppDelegate.swift` and `android/app/src/main/AndroidManifest.xml`
- **Google Sign-In**: Platform-specific client IDs in `AuthService.signInWithGoogle()`
