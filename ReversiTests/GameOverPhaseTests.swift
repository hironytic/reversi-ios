import XCTest
import Combine
@testable import Reversi

class GameOverPhaseTests: XCTestCase {
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
    
    func testGameOverPhase() throws {
        let board = try Board(restoringFromText: """
            --------
            --------
            ----x---
            ---xxx--
            --xxxxx-
            ---xxx--
            ----x---
            --------
            """)
        var state = State(board: board, turn: .dark, playerModes: [.manual, .manual])
        state.diskCount[.dark] = 13
        state.diskCount[.light] = 0
        state.phase = AnyPhase(GameOverPhase())

        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // ターンがnilに変わる
        let expectTurnChange = expectation(description: "Turn changed to nil")
        let stateSubscriber = EventuallyFulfill<State, Never>(expectTurnChange, inputChecker: { state in
            return state.turn == nil
        })
        gameState.subscribe(stateSubscriber)
        stateSubscriber.store(in: &cancellables)

        if let onEnter = GameOverPhase.onEnter(previousPhase: AnyPhase(NextTurnPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectTurnChange], timeout: 3.0)
        
        // そのまま待っていても、GameOverのまま
        let expectGameOver = expectation(description: "Still game over")
        expectGameOver.isInverted = true
        stateSubscriber.reset(expectTurnChange, inputChecker: { state in
            return state.phase.kind != .gameOver
        })
        wait(for: [expectGameOver], timeout: 1.0)
    }
}
