// VietnameseEngine+Mark.swift
// GoviKey Engine
//
// Tone mark placement (modern/old style) and mark insertion.

import Foundation

extension VietnameseEngine {

    // MARK: - Modern Mark Placement

    func handleModernMark() {
        let (preferLastRepeat, savedEnd, savedCount) = normalizeTrailingVowelRun()

        markPosition = vowelEnd  // default: last vowel

        applyStandardMarkPosition()
        applyDiphthongMarkOverride()
        applyTwoVowelMarkOverrides()

        if preferLastRepeat { markPosition = savedEnd }
        if savedEnd != vowelEnd { vowelEnd = savedEnd; vowelCount = savedCount }

        backspaceCount = bufferLen - markPosition
    }

    // MARK: - Old Mark Placement

    func handleOldMark() {
        let savedEnd = vowelEnd, savedCount = vowelCount
        if vowelCount >= 2 {
            let tailVowel = chr(vowelEnd)
            var tailStart = vowelEnd
            while tailStart > vowelStart && chr(tailStart - 1) == tailVowel { tailStart -= 1 }
            if vowelEnd - tailStart + 1 >= 2 {
                vowelEnd = tailStart; vowelCount = 0
                for id in vowelStart...vowelEnd where !isConsonant(chr(id)) { vowelCount += 1 }
            }
        }

        markPosition = (vowelCount == 0 && chr(vowelEnd) == KEY_I) ? vowelEnd : vowelStart

        if vowelCount == 3 || (vowelEnd + 1 < bufferLen && isConsonant(chr(vowelEnd + 1)) && canHasEndConsonant()) {
            markPosition = vowelStart + 1
        }

        for ii in vowelStart...vowelEnd {
            if (chr(ii) == KEY_E && (typingWord[ii] & TONE_MASK) != 0) ||
               (chr(ii) == KEY_O && (typingWord[ii] & TONEW_MASK) != 0) {
                markPosition = ii; break
            }
        }

        backspaceCount = bufferLen - markPosition
        newCharCount = backspaceCount
        if savedEnd != vowelEnd { vowelEnd = savedEnd; vowelCount = savedCount }
    }

    // MARK: - Insert Mark

    func insertMark(_ markMask: UInt32, canModifyFlag: Bool = true) {
        vowelCount = 0
        if canModifyFlag { actionCode = EngineAction.willProcess.rawValue }
        backspaceCount = 0; newCharCount = 0
        findAndCalculateVowel()
        markPosition = 0

        if vowelCount == 1 {
            markPosition = vowelEnd; backspaceCount = bufferLen - vowelEnd
        } else {
            if !config.useModernOrthography { handleOldMark() } else { handleModernMark() }
            if (typingWord[vowelEnd] & (TONE_MASK | TONEW_MASK)) != 0 {
                markPosition = vowelEnd
            }
        }

        let reverseStart = bufferLen - 1 - vowelStart
        if (typingWord[markPosition] & markMask) != 0 {
            removeMarkFromVowels(reverseStart: reverseStart)
            if canModifyFlag { actionCode = EngineAction.restore.rawValue }
            tempDisableKey = true
        } else {
            applyMarkToVowels(markMask: markMask, reverseStart: reverseStart)
            backspaceCount = bufferLen - vowelStart
        }
        newCharCount = backspaceCount
    }

    // MARK: - Modern Mark Helpers

    /// Trims a repeated-vowel run at the end of the nucleus so the mark lands on
    /// the first occurrence rather than the last.
    /// Returns whether to prefer the last repeat (preferLastRepeat) and the saved vowelEnd/vowelCount.
    private func normalizeTrailingVowelRun() -> (preferLastRepeat: Bool, savedEnd: Int, savedCount: Int) {
        let savedEnd = vowelEnd, savedCount = vowelCount
        guard vowelCount >= 2 else { return (false, savedEnd, savedCount) }

        let tailVowel = chr(vowelEnd)
        var tailStart = vowelEnd
        while tailStart > vowelStart && chr(tailStart - 1) == tailVowel { tailStart -= 1 }
        guard vowelEnd - tailStart + 1 >= 2 else { return (false, savedEnd, savedCount) }

        let runHasDiacritic = (tailStart...vowelEnd).contains {
            (typingWord[$0] & (TONE_MASK | TONEW_MASK)) != 0
        }
        if !runHasDiacritic && tailVowel == KEY_O && tailStart == vowelStart {
            return (true, savedEnd, savedCount)
        }
        vowelEnd = tailStart
        vowelCount = (vowelStart...vowelEnd).filter { !isConsonant(chr($0)) }.count
        return (false, savedEnd, savedCount)
    }

    /// Applies the standard priority-chain position rules for 3-vowel patterns,
    /// Y-trailing, and common two-vowel combinations.
    private func applyStandardMarkPosition() {
        if isTriVowelSpecialPattern()      { markPosition = vowelStart + 1; return }
        if vowelCount >= 2 && chr(vowelEnd) == KEY_Y { applyYTrailingMarkPosition(); return }
        if isLeadingMarkPattern()          { markPosition = vowelStart;     return }
        if isAYPattern()                   { markPosition = vowelEnd - 1;   return }
        if isUOLeadPattern()               { markPosition = vowelStart + 1; return }
        if isNextVowelOUPattern()          { markPosition = vowelEnd - 1;   return }
        if isLeadingOUPattern()            { markPosition = vowelEnd;       return }
    }

    /// Checks for the three-vowel patterns where the mark goes on the middle vowel.
    private func isTriVowelSpecialPattern() -> Bool {
        guard vowelCount == 3 else { return false }
        let v0 = chr(vowelStart), v1 = chr(vowelStart + 1), v2 = chr(vowelStart + 2)
        return (v0 == KEY_O && v1 == KEY_A && v2 == KEY_I) ||
               (v0 == KEY_U && v1 == KEY_Y && v2 == KEY_U) ||
               (v0 == KEY_O && v1 == KEY_E && v2 == KEY_O) ||
               (v0 == KEY_U && v1 == KEY_Y && v2 == KEY_A)
    }

    /// Handles Y at the end of the vowel nucleus (e.g. "uy" → mark on Y; others → last non-Y).
    private func applyYTrailingMarkPosition() {
        if vowelCount == 2 && chr(vowelStart) == KEY_U && chr(vowelStart + 1) == KEY_Y {
            markPosition = vowelEnd  // "uy": mark stays on Y
            return
        }
        var lastNonY = vowelEnd
        while lastNonY >= vowelStart && chr(lastNonY) == KEY_Y { lastNonY -= 1 }
        if lastNonY >= vowelStart { markPosition = lastNonY }
    }

    /// Patterns oi / ai / ui where the mark goes on the leading vowel.
    private func isLeadingMarkPattern() -> Bool {
        guard vowelStart + 1 <= vowelEnd else { return false }
        let v0 = chr(vowelStart), v1 = chr(vowelStart + 1)
        return (v0 == KEY_O || v0 == KEY_A || v0 == KEY_U) && v1 == KEY_I
    }

    /// Pattern "ay" where the mark goes on the A (second-to-last position).
    private func isAYPattern() -> Bool {
        vowelEnd - 1 >= vowelStart &&
        chr(vowelEnd - 1) == KEY_A && chr(vowelEnd) == KEY_Y
    }

    /// Pattern "uo" where the mark goes on the O (second position).
    private func isUOLeadPattern() -> Bool {
        vowelStart + 1 <= vowelEnd &&
        chr(vowelStart) == KEY_U && chr(vowelStart + 1) == KEY_O
    }

    /// The second vowel is O or U — mark goes on second-to-last position.
    private func isNextVowelOUPattern() -> Bool {
        guard vowelStart + 1 <= vowelEnd else { return false }
        let next = chr(vowelStart + 1)
        return next == KEY_O || next == KEY_U
    }

    /// Nucleus starts with O or U (fallback) — mark stays at vowelEnd.
    private func isLeadingOUPattern() -> Bool {
        chr(vowelStart) == KEY_O || chr(vowelStart) == KEY_U
    }

    /// Override for diphthongs with diacritics: iê/yê, uô, ươ.
    private func applyDiphthongMarkOverride() {
        guard vowelStart + 1 <= vowelEnd else { return }
        let tw0 = typingWord[vowelStart]
        let tw1 = typingWord[vowelStart + 1]

        let matchesIE = chr(vowelStart) == KEY_I && (tw1 & (UInt32(KEY_E) | TONE_MASK)) != 0
        let matchesYE = chr(vowelStart) == KEY_Y && (tw1 & (UInt32(KEY_E) | TONE_MASK)) != 0
        let matchesUO = chr(vowelStart) == KEY_U && tw1 == (UInt32(KEY_O) | TONE_MASK)
        let matchesUornOorn = tw0 == (UInt32(KEY_U) | TONEW_MASK) && tw1 == (UInt32(KEY_O) | TONEW_MASK)
        guard matchesIE || matchesYE || matchesUO || matchesUornOorn else { return }

        if diphthongForcesSecondPosition(tw0: tw0, tw1: tw1) {
            markPosition = vowelStart + 1
        } else if vowelStart + 2 < bufferLen && isFollowedByEndConsonantOrMidVowel(chr(vowelStart + 2)) {
            markPosition = vowelStart + 1
        } else {
            markPosition = vowelStart
        }
    }

    private func diphthongForcesSecondPosition(tw0: UInt32, tw1: UInt32) -> Bool {
        let v0 = chr(vowelStart), v1 = chr(vowelStart + 1)
        if (v0 == KEY_I || v0 == KEY_Y) && v1 == KEY_E && (tw1 & TONE_MASK) != 0 { return true }
        if v0 == KEY_U && v1 == KEY_O && (tw1 & TONE_MASK) != 0 { return true }
        if (tw0 & TONEW_MASK) != 0 && (tw1 & TONEW_MASK) != 0 && v0 == KEY_U && v1 == KEY_O { return true }
        return false
    }

    private func isFollowedByEndConsonantOrMidVowel(_ keyCode: UInt16) -> Bool {
        keyCode == KEY_P || keyCode == KEY_T || keyCode == KEY_M || keyCode == KEY_N ||
        keyCode == KEY_O || keyCode == KEY_U || keyCode == KEY_I || keyCode == KEY_C
    }

    /// Two-vowel overrides: iA/iU/iO (after non-G), uA (after non-Q), oo.
    private func applyTwoVowelMarkOverrides() {
        guard vowelCount == 2 else { return }
        let v0 = chr(vowelStart), v1 = chr(vowelStart + 1)
        let precededByG = vowelStart > 0 && chr(vowelStart - 1) == KEY_G
        let precededByQ = vowelStart > 0 && chr(vowelStart - 1) == KEY_Q

        if v0 == KEY_I && (v1 == KEY_A || v1 == KEY_U || v1 == KEY_O) {
            markPosition = precededByG ? vowelStart + 1 : vowelStart
        } else if v0 == KEY_U && v1 == KEY_A && !precededByQ {
            if vowelEnd + 1 >= bufferLen || !canHasEndConsonant() {
                markPosition = vowelStart
            }
        } else if v0 == KEY_U && v1 == KEY_A && precededByQ {
            markPosition = vowelStart + 1
        } else if v0 == KEY_O && v1 == KEY_O {
            markPosition = vowelEnd
        }
    }

    // MARK: - Insert Mark Helpers

    private func removeMarkFromVowels(reverseStart: Int) {
        var kk = reverseStart
        typingWord[markPosition] &= ~MARK_MASK
        for ii in vowelStart..<bufferLen {
            typingWord[ii] &= ~MARK_MASK
            outputData[kk] = get(typingWord[ii])
            kk -= 1
        }
    }

    private func applyMarkToVowels(markMask: UInt32, reverseStart: Int) {
        var kk = reverseStart
        typingWord[markPosition] &= ~MARK_MASK
        typingWord[markPosition] |= markMask
        for ii in vowelStart..<bufferLen {
            if ii != markPosition { typingWord[ii] &= ~MARK_MASK }
            outputData[kk] = get(typingWord[ii])
            kk -= 1
        }
    }
}
