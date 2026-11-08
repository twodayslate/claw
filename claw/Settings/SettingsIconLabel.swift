import SwiftUI
import SimpleCommon

/// Resolves semantic and custom colors before choosing contrasting controls.
struct SettingsColorContrast {
    private let red: Double
    private let green: Double
    private let blue: Double

    init(background: Color, environment: EnvironmentValues) {
        let color = background.resolve(in: environment)
        let surface = Color(uiColor: .secondarySystemGroupedBackground).resolve(in: environment)
        let opacity = Double(color.opacity)
        func composite(_ component: Float, over surface: Float) -> Double {
            min(1, max(0, Double(component) * opacity + Double(surface) * (1 - opacity)))
        }
        red = composite(color.linearRed, over: surface.linearRed)
        green = composite(color.linearGreen, over: surface.linearGreen)
        blue = composite(color.linearBlue, over: surface.linearBlue)
    }

    private var luminance: Double {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    var foreground: Color {
        // Pick whichever of black and white has the higher contrast ratio.
        luminance > 0.179 ? .black : .white
    }

    var switchTint: Color {
        // A switch's thumb is always white. Keep its on-track at least 3:1
        // against white, retaining the selected hue for lighter accents.
        let scale = luminance > 0.3 ? 0.3 / luminance : 1
        return Color(.sRGBLinear, red: red * scale, green: green * scale, blue: blue * scale)
    }
}

struct SettingsIconLabel: View {
    @Environment(\.self) private var environment

    var background: Color
    var systemImage: String
    var text: String

    var body: some View {
        SimpleIconLabel(
            iconBackgroundColor: background,
            iconColor: SettingsColorContrast(background: background, environment: environment).foreground,
            systemImage: systemImage,
            text: text
        )
    }
}
