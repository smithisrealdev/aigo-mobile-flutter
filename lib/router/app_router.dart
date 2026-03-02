import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/itinerary_screen.dart';
import '../screens/trips_list_screen.dart';
import '../screens/packing_list_screen.dart';
import '../screens/travel_tips_screen.dart';
import '../screens/budget_screen.dart';
import '../screens/booking_screen.dart';
import '../screens/flight_search_screen.dart';
import '../screens/hotel_search_screen.dart';
import '../screens/trip_summary_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/dashboard_stats_screen.dart';
import '../screens/saved_places_screen.dart';
import '../screens/map_view_screen.dart';
import '../screens/search_results_screen.dart';
import '../screens/place_detail_screen.dart';
import '../screens/pricing_screen.dart';
import '../screens/account_settings_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/shared_trip_screen.dart';
import '../screens/expense_splitter_screen.dart';
import '../screens/budget_categories_screen.dart';
import '../screens/activity_feed_screen.dart';
import '../screens/referral_screen.dart';
import '../screens/reviews_screen.dart';
import '../screens/destination_guide_screen.dart';
import '../screens/user_journey_screen.dart';
import '../widgets/bottom_nav_bar.dart';
import '../models/models.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

bool _isAuthenticated() =>
    Supabase.instance.client.auth.currentSession != null;

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    final loggedIn = _isAuthenticated();
    final loggingIn = state.matchedLocation == '/login';
    final isSplash = state.matchedLocation == '/';
    final isOnboarding = state.matchedLocation == '/onboarding';

    // Let splash and onboarding through always
    if (isSplash || isOnboarding) return null;

    // Not logged in → send to login (unless already there)
    if (!loggedIn && !loggingIn) return "/login";

    // Logged in but on login page → send to home
    if (loggedIn && loggingIn) return '/home';

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => ScaffoldWithNav(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/explore', builder: (_, _) => const ExploreScreen()),
        GoRoute(path: '/ai-chat', builder: (_, state) => AIChatScreen(initialMessage: state.extra as String?)),
        GoRoute(path: '/trips', builder: (_, _) => const TripsListScreen()),
        GoRoute(path: '/saved', builder: (_, _) => const SavedPlacesScreen()),
        GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      ],
    ),
    GoRoute(path: '/itinerary', pageBuilder: (_, state) => CustomTransitionPage(
      key: state.pageKey, child: ItineraryScreen(trip: state.extra as Trip?),
      transitionsBuilder: (c, a, s, child) => FadeTransition(opacity: a, child: child),
    )),
    GoRoute(path: '/packing-list', pageBuilder: (_, state) => CustomTransitionPage(
      key: state.pageKey, child: PackingListScreen(trip: state.extra as Trip?),
      transitionsBuilder: (c, a, s, child) => FadeTransition(opacity: a, child: child),
    )),
    GoRoute(path: '/travel-tips', pageBuilder: (_, state) => CustomTransitionPage(
      key: state.pageKey, child: TravelTipsScreen(destination: state.extra as String?),
      transitionsBuilder: (c, a, s, child) => FadeTransition(opacity: a, child: child),
    )),
    GoRoute(path: '/budget', pageBuilder: (_, state) => CustomTransitionPage(
      key: state.pageKey, child: const BudgetScreen(),
      transitionsBuilder: (c, a, s, child) => FadeTransition(opacity: a, child: child),
    )),
    GoRoute(path: '/booking', builder: (_, _) => const BookingScreen()),
    GoRoute(path: '/flight-search', builder: (_, _) => const FlightSearchScreen()),
    GoRoute(path: '/hotel-search', builder: (_, _) => const HotelSearchScreen()),
    GoRoute(path: '/trip-summary', pageBuilder: (_, state) => CustomTransitionPage(
      key: state.pageKey, child: TripSummaryScreen(trip: state.extra as Trip?),
      transitionsBuilder: (c, a, s, child) => FadeTransition(opacity: a, child: child),
    )),
    GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
    GoRoute(path: '/saved-places', builder: (_, _) => const SavedPlacesScreen()),
    GoRoute(path: '/map-view', builder: (_, _) => const MapViewScreen()),
    GoRoute(path: '/search-results', builder: (_, _) => const SearchResultsScreen()),
    GoRoute(path: '/pricing', builder: (_, _) => const PricingScreen()),
    GoRoute(path: '/account-settings', builder: (_, _) => const AccountSettingsScreen()),
    GoRoute(path: '/progress', builder: (_, _) => const ProgressScreen()),
    GoRoute(path: '/dashboard-stats', builder: (_, _) => const DashboardStatsScreen()),
    GoRoute(path: '/shared-trip/:token', builder: (_, state) => SharedTripScreen(token: state.pathParameters['token']!)),
    GoRoute(path: '/expense-splitter', builder: (_, _) => const ExpenseSplitterScreen()),
    GoRoute(path: '/budget-categories', builder: (_, _) => const BudgetCategoriesScreen()),
    GoRoute(path: '/activity-feed', builder: (_, _) => const ActivityFeedScreen()),
    GoRoute(path: '/referral', builder: (_, _) => const ReferralScreen()),
    GoRoute(path: '/user-journey', builder: (_, _) => const UserJourneyScreen()),
    GoRoute(path: '/reviews', builder: (_, state) {
      final extra = state.extra as Map<String, String?>? ?? {};
      return ReviewsScreen(
        tripId: extra['tripId'],
        placeId: extra['placeId'],
        title: extra['title'],
      );
    }),
    GoRoute(path: '/destination-guide', builder: (_, state) {
      final destination = state.uri.queryParameters['destination'] ??
          (state.extra is String ? state.extra as String : 'Bangkok');
      return DestinationGuideScreen(destination: destination);
    }),
    GoRoute(path: '/place-detail', builder: (_, state) {
      final extra = state.extra;
      if (extra is Map<String, String?>) {
        return PlaceDetailScreen(placeId: extra['placeId'], placeName: extra['placeName']);
      }
      return const PlaceDetailScreen();
    }),
  ],
);
