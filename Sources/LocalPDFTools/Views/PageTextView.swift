import PDFEngine
import SwiftUI

/// 文字の抽出のシートの、1 ページ分（ページ番号・文字の出どころの札・文字・コピー / OCR のボタン）
struct PageTextView: View {
    let page: PageText
    /// このページを今読んでいるか、これから読む
    let isQueued: Bool
    /// ほかのページを OCR している間は押せない
    let canStartOCR: Bool
    let startOCR: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(page.pageNumber) ページ").font(.callout.weight(.semibold)).monospacedDigit()
                sourceBadge
                Spacer()
                if isQueued {
                    ProgressView().controlSize(.small)
                    Text("読んでいます…").font(.caption).foregroundStyle(.secondary)
                } else {
                    switch page.source {
                    case .none:
                        Button("OCR する", systemImage: "text.viewfinder", action: startOCR)
                            .controlSize(.small)
                            .disabled(!canStartOCR)
                    case .ocr:
                        Button("読み直す", systemImage: "arrow.clockwise", action: startOCR)
                            .controlSize(.small)
                            .disabled(!canStartOCR)
                            .help("向きを直した後などに、もう一度 OCR する")
                    case .textLayer:
                        EmptyView()
                    }
                    if !page.text.isEmpty {
                        Button {
                            DesktopActions.copy(page.text)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("このページの文字をコピー")
                    }
                }
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
    }

    @ViewBuilder
    private var sourceBadge: some View {
        switch page.source {
        case .textLayer: Badge(text: "文字の層", symbol: "doc.text", tint: .teal)
        case .ocr: Badge(text: "OCR", symbol: "text.viewfinder", tint: .orange)
        case .none: Badge(text: "文字の層なし", symbol: "photo", tint: .secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch page.source {
        case .none:
            Text("文字の層がありません（スキャンした画像など）。OCR で読めます。")
                .font(.callout).foregroundStyle(.secondary)
        case .ocr where page.text.isEmpty:
            Text("OCR で文字が見つかりませんでした").font(.callout).foregroundStyle(.secondary)
        default:
            Text(page.text.trimmingCharacters(in: .newlines))
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
