import Foundation

extension PDFPipeline {
    /// 1 つの PDF を、解除・回転・分割・圧縮を指定の順に続けて行い、parent の中に新しく作ったフォルダへまとめて置く。
    /// steps は行う順（.decrypt があれば先頭・.split を必ず含む・.merge は含まない）。
    /// 分割の前に回すときはファイル全体を、後に回すときは分けたファイルごとに元のページ番号の指定を当てる。
    /// MEMO(2026-11-27・by claude): 村田さんの指示「保存場所を選んだら新しいフォルダを作って入れる形がいい」。
    /// 既にあるフォルダには入れず、同じ名前があれば「名前 2」にする（FolderOutputWriter）。
    public func runSplit(_ file: PipelineFile,
                         steps: [PipelineStep],
                         split: SplitPlan,
                         compression: CompressionSettings = CompressionSettings(),
                         baseName: String,
                         folderName: String,
                         in parent: URL,
                         askPassword: PasswordProvider) async throws -> SplitOutcome {
        guard steps.contains(.split), !steps.contains(.merge) else { throw EngineError.nothingToDo }
        if !steps.contains(.decrypt) && file.encryption == .passwordRequired {
            throw EngineError.passwordRequired(path: file.url.path)
        }

        var pieces: [SplitPiece] = []
        var warnings: [String] = []
        var compressionResult: CompressionResult?
        let folder = try await FolderOutputWriter().write(folderName: folderName, in: parent) { folder, scratch in
            var stepNumber = 0
            func nextFile() -> URL {
                stepNumber += 1
                return scratch.appendingPathComponent("step-\(stepNumber).pdf")
            }

            var current = file.url
            // 分けた後のファイル（分ける前は nil）と、それぞれの元のページ番号
            var parts: [URL]?
            var ranges: [ClosedRange<Int>] = []

            for step in steps {
                switch step {
                case .decrypt:
                    guard file.encryption != .notEncrypted else { continue }
                    let output = nextFile()
                    warnings += try await decrypt(file, input: current, into: output, askPassword: askPassword)
                    current = output
                case .rotate:
                    let rotator = PDFRotator(runner: runner)
                    if var files = parts {
                        for (index, range) in ranges.enumerated() {
                            let plan = file.rotation.slice(range)
                            guard plan.hasChanges else { continue }
                            let output = nextFile()
                            warnings += try await rotator.rotateFile(files[index], plan: plan, into: output)
                            files[index] = output
                        }
                        parts = files
                    } else if file.rotation.hasChanges {
                        let output = nextFile()
                        warnings += try await rotator.rotateFile(current, plan: file.rotation, into: output)
                        current = output
                    }
                case .merge:
                    throw EngineError.nothingToDo
                case .split:
                    let count = try await pageCount(of: current)
                    ranges = try split.ranges(pageCount: count)
                    stepNumber += 1
                    let result = try await PDFSplitter(runner: runner)
                        .splitFile(current, ranges: ranges, pageCount: count,
                                   into: scratch.appendingPathComponent("split-\(stepNumber)", isDirectory: true))
                    parts = result.files
                    warnings += result.warnings
                case .compress:
                    let compressor = PDFCompressor(runner: runner)
                    var total = CompressionResult()
                    var inputs = parts ?? [current]
                    for index in inputs.indices {
                        let output = nextFile()
                        total = total + (try await compressor.compressFile(inputs[index], settings: compression, into: output))
                        inputs[index] = output
                    }
                    if parts == nil { current = inputs[0] } else { parts = inputs }
                    warnings += total.warnings
                    total.warnings = []
                    compressionResult = total
                }
            }

            guard let parts else { throw EngineError.nothingToDo }
            var usedNames: Set<String> = []
            for (part, range) in zip(parts, ranges) {
                let name = Self.uniqueName(SplitPiece.fileName(base: baseName, pages: range), used: &usedNames)
                let destination = folder.appendingPathComponent(name)
                try FileManager.default.moveItem(at: part, to: destination)
                if steps.contains(.decrypt) {
                    let check = try await PDFEncryptionInspector(runner: runner).inspect(destination)
                    guard check.status == .notEncrypted else {
                        throw EngineError.stillEncrypted(path: destination.path)
                    }
                }
                pieces.append(SplitPiece(url: destination, pages: range, bytes: FileSize.of(destination) ?? 0))
            }
        }
        // フォルダごと移したので、中のファイルの場所を移した先に直す
        let moved = pieces.map {
            SplitPiece(url: folder.appendingPathComponent($0.url.lastPathComponent), pages: $0.pages, bytes: $0.bytes)
        }
        return SplitOutcome(folder: folder, pieces: moved, inputBytes: FileSize.of(file.url) ?? 0,
                            warnings: warnings, compression: compressionResult)
    }

    /// 同じ範囲を 2 回書いたときなど、名前が重なったら _2・_3 を付ける
    private static func uniqueName(_ name: String, used: inout Set<String>) -> String {
        let base = (name as NSString).deletingPathExtension
        var candidate = name
        var number = 2
        // Mac のディスクは大文字・小文字を区別しないことが多いので、小文字にして比べる
        while used.contains(candidate.lowercased()) {
            candidate = "\(base)_\(number).pdf"
            number += 1
        }
        used.insert(candidate.lowercased())
        return candidate
    }
}
