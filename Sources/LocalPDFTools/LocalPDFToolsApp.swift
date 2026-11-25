import SwiftUI

/// 入口: 画面を組み立てるだけ
@main
struct LocalPDFToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 窓は 1 つだけ（⌘N で増えない）。各機能の状態は ContentView が 1 組だけ持つので、窓が増えると同じ中身が並んでしまう
        Window(AppInfo.name, id: "main") {
            ContentView()
                .frame(minWidth: 760, minHeight: 520)
        }
    }
}
