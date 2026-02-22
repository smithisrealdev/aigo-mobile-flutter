#!/bin/bash
# Script to screenshot all routes by modifying initialLocation and hot-restarting

PROJ="/Users/smithisreal_l/aigo/aigo mobile new/aigo-mobile-flutter"
ROUTER="$PROJ/lib/router/app_router.dart"
SS="$PROJ/screenshots"

routes=(
  "/onboarding:onboarding"
  "/login:login"
  "/home:home"
  "/explore:explore"
  "/ai-chat:ai-chat"
  "/trips:trips"
  "/profile:profile"
  "/packing-list:packing-list"
  "/travel-tips:travel-tips"
  "/budget:budget"
  "/booking:booking"
  "/trip-summary:trip-summary"
  "/notifications:notifications"
  "/saved-places:saved-places"
  "/map-view:map-view"
  "/search-results:search-results"
  "/place-detail:place-detail"
)

for entry in "${routes[@]}"; do
  route="${entry%%:*}"
  name="${entry##*:}"
  echo "=== Screenshotting $name ($route) ==="
  
  # Update initialLocation
  sed -i '' "s|initialLocation: '[^']*'|initialLocation: '$route'|" "$ROUTER"
  
  echo "READY_FOR_RESTART:$name"
done
