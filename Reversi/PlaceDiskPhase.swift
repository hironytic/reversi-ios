import Foundation

extension PhaseKind {
    public static let placeDisk = PhaseKind(rawValue: "placeDisk")
}

public struct PlaceDiskPhase: Phase {
    public let x: Int
    public let y: Int
    
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
    
    public var kind: PhaseKind { .placeDisk }
    public var description: String {
        return "\(kind.description)(x=\(x), y=\(y))"
    }

    public static func onEnter(previousPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, state) in
            guard let turn = state.turn else {
                // ゲームが終了しているのにPlaceDiskPhaseに来たということなのでおかしい
                assertionFailure()
                return
            }

            // ボードにディスクを置く。その変更分は `PlacingDiskPhase` で反映。
            if let phase = thisPhase(of: state) {
                dispatcher.dispatch(.placeDisk(disk: turn, x: phase.x, y: phase.y))
            }
        }
    }
    
    public static func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .placeDisk(disk: let disk, x: let x, y: let y):
            if let cellChanges = try? state.board.placeDisk(disk, atX: x , y: y) {
                // 置けたら
                state.loop { (dispatcher, _) in
                    dispatcher.dispatch(.changePhase(to: PlacingDiskPhase(cellChanges: cellChanges[...])))
                }
            } else {
                // 置けなかったら `WaitForPlayer` へ
                state.loop { (dispatcher, _) in
                    dispatcher.dispatch(.changePhase(to: WaitForPlayerPhase()))
                }
            }
            
        default:
            break
        }
        
        return state
    }
}
