import AppKit

@MainActor
@objc protocol StatusMenuActions: AnyObject {
    @objc func showAbout(_ sender: Any?)
    @objc func showHelp(_ sender: Any?)
    @objc func showPreferences(_ sender: Any?)
    @objc func togglePanel(_ sender: Any?)
    @objc func toggleLaunchAtLogin(_ sender: Any?)
    @objc func deleteSelected(_ sender: Any?)
    @objc func clearHistory(_ sender: Any?)
    @objc func exportHistory(_ sender: Any?)
    @objc func importHistory(_ sender: Any?)
    @objc func selectPosition(_ sender: NSMenuItem)
    @objc func quit(_ sender: Any?)
}
