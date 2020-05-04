import XCTest
import Combine
@testable import Reversi

class ResetPhaseTests: XCTestCase {
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
    
    func testReset1() throws {
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
        var state = State(board: board, turn: .dark, playerModes: [.manual, .computer])
        state.diskCount[.dark] = 9
        state.diskCount[.light] = 12
        state.phase = AnyPhase(WaitForPlayerPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        if let onEnter = WaitForPlayerPhase.onEnter(previousPhase: AnyPhase(InitialPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        
        // リセットが要求されると、リセット確認依頼が出る
        var requestId = UniqueIdentifier.invalid
        let expectResetConfirmation = expectation(description: "Request for reset-confirmation")
        let stateSubscriber1 = EventuallyFulfill<State, Never>(expectResetConfirmation, inputChecker: { state in
            if let request = state.resetConfirmationRequst {
                requestId = request.requestId
                return true
            }
            return false
        })
        gameState.subscribe(stateSubscriber1)
        stateSubscriber1.store(in: &cancellables)
        
        game.dispatch(.reset())
        wait(for: [expectResetConfirmation], timeout: 3.0)

        // リセットをキャンセルすると、リセット確認依頼が取り下げられる
        // そのまま特に何も起こらない
        let expectResetConfirmationDisappear = expectation(description: "Request disappears")
        stateSubscriber1.reset(expectResetConfirmationDisappear, inputChecker: { state in
            return state.resetConfirmationRequst == nil
        })
        
        let expectKeepWaitForPlayer = expectation(description: "Keep 'WaitForPlayer' and current disk count")
        expectKeepWaitForPlayer.isInverted = true
        let stateSubscriber2 = EventuallyFulfill<State, Never>(expectKeepWaitForPlayer, inputChecker: { state in
            return state.phase.kind != .waitForPlayer || state.diskCount[.dark] != 9 || state.diskCount[.light] != 12
        })
        gameState.subscribe(stateSubscriber2)
        stateSubscriber2.store(in: &cancellables)

        game.dispatch(.resetConfirmed(requestId: requestId, execute: false))
        wait(for: [expectResetConfirmationDisappear], timeout: 3.0)

        // そのまま特に何も起こらない
        wait(for: [expectKeepWaitForPlayer], timeout: 1.0)
    }

    func testReset2() throws {
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
        var state = State(board: board, turn: .dark, playerModes: [.manual, .computer])
        state.diskCount[.dark] = 9
        state.diskCount[.light] = 12
        state.phase = AnyPhase(WaitForPlayerPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        if let onEnter = WaitForPlayerPhase.onEnter(previousPhase: AnyPhase(InitialPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        
        // リセットが要求されると、リセット確認依頼が出る
        var requestId = UniqueIdentifier.invalid
        let expectResetConfirmation = expectation(description: "Request for reset-confirmation")
        let stateSubscriber1 = EventuallyFulfill<State, Never>(expectResetConfirmation, inputChecker: { state in
            if let request = state.resetConfirmationRequst {
                requestId = request.requestId
                return true
            }
            return false
        })
        gameState.subscribe(stateSubscriber1)
        stateSubscriber1.store(in: &cancellables)
        
        game.dispatch(.reset())
        wait(for: [expectResetConfirmation], timeout: 3.0)

        // リセットを実行すると、リセット確認依頼が取り下げられてResetフェーズへ
        let expectResetConfirmationDisappear = expectation(description: "Request disappears")
        stateSubscriber1.reset(expectResetConfirmationDisappear, inputChecker: { state in
            return state.resetConfirmationRequst == nil
        })
        
        let expectPhaseToBeReset = expectation(description: "Phase transits to 'Reset'")
        let stateSubscriber2 = EventuallyFulfill<State, Never>(expectPhaseToBeReset, inputChecker: { state in
            return state.phase.kind == .reset
        })
        gameState.subscribe(stateSubscriber2)
        stateSubscriber2.store(in: &cancellables)

        game.dispatch(.resetConfirmed(requestId: requestId, execute: true))
        wait(for: [expectResetConfirmationDisappear, expectPhaseToBeReset], timeout: 3.0)
    }
    
    func testResetPhase() throws {
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
        state.diskCount[.dark] = 9
        state.diskCount[.light] = 12
        state.phase = AnyPhase(ResetPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()

        // いろいろリセットされる
        let expectReset = expectation(description: "Reset!!!")
        let stateSubscriber1 = EventuallyFulfill<State, Never>(expectReset, inputChecker: { state in
            // リバーシ盤の更新依頼が出る
            guard state.boardUpdateRequest != nil else { return false }
            
            // turnが黒になる
            guard state.turn == .dark else { return false }
            
            // プレイヤーモードはどちらもmanualになる
            guard state.playerModes[.dark] == .manual else { return false }
            guard state.playerModes[.light] == .manual else { return false }
            
            // ディスク枚数は2, 2になる
            guard state.diskCount[.dark] == 2 else { return false }
            guard state.diskCount[.light] == 2 else { return false }

            // セーブ依頼が出る
            guard state.saveRequest != nil else { return false }
            
            return true
        })
        gameState.subscribe(stateSubscriber1)
        stateSubscriber1.store(in: &cancellables)

        // また、次のフェーズは WaitForPlayer になる
        let expectPhaseToBeWaitForPlayer = expectation(description: "Phase transits to 'WaitForPlayer'")
        let stateSubscriber2 = EventuallyFulfill<State, Never>(expectPhaseToBeWaitForPlayer, inputChecker: { state in
            return state.phase.kind == .waitForPlayer
        })
        gameState.subscribe(stateSubscriber2)
        stateSubscriber2.store(in: &cancellables)

        if let onEnter = ResetPhase.onEnter(previousPhase: AnyPhase(WaitForPlayerPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectReset, expectPhaseToBeWaitForPlayer], timeout: 3.0)
    }
    
    func testResetOnThinkingPhase() throws {
        ThinkingPhase.thinkingDuration = 2.0
        
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
        let stateSubscriber1 = EventuallyFulfill<State, Never>(expectThinking, inputChecker: { state in
            return state.thinking
        })
        gameState.subscribe(stateSubscriber1)
        stateSubscriber1.store(in: &cancellables)
        
        if let onEnter = ThinkingPhase.onEnter(previousPhase: AnyPhase(WaitForPlayerPhase())) {
            game.dispatch(.thunk(onEnter))
        }
        wait(for: [expectThinking], timeout: 3.0)
        
        // リセット実行！
        // 思考中ではなくなる。
        // 勝手にディスクが打たれたりしない
        gameState
            .sink { state in
                // リセット確認が来たら確認して実行する
                if let request = state.resetConfirmationRequst {
                    DispatchQueue.main.async {
                        game.dispatch(.resetConfirmed(requestId: request.requestId, execute: true))
                    }
                }
            }
            .store(in: &cancellables)

        let expectNotThinking = expectation(description: "'thinking' in state is false")
        stateSubscriber1.reset(expectNotThinking, inputChecker: { state in
            return !state.thinking
        })
        
        let expectNotTransitToPlaceDiskPhase = expectation(description: "Phase should not transit to 'PlaceDisk'")
        expectNotTransitToPlaceDiskPhase.isInverted = true
        let stateSubscriber2 = EventuallyFulfill<State, Never>(expectThinking, inputChecker: { state in
            return state.phase.kind == .placeDisk
        })
        gameState.subscribe(stateSubscriber2)
        stateSubscriber2.store(in: &cancellables)

        game.dispatch(.reset())
        wait(for: [expectNotThinking], timeout: 3.0)

        // 待っていても勝手にディスクは打たれない
        wait(for: [expectNotTransitToPlaceDiskPhase], timeout: 3.0)
    }
}
