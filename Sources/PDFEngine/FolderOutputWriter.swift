import Foundation

/// いくつものファイルを、新しく作るフォルダにまとめて保存する（分割で使う）。
/// - 保存先と同じディスクの一時フォルダの中で、フォルダごと中身を作る
/// - できあがってから保存先へフォルダごと移す（途中で失敗しても、保存先には何も残らない）
/// - 既にある同じ名前のフォルダには入れない・上書きしない。「名前 2」「名前 3」… と空いている名前にする
public struct FolderOutputWriter {
    public init() {}

    /// produce に「中身を入れるフォルダ」と「途中のファイルを置ける一時フォルダ」を渡して作らせ、
    /// できたら parent の中に folderName（空いていなければ番号付き）で置く。置いたフォルダを返す
    public func write(folderName: String, in parent: URL,
                      produce: (_ folder: URL, _ scratch: URL) async throws -> Void) async throws -> URL {
        let fileManager = FileManager.default
        let workDirectory = try fileManager.url(for: .itemReplacementDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: parent,
                                                create: true)
        defer { try? fileManager.removeItem(at: workDirectory) }
        let folder = workDirectory.appendingPathComponent("output", isDirectory: true)
        let scratch = workDirectory.appendingPathComponent("scratch", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: false)
        try fileManager.createDirectory(at: scratch, withIntermediateDirectories: false)

        try await produce(folder, scratch)

        // 空いている名前を探して移す。調べてから移すまでの間に同じ名前ができても、移す方が失敗するだけなので次の番号で試す
        for number in 1...999 {
            let name = number == 1 ? folderName : "\(folderName) \(number)"
            let destination = parent.appendingPathComponent(name, isDirectory: true)
            if fileManager.fileExists(atPath: destination.path) { continue }
            do {
                try fileManager.moveItem(at: folder, to: destination)
                return destination
            } catch CocoaError.fileWriteFileExists {
                continue
            }
        }
        throw EngineError.outputNotCreated
    }
}
