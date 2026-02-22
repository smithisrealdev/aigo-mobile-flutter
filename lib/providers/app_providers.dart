// ──────────────────────────────────────────────
// App-wide Riverpod providers
// ──────────────────────────────────────────────
//
// Service-specific providers live in their own files:
//   - auth_service.dart   → authStateProvider, currentUserProvider, etc.
//   - trip_service.dart   → tripsProvider, tripProvider, etc.
//   - chat_service.dart   → chatProvider
//   - itinerary_service.dart → itineraryGenProvider
//
// Re-export everything here for convenient single-import.

export '../services/auth_service.dart'
    show
        authStateProvider,
        currentUserProvider,
        isAuthenticatedProvider,
        userProfileProvider;

export '../services/trip_service.dart'
    show tripsProvider, tripProvider, tripExpensesProvider, tripServiceProvider;

export '../services/chat_service.dart' show chatProvider, chatServiceProvider;

export '../services/itinerary_service.dart'
    show itineraryGenProvider, itineraryServiceProvider;

export '../services/notification_service.dart' show notificationServiceProvider;

export '../services/image_service.dart'
    show imageServiceProvider, placePhotosProvider, destinationImagesProvider;

export '../services/billing_service.dart'
    show billingServiceProvider, currentPlanProvider, paymentHistoryProvider;
