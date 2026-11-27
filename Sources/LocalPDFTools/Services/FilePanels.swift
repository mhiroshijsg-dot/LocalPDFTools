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

    /// 保存先のフォルダを選ばせる（キャンセルなら nil）
    func chooseFolder(startingAt folder: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "このフォルダに保存")
        panel.directoryURL = folder
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// 分割: 新しいフォルダを作る場所を選ばせる（キャンセルなら nil）。message に何というフォルダを作るかを出す
    func chooseSplitLocation(startingAt folder: URL?, message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "ここに作る")
        panel.message = message
        panel.directoryURL = folder
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// 保存先を選ばせる（キャンセルなら nil）。folder のフォルダ・suggestedName の名前で開き、そこで選び直せる。
    /// 既にあるファイルを選ぶと、ダイアログが上書きしてよいかを確認する。
    func chooseDestination(suggestedName: String, in folder: URL?, message: String? = nil) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        if let message { panel.message = message }
        if let folder { panel.directoryURL = folder }
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// 取り出した文字（.txt）の保存先を選ばせる（キャンセルなら nil）
    func chooseTextDestination(suggestedName: String, in folder: URL?, message: String? = nil) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        if let message { panel.message = message }
        if let folder { panel.directoryURL = folder }
        return panel.runModal() == .OK ? panel.url : nil
    }
}
