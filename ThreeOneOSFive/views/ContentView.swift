import SwiftUI

// MARK: - Main Menu View (replaces all 3105 original views)
struct ContentView: View {
    @StateObject private var vm = FFXCMenuViewModel()
    @State private var showLog = false
    @State private var searchText = ""
    @State private var showAllOn = false

    private var filteredFeatures: [FFXCFeature] {
        if searchText.isEmpty { return vm.features }
        return vm.features.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color.ffxcBackground.ignoresSafeArea()

            // Ambient glow
            RadialGradient(
                colors: [Color.ffxcAccent.opacity(0.08), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                gameSelector
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)

                statusRow
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)

                searchBar
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)

                featureList

                bottomSection
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundStyle(
                            LinearGradient(colors: [.ffxcAccent, .blue], startPoint: .top, endPoint: .bottom)
                        )
                        .font(.system(size: 20, weight: .bold))
                    Text("3105x")
                        .font(FFXCFont.title)
                        .foregroundStyle(
                            LinearGradient(colors: [.ffxcAccent, .white], startPoint: .leading, endPoint: .trailing)
                        )
                }
                Text("Free Fire Patch Manager")
                    .font(FFXCFont.caption)
                    .foregroundColor(.ffxcTextSecondary)
            }

            Spacer()

            // Log toggle button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showLog.toggle() }
            } label: {
                Image(systemName: showLog ? "terminal.fill" : "terminal")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(showLog ? .ffxcAccent : .ffxcTextSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color.ffxcCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(showLog ? Color.ffxcAccent.opacity(0.5) : Color.ffxcBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Game Selector
    private var gameSelector: some View {
        GameSelectorCard(selected: $vm.selectedGame)
    }

    // MARK: - Status row
    private var statusRow: some View {
        HStack {
            StatusBadge(status: vm.injectStatus.badge, label: vm.injectStatus.label)
            Spacer()
            if let path = vm.containerPath {
                Text(String(path.suffix(30)))
                    .font(FFXCFont.mono)
                    .foregroundColor(.ffxcTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(vm.features.filter(\.isOn).count)/\(vm.features.count) ON")
                .font(FFXCFont.caption)
                .foregroundColor(.ffxcAccent)
        }
    }

    // MARK: - Search bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(.ffxcTextSecondary)
            TextField("Search features...", text: $searchText)
                .font(FFXCFont.body)
                .foregroundColor(.ffxcTextPrimary)
                .tint(.ffxcAccent)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.ffxcCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.ffxcBorder, lineWidth: 1)
        )
    }

    // MARK: - Feature list
    private var featureList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 2) {
                // Log panel (if shown)
                if showLog {
                    InlineLogView(entries: vm.logEntries)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Quick actions
                HStack(spacing: 8) {
                    quickButton(label: "All ON", icon: "checkmark.circle.fill", color: .ffxcGreen) {
                        vm.setAll(on: true)
                    }
                    quickButton(label: "All OFF", icon: "xmark.circle.fill", color: .ffxcRed) {
                        vm.setAll(on: false)
                    }
                    quickButton(label: "Clear Log", icon: "trash.fill", color: .ffxcTextSecondary) {
                        vm.clearLog()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 6)

                // Feature section header
                HStack {
                    Text("FEATURES  (\(filteredFeatures.count))")
                        .font(FFXCFont.caption)
                        .foregroundColor(.ffxcTextSecondary)
                        .tracking(1.5)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 4)

                // Feature rows inside a card
                FFXCCard {
                    VStack(spacing: 0) {
                        ForEach(filteredFeatures) { feature in
                            FeatureToggleRow(feature: feature) {
                                vm.toggleFeature(id: feature.id)
                            }
                            if feature.id != filteredFeatures.last?.id {
                                Divider()
                                    .background(Color.ffxcBorder)
                                    .padding(.horizontal, 14)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Bottom section: inject button
    private var bottomSection: some View {
        VStack(spacing: 10) {
            if case .failed(let msg) = vm.injectStatus {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.ffxcRed)
                    Text(msg)
                        .font(FFXCFont.caption)
                        .foregroundColor(.ffxcRed)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.ffxcRed.opacity(0.12))
                .clipShape(Capsule())
                .transition(.opacity)
            }

            InjectButton(
                status: vm.injectStatus,
                isInjected: vm.isInjected,
                onInject: { vm.inject() },
                onNeutralize: { vm.neutralize() }
            )
        }
    }

    // MARK: - Quick action button helper
    private func quickButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(FFXCFont.caption)
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(color.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}
