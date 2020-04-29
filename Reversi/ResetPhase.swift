import Foundation

extension PhaseKind {
    public static let reset = PhaseKind(rawValue: "reset")
}

public struct ResetPhase: Phase {
    public var kind: PhaseKind { .reset }
    
    public func onEnter(state: State, previousPhase: AnyPhase) -> State {
        var state = state
        
        // リセットして、入力待ちフェーズへ遷移
        let cellChanges = state.board.reset()
        state.boardUpdateRequest = Request(.withoutAnimation(cellChanges))
        state.turn = .dark
        state.playerModes = state.playerModes.map { _ in .manual }
        state.phase = AnyPhase(WaitForPlayerPhase())

        return state
    }
    
    public func onExit(state: State, nextPhase: AnyPhase) -> State {
        // TODO: セーブ
        return state
    }
}
