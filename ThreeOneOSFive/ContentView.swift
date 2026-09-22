import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("yabaocheat.patchEnabled") private var patchEnabled = false
    @State private var statusMessage: String = "Sẵn sàng inject..."
    @State private var resolvedPath: String = "Đang tìm..."
    @State private var isAnimating = false

    // Free Fire bundle ID (target game)
    let ffBundleID = "com.dts.freefireth"

    var body: some View {
        ZStack {
            // Premium Dark Background
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(white: 0.12)]),
                startPoint: .top, endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 22) {

                // ── Header ──────────────────────────────────────────────
                VStack(spacing: 8) {
                    Image(systemName: patchEnabled ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 68))
                        .foregroundColor(patchEnabled ? .green : .red)
                        .shadow(color: patchEnabled ? .green : .red, radius: 14, x: 0, y: 0)
                        .scaleEffect(isAnimating ? 1.07 : 0.93)
                        .animation(
                            .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                        .onAppear { isAnimating = true }

                    Text("YABAO Patcher")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    Text("IFix Payload Injector · com.dts.freefireth")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top, 42)

                // ── Exploit Status Card ──────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.blue)
                        Text("Kernel Exploit")
                            .font(.headline).foregroundColor(.white)
                        Spacer()
                        statusBadge(for: appState.exploitStatus)
                    }

                    if appState.exploitStatus.isFailed || appState.exploitStatus.isNotStarted {
                        Button {
                            appState.runKernelExploitIfNeeded()
                        } label: {
                            Label("Initialize Exploit", systemImage: "bolt.fill")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(radius: 6)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
                .padding(.horizontal)

                // ── Path Info Card ───────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.orange)
                        Text("Injection Target Path")
                            .font(.headline).foregroundColor(.white)
                    }
                    Text(resolvedPath)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(4)
                        .truncationMode(.middle)
                        .padding(.top, 2)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.08))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
                .padding(.horizontal)
                .onAppear { refreshPath() }

                Spacer()

                // ── Main Toggle ──────────────────────────────────────────
                VStack(spacing: 14) {
                    Toggle(isOn: $patchEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(patchEnabled ? "✅ Patch Active" : "💉 Enable Patch")
                                .font(.title3).fontWeight(.bold)
                                .foregroundColor(.white)
                            Text(patchEnabled ? "Assembly-CSharp-patch.bytes injected" : "Toggle để inject vào FreeFire")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(patchEnabled ? Color.green.opacity(0.5) : Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .onChange(of: patchEnabled) { enabled in
                        handleToggle(enabled: enabled)
                    }

                    // Status Label
                    HStack(spacing: 6) {
                        Image(systemName: statusMessage.contains("✅") ? "checkmark.circle.fill" :
                              statusMessage.contains("❌") ? "xmark.circle.fill" : "info.circle.fill")
                            .foregroundColor(
                                statusMessage.contains("✅") ? .green :
                                statusMessage.contains("❌") ? .red : .gray
                            )
                        Text(statusMessage)
                            .font(.footnote).fontWeight(.medium)
                            .foregroundColor(
                                statusMessage.contains("✅") ? .green :
                                statusMessage.contains("❌") ? .red : .gray
                            )
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 30)
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            if appState.kernelExploitApplicable {
                appState.runKernelExploitIfNeeded()
            }
        }
    }

    // MARK: - Badge Helper

    @ViewBuilder
    private func statusBadge(for status: ExploitStatus) -> some View {
        switch status {
        case .notStarted:
            Text("Not Started").bold().foregroundColor(.gray)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.gray.opacity(0.2)).cornerRadius(8)
        case .unsupported:
            Text("Unsupported").bold().foregroundColor(.red)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.red.opacity(0.15)).cornerRadius(8)
        case .failed:
            Text("Failed").bold().foregroundColor(.red)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.red.opacity(0.15)).cornerRadius(8)
        case .success:
            Text("✓ Active").bold().foregroundColor(.green)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.green.opacity(0.15)).cornerRadius(8)
        }
    }

    // MARK: - Path Resolution

    private func refreshPath() {
        if let url = findFFAppBundle() {
            let patchPath = url.appendingPathComponent("Assembly-CSharp-patch.bytes").path
            resolvedPath = patchPath
        } else {
            resolvedPath = "❌ FreeFire not found (\(ffBundleID))"
        }
    }

    // MARK: - Toggle Handler

    private func handleToggle(enabled: Bool) {
        guard appState.exploitStatus.isSuccess else {
            statusMessage = "⚠️ Exploit phải active trước khi inject!"
            patchEnabled = false
            return
        }

        statusMessage = enabled ? "⏳ Đang inject patch..." : "⏳ Đang restore file gốc..."

        DispatchQueue.global(qos: .userInitiated).async {
            let success = enabled ? applyPatch() : restorePatch()
            DispatchQueue.main.async {
                if success {
                    statusMessage = enabled
                        ? "✅ Inject thành công! Mở FreeFire để hack."
                        : "✅ Đã restore file gốc."
                } else {
                    statusMessage = enabled
                        ? "❌ Inject thất bại. Xem log để debug."
                        : "❌ Restore thất bại."
                    patchEnabled = !enabled
                }
                refreshPath()
            }
        }
    }

    // MARK: - Core Patch Logic

    private func applyPatch() -> Bool {
        guard let bundleURL = findFFAppBundle() else {
            log("inject: ❌ Cannot find FreeFire bundle")
            return false
        }

        let targetAssembly = bundleURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
        let targetTest     = bundleURL.appendingPathComponent("test")
        let assemblyBak    = bundleURL.appendingPathComponent("Assembly-CSharp-patch.bytes.bak")
        let testBak        = bundleURL.appendingPathComponent("test.bak")

        guard let bundledAssembly = Bundle.main.url(forResource: "Assembly-CSharp-patch", withExtension: "bytes"),
              let bundledTest     = Bundle.main.url(forResource: "test", withExtension: nil)
        else {
            log("inject: ❌ Payload files missing from app bundle")
            return false
        }

        let fm = FileManager.default
        do {
            // Backup originals (only once)
            if !fm.fileExists(atPath: assemblyBak.path) && fm.fileExists(atPath: targetAssembly.path) {
                try fm.copyItem(at: targetAssembly, to: assemblyBak)
                log("inject: backed up Assembly-CSharp-patch.bytes")
            }
            if !fm.fileExists(atPath: testBak.path) && fm.fileExists(atPath: targetTest.path) {
                try fm.copyItem(at: targetTest, to: testBak)
                log("inject: backed up test")
            }

            // Replace with cheat payloads
            _ = try FileReplacementService.replace(target: targetAssembly, with: bundledAssembly, fileManager: fm)
            log("inject: ✅ Assembly-CSharp-patch.bytes replaced")

            _ = try FileReplacementService.replace(target: targetTest, with: bundledTest, fileManager: fm)
            log("inject: ✅ test replaced")

            return true
        } catch {
            log("inject: ❌ Error — \(error.localizedDescription)")
            return false
        }
    }

    private func restorePatch() -> Bool {
        guard let bundleURL = findFFAppBundle() else {
            log("restore: ❌ Cannot find FreeFire bundle")
            return false
        }

        let targetAssembly = bundleURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
        let targetTest     = bundleURL.appendingPathComponent("test")
        let assemblyBak    = bundleURL.appendingPathComponent("Assembly-CSharp-patch.bytes.bak")
        let testBak        = bundleURL.appendingPathComponent("test.bak")

        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: assemblyBak.path) {
                if fm.fileExists(atPath: targetAssembly.path) {
                    try fm.removeItem(at: targetAssembly)
                }
                try fm.moveItem(at: assemblyBak, to: targetAssembly)
                log("restore: ✅ Assembly-CSharp-patch.bytes restored")
            }
            if fm.fileExists(atPath: testBak.path) {
                if fm.fileExists(atPath: targetTest.path) {
                    try fm.removeItem(at: targetTest)
                }
                try fm.moveItem(at: testBak, to: targetTest)
                log("restore: ✅ test restored")
            }
            return true
        } catch {
            log("restore: ❌ Error — \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Find FreeFire Bundle via MobileHouseArrest / direct scan

    private func findFFAppBundle() -> URL? {
        // Method 1: LSApplicationWorkspace (requires sandbox escape)
        if let url = lsWorkspaceBundle(bundleID: ffBundleID) {
            return url
        }
        // Method 2: Direct filesystem scan (fallback)
        return directScanBundle(bundleID: ffBundleID)
    }

    private func lsWorkspaceBundle(bundleID: String) -> URL? {
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let workspace = workspaceClass
                .perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue(),
              let apps = workspace
                .perform(NSSelectorFromString("allInstalledApplications"))?.takeUnretainedValue() as? [NSObject]
        else { return nil }

        for app in apps {
            guard let ident = app.perform(NSSelectorFromString("applicationIdentifier"))?.takeUnretainedValue() as? String,
                  ident == bundleID,
                  let url = app.perform(NSSelectorFromString("bundleURL"))?.takeUnretainedValue() as? URL
            else { continue }
            return url
        }
        return nil
    }

    private func directScanBundle(bundleID: String) -> URL? {
        let fm = FileManager.default
        let appsDir = URL(fileURLWithPath: "/var/containers/Bundle/Application")
        guard let uuidDirs = try? fm.contentsOfDirectory(at: appsDir, includingPropertiesForKeys: nil) else {
            return nil
        }
        for uuidDir in uuidDirs {
            guard let appDirs = try? fm.contentsOfDirectory(at: uuidDir, includingPropertiesForKeys: nil)
                    .filter({ $0.pathExtension == "app" }),
                  let appDir = appDirs.first
            else { continue }

            let plist = appDir.appendingPathComponent("Info.plist")
            if let dict = NSDictionary(contentsOf: plist),
               let ident = dict["CFBundleIdentifier"] as? String,
               ident == bundleID {
                return appDir
            }
        }
        return nil
    }
}
