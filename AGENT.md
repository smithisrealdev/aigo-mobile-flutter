# Agent Instructions

## ⚠️ MANDATORY: Read Before Any Action

**Every AI agent working on this codebase MUST:**

1. **Read your system instructions completely** - Understand your capabilities and limitations before responding
2. **Read your available skills/tools** - Know what tools you have access to and use them appropriately
3. **Read `.github/copilot-instructions.md`** - Contains project-specific conventions and patterns
4. **Gather context first** - Do not assume; search and read relevant code before making changes

## Quick Reference

- **State Management**: Riverpod (not Provider, not Bloc)
- **Backend**: Supabase (not Firebase for data)
- **Routing**: GoRouter
- **Offline**: Hive + PendingChange queue

## Key Files to Understand

| File | Why Important |
|------|---------------|
| `lib/config/supabase_config.dart` | All Supabase access goes through `SupabaseConfig.client` |
| `lib/providers/app_providers.dart` | Central export of all providers |
| `lib/services/offline_service.dart` | Offline caching pattern |
| `lib/router/app_router.dart` | All routes and auth guards |

## Do NOT

- Use `Supabase.instance.client` directly (use `SupabaseConfig.client`)
- Create `toJson()` methods (use `toInsertJson()` for Supabase inserts)
- Add providers outside service files
- Skip offline handling for CRUD operations

---

## 🧑‍💻 Flutter Developer Agent

**Your Role**: Implement features, fix bugs, and maintain code quality.

### Before Coding
1. Read `lib/services/` for existing patterns before creating new services
2. Check `lib/models/models.dart` for existing data classes
3. Understand the offline-first pattern in `offline_service.dart`

### Coding Standards
```dart
// ✅ Correct: Service singleton pattern
class MyService {
  MyService._();
  static final MyService instance = MyService._();
}
final myServiceProvider = Provider((_) => MyService.instance);

// ✅ Correct: Screen with Riverpod
class MyScreen extends ConsumerStatefulWidget {
  const MyScreen({super.key});
  @override
  ConsumerState<MyScreen> createState() => _MyScreenState();
}

// ✅ Correct: Model JSON methods
factory MyModel.fromJson(Map<String, dynamic> json) => MyModel(
  id: json['id'] as String,
  userId: json['user_id'] as String,  // snake_case from Supabase
);
Map<String, dynamic> toInsertJson() => {
  'user_id': userId,  // snake_case for Supabase
};
```

### Checklist for New Features
- [ ] Created service with singleton pattern?
- [ ] Added provider in service file?
- [ ] Exported provider in `app_providers.dart`?
- [ ] Added route in `app_router.dart`?
- [ ] Implemented offline caching if needed?
- [ ] Used `AppColors` and `AppTheme`?

---

## 📋 Project Manager (PM) Agent

**Your Role**: Plan features, track progress, manage requirements.

### Project Overview
- **App Name**: AiGo - AI Travel Planning
- **Platform**: Flutter (iOS + Android)
- **Backend**: Supabase (matches companion website)

### Current Architecture Stats
| Category | Count |
|----------|-------|
| Services | 38 |
| Screens | 32 |
| Widgets | 30 |
| Models | 5 files |

### Key Feature Areas
1. **Trip Planning** - AI chat, itinerary generation
2. **Bookings** - Flights, hotels, reservations
3. **Social** - Sharing, collaboration, reviews
4. **Budget** - Expense tracking, splitting
5. **Offline** - Full offline support with sync

### When Planning Features
- Check if service already exists in `lib/services/`
- Verify Supabase table structure matches website
- Consider offline-first implications
- Review `lib/screens/` for similar UI patterns

### Status Tracking Files
- Routes: `lib/router/app_router.dart`
- All screens: `lib/screens/` directory
- All services: `lib/services/` directory

---

## 🎨 UX/UI Designer Agent

**Your Role**: Design interfaces, review layouts, suggest improvements.

### Design System

**Colors** (from `lib/theme/app_colors.dart`):
```dart
// Primary
brandBlue        // Main accent color
brandBlueLight   // Secondary accent

// Text
textPrimary      // Main text
textSecondary    // Muted text

// Background
background       // Light mode bg
backgroundDark   // Dark mode bg
surface          // Card surfaces
```

**Typography**: DM Sans (via Google Fonts)
- Use `GoogleFonts.dmSans()` for all text
- Follow Material 3 text hierarchy

**Spacing & Sizing**:
- Border radius: 14-24px for cards/buttons
- Padding: 16-24px standard
- Icon sizes: 24px default

### Component Library
Review existing widgets in `lib/widgets/`:
- `destination_card.dart` - Travel card pattern
- `skeleton_loading.dart` - Loading states
- `bottom_nav_bar.dart` - Navigation pattern
- `review_card.dart` - User content cards

### Design Principles
1. **Offline-aware** - Show cached content gracefully
2. **Travel-focused** - Rich imagery, maps, itineraries
3. **AI-forward** - Chat interfaces, streaming responses
4. **Dark mode** - Full support via `AppTheme`

### When Reviewing Screens
- Check consistency with `AppColors`
- Verify dark mode support
- Review loading/error states
- Ensure accessibility (contrast, touch targets)

### Key Screens to Reference
| Screen | Pattern |
|--------|---------|
| `home_screen.dart` | Dashboard layout |
| `ai_chat_screen.dart` | Chat interface |
| `itinerary_screen.dart` | List with actions |
| `profile_screen.dart` | Settings/account |
