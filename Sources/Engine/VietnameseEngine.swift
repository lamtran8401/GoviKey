// VietnameseEngine.swift
// VietKey Engine
//
// Core Vietnamese input processing engine.
// Ported from PHTV's PHTVEngineCore.swift with clean API (EngineResult value type,
// EngineConfig instead of C bridge calls).
//
// Split into extensions:
//   EngineSpelling.swift     — Spelling validation, grammar normalization
//   EngineVowel.swift        — Vowel operations, character lookup, mark validation
//   EngineMark.swift         — Tone mark placement (modern/old), mark insertion
//   EngineComposition.swift  — Insert D/AOE/W, standalone, elongated vowels, quick telex/consonant
//   EngineHandler.swift      — Event handlers: main dispatch, word break, space, delete, main flow

import Foundation

public final class VietnameseEngine {

    // MARK: - Configuration

    public var config = EngineConfig()

    // MARK: - Hook output state (internal, copied into EngineResult)

    var hCode: Int32 = 0
    var hExt: Int32 = 0
    var hBPC: Int = 0
    var hNCC: Int = 0
    var hData: [UInt32] = Array(repeating: 0, count: ENGINE_MAX_BUFF)

    // MARK: - Core buffers

    var typingWord: [UInt32] = Array(repeating: 0, count: ENGINE_MAX_BUFF)
    var idx: Int = 0
    var longWordHelper: [UInt32] = []
    var typingStates: [[UInt32]] = []
    var typingStatesData: [UInt32] = []

    var keyStates: [UInt32] = Array(repeating: 0, count: ENGINE_MAX_BUFF)
    var stateIdx: Int = 0

    var tempDisableKey: Bool = false

    // MARK: - Spelling state

    var spellingOK: Bool = false
    var spellingFlag: Bool = false
    var spellingVowelOK: Bool = false
    var spellingEndIndex: Int = 0

    // MARK: - Session-scoped vars

    var capsElem: Int = 0
    var markElem: Int = 0
    var keyVal: Int = 0
    var isCorect: Bool = false
    var isChanged: Bool = false
    var vowelCount: Int = 0
    var VSI: Int = 0
    var VEI: Int = 0
    var VWSM: Int = 0
    var isRestoredW: Bool = false
    var keyForAEO: UInt16 = 0
    var isCheckedGrammar: Bool = false
    var isCaps: Bool = false
    var skipGrammarMarkNormalizationOnce: Bool = false

    var spaceCount: Int = 0
    var willTempOffEngine: Bool = false
    var isCharKeyCode: Bool = false
    var specialChar: [UInt32] = []

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Process a key event and return the result.
    public func handleKeyEvent(
        event: InputEvent,
        state: InputEventState,
        keyCode: UInt16,
        capsStatus: UInt8,
        otherControlKey: Bool
    ) -> EngineResult {
        hCode = EngineAction.doNothing.rawValue
        hExt = 0
        hBPC = 0
        hNCC = 0

        vKeyHandleEvent(
            event: event,
            state: state,
            data: keyCode,
            capsStatus: capsStatus,
            otherControlKey: otherControlKey
        )

        return makeResult()
    }

    /// Reset engine state for a new typing session.
    public func resetSession() {
        startNewSession()
    }

    /// Initialize engine for first use.
    public func initialize() {
        vKeyInit()
    }

    // MARK: - Inline key helpers

    @inline(__always)
    func chr(_ i: Int) -> UInt16 { UInt16(typingWord[i] & CHAR_MASK) }

    @inline(__always)
    func get(_ data: UInt32) -> UInt32 { getCharacterCode(data) }

    @inline(__always)
    func inputTypeIndex() -> Int { Int(config.inputType.rawValue) }

    @inline(__always)
    func isKeyZ(_ k: UInt16) -> Bool { processingChar[inputTypeIndex()][10] == k }
    @inline(__always)
    func isKeyD(_ k: UInt16) -> Bool { processingChar[inputTypeIndex()][9] == k }
    @inline(__always)
    func isKeyS(_ k: UInt16) -> Bool { processingChar[inputTypeIndex()][0] == k }
    @inline(__always)
    func isKeyF(_ k: UInt16) -> Bool { processingChar[inputTypeIndex()][1] == k }
    @inline(__always)
    func isKeyR(_ k: UInt16) -> Bool { processingChar[inputTypeIndex()][2] == k }
    @inline(__always)
    func isKeyX(_ k: UInt16) -> Bool { processingChar[inputTypeIndex()][3] == k }
    @inline(__always)
    func isKeyJ(_ k: UInt16) -> Bool { processingChar[inputTypeIndex()][4] == k }

    @inline(__always)
    func isKeyW(_ k: UInt16) -> Bool {
        if config.inputType != .vni {
            return processingChar[inputTypeIndex()][8] == k
        } else {
            return processingChar[1][8] == k || processingChar[1][7] == k
        }
    }

    @inline(__always)
    func isKeyDouble(_ k: UInt16) -> Bool {
        if config.inputType != .vni {
            let pc = processingChar[inputTypeIndex()]
            return pc[5] == k || pc[6] == k || pc[7] == k
        } else {
            return processingChar[1][6] == k
        }
    }

    @inline(__always)
    func isMarkKey(_ k: UInt16) -> Bool {
        if config.inputType != .vni {
            return k == KEY_S || k == KEY_F || k == KEY_R || k == KEY_J || k == KEY_X
        } else {
            return k == KEY_1 || k == KEY_2 || k == KEY_3 || k == KEY_5 || k == KEY_4
        }
    }

    @inline(__always)
    func isBracketKey(_ k: UInt16) -> Bool { k == KEY_LEFT_BRACKET || k == KEY_RIGHT_BRACKET }

    @inline(__always)
    func isSpecialKey(_ k: UInt16) -> Bool {
        switch config.inputType {
        case .telex:
            return k == KEY_W || k == KEY_E || k == KEY_R || k == KEY_O ||
                   k == KEY_LEFT_BRACKET || k == KEY_RIGHT_BRACKET || k == KEY_A ||
                   k == KEY_S || k == KEY_D || k == KEY_F || k == KEY_J ||
                   k == KEY_Z || k == KEY_X
        case .vni:
            return isNumberKey(k)
        }
    }

    @inline(__always)
    func isQuickTelexKey(_ k: UInt16) -> Bool { vnQuickTelex[UInt32(k)] != nil }

    // MARK: - Result builder

    func makeResult() -> EngineResult {
        guard let action = EngineAction(rawValue: hCode) else {
            return .passThrough
        }
        let count = max(hNCC, hBPC)
        let dataCopy = count > 0 ? Array(hData.prefix(count)) : []
        return EngineResult(
            action: action,
            extCode: hExt,
            backspaceCount: hBPC,
            newCharCount: hNCC,
            data: dataCopy
        )
    }

    // MARK: - Session operations

    func setKeyData(_ index: Int, _ keyCode: UInt16, _ isCaps: Bool) {
        guard index >= 0 && index < ENGINE_MAX_BUFF else { return }
        typingWord[index] = UInt32(keyCode) | (isCaps ? CAPS_MASK : 0)
    }

    func insertKey(_ keyCode: UInt16, _ isCaps: Bool, _ isCheckSpelling: Bool = true) {
        if idx >= ENGINE_MAX_BUFF {
            longWordHelper.append(typingWord[0])
            for i in 0..<(ENGINE_MAX_BUFF - 1) { typingWord[i] = typingWord[i + 1] }
            setKeyData(ENGINE_MAX_BUFF - 1, keyCode, isCaps)
        } else {
            setKeyData(idx, keyCode, isCaps)
            idx += 1
        }
        if config.checkSpelling && isCheckSpelling { checkSpelling() }
        if keyCode == KEY_D && idx - 2 >= 0 && isConsonant(chr(idx - 2)) {
            tempDisableKey = false
        }
    }

    func markMask(for data: UInt16) -> UInt32? {
        if isKeyS(data) { return MARK1_MASK }
        if isKeyF(data) { return MARK2_MASK }
        if isKeyR(data) { return MARK3_MASK }
        if isKeyX(data) { return MARK4_MASK }
        if isKeyJ(data) { return MARK5_MASK }
        return nil
    }

    func insertState(_ keyCode: UInt16, _ isCaps: Bool) {
        if stateIdx >= ENGINE_MAX_BUFF {
            for i in 0..<(ENGINE_MAX_BUFF - 1) { keyStates[i] = keyStates[i + 1] }
            keyStates[ENGINE_MAX_BUFF - 1] = UInt32(keyCode) | (isCaps ? CAPS_MASK : 0)
        } else {
            keyStates[stateIdx] = UInt32(keyCode) | (isCaps ? CAPS_MASK : 0)
            stateIdx += 1
        }
    }

    func saveWord() {
        if idx > 0 {
            if !longWordHelper.isEmpty {
                typingStatesData.removeAll()
                for (i, v) in longWordHelper.enumerated() {
                    if i != 0 && i % ENGINE_MAX_BUFF == 0 {
                        typingStates.append(typingStatesData)
                        typingStatesData.removeAll()
                    }
                    typingStatesData.append(v)
                }
                typingStates.append(typingStatesData)
                longWordHelper.removeAll()
            }
            typingStatesData.removeAll()
            for i in 0..<idx { typingStatesData.append(typingWord[i]) }
            typingStates.append(typingStatesData)
        }
    }

    func saveWord(_ keyCode: UInt32, _ count: Int) {
        typingStatesData.removeAll()
        for _ in 0..<count { typingStatesData.append(keyCode) }
        typingStates.append(typingStatesData)
    }

    func saveSpecialChar() {
        typingStatesData.removeAll()
        for v in specialChar { typingStatesData.append(v) }
        typingStates.append(typingStatesData)
        specialChar.removeAll()
    }

    func restoreLastTypingState() {
        guard !typingStates.isEmpty else { return }
        typingStatesData = typingStates.removeLast()
        guard !typingStatesData.isEmpty else { return }
        let first = UInt16(typingStatesData[0] & CHAR_MASK)
        if first == KEY_SPACE {
            spaceCount = typingStatesData.count
            idx = 0
        } else if kCharKeyCode.contains(first) {
            idx = 0
            specialChar = typingStatesData
            checkSpelling()
        } else {
            for i in 0..<typingStatesData.count { typingWord[i] = typingStatesData[i] }
            idx = typingStatesData.count
            if config.checkSpelling {
                checkSpelling()
            } else {
                tempDisableKey = false
            }
        }
    }

    func startNewSession() {
        idx = 0
        hBPC = 0
        hNCC = 0
        tempDisableKey = false
        stateIdx = 0
        skipGrammarMarkNormalizationOnce = false
        spaceCount = 0
        longWordHelper.removeAll()
    }
}
