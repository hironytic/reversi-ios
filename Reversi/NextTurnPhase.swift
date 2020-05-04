import Foundation

extension PhaseKind {
    public static let nextTurn = PhaseKind(rawValue: "nextTurn")
}

public struct NextTurnPhase: Phase {
    public var kind: PhaseKind { .nextTurn }
    
    public static func onEnter(previousPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, state) in
            dispatcher.dispatch(.nextTurn())
        }
    }
    
    public static func onExit(nextPhase: AnyPhase) -> Thunk? {
        // 次がGameOverの場合はそちらでセーブ依頼を出してもらう
        guard nextPhase.kind != .gameOver else { return nil }
        
        return { (dispatcher, _) in
            dispatcher.dispatch(.requestSave())
        }
    }
    
    public static func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .nextTurn:
            // ディスク枚数をカウント
            for disk in Disk.sides {
                state.diskCount[disk] = state.board.countDisks(of: disk)
            }
            
            state.turn?.flip()
            
            if let turn = state.turn {
                if state.board.validMoves(for: turn).isEmpty {
                    if state.board.validMoves(for: turn.flipped).isEmpty {
                        // 両方が置けなかったらゲーム終了
                        state.loop { (dispatcher, _) in
                            dispatcher.dispatch(.changePhase(to: GameOverPhase()))
                        }
                    } else {
                        // 相手は置けるのであれば「パス」
                        state.loop { (dispatcher, _) in
                            dispatcher.dispatch(.changePhase(to: PassPhase()))
                        }
                    }
                } else {
                    // 置けるのなら入力待ちへ
                    state.loop { (dispatcher, _) in
                        dispatcher.dispatch(.changePhase(to: WaitForPlayerPhase()))
                    }                    }
            } else {
                // ゲーム終了しているのに NextTurnPhase に来たのがおかしい
                assertionFailure()
            }

        default:
            break
        }
        
        return state
    }
}
