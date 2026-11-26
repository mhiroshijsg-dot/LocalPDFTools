import CoreGraphics
import Foundation

/// 各ページの描画の命令を読み、画像がページ上でどの大きさに描かれているか（ポイント）を調べる。
/// ページの中の図（Form XObject）の中に置かれた画像もたどる。
/// MEMO(2026-11-26・by claude): Core Graphics は部品の番号を教えてくれないので、
/// 画像の名前（/Im1 など）を qpdf の一覧（QPDFObjectTable）と突き合わせて番号にする。
final class ImagePlacementScanner {
    /// 部品の番号 → 描かれた中で一番大きい幅と高さ（ポイント）
    private(set) var largestPlacement: [String: CGSize] = [:]

    private let table: QPDFObjectTable
    private var transform = CGAffineTransform.identity
    private var savedTransforms: [CGAffineTransform] = []
    /// 今読んでいる流れで使える名前 → 部品の番号（図に入るたびに積む）
    private var namesStack: [[String: String]] = []
    /// 命令ごとの処理の表（C の関数なので、図の中を読むときにここから取り出す）
    private var operators: CGPDFOperatorTableRef?
    private static let maxFormDepth = 12

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
            guard let page = document.page(at: index + 1) else { continue }
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

    private static func makeOperatorTable() -> CGPDFOperatorTableRef? {
        guard let operators = CGPDFOperatorTableCreate() else { return nil }
        CGPDFOperatorTableSetCallback(operators, "q") { _, info in
            guard let info else { return }
            let me = Unmanaged<ImagePlacementScanner>.fromOpaque(info).takeUnretainedValue()
            me.savedTransforms.append(me.transform)
        }
        CGPDFOperatorTableSetCallback(operators, "Q") { _, info in
            guard let info else { return }
            let me = Unmanaged<ImagePlacementScanner>.fromOpaque(info).takeUnretainedValue()
            if let last = me.savedTransforms.popLast() { me.transform = last }
        }
        CGPDFOperatorTableSetCallback(operators, "cm") { scanner, info in
            guard let info else { return }
            let me = Unmanaged<ImagePlacementScanner>.fromOpaque(info).takeUnretainedValue()
            var values = [CGPDFReal](repeating: 0, count: 6)
            for index in (0..<6).reversed() {
                guard CGPDFScannerPopNumber(scanner, &values[index]) else { return }
            }
            let matrix = CGAffineTransform(a: values[0], b: values[1], c: values[2], d: values[3], tx: values[4], ty: values[5])
            me.transform = matrix.concatenating(me.transform)
        }
        CGPDFOperatorTableSetCallback(operators, "Do") { scanner, info in
            guard let info else { return }
            let me = Unmanaged<ImagePlacementScanner>.fromOpaque(info).takeUnretainedValue()
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
            guard let ref else { return }
            // 画像は 1×1 の正方形を今の変換で描く。変換後の辺の長さが、ページ上の幅と高さ
            let width = hypot(transform.a, transform.b)
            let height = hypot(transform.c, transform.d)
            let previous = largestPlacement[ref] ?? .zero
            largestPlacement[ref] = CGSize(width: max(previous.width, width), height: max(previous.height, height))
        case "Form":
            guard namesStack.count < Self.maxFormDepth, let operators else { return }
            var formResources: CGPDFDictionaryRef?
            let hasResources = CGPDFDictionaryGetDictionary(dictionary, "Resources", &formResources)
            // 資源の無い図は、呼び出し元の資源を使う（辞書そのものを渡すと、名前は親でさがされる）
            let child = CGPDFContentStreamCreateWithStream(streamRef, (hasResources ? formResources : nil) ?? dictionary, stream)
            var names = namesStack.last ?? [:]
            if let ref, let formDictionary = table.streamDictionary(ref),
               let resources = table.dictionary(formDictionary["/Resources"]) {
                names = table.xObjects(in: resources)
            }
            let saved = transform
            transform = Self.formMatrix(dictionary).concatenating(transform)
            namesStack.append(names)
            run(child, operators: operators)
            namesStack.removeLast()
            transform = saved
            CGPDFContentStreamRelease(child)
        default:
            return
        }
    }

    private static func formMatrix(_ dictionary: CGPDFDictionaryRef) -> CGAffineTransform {
        var array: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dictionary, "Matrix", &array), let array, CGPDFArrayGetCount(array) == 6 else {
            return .identity
        }
        var values = [CGPDFReal](repeating: 0, count: 6)
        for index in 0..<6 {
            guard CGPDFArrayGetNumber(array, index, &values[index]) else { return .identity }
        }
        return CGAffineTransform(a: values[0], b: values[1], c: values[2], d: values[3], tx: values[4], ty: values[5])
    }
}
