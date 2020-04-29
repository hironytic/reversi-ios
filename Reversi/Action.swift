import Foundation

/// ゲームの状態を進めるためのアクションです。
public enum Action {
    /// ゲームを開始するときにディスパッチするアクションです。
    case start
    
    /// ボードのセルが選択されたときにディスパッチするアクションです。
    case boardCellSelected(x: Int, y: Int)
    
    /// 黒・白のプレイヤーモードが変更されたときにディスパッチするアクションです。
    case playerModeChanged(player: Disk, mode: PlayerMode)
    
    /// リセットボタンが押されたときにディスパッチするアクションです。
    case reset
    
    /// リセットの確認ができたときにディスパッチするアクションです。
    case executeReset
    
    /// 「パス」の表示を行ったときにディスパッチするアクションです。
    case passNotified(requestId: UniqueIdentifier)
    
    /// 「パス」の表示が消されたときにディスパッチするアクションです。
    case passDismissed
    
    /// リバーシ盤の更新が完了したときにディスパッチするアクションです。
    case boardUpdated(requestId: UniqueIdentifier)
}
