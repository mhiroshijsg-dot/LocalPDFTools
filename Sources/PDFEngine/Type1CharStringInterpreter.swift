/// Type1 の字形の描き方（暗号を解いた CharString）を実行して、字形の形（GlyphOutline）にする。
/// 下請け（Subrs）の呼び出し・flex（なだらかな曲線の組）・手がかりの入れ替え・アクセント付きの字（seac）・割り算（div）を扱う。
/// 知らない命令が出たら throw する（そのフォントは作り直さずに元のまま残す）。
/// MEMO(2026-11-27・by claude): 動きは Adobe の Type 1 Font Format と FreeType（t1decode）・fontTools（psCharStrings）に合わせた。
/// seac のアクセントの位置は fontTools と同じく「adx + 合成する字の左の余白 − asb」。
struct Type1CharStringInterpreter {
    enum InterpretError: Error {
        case stackUnderflow
        case badSubr(Int)
        case unknownOperator(Int)
        case unknownOtherSubr(Int)
        case missingGlyph(String)
        case tooDeep
    }

    let subrs: [[UInt8]]
    /// 名前 → 描き方（seac でほかの字形を呼ぶため）
    let charStrings: [String: [UInt8]]

    func outline(of name: String) throws -> GlyphOutline {
        guard let data = charStrings[name] else { throw InterpretError.missingGlyph(name) }
        var state = State()
        try run(data, state: &state, depth: 0)
        return state.outline
    }

    private struct State {
        var stack: [Double] = []
        var psStack: [Double] = []
        var x = 0.0
        var y = 0.0
        var sideBearingX = 0.0
        var sideBearingY = 0.0
        var inFlex = false
        /// flex を終えた直後（続く setcurrentpoint の値は使わず、flex の終わりの点のままにする）
        var flexJustEnded = false
        var flexPoints: [GlyphOutline.Point] = []
        var finished = false
        var outline = GlyphOutline()

        mutating func pop() throws -> Double {
            guard let value = stack.popLast() else { throw InterpretError.stackUnderflow }
            return value
        }

        /// 下から順に count 個を取り出す
        mutating func take(_ count: Int) throws -> [Double] {
            guard stack.count >= count else { throw InterpretError.stackUnderflow }
            let values = Array(stack.suffix(count))
            stack.removeLast(count)
            return values
        }

        mutating func moveBy(_ dx: Double, _ dy: Double) {
            x += dx
            y += dy
            if inFlex {
                flexPoints.append(.init(x: x, y: y))
            } else {
                outline.segments.append(.move(.init(x: x, y: y)))
            }
        }

        mutating func lineBy(_ dx: Double, _ dy: Double) {
            x += dx
            y += dy
            outline.segments.append(.line(.init(x: x, y: y)))
        }

        mutating func curveBy(_ dx1: Double, _ dy1: Double, _ dx2: Double, _ dy2: Double, _ dx3: Double, _ dy3: Double) {
            let p1 = GlyphOutline.Point(x: x + dx1, y: y + dy1)
            let p2 = GlyphOutline.Point(x: p1.x + dx2, y: p1.y + dy2)
            let p3 = GlyphOutline.Point(x: p2.x + dx3, y: p2.y + dy3)
            x = p3.x
            y = p3.y
            outline.segments.append(.curve(p1, p2, p3))
        }
    }

    private func run(_ code: [UInt8], state: inout State, depth: Int) throws {
        guard depth < 16 else { throw InterpretError.tooDeep }
        var index = 0
        while index < code.count, !state.finished {
            let byte = Int(code[index])
            index += 1
            switch byte {
            case 32...246:
                state.stack.append(Double(byte - 139))
                continue
            case 247...250:
                guard index < code.count else { throw InterpretError.stackUnderflow }
                state.stack.append(Double((byte - 247) * 256 + Int(code[index]) + 108))
                index += 1
                continue
            case 251...254:
                guard index < code.count else { throw InterpretError.stackUnderflow }
                state.stack.append(Double(-(byte - 251) * 256 - Int(code[index]) - 108))
                index += 1
                continue
            case 255:
                guard index + 4 <= code.count else { throw InterpretError.stackUnderflow }
                let value = Int32(bitPattern: UInt32(code[index]) << 24 | UInt32(code[index + 1]) << 16
                                  | UInt32(code[index + 2]) << 8 | UInt32(code[index + 3]))
                state.stack.append(Double(value))
                index += 4
                continue
            default:
                break
            }

            var op = byte
            if byte == 12 {
                guard index < code.count else { throw InterpretError.unknownOperator(12) }
                op = 1200 + Int(code[index])
                index += 1
            }
            switch op {
            case 1: // hstem
                let v = try state.take(2)
                state.outline.horizontalStems.append(.init(position: state.sideBearingY + v[0], width: v[1]))
            case 3: // vstem
                let v = try state.take(2)
                state.outline.verticalStems.append(.init(position: state.sideBearingX + v[0], width: v[1]))
            case 1202: // hstem3
                let v = try state.take(6)
                for i in stride(from: 0, to: 6, by: 2) {
                    state.outline.horizontalStems.append(.init(position: state.sideBearingY + v[i], width: v[i + 1]))
                }
            case 1201: // vstem3
                let v = try state.take(6)
                for i in stride(from: 0, to: 6, by: 2) {
                    state.outline.verticalStems.append(.init(position: state.sideBearingX + v[i], width: v[i + 1]))
                }
            case 1200: // dotsection
                state.stack.removeAll()
            case 4: // vmoveto
                let v = try state.take(1)
                state.moveBy(0, v[0])
            case 22: // hmoveto
                let v = try state.take(1)
                state.moveBy(v[0], 0)
            case 21: // rmoveto
                let v = try state.take(2)
                state.moveBy(v[0], v[1])
            case 5: // rlineto
                let v = try state.take(2)
                state.lineBy(v[0], v[1])
            case 6: // hlineto
                let v = try state.take(1)
                state.lineBy(v[0], 0)
            case 7: // vlineto
                let v = try state.take(1)
                state.lineBy(0, v[0])
            case 8: // rrcurveto
                let v = try state.take(6)
                state.curveBy(v[0], v[1], v[2], v[3], v[4], v[5])
            case 30: // vhcurveto
                let v = try state.take(4)
                state.curveBy(0, v[0], v[1], v[2], v[3], 0)
            case 31: // hvcurveto
                let v = try state.take(4)
                state.curveBy(v[0], 0, v[1], v[2], 0, v[3])
            case 9: // closepath（CFF では次の移動か終わりで自動で閉じる。今の位置は変えない）
                state.stack.removeAll()
            case 13: // hsbw
                let v = try state.take(2)
                state.sideBearingX = v[0]
                state.sideBearingY = 0
                state.outline.width = v[1]
                state.x = v[0]
                state.y = 0
            case 1207: // sbw
                let v = try state.take(4)
                state.sideBearingX = v[0]
                state.sideBearingY = v[1]
                state.outline.width = v[2]
                state.x = v[0]
                state.y = v[1]
            case 1212: // div
                let v = try state.take(2)
                guard v[1] != 0 else { throw InterpretError.stackUnderflow }
                state.stack.append(v[0] / v[1])
            case 10: // callsubr
                let number = Int(try state.pop())
                guard number >= 0, number < subrs.count else { throw InterpretError.badSubr(number) }
                try run(subrs[number], state: &state, depth: depth + 1)
            case 11: // return
                return
            case 1216: // callothersubr
                try callOtherSubr(&state)
            case 1217: // pop
                guard let value = state.psStack.popLast() else { throw InterpretError.stackUnderflow }
                state.stack.append(value)
            case 1233: // setcurrentpoint
                let v = try state.take(2)
                if !state.flexJustEnded {
                    state.x = v[0]
                    state.y = v[1]
                }
                state.flexJustEnded = false
            case 1206: // seac
                let v = try state.take(5)
                try composeAccented(asb: v[0], adx: v[1], ady: v[2], base: Int(v[3]), accent: Int(v[4]), state: &state)
                state.finished = true
            case 14: // endchar
                state.finished = true
            default:
                throw InterpretError.unknownOperator(op)
            }
            if op != 1212 && op != 1217 && op != 10 && op != 11 && op != 1216 { state.stack.removeAll() }
        }
    }

    /// 決まった番号の「ほかの下請け」（flex と、手がかりの入れ替え）
    private func callOtherSubr(_ state: inout State) throws {
        let number = Int(try state.pop())
        let count = Int(try state.pop())
        let arguments = try state.take(count)
        switch number {
        case 1: // flex の始め
            state.inFlex = true
            state.flexPoints = []
        case 2: // flex の点を足す（点は直前の rmoveto で足してある）
            break
        case 0: // flex の終わり: 7 点のうち、最初の基準の点を除く 6 点で曲線 2 本
            guard arguments.count == 3, state.flexPoints.count == 7 else { throw InterpretError.unknownOtherSubr(0) }
            let p = state.flexPoints
            state.inFlex = false
            state.outline.segments.append(.curve(p[1], p[2], p[3]))
            state.outline.segments.append(.curve(p[4], p[5], p[6]))
            state.x = p[6].x
            state.y = p[6].y
            state.flexJustEnded = true
            // 後に続く "pop pop setcurrentpoint" が、終わりの点を受け取る
            state.psStack = [arguments[2], arguments[1]]
        case 3: // 手がかりの入れ替え: 続く "pop callsubr" で、手がかりだけの下請けを呼ばせる
            guard let subr = arguments.first else { throw InterpretError.unknownOtherSubr(3) }
            state.psStack = [subr]
        case 12, 13: // 字間の調整（使わない）
            state.psStack = []
        default:
            throw InterpretError.unknownOtherSubr(number)
        }
    }

    /// アクセント付きの字: 元の字をそのまま、アクセントをずらして重ねる（手がかりは元の字のものだけ）
    private func composeAccented(asb: Double, adx: Double, ady: Double, base: Int, accent: Int, state: inout State) throws {
        guard let baseName = StandardEncodingNames.name(of: base),
              let accentName = StandardEncodingNames.name(of: accent) else { throw InterpretError.missingGlyph("seac") }
        let baseOutline = try outline(of: baseName)
        let accentOutline = try outline(of: accentName)
        let offsetX = adx + state.sideBearingX - asb
        state.outline.segments += baseOutline.segments
        state.outline.segments += accentOutline.segments.map { $0.offset(by: offsetX, ady) }
        state.outline.horizontalStems = baseOutline.horizontalStems
        state.outline.verticalStems = baseOutline.verticalStems
    }
}

extension GlyphOutline.Segment {
    func offset(by dx: Double, _ dy: Double) -> GlyphOutline.Segment {
        func move(_ p: GlyphOutline.Point) -> GlyphOutline.Point { .init(x: p.x + dx, y: p.y + dy) }
        switch self {
        case .move(let p): return .move(move(p))
        case .line(let p): return .line(move(p))
        case .curve(let a, let b, let c): return .curve(move(a), move(b), move(c))
        }
    }
}
