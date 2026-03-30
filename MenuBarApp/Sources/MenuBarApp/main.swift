import Cocoa

let BACKEND_PATH = "/Volumes/Memory+/AF-LLM/.build/arm64-apple-macosx/release/AF-LLM"

class AppController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    override init() {
        // Load saved settings before super.init()
        let savedTemp = UserDefaults.standard.double(forKey: "temperature")
        temperature = savedTemp == 0 ? 0.7 : savedTemp
        let savedTopP = UserDefaults.standard.double(forKey: "topP")
        topP = savedTopP == 0 ? 0.9 : savedTopP
        let savedMax = UserDefaults.standard.integer(forKey: "maxTokens")
        maxTokens = savedMax == 0 ? 32768 : savedMax
        super.init()
    }
    
    var statusItem: NSStatusItem?
    var menu: NSMenu?
    var settingsWindow: NSWindow?
    var serverProcess: Process?
    var serverRunning = false
    var startStopItem: NSMenuItem?
    // Health check retries on startup
    let maxHealthRetries = 3
    var healthRetryCount = 0
    var intentionalStop = false  // Flag to distinguish intentional vs unexpected stops
    // Startup-report window (popup) — crash-safe implementation
    var startupReportWindow: NSWindow?
    var startupReportTextView: NSTextView?
    var startupLogBuffer: String = ""
    var startupReportVisible: Bool = false
    // Startup log file path (per-user logs)
    let startupLogFilePath = "\(NSHomeDirectory())/Library/Logs/AF-LLM/startup.log"
    // Max size before rotation (2 MB)
    let startupLogMaxSize: UInt64 = 2 * 1024 * 1024
    func appendStartupLog(_ line: String) {
        startupLogBuffer += line + "\n"
        let bufferSnapshot = startupLogBuffer
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.startupReportVisible {
                self.showStartupReport()
            }
            self.startupReportTextView?.string = bufferSnapshot
            self.startupReportTextView?.scrollToEndOfDocument(nil)
        }
        writeStartupLogToFileSync(line)
    }
    
    func writeStartupLogToFileSync(_ text: String) {
        let logLine = "[" + ISO8601DateFormatter().string(from: Date()) + "] " + text + "\n"
        let dir = (startupLogFilePath as NSString).deletingLastPathComponent
        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            // ignore directory creation errors
        }
        if FileManager.default.fileExists(atPath: startupLogFilePath) {
            let fh = FileHandle(forWritingAtPath: startupLogFilePath)
            fh?.seekToEndOfFile()
            if let data = logLine.data(using: .utf8) { fh?.write(data) }
            fh?.closeFile()
        } else {
            if let data = logLine.data(using: .utf8) {
                FileManager.default.createFile(atPath: startupLogFilePath, contents: data, attributes: nil)
            }
        }
        // Rotation check
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: startupLogFilePath)
            if let size = (attrs[.size] as? NSNumber)?.uint64Value, size > startupLogMaxSize {
                let rotatedPath = startupLogFilePath + ".1"
                if FileManager.default.fileExists(atPath: rotatedPath) {
                    try? FileManager.default.removeItem(atPath: rotatedPath)
                }
                try FileManager.default.moveItem(atPath: startupLogFilePath, toPath: rotatedPath)
                FileManager.default.createFile(atPath: startupLogFilePath, contents: nil, attributes: nil)
                startupLogBuffer = ""
            }
        } catch {
            // ignore rotation errors
        }
    }
    
    func showStartupReport() {
        if startupReportWindow != nil {
            startupReportWindow?.makeKeyAndOrderFront(nil)
            return
        }
        let w = NSWindow(contentRect: NSRect(x: 20, y: 40, width: 520, height: 260),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "AF-LLM Startup Report"
        w.level = .floating
        w.delegate = self
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 520, height: 260))
        scroll.autoresizingMask = [.width, .height]
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 520, height: 260))
        tv.isEditable = false
        tv.isRichText = false
        tv.string = startupLogBuffer
        scroll.documentView = tv
        w.contentView?.addSubview(scroll)
        w.makeKeyAndOrderFront(nil)
        startupReportWindow = w
        startupReportTextView = tv
        startupReportVisible = true
    }
    
    func closeStartupReport() {
        startupReportWindow?.close()
        startupReportWindow = nil
        startupReportTextView = nil
        startupReportVisible = false
    }

    @objc func showStartupReportFromMenu() {
        showStartupReport()
    }

    // Settings with UserDefaults persistence
    var temperature: Double {
        didSet { UserDefaults.standard.set(temperature, forKey: "temperature") }
    }
    var topP: Double {
        didSet { UserDefaults.standard.set(topP, forKey: "topP") }
    }
    var maxTokens: Int {
        didSet { UserDefaults.standard.set(maxTokens, forKey: "maxTokens") }
    }

    var tempValueLabel: NSTextField?
    var topPValueLabel: NSTextField?
    var maxTokensValueLabel: NSTextField?
    var endpointValueLabel: NSTextField?
    var statusIndicator: NSTextField?

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === startupReportWindow {
            startupReportWindow = nil
            startupReportTextView = nil
            startupReportVisible = false
        }
    }

    func loadMenuBarIcon() -> NSImage? {
        // Try to load from bundle resources using URL
        let bundle = Bundle.main
        if let url = bundle.url(forResource: "Icon", withExtension: "png"),
           let originalImage = NSImage(contentsOf: url) {
            // Resize to menu bar size (18x18 is good for menu bar)
            let targetSize = NSSize(width: 18, height: 18)
            let resizedImage = NSImage(size: targetSize)
            resizedImage.lockFocus()
            originalImage.draw(in: NSRect(origin: .zero, size: targetSize),
                              from: NSRect(origin: .zero, size: originalImage.size),
                              operation: .copy,
                              fraction: 1.0)
            resizedImage.unlockFocus()
            resizedImage.isTemplate = true
            print("Loaded custom icon from bundle: \(url.path)")
            return resizedImage
        } else {
            print("Failed to load Icon.png from bundle")
        }
        
        // Fallback to system symbol
        if let symbol = NSImage(systemSymbolName: "cpu", accessibilityDescription: "AI") {
            symbol.isTemplate = true
            print("Using system symbol icon")
            return symbol
        }
        
        return nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: 24)
        guard let button = statusItem?.button else { return }

        appendStartupLog("Startup sequence initiated.")
        
        // Set initial icon (gray, stopped)
        updateMenuBarIcon()
        button.toolTip = "AF-LLM Server: Stopped"

        rebuildMenu()
        
        print("MenuBarApp launched")
        appendStartupLog("UI initialized. Ready to Start Server.")
    }
    
    func rebuildMenu() {
        let newMenu = NSMenu()
        
        // Start/Stop item
        let startStop = NSMenuItem(title: serverRunning ? "Stop Server" : "Start Server", 
                                   action: #selector(toggleServer), 
                                   keyEquivalent: "")
        startStop.target = self
        newMenu.addItem(startStop)
        self.startStopItem = startStop
        
        newMenu.addItem(NSMenuItem.separator())
        
        // Settings item
        let settings = NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        newMenu.addItem(settings)
        
        // Show Startup Report
        let report = NSMenuItem(title: "Show Startup Report", action: #selector(showStartupReportFromMenu), keyEquivalent: "")
        report.target = self
        newMenu.addItem(report)
        
        newMenu.addItem(NSMenuItem.separator())
        
        // Stop & Quit item
        let quit = NSMenuItem(title: "Stop & Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        newMenu.addItem(quit)
        
        statusItem?.menu = newMenu
        self.menu = newMenu
    }
    
    func updateMenuBarIcon() {
        guard let button = statusItem?.button else { return }
        
        if serverRunning {
            // Green icon for running state
            if let icon = loadMenuBarIcon() {
                icon.isTemplate = false
                button.image = icon
                button.contentTintColor = NSColor.systemGreen
            } else if let symbol = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Running") {
                symbol.isTemplate = false
                button.image = symbol
                button.contentTintColor = NSColor.systemGreen
            }
            button.toolTip = "AF-LLM Server: Running"
        } else {
            // Rack icon for stopped state - no placeholder
            if let symbol = NSImage(systemSymbolName: "server.rack", accessibilityDescription: "Stopped") {
                symbol.isTemplate = true
                button.image = symbol
            } else if let symbol = NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: "Stopped") {
                symbol.isTemplate = true
                button.image = symbol
            }
            button.contentTintColor = nil
            button.toolTip = "AF-LLM Server: Stopped"
        }
    }

    // Health check to verify backend start
    func healthCheck(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "http://localhost:8080/healthz") else {
            completion(false)
            return
        }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 2.0
        config.timeoutIntervalForResource = 2.0
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: url) { _, response, error in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                completion(true)
            } else {
                completion(false)
            }
        }
        task.resume()
    }

    func retryHealthCheck(_ attempt: Int) {
        guard attempt <= maxHealthRetries else {
            appendStartupLog("Health check failed after \(maxHealthRetries) attempts")
            showAlert(title: "Backend Error", message: "Health check failed. Please check if the backend is accessible at http://localhost:8080/")
            return
        }
        
        healthCheck { [weak self] ok in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if ok {
                    self.serverRunning = true
                    self.rebuildMenu()
                    self.updateMenuBarIcon()
                    self.updateStatusItem()
                    self.appendStartupLog("Backend health OK (attempt \(attempt))")
                    print("Health check OK")
                } else {
                    print("Health check failed, retry \(attempt)/\(self.maxHealthRetries)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.retryHealthCheck(attempt + 1)
                    }
                }
            }
        }
    }

    func updateStatusItem() {
        if serverRunning {
            statusItem?.button?.toolTip = "AF-LLM Server: Running"
        } else {
            statusItem?.button?.toolTip = "AF-LLM Server: Stopped"
        }
        // Update status indicator in settings window if open
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let statusText = self.serverRunning ? "● Running" : "○ Stopped"
            self.statusIndicator?.stringValue = statusText
            self.statusIndicator?.textColor = self.serverRunning ? NSColor.systemGreen : NSColor.secondaryLabelColor
        }
    }

    // Simple user alert helper
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    

    @objc func toggleServer() {
        if serverRunning {
            stopServer()
        } else {
            startServer()
        }
    }
    
    func startServer() {
        print("Starting server...")
        appendStartupLog("Starting AF-LLM backend...")
        
        guard FileManager.default.fileExists(atPath: BACKEND_PATH) else {
            print("ERROR: Backend not found at \(BACKEND_PATH)")
            appendStartupLog("Backend binary not found at \(BACKEND_PATH)")
            showAlert(title: "Error", message: "Backend not found at \(BACKEND_PATH)")
            return
        }
        
        // Reset state
        serverProcess = nil
        serverRunning = false
        intentionalStop = false
        
        // Wait for port to be free before starting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.doStartServer()
        }
    }
    
    func doStartServer() {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: BACKEND_PATH)
        var env = ProcessInfo.processInfo.environment
        env["MODEL_TEMPERATURE"] = String(temperature)
        env["MODEL_TOPP"] = String(topP)
        env["MODEL_MAXTOKENS"] = String(maxTokens)
        proc.environment = env
        
        // Handle unexpected process termination
        proc.terminationHandler = { [weak self] terminatedProcess in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Only update UI if this was unexpected (not an intentional stop)
                if !self.intentionalStop && terminatedProcess === self.serverProcess {
                    self.serverRunning = false
                    self.serverProcess = nil
                    self.rebuildMenu()
                    self.updateMenuBarIcon()
                    self.updateStatusItem()
                    self.appendStartupLog("Server process terminated unexpectedly")
                    print("Server process terminated unexpectedly")
                }
            }
        }
        
        do {
            try proc.run()
            serverProcess = proc
            appendStartupLog("Backend process started (PID \(proc.processIdentifier)). Running health check...")
            
            // Simple delay then check
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.healthCheck { [weak self] ok in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if ok {
                            self.serverRunning = true
                            self.rebuildMenu()
                            self.updateMenuBarIcon()
                            self.updateStatusItem()
                            self.appendStartupLog("Server started successfully")
                            print("Server started successfully")
                        } else {
                            self.appendStartupLog("Health check failed - server may still be starting")
                            // Try one more time
                            self.retryHealthCheck(1)
                        }
                    }
                }
            }
        } catch {
            print("Failed to start: \(error)")
            appendStartupLog("Backend start failed: \(error)")
            showAlert(title: "Start Failed", message: error.localizedDescription)
        }
    }
    
    func stopServer() {
        print("Stopping server...")
        appendStartupLog("Stopping backend...")
        
        intentionalStop = true
        
        if let proc = serverProcess {
            proc.terminate()
            // Wait briefly for process to actually terminate
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.serverProcess = nil
                self?.intentionalStop = false
            }
        }
        serverRunning = false
        rebuildMenu()
        updateMenuBarIcon()
        updateStatusItem()
        appendStartupLog("Server stopped")
        print("Server stopped")
    }

    // Log window removed (no-op)

    @objc func openSettings() {
        // Close existing window safely
        if settingsWindow != nil {
            settingsWindow?.close()
            settingsWindow = nil
        }

        // Use simple frame-based layout only - no Auto Layout mixing
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
                         styleMask: [.titled, .closable], backing: .buffered, defer: true)
        w.title = "AF-LLM Settings"
        w.isReleasedWhenClosed = false
        w.center()

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 280))

        // Header line: icon + title + endpoint
        let headerY: CGFloat = 245
        
        // Status icon in header
        if serverRunning {
            if let icon = loadMenuBarIcon() {
                icon.isTemplate = false
                let iconView = NSImageView(frame: NSRect(x: 20, y: headerY, width: 18, height: 18))
                iconView.image = icon
                content.addSubview(iconView)
            }
        } else {
            if let symbol = NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil) {
                let iconView = NSImageView(frame: NSRect(x: 20, y: headerY, width: 18, height: 18))
                iconView.image = symbol
                content.addSubview(iconView)
            }
        }

        // Title
        let headerTitle = NSTextField(labelWithString: "Model Settings")
        headerTitle.font = NSFont.boldSystemFont(ofSize: 16)
        headerTitle.frame = NSRect(x: 48, y: headerY - 2, width: 160, height: 22)
        content.addSubview(headerTitle)

        // Endpoint label
        let epLabel = NSTextField(labelWithString: "Endpoint:")
        epLabel.font = NSFont.systemFont(ofSize: 12)
        epLabel.textColor = NSColor.secondaryLabelColor
        epLabel.frame = NSRect(x: 220, y: headerY, width: 70, height: 20)
        content.addSubview(epLabel)

        // Endpoint value
        endpointValueLabel = NSTextField(labelWithString: "http://localhost:8080")
        endpointValueLabel?.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        endpointValueLabel?.frame = NSRect(x: 290, y: headerY, width: 100, height: 20)
        endpointValueLabel?.alignment = .left
        if let ep = endpointValueLabel { content.addSubview(ep) }

        // Server status box
        let serverBox = NSBox(frame: NSRect(x: 20, y: 200, width: 360, height: 38))
        serverBox.titlePosition = .noTitle
        serverBox.boxType = .primary
        serverBox.fillColor = NSColor.controlBackgroundColor
        content.addSubview(serverBox)

        let serverLabel = NSTextField(labelWithString: "Server: http://localhost:8080")
        serverLabel.font = NSFont.systemFont(ofSize: 12)
        serverLabel.frame = NSRect(x: 10, y: 8, width: 200, height: 20)
        serverBox.addSubview(serverLabel)

        let statusText = serverRunning ? "● Running" : "○ Stopped"
        statusIndicator = NSTextField(labelWithString: statusText)
        statusIndicator?.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        statusIndicator?.textColor = serverRunning ? NSColor.systemGreen : NSColor.secondaryLabelColor
        statusIndicator?.frame = NSRect(x: 250, y: 8, width: 100, height: 20)
        statusIndicator?.alignment = .right
        if let si = statusIndicator { serverBox.addSubview(si) }

        // Temperature
        let tLabel = NSTextField(labelWithString: "Temperature:")
        tLabel.frame = NSRect(x: 20, y: 160, width: 120, height: 22)
        content.addSubview(tLabel)

        let tSlider = NSSlider(value: temperature, minValue: 0, maxValue: 2, target: self, action: #selector(tempChanged(_:)))
        tSlider.frame = NSRect(x: 140, y: 160, width: 180, height: 24)
        content.addSubview(tSlider)

        tempValueLabel = NSTextField(labelWithString: String(format: "%.2f", temperature))
        tempValueLabel?.frame = NSRect(x: 330, y: 160, width: 50, height: 22)
        tempValueLabel?.alignment = .right
        if let tv = tempValueLabel { content.addSubview(tv) }

        // Top-P
        let pLabel = NSTextField(labelWithString: "Top-P:")
        pLabel.frame = NSRect(x: 20, y: 120, width: 120, height: 22)
        content.addSubview(pLabel)

        let pSlider = NSSlider(value: topP, minValue: 0, maxValue: 1, target: self, action: #selector(topChanged(_:)))
        pSlider.frame = NSRect(x: 140, y: 120, width: 180, height: 24)
        content.addSubview(pSlider)

        topPValueLabel = NSTextField(labelWithString: String(format: "%.2f", topP))
        topPValueLabel?.frame = NSRect(x: 330, y: 120, width: 50, height: 22)
        topPValueLabel?.alignment = .right
        if let pv = topPValueLabel { content.addSubview(pv) }

        // Max Tokens
        let mLabel = NSTextField(labelWithString: "Max Tokens:")
        mLabel.frame = NSRect(x: 20, y: 80, width: 120, height: 22)
        content.addSubview(mLabel)

        let mSlider = NSSlider(value: Double(maxTokens), minValue: 256, maxValue: 32768, target: self, action: #selector(maxChanged(_:)))
        mSlider.frame = NSRect(x: 140, y: 80, width: 180, height: 24)
        content.addSubview(mSlider)

        maxTokensValueLabel = NSTextField(labelWithString: "\(maxTokens)")
        maxTokensValueLabel?.frame = NSRect(x: 330, y: 80, width: 50, height: 22)
        maxTokensValueLabel?.alignment = .right
        if let mv = maxTokensValueLabel { content.addSubview(mv) }

        // Separator
        let sep = NSBox(frame: NSRect(x: 20, y: 50, width: 360, height: 1))
        sep.boxType = .separator
        content.addSubview(sep)

        // Apply button
        let applyBtn = NSButton(frame: NSRect(x: 270, y: 12, width: 110, height: 32))
        applyBtn.title = "Apply & Restart"
        applyBtn.bezelStyle = .rounded
        applyBtn.target = self
        applyBtn.action = #selector(applySettings)
        content.addSubview(applyBtn)

        // Info label
        let infoLabel = NSTextField(labelWithString: "API: /v1/chat/completions")
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = NSColor.secondaryLabelColor
        infoLabel.frame = NSRect(x: 20, y: 18, width: 200, height: 20)
        content.addSubview(infoLabel)

        w.contentView = content
        w.makeKeyAndOrderFront(nil)
        w.orderFrontRegardless()
        settingsWindow = w
    }

    @objc func tempChanged(_ s: NSSlider) {
        temperature = s.doubleValue
        tempValueLabel?.stringValue = String(format: "%.2f", temperature)
    }

    @objc func topChanged(_ s: NSSlider) {
        topP = s.doubleValue
        topPValueLabel?.stringValue = String(format: "%.2f", topP)
    }

    @objc func maxChanged(_ s: NSSlider) {
        maxTokens = Int(s.doubleValue)
        maxTokensValueLabel?.stringValue = "\(maxTokens)"
    }

    @objc func applySettings() {
        appendStartupLog("Applying new settings and restarting...")
        
        // Close settings window first
        settingsWindow?.close()
        settingsWindow = nil
        
        let wasRunning = serverRunning
        
        // Stop server if running
        if wasRunning {
            stopServer()
        }
        
        // Restart after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            if wasRunning {
                self.startServer()
            }
            self.appendStartupLog("Settings applied")
        }
    }

    @objc func quitApp() {
        print("Quitting application...")
        if serverRunning {
            stopServer()
        }
        settingsWindow?.close()
        settingsWindow = nil
        closeStartupReport()
        NSApplication.shared.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppController()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
