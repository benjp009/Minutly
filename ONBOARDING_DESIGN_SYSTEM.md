# Onboarding Design System

All onboarding pages must follow these consistent design patterns for a cohesive user experience.

> **Note**: Onboarding is currently disabled (`if false` in MinutlyApp.swift:65). Re-enable it before testing onboarding changes.

## Progress Indicator (3 Steps)

**Structure**: Use `ZStack` with two layers:
1. **Background layer**: Continuous progress lines (no gaps)
2. **Foreground layer**: Numbered circles on top

```swift
ZStack(alignment: .center) {
    // Background progress lines layer
    HStack(spacing: 0) {
        // Line 1 - Gradient from black to gray (for active step)
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [.black, Color(red: 0.85, green: 0.85, blue: 0.85)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 8)

        // Line 2 - Gray (for inactive steps)
        Rectangle()
            .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
            .frame(height: 8)
    }

    // Circles layer on top
    HStack(spacing: 0) {
        // Active step - Black circle with white number
        Circle()
            .fill(.black)
            .frame(width: 50, height: 50)
            .overlay(
                Text("1")
                    .font(Font.custom("Arial", size: 28).weight(.bold))
                    .foregroundColor(.white)
            )

        Spacer()

        // Inactive step - Gray circle with black number
        Circle()
            .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
            .frame(width: 50, height: 50)
            .overlay(
                Text("2")
                    .font(Font.custom("Arial", size: 28).weight(.bold))
                    .foregroundColor(.black)
            )

        Spacer()

        Circle()
            .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
            .frame(width: 50, height: 50)
            .overlay(
                Text("3")
                    .font(Font.custom("Arial", size: 28).weight(.bold))
                    .foregroundColor(.black)
            )
    }
}
.frame(width: geometry.size.width * 0.5, alignment: .center)
```

**Key Rules**:
- NO text labels below circles (no "Step 1", "Step 2", etc.)
- Lines extend continuously behind circles (no gaps)
- Active step: Black circle + white text
- Inactive steps: Gray circle (`Color(red: 0.85, green: 0.85, blue: 0.85)`) + black text
- Progress indicator width: 50% of screen width, centered

## Text Field Styling

```swift
TextField("Placeholder text here", text: $binding)
    .font(Font.custom("Arial", size: 16))
    .foregroundColor(.black)  // Input text is black
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color(red: 0.85, green: 0.85, blue: 0.85))  // Gray background
    .cornerRadius(16)
    .textFieldStyle(.plain)  // CRITICAL: Removes default borders
```

**Key Rules**:
- Background: Gray `Color(red: 0.85, green: 0.85, blue: 0.85)`
- Text color: Black `.foregroundColor(.black)`
- MUST use `.textFieldStyle(.plain)` to remove default borders
- No white background, no borders

## Navigation Buttons

**Button Structure** (simple, no nested VStacks):

```swift
HStack(alignment: .center, spacing: min(400, geometry.size.width * 0.3)) {
    // Skip button - Black background, white text
    Button(action: { onboardingState.skipPage() }) {
        Text("Skip")
            .font(Font.custom("Arial", size: min(30, geometry.size.height * 0.048)).weight(.bold))
            .foregroundColor(.white)
    }
    .buttonStyle(.plain)  // CRITICAL: Removes default button styling
    .frame(width: min(302, geometry.size.width * 0.25), height: 50)
    .background(.black)
    .cornerRadius(16)

    // Next button - Gray background, white text
    Button(action: { onboardingState.nextPage() }) {
        Text("Next")
            .font(Font.custom("Arial", size: min(30, geometry.size.height * 0.048)).weight(.bold))
            .foregroundColor(.white)
    }
    .buttonStyle(.plain)  // CRITICAL: Removes default button styling
    .frame(width: min(302, geometry.size.width * 0.25), height: 50)
    .background(Color(red: 0.85, green: 0.85, blue: 0.85))
    .cornerRadius(16)
}
```

**Key Rules**:
- MUST use `.buttonStyle(.plain)` to remove default macOS button styling
- Skip button: Black background (`.black`) + white text
- Next button: Gray background (`Color(red: 0.85, green: 0.85, blue: 0.85)`) + white text
- Go Back button (if needed): Gray background (`Color(red: 0.5, green: 0.5, blue: 0.5)`) + white text
- Keep it simple: No nested VStacks, no description text below buttons
- Button height: 50px fixed
- Button width: Responsive `min(302, geometry.size.width * 0.25)`

## Layout Structure

All onboarding pages should follow this structure:

```swift
GeometryReader { geometry in
    ScrollView {
        VStack(spacing: 0) {
            // Top whitespace
            Spacer()
                .frame(height: max(20, geometry.size.height * 0.03))

            // Progress header (if applicable)
            VStack(spacing: 16) {
                Text("Configure your app")
                    .font(Font.custom("Arial", size: min(50, geometry.size.height * 0.08)).weight(.bold))
                    .foregroundColor(.black)

                // Progress indicator here
            }
            .padding(.bottom, max(20, geometry.size.height * 0.03))

            // Content area
            VStack(alignment: .leading, spacing: 6) {
                // Page-specific content
            }
            .padding(.horizontal, 60)
            .padding(.bottom, max(20, geometry.size.height * 0.03))

            // Navigation buttons
            HStack(alignment: .center, spacing: min(400, geometry.size.width * 0.3)) {
                // Buttons here
            }
            .padding(.horizontal, 60)
            .padding(.bottom, max(20, geometry.size.height * 0.03))
        }
        .frame(maxWidth: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.white)
}
```

## Responsive Font Sizing

Use `min()` for responsive font sizes based on window height:

```swift
.font(Font.custom("Arial", size: min(50, geometry.size.height * 0.08)).weight(.bold))  // Large title
.font(Font.custom("Arial", size: min(30, geometry.size.height * 0.048)).weight(.bold)) // Headings
.font(Font.custom("Arial", size: min(28, geometry.size.height * 0.044)))              // Body text
.font(Font.custom("Arial", size: min(25, geometry.size.height * 0.04)).weight(.bold)) // Sub-headings
```

## Color Palette

- **Black**: `.black` - Active elements, primary buttons, active step indicators
- **Gray**: `Color(red: 0.85, green: 0.85, blue: 0.85)` - Inactive elements, text fields, secondary buttons
- **White**: `.white` - Button text, background, active step numbers
- **Success Green**: `Color(red: 0.91, green: 0.96, blue: 0.91)` - Success message backgrounds
- **Error Red**: `Color(red: 1.0, green: 0.92, blue: 0.93)` - Error message backgrounds

## Critical Implementation Notes

1. **ALWAYS use `.buttonStyle(.plain)`** on buttons to remove default macOS styling
2. **ALWAYS use `.textFieldStyle(.plain)`** on text fields to remove borders
3. **Use ZStack for progress indicator** to layer lines behind circles seamlessly
4. **Use GeometryReader** for responsive layouts that work at all window sizes
5. **Keep button structure simple** - no unnecessary nested VStacks or extra text
6. **Follow the exact color values** - consistency is critical for professional appearance

## Reference Implementation

See [OnboardingTranscriptionSetupView.swift](Minutly/OnboardingTranscriptionSetupView.swift) for complete reference implementation of these design patterns.
