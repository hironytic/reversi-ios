import Foundation

extension PhaseKind {
    public static let initial = PhaseKind(rawValue: "initial")
}

public struct InitialPhase: Phase {
    public var kind: PhaseKind { .initial }

    public func onExit(nextPhase: AnyPhase) -> Thunk? {
        // ゲームの準備が整って始まったところでいろいろ初期化する
        return { (dispatcher, _) in
            dispatcher.dispatch(.setState { state in
                var state = state
                                
                state.thinking = false
                for disk in Disk.sides {
                    state.diskCount[disk] = state.board.countDisks(of: disk)
                }
                state.boardUpdateRequest = nil
                state.passNotificationRequest = nil
                state.resetConfirmationRequst = nil

                return state
            })
        }
    }
    
    public func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .start:
            state.thunks.append { (dispatcher, state) in
                dispatcher.dispatch(.changePhase(to: WaitForPlayerPhase()))
            }
        default:
            break
        }
        
        return state
    }
}
