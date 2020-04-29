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
    
    public static func onEnter(state: State, previousPhase: AnyPhase) -> State {
        var state = state
        
        // ボードにディスクを置く。その変更分は `PlacingDiskPhase` で反映。
        if let turn = state.turn {
            let phase = state.phase.base as! PlaceDiskPhase
            if let cellChanges = try? state.board.placeDisk(turn, atX: phase.x , y: phase.y) {
                // 置けたら
                state.phase = AnyPhase(PlacingDiskPhase(cellChanges: cellChanges[...]))
            }
        }
        
        return state
    }
}
