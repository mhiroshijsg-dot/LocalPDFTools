import PDFEngine
import SwiftUI

/// 文字の抽出のシート: 入れた全ファイルのページごとの文字を並べ、OCR・コピー・.txt の保存をする。PDF は変えない
struct TextExtractionSheet: View {
    let workspace: Workspace
    @Environment(\.dismiss) private var dismiss

    private var model: TextExtractionModel { workspace.text }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                OperationIcon(operation: .text, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("文字の抽出").font(.title3.weight(.semibold))
                    Text("文字の層があるページはそのまま取り出し、無いページは OCR で読みます")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Label("OCR は読み間違えることがあります（ローマ数字の Ⅰ・Ⅱ、〇、数字など）。式や表は崩れることがあります。提出物に使う前に、元の PDF と見比べてください。横倒しのページは、先に「回転」で向きを直すと読めます。",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.09)))
                    ForEach(Array(workspace.files.enumerated()), id: \.element.id) { index, file in
                        FileTextSection(number: index + 1, file: file, workspace: workspace)
                    }
                }
                .padding(20)
            }
            .background(Color(nsColor: .underPageBackgroundColor))
            if !model.saved.isEmpty || !model.messages.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.saved, id: \.self) { url in savedRow(url) }
                    MessageList(messages: model.messages)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            Divider()
            footer.padding(16)
        }
        .frame(minWidth: 780, minHeight: 560)
        // 閉じた後は進み具合が見えないので、OCR は止める（読み終えたページの結果は残る）
        .onDisappear { model.cancelOCR() }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if model.isOCRRunning {
                ProgressView(value: Double(model.ocrDone), total: Double(max(model.ocrTotal, 1)))
                    .frame(width: 120)
                Text(model.ocrDone == 0 ? "OCR の準備中（初めての時は十数秒かかります）"
                                        : "OCR \(model.ocrDone) / \(model.ocrTotal) ページ")
                    .foregroundStyle(.secondary).monospacedDigit()
                Button("中止") { model.cancelOCR() }
            }
            Spacer()
            saveButtons.disabled(model.isReading || workspace.files.isEmpty)
            Button("完了") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
    }

    @ViewBuilder
    private var saveButtons: some View {
        if workspace.files.count > 1 {
            Button {
                TextExportRunner(workspace: workspace).saveEach()
            } label: {
                Label("ファイルごとに保存…", systemImage: "square.and.arrow.down.on.square")
            }
            Button {
                TextExportRunner(workspace: workspace).saveCombined()
            } label: {
                Label("まとめて 1 つの .txt に保存…", systemImage: "square.and.arrow.down")
            }
        } else {
            Button {
                TextExportRunner(workspace: workspace).saveCombined()
            } label: {
                Label(".txt で保存…", systemImage: "square.and.arrow.down")
            }
        }
    }

    private func savedRow(_ url: URL) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text("保存しました: \(url.lastPathComponent)").font(.callout.weight(.medium))
            Text(url.deletingLastPathComponent().path)
                .font(.callout).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
                .textSelection(.enabled)
            Spacer()
            Button("Finder で表示") { DesktopActions.revealInFinder(url) }
                .controlSize(.small)
        }
    }
}

#if DEBUG
#Preview {
    TextExtractionSheet(workspace: PreviewSamples.textWorkspace())
}
#endif
