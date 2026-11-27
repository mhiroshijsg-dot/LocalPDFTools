import SwiftUI

/// ヘルプの窓の右側: 項目 1 つ分の説明（見出し・影響の札・図・段落のカード）。
/// 検索しているときは、探した語に印を付け、見つかった段落のまとまりまで動かす
struct HelpTopicView: View {
    let topic: HelpTopic
    /// 検索した語（検索していなければ空）
    var terms: [String] = []
    /// 検索の一覧で選んだ段落のまとまりの番号（項目の頭なら nil）
    var focusSection: Int? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header.id(Self.topAnchor)
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
                    ForEach(Array(topic.sections.enumerated()), id: \.offset) { index, section in
                        HelpSectionCard(section: section, terms: terms)
                            .id(Self.anchor(index))
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
            // 項目を切り替えたら一番上から見せる（検索の一覧から来たときは、見つかった所から）
            .id(topic.id)
            .onAppear { scroll(proxy) }
            .onChange(of: focusSection) { scroll(proxy) }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(topic.title)
    }

    private static let topAnchor = "top"

    private static func anchor(_ index: Int) -> String {
        "section.\(index)"
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        let target = focusSection.map(Self.anchor) ?? Self.topAnchor
        // 並べ終わってから動かす（出した直後だと、まだ位置が決まっていない）
        DispatchQueue.main.async {
            withAnimation { proxy.scrollTo(target, anchor: .top) }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            SymbolTile(symbol: topic.icon.symbolName, color: topic.icon.color, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(HelpHighlight.apply(terms, to: topic.title)).font(.title2.weight(.semibold))
                Text(HelpHighlight.apply(terms, to: topic.lead)).font(.callout).foregroundStyle(.secondary)
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
