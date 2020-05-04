import XCTest
import Combine
@testable import Reversi

class NextTurnPhaseTests: XCTestCase {
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
    
    func testNextTurnPhase1() throws {
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
        var state = State(board: board, turn: .light, playerModes: [.manual, .manual])
        state.diskCount[.dark] = 9
        state.diskCount[.light] = 12
        state.phase = AnyPhase(NextTurnPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // ターンが黒に変わって、ディスク枚数が更新され、
        // WaitForPlayerフェーズに遷移する
        // セーブ依頼も出る
        let expectTurnChange = expectation(description: "Changed to dark's turn")
        let stateSubscriber1 = EventuallyFulfill<State, Never>(expectTurnChange, inputChecker: { state in
            return state.turn == .dark
        })
        gameState.subscribe(stateSubscriber1)
        stateSubscriber1.store(in: &cancellables)

        let expectDiskCount = expectation(description: "Disk-counts change")
        let stateSubscriber2 = EventuallyFulfill<State, Never>(expectDiskCount, inputChecker: { state in
            return state.diskCount[.dark] == 6 && state.diskCount[.light] == 16
        })
        gameState.subscribe(stateSubscriber2)
        stateSubscriber2.store(in: &cancellables)

        let expectPhaseToBeWaitForPlayer = expectation(description: "Phase transits to 'WaitForPlayer'")
        let stateSubscriber3 = EventuallyFulfill<State, Never>(expectPhaseToBeWaitForPlayer, inputChecker: { state in
            return state.phase.kind == .waitForPlayer
        })
        gameState.subscribe(stateSubscriber3)
        stateSubscriber3.store(in: &cancellables)
        
        var requestId = UniqueIdentifier.invalid
        let expectSaveRequest = expectation(description: "Save request")
        let stateSubscriber4 = EventuallyFulfill<State, Never>(expectSaveRequest, inputChecker: { state in
            if let request = state.saveRequest {
                requestId = request.requestId
                return true
            }
            return false
        })
        gameState.subscribe(stateSubscriber4)
        stateSubscriber4.store(in: &cancellables)

        if let onEnter = NextTurnPhase.onEnter(previousPhase: AnyPhase(PlacingDiskPhase(cellChanges: [][...]))) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectTurnChange, expectDiskCount, expectPhaseToBeWaitForPlayer, expectSaveRequest], timeout: 3.0)
        
        // セーブ依頼は完了したら消える
        let expectSaveRequestDisappear = expectation(description: "Save request disappears")
        stateSubscriber4.reset(expectSaveRequestDisappear, inputChecker: { state in
            return state.saveRequest == nil
        })
        game.dispatch(.saveCompleted(requestId: requestId))
        wait(for: [expectSaveRequestDisappear], timeout: 3.0)        
    }
    
    func testNextTurnPhase2() throws {
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
        var state = State(board: board, turn: .dark, playerModes: [.manual, .manual])
        state.diskCount[.dark] = 4
        state.diskCount[.light] = 34
        state.phase = AnyPhase(NextTurnPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // ターンが白に変わって、ディスク枚数が更新されるが、
        // 白は打つところがないので、Passフェーズに遷移する
        let expectTurnChange = expectation(description: "Changed to light's turn")
        let stateSubscriber1 = EventuallyFulfill<State, Never>(expectTurnChange, inputChecker: { state in
            return state.turn == .light
        })
        gameState.subscribe(stateSubscriber1)
        stateSubscriber1.store(in: &cancellables)

        let expectDiskCount = expectation(description: "Disk-counts change")
        let stateSubscriber2 = EventuallyFulfill<State, Never>(expectDiskCount, inputChecker: { state in
            return state.diskCount[.dark] == 7 && state.diskCount[.light] == 32
        })
        gameState.subscribe(stateSubscriber2)
        stateSubscriber2.store(in: &cancellables)

        let expectPhaseToBeWaitForPlayer = expectation(description: "Phase transits to 'Pass'")
        let stateSubscriber3 = EventuallyFulfill<State, Never>(expectPhaseToBeWaitForPlayer, inputChecker: { state in
            return state.phase.kind == .pass
        })
        gameState.subscribe(stateSubscriber3)
        stateSubscriber3.store(in: &cancellables)
        
        if let onEnter = NextTurnPhase.onEnter(previousPhase: AnyPhase(PlacingDiskPhase(cellChanges: [][...]))) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectTurnChange, expectDiskCount, expectPhaseToBeWaitForPlayer], timeout: 3.0)
    }
    
    func testNextTurnPhase3() throws {
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
        state.diskCount[.dark] = 7
        state.diskCount[.light] = 5
        state.phase = AnyPhase(NextTurnPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // ターンが白に変わって、ディスク枚数が更新されるが、
        // 白は打つところがなく、黒も打てないので、GameOverフェーズに遷移する
        let expectTurnChange = expectation(description: "Changed to light's turn")
        let stateSubscriber1 = EventuallyFulfill<State, Never>(expectTurnChange, inputChecker: { state in
            return state.turn == .light
        })
        gameState.subscribe(stateSubscriber1)
        stateSubscriber1.store(in: &cancellables)

        let expectDiskCount = expectation(description: "Disk-counts change")
        let stateSubscriber2 = EventuallyFulfill<State, Never>(expectDiskCount, inputChecker: { state in
            return state.diskCount[.dark] == 13 && state.diskCount[.light] == 0
        })
        gameState.subscribe(stateSubscriber2)
        stateSubscriber2.store(in: &cancellables)

        let expectPhaseToBeWaitForPlayer = expectation(description: "Phase transits to 'GameOver'")
        let stateSubscriber3 = EventuallyFulfill<State, Never>(expectPhaseToBeWaitForPlayer, inputChecker: { state in
            return state.phase.kind == .gameOver
        })
        gameState.subscribe(stateSubscriber3)
        stateSubscriber3.store(in: &cancellables)
        
        if let onEnter = NextTurnPhase.onEnter(previousPhase: AnyPhase(PlacingDiskPhase(cellChanges: [][...]))) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectTurnChange, expectDiskCount, expectPhaseToBeWaitForPlayer], timeout: 3.0)
    }
}
