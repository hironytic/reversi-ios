import Foundation

extension PhaseKind {
    public static let nextTurn = PhaseKind(rawValue: "nextTurn")
}

public struct NextTurnPhase: Phase {
    public var kind: PhaseKind { .nextTurn }
    
    public func onEnter(previousPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, state) in
            dispatcher.dispatch(.setState { state in
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
                            state.thunks.append { (dispatcher, _) in
                                dispatcher.dispatch(.changePhase(to: GameOverPhase()))
                            }
                        } else {
                            // 相手は置けるのであれば「パス」
                            state.thunks.append { (dispatcher, _) in
                                dispatcher.dispatch(.changePhase(to: PassPhase()))
                            }
                        }
                    } else {
                        // 置けるのなら入力待ちへ
                        state.thunks.append { (dispatcher, _) in
                            dispatcher.dispatch(.changePhase(to: WaitForPlayerPhase()))
                        }                    }
                } else {
                    // ゲーム終了しているのに NextTurnPhase に来たのがおかしい
                    assertionFailure()
                }
                
                return state
            })
        }
    }
    
    public func onExit(nextPhase: AnyPhase) -> Thunk? {
        // TODO: セーブ
        return nil
    }
}
