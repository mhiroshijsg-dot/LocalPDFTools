extension HelpTopic {
    static let faq = HelpTopic(
        id: "faq",
        title: String(localized: "よくある質問"),
        icon: .symbol("questionmark.bubble.fill"),
        lead: "困ったときに、まず確かめること",
        sections: [
            HelpSection(
                heading: "最初に開こうとしたら「開かれていません」と出た",
                paragraphs: [
                    "このアプリは個人で作っているので、Apple の審査（公証）を受けていません。最初の 1 回だけ、次の手順で開いてください。",
                ],
                bullets: [
                    "表示の「完了」を押して閉じます（「ゴミ箱に入れる」は押さないでください）",
                    "**システム設定** → **プライバシーとセキュリティ** を開きます",
                    "「セキュリティ」の欄に「“LocalPDFTools”は … ブロックされました」と出ているので、**このまま開く** を押します",
                ]
            ),
            HelpSection(
                heading: "Intel の Mac で動かない",
                paragraphs: [
                    "Apple シリコン（M1 以降）の Mac 専用です。macOS 14 Sonoma 以降が必要です。",
                ]
            ),
            HelpSection(
                heading: "圧縮したのに、ほとんど小さくならない・大きくなった",
                paragraphs: [
                    "すでに十分圧縮されている PDF は、それ以上小さくなりにくいです。構造の圧縮だけでは、画像は小さくなりません。まず品質を「中」か「低」にしてください。それでも足りなければ、「詳細」の内訳で何が大きいかを確かめ、画像が大きいなら「解像度」や「JPEG の画質」を下げてください。点や線がとても多いグラフが入っているなら、「図を画像にする」で大きく減ることがあります。Type1 以外のフォント（TrueType・OpenType など）が大きいときは、このアプリでは小さくできません。なお、Illustrator で保存した PDF の編集用のデータ・重複した画像やフォント・色の無いカラーの画像・LaTeX などの Type1 のフォントは、圧縮をオンにすれば毎回自動で減らします。",
                ]
            ),
            HelpSection(
                heading: "スキャンした PDF の文字がコピーできない",
                paragraphs: [
                    "文字の層（文字のデータ）が無いためです。「文字の抽出」のシートで、ページの「OCR する」を押すと読めます。",
                ]
            ),
            HelpSection(
                heading: "結合したら、しおり（目次）が消えた",
                paragraphs: [
                    "結合ではしおりと PDF の中のリンクは残りません。しおりが必要なら、結合しないで別々に保存してください。",
                ]
            ),
            HelpSection(
                heading: "エラーが出た・おかしな動きをした",
                paragraphs: [
                    "画面に出たエラーの文は、右のボタンでコピーできます。[Issues](https://github.com/mhiroshijsg-dot/LocalPDFTools/issues) に、エラーの文と、何をしたかを書いてください。書類そのものや、個人の情報は載せないでください。",
                ]
            ),
        ]
    )
}
