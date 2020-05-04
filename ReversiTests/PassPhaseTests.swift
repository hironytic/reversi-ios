import XCTest
import Combine
@testable import Reversi

class PassPhaseTests: XCTestCase {
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
    
    func testPassPhase1() throws {
        let board = try Board(restoringFromText: """
            --------
            --------
            xooooooo
            xxoooooo
            xoxxoooo
            -ooxoooo
            --oooo--
            --oooo--
            """)
        var state = State(board: board, turn: .light, playerModes: [.manual, .manual])
        state.diskCount[.dark] = 7
        state.diskCount[.light] = 32
        state.phase = AnyPhase(PassPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // 「パス」表示の依頼が出る
        let expectPassNotificationRequest = expectation(description: "Request for pass-notification")
        let stateSubscriber = EventuallyFulfill<State, Never>(expectPassNotificationRequest, inputChecker: { state in
            return state.passNotificationRequest != nil
        })
        gameState.subscribe(stateSubscriber)
        stateSubscriber.store(in: &cancellables)
        
        if let onEnter = PassPhase.onEnter(previousPhase: AnyPhase(NextTurnPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectPassNotificationRequest], timeout: 3.0)

        // その依頼が完了するまでは、勝手に次みは進まずに
        // そのままの状態でとどまる
        let expectRequestNotChange = expectation(description: "Request for pass-notification continues")
        expectRequestNotChange.isInverted = true
        stateSubscriber.reset(expectRequestNotChange, inputChecker: { state in
            return state.passNotificationRequest == nil || state.phase.kind != .pass
        })
        wait(for: [expectRequestNotChange], timeout: 1.0)
    }
    
    func testPassPhase2() throws {
        let board = try Board(restoringFromText: """
            --------
            --------
            xooooooo
            xxoooooo
            xoxxoooo
            -ooxoooo
            --oooo--
            --oooo--
            """)
        var state = State(board: board, turn: .light, playerModes: [.manual, .manual])
        state.diskCount[.dark] = 7
        state.diskCount[.light] = 32
        state.phase = AnyPhase(PassPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // 「パス」表示の依頼が出る
        var requestId = UniqueIdentifier.invalid
        let expectPassNotificationRequest = expectation(description: "Request for pass-notification")
        let stateSubscriber1 = EventuallyFulfill<State, Never>(expectPassNotificationRequest, inputChecker: { state in
            if let request = state.passNotificationRequest {
                requestId = request.requestId
                return true
            }
            return false
        })
        gameState.subscribe(stateSubscriber1)
        stateSubscriber1.store(in: &cancellables)
        
        if let onEnter = PassPhase.onEnter(previousPhase: AnyPhase(NextTurnPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectPassNotificationRequest], timeout: 3.0)

        // その依頼を完了すると、依頼は消えて、
        // NextTurnフェーズに遷移する
        let expectPassNotificationRequestDisappear = expectation(description: "Request disappears")
        stateSubscriber1.reset(expectPassNotificationRequestDisappear, inputChecker: { state in
            return state.passNotificationRequest == nil
        })

        let expectPhaseToBeNextTurn = expectation(description: "Phase transits to 'NextTurn'")
        let stateSubscriber2 = EventuallyFulfill<State, Never>(expectPhaseToBeNextTurn, inputChecker: { state in
            return state.phase.kind == .nextTurn
        })
        gameState.subscribe(stateSubscriber2)
        stateSubscriber2.store(in: &cancellables)

        game.dispatch(.passDismissed(requestId: requestId))
        wait(for: [expectPassNotificationRequestDisappear, expectPhaseToBeNextTurn], timeout: 3.0)
    }
}
