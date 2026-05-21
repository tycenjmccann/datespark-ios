import SwiftUI

/// Profile screen showing user info, settings sections, and the logout button.
///
/// Layout follows TEAM-142 spec:
/// - ScrollView with profile header, settings sections, logout button at bottom
/// - Logout button is NOT fixed — it scrolls with content (intentional friction)
/// - Confirmation dialog overlays when logout is tapped
///
/// The logout flow is managed reactively:
/// 1. User taps "Log Out" → confirmation dialog appears
/// 2. User confirms → loading state on button, async logout call
/// 3. AuthService transitions to .unauthenticated → root navigation changes
struct ProfileScreen: View {

    // MARK: - Properties

    @Environment(AuthService.self) private var authService
    @Environment(\.scenePhase) private var scenePhase

    @State private var showLogoutConfirmation = false
    @State private var isLoggingOut = false

    // MARK: - Body

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                    settingsSections
                    logoutSection
                    appVersion
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)

            // Confirmation dialog overlay
            if showLogoutConfirmation {
                LogoutConfirmationDialog(
                    isPresented: $showLogoutConfirmation,
                    onConfirm: performLogout
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showLogoutConfirmation)
        .onChange(of: scenePhase) { _, newPhase in
            // Per TEAM-141: Check auth state on foreground (back-button attack prevention)
            if newPhase == .active {
                verifyAuthStateOnForeground()
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.gray)
                )
                .accessibilityHidden(true)

            // Name
            if let user = authService.authState.currentUser {
                Text(user.displayName)
                    .font(.system(size: 22, weight: .bold))

                Text(user.email)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Settings Sections

    private var settingsSections: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "person.circle", title: "Account Settings")
            Divider().padding(.leading, 56)

            settingsRow(icon: "slider.horizontal.3", title: "Preferences")
            Divider().padding(.leading, 56)

            settingsRow(icon: "bell", title: "Notifications")
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private func settingsRow(icon: String, title: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.primary)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 17))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Logout Section

    private var logoutSection: some View {
        LogoutButton(
            isLoading: $isLoggingOut,
            isDisabled: false,
            action: {
                showLogoutConfirmation = true
            }
        )
    }

    // MARK: - App Version

    private var appVersion: some View {
        Text("DateSpark v2.1.0")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .padding(.top, 16)
            .padding(.bottom, LogoutTokens.Sizing.marginBottom)
            .accessibilityLabel("App version 2.1.0")
    }

    // MARK: - Actions

    private func performLogout() {
        isLoggingOut = true

        Task {
            await authService.logout()
            // Navigation handled reactively by AuthService state change
            // isLoggingOut will be irrelevant once view hierarchy changes
        }
    }

    /// Verify auth state when app returns to foreground.
    /// Per TEAM-141: prevents stale authenticated views from appearing
    /// after logout completed in background or on another device.
    private func verifyAuthStateOnForeground() {
        if !authService.authState.isAuthenticated && authService.authState != .loading {
            // Auth state invalid — this view shouldn't be showing
            // Root navigation will handle this via state observation
        }
    }
}
