import SwiftUI

// MARK: - ContentView
struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    // Game selection
    @AppStorage("selected_game") private var selectedGame: String = "freeFire"

    // Feature settings
    // headshot: 0 = off, 1-100 = on with this value
    @AppStorage("feat_headshot_val")   private var headshotValue: Double  = 0    // 0 = disabled
    @AppStorage("feat_fov_radius")     private var fovRadius: Double      = 0    // 0 = disabled
    @AppStorage("feat_aim_target")     private var aimTarget: String      = "head"

    // UI state
    @State private var statusMessage: String   = "Đang kiểm tra..."
    @State private var resolvedPath: String    = ""
    @State private var isInjected: Bool        = false
    @State private var isProcessing: Bool      = false
    @State private var glowPulse: Bool         = false
    @State private var containerURL: URL?      = nil
    @State private var foundBundleID: String   = ""

    // Derived toggle states from values
    private var headshotOn: Bool { headshotValue > 0 }
    private var fovOn: Bool { fovRadius > 0 }

    let aimTargets: [(key: String, label: String)] = [
        ("head",  "\u{1F3AF} Đầu"),
        ("chest", "\u{1F4A2} Ngực"),
        ("belly", "\u{1F538} Bụng"),
        ("auto",  "\u{26A1} Tự Động")
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.04, green: 0.04, blue: 0.10),
                    Color(red: 0.06, green: 0.08, blue: 0.18)
                ]),
                startPoint: .top, endPoint: .bottom
            ).edgesIgnoringSafeArea(.all)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    headerView
                    gameSelectorView
                    containerCard
                    featureCard
                    injectButtonView
                    statusView
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            resolveContainer()
        }
        .onChange(of: selectedGame) { _ in
            resolveContainer()
        }
    }

    // MARK: - Header
    var headerView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        gradient: Gradient(colors: [
                            isInjected ? Color.green.opacity(0.35) : Color.red.opacity(0.25),
                            Color.clear
                        ]),
                        center: .center, startRadius: 5, endRadius: 60
                    ))
                    .frame(width: 120, height: 120)
                    .scaleEffect(glowPulse ? 1.12 : 0.88)
                    .animation(Animation.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: glowPulse)

                Image(systemName: isInjected ? "checkmark.shield.fill" : "shield.slash.fill")
                    .font(.system(size: 58, weight: .bold))
                    .foregroundStyle(LinearGradient(
                        colors: isInjected ? [.green, .mint] : [.red, .orange],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }
            .padding(.top, 24)
            .onAppear { glowPulse = true }

            Text("YABAO PATCHER")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(2)

            Text("Free Fire Cheat Injector")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    // MARK: - Game Selector
    var gameSelectorView: some View {
        HStack(spacing: 10) {
            ForEach([("freeFire", "Free Fire", "flame.fill"),
                     ("freeFireMax", "FF MAX", "flame.circle.fill")], id: \.0) { id, name, icon in
                Button(action: { selectedGame = id }) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                        Text(name).fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedGame == id
                                  ? LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                                  : LinearGradient(colors: [Color.white.opacity(0.08), Color.clear], startPoint: .top, endPoint: .bottom))
                    )
                    .foregroundColor(selectedGame == id ? .white : .gray)
                    .font(.subheadline)
                }
            }
        }
        .padding(6)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
    }

    // MARK: - Container Card
    var containerCard: some View {
        HStack(spacing: 10) {
            Image(systemName: containerURL != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(containerURL != nil ? .green : .red)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(containerURL != nil ? "\(foundBundleID)" : "Không tìm thấy game")
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(containerURL != nil ? .green : .red)
                Text(resolvedPath.isEmpty ? "Container chưa được phát hiện" : resolvedPath)
                    .font(.caption2).foregroundColor(.gray)
                    .lineLimit(2).truncationMode(.middle)
            }
            Spacer()
            if containerURL == nil {
                Button(action: {
                    appState.runKernelExploitIfNeeded()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { resolveContainer() }
                }) {
                    Text("Thử lại")
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.blue.opacity(0.3))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Feature Card
    var featureCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\u{26A1} CÀI ĐẶT CHỨC NĂNG")
                    .font(.caption2).fontWeight(.black).foregroundColor(.gray).tracking(2)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.white.opacity(0.04))

            // ── Headshot ──
            VStack(spacing: 0) {
                // Toggle row: tap icon to toggle on/off
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.18)).frame(width: 36, height: 36)
                        Image(systemName: "scope").foregroundColor(.red).font(.system(size: 16, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto Headshot").font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                        Text(headshotOn ? "Bắt đầu: \(Int(headshotValue))%" : "Tắt").font(.caption2).foregroundColor(.gray)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { headshotOn },
                        set: { on in headshotValue = on ? 80 : 0 }
                    )).toggleStyle(SwitchToggleStyle(tint: .green)).labelsHidden()
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                if headshotOn {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Tỉ lệ").font(.caption2).foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(headshotValue))%").font(.caption2).fontWeight(.bold).foregroundColor(.red)
                        }
                        Slider(value: $headshotValue, in: 10...100, step: 10).accentColor(.red)
                    }
                    .padding(.horizontal, 16).padding(.bottom, 12)
                    .background(Color.white.opacity(0.03))
                    .transition(.opacity)
                }
            }

            Divider().background(Color.white.opacity(0.07))

            // ── FOV Radius ──
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.18)).frame(width: 36, height: 36)
                        Image(systemName: "circle.dashed").foregroundColor(.blue).font(.system(size: 16, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FOV Aim Assist").font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                        Text(fovOn ? "Bán kính: \(Int(fovRadius))" : "Tắt").font(.caption2).foregroundColor(.gray)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { fovOn },
                        set: { on in fovRadius = on ? 50 : 0 }
                    )).toggleStyle(SwitchToggleStyle(tint: .green)).labelsHidden()
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                if fovOn {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Bán kính").font(.caption2).foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(fovRadius))").font(.caption2).fontWeight(.bold).foregroundColor(.blue)
                        }
                        Slider(value: $fovRadius, in: 10...100, step: 5).accentColor(.blue)
                    }
                    .padding(.horizontal, 16).padding(.bottom, 12)
                    .background(Color.white.opacity(0.03))
                    .transition(.opacity)
                }
            }

            Divider().background(Color.white.opacity(0.07))

            // ── Aim Target ──
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark").foregroundColor(.purple)
                    Text("Vị trí Aim").font(.subheadline).fontWeight(.semibold).foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 12)

                HStack(spacing: 6) {
                    ForEach(aimTargets, id: \.key) { t in
                        Button(action: { aimTarget = t.key }) {
                            Text(t.label)
                                .font(.caption2).fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8)
                                    .fill(aimTarget == t.key
                                          ? LinearGradient(colors: [.purple, .indigo], startPoint: .leading, endPoint: .trailing)
                                          : LinearGradient(colors: [Color.white.opacity(0.07), Color.clear], startPoint: .top, endPoint: .bottom)))
                                .foregroundColor(aimTarget == t.key ? .white : .gray)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 12)
            }
        }
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .animation(.easeInOut(duration: 0.2), value: headshotOn)
        .animation(.easeInOut(duration: 0.2), value: fovOn)
    }

    // MARK: - Inject Button
    var injectButtonView: some View {
        Button(action: handleInjectTap) {
            HStack(spacing: 10) {
                if isProcessing {
                    ProgressView().tint(.white).scaleEffect(0.85)
                    Text("Đang xử lý...").fontWeight(.black)
                } else if isInjected {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                    Text("KHÔI PHỤC").fontWeight(.black).tracking(1)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("INJECT NGAY").fontWeight(.black).tracking(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Group {
                if isProcessing {
                    LinearGradient(colors: [.gray, .gray.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                } else if isInjected {
                    LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                } else {
                    LinearGradient(colors: [.green, Color(red: 0.0, green: 0.8, blue: 0.4)], startPoint: .leading, endPoint: .trailing)
                }
            })
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: isInjected ? .orange.opacity(0.4) : .green.opacity(0.4), radius: 12, x: 0, y: 5)
        }
        .disabled(isProcessing || containerURL == nil)
        .opacity(containerURL == nil ? 0.5 : 1.0)
    }

    // MARK: - Status
    var statusView: some View {
        HStack(spacing: 8) {
            Circle().fill(statusColor).frame(width: 7, height: 7)
            Text(statusMessage).font(.caption).foregroundColor(.gray)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    var statusColor: Color {
        if statusMessage.contains("thành công") || statusMessage.contains("Đã inject") || statusMessage.contains("Sẵn sàng") { return .green }
        if statusMessage.contains("Lỗi") || statusMessage.contains("Không tìm") { return .red }
        return .orange
    }

    // MARK: - Core Logic

    private func resolveContainer() {
        let primary   = selectedGame == "freeFireMax" ? "com.dts.freefiremax" : "com.dts.freefireth"
        let secondary = selectedGame == "freeFireMax" ? "com.dts.freefireth" : "com.dts.freefiremax"

        var resolved: String? = nil
        var resolvedBID: String = ""

        for bid in [primary, secondary] {
            if let p = ContainerStore.resolveAppContainerPath(bundleID: bid) {
                resolved = p; resolvedBID = bid; break
            }
        }

        DispatchQueue.main.async {
            if let p = resolved {
                containerURL = URL(fileURLWithPath: p)
                foundBundleID = resolvedBID
                resolvedPath = p
                checkInjectionState()
            } else {
                containerURL = nil
                foundBundleID = ""
                resolvedPath = ""
                isInjected = false
                statusMessage = "Không tìm thấy Free Fire. Kiểm tra TrollStore hoặc exploit."
            }
        }
    }

    private func checkInjectionState() {
        guard let url = containerURL else { isInjected = false; return }
        let fm = FileManager.default
        let doc  = url.appendingPathComponent("Documents/Assembly-CSharp-patch.bytes")
        let root = url.appendingPathComponent("Assembly-CSharp-patch.bytes")
        let injected = fm.fileExists(atPath: doc.path) || fm.fileExists(atPath: root.path)
        isInjected = injected
        statusMessage = injected ? "Đã inject! Thoát + mở lại FF để áp dụng." : "Sẵn sàng inject."
    }

    private func handleInjectTap() {
        guard !isProcessing, let url = containerURL else { return }
        isProcessing = true
        let action = isInjected ? "restore" : "inject"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = action == "inject" ? performInject(containerURL: url) : performRestore(containerURL: url)
            DispatchQueue.main.async {
                isProcessing = false
                statusMessage = result.1
                checkInjectionState()
            }
        }
    }

    // MARK: - Inject
    private func performInject(containerURL url: URL) -> (Bool, String) {
        // Load patch bytes from bundle
        let pData: Data
        if let p = Bundle.main.path(forResource: "Assembly-CSharp-patch", ofType: "bytes"),
           let d = try? Data(contentsOf: URL(fileURLWithPath: p)), !d.isEmpty {
            pData = d
        } else {
            let alt = Bundle.main.bundleURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
            if let d = try? Data(contentsOf: alt), !d.isEmpty {
                pData = d
            } else {
                return (false, "Lỗi: Không tìm thấy Assembly-CSharp-patch.bytes trong bundle app.")
            }
        }

        // Build localConfig.json with exact format the patch reads
        // Format: {"testCodePatch":true,"headshot":<int>,"aimTarget":"<str>","fovRadius":<int>}
        // headshot = 0 means disabled, > 0 means enabled with that percentage
        var cfg: [String: Any] = ["testCodePatch": true]
        cfg["headshot"]  = Int(headshotValue)   // 0 = off, 10-100 = on
        cfg["aimTarget"] = aimTarget
        if fovOn {
            cfg["fovRadius"] = Int(fovRadius)
        }

        guard let configData = try? JSONSerialization.data(withJSONObject: cfg),
              let configStr = String(data: configData, encoding: .utf8) else {
            return (false, "Lỗi: Không tạo được localConfig.json.")
        }

        let fm = FileManager.default
        let docs = url.appendingPathComponent("Documents")
        if !fm.fileExists(atPath: docs.path) {
            try? fm.createDirectory(at: docs, withIntermediateDirectories: true)
        }

        // Write patch.bytes to Documents/ and container root
        var ok = false
        for dest in [docs.appendingPathComponent("Assembly-CSharp-patch.bytes"),
                     url.appendingPathComponent("Assembly-CSharp-patch.bytes")] {
            if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
            if (try? pData.write(to: dest, options: .atomic)) != nil { ok = true }
        }

        // Write localConfig.json to same locations
        let cfgBytes = configStr.data(using: .utf8)!
        for dest in [docs.appendingPathComponent("localConfig.json"),
                     url.appendingPathComponent("localConfig.json")] {
            if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
            _ = try? cfgBytes.write(to: dest, options: .atomic)
        }

        guard ok else {
            return (false, "Lỗi: Ghi file thất bại. Kiểm tra quyền TrollStore.")
        }
        return (true, "Inject thành công! Config: \(configStr)")
    }

    // MARK: - Restore
    private func performRestore(containerURL url: URL) -> (Bool, String) {
        let fm   = FileManager.default
        let docs = url.appendingPathComponent("Documents")
        for name in ["Assembly-CSharp-patch.bytes", "localConfig.json", "Assembly-CSharp-patch.bytes.bak"] {
            for base in [docs, url] {
                let t = base.appendingPathComponent(name)
                if fm.fileExists(atPath: t.path) { try? fm.removeItem(at: t) }
            }
        }
        return (true, "Đã khôi phục. Free Fire sạch bản gốc.")
    }
}
