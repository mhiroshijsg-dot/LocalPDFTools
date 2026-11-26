/// 1 ページ分の文字と、その出どころ
public struct PageText: Sendable, Equatable {
    public enum Source: Sendable, Equatable {
        /// PDF の中の文字の層から取り出した
        case textLayer
        /// 文字の層が無いので、ページを画像にして Vision で読んだ
        case ocr
        /// 文字の層が無く、まだ OCR していない
        case none
    }

    /// 0 から数えたページの位置
    public let pageIndex: Int
    public var source: Source
    public var text: String

    public init(pageIndex: Int, source: Source, text: String) {
        self.pageIndex = pageIndex
        self.source = source
        self.text = text
    }

    public var pageNumber: Int { pageIndex + 1 }
}
