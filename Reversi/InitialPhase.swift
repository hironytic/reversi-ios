import Foundation

public extension PhaseKind {
    static let initial = PhaseKind(rawValue: "initial")
}

public struct InitialPhase: Phase {
    public var kind: PhaseKind { .initial }
    
    public static func reduce(state: State, action: Action) -> State {
        // TODO:
        return state
    }
}
