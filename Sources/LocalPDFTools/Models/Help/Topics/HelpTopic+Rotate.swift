extension HelpTopic {
    static let rotate = HelpTopic(
        id: HelpTopic.id(for: .rotate),
        title: Operation.rotate.title,
        icon: .operation(.rotate),
        lead: "横倒しや逆さまのページの向きを、ページごとに直します",
        effects: [
            HelpEffect(label: "画質", value: "変わらない"),
            HelpEffect(label: "大きさ", value: "ほぼ同じ"),
        ],
        sections: [
            HelpSection(
                heading: "使い方",
                paragraphs: [
                    "カードの「ページを見て回す…」を押すと、入れた PDF のページがすべて並びます。",
                ],
                bullets: [
                    "ページをクリックするたびに、右へ 90° 回ります",
                    "右クリックすると、左回り・180°・元に戻すを選べます",
                    "上の「すべて左に 90°」「すべて右に 90°」で、全ページをまとめて回せます。「すべて元に戻す」で最初の向きに戻ります",
                ]
            ),
            HelpSection(
                heading: "中で何をしているか",
                paragraphs: [
                    "PDF のページには「このページを何度回して表示するか」という情報があります。回転では、その情報だけを書き換えます。"
                        + "ページの中身（文字や画像）は作り直さないので、画質も大きさも変わりません。",
                ]
            ),
            HelpSection(
                heading: "できないこと・注意",
                bullets: [
                    "開くのにパスワードが要る PDF は、ページを表示できないので、ここでは回せません。先に解除して保存した PDF を入れ直すと回せます",
                    "回転がオンのとき、文字の抽出の OCR は、ここで直した向きでページを読みます",
                ]
            ),
        ]
    )
}
