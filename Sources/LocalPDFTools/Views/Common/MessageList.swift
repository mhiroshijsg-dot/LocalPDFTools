import SwiftUI

/// お知らせの一覧。エラーと警告は赤字。文字は選択でき、右のボタンでコピーできる
struct MessageList: View {
    let messages: [UserMessage]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(messages) { message in
                HStack(alignment: .top) {
                    Text(message.text)
                        .foregroundStyle(message.kind == .note ? Color.secondary : Color.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        DesktopActions.copy(message.text)
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.borderless)
                    .help("コピー")
                }
            }
        }
    }
}
