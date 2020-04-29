import XCTest
import Combine
@testable import Reversi

extension PhaseKind {
    fileprivate static let test1 = PhaseKind(rawValue: "test1")
    fileprivate static let test2 = PhaseKind(rawValue: "test2")
}

class GameTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()
    
    override func setUpWithError() throws {
        cancellables = Set<AnyCancellable>()
    }

    override func tearDownWithError() throws {
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
    
    func testPhaseChange() {
        struct TestPhase1: Phase {
            let enterExpectation: XCTestExpectation
            let exitExpectation:  XCTestExpectation

            init(enterExpectation: XCTestExpectation, exitExpectation: XCTestExpectation) {
                self.enterExpectation = enterExpectation
                self.exitExpectation = exitExpectation
            }
            
            public var kind: PhaseKind { .test1 }
            
            func onEnter(state: State, previousPhase: AnyPhase) -> State {
                self.enterExpectation.fulfill()
                return state
            }
            
            func onExit(state: State, nextPhase: AnyPhase) -> State {
                self.exitExpectation.fulfill()
                return state
            }
            
            func reduce(state: State, action: Action) -> State {
                var state = state

                // なんでもいいのでアクションが来たらTestPhase2へ遷移
                state.phase = AnyPhase(TestPhase2())
                
                return state
            }
        }
        struct TestPhase2: Phase {
            public var kind: PhaseKind { .test2 }
        }

        let test1Enter = expectation(description: "onEnter of test1")
        test1Enter.isInverted = true
        
        let test1Exit = expectation(description: "onExit of test1")

        let phase = TestPhase1(enterExpectation: test1Enter, exitExpectation: test1Exit)
        var state = State(board: Board(), turn: .dark, playerModes: [.manual, .manual])
        state.phase = AnyPhase(phase)
        
        let game = Game(state: state)

        let stateChange = expectation(description: "change of state")
        game.statePublisher
            .sink { state in
                if state.phase.kind == .test2 {
                    stateChange.fulfill()
                }
            }
            .store(in: &cancellables)

        game.dispatch(action: .start)
        
        wait(for: [stateChange, test1Enter, test1Exit], timeout: 3.0)
    }
    
    func testGameStartToNextTurn() {
        let game = Game()
        game.makeCurrent()

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
        game.dispatch(action: .start)
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
        game.dispatch(action: .boardCellSelected(x: 2, y: 3))
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
        game.dispatch(action: .boardUpdated(requestId: requestId))
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
        game.dispatch(action: .boardUpdated(requestId: requestId))
        wait(for: [turnChangeExpectation], timeout: 3.0)
    }
    
    func testGameByComputer() {
        // 思考時間を短くしておく
        let originalDuration = ThinkingPhase.thinkingDuration
        defer { ThinkingPhase.thinkingDuration = originalDuration }
        ThinkingPhase.thinkingDuration = 0.5
        
        let state = State(board: Board(), turn: .dark, playerModes: [.computer, .computer])
        let game = Game(state: state)
        game.makeCurrent()

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
                game.dispatch(action: .boardUpdated(requestId: request.requestId))
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
        game.dispatch(action: .start)
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
}
