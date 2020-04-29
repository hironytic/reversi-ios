import Foundation

extension PhaseKind {
    public static let initial = PhaseKind(rawValue: "initial")
}

public struct InitialPhase: Phase {
    public var kind: PhaseKind { .initial }
    
    public func reduce(state: State, action: Action) -> State {
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
