import CoreGraphics
import CryptoKit
import Foundation

/// 各ページの描画の命令を読み、ページに直接置かれた図（Form XObject）ごとに、
/// 描く命令の数・ページ上に置かれた大きさ・中に含む部品（図の中の図・画像）を数える。中身は変えない。
/// 図の中の図は、一番外側の図の分として数える（中だけ画像にしても外側の線が残り、効果が中途半端になるため）。
/// MEMO(2026-11-26・by claude): 段階 5（重い図を画像にする）のために作った。置き場所のたどり方は ImagePlacementScanner と同じ。
final class FigureScanner {
    struct Figure {
        /// 部品の番号（"12 0 R"。このファイルの中だけで通じる）
        let ref: String
        /// 最初に置かれているページ（0 始まり）
        let pageIndex: Int
        /// 図の枠（図の中の座標）
        let bbox: CGRect
        /// 図の中身の指紋（解除・回転・結合で番号が変わっても、同じ図だと分かるように）
        let contentHash: String
        /// 描く命令の数（図の中の図も含む。1 回目に置かれた分だけ数える）
        var operationCount = 0
        /// 図の中の 1 単位が、ページ上で何ポイントになるか（置かれた中で一番大きいもの）
        var scaleX: CGFloat = 0
        var scaleY: CGFloat = 0
        /// ページ上に置かれた大きさ（ポイント。置かれた中で一番大きいもの）
        var placedSize: CGSize = .zero
        /// 図の中にある図の部品の番号
        var nestedForms = Set<String>()
        /// 図の中にある画像の部品の番号
        var nestedImages = Set<String>()
    }

    /// 見つけた順
    private(set) var figures: [Figure] = []
    /// ページに直接書かれた命令の数（ページごと）
    private(set) var pageOperationCounts: [Int] = []

    private let table: QPDFObjectTable
    private var indexByRef: [String: Int] = [:]
    private var transform = CGAffineTransform.identity
    private var savedTransforms: [CGAffineTransform] = []
    private var namesStack: [[String: String]] = []
    private var operators: CGPDFOperatorTableRef?
    private var pageIndex = 0
    /// 今読んでいる一番外側の図（nil ならページの命令）
    private var owner: Int?
    private static let maxFormDepth = 12
    /// 数える命令: 線や形を描くもの・文字を書くもの
    private static let countedOperators = ["m", "l", "c", "v", "y", "h", "re", "S", "s", "f", "F", "f*",
                                           "B", "B*", "b", "b*", "n", "Tj", "TJ", "'", "\""]

    init(table: QPDFObjectTable) {
        self.table = table
    }

    func scan(_ document: CGPDFDocument) {
        guard let operators = Self.makeOperatorTable() else { return }
        self.operators = operators
        defer {
            self.operators = nil
            CGPDFOperatorTableRelease(operators)
        }
        for (index, pageRef) in table.pageRefs.enumerated() {
            pageOperationCounts.append(0)
            guard let page = document.page(at: index + 1) else { continue }
            pageIndex = index
            owner = nil
            transform = .identity
            savedTransforms = []
            namesStack = [table.xObjects(in: table.pageResources(pageRef))]
            let stream = CGPDFContentStreamCreateWithPage(page)
            run(stream, operators: operators)
            CGPDFContentStreamRelease(stream)
        }
    }

    private func run(_ stream: CGPDFContentStreamRef, operators: CGPDFOperatorTableRef) {
        let info = Unmanaged.passUnretained(self).toOpaque()
        let scanner = CGPDFScannerCreate(stream, operators, info)
        CGPDFScannerScan(scanner)
        CGPDFScannerRelease(scanner)
    }

    private func countOperation() {
        if let owner {
            figures[owner].operationCount += 1
        } else if pageIndex < pageOperationCounts.count {
            pageOperationCounts[pageIndex] += 1
        }
    }

    private static func makeOperatorTable() -> CGPDFOperatorTableRef? {
        guard let operators = CGPDFOperatorTableCreate() else { return nil }
        for name in countedOperators {
            CGPDFOperatorTableSetCallback(operators, name) { _, info in
                guard let info else { return }
                Unmanaged<FigureScanner>.fromOpaque(info).takeUnretainedValue().countOperation()
            }
        }
        CGPDFOperatorTableSetCallback(operators, "q") { _, info in
            guard let info else { return }
            let me = Unmanaged<FigureScanner>.fromOpaque(info).takeUnretainedValue()
            me.savedTransforms.append(me.transform)
        }
        CGPDFOperatorTableSetCallback(operators, "Q") { _, info in
            guard let info else { return }
            let me = Unmanaged<FigureScanner>.fromOpaque(info).takeUnretainedValue()
            if let last = me.savedTransforms.popLast() { me.transform = last }
        }
        CGPDFOperatorTableSetCallback(operators, "cm") { scanner, info in
            guard let info else { return }
            let me = Unmanaged<FigureScanner>.fromOpaque(info).takeUnretainedValue()
            var values = [CGPDFReal](repeating: 0, count: 6)
            for index in (0..<6).reversed() {
                guard CGPDFScannerPopNumber(scanner, &values[index]) else { return }
            }
            let matrix = CGAffineTransform(a: values[0], b: values[1], c: values[2], d: values[3], tx: values[4], ty: values[5])
            me.transform = matrix.concatenating(me.transform)
        }
        CGPDFOperatorTableSetCallback(operators, "Do") { scanner, info in
            guard let info else { return }
            let me = Unmanaged<FigureScanner>.fromOpaque(info).takeUnretainedValue()
            me.handleDo(scanner)
        }
        return operators
    }

    private func handleDo(_ scanner: CGPDFScannerRef) {
        var namePointer: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &namePointer), let namePointer else { return }
        let name = "/" + String(cString: namePointer)
        let stream = CGPDFScannerGetContentStream(scanner)
        var streamRef: CGPDFStreamRef?
        guard let object = CGPDFContentStreamGetResource(stream, "XObject", namePointer),
              CGPDFObjectGetValue(object, .stream, &streamRef), let streamRef,
              let dictionary = CGPDFStreamGetDictionary(streamRef) else { return }
        var subtype: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(dictionary, "Subtype", &subtype), let subtype else { return }
        let ref = namesStack.last?[name]

        switch String(cString: subtype) {
        case "Image":
            if let owner, let ref { figures[owner].nestedImages.insert(ref) }
        case "Form":
            guard namesStack.count < Self.maxFormDepth else { return }
            let full = Self.formMatrix(dictionary).concatenating(transform)
            if let owner {
                // 図の中の図: 外側の図の分として数える
                if let ref { figures[owner].nestedForms.insert(ref) }
                enter(streamRef, dictionary: dictionary, ref: ref, parent: stream, transform: full)
                return
            }
            // ページに直接置かれた図。番号が分からない図は扱えない（差し替えられない）ので数えない
            guard let ref else { return }
            let bbox = Self.bbox(dictionary)
            let isFirst = indexByRef[ref] == nil
            if isFirst {
                indexByRef[ref] = figures.count
                figures.append(Figure(ref: ref, pageIndex: pageIndex, bbox: bbox,
                                      contentHash: Self.hash(streamRef, bbox: bbox)))
            }
            let index = indexByRef[ref]!
            figures[index].scaleX = max(figures[index].scaleX, hypot(full.a, full.b))
            figures[index].scaleY = max(figures[index].scaleY, hypot(full.c, full.d))
            let placed = bbox.applying(full).size
            if placed.width * placed.height > figures[index].placedSize.width * figures[index].placedSize.height {
                figures[index].placedSize = placed
            }
            // 同じ図が 2 回目に置かれたときは、置かれた大きさだけ記録し、中は数え直さない
            guard isFirst else { return }
            owner = index
            enter(streamRef, dictionary: dictionary, ref: ref, parent: stream, transform: full)
            owner = nil
        default:
            return
        }
    }

    /// 図の中の命令を読む
    private func enter(_ streamRef: CGPDFStreamRef, dictionary: CGPDFDictionaryRef, ref: String?,
                       parent: CGPDFContentStreamRef, transform full: CGAffineTransform) {
        guard let operators else { return }
        var formResources: CGPDFDictionaryRef?
        let hasResources = CGPDFDictionaryGetDictionary(dictionary, "Resources", &formResources)
        // 資源の無い図は、呼び出し元の資源を使う
        let child = CGPDFContentStreamCreateWithStream(streamRef, (hasResources ? formResources : nil) ?? dictionary, parent)
        var names = namesStack.last ?? [:]
        if let ref, let formDictionary = table.streamDictionary(ref),
           let resources = table.dictionary(formDictionary["/Resources"]) {
            names = table.xObjects(in: resources)
        }
        let saved = transform
        let savedStack = savedTransforms
        transform = full
        savedTransforms = []
        namesStack.append(names)
        run(child, operators: operators)
        namesStack.removeLast()
        transform = saved
        savedTransforms = savedStack
        CGPDFContentStreamRelease(child)
    }

    private static func formMatrix(_ dictionary: CGPDFDictionaryRef) -> CGAffineTransform {
        guard let values = numbers(dictionary, "Matrix", count: 6) else { return .identity }
        return CGAffineTransform(a: values[0], b: values[1], c: values[2], d: values[3], tx: values[4], ty: values[5])
    }

    private static func bbox(_ dictionary: CGPDFDictionaryRef) -> CGRect {
        guard let values = numbers(dictionary, "BBox", count: 4) else { return .zero }
        return CGRect(x: min(values[0], values[2]), y: min(values[1], values[3]),
                      width: abs(values[2] - values[0]), height: abs(values[3] - values[1]))
    }

    private static func numbers(_ dictionary: CGPDFDictionaryRef, _ key: String, count: Int) -> [CGFloat]? {
        var array: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dictionary, key, &array), let array, CGPDFArrayGetCount(array) == count else {
            return nil
        }
        var values = [CGPDFReal](repeating: 0, count: count)
        for index in 0..<count {
            guard CGPDFArrayGetNumber(array, index, &values[index]) else { return nil }
        }
        return values
    }

    /// 図の中身（圧縮を解いた命令）と枠から作る指紋
    private static func hash(_ stream: CGPDFStreamRef, bbox: CGRect) -> String {
        var format = CGPDFDataFormat.raw
        var hasher = SHA256()
        if let data = CGPDFStreamCopyData(stream, &format) as Data? { hasher.update(data: data) }
        hasher.update(data: Data("\(bbox.minX) \(bbox.minY) \(bbox.width) \(bbox.height)".utf8))
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
