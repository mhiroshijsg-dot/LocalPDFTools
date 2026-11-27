extension HelpTopic {
    static let merge = HelpTopic(
        id: HelpTopic.id(for: .merge),
        title: Operation.merge.title,
        icon: .operation(.merge),
        lead: "いくつかの PDF を、並べた順に 1 つにまとめます",
        effects: [
            HelpEffect(label: "画質", value: "変わらない"),
            HelpEffect(label: "しおり", value: "残らない", isCaution: true),
        ],
        sections: [
            HelpSection(
                heading: "使い方",
                paragraphs: [
                    "左の並びの上から順に、1 つの PDF にまとめます。順番は行をドラッグして変えられます。",
                    "保存名の初期値は、一番上のファイルの名前に _merge を付けたものです。",
                ]
            ),
            HelpSection(
                heading: "中で何をしているか",
                paragraphs: [
                    "それぞれの PDF からページをそのまま取り出して、新しい PDF に順に並べます。ページを作り直さないので、文字・画質・Web ページへのリンクは変わりません。",
                ]
            ),
            HelpSection(
                heading: "残らないもの",
                bullets: [
                    "**しおり**（目次）と、**PDF の中の別のページへのリンク**は、結合すると残りません",
                    "Web ページへのリンク（URL）は残ります",
                    "しおりのある PDF が入っていると、カードに赤字で知らせます",
                ]
            ),
            HelpSection(
                heading: "結合をオフにすると",
                paragraphs: [
                    "ほかの操作だけを、ファイルごとに行って別々に保存します。",
                ]
            ),
        ]
    )
}
