import PDFEngine
import SwiftUI

/// 分割のシート（印刷の画面の形）: 左に全ファイルのページの縮小表示、右に分け方とできるファイル。
/// ページの間をクリックすると、そこで切る（PDF が 1 つのとき）
struct SplitPagesSheet: View {
    @Bindable var workspace: Workspace
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                OperationIcon(operation: .split, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ページを見て分ける").font(.title3.weight(.semibold))
                    Text(subtitle).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            Divider()
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(Array(workspace.files.enumerated()), id: \.element.id) { index, file in
                            FileSplitSection(number: index + 1, file: file, workspace: workspace)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .underPageBackgroundColor))
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("分け方").font(.headline)
                        SplitOptionsForm(split: workspace.split, fileCount: workspace.files.count, usesRadio: true)
                        if workspace.split.mode == .ranges {
                            Text("「8-」は 8 ページから最後まで。書いた順に 1 つずつのファイルになります")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Divider()
                        Text("できるファイル").font(.headline)
                        SplitPreviewList(workspace: workspace)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: 290)
            }
            Divider()
            HStack {
                Text("しおり（目次）と文書内のリンクは残りません").foregroundStyle(.secondary)
                Spacer()
                Button("完了") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding(16)
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var subtitle: String {
        if workspace.files.count > 1 { return "すべての PDF を、右の同じ分け方で分けます" }
        if workspace.split.mode == .ranges { return "範囲は右の欄に書きます" }
        return "ページの間をクリックすると、そこで切ります"
    }
}
