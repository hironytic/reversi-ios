import Foundation

extension PhaseKind {
    public static let initial = PhaseKind(rawValue: "initial")
}

public struct InitialPhase: Phase {
    public var kind: PhaseKind { .initial }

    public static func onExit(nextPhase: AnyPhase) -> Thunk? {
        // ゲームの準備が整って始まったところでいろいろ初期化する
        return { (dispatcher, _) in
            dispatcher.dispatch(.initializeStateWhenStarted())
        }
    }
    
    public static func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .start:
            state.loop { (dispatcher, state) in
                dispatcher.dispatch(.changePhase(to: WaitForPlayerPhase()))
            }
        default:
            break
        }
        
        return state
    }
}
