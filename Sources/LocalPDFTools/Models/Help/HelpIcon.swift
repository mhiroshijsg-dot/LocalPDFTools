import SwiftUI

/// ヘルプの項目の印。操作の項目は操作と同じ色と記号、それ以外は灰色
enum HelpIcon: Hashable {
    case operation(Operation)
    case symbol(String)

    var symbolName: String {
        switch self {
        case .operation(let operation): return operation.symbolName
        case .symbol(let name): return name
        }
    }

    var color: Color {
        switch self {
        case .operation(let operation): return OperationIcon.color(of: operation)
        case .symbol: return .gray
        }
    }
}
