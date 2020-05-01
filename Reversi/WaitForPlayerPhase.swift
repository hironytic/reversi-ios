import Foundation

extension PhaseKind {
    public static let waitForPlayer = PhaseKind(rawValue: "waitForPlayer")
}

public struct WaitForPlayerPhase: Phase {
    public var kind: PhaseKind { .waitForPlayer }
    
    public func onEnter(previousPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, state) in
            // このターンがコンピューターに任せられているのなら
            // コンピューターの思考フェーズへ遷移させる
            if let turn = state.turn, state.playerModes[turn] == .computer {
                dispatcher.dispatch(.changePhase(to: ThinkingPhase()))
            }
        }
    }
    
    public func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .boardCellSelected(x: let x, y: let y):
            state.thunks.append { (dispatcher, _) in
                dispatcher.dispatch(.changePhase(to: PlaceDiskPhase(x: x, y: y)))
            }
            
        default:
            break
        }
        
        return state
    }
}
