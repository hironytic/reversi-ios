import UIKit
import Combine

private let middlewares = [Logger.self]

class ViewModel {
    private let game: GameModel
    
    /// アラート表示の依頼内容
    struct AlertRequest {
        let requestId: UniqueIdentifier
        let title: String?
        let message: String?
        let actions: [AlertRequstAction]
    }
    struct AlertRequstAction {
        let title: String?
        let style: UIAlertAction.Style
    }
    
    convenience init(savedData: String? = nil) {
        // テスト実行のときはダミーのゲームに接続
        let isTestRunning = ProcessInfo.processInfo.environment["XCInjectBundleInto"] != nil
        if isTestRunning {
            self.init(game: NullGame())
            return
        }
        
        let game = savedData.flatMap { try? Game(loading: $0, middlewares: middlewares) } ?? Game(middlewares: middlewares)
        self.init(game: game)
    }
    
    init(game: GameModel) {
        self.game = game
        let gameState = game.statePublisher
            .share()
        
        // メッセージ
        let messageDiskAndText = gameState
            .map { (state) -> (Disk?, String) in
                if state.turn != nil {
                    return (state.turn, "'s turn")
                } else {
                    let darkCount = state.diskCount[.dark]
                    let lightCount = state.diskCount[.light]
                    if darkCount == lightCount {
                        return (nil, "Tied")
                    } else {
                        return (darkCount > lightCount ? .dark : .light, " won")
                    }
                }
            }
            .share()
        
        messageDiskViewDisk = messageDiskAndText
            .map { $0.0 }
            .removeDuplicates()
            .eraseToAnyPublisher()

        messageLabelText = messageDiskAndText
            .map { $0.1 }
            .removeDuplicates()
            .eraseToAnyPublisher()
        
        // プレイヤーモードの選択状態
        playerControlSelectedIndices = Disk.sides.map { side in
            return gameState
                .map { $0.playerModes[side].index }
                .removeDuplicates()
                .eraseToAnyPublisher()
        }
        
        // ディスク枚数表示
        countLabelTexts = Disk.sides.map { side in
            return gameState
                .map { "\($0.diskCount[side])" }
                .removeDuplicates()
                .eraseToAnyPublisher()
        }

        // 思考中表示のぐるぐる
        playerActivityIndicatorAnimateds = Disk.sides.map { side in
            return gameState
                .map { state in
                    if state.turn != side {
                        return false
                    } else {
                        return state.thinking
                    }
                }
                .removeDuplicates()
                .eraseToAnyPublisher()
        }
        
        // リバーシ盤表示の更新依頼
        boardViewUpdate = gameState
            .compactMap { $0.boardUpdateRequest }
            .removeDuplicates()
            .eraseToAnyPublisher()

        // リセットの確認依頼
        let resetConfirmationAlert = gameState
            .compactMap { $0.resetConfirmationRequst }
            .removeDuplicates()
            .map { (request: Request) in
                return AlertRequest(requestId: request.requestId,
                                    title: "Confirmation",
                                    message: "Do you really want to reset the game?",
                                    actions: [AlertRequstAction(title: "Cancel", style: .cancel),
                                              AlertRequstAction(title: "OK", style: .default)])
            }

        // 「パス」の表示依頼
        let passAlert = gameState
            .compactMap { $0.passNotificationRequest }
            .removeDuplicates()
            .map { (request: Request) in
                return AlertRequest(requestId: request.requestId,
                                    title: "Pass",
                                    message: "Cannot place a disk.",
                                    actions: [AlertRequstAction(title: "Dismiss", style: .default)])
            }

        showAlert = resetConfirmationAlert
            .merge(with: passAlert)
            .eraseToAnyPublisher()
        
        // セーブ依頼のハンドリング
        save = gameState
            .compactMap { $0.saveRequest }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    // MARK: Outputs

    /// メッセージ表示の中のディスクの表示
    let messageDiskViewDisk: AnyPublisher<Disk?, Never>
 
    /// メッセージ表示の中のテキスト
    let messageLabelText: AnyPublisher<String?, Never>
    
    /// プレイヤーモードの選択値
    let playerControlSelectedIndices: [AnyPublisher<Int, Never>]

    /// ディスクカウント
    let countLabelTexts: [AnyPublisher<String?, Never>]
    
    /// ぐるぐる
    let playerActivityIndicatorAnimateds: [AnyPublisher<Bool, Never>]

    /// リバーシ盤表示の更新
    let boardViewUpdate: AnyPublisher<DetailedRequest<BoardUpdate>, Never>
    
    /// アラート表示
    let showAlert: AnyPublisher<AlertRequest, Never>
    
    /// セーブ
    let save: AnyPublisher<DetailedRequest<String>, Never>
    
    // MARK: Inputs
    
    /// ビューが初めて表示されたときに呼び出します。
    func viewDidFirstAppear() {
        game.dispatch(.start())
    }
    
    /// リバーシ盤の表示の更新が完了したときに呼び出します。
    /// - Parameter requestId: `boardViewUpdate` が発行したリクエストの `requestId`
    func boardViewUpdateCompleted(requestId: UniqueIdentifier) {
        game.dispatch(.boardUpdated(requestId: requestId))
    }
    
    /// リセットボタンが押されたときに呼び出します。
    func pressResetButton() {
        game.dispatch(.reset())
    }
    
    /// プレイヤーモードの切り替えが行われたときに呼び出します。
    /// - Parameters:
    ///   - player: どちらの `UISegmentedControl` か
    ///   - selectedIndex: `UISegmentedControl.selectedIndex` の値
    func changePlayerControlSegment(side: Int, selectedIndex: Int) {
        let player = Disk(index: side)
        let mode = PlayerMode(index: selectedIndex)
        game.dispatch(.playerModeChanged(player: player, mode: mode))
    }
    
    /// ボードのセルがタップされたときに呼び出します。
    /// - Parameters:
    ///   - x: セルの列
    ///   - y: セルの行
    func boardViewDidSelectCell(x: Int, y: Int) {
        game.dispatch(.boardCellSelected(x: x, y: y))
    }
    
    /// アラートが閉じられたときに呼び出します。
    /// - Parameters:
    ///   - requestId: `showAlert` が発行したリクエストの `requestId`
    ///   - index: 選択されたアクションのインデックス
    func alertActionSelected(requestId: UniqueIdentifier, selectedIndex: Int) {
        if let resetConfirmation = game.state.resetConfirmationRequst, resetConfirmation.requestId == requestId {
            game.dispatch(.resetConfirmed(requestId: requestId, execute: selectedIndex == 1))
        } else if let passNotifiaction = game.state.passNotificationRequest, passNotifiaction.requestId == requestId {
            game.dispatch(.passDismissed(requestId: requestId))
        }
    }
    
    /// セーブが完了したときに呼び出します。
    /// - Parameter requestid: `save` が発行したリクエストの `requestId`
    func saveCompleted(requestId: UniqueIdentifier) {
        game.dispatch(.saveCompleted(requestId: requestId))
    }
}

class NullGame: GameModel {
    /// 現在の状態
    var state: State = State(board: Board(), turn: .dark, playerModes: [.manual, .manual])
    
    /// 現在の状態が変更されたときのイベント発行者
    var statePublisher: AnyPublisher<State, Never> = Empty().eraseToAnyPublisher()
    
    /// アクションらしきものをディスパッチします。
    /// - Parameter actionish: アクションらしきもの
    func dispatch(_ actionish: Actionish) {}
}

// MARK: - fileprivate extensions

extension PlayerMode {
    fileprivate init(index: Int) {
        guard let mode = PlayerMode.allCases.first(where: { $0.index == index }) else {
            preconditionFailure("Illegal index: \(index)")
        }
        self = mode
    }
    
    fileprivate var index: Int {
        switch self {
        case .manual: return 0
        case .computer: return 1
        }
    }
}

extension Disk {
    fileprivate init(index: Int) {
        guard let mode = Disk.sides.first(where: { $0.index == index }) else {
            preconditionFailure("Illegal index: \(index)")
        }
        self = mode
    }
    
    fileprivate var index: Int {
        switch self {
        case .dark: return 0
        case .light: return 1
        }
    }
}
