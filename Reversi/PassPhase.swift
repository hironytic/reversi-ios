import Foundation

public extension PhaseKind {
    static let pass = PhaseKind(rawValue: "pass")
}

public struct PassPhase: Phase {
    public var kind: PhaseKind { .pass }
    
    public static func onEnter(state: State, previousPhase: AnyPhase) -> State {
        var state = state
        
        // パスの表示をゲーム外部に依頼
        state.passNotificationRequest = Request()
        
        return state
    }
    
    public static func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .passNotified(let requestId):
            if let request = state.passNotificationRequest, request.requestId == requestId {
                state.passNotificationRequest = nil
            }
            
        case .passDismissed:
            // パス表示を消したら次のターンへ
            state.phase = AnyPhase(NextTurnPhase())
            
        default:
            break
        }
        
        return state
    }
}
