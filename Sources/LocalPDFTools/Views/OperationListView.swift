import PDFEngine
import SwiftUI

/// 右側: 行う操作のカード（スイッチをオンにしたものを、上から順に実行する）
struct OperationListView: View {
    @Bindable var workspace: Workspace
    @Binding var showsRotateSheet: Bool
    @Binding var showsTextSheet: Bool
    @Binding var showsSplitSheet: Bool
    @AppStorage(OperationOrder.storageKey) private var orderRaw = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("やること").font(.title3.weight(.semibold))
                    Text("オンにした操作を、上から順に行います").font(.callout).foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
                ForEach([PipelineStep.decrypt] + OperationOrder.reorderable(from: orderRaw), id: \.self) { step in
                    OperationCard(operation: Operation(step), isOn: binding(step), blockedReason: blockedReason(step)) {
                        details(step)
                    }
                }
                // 文字の抽出は PDF の保存の流れに入らないので、順番の設定とは別に最後に置く
                OperationCard(operation: .text, isOn: $workspace.extractsText) {
                    TextExtractionDetailsView(workspace: workspace, showsTextSheet: $showsTextSheet)
                }
                ForEach(Operation.upcoming) { operation in
                    OperationCard(operation: operation, isOn: .constant(false), isAvailable: false) { EmptyView() }
                }
                Label("順番は設定（⌘,）で変えられます。暗号化の解除はいつも最初です。", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .disabled(workspace.isWorking)
    }

    private func binding(_ step: PipelineStep) -> Binding<Bool> {
        Binding(get: { workspace.selected.contains(step) },
                set: { isOn in
                    if isOn { workspace.selected.insert(step) } else { workspace.selected.remove(step) }
                })
    }

    /// 結合と分割は同時にオンにできない（片方がオンなら、もう片方のスイッチを押せなくする）
    private func blockedReason(_ step: PipelineStep) -> String? {
        switch step {
        case .merge where workspace.splits: return String(localized: "分割と同時には使えません")
        case .split where workspace.merges: return String(localized: "結合と同時には使えません")
        default: return nil
        }
    }

    @ViewBuilder
    private func details(_ step: PipelineStep) -> some View {
        switch step {
        case .decrypt:
            let restricted = workspace.files.filter { $0.encryption.status == .restricted }.count
            let locked = workspace.files.filter(\.isLocked).count
            if restricted + locked == 0 {
                Text("暗号化された PDF はありません").foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    if restricted > 0 { Badge(text: "制限あり \(restricted)", symbol: "lock", tint: .orange) }
                    if locked > 0 { Badge(text: "要パスワード \(locked)", symbol: "lock.fill", tint: .red) }
                }
                if locked > 0 {
                    Text("パスワードは、実行中に必要になった時点で聞きます").foregroundStyle(.secondary)
                }
            }
        case .rotate:
            let pages = workspace.files.reduce(0) { $0 + $1.rotatedPageCount }
            Button {
                showsRotateSheet = true
            } label: {
                Label("ページを見て回す…", systemImage: "square.grid.2x2")
            }
            .disabled(workspace.files.isEmpty)
            Text(pages == 0 ? "回すページはまだありません" : "\(pages) ページを回す予定")
                .foregroundStyle(pages == 0 ? Color.secondary : Color.blue)
        case .merge:
            Text("しおり（目次）と文書内のリンクは残りません（URL のリンクは残ります）")
                .foregroundStyle(.secondary)
            if workspace.merges && workspace.files.contains(where: \.hasOutline) {
                Label("しおりのある PDF が含まれています", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        case .split:
            SplitDetailsView(workspace: workspace, showsSplitSheet: $showsSplitSheet)
        case .compress:
            CompressionDetailsView(workspace: workspace)
        }
    }
}
