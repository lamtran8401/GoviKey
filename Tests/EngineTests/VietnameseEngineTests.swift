// VietnameseEngineTests.swift
// GoviKey Engine Tests
//
// Comprehensive test suite for Telex and VNI input methods.
// Tests cover: basic diacritics, tone marks, combined forms, restore/cycling,
// word composition, spelling, orthography, and edge cases.

import XCTest
@testable import Engine

// MARK: - Base

class EngineTestBase: XCTestCase {

    var engine: VietnameseEngine!

    override func setUp() {
        super.setUp()
        engine = VietnameseEngine()
        engine.config.inputType = .telex
        engine.config.checkSpelling = true
        engine.config.useModernOrthography = true
        engine.initialize()
    }

    // MARK: - Helpers

    @discardableResult
    func type(_ keys: String) -> EngineResult {
        var result = EngineResult.passThrough
        for ch in keys {
            let isCaps = ch.isUppercase
            let lower = ch.lowercased()
            guard let asciiVal = lower.first?.asciiValue else { continue }
            guard let keyCode = vnCharacterMap[UInt32(asciiVal)] else { continue }
            let kc = UInt16(keyCode & CHAR_MASK)
            result = engine.handleKeyEvent(
                event: .keyboard,
                state: .keyDown,
                keyCode: kc,
                capsStatus: isCaps ? 1 : 0,
                otherControlKey: false
            )
        }
        return result
    }

    @discardableResult
    func press(_ keyCode: UInt16, caps: UInt8 = 0) -> EngineResult {
        engine.handleKeyEvent(
            event: .keyboard, state: .keyDown,
            keyCode: keyCode, capsStatus: caps, otherControlKey: false
        )
    }

    /// Render the current engine buffer as a Unicode string.
    func output() -> String {
        var chars: [UInt16] = []
        for i in 0..<engine.idx {
            let code = engine.getCharacterCode(engine.typingWord[i])
            if (code & CHAR_CODE_MASK) != 0 {
                let v = UInt16(code & CHAR_MASK)
                if v > 0 { chars.append(v) }
            } else {
                let v = vnKeyCodeToCharacter(engine.typingWord[i])
                if v > 0 { chars.append(v) }
            }
        }
        return String(utf16CodeUnits: chars, count: chars.count)
    }
}

// MARK: - Telex Basic Tests

final class TelexBasicTests: EngineTestBase {

    // MARK: Diacritics — circumflex

    func testCircumflexA() {
        // aa → â
        type("aa")
        XCTAssertEqual(output(), "â")
    }

    func testCircumflexE() {
        // ee → ê
        type("ee")
        XCTAssertEqual(output(), "ê")
    }

    func testCircumflexO() {
        // oo → ô
        type("oo")
        XCTAssertEqual(output(), "ô")
    }

    // MARK: Diacritics — breve / horn

    func testBreveA() {
        // aw → ă
        type("aw")
        XCTAssertEqual(output(), "ă")
    }

    func testHornO() {
        // ow → ơ
        type("ow")
        XCTAssertEqual(output(), "ơ")
    }

    func testHornU() {
        // uw → ư
        type("uw")
        XCTAssertEqual(output(), "ư")
    }

    // MARK: Stroke D

    func testStrokedD() {
        // dd → đ
        type("dd")
        XCTAssertEqual(output(), "đ")
    }

    // MARK: Tone marks on plain 'a'

    func testSacOnA() {
        type("as")
        XCTAssertEqual(output(), "á")
    }

    func testHuyenOnA() {
        type("af")
        XCTAssertEqual(output(), "à")
    }

    func testHoiOnA() {
        type("ar")
        XCTAssertEqual(output(), "ả")
    }

    func testNgaOnA() {
        type("ax")
        XCTAssertEqual(output(), "ã")
    }

    func testNangOnA() {
        type("aj")
        XCTAssertEqual(output(), "ạ")
    }

    // MARK: Tone marks on â

    func testSacOnCircumflexA() {
        // aas → ấ
        type("aas")
        XCTAssertEqual(output(), "ấ")
    }

    func testHuyenOnCircumflexA() {
        type("aaf")
        XCTAssertEqual(output(), "ầ")
    }

    func testHoiOnCircumflexA() {
        type("aar")
        XCTAssertEqual(output(), "ẩ")
    }

    func testNgaOnCircumflexA() {
        type("aax")
        XCTAssertEqual(output(), "ẫ")
    }

    func testNangOnCircumflexA() {
        type("aaj")
        XCTAssertEqual(output(), "ậ")
    }

    // MARK: Tone marks on ă

    func testSacOnBreveA() {
        // aws → ắ
        type("aws")
        XCTAssertEqual(output(), "ắ")
    }

    func testHuyenOnBreveA() {
        type("awf")
        XCTAssertEqual(output(), "ằ")
    }

    func testHoiOnBreveA() {
        type("awr")
        XCTAssertEqual(output(), "ẳ")
    }

    func testNgaOnBreveA() {
        type("awx")
        XCTAssertEqual(output(), "ẵ")
    }

    func testNangOnBreveA() {
        type("awj")
        XCTAssertEqual(output(), "ặ")
    }

    // MARK: Tone marks on ê

    func testSacOnCircumflexE() {
        type("ees")
        XCTAssertEqual(output(), "ế")
    }

    func testHuyenOnCircumflexE() {
        type("eef")
        XCTAssertEqual(output(), "ề")
    }

    func testHoiOnCircumflexE() {
        type("eer")
        XCTAssertEqual(output(), "ể")
    }

    func testNgaOnCircumflexE() {
        type("eex")
        XCTAssertEqual(output(), "ễ")
    }

    func testNangOnCircumflexE() {
        type("eej")
        XCTAssertEqual(output(), "ệ")
    }

    // MARK: Tone marks on ô

    func testSacOnCircumflexO() {
        type("oos")
        XCTAssertEqual(output(), "ố")
    }

    func testHuyenOnCircumflexO() {
        type("oof")
        XCTAssertEqual(output(), "ồ")
    }

    func testHoiOnCircumflexO() {
        type("oor")
        XCTAssertEqual(output(), "ổ")
    }

    func testNgaOnCircumflexO() {
        type("oox")
        XCTAssertEqual(output(), "ỗ")
    }

    func testNangOnCircumflexO() {
        type("ooj")
        XCTAssertEqual(output(), "ộ")
    }

    // MARK: Tone marks on ơ

    func testSacOnHornO() {
        type("ows")
        XCTAssertEqual(output(), "ớ")
    }

    func testHuyenOnHornO() {
        type("owf")
        XCTAssertEqual(output(), "ờ")
    }

    func testHoiOnHornO() {
        type("owr")
        XCTAssertEqual(output(), "ở")
    }

    func testNgaOnHornO() {
        type("owx")
        XCTAssertEqual(output(), "ỡ")
    }

    func testNangOnHornO() {
        type("owj")
        XCTAssertEqual(output(), "ợ")
    }

    // MARK: Tone marks on ư

    func testSacOnHornU() {
        type("uws")
        XCTAssertEqual(output(), "ứ")
    }

    func testHuyenOnHornU() {
        type("uwf")
        XCTAssertEqual(output(), "ừ")
    }

    func testHoiOnHornU() {
        type("uwr")
        XCTAssertEqual(output(), "ử")
    }

    func testNgaOnHornU() {
        type("uwx")
        XCTAssertEqual(output(), "ữ")
    }

    func testNangOnHornU() {
        type("uwj")
        XCTAssertEqual(output(), "ự")
    }

    // MARK: Uppercase

    func testUppercaseA_Sac() {
        // "As" → Á
        type("As")
        XCTAssertEqual(output(), "Á")
    }

    func testUppercaseD_Stroked() {
        // "DD" → Đ
        type("DD")
        XCTAssertEqual(output(), "Đ")
    }

    func testUppercaseCircumflexA() {
        // "AA" → Â
        type("AA")
        XCTAssertEqual(output(), "Â")
    }

    // MARK: Passthrough

    func testNonSpecialKey_DoNothing() {
        let result = type("h")
        XCTAssertEqual(result.action, .doNothing)
        XCTAssertEqual(engine.idx, 1)
    }
}

// MARK: - Telex Restore / Cycling Tests

final class TelexRestoreTests: EngineTestBase {

    // MARK: Diacritic cycling

    func testCircumflexARestores() {
        // aa → â, then a → restore to "aa"
        type("aa")
        XCTAssertEqual(output(), "â")

        let r = type("a")
        XCTAssertEqual(r.action, .restore)
        XCTAssertEqual(r.backspaceCount, 1)
        XCTAssertEqual(r.newCharCount, 2)
        XCTAssertEqual(output(), "aa")
    }

    func testCircumflexERestores() {
        // ee → ê, then e → restore to "ee"
        type("ee")
        XCTAssertEqual(output(), "ê")

        let r = type("e")
        XCTAssertEqual(r.action, .restore)
        XCTAssertEqual(r.backspaceCount, 1)
        XCTAssertEqual(r.newCharCount, 2)
        XCTAssertEqual(output(), "ee")
    }

    func testCircumflexORestores() {
        // oo → ô, then o → restore to "oo"
        type("oo")
        XCTAssertEqual(output(), "ô")

        let r = type("o")
        XCTAssertEqual(r.action, .restore)
        XCTAssertEqual(r.backspaceCount, 1)
        XCTAssertEqual(r.newCharCount, 2)
        XCTAssertEqual(output(), "oo")
    }

    func testHornURestores() {
        // uw → ư, then w → restore to "uw"
        type("uw")
        XCTAssertEqual(output(), "ư")

        let r = type("w")
        XCTAssertEqual(r.action, .restore)
        XCTAssertEqual(r.backspaceCount, 1)
        XCTAssertEqual(r.newCharCount, 2)
        XCTAssertEqual(output(), "uw")
    }

    func testHornORestores() {
        // ow → ơ, then w → restore to "ow"
        type("ow")
        XCTAssertEqual(output(), "ơ")

        let r = type("w")
        XCTAssertEqual(r.action, .restore)
        XCTAssertEqual(r.backspaceCount, 1)
        XCTAssertEqual(r.newCharCount, 2)
        XCTAssertEqual(output(), "ow")
    }

    func testStrokedDRestores() {
        // dd → đ, then d → restore to "dd"
        type("dd")
        XCTAssertEqual(output(), "đ")

        let r = type("d")
        XCTAssertEqual(r.action, .restore)
        XCTAssertEqual(r.backspaceCount, 1)
        XCTAssertEqual(r.newCharCount, 2)
        XCTAssertEqual(output(), "dd")
    }

    // MARK: Restore does not re-cycle

    func testRestoreDoesNotRecycleO() {
        // oo → ô → ooo restores to "oo" → 4th 'o' appends raw (no re-transform)
        type("ooo")
        XCTAssertEqual(output(), "oo")

        type("o")
        XCTAssertEqual(output(), "ooo")
    }

    func testRestoreDoesNotRecycleU() {
        // uw → ư → uww restores to "uw" → 4th 'w' appends raw
        type("uww")
        XCTAssertEqual(output(), "uw")

        type("w")
        XCTAssertEqual(output(), "uww")
    }

    // MARK: Tone cycling

    func testSameToneKeyRemovesTone() {
        // "as" → á; then "s" again toggles the mark OFF (restore) and the 's'
        // is appended to the buffer, producing "as" raw.
        type("as")
        XCTAssertEqual(output(), "á")
        let r = type("s")
        XCTAssertEqual(r.action, .restore)
        XCTAssertEqual(r.backspaceCount, 1)
        XCTAssertEqual(r.newCharCount, 2)
        XCTAssertEqual(output(), "as")
    }

    // MARK: Circumflex + tone then restore circumflex

    func testCircumflexPlusToneThenBaseKey() {
        // "aas" → ấ, then "a" → restore circumflex → "áa"
        type("aas")
        XCTAssertEqual(output(), "ấ")

        let r = type("a")
        XCTAssertEqual(r.action, .restore)
        XCTAssertEqual(r.backspaceCount, 1)
        XCTAssertEqual(r.newCharCount, 2)
        XCTAssertEqual(output(), "áa")
    }

    func testBrevePlusToneCyclesToCircumflex() {
        // "aws" → ắ, then "a" → cycles breve→circumflex → ấ
        type("aws")
        XCTAssertEqual(output(), "ắ")

        let r = type("a")
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ấ")
    }

    // MARK: ESC restores raw keys

    func testEscRestoresRawKeys() {
        // Type Vietnamese, then ESC → restore to raw key sequence
        type("aa")                  // â
        XCTAssertEqual(output(), "â")

        let r = press(KEY_ESC)
        XCTAssertEqual(r.action, .restore)
        XCTAssertEqual(r.backspaceCount, 1)
        // Restored output should be 2 raw chars "aa"
        XCTAssertEqual(r.newCharCount, 2)
    }

    func testEscOnPlainTextNoOp() {
        // ESC with no transforms → does nothing
        type("abc")
        let r = press(KEY_ESC)
        XCTAssertEqual(r.action, .doNothing)
    }
}

// MARK: - Telex Word Tests

final class TelexWordTests: EngineTestBase {

    func testWordViet() {
        // "vieejt" → "việt"
        type("vieejt")
        XCTAssertEqual(output(), "việt")
    }

    func testWordDuong() {
        // "dduwowngf" → "đường"
        type("dduwowngf")
        XCTAssertEqual(output(), "đường")
    }

    func testWordNguoi() {
        // "nguowif" → "người"
        type("nguowif")
        XCTAssertEqual(output(), "người")
    }

    func testWordNam() {
        // "nam" → no transform
        type("nam")
        XCTAssertEqual(output(), "nam")
    }

    func testWordXin() {
        // "xin" → no transform
        type("xin")
        XCTAssertEqual(output(), "xin")
    }

    func testWordTieng() {
        // "tieengs" → "tiếng"
        type("tieengs")
        XCTAssertEqual(output(), "tiếng")
    }

    func testWordHanh() {
        // "hanjh" → "hạnh" (h + a + n + nặng + h = hạnh, no 'o')
        type("hanjh")
        XCTAssertEqual(output(), "hạnh")
    }

    func testWordChao() {
        // "chaof" → "chào"
        type("chaof")
        XCTAssertEqual(output(), "chào")
    }

    func testWordTuan() {
        // "tuaans" → "tuấn"
        type("tuaans")
        XCTAssertEqual(output(), "tuấn")
    }
}

// MARK: - Telex Modern Orthography Tests

final class TelexOrthographyTests: EngineTestBase {

    func testModernHoang() {
        // "hoangf" with modern orthography → "hoàng" (mark on 'a', not 'o')
        engine.config.useModernOrthography = true
        type("hoangf")
        XCTAssertEqual(output(), "hoàng")
    }

    func testModernThuong() {
        // "thuwowngf" → "thường"
        engine.config.useModernOrthography = true
        type("thuwowngf")
        XCTAssertEqual(output(), "thường")
    }

    func testOldHoangSameAsModern() {
        // "hoang" has the "oang" pattern with end consonant ng.
        // handleOldMark sets VWSM = VSI+1 when canHasEndConsonant() is true,
        // which places the mark on 'a' — same result as modern orthography.
        engine.config.useModernOrthography = false
        type("hoangf")
        XCTAssertEqual(output(), "hoàng")
    }
}

// MARK: - Telex Spelling Tests

final class TelexSpellingTests: EngineTestBase {

    func testValidWordDoesNotDisable() {
        engine.config.checkSpelling = true
        type("viet")
        XCTAssertFalse(engine.tempDisableKey)
    }

    func testInvalidSequenceDisablesKey() {
        // "fj" is not a valid Vietnamese consonant → tempDisableKey stays false
        // because unrecognised consonant starts are allowed through (spelling OK = true)
        engine.config.checkSpelling = true
        type("fj")
        // fj is not in vnConsonantTable → matched=false → j=spellingEndIndex → spellingOK=true
        XCTAssertFalse(engine.tempDisableKey)
    }

    func testSpellingCheckOff_NeverDisables() {
        engine.config.checkSpelling = false
        type("xzq")
        XCTAssertFalse(engine.tempDisableKey)
    }

    // MARK: Unrecognized consonant start blocks tone marks

    /// "featu" + "r": 'f' is not in vnConsonantTable → unrecognizedConsonantStart = true
    /// → 'r' (hỏi tone) must be blocked → output stays "featur", not "featủ".
    func testEnglishWordBlocksToneMark() {
        engine.config.checkSpelling = true
        type("featu")
        XCTAssertTrue(engine.unrecognizedConsonantStart, "English word start should set unrecognizedConsonantStart")
        let r = type("r")
        XCTAssertEqual(r.action, .doNothing, "Tone mark 'r' must be blocked for English words")
        XCTAssertEqual(output(), "featur")
    }

    /// Valid Vietnamese word — tone mark must still work normally.
    func testVietnameseWordAllowsToneMark() {
        engine.config.checkSpelling = true
        type("vie")
        XCTAssertFalse(engine.unrecognizedConsonantStart, "Valid Vietnamese consonant should not set flag")
        type("t")
        let r = type("j")   // nặng → ệ
        XCTAssertNotEqual(r.action, .doNothing, "Tone mark must apply for valid Vietnamese words")
    }

    // MARK: Restore on Space includes trailing Space

    /// "uwhen" + Space: spell check triggers restore → output must include trailing Space.
    /// "uw" → "ư" in the buffer (2 raw keystrokes), so restore replays all 5 raw keys
    /// (u, w, h, e, n) plus the Space = 6 chars total, giving "uwhen ".
    func testRestoreOnSpaceIncludesSpace() {
        engine.config.checkSpelling = true
        engine.config.restoreIfWrongSpelling = true
        // "uw" → "ư", then "hen" → buffer contains "ưhen" (invalid Vietnamese)
        type("uwhen")
        XCTAssertTrue(engine.tempDisableKey, "Invalid sequence should set tempDisableKey")

        let r = press(KEY_SPACE)
        XCTAssertEqual(r.action, .restore, "Space on invalid word should trigger restore")
        XCTAssertEqual(r.newCharCount, 6, "Output should be 6 chars: u-w-h-e-n-space")

        // Decode the output and verify it ends with a space
        let decoded = decodeResult(r)
        XCTAssertEqual(decoded, "uwhen ", "Restored output must replay raw keys and include trailing space")
    }

    // MARK: - Result decode helper

    private func decodeResult(_ result: EngineResult) -> String {
        guard result.newCharCount > 0 else { return "" }
        var chars: [UInt16] = []
        for i in stride(from: result.newCharCount - 1, through: 0, by: -1) {
            guard i < result.data.count else { continue }
            let raw = result.data[i]
            let ch: UInt16
            if (raw & PURE_CHARACTER_MASK) != 0 || (raw & CHAR_CODE_MASK) != 0 {
                ch = UInt16(raw & 0xFFFF)
            } else {
                ch = vnKeyCodeToCharacter(raw)
            }
            if ch > 0 { chars.append(ch) }
        }
        return String(utf16CodeUnits: chars, count: chars.count)
    }
}

// MARK: - Telex Quick Telex Tests

final class TelexQuickTelexTests: EngineTestBase {

    func testQuickTelexCC() {
        engine.config.quickTelex = true
        type("c")
        let r = type("c")
        // cc → ch
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(r.backspaceCount, 1)
        XCTAssertEqual(r.newCharCount, 2)
    }

    func testQuickTelexGG() {
        engine.config.quickTelex = true
        type("g")
        let r = type("g")
        // gg → gi
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(r.backspaceCount, 1)
        XCTAssertEqual(r.newCharCount, 2)
    }

    func testQuickTelexDisabledDoesNotExpand() {
        engine.config.quickTelex = false
        type("c")
        let r = type("c")
        // Without quickTelex, cc = doNothing (both chars inserted raw)
        XCTAssertEqual(r.action, .doNothing)
    }
}

// MARK: - Telex Engine State Tests

final class TelexEngineStateTests: EngineTestBase {

    func testResetClearsBuffer() {
        type("abc")
        XCTAssertEqual(engine.idx, 3)
        engine.resetSession()
        XCTAssertEqual(engine.idx, 0)
        XCTAssertEqual(engine.stateIdx, 0)
        XCTAssertFalse(engine.tempDisableKey)
    }

    func testDeleteDecreasesBuffer() {
        type("vie")
        XCTAssertEqual(engine.idx, 3)
        press(KEY_DELETE)
        XCTAssertEqual(engine.idx, 2)
    }

    func testDeleteOnEmptyBuffer() {
        let r = press(KEY_DELETE)
        XCTAssertEqual(r.action, .doNothing)
        XCTAssertEqual(engine.idx, 0)
    }

    func testWordBreakOnCommaResetsBuffer() {
        type("viet")
        XCTAssertEqual(engine.idx, 4)
        press(KEY_COMMA)
        XCTAssertEqual(engine.idx, 0)
    }

    func testWordBreakOnSpaceDoesNotResetIdx() {
        // Space is handled separately; idx is not cleared until next non-space key
        type("viet")
        press(KEY_SPACE)
        // Space increments spaceCount but does not clear idx immediately
        XCTAssertEqual(engine.spaceCount, 1)
    }

    func testUppercaseCapsMaskSet() {
        press(KEY_A, caps: 1)
        XCTAssertTrue((engine.typingWord[0] & CAPS_MASK) != 0)
    }

    func testEmptyBufferDeleteIsDoNothing() {
        let r = press(KEY_DELETE)
        XCTAssertEqual(r.action, .doNothing)
    }
}

// MARK: - VNI Basic Tests

final class VNIBasicTests: EngineTestBase {

    override func setUp() {
        super.setUp()
        engine.config.inputType = .vni
        engine.resetSession()
    }

    // MARK: Tones (1-5)

    func testSacOnA() {
        // a + 1 → á
        type("a")
        let r = press(KEY_1)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "á")
    }

    func testHuyenOnA() {
        // a + 2 → à
        type("a")
        let r = press(KEY_2)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "à")
    }

    func testHoiOnA() {
        // a + 3 → ả
        type("a")
        let r = press(KEY_3)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ả")
    }

    func testNgaOnA() {
        // a + 4 → ã
        type("a")
        let r = press(KEY_4)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ã")
    }

    func testNangOnA() {
        // a + 5 → ạ
        type("a")
        let r = press(KEY_5)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ạ")
    }

    // MARK: Diacritics (6, 7, 8, 9)

    func testCircumflexA() {
        // a + 6 → â
        type("a")
        let r = press(KEY_6)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "â")
    }

    func testCircumflexE() {
        // e + 6 → ê
        type("e")
        let r = press(KEY_6)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ê")
    }

    func testCircumflexO() {
        // o + 6 → ô
        type("o")
        let r = press(KEY_6)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ô")
    }

    func testBreveA() {
        // a + 8 → ă
        type("a")
        let r = press(KEY_8)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ă")
    }

    func testHornO() {
        // o + 7 → ơ
        type("o")
        let r = press(KEY_7)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ơ")
    }

    func testHornU() {
        // u + 7 → ư
        type("u")
        let r = press(KEY_7)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ư")
    }

    func testStrokedD() {
        // d + 9 → đ
        type("d")
        let r = press(KEY_9)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "đ")
    }

    // MARK: Combined diacritic + tone

    func testCircumflexA_Sac() {
        // a + 6 + 1 → ấ
        type("a")
        press(KEY_6)
        let r = press(KEY_1)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ấ")
    }

    func testCircumflexA_Huyen() {
        type("a")
        press(KEY_6)
        press(KEY_2)
        XCTAssertEqual(output(), "ầ")
    }

    func testCircumflexA_Hoi() {
        type("a")
        press(KEY_6)
        press(KEY_3)
        XCTAssertEqual(output(), "ẩ")
    }

    func testCircumflexA_Nga() {
        type("a")
        press(KEY_6)
        press(KEY_4)
        XCTAssertEqual(output(), "ẫ")
    }

    func testCircumflexA_Nang() {
        type("a")
        press(KEY_6)
        press(KEY_5)
        XCTAssertEqual(output(), "ậ")
    }

    func testBreveA_Sac() {
        // a + 8 + 1 → ắ
        type("a")
        press(KEY_8)
        let r = press(KEY_1)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ắ")
    }

    func testHornO_Sac() {
        // o + 7 + 1 → ớ
        type("o")
        press(KEY_7)
        let r = press(KEY_1)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ớ")
    }

    func testHornU_Sac() {
        // u + 7 + 1 → ứ
        type("u")
        press(KEY_7)
        let r = press(KEY_1)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ứ")
    }

    func testCircumflexE_Nang() {
        // e + 6 + 5 → ệ
        type("e")
        press(KEY_6)
        let r = press(KEY_5)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ệ")
    }

    func testCircumflexO_Hoi() {
        // o + 6 + 3 → ổ
        type("o")
        press(KEY_6)
        let r = press(KEY_3)
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ổ")
    }

    // MARK: Stroke restore

    func testStrokedDRestores() {
        // d + 9 → đ, then 9 → restore.
        // In VNI the raw key sequence is [d, 9] (not "dd"), so output is "d9".
        type("d")
        press(KEY_9)
        XCTAssertEqual(output(), "đ")

        let r = press(KEY_9)
        XCTAssertEqual(r.action, .restore)
        XCTAssertEqual(output(), "d9")
    }

    // MARK: Number at start = word break

    func testNumberAtStartIsWordBreak() {
        // If idx == 0 and we type a number, it is treated as a word break (passthrough)
        let r = press(KEY_1)
        XCTAssertEqual(r.action, .doNothing)
        XCTAssertEqual(engine.idx, 0)
    }
}

// MARK: - VNI Word Tests

final class VNIWordTests: EngineTestBase {

    override func setUp() {
        super.setUp()
        engine.config.inputType = .vni
        engine.resetSession()
    }

    func testWordViet() {
        // v i e 6 t 5 → "việt"
        type("vie")
        press(KEY_6)   // ê
        type("t")
        press(KEY_5)   // nặng → ệ
        XCTAssertEqual(output(), "việt")
    }

    func testWordOn() {
        // o 6 n 3 → "ổn"
        type("o")
        press(KEY_6)   // ô
        type("n")
        press(KEY_3)   // hỏi → ổ
        XCTAssertEqual(output(), "ổn")
    }

    func testWordUng() {
        // u 7 n g 1 → "ứng"
        type("u")
        press(KEY_7)   // ư
        type("ng")
        press(KEY_1)   // sắc → ứ
        XCTAssertEqual(output(), "ứng")
    }

    func testWordDo() {
        // d 9 o 1 → "đó"
        type("d")
        press(KEY_9)   // đ
        type("o")
        press(KEY_1)   // sắc → ó
        XCTAssertEqual(output(), "đó")
    }
}

// MARK: - W Key As Letter Tests

final class WKeyAsLetterTests: EngineTestBase {

    override func setUp() {
        super.setUp()
        engine.config.wKeyAsLetter = true
        engine.resetSession()
    }

    func testWAloneProducesUHorn() {
        // w → ư (standalone)
        let r = type("w")
        XCTAssertEqual(r.action, .willProcess)
        XCTAssertEqual(output(), "ư")
    }

    // MARK: Feature ON — w at start → ư; consonant+w and vowel modifier unchanged

    func testWAloneGivesUHornWhenOn() {
        type("w")
        XCTAssertEqual(output(), "ư")
    }

    func testOWGivesOHornWhenOn() {
        type("ow")
        XCTAssertEqual(output(), "ơ")
    }

    func testAWGivesABreveWhenOn() {
        type("aw")
        XCTAssertEqual(output(), "ă")
    }

    // MARK: Feature OFF — w alone → plain 'w'; consonant+w still → ư; vowel modifier unchanged

    func testWAloneGivesPlainWWhenOff() {
        engine.config.wKeyAsLetter = false
        engine.resetSession()
        type("w")
        XCTAssertEqual(output(), "w")
    }

    func testOWGivesOHornWhenOff() {
        engine.config.wKeyAsLetter = false
        engine.resetSession()
        type("ow")
        XCTAssertEqual(output(), "ơ")
    }

    func testAWGivesABreveWhenOff() {
        engine.config.wKeyAsLetter = false
        engine.resetSession()
        type("aw")
        XCTAssertEqual(output(), "ă")
    }

    // MARK: Consonant + w always → ư (same for ON and OFF)

    func testConsonantWAlwaysGivesUHorn() {
        // lw → lư regardless of feature flag
        type("lw")
        XCTAssertEqual(output(), "lư", "Feature ON: lw → lư")

        engine.config.wKeyAsLetter = false
        engine.resetSession()
        type("lw")
        XCTAssertEqual(output(), "lư", "Feature OFF: lw → lư")
    }

    func testLongConsonantWAlwaysGivesUHorn() {
        // nghw → nghư regardless of feature flag
        type("nghw")
        XCTAssertEqual(output(), "nghư", "Feature ON: nghw → nghư")

        engine.config.wKeyAsLetter = false
        engine.resetSession()
        type("nghw")
        XCTAssertEqual(output(), "nghư", "Feature OFF: nghw → nghư")
    }
}
