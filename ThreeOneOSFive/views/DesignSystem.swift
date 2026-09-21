import SwiftUI

// MARK: - Color Palette
extension Color {
    static let ffxcBackground   = Color(red: 0.05, green: 0.05, blue: 0.08)
    static let ffxcCard         = Color(red: 0.10, green: 0.10, blue: 0.15)
    static let ffxcCardAlt      = Color(red: 0.13, green: 0.13, blue: 0.19)
    static let ffxcAccent       = Color(red: 0.25, green: 0.78, blue: 1.00)
    static let ffxcGreen        = Color(red: 0.25, green: 0.90, blue: 0.55)
    static let ffxcRed          = Color(red: 1.00, green: 0.35, blue: 0.35)
    static let ffxcTextPrimary  = Color.white
    static let ffxcTextSecondary = Color(white: 0.6)
    static let ffxcBorder       = Color(white: 1.0).opacity(0.08)
}

// MARK: - Typography
struct FFXCFont {
    static let title   = Font.system(size: 22, weight: .bold,   design: .rounded)
    static let heading = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let body    = Font.system(size: 13, weight: .regular, design: .rounded)
    static let caption = Font.system(size: 11, weight: .medium, design: .rounded)
    static let mono    = Font.system(size: 11, weight: .regular, design: .monospaced)
}

// MARK: - Card container
struct FFXCCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .background(Color.ffxcCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.ffxcBorder, lineWidth: 1)
            )
    }
}

// MARK: - Status badge
struct StatusBadge: View {
    enum Status { case idle, running, success, failed }
    let status: Status
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .overlay(
                    Circle().stroke(color.opacity(0.4), lineWidth: 3)
                )
            Text(label)
                .font(FFXCFont.caption)
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var color: Color {
        switch status {
        case .idle:    return Color.ffxcTextSecondary
        case .running: return Color.ffxcAccent
        case .success: return Color.ffxcGreen
        case .failed:  return Color.ffxcRed
        }
    }
}
