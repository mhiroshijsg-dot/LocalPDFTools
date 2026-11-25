import AppKit
import UniformTypeIdentifiers

/// 「開く」と「保存」のダイアログ
@MainActor
struct FilePanels {
    /// PDF を選ばせる（キャンセルなら空）
    func choosePDFs(allowsMultiple: Bool) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = allowsMultiple
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.urls : []
    }

    /// 保存先を選ばせる（キャンセルなら nil）。
    /// 既にあるファイルを選ぶと、ダイアログが上書きしてよいかを確認する。
    func chooseDestination(suggestedName: String, nextTo reference: URL?) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        // 既定の保存先は決めない。最初は入力と同じフォルダを開くだけ
        if let reference {
            panel.directoryURL = reference.deletingLastPathComponent()
        }
        return panel.runModal() == .OK ? panel.url : nil
    }
}
