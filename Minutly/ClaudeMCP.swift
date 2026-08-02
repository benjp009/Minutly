import AppKit

/// Hooks Minutly up to Claude (and any other MCP client) via the bundled
/// `minutly_mcp.py` server, which reads the plaintext transcript/summary
/// sidecars this app already writes.
///
/// ponytail: no MCP client lives in the app. Minutly is sandboxed, so it can
/// neither run `claude mcp add` nor drive Claude. Everything here is clipboard
/// + LaunchServices, which is all the sandbox allows.
enum ClaudeMCP {
    private static let claudeBundleID = "com.anthropic.claudefordesktop"

    /// The server script, copied into the app bundle by the synchronized-folder
    /// build phase. nil only if the resource failed to ship.
    static var scriptPath: String? {
        Bundle.main.path(forResource: "minutly_mcp", ofType: "py")
    }

    static var isAvailable: Bool { scriptPath != nil }

    static var isClaudeInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: claudeBundleID) != nil
    }

    /// Block to paste into an MCP client's config file.
    static var desktopConfigSnippet: String {
        """
        "minutly": {
          "command": "python3",
          "args": ["\(scriptPath ?? "")"]
        }
        """
    }

    static let desktopConfigPath = "~/Library/Application Support/Claude/claude_desktop_config.json"

    /// The folder the MCP server reads — Minutly's own sandbox container.
    /// macOS shields it from other apps, hence the Full Disk Access step.
    static var dataFolder: String {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
    }

    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    static func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func prompt(for meetingName: String) -> String {
        "Using the minutly MCP server, open the meeting \"\(meetingName)\" and help me turn its action items into follow-ups."
    }

    /// Copies a prompt naming this meeting, then brings Claude forward so the
    /// user only has to paste. Returns false if Claude Desktop isn't installed
    /// (the prompt is on the clipboard either way).
    @discardableResult
    static func ask(about meetingName: String) -> Bool {
        copyToClipboard(prompt(for: meetingName))
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: claudeBundleID) else {
            return false
        }
        NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
        return true
    }
}
