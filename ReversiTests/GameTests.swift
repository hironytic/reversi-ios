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
        // セーブ依頼も出る
        var saveText = ""
        let turnChangeExpectation = expectation(description: "Turn change to light")
        stateSubscriber.reset(turnChangeExpectation, inputChecker: { state in
            guard state.diskCount[.dark] == 4 else { return false }
            guard state.diskCount[.light] == 1 else { return false }
            guard state.turn == .light else { return false }
            guard let saveRequest = state.saveRequest else { return false }

            saveText = saveRequest.detail
            return true
        })
        game.dispatch(.boardUpdated(requestId: requestId))
        wait(for: [turnChangeExpectation], timeout: 3.0)
        
        XCTAssertEqual(saveText, """
            o00
            --------
            --------
            --------
            --xxx---
            ---xo---
            --------
            --------
            --------

            """
        )
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
    
    func testLoadGame() throws {
        let saveText = """
            o00
            --------
            --------
            --------
            --xxx---
            ---xo---
            --------
            --------
            --------

            """
        
        var game: Game!
        try XCTAssertNoThrow(game = Game(loading: saveText, middlewares: [Logger.self]))

        let publisher = game
            .statePublisher
            .share()

        let startingExpectation = expectation(description: "Start")
        let stateSubscriber = EventuallyFulfill<State, Never>(startingExpectation, inputChecker: { state in
            // それぞれのカウント
            guard state.diskCount[.dark] == 4 else { return false }
            guard state.diskCount[.light] == 1 else { return false }
            
            // 思考中ではない
            guard !state.thinking else { return false}
            
            // どちらもManual
            guard state.playerModes[.dark] == .manual else { return false }
            guard state.playerModes[.light] == .manual else { return false }
            
            // 白のターン
            guard state.turn == .light else { return false }
            
            return true
        })
        publisher.subscribe(stateSubscriber)
        stateSubscriber.store(in: &cancellables)
        
        game.dispatch(.start())
        wait(for: [startingExpectation], timeout: 3.0)
    }
    
    func testLoadGameFromBrokenData1() {
        // 先頭行がおかしいデータ
        let saveText = """
            oxx
            --------
            --------
            --------
            --xxx---
            ---xo---
            --------
            --------
            --------

            """
        
        XCTAssertThrowsError(try Game(loading: saveText, middlewares: [Logger.self])) { error in
            if case let GameError.restore(data: data) = error {
                XCTAssertEqual(data, saveText)
            } else {
                XCTFail()
            }
        }
    }
    
    func testLoadGameFromBrokenData2() {
        // 途中までしかないデータ
        let saveText = """
            o00
            --------
            --------
            --------
            --xxx---
            """
        
        XCTAssertThrowsError(try Game(loading: saveText, middlewares: [Logger.self])) { error in
            if case let GameError.restore(data: data) = error {
                XCTAssertEqual(data, saveText)
            } else {
                XCTFail()
            }
        }
    }
    
    func testLoadGameOnPassSituation() throws {
        let saveText = """
            o00
            -xxooooo
            -xoooxoo
            xxooxooo
            xxxooooo
            xxxooooo
            xxxooooo
            ---xoooo
            ----oooo

            """
        
        let game1 = try Game(loading: saveText, middlewares: [Logger.self])
        let publisher1 = game1.statePublisher.share()

        // リバーシ盤の更新依頼に答える
        publisher1
            .compactMap { $0.boardUpdateRequest }
            .removeDuplicates()
            .sink { request in
                DispatchQueue.main.async {
                    game1.dispatch(.boardUpdated(requestId: request.requestId))
                }
            }
            .store(in: &cancellables)
        
        // ゲーム開始
        // ボードが更新されるまで待つ
        let expectBoardUpdate = expectation(description: "Board is updated")
        let stateSubscriber1 = EventuallyFulfill<State, Never>(expectBoardUpdate, inputChecker: { state in
            return state.boardUpdateRequest != nil
        })
        publisher1.subscribe(stateSubscriber1)
        stateSubscriber1.store(in: &cancellables)

        game1.dispatch(.start())
        wait(for: [expectBoardUpdate], timeout: 3.0)
        
        // 白のターンなので (3, 7) にディスクを置く
        // セーブ依頼、パス依頼が出るまで待つ
        var newSaveText = ""
        let expectPassAndSaveRequests = expectation(description: "Pass and save requests")
        stateSubscriber1.reset(expectPassAndSaveRequests, inputChecker: { state in
            if let saveRequest = state.saveRequest, state.passNotificationRequest != nil {
                newSaveText = saveRequest.detail
                return true
            }
            return false
        })

        game1.dispatch(.boardCellSelected(x: 3, y: 7))
        wait(for: [expectPassAndSaveRequests], timeout: 3.0)

        // セーブデータから復帰
        let game2 = try Game(loading: newSaveText, middlewares: [Logger.self])
        let publisher2 = game2.statePublisher.share()
        
        // リバーシ盤の更新依頼に答える
        publisher2
            .compactMap { $0.boardUpdateRequest }
            .removeDuplicates()
            .sink { request in
                DispatchQueue.main.async {
                    game2.dispatch(.boardUpdated(requestId: request.requestId))
                }
            }
            .store(in: &cancellables)

        // パス依頼が出るまで待つ
        let expectPass = expectation(description: "Pass request")
        let stateSubscriber2 = EventuallyFulfill<State, Never>(expectPass, inputChecker: { state in
            return state.passNotificationRequest != nil
        })
        publisher2.subscribe(stateSubscriber2)
        stateSubscriber2.store(in: &cancellables)
        
        game2.dispatch(.start())
        wait(for: [expectPass], timeout: 3.0)
    }
}
