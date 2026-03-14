# Keypunch — 仕様書

> English version: [SPEC.md](./SPEC.md)

## Overview

Keypunch は macOS のフローティングウィジェットアプリケーションで、グローバルキーボードショートカットを登録してアプリケーションを起動する。Dock アイコンは表示せず、画面端のフローティングトリガーとメニューバーアイコンからすべての操作を行う。

## System Requirements

| 項目 | 要件 |
|------|------|
| OS | macOS 15.0+ |
| Xcode | 16+ |
| Swift | 5.0 |

## Architecture

### Tech Stack

| レイヤー | 技術 |
|---------|------|
| UI フレームワーク | SwiftUI (フローティング `NSPanel`) |
| ウィンドウ管理 | `NSPanel` (borderless, non-activating) |
| グローバルホットキー | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) v2.4.0 |
| ショートカット録画 | カスタム `ShortcutCaptureView` (プレーン `NSView`) |
| 状態管理 | `@Observable` (Swift Observation) |
| データ永続化 | UserDefaults (JSON エンコード) |
| アプリ起動 | NSWorkspace |
| ログインアイテム | SMAppService |

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
├── FloatingWidgetController.swift   # NSPanel 管理、マウストラッキング、ドラッグ
├── Models/
│   └── AppShortcut.swift            # ショートカットデータモデル
├── ShortcutStore.swift              # 状態管理・永続化・アプリ起動
├── Views/
│   ├── FloatingPanelView.swift      # 拡張パネル (コンパクト行、編集カード、削除確認)
│   ├── FloatingTriggerView.swift    # トリガーピル (1つのピルに4つのアイコンボタン)
│   ├── SettingsView.swift           # (レガシー、未使用)
│   └── ShortcutEditView.swift       # (レガシー、未使用)
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

### 1. フローティングトリガー (画面端ピル)

画面端に浮遊する縦長のピル型ウィジェット。4つのアイコンが1つのピル内に常時表示される。

**サイズ**: 48 × 160 pt
**角丸**: 24 pt
**背景色**: `#1A1A1E`
**パネルレベル**: `.floating`
**動作**: `.canJoinAllSpaces`, `.fullScreenAuxiliary`

#### ボタン (4つのアイコン、上から下)

| アイコン | SF Symbol | 動作 | ツールチップ | アクセシビリティ ID |
|---------|-----------|------|------------|-------------------|
| キーボード | `keyboard` | 拡張パネルをトグル | "Toggle Keypunch" | `trigger-button` |
| 非表示 | `eye.slash` | トリガーをフェードアウトして非表示 | "Hide Trigger" | `menu-hide` |
| ログイン | `power` / `power.circle.fill` | ログインアイテムをトグル | "Enable/Disable Start at Login" | `menu-power` |
| 終了 | `rectangle.portrait.and.arrow.right` | アプリを終了 | "Quit App" | `menu-quit` |

#### アイコンホバーエフェクト
- スケール: 1.0 → 1.2 (ホバー時)
- グロー: カラーシャドウ (半径 8, 不透明度 0.3) (ホバー時)
- カラー: アイドル `#6B6B70` (不透明度 0.7) → フルカラー (ホバー時またはアクティブ時)
- 終了アイコンはデンジャーカラー `#E85A4F` を使用
- ツールチップ: 0.5秒遅延後にカスタムツールチップパネルが表示

#### ピルアクティブ状態
- ボーダーストローク: アイドル時 `#FFFFFF` @ 9%、パネルアクティブ時 15%
- グロー: アクティブ時 インディゴ `#6366F1` @ 12%

#### ドラッグ移動
- トリガーと拡張パネルがドラッグ時に連動して移動
- 位置は UserDefaults (`triggerPositionX`, `triggerPositionY`) に永続化
- デフォルト位置: 画面右端、縦方向中央

#### 非表示動作
- 0.3秒アニメーションでフェードアウト後、`orderOut`
- 次回表示用にアルファ値を 1.0 にリセット
- 拡張パネルとツールチップを先に閉じる
- メニューバーの「Show Keypunch」または `applicationShouldHandleReopen` で復帰可能

---

### 2. 拡張パネル (フローティングパネル)

トリガーの隣に表示されるメインの操作パネル。

**サイズ**: 300 × 360 pt
**角丸**: 20 pt
**背景色**: `#16161A`
**パネルレベル**: `.floating`

#### パネル構成

```
┌──────────────────────────────────────┐
│ Keypunch                             │  ← ドラッグハンドル (ヘッダー)
│──────────────────────────────────────│
│ [icon] Calculator      ⌘⇧C    [✎]  │  ← コンパクト行 (LaunchRow)
│        /System/Applications          │
│ [icon] TextEdit        Not set [✎]  │
│        /System/Applications          │
│                                      │
│         [+ Add App]                  │  ← 追加ボタン
└──────────────────────────────────────┘
```

#### ヘッダー
- テキスト: "Keypunch" (15pt, セミボールド, 白)
- パネル再配置のドラッグハンドルとして機能
- ドラッグ時は拡張パネルとトリガーが連動して移動

#### コンパクト行 (LaunchRow)

登録された各アプリがコンパクトな行として表示される。

| 要素 | サイズ | 説明 |
|------|------|------|
| アプリアイコン | 28×28 | `NSWorkspace.shared.icon(forFile:)`、角丸 (7pt) |
| アプリ名 | — | 13pt、ミディアム。ホバー時セミボールド |
| アプリディレクトリ | — | 10pt、`#4A4A50`、中間省略 |
| ショートカットバッジ | — | 3状態表示 (下記参照) |
| 編集ボタン | 22×22 | ペンシルアイコン、行内編集モードを開く |

**ショートカットバッジ (3状態)**:

| 状態 | 表示 | バッジ色 |
|------|------|---------|
| 設定済み & 有効 | キーコンボ (例: `⌘⇧C`) | 青 `#0A84FF`、背景 `#0A84FF` @ 15% |
| 無効化 | キーコンボ (取消線付き) | グレー `#6B6B70` |
| 未設定 | "Not set" テキスト | グレー `#4A4A50` |

**ホバーエフェクト**: 行の背景がブルー系 `#0A84FF` @ 8% に変化、ボーダー `#0A84FF` @ 20%。

**クリック**: `store.launchApp(for:)` で対象アプリを起動。

**編集ボタン**: `accessibilityIdentifier("edit-shortcut")`。0.15秒のアニメーションで該当行の EditCard に遷移。

#### 編集カード (行内編集モード)

ペンシルボタンをクリックすると、コンパクト行が編集カードに展開される。コンパクト行と同じ寸法で統一し、行の高さが一定に保たれる。

| 要素 | サイズ | 説明 |
|------|------|------|
| アプリアイコン | 28×28 | 角丸 (7pt) |
| アプリ名 | — | 13pt、セミボールド |
| アプリディレクトリ | — | 10pt、`#4A4A50` |
| ショートカットバッジエリア | 高さ 22, r6 | 3状態: 未設定、録画中、設定済み |
| キャンセルボタン (X) | 22×22, r6 | 編集モードを終了 |
| デンジャートリガー (!) | 22×22, r6 | アクションドロップダウンを開く |

**行パディング**: 水平 10、垂直 8。角丸: 12。

**ショートカットバッジエリア (3状態)**:

1. **未設定**: "Not set" テキスト + ペンシルアイコンボタン。ペンシルをクリックで録画開始。
2. **録画中**: アンバードット (`#FFB547`) + "Record" テキスト + X キャンセル。背景 `#FFB547` @ 12.5%、ボーダー `#FFB547` @ 25%。カスタム `ShortcutCaptureView` がキーボード入力をキャプチャ。
3. **設定済み**: キーコンボテキスト (クリックで有効/無効をトグル) + ペンシルアイコン (クリックで再録画)。

**編集キャンセル**: `accessibilityIdentifier("cancel-edit")`。コンパクト行に戻る。

**デンジャートリガー**: `accessibilityIdentifier("danger-trigger")`。ポップオーバーを開く:
- **ショートカット解除** (`accessibilityIdentifier("unset-shortcut")`): キーバインドが設定済みの場合のみ表示。キーバインドをリセットし、アプリエントリは保持。
- **アプリ削除** (`accessibilityIdentifier("delete-app")`): 削除確認オーバーレイを表示。

#### 削除確認オーバーレイ

パネル内のモーダルオーバーレイ:
- 赤い円内のゴミ箱アイコン
- 「Remove [アプリ名]?」タイトル
- 取り消し不可の警告テキスト
- Cancel と Remove ボタン
- Remove ボタン: 赤 (`#E85A4F`) + シャドウ

#### アプリ追加ボタン

- ラベル: "+ Add App"
- スタイル: 幅いっぱいのボタン (破線ボーダー)
- `.contentShape(Rectangle())` で全域ヒット可能
- `NSOpenPanel` を開く (`.application` フィルター)
- パスとバンドル ID による重複検出
- 重複時にアラート表示: "Duplicate Application — [名前] has already been added."

---

### 3. ツールチップパネル

カスタムツールチップ用の独立した `NSPanel` (`.help()` は `nonactivatingPanel` で動作しないため)。

- トリガーボタンの 0.5秒ホバー後に表示
- トリガーの左右に配置 (画面中央基準)
- フェードイン 0.15秒、フェードアウト 0.1秒
- `ignoresMouseEvents = true` (クリックスルー)

---

### 4. メニューバー (ステータスアイテム)

フォールバック用の `NSStatusItem` (キーボードアイコン)。

**メニュー項目**:
- "Show Keypunch" → トリガーパネルを表示
- セパレーター
- "Quit" (⌘Q) → アプリを終了

---

## キーボードナビゲーション

フルキーボードナビゲーションをサポート。両パネルは `KeyablePanel` (`canBecomeKey` 常に `true`) を使用。

### アクティベーション

- 拡張パネル表示時に常に `NSApp.activate()` + `makeKey()` を呼び出し、キーボード入力を有効化
- `activateViaKeyboard()` はキーボードショートカットで Keypunch 自身が起動された際に呼ばれる（自己アクティベーション）
- Tab/Shift-Tab でトリガーアイコンやパネル行間のフォーカス移動

### トリガーピル (FloatingTriggerView)

- 4つのアイコンが `focusable()` と `@FocusState` で追跡: keyboard, hide, power, quit
- フォーカス中のアイコンにインディゴのフォーカスリング (`#6366F1` @ 60%, 1.5pt, r4)
- フォーカスは表示状態にも影響: ホバーと同様にアクティブカラーを適用

### 拡張パネル (FloatingPanelView)

- 各 `LaunchRow` が `focusable()` で `@FocusState` が `UUID` にバインド
- フォーカスされた行にインディゴのフォーカスリング (`#6366F1` @ 60%, 1.5pt, r12)
- Enter キー (`.onKeyPress(.return)`) でフォーカスされた行のアプリを起動
- `.onExitCommand` で Esc の階層ハンドリング:
  1. 削除確認表示中 → 閉じる
  2. 編集モード中 → 編集終了
  3. それ以外 → パネルを閉じる (`onDismissPanel`)

### パネルフォーカス管理

- 拡張パネル表示時: `NSApp.activate()` + `expandedPanel.makeKey()` (キーボードイベントが常にパネルにルーティング)
- 拡張パネル非表示時: パネルがフェードアウト、特別なフォーカス管理は不要

---

## ウィンドウ管理

### FloatingWidgetController

全パネルを管理する `@MainActor` シングルトン。

#### パネル

| パネル | クラス | サイズ | 用途 |
|--------|--------|------|------|
| トリガー | `KeyablePanel` | 48×160 | 画面端ピルウィジェット |
| 拡張 | `KeyablePanel` | 300×360 | メイン操作パネル |
| ツールチップ | `NSPanel` | 動的 | ホバーツールチップ |

`KeyablePanel` は `NSPanel` サブクラスで、`canBecomeKey` が常に `true` を返し、ショートカット録画とキーボードナビゲーションのキーボードフォーカスを有効化。

#### 表示/非表示ロジック

| イベント | 動作 |
|---------|------|
| マウスがトリガーまたはパネルに入る | 非表示タイマーをキャンセル、拡張パネルを表示 |
| マウスが両パネルから出る | 0.3秒タイマーを開始、範囲外なら非表示 |
| モーダルウィンドウがアクティブ (`NSApp.modalWindow != nil`) | マウス退出時の非表示をスキップ |
| トグルボタンをクリック | 拡張パネルの表示/非表示を切り替え |
| トリガー非表示をクリック | トリガーをフェードアウト (0.3秒)、拡張パネルとツールチップを閉じる |

#### 配置

- **トリガー**: UserDefaults の保存位置、または画面右端 + 縦方向中央
- **拡張パネル**: トリガーの隣 (画面中央基準で左右)、表示フレーム内にクランプ
- **画面変更**: `didChangeScreenParametersNotification` でトリガーを再配置

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
- `applicationShouldHandleReopen` で表示ウィンドウがない場合にトリガーを表示

### ログインアイテムサポート

- `SMAppService.mainApp` でログインアイテムの登録/解除
- トリガーボタン (電源アイコン) でトグル
- 有効時は塗りつぶしアイコン (`power.circle.fill`)

---

## Test Mode

CI やテスト実行時にアプリの動作を制御するための仕組み。

### コマンドライン引数

| 引数 | UserDefaults リセット | シードデータ適用 | テストモード (全アプリ表示) |
|------|---------------------|-----------------|--------------------------|
| `-resetForTesting` | Yes | Yes (環境変数があれば) | Yes (`showAllForTesting = true`) |
| `-seedOnly` | Yes | Yes (環境変数があれば) | No (通常動作) |
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
| パネル表示 | 全ショートカット表示 | 全ショートカット表示 |
| UserDefaults | 通常動作 | 起動時にリセット |
| トリガー位置 | 保存位置 | デフォルトにリセット |

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
| `findTrigger()` | トリガーボタンを見つけて返す |
| `openPanel()` | トリガーをホバーして拡張パネルを開く |
| `openEditMode()` | パネルを開き、最初の行の編集ボタンをクリック |

#### トリガーテスト (3 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testTriggerExists` | トリガーボタンが画面に表示される |
| `testTriggerHoverOpensPanel` | トリガーをホバーで拡張パネルが開く |
| `testTriggerMenuItemsExist` | Hide、Power、Quit メニューアイテムがトリガーピルに存在 |

#### ランチタブテスト (5 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testEmptyStatePanelContents` | 空状態で "No shortcuts configured" 表示 |
| `testSeededShortcutAppearsInPanel` | シードしたショートカットがパネルに表示 |
| `testMultipleSeededShortcutsAppearInPanel` | 複数ショートカットが表示 |
| `testPanelShowsAppIcon` | アプリアイコンが表示される |
| `testPanelShowsShortcutBadge` | 未バインドのショートカットに "Not set" バッジ |

#### 編集モードテスト (8 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testEditButtonExistsOnRow` | 編集 (ペンシル) ボタンがショートカット行に存在 |
| `testEditModeShowsSeededShortcut` | 編集モードでショートカットが表示 |
| `testPanelShowsAddAppButton` | "Add App" ボタンが存在 |
| `testDangerTriggerExists` | 編集モードでデンジャートリガーボタンが存在 |
| `testDangerDropdownShowsDeleteButton` | デンジャードロップダウンに削除ボタンが表示 |
| `testEditModeShowsCancelEditButton` | 編集キャンセル (X) ボタンが存在 |
| `testCancelEditExitsEditMode` | 編集キャンセルでコンパクトモードに戻る |
| `testEditModeIsExclusive` | 編集モードは同時に1行のみ（排他制御） |

#### 編集モードバッジ & UI テスト (3 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testEditModeHasRecordShortcutButton` | 編集モードに録画ショートカットボタンが存在 |
| `testEditModeShowsAppDirectory` | 編集カードにアプリディレクトリパスが表示 |
| `testEditModeShowsRecordButton` | 編集モードで "Not set" バッジが表示 |

#### パネルドラッグテスト (1 test)

| テスト名 | 検証内容 |
|---------|---------|
| `testPanelHeaderIsDraggable` | パネルヘッダーが存在し、パネルが機能する |

#### アプリ起動テスト (1 test)

| テスト名 | 検証内容 |
|---------|---------|
| `testPanelLaunchesApp` | アプリ名クリックで TextEdit が起動する |

#### ランチタブ全アプリテスト (1 test)

| テスト名 | 検証内容 |
|---------|---------|
| `testLaunchTabShowsAllAppsEvenWithoutShortcuts` | キーバインドなしでも全アプリ表示 |

#### コンパクト行テスト (2 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testCompactRowShowsAppDirectory` | コンパクト行にアプリディレクトリパスが表示 |
| `testMultipleShortcutsShowSeparateEditButtons` | 各行にそれぞれの編集ボタンがある |

#### 削除確認モーダルテスト (3 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testDeleteConfirmationModalAppears` | 削除確認で "Remove Calculator?" が表示 |
| `testDeleteConfirmationCancelKeepsShortcut` | キャンセルでショートカットエントリが保持 |
| `testDeleteConfirmationRemoveDeletesShortcut` | 削除でショートカットが消え空状態表示 |

#### 録音モードテスト (2 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testRecordingModeShowsRecordBadge` | 録音時に "Record" バッジが表示 |
| `testRecordingCancelButtonExitsRecording` | キャンセルで録音終了、"Not set" に戻る |

#### Add App テスト (1 test)

| テスト名 | 検証内容 |
|---------|---------|
| `testAddAppButtonOpensFileDialog` | "Add App" クリックで NSOpenPanel ファイルダイアログが開く |

#### メニューバーテスト (1 test)

| テスト名 | 検証内容 |
|---------|---------|
| `testMenuBarShowKeypunchRestoresTrigger` | "Show Keypunch" メニューでトリガーが再表示される |

#### デンジャードロップダウン条件テスト (1 test)

| テスト名 | 検証内容 |
|---------|---------|
| `testUnsetButtonNotShownWhenNoShortcutSet` | ショートカット未設定時に解除ボタン非表示 |

#### キーボードナビゲーションテスト (8 tests)

| テスト名 | 検証内容 |
|---------|---------|
| `testTriggerHasFocusableIcons` | 全トリガーアイコンが有効でフォーカス可能 |
| `testPanelRowsExistForKeyboardNavigation` | キーボードナビ用の行と Add App ボタンが存在 |
| `testKeyboardEscDismissesPanel` | Esc キーで拡張パネルが閉じる |
| `testKeyboardEscExitsEditModeBeforeDismissing` | 最初の Esc で編集モード終了、パネルは残る |
| `testKeyboardEscDismissesDeleteConfirmation` | Esc で削除確認ダイアログが閉じ、パネルは残る |
| `testKeyboardEnterLaunchesApp` | Tab でフォーカスし Enter でアプリ起動 |
| `testKeyboardTabNavigatesBetweenRows` | Tab で2行目に移動し Enter で2番目のアプリ起動 |
| `testKeyboardShiftTabNavigatesBackward` | Shift-Tab で前の行に戻り Enter で1番目のアプリ起動 |

#### 起動テスト (1 test)

| テスト名 | 検証内容 |
|---------|---------|
| `testLaunch` | アプリが起動しスクリーンショットをキャプチャ |

### テスト数サマリー

| カテゴリ | テスト数 |
|---------|---------|
| Unit: AppShortcutTests | 12 |
| Unit: ShortcutStoreTests | 19 |
| UI: トリガー | 3 |
| UI: ランチタブ | 5 |
| UI: 編集モード | 8 |
| UI: 編集モードバッジ & UI | 3 |
| UI: パネルドラッグ | 1 |
| UI: アプリ起動 | 1 |
| UI: ランチタブ全アプリ | 1 |
| UI: コンパクト行 | 2 |
| UI: Add App | 1 |
| UI: 削除確認モーダル | 3 |
| UI: 録音モード | 2 |
| UI: メニューバー | 1 |
| UI: デンジャードロップダウン条件 | 1 |
| UI: キーボードナビゲーション | 8 |
| UI: 起動 | 1 |
| **合計** | **72** |

---

## CI/CD

### GitHub Actions Workflow

**ファイル**: `.github/workflows/test.yml`
**トリガー**: `push` (パスフィルター: `Keypunch/**`, `KeypunchTests/**`, `KeypunchUITests/**`, `.github/workflows/test.yml`)

| ジョブ | ランナー | 対象 |
|--------|---------|------|
| Unit Tests | `macos-15` | `KeypunchTests` |
| UI Tests | `macos-15` | `KeypunchUITests` |

**Actions**: `actions/checkout` は pinact により commit hash にピン留め。

---

## Dependencies

| パッケージ | バージョン | 用途 |
|-----------|----------|------|
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 2.4.0 (>=2.2.2) | グローバルキーボードショートカットの登録・管理 |

---

## Known Limitations

1. **ViewBridge エラー**: `RecorderCocoa` (NSSearchField サブクラス) がフローティングパネルで ViewBridge 切断エラーを発生させる。カスタム `ShortcutCaptureView` (プレーン NSView) で置き換え済み。
2. **ゾンビプロセス**: Xcode デバッグセッション後にゾンビプロセスが残ると、XCUITest の tearDown で termination エラーが発生する。`resilientLaunch()` で緩和。
3. **ツールチップ回避策**: `.help()` モディファイアは `nonactivatingPanel` で動作しない。カスタムツールチップパネルで代替。
4. **NSOpenPanel モーダルガード**: NSOpenPanel が開いている間、`mouseExited` をガードしてパネルの誤非表示を防止。
5. **非アクティベーションパネルのクリック制約**: `NSPanel(.nonactivatingPanel)` 内の SwiftUI `Button` は XCUITest の `.click()` アクションに応答しない。トリガーピルのボタン操作は XCUITest では検証できず、要素の存在確認のみ行う。

## License

MIT
