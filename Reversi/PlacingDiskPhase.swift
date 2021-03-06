import Foundation

extension PhaseKind {
    public static let placingDisk = PhaseKind(rawValue: "placingDisk")
}

public struct PlacingDiskPhase: Phase {
    public let cellChanges: ArraySlice<Board.CellChange>
    
    public init(cellChanges: ArraySlice<Board.CellChange>) {
        self.cellChanges = cellChanges
    }
    
    public var kind: PhaseKind { .placingDisk }
    public var description: String {
        return "\(kind.description)(\(cellChanges.count) change(s) left)"
    }

    public static func onEnter(previousPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, state) in
            if let phase = thisPhase(of: state) {
                // 1つ目を取り出して、ゲーム外部に更新を依頼
                if let change = phase.cellChanges.first {
                    dispatcher.dispatch(.requestUpdateBoard(request: DetailedRequest(.withAnimation(change))))
                } else {
                    // 反映するものがなくなったら、次のターンへ
                    dispatcher.dispatch(.changePhase(to: NextTurnPhase()))
                }
            }
        }
    }
    
    public static func onExit(nextPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, state) in
            dispatcher.dispatch(.requestUpdateBoard(request: nil))
        }
    }
    
    public static func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .boardUpdated(let requestId):
            if let request = state.boardUpdateRequest, request.requestId == requestId {
                // 残りの変更の反映を依頼するフェーズへ
                state.loop { (dispatcher, state) in
                    if let cellChanges = thisPhase(of: state)?.cellChanges {
                        dispatcher.dispatch(.changePhase(to: PlacingDiskPhase(cellChanges: cellChanges[cellChanges.startIndex.advanced(by: 1)...])))
                    }
                }
            }
            
        default:
            break
        }
        
        return state
    }
}
