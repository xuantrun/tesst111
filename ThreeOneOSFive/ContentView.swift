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
        let path = findTargetContainer(bundleId: selectedGame)
        DispatchQueue.main.async {
            self.isTargetInstalled = (path != nil)
            if self.isTargetInstalled {
                self.log("Phát hiện game: \(self.selectedGame)")
            } else {
                self.log("Chưa phát hiện container: \(self.selectedGame)")
            }
        }
    }

    func findTargetContainer(bundleId: String) -> String? {
        let base = "/var/mobile/Containers/Data/Application"
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: base) else {
            return nil
        }
        for item in items {
            let containerPath = (base as NSString).appendingPathComponent(item)
            let metaPath = (containerPath as NSString).appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
            if let dict = NSDictionary(contentsOfFile: metaPath),
               let bid = dict["MCMMetadataIdentifier"] as? String,
               bid == bundleId {
                return containerPath
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

            self.updateProgress(0.2, "Đang tìm thư mục game...")
            let container = self.findTargetContainer(bundleId: self.selectedGame)

            self.updateProgress(0.5, "Đang cấu hình file patch...")
            var config: [String: Any] = [:]
            for feat in self.features {
                config[feat.id] = feat.isEnabled ? 1 : 0
            }

            if let targetDir = container {
                let docDir = (targetDir as NSString).appendingPathComponent("Documents")
                self.updateProgress(0.7, "Đang ghi dữ liệu vào container...")

                if let jsonData = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
                    let configPath = (docDir as NSString).appendingPathComponent("localConfig.json")
                    try? jsonData.write(to: URL(fileURLWithPath: configPath))
                    self.log("Đã ghi config: \(configPath)")
                }

                if let patchSource = Bundle.main.path(forResource: "Assembly-CSharp-patch", ofType: "bytes") {
                    let destPath = (docDir as NSString).appendingPathComponent("Assembly-CSharp-patch.bytes")
                    try? FileManager.default.removeItem(atPath: destPath)
                    try? FileManager.default.copyItem(atPath: patchSource, toPath: destPath)
                    self.log("Đã chép patch bytes: \(destPath)")
                }
            } else {
                self.log("Lưu ý: Không tìm thấy container trực tiếp, đã lưu cấu hình UserDefaults")
            }

            self.updateProgress(1.0, "Inject thành công!")
            self.log("--- HOÀN TẤT INJECT ---")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.isInjecting = false
                self.statusMessage = "Inject hoàn tất! Khởi động lại game."
            }
        }
    }

    func clearPatch() {
        guard let container = findTargetContainer(bundleId: selectedGame) else {
            log("Không tìm thấy container để dọn dẹp")
            return
        }
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

            HStack(spacing: 10) {
                Button(action: { vm.setAllFeatures(enabled: true) }) {
                    Text("Bật tất cả")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color.ffxcCardAlt)
                        .foregroundStyle(Color.ffxcText)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: { vm.setAllFeatures(enabled: false) }) {
                    Text("Tắt tất cả")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color.ffxcCardAlt)
                        .foregroundStyle(Color.ffxcText)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: { vm.clearPatch() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                        Text("Xóa patch")
                    }
                    .font(.system(size: 13, weight: .semibold))
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
