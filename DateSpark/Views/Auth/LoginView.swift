import SwiftUI

/// Placeholder login view — the redirect target after logout.
///
/// In the full app, this would contain the actual authentication UI.
/// For now, it serves as the landing screen for unauthenticated users.
struct LoginView: View {

    @Environment(AuthService.self) private var authService

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App branding
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.pink)
                .accessibilityHidden(true)

            Text("DateSpark")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text("Sign in to access your matches and messages")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            // Placeholder sign-in button
            Button {
                // In production: trigger actual auth flow
            } label: {
                Text("Sign In")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.pink)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 48)
            .accessibilityLabel("Sign In")
        }
    }
}
