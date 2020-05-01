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
    public var description: String {
        return "\(kind.description)(\(cellChanges.count) change(s) left)"
    }

    public func onEnter(previousPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, state) in
            // 1つ目を取り出して、ゲーム外部に更新を依頼
            if let change = self.cellChanges.first {
                dispatcher.dispatch(.setState { state in
                    var state = state
                    state.boardUpdateRequest = DetailedRequest(.withAnimation(change))
                    return state
                })
            } else {
                // 反映するものがなくなったら、次のターンへ
                dispatcher.dispatch(.changePhase(to: NextTurnPhase()))
            }
        }
    }
    
    public func onExit(nextPhase: AnyPhase) -> Thunk? {
        return { (dispatcher, state) in
            dispatcher.dispatch(.setState { state in
                var state = state
                state.boardUpdateRequest = nil
                return state
            })
        }
    }
    
    public func reduce(state: State, action: Action) -> State {
        var state = state
        
        switch action {
        case .boardUpdated(let requestId):
            if let request = state.boardUpdateRequest, request.requestId == requestId {
                // 残りの変更の反映を依頼するフェーズへ
                state.thunks.append { (dispatcher, _) in
                    dispatcher.dispatch(.changePhase(to: PlacingDiskPhase(cellChanges: self.cellChanges[self.cellChanges.startIndex.advanced(by: 1)...])))
                }
            }
            
        default:
            break
        }
        
        return state
    }
}
