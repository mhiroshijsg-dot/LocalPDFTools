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
                chip(Operation(step))
                arrow
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

    private func chip(_ operation: Operation) -> some View {
        HStack(spacing: 5) {
            OperationIcon(operation: operation, size: 18)
            Text(shortTitle(operation)).font(.callout.weight(.medium))
        }
        .padding(.leading, 3)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(OperationIcon.color(of: operation).opacity(0.12)))
    }

    /// 矢印の中では短い名前にする
    private func shortTitle(_ operation: Operation) -> String {
        operation == .decrypt ? "解除" : operation.title
    }

    private var arrow: some View {
        Image(systemName: "arrow.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
    }
}
