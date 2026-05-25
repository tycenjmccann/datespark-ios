import SwiftUI

/// The logout button component for the profile screen.
///
/// Implements the TEAM-142 design spec with:
/// - Warm coral-red destructive styling
/// - All visual states (default, hover, pressed, loading, disabled)
/// - Accessibility labels for VoiceOver
/// - Reduced motion support
/// - Debounce protection (disabled during loading)
///
/// Usage:
/// ```swift
/// LogoutButton(isLoading: $isLoading) {
///     await authService.logout()
/// }
/// ```
struct LogoutButton: View {

    // MARK: - Properties

    @Binding var isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPressed = false

    // MARK: - Init

    init(
        isLoading: Binding<Bool>,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self._isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            buttonContent
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .scaleEffect(scaleEffect)
        .animation(pressAnimation, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityRemoveTraits(isDisabled ? .isButton : [])
        .accessibilityValue(isLoading ? "Logging out, please wait" : "")
        .padding(.horizontal, LogoutTokens.Sizing.contentInsets)
        .padding(.top, LogoutTokens.Sizing.marginTop)
    }

    // MARK: - Subviews

    private var buttonContent: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(textColor)
                    .scaleEffect(0.9)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 18, weight: .medium))
                    .accessibilityHidden(true)

                Text("Log Out")
                    .font(LogoutTokens.Typography.buttonFont)
                    .tracking(-0.2) // letter-spacing from spec
            }
        }
        .foregroundStyle(currentTextColor)
        .frame(maxWidth: LogoutTokens.Sizing.buttonMaxWidth)
        .frame(height: LogoutTokens.Sizing.buttonHeight)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: LogoutTokens.Sizing.borderRadius)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LogoutTokens.Sizing.borderRadius)
                .stroke(borderColor, lineWidth: LogoutTokens.Sizing.borderWidth)
        )
        .contentShape(RoundedRectangle(cornerRadius: LogoutTokens.Sizing.borderRadius))
    }

    // MARK: - Computed Properties

    private var scaleEffect: CGFloat {
        guard !reduceMotion else { return 1.0 }
        return isPressed && !isDisabled && !isLoading ? LogoutTokens.Motion.pressScale : 1.0
    }

    private var pressAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: LogoutTokens.Motion.pressDuration)
    }

    private var textColor: Color {
        colorScheme == .dark ? LogoutTokens.Colors.textDark : LogoutTokens.Colors.textLight
    }

    private var currentTextColor: Color {
        if isDisabled {
            return colorScheme == .dark
                ? LogoutTokens.Colors.disabledTextDark
                : LogoutTokens.Colors.disabledTextLight
        }
        return textColor
    }

    private var backgroundColor: Color {
        if isDisabled {
            return colorScheme == .dark
                ? LogoutTokens.Colors.disabledBackgroundDark
                : LogoutTokens.Colors.disabledBackgroundLight
        }
        if isPressed && !isLoading {
            return colorScheme == .dark
                ? LogoutTokens.Colors.backgroundActiveDark
                : LogoutTokens.Colors.backgroundActiveLight
        }
        return colorScheme == .dark
            ? LogoutTokens.Colors.backgroundDark
            : LogoutTokens.Colors.backgroundLight
    }

    private var borderColor: Color {
        if isDisabled {
            return .clear
        }
        return colorScheme == .dark
            ? LogoutTokens.Colors.borderDark
            : LogoutTokens.Colors.borderLight
    }

    private var accessibilityLabel: String {
        if isLoading {
            return "Logging out, please wait"
        }
        return "Log Out"
    }
}
