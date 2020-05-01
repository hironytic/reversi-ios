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
                dispatcher.dispatch(.setState { state in
                    var state = state
                    if let cellChanges = try? state.board.placeDisk(turn, atX: self.x , y: self.y) {
                        // 置けたら
                        state.thunks.append { (dispatcher, _) in
                            dispatcher.dispatch(.changePhase(to: PlacingDiskPhase(cellChanges: cellChanges[...])))
                        }
                    } else {
                        // 置けなかったら `ThinkingPhase` へ
                        state.thunks.append { (dispatcher, _) in
                            dispatcher.dispatch(.changePhase(to: ThinkingPhase()))
                        }
                    }
                    return state
                })
            } else {
                // ゲームが終了しているのにPlaceDiskPhaseに来たということなのでおかしい
                assertionFailure()
            }

        }
    }
}
