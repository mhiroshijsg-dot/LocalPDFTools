import Foundation

/// 出力の保存を一手に引き受ける。
/// - 保存先が入力と同じなら止める（元のファイルを壊さない）
/// - まず一時ファイルに作り、できあがってから保存先へ移す（途中で失敗しても、既にある保存先のファイルは壊れない）
public struct OutputWriter {
    public init() {}

    /// 保存先が入力のどれかと同じファイルなら EngineError.outputSameAsInput を投げる
    public func ensureDistinct(destination: URL, inputs: [URL]) throws {
        let destinationPath = destination.resolvingSymlinksInPath().standardizedFileURL.path
        let destinationID = Self.fileIdentifier(destination)
        for input in inputs {
            let inputPath = input.resolvingSymlinksInPath().standardizedFileURL.path
            // MEMO(2026-11-25・by claude): Mac のディスクは大文字・小文字を区別しないことが多いので、
            // パスの比較に加えて「ファイルそのものの番号」でも比べる（a.pdf と A.pdf は同じファイル）。
            let sameID = destinationID != nil && destinationID == Self.fileIdentifier(input)
            if inputPath == destinationPath || sameID {
                throw EngineError.outputSameAsInput(path: destination.path)
            }
        }
    }

    /// produce に一時ファイルの場所を渡して中身を作らせ、できたら保存先へ移す。
    /// produce は qpdf の警告の行を返す。
    public func write(to destination: URL,
                      inputs: [URL],
                      produce: (URL) async throws -> [String]) async throws -> OperationOutcome {
        try ensureDistinct(destination: destination, inputs: inputs)

        let fileManager = FileManager.default
        // 保存先と同じディスク上の一時フォルダ（移すときにコピーが起きず、置き換えが一瞬で済む）
        let workDirectory = try fileManager.url(for: .itemReplacementDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: destination.deletingLastPathComponent(),
                                                create: true)
        defer { try? fileManager.removeItem(at: workDirectory) }
        let temporary = workDirectory.appendingPathComponent("output.pdf")

        let warnings = try await produce(temporary)
        guard fileManager.fileExists(atPath: temporary.path) else {
            throw EngineError.outputNotCreated
        }

        if fileManager.fileExists(atPath: destination.path) {
            // 上書きの確認は保存ダイアログで済んでいる
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }

        let inputBytes = inputs.compactMap { FileSize.of($0) }.reduce(0, +)
        return OperationOutcome(destination: destination,
                                inputBytes: inputBytes,
                                outputBytes: FileSize.of(destination) ?? 0,
                                warnings: warnings)
    }

    private static func fileIdentifier(_ url: URL) -> NSObject? {
        (try? url.resourceValues(forKeys: [.fileResourceIdentifierKey]))?.fileResourceIdentifier as? NSObject
    }
}
