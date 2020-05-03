import Foundation
import Combine

class ViewModel {
    private let game: Game
    
    init() {
        game = Game(middlewares: [Logger.self])
        
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
            .eraseToAnyPublisher()

        messageLabelText = messageDiskAndText
            .map { $0.1 }
            .eraseToAnyPublisher()
        
        // プレイヤーモードの選択状態
        playerControlSelectedIndices = Disk.sides.map { side in
            return gameState
                .map { $0.playerModes[side].index }
                .eraseToAnyPublisher()
        }
        
        // ディスク枚数表示
        countLabelTexts = Disk.sides.map { side in
            return gameState
                .map { "\($0.diskCount[side])" }
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
                .eraseToAnyPublisher()
        }
        
        // リバーシ盤表示の更新依頼
        boardViewUpdate = gameState
            .compactMap { $0.boardUpdateRequest }
            .removeDuplicates()
            .eraseToAnyPublisher()

        // リセットの確認依頼
        showResetConfirmationAlert = gameState
            .compactMap { $0.resetConfirmationRequst }
            .removeDuplicates()
            .eraseToAnyPublisher()

        // 「パス」の表示依頼
        showPassAlert = gameState
            .compactMap { $0.passNotificationRequest }
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
    
    /// リセット確認のアラート表示
    let showResetConfirmationAlert: AnyPublisher<Request, Never>

    /// 「パス」のアラート表示
    let showPassAlert: AnyPublisher<Request, Never>
    
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
    
    /// リセット確認のアラートが閉じられたら呼び出します。
    /// - Parameters:
    ///   - requestId: `showResetConfirmationAlert` が発行したリクエストの `requestId`
    ///   - doReset: リセットを行うなら `true` 、キャンセルするなら `false`
    func resetConfirmed(requestId: UniqueIdentifier, doReset: Bool) {
        game.dispatch(.resetConfirmed(requestId: requestId, execute: doReset))
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
    
    /// 「パス」のアラートが閉じられたときに呼び出します。
    /// - Parameter requestId: `showPassAlert` が発行したリクエストの `requestId`
    func passDismissed(requestId: UniqueIdentifier) {
        game.dispatch(.passDismissed(requestId: requestId))
    }    
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
