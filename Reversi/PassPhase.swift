import Foundation

extension PhaseKind {
    public static let pass = PhaseKind(rawValue: "pass")
}

public struct PassPhase: Phase {
    public var kind: PhaseKind { .pass }
    
    public func onEnter(previousPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, _) in
            dispatcher.dispatch(.setState { state in
                var state = state
                
                // パスの表示をゲーム外部に依頼
                state.passNotificationRequest = Request()
                
                return state
            })
        }
    }
    
    public func onExit(state: State, nextPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, _) in
            dispatcher.dispatch(.setState { state in
                var state = state
                state.passNotificationRequest = nil
                return state
            })
        }
    }
    
    public func reduce(state: State, action: Action) -> State {
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
