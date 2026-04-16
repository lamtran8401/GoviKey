// CharacterEncodingTests.swift
// GoviKey Engine Tests
//
// Tests for the Bảng mã (character encoding) feature.
// Verifies that each encoding produces the correct output codes
// for Vietnamese characters. Input key handling is encoding-agnostic;
// encoding only affects getCharacterCode() which selects from vnCodeTable.

import XCTest
@testable import Engine

final class CharacterEncodingTests: XCTestCase {

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

    /// Returns the raw UInt16 code values from the engine buffer for the current encoding.
    /// Mirrors composedOutput() but returns codes instead of a String so legacy
    /// encodings (TCVN3, VNI, CP1258) can be verified by byte value.
    func rawCodes() -> [UInt16] {
        var codes: [UInt16] = []
        for i in 0..<engine.bufferLen {
            let code = engine.getCharacterCode(engine.typingWord[i])
            if (code & CHAR_CODE_MASK) != 0 {
                let val = UInt16(code & CHAR_MASK)
                if val > 0 { codes.append(val) }
            } else {
                let val = vnKeyCodeToCharacter(engine.typingWord[i])
                if val > 0 { codes.append(val) }
            }
        }
        return codes
    }

    // MARK: - Metadata

    func testAllEncodingCasesExist() {
        XCTAssertEqual(CharacterEncoding.allCases.count, 5)
        XCTAssertEqual(CharacterEncoding.unicode.rawValue, 0)
        XCTAssertEqual(CharacterEncoding.tcvn3.rawValue, 1)
        XCTAssertEqual(CharacterEncoding.vniWindows.rawValue, 2)
        XCTAssertEqual(CharacterEncoding.unicodeCompound.rawValue, 3)
        XCTAssertEqual(CharacterEncoding.cp1258.rawValue, 4)
    }

    func testEncodingDisplayNames() {
        XCTAssertEqual(CharacterEncoding.unicode.displayName, "Unicode")
        XCTAssertEqual(CharacterEncoding.tcvn3.displayName, "TCVN3 (ABC)")
        XCTAssertEqual(CharacterEncoding.vniWindows.displayName, "VNI Windows")
        XCTAssertEqual(CharacterEncoding.unicodeCompound.displayName, "Unicode Compound")
        XCTAssertEqual(CharacterEncoding.cp1258.displayName, "CP1258")
    }

    // MARK: - Unicode Encoding

    func testUnicode_a_sac() {
        // "as" → á (U+00E1)
        engine.config.charEncoding = .unicode
        engine.resetSession()
        _ = type("as")
        XCTAssertEqual(rawCodes(), [0x00E1])
    }

    func testUnicode_a_circumflex() {
        // "aa" → â (U+00E2)
        engine.config.charEncoding = .unicode
        engine.resetSession()
        _ = type("aa")
        XCTAssertEqual(rawCodes(), [0x00E2])
    }

    func testUnicode_a_breve() {
        // "aw" → ă (U+0103)
        engine.config.charEncoding = .unicode
        engine.resetSession()
        _ = type("aw")
        XCTAssertEqual(rawCodes(), [0x0103])
    }

    func testUnicode_d_stroked() {
        // "dd" → đ (U+0111)
        engine.config.charEncoding = .unicode
        engine.resetSession()
        _ = type("dd")
        XCTAssertEqual(rawCodes(), [0x0111])
    }

    func testUnicode_a_circumflex_sac() {
        // "aas" → ấ (U+1EA5)
        engine.config.charEncoding = .unicode
        engine.resetSession()
        _ = type("aas")
        XCTAssertEqual(rawCodes(), [0x1EA5])
    }

    func testUnicode_o_horn_huyen() {
        // "owf" → ờ (U+1EDD)
        engine.config.charEncoding = .unicode
        engine.resetSession()
        _ = type("owf")
        XCTAssertEqual(rawCodes(), [0x1EDD])
    }

    func testUnicode_uppercase_A_sac() {
        // "As" → Á (U+00C1)
        engine.config.charEncoding = .unicode
        engine.resetSession()
        _ = type("As")
        XCTAssertEqual(rawCodes(), [0x00C1])
    }

    // MARK: - TCVN3 Encoding

    func testTCVN3_a_sac() {
        // "as" → 0xB8 in TCVN3
        engine.config.charEncoding = .tcvn3
        engine.resetSession()
        _ = type("as")
        XCTAssertEqual(rawCodes(), [0xB8])
    }

    func testTCVN3_a_circumflex() {
        // "aa" → 0xA9 in TCVN3
        engine.config.charEncoding = .tcvn3
        engine.resetSession()
        _ = type("aa")
        XCTAssertEqual(rawCodes(), [0xA9])
    }

    func testTCVN3_a_breve() {
        // "aw" → 0xA8 in TCVN3
        engine.config.charEncoding = .tcvn3
        engine.resetSession()
        _ = type("aw")
        XCTAssertEqual(rawCodes(), [0xA8])
    }

    func testTCVN3_d_stroked() {
        // "dd" → 0xAE in TCVN3
        engine.config.charEncoding = .tcvn3
        engine.resetSession()
        _ = type("dd")
        XCTAssertEqual(rawCodes(), [0xAE])
    }

    func testTCVN3_a_circumflex_sac() {
        // "aas" → 0xCA in TCVN3
        engine.config.charEncoding = .tcvn3
        engine.resetSession()
        _ = type("aas")
        XCTAssertEqual(rawCodes(), [0xCA])
    }

    // MARK: - VNI Windows Encoding

    func testVNI_a_sac() {
        // "as" → 0xF961 in VNI Windows
        engine.config.charEncoding = .vniWindows
        engine.resetSession()
        _ = type("as")
        XCTAssertEqual(rawCodes(), [0xF961])
    }

    func testVNI_a_circumflex() {
        // "aa" → 0xE261 in VNI Windows
        engine.config.charEncoding = .vniWindows
        engine.resetSession()
        _ = type("aa")
        XCTAssertEqual(rawCodes(), [0xE261])
    }

    func testVNI_a_breve() {
        // "aw" → 0xEA61 in VNI Windows
        engine.config.charEncoding = .vniWindows
        engine.resetSession()
        _ = type("aw")
        XCTAssertEqual(rawCodes(), [0xEA61])
    }

    func testVNI_d_stroked() {
        // "dd" → 0x00F1 in VNI Windows
        engine.config.charEncoding = .vniWindows
        engine.resetSession()
        _ = type("dd")
        XCTAssertEqual(rawCodes(), [0x00F1])
    }

    func testVNI_a_circumflex_sac() {
        // "aas" → 0xE161 in VNI Windows
        engine.config.charEncoding = .vniWindows
        engine.resetSession()
        _ = type("aas")
        XCTAssertEqual(rawCodes(), [0xE161])
    }

    // MARK: - Unicode Compound Encoding

    func testUnicodeCompound_a_sac() {
        // "as" → 0x2061 in Unicode Compound (table index 5: MARK1 lowercase, no circ/horn)
        engine.config.charEncoding = .unicodeCompound
        engine.resetSession()
        _ = type("as")
        XCTAssertEqual(rawCodes(), [0x2061])
    }

    func testUnicodeCompound_a_circumflex() {
        // "aa" → 0x00E2 (same base char as Unicode)
        engine.config.charEncoding = .unicodeCompound
        engine.resetSession()
        _ = type("aa")
        XCTAssertEqual(rawCodes(), [0x00E2])
    }

    func testUnicodeCompound_a_breve() {
        // "aw" → 0x0103 (same as Unicode)
        engine.config.charEncoding = .unicodeCompound
        engine.resetSession()
        _ = type("aw")
        XCTAssertEqual(rawCodes(), [0x0103])
    }

    func testUnicodeCompound_d_stroked() {
        // "dd" → 0x0111 (same as Unicode)
        engine.config.charEncoding = .unicodeCompound
        engine.resetSession()
        _ = type("dd")
        XCTAssertEqual(rawCodes(), [0x0111])
    }

    func testUnicodeCompound_a_circumflex_sac() {
        // "aas" → 0x20E2 in Unicode Compound (tone in high byte)
        engine.config.charEncoding = .unicodeCompound
        engine.resetSession()
        _ = type("aas")
        XCTAssertEqual(rawCodes(), [0x20E2])
    }

    // MARK: - CP1258 Encoding

    func testCP1258_a_sac() {
        // "as" → 0xEC61 in CP1258 (table index 5: MARK1 lowercase, no circ/horn)
        engine.config.charEncoding = .cp1258
        engine.resetSession()
        _ = type("as")
        XCTAssertEqual(rawCodes(), [0xEC61])
    }

    func testCP1258_a_circumflex() {
        // "aa" → 0x00E2 (same as Unicode for â)
        engine.config.charEncoding = .cp1258
        engine.resetSession()
        _ = type("aa")
        XCTAssertEqual(rawCodes(), [0x00E2])
    }

    func testCP1258_a_breve() {
        // "aw" → 0x00E3 in CP1258
        engine.config.charEncoding = .cp1258
        engine.resetSession()
        _ = type("aw")
        XCTAssertEqual(rawCodes(), [0x00E3])
    }

    func testCP1258_d_stroked() {
        // "dd" → 0x00F0 in CP1258
        engine.config.charEncoding = .cp1258
        engine.resetSession()
        _ = type("dd")
        XCTAssertEqual(rawCodes(), [0x00F0])
    }

    func testCP1258_a_circumflex_sac() {
        // "aas" → 0xECE2 in CP1258
        engine.config.charEncoding = .cp1258
        engine.resetSession()
        _ = type("aas")
        XCTAssertEqual(rawCodes(), [0xECE2])
    }

    // MARK: - Cross-encoding difference

    func testAllEncodingsProduceDifferentCodesForSac() {
        // á must produce a distinct code in each legacy encoding
        let encodings: [CharacterEncoding] = [.unicode, .tcvn3, .vniWindows, .unicodeCompound, .cp1258]
        var results: [UInt16] = []
        for enc in encodings {
            engine.config.charEncoding = enc
            engine.resetSession()
            _ = type("as")
            results.append(rawCodes().first ?? 0)
        }
        // At minimum, TCVN3 and VNI must differ from Unicode
        XCTAssertNotEqual(results[1], results[0], "TCVN3 should differ from Unicode for á")
        XCTAssertNotEqual(results[2], results[0], "VNI Windows should differ from Unicode for á")
        XCTAssertNotEqual(results[3], results[0], "Unicode Compound should differ from Unicode for á")
        XCTAssertNotEqual(results[4], results[0], "CP1258 should differ from Unicode for á")
    }

    func testEncodingSwitchMidSessionChangesOutput() {
        // Switching encoding resets the session; each encoding independently produces correct output
        engine.config.charEncoding = .unicode
        engine.resetSession()
        _ = type("as")
        let unicodeCode = rawCodes().first

        engine.config.charEncoding = .tcvn3
        engine.resetSession()
        _ = type("as")
        let tcvn3Code = rawCodes().first

        XCTAssertNotNil(unicodeCode)
        XCTAssertNotNil(tcvn3Code)
        XCTAssertNotEqual(unicodeCode, tcvn3Code)
    }
}
