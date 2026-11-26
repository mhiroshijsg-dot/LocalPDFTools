import SwiftUI

/// お知らせの一覧。エラーと警告は赤字。文字は選択でき、右のボタンでコピーできる
struct MessageList: View {
    let messages: [UserMessage]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(messages) { message in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: symbol(message.kind))
                        .foregroundStyle(color(message.kind))
                    Text(message.text)
                        .foregroundStyle(message.kind == .note ? Color.secondary : Color.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        DesktopActions.copy(message.text)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("コピー")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color(message.kind).opacity(message.kind == .note ? 0.06 : 0.09))
                )
            }
        }
    }

    private func symbol(_ kind: UserMessage.Kind) -> String {
        switch kind {
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .note: return "info.circle.fill"
        }
    }

    private func color(_ kind: UserMessage.Kind) -> Color {
        switch kind {
        case .error, .warning: return .red
        case .note: return .secondary
        }
    }
}
