extension HelpTopic {
    /// 部品と命令の名前は、この項目にだけ書く（他の項目は一般の言葉で書く。計画 G の決めること 2）
    static let components = HelpTopic(
        id: "components",
        title: String(localized: "使っている部品"),
        icon: .symbol("shippingbox.fill"),
        lead: "インターネットにつながず、次の部品だけで処理します",
        attachment: .licenses,
        sections: [
            HelpSection(
                heading: "アプリの中に入れている部品",
                bullets: [
                    "**qpdf** — PDF の中身を読み書きする部品。解除・回転・結合・分割・圧縮で使います（Apache License 2.0）",
                    "qpdf が使う **libjpeg-turbo**（JPEG の読み書き）と **OpenSSL**（暗号）",
                ]
            ),
            HelpSection(
                heading: "Mac に最初から入っている部品",
                bullets: [
                    "**PDFKit** — ページの縮小表示と、文字の層の読み取り",
                    "**Core Graphics** — OCR の前にページを絵にする、図を画像にするときに図を描く、画像がページのどこに置かれているかを調べる",
                    "**ImageIO** — 圧縮のときの画像の縮小と再圧縮",
                    "**Vision** — 文字認識（OCR）",
                    "**CryptoKit** — 圧縮のときに、重複した部品を見つけるための指紋（SHA-256）を作る",
                ]
            ),
            HelpSection(
                heading: "操作と qpdf の命令",
                bullets: [
                    "暗号化の解除: `qpdf --decrypt`（パスワードは引数ではなく、他のプログラムから見えない形で渡します）",
                    "回転: `qpdf --rotate`",
                    "結合: `qpdf --empty --pages`",
                    "分割: 同じページ数ずつなら `qpdf --split-pages=N`、範囲ごとなら `qpdf --empty --pages 入力 1-3 --`",
                    "圧縮（構造）: `qpdf --object-streams=generate --recompress-flate`",
                    "圧縮（画像）: qpdf で画像を取り出し → ImageIO で作り直し → `qpdf --update-from-json` で元の場所に戻す",
                    "圧縮（重複を探す）: `qpdf --json --json-object=… --json-stream-data=file` で候補の部品のデータだけを取り出す",
                    "圧縮（要らないデータ・重複の付け替え・色の無い画像）: 書き換えた部品だけを `qpdf --update-from-json` で戻す。使われなくなった部品は、qpdf が書き出すときに捨てる",
                    "圧縮（フォントの作り直し）: `qpdf --json-object=… --json-stream-data=file` で Type1 のフォントを取り出す → このアプリの中で CFF に書き直す → `qpdf --update-from-json` で /FontFile を /FontFile3（/Type1C）に差し替える",
                    "圧縮（図を画像にする）: qpdf で図だけを並べた一時的な PDF を作る → Core Graphics で描く → `qpdf --update-from-json` で図の中身を画像に差し替える",
                ]
            ),
            HelpSection(
                heading: "使っていないもの",
                paragraphs: [
                    "PDF を丸ごと作り直す道具（Ghostscript など）は使っていません。選んだ部分だけを変え、それ以外はそのまま残すためです。",
                ]
            ),
            HelpSection(
                heading: "ライセンス",
                paragraphs: [
                    "このアプリは MIT License です。アプリの中に入れている部品は、それぞれのライセンスに従います。ライセンスの文は、下のボタンで開けます。",
                ]
            ),
        ]
    )
}
