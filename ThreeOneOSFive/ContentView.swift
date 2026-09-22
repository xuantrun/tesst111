import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("yabaocheat.patchEnabled") private var patchEnabled = false
    @State private var statusMessage: String = "Đang kiểm tra..."
    @State private var resolvedPath: String = "Resolving..."
    @State private var isAnimating = false
    @State private var isUpdatingProgrammatically = false
    @State private var isProcessing = false
    
    // Bundle identifiers to support
    let targetBundleIDs = ["com.dts.freefireth", "com.dts.freefiremax"]
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.black, Color(white: 0.15)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 25) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: patchEnabled ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 70))
                        .foregroundColor(patchEnabled ? .green : .red)
                        .shadow(color: patchEnabled ? .green : .red, radius: 10, x: 0, y: 0)
                        .scaleEffect(isAnimating ? 1.05 : 0.95)
                        .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
                        .onAppear { isAnimating = true }
                    
                    Text("YABAO Patcher")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Free Fire Data Injector")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 30)
                
                // Status Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "bolt.shield.fill")
                            .foregroundColor(.green)
                        Text("Quyền truy cập")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        if findAppBundle() != nil {
                            Text("TrollStore Sẵn Sàng").bold().foregroundColor(.green)
                        } else {
                            statusText(for: appState.exploitStatus)
                        }
                    }
                    
                    if findAppBundle() == nil && (appState.exploitStatus.isFailed || appState.exploitStatus.isNotStarted) {
                        Button(action: {
                            appState.runKernelExploitIfNeeded()
                        }) {
                            Text("Kích hoạt Exploit")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
                
                // Target Game Path Info Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.orange)
                        Text("Đường dẫn Free Fire")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    
                    Text(resolvedPath)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .padding(.top, 4)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
                
                Spacer()
                
                // Main Toggle Flow
                VStack(spacing: 15) {
                    Toggle(isOn: $patchEnabled) {
                        Text(patchEnabled ? "Đã Dán Patch (Active)" : "Bật Dán Patch (Enable)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .disabled(isProcessing)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(patchEnabled ? Color.green.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .onChange(of: patchEnabled) { enabled in
                        guard !isUpdatingProgrammatically else { return }
                        handleToggle(enabled: enabled)
                    }
                    
                    Text(statusMessage)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(statusMessage.contains("thành công") || statusMessage.contains("Đã dán") ? .green : (statusMessage.contains("Lỗi") || statusMessage.contains("Không tìm") ? .red : .gray))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            checkCurrentPatchStatus()
            if appState.kernelExploitApplicable && findAppBundle() == nil {
                appState.runKernelExploitIfNeeded()
            }
        }
    }
    
    @ViewBuilder
    private func statusText(for status: ExploitStatus) -> some View {
        switch status {
        case .notStarted:
            Text("Chưa chạy").bold().foregroundColor(.gray)
        case .unsupported(_):
            Text("iOS không hỗ trợ").bold().foregroundColor(.red)
        case .failed(_, _):
            Text("Thất bại").bold().foregroundColor(.red)
        case .success(_):
            Text("Active").bold().foregroundColor(.green)
        }
    }
    
    private func resolvePath() {
        if let appInfo = findAppBundle() {
            resolvedPath = "\(appInfo.url.path)\nBundle: \(appInfo.bundleID)"
        } else {
            resolvedPath = "Không tìm thấy Free Fire (\(targetBundleIDs.joined(separator: ", ")))"
        }
    }
    
    private func setToggleState(_ val: Bool) {
        isUpdatingProgrammatically = true
        patchEnabled = val
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isUpdatingProgrammatically = false
        }
    }
    
    private func checkCurrentPatchStatus() {
        if let appInfo = findAppBundle() {
            resolvePath()
            let docPatch = appInfo.url.appendingPathComponent("Documents").appendingPathComponent("Assembly-CSharp-patch.bytes")
            let rootPatch = appInfo.url.appendingPathComponent("Assembly-CSharp-patch.bytes")
            let exists = FileManager.default.fileExists(atPath: docPatch.path) || FileManager.default.fileExists(atPath: rootPatch.path)
            
            setToggleState(exists)
            statusMessage = exists ? "Đã dán patch vào Free Fire!" : "Chưa dán patch. Gạt để dán."
        } else {
            resolvePath()
            statusMessage = "Không tìm thấy game Free Fire trên máy."
            setToggleState(false)
        }
    }
    
    private func handleToggle(enabled: Bool) {
        guard !isProcessing else { return }
        isProcessing = true
        statusMessage = enabled ? "Đang dán file patch vào Free Fire..." : "Đang xoá file patch (khôi phục)..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = enabled ? applyPatch() : restorePatch()
            
            DispatchQueue.main.async {
                self.isProcessing = false
                self.statusMessage = result.message
                if result.success {
                    self.setToggleState(enabled)
                } else {
                    self.setToggleState(!enabled)
                }
                resolvePath()
            }
        }
    }
    
    // MARK: - Core Logic & Data Injection
    
    private func applyPatch() -> (success: Bool, message: String) {
        guard let appInfo = findAppBundle() else {
            return (false, "Lỗi: Không tìm thấy Free Fire (com.dts.freefireth)")
        }
        
        guard let patchData = getPatchData(), !patchData.isEmpty else {
            return (false, "Lỗi: Không tìm thấy file Assembly-CSharp-patch.bytes trong bundle app.")
        }
        
        let containerURL = appInfo.url
        let docs = containerURL.appendingPathComponent("Documents")
        let fm = FileManager.default
        
        if !fm.fileExists(atPath: docs.path) {
            try? fm.createDirectory(at: docs, withIntermediateDirectories: true, attributes: nil)
        }
        
        let docPatch = docs.appendingPathComponent("Assembly-CSharp-patch.bytes")
        let rootPatch = containerURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
        
        let ok1 = writeFileSafely(data: patchData, to: docPatch)
        let ok2 = writeFileSafely(data: patchData, to: rootPatch)
        
        if let configData = "{\"testCodePatch\":true}".data(using: .utf8) {
            _ = writeFileSafely(data: configData, to: docs.appendingPathComponent("localConfig.json"))
            _ = writeFileSafely(data: configData, to: containerURL.appendingPathComponent("localConfig.json"))
        }
        
        if ok1 || ok2 || fm.fileExists(atPath: docPatch.path) {
            return (true, "Dán patch thành công! (\(appInfo.bundleID))")
        } else {
            return (false, "Lỗi: Không thể ghi file vào thư mục Free Fire. Kiểm tra TrollStore.")
        }
    }
    
    private func restorePatch() -> (success: Bool, message: String) {
        guard let appInfo = findAppBundle() else {
            return (false, "Không tìm thấy Free Fire để xoá patch.")
        }
        
        let containerURL = appInfo.url
        let docs = containerURL.appendingPathComponent("Documents")
        
        let targets = [
            docs.appendingPathComponent("Assembly-CSharp-patch.bytes"),
            docs.appendingPathComponent("localConfig.json"),
            containerURL.appendingPathComponent("Assembly-CSharp-patch.bytes"),
            containerURL.appendingPathComponent("localConfig.json"),
            docs.appendingPathComponent("Assembly-CSharp-patch.bytes.bak"),
            containerURL.appendingPathComponent("Assembly-CSharp-patch.bytes.bak")
        ]
        
        let fm = FileManager.default
        for target in targets {
            if fm.fileExists(atPath: target.path) {
                try? fm.removeItem(at: target)
            }
        }
        
        return (true, "Đã khôi phục thành công! (Đã xoá patch)")
    }
    
    private func writeFileSafely(data: Data, to destination: URL) -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try? fm.removeItem(at: destination)
        }
        do {
            try data.write(to: destination, options: .atomic)
            return true
        } catch {
            return fm.createFile(atPath: destination.path, contents: data, attributes: nil)
        }
    }
    
    private func findAppBundle() -> (url: URL, bundleID: String)? {
        for bid in targetBundleIDs {
            if let path = ContainerStore.resolveAppContainerPath(bundleID: bid) {
                return (URL(fileURLWithPath: path), bid)
            }
        }
        return nil
    }
    
    private func getPatchData() -> Data? {
        // 1. Try URL in Bundle.main
        if let url = Bundle.main.url(forResource: "Assembly-CSharp-patch", withExtension: "bytes"),
           let data = try? Data(contentsOf: url), !data.isEmpty {
            return data
        }
        // 2. Try direct path in Bundle.main.bundlePath
        let bundlePath = (Bundle.main.bundlePath as NSString).appendingPathComponent("Assembly-CSharp-patch.bytes")
        if let data = try? Data(contentsOf: URL(fileURLWithPath: bundlePath)), !data.isEmpty {
            return data
        }
        // 3. Try Bundle.main.resourcePath
        if let resPath = Bundle.main.resourcePath {
            let resURL = URL(fileURLWithPath: resPath).appendingPathComponent("Assembly-CSharp-patch.bytes")
            if let data = try? Data(contentsOf: resURL), !data.isEmpty {
                return data
            }
        }
        // 4. Try bundleURL
        let directURL = Bundle.main.bundleURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
        if let data = try? Data(contentsOf: directURL), !data.isEmpty {
            return data
        }
        return nil
    }
}
