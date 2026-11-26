import Foundation
import PDFEngine

/// 保存名の初期値
enum SuggestedName {
    /// 結合: 一番上のファイル名_merge.pdf
    static func merged(top: URL) -> String {
        baseName(top) + "_merge.pdf"
    }

    /// 結合しないとき: 元の名前＋行った操作の語（例: 成績 B_unlocked_rotated.pdf）
    static func single(_ url: URL, steps: [PipelineStep]) -> String {
        baseName(url) + steps.compactMap(suffix).joined() + ".pdf"
    }

    /// 文字の抽出（1 ファイル分）: 元の名前.txt
    static func text(_ url: URL) -> String {
        baseName(url) + ".txt"
    }

    /// 文字の抽出（複数のファイルをまとめて 1 つ）: 一番上のファイル名_merge.txt
    static func mergedText(top: URL) -> String {
        baseName(top) + "_merge.txt"
    }

    private static func suffix(_ step: PipelineStep) -> String? {
        switch step {
        case .decrypt: return "_unlocked"
        case .rotate: return "_rotated"
        case .merge: return nil
        case .compress: return "_compressed"
        }
    }

    private static func baseName(_ url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }
}
