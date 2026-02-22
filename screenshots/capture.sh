#!/bin/bash
# Capture all screens by changing initialLocation and sending 'R' (shift+r = hot restart) to flutter process

PROJECT="/Users/smithisreal_l/aigo/aigo mobile new/aigo-mobile-flutter"
SCREENSHOTS="$PROJECT/screenshots"
ROUTER="$PROJECT/lib/router/app_router.dart"
FLUTTER_PID_FILE="/tmp/flutter_screenshot_pid"

export PATH="$PATH:/Users/smithisreal_l/auto-planer-by-ai/mobile/flutter/bin"

mkdir -p "$SCREENSHOTS"

# Routes to capture (route|filename)
ROUTES=(
  "/|splash"
  "/onboarding|onboarding"  
  "/login|login"
  "/home|home"
  "/explore|explore"
  "/ai-chat|ai_chat"
  "/trips|itinerary"
  "/profile|profile"
  "/packing-list|packing_list"
  "/travel-tips|travel_tips"
  "/budget|budget"
  "/booking|booking"
  "/trip-summary|trip_summary"
  "/notifications|notifications"
  "/saved-places|saved_places"
  "/map-view|map_view"
  "/search-results|search_results"
  "/place-detail|place_detail"
)

capture_route() {
  local route="$1"
  local name="$2"
  
  echo "📸 Setting route to $route ($name)..."
  sed -i '' "s|initialLocation: '.*'|initialLocation: '$route'|" "$ROUTER"
}

# Set first route
capture_route "/" "splash"
echo "All routes prepared. Start flutter and send R to hot restart between each."
