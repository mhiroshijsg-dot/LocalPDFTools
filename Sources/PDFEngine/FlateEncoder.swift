import Foundation

/// データを PDF の可逆の圧縮（FlateDecode = zlib の形）にする。
/// MEMO(2026-11-26・by claude): Foundation の `.zlib` は zlib の頭と末尾の検査の値が付かない（raw deflate）ので、
/// ここで付け足す。圧縮後の大きさを先に知りたい（画像にしても小さくならない図は元のまま残す）ので、qpdf に任せず自分で圧縮する。
enum FlateEncoder {
    static func encode(_ data: Data) -> Data? {
        guard let deflated = try? (data as NSData).compressed(using: .zlib) as Data else { return nil }
        var result = Data([0x78, 0xDA])
        result.append(deflated)
        let checksum = adler32(data)
        result.append(contentsOf: [UInt8(checksum >> 24), UInt8((checksum >> 16) & 0xFF),
                                   UInt8((checksum >> 8) & 0xFF), UInt8(checksum & 0xFF)])
        return result
    }

    /// zlib の末尾に付ける検査の値（Adler-32）
    static func adler32(_ data: Data) -> UInt32 {
        var a: UInt32 = 1
        var b: UInt32 = 0
        let modulus: UInt32 = 65_521
        // 5552 バイトごとに割った余りを取れば、途中であふれない
        data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            var index = 0
            while index < buffer.count {
                let end = min(index + 5_552, buffer.count)
                for offset in index..<end {
                    a &+= UInt32(buffer[offset])
                    b &+= a
                }
                a %= modulus
                b %= modulus
                index = end
            }
        }
        return (b << 16) | a
    }
}
