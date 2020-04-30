import Foundation

extension PhaseKind {
    public static let thinking = PhaseKind(rawValue: "thinking")
}

public struct ThinkingPhase: Phase {
    public static var thinkingDuration: Double = 2.0
    
    private let thinkingId = UniqueIdentifier()
    
    public var kind: PhaseKind { .thinking }
    public var description: String {
        return "\(kind.description)(thinkingId=\(thinkingId))"
    }
    
    public func onEnter(previousPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, state) in
            if let turn = state.turn {
                // 思考を開始
                dispatcher.dispatch(ActionCreators.setState { state in
                    var state = state
                    state.thinking = true
                    return state
                })
                
                if let (x, y) = state.board.validMoves(for: turn).randomElement() {
                    // 実はもう打つ手は決まったのだが、もったいぶって（？）
                    // 時間を置いてから打つ
                    DispatchQueue.main.asyncAfter(deadline: .now() + ThinkingPhase.thinkingDuration) {
                        dispatcher.dispatch({ (dispatcher, state) in
                            // 時間をつぶして戻ってきてもまだこのフェーズにいるときだけ打つ。
                            if let phase = state.phase.base as? ThinkingPhase, phase.thinkingId == self.thinkingId {
                                dispatcher.dispatch(.boardCellSelected(x: x, y: y))
                            }
                        })
                    }
                } else {
                    // 打つところがないのにThinkingPhaseになったということなのでおかしい
                    assertionFailure()
                }
            } else {
                // ゲームが終了しているのにThinkingPhaseになったということなのでおかしい
                assertionFailure()
            }
        }
    }
    
    public func onExit(nextPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, state) in
            dispatcher.dispatch(ActionCreators.setState { state in
                var state = state
                state.thinking = false
                return state
            })
        }
    }
    
    public func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .playerModeChanged(player: let player, mode: let mode):
            if let turn = state.turn, turn == player && mode == .manual {
                // 現在の対象のプレイヤーがマニュアルに変更されたら
                // 入力待ちフェーズへ遷移
                state.thunks.append { (dispatcher, _) in
                    dispatcher.dispatch(ActionCreators.changePhase(to: WaitForPlayerPhase()))
                }
            }
            
        case .boardCellSelected(x: let x, y: let y):
            state.thunks.append { (dispatcher, _) in
                dispatcher.dispatch(ActionCreators.changePhase(to: PlaceDiskPhase(x: x, y: y)))
            }
            
        default:
            break
        }
        
        return state
    }
}
