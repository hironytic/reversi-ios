import XCTest
import Combine
@testable import Reversi

class InitialPhaseTests: XCTestCase {
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
}
