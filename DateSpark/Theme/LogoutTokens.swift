import SwiftUI

/// Design tokens for the Logout Button component.
///
/// Derived from TEAM-142 design specification. All values match the
/// design system's "Warm Minimalism with Intentional Weight" direction.
enum LogoutTokens {

    // MARK: - Sizing

    enum Sizing {
        static let buttonHeight: CGFloat = 52
        static let buttonMinHeight: CGFloat = 44
        static let buttonMaxWidth: CGFloat = 358
        static let borderRadius: CGFloat = 14
        static let iconSize: CGFloat = 20
        static let paddingHorizontal: CGFloat = 24
        static let marginTop: CGFloat = 32
        static let marginBottom: CGFloat = 48
        static let contentInsets: CGFloat = 20
        static let borderWidth: CGFloat = 1
        static let focusRingWidth: CGFloat = 3
        static let focusRingOffset: CGFloat = 3
    }

    // MARK: - Typography

    enum Typography {
        static let buttonFont: Font = .system(size: 17, weight: .semibold, design: .default)
        static let dialogTitleFont: Font = .system(size: 20, weight: .bold, design: .default)
        static let dialogBodyFont: Font = .system(size: 15, weight: .regular, design: .default)
        static let dialogButtonFont: Font = .system(size: 16, weight: .medium, design: .default)
        static let dialogConfirmFont: Font = .system(size: 16, weight: .semibold, design: .default)
    }

    // MARK: - Colors

    enum Colors {
        // Button backgrounds
        static let backgroundLight = Color(red: 254/255, green: 242/255, blue: 242/255) // #FEF2F2
        static let backgroundDark = Color(red: 45/255, green: 21/255, blue: 21/255) // #2D1515

        static let backgroundHoverLight = Color(red: 254/255, green: 226/255, blue: 226/255) // #FEE2E2
        static let backgroundHoverDark = Color(red: 61/255, green: 28/255, blue: 28/255) // #3D1C1C

        static let backgroundActiveLight = Color(red: 254/255, green: 202/255, blue: 202/255) // #FECACA
        static let backgroundActiveDark = Color(red: 74/255, green: 32/255, blue: 32/255) // #4A2020

        // Text
        static let textLight = Color(red: 220/255, green: 38/255, blue: 38/255) // #DC2626
        static let textDark = Color(red: 248/255, green: 113/255, blue: 113/255) // #F87171

        // Border
        static let borderLight = Color(red: 254/255, green: 202/255, blue: 202/255) // #FECACA
        static let borderDark = Color(red: 74/255, green: 32/255, blue: 32/255) // #4A2020

        // Disabled
        static let disabledBackgroundLight = Color(red: 249/255, green: 250/255, blue: 251/255) // #F9FAFB
        static let disabledBackgroundDark = Color(red: 31/255, green: 31/255, blue: 31/255) // #1F1F1F
        static let disabledTextLight = Color(red: 156/255, green: 163/255, blue: 175/255) // #9CA3AF
        static let disabledTextDark = Color(red: 75/255, green: 85/255, blue: 99/255) // #4B5563

        // Dialog
        static let destructiveButton = Color(red: 220/255, green: 38/255, blue: 38/255) // #DC2626
        static let destructiveButtonText = Color.white
        static let cancelBackgroundLight = Color(red: 243/255, green: 244/255, blue: 246/255) // #F3F4F6
        static let cancelBackgroundDark = Color(red: 45/255, green: 45/255, blue: 45/255) // #2D2D2D
        static let cancelTextLight = Color(red: 55/255, green: 65/255, blue: 81/255) // #374151
        static let cancelTextDark = Color(red: 229/255, green: 231/255, blue: 235/255) // #E5E7EB
    }

    // MARK: - Dialog Sizing

    enum Dialog {
        static let maxWidth: CGFloat = 340
        static let padding: CGFloat = 24
        static let borderRadius: CGFloat = 20
        static let buttonHeight: CGFloat = 48
        static let buttonRadius: CGFloat = 12
        static let buttonGap: CGFloat = 8
        static let overlayOpacity: Double = 0.4
        static let backdropBlur: CGFloat = 4
    }

    // MARK: - Motion

    enum Motion {
        static let hoverScale: CGFloat = 1.005
        static let pressScale: CGFloat = 0.98
        static let hoverDuration: Double = 0.18
        static let pressDuration: Double = 0.08
        static let releaseDuration: Double = 0.18
        static let spinnerDuration: Double = 0.8
        static let dialogEnterDuration: Double = 0.25
        static let dialogExitDuration: Double = 0.15
    }
}
