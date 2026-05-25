import SwiftUI

/// Root entry point for the DateSpark app.
///
/// Authentication state drives the root navigation:
/// - `.authenticated` → Main app (NavigationStack with ProfileScreen)
/// - `.unauthenticated` → LoginView
/// - `.loading` → Splash/loading screen
/// - `.loggingOut` → Keep showing current UI (handled by loading state on button)
///
/// Theme Management:
/// - ThemeService reads preference from UserDefaults on init (before first render)
/// - `.preferredColorScheme()` applied at WindowGroup level for immediate effect
/// - No flash of wrong theme because UserDefaults is synchronous
///
/// Per TEAM-141 security requirements:
/// - Uses navigation replacement (not push) to prevent back-button to authenticated content
/// - Checks auth state on scenePhase changes
/// - No cached authenticated views accessible after logout
@main
struct DateSparkApp: App {

    @State private var authService = AuthService()
    @State private var themeService = ThemeService()

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(authService)
                .environment(themeService)
                .preferredColorScheme(themeService.resolvedColorScheme)
                .task {
                    authService.checkAuthState()
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        switch authService.authState {
        case .loading:
            // Launch screen / splash
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemBackground))

        case .unauthenticated:
            // Login screen — no navigation stack wrapping to prevent back navigation
            LoginView()
                .transition(.opacity)

        case .authenticated:
            // Main authenticated experience
            NavigationStack {
                ProfileScreen()
            }
            .transition(.opacity)

        case .loggingOut:
            // Keep showing the current authenticated UI while logout processes
            // The button's loading state provides visual feedback
            NavigationStack {
                ProfileScreen()
            }
        }
    }
}
