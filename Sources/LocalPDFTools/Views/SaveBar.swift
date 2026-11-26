import SwiftUI

/// 下側: これから行うこと・保存名・保存先・「実行して保存…」
struct SaveBar: View {
    @Bindable var workspace: Workspace

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                if workspace.files.isEmpty || workspace.selected.isEmpty {
                    Text(workspace.files.isEmpty ? "PDF を入れて、やることをオンにしてください" : "やることをオンにしてください")
                        .font(.callout.weight(.medium)).foregroundStyle(.secondary)
                } else {
                    PlanSummaryView(workspace: workspace)
                }
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                    if workspace.hasSingleOutput {
                        GridRow {
                            fieldLabel("保存名")
                            OutputNameField(name: $workspace.outputName)
                        }
                    } else if workspace.files.count > 1 {
                        GridRow {
                            fieldLabel("保存名")
                            Text("ファイルごとに保存のダイアログで決めます（初期値は元の名前＋_unlocked・_rotated などの語）")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    GridRow {
                        fieldLabel("保存先")
                        folderRow
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    Task { await WorkspaceRunner(workspace: workspace).run() }
                } label: {
                    HStack(spacing: 6) {
                        if workspace.isWorking {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text("実行して保存…")
                    }
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)
                .keyboardShortcut("s")
                .disabled(workspace.blocker != nil || workspace.isWorking)
                if let blocker = workspace.blocker, !workspace.files.isEmpty, !workspace.selected.isEmpty {
                    Text(blocker)
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 260, alignment: .trailing)
                } else {
                    Text("⌘S").font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
        .disabled(workspace.isWorking)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
    }

    private var folderRow: some View {
        HStack(spacing: 8) {
            Label {
                Text(folderText).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
            } icon: {
                Image(systemName: "folder.fill").foregroundStyle(.tint)
            }
            Button("変更…") { workspace.changeFolder() }
                .controlSize(.small)
                .disabled(workspace.files.isEmpty)
            if workspace.chosenFolder != nil {
                Button("元のファイルの場所に戻す") { workspace.resetFolder() }
                    .controlSize(.small)
            }
        }
    }

    private var folderText: String {
        if let folder = workspace.saveFolder {
            return (folder.path as NSString).abbreviatingWithTildeInPath
        }
        return workspace.files.isEmpty ? "—" : "それぞれの元のファイルのフォルダ（保存のときに選び直せます）"
    }
}
