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
import '../screens/trip_summary_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/saved_places_screen.dart';
import '../screens/map_view_screen.dart';
import '../screens/search_results_screen.dart';
import '../screens/place_detail_screen.dart';
import '../widgets/bottom_nav_bar.dart';

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
    if (!loggedIn && !loggingIn) return '/login';

    // Logged in but on login page → send to home
    if (loggedIn && loggingIn) return '/home';

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => ScaffoldWithNav(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/explore', builder: (_, __) => const ExploreScreen()),
        GoRoute(path: '/ai-chat', builder: (_, __) => const AIChatScreen()),
        GoRoute(path: '/trips', builder: (_, __) => const TripsListScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),
    GoRoute(path: '/itinerary', builder: (_, __) => const ItineraryScreen()),
    GoRoute(path: '/packing-list', builder: (_, __) => const PackingListScreen()),
    GoRoute(path: '/travel-tips', builder: (_, __) => const TravelTipsScreen()),
    GoRoute(path: '/budget', builder: (_, __) => const BudgetScreen()),
    GoRoute(path: '/booking', builder: (_, __) => const BookingScreen()),
    GoRoute(path: '/trip-summary', builder: (_, __) => const TripSummaryScreen()),
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
    GoRoute(path: '/saved-places', builder: (_, __) => const SavedPlacesScreen()),
    GoRoute(path: '/map-view', builder: (_, __) => const MapViewScreen()),
    GoRoute(path: '/search-results', builder: (_, __) => const SearchResultsScreen()),
    GoRoute(path: '/place-detail', builder: (_, __) => const PlaceDetailScreen()),
  ],
);
