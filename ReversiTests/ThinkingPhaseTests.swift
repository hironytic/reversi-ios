import XCTest
import Combine
@testable import Reversi

class ThinkingPhaseTests: XCTestCase {
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
    
    func testThinkingPhase1() throws {
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
        var state = State(board: board, turn: .dark, playerModes: [.computer, .manual])
        state.phase = AnyPhase(ThinkingPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // 思考中になったらぐるぐるする
        let expectThinking = expectation(description: "'thining' in state is true")
        let stateSubscriber = EventuallyFulfill<State, Never>(expectThinking, inputChecker: { state in
            return state.thinking
        })
        gameState.subscribe(stateSubscriber)
        stateSubscriber.store(in: &cancellables)
        
        if let onEnter = ThinkingPhase.onEnter(previousPhase: AnyPhase(WaitForPlayerPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectThinking], timeout: 3.0)
    }
    
    func testThinkingPhase2() throws {
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
        var state = State(board: board, turn: .dark, playerModes: [.computer, .manual])
        state.phase = AnyPhase(ThinkingPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // 思考中になり、しばらく待っていたら、ディスクを打つ（PlaceDiskフェーズへ遷移する）
        // そしたらまた、思考中でなくなる。
        var hasEverBeenThinking = false
        let expectThinking = expectation(description: "'thining' in state becomes true and then false")
        let stateSubscriber1 = EventuallyFulfill<State, Never>(expectThinking, inputChecker: { state in
            if !hasEverBeenThinking && state.thinking {
                hasEverBeenThinking = true
            }
            return hasEverBeenThinking && !state.thinking
        })
        gameState.subscribe(stateSubscriber1)
        stateSubscriber1.store(in: &cancellables)
        
        let expectPhaseToBePlaceDisk = expectation(description: "Computer automatically place the disk")
        let stateSubscriber2 = EventuallyFulfill<State, Never>(expectPhaseToBePlaceDisk, inputChecker: { state in
            return state.phase.kind == .placeDisk
        })
        gameState.subscribe(stateSubscriber2)
        stateSubscriber2.store(in: &cancellables)

        if let onEnter = ThinkingPhase.onEnter(previousPhase: AnyPhase(WaitForPlayerPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectThinking, expectPhaseToBePlaceDisk], timeout: 3.0)
    }
    
    func testThinkingPhase3() throws {
        ThinkingPhase.thinkingDuration = 3.0
        
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
        var state = State(board: board, turn: .dark, playerModes: [.computer, .manual])
        state.phase = AnyPhase(ThinkingPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // 思考中になってぐるぐるし始めたあと、
        let expectThinking = expectation(description: "'thining' in state is true")
        let stateSubscriber1 = EventuallyFulfill<State, Never>(expectThinking, inputChecker: { state in
            return state.thinking
        })
        gameState.subscribe(stateSubscriber1)
        stateSubscriber1.store(in: &cancellables)
        if let onEnter = ThinkingPhase.onEnter(previousPhase: AnyPhase(WaitForPlayerPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectThinking], timeout: 3.0)

        // 思考中の間に黒のプレイヤーモードをmanualに変えたら
        // WaitForPlayerフェーズに戻る
        // そのとき思考中ではなくなる
        let expectPhaseToBeWaitForPlayer = expectation(description: "Phase transits to 'WaitForPlayer'")
        let stateSubscriber2 = EventuallyFulfill<State, Never>(expectPhaseToBeWaitForPlayer, inputChecker: { state in
            return state.phase.kind == .waitForPlayer
        })
        gameState.subscribe(stateSubscriber2)
        stateSubscriber2.store(in: &cancellables)

        let expectNotThinking = expectation(description: "'thining' in state is false")
        stateSubscriber1.reset(expectNotThinking, inputChecker: { state in
            return !state.thinking
        })

        game.dispatch(.playerModeChanged(player: .dark, mode: .manual))
        wait(for: [expectPhaseToBeWaitForPlayer, expectNotThinking], timeout: 3.0)
    }
}
