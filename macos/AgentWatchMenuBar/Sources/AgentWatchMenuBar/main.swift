import AppKit
import Foundation

// ──────────────────────────────────────────────────────────────────────────────
// Configuration
// ──────────────────────────────────────────────────────────────────────────────
let kProjectPathDefaultsKey = "AgentWatchProjectPath"

func isProjectRoot(_ path: String) -> Bool {
    let fm = FileManager.default
    return fm.fileExists(atPath: "\(path)/pyproject.toml")
        && fm.fileExists(atPath: "\(path)/agentwatch/cli.py")
}

func saveProjectPath(_ path: String) {
    UserDefaults.standard.set(path, forKey: kProjectPathDefaultsKey)
}

func findProjectPath() -> String {
    let fm = FileManager.default

    if let envPath = ProcessInfo.processInfo.environment["AGENTWATCH_HOME"],
       isProjectRoot(envPath) {
        return envPath
    }

    if let savedPath = UserDefaults.standard.string(forKey: kProjectPathDefaultsKey),
       isProjectRoot(savedPath) {
        return savedPath
    }

    if let resourcePath = Bundle.main.resourceURL?.appendingPathComponent("AgentWatchProject").path,
       isProjectRoot(resourcePath) {
        return resourcePath
    }

    var url = Bundle.main.bundleURL
    for _ in 0..<8 {
        let candidate = url.path
        if isProjectRoot(candidate) {
            return candidate
        }
        url.deleteLastPathComponent()
    }

    let cwd = fm.currentDirectoryPath
    if isProjectRoot(cwd) {
        return cwd
    }

    let home = NSHomeDirectory()
    let candidates = [
        "\(home)/Projects/agentwatch",
        "\(home)/Projects/AgentWatch",
        "\(home)/Documents/WorkSpace/agentwatch",
        "\(home)/Documents/WorkSpace/AgentWatch",
        "\(home)/Documents/Workspace/agentwatch",
        "\(home)/Documents/Workspace/AgentWatch",
        "\(home)/agentwatch",
        "\(home)/AgentWatch",
    ]
    for candidate in candidates where isProjectRoot(candidate) {
        saveProjectPath(candidate)
        return candidate
    }

    return "\(NSHomeDirectory())/Projects/agentwatch"
}

var kProjectPath = findProjectPath()
var kPythonBin: String { "\(kProjectPath)/.venv/bin/python" }
var kAgentWatchBin: String { "\(kProjectPath)/.venv/bin/agentwatch" }
var kConfigPath: String { "\(kProjectPath)/config.json" }
var kEventsLog: String { "\(kProjectPath)/logs/agentwatch_events.jsonl" }
var kStateFile: String { "\(kProjectPath)/logs/state.json" }
let kClaudeSettings = "\(NSHomeDirectory())/.claude/settings.json"
let kCodexHooks     = "\(NSHomeDirectory())/.codex/hooks.json"

func chooseProjectPath() -> String? {
    let panel = NSOpenPanel()
    panel.title = localized("Select AgentWatch Project Folder", "选择 AgentWatch 项目目录")
    panel.message = localized(
        "Choose the folder that contains pyproject.toml and the agentwatch directory.",
        "请选择包含 pyproject.toml 和 agentwatch 目录的项目文件夹。"
    )
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())

    guard panel.runModal() == .OK, let url = panel.url else {
        return nil
    }

    let path = url.path
    guard isProjectRoot(path) else {
        let alert = NSAlert()
        alert.messageText = localized("Invalid Project Folder", "项目目录无效")
        alert.informativeText = localized(
            "The selected folder must contain pyproject.toml and agentwatch/cli.py.",
            "所选目录必须包含 pyproject.toml 和 agentwatch/cli.py。"
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: localized("OK", "确定"))
        alert.runModal()
        return nil
    }

    saveProjectPath(path)
    return path
}

@discardableResult
func ensureProjectPath(interactive: Bool = false) -> Bool {
    if isProjectRoot(kProjectPath) {
        return true
    }
    if interactive, let selected = chooseProjectPath() {
        kProjectPath = selected
        return true
    }
    return false
}

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

/// Run a subprocess, return (stdout, stderr, exitCode) or nil on timeout / error.
func runCommand(
    executable: String,
    arguments: [String],
    workingDir: String? = nil,
    timeoutSec: Double = 15.0,
    env: [String: String] = [:]
) -> (stdout: String, stderr: String, exitCode: Int32)? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = URL(fileURLWithPath: workingDir ?? kProjectPath)

    var fullEnv = ProcessInfo.processInfo.environment
    for (k, v) in env { fullEnv[k] = v }
    // Ensure .venv Python comes first in PATH
    let venvBin = "\(kProjectPath)/.venv/bin"
    if let path = fullEnv["PATH"] {
        fullEnv["PATH"] = "\(venvBin):\(path)"
    } else {
        fullEnv["PATH"] = venvBin
    }
    process.environment = fullEnv

    let outPipe = Pipe(), errPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError  = errPipe

    do {
        try process.run()
    } catch {
        return ("", "Failed to run \(executable): \(error.localizedDescription)", 127)
    }

    let deadline = DispatchTime.now() + timeoutSec
    let group = DispatchGroup()
    group.enter()
    DispatchQueue.global().async {
        process.waitUntilExit()
        group.leave()
    }
    if group.wait(timeout: deadline) == .timedOut {
        process.terminate()
        return nil
    }

    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
    return (
        String(data: outData, encoding: .utf8) ?? "",
        String(data: errData, encoding: .utf8) ?? "",
        process.terminationStatus
    )
}

func isPython310Plus(_ path: String) -> Bool {
    let result = runCommand(
        executable: path,
        arguments: ["-c", "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)"],
        workingDir: kProjectPath,
        timeoutSec: 3.0
    )
    return result?.exitCode == 0
}

func findPython310Plus() -> String? {
    let fm = FileManager.default
    let candidates = [
        kPythonBin,
        "/usr/local/bin/python3.14",
        "/usr/local/bin/python3.13",
        "/usr/local/bin/python3.12",
        "/usr/local/bin/python3.11",
        "/usr/local/bin/python3.10",
        "/usr/local/bin/python3",
        "/opt/homebrew/bin/python3.14",
        "/opt/homebrew/bin/python3.13",
        "/opt/homebrew/bin/python3.12",
        "/opt/homebrew/bin/python3.11",
        "/opt/homebrew/bin/python3.10",
        "/opt/homebrew/bin/python3"
    ]

    for candidate in candidates where fm.fileExists(atPath: candidate) {
        if isPython310Plus(candidate) {
            return candidate
        }
    }
    return nil
}

/// Call the agentwatch CLI (prefer .venv, then a Python 3.10+ source checkout).
func callAgentWatch(_ args: [String], timeoutSec: Double = 15.0) -> (stdout: String, stderr: String, exitCode: Int32)? {
    let fm = FileManager.default
    if !ensureProjectPath(interactive: false) || !fm.fileExists(atPath: kProjectPath) {
        return ("", "AgentWatch project folder not found: \(kProjectPath)", 127)
    }

    let executable: String
    let fullArgs: [String]
    if fm.fileExists(atPath: kAgentWatchBin),
       fm.fileExists(atPath: kPythonBin),
       isPython310Plus(kPythonBin) {
        executable = kAgentWatchBin
        fullArgs = args
    } else if fm.fileExists(atPath: "\(kProjectPath)/agentwatch/cli.py") {
        guard let python = findPython310Plus() else {
            return ("", "Python 3.10 or newer is required. Install Python 3.10+ or run AgentWatch Setup.command to create .venv.", 127)
        }
        executable = python
        fullArgs = ["-m", "agentwatch.cli"] + args
    } else {
        executable = "/usr/bin/env"
        fullArgs = ["agentwatch"] + args
    }
    return runCommand(executable: executable, arguments: fullArgs, timeoutSec: timeoutSec)
}

/// Mask a string for display: show first 4 + last 3, middle replaced with *.
func maskKey(_ key: String) -> String {
    if key.isEmpty || key == "YOUR_BARK_KEY" { return localized("NOT SET", "未设置") }
    if key.count <= 7 { return String(repeating: "*", count: key.count) }
    let prefix = key.prefix(4)
    let suffix = key.suffix(3)
    let stars = String(repeating: "*", count: max(0, key.count - 7))
    return "\(prefix)\(stars)\(suffix)"
}

/// Read a JSON file, returning the parsed dictionary or nil.
func readJSON(_ path: String) -> [String: Any]? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return obj
}

func formatLocalEventTime(_ timestamp: String) -> String {
    let parser = ISO8601DateFormatter()
    parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = parser.date(from: timestamp) ?? {
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        return fallback.date(from: timestamp)
    }()

    guard let date else {
        return timestamp.count >= 19 ? String(timestamp.prefix(19).suffix(8)) : ""
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: date)
}

func readHookStatus(_ path: String, expectedEvents: [String]) -> (installed: Bool, count: Int) {
    var count = 0
    guard let settings = readJSON(path),
          let hooks = settings["hooks"] as? [String: Any] else {
        return (false, 0)
    }

    for eventName in expectedEvents {
        guard let groups = hooks[eventName] as? [[String: Any]] else { continue }
        var foundForEvent = false
        for group in groups {
            guard let inner = group["hooks"] as? [[String: Any]] else { continue }
            for hook in inner {
                let command = ((hook["command"] as? String) ?? "") + " " + ((hook["commandWindows"] as? String) ?? "")
                if command.range(of: "agentwatch", options: .caseInsensitive) != nil {
                    count += 1
                    foundForEvent = true
                    break
                }
            }
            if foundForEvent { break }
        }
    }

    return (count >= expectedEvents.count, count)
}

// ──────────────────────────────────────────────────────────────────────────────
// Menu localization
// ──────────────────────────────────────────────────────────────────────────────

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case chinese = "zh-Hans"

    static let defaultsKey = "AgentWatchMenuLanguage"

    static var current: AppLanguage {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? defaultLanguage().rawValue
            return AppLanguage(rawValue: raw) ?? .english
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    static func defaultLanguage() -> AppLanguage {
        for language in Locale.preferredLanguages {
            if language.lowercased().hasPrefix("zh") {
                return .chinese
            }
        }
        return .english
    }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "简体中文"
        }
    }
}

func localized(_ english: String, _ chinese: String) -> String {
    switch AppLanguage.current {
    case .english: return english
    case .chinese: return chinese
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Status
// ──────────────────────────────────────────────────────────────────────────────

enum OverallStatus: String {
    case ready       = "Ready"
    case needsSetup  = "Needs Setup"
    case hooksMissing = "Hooks Missing"
    case noBark      = "No Bark Key"
    case recentRisk  = "Recent Risk"

    var icon: String {
        switch self {
        case .ready:        return "●"
        case .needsSetup:   return "○"
        case .hooksMissing: return "◐"
        case .noBark:       return "◌"
        case .recentRisk:   return "⚠"
        }
    }

    var displayName: String {
        switch self {
        case .ready:        return localized("Ready", "就绪")
        case .needsSetup:   return localized("Needs Setup", "需要设置")
        case .hooksMissing: return localized("Hooks Missing", "Hooks 缺失")
        case .noBark:       return localized("No Bark Key", "未配置 Bark Key")
        case .recentRisk:   return localized("Recent Risk", "最近有风险")
        }
    }
}

struct AppStatus {
    var barkOk: Bool
    var barkDisplay: String        // redacted key
    var claudeHooksInstalled: Bool
    var claudeHookCount: Int
    var codexHooksInstalled: Bool
    var codexHookCount: Int
    var taskName: String?
    var allowedPaths: [String]
    var forbiddenPaths: [String]
    var recentEvents: [EventSummary]
    var overall: OverallStatus
    var notificationMode: String   // "actionable" or "verbose"
    var personaTheme: String       // "off", "boss", "heir_male", ...
    var timeoutWatchNotify: Bool   // approval_detection.timeout_watch_notify
}

struct EventSummary: Identifiable {
    let id: String  // timestamp
    let time: String
    let eventType: String
    let title: String
    let risk: String
    let bodyFirstLine: String
    let notified: Bool
}

// ──────────────────────────────────────────────────────────────────────────────
// Status reader — reads files directly (fast, no subprocess).
// ──────────────────────────────────────────────────────────────────────────────

func readAppStatus() -> AppStatus {
    // --- Bark ---
    var barkOk = false
    var barkDisplay = localized("NOT SET", "未设置")
    var configDict: [String: Any]? = nil
    if let config = readJSON(kConfigPath),
       let notifier = config["notifier"] as? [String: Any] {
        configDict = config
        let key = notifier["bark_key"] as? String ?? ""
        barkOk = (!key.isEmpty && key != "YOUR_BARK_KEY")
        barkDisplay = maskKey(key)
    }

    // --- Notification mode ---
    var notificationMode = "actionable"
    if let np = configDict?["notification_policy"] as? [String: Any] {
        notificationMode = np["mode"] as? String ?? "actionable"
    }

    // --- Persona theme ---
    var personaTheme = "off"
    if let pers = configDict?["persona"] as? [String: Any] {
        let enabled = pers["enabled"] as? Bool ?? false
        let theme = pers["theme"] as? String ?? "off"
        personaTheme = enabled ? theme : "off"
    }

    // --- Approval timeout notify ---
    var timeoutWatchNotify = false
    if let ad = configDict?["approval_detection"] as? [String: Any] {
        timeoutWatchNotify = ad["timeout_watch_notify"] as? Bool ?? false
    }

    // --- Hooks (read-only check, never modifies) ---
    let claudeHookStatus = readHookStatus(
        kClaudeSettings,
        expectedEvents: ["PreToolUse", "PostToolUse", "Notification", "Stop", "PermissionRequest", "PermissionDenied"]
    )
    let codexHookStatus = readHookStatus(
        kCodexHooks,
        expectedEvents: ["PreToolUse", "PostToolUse", "Stop", "PermissionRequest"]
    )

    // --- Task ---
    var taskName: String? = nil
    var allowedPaths: [String] = []
    var forbiddenPaths: [String] = []
    if let state = readJSON(kStateFile),
       let task = state["active_task"] as? [String: Any] {
        taskName = task["name"] as? String
        allowedPaths = task["allowed_paths"] as? [String] ?? []
        forbiddenPaths = task["forbidden_paths"] as? [String] ?? []
    }

    // --- Recent events (last 5 non-info) ---
    var recent: [EventSummary] = []
    if let data = try? String(contentsOfFile: kEventsLog, encoding: .utf8) {
        let lines = data.components(separatedBy: "\n").filter { !$0.isEmpty }
        var parsed: [[String: Any]] = []
        for line in lines.suffix(50) {
            if let d = line.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                parsed.append(obj)
            }
        }
        for ev in parsed.reversed() {
            let etype = ev["event_type"] as? String ?? "info"
            if etype == "info" { continue }
            let ts = ev["timestamp"] as? String ?? ""
            let time = formatLocalEventTime(ts)
            let body = ev["body"] as? String ?? ""
            let firstLine = body.components(separatedBy: "\n").first ?? ""
            let wasNotified = ev["notified"] as? Bool ?? false
            recent.append(EventSummary(
                id: ts,
                time: time,
                eventType: etype,
                title: ev["title"] as? String ?? "",
                risk: ev["risk"] as? String ?? "低",
                bodyFirstLine: firstLine,
                notified: wasNotified
            ))
            if recent.count >= 5 { break }
        }
    }

    // --- Overall ---
    let hasRecentRisk = recent.contains { ["danger", "drift", "failure"].contains($0.eventType) }
    let overall: OverallStatus
    if !barkOk {
        overall = .noBark
    } else if !claudeHookStatus.installed && !codexHookStatus.installed {
        overall = .hooksMissing
    } else if hasRecentRisk {
        overall = .recentRisk
    } else if !barkOk && !claudeHookStatus.installed && !codexHookStatus.installed {
        overall = .needsSetup
    } else {
        overall = .ready
    }

    return AppStatus(
        barkOk: barkOk,
        barkDisplay: barkDisplay,
        claudeHooksInstalled: claudeHookStatus.installed,
        claudeHookCount: claudeHookStatus.count,
        codexHooksInstalled: codexHookStatus.installed,
        codexHookCount: codexHookStatus.count,
        taskName: taskName,
        allowedPaths: allowedPaths,
        forbiddenPaths: forbiddenPaths,
        recentEvents: recent,
        overall: overall,
        notificationMode: notificationMode,
        personaTheme: personaTheme,
        timeoutWatchNotify: timeoutWatchNotify
    )
}

// ──────────────────────────────────────────────────────────────────────────────
// App Delegate
// ──────────────────────────────────────────────────────────────────────────────

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var lastActionResult: String = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "AW"
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .bold)

        rebuildMenu()
        if !ensureProjectPath(interactive: false) {
            DispatchQueue.main.async { [weak self] in
                if ensureProjectPath(interactive: true) {
                    self?.refreshUI(with: localized("Project folder saved.", "项目目录已保存。"))
                } else {
                    self?.refreshUI(with: localized("Project folder not selected.", "未选择项目目录。"))
                }
            }
        }
    }

    // ── Menu building ────────────────────────────────────────────────────

    private func rebuildMenu() {
        let menu = NSMenu(title: "AgentWatch")
        let status = readAppStatus()
        statusItem.button?.title = "\(status.overall.icon) AW"

        // ── Header ──
        addDisabled(menu, "AgentWatch — \(status.overall.displayName)")
        menu.addItem(.separator())

        // ── Status ──
        addDisabled(menu, "Bark: \(status.barkOk ? "✓ OK" : "✗ \(status.barkDisplay)")")
        addDisabled(menu, "Claude Hooks: \(hookStatusText(installed: status.claudeHooksInstalled, count: status.claudeHookCount, expected: 6))")
        addDisabled(menu, "Codex Hooks: \(hookStatusText(installed: status.codexHooksInstalled, count: status.codexHookCount, expected: 4))")
        addDisabled(menu, "\(localized("Notif Mode", "通知模式")): \(notificationModeDisplayName(status.notificationMode))")
        addDisabled(menu, "\(localized("Persona", "人格包")): \(personaDisplayName(status.personaTheme))")
        addDisabled(menu, "\(localized("Approval Timeout Notify", "审批超时推送")): \(status.timeoutWatchNotify ? localized("On", "开") : localized("Off", "关"))")
        if let task = status.taskName {
            addDisabled(menu, "\(localized("Task", "任务")): \(task)")
            let allowed = status.allowedPaths.prefix(4).joined(separator: ", ")
            let forbidden = status.forbiddenPaths.prefix(4).joined(separator: ", ")
            if !allowed.isEmpty { addDisabled(menu, "  \(localized("Allowed", "允许")): \(allowed)") }
            if !forbidden.isEmpty { addDisabled(menu, "  \(localized("Forbidden", "禁止")): \(forbidden)") }
        } else {
            addDisabled(menu, "\(localized("Task", "任务")): \(localized("(none)", "(无)"))")
        }

        menu.addItem(.separator())

        // ── Recent Events ──
        addDisabled(menu, "\(localized("Recent Events", "最近事件")):")
        if status.recentEvents.isEmpty {
            addDisabled(menu, "  \(localized("(no events yet)", "(暂无事件)"))")
        } else {
            for ev in status.recentEvents {
                let icon = eventIcon(ev.eventType)
                let tag = ev.notified ? localized("notified", "已推送") : localized("logged", "已记录")
                let line = "\(icon) [\(ev.time)] \(ev.title) | \(tag)"
                addDisabled(menu, "  \(line)")
            }
        }

        menu.addItem(.separator())

        // ── Persona Theme ──
        let personaMenu = NSMenuItem(title: localized("Persona Theme", "人格包主题"), action: nil, keyEquivalent: "")
        let personaSubmenu = NSMenu(title: localized("Persona Theme", "人格包主题"))
        let themes: [(String, String)] = [
            ("off", localized("Off", "关闭")), ("boss", "总裁版"), ("heir_male", "少爷版"),
            ("heir_female", "大小姐版"), ("emperor", "皇上版"), ("palace", "甄嬛版"),
        ]
        let currentTheme = status.personaTheme
        for (key, name) in themes {
            let item = NSMenuItem(title: name, action: #selector(selectPersonaTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = key
            item.state = (key == currentTheme) ? .on : .off
            personaSubmenu.addItem(item)
        }
        personaMenu.submenu = personaSubmenu
        menu.addItem(personaMenu)
        menu.addItem(.separator())

        // ── Language ──
        let languageMenu = NSMenuItem(title: localized("Language", "语言"), action: nil, keyEquivalent: "")
        let languageSubmenu = NSMenu(title: localized("Language", "语言"))
        for language in AppLanguage.allCases {
            let item = NSMenuItem(title: language.displayName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.rawValue
            item.state = (language == AppLanguage.current) ? .on : .off
            languageSubmenu.addItem(item)
        }
        languageMenu.submenu = languageSubmenu
        menu.addItem(languageMenu)
        menu.addItem(.separator())

        // ── Actions ──
        addAction(menu, localized("Refresh Status", "刷新状态"),               #selector(refreshStatus))
        addAction(menu, localized("Select Project Folder...", "选择项目目录..."), #selector(selectProjectFolder))
        addAction(menu, localized("Add / Update Bark Key...", "添加 / 更新 Bark Key..."), #selector(updateBarkKey))
        addAction(menu, localized("Show Bark Config", "查看 Bark 配置"),         #selector(showBarkConfig))
        addAction(menu, localized("Test Push", "测试推送"),                    #selector(testPush))
        addAction(menu, localized("Set Task Boundary...", "设置任务边界..."),    #selector(setTaskBoundary))
        addAction(menu, localized("Clear Task Boundary", "清除任务边界"),       #selector(clearTaskBoundary))
        addAction(menu, localized("Install / Update Claude Code Hooks", "安装 / 更新 Claude Code Hooks"), #selector(installClaudeHooks))
        addAction(menu, localized("Install / Update Codex Hooks", "安装 / 更新 Codex Hooks"), #selector(installCodexHooks))

        menu.addItem(.separator())

        addAction(menu, localized("Open Monitor in Terminal", "在终端打开监视器"), #selector(openMonitor))
        addAction(menu, localized("Open Logs Folder", "打开日志文件夹"),          #selector(openLogsFolder))
        addAction(menu, localized("Open README", "打开 README"),                #selector(openReadme))
        addAction(menu, localized("Open config.json", "打开 config.json"),       #selector(openConfig))
        addAction(menu, localized("Copy Setup Commands", "复制安装命令"),        #selector(copySetupCommands))

        menu.addItem(.separator())

        // Last action feedback (if any)
        if !lastActionResult.isEmpty {
            addDisabled(menu, lastActionResult)
            menu.addItem(.separator())
        }

        addAction(menu, localized("Quit", "退出"), #selector(quitApp))

        statusItem.menu = menu
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private func addDisabled(_ menu: NSMenu, _ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addAction(_ menu: NSMenu, _ title: String, _ sel: Selector) {
        let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    private func refreshUI(with result: String? = nil) {
        if let r = result { lastActionResult = r }
        rebuildMenu()
    }

    private func notificationModeDisplayName(_ mode: String) -> String {
        switch mode {
        case "actionable": return localized("actionable", "只推送需处理事件")
        case "verbose":    return localized("verbose", "全部事件")
        default:           return mode
        }
    }

    private func hookStatusText(installed: Bool, count: Int, expected: Int) -> String {
        if installed {
            return "✓ \(localized("Installed", "已安装"))"
        }
        if count <= 0 {
            return "✗ \(localized("Missing", "缺失"))"
        }
        return "✗ \(localized("Partial", "部分安装")) (\(count)/\(expected))"
    }

    private func eventIcon(_ type: String) -> String {
        switch type {
        case "danger":                     return "⚠"
        case "drift":                      return "↗"
        case "failure":                    return "✗"
        case "task_done":                  return "✓"
        case "attention_required":         return "‼"
        case "permission_required":        return "‼"
        case "possible_permission_wait":   return "⏳"
        case "permission_denied":          return "✕"
        default:                           return "·"
        }
    }

    // ── Persona helpers ─────────────────────────────────────────────────

    private func personaDisplayName(_ theme: String) -> String {
        switch theme {
        case "off":         return localized("Off", "关闭")
        case "boss":        return "总裁版"
        case "heir_male":   return "少爷版"
        case "heir_female": return "大小姐版"
        case "emperor":     return "皇上版"
        case "palace":      return "甄嬛版"
        default:            return theme
        }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let language = AppLanguage(rawValue: raw) else { return }
        AppLanguage.current = language
        lastActionResult = localized("Language updated.", "语言已切换。")
        rebuildMenu()
    }

    @objc private func selectPersonaTheme(_ sender: NSMenuItem) {
        guard let theme = sender.representedObject as? String else { return }
        let name = personaDisplayName(theme)
        lastActionResult = localized("Setting persona", "正在设置人格包") + ": \(name)..."
        rebuildMenu()
        DispatchQueue.global().async { [weak self] in
            let args: [String]
            if theme == "off" {
                args = ["persona", "off"]
            } else {
                args = ["persona", "set", theme]
            }
            let result = callAgentWatch(args, timeoutSec: 10.0)
            DispatchQueue.main.async {
                let ok = (result?.exitCode == 0)
                let msg = ok
                    ? localized("Persona theme updated", "人格包主题已更新") + ": \(name)"
                    : localized("Persona update failed.", "人格包更新失败。")
                if ok {
                    // Brief feedback via last result; full status already refreshed below.
                    self?.showInfoDialog(localized("Persona Theme Updated", "人格包主题已更新"), message: msg)
                }
                self?.refreshUI(with: msg)
            }
        }
    }

    // ── Actions ──────────────────────────────────────────────────────────

    @objc private func refreshStatus() {
        DispatchQueue.global().async { [weak self] in
            // No subprocess needed — readAppStatus reads files directly.
            DispatchQueue.main.async {
                self?.refreshUI()
            }
        }
    }

    @objc private func selectProjectFolder() {
        if let selected = chooseProjectPath() {
            kProjectPath = selected
            refreshUI(with: localized("Project folder saved.", "项目目录已保存。"))
        }
    }

    @objc private func testPush() {
        lastActionResult = localized("Testing push...", "正在测试推送...")
        rebuildMenu()
        DispatchQueue.global().async { [weak self] in
            let result = callAgentWatch(["test-push"], timeoutSec: 20.0)
            DispatchQueue.main.async {
                let ok = (result?.exitCode == 0)
                self?.refreshUI(with: ok
                    ? localized("Last: Test push sent ✓", "上次操作：测试推送已发送 ✓")
                    : localized("Last: Test push failed ✗", "上次操作：测试推送失败 ✗"))
            }
        }
    }

    @objc private func setTaskBoundary() {
        guard ensureProjectPath(interactive: true) else {
            refreshUI(with: localized("Project folder is required.", "需要先选择项目目录。"))
            return
        }
        // Open Terminal with agentwatch task quick
        let script = """
        cd '\(kProjectPath)' && source .venv/bin/activate && agentwatch task quick
        """
        runTerminalScript(script)
        // Schedule a refresh after a few seconds to pick up the new task
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.refreshUI()
        }
    }

    @objc private func clearTaskBoundary() {
        guard ensureProjectPath(interactive: true) else {
            refreshUI(with: localized("Project folder is required.", "需要先选择项目目录。"))
            return
        }
        DispatchQueue.global().async { [weak self] in
            _ = callAgentWatch(["task", "clear"], timeoutSec: 5.0)
            DispatchQueue.main.async {
                self?.refreshUI(with: localized("Task boundary cleared.", "任务边界已清除。"))
            }
        }
    }

    @objc private func installClaudeHooks() {
        guard ensureProjectPath(interactive: true) else {
            refreshUI(with: localized("Project folder is required.", "需要先选择项目目录。"))
            return
        }
        guard confirmHookInstall(
            title: localized("Install Claude Code Hooks", "安装 Claude Code Hooks"),
            message: localized(
                "This will install AgentWatch hooks into your Claude Code settings. A backup is created first.",
                "这会把 AgentWatch hooks 写入 Claude Code 配置，并会先创建备份。"
            )
        ) else { return }
        let script = """
        cd '\(kProjectPath)' && bash install_claude_hooks.sh
        """
        runTerminalScript(script)
        refreshUI(with: localized("Claude hooks installer launched.", "Claude hooks 安装器已启动。"))
    }

    @objc private func installCodexHooks() {
        guard ensureProjectPath(interactive: true) else {
            refreshUI(with: localized("Project folder is required.", "需要先选择项目目录。"))
            return
        }
        guard confirmHookInstall(
            title: localized("Install Codex Hooks", "安装 Codex Hooks"),
            message: localized(
                "This will install AgentWatch hooks into your Codex hooks.json. A backup is created first.",
                "这会把 AgentWatch hooks 写入 Codex hooks.json，并会先创建备份。"
            )
        ) else { return }
        let script = """
        cd '\(kProjectPath)' && bash install_codex_hooks.sh
        """
        runTerminalScript(script)
        refreshUI(with: localized("Codex hooks installer launched.", "Codex hooks 安装器已启动。"))
    }

    @objc private func openMonitor() {
        guard ensureProjectPath(interactive: true) else {
            refreshUI(with: localized("Project folder is required.", "需要先选择项目目录。"))
            return
        }
        let script = """
        cd '\(kProjectPath)' && source .venv/bin/activate && agentwatch monitor
        """
        runTerminalScript(script)
    }

    @objc private func openLogsFolder() {
        guard ensureProjectPath(interactive: true) else { return }
        openPath("\(kProjectPath)/logs", kind: localized("Logs folder", "日志文件夹"))
    }

    @objc private func openReadme() {
        guard ensureProjectPath(interactive: true) else { return }
        openPath("\(kProjectPath)/README.md", kind: "README")
    }

    @objc private func openConfig() {
        guard ensureProjectPath(interactive: true) else { return }
        openPath(kConfigPath, kind: "config.json")
    }

    @objc private func copySetupCommands() {
        let cmds = """
        cd ~/Projects/agentwatch
        python3 -m venv .venv
        source .venv/bin/activate
        pip install -e .
        agentwatch init
        agentwatch test-push
        bash install_claude_hooks.sh
        bash install_codex_hooks.sh
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(cmds, forType: .string)
        refreshUI(with: localized("Setup commands copied to clipboard.", "安装命令已复制到剪贴板。"))
    }

    @objc private func updateBarkKey() {
        guard ensureProjectPath(interactive: true) else {
            refreshUI(with: localized("Project folder is required.", "需要先选择项目目录。"))
            return
        }

        let alert = NSAlert()
        alert.messageText = localized("Configure Bark Key", "配置 Bark Key")
        alert.informativeText = localized(
            "Paste your Bark URL or Bark Key.\n\nExamples:\n  https://api.day.app/YOUR_KEY/\n  YOUR_KEY",
            "粘贴你的 Bark URL 或 Bark Key。\n\n示例：\n  https://api.day.app/YOUR_KEY/\n  YOUR_KEY"
        )
        alert.alertStyle = .informational
        alert.addButton(withTitle: localized("Save", "保存"))
        alert.addButton(withTitle: localized("Cancel", "取消"))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        textField.placeholderString = "https://api.day.app/... or key"
        textField.stringValue = ""
        alert.accessoryView = textField

        alert.window.initialFirstResponder = textField

        let response = alert.runModal()
        if response != .alertFirstButtonReturn { return }
        let input = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty { return }

        lastActionResult = localized("Updating Bark key...", "正在更新 Bark Key...")
        rebuildMenu()

        DispatchQueue.global().async { [weak self] in
            let result = callAgentWatch(["config", "bark", "--value", input], timeoutSec: 10.0)
            DispatchQueue.main.async {
                let ok = (result?.exitCode == 0)
                if ok {
                    // Extract the redacted key from stdout for the dialog
                    let out = result?.stdout ?? ""
                    let lines = out.components(separatedBy: "\n")
                    let keyLine = lines.first(where: { $0.lowercased().contains("key updated") }) ?? localized("Bark key updated.", "Bark Key 已更新。")
                    self?.showInfoDialog(localized("Bark Key Updated", "Bark Key 已更新"), message: keyLine.trimmingCharacters(in: .whitespaces))
                } else {
                    let err = result?.stderr ?? result?.stdout ?? localized("Unknown error", "未知错误")
                    self?.showInfoDialog(localized("Error", "错误"), message: err.trimmingCharacters(in: .whitespaces))
                }
                self?.refreshUI()
            }
        }
    }

    @objc private func showBarkConfig() {
        let status = readAppStatus()
        let server = (readJSON(kConfigPath)?["notifier"] as? [String: Any])?["bark_server"] as? String ?? "https://api.day.app"
        let message = """
        Bark:  \(status.barkOk ? "OK" : localized("Missing", "缺失"))
        \(localized("Server", "服务器")): \(server)
        \(localized("Key", "Key")):   \(status.barkDisplay)
        """
        showInfoDialog(localized("Bark Configuration", "Bark 配置"), message: message)
    }

    private func showInfoDialog(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: localized("OK", "确定"))
        alert.runModal()
    }

    private func showWarningDialog(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: localized("OK", "确定"))
        alert.runModal()
    }

    private func openPath(_ path: String, kind: String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            showWarningDialog(
                localized("Cannot Open", "无法打开"),
                message: localized("\(kind) does not exist:\n\(path)", "\(kind) 不存在：\n\(path)")
            )
            refreshUI(with: localized("Open failed: missing file.", "打开失败：文件不存在。"))
            return
        }

        let url = URL(fileURLWithPath: path)
        if NSWorkspace.shared.open(url) {
            refreshUI(with: localized("Opened \(kind).", "已打开 \(kind)。"))
            return
        }

        let result = runCommand(
            executable: "/usr/bin/open",
            arguments: [path],
            workingDir: "/",
            timeoutSec: 5.0
        )
        if result?.exitCode == 0 {
            refreshUI(with: localized("Opened \(kind).", "已打开 \(kind)。"))
            return
        }

        let detail = result?.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? result?.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? localized("Unknown error", "未知错误")
        showWarningDialog(
            localized("Cannot Open", "无法打开"),
            message: "\(kind):\n\(path)\n\n\(detail)"
        )
        refreshUI(with: localized("Open failed.", "打开失败。"))
    }

    private func confirmHookInstall(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: localized("Continue", "继续"))
        alert.addButton(withTitle: localized("Cancel", "取消"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // ── Terminal helper ──────────────────────────────────────────────────

    private func runTerminalScript(_ script: String) {
        // Use osascript to open a new Terminal window and run the script.
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))"
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        try? process.run()
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Entry point
// ──────────────────────────────────────────────────────────────────────────────

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // LSUIElement equivalent
app.run()
