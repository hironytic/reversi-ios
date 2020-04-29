import Foundation

extension PhaseKind {
    public static let thinking = PhaseKind(rawValue: "thinking")
}

public struct ThinkingPhase: Phase {
    private let thinkingId = UniqueIdentifier()
    private let thinkingDuration: Double
    
    public init(thinkingDuration: Double = 2.0) {
        self.thinkingDuration = thinkingDuration
    }
    
    public var kind: PhaseKind { .thinking }
    
    public static func onEnter(state: State, previousPhase: AnyPhase) -> State {
        if let turn = state.turn {
            // 思考を開始
            if let (x, y) = state.board.validMoves(for: turn).randomElement() {
                // 実はもう打つ手は決まったのだが、もったいぶって（？）
                // 時間を置いてから打つ
                let phase = state.phase.base as! ThinkingPhase
                let currentId = phase.thinkingId
                DispatchQueue.main.asyncAfter(deadline: .now() + phase.thinkingDuration) {
                    if let game = Game.current {
                        game.dispatch { state in
                            // 時間をつぶして戻ってきてもまだこのフェーズにいるときだけ打つ。
                            if let phase = state.phase.base as? ThinkingPhase, phase.thinkingId == currentId {
                                return .boardCellSelected(x: x, y: y)
                            }
                            return nil
                        }
                    }
                }
            }
        }

        return state
    }
    
    public static func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .playerModeChanged(player: let player, mode: let mode):
            if let turn = state.turn, turn == player && mode == .manual {
                // 現在の対象のプレイヤーがマニュアルに変更されたら
                // 入力待ちフェーズへ遷移
                state.phase = AnyPhase(WaitForPlayerPhase())
            }
            
        case .boardCellSelected(x: let x, y: let y):
            state.phase = AnyPhase(PlaceDiskPhase(x: x, y: y))
            
        default:
            break
        }
        
        return state
    }
}
