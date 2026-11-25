import AppKit

/// アプリ全体の振る舞いのうち、SwiftUI だけでは決められないもの
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 窓を閉じたらアプリも終わる。
    /// MEMO(2026-11-25・by claude): Mac の標準では窓を閉じてもアプリは動き続ける。そのため次に起動しても
    /// 窓の無いアプリが前に出るだけで、窓が出てこなかった。窓が 1 つだけのアプリなので閉じたら終える。
    /// （起動時に前へ出す処理は、Xcode のプロジェクトに移って ⌘R でも .app として起動するようになったので外した）
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
