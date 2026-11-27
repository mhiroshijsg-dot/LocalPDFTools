import PDFEngine
import SwiftUI

/// 分割のシートの右下: できるファイルの名前とページ数（ファイルが 1 つのとき）。複数ならファイルごとの数
struct SplitPreviewList: View {
    let workspace: Workspace

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(workspace.files) { file in
                if let count = file.pageCount {
                    switch workspace.split.ranges(pageCount: count) {
                    case .success(let ranges):
                        if workspace.files.count == 1 {
                            ForEach(Array(ranges.enumerated()), id: \.offset) { _, range in
                                HStack {
                                    Text(SplitPiece.fileName(base: SuggestedName.baseName(file.url), pages: range))
                                        .lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    Text("\(range.count) ページ").foregroundStyle(.secondary).monospacedDigit()
                                }
                            }
                        } else {
                            Text("\(file.fileName): \(ranges.count) つ").lineLimit(1).truncationMode(.middle)
                        }
                    case .failure(let error):
                        Text(error.localizedDescription).foregroundStyle(.red)
                    }
                } else {
                    Text("\(file.fileName): 解除した後にページ数が分かります").foregroundStyle(.secondary)
                }
            }
        }
        .font(.callout)
    }
}
