// VietnameseEngineTests.swift
// GoviKey Engine Tests

import XCTest
@testable import Engine

final class VietnameseEngineTests: XCTestCase {

    var engine: VietnameseEngine!

    override func setUp() {
        super.setUp()
        engine = VietnameseEngine()
        engine.config.inputType = .telex
        engine.config.checkSpelling = true
        engine.config.useModernOrthography = true
        engine.initialize()
    }

    // MARK: - Helper

    /// Simulate typing a string and return the last result.
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

    /// Get the composed output as Unicode string from engine state.
    func composedOutput() -> String {
        var chars: [UInt16] = []
        for i in 0..<engine.idx {
            let code = engine.getCharacterCode(engine.typingWord[i])
            if (code & CHAR_CODE_MASK) != 0 {
                let charVal = UInt16(code & CHAR_MASK)
                if charVal > 0 {
                    chars.append(charVal)
                }
            } else {
                let raw = vnKeyCodeToCharacter(engine.typingWord[i])
                if raw > 0 { chars.append(raw) }
            }
        }
        return String(utf16CodeUnits: chars, count: chars.count)
    }

    // MARK: - Basic Telex Tests

    func testSimpleLetterPassThrough() {
        let result = type("h")
        XCTAssertEqual(result.action, .doNothing)
        XCTAssertEqual(engine.idx, 1)
    }

    func testTelexCircumflexA() {
        // "aa" -> â
        _ = type("a")
        let result = type("a")
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "â")
    }

    func testTelexCircumflexE() {
        // "ee" -> ê
        _ = type("e")
        let result = type("e")
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "ê")
    }

    func testTelexCircumflexO() {
        // "oo" -> ô
        _ = type("o")
        let result = type("o")
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "ô")
    }

    func testTelexBreveA() {
        // "aw" -> ă
        _ = type("a")
        let result = type("w")
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "ă")
    }

    func testTelexHornO() {
        // "ow" -> ơ (standalone)
        _ = type("o")
        let result = type("w")
        XCTAssertEqual(result.action, .willProcess)
    }

    func testTelexHornU() {
        // "uw" -> ư (standalone)
        _ = type("u")
        let result = type("w")
        XCTAssertEqual(result.action, .willProcess)
    }

    func testTelexStrokedD() {
        // "dd" -> đ
        _ = type("d")
        let result = type("d")
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "đ")
    }

    // MARK: - Tone Mark Tests (Telex)

    func testTelexSacTone() {
        // "as" -> á
        _ = type("a")
        let result = type("s")
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "á")
    }

    func testTelexHuyenTone() {
        // "af" -> à
        _ = type("a")
        let result = type("f")
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "à")
    }

    func testTelexHoiTone() {
        // "ar" -> ả
        _ = type("a")
        let result = type("r")
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "ả")
    }

    func testTelexNgaTone() {
        // "ax" -> ã
        _ = type("a")
        let result = type("x")
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "ã")
    }

    func testTelexNangTone() {
        // "aj" -> ạ
        _ = type("a")
        let result = type("j")
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "ạ")
    }

    // MARK: - Combined vowel + tone tests

    func testTelexCircumflexWithTone() {
        // "aas" -> ấ
        engine.resetSession()
        _ = type("a")
        _ = type("a")
        let result = type("s")
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "ấ")
    }

    func testTelexBreveWithTone() {
        // "aws" -> ắ
        engine.resetSession()
        _ = type("a")
        _ = type("w")
        let result = type("s")
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "ắ")
    }

    // MARK: - Word composition tests

    func testVietnameseWordViet() {
        // "vieejt" -> việt
        engine.resetSession()
        _ = type("vieejt")
        let output = composedOutput()
        XCTAssertEqual(output, "việt")
    }

    func testVietnameseWordNam() {
        // "nam" -> nam (no transformation)
        engine.resetSession()
        _ = type("nam")
        let output = composedOutput()
        XCTAssertEqual(output, "nam")
    }

    func testVietnameseWordXinChao() {
        // "xin" -> xin
        engine.resetSession()
        _ = type("xin")
        let output = composedOutput()
        XCTAssertEqual(output, "xin")
    }

    func testVietnameseWordDuong() {
        // "dduwowngf" -> đường
        engine.resetSession()
        _ = type("dduwowngf")
        let output = composedOutput()
        XCTAssertEqual(output, "đường")
    }

    func testVietnameseWordNguoi() {
        // "nguowif" -> người
        engine.resetSession()
        _ = type("nguowif")
        let output = composedOutput()
        XCTAssertEqual(output, "người")
    }

    // MARK: - Toggle behavior tests

    func testTelexDoubleToggle() {
        // "aas" -> ấ, then "s" again should remove the mark
        engine.resetSession()
        _ = type("aass")
        // After "aass": â + s toggled off = should restore
        let result = engine.hCode
        XCTAssertEqual(result, EngineAction.restore.rawValue)
    }

    func testTelexDToggle() {
        // "dd" -> đ, then "d" again should restore to "dd" (iOS behavior)
        engine.resetSession()
        _ = type("d")
        _ = type("d")
        let output1 = composedOutput()
        XCTAssertEqual(output1, "đ")

        let result = type("d")
        // Restore: backspace "đ" (1), output "dd" (2)
        XCTAssertEqual(result.action, .restore)
        XCTAssertEqual(result.backspaceCount, 1)
        XCTAssertEqual(result.newCharCount, 2)
        let output2 = composedOutput()
        XCTAssertEqual(output2, "dd")
    }

    // MARK: - iOS-style restore tests

    func testTelexCircumflexARestore() {
        // "aa" -> â, then "a" again -> "aa"
        engine.resetSession()
        _ = type("aa")
        XCTAssertEqual(composedOutput(), "â")

        let result = type("a")
        XCTAssertEqual(result.action, .restore)
        XCTAssertEqual(result.backspaceCount, 1)
        XCTAssertEqual(result.newCharCount, 2)
        XCTAssertEqual(composedOutput(), "aa")
    }

    func testTelexCircumflexERestore() {
        // "ee" -> ê, then "e" again -> "ee"
        engine.resetSession()
        _ = type("ee")
        XCTAssertEqual(composedOutput(), "ê")

        let result = type("e")
        XCTAssertEqual(result.action, .restore)
        XCTAssertEqual(result.backspaceCount, 1)
        XCTAssertEqual(result.newCharCount, 2)
        XCTAssertEqual(composedOutput(), "ee")
    }

    func testTelexCircumflexORestore() {
        // "oo" -> ô, then "o" again -> "oo"
        engine.resetSession()
        _ = type("oo")
        XCTAssertEqual(composedOutput(), "ô")

        let result = type("o")
        XCTAssertEqual(result.action, .restore)
        XCTAssertEqual(result.backspaceCount, 1)
        XCTAssertEqual(result.newCharCount, 2)
        XCTAssertEqual(composedOutput(), "oo")
    }

    func testTelexHornURestore() {
        // "uw" -> ư, then "w" again -> "uw"
        engine.resetSession()
        _ = type("u")
        _ = type("w")
        XCTAssertEqual(composedOutput(), "ư")

        let result = type("w")
        XCTAssertEqual(result.action, .restore)
        XCTAssertEqual(result.backspaceCount, 1)
        XCTAssertEqual(result.newCharCount, 2)
        XCTAssertEqual(composedOutput(), "uw")
    }

    func testTelexCircumflexPlusToneThenSameKey() {
        // "aas" -> ấ, then "a" -> "áa" (restore circumflex, keep tone, append new a)
        engine.resetSession()
        _ = type("aas")
        XCTAssertEqual(composedOutput(), "ấ")

        let result = type("a")
        XCTAssertEqual(result.action, .restore)
        XCTAssertEqual(result.backspaceCount, 1)
        XCTAssertEqual(result.newCharCount, 2)
        XCTAssertEqual(composedOutput(), "áa")
    }

    func testTelexBrevePlusToneCyclesToCircumflex() {
        // "aws" -> ắ, then "a" -> "ấ" (breve cycles to circumflex, tone preserved)
        engine.resetSession()
        _ = type("aws")
        XCTAssertEqual(composedOutput(), "ắ")

        let result = type("a")
        XCTAssertEqual(result.action, .willProcess)
        XCTAssertEqual(composedOutput(), "ấ")
    }

    func testTelexRestoreDoesNotRecycleO() {
        // After "oo" -> ô -> restore to "oo", a 4th "o" should just append raw (not re-transform)
        engine.resetSession()
        _ = type("ooo") // restore to "oo"
        XCTAssertEqual(composedOutput(), "oo")
        _ = type("o")   // 4th o: tempDisableKey=true, should be raw
        XCTAssertEqual(composedOutput(), "ooo")
    }

    // MARK: - VNI Mode Tests

    func testVNISacTone() {
        engine.config.inputType = .vni
        engine.resetSession()
        // "a1" -> á
        _ = type("a")
        let result = engine.handleKeyEvent(
            event: .keyboard, state: .keyDown,
            keyCode: KEY_1, capsStatus: 0, otherControlKey: false
        )
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "á")
    }

    func testVNIHuyenTone() {
        engine.config.inputType = .vni
        engine.resetSession()
        // "a2" -> à
        _ = type("a")
        let result = engine.handleKeyEvent(
            event: .keyboard, state: .keyDown,
            keyCode: KEY_2, capsStatus: 0, otherControlKey: false
        )
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "à")
    }

    func testVNICircumflex() {
        engine.config.inputType = .vni
        engine.resetSession()
        // "a6" -> â
        _ = type("a")
        let result = engine.handleKeyEvent(
            event: .keyboard, state: .keyDown,
            keyCode: KEY_6, capsStatus: 0, otherControlKey: false
        )
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "â")
    }

    func testVNIStrokedD() {
        engine.config.inputType = .vni
        engine.resetSession()
        // "d9" -> đ
        _ = type("d")
        let result = engine.handleKeyEvent(
            event: .keyboard, state: .keyDown,
            keyCode: KEY_9, capsStatus: 0, otherControlKey: false
        )
        XCTAssertEqual(result.action, .willProcess)
        let output = composedOutput()
        XCTAssertEqual(output, "đ")
    }

    // MARK: - Modern Orthography Tests

    func testModernMarkPlacement_Hoang() {
        // "hoangf" with modern orthography -> hoàng (mark on a, not o)
        engine.config.useModernOrthography = true
        engine.resetSession()
        _ = type("hoangf")
        let output = composedOutput()
        XCTAssertEqual(output, "hoàng")
    }

    func testModernMarkPlacement_Thuong() {
        // "thuwowngf" -> thường (mark on ơ)
        engine.config.useModernOrthography = true
        engine.resetSession()
        _ = type("thuwowngf")
        let output = composedOutput()
        XCTAssertEqual(output, "thường")
    }

    // MARK: - Spelling Check Tests

    func testSpellingValidWord() {
        engine.config.checkSpelling = true
        engine.resetSession()
        _ = type("viet")
        XCTAssertFalse(engine.tempDisableKey)
    }

    func testEngineReset() {
        _ = type("abc")
        XCTAssertEqual(engine.idx, 3)
        engine.resetSession()
        XCTAssertEqual(engine.idx, 0)
        XCTAssertEqual(engine.stateIdx, 0)
        XCTAssertFalse(engine.tempDisableKey)
    }

    // MARK: - Edge cases

    func testEmptyInput() {
        let result = engine.handleKeyEvent(
            event: .keyboard, state: .keyDown,
            keyCode: KEY_DELETE, capsStatus: 0, otherControlKey: false
        )
        XCTAssertEqual(result.action, .doNothing)
    }

    func testUppercaseInput() {
        // "As" -> Á
        let _ = engine.handleKeyEvent(
            event: .keyboard, state: .keyDown,
            keyCode: KEY_A, capsStatus: 1, otherControlKey: false
        )
        let result = engine.handleKeyEvent(
            event: .keyboard, state: .keyDown,
            keyCode: KEY_S, capsStatus: 0, otherControlKey: false
        )
        XCTAssertEqual(result.action, .willProcess)
        // Verify the first character has CAPS_MASK
        XCTAssertTrue((engine.typingWord[0] & CAPS_MASK) != 0)
    }

    func testWordBreakOnComma() {
        _ = type("viet")
        let result = engine.handleKeyEvent(
            event: .keyboard, state: .keyDown,
            keyCode: KEY_COMMA, capsStatus: 0, otherControlKey: false
        )
        // After word break, engine should reset
        XCTAssertEqual(engine.idx, 0)
    }

    func testQuickTelexCC() {
        engine.config.quickTelex = true
        engine.resetSession()
        _ = type("c")
        let result = type("c")
        // "cc" with quick telex -> ch
        // The result should indicate willProcess with backspace 1 and new char count 2
        XCTAssertEqual(result.action, .willProcess)
        XCTAssertEqual(result.backspaceCount, 1)
        XCTAssertEqual(result.newCharCount, 2)
    }
}
