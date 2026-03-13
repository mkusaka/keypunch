# Keypunch — 仕様書

> English version: [SPEC.md](./SPEC.md)

## Overview

Keypunch は macOS メニューバー常駐アプリケーションで、グローバルキーボードショートカットを登録してアプリケーションを起動する。Dock アイコンは表示せず、メニューバーのキーボードアイコンからすべての操作を行う。

## System Requirements

| 項目 | 要件 |
|------|------|
| OS | macOS 15.0+ |
| Xcode | 16+ |
| Swift | 5.0 |
| サンドボックス | 有効 (App Sandbox) |
| ファイルアクセス | ユーザー選択ファイルの読み取り専用 |

## Architecture

### Tech Stack

| レイヤー | 技術 |
|---------|------|
| UI フレームワーク | SwiftUI (`MenuBarExtra` + `Settings`) |
| グローバルホットキー | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) v2.4.0 |
| 状態管理 | `@Observable` (Swift Observation) |
| データ永続化 | UserDefaults (JSON エンコード) |
| アプリ起動 | NSWorkspace |

### App Configuration

| 項目 | 値 |
|------|-----|
| Bundle Identifier | `com.mkusaka.Keypunch` |
| LSUIElement | `YES` (Dock 非表示) |
| メニューバーアイコン | SF Symbols `keyboard` |

### ファイル構成

```
Keypunch/
├── KeypunchApp.swift          # エントリポイント、テストモード制御
├── Models/
│   └── AppShortcut.swift      # ショートカットデータモデル
├── ShortcutStore.swift        # 状態管理・永続化・アプリ起動
├── Views/
│   ├── MenuBarView.swift      # メニューバードロップダウン
│   ├── SettingsView.swift     # 設定ウィンドウ (マスター・ディテール)
│   └── ShortcutEditView.swift # ショートカット編集フォーム
└── Keypunch.entitlements      # サンドボックス設定

KeypunchTests/
└── KeypunchTests.swift        # ユニットテスト (Swift Testing)

KeypunchUITests/
├── KeypunchUITests.swift      # UI テスト (XCTest)
└── KeypunchUITestsLaunchTests.swift # 起動テスト
```

---

## Data Model

### AppShortcut

アプリケーションショートカットの1件を表す構造体。

```swift
struct AppShortcut: Identifiable, Codable, Hashable
```

| プロパティ | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `id` | `UUID` | 自動生成 | 一意識別子 |
| `name` | `String` | — | 表示名 (ユーザー編集可) |
| `bundleIdentifier` | `String?` | — | macOS バンドル ID (例: `com.apple.calculator`) |
| `appPath` | `String` | — | アプリケーションのフルパス |
| `shortcutName` | `String` | `"appShortcut_\(id)"` | KeyboardShortcuts ライブラリ用の一意名 |

**Computed Properties**:

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `keyboardShortcutName` | `KeyboardShortcuts.Name` | ライブラリ連携用の名前オブジェクト |
| `appURL` | `URL` | `appPath` から生成したファイル URL |

**制約**:
- `id` は生成時に自動採番され、一意性が保証される
- `shortcutName` も生成時に `id` ベースで自動生成され、一意性が保証される
- `bundleIdentifier` は `nil` を許容する (バンドル ID を持たないアプリに対応)

---

## State Management

### ShortcutStore

アプリケーション全体のショートカット管理を担う `@Observable` クラス。

```swift
@MainActor
@Observable
final class ShortcutStore
```

#### 永続化

| 項目 | 値 |
|------|-----|
| ストレージ | UserDefaults |
| キー | `"savedAppShortcuts"` |
| フォーマット | JSON (`JSONEncoder` / `JSONDecoder`) |
| 対象データ | `[AppShortcut]` 配列 |
| 初期化時の読み込み | `init()` でデコードして `shortcuts` に設定 |

**注意**: キーボードショートカットのキーバインディング自体は KeyboardShortcuts ライブラリが独自に UserDefaults へ永続化する。ShortcutStore が保存するのはアプリメタデータ (名前、パス、バンドル ID、ショートカット名) のみ。

#### 公開メソッド

| メソッド | 説明 |
|---------|------|
| `addShortcut(_:)` | ショートカットを追加し、ハンドラ登録・永続化を実行 |
| `removeShortcut(_:)` | ショートカットを削除し、キーバインディングをリセット・永続化 |
| `removeShortcuts(at:)` | `IndexSet` で指定された複数ショートカットを一括削除 |
| `updateShortcut(_:)` | ID で一致するショートカットを更新。`shortcutName` 変更時は旧バインディングをリセット |
| `containsApp(path:)` | 指定パスのアプリが登録済みか判定 |
| `containsApp(bundleIdentifier:)` | 指定バンドル ID のアプリが登録済みか判定 |
| `launchApp(for:)` | 対象アプリを起動 |

#### アプリ起動ロジック

`launchApp(for:)` は以下の優先順位でアプリを解決する:

1. `bundleIdentifier` が非 nil かつ `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` で解決可能 → そのURLで起動
2. フォールバック: `appPath` を URL に変換して起動

いずれも `NSWorkspace.shared.openApplication(at:configuration:)` を使用。

#### ハンドラ登録

- `addShortcut` 時に `KeyboardShortcuts.onKeyUp(for:)` でコールバックを登録
- コールバック内で `launchApp(for:)` を呼び出し
- `init()` 時に全ショートカットのハンドラを一括登録

---

## UI Components

### 1. MenuBarExtra (メニューバードロップダウン)

**アイコン**: SF Symbols `keyboard`
**タイトル**: "Keypunch"

#### メニュー構成

```
┌──────────────────────────────────┐
│ [icon] Calculator     ⌘⇧C       │  ← ショートカットあり: 表示
│ [icon] Safari         ⌥⇧S       │
│──────────────────────────────────│
│ Settings...               ⌘,    │
│ Quit Keypunch             ⌘Q    │
└──────────────────────────────────┘
```

**ショートカット未登録時**:

```
┌──────────────────────────────────┐
│ No shortcuts configured         │  ← disabled
│──────────────────────────────────│
│ Settings...               ⌘,    │
│ Quit Keypunch             ⌘Q    │
└──────────────────────────────────┘
```

#### 表示ルール

| 条件 | 表示 |
|------|------|
| ショートカットが1件以上 (キーバインド設定済み) | アイコン + アプリ名 + ショートカットキー |
| ショートカットが0件、またはすべてキーバインド未設定 | "No shortcuts configured" (disabled) |

#### フィルタリング

- **通常モード**: `KeyboardShortcuts.getShortcut(for:) != nil` のショートカットのみ表示
- **テストモード** (`showAllForTesting = true`): すべてのショートカットを表示

#### メニューアイテム構成

各ショートカット行は以下の要素を含む:

| 要素 | 取得方法 | 備考 |
|------|---------|------|
| アプリアイコン | `NSWorkspace.shared.icon(forFile: appPath)` | パスが無効でもジェネリックアイコンを返す |
| アプリ名 | `shortcut.name` | |
| ショートカットキー | `KeyboardShortcuts.getShortcut(for:)?.description` | 未設定時は非表示 |

#### アクション

| 操作 | 動作 |
|------|------|
| ショートカット行をクリック | 対象アプリを起動 |
| "Settings..." をクリック | 設定ウィンドウを開く |
| "Quit Keypunch" をクリック | アプリを終了 |

---

### 2. Settings Window (設定ウィンドウ)

**ウィンドウタイトル**: "Keypunch Settings"
**最小サイズ**: 550 x 300

マスター・ディテールレイアウト (`HSplitView`)。

#### 左ペイン: サイドバー

**幅**: 220pt (固定)

```
┌─────────────────────────────┐
│ [icon] Calculator    ⌘⇧C   │  ← 選択状態
│ [icon] Safari        ⌥⇧S   │
│ [icon] TextEdit             │  ← キーバインド未設定
│                             │
│                             │
│ [+] [-]                     │  ← ツールバー
└─────────────────────────────┘
```

**各行の構成**:

| 要素 | サイズ | 説明 |
|------|------|------|
| アプリアイコン | 18x18 | `NSWorkspace.shared.icon(forFile:)` |
| アプリ名 | — | `shortcut.name` |
| ショートカットキー | — | secondary カラー、`.callout` フォント。未設定時は非表示 |

**ツールバーボタン**:

| ボタン | アイコン | 動作 | 状態 |
|--------|---------|------|------|
| `+` (追加) | `plus` | NSOpenPanel を開く | 常に有効 |
| `-` (削除) | `minus` | 選択中のショートカットを削除 | 未選択時は無効 |

#### 右ペイン: ディテール

**最小幅**: 300pt

**ショートカット未選択時**:
```
Select a shortcut or add a new one
```

**ショートカット選択時** (ShortcutEditView):

```
┌─────────────────────────────────┐
│  Name:        [Calculator    ]  │  ← 編集可能テキストフィールド
│  Application: /System/Applic... │  ← 読み取り専用、中間省略
│  Bundle ID:   com.apple.calc... │  ← bundleIdentifier が nil の場合は非表示
│  Shortcut:    [Record Shortcut] │  ← KeyboardShortcuts.Recorder
└─────────────────────────────────┘
```

**ShortcutEditView の各フィールド**:

| フィールド | 型 | 編集可否 | 備考 |
|-----------|-----|---------|------|
| Name | TextField | 可 | `onSubmit` で store.updateShortcut を呼び出し |
| Application | LabeledContent | 不可 | `.truncationMode(.middle)` で中間省略 |
| Bundle ID | LabeledContent | 不可 | `bundleIdentifier` が nil の場合は行自体を非表示 |
| Shortcut | KeyboardShortcuts.Recorder | 可 | ライブラリ提供の録画ウィジェット |

---

### 3. ショートカット追加フロー

1. ユーザーが `+` ボタンをクリック
2. `NSOpenPanel` が開く
   - `allowedContentTypes`: `.application`
   - `directoryURL`: `/Applications`
   - `allowsMultipleSelection`: `false`
3. ユーザーがアプリケーションを選択
4. 以下の情報を抽出:
   - `appName`: ファイル名から `.app` 拡張子を除去
   - `appPath`: フルパス
   - `bundleIdentifier`: `Bundle(path:)?.bundleIdentifier`
5. **重複チェック**:
   - `store.containsApp(path: appPath)` → パスで重複確認
   - `bundleIdentifier != nil && store.containsApp(bundleIdentifier: bundleIdentifier!)` → バンドル ID で重複確認
6. 重複の場合: "Duplicate Application" アラートを表示 (`"\(appName) has already been added."`)
7. 重複でない場合: `AppShortcut` を生成して `store.addShortcut()` で追加

---

### 4. ショートカット削除フロー

1. サイドバーでショートカットを選択
2. `-` ボタンをクリック (または将来的に Delete キー)
3. `store.removeShortcut()` を呼び出し
4. キーバインディングがリセットされ、UserDefaults から削除
5. `selectedShortcut` が nil に戻り、ディテールペインがプレースホルダーに変わる

---

## Test Mode

CI やテスト実行時にアプリの動作を制御するための仕組み。

### コマンドライン引数

| 引数 | UserDefaults リセット | シードデータ適用 | テストモード (フィルタバイパス) |
|------|---------------------|-----------------|----------------------------|
| `-resetForTesting` | Yes | Yes (環境変数があれば) | Yes (`showAllForTesting = true`) |
| `-seedOnly` | Yes | Yes (環境変数があれば) | No (通常のフィルタ動作) |
| (なし) | No | No | No |

### 環境変数

| 変数名 | 型 | 説明 |
|--------|-----|------|
| `SEED_SHORTCUTS` | JSON 文字列 | テスト用のシードデータ。AppShortcut の配列を JSON 形式で渡す |

**シードデータのフォーマット**:

```json
[
  {
    "id": "UUID文字列",
    "name": "Calculator",
    "bundleIdentifier": "com.apple.calculator",
    "appPath": "/System/Applications/Calculator.app",
    "shortcutName": "test_UUID文字列"
  }
]
```

### テストモードの影響

| 機能 | 通常モード | テストモード (`-resetForTesting`) |
|------|-----------|--------------------------------|
| メニューバー表示 | キーバインド設定済みのみ表示 | 全ショートカット表示 |
| 設定ウィンドウ | 変化なし | 変化なし |
| UserDefaults | 通常動作 | 起動時にリセット |

---

## Testing

### ユニットテスト (Swift Testing)

テストフレームワーク: `@Test`, `#expect` (Swift Testing)
テスト用 UserDefaults: テストごとに一意の `suiteName` で隔離

#### AppShortcutTests (7 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `initWithDefaults` | デフォルト初期化で正しいプロパティが設定される |
| `initWithCustomShortcutName` | カスタム shortcutName が保持される |
| `initWithNilBundleIdentifier` | nil の bundleIdentifier が許容される |
| `codableRoundTrip` | 単一ショートカットの JSON エンコード/デコードが正確 |
| `codableRoundTripArray` | 配列の JSON エンコード/デコードが正確 |
| `hashableConformance` | 同一 ID のショートカットが等値かつ同一ハッシュ |
| `uniqueIdsOnCreation` | 新規生成ごとに一意な ID と shortcutName |

#### ShortcutStoreTests (10 tests, serialized)

| テスト名 | 検証内容 |
|---------|---------|
| `addShortcut` | 追加でカウント増加、正しく格納 |
| `removeShortcut` | 削除で配列が空になる |
| `removeShortcutsAtOffsets` | IndexSet による一括削除 |
| `updateShortcut` | 既存ショートカットの更新 |
| `updateNonexistentShortcutIsNoop` | 存在しない ID の更新は無操作 |
| `persistenceAcrossInstances` | ストア再生成後もデータが復元される |
| `emptyStoreOnFreshDefaults` | 新規 UserDefaults で空のストア |
| `containsAppByPath` | パスによる重複検出 |
| `containsAppByBundleIdentifier` | バンドル ID による重複検出 |
| `containsAppByBundleIdentifierWithNilBundleIDs` | nil バンドル ID が誤マッチしない |

### UI テスト (XCTest)

テストフレームワーク: XCTest / XCUITest

#### テストヘルパー

| メソッド | 説明 |
|---------|------|
| `resilientLaunch()` | `continueAfterFailure = true` で起動し、ゾンビプロセスのエラーを許容 |
| `launchClean()` | `-resetForTesting` フラグで起動 |
| `launchWithSeededShortcuts(_:)` | シードデータ付き + テストモードで起動 |
| `launchWithSeededShortcutsNoTestMode(_:)` | シードデータ付き + 通常モード (`-seedOnly`) で起動 |
| `makeSeedShortcut(name:bundleID:appPath:)` | シード用辞書を生成 |
| `openMenu()` | ステータスバーアイテムをクリックしてメニューを取得 |
| `openSettings()` | メニュー経由で設定ウィンドウを開く |

#### Menu Bar Tests (4 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testMenuBarItemExists` | メニューバーにステータスアイテムが表示される |
| `testEmptyStateMenuContents` | 空状態で "No shortcuts configured"、Settings、Quit が表示 |
| `testSeededShortcutAppearsInMenu` | シードしたショートカットがメニューに表示 (テストモード) |
| `testMultipleSeededShortcutsAppearInMenu` | 複数ショートカットがメニューに表示 |

#### Settings Window Tests (6 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testSettingsWindowOpens` | 設定ウィンドウが開く |
| `testSettingsShowsEmptyStateMessage` | 空状態のプレースホルダーテキスト表示 |
| `testSettingsShowsSeededShortcut` | シードデータがリストに表示 |
| `testSettingsSelectShortcutShowsEditView` | 選択で編集ビューの各フィールド (Name, Application, Bundle ID, Shortcut) が表示 |
| `testSettingsDeleteShortcut` | 削除ボタンでショートカットが除去され、プレースホルダーに戻る |
| `testSettingsAddButtonExists` | +/- ボタンの存在と初期状態 |

#### Display Tests (4 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testMenuItemWithIconExists` | メニューアイテムがアイコン付きで存在 |
| `testSettingsSidebarShowsAppIcon` | サイドバーにアプリアイコン画像が表示 |
| `testMenuHidesItemsWithoutShortcuts` | 通常モードでキーバインド未設定のアプリが非表示 |
| `testSettingsSidebarWidthConsistency` | サイドバー幅が選択状態に関わらず一定 (誤差 2pt 以内) |

#### App Launch Tests (1 test)

| テスト名 | 検証内容 |
|---------|---------|
| `testMenuLaunchesApp` | メニュークリックで対象アプリ (TextEdit) が起動する |

#### Launch Tests (1 test)

| テスト名 | 検証内容 |
|---------|---------|
| `testLaunch` | アプリが起動しスクリーンショットをキャプチャ |

### テスト数サマリー

| カテゴリ | テスト数 |
|---------|---------|
| Unit: AppShortcutTests | 7 |
| Unit: ShortcutStoreTests | 10 |
| UI: Menu Bar | 4 |
| UI: Settings Window | 6 |
| UI: Display | 4 |
| UI: App Launch | 1 |
| UI: Launch | 1 |
| **合計** | **33** |

---

## CI/CD

### GitHub Actions Workflow

**ファイル**: `.github/workflows/test.yml`
**トリガー**: `push` (全ブランチ、フィルタなし)

| ジョブ | ランナー | 対象 | continue-on-error |
|--------|---------|------|-------------------|
| Unit Tests | `macos-15` | `KeypunchTests` | `false` |
| UI Tests | `macos-15` | `KeypunchUITests` | `true` |

**Actions**: `actions/checkout` は pinact により commit hash にピン留め。

**注意**: UI Tests は `continue-on-error: true` で実行。macOS CI 環境での安定性が完全には保証されないため、UI テストの失敗はワークフロー全体の失敗にはしない。

---

## Security

### App Sandbox

| エンタイトルメント | 値 | 用途 |
|-----------------|-----|------|
| `com.apple.security.app-sandbox` | `true` | サンドボックス有効 |
| `com.apple.security.files.user-selected.read-only` | `true` | NSOpenPanel でのアプリ選択 |

### KeyboardShortcuts ライブラリ

- Accessibility (アクセシビリティ) 権限が必要
- グローバルホットキー登録のため、ユーザーにシステム環境設定でのアクセシビリティ許可を求める

---

## Dependencies

| パッケージ | バージョン | 用途 |
|-----------|----------|------|
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 2.4.0 (>=2.2.2) | グローバルキーボードショートカットの登録・管理 |

---

## Known Limitations

1. **MenuBarExtra のアイコン**: `Image(nsImage:)` で設定したアイコンは XCUITest のアクセシビリティツリーで子要素として取得できない。メニューアイテム自体の存在のみテスト可能。
2. **ゾンビプロセス**: Xcode デバッグセッション後にゾンビプロセスが残ると、XCUITest の tearDown で termination エラーが発生する。`resilientLaunch()` で緩和しているが、根本解決には Xcode の停止が必要。
3. **ショートカットの表示**: メニューバーのショートカットキー表示は `KeyboardShortcuts.getShortcut(for:)?.description` による文字列であり、ネイティブの `keyboardShortcut` modifier とは異なる。

## License

MIT
