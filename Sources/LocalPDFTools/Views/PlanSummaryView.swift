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
            Label(result, systemImage: workspace.splits ? "folder.fill" : workspace.merges ? "doc.fill" : "doc.on.doc")
                .font(.callout.weight(.semibold))
        }
        .lineLimit(1)
    }

    private var result: String {
        if workspace.splits {
            if workspace.files.count == 1, let count = workspace.files[0].pageCount,
               case .success(let ranges) = workspace.split.ranges(pageCount: count) {
                return String(localized: "\(ranges.count) つの PDF に分けて、新しいフォルダに保存")
            }
            return String(localized: "ファイルごとに分けて、新しいフォルダに保存")
        }
        if workspace.merges { return String(localized: "1 つの PDF にして保存") }
        return workspace.files.count > 1 ? String(localized: "\(workspace.files.count) つの PDF を別々に保存") : String(localized: "PDF を保存")
    }

}
