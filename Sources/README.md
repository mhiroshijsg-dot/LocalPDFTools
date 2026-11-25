# Sources の中身

どのファイルが何をしているかの一覧。ファイルを足したり役割を変えたりしたら、ここも直す。

## 開き方

`LocalPDFTools.xcodeproj` を Xcode で開く。⌘R でアプリが起動し、⌘U で検査（テスト）が走る。
フォルダの中のファイルは Xcode に自動で入る（ファイルを足しても、プロジェクトの設定を直す必要はない）。

## 3 つのフォルダ（Xcode では 3 つの「ターゲット」）

| フォルダ | 何か | アプリに入るか |
|---|---|---|
| `Sources/LocalPDFTools/` | アプリ本体（画面とボタンの動き） | 入る |
| `Sources/PDFEngine/` | PDF の処理（qpdf の呼び出し・保存）。画面を持たない部品（フレームワーク） | 入る（本体から使う） |
| `Tests/PDFEngineTests/` | `PDFEngine` の検査。合成した PDF で結合・回転・暗号化の解除などを確かめる | 入らない |

## ビルドと .app

| ファイル | 役割 |
|---|---|
| `LocalPDFTools.xcodeproj` | Xcode のプロジェクト。バージョン番号（MARKETING_VERSION）もここ |
| `scripts/bundle_qpdf.sh` | Xcode のビルドの最後に毎回走り、Homebrew の qpdf とそのライブラリを .app に入れて署名する。⌘R でも配る形と同じ中身になる |
| `scripts/make_app.sh` | 配る形（Release）の .app を `build/LocalPDFTools.app` に作る |

覚え方: **見た目は `Views`、ボタンを押したあとの動きは `Models`、PDF そのものの処理は `PDFEngine`**。
こう分けておくと、見た目を変えても PDF の処理を壊さない。

## 動く順番

```
LocalPDFToolsApp.swift      起動の入口。窓を 1 つ作るだけ
   ↓
Views/ContentView.swift     左の機能一覧と、選んだ機能の画面への切り替え。各機能の状態（Model）を持つ
   ↓
Views/MergeView.swift       結合の画面（見た目）
Views/RotateView.swift      回転の画面（見た目）
Views/EncryptionView.swift  暗号化の解除の画面（見た目）
   ↓ ボタンが押されたら
Models/MergeModel.swift     結合の動き（保存先を聞く・結合を頼む・結果を覚える）
Models/RotateModel.swift    回転の動き
Models/EncryptionModel.swift  暗号化の解除の動き
   ↓
PDFEngine/PDFMerger.swift   qpdf に結合させる
PDFEngine/PDFRotator.swift  qpdf に回転させる
PDFEngine/PDFDecryptor.swift  qpdf に暗号化を外させる
   ↓
PDFEngine/OutputWriter.swift  一時ファイルに作ってから保存先へ移す（入力と同じ場所には保存させない）
```

## LocalPDFTools/（アプリ本体）

### 入口と全体

| ファイル | 役割 |
|---|---|
| `LocalPDFToolsApp.swift` | 起動の入口。窓を 1 つ作り、`ContentView` を表示する。窓の最小の大きさもここ |
| `AppDelegate.swift` | SwiftUI だけでは決められない振る舞い。窓を閉じたらアプリも終わる |
| `AppInfo.swift` | アプリ名 |

### Views/（画面の見た目）

| ファイル | 役割 |
|---|---|
| `ContentView.swift` | 窓全体。左に機能の一覧、右に選んだ機能の画面。各機能の状態をここで持つので、機能を切り替えても中身が消えない |
| `MergeView.swift` | 結合の画面。ファイルの一覧（ドラッグで並べ替え）・合計・説明文・保存ボタン |
| `RotateView.swift` | 回転の画面。ページの縮小表示を並べ、クリックで回す。「すべて右に 90°」などのボタン |
| `EncryptionView.swift` | 暗号化の解除の画面。注意書き・状態の札・（要るときだけ）パスワード欄・保存ボタン |
| `EncryptionStatusView.swift` | 暗号化の状態の札（「暗号化なし」「開けるが制限付き」「パスワードが要る」・方式・禁止されている操作） |
| `PageThumbnailView.swift` | 回転の画面の、縮小表示 1 枚分（画像・ページ番号・「右に 90°」の文字・枠） |
| `ComingSoonView.swift` | まだ作っていない機能（圧縮・文字の抽出）の「段階 ○ で作ります」画面 |

`MergeView.swift`・`RotateView.swift`・`EncryptionView.swift` の末尾の `#Preview` は、Xcode のプレビュー（右側にその場で描かれる画面）の設定。

### Views/Previews/（プレビュー用。配る .app には入らない）

| ファイル | 役割 |
|---|---|
| `PreviewSamples.swift` | プレビューに使う見本のデータ（架空のファイル名を並べた結合の状態・番号入りの見本 PDF を開いた回転の状態・架空のスコアレポートの暗号化の状態） |

### Views/Common/（結合と回転の両方で使う部品。1 か所直せば両方の画面が変わる）

| ファイル | 役割 |
|---|---|
| `DropZone.swift` | 「ここに PDF をドロップ」の点線の枠と「開く…」ボタン |
| `OutputNameField.swift` | 保存名の入力欄・文字数・文字数の上限（上限を超えると赤字） |
| `OutcomeView.swift` | 保存後の表示（保存先・「元 → 新」の大きさ・Finder で表示） |
| `MessageList.swift` | エラー・警告（赤字）とお知らせの一覧。右にコピーボタン |
| `Badge.swift` | ファイル名の横の小さな札（「制限あり」「しおりあり」） |

### Models/（画面の状態と、ボタンを押したときの動き）

| ファイル | 役割 |
|---|---|
| `Tool.swift` | 左の一覧に並ぶ機能の名前・アイコン・作る予定の段階 |
| `MergeModel.swift` | 結合の状態（入れたファイルの並び・保存名・結果）と操作（追加・外す・並べ替え・結合して保存） |
| `RotateModel.swift` | 回転の状態（開いた PDF・ページごとの向き・画面で傾ける角度）と操作（回す・元に戻す・保存） |
| `EncryptionModel.swift` | 暗号化の解除の状態（開いた PDF・調べた結果・パスワード・保存名・結果）と操作（調べる・外して保存）。パスワードは保存しない |
| `ThumbnailCache.swift` | 回転の画面の縮小表示を作って覚えておく（同じページを何度も描かない） |
| `OutputName.swift` | 保存名に `.pdf` を付ける・文字数を数える・上限を超えたかを判定する |
| `UserMessage.swift` | 画面に出すお知らせ 1 件（エラー・警告・お知らせの区別と文） |

### Services/（Mac の機能を呼ぶ部品）

| ファイル | 役割 |
|---|---|
| `FilePanels.swift` | 「開く」と「保存」のダイアログ |
| `DesktopActions.swift` | Finder でファイルを表示する・文字をコピーする |

## PDFEngine/（PDF の処理。画面を持たない）

| ファイル | 役割 |
|---|---|
| `QPDFRunner.swift` | qpdf のコマンドを呼ぶ。.app の中（Xcode の ⌘R も含む）では同梱の qpdf、テストでは Homebrew の qpdf を使う |
| `QPDFPassword.swift` | qpdf にパスワードを渡す方法。引数ではなく標準入力で渡す（引数は他のプログラムから見えるため） |
| `PDFMerger.swift` | 結合。`qpdf --empty --pages a.pdf b.pdf -- 出力.pdf` |
| `PDFRotator.swift` | 回転。`qpdf 入力 出力 --rotate=+90:1,3` |
| `RotationPlan.swift` | ページごとに「時計回りに何回 90° 回すか」と、それを qpdf の引数にする処理 |
| `OutputWriter.swift` | 保存の共通処理。入力と同じファイルには保存させない・一時ファイルに作ってから保存先へ移す（失敗しても既存のファイルを壊さない） |
| `PDFDecryptor.swift` | 暗号化の解除。`qpdf --decrypt`。保存先へ移す前に、出力が本当に暗号化なしかを確かめる |
| `PDFEncryptionInspector.swift` | 暗号化の状態を調べる。`qpdf --requires-password` と `qpdf --json --json-key=encrypt` |
| `EncryptionReport.swift` | 調べた結果 1 ファイル分（暗号化なし／制限付き／パスワードが要る・方式・禁止されている操作） |
| `PDFPermission.swift` | 禁止できる操作の一覧と日本語の名前（印刷・コピー・編集など） |
| `QPDFEncryptionJSON.swift` | qpdf の JSON の読み取り（使う部分だけ） |
| `PDFInspector.swift` | PDF を開いてページ数・大きさ・暗号化・しおりの有無を読む（中身は変えない） |
| `PDFFileInfo.swift` | `PDFInspector` が読んだ情報 1 ファイル分 |
| `OperationOutcome.swift` | 保存の結果（保存先・元と新の大きさ・qpdf の警告） |
| `FileSize.swift` | ファイルの大きさの取得と「4.9 MB」のような表示 |
| `EngineError.swift` | エラーの種類と、画面に出す日本語の説明文 |

## Tests/PDFEngineTests/（検査。アプリには入らない）

Xcode では ⌘U。結果は左の「テスト」の欄（◇ の印）に、1 件ごとに ✔ / ✘ で出る。
ターミナルなら `xcodebuild -project LocalPDFTools.xcodeproj -scheme LocalPDFTools test`。
.app に同梱した qpdf で確かめるときは、頭に `TEST_RUNNER_LOCALPDFTOOLS_QPDF=build/LocalPDFTools.app/Contents/Helpers/qpdf` を付ける。

| ファイル | 役割 |
|---|---|
| `MergeTests.swift` | 結合（順番・制限付きの混在・しおりが消えること） |
| `RotateTests.swift` | 回転（ページごと・足し算・大きさ・暗号化を保つこと） |
| `OutputSafetyTests.swift` | 保存の安全（入力と同じ保存先を止める・失敗しても既存のファイルを壊さない） |
| `PDFInspectorTests.swift` | 読み込み（制限付き・パスワードが要る・PDF でない） |
| `EncryptionTests.swift` | 暗号化の判定と解除（ETS 型・パスワード・日本語のパスワード・間違ったパスワード） |
| `TestWorkspace.swift` | テスト 1 件分の作業場所（一時フォルダ・見本の PDF・使う qpdf）。終わったら消す |
| `SamplePDFFactory.swift` | 検査に使う PDF を合成する（個人の書類は使わない） |
| `SampleError.swift` | 見本の PDF を作れなかったときのエラー |
