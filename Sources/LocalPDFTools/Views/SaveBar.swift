import SwiftUI

/// 下側: これから行うこと・保存名・保存先・「実行して保存…」
struct SaveBar: View {
    @Bindable var workspace: Workspace

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                if workspace.files.isEmpty || workspace.selected.isEmpty {
                    Text(idleText).font(.callout.weight(.medium)).foregroundStyle(.secondary)
                } else {
                    PlanSummaryView(workspace: workspace)
                }
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                    if workspace.splits {
                        GridRow {
                            fieldLabel("フォルダ名")
                            splitFolderRow
                        }
                    } else if workspace.hasSingleOutput {
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

    /// やることを何もオンにしていないときの一言
    private var idleText: String {
        if workspace.files.isEmpty { return String(localized: "PDF を入れて、やることをオンにしてください") }
        // 文字の抽出だけなら、PDF は保存しない（文字はシートで保存する）
        if workspace.extractsText { return String(localized: "文字は「文字を見る…」のシートでコピー・保存します。PDF も加工するなら、ほかの操作もオンに") }
        return String(localized: "やることをオンにしてください")
    }

    private func fieldLabel(_ text: LocalizedStringKey) -> some View {
        Text(text).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
    }

    /// 分割: 分けた PDF を入れる新しいフォルダの名前（ファイルが 1 つのときだけ書き換えられる）
    @ViewBuilder
    private var splitFolderRow: some View {
        if workspace.files.count == 1 {
            HStack(spacing: 8) {
                TextField("フォルダ名", text: $workspace.splitFolderName)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 200, maxWidth: 340)
                Text("中は \(SuggestedName.baseName(workspace.files[0].url))_p1-3.pdf など")
                    .font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
        } else {
            Text("ファイルごとに「元の名前_split」を新しく作ります（中は 元の名前_p1-3.pdf など）")
                .font(.callout).foregroundStyle(.secondary)
        }
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
        return workspace.files.isEmpty ? "—" : String(localized: "それぞれの元のファイルのフォルダ（保存のときに選び直せます）")
    }
}
