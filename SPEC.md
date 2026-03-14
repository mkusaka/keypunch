# Keypunch — Specification

> Japanese version: [SPEC.ja.md](./SPEC.ja.md)

## Overview

Keypunch is a macOS floating widget application that registers global keyboard shortcuts to launch applications. It runs without a Dock icon — all interactions happen through a floating trigger pill on the screen edge and a menu bar icon as a fallback.

## System Requirements

| Item | Requirement |
|------|-------------|
| OS | macOS 15.0+ |
| Xcode | 16+ |
| Swift | 5.0 |

## Architecture

### Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | SwiftUI (floating `NSPanel`) |
| Window Management | `NSPanel` (borderless, non-activating) |
| Global Hotkeys | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) v2.4.0 |
| Shortcut Recording | Custom `ShortcutCaptureView` (plain `NSView`) |
| State Management | `@Observable` (Swift Observation) |
| Data Persistence | UserDefaults (JSON encoding) |
| App Launching | NSWorkspace |
| Login Item | SMAppService |

### App Configuration

| Item | Value |
|------|-------|
| Bundle Identifier | `com.mkusaka.Keypunch` |
| LSUIElement | `YES` (hidden from Dock) |
| Menu Bar Icon | SF Symbols `keyboard` |

### File Structure

```
Keypunch/
├── KeypunchApp.swift                # Entry point, AppDelegate, test mode control
├── FloatingWidgetController.swift   # NSPanel orchestration, mouse tracking, drag
├── Models/
│   └── AppShortcut.swift            # Shortcut data model
├── ShortcutStore.swift              # State management, persistence, app launching
├── Views/
│   ├── FloatingPanelView.swift      # Expanded panel (compact rows, edit cards, delete confirm)
│   ├── FloatingTriggerView.swift    # Trigger pill (4 icon buttons in single pill)
│   ├── SettingsView.swift           # (legacy, unused)
│   └── ShortcutEditView.swift       # (legacy, unused)
└── Keypunch.entitlements            # (empty — no sandbox)

KeypunchTests/
└── KeypunchTests.swift              # Unit tests (Swift Testing)

KeypunchUITests/
├── KeypunchUITests.swift            # UI tests (XCTest)
└── KeypunchUITestsLaunchTests.swift # Launch tests
```

---

## Data Model

### AppShortcut

A struct representing a single application shortcut configuration.

```swift
struct AppShortcut: Identifiable, Codable, Hashable
```

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `id` | `UUID` | Auto-generated | Unique identifier |
| `name` | `String` | — | Display name (derived from app file name) |
| `bundleIdentifier` | `String?` | — | macOS bundle ID (e.g., `com.apple.calculator`) |
| `appPath` | `String` | — | Full file system path to the application |
| `shortcutName` | `String` | `"appShortcut_\(id)"` | Unique name for KeyboardShortcuts library registration |
| `isEnabled` | `Bool` | `true` | Whether the shortcut is active (key binding preserved when disabled) |

**Computed Properties**:

| Property | Type | Description |
|----------|------|-------------|
| `keyboardShortcutName` | `KeyboardShortcuts.Name` | Name object for library integration |
| `appURL` | `URL` | File URL generated from `appPath` |
| `appDirectory` | `String` | Parent directory path (e.g., `/System/Applications`) |

**Codable Compatibility**:
- `isEnabled` uses `decodeIfPresent` with `true` fallback for backward compatibility with older data that lacks this field.

**Constraints**:
- `id` is auto-generated at creation, guaranteeing uniqueness
- `shortcutName` is also auto-generated based on `id`, guaranteeing uniqueness
- `bundleIdentifier` allows `nil` (for apps without a bundle ID)

---

## State Management

### ShortcutStore

The `@Observable` class responsible for managing all shortcuts across the application.

```swift
@MainActor
@Observable
final class ShortcutStore
```

#### Persistence

| Item | Value |
|------|-------|
| Storage | UserDefaults |
| Key | `"savedAppShortcuts"` |
| Format | JSON (`JSONEncoder` / `JSONDecoder`) |
| Data | `[AppShortcut]` array |
| Loading | Decoded from UserDefaults in `init()` |
| Corrupt Data | Silently loads empty array on decode failure |

**Note**: The actual keyboard shortcut key bindings are persisted independently by the KeyboardShortcuts library in its own UserDefaults entries. ShortcutStore only saves app metadata.

#### Public Properties

| Property | Type | Description |
|----------|------|-------------|
| `shortcuts` | `[AppShortcut]` | All registered shortcuts (read-only) |
| `shortcutKeysVersion` | `Int` | Incremented on key binding changes, used to force SwiftUI refresh |

#### Public Methods

| Method | Description |
|--------|-------------|
| `addShortcut(_:)` | Adds a shortcut, registers its handler, and persists to disk |
| `removeShortcut(_:)` | Removes a shortcut, resets its key binding, and persists |
| `removeShortcuts(at:)` | Batch-removes shortcuts by `IndexSet` |
| `updateShortcut(_:)` | Updates an existing shortcut by ID. Resets old key binding if `shortcutName` changed |
| `toggleEnabled(for:)` | Toggles `isEnabled` state. When disabled, handler is emptied but key binding is preserved |
| `unsetShortcut(for:)` | Resets key binding via `KeyboardShortcuts.reset()`. App entry remains. Increments `shortcutKeysVersion` |
| `containsApp(path:)` | Checks if an app at the given path is already registered |
| `containsApp(bundleIdentifier:)` | Checks if an app with the given bundle ID is already registered |
| `isShortcutConflicting(_:excluding:)` | Checks if a shortcut key combo conflicts with another registered shortcut |
| `addShortcutFromURL(_:)` | Adds from URL with duplicate detection. Returns `.success(AppShortcut)` or `.duplicate(String)` |
| `launchApp(for:)` | Launches the target application |

#### App Launch Logic

`launchApp(for:)` resolves the application in the following priority order:

1. If `bundleIdentifier` is non-nil and resolvable via `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` → launch using that URL
2. Fallback: convert `appPath` to a URL and launch

Both paths use `NSWorkspace.shared.openApplication(at:configuration:)`.

#### Handler Registration

- `registerHandler(for:)` checks `isEnabled` before setting up the callback
- When disabled, an empty handler is registered (preserving the key binding)
- On `init()`, handlers are registered for all loaded shortcuts in bulk
- `shortcutKeysVersion` is incremented via NotificationCenter observation of `KeyboardShortcuts_shortcutByNameDidChange`

---

## UI Components

### 1. Floating Trigger (Screen-Edge Pill)

A vertical pill-shaped widget that floats on the screen edge. All 4 icons are always visible in a single pill.

**Size**: 48 × 160 pt
**Corner Radius**: 24 pt
**Background**: `#1A1A1E`
**Panel Level**: `.floating`
**Behavior**: `.canJoinAllSpaces`, `.fullScreenAuxiliary`

#### Buttons (4 icons, top to bottom)

| Icon | SF Symbol | Action | Tooltip | Accessibility ID |
|------|-----------|--------|---------|------------------|
| Keyboard | `keyboard` | Toggle expanded panel | "Toggle Keypunch" | `trigger-button` |
| Hide | `eye.slash` | Fade-out and hide trigger | "Hide Trigger" | `menu-hide` |
| Login | `power` / `power.circle.fill` | Toggle login item | "Enable/Disable Start at Login" | `menu-power` |
| Quit | `rectangle.portrait.and.arrow.right` | Quit app | "Quit App" | `menu-quit` |

#### Icon Hover Effects
- Scale: 1.0 → 1.2 on hover
- Glow: color shadow (radius 8, opacity 0.3) on hover
- Color: idle `#6B6B70` (opacity 0.7) → full color on hover or when active
- Quit icon uses danger color `#E85A4F`
- Tooltip: Custom tooltip panel appears after 0.5s delay

#### Pill Active State
- Border stroke: `#FFFFFF` @ 9% idle, 15% when panel is active
- Glow: indigo `#6366F1` @ 12% when active

#### Drag-to-Move
- Both trigger and expanded panel move in lockstep during drag
- Position is persisted to UserDefaults (`triggerPositionX`, `triggerPositionY`)
- Default position: right screen edge, vertically centered

#### Hide Behavior
- Fades out with 0.3s animation, then `orderOut`
- Alpha reset to 1.0 for next show
- Expanded panel and tooltips are dismissed first
- Can be restored via menu bar "Show Keypunch" or `applicationShouldHandleReopen`

---

### 2. Expanded Panel (Floating Panel)

The main interaction panel that appears adjacent to the trigger.

**Size**: 300 × 360 pt
**Corner Radius**: 20 pt
**Background**: `#16161A`
**Panel Level**: `.floating`

#### Panel Structure

```
┌──────────────────────────────────────┐
│ Keypunch                             │  ← drag handle (header)
│──────────────────────────────────────│
│ [icon] Calculator      ⌘⇧C    [✎]  │  ← compact row (LaunchRow)
│        /System/Applications          │
│ [icon] TextEdit        Not set [✎]  │
│        /System/Applications          │
│                                      │
│         [+ Add App]                  │  ← add button
└──────────────────────────────────────┘
```

#### Header
- Text: "Keypunch" (15pt, semibold, white)
- Serves as drag handle for panel repositioning
- Drag moves both expanded panel and trigger in lockstep

#### Compact Row (LaunchRow)

Each registered app is shown as a compact row.

| Element | Size | Description |
|---------|------|-------------|
| App icon | 28×28 | `NSWorkspace.shared.icon(forFile:)`, rounded corners (7pt) |
| App name | — | 13pt, medium weight. Semibold on hover |
| App directory | — | 10pt, `#4A4A50`, middle truncation |
| Shortcut badge | — | 3-state display (see below) |
| Edit button | 22×22 | Pencil icon, opens per-row edit mode |

**Shortcut Badge (3 states)**:

| State | Display | Badge Color |
|-------|---------|-------------|
| Set & Active | Key combo (e.g., `⌘⇧C`) | Blue `#0A84FF`, background `#0A84FF` @ 15% |
| Disabled | Key combo with strikethrough | Gray `#6B6B70` |
| Not set | "Not set" text | Gray `#4A4A50` |

**Hover Effect**: Row background changes to blue-tinted `#0A84FF` @ 8%, border `#0A84FF` @ 20%.

**Click**: Launches the target application via `store.launchApp(for:)`.

**Edit Button**: `accessibilityIdentifier("edit-shortcut")`. Transitions to EditCard for that row with 0.15s opacity animation.

#### Edit Card (Expanded Per-Row Edit Mode)

When the pencil button is clicked, the compact row expands into an edit card. Dimensions are unified with the compact row for consistent row height.

| Element | Size | Description |
|---------|------|-------------|
| App icon | 28×28 | Rounded corners (7pt) |
| App name | — | 13pt, semibold |
| App directory | — | 10pt, `#4A4A50` |
| Shortcut badge area | height 22, r6 | 3 states: not set, recording, set |
| Cancel button (X) | 22×22, r6 | Exits edit mode |
| Danger trigger (!) | 22×22, r6 | Opens action dropdown |

**Row padding**: horizontal 10, vertical 8. Corner radius: 12.

**Shortcut Badge Area (3 states)**:

1. **Not Set**: "Not set" text + pencil icon button. Click pencil to start recording.
2. **Recording**: Amber dot (`#FFB547`) + "Record" text + X cancel. Background `#FFB547` @ 12.5%, border `#FFB547` @ 25%. Custom `ShortcutCaptureView` captures keyboard input.
3. **Set**: Key combo text (click to toggle enable/disable) + pencil icon (click to re-record).

**Cancel Edit**: `accessibilityIdentifier("cancel-edit")`. Returns to compact row.

**Danger Trigger**: `accessibilityIdentifier("danger-trigger")`. Opens popover with:
- **Unset Shortcut** (`accessibilityIdentifier("unset-shortcut")`): Only shown when a key binding exists. Resets key binding, preserves app entry.
- **Delete App** (`accessibilityIdentifier("delete-app")`): Opens delete confirmation overlay.

#### Delete Confirmation Overlay

A modal overlay within the panel showing:
- Trash icon in red circle
- "Remove [AppName]?" title
- Warning text about irreversibility
- Cancel and Remove buttons
- Remove button: red (`#E85A4F`) with shadow

#### Add App Button

- Label: "+ Add App"
- Style: Full-width button with dashed border
- `.contentShape(Rectangle())` for full hit area
- Opens `NSOpenPanel` filtered to `.application`
- Duplicate detection by path and bundle ID
- Shows alert on duplicate: "Duplicate Application — [name] has already been added."

---

### 3. Tooltip Panel

A separate `NSPanel` for custom tooltips (since `.help()` doesn't work with `nonactivatingPanel`).

- Appears after 0.5s hover delay on trigger buttons
- Positioned to the left or right of the trigger (based on screen center)
- Fade-in 0.15s, fade-out 0.1s
- `ignoresMouseEvents = true` (click-through)

---

### 4. Menu Bar (Status Item)

A fallback `NSStatusItem` with keyboard icon.

**Menu Items**:
- "Show Keypunch" → shows trigger panel
- Separator
- "Quit" (⌘Q) → terminates app

---

## Keyboard Navigation

Keypunch supports full keyboard navigation when activated via keyboard shortcut (as opposed to mouse hover).

### Activation

- `activateViaKeyboard()` is called when Keypunch is triggered via a registered keyboard shortcut
- This sets `triggerPanel.allowBecomeKey = true` and makes it the key window
- Tab/Shift-Tab moves focus between trigger icons and panel rows

### Trigger Pill (FloatingTriggerView)

- 4 icons are `focusable()` with `@FocusState` tracking: keyboard, hide, power, quit
- Focused icon shows indigo focus ring (`#6366F1` @ 60%, 1.5pt, r4)
- Focus affects visual state: focused icon uses active color like hover

### Expanded Panel (FloatingPanelView)

- Each `LaunchRow` is `focusable()` with `@FocusState` bound to `UUID`
- Focused row shows indigo focus ring (`#6366F1` @ 60%, 1.5pt, r12)
- Enter key (`.onKeyPress(.return)`) on focused row launches the app
- `.onExitCommand` provides layered Esc handling:
  1. If delete confirmation is showing → dismiss it
  2. If in edit mode → exit edit mode
  3. Otherwise → dismiss the panel (`onDismissPanel`)

### Keyboard-Driven Panel Switching

- When panel opens via keyboard: trigger `allowBecomeKey = false`, expanded `allowBecomeKey = true`, expanded `makeKey()`
- When panel closes: if was keyboard-driven, trigger `allowBecomeKey = true`, trigger `makeKey()` (focus returns to trigger)

---

## Window Management

### FloatingWidgetController

`@MainActor` singleton that orchestrates all panels.

#### Panels

| Panel | Class | Size | Purpose |
|-------|-------|------|---------|
| Trigger | `KeyablePanel` | 48×160 | Screen-edge pill widget |
| Expanded | `KeyablePanel` | 300×360 | Main interaction panel |
| Tooltip | `NSPanel` | Dynamic | Hover tooltips |

`KeyablePanel` is an `NSPanel` subclass with toggleable `canBecomeKey` (`allowBecomeKey` property) to enable keyboard focus for shortcut recording and keyboard navigation.

#### Show/Hide Logic

| Event | Action |
|-------|--------|
| Mouse enters trigger or panel | Cancel hide timer, show expanded panel |
| Mouse exits both panels | Start 0.3s timer, then hide if still outside |
| Modal window active (`NSApp.modalWindow != nil`) | Skip hide on mouse exit |
| Toggle button clicked | Toggle expanded panel visibility |
| Hide trigger clicked | Fade-out trigger (0.3s), dismiss expanded panel and tooltips |

#### Positioning

- **Trigger**: Saved position from UserDefaults, or right edge + vertically centered
- **Expanded panel**: Adjacent to trigger (left or right based on screen center), clamped to visible frame
- **Screen changes**: Trigger repositions on `didChangeScreenParametersNotification`

---

## Keyboard Shortcut Recording

### ShortcutCaptureView

A plain `NSView` subclass (not `NSSearchField`-based) to avoid ViewBridge disconnection errors in floating panels.

**Behavior**:
1. View becomes first responder → `KeyablePanel.allowBecomeKey = true`
2. User presses modifier + key → `KeyboardShortcuts.setShortcut()` called
3. Escape → cancels recording
4. Resign first responder → cancels recording
5. After capture/cancel → `KeyablePanel.allowBecomeKey = false`

**Conflict Detection**: After setting a shortcut, `store.isShortcutConflicting()` checks all other registered shortcuts. If conflict detected, the shortcut is reset.

---

## Application Lifecycle

### KeypunchApp (Entry Point)

```swift
@main struct KeypunchApp: App
```

- Creates `ShortcutStore` and shares it via static properties
- `AppDelegate.applicationDidFinishLaunching` creates `FloatingWidgetController`
- Guard: skips controller setup when running under `XCTestCase`
- `applicationShouldHandleReopen` shows trigger when no visible windows

### Login Item Support

- Uses `SMAppService.mainApp` for login item registration
- Toggle via trigger button (power icon)
- Filled icon (`power.circle.fill`) when enabled

---

## Test Mode

Mechanism to control app behavior during CI and test execution.

### Command Line Arguments

| Argument | UserDefaults Reset | Seed Data | Test Mode (All Apps Visible) |
|----------|--------------------|-----------|------------------------------|
| `-resetForTesting` | Yes | Yes (if env var present) | Yes (`showAllForTesting = true`) |
| `-seedOnly` | Yes | Yes (if env var present) | No (normal behavior) |
| (none) | No | No | No |

### Environment Variables

| Variable | Type | Description |
|----------|------|-------------|
| `SEED_SHORTCUTS` | JSON string | Seed data for testing. An array of AppShortcut objects in JSON format |

**Seed Data Format**:

```json
[
  {
    "id": "UUID-string",
    "name": "Calculator",
    "bundleIdentifier": "com.apple.calculator",
    "appPath": "/System/Applications/Calculator.app",
    "shortcutName": "test_UUID-string"
  }
]
```

### Test Mode Effects

| Feature | Normal Mode | Test Mode (`-resetForTesting`) |
|---------|-------------|-------------------------------|
| Panel display | All shortcuts shown | All shortcuts shown |
| UserDefaults | Normal operation | Reset on launch |
| Trigger position | Saved position | Reset to default |

---

## Testing

### Unit Tests (Swift Testing)

Framework: `@Test`, `#expect` (Swift Testing)
Test UserDefaults: isolated per test with unique `suiteName`

#### AppShortcutTests (12 tests)

| Test | Verified Behavior |
|------|-------------------|
| `initWithDefaults` | Default initialization sets correct properties |
| `initWithCustomShortcutName` | Custom shortcutName is preserved |
| `initWithNilBundleIdentifier` | nil bundleIdentifier is accepted |
| `isEnabledDefaultsToTrue` | isEnabled defaults to true |
| `isEnabledCanBeSetToFalse` | isEnabled can be set to false |
| `codableRoundTrip` | Single shortcut JSON encode/decode is accurate |
| `codableBackwardCompatibility` | Old JSON without isEnabled field defaults to true |
| `codableRoundTripArray` | Array JSON encode/decode is accurate |
| `hashableConformance` | Shortcuts with same ID are equal and hash identically |
| `uniqueIdsOnCreation` | Each new instance gets a unique ID and shortcutName |
| `appDirectoryComputed` | appDirectory returns parent directory path |
| `appDirectoryForNestedPath` | appDirectory works for deeply nested paths |

#### ShortcutStoreTests (19 tests, serialized)

| Test | Verified Behavior |
|------|-------------------|
| `addShortcut` | Adding increments count and stores correctly |
| `removeShortcut` | Removing empties the array |
| `removeShortcutsAtOffsets` | Batch removal by IndexSet |
| `updateShortcut` | Existing shortcut is updated |
| `updateNonexistentShortcutIsNoop` | Updating non-existent ID is a no-op |
| `persistenceAcrossInstances` | Data is restored after store re-creation |
| `emptyStoreOnFreshDefaults` | Fresh UserDefaults yields empty store |
| `containsAppByPath` | Duplicate detection by path |
| `containsAppByBundleIdentifier` | Duplicate detection by bundle ID |
| `toggleEnabled` | Toggle flips isEnabled state and back |
| `toggleEnabledPersists` | Toggled state persists across store instances |
| `unsetShortcutKeepsAppEntry` | Unset removes key binding but keeps app entry |
| `unsetShortcutIncrementsVersion` | shortcutKeysVersion increments after unset |
| `containsAppByBundleIdentifierWithNilBundleIDs` | nil bundle IDs don't cause false positives |
| `addShortcutFromURLSuccess` | Adding from valid URL extracts name, path, bundle ID |
| `addShortcutFromURLDuplicateByPath` | Duplicate detection by path via URL |
| `addShortcutFromURLDuplicateByBundleID` | Duplicate detection by bundle ID via URL |
| `corruptDataLoadsEmpty` | Corrupt UserDefaults data results in empty store |
| `toggleEnabledNonexistentIsNoop` | Toggle on nonexistent shortcut is no-op |

### UI Tests (XCTest)

Framework: XCTest / XCUITest

#### Test Helpers

| Method | Description |
|--------|-------------|
| `resilientLaunch()` | Launches with `continueAfterFailure = true` to tolerate zombie process errors |
| `launchClean()` | Launches with `-resetForTesting` flag |
| `launchWithSeededShortcuts(_:)` | Launches with seed data + test mode |
| `launchWithSeededShortcutsNoTestMode(_:)` | Launches with seed data + normal mode (`-seedOnly`) |
| `makeSeedShortcut(name:bundleID:appPath:)` | Generates a seed data dictionary |
| `findTrigger()` | Finds and returns the trigger button |
| `openPanel()` | Hovers trigger to open expanded panel |
| `openEditMode()` | Opens panel and clicks edit button on first row |

#### Trigger Tests (3 tests)

| Test | Verified Behavior |
|------|-------------------|
| `testTriggerExists` | Trigger button appears on screen |
| `testTriggerHoverOpensPanel` | Hovering trigger opens expanded panel |
| `testTriggerMenuItemsExist` | Hide, power, and quit menu items exist on trigger pill |

#### Launch Tab Tests (5 tests)

| Test | Verified Behavior |
|------|-------------------|
| `testEmptyStatePanelContents` | Empty state shows "No shortcuts configured" |
| `testSeededShortcutAppearsInPanel` | Seeded shortcut appears in panel |
| `testMultipleSeededShortcutsAppearInPanel` | Multiple shortcuts appear |
| `testPanelShowsAppIcon` | App icon is displayed |
| `testPanelShowsShortcutBadge` | "Not set" badge for unbound shortcut |

#### Edit Mode Tests (8 tests)

| Test | Verified Behavior |
|------|-------------------|
| `testEditButtonExistsOnRow` | Edit (pencil) button exists on shortcut row |
| `testEditModeShowsSeededShortcut` | Shortcut appears in edit mode |
| `testPanelShowsAddAppButton` | "Add App" button exists |
| `testDangerTriggerExists` | Danger trigger button exists in edit mode |
| `testDangerDropdownShowsDeleteButton` | Delete button appears in danger dropdown |
| `testEditModeShowsCancelEditButton` | Cancel edit (X) button exists |
| `testCancelEditExitsEditMode` | Cancel edit returns to compact mode |
| `testEditModeIsExclusive` | Only one row can be in edit mode at a time |

#### Edit Mode Badge & UI Tests (3 tests)

| Test | Verified Behavior |
|------|-------------------|
| `testEditModeHasRecordShortcutButton` | Record shortcut button exists in edit mode |
| `testEditModeShowsAppDirectory` | App directory path shown in edit card |
| `testEditModeShowsRecordButton` | "Not set" badge visible in edit mode |

#### Panel Drag Tests (1 test)

| Test | Verified Behavior |
|------|-------------------|
| `testPanelHeaderIsDraggable` | Panel header exists and panel remains functional |

#### App Launch Tests (1 test)

| Test | Verified Behavior |
|------|-------------------|
| `testPanelLaunchesApp` | Clicking app name launches TextEdit |

#### Launch Tab All Apps Tests (1 test)

| Test | Verified Behavior |
|------|-------------------|
| `testLaunchTabShowsAllAppsEvenWithoutShortcuts` | All apps shown even without key bindings |

#### Compact Row Tests (2 tests)

| Test | Verified Behavior |
|------|-------------------|
| `testCompactRowShowsAppDirectory` | Compact row shows app directory path |
| `testMultipleShortcutsShowSeparateEditButtons` | Each row has its own edit button |

#### Delete Confirmation Modal Tests (3 tests)

| Test | Verified Behavior |
|------|-------------------|
| `testDeleteConfirmationModalAppears` | Delete confirmation shows "Remove Calculator?" |
| `testDeleteConfirmationCancelKeepsShortcut` | Cancel keeps the shortcut entry |
| `testDeleteConfirmationRemoveDeletesShortcut` | Remove deletes the shortcut and shows empty state |

#### Recording Mode Tests (2 tests)

| Test | Verified Behavior |
|------|-------------------|
| `testRecordingModeShowsRecordBadge` | "Record" badge appears when recording |
| `testRecordingCancelButtonExitsRecording` | Cancel exits recording mode, shows "Not set" |

#### Add App Tests (1 test)

| Test | Verified Behavior |
|------|-------------------|
| `testAddAppButtonOpensFileDialog` | Clicking "Add App" opens NSOpenPanel file dialog |

#### Menu Bar Tests (1 test)

| Test | Verified Behavior |
|------|-------------------|
| `testMenuBarShowKeypunchRestoresTrigger` | "Show Keypunch" menu item restores trigger visibility |

#### Danger Dropdown Conditional Tests (1 test)

| Test | Verified Behavior |
|------|-------------------|
| `testUnsetButtonNotShownWhenNoShortcutSet` | Unset button hidden when no shortcut is bound |

#### Keyboard Navigation Structure Tests (2 tests)

| Test | Verified Behavior |
|------|-------------------|
| `testTriggerHasFocusableIcons` | All trigger icons are enabled and focusable |
| `testPanelRowsExistForKeyboardNavigation` | Rows and Add App button exist for keyboard navigation |

#### Launch Tests (1 test)

| Test | Verified Behavior |
|------|-------------------|
| `testLaunch` | App launches and captures a screenshot |

### Test Count Summary

| Category | Count |
|----------|-------|
| Unit: AppShortcutTests | 12 |
| Unit: ShortcutStoreTests | 19 |
| UI: Trigger | 3 |
| UI: Launch Tab | 5 |
| UI: Edit Mode | 8 |
| UI: Edit Mode Badge & UI | 3 |
| UI: Panel Drag | 1 |
| UI: App Launch | 1 |
| UI: Launch Tab All Apps | 1 |
| UI: Compact Row | 2 |
| UI: Add App | 1 |
| UI: Delete Confirmation Modal | 3 |
| UI: Recording Mode | 2 |
| UI: Menu Bar | 1 |
| UI: Danger Dropdown Conditional | 1 |
| UI: Keyboard Navigation Structure | 2 |
| UI: Launch | 1 |
| **Total** | **66** |

---

## CI/CD

### GitHub Actions Workflow

**File**: `.github/workflows/test.yml`
**Trigger**: `push` (filtered by paths: `Keypunch/**`, `KeypunchTests/**`, `KeypunchUITests/**`, `.github/workflows/test.yml`)

| Job | Runner | Target |
|-----|--------|--------|
| Unit Tests | `macos-15` | `KeypunchTests` |
| UI Tests | `macos-15` | `KeypunchUITests` |

**Actions**: `actions/checkout` is pinned to a commit hash via pinact.

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 2.4.0 (>=2.2.2) | Global keyboard shortcut registration and management |

---

## Known Limitations

1. **ViewBridge Errors**: `RecorderCocoa` (NSSearchField subclass) causes ViewBridge disconnection errors in floating panels. Replaced with custom `ShortcutCaptureView` (plain NSView).
2. **Zombie Processes**: If a zombie process remains after an Xcode debug session, XCUITest's tearDown will fail with a termination error. `resilientLaunch()` mitigates this.
3. **Tooltip Workaround**: `.help()` modifier doesn't work with `nonactivatingPanel`. Custom tooltip panel used instead.
4. **NSOpenPanel Modal Guard**: When NSOpenPanel is open, `mouseExited` must be guarded to prevent panel dismissal.
5. **Non-Activating Panel Click Limitation**: SwiftUI `Button` inside `NSPanel(.nonactivatingPanel)` does not respond to XCUITest `.click()` actions. Trigger pill button interactions cannot be tested via XCUITest; only element existence is verified.

## License

MIT
