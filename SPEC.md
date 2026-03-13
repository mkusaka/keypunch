# Keypunch — Specification

> Japanese version: [SPEC.ja.md](./SPEC.ja.md)

## Overview

Keypunch is a macOS menu bar application that registers global keyboard shortcuts to launch applications. It runs without a Dock icon — all interactions happen through the keyboard icon in the menu bar.

## System Requirements

| Item | Requirement |
|------|-------------|
| OS | macOS 15.0+ |
| Xcode | 16+ |
| Swift | 5.0 |
| Sandbox | Enabled (App Sandbox) |
| File Access | Read-only for user-selected files |

## Architecture

### Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | SwiftUI (`MenuBarExtra` + `Settings`) |
| Global Hotkeys | [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) v2.4.0 |
| State Management | `@Observable` (Swift Observation) |
| Data Persistence | UserDefaults (JSON encoding) |
| App Launching | NSWorkspace |

### App Configuration

| Item | Value |
|------|-------|
| Bundle Identifier | `com.mkusaka.Keypunch` |
| LSUIElement | `YES` (hidden from Dock) |
| Menu Bar Icon | SF Symbols `keyboard` |

### File Structure

```
Keypunch/
├── KeypunchApp.swift          # Entry point, test mode control
├── Models/
│   └── AppShortcut.swift      # Shortcut data model
├── ShortcutStore.swift        # State management, persistence, app launching
├── Views/
│   ├── MenuBarView.swift      # Menu bar dropdown
│   ├── SettingsView.swift     # Settings window (master-detail)
│   └── ShortcutEditView.swift # Shortcut edit form
└── Keypunch.entitlements      # Sandbox configuration

KeypunchTests/
└── KeypunchTests.swift        # Unit tests (Swift Testing)

KeypunchUITests/
├── KeypunchUITests.swift      # UI tests (XCTest)
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
| `name` | `String` | — | Display name (user-editable) |
| `bundleIdentifier` | `String?` | — | macOS bundle ID (e.g., `com.apple.calculator`) |
| `appPath` | `String` | — | Full file system path to the application |
| `shortcutName` | `String` | `"appShortcut_\(id)"` | Unique name for KeyboardShortcuts library registration |

**Computed Properties**:

| Property | Type | Description |
|----------|------|-------------|
| `keyboardShortcutName` | `KeyboardShortcuts.Name` | Name object for library integration |
| `appURL` | `URL` | File URL generated from `appPath` |

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

**Note**: The actual keyboard shortcut key bindings are persisted independently by the KeyboardShortcuts library in its own UserDefaults entries. ShortcutStore only saves app metadata (name, path, bundle ID, shortcut name).

#### Public Methods

| Method | Description |
|--------|-------------|
| `addShortcut(_:)` | Adds a shortcut, registers its handler, and persists to disk |
| `removeShortcut(_:)` | Removes a shortcut, resets its key binding, and persists |
| `removeShortcuts(at:)` | Batch-removes shortcuts by `IndexSet` |
| `updateShortcut(_:)` | Updates an existing shortcut by ID. Resets old key binding if `shortcutName` changed |
| `containsApp(path:)` | Checks if an app at the given path is already registered |
| `containsApp(bundleIdentifier:)` | Checks if an app with the given bundle ID is already registered |
| `launchApp(for:)` | Launches the target application |

#### App Launch Logic

`launchApp(for:)` resolves the application in the following priority order:

1. If `bundleIdentifier` is non-nil and resolvable via `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)` — launch using that URL
2. Fallback: convert `appPath` to a URL and launch

Both paths use `NSWorkspace.shared.openApplication(at:configuration:)`.

#### Handler Registration

- `KeyboardShortcuts.onKeyUp(for:)` registers a callback when `addShortcut` is called
- The callback invokes `launchApp(for:)` to launch the target app
- On `init()`, handlers are registered for all loaded shortcuts in bulk

---

## UI Components

### 1. MenuBarExtra (Menu Bar Dropdown)

**Icon**: SF Symbols `keyboard`
**Title**: "Keypunch"

#### Menu Layout

```
┌──────────────────────────────────┐
│ [icon] Calculator     ⌘⇧C       │  ← shortcut assigned: visible
│ [icon] Safari         ⌥⇧S       │
│──────────────────────────────────│
│ Settings...               ⌘,    │
│ Quit Keypunch             ⌘Q    │
└──────────────────────────────────┘
```

**When no shortcuts are registered**:

```
┌──────────────────────────────────┐
│ No shortcuts configured         │  ← disabled
│──────────────────────────────────│
│ Settings...               ⌘,    │
│ Quit Keypunch             ⌘Q    │
└──────────────────────────────────┘
```

#### Display Rules

| Condition | Display |
|-----------|---------|
| One or more shortcuts with key bindings assigned | Icon + app name + shortcut key |
| No shortcuts, or all shortcuts without key bindings | "No shortcuts configured" (disabled) |

#### Filtering

- **Normal mode**: Only shortcuts where `KeyboardShortcuts.getShortcut(for:) != nil` are displayed
- **Test mode** (`showAllForTesting = true`): All shortcuts are displayed regardless of key binding status

#### Menu Item Composition

Each shortcut row contains the following elements:

| Element | Source | Notes |
|---------|--------|-------|
| App icon | `NSWorkspace.shared.icon(forFile: appPath)` | Returns a generic icon even if the path is invalid |
| App name | `shortcut.name` | |
| Shortcut key | `KeyboardShortcuts.getShortcut(for:)?.description` | Hidden when not assigned |

#### Actions

| Action | Behavior |
|--------|----------|
| Click a shortcut row | Launches the target application |
| Click "Settings..." | Opens the Settings window |
| Click "Quit Keypunch" | Terminates the application |

---

### 2. Settings Window

**Window Title**: "Keypunch Settings"
**Minimum Size**: 550 x 300

Master-detail layout using `HSplitView`.

#### Left Pane: Sidebar

**Width**: 220pt (fixed)

```
┌─────────────────────────────┐
│ [icon] Calculator    ⌘⇧C   │  ← selected
│ [icon] Safari        ⌥⇧S   │
│ [icon] TextEdit             │  ← no key binding set
│                             │
│                             │
│ [+] [-]                     │  ← toolbar
└─────────────────────────────┘
```

**Row Composition**:

| Element | Size | Description |
|---------|------|-------------|
| App icon | 18x18 | `NSWorkspace.shared.icon(forFile:)` |
| App name | — | `shortcut.name` |
| Shortcut key | — | Secondary color, `.callout` font. Hidden when not assigned |

**Toolbar Buttons**:

| Button | Icon | Action | State |
|--------|------|--------|-------|
| `+` (Add) | `plus` | Opens NSOpenPanel | Always enabled |
| `-` (Remove) | `minus` | Removes the selected shortcut | Disabled when nothing is selected |

#### Right Pane: Detail

**Minimum Width**: 300pt

**When no shortcut is selected**:
```
Select a shortcut or add a new one
```

**When a shortcut is selected** (ShortcutEditView):

```
┌─────────────────────────────────┐
│  Name:        [Calculator    ]  │  ← editable text field
│  Application: /System/Applic... │  ← read-only, middle truncation
│  Bundle ID:   com.apple.calc... │  ← hidden if bundleIdentifier is nil
│  Shortcut:    [Record Shortcut] │  ← KeyboardShortcuts.Recorder
└─────────────────────────────────┘
```

**ShortcutEditView Fields**:

| Field | Type | Editable | Notes |
|-------|------|----------|-------|
| Name | TextField | Yes | Calls `store.updateShortcut` on `onSubmit` |
| Application | LabeledContent | No | `.truncationMode(.middle)` for middle ellipsis |
| Bundle ID | LabeledContent | No | Entire row hidden if `bundleIdentifier` is nil |
| Shortcut | KeyboardShortcuts.Recorder | Yes | Library-provided recording widget |

---

### 3. Add Shortcut Flow

1. User clicks the `+` button
2. `NSOpenPanel` opens
   - `allowedContentTypes`: `.application`
   - `directoryURL`: `/Applications`
   - `allowsMultipleSelection`: `false`
3. User selects an application
4. The following information is extracted:
   - `appName`: file name with `.app` extension removed
   - `appPath`: full file path
   - `bundleIdentifier`: `Bundle(path:)?.bundleIdentifier`
5. **Duplicate check**:
   - `store.containsApp(path: appPath)` — check by path
   - `bundleIdentifier != nil && store.containsApp(bundleIdentifier: bundleIdentifier!)` — check by bundle ID
6. If duplicate: show "Duplicate Application" alert (`"\(appName) has already been added."`)
7. If not duplicate: create `AppShortcut` and add via `store.addShortcut()`

---

### 4. Remove Shortcut Flow

1. Select a shortcut in the sidebar
2. Click the `-` button
3. `store.removeShortcut()` is called
4. Key binding is reset and removed from UserDefaults
5. `selectedShortcut` returns to nil, detail pane shows placeholder

---

## Test Mode

Mechanism to control app behavior during CI and test execution.

### Command Line Arguments

| Argument | UserDefaults Reset | Seed Data | Test Mode (Filter Bypass) |
|----------|--------------------|-----------|---------------------------|
| `-resetForTesting` | Yes | Yes (if env var present) | Yes (`showAllForTesting = true`) |
| `-seedOnly` | Yes | Yes (if env var present) | No (normal filter behavior) |
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
| Menu bar display | Only shows shortcuts with key bindings | Shows all shortcuts |
| Settings window | No change | No change |
| UserDefaults | Normal operation | Reset on launch |

---

## Testing

### Unit Tests (Swift Testing)

Framework: `@Test`, `#expect` (Swift Testing)
Test UserDefaults: isolated per test with unique `suiteName`

#### AppShortcutTests (7 tests)

| Test | Verified Behavior |
|------|-------------------|
| `initWithDefaults` | Default initialization sets correct properties |
| `initWithCustomShortcutName` | Custom shortcutName is preserved |
| `initWithNilBundleIdentifier` | nil bundleIdentifier is accepted |
| `codableRoundTrip` | Single shortcut JSON encode/decode is accurate |
| `codableRoundTripArray` | Array JSON encode/decode is accurate |
| `hashableConformance` | Shortcuts with same ID are equal and hash identically |
| `uniqueIdsOnCreation` | Each new instance gets a unique ID and shortcutName |

#### ShortcutStoreTests (10 tests, serialized)

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
| `containsAppByBundleIdentifierWithNilBundleIDs` | nil bundle IDs don't cause false positives |

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
| `openMenu()` | Clicks the status bar item and returns the menu |
| `openSettings()` | Opens the settings window via the menu |

#### Menu Bar Tests (4 tests)

| Test | Verified Behavior |
|------|-------------------|
| `testMenuBarItemExists` | Status item appears in the menu bar |
| `testEmptyStateMenuContents` | Empty state shows "No shortcuts configured", Settings, Quit |
| `testSeededShortcutAppearsInMenu` | Seeded shortcut appears in menu (test mode) |
| `testMultipleSeededShortcutsAppearInMenu` | Multiple shortcuts appear in menu |

#### Settings Window Tests (6 tests)

| Test | Verified Behavior |
|------|-------------------|
| `testSettingsWindowOpens` | Settings window opens |
| `testSettingsShowsEmptyStateMessage` | Empty state placeholder text is shown |
| `testSettingsShowsSeededShortcut` | Seeded data appears in the list |
| `testSettingsSelectShortcutShowsEditView` | Selecting shows edit fields (Name, Application, Bundle ID, Shortcut) |
| `testSettingsDeleteShortcut` | Minus button removes shortcut and returns to placeholder |
| `testSettingsAddButtonExists` | +/- buttons exist with correct initial states |

#### Display Tests (4 tests)

| Test | Verified Behavior |
|------|-------------------|
| `testMenuItemWithIconExists` | Menu item exists with icon |
| `testSettingsSidebarShowsAppIcon` | Sidebar displays app icon images |
| `testMenuHidesItemsWithoutShortcuts` | Normal mode hides apps without key bindings |
| `testSettingsSidebarWidthConsistency` | Sidebar width remains consistent regardless of selection (within 2pt tolerance) |

#### App Launch Tests (1 test)

| Test | Verified Behavior |
|------|-------------------|
| `testMenuLaunchesApp` | Clicking a menu item launches the target app (TextEdit) |

#### Launch Tests (1 test)

| Test | Verified Behavior |
|------|-------------------|
| `testLaunch` | App launches and captures a screenshot |

### Test Count Summary

| Category | Count |
|----------|-------|
| Unit: AppShortcutTests | 7 |
| Unit: ShortcutStoreTests | 10 |
| UI: Menu Bar | 4 |
| UI: Settings Window | 6 |
| UI: Display | 4 |
| UI: App Launch | 1 |
| UI: Launch | 1 |
| **Total** | **33** |

---

## CI/CD

### GitHub Actions Workflow

**File**: `.github/workflows/test.yml`
**Trigger**: `push` (all branches, no filter)

| Job | Runner | Target | continue-on-error |
|-----|--------|--------|-------------------|
| Unit Tests | `macos-15` | `KeypunchTests` | `false` |
| UI Tests | `macos-15` | `KeypunchUITests` | `true` |

**Actions**: `actions/checkout` is pinned to a commit hash via pinact.

**Note**: UI Tests run with `continue-on-error: true`. Since stability is not fully guaranteed in macOS CI environments, UI test failures do not fail the overall workflow.

---

## Security

### App Sandbox

| Entitlement | Value | Purpose |
|-------------|-------|---------|
| `com.apple.security.app-sandbox` | `true` | Sandbox enabled |
| `com.apple.security.files.user-selected.read-only` | `true` | App selection via NSOpenPanel |

### KeyboardShortcuts Library

- Requires Accessibility permission
- Users are prompted to grant Accessibility access in System Settings for global hotkey registration

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | 2.4.0 (>=2.2.2) | Global keyboard shortcut registration and management |

---

## Known Limitations

1. **MenuBarExtra Icons**: Icons set via `Image(nsImage:)` are not accessible as child elements in XCUITest's accessibility tree. Only the existence of the menu item itself can be tested.
2. **Zombie Processes**: If a zombie process remains after an Xcode debug session, XCUITest's tearDown will fail with a termination error. `resilientLaunch()` mitigates this, but fully resolving it requires stopping Xcode.
3. **Shortcut Key Display**: The shortcut key display in the menu bar uses `KeyboardShortcuts.getShortcut(for:)?.description` (a plain string), which differs from the native `keyboardShortcut` modifier.

## License

MIT
