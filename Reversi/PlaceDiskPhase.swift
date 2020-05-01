import Foundation

extension PhaseKind {
    public static let placeDisk = PhaseKind(rawValue: "placeDisk")
}

public struct PlaceDiskPhase: Phase {
    private let x: Int
    private let y: Int
    
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
    
    public var kind: PhaseKind { .placeDisk }
    public var description: String {
        return "\(kind.description)(x=\(x), y=\(y))"
    }

    public func onEnter(previousPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, state) in
            // ボードにディスクを置く。その変更分は `PlacingDiskPhase` で反映。
            if let turn = state.turn {
                dispatcher.dispatch(.placeDisk(disk: turn, x: self.x, y: self.y))
            } else {
                // ゲームが終了しているのにPlaceDiskPhaseに来たということなのでおかしい
                assertionFailure()
            }

        }
    }
    
    public func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .placeDisk(disk: let disk, x: let x, y: let y):
            if let cellChanges = try? state.board.placeDisk(disk, atX: x , y: y) {
                // 置けたら
                state.loop { (dispatcher, _) in
                    dispatcher.dispatch(.changePhase(to: PlacingDiskPhase(cellChanges: cellChanges[...])))
                }
            } else {
                // 置けなかったら `ThinkingPhase` へ
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
