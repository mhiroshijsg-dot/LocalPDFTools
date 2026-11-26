import SwiftUI

/// メニュー「ヘルプ」の中身: 「LocalPDFTools のヘルプ」（⌘?）でヘルプの窓を開く。
/// MEMO(2026-11-26・by claude): 標準のままだと「ヘルプは利用できません」としか出ないので置き換える
struct HelpCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("\(AppInfo.name) のヘルプ") {
                openWindow(id: HelpTopic.windowID)
            }
            .keyboardShortcut("?", modifiers: .command)
        }
    }
}
