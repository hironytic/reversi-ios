import Foundation

extension PhaseKind {
    public static let gameOver = PhaseKind(rawValue: "gameOver")
}

public struct GameOverPhase: Phase {
    public var kind: PhaseKind { .gameOver }
    
    public static func onEnter(previousPhase: AnyPhase) -> Thunk? {
        // ゲームオーバーにする
        return { (dispatcher, _) in
            dispatcher.dispatch(.gameOver())
        }
    }
    
    public static func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .gameOver:
            state.turn = nil
            state.loop { (dispatcher, _) in
                dispatcher.dispatch(.requestSave())
            }
            
        default:
            break
        }
        
        return state
    }
}
