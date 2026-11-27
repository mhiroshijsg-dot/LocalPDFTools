extension HelpTopic {
    static let order = HelpTopic(
        id: "order",
        title: String(localized: "操作の順番"),
        icon: .symbol("arrow.up.arrow.down"),
        lead: "オンにした操作は、決まった順番で続けて行います",
        attachment: .order,
        sections: [
            HelpSection(
                heading: "暗号化の解除はいつも最初",
                paragraphs: [
                    "解除を後にすると、結合するときに、パスワードを他のプログラムからも見える形で渡すしかなくなります。パスワードを守るため、解除は最初から動かせないようにしています。",
                ]
            ),
            HelpSection(
                heading: "おすすめの順: 回転 → 結合 → 圧縮",
                paragraphs: [
                    "圧縮が最後なのは、提出先の大きさの上限に関わるのは、最後にできたファイルの大きさだからです。",
                ]
            ),
            HelpSection(
                heading: "順番の変え方",
                bullets: [
                    "設定（⌘,）を開き、行をドラッグして並べ替えます",
                    "右クリックの「上へ」「下へ」でも動かせます",
                    "「おすすめの順に戻す」で最初の順に戻ります",
                ]
            ),
        ]
    )
}
