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
    
    public static func onEnter(previousPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, state) in
            guard let turn = state.turn else {
                // ゲームが終了しているのにThinkingPhaseになったということなのでおかしい
                assertionFailure()
                return
            }
            
            // 思考を開始
            dispatcher.dispatch(.setThinking(true))
            
            guard let (x, y) = state.board.validMoves(for: turn).randomElement() else {
                // 打つところがないのにThinkingPhaseになったということなのでおかしい
                assertionFailure()
                return
            }
            
            // 実はもう打つ手は決まったのだが、もったいぶって（？）
            // 時間を置いてから打つ
            if let thinkingId = thisPhase(of: state)?.thinkingId {
                DispatchQueue.main.asyncAfter(deadline: .now() + ThinkingPhase.thinkingDuration) {
                    dispatcher.dispatch(.thunk({ (dispatcher, state) in
                        // 時間をつぶして戻ってきてもまだこのフェーズにいるときだけ打つ。
                        if let phase = thisPhase(of: state), phase.thinkingId == thinkingId {
                            dispatcher.dispatch(.boardCellSelected(x: x, y: y))
                        }
                    }))
                }
            }
        }
    }
    
    public static func onExit(nextPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, state) in
            // 思考を終了
            dispatcher.dispatch(.setThinking(false))
        }
    }
    
    public static func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .playerModeChanged(player: let player, mode: let mode):
            if let turn = state.turn, turn == player && mode == .manual {
                // 現在の対象のプレイヤーがマニュアルに変更されたら
                // 入力待ちフェーズへ遷移
                
                // TODO: セーブ
                state.loop { (dispatcher, _) in
                    dispatcher.dispatch(.requestSave())
                    dispatcher.dispatch(.changePhase(to: WaitForPlayerPhase()))
                }
            }
            
        case .boardCellSelected(x: let x, y: let y):
            state.loop { (dispatcher, _) in
                dispatcher.dispatch(.changePhase(to: PlaceDiskPhase(x: x, y: y)))
            }
            
        default:
            break
        }
        
        return state
    }
}
