import CoreGraphics

/// Vision が返す文字の塊 1 つ（文字と、ページの画像の中の位置）
public struct RecognizedBlock: Sendable, Equatable {
    public let text: String
    /// 画像全体を 0〜1 とした位置。Vision と同じく、原点は左下で上へ行くほど y が大きい
    public let box: CGRect

    public init(text: String, box: CGRect) {
        self.text = text
        self.box = box
    }
}
