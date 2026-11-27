import Foundation

/// アプリの画面の言語。設定（⌘,）で選ぶ。
/// MEMO(2026-11-27・by claude): 英語版（計画 A）。村田さんの選択「アプリの設定でも選べる」。
/// Mac の標準の仕組み（このアプリの設定の AppleLanguages）を書き換えるだけなので、
/// システム設定 → 一般 → 言語と地域 →「アプリケーション」で選んだものと同じ所に入る。切り替わるのは次に起動したとき。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case japanese = "ja"
    case english = "en"

    var id: String { rawValue }

    /// 選ぶ欄に出す名前。日本語・English は、今の画面の言語に関係なくその言語で書く（読めない人が戻せるように）
    var title: String {
        switch self {
        case .system: return String(localized: "Mac に合わせる")
        case .japanese: return "日本語"
        case .english: return "English"
        }
    }

    private static let key = "AppleLanguages"

    /// このアプリだけに選んである言語（無ければ Mac に合わせる）。Mac 全体の設定は見ない
    static var saved: AppLanguage {
        let domain = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }
        guard let first = (domain?[key] as? [String])?.first else { return .system }
        if first.hasPrefix("ja") { return .japanese }
        if first.hasPrefix("en") { return .english }
        return .system
    }

    /// 起動したときの選択（変えたら「次の起動から」と知らせるため）
    static let atLaunch = saved

    static func save(_ language: AppLanguage) {
        switch language {
        case .system: UserDefaults.standard.removeObject(forKey: key)
        case .japanese, .english: UserDefaults.standard.set([language.rawValue], forKey: key)
        }
    }
}
