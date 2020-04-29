import Foundation

extension PhaseKind {
    public static let initial = PhaseKind(rawValue: "initial")
}

public struct InitialPhase: Phase {
    public var kind: PhaseKind { .initial }

    public func onExit(state: State, nextPhase: AnyPhase) -> State {
        var state = state
        
        // ゲームの準備が整って始まったところでいろいろ初期化して外部に伝える
        state.thinking = false
        for disk in Disk.sides {
            state.diskCount[disk] = state.board.countDisks(of: disk)
        }
        state.boardUpdateRequest = nil
        state.passNotificationRequest = nil
        state.resetConfirmationRequst = nil

        return state
    }
    
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
