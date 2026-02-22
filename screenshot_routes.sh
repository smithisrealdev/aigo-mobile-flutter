#!/bin/bash
PROJ="/Users/smithisreal_l/aigo/aigo mobile new/aigo-mobile-flutter"
ROUTER="$PROJ/lib/router/app_router.dart"
SS="$PROJ/screenshots"

declare -a ROUTES=("/onboarding" "/login" "/home" "/explore" "/ai-chat" "/trips" "/profile" "/packing-list" "/travel-tips" "/budget" "/booking" "/trip-summary" "/notifications" "/saved-places" "/map-view" "/search-results" "/place-detail")
declare -a NAMES=("onboarding" "login" "home" "explore" "ai-chat" "trips" "profile" "packing-list" "travel-tips" "budget" "booking" "trip-summary" "notifications" "saved-places" "map-view" "search-results" "place-detail")

for i in "${!ROUTES[@]}"; do
  route="${ROUTES[$i]}"
  name="${NAMES[$i]}"
  echo ">>> Processing: $name ($route)"
  sed -i '' "s|initialLocation: '[^']*'|initialLocation: '$route'|" "$ROUTER"
  echo "Modified initialLocation to $route, waiting for hot restart..."
done
echo "DONE"
