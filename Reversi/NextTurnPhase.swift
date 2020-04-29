import Foundation

extension PhaseKind {
    public static let nextTurn = PhaseKind(rawValue: "nextTurn")
}

public struct NextTurnPhase: Phase {
    public var kind: PhaseKind { .nextTurn }
    
    public func onEnter(state: State, previousPhase: AnyPhase) -> State {
        var state = state

        // ディスク枚数をカウント
        for disk in Disk.sides {
            state.diskCount[disk] = state.board.countDisks(of: disk)
        }
        
        state.turn?.flip()
        
        if let turn = state.turn {
            if state.board.validMoves(for: turn).isEmpty {
                if state.board.validMoves(for: turn.flipped).isEmpty {
                    // 両方が置けなかったらゲーム終了
                    state.phase = AnyPhase(GameOverPhase())
                } else {
                    // 相手は置けるのであれば「パス」
                    state.phase = AnyPhase(PassPhase())
                }
            } else {
                // 置けるのなら入力待ちへ
                state.phase = AnyPhase(WaitForPlayerPhase())
            }
        } else {
            assertionFailure()
        }
        
        return state
    }
    
    public func onExit(state: State, nextPhase: AnyPhase) -> State {
        // TODO: セーブ
        return state
    }
}
