import SwiftUI

// MARK: - Feature Model
struct CheatConfig: Codable {
    var testCodePatch: Bool = true
    var headshotRate: Int = 100
    var fovRadius: Int = 50
    var aimTarget: String = "head"
    
    enum CodingKeys: String, CodingKey {
        case testCodePatch
        case headshotRate
        case fovRadius
        case aimTarget
    }
}

// MARK: - ContentView
struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    
    // Game selection
    @AppStorage("selected_game") private var selectedGame: String = "freeFire"
    
    // Feature toggles
    @AppStorage("feat_patch_enabled") private var patchEnabled: Bool = false
    @AppStorage("feat_headshot") private var headshotEnabled: Bool = false
    @AppStorage("feat_headshot_rate") private var headshotRate: Double = 100
    @AppStorage("feat_fov") private var fovEnabled: Bool = false
    @AppStorage("feat_fov_radius") private var fovRadius: Double = 50
    @AppStorage("feat_aim_target") private var aimTarget: String = "head"
    
    // UI state
    @State private var statusMessage: String = "Sẵn sàng"
    @State private var resolvedPath: String = "Đang tìm game..."
    @State private var isProcessing: Bool = false
    @State private var isInjected: Bool = false
    @State private var isAnimatingGlow: Bool = false
    @State private var updatingProgrammatically: Bool = false
    
    let targetBundleIDs = ["com.dts.freefireth", "com.dts.freefiremax"]
    
    let aimTargets: [(key: String, label: String)] = [
        ("head", "🎯 Đầu"),
        ("chest", "💢 Ngực"),
        ("belly", "🔘 Bụng"),
        ("auto", "⚡ Tự Động")
    ]
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.04, green: 0.04, blue: 0.10), Color(red: 0.06, green: 0.08, blue: 0.18)]),
                startPoint: .top, endPoint: .bottom
            ).edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 18) {
                    headerView
                    gameSelector
                    containerPathCard
                    featureSection
                    injectButton
                    statusBar
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            refreshState()
            if appState.kernelExploitApplicable && findAppBundle() == nil {
                appState.runKernelExploitIfNeeded()
            }
        }
    }
    
    // MARK: - Header
    var headerView: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        gradient: Gradient(colors: [isInjected ? Color.green.opacity(0.4) : Color.red.opacity(0.3), Color.clear]),
                        center: .center, startRadius: 10, endRadius: 55
                    ))
                    .frame(width: 110, height: 110)
                    .scaleEffect(isAnimatingGlow ? 1.1 : 0.9)
                    .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimatingGlow)
                
                Image(systemName: isInjected ? "checkmark.shield.fill" : "shield.slash.fill")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isInjected ? [.green, .mint] : [.red, .orange],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }
            .onAppear { isAnimatingGlow = true }
            .padding(.top, 20)
            
            Text("YABAO CHEAT")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.8)], startPoint: .top, endPoint: .bottom))
            
            Text("Free Fire Injector v3.1.0.5")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Game Selector
    var gameSelector: some View {
        HStack(spacing: 12) {
            ForEach([("freeFire", "Free Fire", "flame.fill"), ("freeFireMax", "FF MAX", "flame.circle.fill")], id: \.0) { bid, name, icon in
                Button(action: { selectedGame = bid }) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                        Text(name).fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedGame == bid
                                  ? LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                                  : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom))
                    )
                    .foregroundColor(selectedGame == bid ? .white : .gray)
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }
    
    // MARK: - Container Path
    var containerPathCard: some View {
        HStack(spacing: 10) {
            Image(systemName: findAppBundle() != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(findAppBundle() != nil ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(findAppBundle() != nil ? "Game đã được tìm thấy" : "Không tìm thấy game")
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(findAppBundle() != nil ? .green : .red)
                Text(resolvedPath)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    // MARK: - Feature Section
    var featureSection: some View {
        VStack(spacing: 1) {
            sectionHeader("⚡ CHỨC NĂNG")
            
            // Main Patch Toggle
            featureRow(
                icon: "bolt.fill", iconColor: .yellow,
                title: "Kích hoạt Patch",
                subtitle: "Assembly-CSharp-patch.bytes",
                isOn: $patchEnabled
            )
            
            Divider().background(Color.white.opacity(0.08))
            
            // Headshot toggle + rate
            VStack(spacing: 0) {
                featureRow(
                    icon: "scope", iconColor: .red,
                    title: "Auto Headshot",
                    subtitle: "Ngắm thẳng đầu đối thủ",
                    isOn: $headshotEnabled
                )
                if headshotEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Tỉ lệ Headshot").font(.caption2).foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(headshotRate))%").font(.caption2).fontWeight(.bold).foregroundColor(.red)
                        }
                        Slider(value: $headshotRate, in: 10...100, step: 10)
                            .accentColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .background(Color.white.opacity(0.03))
                }
            }
            
            Divider().background(Color.white.opacity(0.08))
            
            // FOV toggle + radius
            VStack(spacing: 0) {
                featureRow(
                    icon: "circle.dashed", iconColor: .blue,
                    title: "FOV Aim Assist",
                    subtitle: "Vùng nhắm mục tiêu",
                    isOn: $fovEnabled
                )
                if fovEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Bán kính FOV").font(.caption2).foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(fovRadius))").font(.caption2).fontWeight(.bold).foregroundColor(.blue)
                        }
                        Slider(value: $fovRadius, in: 10...100, step: 5)
                            .accentColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .background(Color.white.opacity(0.03))
                }
            }
            
            Divider().background(Color.white.opacity(0.08))
            
            // Aim Target picker
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundColor(.purple)
                    Text("Vị trí Aim").font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                HStack(spacing: 8) {
                    ForEach(aimTargets, id: \.key) { target in
                        Button(action: { aimTarget = target.key }) {
                            Text(target.label)
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(aimTarget == target.key
                                              ? LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing)
                                              : LinearGradient(colors: [Color.white.opacity(0.08), Color.clear], startPoint: .top, endPoint: .bottom))
                                )
                                .foregroundColor(aimTarget == target.key ? .white : .gray)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.black)
                .foregroundColor(.gray)
                .tracking(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
    }
    
    func featureRow(icon: String, iconColor: Color, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 16, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                Text(subtitle).font(.caption2).foregroundColor(.gray)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Inject Button
    var injectButton: some View {
        VStack(spacing: 10) {
            Button(action: {
                guard !isProcessing else { return }
                isProcessing = true
                DispatchQueue.global(qos: .userInitiated).async {
                    let result: (Bool, String)
                    if isInjected {
                        result = restorePatch()
                    } else {
                        result = applyPatch()
                    }
                    DispatchQueue.main.async {
                        isProcessing = false
                        statusMessage = result.1
                        isInjected = result.0 ? !isInjected : isInjected
                        refreshState()
                    }
                }
            }) {
                HStack(spacing: 10) {
                    if isProcessing {
                        ProgressView().tint(.white).scaleEffect(0.8)
                        Text("Đang xử lý...")
                    } else if isInjected {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                        Text("KHÔI PHỤC")
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("INJECT NGAY")
                    }
                }
                .font(.headline)
                .fontWeight(.black)
                .tracking(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if isProcessing {
                            LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                        } else if isInjected {
                            LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                        } else {
                            LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                        }
                    }
                )
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: isInjected ? .orange.opacity(0.5) : .green.opacity(0.5), radius: 10, x: 0, y: 4)
            }
            .disabled(isProcessing)
        }
    }
    
    // MARK: - Status Bar
    var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusMessage.contains("thành công") || statusMessage.contains("Sẵn") ? Color.green : (statusMessage.contains("Lỗi") ? Color.red : Color.orange))
                .frame(width: 7, height: 7)
            Text(statusMessage)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Core Logic
    
    private func refreshState() {
        if let appInfo = findAppBundle() {
            let docPatch = appInfo.url.appendingPathComponent("Documents/Assembly-CSharp-patch.bytes")
            let rootPatch = appInfo.url.appendingPathComponent("Assembly-CSharp-patch.bytes")
            isInjected = FileManager.default.fileExists(atPath: docPatch.path) || FileManager.default.fileExists(atPath: rootPatch.path)
            resolvedPath = appInfo.url.path
            if isInjected { statusMessage = "Đã inject - Free Fire đã được patch!" }
        } else {
            isInjected = false
            resolvedPath = "Không tìm thấy Free Fire"
            statusMessage = "Sẵn sàng - Chưa tìm thấy game"
        }
    }
    
    private func buildLocalConfig() -> String {
        var cfg: [String: Any] = [:]
        cfg["testCodePatch"] = patchEnabled
        if headshotEnabled {
            cfg["headshot"] = true
            cfg["headshotValue"] = Int(headshotRate)
        } else {
            cfg["headshot"] = false
        }
        if fovEnabled {
            cfg["fovRadius"] = Int(fovRadius)
        }
        cfg["aimTarget"] = aimTarget
        cfg["selectedGame"] = selectedGame
        
        guard let data = try? JSONSerialization.data(withJSONObject: cfg, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else {
            return "{\"testCodePatch\":true}"
        }
        return str
    }
    
    private func applyPatch() -> (Bool, String) {
        guard let appInfo = findAppBundle() else {
            return (false, "Lỗi: Không tìm thấy game Free Fire")
        }
        
        guard let bundlePath = Bundle.main.path(forResource: "Assembly-CSharp-patch", ofType: "bytes"),
              let pData = try? Data(contentsOf: URL(fileURLWithPath: bundlePath)), !pData.isEmpty else {
            let altURL = Bundle.main.bundleURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
            guard let pData = try? Data(contentsOf: altURL), !pData.isEmpty else {
                return (false, "Lỗi: Không tìm thấy file patch trong bundle")
            }
            return writePatchFiles(appInfo: appInfo, pData: pData)
        }
        return writePatchFiles(appInfo: appInfo, pData: pData)
    }
    
    private func writePatchFiles(appInfo: (url: URL, bundleID: String), pData: Data) -> (Bool, String) {
        let container = appInfo.url
        let docs = container.appendingPathComponent("Documents")
        let fm = FileManager.default
        
        if !fm.fileExists(atPath: docs.path) {
            try? fm.createDirectory(at: docs, withIntermediateDirectories: true)
        }
        
        let configStr = buildLocalConfig()
        
        let targets: [(URL, Data)] = [
            (docs.appendingPathComponent("Assembly-CSharp-patch.bytes"), pData),
            (container.appendingPathComponent("Assembly-CSharp-patch.bytes"), pData),
            (docs.appendingPathComponent("localConfig.json"), configStr.data(using: .utf8) ?? Data()),
            (container.appendingPathComponent("localConfig.json"), configStr.data(using: .utf8) ?? Data()),
        ]
        
        var anySuccess = false
        for (url, data) in targets {
            if fm.fileExists(atPath: url.path) { try? fm.removeItem(at: url) }
            if (try? data.write(to: url, options: .atomic)) != nil { anySuccess = true }
            else { _ = fm.createFile(atPath: url.path, contents: data) }
        }
        
        if anySuccess || fm.fileExists(atPath: targets[0].0.path) {
            return (true, "Inject thành công! (\(appInfo.bundleID))")
        }
        return (false, "Lỗi: Không thể ghi file. Kiểm tra TrollStore.")
    }
    
    private func restorePatch() -> (Bool, String) {
        guard let appInfo = findAppBundle() else {
            return (false, "Không tìm thấy game để xoá patch")
        }
        
        let container = appInfo.url
        let docs = container.appendingPathComponent("Documents")
        let fm = FileManager.default
        
        for name in ["Assembly-CSharp-patch.bytes", "localConfig.json", "Assembly-CSharp-patch.bytes.bak"] {
            for base in [docs, container] {
                let url = base.appendingPathComponent(name)
                if fm.fileExists(atPath: url.path) { try? fm.removeItem(at: url) }
            }
        }
        
        return (true, "Đã khôi phục! Patch đã bị xoá.")
    }
    
    private func findAppBundle() -> (url: URL, bundleID: String)? {
        let bid = selectedGame == "freeFireMax" ? "com.dts.freefiremax" : "com.dts.freefireth"
        let all = [bid] + targetBundleIDs
        for b in all {
            if let path = ContainerStore.resolveAppContainerPath(bundleID: b) {
                return (URL(fileURLWithPath: path), b)
            }
        }
        return nil
    }
}
