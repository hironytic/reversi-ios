import XCTest
import Combine
@testable import Reversi

extension PhaseKind {
    fileprivate static let test1 = PhaseKind(rawValue: "test1")
    fileprivate static let test2 = PhaseKind(rawValue: "test2")
}

class GameTests: XCTestCase {
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

    func testStatePublisher() {
        struct TestPhase1: Phase {
            public var kind: PhaseKind { .test1 }
        }
        
        var state = State(board: Board(), turn: .dark, playerModes: [.manual, .manual])
        state.phase = AnyPhase(TestPhase1())

        let game = Game(state: state)
        
        let exp = expectation(description: "waiting for phase test1")
        game.statePublisher
            .sink { state in
                if state.phase.kind == .test1 {
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [exp], timeout: 3.0)
    }
    
    func testGameStartToNextTurn() {
        let game = Game(middlewares: [Logger.self])

        let stateSubscriber = EventuallyFulfill<State, Never>()
        game.statePublisher.subscribe(stateSubscriber)
        stateSubscriber.store(in: &cancellables)

        // まずはゲーム開始時点のチェック
        let startingExpectation = expectation(description: "Start")
        stateSubscriber.reset(startingExpectation, inputChecker: { state in
            // 両カウントが 2
            guard state.diskCount[.dark] == 2 else { return false }
            guard state.diskCount[.light] == 2 else { return false }
            
            // 思考中ではない
            guard !state.thinking else { return false}
            
            // というかどちらもManual
            guard state.playerModes[.dark] == .manual else { return false }
            guard state.playerModes[.light] == .manual else { return false }
            
            // 黒のターン
            guard state.turn == .dark else { return false }
            
            return true
        })
        game.dispatch(.start())
        wait(for: [startingExpectation], timeout: 3.0)

        var requestId: UniqueIdentifier = .invalid
        
        // --------
        // --------
        // --------
        // ---ox---
        // ---xo---
        // --------
        // --------
        // --------
        
        // 黒を (2, 3) に置いてみる
        // (2, 3)を黒にする指示が来るまで待つ
        let dark23Expectation = expectation(description: "Place dark disk on (2, 3)")
        stateSubscriber.reset(dark23Expectation, inputChecker: { state in
            if let request = state.boardUpdateRequest {
                if case let .withAnimation(cellChange) = request.detail {
                    if cellChange.x == 2 && cellChange.y == 3 && cellChange.disk == .dark {
                        requestId = request.requestId
                        return true
                    }
                }
            }
            return false
        })
        game.dispatch(.boardCellSelected(x: 2, y: 3))
        wait(for: [dark23Expectation], timeout: 3.0)

        // --------
        // --------
        // --------
        // --xox---
        // ---xo---
        // --------
        // --------
        // --------
        
        // (2, 3)のアニメーションが終了したことを伝え、
        // (3, 3)が黒にひっくり返る指示が来るまで待つ
        let dark33Expectation = expectation(description: "Disk on (3, 3) is flipped")
        stateSubscriber.reset(dark33Expectation, inputChecker: { state in
            if let request = state.boardUpdateRequest {
                if case let .withAnimation(cellChange) = request.detail {
                    if cellChange.x == 3 && cellChange.y == 3 && cellChange.disk == .dark {
                        requestId = request.requestId
                        return true
                    }
                }
            }
            return false
        })
        game.dispatch(.boardUpdated(requestId: requestId))
        wait(for: [dark33Expectation], timeout: 3.0)

        // --------
        // --------
        // --------
        // --xxx---
        // ---xo---
        // --------
        // --------
        // --------

        // (3, 3)のアニメーションが終了したことを伝えると
        // 黒のカウントが4, 白のカウントが1になり、白のターンになる
        let turnChangeExpectation = expectation(description: "Turn change to light")
        stateSubscriber.reset(turnChangeExpectation, inputChecker: { state in
            guard state.diskCount[.dark] == 4 else { return false }
            guard state.diskCount[.light] == 1 else { return false }
            guard state.turn == .light else { return false }
            
            return true
        })
        game.dispatch(.boardUpdated(requestId: requestId))
        wait(for: [turnChangeExpectation], timeout: 3.0)
    }
    
    func testGameByComputer() {
        let state = State(board: Board(), turn: .dark, playerModes: [.computer, .computer])
        let game = Game(state: state, middlewares: [Logger.self])

        let stateSubscriber = EventuallyFulfill<State, Never>()
        let publisher = game
            .statePublisher
            .share()
            
        publisher.subscribe(stateSubscriber)
        stateSubscriber.store(in: &cancellables)

        // 画面への表示要求が来たら表示したことにして返すための購読を
        // 行っておく
        publisher
            .compactMap { $0.boardUpdateRequest }
            .removeDuplicates()
            .sink { request in
                game.dispatch(.boardUpdated(requestId: request.requestId))
            }
            .store(in: &cancellables)
        
        // ゲームを開始して、黒のターンで、思考中になるまで待つ
        let startingExpectation = expectation(description: "Start")
        stateSubscriber.reset(startingExpectation, inputChecker: { state in
            // 黒のターン
            guard state.turn == .dark else { return false }

            // 思考中
            guard state.thinking else { return false}
            
            return true
        })
        game.dispatch(.start())
        wait(for: [startingExpectation], timeout: 3.0)

        // 思考中が終わるまで待つ
        let darkThinkingFinishedExpectation = expectation(description: "Thinking finished (dark)")
        stateSubscriber.reset(darkThinkingFinishedExpectation, inputChecker: { state in
            return !state.thinking && state.turn == .dark
        })
        wait(for: [darkThinkingFinishedExpectation], timeout: 3.0)
        
        // 白のターンで思考中になるまで待つ
        // その間、画面への表示要求が来たら表示したことにして返す
        let lightThinkingExpectation = expectation(description: "Thinking (light))")
        stateSubscriber.reset(lightThinkingExpectation, inputChecker: { state in
            return state.thinking && state.turn == .light
        })
        wait(for: [lightThinkingExpectation], timeout: 3.0)
    }
    
    func testInitialPhase() throws {
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
        state.phase = AnyPhase(InitialPhase())
        
        let game = Game(state: state, middlewares: [Logger.self])
        let gameState = game.statePublisher.share()
        
        // .start()をディスパッチしたらStateが現在の状態に正しく初期化される。
        let expectStateToBeInitialized = expectation(description: "State is initialized")
        let stateSubscriber1 = EventuallyFulfill<State, Never>(expectStateToBeInitialized, inputChecker: { state in
            // カウント数
            guard state.diskCount[.dark] == 9 else { return false }
            guard state.diskCount[.light] == 12 else { return false }
            
            // 思考中ではない
            guard !state.thinking else { return false}
            
            // プレイヤーモード
            guard state.playerModes[.dark] == .computer else { return false }
            guard state.playerModes[.light] == .manual else { return false }
            
            // 白のターン
            guard state.turn == .light else { return false }

            // ボードの更新依頼が出る
            guard state.boardUpdateRequest != nil else { return false }
            
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
        
        game.dispatch(.start())
        wait(for: [expectStateToBeInitialized, expectPhaseToBeWaitForPlayer], timeout: 3.0)
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

