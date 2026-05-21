# Localization Design: Logout Button

## Overview

This document defines the localization strategy for the logout button feature on the Profile screen in DateSpark iOS.

## String Key Definitions

| Key | Purpose | English Value | Max Length |
|-----|---------|---------------|------------|
| `profile.logout.button` | Main logout button on profile screen | "Log Out" | ~12 chars |
| `profile.logout.confirmation.title` | Confirmation dialog title | "Log Out?" | ~20 chars |
| `profile.logout.confirmation.message` | Confirmation dialog body | "Are you sure you want to log out of your account?" | ~60 chars |
| `profile.logout.confirmation.confirm` | Confirm/destructive action button | "Log Out" | ~12 chars |
| `profile.logout.confirmation.cancel` | Cancel/dismiss button | "Cancel" | ~10 chars |

## Naming Convention

We use a hierarchical dot-notation pattern:
```
{screen}.{feature}.{component}
```

Examples:
- `profile.logout.button` → Profile screen, logout feature, button element
- `profile.logout.confirmation.title` → Profile screen, logout confirmation, title element

## Supported Languages (10)

| Language | Code | Direction | Notes |
|----------|------|-----------|-------|
| English | `en` | LTR | Source language |
| Spanish | `es` | LTR | Latin American Spanish |
| French | `fr` | LTR | European French |
| German | `de` | LTR | Standard German |
| Japanese | `ja` | LTR* | CJK characters, compact |
| Korean | `ko` | LTR* | Hangul, compact |
| Simplified Chinese | `zh-Hans` | LTR* | PRC standard |
| Traditional Chinese | `zh-Hant` | LTR* | Taiwan/HK standard |
| Arabic | `ar` | **RTL** | Right-to-left layout |
| Brazilian Portuguese | `pt-BR` | LTR | Brazilian variant |

*CJK languages are written LTR in modern UI contexts.

## RTL Layout Considerations

### Arabic (`ar`) Specific Guidance

1. **Button Placement**: In RTL mode, the logout button should appear on the **left side** of the profile screen (mirrored from the default right-side LTR placement).

2. **SwiftUI Auto-Mirroring**: Use `.environment(\.layoutDirection, .rightToLeft)` — SwiftUI handles most mirroring automatically when using standard layout modifiers:
   - Use `leading`/`trailing` instead of `left`/`right`
   - Use `HStack` which auto-mirrors in RTL
   - Avoid hardcoded padding on specific sides

3. **Icon Considerations**: If the logout button includes an icon (e.g., arrow pointing outward):
   - Use `Image(systemName: "rectangle.portrait.and.arrow.right")` which auto-mirrors in RTL
   - Or explicitly flip: `.flipsForRightToLeftLayoutDirection(true)`

4. **Confirmation Dialog**: iOS `Alert` and `ConfirmationDialog` automatically handle RTL text alignment.

5. **Text Length**: Arabic text for "تسجيل الخروج" (13 chars) is within acceptable button width. Test at largest Dynamic Type sizes.

## Character Length Analysis

| Key | EN | ES | FR | DE | JA | KO | ZH-S | ZH-T | AR | PT-BR |
|-----|----|----|----|----|----|----|------|------|----|-------|
| button | 7 | 14 | 12 | 8 | 5 | 4 | 4 | 2 | 13 | 4 |
| confirm | 7 | 14 | 12 | 8 | 5 | 4 | 2 | 2 | 4 | 4 |
| cancel | 6 | 8 | 7 | 9 | 5 | 2 | 2 | 2 | 5 | 8 |

### Length Risk Assessment
- **Spanish** (`Cerrar sesión` = 14 chars): Longest button text. May need testing at large Dynamic Type.
- **French** (`Déconnexion` = 12 chars): Moderate length, should fit standard buttons.
- **Arabic** (`تسجيل الخروج` = 13 chars): Connected script renders more compactly than character count suggests.

## Implementation Guide (SwiftUI)

### Usage in Code

```swift
import SwiftUI

struct ProfileView: View {
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        Button(role: .destructive) {
            showLogoutConfirmation = true
        } label: {
            Text("profile.logout.button")
        }
        .confirmationDialog(
            Text("profile.logout.confirmation.title"),
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "profile.logout.confirmation.confirm"), role: .destructive) {
                // Perform logout
            }
            Button(String(localized: "profile.logout.confirmation.cancel"), role: .cancel) {}
        } message: {
            Text("profile.logout.confirmation.message")
        }
    }
}
```

### Accessibility

- The button uses `.destructive` role, which provides appropriate VoiceOver hints.
- String keys are compatible with `String(localized:)` for accessibility labels.
- No additional accessibility strings needed — standard button semantics apply.

## Testing Checklist

- [ ] Verify all 10 languages display correctly in button
- [ ] Test Arabic layout mirrors correctly (button on trailing edge)
- [ ] Test with Dynamic Type (Accessibility sizes)
- [ ] Verify confirmation dialog displays properly in all languages
- [ ] Test VoiceOver reads button label correctly per language
- [ ] Verify no text truncation at standard button width
- [ ] Test Spanish (longest) at maximum Dynamic Type size

## File Structure

```
DateSpark/
└── Resources/
    ├── Localizable.xcstrings          ← Primary (Xcode 15+ String Catalog)
    ├── en.lproj/Localizable.strings   ← English source
    ├── es.lproj/Localizable.strings   ← Spanish
    ├── fr.lproj/Localizable.strings   ← French
    ├── de.lproj/Localizable.strings   ← German
    ├── ja.lproj/Localizable.strings   ← Japanese
    ├── ko.lproj/Localizable.strings   ← Korean
    ├── zh-Hans.lproj/Localizable.strings ← Simplified Chinese
    ├── zh-Hant.lproj/Localizable.strings ← Traditional Chinese
    ├── ar.lproj/Localizable.strings   ← Arabic (RTL)
    └── pt-BR.lproj/Localizable.strings ← Brazilian Portuguese
```

## Translation Guidelines

See `docs/localization/translation-guidelines.md` for contributor instructions.
