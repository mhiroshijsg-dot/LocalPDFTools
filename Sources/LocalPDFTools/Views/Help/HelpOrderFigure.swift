import PDFEngine
import SwiftUI

/// 操作の順番の図: 今の設定の順を矢印でつなぐ（「これから行うこと」と同じ札）。設定で順番を変えると、ここも変わる
struct HelpOrderFigure: View {
    @AppStorage(OperationOrder.storageKey) private var orderRaw = ""

    var body: some View {
        let order = OperationOrder.reorderable(from: orderRaw)
        VStack(alignment: .leading, spacing: 8) {
            Text("今の設定の順").font(.caption.weight(.medium)).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(Array(([PipelineStep.decrypt] + order).enumerated()), id: \.element) { index, step in
                    if index > 0 { OperationChip.arrow }
                    OperationChip(operation: Operation(step))
                }
            }
            .lineLimit(1)
            Text(order == OperationOrder.recommended ? "おすすめの順です" : "おすすめの順から変えています")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
    }
}
