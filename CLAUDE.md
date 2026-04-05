# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iWalk AI is a native iOS/iPadOS app built with **SwiftUI + SwiftData**. Currently at initial scaffold stage — CloudKit and push notifications are configured but core features (walk tracking, AI integration) are not yet implemented.

## Build & Run

```bash
# Build
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PATH="$DEVELOPER_DIR/usr/bin:$PATH"
xcodebuild build \
  -project "iWalk AI.xcodeproj" \
  -scheme "iWalk AI" \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  2>&1 | xcbeautify --quiet

# Run on simulator
UDID=$(xcrun simctl list devices | grep "iPhone 17 Pro" | grep -v "Plus\|Max" | head -1 | grep -oE "[A-F0-9-]{36}")
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path "*/iWalk_AI*/Build/Products/Debug-iphonesimulator/iWalk AI.app" -maxdepth 5 | head -1)
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl launch --terminate-running-process "$UDID" "kanshaous.iWalk-AI"
```

No test targets exist yet. No external dependencies.

## Architecture

- **Pattern:** MVVM with SwiftUI state management
- **UI:** SwiftUI with NavigationSplitView (list-detail)
- **Persistence:** SwiftData with `@Model` / `@Query`
- **Cloud:** CloudKit-ready (entitlements configured, containers not yet set up)
- **Concurrency:** MainActor default isolation, Swift structured concurrency

## Key Files

| File | Role |
|------|------|
| `iWalk AI/iWalk_AIApp.swift` | App entry point, ModelContainer setup |
| `iWalk AI/ContentView.swift` | Main UI view |
| `iWalk AI/Item.swift` | SwiftData model |
| `iWalk AI/iWalk_AI.entitlements` | CloudKit + push notification entitlements |

## Build Configuration

- **Bundle ID:** `kanshaous.iWalk-AI`
- **Scheme:** `iWalk AI`
- **Team:** X332YRW558 (automatic signing)
- **Targets:** iPhone & iPad
- **Swift:** 5.0, Xcode 16.4
- **Concurrency flags:** `SWIFT_APPROACHABLE_CONCURRENCY=YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`
