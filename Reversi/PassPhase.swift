import Foundation

extension PhaseKind {
    public static let pass = PhaseKind(rawValue: "pass")
}

public struct PassPhase: Phase {
    public var kind: PhaseKind { .pass }
    
    public static func onEnter(previousPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, _) in
            // パスの表示をゲーム外部に依頼
            dispatcher.dispatch(.requestPassNotification(true))
        }
    }
    
    public static func onExit(nextPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, _) in
            // パス表示リクエストを取り下げ
            dispatcher.dispatch(.requestPassNotification(false))
        }
    }
    
    public static func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .passDismissed(let requestId):
            if let request = state.passNotificationRequest, request.requestId == requestId {
                // パス表示を消したら次のターンへ
                state.loop { (dispatcher, _) in
                    dispatcher.dispatch(.changePhase(to: NextTurnPhase()))
                }
            }
            
        default:
            break
        }
        
        return state
    }
}
