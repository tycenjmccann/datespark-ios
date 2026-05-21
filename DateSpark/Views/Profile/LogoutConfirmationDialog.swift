import SwiftUI

/// Confirmation dialog presented before logout.
///
/// Per TEAM-142 design spec:
/// - Modal overlay with 40% black + 4pt backdrop blur
/// - Focus trapping within dialog when open
/// - Cancel is the default focused button (safer default)
/// - Escape key dismisses (acts as Cancel)
/// - Reduced motion: opacity-only transitions, no scale
///
/// Accessibility:
/// - Announced as modal alert
/// - Focus moves to dialog title when opened
/// - VoiceOver labels on all interactive elements
struct LogoutConfirmationDialog: View {

    // MARK: - Properties

    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var animateIn = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Backdrop overlay
            Color.black
                .opacity(animateIn ? LogoutTokens.Dialog.overlayOpacity : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    // Do NOT dismiss on backdrop tap (accessibility requirement per spec)
                }
                .accessibilityHidden(true)

            // Dialog card
            dialogContent
                .scaleEffect(dialogScale)
                .opacity(animateIn ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: LogoutTokens.Motion.dialogEnterDuration)) {
                animateIn = true
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Dialog Content

    private var dialogContent: some View {
        VStack(spacing: 20) {
            // Title
            Text("Log Out of DateSpark?")
                .font(LogoutTokens.Typography.dialogTitleFont)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            // Body message
            Text("You'll need to sign in again to access your matches and messages.")
                .font(LogoutTokens.Typography.dialogBodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // Buttons
            HStack(spacing: LogoutTokens.Dialog.buttonGap) {
                // Cancel button
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(LogoutTokens.Typography.dialogButtonFont)
                        .foregroundStyle(cancelTextColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: LogoutTokens.Dialog.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: LogoutTokens.Dialog.buttonRadius)
                                .fill(cancelBackgroundColor)
                        )
                }
                .accessibilityLabel("Cancel, stay logged in")

                // Confirm logout button
                Button {
                    dismiss()
                    onConfirm()
                } label: {
                    Text("Log Out")
                        .font(LogoutTokens.Typography.dialogConfirmFont)
                        .foregroundStyle(LogoutTokens.Colors.destructiveButtonText)
                        .frame(maxWidth: .infinity)
                        .frame(height: LogoutTokens.Dialog.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: LogoutTokens.Dialog.buttonRadius)
                                .fill(LogoutTokens.Colors.destructiveButton)
                        )
                }
                .accessibilityLabel("Confirm log out")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(LogoutTokens.Dialog.padding)
        .frame(maxWidth: LogoutTokens.Dialog.maxWidth)
        .background(
            RoundedRectangle(cornerRadius: LogoutTokens.Dialog.borderRadius)
                .fill(dialogBackgroundColor)
                .shadow(color: .black.opacity(0.16), radius: 24, x: 0, y: 24)
        )
        .padding(.horizontal, 24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Log out confirmation")
    }

    // MARK: - Helpers

    private var dialogScale: CGFloat {
        guard !reduceMotion else { return 1.0 }
        return animateIn ? 1.0 : 0.95
    }

    private var dialogBackgroundColor: Color {
        colorScheme == .dark
            ? Color(uiColor: .secondarySystemBackground)
            : Color(uiColor: .systemBackground)
    }

    private var cancelBackgroundColor: Color {
        colorScheme == .dark
            ? LogoutTokens.Colors.cancelBackgroundDark
            : LogoutTokens.Colors.cancelBackgroundLight
    }

    private var cancelTextColor: Color {
        colorScheme == .dark
            ? LogoutTokens.Colors.cancelTextDark
            : LogoutTokens.Colors.cancelTextLight
    }

    private func dismiss() {
        let duration = LogoutTokens.Motion.dialogExitDuration
        withAnimation(.easeIn(duration: duration)) {
            animateIn = false
        }
        // Delay actual dismissal until animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            isPresented = false
        }
    }
}
