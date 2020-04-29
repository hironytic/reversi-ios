import Foundation

extension PhaseKind {
    public static let waitForPlayer = PhaseKind(rawValue: "waitForPlayer")
}

public struct WaitForPlayerPhase: Phase {
    public var kind: PhaseKind { .waitForPlayer }
    
    public func onEnter(state: State, previousPhase: AnyPhase) -> State {
        var state = state
        
        // このターンがコンピューターに任せられているのなら
        // コンピューターの思考フェーズへ遷移させる
        if let turn = state.turn, state.playerModes[turn] == .computer {
            state.phase = AnyPhase(ThinkingPhase())
        }
        
        return state
    }
    
    public func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .boardCellSelected(x: let x, y: let y):
            state.phase = AnyPhase(PlaceDiskPhase(x: x, y: y))
            
        default:
            break
        }
        
        return state
    }
}
