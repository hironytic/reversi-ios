import Foundation

extension PhaseKind {
    public static let placingDisk = PhaseKind(rawValue: "placingDisk")
}

public struct PlacingDiskPhase: Phase {
    private let cellChanges: ArraySlice<Board.CellChange>
    
    public init(cellChanges: ArraySlice<Board.CellChange>) {
        self.cellChanges = cellChanges
    }
    
    public var kind: PhaseKind { .placingDisk }
    
    public func onEnter(state: State, previousPhase: AnyPhase) -> State {
        var state = state
        
        // 1つ目を取り出して、ゲーム外部に更新を依頼
        if let change = self.cellChanges.first {
            state.boardUpdateRequest = Request(.withAnimation(change))
        } else {
            // 反映するものがなくなったら、次のターンへ
            state.phase = AnyPhase(NextTurnPhase())
        }
        
        return state
    }
    
    public func onExit(state: State, nextPhase: AnyPhase) -> State {
        var state = state

        state.boardUpdateRequest = nil
        
        return state
    }
    
    public func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .boardUpdated(let requestId):
            if let request = state.boardUpdateRequest, request.requestId == requestId {
                // 残りの変更の反映を依頼するフェーズへ
                state.phase = AnyPhase(PlacingDiskPhase(cellChanges: self.cellChanges[1...]))
            }
            
        default:
            break
        }
        
        return state
    }
}
