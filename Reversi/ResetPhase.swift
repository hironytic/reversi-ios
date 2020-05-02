import Foundation

extension PhaseKind {
    public static let reset = PhaseKind(rawValue: "reset")
}

public struct ResetPhase: Phase {
    public var kind: PhaseKind { .reset }
    
    public static func onEnter(previousPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, _) in
            dispatcher.dispatch(.doReset())
        }
    }
    
    public static func onExit(nextPhase: AnyPhase) -> Thunk? {
        // TODO: セーブ
        return nil
    }
    
    public static func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .doReset:
            // リセットして、入力待ちフェーズへ遷移
            let cellChanges = state.board.reset()
            state.boardUpdateRequest = DetailedRequest(.withoutAnimation(cellChanges))
            state.turn = .dark
            state.playerModes = state.playerModes.map { _ in .manual }
            state.thinking = false
            for disk in Disk.sides {
                state.diskCount[disk] = state.board.countDisks(of: disk)
            }
            state.boardUpdateRequest = nil
            state.passNotificationRequest = nil
            state.resetConfirmationRequst = nil
            state.loop { (dispatcher, _) in
                dispatcher.dispatch(.changePhase(to: WaitForPlayerPhase()))
            }

        default:
            break
        }
        
        return state
    }
}
