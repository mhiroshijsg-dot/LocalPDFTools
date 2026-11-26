import Foundation
import PDFEngine

/// 操作を行う順番（設定で変えられる）。
/// 暗号化の解除は常に最初で、並べ替えられるのはその後ろだけ。
/// MEMO(2026-11-26・by claude): 解除を後ろにすると、結合でパスワードを引数（他のプログラムから見える）で渡すしかなくなるため固定（村田さん了承）。
enum OperationOrder {
    /// 設定に覚えるときの名前
    static let storageKey = "operationOrder"
    /// おすすめの順（解除の後ろ）。圧縮が最後なのは、提出先のサイズ上限に効くのは最後の大きさだから
    static let recommended: [PipelineStep] = [.rotate, .merge, .compress]

    /// 設定の文字（例: "merge,rotate"）を順番にする。知らない名前は捨て、足りない操作はおすすめの順で後ろに足す
    static func reorderable(from raw: String) -> [PipelineStep] {
        var order: [PipelineStep] = []
        for name in raw.split(separator: ",") {
            if let step = PipelineStep(rawValue: String(name)), recommended.contains(step), !order.contains(step) {
                order.append(step)
            }
        }
        return order + recommended.filter { !order.contains($0) }
    }

    static func raw(_ order: [PipelineStep]) -> String {
        order.map(\.rawValue).joined(separator: ",")
    }

    /// 今の設定での、解除を含めた全部の順番
    static func current() -> [PipelineStep] {
        [.decrypt] + reorderable(from: UserDefaults.standard.string(forKey: storageKey) ?? "")
    }
}
