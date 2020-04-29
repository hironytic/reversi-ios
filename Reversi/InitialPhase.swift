import Foundation

public extension PhaseKind {
    static let initial = PhaseKind(rawValue: "initial")
}

public struct InitialPhase: Phase {
    public var kind: PhaseKind { .initial }
    
    public static func reduce(state: State, action: Action) -> State {
        var reducedState = state
        
        switch action {
        case .start:
            reducedState.phase = AnyPhase(WaitForPlayerPhase())
        default:
            break
        }
        
        return reducedState
    }
}
