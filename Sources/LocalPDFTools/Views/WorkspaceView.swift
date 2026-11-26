import PDFEngine
import SwiftUI

/// 窓全体（作業台）: 左に PDF の並び、右にやること（操作のカード）、下に「これから行うこと」と保存。
/// 上のツールバーに「追加」と「すべて外す」
struct WorkspaceView: View {
    @Bindable var workspace: Workspace
    @State private var showsRotateSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                FileListView(workspace: workspace)
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                OperationListView(workspace: workspace, showsRotateSheet: $showsRotateSheet)
                    .frame(width: 330)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(Color(nsColor: .windowBackgroundColor))
            }
            if !workspace.messages.isEmpty || !workspace.outcomes.isEmpty {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(workspace.outcomes, id: \.destination) { OutcomeView(outcome: $0) }
                        MessageList(messages: workspace.messages)
                    }
                    .padding(16)
                }
                .frame(maxHeight: 240)
                .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            SaveBar(workspace: workspace)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.bar)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .navigationSubtitle(subtitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    workspace.removeAll()
                } label: {
                    Label("すべて外す", systemImage: "trash")
                }
                .help("入れた PDF をすべて外す（元のファイルは消えません）")
                .disabled(workspace.files.isEmpty || workspace.isWorking)
                Button {
                    let urls = FilePanels().choosePDFs(allowsMultiple: true)
                    if !urls.isEmpty { Task { await workspace.add(urls) } }
                } label: {
                    Label("PDF を追加", systemImage: "plus")
                }
                .help("PDF を追加（ドラッグ＆ドロップでも入れられます）")
                .keyboardShortcut("o")
                .disabled(workspace.isWorking)
            }
        }
        .sheet(isPresented: $showsRotateSheet) {
            RotatePagesSheet(workspace: workspace)
        }
    }

    /// 窓の題名の下に出す一言
    private var subtitle: String {
        workspace.files.isEmpty ? "PDF はこの Mac の中だけで処理します" : "\(workspace.files.count) ファイル"
    }
}

#if DEBUG
#Preview("ファイルあり") {
    WorkspaceView(workspace: PreviewSamples.workspace())
        .frame(width: 980, height: 660)
}

#Preview("空") {
    WorkspaceView(workspace: Workspace())
        .frame(width: 980, height: 660)
}
#endif
