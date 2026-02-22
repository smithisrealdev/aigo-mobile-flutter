#!/bin/bash
PROJECT="/Users/smithisreal_l/aigo/aigo mobile new/aigo-mobile-flutter"
SCREENSHOTS="$PROJECT/screenshots"
ROUTER="$PROJECT/lib/router/app_router.dart"
FLUTTER_SESSION="tide-cedar"

# Routes remaining (splash already done)
declare -a ROUTES=(
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

for entry in "${ROUTES[@]}"; do
  ROUTE="${entry%%|*}"
  NAME="${entry##*|}"
  
  echo "📸 $NAME ($ROUTE)..."
  
  # Change initialLocation
  sed -i '' "s|initialLocation: '.*'|initialLocation: '$ROUTE'|" "$ROUTER"
  
  # Send R for hot restart to the flutter process via its stdin
  # We need to write to the pty - use the PID's tty
  FLUTTER_PID=$(ps aux | grep "flutter_tools.snapshot run" | grep -v grep | awk '{print $2}')
  if [ -n "$FLUTTER_PID" ]; then
    TTY=$(ps -p $FLUTTER_PID -o tty= 2>/dev/null)
    if [ -n "$TTY" ]; then
      echo -n "R" > /dev/$TTY 2>/dev/null
    fi
  fi
  
  sleep 4
  
  xcrun simctl io booted screenshot "$SCREENSHOTS/${NAME}.png" 2>/dev/null
  echo "✅ $NAME"
done

# Restore
sed -i '' "s|initialLocation: '.*'|initialLocation: '/'|" "$ROUTER"
echo "🎉 Done!"
