import Foundation

public extension PhaseKind {
    static let placingDisk = PhaseKind(rawValue: "placingDisk")
}

public struct PlacingDiskPhase: Phase {
    private let cellChanges: ArraySlice<Board.CellChange>
    
    public init(cellChanges: ArraySlice<Board.CellChange>) {
        self.cellChanges = cellChanges
    }
    
    public var kind: PhaseKind { .placingDisk }
    
    public static func onEnter(state: State, previousPhase: AnyPhase) -> State {
        var state = state
        
        // 1つ目を取り出して、ゲーム外部に更新を依頼
        let phase = state.phase.base as! PlacingDiskPhase
        if let change = phase.cellChanges.first {
            state.boardUpdateRequest = Request(.withAnimation(change))
        } else {
            // 反映するものがなくなったら、次のターンへ
            state.phase = AnyPhase(NextTurnPhase())
        }
        
        return state
    }
    
    public static func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .boardUpdated(let requestId):
            if let request = state.boardUpdateRequest, request.requestId == requestId {
                // この依頼が反映された
                state.boardUpdateRequest = nil
                
                // 残りの変更の反映を依頼するフェーズへ
                let phase = state.phase.base as! PlacingDiskPhase
                state.phase = AnyPhase(PlacingDiskPhase(cellChanges: phase.cellChanges[1...]))
            }
            
        default:
            break
        }
        
        return state
    }
}
