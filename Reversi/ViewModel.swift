import Foundation
import Combine

class ViewModel {
    init() {
        // TODO: とりあえず
        boardViewUpdate = Empty().eraseToAnyPublisher()
        messageDiskViewDisk = Empty().eraseToAnyPublisher()
        messageLabelText = Empty().eraseToAnyPublisher()
        playerControlSelectedIndices = Disk.sides.map { _ in Empty().eraseToAnyPublisher() }
        countLabelTexts = Disk.sides.map { _ in Empty().eraseToAnyPublisher() }
        playerActivityIndicatorAnimateds = Disk.sides.map { _ in Empty().eraseToAnyPublisher() }
        showResetConfirmationAlert = Empty().eraseToAnyPublisher()
        showPassAlert = Empty().eraseToAnyPublisher()
    }

    // MARK: Outputs

    /// メッセージ表示の中のディスクの表示
    let messageDiskViewDisk: AnyPublisher<Disk?, Never>
 
    /// メッセージ表示の中のテキスト
    let messageLabelText: AnyPublisher<String, Never>
    
    /// プレイヤーモードの選択値
    let playerControlSelectedIndices: [AnyPublisher<Int, Never>]

    /// ディスクカウント
    let countLabelTexts: [AnyPublisher<String, Never>]
    
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
        
    }
    
    /// リバーシ盤の表示の更新が完了したときに呼び出します。
    /// - Parameter requestId: `boardViewUpdate` が発行したリクエストの `requestId`
    func boardViewUpdateCompleted(requestId: UniqueIdentifier) {
        
    }
    
    /// リセットボタンが押されたときに呼び出します。
    func pressResetButton() {
        
    }
    
    /// リセット確認のアラートが閉じられたら呼び出します。
    /// - Parameters:
    ///   - requestId: `showResetConfirmationAlert` が発行したリクエストの `requestId`
    ///   - doReset: リセットを行うなら `true` 、キャンセルするなら `false`
    func resetConfirmed(requestId: UniqueIdentifier, doReset: Bool) {
        
    }
    
    /// プレイヤーモードの切り替えが行われたときに呼び出します。
    /// - Parameters:
    ///   - player: どちらの `UISegmentedControl` か
    ///   - selectedIndex: `UISegmentedControl.selectedIndex` の値
    func changePlayerControlSegment(side: Int, selectedIndex: Int) {
        
    }
    
    /// ボードのセルがタップされたときに呼び出します。
    /// - Parameters:
    ///   - x: セルの列
    ///   - y: セルの行
    func boardViewDidSelectCell(x: Int, y: Int) {
        
    }
    
    /// 「パス」のアラートが閉じられたときに呼び出します。
    /// - Parameter requestId: `showPassAlert` が発行したリクエストの `requestId`
    func passDismissed(requestId: UniqueIdentifier) {
        
    }    
}
