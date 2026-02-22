#!/bin/bash
set -e

PROJECT="/Users/smithisreal_l/aigo/aigo mobile new/aigo-mobile-flutter"
SCREENSHOTS="$PROJECT/screenshots"
ROUTER="$PROJECT/lib/router/app_router.dart"
VM_SERVICE="http://127.0.0.1:49820/7wez26WTxNM=/"
ISOLATE_ID="isolates/6659845677007051"

# All routes to screenshot
declare -a ROUTES=(
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

mkdir -p "$SCREENSHOTS"

# Use evaluate expression to navigate via GoRouter
for entry in "${ROUTES[@]}"; do
  ROUTE="${entry%%|*}"
  NAME="${entry##*|}"
  
  echo "📸 Capturing $NAME ($ROUTE)..."
  
  # Navigate using VM service evaluate
  EXPR="import 'package:go_router/go_router.dart'; import 'package:flutter/widgets.dart'; final ctx = (WidgetsBinding.instance.rootElement! as Element); GoRouter.of(ctx).go('$ROUTE');"
  
  # Use hot restart approach: change initialLocation
  # Actually let's use a simpler approach - just modify and hot restart
  
  # Modify initialLocation
  sed -i '' "s|initialLocation: '.*'|initialLocation: '$ROUTE'|" "$ROUTER"
  
  # Trigger hot restart via VM service
  curl -s -X POST "${VM_SERVICE}_flutter.hotRestart" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":"1","method":"_flutter.hotRestart","params":{}}' > /dev/null 2>&1
  
  # Wait for restart
  if [ "$NAME" = "splash" ]; then
    sleep 2
  else
    sleep 3
  fi
  
  # Screenshot
  xcrun simctl io booted screenshot "$SCREENSHOTS/${NAME}.png" 2>/dev/null
  echo "✅ $NAME saved"
done

# Restore initialLocation to splash
sed -i '' "s|initialLocation: '.*'|initialLocation: '/'|" "$ROUTER"
curl -s -X POST "${VM_SERVICE}_flutter.hotRestart" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":"1","method":"_flutter.hotRestart","params":{}}' > /dev/null 2>&1

echo ""
echo "🎉 Done! All screenshots saved to $SCREENSHOTS/"
ls -la "$SCREENSHOTS/"*.png
