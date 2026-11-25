import Foundation

/// ファイルの大きさの取得と表示
public enum FileSize {
    public static func of(_ url: URL) -> Int64? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return nil }
        return Int64(size)
    }

    /// 例: 4.9 MB。
    /// MEMO(2026-11-25・by claude): Finder と同じく 1 MB = 1,000,000 バイトで数える。
    public static func text(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
