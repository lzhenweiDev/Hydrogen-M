//
//  ContentView.swift
//  HydrogenMInstaller
//
//  Beautiful GUI + Admin Password
//

import SwiftUI
import Combine
import AppKit
import Security

// MARK: - Models
struct StepItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    var status: StepStatus = .waiting
}

enum StepStatus { case waiting, running, done, failed }

// MARK: - Installer Manager
class InstallerManager: ObservableObject {
    @Published var progress: Double = 0
    @Published var statusText = "Ready to install"
    @Published var isInstalling = false
    @Published var currentActionText = ""
    @Published var logMessages: [String] = []
    @Published var downloadInfo = ""
    @Published var downloadPercent: Double = 0
    @Published var downloadSpeed = ""
    
    @Published var showSuccessPopup = false
    @Published var showErrorPopup = false
    @Published var errorMessage = ""
    @Published var showCheckmark = false
    @Published var activeStepIndex = 0
    
    @Published var steps: [StepItem] = [
        StepItem(title: "Authenticate", detail: "Verify administrator privileges", icon: "lock.shield.fill"),
        StepItem(title: "Kill Processes", detail: "Terminating Hydrogen & Roblox", icon: "xmark.circle.fill"),
        StepItem(title: "Remove Old Apps", detail: "Deleting old installations", icon: "trash.fill"),
        StepItem(title: "Download Installer", detail: "Fetching installer binary", icon: "arrow.down.circle.fill"),
        StepItem(title: "Run Installer", detail: "Installing Hydrogen & Roblox", icon: "gearshape.2.fill"),
        StepItem(title: "Clear Preferences", detail: "Removing Roblox settings", icon: "slider.horizontal.3"),
        StepItem(title: "Finalize", detail: "Completing setup", icon: "flag.checkered")
    ]
    
    // URLs from install.sh
    private let hydrogenInstallerURL = "https://0ai4bbbahf.ufs.sh/f/4fzhZqSSYIjmt8OGDr546yzQVkLwJsKXF8Y7eoi1cUprDjC2"
    private let hydrogenMURL = "https://0ai4bbbahf.ufs.sh/f/4fzhZqSSYIjmwLOYvnLyRu4HmMXkvGhDw8SctAIPEs3BrTpU"
    private let robloxURL_ARM = "https://setup.rbxcdn.com/mac/arm64/version-9e55b34566734c3b-RobloxPlayer.zip"
    private let robloxURL_X86 = "https://setup.rbxcdn.com/mac/version-9e55b34566734c3b-RobloxPlayer.zip"
    
    private let tmpDir = "/tmp"
    private var installerBin: String { "\(tmpDir)/hydrogen_installer" }
    private var workItem: DispatchWorkItem?
    
    func startInstallation() {
        guard !isInstalling else { return }

        isInstalling = true
        progress = 0
        downloadPercent = 0
        downloadSpeed = ""
        showSuccessPopup = false
        showErrorPopup = false
        showCheckmark = false
        logMessages.removeAll()
        resetSteps()
        
        addLog("═══════════════════════════════")
        addLog("Installation started with admin privileges")
        addLog("═══════════════════════════════")
        
        let item = DispatchWorkItem { [weak self] in
            self?.runInstallation()
        }
        workItem = item
        DispatchQueue.global(qos: .userInitiated).async(execute: item)
    }
    
    func cancelInstallation() {
        isInstalling = false
        workItem?.cancel()
        workItem = nil
        statusText = "Cancelled"
        currentActionText = ""
        downloadInfo = ""
        downloadPercent = 0
        downloadSpeed = ""
        addLog("Installation cancelled")
    }
    
    private func resetSteps() {
        for i in steps.indices { steps[i].status = .waiting }
        activeStepIndex = 0
    }
    
    private func runInstallation() {
        // Step 1: Authenticate (already done)
        updateStepUI(0, status: .done, progress: 5)
        
        // Step 2: Kill Processes
        updateStepUI(1, status: .running)
        do {
            try killProcesses()
            updateStepUI(1, status: .done, progress: 12)
        } catch {
            addLog("Warning: Some processes could not be terminated")
            updateStepUI(1, status: .done, progress: 12)
        }
        
        // Step 3: Remove Old Apps
        updateStepUI(2, status: .running)
        do {
            try removeOldApps()
            updateStepUI(2, status: .done, progress: 20)
        } catch {
            handleStepError(2, error)
            return
        }
        
        // Step 4: Download Installer
        updateStepUI(3, status: .running)
        do {
            try downloadInstallerBinary()
            updateStepUI(3, status: .done, progress: 45)
        } catch {
            handleStepError(3, error)
            return
        }
        
        // Step 5: Run Installer
        updateStepUI(4, status: .running)
        do {
            try runInstallerBinary()
            updateStepUI(4, status: .done, progress: 80)
        } catch {
            handleStepError(4, error)
            return
        }
        
        // Step 6: Clear Preferences
        updateStepUI(5, status: .running)
        do {
            try clearPreferences()
            updateStepUI(5, status: .done, progress: 93)
        } catch {
            addLog("Warning: Preferences could not be fully cleared")
            updateStepUI(5, status: .done, progress: 93)
        }
        
        // Step 7: Finalize
        updateStepUI(6, status: .running)
        do {
            try finalizeSetup()
            updateStepUI(6, status: .done, progress: 100)
        } catch {
            handleStepError(6, error)
            return
        }
        
        // SUCCESS!
        DispatchQueue.main.async {
            self.statusText = "Complete"
            self.currentActionText = "Enjoy the experience!"
            self.isInstalling = false
            self.downloadInfo = ""
            self.downloadPercent = 0
            self.downloadSpeed = ""
            self.addLog("═══════════════════════════════")
            self.addLog("Hydrogen-M installed successfully!")
            self.addLog("Enjoy the experience! Please provide feedback.")
            self.addLog("═══════════════════════════════")
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                self.showCheckmark = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    self.showSuccessPopup = true
                }
            }
            
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }
    
    private func updateStepUI(_ index: Int, status: StepStatus, progress: Double? = nil) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.32)) {
                self.steps[index].status = status
                self.currentActionText = self.steps[index].detail
                self.statusText = self.steps[index].title
                if status == .running || (status == .done && index == self.steps.indices.last) {
                    self.activeStepIndex = index
                }
                if let prog = progress {
                    self.progress = prog
                }
            }
        }
    }
    
    private func handleStepError(_ index: Int, _ error: Error) {
        DispatchQueue.main.async {
            self.steps[index].status = .failed
            self.activeStepIndex = index
            self.errorMessage = error.localizedDescription
            self.addLog("Error: \(error.localizedDescription)")
            self.showErrorPopup = true
            self.isInstalling = false
            self.downloadInfo = ""
            self.downloadPercent = 0
            self.downloadSpeed = ""
            self.statusText = "Failed"
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }
    
    // MARK: - Installation Steps
    private func killProcesses() throws {
        addLog("Terminating Hydrogen-M.app...")
        let p1 = Process()
        p1.launchPath = "/usr/bin/pkill"
        p1.arguments = ["-f", "Hydrogen-M.app"]
        p1.launch()
        p1.waitUntilExit()
        
        addLog("Terminating Hydrogen.app...")
        let p2 = Process()
        p2.launchPath = "/usr/bin/pkill"
        p2.arguments = ["-f", "Hydrogen.app"]
        p2.launch()
        p2.waitUntilExit()
        
        addLog("Terminating Roblox.app...")
        let p3 = Process()
        p3.launchPath = "/usr/bin/pkill"
        p3.arguments = ["-f", "Roblox.app"]
        p3.launch()
        p3.waitUntilExit()
        
        Thread.sleep(forTimeInterval: 0.5)
        addLog("Processes terminated")
    }
    
    private func removeOldApps() throws {
        let fm = FileManager.default
        
        for appPath in ["/Applications/Hydrogen-M.app", "/Applications/Hydrogen.app", "/Applications/Roblox.app"] {
            if fm.fileExists(atPath: appPath) {
                addLog("Queued for removal: \(appPath)")
            }
        }
        
        addLog("Existing apps will be removed during privileged install step")
    }
    
    private func downloadInstallerBinary() throws {
        addLog("Downloading installer binary...")
        
        let url = URL(string: hydrogenInstallerURL)!
        let destPath = installerBin
        
        try? FileManager.default.removeItem(atPath: destPath)
        
        let expectedSize = try getFileSize(url: url)
        
        let curl = Process()
        curl.launchPath = "/usr/bin/curl"
        curl.arguments = ["-f", "-s", "-S", "-L", "--connect-timeout", "30", "--max-time", "300", "-o", destPath, url.absoluteString]
        curl.launch()
        
        var lastSize: Int64 = 0
        var lastTime = Date()
        let startTime = Date()
        
        while curl.isRunning {
            guard isInstalling else { curl.terminate(); throw NSError(domain: "", code: -1, userInfo: nil) }
            
            if FileManager.default.fileExists(atPath: destPath) {
                let attrs = try? FileManager.default.attributesOfItem(atPath: destPath)
                let currentSize = (attrs?[.size] as? Int64) ?? 0
                let now = Date()
                let timeDiff = now.timeIntervalSince(lastTime)
                
                if timeDiff > 0.1 {
                    let speedMB = (Double(currentSize - lastSize) / timeDiff) / 1_000_000.0
                    let percent = expectedSize > 0 ? Double(currentSize) / Double(expectedSize) * 100.0 : 0
                    let currentMB = Double(currentSize) / 1_000_000.0
                    
                    DispatchQueue.main.async {
                        self.downloadPercent = percent
                        self.downloadSpeed = String(format: "%.1f MB/s", speedMB)
                        self.downloadInfo = String(format: "%.1f MB downloaded", currentMB)
                        self.currentActionText = String(format: "Downloading installer %.0f%%", percent)
                        self.progress = 20.0 + (percent / 100.0) * 25.0
                    }
                    
                    lastSize = currentSize
                    lastTime = now
                }
            }
            
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        curl.waitUntilExit()
        
        if curl.terminationStatus != 0 {
            throw NSError(domain: "download", code: Int(curl.terminationStatus),
                         userInfo: [NSLocalizedDescriptionKey: "Download failed"])
        }
        
        let finalSizeMB = Double((try? FileManager.default.attributesOfItem(atPath: destPath)[.size] as? Int64) ?? 0) / 1_000_000.0
        let totalTime = Date().timeIntervalSince(startTime)
        
        DispatchQueue.main.async {
            self.downloadPercent = 100
            self.downloadSpeed = ""
            self.downloadInfo = String(format: "%.1f MB downloaded in %.0fs", finalSizeMB, totalTime)
        }
        
        // chmod +x
        let chmod = Process()
        chmod.launchPath = "/bin/chmod"
        chmod.arguments = ["+x", destPath]
        chmod.launch()
        chmod.waitUntilExit()
        
        addLog("Installer binary ready")
    }
    
    private func runInstallerBinary() throws {
        addLog("Running installer...")
        
        DispatchQueue.main.async {
            self.currentActionText = "Installing Hydrogen & Roblox..."
            self.downloadInfo = "This may take a few minutes"
            self.downloadSpeed = ""
            self.downloadPercent = 0
        }
        
        let arch = NSRunningApplication.current.executableArchitecture
        let archName = arch == NSBundleExecutableArchitectureARM64 ? "ARM64" : "x86_64"
        
        addLog("Architecture: \(archName)")
        
        let command = """
        rm -rf '/Applications/Hydrogen-M.app' '/Applications/Hydrogen.app' '/Applications/Roblox.app'; \
        '\(installerBin)' \
        --hydrogen-url '\(hydrogenMURL)' \
        --roblox-url-arm '\(robloxURL_ARM)' \
        --roblox-url-x86 '\(robloxURL_X86)'
        """
        let appleScriptCommand = "do shell script \"\(escapeForAppleScript(command))\" with administrator privileges"

        let installer = Process()
        installer.launchPath = "/usr/bin/osascript"
        installer.arguments = ["-e", appleScriptCommand]
        
        let outputPipe = Pipe()
        installer.standardOutput = outputPipe
        installer.standardError = outputPipe
        
        installer.launch()
        
        let startTime = Date()
        var lastUpdate = Date()
        
        while installer.isRunning {
            guard isInstalling else { installer.terminate(); throw NSError(domain: "", code: -1, userInfo: nil) }
            
            let now = Date()
            if now.timeIntervalSince(lastUpdate) > 1.0 {
                DispatchQueue.main.async {
                    let elapsed = now.timeIntervalSince(startTime)
                    self.progress = 45.0 + min(elapsed / 120.0, 1.0) * 35.0
                    self.currentActionText = String(format: "Installing... (%.0fs)", elapsed)
                }
                lastUpdate = now
            }
            
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        installer.waitUntilExit()
        
        if installer.terminationStatus != 0 {
            let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let outputStr = String(data: output, encoding: .utf8) ?? ""
            throw NSError(domain: "installer", code: Int(installer.terminationStatus),
                         userInfo: [NSLocalizedDescriptionKey: outputStr])
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        addLog(String(format: "Installer completed in %.0fs", totalTime))
        
        DispatchQueue.main.async {
            self.downloadInfo = ""
        }
    }

    private func escapeForAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
    
    private func clearPreferences() throws {
        addLog("Clearing Roblox preferences...")
        
        let domains = [
            "com.roblox.RobloxPlayer",
            "com.roblox.RobloxStudio",
            "com.roblox.Retention",
            "com.roblox.RobloxStudioChannel",
            "com.roblox.RobloxPlayerChannel"
        ]
        
        for domain in domains {
            let p = Process()
            p.launchPath = "/usr/bin/defaults"
            p.arguments = ["delete", domain]
            p.launch()
            p.waitUntilExit()
        }
        
        let killall = Process()
        killall.launchPath = "/usr/bin/killall"
        killall.arguments = ["cfprefsd"]
        killall.launch()
        killall.waitUntilExit()
        
        addLog("Preferences cleared")
    }
    
    private func finalizeSetup() throws {
        addLog("Cleaning up installer binary...")
        try? FileManager.default.removeItem(atPath: installerBin)
        
        addLog("Refreshing system...")
        let lsregister = Process()
        lsregister.launchPath = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        lsregister.arguments = ["-r", "-domain", "local", "-domain", "system", "-domain", "user"]
        lsregister.launch()
        lsregister.waitUntilExit()
        
        addLog("Setup finalized")
    }
    
    private func getFileSize(url: URL) throws -> Int64 {
        let headTask = Process()
        headTask.launchPath = "/usr/bin/curl"
        headTask.arguments = ["-sI", "-L", url.absoluteString]
        let headPipe = Pipe()
        headTask.standardOutput = headPipe
        headTask.launch()
        headTask.waitUntilExit()
        
        let headData = headPipe.fileHandleForReading.readDataToEndOfFile()
        if let headStr = String(data: headData, encoding: .utf8) {
            for line in headStr.components(separatedBy: "\n") {
                if line.lowercased().hasPrefix("content-length:") {
                    let sizeStr = line.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces)
                    return Int64(sizeStr) ?? 0
                }
            }
        }
        return 0
    }
    
    private func addLog(_ msg: String) {
        DispatchQueue.main.async {
            let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            self.logMessages.append("[\(ts)] \(msg)")
        }
    }
}

// MARK: - Success Popup
struct SuccessPopupView: View {
    @Binding var isPresented: Bool
    @Binding var showCheckmark: Bool
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea().onTapGesture { dismiss() }
            
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color.green).frame(width: 76, height: 76)
                    if showCheckmark {
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(scale)
                            .onAppear {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { scale = 1.0 }
                            }
                    }
                }
                
                Text("Installation Complete")
                    .font(.title3).fontWeight(.semibold)
                
                Text("Hydrogen-M installed successfully!\nEnjoy the experience!")
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                
                VStack(spacing: 6) {
                    AppRowView(icon: "app.fill", name: "Hydrogen.app")
                    AppRowView(icon: "app.fill", name: "Hydrogen-M.app")
                    AppRowView(icon: "gamecontroller.fill", name: "Roblox.app")
                }
                .padding()
                .installerGlassCard(cornerRadius: 12, fillOpacity: 0.45)
                .padding(.horizontal)
                
                Button("Done") { dismiss() }
                    .installerPrimaryButton().controlSize(.large).padding(.horizontal).padding(.bottom)
            }
            .frame(width: 320)
            .installerGlassCard(cornerRadius: 16, fillOpacity: 0.7)
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .scaleEffect(scale).opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { scale = 1.0; opacity = 1.0 }
            }
        }
        .transition(.opacity)
    }
    
    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.2)) { scale = 0.8; opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false; showCheckmark = false
        }
    }
}

struct AppRowView: View {
    let icon: String
    let name: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.caption)
            Text(name)
                .font(.caption)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        }
    }
}

// MARK: - Error Popup
struct ErrorPopupView: View {
    @Binding var isPresented: Bool
    let message: String
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var shakeOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea().onTapGesture { dismiss() }
            
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color.red).frame(width: 76, height: 76)
                    Image(systemName: "xmark")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: shakeOffset)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.interpolatingSpring(stiffness: 100, damping: 5)) { shakeOffset = -10 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.interpolatingSpring(stiffness: 100, damping: 5)) { shakeOffset = 10 }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.interpolatingSpring(stiffness: 100, damping: 5)) { shakeOffset = 0 }
                        }
                    }
                }
                
                Text("Installation Failed")
                    .font(.title3).fontWeight(.semibold)
                
                ScrollView {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                        .padding(.horizontal)
                }
                .frame(maxHeight: 220)
                
                HStack(spacing: 12) {
                    Button("Cancel") { dismiss() }.installerSecondaryButton().controlSize(.large)
                    Button("Copy Error") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message, forType: .string)
                    }
                    .installerSecondaryButton()
                    .controlSize(.large)
                    Button("Try Again") { dismiss() }.installerPrimaryButton().controlSize(.large)
                }
                .padding(.horizontal).padding(.bottom)
            }
            .frame(width: 420)
            .installerGlassCard(cornerRadius: 16, fillOpacity: 0.7)
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .scaleEffect(scale).opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { scale = 1.0; opacity = 1.0 }
            }
        }
        .transition(.opacity)
    }
    
    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.2)) { scale = 0.8; opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { isPresented = false }
    }
}

struct ConsolePopupView: View {
    @Binding var isPresented: Bool
    let messages: [String]
    @State private var scale: CGFloat = 0.96
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                HStack {
                    Label("Console", systemImage: "terminal")
                        .font(.headline)
                    Spacer()
                    Button("Close") { dismiss() }
                        .installerSecondaryButton()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(messages, id: \.self) { msg in
                            Text(msg)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(minHeight: 220, maxHeight: 360)
            }
            .frame(width: 560)
            .installerGlassCard(cornerRadius: 16, fillOpacity: 0.78)
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
        .transition(.opacity)
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.18)) {
            scale = 0.96
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            isPresented = false
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var installer: InstallerManager
    @State private var showLog = false
    @State private var animateHeader = false
    @State private var animateBackground = false
    @State private var animateFlowArrow = false
    private let compactLayoutWidth: CGFloat = 760
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.90, green: 0.95, blue: 1.0),
                    Color(red: 0.92, green: 0.94, blue: 1.0),
                    Color(red: 0.91, green: 0.98, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.cyan.opacity(0.22))
                .frame(width: 360, height: 360)
                .blur(radius: 42)
                .offset(x: animateBackground ? -140 : -40, y: animateBackground ? -210 : -130)
                .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animateBackground)

            Circle()
                .fill(Color.blue.opacity(0.20))
                .frame(width: 300, height: 300)
                .blur(radius: 48)
                .offset(x: animateBackground ? 150 : 60, y: animateBackground ? 220 : 140)
                .animation(.easeInOut(duration: 9.5).repeatForever(autoreverses: true), value: animateBackground)

            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: 250, height: 250)
                .blur(radius: 45)
                .offset(x: animateBackground ? 180 : 95, y: animateBackground ? -180 : -70)
                .animation(.easeInOut(duration: 11).repeatForever(autoreverses: true), value: animateBackground)

            GeometryReader { proxy in
                let isCompact = proxy.size.width < compactLayoutWidth
                let stepPanelHeight = isCompact
                    ? max(210, min(380, proxy.size.height * 0.48))
                    : max(250, min(460, proxy.size.height * 0.54))

                VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(
                                colors: [Color.accentColor, Color.blue.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 64, height: 64)
                            .installerGlassCard(cornerRadius: 20, fillOpacity: 0.35)
                        
                        Image(systemName: "bolt.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .scaleEffect(animateHeader ? 1.08 : 0.94)
                            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: animateHeader)
                    }
                    
                    VStack(spacing: 4) {
                        Text("Hydrogen-M Installer")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("Next-Gen Roblox Experience")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 22)
                .padding(.bottom, 16)
                
                // Progress Section
                VStack(spacing: 14) {
                    // Main progress
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.white.opacity(0.7))
                                .frame(height: 10)
                            
                            RoundedRectangle(cornerRadius: 7)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: (installer.progress / 100) * geometry.size.width, height: 10)
                                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: installer.progress)
                        }
                    }
                    .frame(height: 10)
                    
                    // Download progress
                    if !installer.downloadSpeed.isEmpty {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.7))
                                    .frame(height: 5)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(0.85))
                                    .frame(width: (installer.downloadPercent / 100) * geometry.size.width, height: 5)
                                    .animation(.linear(duration: 0.1), value: installer.downloadPercent)
                            }
                        }
                        .frame(height: 5)
                    }
                    
                    // Status
                    HStack {
                        if installer.isInstalling {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text(installer.currentActionText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if !installer.downloadSpeed.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down")
                                    .font(.caption2)
                                Text(installer.downloadSpeed)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        Text("\(Int(installer.progress))%")
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    
                    if !installer.downloadInfo.isEmpty {
                        Text(installer.downloadInfo)
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 14)
                .installerGlassCard(cornerRadius: 16, fillOpacity: 0.72)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                
                if isCompact {
                    animatedStepSection(height: stepPanelHeight)
                    .installerGlassCard(cornerRadius: 16, fillOpacity: 0.55)
                    .padding(.horizontal, 24)
                } else {
                    HStack(alignment: .top, spacing: 14) {
                        animatedStepSection(height: stepPanelHeight)
                        .frame(maxWidth: .infinity, minHeight: stepPanelHeight, maxHeight: stepPanelHeight, alignment: .top)
                        .installerGlassCard(cornerRadius: 16, fillOpacity: 0.55)

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Console Popup", systemImage: "terminal")
                                .font(.subheadline.weight(.semibold))
                            Text("Konsole öffnet sich als Overlay und stört das Layout nicht.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: stepPanelHeight, maxHeight: stepPanelHeight, alignment: .topLeading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .installerGlassCard(cornerRadius: 16, fillOpacity: 0.5)
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer(minLength: 0)
                
                // Footer
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                            Text("Uses native macOS admin prompt")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Cancel") {
                            installer.cancelInstallation()
                        }
                        .disabled(!installer.isInstalling)
                        .installerSecondaryButton()

                        Button("Console") {
                            showLog = true
                        }
                        .disabled(installer.logMessages.isEmpty)
                        .installerSecondaryButton()
                        
                        Button(action: { installer.startInstallation() }) {
                            HStack(spacing: 6) {
                                if installer.isInstalling {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .tint(.white)
                                }
                                Text(installer.isInstalling ? "Installing..." : (hasExistingInstallation ? "Update / Reinstall" : "Install"))
                            }
                            .frame(minWidth: isCompact ? 78 : 110)
                        }
                        .disabled(installer.isInstalling)
                        .installerPrimaryButton()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .installerGlassCard(cornerRadius: 0, fillOpacity: 0.3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.75), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 24, y: 14)
            )
            .onAppear {
                animateHeader = true
                animateBackground = true
                animateFlowArrow = true
            }
            .padding(16)
            
            // Success/Error Popups
            if installer.showSuccessPopup {
                SuccessPopupView(isPresented: $installer.showSuccessPopup, showCheckmark: $installer.showCheckmark)
            }
            if installer.showErrorPopup {
                ErrorPopupView(isPresented: $installer.showErrorPopup, message: installer.errorMessage)
            }
            if showLog {
                ConsolePopupView(isPresented: $showLog, messages: installer.logMessages)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: installer.showErrorPopup)
    }
    
    private func stepBackgroundColor(_ status: StepStatus) -> Color {
        switch status {
        case .waiting: return Color(.controlBackgroundColor)
        case .running: return .accentColor
        case .done: return .green
        case .failed: return .red
        }
    }

    private var hasExistingInstallation: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: "/Applications/Hydrogen.app")
            || fm.fileExists(atPath: "/Applications/Hydrogen-M.app")
            || fm.fileExists(atPath: "/Applications/Roblox.app")
    }

    private func stepRow(_ step: StepItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(stepBackgroundColor(step.status))
                    .frame(width: 36, height: 36)

                if step.status == .running {
                    ProgressView()
                        .scaleEffect(0.72)
                        .tint(.white)
                } else if step.status == .done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                } else if step.status == .failed {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: step.icon)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(step.status == .waiting ? .secondary : .primary)
                Text(step.detail)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(step.status == .running ? .accentColor : .secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(step.status == .running ? 0.8 : 0.45))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(step.status == .running ? 1.015 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step.status)
    }

    private func animatedStepSection(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                ForEach(Array(installer.steps.enumerated()), id: \.element.id) { index, step in
                    Circle()
                        .fill(stepDotColor(index: index, status: step.status))
                        .frame(width: index == installer.activeStepIndex ? 9 : 7, height: index == installer.activeStepIndex ? 9 : 7)
                        .scaleEffect(index == installer.activeStepIndex ? 1.15 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: installer.activeStepIndex)
                }
            }
            .padding(.bottom, 14)

            Spacer(minLength: 0)

            ZStack {
                if let step = displayedStep {
                    HStack(spacing: 12) {
                        stepRow(step)

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 40, weight: .bold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.accentColor)
                            .offset(x: animateFlowArrow ? 11 : -11)
                            .opacity(0.95)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animateFlowArrow)
                    }
                    .id(step.id)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: installer.activeStepIndex)

            Spacer(minLength: 0)

            Text("\(installer.activeStepIndex + 1) / \(installer.steps.count)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
    }

    private var displayedStep: StepItem? {
        guard !installer.steps.isEmpty else { return nil }
        let clamped = min(max(installer.activeStepIndex, 0), installer.steps.count - 1)
        return installer.steps[clamped]
    }

    private func stepDotColor(index: Int, status: StepStatus) -> Color {
        if index == installer.activeStepIndex { return .accentColor }
        switch status {
        case .done: return .green
        case .failed: return .red
        case .running: return .accentColor.opacity(0.6)
        case .waiting: return Color.secondary.opacity(0.35)
        }
    }
}

private extension View {
    @ViewBuilder
    func installerPrimaryButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    func installerSecondaryButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func installerGlassCard(cornerRadius: CGFloat, fillOpacity: Double) -> some View {
        if #available(macOS 26.0, *) {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(fillOpacity))
                )
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(fillOpacity))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                )
        }
    }
}

// MARK: - App
@main
struct HydrogenMInstallerApp: App {
    @StateObject private var installer = InstallerManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(installer)
        }
        .defaultSize(width: 430, height: 620)
        .windowResizability(.automatic)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
