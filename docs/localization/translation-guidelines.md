# Translation Guidelines — DateSpark iOS

## For Translators

### General Rules

1. **Keep it concise**: UI elements have limited space. Prefer shorter phrasing that conveys the same meaning.
2. **Be consistent**: Use the same term for the same action throughout the app.
3. **Match platform conventions**: Use the same terminology that Apple uses in the device's language (e.g., iOS Settings uses "Sign Out" in some languages).
4. **Formal vs. informal**: Use the formal register unless the language culture strongly prefers informal in apps (e.g., Japanese can use polite form).

### Logout-Specific Guidelines

| Concern | Guidance |
|---------|----------|
| Terminology | Use the equivalent of "Log Out" (session termination), not "Sign Out" (account-level) unless that's the platform norm for the language. |
| Button text | Max ~12-14 characters. Abbreviate if needed. |
| Confirmation dialog | Should clearly communicate the action is reversible (user can log back in). |
| Destructive tone | The confirm button should feel decisive but not alarming. |

### Character Limits

| String Key | Recommended Max |
|------------|----------------|
| `profile.logout.button` | 14 characters |
| `profile.logout.confirmation.title` | 20 characters |
| `profile.logout.confirmation.message` | 60 characters |
| `profile.logout.confirmation.confirm` | 14 characters |
| `profile.logout.confirmation.cancel` | 10 characters |

### Context for Each String

#### `profile.logout.button`
- **Where**: Profile screen, typically at the bottom of settings/options list
- **Style**: Button label, action verb
- **Tone**: Neutral, clear
- **Example placement**: Full-width button or trailing list item

#### `profile.logout.confirmation.title`
- **Where**: Top of a confirmation dialog/action sheet
- **Style**: Question or statement
- **Tone**: Confirming intent

#### `profile.logout.confirmation.message`
- **Where**: Body of the confirmation dialog
- **Style**: Full sentence, question form
- **Tone**: Informative, slightly cautionary

#### `profile.logout.confirmation.confirm`
- **Where**: Destructive action button in dialog
- **Style**: Short action verb/phrase
- **Tone**: Decisive

#### `profile.logout.confirmation.cancel`
- **Where**: Cancel button in dialog
- **Style**: Standard platform cancel text
- **Tone**: Neutral

### RTL Languages (Arabic, Hebrew)

- Text alignment is handled automatically by iOS
- Do NOT add directional characters (LRM/RLM) unless absolutely necessary for mixed content
- Ensure translations read naturally right-to-left
- Parentheses and punctuation marks are auto-mirrored by the OS

### Adding a New Language

1. Create a new `{locale}.lproj/Localizable.strings` file
2. Add translations for all existing keys
3. Update `Localizable.xcstrings` with the new locale entries
4. Test in simulator with the target language set
5. Verify text fits within UI constraints

## For Developers

### Using Localized Strings

```swift
// SwiftUI - auto-localized
Text("profile.logout.button")

// Programmatic access
let text = String(localized: "profile.logout.button")

// With comment for translators (compile-time)
let text = String(localized: "profile.logout.button", 
                  comment: "Logout button on profile screen")
```

### Testing Localization

```swift
// In Xcode scheme: Edit Scheme → Run → Options → App Language
// Or in SwiftUI Preview:
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environment(\.locale, Locale(identifier: "ar"))
            .environment(\.layoutDirection, .rightToLeft)
    }
}
```

### Pseudo-Localization (Development)

Enable "Show non-localized strings" in scheme settings to catch any hardcoded text.
Use Xcode's built-in pseudo-language options for length/RTL testing.
