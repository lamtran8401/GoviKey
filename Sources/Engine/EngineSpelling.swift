// VietnameseEngine+Spelling.swift
// GoviKey Engine
//
// Spelling validation and grammar normalization.

import Foundation

extension VietnameseEngine {

    // MARK: - Spelling Check

    func checkSpelling(forceCheckVowel: Bool = false) {
        guard bufferLen > 0 else {
            spellingOK = true; spellingVowelOK = true; tempDisableKey = false; return
        }
        spellingOK = false; spellingVowelOK = true
        spellingBound = bufferLen
        if chr(bufferLen - 1) == KEY_RIGHT_BRACKET { spellingBound = bufferLen - 1 }

        guard spellingBound > 0 else { spellingOK = true; tempDisableKey = false; return }

        let consonantEnd = scanConsonantCluster()
        if consonantEnd == spellingBound { spellingOK = true }

        let (nucleusStart, nucleusEnd) = scanVowelNucleus(from: consonantEnd)
        if nucleusEnd > nucleusStart {
            validateVowelNucleus(from: nucleusStart, to: nucleusEnd, forceCheck: forceCheckVowel)
            validateEndConsonantCluster(from: nucleusEnd)
            if spellingOK { validateEndConsonantMarkConstraints() }
        }

        tempDisableKey = !(spellingOK && spellingVowelOK)
    }

    // MARK: - Spelling Helpers

    /// Matches the buffer start against `vnConsonantTable`.
    /// Sets `unrecognizedConsonantStart` if no row matches.
    /// Returns the index just past the consonant cluster.
    private func scanConsonantCluster() -> Int {
        guard isConsonant(chr(0)) else { return 0 }

        let quickStart = config.quickStartConsonant
        let allowZFWJ  = config.allowConsonantZFWJ
        unrecognizedConsonantStart = false

        for row in vnConsonantTable {
            spellingFlag = spellingBound < row.count
            var j = 0
            while j < row.count {
                let rc = row[j]
                let maskedNoQuick = rc & ~(quickStart ? END_CONSONANT_MASK : 0)
                let maskedNoAllow = rc & ~(allowZFWJ  ? CONSONANT_ALLOW_MASK : 0)
                if spellingBound > j && maskedNoQuick != chr(j) && maskedNoAllow != chr(j) {
                    spellingFlag = true; break
                }
                j += 1
            }
            if !spellingFlag { return j }  // matched this row
        }
        unrecognizedConsonantStart = true
        return spellingBound  // no match → treat entire buffer as consonant
    }

    /// Advances past vowel characters starting at `start`, adjusting for Q+U and G+I+consonant.
    /// Updates `vowelStart` and returns `(nucleusStart, nucleusEnd)` where nucleusStart is the
    /// index of the first true vowel (after any Q+U onset) and nucleusEnd is one past the last vowel.
    private func scanVowelNucleus(from start: Int) -> (nucleusStart: Int, nucleusEnd: Int) {
        vowelStart = start
        var k = start

        if chr(vowelStart) == KEY_U && k > 0 && k < spellingBound - 1 && chr(vowelStart - 1) == KEY_Q {
            k += 1; vowelStart = k
        } else if bufferLen >= 2 && chr(0) == KEY_G && chr(1) == KEY_I && isConsonant(chr(2)) {
            vowelStart = 1; k = 1
        }

        let nucleusStart = k
        for _ in 0..<3 {
            if k < spellingBound && !isConsonant(chr(k)) { k += 1; vowelEnd = k }
        }
        return (nucleusStart, k)
    }

    /// Validates the vowel nucleus (j..<k) against `vnVowelCombine`.
    /// Sets `spellingVowelOK`.
    private func validateVowelNucleus(from j: Int, to k: Int, forceCheck: Bool) {
        spellingVowelOK = false
        if k - j > 1 && forceCheck {
            let vowelSet = vnVowelCombine[chr(j)] ?? []
            for pattern in vowelSet {
                spellingFlag = false
                for pi in 1..<pattern.count {
                    let idx = j + pi - 1
                    if idx < spellingBound {
                        let expected = pattern[pi]
                        let actual = UInt32(chr(idx)) | (typingWord[idx] & TONEW_MASK) | (typingWord[idx] & TONE_MASK)
                        if expected != actual { spellingFlag = true; break }
                    }
                }
                let ii = pattern.count - 1
                let hasEndConsonant = k < spellingBound && pattern[0] == 0
                let lastIsConsonant = (j + ii - 1 < spellingBound) && isConsonant(chr(j + ii - 1))
                if spellingFlag || hasEndConsonant || lastIsConsonant { continue }
                spellingVowelOK = true; break
            }
        } else if !isConsonant(chr(j)) {
            spellingVowelOK = true
        }
    }

    /// Validates trailing consonants from `k` onward against `vnEndConsonantTable`.
    /// Sets `spellingOK`.
    private func validateEndConsonantCluster(from k: Int) {
        let quickEnd = config.quickEndConsonant
        for row in vnEndConsonantTable {
            spellingFlag = false
            var jj = 0
            while jj < row.count {
                let maskedNoQuick = row[jj] & ~(quickEnd ? END_CONSONANT_MASK : 0)
                if spellingBound > k + jj && maskedNoQuick != chr(k + jj) {
                    spellingFlag = true; break
                }
                jj += 1
            }
            if spellingFlag { continue }
            if k + jj >= spellingBound { spellingOK = true; return }
        }
    }

    /// Blocks spellingOK when the ending consonant has an incompatible tone mark
    /// (e.g. "ch" or "t" endings only allow sắc/nặng/no mark).
    private func validateEndConsonantMarkConstraints() {
        func markIsAllowed(for tw: UInt32) -> Bool {
            (tw & MARK1_MASK) != 0 || (tw & MARK5_MASK) != 0 || (tw & MARK_MASK) == 0
        }
        if bufferLen >= 3 && chr(bufferLen - 1) == KEY_H && chr(bufferLen - 2) == KEY_C {
            if !markIsAllowed(for: typingWord[bufferLen - 3]) { spellingOK = false }
        } else if bufferLen >= 2 && chr(bufferLen - 1) == KEY_T {
            if !markIsAllowed(for: typingWord[bufferLen - 2]) { spellingOK = false }
        }
    }

    // MARK: - Grammar Check

    func checkGrammar(deltaBackSpace: Int) {
        guard bufferLen > 1 && bufferLen < ENGINE_MAX_BUFF else { return }
        findAndCalculateVowel(forGrammar: true)
        guard vowelCount > 0 else { return }
        grammarNormalized = false
        let l = vowelStart

        normalizeUOTonewMask()
        normalizeMarkPosition(from: l)

        skipGrammarMarkNormalizationOnce = false

        if grammarNormalized {
            if actionCode == EngineAction.doNothing.rawValue { actionCode = EngineAction.willProcess.rawValue }
            backspaceCount = 0
            for i in stride(from: bufferLen - 1, through: l, by: -1) {
                backspaceCount += 1
                outputData[bufferLen - 1 - i] = get(typingWord[i])
            }
            newCharCount = backspaceCount
            backspaceCount += deltaBackSpace
            extCode = 4
        }
    }

    // MARK: - Grammar Helpers

    /// Ensures both U and O in a "uô..." cluster carry the same TONEW_MASK.
    private func normalizeUOTonewMask() {
        guard bufferLen >= 3 else { return }
        outer: for i in stride(from: bufferLen - 1, through: 0, by: -1) {
            let c = chr(i)
            guard c == KEY_N || c == KEY_C || c == KEY_I || c == KEY_M || c == KEY_P || c == KEY_T else { continue }
            guard i - 2 >= 0 && chr(i - 1) == KEY_O && chr(i - 2) == KEY_U else { continue }
            let tonewI1 = typingWord[i - 1] & TONEW_MASK
            let tonewI2 = typingWord[i - 2] & TONEW_MASK
            if tonewI1 ^ tonewI2 != 0 {
                typingWord[i - 2] |= TONEW_MASK
                typingWord[i - 1] |= TONEW_MASK
                grammarNormalized = true
                break outer
            }
        }
    }

    /// Moves a misplaced tone mark to its canonical position in the vowel nucleus.
    private func normalizeMarkPosition(from l: Int) {
        guard bufferLen >= 2 else { return }
        for i in l...vowelEnd {
            guard (typingWord[i] & MARK_MASK) != 0 else { continue }

            if skipGrammarMarkNormalizationOnce &&
               i < vowelEnd &&
               (chr(vowelEnd) == KEY_A || chr(vowelEnd) == KEY_E || chr(vowelEnd) == KEY_O) &&
               (typingWord[vowelEnd] & (TONE_MASK | TONEW_MASK)) != 0 {
                skipGrammarMarkNormalizationOnce = false
                break
            }

            let tailStart = computeTailStart()
            let tailLen = vowelEnd - tailStart + 1
            if tailLen >= 2 && i <= tailStart { grammarNormalized = false; break }

            if isExtendedVowelRun(at: i) { grammarNormalized = false; break }

            let mark = typingWord[i] & MARK_MASK
            typingWord[i] &= ~MARK_MASK
            insertMark(mark, canModifyFlag: false)
            if i != markPosition { grammarNormalized = true }
            break
        }
    }

    private func computeTailStart() -> Int {
        guard vowelEnd > vowelStart else { return vowelEnd }
        let tailVowel = chr(vowelEnd)
        var ts = vowelEnd
        while ts > vowelStart && chr(ts - 1) == tailVowel { ts -= 1 }
        return ts
    }

    private func isExtendedVowelRun(at i: Int) -> Bool {
        guard i < vowelEnd && chr(i) == chr(i + 1) else { return false }
        for ci in (i + 1)...vowelEnd where chr(ci) != chr(i) { return false }
        return true
    }
}
