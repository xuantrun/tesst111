import SwiftUI
import Combine

// MARK: - Feature model
struct FFXCFeature: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    var isEnabled: Bool
}

// MARK: - Core ViewModel
class FFXCMenuViewModel: ObservableObject {
    @Published var selectedGame = "com.dts.freefiremax"
    @Published var isTargetInstalled = false
    @Published var targetContainerPath: String? = nil
    @Published var isInjecting = false
    @Published var injectProgress: Float = 0.0
    @Published var statusMessage = "Sẵn sàng"
    @Published var logEntries: [String] = []
    @Published var features: [FFXCFeature] = []

    let availableGames = [
        ("Free Fire MAX", "com.dts.freefiremax"),
        ("Free Fire VNG", "com.dts.freefireth")
    ]

    private let defaults = UserDefaults.standard
    private let keyPrefix = "ffxc.controls.v3."

    init() {
        setupFeatures()
        checkInstalledGames()
        log("3105x Patch Manager khởi động")
        // Retry scan automatically after LaunchServices and KernelExploit stabilize
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.isTargetInstalled == false {
                self?.checkInstalledGames()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            if self?.isTargetInstalled == false {
                self?.checkInstalledGames()
            }
        }
    }

    func setupFeatures() {
        let catalog: [(String, String, String, String)] = [
            ("k0",  "Wallhack",          "Nhìn vị trí đối thủ qua vật cản",    "eye.fill"),
            ("k1",  "Aimbot Assist",     "Tự động canh hướng mục tiêu",        "scope"),
            ("k2",  "No Recoil",         "Triệt tiêu độ giật của súng",        "bolt.shield.fill"),
            ("k3",  "Speed Boost",       "Gia tăng tốc độ chạy",               "hare.fill"),
            ("k4",  "No Spread",         "Đạn bay chụm thẳng tâm",             "circle.circle.fill"),
            ("k5",  "Rapid Fire",        "Tốc độ ra đạn tối đa",               "flame.fill"),
            ("k6",  "Long Range",        "Tăng tầm bắn xa của vũ khí",         "arrow.up.forward"),
            ("k7",  "Anti-Ban Shield",   "Ẩn danh mã định danh client",        "lock.shield.fill"),
            ("k8",  "Auto Headshot",     "Ưu tiên hitbox phần đầu",            "target"),
            ("k9",  "Item Radar",        "Hiện vị trí trang bị trên map",      "location.fill"),
            ("k10", "Drone View",        "Mở rộng góc nhìn toàn cảnh",         "camera.aperture"),
            ("k11", "Fast Loot",         "Nhặt trang bị tức thì",              "hand.raised.fill"),
            ("k12", "Silent Aim",        "Đạn tự tìm mục tiêu lân cận",        "cross.fill"),
            ("k13", "No Flash",          "Loại bỏ hiệu ứng mù lóa",            "sun.max.fill"),
            ("k14", "No Smoke",          "Nhìn xuyên làn khói",                "smoke.fill"),
            ("k15", "High Jump",         "Gia tăng độ cao khi nhảy",           "arrow.up.to.line"),
            ("k16", "Fast Revive",       "Rút ngắn thời gian cứu đồng đội",    "heart.fill"),
            ("k17", "Unlimited Ammo",    "Không tốn thời gian nạp đạn",        "infinity"),
            ("k18", "Fly Hack",          "Tự do điều hướng trên không",        "airplane"),
            ("k19", "Vehicle Speed",     "Tăng vận tốc phương tiện",           "car.fill"),
            ("k20", "Gloo Wall Spam",    "Đặt bom keo không giới hạn",         "shield.fill"),
            ("k21", "ESP Box",           "Khung viền bao quanh mục tiêu",      "square"),
            ("k22", "Health Bar ESP",    "Thanh máu hiển thị trên đầu",        "waveform.path.ecg"),
            ("k23", "Distance ESP",      "Khoảng cách tính bằng mét",          "ruler.fill")
        ]

        features = catalog.map { id, title, subtitle, icon in
            let saved = defaults.bool(forKey: keyPrefix + id)
            return FFXCFeature(id: id, title: title, subtitle: subtitle, icon: icon, isEnabled: saved)
        }
    }

    func toggleFeature(_ feature: FFXCFeature) {
        if let idx = features.firstIndex(where: { $0.id == feature.id }) {
            features[idx].isEnabled.toggle()
            defaults.set(features[idx].isEnabled, forKey: keyPrefix + feature.id)
            log("Toggle [\(feature.id)] \(feature.title): \(features[idx].isEnabled ? "BẬT" : "TẮT")")
        }
    }

    func setAllFeatures(enabled: Bool) {
        for i in 0..<features.count {
            features[i].isEnabled = enabled
            defaults.set(enabled, forKey: keyPrefix + features[i].id)
        }
        log("Đã \(enabled ? "BẬT" : "TẮT") tất cả các tính năng")
    }

    func checkInstalledGames() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            self.log("🔍 Đang dò tìm container game...")

            // 1. Kiểm tra game đang chọn trước
            var foundPath = self.findTargetContainer(bundleId: self.selectedGame)
            var activeGame = self.selectedGame

            // 2. Nếu chưa thấy, tự động quét các bundle ID Free Fire khả dĩ
            if foundPath == nil {
                let alternatives = [
                    "com.dts.freefireth",
                    "com.dts.freefiremax",
                    "com.dts.freefire",
                    "com.garena.game.kgvn"
                ]
                for alt in alternatives where alt != self.selectedGame {
                    if let path = self.findTargetContainer(bundleId: alt) {
                        foundPath = path
                        activeGame = alt
                        self.log("✨ Tự động nhận diện bản: \(alt)")
                        break
                    }
                }
            }

            DispatchQueue.main.async {
                if let path = foundPath {
                    self.selectedGame = activeGame
                    self.targetContainerPath = path
                    self.isTargetInstalled = true
                    self.statusMessage = "Đã tìm thấy: \(activeGame)"
                    self.log("✅ Container: \(path)")
                } else {
                    self.isTargetInstalled = false
                    self.targetContainerPath = nil
                    self.statusMessage = "Chưa phát hiện container — Bấm 'Quét lại' hoặc Inject"
                    self.log("⚠️ Chưa tìm thấy container cho \(self.selectedGame)")
                }
            }
        }
    }

    func findTargetContainer(bundleId: String) -> String? {
        // 1. LaunchServices appInfoForBundleID (nhanh nhất, hoạt động cả trong sandbox)
        if let info = appInfoForBundleID(bundleId) as? [String: Any],
           let container = info["container"] as? String,
           !container.isEmpty {
            log("Tìm thấy qua LSApplicationProxy: \(bundleId)")
            _ = ContainerStore.grantContainerAccess(container)
            return container
        }

        // 2. LaunchServices installedAppInfo enumeration
        if let all = installedAppInfo() as? [String: [String: Any]] {
            for (bid, info) in all {
                if bid.caseInsensitiveCompare(bundleId) == .orderedSame,
                   let container = info["container"] as? String,
                   !container.isEmpty {
                    log("Tìm thấy qua LS Workspace: \(bid)")
                    _ = ContainerStore.grantContainerAccess(container)
                    return container
                }
            }
        }

        // 3. ContainerStore.resolveAppContainerPath
        if let resolved = ContainerStore.resolveAppContainerPath(bundleID: bundleId) {
            log("Tìm thấy qua ContainerStore: \(resolved)")
            _ = ContainerStore.grantContainerAccess(resolved)
            return resolved
        }

        // 4. MobileContainerManager API - MCMContainerPathForIdentifier
        var mcmErr: NSString?
        if let mcmPath = MCMContainerPathForIdentifier(2, bundleId, false, &mcmErr), !mcmPath.isEmpty {
            log("Tìm thấy qua MCMContainerPath: \(mcmPath)")
            _ = ContainerStore.grantContainerAccess(mcmPath)
            return mcmPath
        }

        // 5. MobileContainerManager API - MCMActivateContainerPath
        if let actPath = MCMActivateContainerPath(2, bundleId, false, &mcmErr), !actPath.isEmpty {
            log("Tìm thấy qua MCMActivateContainer: \(actPath)")
            _ = ContainerStore.grantContainerAccess(actPath)
            return actPath
        }

        // 6. Quét trực tiếp hệ thống file qua các root khả dụng
        let candidateRoots = [
            "/var/mobile/Containers/Data/Application",
            "/private/var/mobile/Containers/Data/Application"
        ]

        for root in candidateRoots {
            if let items = try? FileManager.default.contentsOfDirectory(atPath: root) {
                for item in items {
                    let cPath = (root as NSString).appendingPathComponent(item)
                    let metaPath = (cPath as NSString).appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")

                    var matched = false
                    if let dict = NSDictionary(contentsOfFile: metaPath),
                       let bid = dict["MCMMetadataIdentifier"] as? String,
                       bid.caseInsensitiveCompare(bundleId) == .orderedSame {
                        matched = true
                    } else if let data = try? Data(contentsOf: URL(fileURLWithPath: metaPath)),
                              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                              let bid = plist["MCMMetadataIdentifier"] as? String,
                              bid.caseInsensitiveCompare(bundleId) == .orderedSame {
                        matched = true
                    }

                    if matched {
                        log("Tìm thấy qua FS metadata: \(cPath)")
                        _ = ContainerStore.grantContainerAccess(cPath)
                        return cPath
                    }
                }
            }

            // Fallback: Duyệt inode qua ContainerStore
            let enumerated = ContainerStore.enumerateDirectories(path: root)
            for cPath in enumerated {
                if let meta = ContainerStore.readContainerMetadata(containerPath: cPath),
                   meta.bundleID.caseInsensitiveCompare(bundleId) == .orderedSame {
                    log("Tìm thấy qua Inode scan: \(cPath)")
                    _ = ContainerStore.grantContainerAccess(cPath)
                    return cPath
                }
            }
        }

        return nil
    }

    func injectPatch() {
        guard !isInjecting else { return }
        isInjecting = true
        injectProgress = 0.0
        statusMessage = "Đang chuẩn bị inject..."
        log("--- BẮT ĐẦU INJECT ---")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            self.updateProgress(0.2, "Đang định vị thư mục game...")
            var container = self.targetContainerPath ?? self.findTargetContainer(bundleId: self.selectedGame)

            // Thử quét lại nếu chưa có
            if container == nil {
                let alternatives = [
                    self.selectedGame,
                    "com.dts.freefireth",
                    "com.dts.freefiremax",
                    "com.dts.freefire",
                    "com.garena.game.kgvn"
                ]
                for alt in alternatives {
                    if let found = self.findTargetContainer(bundleId: alt) {
                        container = found
                        DispatchQueue.main.async {
                            self.selectedGame = alt
                            self.targetContainerPath = found
                            self.isTargetInstalled = true
                        }
                        break
                    }
                }
            }

            self.updateProgress(0.5, "Đang cấu hình file patch...")
            var config: [String: Any] = [:]
            for feat in self.features {
                config[feat.id] = feat.isEnabled ? 1 : 0
                self.defaults.set(feat.isEnabled ? 1 : 0, forKey: "ffxc.active." + feat.id)
            }

            let embeddedPatchBase64 = "y6K0DbIZo2ZkSUZpeC5JTEZpeEludGVyZmFjZUJyaWRnZSwgQXNzZW1ibHktQ1NoYXJwLCBWZXJzaW9uPTAuODYuMC41MTgsIEN1bHR1cmU9bmV1dHJhbCwgUHVibGljS2V5VG9rZW49bnVsbAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABjSUZpeC5XcmFwcGVyc01hbmFnZXJJbXBsLCBBc3NlbWJseS1DU2hhcnAsIFZlcnNpb249MC44Ni4wLjUxOCwgQ3VsdHVyZT1uZXV0cmFsLCBQdWJsaWNLZXlUb2tlbj1udWxsSywgQXNzZW1ibHktQ1NoYXJwLCBWZXJzaW9uPTAuODYuMC41MTgsIEN1bHR1cmU9bmV1dHJhbCwgUHVibGljS2V5VG9rZW49bnVsbAAAAAAAAAAAAA=="
            let patchData = Data(base64Encoded: embeddedPatchBase64)

            if let targetDir = container {
                _ = ContainerStore.grantContainerAccess(targetDir)
                let docDir = (targetDir as NSString).appendingPathComponent("Documents")
                try? FileManager.default.createDirectory(atPath: docDir, withIntermediateDirectories: true, attributes: nil)

                self.updateProgress(0.7, "Đang ghi dữ liệu vào container...")

                if let jsonData = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
                    let configPath = (docDir as NSString).appendingPathComponent("localConfig.json")
                    try? jsonData.write(to: URL(fileURLWithPath: configPath))
                    self.log("Đã ghi config: \(configPath)")
                }

                let destPath = (docDir as NSString).appendingPathComponent("Assembly-CSharp-patch.bytes")
                if let patchData = patchData {
                    try? FileManager.default.removeItem(atPath: destPath)
                    try? patchData.write(to: URL(fileURLWithPath: destPath))
                    self.log("Đã chép patch bytes: \(destPath)")
                } else if let patchSource = Bundle.main.path(forResource: "Assembly-CSharp-patch", ofType: "bytes") {
                    try? FileManager.default.removeItem(atPath: destPath)
                    try? FileManager.default.copyItem(atPath: patchSource, toPath: destPath)
                    self.log("Đã chép patch bytes từ bundle: \(destPath)")
                }

                self.updateProgress(1.0, "Inject thành công!")
                self.log("--- HOÀN TẤT INJECT ---")

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.isInjecting = false
                    self.statusMessage = "Inject hoàn tất! Mở Free Fire để trải nghiệm."
                }
            } else {
                // Fallback nếu máy chạy chế độ sandbox chặt
                self.updateProgress(0.85, "Lưu cấu hình hệ thống...")
                if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let localCfg = docs.appendingPathComponent("localConfig.json")
                    if let jsonData = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
                        try? jsonData.write(to: localCfg)
                    }
                    if let patchData = patchData {
                        let localPatch = docs.appendingPathComponent("Assembly-CSharp-patch.bytes")
                        try? patchData.write(to: localPatch)
                    }
                }
                self.log("Đã lưu cấu hình dự phòng. Đang thử kích hoạt game...")
                _ = openApplicationForBundleID(self.selectedGame)

                self.updateProgress(1.0, "Đã lưu cấu hình!")
                self.log("--- HOÀN TẤT (DỰ PHÒNG) ---")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.isInjecting = false
                    self.statusMessage = "Đã lưu cấu hình. Vui lòng mở game Free Fire!"
                }
            }
        }
    }

    func clearPatch() {
        guard let container = targetContainerPath ?? findTargetContainer(bundleId: selectedGame) else {
            log("Không tìm thấy container để dọn dẹp")
            return
        }
        _ = ContainerStore.grantContainerAccess(container)
        let docDir = (container as NSString).appendingPathComponent("Documents")
        let patchFile = (docDir as NSString).appendingPathComponent("Assembly-CSharp-patch.bytes")
        let configFile = (docDir as NSString).appendingPathComponent("localConfig.json")

        try? FileManager.default.removeItem(atPath: patchFile)
        try? FileManager.default.removeItem(atPath: configFile)
        log("Đã xóa file patch khỏi: \(docDir)")
        statusMessage = "Đã dọn dẹp patch thành công"
    }

    private func updateProgress(_ prog: Float, _ msg: String) {
        DispatchQueue.main.async {
            self.injectProgress = prog
            self.statusMessage = msg
            self.log(msg)
        }
    }

    func log(_ msg: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        DispatchQueue.main.async {
            self.logEntries.append("[\(timestamp)] \(msg)")
            if self.logEntries.count > 100 {
                self.logEntries.removeFirst()
            }
        }
    }
}

// MARK: - UI Components
struct FeatureToggleRow: View {
    let feature: FFXCFeature
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(feature.isEnabled ? Color.ffxcAccent.opacity(0.18) : Color.white.opacity(0.06))
                    .frame(width: 38, height: 38)

                Image(systemName: feature.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(feature.isEnabled ? Color.ffxcAccent : Color.ffxcSubtext)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(feature.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.ffxcText)

                    Text(feature.id)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.ffxcSubtext)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Text(feature.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.ffxcSubtext)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { feature.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .tint(Color.ffxcAccent)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

struct GameSelectorView: View {
    @ObservedObject var vm: FFXCMenuViewModel

    var body: some View {
        FFXCCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "gamecontroller.fill")
                        .foregroundStyle(Color.ffxcAccent)
                    Text("GAME MỤC TIÊU")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.ffxcSubtext)
                    Spacer()
                    if vm.isTargetInstalled {
                        FFXCStatusBadge(text: "ĐÃ CÀI ĐẶT", color: Color.ffxcGreen)
                    } else {
                        FFXCStatusBadge(text: "CHƯA TÌM THẤY", color: Color.ffxcRed)
                    }
                    Button(action: { vm.checkInstalledGames() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.ffxcAccent)
                            .padding(6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }

                Picker("Chọn game", selection: $vm.selectedGame) {
                    ForEach(vm.availableGames, id: \.1) { name, id in
                        Text(name).tag(id)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: vm.selectedGame) { _ in
                    vm.checkInstalledGames()
                }

                if let path = vm.targetContainerPath {
                    Text("Thư mục: \(path)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.ffxcSubtext)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct ActionButtonsView: View {
    @ObservedObject var vm: FFXCMenuViewModel

    var body: some View {
        VStack(spacing: 10) {
            Button(action: { vm.injectPatch() }) {
                HStack(spacing: 8) {
                    if vm.isInjecting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "bolt.fill")
                    }
                    Text(vm.isInjecting ? "ĐANG INJECT (\(Int(vm.injectProgress * 100))%)..." : "INJECT VÀO GAME")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.ffxcAccent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(vm.isInjecting)

            HStack(spacing: 8) {
                Button(action: { vm.setAllFeatures(enabled: true) }) {
                    Text("Bật tất cả")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color.ffxcCardAlt)
                        .foregroundStyle(Color.ffxcText)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: { vm.setAllFeatures(enabled: false) }) {
                    Text("Tắt tất cả")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color.ffxcCardAlt)
                        .foregroundStyle(Color.ffxcText)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: {
                    _ = openApplicationForBundleID(vm.selectedGame)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                        Text("Mở game")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.ffxcGreen.opacity(0.18))
                    .foregroundStyle(Color.ffxcGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: { vm.clearPatch() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                        Text("Xóa patch")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.ffxcRed.opacity(0.18))
                    .foregroundStyle(Color.ffxcRed)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

struct LogOverlayView: View {
    @ObservedObject var vm: FFXCMenuViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(vm.logEntries, id: \.self) { entry in
                        Text(entry)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.ffxcText)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.ffxcBackground)
            .navigationTitle("Nhật ký 3105x")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { isPresented = false }
                }
            }
        }
    }
}

// MARK: - Main ContentView
struct ContentView: View {
    @StateObject private var vm = FFXCMenuViewModel()
    @State private var showLog = false
    @State private var searchText = ""

    var filteredFeatures: [FFXCFeature] {
        if searchText.isEmpty {
            return vm.features
        }
        return vm.features.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.ffxcBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        GameSelectorView(vm: vm)

                        FFXCCard {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Color.ffxcSubtext)
                                TextField("Tìm kiếm tính năng...", text: $searchText)
                                    .foregroundStyle(Color.ffxcText)
                                if !searchText.isEmpty {
                                    Button(action: { searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Color.ffxcSubtext)
                                    }
                                }
                            }
                        }

                        FFXCCard {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("TÍNH NĂNG (\(vm.features.filter { $0.isEnabled }.count)/\(vm.features.count))")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.ffxcSubtext)
                                    Spacer()
                                }
                                .padding(.bottom, 6)

                                ForEach(filteredFeatures) { feat in
                                    FeatureToggleRow(feature: feat) {
                                        vm.toggleFeature(feat)
                                    }
                                    if feat.id != filteredFeatures.last?.id {
                                        Divider().background(Color.white.opacity(0.06))
                                    }
                                }
                            }
                        }

                        ActionButtonsView(vm: vm)

                        Text(vm.statusMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.ffxcSubtext)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("3105x Manager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showLog = true }) {
                        Image(systemName: "terminal.fill")
                            .foregroundStyle(Color.ffxcAccent)
                    }
                }
            }
            .sheet(isPresented: $showLog) {
                LogOverlayView(vm: vm, isPresented: $showLog)
            }
        }
    }
}
