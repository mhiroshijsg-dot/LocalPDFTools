import SwiftUI

/// 入口: 画面を組み立てるだけ
@main
struct LocalPDFToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    /// 作業台の状態。窓が 1 つなので 1 組だけ持つ
    @State private var workspace = Workspace()

    var body: some Scene {
        // 窓は 1 つだけ（⌘N で増えない）
        Window(AppInfo.name, id: "main") {
            WorkspaceView(workspace: workspace)
                .frame(minWidth: 860, minHeight: 560)
        }
        Settings {
            SettingsView()
        }
    }
}
