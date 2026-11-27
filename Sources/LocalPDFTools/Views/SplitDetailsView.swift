import PDFEngine
import SwiftUI

/// 分割のカードの中身: 分け方・「ページを見て分ける…」・いくつに分かれるか・しおりの注意
struct SplitDetailsView: View {
    @Bindable var workspace: Workspace
    @Binding var showsSplitSheet: Bool

    var body: some View {
        SplitOptionsForm(split: workspace.split, fileCount: workspace.files.count)
        Button {
            showsSplitSheet = true
        } label: {
            Label("ページを見て分ける…", systemImage: "square.grid.2x2")
        }
        .disabled(workspace.files.isEmpty)
        resultLine
        Text("保存のときに場所を選ぶと、そこに新しいフォルダを作って入れます").foregroundStyle(.secondary)
        Text("しおり（目次）と文書内のリンクは残りません（URL のリンクは残ります）").foregroundStyle(.secondary)
        if workspace.files.contains(where: \.hasOutline) {
            Label("しおりのある PDF が含まれています", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }

    /// いくつに分かれるか（ファイルが 1 つでページ数が分かるときだけ数を出す）
    @ViewBuilder
    private var resultLine: some View {
        if workspace.files.count == 1, let count = workspace.files[0].pageCount {
            switch workspace.split.ranges(pageCount: count) {
            case .success(let ranges):
                Text("\(count) ページ → \(ranges.count) つの PDF").foregroundStyle(.pink)
            case .failure(let error):
                Text(error.localizedDescription).foregroundStyle(.red)
            }
        } else if workspace.files.count > 1 {
            Text("\(workspace.files.count) つの PDF を、それぞれ同じ分け方で分けます").foregroundStyle(.secondary)
        }
    }
}
