// VietnameseEngine+Vowel.swift
// VietKey Engine
//
// Vowel operations, character lookup, mark validation.

import Foundation

extension VietnameseEngine {

    // MARK: - Vowel Operations

    func findAndCalculateVowel(forGrammar: Bool = false) {
        vowelCount = 0; VSI = 0; VEI = 0
        var iii = idx - 1
        while iii >= 0 {
            if isConsonant(chr(iii)) {
                if vowelCount > 0 { break }
            } else {
                if vowelCount == 0 { VEI = iii }
                if !forGrammar {
                    if (iii - 1 >= 0 && chr(iii) == KEY_I && chr(iii - 1) == KEY_G) ||
                       (iii - 1 >= 0 && chr(iii) == KEY_U && chr(iii - 1) == KEY_Q) { break }
                }
                VSI = iii; vowelCount += 1
            }
            iii -= 1
        }
        if VSI - 1 >= 0 && chr(VSI) == KEY_U && chr(VSI - 1) == KEY_Q {
            VSI += 1; vowelCount -= 1
        }
    }

    func removeMark() {
        findAndCalculateVowel(forGrammar: true)
        isChanged = false
        if idx > 0 {
            for i in VSI...VEI {
                if (typingWord[i] & MARK_MASK) != 0 {
                    typingWord[i] &= ~MARK_MASK; isChanged = true
                }
            }
        }
        if isChanged {
            hCode = EngineAction.willProcess.rawValue; hBPC = 0
            for i in stride(from: idx - 1, through: VSI, by: -1) {
                hBPC += 1; hData[idx - 1 - i] = get(typingWord[i])
            }
            hNCC = hBPC
        } else {
            hCode = EngineAction.doNothing.rawValue
        }
    }

    func canHasEndConsonant() -> Bool {
        let vo = vnVowelCombine[chr(VSI)] ?? []
        for pattern in vo {
            var kk = VSI
            var iii = 1
            while iii < pattern.count {
                let tw = typingWord[kk]
                if kk > VEI || (UInt32(chr(kk)) | (tw & TONE_MASK) | (tw & TONEW_MASK)) != pattern[iii] { break }
                kk += 1; iii += 1
            }
            if iii >= pattern.count { return pattern[0] == 1 }
        }
        return false
    }

    // MARK: - Mark Handling Vowel Check

    func canFixVowelWithDiacriticsForMark() -> Bool {
        let savedVowelCount = vowelCount, savedVSI = VSI, savedVEI = VEI
        findAndCalculateVowel()
        defer { vowelCount = savedVowelCount; VSI = savedVSI; VEI = savedVEI }
        guard vowelCount > 0 else { return false }
        guard let patterns = vnVowelCombine[chr(VSI)] else { return false }
        for pattern in patterns {
            let patternLen = pattern.count - 1
            if patternLen < vowelCount { continue }
            var match = true
            for pIdx in 0..<vowelCount {
                let expected = pattern[pIdx + 1]
                let expectedBase = UInt16(expected & CHAR_MASK)
                let currentBase = chr(VSI + pIdx)
                if currentBase != expectedBase { match = false; break }
                let expectedTone = expected & (TONE_MASK | TONEW_MASK)
                let currentTone = typingWord[VSI + pIdx] & (TONE_MASK | TONEW_MASK)
                if expectedTone == 0 {
                    if currentTone != 0 { match = false; break }
                } else {
                    if currentTone != 0 && currentTone != expectedTone { match = false; break }
                }
            }
            if match { return true }
        }
        return false
    }

    // MARK: - Character Lookup

    func checkCorrectVowel(_ charset: [[UInt16]], _ charsetIdx: Int, _ k: inout Int, _ markKey: UInt16) {
        if idx >= 2 && chr(idx - 1) == KEY_U && chr(idx - 2) == KEY_Q { isCorect = false; return }
        k = idx - 1
        let quickEnd = config.quickEndConsonant
        let row = charset[charsetIdx]
        var j = row.count - 1
        while j >= 0 {
            let rc = row[j] & ~(quickEnd ? END_CONSONANT_MASK : 0)
            if rc != chr(k) { isCorect = false; return }
            k -= 1
            if k < 0 { break }
            j -= 1
        }
        if isCorect && row.count > 1 && (isKeyF(markKey) || isKeyX(markKey) || isKeyR(markKey)) {
            if row[1] == KEY_C || row[1] == KEY_T { isCorect = false; return }
            if row.count > 2 && row[2] == KEY_T { isCorect = false; return }
        }
        if isCorect && k >= 0 {
            if chr(k) == chr(k + 1) &&
               (typingWord[k] & (TONE_MASK | TONEW_MASK)) == 0 &&
               (typingWord[k + 1] & (TONE_MASK | TONEW_MASK)) == 0 {
                if isMarkKey(markKey) && k + 2 < idx && chr(k) == chr(k + 2) {
                    // Allow triple vowels
                } else {
                    isCorect = false
                }
            }
        }
    }

    func getCharacterCode(_ data: UInt32) -> UInt32 {
        let table = vnCodeTable[config.charEncoding.rawValue]
        capsElem = (data & CAPS_MASK) != 0 ? 0 : 1
        keyVal = Int(data & CHAR_MASK)

        if (data & MARK_MASK) != 0 {
            markElem = -2
            switch data & MARK_MASK {
            case MARK1_MASK: markElem = 0
            case MARK2_MASK: markElem = 2
            case MARK3_MASK: markElem = 4
            case MARK4_MASK: markElem = 6
            case MARK5_MASK: markElem = 8
            default: break
            }
            markElem += capsElem
            switch UInt16(keyVal) {
            case KEY_A, KEY_O, KEY_U, KEY_E:
                if (data & TONE_MASK) == 0 && (data & TONEW_MASK) == 0 { markElem += 4 }
            default: break
            }
            var lookupKey = UInt32(keyVal)
            if (data & TONE_MASK) != 0 { lookupKey |= TONE_MASK }
            else if (data & TONEW_MASK) != 0 { lookupKey |= TONEW_MASK }
            guard let vals = table[lookupKey], markElem >= 0 && markElem < vals.count else { return data }
            return UInt32(vals[markElem]) | CHAR_CODE_MASK
        } else {
            let lookupKey = UInt32(keyVal)
            guard let vals = table[lookupKey] else { return data }
            if (data & TONE_MASK) != 0 {
                guard capsElem < vals.count else { return data }
                return UInt32(vals[capsElem]) | CHAR_CODE_MASK
            } else if (data & TONEW_MASK) != 0 {
                guard capsElem + 2 < vals.count else { return data }
                return UInt32(vals[capsElem + 2]) | CHAR_CODE_MASK
            } else {
                return data
            }
        }
    }
}
