import SwiftUI

/// ヘルプの窓の右側: 項目 1 つ分の説明（見出し・影響の札・図・段落のカード）
struct HelpTopicView: View {
    let topic: HelpTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if !topic.effects.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(topic.effects, id: \.self) { effect in
                            Badge(text: "\(effect.label): \(effect.value)",
                                  symbol: effect.isCaution ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                                  tint: effect.isCaution ? .orange : .green)
                        }
                    }
                }
                if let attachment = topic.attachment, attachment.isFigure {
                    figure(attachment)
                }
                ForEach(topic.sections, id: \.self) { section in
                    HelpSectionCard(section: section)
                }
                if let attachment = topic.attachment, !attachment.isFigure {
                    figure(attachment)
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        // 項目を切り替えたら一番上から見せる
        .id(topic.id)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(topic.title)
    }

    private var header: some View {
        HStack(spacing: 14) {
            SymbolTile(symbol: topic.icon.symbolName, color: topic.icon.color, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(topic.title).font(.title2.weight(.semibold))
                Text(topic.lead).font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func figure(_ attachment: HelpAttachment) -> some View {
        switch attachment {
        case .flow: HelpFlowFigure()
        case .order: HelpOrderFigure()
        case .licenses: HelpLicensesButton()
        }
    }
}
