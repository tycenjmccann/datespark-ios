import SwiftUI

/// Settings screen containing app preferences.
///
/// Currently hosts the theme/appearance toggle.
/// Future settings sections can be added to the VStack.
struct SettingsScreen: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ThemeToggleView()
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}
