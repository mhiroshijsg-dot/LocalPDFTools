/// 見た目に関わらない「要らないデータ」を部品の辞書から外す（圧縮のときにいつも行う）。
/// - `/PieceInfo`: Illustrator・Photoshop などが、自分で編集し直すために入れておくデータ。PDF を表示するときには使わない。
///   Illustrator で保存した PDF では、これが PDF の大部分を占めることがある
/// - ページの `/Thumb`: ページの小さな縮小画像。今のビューアは自分で作るので使わない
/// - 文書全体以外の `/Metadata`: 画像やページに付いた説明のデータ（撮影や編集の履歴など）。
///   文書全体のもの（題名・作成者など。カタログの /Metadata）は残す
/// 外したデータは、どこからも使われなくなるので、qpdf が書き出すときに捨てる。
/// MEMO(2026-11-26・by claude): 添付ファイル・しおり・文書の構造（読み上げ用のタグ）・フォームは、中身や使い勝手が変わるので外さない。
enum ExtraDataStripper {
    /// 辞書から要らないデータを外す。外した数も返す
    static func strip(_ dictionary: [String: Any]) -> (dictionary: [String: Any], removed: Int) {
        var result = dictionary
        var removed = 0
        let type = dictionary["/Type"] as? String
        var keys = ["/PieceInfo"]
        if type == "/Page" { keys.append("/Thumb") }
        if type != "/Catalog" { keys.append("/Metadata") }
        for key in keys where result[key] != nil {
            result[key] = nil
            removed += 1
        }
        return (result, removed)
    }
}
