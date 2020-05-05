import XCTest
import Combine
@testable import Reversi

class WaitForPlayerPhaseTests: XCTestCase {
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
    
    func testWaitForPlayerPhase1() throws {
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
        state.phase = AnyPhase(WaitForPlayerPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // 黒のターンだが、黒はcomputerなのでThinkingPhaseへ遷移する
        let expectPhaseToBeThinking = expectation(description: "Phase transits to 'Thinking'")
        let stateSubscriber = EventuallyFulfill<State, Never>(expectPhaseToBeThinking, inputChecker: { state in
            return state.phase.kind == .thinking
        })
        gameState.subscribe(stateSubscriber)
        stateSubscriber.store(in: &cancellables)
        
        if let onEnter = WaitForPlayerPhase.onEnter(previousPhase: AnyPhase(InitialPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectPhaseToBeThinking], timeout: 3.0)
    }
    
    func testWaitForPlayerPhase2() throws {
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
        state.phase = AnyPhase(WaitForPlayerPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // 白のターンだが、白はmanualなのでそのまま待っていてもWaitForPlayerにとどまる
        let expectPhaseNotToTransit = expectation(description: "Phase transits to nothing but 'WaitForPlayer'")
        expectPhaseNotToTransit.isInverted = true
        let stateSubscriber = EventuallyFulfill<State, Never>(expectPhaseNotToTransit, inputChecker: { state in
            return state.phase.kind != .waitForPlayer
        })
        gameState.subscribe(stateSubscriber)
        stateSubscriber.store(in: &cancellables)
        
        if let onEnter = WaitForPlayerPhase.onEnter(previousPhase: AnyPhase(InitialPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectPhaseNotToTransit], timeout: 1.0)
        
        // ボードのセルをタップすると、フェーズがPlaceDiskに移る
        let expectPhaseToBePlaceDisk = expectation(description: "Phase transits to 'PlaceDisk'")
        stateSubscriber.reset(expectPhaseToBePlaceDisk, inputChecker: { state in
            guard let phase = PlaceDiskPhase.thisPhase(of: state) else { return false }
            guard phase.x == 1 else { return false }
            guard phase.y == 3 else { return false }
            
            return true
        })
        game.dispatch(.boardCellSelected(x: 1, y: 3))
        wait(for: [expectPhaseToBePlaceDisk], timeout: 3.0)
    }
    
    func testWaitForPlayerPhase3() throws {
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
        state.phase = AnyPhase(WaitForPlayerPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // 白のターンだが、白はmanual
        if let onEnter = WaitForPlayerPhase.onEnter(previousPhase: AnyPhase(InitialPhase())) {
            game.dispatch(.thunk(onEnter))
        }

        // 白のプレイヤーモードをcomputerに変更すると
        // ThinkingPhaseに移る
        let expectPhaseToBeThinking = expectation(description: "Phase transits to 'Thinking'")
        let stateSubscriber = EventuallyFulfill<State, Never>(expectPhaseToBeThinking, inputChecker: { state in
            return state.phase.kind == .thinking
        })
        gameState.subscribe(stateSubscriber)
        stateSubscriber.store(in: &cancellables)
        
        game.dispatch(.playerModeChanged(player: .light, mode: .computer))
        wait(for: [expectPhaseToBeThinking], timeout: 3.0)
    }
    
    func testWaitForPlayerPhase4() throws {
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
        var state = State(board: board, turn: nil, playerModes: [.computer, .manual])
        state.diskCount[.dark] = 13
        state.diskCount[.light] = 0
        state.phase = AnyPhase(WaitForPlayerPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // ターンがnilなのでGameOverへ遷移する
        let expectPhaseToBeGameOver = expectation(description: "Phase transits to 'GameOver'")
        let stateSubscriber = EventuallyFulfill<State, Never>(expectPhaseToBeGameOver, inputChecker: { state in
            return state.phase.kind == .gameOver
        })
        gameState.subscribe(stateSubscriber)
        stateSubscriber.store(in: &cancellables)
        
        if let onEnter = WaitForPlayerPhase.onEnter(previousPhase: AnyPhase(InitialPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectPhaseToBeGameOver], timeout: 3.0)
    }
    
    func testWaitForPlayerPhase5() throws {
        let board = try Board(restoringFromText: """
            -xxooooo
            -xoooxoo
            xxooxooo
            xxxooooo
            xxxooooo
            xxxooooo
            ---ooooo
            ---ooooo
            """)
        var state = State(board: board, turn: .dark, playerModes: [.manual, .manual])
        state.diskCount[.dark] = board.countDisks(of: .dark)
        state.diskCount[.light] = board.countDisks(of: .light)
        state.phase = AnyPhase(WaitForPlayerPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // 黒は置くところがないのでPassフェーズへ遷移する
        let expectPhaseToBePass = expectation(description: "Phase transits to 'Pass'")
        let stateSubscriber = EventuallyFulfill<State, Never>(expectPhaseToBePass, inputChecker: { state in
            return state.phase.kind == .pass
        })
        gameState.subscribe(stateSubscriber)
        stateSubscriber.store(in: &cancellables)
        
        if let onEnter = WaitForPlayerPhase.onEnter(previousPhase: AnyPhase(InitialPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectPhaseToBePass], timeout: 3.0)
    }
}
