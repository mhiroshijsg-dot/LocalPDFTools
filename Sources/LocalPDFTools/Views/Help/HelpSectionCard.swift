import SwiftUI

/// ヘルプの段落のまとまり 1 つ分のカード: 見出し・文・箇条書き
struct HelpSectionCard: View {
    let section: HelpSection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.heading).font(.headline)
            ForEach(section.paragraphs, id: \.self) { paragraph in
                Text(Self.styled(paragraph))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !section.bullets.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(section.bullets, id: \.self) { bullet in
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("•").foregroundStyle(.secondary)
                            Text(Self.styled(bullet))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .font(.body)
        .lineSpacing(2)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    /// **太字**・`命令`・[リンク](URL) を効かせた文字。読めない書き方なら、そのままの文字で出す
    static func styled(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
