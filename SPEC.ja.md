# Keypunch — 仕様書

> English version: [SPEC.md](./SPEC.md)

## Overview

Keypunch は macOS のメニューバーアプリケーションで、グローバルキーボードショートカットを登録してアプリケーションを起動する。Dock アイコンは表示せず、メニューバーアイコンと標準の設定ウィンドウからすべての操作を行う。

## System Requirements

| 項目 | 要件 |
|------|------|
| OS | macOS 15.5+ |
| Xcode | 16+ |
| Swift | 5.0 |

## Architecture

### Tech Stack

| レイヤー | 技術 |
|---------|------|
| UI フレームワーク | SwiftUI (標準 `NSWindow`) |
| ウィンドウ管理 | `NSWindow` (titled, closable, miniaturizable) |
| グローバルホットキー | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) v2.4.0 |
| ショートカット録画 | カスタム `ShortcutCaptureView` (プレーン `NSView`) |
| 状態管理 | `@Observable` (Swift Observation) |
| データ永続化 | UserDefaults (JSON エンコード) |
| アプリ起動 | NSWorkspace (`AppLaunching` プロトコル経由) |
| ログインアイテム | SMAppService (`LoginItemManaging` プロトコル経由) |
| ショートカット登録 | KeyboardShortcuts (`ShortcutRegistering` プロトコル経由) |

### App Configuration

| 項目 | 値 |
|------|-----|
| Bundle Identifier | `com.mkusaka.Keypunch` |
| LSUIElement | `YES` (Dock 非表示) |
| メニューバーアイコン | SF Symbols `keyboard` |

### ファイル構成

```
Keypunch/
├── KeypunchApp.swift                # エントリポイント、AppDelegate、テストモード制御
├── FloatingWidgetController.swift   # メニューバー、標準 NSWindow 管理
├── Models/
│   └── AppShortcut.swift            # ショートカットデータモデル
├── ShortcutStore.swift              # 状態管理・永続化 (サービスに委譲)
├── Protocols/
│   ├── AppLaunching.swift           # NSWorkspace 抽象化 (アプリ起動)
│   ├── BundleProviding.swift        # Bundle.main 抽象化
│   ├── LoginItemManaging.swift      # SMAppService 抽象化
│   └── ShortcutRegistering.swift    # KeyboardShortcuts 静的 API 抽象化
├── Services/
│   ├── AppLaunchService.swift       # アプリ起動 + 自己アクティベーションロジック
│   ├── LoginItemService.swift       # ログインアイテムトグルロジック
│   └── ShortcutRegistrationService.swift  # ショートカット登録/解除/リセット
├── Views/
│   ├── FloatingPanelView.swift      # 設定パネル (SettingsPanelView)
│   ├── EditCardView.swift           # 行内編集モードカード
│   ├── EditCardBadges.swift         # SetBadgeButton, NotSetBadgeButton, EditShortcutButton
│   ├── CardActionButton.swift       # 共通アクションボタン (解除・削除・キャンセル)
│   ├── CompactRowView.swift         # 非編集モードのコンパクト行
│   ├── EditPencilButton.swift       # ペンシル編集ボタンコンポーネント
│   ├── RecordingBadgeView.swift     # 録画モードバッジ (ShortcutCaptureView 内包)
│   ├── DeleteConfirmationDialog.swift  # 削除確認オーバーレイ
│   ├── DuplicateAlertDialog.swift   # 重複アプリ警告オーバーレイ
│   ├── AddAppButtonView.swift       # NSOpenPanel 付き Add App ボタン
│   ├── PanelFocus.swift             # フォーカス管理用 PanelFocus enum
│   └── ShortcutCaptureView.swift    # キーボードショートカットキャプチャ用 NSView
└── Keypunch.entitlements            # (空 — サンドボックスなし)

KeypunchTests/
└── KeypunchTests.swift              # ユニットテスト (Swift Testing)

KeypunchUITests/
├── KeypunchUITests.swift            # UI テスト (XCTest)
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
| `name` | `String` | — | 表示名 (アプリファイル名から取得) |
| `bundleIdentifier` | `String?` | — | macOS バンドル ID (例: `com.apple.calculator`) |
| `appPath` | `String` | — | アプリケーションのフルパス |
| `shortcutName` | `String` | `"appShortcut_\(id)"` | KeyboardShortcuts ライブラリ用の一意名 |
| `isEnabled` | `Bool` | `true` | ショートカットが有効か (無効時もキーバインドは保持) |

**Computed Properties**:

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `keyboardShortcutName` | `KeyboardShortcuts.Name` | ライブラリ連携用の名前オブジェクト |
| `appURL` | `URL` | `appPath` から生成したファイル URL |
| `appDirectory` | `String` | 親ディレクトリパス (例: `/System/Applications`) |

**Codable 互換性**:
- `isEnabled` は `decodeIfPresent` + `true` フォールバックにより、古いデータとの後方互換性を確保。

**制約**:
- `id` は生成時に自動採番され、一意性が保証される
- `shortcutName` も `id` ベースで自動生成され、一意性が保証される
- `bundleIdentifier` は `nil` を許容する (バンドル ID を持たないアプリに対応)

---

## State Management

### ShortcutStore

アプリケーション全体のショートカット管理を担う `@Observable` クラス。テスタビリティのためプロトコル抽象化による DI を使用。

```swift
@MainActor
@Observable
final class ShortcutStore
```

**依存関係** (init でデフォルト付きで注入):
- `defaults: UserDefaults` — 永続化ストア
- `workspace: AppLaunching` — アプリ起動 (デフォルト: `NSWorkspace.shared`)
- `registrar: ShortcutRegistering` — ショートカット登録 (デフォルト: `KeyboardShortcutsRegistrar()`)
- `mainBundle: BundleProviding` — バンドル識別 (デフォルト: `Bundle.main`)

**内部サービス**:
- `AppLaunchService` — アプリ起動と自己アクティベーション検出を処理
- `ShortcutRegistrationService` — ショートカットの登録/解除/リセットを処理

#### 永続化

| 項目 | 値 |
|------|-----|
| ストレージ | UserDefaults |
| キー | `"savedAppShortcuts"` |
| フォーマット | JSON (`JSONEncoder` / `JSONDecoder`) |
| 対象データ | `[AppShortcut]` 配列 |
| 初期化時の読み込み | `init()` でデコードして `shortcuts` に設定 |
| データ破損時 | デコード失敗時は空配列を静かに読み込み |

**注意**: キーボードショートカットのキーバインディング自体は KeyboardShortcuts ライブラリが独自に UserDefaults へ永続化する。ShortcutStore が保存するのはアプリメタデータのみ。

#### 公開プロパティ

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `shortcuts` | `[AppShortcut]` | 全登録ショートカット (読み取り専用) |
| `shortcutKeysVersion` | `Int` | キーバインド変更時にインクリメント、SwiftUI の強制リフレッシュに使用 |

#### 公開メソッド

| メソッド | 説明 |
|---------|------|
| `addShortcut(_:)` | ショートカットを追加し、ハンドラ登録・永続化を実行 |
| `removeShortcut(_:)` | ショートカットを削除し、キーバインディングをリセット・永続化 |
| `removeShortcuts(at:)` | `IndexSet` で指定された複数ショートカットを一括削除 |
| `updateShortcut(_:)` | ID で一致するショートカットを更新。`shortcutName` 変更時は旧バインディングをリセット |
| `toggleEnabled(for:)` | `isEnabled` 状態をトグル。無効化時はハンドラを空にするがキーバインドは保持 |
| `unsetShortcut(for:)` | `KeyboardShortcuts.reset()` でキーバインドをリセット。アプリエントリは残る。`shortcutKeysVersion` をインクリメント |
| `containsApp(path:)` | 指定パスのアプリが登録済みか判定 |
| `containsApp(bundleIdentifier:)` | 指定バンドル ID のアプリが登録済みか判定 |
| `isShortcutConflicting(_:excluding:)` | ショートカットキーの組み合わせが他の登録済みショートカットと競合するか判定 |
| `addShortcutFromURL(_:)` | URL からアプリを追加 (重複検出付き)。`.success(AppShortcut)` または `.duplicate(String)` を返す |
| `launchApp(for:)` | 対象アプリを起動 |

#### アプリ起動ロジック

`launchApp(for:)` は以下の優先順位でアプリを解決する:

1. `bundleIdentifier` が非 nil かつ `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` で解決可能 → そのURLで起動
2. フォールバック: `appPath` を URL に変換して起動

いずれも `NSWorkspace.shared.openApplication(at:configuration:)` を使用。

#### ハンドラ登録

- `registerHandler(for:)` は `isEnabled` をチェックしてからコールバックを設定
- 無効化時は空のハンドラを登録 (キーバインドは保持)
- `init()` 時に全ショートカットのハンドラを一括登録
- `shortcutKeysVersion` は `KeyboardShortcuts_shortcutByNameDidChange` 通知の監視によりインクリメント

---

## UI Components

### 1. メニューバー (ステータスアイテム)

アプリ操作の主要エントリポイント。`NSStatusItem` (キーボードアイコン)。

**メニュー項目**:
- "Show Keypunch" → 設定ウィンドウを表示
- セパレーター
- "Start at Login" → ログインアイテムをトグル (有効時にチェックマーク、`NSMenuDelegate` 経由)
- セパレーター
- "Quit" (⌘Q) → アプリを終了

### 2. 設定ウィンドウ

ショートカット設定を管理する標準の macOS `NSWindow`。

**サイズ**: 380 × 616 pt
**スタイル**: `.titled`, `.closable`, `.miniaturizable` (標準の信号機ボタン)
**タイトル**: "Keypunch"
**アクセシビリティ ID**: `keypunch-panel`

#### パネル構成

```
┌──────────────────────────────────────┐
│ ● ● ●  Keypunch                      │  ← 標準タイトルバー
│──────────────────────────────────────│
│ [icon] Calculator      ⌘⇧C    [✎]  │  ← コンパクト行 (LaunchRow)
│        /System/Applications          │
│ [icon] TextEdit        Not set [✎]  │
│        /System/Applications          │
│                                      │
│         [+ Add App]                  │  ← 追加ボタン
└──────────────────────────────────────┘
```

#### コンパクト行 (LaunchRow)

登録された各アプリがコンパクトな行として表示される。

| 要素 | サイズ | 説明 |
|------|------|------|
| アプリアイコン | 28×28 | `NSWorkspace.shared.icon(forFile:)`、角丸 (7pt) |
| アプリ名 | — | 13pt、ミディアム。ホバー時セミボールド |
| アプリディレクトリ | — | 10pt、セカンダリカラー、中間省略 |
| ショートカットバッジ | — | 3状態表示 (下記参照) |
| 編集ボタン | 22×22 | ペンシルアイコン、行内編集モードを開く |

**ショートカットバッジ (3状態)**:

| 状態 | 表示 | バッジ色 |
|------|------|---------|
| 設定済み & 有効 | キーコンボ (例: `⌘⇧C`) | アクセントカラー、背景アクセント @ 15% |
| 無効化 | キーコンボ (取消線付き) | セカンダリカラー |
| 未設定 | "Not set" テキスト | ターシャリカラー |

**ホバーエフェクト**: 行の背景がアクセント系 @ 8% に変化、ボーダーアクセント @ 20%。

**クリック**: `store.launchApp(for:)` で対象アプリを起動。

**編集ボタン**: `accessibilityIdentifier("edit-shortcut")`。0.15秒のアニメーションで該当行の EditCard に遷移。

#### 編集カード (行内編集モード)

ペンシルボタンをクリックすると、コンパクト行が編集カードに展開される。コンパクト行と同じ寸法で統一し、行の高さが一定に保たれる。

| 要素 | サイズ | 説明 |
|------|------|------|
| アプリアイコン | 28×28 | 角丸 (7pt) |
| アプリ名 | — | 13pt、セミボールド |
| アプリディレクトリ | — | 10pt、セカンダリカラー |
| ショートカットバッジエリア | 高さ 22, r6 | 3状態: 未設定、録画中、設定済み |
| ショートカット解除 (↺) | 22×22, r6 | キーバインドをリセット (ショートカット設定時のみ表示) |
| アプリ削除 (🗑) | 22×22, r6 | 削除確認オーバーレイを表示 |
| キャンセルボタン (X) | 22×22, r6 | 編集モードを終了 |

**行パディング**: 水平 10、垂直 8。角丸: 12。

**ボタン配置**: `[icon] [name] [badge] [✎] [↺] [🗑] [×]` — 全アクションボタンがインラインに配置、ドロップダウン/ポップオーバーなし。編集ボタン (✎) はバッジと解除ボタンの間の独立ボタン。

**ショートカットバッジエリア (3状態)**:

1. **未設定**: "Not set" テキスト + ペンシルアイコン。クリックで録画開始。`accessibilityIdentifier("not-set-badge")`
2. **録画中**: アンバードット (`#FFB547`) + "Record" テキスト + X キャンセル。背景 `#FFB547` @ 12.5%、ボーダー `#FFB547` @ 25%。カスタム `ShortcutCaptureView` がキーボード入力をキャプチャ。
3. **設定済み**: キーコンボテキスト — トグル専用 (クリック/Enter で有効/無効を切替)。ペンシルアイコンは内包しない。`accessibilityIdentifier("shortcut-badge")`

**編集ボタン (独立)**: `accessibilityIdentifier("record-shortcut")`。バッジと解除ボタンの間のペンシルアイコン。ショートカット設定済みかつ録画中でない場合のみ表示。クリック/Enter で再録画開始。

**Tab ループ (編集モード)**: Tab と Shift+Tab は `onKeyPress` で編集カード内に閉じ込められる。カード要素間でフォーカスがループし、他の行や Add App ボタンには漏れない。フォーカス順: `shortcutBadge` → `shortcutEditButton` (✎、ショートカット設定時) → `dangerButton` (↺、ショートカット設定時) → `deleteButton` (🗑) → `cancelEdit` (×) → `shortcutBadge` に戻る。

**編集キャンセル**: `accessibilityIdentifier("cancel-edit")`。コンパクト行に戻る。

**ショートカット解除**: `accessibilityIdentifier("unset-shortcut")`。キーバインドが設定済みの場合のみ表示。キーバインドをリセットし、アプリエントリは保持。

**アプリ削除**: `accessibilityIdentifier("delete-app")`。削除確認オーバーレイを表示。

#### 削除確認オーバーレイ

パネル内のモーダルオーバーレイ:
- 赤い円内のゴミ箱アイコン
- 「Remove [アプリ名]?」タイトル
- 取り消し不可の警告テキスト
- Cancel と Remove ボタン
- Remove ボタン: `.borderedProminent` スタイル + デストラクティブティント
- デフォルトフォーカスなし — 表示時にどのボタンにも自動フォーカスしない

#### 重複アプリケーションダイアログ

既に登録済みのアプリを追加しようとした際に表示されるモーダルオーバーレイ (削除確認と同じスタイル):
- オレンジ色の円内に警告三角アイコン
- "Duplicate Application" タイトル
- "[名前] has already been added." メッセージ
- OK ボタン (`.borderedProminent` スタイル) で閉じる
- 表示中は背景操作を無効化
- Esc キーでもダイアログを閉じる

#### アプリ追加ボタン

- ラベル: "+ Add App"
- スタイル: 幅いっぱいのボタン (破線ボーダー)
- `.contentShape(Rectangle())` で全域ヒット可能
- `NSOpenPanel` を開く (`.application` フィルター)
- パスとバンドル ID による重複検出
- 重複時に重複ダイアログを表示

---

## キーボードナビゲーション

標準設定ウィンドウ内でキーボードナビゲーションをサポート。

### 設定ウィンドウ (SettingsPanelView)

**フォーカス管理**: `@FocusState` と `PanelFocus` enum で全 UI 要素のフォーカスを制御。

**フォーカスターゲット** (PanelFocus enum):

| ケース | 説明 |
|--------|------|
| `.row(UUID)` | コンパクト行 — Enter でアプリ起動 |
| `.editButton(UUID)` | コンパクト行の編集 (ペンシル) ボタン — Enter で編集モードへ |
| `.addApp` | Add App ボタン — Enter でファイルダイアログを開く |
| `.shortcutBadge(UUID)` | 編集モードのショートカットバッジ — Enter で有効/無効をトグル (設定済み時) または録画開始 (未設定時) |
| `.shortcutEditButton(UUID)` | 独立ペンシルボタン — Enter で再録画開始 (ショートカット設定済み時のみ表示) |
| `.cancelEdit(UUID)` | 編集モードのキャンセル (×) ボタン — Enter で編集終了 |
| `.dangerButton(UUID)` | 編集モードの解除 (↺) ボタン — Enter でショートカット解除 |
| `.deleteButton(UUID)` | 編集モードの削除 (🗑) ボタン — Enter で削除ダイアログ表示 |

**Tab 順序** (非編集モード): Tab/Shift+Tab で全フォーカス可能要素を巡回する。`.row(app1)` → `.editButton(app1)` → `.row(app2)` → `.editButton(app2)` → … → `.addApp` → `.row(app1)` に戻る。

**Tab 順序** (編集モード): Tab/Shift+Tab は編集カード内でループする。`shortcutBadge` → `shortcutEditButton` (✎、ショートカット設定時) → `dangerButton` (↺、ショートカット設定時) → `deleteButton` (🗑) → `cancelEdit` (×) → `shortcutBadge` に戻る。編集モード中はフォーカスが他の行や Add App ボタンに漏れない。

**矢印キーナビゲーション (上下)**: 上下矢印でアプリ行間のみを移動 (編集ボタンをスキップ、ラップ)。編集モード中は無効。

**矢印キーナビゲーション (左右)**: 非編集モードでは、右矢印で `.row(id)` → `.editButton(id)`、左矢印で `.editButton(id)` → `.row(id)` に移動。境界では何もしない。編集モードでは、左右矢印で編集カード内の要素を巡回 (Tab ループと同じ順序、ラップ)。

**Esc ハンドリング** (階層的 `.onExitCommand`):
1. 重複ダイアログ表示中 → 閉じる
2. 削除確認表示中 → 閉じて、削除ボタンにフォーカス
3. ショートカット録画中 → 録画キャンセル
4. 編集モード中 → 編集終了、コンパクト行にフォーカス

**ダイアログ動作**:
- 削除確認・重複ダイアログ表示中は、背景のパネルコンテンツが `.disabled(true)` となり Tab フォーカスの漏れを防止
- 削除ダイアログのキャンセル → 編集カードの削除ボタンにフォーカスが戻る
- 削除ダイアログでの Esc → キャンセルと同じ動作

---

## ウィンドウ管理

### FloatingWidgetController

メニューバーと設定ウィンドウを管理する `@MainActor` コントローラー。

#### コンポーネント

| コンポーネント | クラス | サイズ | 用途 |
|-------------|--------|------|------|
| 設定ウィンドウ | `NSWindow` | 380×616 | ショートカット設定のメインウィンドウ |
| ステータスアイテム | `NSStatusItem` | 正方形 | ドロップダウンメニュー付きメニューバーアイコン |

#### 表示/非表示ロジック

| イベント | 動作 |
|---------|------|
| "Show Keypunch" クリック | `makeKeyAndOrderFront` + `NSApp.activate()` |
| ウィンドウ閉じるボタン | 標準のウィンドウ閉じ動作 (`isReleasedWhenClosed = false`) |
| アプリ再開 (Dock クリック) | 設定ウィンドウを表示 |
| テストモード起動 | 設定ウィンドウを自動表示 |

---

## キーボードショートカット録画

### ShortcutCaptureView

`NSSearchField` ベースではなくプレーンな `NSView` サブクラス。フローティングパネルでの ViewBridge 切断エラーを回避。

**動作**:
1. `window.makeFirstResponder(view)` でビューがファーストレスポンダーになる
2. ユーザーがモディファイア + キーを押す → `KeyboardShortcuts.setShortcut()` を呼び出し
3. Escape → 録画をキャンセル
4. ファーストレスポンダー解除 → 録画をキャンセル

**競合検出**: ショートカット設定後、`store.isShortcutConflicting()` で他の登録済みショートカットとの競合を確認。競合検出時はショートカットをリセット。

---

## アプリケーションライフサイクル

### KeypunchApp (エントリポイント)

```swift
@main struct KeypunchApp: App
```

- `ShortcutStore` を生成し、静的プロパティで共有
- `AppDelegate.applicationDidFinishLaunching` で `FloatingWidgetController` を生成
- ガード: `XCTestCase` 下ではコントローラーのセットアップをスキップ
- `applicationShouldHandleReopen` で表示ウィンドウがない場合に設定ウィンドウを表示

### ログインアイテムサポート

- `SMAppService.mainApp` を `LoginItemManaging` プロトコルと `LoginItemService` 経由でログインアイテムの登録/解除
- メニューバーの "Start at Login" でトグル
- 有効時にチェックマーク表示 (`NSMenuDelegate.menuNeedsUpdate` 経由)

---

## Test Mode

CI やテスト実行時にアプリの動作を制御するための仕組み。

### コマンドライン引数

| 引数 | UserDefaults リセット | シードデータ適用 | ウィンドウ自動表示 |
|------|---------------------|-----------------|------------------|
| `-resetForTesting` | Yes | Yes (環境変数があれば) | Yes |
| `-seedOnly` | Yes | Yes (環境変数があれば) | No |
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
| ウィンドウ表示 | メニューバーから手動 | 起動時に自動表示 |
| パネル表示 | 全ショートカット表示 | 全ショートカット表示 |
| UserDefaults | 通常動作 | 起動時にリセット |

---

## Testing

### ユニットテスト (Swift Testing)

テストフレームワーク: `@Test`, `#expect` (Swift Testing)
テスト用 UserDefaults: テストごとに一意の `suiteName` で隔離

#### AppShortcutTests (12 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `initWithDefaults` | デフォルト初期化で正しいプロパティが設定される |
| `initWithCustomShortcutName` | カスタム shortcutName が保持される |
| `initWithNilBundleIdentifier` | nil の bundleIdentifier が許容される |
| `isEnabledDefaultsToTrue` | isEnabled のデフォルトが true |
| `isEnabledCanBeSetToFalse` | isEnabled を false に設定可能 |
| `codableRoundTrip` | 単一ショートカットの JSON エンコード/デコードが正確 |
| `codableBackwardCompatibility` | isEnabled なしの古い JSON がデフォルト true |
| `codableRoundTripArray` | 配列の JSON エンコード/デコードが正確 |
| `hashableConformance` | 同一 ID のショートカットが等値かつ同一ハッシュ |
| `uniqueIdsOnCreation` | 新規生成ごとに一意な ID と shortcutName |
| `appDirectoryComputed` | appDirectory が親ディレクトリパスを返す |
| `appDirectoryForNestedPath` | 深いネストのパスでも appDirectory が動作 |

#### ShortcutStoreTests (19 tests, serialized)

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
| `toggleEnabled` | isEnabled トグルと再トグル |
| `toggleEnabledPersists` | トグル状態がストアインスタンス間で永続化 |
| `unsetShortcutKeepsAppEntry` | ショートカット解除後もアプリエントリが残る |
| `unsetShortcutIncrementsVersion` | 解除後に shortcutKeysVersion がインクリメント |
| `containsAppByBundleIdentifierWithNilBundleIDs` | nil バンドル ID が誤マッチしない |
| `addShortcutFromURLSuccess` | 有効な URL からの追加で名前・パス・バンドル ID を抽出 |
| `addShortcutFromURLDuplicateByPath` | URL 経由でのパスによる重複検出 |
| `addShortcutFromURLDuplicateByBundleID` | URL 経由でのバンドル ID による重複検出 |
| `corruptDataLoadsEmpty` | 破損した UserDefaults データで空のストアが生成される |
| `toggleEnabledNonexistentIsNoop` | 存在しないショートカットのトグルは無操作 |

#### ShortcutStoreBehaviorTests (10 tests, serialized)

`AppLaunching`, `ShortcutRegistering`, `BundleProviding` プロトコルのモック実装を使用。

| テスト名 | 検証内容 |
|---------|---------|
| `launchAppResolvesByBundleID` | バンドル ID 利用可能時にバンドル ID でアプリを解決 |
| `launchAppFallsBackToAppPath` | バンドル ID 解決不可時に appPath にフォールバック |
| `launchAppFallsBackWhenNoBundleID` | bundleIdentifier が nil の時に appPath にフォールバック |
| `launchAppSelfActivation` | 自身のバンドルを起動時に自己アクティベーションコールバックが発火 |
| `removeShortcutResetsBinding` | ショートカット削除時にレジストラの reset を呼び出し |
| `toggleDisabledRegistersNoopHandler` | 無効化時に空ハンドラを登録 (バインドは保持) |
| `conflictDetectionFindsConflict` | 異なる名前間でのショートカット競合を検出 |
| `conflictDetectionNoConflictWhenExcluded` | 同一名前を除外した場合に競合なし |
| `conflictDetectionNoConflictWhenDifferent` | 異なるキーの組み合わせで競合なし |
| `unsetShortcutCallsReset` | ショートカット解除時にレジストラの reset を呼び出し |

### UI テスト (XCTest)

テストフレームワーク: XCTest / XCUITest

#### テストヘルパー (KeypunchPage)

| メソッド | 説明 |
|---------|------|
| `launchClean()` | `-resetForTesting` フラグで起動 |
| `launchWithSeededShortcuts(_:)` | シードデータ付き + テストモードで起動 |
| `launchWithSeededShortcutsNoTestMode(_:)` | シードデータ付き + 通常モード (`-seedOnly`) で起動 |
| `makeSeedShortcut(name:bundleID:appPath:)` | シード用辞書を生成 |
| `waitForWindow()` | 設定ウィンドウ (`keypunch-panel`) の表示を待機 |
| `openEditMode()` | ウィンドウを待機し、最初の行の編集ボタンをクリック |
| `clickRecordShortcut()` | record-shortcut または not-set-badge 要素を検索しクリック |

#### ウィンドウテスト (1 test)

| テスト名 | 検証内容 |
|---------|---------|
| `testWindowAppearsInTestMode` | テストモードで設定ウィンドウが自動表示される |

#### パネルコンテンツテスト (5 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testEmptyStatePanelContents` | 空状態で "No shortcuts configured" 表示 |
| `testSeededShortcutAppearsInPanel` | シードしたショートカットがパネルに表示 |
| `testMultipleSeededShortcutsAppearInPanel` | 複数ショートカットが表示 |
| `testPanelShowsAppIconAndBadge` | アプリアイコンと "Not set" バッジが表示 |
| `testPanelShowsAddAppButton` | "Add App" ボタンが存在 |

#### 編集モードテスト (5 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testEditButtonExistsOnRow` | 編集 (ペンシル) ボタンがショートカット行に存在 |
| `testEditModeShowsSeededShortcut` | 編集モードでショートカットが表示 |
| `testEditModeShowsAppDirectoryAndBadge` | 編集カードにアプリディレクトリパスと "Not set" バッジ |
| `testDeleteButtonExistsInEditMode` | 編集モードに削除ボタンが存在 |
| `testCancelEditExitsEditMode` | 編集キャンセルでコンパクトモードに戻る |

#### コンパクト行テスト (2 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testCompactRowShowsAppDirectory` | コンパクト行にアプリディレクトリパスが表示 |
| `testMultipleShortcutsShowSeparateEditButtons` | 各行にそれぞれの編集ボタンがある |

#### 編集モード排他制御テスト (2 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testEditModeIsExclusive` | 編集モードは同時に1行のみ |
| `testEditModeSwitchCancelsRecording` | 別の行への編集モード切替で録画がキャンセルされる |

#### アプリ起動テスト (2 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testPanelLaunchesApp` | アプリ名クリックで TextEdit が起動する |
| `testEditButtonClickEntersEditMode` | 編集ボタンクリックで編集モードに入る |

#### 削除確認テスト (3 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testDeleteConfirmationModalAppears` | 削除確認で "Remove Calculator?" が表示 |
| `testDeleteConfirmationCancelKeepsShortcut` | キャンセルでショートカットエントリが保持 |
| `testDeleteConfirmationRemoveDeletesShortcut` | 削除でショートカットが消え空状態表示 |

#### 録画モードテスト (2 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testRecordingModeShowsRecordBadge` | 録画時に "Record" バッジが表示 |
| `testRecordingCancelButtonExitsRecording` | キャンセルで録画終了、"Not set" に戻る |

#### Add App テスト (3 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testAddAppButtonOpensFileDialog` | "Add App" クリックで NSOpenPanel ファイルダイアログが開く |
| `testAddAppViaOpenPanel` | オープンパネル経由でアプリ追加すると新しい行が作成 |
| `testAddDuplicateAppShowsAlert` | 重複アプリ追加で重複アラートが表示 |

#### ショートカット録画 E2E テスト (2 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testRecordShortcutSetsKey` | ショートカット録画でキーバインドが設定される |
| `testRecordShortcutThenUnset` | 録画後に解除でキーバインドがクリアされる |

#### デンジャーゾーンテスト (2 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testUnsetButtonNotShownWhenNoShortcutSet` | ショートカット未設定時に解除ボタン非表示 |
| `testUnsetShortcutPreservesEditMode` | ショートカット解除後も編集モードが維持される |

#### Esc 動作テスト (4 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testKeyboardEscExitsEditModeBeforeDismissing` | 最初の Esc で編集モード終了、ウィンドウは残る |
| `testKeyboardEscDismissesDeleteConfirmation` | Esc で削除確認ダイアログが閉じ、ウィンドウは残る |
| `testEscDuringRecordingStaysInEditMode` | 録画中の Esc で録画キャンセル、編集モードは維持 |
| `testEscFromRemoveDialogKeepsEditMode` | 削除ダイアログからの Esc で編集モードが維持 |

#### キーボードナビゲーション: Tab (3 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testKeyboardTabNavigatesBetweenRows` | Tab で row → editButton → 次の row と移動し Enter でアプリ起動 |
| `testTabStopsOnEditButtonBetweenRows` | Tab が row の後に editButton で停止し Enter で編集モードに入る |
| `testKeyboardShiftTabNavigatesBackward` | Shift-Tab で前の行に戻り Enter で1番目のアプリ起動 |

#### キーボードナビゲーション: 矢印キー (9 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testDownArrowNavigatesBetweenApps` | 下矢印でアプリ行間を移動 |
| `testUpArrowNavigatesBetweenApps` | 上矢印でアプリ行間を移動 |
| `testDownArrowWrapsToAddApp` | 下矢印で最終行から Add App にラップ |
| `testUpArrowWrapsFromFirstToAddApp` | 上矢印で最初の行から Add App にラップ |
| `testRightArrowMovesToEditButton` | 右矢印で row から editButton に移動 |
| `testLeftArrowMovesBackToRow` | 左矢印で editButton から row に戻る |
| `testRightArrowNoOpOnEditButton` | editButton で右矢印は何もしない |
| `testLeftArrowNoOpOnRow` | row で左矢印は何もしない |
| `testUpDownArrowDisabledInEditMode` | 編集モード中は上下矢印が無効 |

#### Tab ナビゲーション: 編集モード (12 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testTabOrderEditModeNoShortcutToCancelEdit` | 未設定時の Tab でバッジ → 削除 → キャンセル |
| `testTabOrderEditModeNoShortcutToDeleteButton` | 未設定時の Tab でバッジ → 削除ボタン |
| `testTabOrderEditModeWithShortcutToCancelEdit` | 設定済み時の Tab でキャンセルボタンまで到達 |
| `testTabOrderEditModeWithShortcutToUnsetButton` | 設定済み時の Tab で解除ボタンまで到達 |
| `testShiftTabInEditMode` | Shift+Tab で編集カード内を逆方向に移動 |
| `testFocusRestoredAfterRecordingCancel` | 録画キャンセル後にバッジにフォーカスが戻る |
| `testFocusRestoredAfterRecordingCancelWithTwoApps` | 複数アプリ時の録画キャンセル後にバッジにフォーカス |
| `testTabLoopsWithinEditCard` | Tab がカード内でループし他の行に漏れない |
| `testToggleShortcutEnabledViaKeyboard` | 設定済みバッジで Enter → 有効/無効トグル (録画開始しない) |
| `testShiftTabLoopsWithinEditCardWithTwoApps` | 複数アプリ時の Shift+Tab がカード内でラップ |
| `testEditButtonIsStandaloneWithShortcutSet` | 編集ボタンが独立しており Enter で録画開始 |
| `testTabOrderWithShortcutSet` | 5要素の Tab 順序: バッジ → 編集 → 解除 → 削除 → キャンセル |

#### スクロール & 多数アプリテスト (2 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testManyAppsScrollable` | 多数アプリ追加時にパネルがスクロール |
| `testAutoScrollWithArrowKeys` | 矢印キーナビゲーションでフォーカス行に自動スクロール |

#### 起動テスト (1 test)

| テスト名 | 検証内容 |
|---------|---------|
| `testLaunch` | アプリが起動しスクリーンショットをキャプチャ |

### テスト数サマリー

| カテゴリ | テスト数 |
|---------|---------|
| Unit: AppShortcutTests | 12 |
| Unit: ShortcutStoreTests | 19 |
| Unit: ShortcutStoreBehaviorTests | 10 |
| UI: ウィンドウ | 1 |
| UI: パネルコンテンツ | 5 |
| UI: 編集モード | 5 |
| UI: コンパクト行 | 2 |
| UI: 編集モード排他制御 | 2 |
| UI: アプリ起動 | 2 |
| UI: 削除確認 | 3 |
| UI: 録画モード | 2 |
| UI: Add App | 3 |
| UI: ショートカット録画 E2E | 2 |
| UI: デンジャーゾーン | 2 |
| UI: Esc 動作 | 4 |
| UI: キーボードナビ: Tab | 3 |
| UI: キーボードナビ: 矢印キー | 9 |
| UI: Tab ナビ: 編集モード | 12 |
| UI: スクロール & 多数アプリ | 2 |
| UI: 起動 | 1 |
| **合計** | **101** |

---

## CI/CD

### GitHub Actions Workflow

**ファイル**: `.github/workflows/test.yml`
**トリガー**: `push`、`pull_request`、`workflow_call` (`push` と `pull_request` はパスフィルター付き: `Keypunch/**`, `Keypunch.xcodeproj/**`, `KeypunchTests/**`, `KeypunchUITests/**`, `.github/workflows/test.yml`)

| ジョブ | ランナー | 対象 |
|--------|---------|------|
| Lint | `macos-15` | SwiftFormat + SwiftLint |
| Unit Tests | `macos-15` | `KeypunchTests` |
| UI Tests | `macos-15` | `KeypunchUITests` |

**Actions**: `actions/checkout` は pinact により commit hash にピン留め。
`release.yml` は署名付きリリース job の前にこの workflow を呼び出す。

---

## Dependencies

| パッケージ | バージョン | 用途 |
|-----------|----------|------|
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 2.4.0 (>=2.2.2) | グローバルキーボードショートカットの登録・管理 |

---

## Known Limitations

1. **ViewBridge エラー**: `RecorderCocoa` (NSSearchField サブクラス) がフローティングパネルで ViewBridge 切断エラーを発生させる。カスタム `ShortcutCaptureView` (プレーン NSView) で置き換え済み。
2. **ゾンビプロセス**: Xcode デバッグセッション後にゾンビプロセスが残ると、XCUITest の tearDown で termination エラーが発生する。`resilientLaunch()` で緩和。

## License

MIT
