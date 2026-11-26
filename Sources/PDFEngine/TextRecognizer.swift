import CoreGraphics
import Vision

/// 画像の中の文字を Vision（macOS 標準の文字認識）で読む。日本語と英語。ネットワークは使わない。
/// MEMO(2026-11-24・by claude): 計画 §8 の V2 で、成績証明書風の合成ページを読めることを確かめた。
/// 最初の 1 回は準備に十数秒かかり、その後は 1 ページ 0.2 秒程度。
public struct TextRecognizer {
    public static let languages = ["ja-JP", "en-US"]

    public init() {}

    /// 読めた文字の塊（位置付き）。文字が無ければ空
    public func recognize(_ image: CGImage) throws -> [RecognizedBlock] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = Self.languages
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let best = observation.topCandidates(1).first else { return nil }
            return RecognizedBlock(text: best.string, box: observation.boundingBox)
        }
    }
}
