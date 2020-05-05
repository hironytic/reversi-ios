import Foundation

extension PhaseKind {
    public static let waitForPlayer = PhaseKind(rawValue: "waitForPlayer")
}

public struct WaitForPlayerPhase: Phase {
    public var kind: PhaseKind { .waitForPlayer }
    
    public static func onEnter(previousPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, state) in
            if let turn = state.turn {
                // 置けないときは「パス」へ
                if state.board.validMoves(for: turn).isEmpty {
                    dispatcher.dispatch(.changePhase(to: PassPhase()))
                    return
                }
                
                // このターンがコンピューターに任せられているのなら
                // コンピューターの思考フェーズへ遷移させる
                if state.playerModes[turn] == .computer {
                    dispatcher.dispatch(.changePhase(to: ThinkingPhase()))
                }
            } else {
                // ターンがなくなっていればGameOver
                dispatcher.dispatch(.changePhase(to: GameOverPhase()))
            }
        }
    }
    
    public static func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .boardCellSelected(x: let x, y: let y):
            state.loop { (dispatcher, _) in
                dispatcher.dispatch(.changePhase(to: PlaceDiskPhase(x: x, y: y)))
            }
        
        case .playerModeChanged(player: let disk, mode: let mode):
            if state.turn == disk && mode == .computer {
                // このターンのプレイヤーモードがコンピューターに変更されたら
                // コンピューターの思考フェーズへ遷移させる
                state.loop { (dispatcher, _) in
                    dispatcher.dispatch(.changePhase(to: ThinkingPhase()))
                }
            }
            
        default:
            break
        }
        
        return state
    }
}
