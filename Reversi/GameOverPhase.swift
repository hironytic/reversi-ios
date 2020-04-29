import Foundation

public extension PhaseKind {
    static let gameOver = PhaseKind(rawValue: "gameOver")
}

public struct GameOverPhase: Phase {
    public var kind: PhaseKind { .gameOver }
}
