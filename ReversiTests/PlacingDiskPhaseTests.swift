import XCTest
import Combine
@testable import Reversi

class PlacingDiskPhaseTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()
    var originalDuration: Double = ThinkingPhase.thinkingDuration

    override func setUpWithError() throws {
        cancellables = Set<AnyCancellable>()
        
        // 思考時間を短くしておく
        originalDuration = ThinkingPhase.thinkingDuration
        ThinkingPhase.thinkingDuration = 0.5
    }

    override func tearDownWithError() throws {
        // 思考時間を元に戻す
        ThinkingPhase.thinkingDuration = originalDuration
        
        for cancellable in cancellables {
            cancellable.cancel()
        }
        cancellables = []
    }
    
    func testPlacingDiskPhase1() throws {
        let board = try Board(restoringFromText: """
            o-------
            -o-o----
            --oo-o--
            --xoxox-
            ---xox--
            ---ooooo
            ---o-x--
            --o-----
            """)
        var state = State(board: board, turn: .light, playerModes: [.computer, .manual])
        let cellChanges = [
            Board.CellChange(x: 7, y: 5, disk: .light),
            Board.CellChange(x: 6, y: 5, disk: .light),
            Board.CellChange(x: 5, y: 5, disk: .light),
            Board.CellChange(x: 4, y: 5, disk: .light),
        ]
        state.phase = AnyPhase(PlacingDiskPhase(cellChanges: cellChanges[...]))
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // 1つ目のセルの表示を更新する依頼が発行され、
        let expectBoardUpdateRequest = expectation(description: "Request for board update")
        let stateSubscriber = EventuallyFulfill<State, Never>(expectBoardUpdateRequest, inputChecker: { state in
            if let request = state.boardUpdateRequest {
                if case let .withAnimation(cellChange) = request.detail {
                    if cellChange == cellChanges[0] {
                        return true
                    }
                }
            }
            return false
        })
        gameState.subscribe(stateSubscriber)
        stateSubscriber.store(in: &cancellables)

        if let onEnter = PlacingDiskPhase.onEnter(previousPhase: AnyPhase(PlaceDiskPhase(x: 7, y: 5))) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectBoardUpdateRequest], timeout: 3.0)

        // その依頼が完了するまでは、勝手に次の表示更新には進まずに
        // そのままの状態でとどまる
        let expectBoardUpdateRequestNotChange = expectation(description: "Request for board update")
        expectBoardUpdateRequestNotChange.isInverted = true
        stateSubscriber.reset(expectBoardUpdateRequestNotChange, inputChecker: { state in
            if let request = state.boardUpdateRequest {
                if case let .withAnimation(cellChange) = request.detail {
                    if cellChange == cellChanges[0] {
                        return false
                    }
                }
            }
            return true
        })
        wait(for: [expectBoardUpdateRequestNotChange], timeout: 1.0)
    }

    func testPlacingDiskPhase2() throws {
        let board = try Board(restoringFromText: """
            o-------
            -o-o----
            --oo-o--
            --xoxox-
            ---xox--
            ---ooooo
            ---o-x--
            --o-----
            """)
        var state = State(board: board, turn: .light, playerModes: [.computer, .manual])
        let cellChanges = [
            Board.CellChange(x: 7, y: 5, disk: .light),
            Board.CellChange(x: 6, y: 5, disk: .light),
            Board.CellChange(x: 5, y: 5, disk: .light),
            Board.CellChange(x: 4, y: 5, disk: .light),
        ]
        state.phase = AnyPhase(PlacingDiskPhase(cellChanges: cellChanges[...]))
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // 依頼を完了していけば、次々と依頼が発行されて、
        // 最終的にNextTurnフェーズに遷移する
        var requestedChanges = [Board.CellChange]()
        gameState
            .compactMap { (state) -> (requestId: UniqueIdentifier, cellChange: Board.CellChange)? in
                if let request = state.boardUpdateRequest {
                     if case let .withAnimation(cellChange) = request.detail {
                        return (requestId: request.requestId, cellChange: cellChange)
                    }
                }
                return nil
            }
            .removeDuplicates { $0.requestId == $1.requestId }
            .sink { value in
                requestedChanges.append(value.cellChange)
                DispatchQueue.main.async {
                    game.dispatch(.boardUpdated(requestId: value.requestId))
                }
            }
            .store(in: &cancellables)
        
        let expectPhaseToBeNextTurn = expectation(description: "Phase transits to 'NextTurn'")
        let stateSubscriber = EventuallyFulfill<State, Never>(expectPhaseToBeNextTurn, inputChecker: { state in
            return state.phase.kind == .nextTurn
        })
        gameState.subscribe(stateSubscriber)
        stateSubscriber.store(in: &cancellables)

        if let onEnter = PlacingDiskPhase.onEnter(previousPhase: AnyPhase(PlaceDiskPhase(x: 7, y: 5))) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectPhaseToBeNextTurn], timeout: 3.0)
        XCTAssertEqual(requestedChanges, cellChanges)
    }
}
