extension HelpTopic {
    static let decrypt = HelpTopic(
        id: HelpTopic.id(for: .decrypt),
        title: Operation.decrypt.title,
        icon: .operation(.decrypt),
        lead: "印刷・コピーの禁止や、開くときのパスワードを外します",
        effects: [
            HelpEffect(label: "見た目", value: "変わらない"),
            HelpEffect(label: "大きさ", value: "ほぼ同じ"),
        ],
        sections: [
            HelpSection(
                heading: "何をするか",
                paragraphs: [
                    "PDF に付いている保護を外し、保護の無い PDF として保存します。保護には 2 種類あります。",
                ],
                bullets: [
                    "**制限あり**（橙の札）— 開けるけれど、印刷・コピー・編集などが禁止されている PDF。パスワードを入れなくても外せます",
                    "**要パスワード**（赤の札）— 開くのにパスワードが要る PDF。正しいパスワードを入れると外せます",
                    "札にマウスを乗せると、何が禁止されているかが出ます",
                ]
            ),
            HelpSection(
                heading: "中で何をしているか",
                paragraphs: [
                    "保護された PDF の中身は、鍵をかけた状態で保存されています。解除では、その鍵を外して書き直すだけで、ページは作り直しません。そのため、文字・画像・ファイルの大きさはほとんど変わりません。",
                    "保存する前に、できた PDF に保護が残っていないかを確かめます。",
                ]
            ),
            HelpSection(
                heading: "実行するとき",
                bullets: [
                    "保護を外す前に、「外して続ける」かどうかを確認します",
                    "パスワードが要る PDF は、処理の途中でその PDF の番になったときに聞きます。入れたパスワードは、この Mac の中で処理に使うだけです。保存も送信もしません",
                    "解除も結合もオンにしないで回転や圧縮だけをしたときは、保護を付けたまま保存します（黙って外すことはしません）",
                ]
            ),
            HelpSection(
                heading: "できないこと・注意",
                bullets: [
                    "パスワードを忘れた PDF は開けません。パスワードを探したり破ったりする機能はありません",
                    "**自分が権利を持つ書類にだけ使ってください**。他人の書類や、保護を外すことが許されていない書類には使わないでください",
                ]
            ),
        ]
    )
}
