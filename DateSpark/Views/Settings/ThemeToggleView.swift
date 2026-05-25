import SwiftUI

/// A segmented theme picker showing Light, Dark, and System options.
///
/// Accessibility:
/// - Full VoiceOver support with descriptive labels and hints
/// - Respects Dynamic Type
/// - Animated transitions respect `accessibilityReduceMotion`
///
/// Usage: Place inside any view that has `ThemeService` in the environment.
struct ThemeToggleView: View {

    @Environment(ThemeService.self) private var themeService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var service = themeService

        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)

            Picker("Theme", selection: $service.preference) {
                ForEach(ThemePreference.allCases, id: \.self) { option in
                    Label(option.displayName, systemImage: option.iconName)
                        .tag(option)
                        .accessibilityLabel("\(option.displayName) theme")
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Theme selection")
            .accessibilityHint("Choose between light, dark, or system appearance")

            Text(descriptionText)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .accessibilityLabel(descriptionText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .animation(
            reduceMotion ? .none : .easeInOut(duration: 0.2),
            value: themeService.preference
        )
    }

    // MARK: - Private

    private var descriptionText: String {
        switch themeService.preference {
        case .light:
            "Always use light appearance."
        case .dark:
            "Always use dark appearance."
        case .system:
            "Automatically match your device settings."
        }
    }
}
