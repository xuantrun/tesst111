import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("yabaocheat.patchEnabled") private var patchEnabled = false
    @State private var statusMessage: String = "Waiting to inject..."
    @State private var resolvedPath: String = "Resolving..."
    @State private var isAnimating = false
    
    // Bundle identifier for the target app
    let targetBundleID = "com.apple.mobile.MobileHouseArrest" 
    
    var body: some View {
        ZStack {
            // Premium Dark Background
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
                    
                    Text("Kernel Exploit & Data Injector")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                
                // Exploit Status Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.blue)
                        Text("Exploit Status")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        statusText(for: appState.exploitStatus)
                    }
                    
                    if appState.exploitStatus.isFailed || appState.exploitStatus.isNotStarted {
                        Button(action: {
                            appState.runKernelExploitIfNeeded()
                        }) {
                            Text("Initialize Exploit")
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
                
                // Injection Path Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.orange)
                        Text("Injection Path Data")
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
                .onAppear {
                    resolvePath()
                }
                
                Spacer()
                
                // Main Toggle Flow
                VStack(spacing: 15) {
                    Toggle(isOn: $patchEnabled) {
                        Text(patchEnabled ? "Patch Active" : "Enable Patch")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(patchEnabled ? Color.green.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .onChange(of: patchEnabled) { enabled in
                        handleToggle(enabled: enabled)
                    }
                    
                    Text(statusMessage)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(statusMessage.contains("Success") ? .green : .gray)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 20)
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
    
    @ViewBuilder
    private func statusText(for status: ExploitStatus) -> some View {
        switch status {
        case .notStarted:
            Text("Not Started").bold().foregroundColor(.gray)
        case .unsupported(let msg):
            Text("Unsupported").bold().foregroundColor(.red)
        case .failed(_, _):
            Text("Failed").bold().foregroundColor(.red)
        case .success(_):
            Text("Active").bold().foregroundColor(.green)
        }
    }
    
    private func resolvePath() {
        if let url = findAppBundle(bundleID: targetBundleID) {
            resolvedPath = url.path
        } else {
            resolvedPath = "Target App Not Found (\(targetBundleID))"
        }
    }
    
    private func handleToggle(enabled: Bool) {
        // Prevent toggle if exploit isn't ready
        guard appState.exploitStatus.isSuccess else {
            statusMessage = "Exploit must be active to inject data!"
            patchEnabled = false
            return
        }
        
        statusMessage = enabled ? "Injecting data into memory..." : "Restoring original state..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            let success = enabled ? applyPatch() : restorePatch()
            
            DispatchQueue.main.async {
                if success {
                    statusMessage = enabled ? "Data Injected Successfully!" : "Original Restored Successfully!"
                } else {
                    statusMessage = enabled ? "Injection Failed. Check Logs." : "Restore Failed."
                    self.patchEnabled = !enabled
                }
                resolvePath() // Refresh path
            }
        }
    }
    
    // MARK: - Core Logic & Data Injection
    
    private func applyPatch() -> Bool {
        guard let targetBundleURL = findAppBundle(bundleID: targetBundleID) else {
            return false
        }
        
        let targetAssembly = targetBundleURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
        let targetTest = targetBundleURL.appendingPathComponent("test")
        
        let assemblyBak = targetBundleURL.appendingPathComponent("Assembly-CSharp-patch.bytes.bak")
        let testBak = targetBundleURL.appendingPathComponent("test.bak")
        
        guard let bundledAssembly = Bundle.main.url(forResource: "Assembly-CSharp-patch", withExtension: "bytes"),
              let bundledTest = Bundle.main.url(forResource: "test", withExtension: "") else {
            return false
        }
        
        let fm = FileManager.default
        do {
            if !fm.fileExists(atPath: assemblyBak.path) && fm.fileExists(atPath: targetAssembly.path) {
                try fm.copyItem(at: targetAssembly, to: assemblyBak)
            }
            if !fm.fileExists(atPath: testBak.path) && fm.fileExists(atPath: targetTest.path) {
                try fm.copyItem(at: targetTest, to: testBak)
            }
            
            _ = try FileReplacementService.replace(target: targetAssembly, with: bundledAssembly, fileManager: fm)
            _ = try FileReplacementService.replace(target: targetTest, with: bundledTest, fileManager: fm)
            return true
        } catch {
            print("Injection Error: \(error)")
            return false
        }
    }
    
    private func restorePatch() -> Bool {
        guard let targetBundleURL = findAppBundle(bundleID: targetBundleID) else { return false }
        
        let targetAssembly = targetBundleURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
        let targetTest = targetBundleURL.appendingPathComponent("test")
        
        let assemblyBak = targetBundleURL.appendingPathComponent("Assembly-CSharp-patch.bytes.bak")
        let testBak = targetBundleURL.appendingPathComponent("test.bak")
        
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: assemblyBak.path) {
                if fm.fileExists(atPath: targetAssembly.path) { try fm.removeItem(at: targetAssembly) }
                try fm.moveItem(at: assemblyBak, to: targetAssembly)
            }
            if fm.fileExists(atPath: testBak.path) {
                if fm.fileExists(atPath: targetTest.path) { try fm.removeItem(at: targetTest) }
                try fm.moveItem(at: testBak, to: targetTest)
            }
            return true
        } catch {
            print("Restore Error: \(error)")
            return false
        }
    }
    
    private func findAppBundle(bundleID: String) -> URL? {
        let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type
        let workspace = workspaceClass?.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue()
        let apps = workspace?.perform(NSSelectorFromString("allInstalledApplications"))?.takeUnretainedValue() as? [NSObject]
        
        for app in apps ?? [] {
            if let ident = app.perform(NSSelectorFromString("applicationIdentifier"))?.takeUnretainedValue() as? String,
               ident == bundleID {
                if let url = app.perform(NSSelectorFromString("bundleURL"))?.takeUnretainedValue() as? URL {
                    return url
                }
            }
        }
        
        let fm = FileManager.default
        let appsDir = URL(fileURLWithPath: "/var/containers/Bundle/Application")
        if let dirs = try? fm.contentsOfDirectory(at: appsDir, includingPropertiesForKeys: nil) {
            for dir in dirs {
                let appDirs = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "app" }
                if let appDir = appDirs?.first {
                    let infoPlist = appDir.appendingPathComponent("Info.plist")
                    if let dict = NSDictionary(contentsOf: infoPlist),
                       let ident = dict["CFBundleIdentifier"] as? String,
                       ident == bundleID {
                        return appDir
                    }
                }
            }
        }
        return nil
    }
}
