# Keypunch — Specification

> Japanese version: [SPEC.ja.md](./SPEC.ja.md)

## Overview

Keypunch is a macOS menu bar application that registers global keyboard shortcuts to launch applications. It runs without a Dock icon — all interactions happen through a menu bar icon and a standard settings window.

## System Requirements

| Item | Requirement |
|------|-------------|
| OS | macOS 15.5+ |
| Xcode | 16+ |
| Swift | 5.0 |

## Architecture

### Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | SwiftUI (standard `NSWindow`) |
| Window Management | `NSWindow` (titled, closable, miniaturizable) |
| Global Hotkeys | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) v2.4.0 |
| Shortcut Recording | Custom `ShortcutCaptureView` (plain `NSView`) |
| State Management | `@Observable` (Swift Observation) |
| Data Persistence | UserDefaults (JSON encoding) |
| App Launching | NSWorkspace (via `AppLaunching` protocol) |
| Login Item | SMAppService (via `LoginItemManaging` protocol) |
| Shortcut Registration | KeyboardShortcuts (via `ShortcutRegistering` protocol) |

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
├── FloatingWidgetController.swift   # Menu bar, standard NSWindow management
├── Models/
│   └── AppShortcut.swift            # Shortcut data model
├── ShortcutStore.swift              # State management, persistence (delegates to services)
├── Protocols/
│   ├── AppLaunching.swift           # NSWorkspace abstraction for app launching
│   ├── BundleProviding.swift        # Bundle.main abstraction
│   ├── LoginItemManaging.swift      # SMAppService abstraction
│   └── ShortcutRegistering.swift    # KeyboardShortcuts static API abstraction
├── Services/
│   ├── AppLaunchService.swift       # App launching + self-activation logic
│   ├── LoginItemService.swift       # Login item toggle logic
│   └── ShortcutRegistrationService.swift  # Shortcut register/unregister/reset
├── Views/
│   ├── FloatingPanelView.swift      # Settings panel (SettingsPanelView)
│   ├── EditCardView.swift           # Per-row edit mode card
│   ├── EditPencilButton.swift       # Pencil edit button component
│   ├── PanelFocus.swift             # PanelFocus enum for focus management
│   └── ShortcutCaptureView.swift    # NSView for keyboard shortcut capture
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

The `@Observable` class responsible for managing all shortcuts across the application. Uses dependency injection via protocol abstractions for testability.

```swift
@MainActor
@Observable
final class ShortcutStore
```

**Dependencies** (injected via init with defaults):
- `defaults: UserDefaults` — persistence store
- `workspace: AppLaunching` — app launching (default: `NSWorkspace.shared`)
- `registrar: ShortcutRegistering` — shortcut registration (default: `KeyboardShortcutsRegistrar()`)
- `mainBundle: BundleProviding` — bundle identity (default: `Bundle.main`)

**Internal Services**:
- `AppLaunchService` — handles app launching and self-activation detection
- `ShortcutRegistrationService` — handles shortcut register/unregister/reset

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

### 1. Menu Bar (Status Item)

The primary entry point for app control via `NSStatusItem` with a keyboard icon.

**Menu Items**:
- "Show Keypunch" → opens the settings window
- Separator
- "Start at Login" → toggles login item (checkmark when enabled, via `NSMenuDelegate`)
- Separator
- "Quit" (⌘Q) → terminates app

### 2. Settings Window

A standard macOS `NSWindow` for managing shortcut configurations.

**Size**: 380 × 616 pt
**Style**: `.titled`, `.closable`, `.miniaturizable` (standard traffic light buttons)
**Title**: "Keypunch"
**Accessibility ID**: `keypunch-panel`

#### Panel Structure

```
┌──────────────────────────────────────┐
│ ● ● ●  Keypunch                      │  ← standard title bar
│──────────────────────────────────────│
│ [icon] Calculator      ⌘⇧C    [✎]  │  ← compact row (LaunchRow)
│        /System/Applications          │
│ [icon] TextEdit        Not set [✎]  │
│        /System/Applications          │
│                                      │
│         [+ Add App]                  │  ← add button
└──────────────────────────────────────┘
```

#### Compact Row (LaunchRow)

Each registered app is shown as a compact row.

| Element | Size | Description |
|---------|------|-------------|
| App icon | 28×28 | `NSWorkspace.shared.icon(forFile:)`, rounded corners (7pt) |
| App name | — | 13pt, medium weight. Semibold on hover |
| App directory | — | 10pt, secondary color, middle truncation |
| Shortcut badge | — | 3-state display (see below) |
| Edit button | 22×22 | Pencil icon, opens per-row edit mode |

**Shortcut Badge (3 states)**:

| State | Display | Badge Color |
|-------|---------|-------------|
| Set & Active | Key combo (e.g., `⌘⇧C`) | Accent color, background accent @ 15% |
| Disabled | Key combo with strikethrough | Secondary color |
| Not set | "Not set" text | Tertiary color |

**Hover Effect**: Row background changes to accent-tinted @ 8%, border accent @ 20%.

**Click**: Launches the target application via `store.launchApp(for:)`.

**Edit Button**: `accessibilityIdentifier("edit-shortcut")`. Transitions to EditCard for that row with 0.15s opacity animation.

#### Edit Card (Expanded Per-Row Edit Mode)

When the pencil button is clicked, the compact row expands into an edit card. Dimensions are unified with the compact row for consistent row height.

| Element | Size | Description |
|---------|------|-------------|
| App icon | 28×28 | Rounded corners (7pt) |
| App name | — | 13pt, semibold |
| App directory | — | 10pt, secondary color |
| Shortcut badge area | height 22, r6 | 3 states: not set, recording, set |
| Unset shortcut (↺) | 22×22, r6 | Resets key binding (only shown when shortcut is set) |
| Delete app (🗑) | 22×22, r6 | Opens delete confirmation overlay |
| Cancel button (X) | 22×22, r6 | Exits edit mode |

**Row padding**: horizontal 10, vertical 8. Corner radius: 12.

**Button Layout**: `[icon] [name] [badge] [↺] [🗑] [×]` — all action buttons are inline, no dropdown/popover.

**Shortcut Badge Area (3 states)**:

1. **Not Set**: "Not set" text + pencil icon button. Click pencil to start recording.
2. **Recording**: Amber dot (`#FFB547`) + "Record" text + X cancel. Background `#FFB547` @ 12.5%, border `#FFB547` @ 25%. Custom `ShortcutCaptureView` captures keyboard input.
3. **Set**: Key combo text (click to toggle enable/disable) + pencil icon (click to re-record).

**Cancel Edit**: `accessibilityIdentifier("cancel-edit")`. Returns to compact row.

**Unset Shortcut**: `accessibilityIdentifier("unset-shortcut")`. Only shown when a key binding exists. Resets key binding, preserves app entry. Focus returns to unset button position after action.

**Delete App**: `accessibilityIdentifier("delete-app")`. Opens delete confirmation overlay.

#### Delete Confirmation Overlay

A modal overlay within the panel showing:
- Trash icon in red circle
- "Remove [AppName]?" title
- Warning text about irreversibility
- Cancel and Remove buttons
- Remove button uses `.borderedProminent` style with destructive tint
- No default focus — buttons have no automatic keyboard focus on display

#### Duplicate Application Dialog

A modal overlay (same style as delete confirmation) shown when attempting to add an already-registered app:
- Warning triangle icon in orange circle
- "Duplicate Application" title
- "[name] has already been added." message
- OK button (`.borderedProminent` style) to dismiss
- Background interactions disabled while shown
- Esc key also dismisses the dialog

#### Add App Button

- Label: "+ Add App"
- Style: Full-width button with dashed border
- `.contentShape(Rectangle())` for full hit area
- Opens `NSOpenPanel` filtered to `.application`
- Duplicate detection by path and bundle ID
- Shows duplicate dialog on duplicate attempt

---

## Keyboard Navigation

Keypunch supports keyboard navigation within the standard settings window.

### Settings Window (SettingsPanelView)

**Focus Management**: `@FocusState` with `PanelFocus` enum controlling focus across all UI elements.

**Focus Targets** (PanelFocus enum):

| Case | Description |
|------|-------------|
| `.row(UUID)` | Compact row — Enter launches app |
| `.editButton(UUID)` | Edit (pencil) button on compact row — Enter enters edit mode |
| `.addApp` | Add App button — Enter opens file dialog |
| `.shortcutBadge(UUID)` | Shortcut badge in edit mode — Enter starts recording |
| `.shortcutEditButton(UUID)` | Pencil icon on set badge — Enter re-records |
| `.cancelEdit(UUID)` | Cancel (×) button in edit mode — Enter exits edit |
| `.dangerButton(UUID)` | Unset (↺) button in edit mode — Enter unsets shortcut |
| `.deleteButton(UUID)` | Delete (🗑) button in edit mode — Enter opens delete dialog |

**Tab Order** (edit mode): `shortcutBadge` → `dangerButton` (↺, if shortcut set) → `deleteButton` (🗑) → `cancelEdit` (×) → next row/addApp

**Arrow Key Navigation**: Up/Down arrows move between app rows (wrapping). In edit mode, arrows move to adjacent rows' edit-mode focus targets.

**Esc Handling** (layered `.onExitCommand`):
1. Duplicate dialog showing → dismiss it
2. Delete confirmation showing → dismiss, focus delete button
3. Recording shortcut → cancel recording
4. Edit mode → exit edit mode, focus the compact row

**Dialog Behavior**:
- While delete or duplicate dialog is showing, background panel content is `.disabled(true)` to prevent Tab focus leaking
- Delete dialog cancel → focus returns to delete button in edit card
- Esc from delete dialog → same behavior as cancel

---

## Window Management

### FloatingWidgetController

`@MainActor` controller that manages the menu bar and settings window.

#### Components

| Component | Class | Size | Purpose |
|-----------|-------|------|---------|
| Settings Window | `NSWindow` | 380×616 | Main shortcut configuration window |
| Status Item | `NSStatusItem` | Square | Menu bar icon with dropdown menu |

#### Show/Hide Logic

| Event | Action |
|-------|--------|
| "Show Keypunch" clicked | `makeKeyAndOrderFront` + `NSApp.activate()` |
| Window close button clicked | Standard window close behavior (`isReleasedWhenClosed = false`) |
| App reopen (Dock click) | Shows settings window |
| Test mode launch | Auto-shows settings window |

---

## Keyboard Shortcut Recording

### ShortcutCaptureView

A plain `NSView` subclass (not `NSSearchField`-based) to avoid ViewBridge disconnection errors in floating panels.

**Behavior**:
1. View becomes first responder via `window.makeFirstResponder(view)`
2. User presses modifier + key → `KeyboardShortcuts.setShortcut()` called
3. Escape → cancels recording
4. Resign first responder → cancels recording

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
- `applicationShouldHandleReopen` shows settings window when no visible windows

### Login Item Support

- Uses `SMAppService.mainApp` via `LoginItemManaging` protocol and `LoginItemService`
- Toggle via menu bar "Start at Login" item
- Checkmark shown when enabled (via `NSMenuDelegate.menuNeedsUpdate`)

---

## Test Mode

Mechanism to control app behavior during CI and test execution.

### Command Line Arguments

| Argument | UserDefaults Reset | Seed Data | Window Auto-Show |
|----------|--------------------|-----------|------------------|
| `-resetForTesting` | Yes | Yes (if env var present) | Yes |
| `-seedOnly` | Yes | Yes (if env var present) | No |
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
| Window display | Manual via menu bar | Auto-shown on launch |
| Panel display | All shortcuts shown | All shortcuts shown |
| UserDefaults | Normal operation | Reset on launch |

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

#### ShortcutStoreBehaviorTests (10 tests, serialized)

Uses mock implementations of `AppLaunching`, `ShortcutRegistering`, and `BundleProviding` protocols.

| Test | Verified Behavior |
|------|-------------------|
| `launchAppResolvesByBundleID` | Launch resolves app by bundle ID when available |
| `launchAppFallsBackToAppPath` | Falls back to appPath when bundle ID not resolvable |
| `launchAppFallsBackWhenNoBundleID` | Falls back to appPath when bundleIdentifier is nil |
| `launchAppSelfActivation` | Self-activation callback fires when launching own bundle |
| `removeShortcutResetsBinding` | Removing shortcut calls reset on registrar |
| `toggleDisabledRegistersNoopHandler` | Disabling registers an empty handler (preserves binding) |
| `conflictDetectionFindsConflict` | Detects conflicting shortcut across different names |
| `conflictDetectionNoConflictWhenExcluded` | No conflict when excluding the same name |
| `conflictDetectionNoConflictWhenDifferent` | No conflict for different key combinations |
| `unsetShortcutCallsReset` | Unsetting calls reset on registrar |

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
| `waitForWindow()` | Waits for the settings window (`keypunch-panel`) to appear |
| `openEditMode()` | Waits for window and clicks edit button on first row |

#### Window Tests (1 test)

| Test | Verified Behavior |
|------|-------------------|
| `testWindowAppearsInTestMode` | Settings window appears automatically in test mode |

#### Launch Tab Tests (4 tests)

| Test | Verified Behavior |
|------|-------------------|
| `testEmptyStatePanelContents` | Empty state shows "No shortcuts configured" |
| `testSeededShortcutAppearsInPanel` | Seeded shortcut appears in panel |
| `testMultipleSeededShortcutsAppearInPanel` | Multiple shortcuts appear |
| `testPanelShowsAppIcon` | App icon is displayed |

#### Shortcut Badge Tests (1 test)

| Test | Verified Behavior |
|------|-------------------|
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

#### App Launch Tests (1 test)

| Test | Verified Behavior |
|------|-------------------|
| `testPanelLaunchesApp` | Clicking app name launches TextEdit |

#### Launch Tab All Apps Tests (1 test)

| Test | Verified Behavior |
|------|-------------------|
| `testLaunchTabShowsAllAppsEvenWithoutShortcuts` | All apps shown even without key bindings (via menu bar) |

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

#### Keyboard Navigation Tests (6 tests)

| Test | Verified Behavior |
|------|-------------------|
| `testPanelRowsExistForKeyboardNavigation` | Rows and Add App button exist for keyboard navigation |
| `testKeyboardEscExitsEditModeBeforeDismissing` | First Esc exits edit mode, window remains visible |
| `testKeyboardEscDismissesDeleteConfirmation` | Esc dismisses delete confirmation, window remains |
| `testKeyboardEnterLaunchesApp` | Tab to focus row, Enter launches the app |
| `testKeyboardTabNavigatesBetweenRows` | Tab navigates to second row, Enter launches second app |
| `testKeyboardShiftTabNavigatesBackward` | Shift-Tab navigates backward, Enter launches first app |

#### Danger Dropdown Conditional Tests (1 test)

| Test | Verified Behavior |
|------|-------------------|
| `testUnsetButtonNotShownWhenNoShortcutSet` | Unset button hidden when no shortcut is bound |

#### Launch Tests (1 test)

| Test | Verified Behavior |
|------|-------------------|
| `testLaunch` | App launches and captures a screenshot |

### Test Count Summary

| Category | Count |
|----------|-------|
| Unit: AppShortcutTests | 12 |
| Unit: ShortcutStoreTests | 19 |
| Unit: ShortcutStoreBehaviorTests | 10 |
| UI: Window | 1 |
| UI: Launch Tab | 4 |
| UI: Shortcut Badge | 1 |
| UI: Edit Mode | 8 |
| UI: Edit Mode Badge & UI | 3 |
| UI: App Launch | 1 |
| UI: Launch Tab All Apps | 1 |
| UI: Compact Row | 2 |
| UI: Delete Confirmation Modal | 3 |
| UI: Recording Mode | 2 |
| UI: Add App | 1 |
| UI: Keyboard Navigation | 6 |
| UI: Danger Dropdown Conditional | 1 |
| UI: Launch | 1 |
| **Total** | **76** |

---

## CI/CD

### GitHub Actions Workflow

**File**: `.github/workflows/test.yml`
**Trigger**: `push` and `pull_request` (filtered by paths: `Keypunch/**`, `Keypunch.xcodeproj/**`, `KeypunchTests/**`, `KeypunchUITests/**`, `.github/workflows/test.yml`)

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

## License

MIT
