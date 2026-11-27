import SwiftUI

/// ヘルプの検索で探した語に、黄色い印を付ける（「Finder で探す」と同じような見た目）
enum HelpHighlight {
    static func apply(_ terms: [String], to text: AttributedString) -> AttributedString {
        var result = text
        for term in terms where !term.isEmpty {
            var from = result.startIndex
            while from < result.endIndex,
                  let range = result[from...].range(of: term, options: HelpSearch.options) {
                // 暗い見た目でも読めるよう、文字は黒にする
                result[range].backgroundColor = Color.yellow.opacity(0.7)
                result[range].foregroundColor = Color.black
                from = range.upperBound
            }
        }
        return result
    }

    static func apply(_ terms: [String], to text: String) -> AttributedString {
        apply(terms, to: AttributedString(text))
    }
}
