import AppKit
import UniformTypeIdentifiers

@MainActor
protocol AppFilePicking {
    func pickApplication() -> URL?
}

@MainActor
struct NSOpenPanelAppPicker: AppFilePicking {
    func pickApplication() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose an Application"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(filePath: "/Applications")

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
