import SwiftUI

/// まだ作っていない機能の画面
struct ComingSoonView: View {
    let tool: Tool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: tool.symbolName).font(.system(size: 40)).foregroundStyle(.secondary)
            Text(tool.title).font(.title2)
            if let stage = tool.plannedStage {
                Text("この機能は段階 \(stage) で作ります。").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(tool.title)
    }
}
