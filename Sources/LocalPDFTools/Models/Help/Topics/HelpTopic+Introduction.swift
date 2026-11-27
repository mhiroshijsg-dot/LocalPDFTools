extension HelpTopic {
    static let introduction = HelpTopic(
        id: "introduction",
        title: String(localized: "はじめに"),
        icon: .symbol("house.fill"),
        lead: "PDF の加工を、この Mac の中だけで行うアプリです",
        sections: [
            HelpSection(
                heading: "できること",
                // 操作の名前と一言は、作業台のカードと同じものを使う（ずれないように）
                bullets: Operation.allCases.map { "**\($0.title)** — \($0.summary)" }
            ),
            HelpSection(
                heading: "ファイルを外に送りません",
                paragraphs: [
                    "このアプリはインターネットに接続しません。PDF もパスワードも、外に送ることはありません。成績証明書や身分証明書のような大事な書類も、そのまま扱えます。",
                ]
            ),
            HelpSection(
                heading: "元のファイルは書き換えません",
                paragraphs: [
                    "結果はいつも新しいファイルとして保存します。元と同じファイルを保存先に選ぶと、保存せずに止まります。",
                ]
            ),
            HelpSection(
                heading: "パスワードは保存しません",
                paragraphs: [
                    "開くのにパスワードが要る PDF は、必要になった時点で小さな窓で聞きます。入れたパスワードはその場の処理に使うだけで、どこにも保存しません。",
                ]
            ),
            HelpSection(
                heading: "このヘルプの開き方",
                paragraphs: [
                    "メニューの「ヘルプ」→「LocalPDFTools のヘルプ」（⌘?）で、いつでも開けます。",
                ]
            ),
            HelpSection(
                heading: "ヘルプの中を探す",
                paragraphs: [
                    "左上の検索の欄に語を入れると、その語が入っている所が一覧に出ます。押すと右にその説明が出て、探した語に黄色い印が付きます。空白で区切って語をいくつか入れると、すべてが入っている所だけを出します。",
                ]
            ),
            HelpSection(
                heading: "画面の言語",
                paragraphs: [
                    "画面は日本語と英語に対応しています。最初は Mac の言語の設定に合わせます。設定（⌘,）の「言語」で、このアプリだけを日本語か English にできます。変えたら、アプリを終了して開き直すと切り替わります。",
                ]
            ),
        ]
    )
}
