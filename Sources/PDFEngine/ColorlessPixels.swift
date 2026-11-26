import Foundation

/// RGB の画像が「色の無い画像」（白・黒・灰色だけ）かを調べる。灰色で保存し直してよいかの判定に使う。
/// MEMO(2026-11-26・by claude): 村田さんの指示で、圧縮のときにいつも行う（選ぶ欄は無い）。見た目を変えないために判定は厳しめにする。
/// 印鑑・青いインクの署名・蛍光ペンなど、色の付いた部分が少しでもあれば灰色にしない。
enum ColorlessPixels {
    /// 可逆の画像（Flate）: すべての画素で R・G・B がぴったり同じときだけ。灰色にしても画素の値は 1 つも変わらない
    static func isExactlyGray(rgb data: Data) -> Bool {
        guard !data.isEmpty, data.count % 3 == 0 else { return false }
        return data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Bool in
            var index = 0
            while index < buffer.count {
                let red = buffer[index]
                if buffer[index + 1] != red || buffer[index + 2] != red { return false }
                index += 3
            }
            return true
        }
    }

    /// 少し色のぶれが残るときの、ぶれ（R・G・B の最大と最小の差）の許し方
    static let looseSpread = 12
    static let colorSpread = 40

    /// JPEG の画像: JPEG は保存のときに色が少しぶれるので、少しのぶれは許す。
    /// - ぶれが 12 を超える画素が全体の 0.5% 以下（紙のわずかな色・JPEG のにじみ）
    /// - ぶれが 40 を超える画素（はっきり色の付いた画素）が全体の 0.01% 以下（印鑑や署名があれば必ず超える）
    /// rgbx は 1 画素 4 バイト（R・G・B・使わない 1 バイト）、行の長さは rowBytes
    static func isNearlyGray(rgbx data: Data, width: Int, height: Int, rowBytes: Int) -> Bool {
        let total = width * height
        guard total > 0, data.count >= rowBytes * height else { return false }
        let looseLimit = total / 200
        let colorLimit = total / 10_000
        var loose = 0
        var colored = 0
        return data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> Bool in
            for row in 0..<height {
                var pixel = row * rowBytes
                for _ in 0..<width {
                    let red = Int(buffer[pixel]), green = Int(buffer[pixel + 1]), blue = Int(buffer[pixel + 2])
                    let spread = max(red, green, blue) - min(red, green, blue)
                    if spread > looseSpread {
                        loose += 1
                        if spread > colorSpread { colored += 1 }
                        if loose > looseLimit || colored > colorLimit { return false }
                    }
                    pixel += 4
                }
            }
            return true
        }
    }
}
