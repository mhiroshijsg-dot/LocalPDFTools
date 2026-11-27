import Foundation

/// 解除・回転・結合・圧縮を、指定の順に続けて行い、最後の 1 つだけを保存先へ置く（分割は PDFPipeline+Split.swift）。
/// 途中のファイルは保存先と同じディスクの一時フォルダに作り、終わったら（失敗しても）消す。
/// MEMO(2026-11-26・by claude): 1 回の qpdf にまとめない。結合の `--pages` でファイルごとのパスワードを渡すには
/// 引数（`ps` で他のプログラムから見える）に入れるしかないので、解除は 1 ファイルずつ標準入力で渡して先に済ませる。
public struct PDFPipeline {
    /// パスワードが本当に要る時点で 1 回ずつ呼ぶ。isRetry は「前に入れたものが違った」。nil はやめる。
    /// MEMO(2026-11-26・by claude): 受け取ったパスワードはその場で qpdf に渡し、変数にも残さない（村田さんの指示）。
    public typealias PasswordProvider = @MainActor (_ file: URL, _ isRetry: Bool) async -> String?

    let runner: QPDFRunner
    let writer = OutputWriter()

    public init(runner: QPDFRunner) {
        self.runner = runner
    }

    /// steps は行う順（.decrypt があれば先頭）。.merge が無いときは files は 1 つだけ。
    /// compression は steps に .compress があるときに使う
    public func run(_ files: [PipelineFile],
                    steps: [PipelineStep],
                    compression: CompressionSettings = CompressionSettings(),
                    to destination: URL,
                    askPassword: PasswordProvider) async throws -> OperationOutcome {
        guard !files.isEmpty, steps.contains(.merge) || files.count == 1 else {
            throw EngineError.nothingToDo
        }
        if !steps.contains(.decrypt), let locked = files.first(where: { $0.encryption == .passwordRequired }) {
            throw EngineError.passwordRequired(path: locked.url.path)
        }

        var compressionResult: CompressionResult?
        let outcome = try await writer.write(to: destination, inputs: files.map(\.url)) { temporary in
            let directory = temporary.deletingLastPathComponent()
            var stepNumber = 0
            func nextFile() -> URL {
                stepNumber += 1
                return directory.appendingPathComponent("step-\(stepNumber).pdf")
            }

            var current = files.map(\.url)
            var merged = false
            var pageCountsAtMerge: [Int] = []
            var warnings: [String] = []

            for step in steps {
                switch step {
                case .decrypt:
                    for (index, file) in files.enumerated() where file.encryption != .notEncrypted {
                        let output = nextFile()
                        warnings += try await decrypt(file, input: current[index], into: output, askPassword: askPassword)
                        current[index] = output
                    }
                case .rotate:
                    if merged {
                        let plan = RotationPlan.joined(files.map(\.rotation), pageCounts: pageCountsAtMerge)
                        if plan.hasChanges {
                            let output = nextFile()
                            warnings += try await PDFRotator(runner: runner).rotateFile(current[0], plan: plan, into: output)
                            current[0] = output
                        }
                    } else {
                        for (index, file) in files.enumerated() where file.rotation.hasChanges {
                            let output = nextFile()
                            warnings += try await PDFRotator(runner: runner).rotateFile(current[index], plan: file.rotation, into: output)
                            current[index] = output
                        }
                    }
                case .merge:
                    // 結合の後に回すときは、通しのページ番号にするため各ファイルのページ数を先に数える
                    if let mergeIndex = steps.firstIndex(of: .merge), steps[mergeIndex...].contains(.rotate) {
                        pageCountsAtMerge = []
                        for url in current {
                            pageCountsAtMerge.append(try await pageCount(of: url))
                        }
                    }
                    let output = nextFile()
                    warnings += try await PDFMerger(runner: runner).mergeFiles(current, into: output)
                    current = [output]
                    merged = true
                case .compress:
                    var total = CompressionResult()
                    for index in current.indices {
                        let output = nextFile()
                        let result = try await PDFCompressor(runner: runner)
                            .compressFile(current[index], settings: compression, into: output)
                        total = total + result
                        current[index] = output
                    }
                    warnings += total.warnings
                    total.warnings = []
                    compressionResult = total
                case .split:
                    // 分割は出力がいくつもになるので runSplit で行う
                    throw EngineError.nothingToDo
                }
            }

            guard current.count == 1, current[0] != files[0].url else {
                throw EngineError.nothingToDo
            }
            try FileManager.default.moveItem(at: current[0], to: temporary)
            if steps.contains(.decrypt) {
                let check = try await PDFEncryptionInspector(runner: runner).inspect(temporary)
                guard check.status == .notEncrypted else {
                    throw EngineError.stillEncrypted(path: destination.path)
                }
            }
            return warnings
        }
        return outcome.with(compression: compressionResult)
    }

    /// 1 ファイルの暗号化を外す。パスワードが要るときだけ聞き、違っていたら聞き直す
    func decrypt(_ file: PipelineFile, input: URL, into output: URL,
                         askPassword: PasswordProvider) async throws -> [String] {
        let decryptor = PDFDecryptor(runner: runner)
        guard file.encryption == .passwordRequired else {
            return try await decryptor.decryptFile(input, password: nil, into: output)
        }
        var isRetry = false
        while true {
            guard let password = await askPassword(file.url, isRetry) else {
                throw EngineError.passwordCancelled(path: file.url.path)
            }
            do {
                return try await decryptor.decryptFile(input, password: password, into: output)
            } catch EngineError.wrongPassword {
                isRetry = true
            }
        }
    }

    /// ページ数を qpdf で数える（パスワードが要らない PDF だけ）
    func pageCount(of url: URL) async throws -> Int {
        let output = try await runner.runChecked(["--show-npages", url.path])
        guard let count = Int(output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw EngineError.unreadablePDF(path: url.path)
        }
        return count
    }
}
