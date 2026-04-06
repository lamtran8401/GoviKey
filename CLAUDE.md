# VietKey

Vietnamese input method (IME) for macOS. Pure Swift, CGEventTap-based.
Supports Telex and VNI input methods. macOS 13+.

## Build & Test

```bash
swift build          # Build all targets
swift test           # Run engine tests (34 tests)
swift run VietKey    # Run the app (requires Accessibility permission)
```

## Project Structure

```
Sources/
  Engine/
    VietnameseEngine.swift   # Core state machine: handleKeyEvent() -> EngineResult
    VietnameseData.swift     # Key codes, bit masks, vowel/consonant tables (~655 lines)
    EngineResult.swift       # EngineResult value type + EngineConfig settings struct
  EventTap/
    EventRouter.swift        # InputController: owns engine + sender, C callback dispatcher
    EventTapManager.swift    # CGEventTap lifecycle (HID tap -> session tap fallback)
    KeyEventSender.swift     # Synthetic backspaces + Unicode output via CGEvent
    EventMarker.swift        # Self-event detection (0x564B4559 "VKEY" marker)
  App/
    VietKeyApp.swift         # NSStatusItem menu bar app (LSUIElement, no dock icon)
Tests/
  EngineTests/               # Unit tests for engine (Telex, VNI, tones, spelling, orthography)
```

## Architecture

### Three-layer design

1. **Engine** (pure Swift, no system deps) — State machine with UInt32 bit-packed typing buffer. Returns `EngineResult` value type (action + backspaceCount + newCharCount + data). No I/O, no globals.
2. **EventTap** — CGEventTap at HID level. `InputController` bridges C callback to engine, sends output via `KeyEventSender`. Self-events skipped via `eventSourceUserData` marker.
3. **App** — NSApplication + NSStatusItem ("Vi"/"En" indicator). Menu for input method, spelling, orthography toggles.

### Data flow

```
CGEventTap callback
  -> skip self-events (EventMarker check)
  -> re-enable if tap disabled by system
  -> keyDown only, Vietnamese mode only
  -> InputController.handleKeyDown()
       -> engine.handleKeyEvent(keyCode, capsStatus)
       -> EngineResult { action, backspaceCount, newCharCount, data[] }
       -> sender.sendBackspaces() + sender.sendUnicodeString()  // NFC precomposed
```

### Engine internals

- **Buffer**: `[UInt32]` of size `ENGINE_MAX_BUFF` (32). Each element is bit-packed:
  - Bits 0-15: character/key code (`CHAR_MASK = 0xFFFF`)
  - Bit 16: caps (`CAPS_MASK`)
  - Bit 17: has tone (`TONE_MASK`)
  - Bit 18: tone-w marker (`TONEW_MASK`)
  - Bits 19-23: vowel mark type (`MARK1_MASK` through `MARK5_MASK`, combined `MARK_MASK`)
  - Bit 30: char code flag (`CHAR_CODE_MASK`)
  - Bit 31: pure character flag (`PURE_CHARACTER_MASK`)
- **Actions**: `doNothing` (passthrough), `willProcess` (replace chars), `restore` (undo Vietnamese), `breakWord` (word boundary)
- **Telex processing keys**: S, F, R, X, J (tones) + A, O, E, W (marks) + D (stroke) + Z (undo)
- **VNI processing keys**: 1-9, 0

### EngineResult decoding

Engine data values are decoded in `decodeEngineChar()`:
1. `PURE_CHARACTER_MASK` set -> raw Unicode in lower 16 bits
2. `CHAR_CODE_MASK` set -> resolved Unicode in lower 16 bits
3. Neither -> raw key code, look up via `vnKeyCodeToCharacter()`

Output is converted to NFC precomposed Unicode (`precomposedStringWithCanonicalMapping`) for app compatibility.

## Conventions

- `@inline(__always)` on hot-path engine helpers
- Engine returns value types; caller handles all I/O
- Synthetic events marked with `EventMarker.vietKey` on `eventSourceUserData`
- Key codes use Mac virtual key codes (not ASCII) — e.g., `KEY_A = 0`, `KEY_S = 1`
- `EngineConfig` struct replaces PHTV's C bridge calls for runtime settings
- Test helper `type("string")` simulates keystrokes through the engine

## Planned (not yet implemented)

- Phase 3: Spotlight fix (AX-based text replacement), app classification
- Phase 4: Game mode (2-tier callback, <100us fast path, no AX)
- Phase 5: SwiftUI settings, hotkeys, onboarding
- Phase 6: Code signing, notarization, distribution
