import XCTest
import Combine
@testable import Reversi

class ViewModelTests: XCTestCase {
    class MockGame: GameModel {
        private var _stateSubject = PassthroughSubject<State, Never>()
        var state: State {
            didSet {
                _stateSubject.send(state)
            }
        }
        let statePublisher: AnyPublisher<State, Never>
        
        private let _dispatchCall = PassthroughSubject<Actionish, Never>()
        let dispatchCall: AnyPublisher<Actionish, Never>
        
        func dispatch(_ actionish: Actionish) {
            _dispatchCall.send(actionish)
        }

        init(state: State = State(board: Board(), turn: .dark, playerModes: [.manual, .manual])) {
            self.state = state
            statePublisher = _stateSubject.eraseToAnyPublisher()
            dispatchCall = _dispatchCall.eraseToAnyPublisher()
        }
    }
    
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

    func testMessageDiskViewDisk() {
        let game = MockGame()
        let viewModel = ViewModel(game: game)
        
        let subscriber = EventuallyFulfill<Disk?, Never>()
        viewModel
            .messageDiskViewDisk
            .subscribe(subscriber)
        subscriber.store(in: &cancellables)

        // 白のターン
        let expectLight = expectation(description: "Light's turn")
        subscriber.reset(expectLight, inputChecker: { disk in
            return disk == .light
        })
        game.state.turn = .light
        wait(for: [expectLight], timeout: 3.0)
        
        // 黒のターン
        let expectDark = expectation(description: "Dark's turn")
        subscriber.reset(expectDark, inputChecker: { disk in
            return disk == .dark
        })
        game.state.turn = .dark
        wait(for: [expectDark], timeout: 3.0)

        // 白の勝利
        let expectLight2 = expectation(description: "Light won")
        subscriber.reset(expectLight2, inputChecker: { disk in
            return disk == .light
        })
        game.state.modifyAtOnce { state in
            state.turn = nil
            state.diskCount[.dark] = 30
            state.diskCount[.light] = 34
        }
        wait(for: [expectLight2], timeout: 3.0)
        
        // 黒の勝利
        let expectDark2 = expectation(description: "Dark won")
        subscriber.reset(expectDark2, inputChecker: { disk in
            return disk == .dark
        })
        game.state.modifyAtOnce { state in
            state.turn = nil
            state.diskCount[.dark] = 34
            state.diskCount[.light] = 30
        }
        wait(for: [expectDark2], timeout: 3.0)

        // 引き分け（表示しない）
        let expectNil = expectation(description: "Tied")
        subscriber.reset(expectNil, inputChecker: { disk in
            return disk == nil
        })
        game.state.modifyAtOnce { state in
            state.turn = nil
            state.diskCount[.dark] = 32
            state.diskCount[.light] = 32
        }
        wait(for: [expectNil], timeout: 3.0)
    }
    
    func testMessageLabelText() {
        let game = MockGame()
        let viewModel = ViewModel(game: game)
        
        let subscriber = EventuallyFulfill<String?, Never>()
        viewModel
            .messageLabelText
            .subscribe(subscriber)
        subscriber.store(in: &cancellables)

        // 白のターン
        let expectLight = expectation(description: "Light's turn")
        subscriber.reset(expectLight, inputChecker: { text in
            return text == "'s turn"
        })
        game.state.turn = .light
        wait(for: [expectLight], timeout: 3.0)
        
        // 白の勝利
        let expectLight2 = expectation(description: "Light won")
        subscriber.reset(expectLight2, inputChecker: { text in
            return text == " won"
        })
        game.state.modifyAtOnce { state in
            state.turn = nil
            state.diskCount[.dark] = 30
            state.diskCount[.light] = 34
        }
        wait(for: [expectLight2], timeout: 3.0)
        
        // 黒のターン
        let expectDark = expectation(description: "Dark's turn")
        subscriber.reset(expectDark, inputChecker: { text in
            return text == "'s turn"
        })
        game.state.turn = .dark
        wait(for: [expectDark], timeout: 3.0)

        // 黒の勝利
        let expectDark2 = expectation(description: "Dark won")
        subscriber.reset(expectDark2, inputChecker: { text in
            return text == " won"
        })
        game.state.modifyAtOnce { state in
            state.turn = nil
            state.diskCount[.dark] = 34
            state.diskCount[.light] = 30
        }
        wait(for: [expectDark2], timeout: 3.0)

        // 引き分け（表示しない）
        let expectNil = expectation(description: "Tied")
        subscriber.reset(expectNil, inputChecker: { text in
            return text == "Tied"
        })
        game.state.modifyAtOnce { state in
            state.turn = nil
            state.diskCount[.dark] = 32
            state.diskCount[.light] = 32
        }
        wait(for: [expectNil], timeout: 3.0)
    }
    
    func testPlayerControlSelectedIndices() {
        let game = MockGame()
        let viewModel = ViewModel(game: game)
        
        // [0]について
        let subscriber0 = EventuallyFulfill<Int, Never>()
        viewModel.playerControlSelectedIndices[0]
            .subscribe(subscriber0)
        subscriber0.store(in: &cancellables)
        
        // manual
        let expect0Manual = expectation(description: "[0] Manual")
        subscriber0.reset(expect0Manual, inputChecker: { mode in
            return mode == 0
        })
        game.state.playerModes = [.manual, .computer]
        wait(for: [expect0Manual], timeout: 3.0)

        // computer
        let expect0Computer = expectation(description: "[0] Computer")
        subscriber0.reset(expect0Computer, inputChecker: { mode in
            return mode == 1
        })
        game.state.playerModes = [.computer, .manual]
        wait(for: [expect0Computer], timeout: 3.0)

        // [1]について
        let subscriber1 = EventuallyFulfill<Int, Never>()
        viewModel.playerControlSelectedIndices[1]
            .subscribe(subscriber1)
        subscriber1.store(in: &cancellables)
        
        // manual
        let expect1Manual = expectation(description: "[1] Manual")
        subscriber1.reset(expect1Manual, inputChecker: { mode in
            return mode == 0
        })
        game.state.playerModes = [.computer, .manual]
        wait(for: [expect1Manual], timeout: 3.0)

        // computer
        let expect1Computer = expectation(description: "[1] Computer")
        subscriber1.reset(expect1Computer, inputChecker: { mode in
            return mode == 1
        })
        game.state.playerModes = [.manual, .computer]
        wait(for: [expect1Computer], timeout: 3.0)
    }
    
    func testCountLabelTexts() {
        let game = MockGame()
        let viewModel = ViewModel(game: game)
        
        // [0]について
        let subscriber0 = EventuallyFulfill<String?, Never>()
        viewModel.countLabelTexts[0]
            .subscribe(subscriber0)
        subscriber0.store(in: &cancellables)
        
        let expect30 = expectation(description: "30")
        subscriber0.reset(expect30, inputChecker: { text in
            return text == "30"
        })
        game.state.diskCount[0] = 30
        wait(for: [expect30], timeout: 3.0)

        // [1]について
        let subscriber1 = EventuallyFulfill<String?, Never>()
        viewModel.countLabelTexts[1]
            .subscribe(subscriber1)
        subscriber1.store(in: &cancellables)
        
        let expect42 = expectation(description: "42")
        subscriber1.reset(expect42, inputChecker: { text in
            return text == "42"
        })
        game.state.diskCount[1] = 42
        wait(for: [expect42], timeout: 3.0)
    }
    
    func testPlayerActivityIndicatorAnimateds() {
        let game = MockGame()
        let viewModel = ViewModel(game: game)
        
        // [0]について
        let subscriber0 = EventuallyFulfill<Bool, Never>()
        viewModel.playerActivityIndicatorAnimateds[0]
            .subscribe(subscriber0)
        subscriber0.store(in: &cancellables)

        // ぐるぐる
        let expect0True = expectation(description: "[0]true")
        subscriber0.reset(expect0True, inputChecker: { animated in
            return animated
        })
        game.state.modifyAtOnce { state in
            state.turn = .dark
            state.thinking = true
        }
        wait(for: [expect0True], timeout: 3.0)
        
        // ぐるぐるは止まる
        let expect0False = expectation(description: "[0]false")
        subscriber0.reset(expect0False, inputChecker: { animated in
            return !animated
        })
        game.state.thinking = false
        wait(for: [expect0False], timeout: 3.0)

        // ぐるぐるは止まったまま
        let expect0KeepFalse = expectation(description: "[0] keep false")
        expect0KeepFalse.isInverted = true
        subscriber0.reset(expect0False, inputChecker: { animated in
            return !animated
        })
        game.state.modifyAtOnce { state in
            state.turn = .light
            state.thinking = true
        }
        wait(for: [expect0KeepFalse], timeout: 1.0)

        // [1]について
        let subscriber1 = EventuallyFulfill<Bool, Never>()
        viewModel.playerActivityIndicatorAnimateds[1]
            .subscribe(subscriber1)
        subscriber0.store(in: &cancellables)

        // ぐるぐる
        let expect1True = expectation(description: "[1]true")
        subscriber1.reset(expect1True, inputChecker: { animated in
            return animated
        })
        game.state.modifyAtOnce { state in
            state.turn = .light
            state.thinking = true
        }
        wait(for: [expect1True], timeout: 3.0)
        
        // ぐるぐるは止まる
        let expect1False = expectation(description: "[1]false")
        subscriber1.reset(expect1False, inputChecker: { animated in
            return !animated
        })
        game.state.thinking = false
        wait(for: [expect1False], timeout: 3.0)

        // ぐるぐるは止まったまま
        let expect1KeepFalse = expectation(description: "[1] keep false")
        expect1KeepFalse.isInverted = true
        subscriber1.reset(expect1False, inputChecker: { animated in
            return !animated
        })
        game.state.modifyAtOnce { state in
            state.turn = .light
            state.thinking = true
        }
        wait(for: [expect1KeepFalse], timeout: 1.0)
    }
    
    func testBoardViewUpdate() {
        let game = MockGame()
        let viewModel = ViewModel(game: game)

        let subscriber = EventuallyFulfill<DetailedRequest<BoardUpdate>, Never>()
        viewModel.boardViewUpdate
            .subscribe(subscriber)
        subscriber.store(in: &cancellables)

        // 非アニメーション
        let cellChanges = [
            Board.CellChange(x: 5, y: 4, disk: .dark),
            Board.CellChange(x: 4, y: 4, disk: .dark),
            Board.CellChange(x: 3, y: 4, disk: .dark),
        ]
        let expectUpdateWithoutAnimation = expectation(description: "Board Update w/o animation")
        subscriber.reset(expectUpdateWithoutAnimation, inputChecker: { request in
            if case let .withoutAnimation(changes) = request.detail {
                if changes == cellChanges {
                    return true
                }
            }
            return false
        })
        game.state.boardUpdateRequest = DetailedRequest(.withoutAnimation(cellChanges))
        wait(for: [expectUpdateWithoutAnimation], timeout: 3.0)
        
        // アニメーション
        let cellChange = Board.CellChange(x: 7, y: 2, disk: .light)
        let expectUpdateWithAnimation = expectation(description: "Board Update with animation")
        subscriber.reset(expectUpdateWithAnimation, inputChecker: { request in
            if case let .withAnimation(change) = request.detail {
                if change == cellChange {
                    return true
                }
            }
            return false
        })
        game.state.boardUpdateRequest = DetailedRequest(.withAnimation(cellChange))
        wait(for: [expectUpdateWithAnimation], timeout: 3.0)
    }
    
    func testShowAlert() {
        let game = MockGame()
        let viewModel = ViewModel(game: game)

        let subscriber = EventuallyFulfill<ViewModel.AlertRequest, Never>()
        viewModel.showAlert
            .subscribe(subscriber)
        subscriber.store(in: &cancellables)

        // リセット確認
        let expectResetConfirmation = expectation(description: "Reset confirmation")
        subscriber.reset(expectResetConfirmation, inputChecker: { request in
            guard request.title == "Confirmation" else { return false }
            guard request.message == "Do you really want to reset the game?" else { return false }
            guard request.actions.count == 2 else { return false }
            guard request.actions[0].title == "Cancel" else { return false }
            guard request.actions[0].style == .cancel else { return false }
            guard request.actions[1].title == "OK" else { return false }
            guard request.actions[1].style == .default else { return false }
            
            return true
        })
        game.state.resetConfirmationRequst = Request()
        wait(for: [expectResetConfirmation], timeout: 3.0)
        
        game.state.resetConfirmationRequst = nil
        
        // パス
        let expectPass = expectation(description: "Pass")
        subscriber.reset(expectPass, inputChecker: { request in
            guard request.title == "Pass" else { return false }
            guard request.message == "Cannot place a disk." else { return false }
            guard request.actions.count == 1 else { return false }
            guard request.actions[0].title == "Dismiss" else { return false }
            guard request.actions[0].style == .default else { return false }
            
            return true
        })
        game.state.passNotificationRequest = Request()
        wait(for: [expectPass], timeout: 3.0)

        game.state.passNotificationRequest = nil
    }
    
    func testSave() {
        let game = MockGame()
        let viewModel = ViewModel(game: game)

        let subscriber = EventuallyFulfill<DetailedRequest<String>, Never>()
        viewModel.save
            .subscribe(subscriber)
        subscriber.store(in: &cancellables)

        let saveData = """
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
        let expectSave = expectation(description: "Save")
        subscriber.reset(expectSave, inputChecker: { request in
            return request.detail == saveData
        })
        
        game.state.saveRequest = DetailedRequest(saveData)
        wait(for: [expectSave], timeout: 3.0)
        
        game.state.saveRequest = nil
    }
    
    func testViewDidFirstAppear() {
        let game = MockGame()
        let viewModel = ViewModel(game: game)

        let subscriber = EventuallyFulfill<Actionish, Never>()
        game.dispatchCall
            .subscribe(subscriber)
        subscriber.store(in: &cancellables)

        // .startが呼ばれる
        let expectStart = expectation(description: ".start()")
        subscriber.reset(expectStart, inputChecker: { actionish in
            if case .action(.start) = actionish {
                return true
            }
            return false
        })
        viewModel.viewDidFirstAppear()
        wait(for: [expectStart], timeout: 3.0)
    }
    
    func testBoardViewUpdateCompleted() {
        let game = MockGame()
        let viewModel = ViewModel(game: game)

        let subscriber = EventuallyFulfill<Actionish, Never>()
        game.dispatchCall
            .subscribe(subscriber)
        subscriber.store(in: &cancellables)

        // .boardUpdatedが呼ばれる
        let requestId = UniqueIdentifier()
        let expectBoardUpdated = expectation(description: ".boardUpdated()")
        subscriber.reset(expectBoardUpdated, inputChecker: { actionish in
            if case let .action(.boardUpdated(requestId: id)) = actionish {
                return id == requestId
            }
            return false
        })
        viewModel.boardViewUpdateCompleted(requestId: requestId)
        wait(for: [expectBoardUpdated], timeout: 3.0)
    }
    
    func testPressResetButton() {
        let game = MockGame()
        let viewModel = ViewModel(game: game)

        let subscriber = EventuallyFulfill<Actionish, Never>()
        game.dispatchCall
            .subscribe(subscriber)
        subscriber.store(in: &cancellables)

        // .resetが呼ばれる
        let expectReset = expectation(description: ".reset()")
        subscriber.reset(expectReset, inputChecker: { actionish in
            if case .action(.reset) = actionish {
                return true
            }
            return false
        })
        viewModel.pressResetButton()
        wait(for: [expectReset], timeout: 3.0)
    }

    func tsstChangePlayerControlSegment() {
        let game = MockGame()
        let viewModel = ViewModel(game: game)

        let subscriber = EventuallyFulfill<Actionish, Never>()
        game.dispatchCall
            .subscribe(subscriber)
        subscriber.store(in: &cancellables)

        // .playerModeChangedが呼ばれる
        let expectPlayerModeChanged = expectation(description: ".playerModeChanged()")
        subscriber.reset(expectPlayerModeChanged, inputChecker: { actionish in
            if case let .action(.playerModeChanged(player: disk, mode: mode)) = actionish {
                return disk == .dark && mode == .computer
            }
            return false
        })
        viewModel.changePlayerControlSegment(side: 0, selectedIndex: 1)
        wait(for: [expectPlayerModeChanged], timeout: 3.0)
    }
    
    func testBoardViewDidSelectCell() {
        let game = MockGame()
        let viewModel = ViewModel(game: game)

        let subscriber = EventuallyFulfill<Actionish, Never>()
        game.dispatchCall
            .subscribe(subscriber)
        subscriber.store(in: &cancellables)

        // .boardCellSelectedが呼ばれる
        let expectBoardCellSelected = expectation(description: ".boardCellSelected()")
        subscriber.reset(expectBoardCellSelected, inputChecker: { actionish in
            if case let .action(.boardCellSelected(x: x, y: y)) = actionish {
                return x == 4 && y == 3
            }
            return false
        })
        viewModel.boardViewDidSelectCell(x: 4, y: 3)
        wait(for: [expectBoardCellSelected], timeout: 3.0)
    }
    
    func testAlertActionSelected() {
        let game = MockGame()
        let viewModel = ViewModel(game: game)

        let subscriber = EventuallyFulfill<Actionish, Never>()
        game.dispatchCall
            .subscribe(subscriber)
        subscriber.store(in: &cancellables)

        // パスの場合
        let passRequest = Request()
        game.state.passNotificationRequest = passRequest
        
        // .passDismissedが呼ばれる
        let expectPassDismissed = expectation(description: ".passDismissed()")
        subscriber.reset(expectPassDismissed, inputChecker: { actionish in
            if case let .action(.passDismissed(requestId: id)) = actionish {
                return id == passRequest.requestId
            }
            return false
        })
        viewModel.alertActionSelected(requestId: passRequest.requestId, selectedIndex: 0)
        wait(for: [expectPassDismissed], timeout: 3.0)

        game.state.passNotificationRequest = nil
        
        // リセット確認の場合
        let resetConfirmRequest = Request()
        game.state.resetConfirmationRequst = resetConfirmRequest

        // .resetConfirmedが呼ばれる
        let expectResetConfirmed = expectation(description: ".resetConfirmed()")
        subscriber.reset(expectResetConfirmed, inputChecker: { actionish in
            if case let .action(.resetConfirmed(requestId: id, execute: doExecute)) = actionish {
                return id == resetConfirmRequest.requestId && doExecute
            }
            return false
        })
        viewModel.alertActionSelected(requestId: resetConfirmRequest.requestId, selectedIndex: 1)
        wait(for: [expectResetConfirmed], timeout: 3.0)
        
        game.state.resetConfirmationRequst = nil
    }
    
    func testSaveCompleted() {
        let game = MockGame()
        let viewModel = ViewModel(game: game)

        let subscriber = EventuallyFulfill<Actionish, Never>()
        game.dispatchCall
            .subscribe(subscriber)
        subscriber.store(in: &cancellables)

        // .boardUpdatedが呼ばれる
        let requestId = UniqueIdentifier()
        let expectSaveCompleted = expectation(description: ".saveCompleted()")
        subscriber.reset(expectSaveCompleted, inputChecker: { actionish in
            if case let .action(.saveCompleted(requestId: id)) = actionish {
                return id == requestId
            }
            return false
        })
        viewModel.saveCompleted(requestId: requestId)
        wait(for: [expectSaveCompleted], timeout: 3.0)
    }
}

extension State {
    fileprivate mutating func modifyAtOnce(_ closure: (inout State) -> Void) {
        var state = self
        closure(&state)
        self = state
    }
}
