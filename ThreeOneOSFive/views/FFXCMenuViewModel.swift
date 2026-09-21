import SwiftUI
import Combine

// MARK: - Feature model
struct FFXCFeature: Identifiable, Equatable {
    let id: String      // key lưu UserDefaults, ví dụ "k0"
    let title: String
    let subtitle: String
    let icon: String    // SF Symbol
    var isOn: Bool = false
}

// MARK: - Game target
enum GameTarget: String, CaseIterable, Identifiable {
    case freefireMax  = "com.dts.freefiremax"
    case freefireTH   = "com.dts.freefireth"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .freefireMax: return "Free Fire MAX"
        case .freefireTH:  return "Free Fire"
        }
    }
    var icon: String {
        switch self {
        case .freefireMax: return "flame.fill"
        case .freefireTH:  return "bolt.fill"
        }
    }
}

// MARK: - Inject status
enum InjectStatus: Equatable {
    case idle
    case scanning
    case injecting
    case success
    case neutralized
    case failed(String)

    var label: String {
        switch self {
        case .idle:        return "READY"
        case .scanning:    return "SCANNING"
        case .injecting:   return "INJECTING"
        case .success:     return "ACTIVE"
        case .neutralized: return "CLEARED"
        case .failed:      return "FAILED"
        }
    }

    var badge: StatusBadge.Status {
        switch self {
        case .idle, .neutralized: return .idle
        case .scanning, .injecting: return .running
        case .success:            return .success
        case .failed:             return .failed
        }
    }
}

// MARK: - ViewModel
@MainActor
final class FFXCMenuViewModel: ObservableObject {
    // Persistence key prefix
    private static let controlsKey = "ffxc.controls.v3."
    static let selectedGameKey     = "ffxc.selectedGame"

    // Game selection
    @Published var selectedGame: GameTarget {
        didSet { UserDefaults.standard.set(selectedGame.rawValue, forKey: Self.selectedGameKey) }
    }

    // Inject state
    @Published var injectStatus: InjectStatus = .idle
    @Published var isInjected: Bool = false
    @Published var logEntries: [String] = []

    // Feature list (k0 … k23)
    @Published var features: [FFXCFeature] = FFXCMenuViewModel.defaultFeatures()

    // Container path found
    @Published var containerPath: String? = nil

    // Patch file embedded in app bundle
    private let patchFileName   = "Assembly-CSharp-patch.bytes"
    private let configFileName  = "localConfig.json"

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.selectedGameKey)
        self.selectedGame = GameTarget(rawValue: saved ?? "") ?? .freefireMax
        loadFeatureStates()
    }

    // MARK: - Persistence
    private func loadFeatureStates() {
        for i in features.indices {
            let key = Self.controlsKey + features[i].id
            features[i].isOn = UserDefaults.standard.bool(forKey: key)
        }
    }

    func saveFeatureState(feature: FFXCFeature) {
        UserDefaults.standard.set(feature.isOn, forKey: Self.controlsKey + feature.id)
    }

    func toggleFeature(id: String) {
        guard let idx = features.firstIndex(where: { $0.id == id }) else { return }
        features[idx].isOn.toggle()
        saveFeatureState(feature: features[idx])
    }

    func setAll(on: Bool) {
        for i in features.indices {
            features[i].isOn = on
            saveFeatureState(feature: features[i])
        }
    }

    // MARK: - Logging
    func log(_ msg: String) {
        let ts = DateFormatter.logFormatter.string(from: Date())
        logEntries.append("[\(ts)] \(msg)")
        if logEntries.count > 200 { logEntries.removeFirst() }
    }

    func clearLog() { logEntries.removeAll() }

    // MARK: - Container resolution using 3105 core
    func resolveContainer() -> String? {
        let basePath = "/var/mobile/Containers/Data/Application"
        let fm = FileManager.default
        guard let subdirs = try? fm.contentsOfDirectory(atPath: basePath) else {
            log("container: cannot list \(basePath)")
            return nil
        }
        for dir in subdirs {
            let containerPath = basePath + "/" + dir
            let metaPath = containerPath + "/.com.apple.mobile_container_manager.metadata.plist"
            if let data = fm.contents(atPath: metaPath),
               let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
               let bundleID = plist["MCMMetadataIdentifier"] as? String,
               bundleID == selectedGame.rawValue {
                return containerPath
            }
        }
        return nil
    }

    // MARK: - Probe access
    func probeAccess(at containerPath: String) -> Bool {
        let probePath = containerPath + "/.ffxc_access_probe"
        let data = "probe".data(using: .utf8)!
        let ok = FileManager.default.createFile(atPath: probePath, contents: data)
        if ok { try? FileManager.default.removeItem(atPath: probePath) }
        return ok
    }

    // MARK: - Build localConfig.json
    private func buildConfig() -> Data {
        var config: [String: Any] = ["testCodePatch": true]
        for f in features {
            config[f.id] = f.isOn
        }
        return (try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)) ?? Data()
    }

    // MARK: - Inject
    func inject() {
        guard injectStatus != .injecting, injectStatus != .scanning else { return }

        Task {
            injectStatus = .scanning
            log("scan: looking for \(selectedGame.rawValue)")

            guard let cPath = await Task.detached(priority: .userInitiated) {
                self.resolveContainer()
            }.value else {
                log("scan: container not found — is \(selectedGame.displayName) installed?")
                injectStatus = .failed("Container not found")
                return
            }

            containerPath = cPath
            log("scan: found container at \(cPath)")

            guard probeAccess(at: cPath) else {
                log("inject: access denied — check entitlement")
                injectStatus = .failed("Access denied")
                return
            }

            injectStatus = .injecting
            log("inject: writing patch files...")

            let fm = FileManager.default
            let dataDir = cPath + "/Documents"

            // Write Assembly-CSharp-patch.bytes
            if let patchURL = Bundle.main.url(forResource: "Assembly-CSharp-patch", withExtension: "bytes"),
               let patchData = try? Data(contentsOf: patchURL) {
                let destPath = dataDir + "/" + patchFileName
                fm.createFile(atPath: destPath, contents: patchData)
                log("inject: wrote \(patchFileName) (\(patchData.count) bytes)")
            } else {
                log("inject: WARNING — patch bytes not found in bundle")
            }

            // Write localConfig.json
            let configData = buildConfig()
            let configPath = dataDir + "/" + configFileName
            fm.createFile(atPath: configPath, contents: configData)
            log("inject: wrote \(configFileName)")

            log("inject: complete — restart \(selectedGame.displayName) to activate")
            injectStatus = .success
            isInjected = true
        }
    }

    // MARK: - Neutralize
    func neutralize() {
        guard let cPath = containerPath ?? resolveContainer() else {
            log("neutralize: container not found")
            return
        }

        let fm = FileManager.default
        let dataDir = cPath + "/Documents"

        var removed = 0
        for name in [patchFileName, configFileName] {
            let p = dataDir + "/" + name
            if fm.fileExists(atPath: p) {
                try? fm.removeItem(atPath: p)
                removed += 1
                log("neutralize: removed \(name)")
            }
        }

        if removed == 0 {
            log("neutralize: no patch files found")
        } else {
            log("neutralize: FFXC patch cleared — restart game to restore")
        }

        injectStatus = .neutralized
        isInjected = false
    }

    // MARK: - Default feature catalog
    static func defaultFeatures() -> [FFXCFeature] {
        [
            FFXCFeature(id: "k0",  title: "Wallhack",         subtitle: "See enemies through walls",        icon: "eye.fill"),
            FFXCFeature(id: "k1",  title: "Aimbot",           subtitle: "Auto aim assist",                  icon: "scope"),
            FFXCFeature(id: "k2",  title: "No Recoil",        subtitle: "Zero weapon recoil",               icon: "dot.crosshair"),
            FFXCFeature(id: "k3",  title: "Speed Boost",      subtitle: "Increased movement speed",         icon: "bolt.fill"),
            FFXCFeature(id: "k4",  title: "No Spread",        subtitle: "Perfect bullet accuracy",          icon: "target"),
            FFXCFeature(id: "k5",  title: "Rapid Fire",       subtitle: "Faster fire rate",                 icon: "flame.fill"),
            FFXCFeature(id: "k6",  title: "Long Range",       subtitle: "Extended hit detection",           icon: "arrow.up.forward"),
            FFXCFeature(id: "k7",  title: "Anti-Ban Shield",  subtitle: "Signature masking active",         icon: "shield.fill"),
            FFXCFeature(id: "k8",  title: "Auto Headshot",    subtitle: "Priority head hitbox",             icon: "person.fill.viewfinder"),
            FFXCFeature(id: "k9",  title: "Item Radar",       subtitle: "Highlight loot on map",            icon: "map.fill"),
            FFXCFeature(id: "k10", title: "Drone View",       subtitle: "Elevated camera perspective",      icon: "camera.fill"),
            FFXCFeature(id: "k11", title: "Fast Loot",        subtitle: "Instant pickup animation",         icon: "hand.point.up.fill"),
            FFXCFeature(id: "k12", title: "Silent Aim",       subtitle: "Hit without aiming center",        icon: "arrow.triangle.turn.up.right.diamond.fill"),
            FFXCFeature(id: "k13", title: "No Flash",         subtitle: "Immune to flash grenades",         icon: "sun.max.fill"),
            FFXCFeature(id: "k14", title: "No Smoke",         subtitle: "Clear vision through smoke",       icon: "wind"),
            FFXCFeature(id: "k15", title: "High Jump",        subtitle: "Extended jump height",             icon: "figure.run"),
            FFXCFeature(id: "k16", title: "Fast Revive",      subtitle: "Instant teammate revive",          icon: "cross.fill"),
            FFXCFeature(id: "k17", title: "Unlimited Ammo",   subtitle: "No reload required",               icon: "circle.grid.2x2.fill"),
            FFXCFeature(id: "k18", title: "Fly Hack",         subtitle: "Vertical movement unlock",         icon: "airplane"),
            FFXCFeature(id: "k19", title: "Vehicle Speed",    subtitle: "Boosted vehicle acceleration",     icon: "car.fill"),
            FFXCFeature(id: "k20", title: "Gloo Wall Spam",   subtitle: "Instant gloo placement",           icon: "square.3.layers.3d"),
            FFXCFeature(id: "k21", title: "ESP Box",          subtitle: "Enemy bounding box overlay",       icon: "rectangle.dashed"),
            FFXCFeature(id: "k22", title: "Health Bar ESP",   subtitle: "Display enemy HP above head",      icon: "heart.fill"),
            FFXCFeature(id: "k23", title: "Distance ESP",     subtitle: "Show enemy distance in meters",    icon: "ruler.fill"),
        ]
    }
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
