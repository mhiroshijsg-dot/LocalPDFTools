import SwiftUI

/// 左に機能の一覧、右にその機能の画面
struct ContentView: View {
    @State private var selection: Tool? = .merge
    // 各機能の状態はここで持つ。機能を切り替えても、入れたファイルや回した向きが消えない
    @State private var merge = MergeModel()
    @State private var rotate = RotateModel()
    @State private var encryption = EncryptionModel()

    var body: some View {
        NavigationSplitView {
            List(Tool.allCases, selection: $selection) { tool in
                Label {
                    HStack {
                        Text(tool.title)
                        if tool.plannedStage != nil {
                            Text("準備中だよ").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: tool.symbolName)
                }
                .tag(tool)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            switch selection {
            case .merge: MergeView(model: merge)
            case .rotate: RotateView(model: rotate)
            case .encryption: EncryptionView(model: encryption)
            case .some(let tool): ComingSoonView(tool: tool)
            case .none: Text("左から機能を選んでください").foregroundStyle(.secondary)
            }
        }
    }
}
