# DateSpark iOS - Project Conventions

## Architecture
- **Pattern:** Model-View (MV) with @Observable services
- **Swift Version:** 6.1+ with strict concurrency
- **UI Framework:** SwiftUI (iOS 17+)
- **State:** @State for local, @Environment for shared services

## Code Style
- Google Swift Style Guide
- No force unwraps without guard
- Structured concurrency (async/await, actors, @MainActor)
- .task {} for async operations (never Task in onAppear)
- Enums for view states (loading, loaded, error)

## File Structure
```
DateSpark/
├── App/          # App entry point, root navigation
├── Models/       # Data models (struct, Codable, Sendable)
├── Services/     # @Observable services, API clients
├── Views/        # SwiftUI views organized by feature
│   ├── Auth/     # Login, registration flows
│   └── Profile/  # Profile screen, settings
└── Theme/        # Design tokens, colors, typography
```

## Naming Conventions
- Views: `*View.swift` or `*Screen.swift` (screens are top-level)
- Services: `*Service.swift`
- Models: Named after domain concept
- Tokens: `*Tokens.swift`

## Accessibility
- All interactive elements have accessibility labels
- Support Dynamic Type
- Respect `accessibilityReduceMotion`
- VoiceOver navigable

## Security
- Tokens stored in Keychain (never UserDefaults)
- Clear all auth artifacts on logout
- Server-side session invalidation required
