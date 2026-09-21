import SwiftUI

// MARK: - Feature toggle row
struct FeatureToggleRow: View {
    let feature: FFXCFeature
    let onToggle: () -> Void

    @State private var pressed = false

    var body: some View {
        HStack(spacing: 14) {
            // Icon box
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(feature.isOn ? Color.ffxcAccent.opacity(0.18) : Color.ffxcCardAlt)
                    .frame(width: 38, height: 38)
                Image(systemName: feature.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(feature.isOn ? .ffxcAccent : .ffxcTextSecondary)
            }

            // Title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(FFXCFont.heading)
                    .foregroundColor(feature.isOn ? .ffxcTextPrimary : .ffxcTextSecondary)
                Text(feature.subtitle)
                    .font(FFXCFont.caption)
                    .foregroundColor(.ffxcTextSecondary)
            }

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { feature.isOn },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .tint(.ffxcAccent)
            .scaleEffect(0.85)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(feature.isOn ? Color.ffxcAccent.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(pressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: pressed)
        .animation(.easeInOut(duration: 0.2), value: feature.isOn)
        .onTapGesture { onToggle() }
        .onLongPressGesture(minimumDuration: 0) {} onPressingChanged: { p in pressed = p }
    }
}

// MARK: - Game selector card
struct GameSelectorCard: View {
    @Binding var selected: GameTarget

    var body: some View {
        HStack(spacing: 0) {
            ForEach(GameTarget.allCases) { game in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selected = game }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: game.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(game.displayName)
                            .font(FFXCFont.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(selected == game ? .black : .ffxcTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(selected == game ? Color.ffxcAccent : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.ffxcCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.ffxcBorder, lineWidth: 1)
        )
    }
}

// MARK: - Inject button
struct InjectButton: View {
    let status: InjectStatus
    let isInjected: Bool
    let onInject: () -> Void
    let onNeutralize: () -> Void

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            // Neutralize button
            Button {
                onNeutralize()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.shield.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("CLEAR")
                        .font(FFXCFont.heading)
                }
                .foregroundColor(isInjected ? .ffxcRed : .ffxcTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isInjected ? Color.ffxcRed.opacity(0.18) : Color.ffxcCard)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isInjected ? Color.ffxcRed.opacity(0.5) : Color.ffxcBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Inject button
            Button {
                onInject()
            } label: {
                HStack(spacing: 8) {
                    if status == .injecting || status == .scanning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(0.75)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text(status == .injecting ? "INJECTING..." : status == .scanning ? "SCANNING..." : "INJECT")
                        .font(FFXCFont.heading)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Group {
                        if status == .injecting || status == .scanning {
                            LinearGradient(colors: [Color.ffxcAccent.opacity(0.6), Color.ffxcAccent.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                        } else {
                            LinearGradient(colors: [Color.ffxcAccent, Color(red: 0.0, green: 0.6, blue: 1.0)], startPoint: .leading, endPoint: .trailing)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .scaleEffect(pulse ? 1.03 : 1.0)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            }
            .buttonStyle(.plain)
            .disabled(status == .injecting || status == .scanning)
            .onAppear { pulse = !isInjected }
            .onChange(of: isInjected) { v in pulse = !v }
        }
    }
}

// MARK: - Log view
struct InlineLogView: View {
    let entries: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(FFXCFont.mono)
                            .foregroundColor(logColor(for: line))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line)
                    }
                }
                .padding(10)
            }
            .onChange(of: entries.count) { _ in
                if let last = entries.last {
                    withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
        }
        .frame(height: 130)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.ffxcBorder, lineWidth: 1)
        )
    }

    private func logColor(for line: String) -> Color {
        if line.contains("complete") || line.contains("success") || line.contains("cleared") { return .ffxcGreen }
        if line.contains("WARNING") || line.contains("denied") || line.contains("failed") { return .ffxcRed }
        if line.contains("inject:") { return .ffxcAccent }
        return .ffxcTextSecondary
    }
}
