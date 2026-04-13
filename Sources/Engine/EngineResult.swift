// EngineResult.swift
// GoviKey Engine
//
// Value type returned by the engine after processing each keystroke.

/// Result of processing a key event through the Vietnamese engine.
public struct EngineResult: Sendable {
    /// What action the caller should take
    public let action: EngineAction

    /// Extended action code for caller context
    public let extCode: Int32

    /// Number of characters to backspace before inserting new text
    public let backspaceCount: Int

    /// Number of new characters to insert
    public let newCharCount: Int

    /// The new character data (engine-encoded UInt32 values).
    /// Index 0 is the rightmost (last) character.
    public let data: [UInt32]

    public static let passThrough = EngineResult(
        action: .doNothing, extCode: 0,
        backspaceCount: 0, newCharCount: 0, data: []
    )
}

/// Configuration for the Vietnamese engine, replacing PHTV's runtime bridge calls.
public struct EngineConfig: Sendable {
    public var charEncoding: CharacterEncoding = .unicode
    public var inputType: InputType = .telex
    public var checkSpelling: Bool = true
    public var useModernOrthography: Bool = true
    public var quickTelex: Bool = false
    public var quickStartConsonant: Bool = false
    public var quickEndConsonant: Bool = false
    public var allowConsonantZFWJ: Bool = false
    public var freeMark: Bool = false
    public var restoreOnEscape: Bool = true
    public var restoreIfWrongSpelling: Bool = true
    public var autoRestoreEnglish: Bool = false
    public var upperCaseFirstChar: Bool = false

    public init() {}
}
