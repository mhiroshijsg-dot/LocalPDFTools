import PDFEngine
import SwiftUI

/// 保存の欄の上に出す「これから行うこと」: オンにした操作を実行する順に矢印でつなぎ、最後に何ができるかを見せる。
/// 例: [解除] → [回転] → [結合] → 1 つの PDF
struct PlanSummaryView: View {
    let workspace: Workspace
    @AppStorage(OperationOrder.storageKey) private var orderRaw = ""

    var body: some View {
        let steps = ([PipelineStep.decrypt] + OperationOrder.reorderable(from: orderRaw))
            .filter { workspace.selected.contains($0) }
        HStack(spacing: 6) {
            ForEach(steps, id: \.self) { step in
                OperationChip(operation: Operation(step))
                OperationChip.arrow
            }
            Label(result, systemImage: workspace.merges ? "doc.fill" : "doc.on.doc")
                .font(.callout.weight(.semibold))
        }
        .lineLimit(1)
    }

    private var result: String {
        if workspace.merges { return "1 つの PDF にして保存" }
        return workspace.files.count > 1 ? "\(workspace.files.count) つの PDF を別々に保存" : "PDF を保存"
    }

}
