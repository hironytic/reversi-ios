import XCTest
import Combine
@testable import Reversi

class PlaceDiskPhaseTests: XCTestCase {
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
    
    func testPlaceDiskPhase1() throws {
        var board = try Board(restoringFromText: """
            o-------
            -o-o----
            --oo-o--
            --xoxox-
            ---xox--
            ---oxxx-
            ---o-x--
            --o-----
            """)
        var state = State(board: board, turn: .light, playerModes: [.computer, .manual])
        state.phase = AnyPhase(PlaceDiskPhase(x: 7, y: 5))
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // 打てたらアニメーションさせるセルの情報を引き連れてPlacingDiskへ遷移
        let cellChanges = try board.placeDisk(.light, atX: 7, y: 5)[...]
        let expectPhaseToBePlacingDisk = expectation(description: "Phase transits to 'PlacingDisk'")
        let stateSubscriber = EventuallyFulfill<State, Never>(expectPhaseToBePlacingDisk, inputChecker: { state in
            guard let phase = PlacingDiskPhase.thisPhase(of: state) else { return false }
            guard phase.cellChanges == cellChanges else { return false }
            
            return true
        })
        gameState.subscribe(stateSubscriber)
        stateSubscriber.store(in: &cancellables)

        if let onEnter = PlaceDiskPhase.onEnter(previousPhase: AnyPhase(WaitForPlayerPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectPhaseToBePlacingDisk], timeout: 3.0)
    }
    
    func testPlaceDiskPhase2() throws {
        let board = try Board(restoringFromText: """
            o-------
            -o-o----
            --oo-o--
            --xoxox-
            ---xox--
            ---oxxx-
            ---o-x--
            --o-----
            """)
        var state = State(board: board, turn: .light, playerModes: [.computer, .manual])
        state.phase = AnyPhase(PlaceDiskPhase(x: 2, y: 2))
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // 打てないところに打とうとしているので、
        // WaitForPlayerフェーズに戻る
        let expectPhaseToBeWaitForPlayer = expectation(description: "Phase transits to 'WaitForPlayer'")
        let stateSubscriber = EventuallyFulfill<State, Never>(expectPhaseToBeWaitForPlayer, inputChecker: { state in
            return state.phase.kind == .waitForPlayer
        })
        gameState.subscribe(stateSubscriber)
        stateSubscriber.store(in: &cancellables)

        if let onEnter = PlaceDiskPhase.onEnter(previousPhase: AnyPhase(WaitForPlayerPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectPhaseToBeWaitForPlayer], timeout: 3.0)
    }
}
