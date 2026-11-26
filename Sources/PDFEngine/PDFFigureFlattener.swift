import CoreGraphics
import Foundation

/// 選んだ図（Form XObject）の中身を、同じ枠いっぱいに置いた 1 枚の画像に置き換える。
/// 図そのものを書き換えるので、ページの命令には触らず、同じ図が何か所に置かれていても全部が同じ位置のまま画像になる。
/// 差し戻しは圧縮と同じく qpdf の `--update-from-json` で行う（この型は差し戻しの指定を作るだけ）。
struct PDFFigureFlattener {
    let runner: QPDFRunner

    struct Result {
        /// qpdf の差し戻しの指定（"obj:N 0 R" → 中身）
        var updates: [String: Any] = [:]
        /// 新しく足した部品も含めた、一番大きい部品の番号
        var maxObjectID: Int
        /// 画像にした図の数
        var flattened = 0
        /// 画像にしても小さくならない・描けなかったので、元のまま残した図の数
        var kept = 0
        /// 画像にした図と、その中にあった部品の番号（ほかの圧縮の処理で触らなくてよいもの）
        var replacedRefs = Set<String>()
    }

    /// 画像の名前（図の資源の中で使う）
    static let imageName = "/LPTFig"

    func apply(_ input: URL, table: QPDFObjectTable, settings: FigureRasterization, maxObjectID: Int,
               workDirectory: URL) async throws -> Result {
        var result = Result(maxObjectID: maxObjectID)
        let report = try HeavyFigureFinder(runner: runner).find(input, table: table)
        let targets = report.figures.filter { settings.selected.contains($0.id) }
        guard !targets.isEmpty else { return result }

        let rasterizer = FigureRasterizer(runner: runner)
        let document = try await rasterizer.figureDocument(input, table: table, figures: targets, work: workDirectory)
        for (index, figure) in targets.enumerated() {
            try Task.checkCancellation()
            let size = figure.pixelSize(dpi: settings.dpi)
            guard let image = rasterizer.render(document, index: index, figure: figure, width: size.width, height: size.height),
                  let encoded = Self.encode(image),
                  Int64(encoded.data.count) < figure.byteCount,
                  var dictionary = table.streamDictionary(figure.ref) else {
                result.kept += 1
                continue
            }
            result.maxObjectID += 1
            let imageRef = "\(result.maxObjectID) 0 R"
            let imageFile = workDirectory.appendingPathComponent("figure-\(index).bin")
            try encoded.data.write(to: imageFile)
            result.updates["obj:" + imageRef] = ["stream": [
                "dict": ["/Type": "/XObject", "/Subtype": "/Image", "/Width": size.width, "/Height": size.height,
                         "/ColorSpace": encoded.isGray ? "/DeviceGray" : "/DeviceRGB", "/BitsPerComponent": 8,
                         "/Filter": "/FlateDecode"] as [String: Any],
                "datafile": imageFile.path,
            ] as [String: Any]]

            // 図の枠いっぱいに画像を 1 枚置く命令（図の中の座標で書く。/Matrix はそのまま残すので、置き場所は変わらない）
            let box = figure.bbox
            let content = "q \(Self.number(box.width)) 0 0 \(Self.number(box.height)) \(Self.number(box.minX)) \(Self.number(box.minY)) cm \(Self.imageName) Do Q\n"
            let contentFile = workDirectory.appendingPathComponent("figure-\(index).txt")
            try Data(content.utf8).write(to: contentFile)
            // 古い資源（線・文字・中の図）は参照されなくなり、qpdf が書き出すときに落ちる。
            // 透明度のグループ（/Group）は、不透明な画像になったので外す
            for key in ["/Resources", "/Group", "/Filter", "/DecodeParms", "/Length", "/PieceInfo", "/LastModified"] {
                dictionary[key] = nil
            }
            dictionary["/Resources"] = ["/XObject": [Self.imageName: imageRef]]
            result.updates["obj:" + figure.ref] = ["stream": ["dict": dictionary, "datafile": contentFile.path] as [String: Any]]
            result.flattened += 1
            result.replacedRefs.insert(figure.ref)
            result.replacedRefs.formUnion(figure.nestedRefs)
        }
        return result
    }

    /// 画素の並び（灰色だけなら 1 バイト、色があれば RGB の 3 バイト）を可逆の圧縮にする
    static func encode(_ image: CGImage) -> (data: Data, isGray: Bool)? {
        guard image.bitsPerPixel == 32, let source = image.dataProvider?.data as Data? else { return nil }
        let width = image.width
        let height = image.height
        let rowBytes = image.bytesPerRow
        var isGray = true
        var rgb = Data(count: width * height * 3)
        source.withUnsafeBytes { (input: UnsafeRawBufferPointer) in
            rgb.withUnsafeMutableBytes { (output: UnsafeMutableRawBufferPointer) in
                var target = 0
                for row in 0..<height {
                    var pixel = row * rowBytes
                    for _ in 0..<width {
                        let red = input[pixel], green = input[pixel + 1], blue = input[pixel + 2]
                        if isGray && (red != green || green != blue) { isGray = false }
                        output[target] = red
                        output[target + 1] = green
                        output[target + 2] = blue
                        target += 3
                        pixel += 4
                    }
                }
            }
        }
        // 白黒・灰色だけの図は 1 ピクセル 1 バイトにする（データが 3 分の 1 になる）
        if isGray {
            var gray = Data(count: width * height)
            rgb.withUnsafeBytes { (input: UnsafeRawBufferPointer) in
                gray.withUnsafeMutableBytes { (output: UnsafeMutableRawBufferPointer) in
                    for index in 0..<(width * height) { output[index] = input[index * 3] }
                }
            }
            rgb = gray
        }
        guard let data = FlateEncoder.encode(rgb) else { return nil }
        return (data, isGray)
    }

    /// 命令に書く数（小数は 4 桁まで・末尾の 0 は書かない）
    private static func number(_ value: CGFloat) -> String {
        var text = String(format: "%.4f", Double(value))
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text == "-0" ? "0" : text
    }
}
