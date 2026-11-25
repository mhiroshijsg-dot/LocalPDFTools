/// 検査用の PDF を作れなかった・開けなかったときのエラー
struct SampleError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
